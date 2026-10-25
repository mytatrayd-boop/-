"""يرسم أيقونة BrewLens حسب DESIGN.md §5 ويكتبها لأندرويد وiOS.

التشغيل من apps/brewlens: python3 tool/generate_icon.py (يحتاج Pillow).
"""
import json
import os

from PIL import Image, ImageDraw

CREAM = (0xF5, 0xEB, 0xDD, 255)
DARK = (0x4A, 0x32, 0x26, 255)
BROWN = (0x6F, 0x4E, 0x37, 255)
CARAMEL = (0xB8, 0x76, 0x28, 255)
SS = 4  # تنعيم الحواف بالرسم بدقة أعلى ثم التصغير


def draw_layers(size, scale, with_bg):
    n = size * SS
    img = Image.new("RGBA", (n, n), CREAM if with_bg else (0, 0, 0, 0))
    over = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    k = SS * size / 1024.0

    def p(v, center=512):
        return (center + (v - center) * scale) * k

    def circle(cx, cy, r, **kw):
        d.ellipse([p(cx) - r * scale * k, p(cy) - r * scale * k,
                   p(cx) + r * scale * k, p(cy) + r * scale * k], **kw)

    circle(512, 512, 380, fill=DARK)
    circle(512, 512, 330, fill=BROWN)
    r = 290 * scale * k
    w = int(22 * scale * k)
    d.arc([p(512) - r, p(512) - r, p(512) + r, p(512) + r], 200, 250,
          fill=(255, 255, 255, 89), width=w)
    steam = (0xF5, 0xEB, 0xDD, 204)
    for x0, y0, x1, y1 in ((452, 296, 478, 372), (532, 276, 558, 352)):
        d.rounded_rectangle([p(x0), p(y0), p(x1), p(y1)], radius=13 * scale * k, fill=steam)
    hr = 52 * scale * k
    d.ellipse([p(628) - hr, p(486) - hr, p(628) + hr, p(486) + hr],
              outline=CREAM, width=int(28 * scale * k))
    d.rounded_rectangle([p(362), p(400), p(622), p(620)], radius=90 * scale * k,
                        fill=CREAM, corners=(False, False, True, True))
    d.ellipse([p(492 - 116), p(404 - 22), p(492 + 116), p(404 + 22)], fill=CARAMEL)
    d.rounded_rectangle([p(322), p(640), p(662), p(676)], radius=18 * scale * k, fill=CREAM)
    img = Image.alpha_composite(img, over)
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs("assets/icon", exist_ok=True)
    icon = draw_layers(1024, 1.0, True)
    icon.save("assets/icon/icon.png")
    fg = draw_layers(1024, 0.66, False)
    fg.save("assets/icon/icon_fg.png")
    draw_layers(512, 1.0, False).save("assets/icon/logo.png")

    res = "android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, f in densities.items():
        folder = f"{res}/mipmap-{name}"
        os.makedirs(folder, exist_ok=True)
        icon.resize((int(48 * f),) * 2, Image.LANCZOS).convert("RGB").save(f"{folder}/ic_launcher.png")
        fg.resize((int(108 * f),) * 2, Image.LANCZOS).save(f"{folder}/ic_launcher_foreground.png")
    os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
    with open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w") as fh:
        fh.write('<?xml version="1.0" encoding="utf-8"?>\n'
                 '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                 '    <background android:drawable="@color/ic_launcher_background"/>\n'
                 '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                 '</adaptive-icon>\n')
    os.makedirs(f"{res}/values", exist_ok=True)
    with open(f"{res}/values/ic_launcher_background.xml", "w") as fh:
        fh.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                 '    <color name="ic_launcher_background">#F5EBDD</color>\n</resources>\n')

    ios = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    with open(f"{ios}/Contents.json") as fh:
        contents = json.load(fh)
    rgb = icon.convert("RGB")
    for entry in contents["images"]:
        if "filename" not in entry:
            continue
        pts = float(entry["size"].split("x")[0])
        mult = float(entry["scale"].rstrip("x"))
        px = int(round(pts * mult))
        rgb.resize((px, px), Image.LANCZOS).save(f"{ios}/{entry['filename']}")


if __name__ == "__main__":
    main()
