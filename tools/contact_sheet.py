#!/usr/bin/env python3
"""Put several screenshots side by side in one image, to review a whole flow at a glance.

    python3 -I tools/contact_sheet.py <screenshots dir> out.jpg [names…] [--scale 0.42] [--per-row 5]

Without names, takes every .jpg/.png in the folder in name order (01-…, 02-…). Several rows are made
when there are more images than --per-row. Needs Pillow.
"""
import argparse
import os

from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("folder")
parser.add_argument("out")
parser.add_argument("names", nargs="*", help="Nombres sin extensión, en el orden deseado")
parser.add_argument("--scale", type=float, default=0.42)
parser.add_argument("--per-row", type=int, default=5)
args = parser.parse_args()

files = []
if args.names:
    for name in args.names:
        match = next((f for f in os.listdir(args.folder) if os.path.splitext(f)[0] == name), None)
        if match is None:
            raise SystemExit(f"No encuentro {name} en {args.folder}")
        files.append(match)
else:
    files = sorted(f for f in os.listdir(args.folder) if f.lower().endswith((".jpg", ".png")))

images = [Image.open(os.path.join(args.folder, f)).convert("RGB") for f in files]
w = int(images[0].width * args.scale)
h = int(images[0].height * args.scale)
gap = 10
rows = [images[i:i + args.per_row] for i in range(0, len(images), args.per_row)]
sheet = Image.new("RGB", (len(rows[0]) * (w + gap) - gap, len(rows) * (h + gap) - gap), "white")
for r, row in enumerate(rows):
    for c, image in enumerate(row):
        sheet.paste(image.resize((w, h)), (c * (w + gap), r * (h + gap)))
sheet.save(args.out, quality=85)
print(f"{len(images)} capturas → {args.out}")
