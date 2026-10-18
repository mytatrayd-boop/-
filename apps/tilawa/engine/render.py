"""محرك الرسم: (خلفية + صوت + مقاطع نصية بتوقيتاتها) → فيديو رأسي 1080x1920.

الترويسة (اسم السورة + البسملة) طبقة ثابتة طوال المقطع، والآيات تظهر وتختفي فوقها.

    python render.py --bg خلفية.jpg|mp4 --audio تلاوة.mp3 --segments segs.json --font خط.otf --out out.mp4 \
        [--header "سُورَةُ المعارج" --basmala "بِسْمِ..."] [--style style.json]

segs.json: [{"start": 0.0, "end": 4.2, "text": "..."}, ...] بالثواني.
"""
import argparse, json, os, subprocess, tempfile
from dataclasses import dataclass, asdict, fields
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1080, 1920
FPS = 30
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp"}


@dataclass
class Style:
    # الآيات
    font_size: int = 60
    text_y: float = 0.40          # مركز النص عمودياً: 0 أعلى الشاشة، 1 أسفلها
    align: str = "center"         # center / right / left
    width: float = 0.85           # أقصى عرض للسطر من عرض الشاشة
    line_gap: float = 1.9
    color: str = "#FFFFFF"
    shadow: float = 0.85          # قوة الظل 0..1
    fade: float = 0.35            # مدة الظهور/الاختفاء بالثواني
    # الترويسة الثابتة
    header_size: int = 46
    header_y: float = 0.09
    header_color: str = "#EBEBEB"
    # الخلفية
    dim: float = 0.25             # تعتيم الخلفية 0..0.8
    zoom: bool = True             # تقريب بطيء للصور

    @classmethod
    def from_dict(cls, d):
        names = {f.name for f in fields(cls)}
        return cls(**{k: v for k, v in (d or {}).items() if k in names})


def _font(path, size):
    return ImageFont.truetype(path, size, layout_engine=ImageFont.Layout.RAQM)


def _tl(d, s, font):
    return d.textlength(s, font=font, direction="rtl", language="ar")


def _tokens(text):
    """كلمات النص، ورقم الآية ملتصق بالكلمة قبله فلا ينزل وحده إلى سطر جديد."""
    out = []
    for word in text.split():
        if out and word.isdigit():
            out[-1] += f" {word}"
        else:
            out.append(word)
    return out


def _wrap(d, text, font, max_w):
    """أقل عدد من الأسطر، موزّعة بأطوال متقاربة (لا يبقى سطر أخير بكلمة واحدة)."""
    words = _tokens(text)
    if not words:
        return []
    width = lambda i, j: _tl(d, " ".join(words[i:j]), font)
    count, cur = 1, ""
    for w in words:  # العدد الأدنى من الأسطر بالتعبئة المتتالية
        trial = f"{cur} {w}".strip()
        if cur and _tl(d, trial, font) > max_w:
            count, cur = count + 1, w
        else:
            cur = trial
    # تقسيم إلى count سطراً يجعل أطول سطر أقصر ما يمكن
    n = len(words)
    best = {(0, 0): (0.0, None)}
    for k in range(1, count + 1):
        for j in range(k, n + 1):
            options = [(max(best[(k - 1, i)][0], width(i, j)), i) for i in range(k - 1, j) if (k - 1, i) in best]
            if options:
                best[(k, j)] = min(options)
    lines, j = [], n
    for k in range(count, 0, -1):
        i = best[(k, j)][1]
        lines.insert(0, " ".join(words[i:j]))
        j = i
    return lines


def _x(d, line, font, align, max_w):
    tw = _tl(d, line, font)
    margin = (W - max_w) / 2
    return {"right": W - margin - tw, "left": margin}.get(align, (W - tw) / 2)


def _with_shadow(layer, strength):
    if strength <= 0:
        return layer
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.putalpha(layer.getchannel("A").filter(ImageFilter.GaussianBlur(8)).point(lambda v: int(v * strength)))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(shadow, (3, 4))
    out.alpha_composite(layer)
    return out


def text_layer(text, font_path, st: Style):
    """طبقة شفافة لمقطع آية."""
    font = _font(font_path, st.font_size)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    max_w = W * st.width
    lines = _wrap(d, text, font, max_w)
    step = int(st.font_size * st.line_gap)
    y = int(H * st.text_y - step * len(lines) / 2)
    for ln in lines:
        d.text((_x(d, ln, font, st.align, max_w), y), ln, font=font, fill=st.color, direction="rtl", language="ar")
        y += step
    return _with_shadow(layer, st.shadow)


def header_layer(lines, font_path, st: Style):
    """طبقة الترويسة الثابتة (اسم السورة، البسملة). lines: قائمة أسطر، الفارغ يُتجاهل."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lines = [l for l in lines if l]
    if not lines:
        return layer
    font = _font(font_path, st.header_size)
    d = ImageDraw.Draw(layer)
    y = int(H * st.header_y)
    for ln in lines:
        d.text(((W - _tl(d, ln, font)) / 2, y), ln, font=font, fill=st.header_color, direction="rtl", language="ar")
        y += int(st.header_size * 1.8)
    return _with_shadow(layer, st.shadow)


def _bg_frame(bg, t=0.0):
    """إطار من الخلفية مقصوص إلى 9:16 (للمعاينة)."""
    if os.path.splitext(bg)[1].lower() in IMAGE_EXT:
        im = Image.open(bg).convert("RGB")
    else:
        tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False).name
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", f"{t:.2f}", "-i", bg, "-frames:v", "1", tmp], check=True)
        im = Image.open(tmp).convert("RGB")
    s = max(W / im.width, H / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)))
    l, t_ = (im.width - W) // 2, (im.height - H) // 2
    return im.crop((l, t_, l + W, t_ + H))


def preview(bg, text, header_lines, font_path, st: Style):
    """صورة معاينة واحدة بنفس إعدادات الفيديو."""
    im = _bg_frame(bg).convert("RGBA")
    im.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, int(255 * st.dim))))
    im.alpha_composite(header_layer(header_lines, font_path, st))
    if text:
        im.alpha_composite(text_layer(text, font_path, st))
    return im.convert("RGB")


def _bg_input(bg, duration, st: Style):
    """مدخلات ffmpeg ومرشح الخلفية: قص إلى 9:16 + تعتيم + تقريب بطيء للصور + تكرار للفيديو."""
    dim = f"drawbox=c=black@{st.dim:.2f}:t=fill" if st.dim > 0 else "null"
    if os.path.splitext(bg)[1].lower() in IMAGE_EXT:
        args = ["-loop", "1", "-framerate", str(FPS), "-t", f"{duration:.3f}", "-i", bg]
        if st.zoom:
            frames = int(duration * FPS) + 1
            flt = (f"scale={W*2}:{H*2}:force_original_aspect_ratio=increase,crop={W*2}:{H*2},"
                   f"zoompan=z='1+0.08*on/{frames}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
                   f":d=1:s={W}x{H}:fps={FPS},{dim}")
        else:
            flt = f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},{dim}"
    else:
        args = ["-stream_loop", "-1", "-t", f"{duration:.3f}", "-i", bg]
        flt = f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},fps={FPS},{dim}"
    return args, flt


def render(bg, audio, segments, font, out, st: Style = None, header_lines=(), audio_start=0.0, tail=0.8):
    st = st or Style()
    duration = max(s["end"] for s in segments) + tail
    tmp = tempfile.mkdtemp(prefix="tilawa_")
    bg_args, bg_flt = _bg_input(bg, duration, st)
    head_png = os.path.join(tmp, "header.png")
    header_layer(header_lines, font, st).save(head_png)
    cmd = ["ffmpeg", "-y", "-v", "error", *bg_args, "-ss", f"{audio_start:.3f}", "-i", audio,
           "-loop", "1", "-framerate", str(FPS), "-t", f"{duration:.3f}", "-i", head_png]
    chain = [f"[0:v]{bg_flt},format=yuv420p[bg]", "[bg][2:v]overlay=0:0[v0]"]
    for i, seg in enumerate(segments):
        png = os.path.join(tmp, f"seg_{i:03d}.png")
        text_layer(seg["text"], font, st).save(png)
        dur = seg["end"] - seg["start"]
        fade = min(st.fade, dur / 3)
        cmd += ["-loop", "1", "-framerate", str(FPS), "-t", f"{dur:.3f}", "-i", png]
        chain.append(
            f"[{i + 3}:v]format=rgba,fade=in:st=0:d={fade:.3f}:alpha=1,"
            f"fade=out:st={max(dur - fade, 0):.3f}:d={fade:.3f}:alpha=1,"
            f"setpts=PTS+{seg['start']:.3f}/TB[t{i}]")
        chain.append(f"[v{i}][t{i}]overlay=0:0:eof_action=pass[v{i + 1}]")
    cmd += ["-filter_complex", ";".join(chain), "-map", f"[v{len(segments)}]", "-map", "1:a",
            "-t", f"{duration:.3f}", "-c:v", "libx264", "-preset", "medium", "-crf", "20",
            "-pix_fmt", "yuv420p", "-r", str(FPS), "-c:a", "aac", "-b:a", "160k",
            "-movflags", "+faststart", out]
    subprocess.run(cmd, check=True)
    return out


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--bg", required=True)
    p.add_argument("--audio", required=True)
    p.add_argument("--segments", required=True)
    p.add_argument("--font", required=True)
    p.add_argument("--out", default="out.mp4")
    p.add_argument("--header", default="", help="اسم السورة")
    p.add_argument("--basmala", default="")
    p.add_argument("--style", help="ملف JSON بإعدادات Style")
    p.add_argument("--audio-start", type=float, default=0.0, help="بداية القص من الصوت بالثواني")
    a = p.parse_args()
    style = Style.from_dict(json.load(open(a.style, encoding="utf-8")) if a.style else None)
    render(a.bg, a.audio, json.load(open(a.segments, encoding="utf-8")), a.font, a.out, style,
           [a.header, a.basmala], a.audio_start)
