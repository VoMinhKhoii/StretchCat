#!/usr/bin/env python3
"""Make the cat's *outer* background transparent.

The cat is a white calico on a pure-white background, so a naive
"remove all white" would eat its white fur. Instead we flood-fill inward
from the four corners: only the white region connected to the edges
becomes transparent, while the cat's interior white fur is preserved.

Then we auto-crop to the cat's bounding box (plus a little padding) so the
PNG hugs the character.

    python3 scripts/prep_image.py _assets/cat-source.png Resources/cat.png
"""
import sys
from PIL import Image, ImageDraw

# How close to white a pixel must be to count as background, 0..255 per channel.
THRESHOLD = 30
PADDING = 24  # px of transparent margin to keep around the cropped cat


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "_assets/cat-source.png"
    dst = sys.argv[2] if len(sys.argv) > 2 else "Resources/cat.png"

    img = Image.open(src).convert("RGBA")
    w, h = img.size

    # Flood-fill from each corner. ImageDraw.floodfill walks the connected
    # region whose colour is within `thresh` of the seed and recolours it.
    # We paint it to a fully transparent sentinel, then strip that colour to
    # alpha 0 afterwards.
    SENTINEL = (255, 0, 255, 0)  # magenta, alpha 0 — won't collide with art
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
             (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    for seed in seeds:
        ImageDraw.floodfill(img, seed, SENTINEL, thresh=THRESHOLD)

    # Convert sentinel pixels to true transparency.
    px = img.load()
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if (r, g, b) == (255, 0, 255) and a == 0:
                px[x, y] = (0, 0, 0, 0)
            else:
                # track bounding box of remaining (the cat)
                if x < minx: minx = x
                if y < miny: miny = y
                if x > maxx: maxx = x
                if y > maxy: maxy = y

    # Crop to the cat plus padding.
    minx = max(0, minx - PADDING)
    miny = max(0, miny - PADDING)
    maxx = min(w, maxx + PADDING)
    maxy = min(h, maxy + PADDING)
    img = img.crop((minx, miny, maxx, maxy))

    img.save(dst)
    print(f"wrote {dst}  size={img.size}  (cropped from {w}x{h})")


if __name__ == "__main__":
    main()
