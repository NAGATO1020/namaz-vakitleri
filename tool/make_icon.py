"""Hilal uygulama ikonunu uretir.

Ciktilar:
  android/app/src/main/res/mipmap-*/ic_launcher.png          (klasik ikon)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png (adaptive on kat)
  android/app/src/main/res/drawable-*/ic_stat_crescent.png   (bildirim ikonu, beyaz)
  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png
  assets/icon_preview.png                                    (gorsel kontrol)

Kullanim:  python tool/make_icon.py
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

# Tema renkleri (lib/core/theme.dart ile ayni)
NIGHT_TOP = (27, 58, 107)      # #1B3A6B
NIGHT_BOTTOM = (12, 26, 51)    # koyu gece
GOLD = (232, 184, 75)          # #E8B84B
GOLD_LIGHT = (247, 214, 130)

SS = 8  # supersampling


def _crescent_mask(size: int) -> Image.Image:
    """Buyuk daireden kaydirilmis daireyi cikararak hilal maskesi uretir."""
    s = size * SS
    mask = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(mask)

    # Dis daire
    cx, cy, r = 0.455 * s, 0.50 * s, 0.345 * s
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

    # Kesen daire — hilalin ici
    kx, ky, kr = 0.600 * s, 0.432 * s, 0.310 * s
    d.ellipse([kx - kr, ky - kr, kx + kr, ky + kr], fill=0)

    return mask.resize((size, size), Image.LANCZOS)


def _vertical_gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    img = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(size - 1, 1)
        img.putpixel(
            (0, y),
            tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )
    return img.resize((size, size), Image.BICUBIC)


def _gold_layer(size: int) -> Image.Image:
    """Hilalin kendisi — ustten alta hafif altin gecisi."""
    grad = _vertical_gradient(size, GOLD_LIGHT, GOLD).convert("RGBA")
    grad.putalpha(_crescent_mask(size))
    return grad


def full_icon(size: int, rounded: bool = False) -> Image.Image:
    """Arka planli tam ikon (klasik launcher ve iOS icin)."""
    bg = _vertical_gradient(size, NIGHT_TOP, NIGHT_BOTTOM).convert("RGBA")
    if rounded:
        s = size * SS
        m = Image.new("L", (s, s), 0)
        ImageDraw.Draw(m).ellipse([0, 0, s - 1, s - 1], fill=255)
        bg.putalpha(m.resize((size, size), Image.LANCZOS))

    # Hilal, tam ikonda biraz daha kucuk dursun (kenar bosluğu)
    inner = round(size * 0.78)
    crescent = _gold_layer(inner)
    out = bg.copy()
    off = (size - inner) // 2
    out.alpha_composite(crescent, (off, off))
    return out


def adaptive_foreground(size: int) -> Image.Image:
    """Adaptive icon on katmani: 108dp tuvalin ortasindaki 66dp guvenli alan."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = round(size * 0.58)  # 108 -> ~63dp, guvenli alanin icinde
    canvas.alpha_composite(_gold_layer(inner), ((size - inner) // 2,) * 2)
    return canvas


def notification_icon(size: int) -> Image.Image:
    """Bildirim ikonu: Android sadece alfa kanalini kullanir, duz beyaz."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = round(size * 0.92)
    white = Image.new("RGBA", (inner, inner), (255, 255, 255, 255))
    white.putalpha(_crescent_mask(inner))
    canvas.alpha_composite(white, ((size - inner) // 2,) * 2)
    return canvas


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print(f"  {path.relative_to(ROOT)}  ({img.width}x{img.height})")


def main() -> None:
    res = ROOT / "android/app/src/main/res"

    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

    print("Android launcher ikonlari:")
    for name, scale in densities.items():
        px = round(48 * scale)
        save(full_icon(px), res / f"mipmap-{name}/ic_launcher.png")
        save(full_icon(px, rounded=True), res / f"mipmap-{name}/ic_launcher_round.png")
        save(adaptive_foreground(round(108 * scale)),
             res / f"mipmap-{name}/ic_launcher_foreground.png")

    print("Bildirim ikonlari (beyaz siluet):")
    for name, scale in densities.items():
        save(notification_icon(round(24 * scale)),
             res / f"drawable-{name}/ic_stat_crescent.png")

    print("Play Store gorseli:")
    save(full_icon(512), ROOT / "assets/icon_playstore.png")

    print("iOS ikonlari:")
    appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((appicon / "Contents.json").read_text(encoding="utf-8"))
    for entry in contents.get("images", []):
        filename = entry.get("filename")
        if not filename:
            continue
        base = float(entry["size"].split("x")[0])
        mult = int(entry["scale"].rstrip("x"))
        px = round(base * mult)
        # iOS ikonlari seffaflik kabul etmez
        save(full_icon(px).convert("RGB").convert("RGBA"), appicon / filename)

    print("Onizleme:")
    preview = Image.new("RGBA", (512 * 3 + 64, 512), (255, 255, 255, 0))
    preview.alpha_composite(full_icon(512), (0, 0))
    preview.alpha_composite(full_icon(512, rounded=True), (512 + 32, 0))
    dark_bg = Image.new("RGBA", (512, 512), (30, 30, 30, 255))
    dark_bg.alpha_composite(notification_icon(512))
    preview.alpha_composite(dark_bg, (1024 + 64, 0))
    save(preview, ROOT / "assets/icon_preview.png")


if __name__ == "__main__":
    main()
