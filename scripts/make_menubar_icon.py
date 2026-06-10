#!/usr/bin/env python3
"""Draw a clean minimal cat-face menu-bar icon as a black template image.

Template images are pure black + alpha; macOS recolors them for light/dark
menu bars automatically. Output is @1x (18pt) and @2x (36px).
"""
from PIL import Image, ImageDraw

SS = 8  # supersample
W = 22 * SS
H = 18 * SS


def draw(d, s):
    cx = W / 2
    # Head: rounded blob
    hw, hh = 13.0 * s, 10.5 * s
    top = 7.0 * s
    d.ellipse([cx - hw, top, cx + hw, top + 2 * hh], fill=255)
    # Ears: two triangles
    ear_y = top + 1.0 * s
    d.polygon([(cx - hw + 1.2*s, ear_y), (cx - hw - 2.2*s, top - 7.0*s),
               (cx - 2.0*s, ear_y - 1.5*s)], fill=255)
    d.polygon([(cx + hw - 1.2*s, ear_y), (cx + hw + 2.2*s, top - 7.0*s),
               (cx + 2.0*s, ear_y - 1.5*s)], fill=255)


def whiskers(d, s):
    # subtract: tiny eyes + nose to add character (cut to transparent)
    cx = W / 2
    eye_y = 13.0 * s
    for dx in (-5.2 * s, 5.2 * s):
        d.ellipse([cx + dx - 1.1*s, eye_y - 1.4*s, cx + dx + 1.1*s, eye_y + 1.4*s], fill=0)
    # nose/mouth hint
    d.polygon([(cx - 1.6*s, 16.5*s), (cx + 1.6*s, 16.5*s), (cx, 18.2*s)], fill=0)


def main():
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    draw(d, SS)
    whiskers(d, SS)
    # to RGBA template (black + alpha)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px_a = img.load(); px_o = out.load()
    for y in range(H):
        for x in range(W):
            a = px_a[x, y]
            if a > 0:
                px_o[x, y] = (0, 0, 0, a)
    x2 = out.resize((36, 30), Image.LANCZOS)   # @2x (keep aspect 22:18→36:30)
    x1 = out.resize((18, 15), Image.LANCZOS)    # @1x
    x2.save("Resources/MenuBarCat@2x.png")
    x1.save("Resources/MenuBarCat.png")
    print("wrote Resources/MenuBarCat.png + @2x")


if __name__ == "__main__":
    main()
