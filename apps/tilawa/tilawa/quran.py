"""قراءة نص المصحف من quran.db وتجهيزه للعرض بخط مجمع الملك فهد."""
import re, sqlite3
from functools import lru_cache
from pathlib import Path

DB = Path(__file__).resolve().parent.parent / "assets" / "quran.db"
BASMALA = "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ"
_DIGITS = "٠١٢٣٤٥٦٧٨٩"
# Tanzil يرمز التنوين المتتابع بتنوين + ميم صغيرة؛ خط المجمع له رموز خاصة به
_STAGGERED = {"ً": "ٗ", "ٌ": "ٞ", "ٍ": "ٖ"}
_TANWEEN_MEEM = re.compile("([ًٌٍ])[ۭۢ]")


def _con():
    return sqlite3.connect(DB)


@lru_cache
def surahs():
    """[(رقم، الاسم، عدد الآيات)]"""
    with _con() as c:
        return c.execute("SELECT id, name, ayat FROM surah ORDER BY id").fetchall()


def ayat(surah, start, end):
    with _con() as c:
        return c.execute("SELECT ayah, text FROM ayah WHERE surah=? AND ayah BETWEEN ? AND ? ORDER BY ayah",
                         (surah, start, end)).fetchall()


def arabic_number(n):
    return "".join(_DIGITS[int(d)] for d in str(n))


def for_hafs_font(words):
    """تحويل ترميز Tanzil إلى ترميز خط المجمع (لا يغيّر النص، فقط طريقة كتابة التنوين).
    التنوين قبل باء = إقلاب (يبقى بميم صغيرة)، وغير ذلك تنوين متتابع."""
    out = []
    for i, w in enumerate(words):
        nxt = words[i + 1] if i + 1 < len(words) else ""
        iqlab = nxt.lstrip("ـ").startswith("ب")
        out.append(_TANWEEN_MEEM.sub(lambda m: m.group(1) + "ۢ" if iqlab else _STAGGERED[m.group(1)], w))
    return out


def segments_for(surah, start, end):
    """مقطع لكل آية بنص Tanzil كما هو (يظهر صحيحاً في المتصفح) مع رقم الآية."""
    return [{"ayah": n, "text": f"{t} {arabic_number(n)}"} for n, t in ayat(surah, start, end)]


def next_word(surah, ayah):
    """أول كلمة بعد الآية (لتحديد نوع التنوين في آخر كلمة)."""
    row = ayat(surah, ayah + 1, ayah + 1)
    return row[0][1].split()[0] if row else ""


def texts_for_font(texts, tail=""):
    """تحويل نصوص المقاطع المتتالية إلى ترميز خط المجمع، مع الكلمة التالية لكل كلمة حتى عبر المقاطع.
    أرقام الآيات تُتجاوز عند البحث عن الكلمة التالية."""
    split = [t.split() for t in texts]
    flat = [w for ws in split for w in ws] + [tail]
    real = [i for i, w in enumerate(flat) if w.strip(_DIGITS)]
    conv = list(flat)
    for k, i in enumerate(real):
        nxt = flat[real[k + 1]] if k + 1 < len(real) else ""
        conv[i] = for_hafs_font([flat[i], nxt])[0]
    out, pos = [], 0
    for ws in split:
        out.append(" ".join(conv[pos:pos + len(ws)]))
        pos += len(ws)
    return out


def header_for(surah):
    name = dict((i, n) for i, n, _ in surahs())[surah]
    # التوبة بلا بسملة، والفاتحة البسملة فيها آية فلا تتكرر في الترويسة
    basmala = None if surah in (1, 9) else BASMALA
    return f"سُورَةُ {name}", basmala
