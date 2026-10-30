"""خلفيات جاهزة تولّدها الأداة (بدون صور خارجية أو حقوق)."""
import math, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

W, H = 1080, 1920
CACHE = Path(__file__).resolve().parent.parent / "assets" / "backgrounds"


def _gradient(stops):
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                u = (t - t0) / (t1 - t0)
                d.line([(0, y), (W, y)], fill=tuple(int(c0[i] + (c1[i] - c0[i]) * u) for i in range(3)))
                break
    return img, d


def _stars(d, n, seed, max_y=0.6):
    rnd = random.Random(seed)
    for _ in range(n):
        x, y, c = rnd.randrange(W), rnd.randrange(int(H * max_y)), rnd.randint(110, 235)
        r = rnd.choice((1, 1, 1, 2))
        d.ellipse((x, y, x + r, y + r), fill=(c, c, c))


def _hills(d, layers, seed):
    rnd = random.Random(seed)
    for k, (h, col) in enumerate(layers):
        pts = [(0, H)] + [(x, int(H * h - 60 * math.sin(x / 170 + k * 2) - rnd.random() * 25))
                          for x in range(0, W + 40, 40)] + [(W, H)]
        d.polygon(pts, fill=col)


def night():
    img, d = _gradient([(0, (6, 9, 22)), (0.6, (22, 26, 52)), (1, (10, 12, 26))])
    _stars(d, 220, 1, 0.75)
    return img.filter(ImageFilter.GaussianBlur(1))


def sunset():
    img, d = _gradient([(0, (8, 10, 24)), (0.6, (40, 22, 48)), (0.75, (150, 60, 40)), (1, (150, 60, 40))])
    _stars(d, 140, 7, 0.5)
    _hills(d, [(0.72, (30, 16, 30)), (0.76, (16, 10, 18)), (0.80, (6, 5, 10))], 7)
    return img.filter(ImageFilter.GaussianBlur(1.5))


def black():
    img, _ = _gradient([(0, (4, 4, 6)), (1, (14, 14, 18))])
    return img


def emerald():
    img, d = _gradient([(0, (4, 20, 18)), (0.55, (8, 48, 40)), (1, (3, 14, 12))])
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((140, 500, 940, 1300), fill=70)
    img.paste((40, 110, 90), (0, 0), glow.filter(ImageFilter.GaussianBlur(160)))
    return img


def dawn():
    img, d = _gradient([(0, (18, 26, 58)), (0.5, (70, 80, 130)), (0.78, (220, 150, 120)), (1, (60, 40, 50))])
    _hills(d, [(0.80, (40, 34, 52)), (0.86, (20, 18, 30))], 3)
    return img.filter(ImageFilter.GaussianBlur(1.5))


PRESETS = {"ليل ونجوم": night, "غروب": sunset, "فجر": dawn, "زمردي": emerald, "أسود": black}


def preset_path(name):
    CACHE.mkdir(parents=True, exist_ok=True)
    p = CACHE / f"v3_{list(PRESETS).index(name)}.png"  # يتغير الإصدار عند تعديل الرسم
    if not p.exists():
        PRESETS[name]().save(p)
    return str(p)
