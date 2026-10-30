#!/usr/bin/env python3
"""Generate Doki's self-made demo artwork as an Xcode asset catalog.

The artwork is intentionally abstract and original. It is not derived from any
anime key visual, reference application or upstream image. Run with the bundled
Python that includes Pillow:

    /Users/yaron/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/python/bin/python3 \
      scripts/generate-demo-assets.py

Outputs:
    App/tvOS/Resources/Assets.xcassets/poster-NN.imageset
    App/tvOS/Resources/Assets.xcassets/backdrop-NN.imageset
    App/tvOS/Resources/Assets.xcassets/profile-orb.imageset
"""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "App/tvOS/Resources/Assets.xcassets"

SUBJECTS = [
    ("01", "Stellar Postman", "41D6C3", "00"),
    ("02", "Echoes of Summer", "F39A68", "01"),
    ("03", "Detective Club in the Mist", "7C8EA8", "02"),
    ("04", "Little Cosmic Kitchen", "E7C15A", "03"),
    ("05", "The Northbound Line", "97B7D8", "04"),
    ("06", "Moonlight Library", "9C8BE8", "05"),
    ("07", "Garden of Winds", "88C99A", "06"),
    ("08", "Signal from the Deep", "3E9DC9", "07"),
    ("09", "Paper Plane League", "F2B35D", "08"),
    ("10", "Midnight Radio 24:00", "D77A9A", "09"),
    ("11", "Machines and Wheat", "B7C46B", "10"),
    ("12", "Read This Unsent Letter to the Wind", "7DA8C8", "11"),
]

CJK_FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
LATIN_FONT = "/System/Library/Fonts/HelveticaNeue.ttc"


def rgb(hex_value: str) -> tuple[int, int, int]:
    return tuple(int(hex_value[i : i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def gradient(size, top, bottom) -> Image.Image:
    width, height = size
    y = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None, None]
    top_arr = np.array(top, dtype=np.float32)[None, None, :]
    bottom_arr = np.array(bottom, dtype=np.float32)[None, None, :]
    arr = top_arr * (1 - y) + bottom_arr * y
    arr = np.repeat(arr, width, axis=1)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def add_glow(base: Image.Image, center, radius, color, alpha=120) -> None:
    width, height = base.size
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    cx, cy = center
    for step in range(18, 0, -1):
        r = int(radius * step / 18)
        a = int(alpha * (1 - step / 20))
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*color, a))
    glow = glow.filter(ImageFilter.GaussianBlur(max(4, radius // 12)))
    base.alpha_composite(glow)


def add_grain(image: Image.Image, seed: int, strength=10) -> None:
    rng = np.random.default_rng(seed)
    arr = np.asarray(image).astype(np.int16)
    noise = rng.normal(0, strength, size=arr.shape[:2])[:, :, None]
    arr[:, :, :3] = np.clip(arr[:, :, :3] + noise, 0, 255)
    image.paste(Image.fromarray(arr.astype(np.uint8), "RGBA"))


def font(path: str, size: int):
    try:
        return ImageFont.truetype(path, size=size)
    except OSError:
        return ImageFont.load_default()


def draw_poster(path: Path, number: str, english: str, accent_hex: str, seed: int) -> None:
    accent = rgb(accent_hex)
    base = gradient((600, 900), mix(accent, (8, 12, 20), 0.70), (5, 8, 14))
    glow = base.convert("RGBA")
    add_glow(glow, (430, 220), 260, accent, 150)
    add_glow(glow, (90, 720), 220, mix(accent, (255, 255, 255), 0.25), 90)

    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    rng = random.Random(seed)

    # Concentric orbital rings and a large off-centre disc.
    for i in range(5):
        inset = 70 + i * 42
        draw.ellipse(
            (inset, 160 + inset // 3, 600 - inset, 900 - inset * 2),
            outline=(*mix(accent, (255, 255, 255), 0.45), 34),
            width=2,
        )
    draw.ellipse((300, 90, 700, 490), outline=(*accent, 90), width=2)
    draw.ellipse((330, 160, 600, 430), fill=(*accent, 22))
    draw.arc((260, 180, 680, 600), 200, 340, fill=(*accent, 180), width=5)

    # A few deterministic geometric accents.
    for _ in range(7):
        x = rng.randint(-40, 560)
        y = rng.randint(80, 760)
        w = rng.randint(40, 210)
        draw.line((x, y, x + w, y + rng.randint(-40, 40)), fill=(255, 255, 255, 18), width=1)
    for _ in range(22):
        x = rng.randint(30, 570)
        y = rng.randint(40, 760)
        r = rng.choice([1, 1, 1, 2, 2, 3])
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, rng.randint(25, 90)))

    # Vertical type is a Doki layout motif, not a copy of another app.
    title_font = font(CJK_FONT, 24)
    label_font = font(LATIN_FONT, 17)
    number_font = font(LATIN_FONT, 96)
    label = f"DOKI  /  {number}"
    draw.text((44, 48), label, fill=(255, 255, 255, 150), font=label_font)
    draw.text((44, 760), english.upper()[:28], fill=(255, 255, 255, 190), font=title_font)
    draw.text((470, 680), number, fill=(*accent, 80), font=number_font)
    draw.rectangle((44, 812, 180, 814), fill=(*accent, 210))
    draw.text((44, 828), "SELF-MADE DEMO ART", fill=(255, 255, 255, 95), font=font(LATIN_FONT, 11))

    glow.alpha_composite(layer)
    add_grain(glow, seed, 7)
    glow.convert("RGB").save(path, optimize=True)


def draw_backdrop(path: Path, number: str, english: str, accent_hex: str, seed: int) -> None:
    accent = rgb(accent_hex)
    base = gradient((1600, 900), mix(accent, (6, 10, 18), 0.82), (4, 7, 12))
    canvas = base.convert("RGBA")
    add_glow(canvas, (1160, 260), 540, accent, 135)
    add_glow(canvas, (220, 760), 320, mix(accent, (255, 255, 255), 0.35), 65)

    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    rng = random.Random(seed + 700)

    # Horizon and sweeping orbit lines.
    draw.line((0, 620, 1600, 520), fill=(*accent, 65), width=2)
    draw.line((0, 700, 1600, 600), fill=(255, 255, 255, 16), width=1)
    for i in range(9):
        y = 170 + i * 72
        draw.arc((-200, y - 600, 1800, y + 520), 205, 335, fill=(*accent, 18 + i), width=2)
    draw.ellipse((1010, 80, 1660, 730), outline=(*accent, 55), width=2)
    draw.ellipse((1110, 180, 1560, 630), fill=(*accent, 18))

    for _ in range(80):
        x = rng.randint(0, 1600)
        y = rng.randint(30, 760)
        r = rng.choice([1, 1, 1, 2, 2, 3, 4])
        alpha = rng.randint(18, 100)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, alpha))

    # Thin lines and a soft vignette; no fake glass or blur gradient screenshot.
    for _ in range(12):
        x = rng.randint(0, 1500)
        y = rng.randint(140, 760)
        draw.line((x, y, x + rng.randint(100, 420), y + rng.randint(-30, 30)),
                  fill=(255, 255, 255, 14), width=1)

    label_font = font(LATIN_FONT, 18)
    draw.text((64, 52), f"DOKI  /  {number}  /  SELF-MADE DEMO", fill=(255, 255, 255, 110),
              font=label_font)
    draw.text((64, 760), english.upper()[:52], fill=(255, 255, 255, 150),
              font=font(CJK_FONT, 22))

    canvas.alpha_composite(layer)
    add_grain(canvas, seed + 1, 5)
    canvas.convert("RGB").save(path, optimize=True)


def draw_profile(path: Path) -> None:
    base = gradient((400, 400), (41, 74, 92), (11, 19, 29)).convert("RGBA")
    add_glow(base, (290, 100), 180, (91, 220, 205), 125)
    draw = ImageDraw.Draw(base)
    for i in range(6):
        inset = 28 + i * 26
        draw.ellipse((inset, inset, 400 - inset, 400 - inset),
                     outline=(255, 255, 255, 22), width=2)
    draw.ellipse((96, 70, 320, 294), fill=(255, 255, 255, 18))
    draw.text((120, 112), "D", fill=(255, 255, 255, 230), font=font(LATIN_FONT, 190))
    add_grain(base, 42, 6)
    base.convert("RGB").save(path, optimize=True)


def write_imageset(name: str, filename: str) -> None:
    directory = ASSETS / f"{name}.imageset"
    directory.mkdir(parents=True, exist_ok=True)
    contents = {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "scale": "1x",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (directory / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )

    for index, (number, english, accent_hex, seed) in enumerate(SUBJECTS, start=1):
        name = f"poster-{number}"
        filename = f"{name}.png"
        draw_poster(ASSETS / filename, number, english, accent_hex, index * 37 + 5)
        write_imageset(name, filename)
        (ASSETS / filename).replace(ASSETS / f"{name}.imageset" / filename)

        # The fixture intentionally has one missing poster and one missing
        # backdrop so the TV layout can verify its no-blank fallback.
        if number != "07":
            bname = f"backdrop-{number}"
            bfilename = f"{bname}.png"
            draw_backdrop(ASSETS / bfilename, number, english, accent_hex, index * 53 + 11)
            write_imageset(bname, bfilename)
            (ASSETS / bfilename).replace(ASSETS / f"{bname}.imageset" / bfilename)

    profile_name = "profile-orb"
    profile_file = f"{profile_name}.png"
    draw_profile(ASSETS / profile_file)
    write_imageset(profile_name, profile_file)
    (ASSETS / profile_file).replace(ASSETS / f"{profile_name}.imageset" / profile_file)

    print(f"Generated artwork in {ASSETS}")


if __name__ == "__main__":
    main()
