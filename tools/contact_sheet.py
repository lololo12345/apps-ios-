#!/usr/bin/env python3
"""Put several screenshots side by side in one image, to review a whole flow at a glance.

    python3 -I tools/contact_sheet.py <screenshots dir> out.jpg [names…] [--scale 0.42] [--per-row 5]

Without names, takes every .jpg/.png in the folder in name order (01-…, 02-…). Several rows are made
when there are more images than --per-row. Needs Pillow.

It also warns about screenshots that are almost blank (a screen caught mid-transition) and about two
consecutive screenshots that are practically identical (a tap that did nothing).
"""
import argparse
import os

from PIL import Image, ImageChops, ImageFilter, ImageStat

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

warnings = []
previous = None
for name, image in zip(files, images):
    small = image.resize((180, 390)).convert("L")
    # Edge density below the status bar: real screens score 5+, a blank half-drawn screen about 1.4.
    edges = ImageStat.Stat(small.crop((0, 24, 180, 390)).filter(ImageFilter.FIND_EDGES)).mean[0]
    if edges < 3:
        warnings.append(f"⚠ {name}: casi vacía (¿capturada a mitad de una animación?)")
    if previous is not None and ImageStat.Stat(ImageChops.difference(previous, small)).mean[0] < 0.6:
        warnings.append(f"⚠ {name}: igual que la anterior (¿el toque no hizo nada?)")
    previous = small
print("\n".join(warnings) if warnings else "Sin avisos: ninguna captura vacía ni repetida.")
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
