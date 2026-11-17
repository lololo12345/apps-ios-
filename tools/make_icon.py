#!/usr/bin/env python3
"""Generate a 1024×1024 app icon: diagonal gradient, soft glow and a short glyph (one or two letters).

Usage:
    python3 tools/make_icon.py out.png --from 2A1B5E --to 120C2E --glyph C [--glyph-color FFB020]

Uses Pillow when it is installed (nicer: glow and real fonts). Without Pillow it still writes a valid
gradient PNG with the standard library, so scripts that depend on it never fail (CI runners, fresh machines).
Replace the result with a hand-made icon whenever the app deserves one.
"""
import argparse
import math
import struct
import zlib

SIZE = 1024
FONTS = [
    "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf",
    "/usr/share/fonts/opentype/inter/Inter-Black.otf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/System/Library/Fonts/SFNSRounded.ttf",
    "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf",
    "/Library/Fonts/Arial Bold.ttf",
]


def rgb(hex_text: str) -> tuple[int, int, int]:
    value = int(hex_text.lstrip("#"), 16)
    return (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def plain_png(path: str, top, bottom) -> None:
    """Gradient PNG with only the standard library."""
    rows = []
    for y in range(SIZE):
        row = bytearray([0])
        for x in range(0, SIZE):
            t = min(1.0, (x + y) / (2 * SIZE) + 0.15 * math.hypot(x - SIZE / 2, y - SIZE * 0.4) / SIZE)
            row += bytes(mix(top, bottom, t))
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows), 9)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", raw) + chunk(b"IEND", b""))


def pillow_png(path: str, top, bottom, glyph: str, glyph_color) -> None:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont

    image = Image.new("RGB", (SIZE, SIZE))
    pixels = image.load()
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x - SIZE * 0.5, y - SIZE * 0.38) / (SIZE * 0.8)
            pixels[x, y] = mix(top, bottom, min(1.0, d))
    if glyph:
        font = None
        for candidate in FONTS:
            try:
                font = ImageFont.truetype(candidate, int(SIZE * (0.62 if len(glyph) == 1 else 0.44)))
                break
            except OSError:
                continue
        font = font or ImageFont.load_default()
        mask = Image.new("L", (SIZE, SIZE), 0)
        draw = ImageDraw.Draw(mask)
        box = draw.textbbox((0, 0), glyph, font=font)
        position = ((SIZE - (box[2] - box[0])) / 2 - box[0], (SIZE - (box[3] - box[1])) / 2 - box[1])
        draw.text(position, glyph, font=font, fill=255)
        glow = mask.filter(ImageFilter.GaussianBlur(48)).point(lambda v: int(v * 0.6))
        image = Image.composite(Image.new("RGB", (SIZE, SIZE), glyph_color), image, glow)
        image = Image.composite(Image.new("RGB", (SIZE, SIZE), glyph_color), image, mask)
    image.save(path)


def make_icon(path: str, top: str, bottom: str, glyph: str = "", glyph_color: str = "FFFFFF") -> str:
    try:
        pillow_png(path, rgb(top), rgb(bottom), glyph, rgb(glyph_color))
        return "pillow"
    except ImportError:
        plain_png(path, rgb(top), rgb(bottom))
        return "plain"


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("out")
    parser.add_argument("--from", dest="top", default="3A227A")
    parser.add_argument("--to", dest="bottom", default="0E0A24")
    parser.add_argument("--glyph", default="")
    parser.add_argument("--glyph-color", default="FFFFFF")
    args = parser.parse_args()
    print(make_icon(args.out, args.top, args.bottom, args.glyph, args.glyph_color))
