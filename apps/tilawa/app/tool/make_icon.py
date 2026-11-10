"""أيقونة التطبيق: تُولَّد أحجام أندرويد من الأصل tool/icon_1024.png.

الأصل (مصحف مفتوح، موجة صوتية متذبذبة، وميكروفون ذهبي على كحلي ليلي) مرسوم بنصوص تصميم منفصلة
وليس بخط المجمع؛ لتغيير الأيقونة استبدل tool/icon_1024.png ثم شغّل:

    python tool/make_icon.py
"""
from pathlib import Path
from PIL import Image

APP = Path(__file__).resolve().parent.parent
img = Image.open(APP / "tool" / "icon_1024.png").convert("RGB")
for folder, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    img.resize((size, size), Image.LANCZOS).save(APP / "android/app/src/main/res" / f"mipmap-{folder}" / "ic_launcher.png")
print("icon ok")
