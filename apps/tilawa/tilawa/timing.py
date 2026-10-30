"""توقيت المقاطع: توزيع تقريبي حسب طول النص (حتى يتوفر التعرف الصوتي)، ويعدّله المستخدم يدوياً."""
import json, re, subprocess

_MARKS = re.compile("[ؐ-ًؚ-ٰٟۖ-ࣰۭ-ࣿـ٠-٩]")


def audio_duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", path],
                         capture_output=True, text=True, check=True).stdout
    return float(json.loads(out)["format"]["duration"])


def speech_bounds(path, noise_db=-35, min_silence=0.3):
    """بداية التلاوة ونهايتها بعد تجاوز الصمت في الطرفين."""
    dur = audio_duration(path)
    log = subprocess.run(["ffmpeg", "-v", "info", "-i", path, "-af", f"silencedetect=noise={noise_db}dB:d={min_silence}",
                          "-f", "null", "-"], capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", log)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", log)]
    begin = ends[0] if starts and starts[0] < 0.05 and ends else 0.0
    # صمت في النهاية: إما لم يُغلق، أو يُغلق عند نهاية الملف تقريباً
    finish = starts[-1] if starts and (len(ends) < len(starts) or ends[-1] > dur - 0.1) else dur
    return begin, finish


def letters(text):
    return len(_MARKS.sub("", text).replace(" ", ""))


def distribute(texts, begin, end, gap=0.15):
    """يوزّع المدة على المقاطع بنسبة عدد الحروف (بدون التشكيل)."""
    weights = [max(letters(t), 1) for t in texts]
    total = sum(weights)
    t, out = begin, []
    for w, text in zip(weights, texts):
        d = (end - begin) * w / total
        out.append({"text": text, "start": round(t, 2), "end": round(t + d - gap, 2)})
        t += d
    return out
