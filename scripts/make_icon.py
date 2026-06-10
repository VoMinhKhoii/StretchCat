#!/usr/bin/env python3
"""Compose a macOS app icon from the cat on a soft cream rounded square."""
from PIL import Image, ImageDraw, ImageFilter

S = 1024
R = 230  # corner radius (squircle-ish)

def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size, size], radius=radius, fill=255)
    return m

def main():
    # Warm cream vertical gradient background.
    bg = Image.new("RGB", (S, S), (255, 247, 235))
    top, bot = (255, 250, 242), (252, 232, 210)
    for y in range(S):
        t = y / S
        bg.putpixel  # noqa
    px = bg.load()
    for y in range(S):
        t = y / S
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(S):
            px[x, y] = c
    bg = bg.convert("RGBA")

    cat = Image.open("Resources/cat.png").convert("RGBA")
    # Scale cat to ~74% of icon height.
    target_h = int(S * 0.74)
    scale = target_h / cat.height
    cat = cat.resize((int(cat.width * scale), target_h), Image.LANCZOS)

    # Soft contact shadow.
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sx = (S - cat.width) // 2
    sy = (S - cat.height) // 2 + int(S * 0.04)
    shadow.paste((0, 0, 0, 90), (sx, sy), cat)
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    bg.alpha_composite(shadow)

    bg.alpha_composite(cat, (sx, sy - int(S * 0.04)))

    # Round the corners.
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(bg, (0, 0), rounded_mask(S, R))
    out.save("Resources/AppIcon_1024.png")
    print("wrote Resources/AppIcon_1024.png")

if __name__ == "__main__":
    main()
