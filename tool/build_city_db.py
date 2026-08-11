"""turktakvim sehir listesini indirip assets/cities.tsv.gz uretir.

Kaynak:
    https://gadget.turktakvim.com/gadget.php?pg=2
`q` parametresi sunucuda yok sayiliyor; istek her zaman tum listeyi donduruyor
(~15 MB, 234 ulke / 122.314 sehir). Bu yuzden bir kez indirilip uygulamaya
gomuluyor ve arama tamamen cevrimdisi calisiyor.

Cikti bicimi (gzip'li UTF-8 metin):
    #<ulke adi>
    <cityID>\t<sehir adi>
    ...

Kullanim:
    python tool/build_city_db.py            # indir + uret
    python tool/build_city_db.py kayit.html # elde varolan HTML'den uret
"""
from __future__ import annotations

import gzip
import html
import io
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DST = ROOT / "assets" / "cities.tsv.gz"
URL = "https://gadget.turktakvim.com/gadget.php?pg=2"
USER_AGENT = "NamazVakitleri/1.0 (build tool; turktakvim.com verisi)"

COUNTRY_RE = re.compile(r'onclick="goster_gizle\((\d+)\);"[^>]*/>\s*([^<]+?)\s*<br', re.S)
CITY_RE = re.compile(
    r'onclick="sehir_yap\((\d+)\)"><img src="ok\.gif"[^>]*/>([^<]+)</div>'
)


def fetch() -> str:
    print(f"indiriliyor: {URL}")
    request = urllib.request.Request(URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        raw = response.read()
    print(f"  {len(raw) / 1024 / 1024:.1f} MB alindi")
    return raw.decode("utf-8", errors="replace")


def build(raw: str) -> tuple[bytes, int, int]:
    countries = [
        (m.group(1), html.unescape(m.group(2)).strip(), m.end())
        for m in COUNTRY_RE.finditer(raw)
    ]
    out = io.StringIO()
    total = 0

    for i, (_, name, start) in enumerate(countries):
        end = countries[i + 1][2] if i + 1 < len(countries) else len(raw)
        cities = CITY_RE.findall(raw[start:end])
        if not cities:
            continue
        out.write("#" + name + "\n")
        for city_id, city_name in cities:
            out.write(f"{city_id}\t{html.unescape(city_name).strip()}\n")
            total += 1

    return out.getvalue().encode("utf-8"), len(countries), total


def main() -> int:
    raw = Path(sys.argv[1]).read_text(encoding="utf-8") if len(sys.argv) > 1 else fetch()

    data, country_count, city_count = build(raw)
    if city_count < 100_000:
        print(f"HATA: yalnizca {city_count} sehir ayristirildi, beklenen 120.000+")
        print("Sayfa yapisi degismis olabilir; regex'leri gozden gecir.")
        return 1

    DST.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(DST, "wb", compresslevel=9) as fh:
        fh.write(data)

    print(f"ulke : {country_count}")
    print(f"sehir: {city_count}")
    print(f"ham  : {len(data) / 1024 / 1024:.2f} MB")
    print(f"gzip : {DST.stat().st_size / 1024 / 1024:.2f} MB -> {DST.relative_to(ROOT)}")

    text = data.decode("utf-8")
    for probe in ("\tİstanbul-İstanbul\n", "\tSchönberg-Fribourg\n"):
        status = "VAR" if probe in text else "YOK"
        print(f"kontrol {probe.strip()!r:26} -> {status}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
