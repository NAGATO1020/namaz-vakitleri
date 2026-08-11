"""Fazilet Takvimi'nin ulke/sehir listesini indirip assets/fazilet_cities.tsv.gz uretir.

Kaynaklar:
    https://fazilettakvimi.com/namaz-vakitleri/            -> ulke listesi (sayfa icinde)
    https://fazilettakvimi.com/api/cms/cities-by-country?districtId=<ulkeId>&lang=1

Cikti bicimi (turktakvim listesiyle ayni, ayni Dart ayristiricisi okuyor):
    #<ulke adi>
    <cityId>\t<sehir adi>
    ...

Kullanim:  python tool/build_fazilet_cities.py
"""
from __future__ import annotations

import gzip
import io
import json
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DST = ROOT / "assets" / "fazilet_cities.tsv.gz"

COUNTRIES_FILE = Path(__file__).resolve().parent / "fazilet_countries.json"
CITIES = "https://fazilettakvimi.com/api/cms/cities-by-country?districtId={}&lang=1"
USER_AGENT = "NamazVakitleri/1.0 (build tool; fazilettakvimi.com verisi)"

# Kaynaga yuk bindirmemek icin istekler arasi bekleme.
GAP_SECONDS = 0.3


def fetch(url: str, retries: int = 3) -> bytes:
    last = None
    for attempt in range(retries):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=45) as response:
                return response.read()
        except (urllib.error.URLError, TimeoutError) as exc:
            last = exc
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"{url} alinamadi: {last}")


def countries() -> list[tuple[int, str]]:
    """Ulke listesi.

    Site bu listeyi bir API'den degil React uygulamasinin kendi icinden
    veriyor, sayfanin HTML'inde yok. Bu yuzden bir kez sitedeki secicinin
    DOM'undan alinip `fazilet_countries.json` olarak kaydedildi. Site yeni
    ulke eklerse o dosyanin guncellenmesi gerekir.
    """
    data = json.loads(COUNTRIES_FILE.read_text(encoding="utf-8"))
    seen: dict[int, str] = {}
    for item in data:
        seen.setdefault(int(item["id"]), str(item["adi"]).strip())
    return sorted(seen.items(), key=lambda kv: kv[1])


def cities_of(country_id: int) -> list[tuple[int, str]]:
    raw = fetch(CITIES.format(country_id)).decode("utf-8", errors="replace")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    if not isinstance(data, list):
        return []
    out = []
    for item in data:
        if isinstance(item, dict) and isinstance(item.get("id"), int):
            out.append((item["id"], str(item.get("adi", "")).strip()))
    return out


def main() -> int:
    country_list = countries()
    if len(country_list) < 50:
        print(f"HATA: yalnizca {len(country_list)} ulke bulundu, sayfa yapisi degismis olabilir")
        return 1
    print(f"{len(country_list)} ulke bulundu, sehirler indiriliyor...")

    out = io.StringIO()
    total = 0
    empty: list[str] = []

    for index, (country_id, country_name) in enumerate(country_list, 1):
        try:
            found = cities_of(country_id)
        except RuntimeError as exc:
            print(f"  ! {country_name}: {exc}")
            found = []

        if not found:
            empty.append(country_name)
        else:
            out.write("#" + country_name + "\n")
            for city_id, city_name in found:
                if city_name:
                    out.write(f"{city_id}\t{city_name}\n")
                    total += 1

        if index % 25 == 0 or index == len(country_list):
            print(f"  {index}/{len(country_list)} ulke, {total} sehir")
        time.sleep(GAP_SECONDS)

    if total < 1000:
        print(f"HATA: yalnizca {total} sehir toplandi, beklenen binlerce")
        return 1

    data = out.getvalue().encode("utf-8")
    DST.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(DST, "wb", compresslevel=9) as fh:
        fh.write(data)

    print(f"\nsehir : {total}")
    print(f"ham   : {len(data) / 1024 / 1024:.2f} MB")
    print(f"gzip  : {DST.stat().st_size / 1024 / 1024:.2f} MB -> {DST.relative_to(ROOT)}")
    if empty:
        print(f"sehri gelmeyen ulkeler ({len(empty)}): {', '.join(empty[:12])}"
              + (" …" if len(empty) > 12 else ""))

    text = data.decode("utf-8")
    for probe in ("\tİstanbul\n", "\tAnkara\n"):
        print(f"kontrol {probe.strip()!r:14} -> {'VAR' if probe in text else 'YOK'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
