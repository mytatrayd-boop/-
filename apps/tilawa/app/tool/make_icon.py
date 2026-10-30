"""أيقونة التطبيق: مصحف مفتوح ذهبي تحته هلال ونجمة على أخضر زمردي، بلا اعتماد على خط.

    python tool/make_icon.py
"""
import math
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

APP = Path(__file__).resolve().parent.parent
N, S = 1024, 2048  # الناتج، والرسم بضعف الدقة للنعومة
GOLD, GOLD2, DEEP = (244, 214, 128), (200, 152, 62), (7, 38, 32)

# خلفية: تدرج شعاعي زمردي
bg = Image.new("RGB", (S, S))
px = bg.load()
cx, cy = S / 2, S * 0.42
for y in range(S):
    for x in range(S):
        t = min(math.hypot(x - cx, y - cy) / (S * 0.78), 1)
        px[x, y] = (int(8 + 12 * (1 - t)), int(40 + 58 * (1 - t) ** 1.3), int(34 + 40 * (1 - t) ** 1.3))
bg = bg.convert("RGBA")


def layer():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def gold_fill(mask, top=GOLD, bottom=GOLD2):
    g = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(g)
    for y in range(S):
        t = y / S
        gd.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    out = layer()
    out.paste(g, (0, 0), mask)
    return out


def bezier(p0, p1, p2, p3, n=60):
    return [((1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t * t * p2[0] + t ** 3 * p3[0],
             (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t * t * p2[1] + t ** 3 * p3[1])
            for t in (i / n for i in range(n + 1))]


# مصحف مفتوح: صفحتان منحنيتان وكعب في المنتصف
mid, top, bot = S / 2, S * 0.50, S * 0.80
left = bezier((mid, top), (mid - 170, top - 90), (mid - 470, top - 70), (mid - 600, top - 10)) \
    + [(mid - 600, bot - 40)] + bezier((mid - 600, bot - 40), (mid - 470, bot - 110), (mid - 170, bot - 130), (mid, bot))
right = [(2 * mid - x, y) for x, y in left]
pages = Image.new("L", (S, S), 0)
ImageDraw.Draw(pages).polygon(left, fill=255)
ImageDraw.Draw(pages).polygon(right, fill=255)

shadow = pages.filter(ImageFilter.GaussianBlur(26)).point(lambda v: int(v * 0.55))
bg.paste(Image.new("RGBA", (S, S), (0, 0, 0, 255)), (0, 36), shadow)
book = gold_fill(pages)
# خطوط الأسطر على الصفحتين (تبدو كنص)
lines = ImageDraw.Draw(book)
for side in (-1, 1):
    for k in range(5):
        y = top + 60 + k * 62
        x0, x1 = mid + side * 70, mid + side * (470 - k * 8)
        lines.line([(x0, y + side * 0), (x1, y - 38 + k * 4)], fill=DEEP + (170,), width=14)
lines.line([(mid, top - 4), (mid, bot + 4)], fill=DEEP + (230,), width=10)  # الكعب
bg.alpha_composite(book)

# هلال فوق المصحف
r = 215
moon = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(moon)
mcx, mcy = mid, S * 0.285
md.ellipse((mcx - r, mcy - r, mcx + r, mcy + r), fill=255)
md.ellipse((mcx - r + 105, mcy - r - 30, mcx + r + 105 - 20, mcy + r - 30), fill=0)
moon = moon.rotate(18, center=(mcx, mcy))
glow = moon.filter(ImageFilter.GaussianBlur(40))
bg.alpha_composite(Image.merge("RGBA", (*[Image.new("L", (S, S), c) for c in GOLD], glow.point(lambda v: int(v * 0.6)))))
bg.alpha_composite(gold_fill(moon, GOLD, GOLD2))

# نجمة ثمانية صغيرة
sx, sy, R, r2 = mid + 250, S * 0.235, 70, 30
pts = [(sx + (R if i % 2 == 0 else r2) * math.sin(i * math.pi / 8), sy - (R if i % 2 == 0 else r2) * math.cos(i * math.pi / 8)) for i in range(16)]
star = Image.new("L", (S, S), 0)
ImageDraw.Draw(star).polygon(pts, fill=255)
bg.alpha_composite(gold_fill(star, GOLD, GOLD))

# إطار ذهبي رفيع داخل المنطقة الآمنة
ring = layer()
rd = ImageDraw.Draw(ring)
rd.ellipse((S / 2 - 900, S / 2 - 900, S / 2 + 900, S / 2 + 900), outline=GOLD2 + (200,), width=10)
bg.alpha_composite(ring)

img = bg.convert("RGB").resize((N, N), Image.LANCZOS)
img.save(APP / "tool" / "icon_1024.png")
for folder, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    img.resize((size, size), Image.LANCZOS).save(APP / "android/app/src/main/res" / f"mipmap-{folder}" / "ic_launcher.png")
print("icon ok")
