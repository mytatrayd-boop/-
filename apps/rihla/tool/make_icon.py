#!/usr/bin/env python3
"""Regenerates all Rihla app icons (needs Pillow). Run from apps/rihla:
    python3 tool/make_icon.py
Concept: split screen. Left half = camera lens, right half = map path + pin.
Palette from DESIGN.md: ink 0E1316, charcoal 182026, amber F5A524, emerald 2FBF9B.
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INK, COAL, COAL2 = "#0E1316", "#182026", "#222C33"
AMBER, EMERALD, DEEP_EM, SNOW = "#F5A524", "#2FBF9B", "#124F43", "#F3F6F8"
SS = 4  # supersampling
U = 1024


def bez(p0, p1, p2, p3, n=60):
    pts = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t * t
        d = t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def glyph(gsize, mono=False):
    """Split-screen glyph on a transparent gsize x gsize canvas (units: 1000)."""
    S = SS
    k = gsize * S / 1000.0
    im = Image.new("RGBA", (gsize * S, gsize * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = lambda v: v * k
    box = (0, 0, 1000, 1000)
    r = 170
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([f(v) for v in box], radius=f(r), fill=255)
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    mono_c = (255, 255, 255, 255)
    c = (lambda col: mono_c) if mono else (lambda col: col)
    gap = 24
    # halves
    if not mono:
        ld.rectangle([0, 0, f(500 - gap / 2), f(1000)], fill=COAL2)
        ld.rectangle([f(500 + gap / 2), 0, f(1000), f(1000)], fill=DEEP_EM)
    else:
        ld.rectangle([0, 0, f(500 - gap / 2), f(1000)], fill=mono_c)
        ld.rectangle([f(500 + gap / 2), 0, f(1000), f(1000)], fill=mono_c)
    # lens (left half centered at 250,500)
    cx, cy = 250, 500
    def circ(cx, cy, rad, col):
        ld.ellipse([f(cx - rad), f(cy - rad), f(cx + rad), f(cy + rad)], fill=col)
    if mono:
        circ(cx, cy, 190, (0, 0, 0, 0))
        circ(cx, cy, 150, mono_c)
        circ(cx, cy, 90, (0, 0, 0, 0))
        circ(cx, cy, 45, mono_c)
    else:
        circ(cx, cy, 200, AMBER)
        circ(cx, cy, 150, INK)
        circ(cx, cy, 95, COAL2)
        circ(cx, cy, 48, EMERALD)
        circ(cx - 22, cy - 24, 14, SNOW)
    # path (right half): amber winding line bottom-left to top-right
    path = bez((560, 870), (560, 560), (950, 760), (860, 400))
    path += bez((860, 400), (830, 290), (700, 330), (700, 250), 30)[1:]
    pc = (0, 0, 0, 0) if mono else AMBER
    w = 46
    for (x, y) in path:
        ld.ellipse([f(x - w / 2), f(y - w / 2), f(x + w / 2), f(y + w / 2)], fill=pc if not mono else (0, 0, 0, 0))
    if mono:
        # cut-out path via transparency already; draw start dot solid
        pass
    # start dot
    sx, sy = 560, 870
    circ(sx, sy, 40, mono_c if mono else SNOW)
    # pin at path end (700,250)
    px, py = 745, 300
    pr = 92
    tip = (px, py + 215)
    pin_col = mono_c if not mono else (0, 0, 0, 0)
    # pin body: circle + triangle
    circ(px, py, pr + (0 if mono else 0), AMBER if not mono else mono_c)
    ld.polygon([(f(px - pr * 0.86), f(py + pr * 0.5)), (f(px + pr * 0.86), f(py + pr * 0.5)), (f(tip[0]), f(tip[1]))],
               fill=AMBER if not mono else mono_c)
    circ(px, py, 38, INK if not mono else (0, 0, 0, 0))
    # center gap stays transparent in mono; ink in color
    if not mono:
        ld.rectangle([f(500 - gap / 2), 0, f(500 + gap / 2), f(1000)], fill=INK)
    im.paste(layer, (0, 0), mask)
    # clip pin/path overflow by mask (already pasted with mask)
    if mono:
        # mono: ensure cutouts: re-apply by compositing with alpha from layer
        im = Image.composite(layer, Image.new("RGBA", im.size, (0, 0, 0, 0)), mask)
    return im.resize((gsize, gsize), Image.LANCZOS)


def rounded_bg(size, radius_frac=0.2237, alpha=True):
    S = SS
    im = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, size * S - 1, size * S - 1], radius=size * S * radius_frac, fill=INK)
    return im.resize((size, size), Image.LANCZOS)


def flat_bg(size):
    im = Image.new("RGB", (size, size), INK)
    d = ImageDraw.Draw(im)
    # subtle emerald glow at bottom for depth
    return im


def compose(size, frac, rounded):
    base = rounded_bg(size) if rounded else flat_bg(size).convert("RGBA")
    g = glyph(int(size * frac))
    off = (size - g.width) // 2
    base.alpha_composite(g, (off, off))
    return base


def save(im, path, rgb=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if rgb:
        bg = Image.new("RGB", im.size, INK)
        bg.paste(im, mask=im.split()[3])
        im = bg
    im.save(path, optimize=True)


def main():
    main_icon = compose(1024, 0.62, True)
    save(main_icon, f"{ROOT}/assets/icon/icon.png")
    # flat full-bleed version for iOS (no alpha; iOS rounds it)
    ios_master = compose(1024, 0.62, False).convert("RGB")
    ios_dir = f"{ROOT}/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    import json
    with open(f"{ios_dir}/Contents.json") as fh:
        contents = json.load(fh)
    for it in contents["images"]:
        sz = float(it["size"].split("x")[0])
        sc = int(it["scale"][0])
        px = round(sz * sc)
        ios_master.resize((px, px), Image.LANCZOS).save(f"{ios_dir}/{it['filename']}", optimize=True)
    # android
    res = f"{ROOT}/android/app/src/main/res"
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for dens, px in legacy.items():
        compose(1024, 0.62, True).resize((px, px), Image.LANCZOS).save(f"{res}/mipmap-{dens}/ic_launcher.png", optimize=True)
        fg = px * 108 // 48
        # adaptive: glyph box 0.46 of 108dp layer (safe zone is 66/108 = 0.61 circle; box diagonal fits)
        for name, mono in (("ic_launcher_foreground", False), ("ic_launcher_monochrome", True)):
            canvas = Image.new("RGBA", (fg, fg), (0, 0, 0, 0))
            g = glyph(int(fg * 0.50), mono)
            o = (fg - g.width) // 2
            canvas.alpha_composite(g, (o, o))
            canvas.save(f"{res}/mipmap-{dens}/{name}.png", optimize=True)
    os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
    with open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w") as fh:
        fh.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
''')
    with open(f"{res}/values/ic_launcher_background.xml", "w") as fh:
        fh.write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0E1316</color>
</resources>
''')
    # preview: main + 48px side by side
    pv = Image.new("RGB", (1024 + 80 + 48 + 80, 1024), "#2A3238")
    pv.paste(main_icon, (0, 0), main_icon)
    small = main_icon.resize((48, 48), Image.LANCZOS)
    pv.paste(small, (1024 + 80, 488), small)
    pv.save(f"{ROOT}/assets/icon/preview.png", optimize=True)


if __name__ == "__main__":
    main()
