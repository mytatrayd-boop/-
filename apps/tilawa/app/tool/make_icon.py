"""أيقونة التطبيق: «تلاوة» بخط المصحف ذهبية داخل حلقة على أخضر داكن.

    python tool/make_icon.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

APP = Path(__file__).resolve().parent.parent
N = 1024
GOLD, GOLD2 = (230, 196, 112), (196, 150, 64)

img = Image.new("RGB", (N, N))
d = ImageDraw.Draw(img)
for y in range(N):  # تدرج أخضر داكن
    t = y / N
    d.line([(0, y), (N, y)], fill=(int(10 + 14 * t), int(52 + 30 * (1 - t)), int(42 + 20 * (1 - t))))
# حلقتان ذهبيتان في المنتصف (المنطقة الآمنة لأقنعة المشغّلات الدائرية)
for r, w in [(392, 10), (362, 4)]:
    d.ellipse((N / 2 - r, N / 2 - r, N / 2 + r, N / 2 + r), outline=GOLD2 if w < 10 else GOLD, width=w)
font = ImageFont.truetype(str(APP / "assets" / "hafs.otf"), 330, layout_engine=ImageFont.Layout.RAQM)
text = "تِلَاوَة"
layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
ld = ImageDraw.Draw(layer)
ld.text((N / 2, N / 2 + 10), text, font=font, fill=GOLD, anchor="mm", direction="rtl", language="ar")
shadow = layer.split()[3].filter(ImageFilter.GaussianBlur(10)).point(lambda v: int(v * 0.6))
img.paste((0, 0, 0), (6, 10), shadow)
img.paste(layer, (0, 0), layer)
img.save(APP / "tool" / "icon_1024.png")
for folder, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    img.resize((size, size), Image.LANCZOS).save(APP / "android/app/src/main/res" / f"mipmap-{folder}" / "ic_launcher.png")
print("icon ok")
