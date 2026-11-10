"""أيقونة التطبيق: تُولَّد أحجام أندرويد من الأصل tool/icon_1024.png.

الأصل (مصحف مفتوح، موجة صوتية متذبذبة، وميكروفون ذهبي على كحلي ليلي) مرسوم بنصوص تصميم منفصلة
وليس بخط المجمع؛ لتغيير الأيقونة استبدل tool/icon_1024.png ثم شغّل:

    python tool/make_icon.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

APP = Path(__file__).resolve().parent.parent
img = Image.open(APP / "tool" / "icon_1024.png").convert("RGB")
RADIUS = 0.225  # نسبة استدارة الحواف إلى الضلع (مربع مدوّر بشفافية في الزوايا)


def rounded(im, size):
    """تصغير بنعومة ثم قناع حواف مدوّرة مرسوم بضعف الدقة (حواف ناعمة بلا تسنّن)."""
    big = 4 * size
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=int(big * RADIUS), fill=255)
    out = im.resize((size, size), Image.LANCZOS).convert("RGBA")
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


for folder, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    rounded(img, size).save(APP / "android/app/src/main/res" / f"mipmap-{folder}" / "ic_launcher.png")
print("icon ok")
