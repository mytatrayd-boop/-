"""المزامنة الآلية: تعرّف على الآيات من التلاوة ووقّت كل مقطع.

المسار: Whisper المدرّب على القرآن يعطي كلمات بتوقيتها (نص تقريبي) ← نحدد موضعها في المصحف ←
نحاذي كلمات التعرف مع كلمات المصحف (مع السماح بالتكرار) ← نبني المقاطع بنص المصحف لا بنص التعرف.
"""
import re, subprocess
from difflib import SequenceMatcher
from functools import lru_cache

import numpy as np

from . import quran

MODEL = "tarteel-ai/whisper-base-ar-quran"
# النموذج المدرّب مشتق من whisper-base ولا يحمل إعدادات التوقيت؛ نأخذها من الأصل
BASE = "openai/whisper-base"
SR = 16000

_MARKS = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭ࣓-ࣿـ]")
_FOLD = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي", "ة": "ه", "ؤ": "و", "ئ": "ي"})


def norm(word):
    """هيكل الكلمة للمطابقة: بلا تشكيل، والألفات والهمزات موحّدة، والألف محذوفة
    (الرسم العثماني يحذف ألفات كثيرة يكتبها التعرف الصوتي)."""
    w = _MARKS.sub("", word).translate(_FOLD)
    return re.sub("[^ء-ي]", "", w).replace("ا", "").replace("ء", "")


def load_audio(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).copy()


@lru_cache
def _asr():
    from transformers import GenerationConfig, pipeline
    asr = pipeline("automatic-speech-recognition", model=MODEL, device="cpu")
    asr.model.generation_config = GenerationConfig.from_pretrained(BASE)
    return asr


def silences(audio, frame=0.02, rel_db=-32, min_len=0.25):
    """فترات الصمت [(بداية، نهاية)] بالطاقة: أهدأ من ذروة التلاوة بـ 32 ديسيبل لربع ثانية فأكثر."""
    n = int(SR * frame)
    frames = audio[:len(audio) // n * n].reshape(-1, n)
    db = 10 * np.log10((frames ** 2).mean(axis=1) + 1e-10)
    quiet = db < np.percentile(db, 95) + rel_db
    out, start = [], None
    for k, q in enumerate(np.append(quiet, False)):
        if q and start is None:
            start = k
        elif not q and start is not None:
            if (k - start) * frame >= min_len:
                out.append((start * frame, k * frame))
            start = None
    return out


def chunks(audio, quiet, max_len=25.0):
    """تقطيع عند الوقفات إلى قطع لا تتجاوز 25 ث (حدّ Whisper 30 ث). القطع المستقلة تحفظ التكرار
    الذي يحذفه دمج القطع المتداخلة."""
    total = len(audio) / SR
    cuts, begin = [0.0], 0.0
    while total - begin > max_len:
        mids = [(a + b) / 2 for a, b in quiet if begin + 3 < (a + b) / 2 <= begin + max_len]
        begin = mids[-1] if mids else begin + max_len
        cuts.append(begin)
    return list(zip(cuts, cuts[1:] + [total]))


def transcribe(path):
    """[(كلمة، بداية، نهاية)] من Whisper، وبداية كل كلمة بعد الصمت الذي يسبقها."""
    audio = load_audio(path)
    quiet = silences(audio)
    words = []
    for b, e in chunks(audio, quiet):
        out = _asr()(audio[int(b * SR):int(e * SR)], return_timestamps="word",
                     generate_kwargs={"language": "ar", "task": "transcribe"})
        for ch in out["chunks"]:
            wb, we = ch["timestamp"]
            we = we if we is not None else wb + 0.4
            for w in ch["text"].split():
                words.append((w, b + float(wb), b + float(we)))
    # Whisper يضم الوقفة إلى الكلمة التالية؛ نزيحها إلى نهاية الصمت
    fixed = []
    for w, wb, we in words:
        for a, z in quiet:
            if wb < z < we:
                wb = z
        fixed.append((w, wb, we))
    return fixed


@lru_cache
def _quran_words():
    """كل كلمات المصحف بالترتيب: [(سورة، آية، الكلمة)] وهياكلها."""
    words = []
    for s, _, n in quran.surahs():
        for a, text in quran.ayat(s, 1, n):
            words += [(s, a, w) for w in text.split()]
    return words, [norm(w) for _, _, w in words]


def locate(asr_norm):
    """أين في المصحف هذه الكلمات؟ تصويت بالكلمات الثنائية على الإزاحة (موضع المصحف - موضع التعرف)."""
    words, qn = _quran_words()
    index = {}
    for j in range(len(qn) - 1):
        index.setdefault((qn[j], qn[j + 1]), []).append(j)
    votes = {}
    for i in range(len(asr_norm) - 1):
        hits = index.get((asr_norm[i], asr_norm[i + 1]), [])
        if 0 < len(hits) <= 50:  # الكلمات الثنائية الشائعة جداً لا تدل على موضع
            for j in hits:
                votes.setdefault(j - i, []).append(j)
    if not votes:
        return None
    # الإزاحات القريبة من بعضها (التكرار والحذف يحرّكانها قليلاً) تُجمع
    best = max(votes, key=lambda d: sum(len(votes.get(d + k, [])) for k in range(-15, 16)))
    hits = sorted(j for k in range(-15, 16) for j in votes.get(best + k, []))
    lo = max(hits[0] - 3, 0)
    hi = min(hits[-1] + 4, len(words) - 1)
    # توسيع الحدود إلى بداية الآية الأولى ونهاية الأخيرة
    while lo > 0 and words[lo - 1][:2] == words[lo][:2]:
        lo -= 1
    while hi < len(words) - 1 and words[hi + 1][:2] == words[hi][:2]:
        hi += 1
    return lo, hi


def _sim(a, b):
    if not a or not b:
        return 0.0
    return 1.0 if a == b else SequenceMatcher(None, a, b).ratio()


def align(asr_norm, q_norm, jump=2.5):
    """محاذاة كلمات التعرف مع كلمات المصحف. يُسمح بالرجوع للخلف (القارئ يعيد مقطعاً).
    ترجع لكل كلمة تعرّف: رقم كلمة المصحف المطابقة أو None."""
    n, m = len(asr_norm), len(q_norm)
    NEG = -1e9
    score = np.full((n + 1, m + 1), NEG)
    back = {}  # (i, j) ← الحالة السابقة ونوع الانتقال

    def forward_skips(i):
        for j in range(1, m + 1):  # كلمة في المصحف لم يلتقطها التعرف
            if score[i, j - 1] - 0.6 > score[i, j]:
                score[i, j] = score[i, j - 1] - 0.6
                back[(i, j)] = (i, j - 1, None)

    def jumps(i):
        best, arg = NEG, None
        for j in range(m, -1, -1):  # رجوع لموضع سابق = تكرار
            if best - jump > score[i, j]:
                score[i, j] = best - jump
                back[(i, j)] = (i, arg, None)
            if score[i, j] > best:
                best, arg = score[i, j], j

    score[0, 0] = 0.0
    forward_skips(0)
    for i in range(1, n + 1):
        a = asr_norm[i - 1]
        for j in range(m + 1):
            # كلمة زائدة في التعرف (استعاذة، خطأ تعرّف)
            if score[i - 1, j] - 0.7 > score[i, j]:
                score[i, j] = score[i - 1, j] - 0.7
                back[(i, j)] = (i - 1, j, None)
            if j:
                s = score[i - 1, j - 1] + 2 * _sim(a, q_norm[j - 1]) - 1
                if s > score[i, j]:
                    score[i, j] = s
                    back[(i, j)] = (i - 1, j - 1, j - 1)
        forward_skips(i)
        jumps(i)
        forward_skips(i)
    match = [None] * n
    i, j = n, int(np.argmax(score[n]))
    while (i, j) in back:
        pi, pj, q = back[(i, j)]
        if pi == i - 1 and q is not None:
            match[i - 1] = q
        i, j = pi, pj
    return match


def build_segments(asr_words, match, qwords, max_gap=0.8):
    """مقاطع العرض: مقطع جديد عند نهاية آية، أو رجوع القارئ للخلف، أو وقفة طويلة."""
    hits = [(q, b, e) for (_, b, e), q in zip(asr_words, match) if q is not None]
    runs = []
    for q, b, e in hits:
        if runs:
            r = runs[-1]
            same_ayah = qwords[q][:2] == qwords[r["last"]][:2]
            if q > r["last"] and same_ayah and b - r["end"] <= max_gap:
                r["last"], r["end"] = q, e
                continue
            if q == r["last"]:  # نفس الكلمة مرتين متتاليتين من التعرف
                r["end"] = e
                continue
        runs.append({"first": q, "last": q, "start": b, "end": e})
    segs = []
    for k, r in enumerate(runs):
        ws = qwords[r["first"]:r["last"] + 1]
        text = " ".join(w for _, _, w in ws)
        s, a = ws[-1][:2]
        ayah_end = r["last"] + 1 >= len(qwords) or qwords[r["last"] + 1][:2] != (s, a)
        if ayah_end:
            text += f" {quran.arabic_number(a)}"
        # يبقى النص ظاهراً حتى قبيل المقطع التالي (المدود والوقفات)
        nxt = runs[k + 1]["start"] if k + 1 < len(runs) else r["end"] + 0.6
        segs.append({"text": text, "start": round(r["start"], 2), "end": round(max(r["end"], nxt - 0.15), 2),
                     "surah": s, "ayah": a})
    return segs


def auto_sync(path, progress=None):
    """التلاوة ← (السورة، أول آية، آخر آية، المقاطع). يرفع ValueError إذا لم يُتعرّف عليها."""
    if progress:
        progress("التعرف على الصوت…")
    asr_words = transcribe(path)
    asr_norm = [norm(w) for w, _, _ in asr_words]
    if progress:
        progress("تحديد الآيات في المصحف…")
    span = locate(asr_norm)
    if not span:
        raise ValueError("لم أتعرف على الآيات في هذا المقطع")
    words, qn = _quran_words()
    lo, hi = span
    qwords = words[lo:hi + 1]
    if progress:
        progress("مزامنة الكلمات…")
    match = align(asr_norm, qn[lo:hi + 1])
    segs = build_segments(asr_words, match, qwords)
    if not segs:
        raise ValueError("لم أتعرف على الآيات في هذا المقطع")
    surahs = {s["surah"] for s in segs}
    surah = max(surahs, key=lambda x: sum(s["surah"] == x for s in segs))
    ayat = [s["ayah"] for s in segs if s["surah"] == surah]
    return surah, min(ayat), max(ayat), [{k: s[k] for k in ("text", "start", "end")} for s in segs if s["surah"] == surah]
