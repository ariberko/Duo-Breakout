"""Draws the Duo Breakout app icon (1024x1024, no transparency).

Neon bricks across the middle (where the iPhone Duo folds), a cyan paddle
at the bottom, a pink paddle at the top and a glowing ball.
Run: python3 scripts/make_icon.py
"""
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 4096  # draw big, then shrink for smooth edges
OUT = sys.argv[1] if len(sys.argv) > 1 else "AppAssets/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
CYAN = (51, 230, 255)
PINK = (255, 77, 191)
ROWS = [(255, 77, 115), (255, 140, 51), (255, 217, 64), (89, 242, 115), (64, 204, 255)]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
for y in range(S):
    d.line([(0, y), (S, y)], fill=lerp((10, 8, 31), (26, 5, 46), y / (S - 1)))

glow = Image.new("RGB", (S, S))
g = ImageDraw.Draw(glow)
shapes = Image.new("RGB", (S, S))
sh = ImageDraw.Draw(shapes)


def both(draw_fn):
    draw_fn(g)
    draw_fn(sh)


# Bricks: 5 rows x 6 columns in the middle.
cols, rows = 6, 5
margin, gap = 420, 70
bw = (S - 2 * margin - gap * (cols - 1)) / cols
bh = 190
top = S / 2 - (rows * (bh + gap) - gap) / 2
for r in range(rows):
    for c in range(cols):
        if (r, c) in [(0, 0), (4, 5), (2, 2)]:
            continue  # a few already broken
        x = margin + c * (bw + gap)
        y = top + r * (bh + gap)
        both(lambda dr: dr.rounded_rectangle([x, y, x + bw, y + bh], radius=40, fill=ROWS[r]))

# Paddles.
pw, ph = 1100, 150
both(lambda dr: dr.rounded_rectangle([S / 2 - pw / 2 - 300, S - 620, S / 2 + pw / 2 - 300, S - 620 + ph], radius=ph / 2, fill=CYAN))
both(lambda dr: dr.rounded_rectangle([S / 2 - pw / 2 + 350, 470, S / 2 + pw / 2 + 350, 470 + ph], radius=ph / 2, fill=PINK))

# Ball.
bx, by, br = S / 2 + 420, S - 1150, 130
both(lambda dr: dr.ellipse([bx - br, by - br, bx + br, by + br], fill=(255, 255, 255)))

glow = glow.filter(ImageFilter.GaussianBlur(90))
img = ImageChops.add(img, glow.point(lambda v: int(v * 0.8)))
mask = shapes.convert("L").point(lambda v: 255 if v > 8 else 0)
img.paste(shapes, (0, 0), mask)

img.resize((1024, 1024), Image.LANCZOS).save(OUT)
print("saved", OUT)
