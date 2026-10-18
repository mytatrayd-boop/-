"""محرك الرسم: يحوّل (خلفية + صوت + مقاطع نصية بتوقيتاتها) إلى فيديو رأسي 1080x1920.

الاستخدام:
    python render.py --bg خلفية.jpg|mp4 --audio تلاوة.mp3 --segments segs.json --font خط.otf --out out.mp4

segs.json: [{"start": 0.0, "end": 4.2, "text": "..."}, ...] بالثواني.
"""
import argparse, json, os, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1080, 1920
FPS = 30


def wrap(draw, text, font, max_w):
    lines, cur = [], ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        if cur and draw.textlength(trial, font=font, direction="rtl", language="ar") > max_w:
            lines.append(cur)
            cur = word
        else:
            cur = trial
    return lines + [cur] if cur else lines


def text_layer(text, font_path, size=64, center_y=0.46, max_w=W - 160, line_gap=1.9, header=None):
    """صورة شفافة بالنص في المنتصف مع ظل ناعم، مثل المقطع المرجعي. header: سطر أعلى الشاشة (اسم السورة)."""
    font = ImageFont.truetype(font_path, size, layout_engine=ImageFont.Layout.RAQM)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if header:
        hfont = ImageFont.truetype(font_path, int(size * 0.8), layout_engine=ImageFont.Layout.RAQM)
        for k, ln in enumerate(header.split("\n")):
            tw = d.textlength(ln, font=hfont, direction="rtl", language="ar")
            d.text(((W - tw) / 2, int(H * 0.09) + k * int(size * 1.7)), ln, font=hfont,
                   fill=(235, 235, 235), direction="rtl", language="ar")
    lines = wrap(d, text, font, max_w)
    step = int(size * line_gap)
    y = int(H * center_y - step * len(lines) / 2)
    for ln in lines:
        tw = d.textlength(ln, font=font, direction="rtl", language="ar")
        d.text(((W - tw) / 2, y), ln, font=font, fill="white", direction="rtl", language="ar")
        y += step
    alpha = layer.getchannel("A")
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.putalpha(alpha.filter(ImageFilter.GaussianBlur(8)).point(lambda v: int(v * 0.85)))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(shadow, (3, 4))
    out.alpha_composite(layer)
    return out


def background_input(bg, duration):
    """مدخلات ffmpeg ومرشح الخلفية: قص إلى 9:16 + تعتيم + تقريب بطيء للصور + تكرار للفيديو."""
    is_image = os.path.splitext(bg)[1].lower() in {".jpg", ".jpeg", ".png", ".webp"}
    cover = f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H}"
    dim = "eq=brightness=-0.12:saturation=0.9"
    if is_image:
        frames = int(duration * FPS) + 1
        args = ["-loop", "1", "-framerate", str(FPS), "-t", f"{duration:.3f}", "-i", bg]
        # تقريب بطيء من 100% إلى 108% طوال المقطع
        flt = (f"scale={W*2}:{H*2}:force_original_aspect_ratio=increase,crop={W*2}:{H*2},"
               f"zoompan=z='1+0.08*on/{frames}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
               f":d=1:s={W}x{H}:fps={FPS},{dim}")
    else:
        args = ["-stream_loop", "-1", "-t", f"{duration:.3f}", "-i", bg]
        flt = f"{cover},fps={FPS},{dim}"
    return args, flt


def render(bg, audio, segments, font, out, fade=0.35, size=64, center_y=0.46, header=None, audio_start=0.0):
    duration = max(s["end"] for s in segments) + 0.6
    tmp = tempfile.mkdtemp(prefix="tilawa_")
    bg_args, bg_flt = background_input(bg, duration)
    cmd = ["ffmpeg", "-y", "-v", "error", *bg_args, "-ss", f"{audio_start:.3f}", "-i", audio]
    chain = [f"[0:v]{bg_flt},format=yuv420p[v0]"]
    for i, seg in enumerate(segments):
        png = os.path.join(tmp, f"seg_{i:03d}.png")
        text_layer(seg["text"], font, size=size, center_y=center_y, header=header).save(png)
        dur = seg["end"] - seg["start"]
        cmd += ["-loop", "1", "-framerate", str(FPS), "-t", f"{dur:.3f}", "-i", png]
        idx = i + 2
        chain.append(
            f"[{idx}:v]format=rgba,fade=in:st=0:d={fade}:alpha=1,"
            f"fade=out:st={max(dur - fade, 0):.3f}:d={fade}:alpha=1,"
            f"setpts=PTS+{seg['start']:.3f}/TB[t{i}]")
        chain.append(f"[v{i}][t{i}]overlay=0:0:eof_action=pass[v{i+1}]")
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
    p.add_argument("--size", type=int, default=64)
    p.add_argument("--center-y", type=float, default=0.46, help="موضع النص عمودياً (0 أعلى، 1 أسفل)")
    p.add_argument("--header", help="سطر أعلى الشاشة، مثل اسم السورة (\\n لسطر جديد)")
    p.add_argument("--audio-start", type=float, default=0.0, help="بداية القص من الصوت بالثواني")
    a = p.parse_args()
    render(a.bg, a.audio, json.load(open(a.segments, encoding="utf-8")), a.font, a.out, size=a.size,
           center_y=a.center_y, header=a.header and a.header.replace("\\n", "\n"), audio_start=a.audio_start)
