"""ينزّل أصول التطبيق إلى app/assets: نص المصحف، والخطوط، والخلفيات، ونموذج التعرف (sherpa-onnx).

    python tool/fetch_assets.py
"""
import json, sqlite3, subprocess, sys, urllib.request
from pathlib import Path

APP = Path(__file__).resolve().parent.parent
TILAWA = APP.parent
OUT = APP / "assets"
MODEL = "https://huggingface.co/kasimyazan/sherpa-tarteel-whisper-tiny-ar-quran/resolve/main/"

subprocess.run([sys.executable, str(TILAWA / "setup_assets.py")], check=True, cwd=TILAWA)
sys.path.insert(0, str(TILAWA))
from tilawa import backgrounds  # noqa: E402
from PIL import Image  # noqa: E402

(OUT / "model").mkdir(parents=True, exist_ok=True)
con = sqlite3.connect(TILAWA / "assets" / "quran.db")
quran = [[n, [t for (t,) in con.execute("SELECT text FROM ayah WHERE surah=? ORDER BY ayah", (i,))]]
         for i, n, _ in con.execute("SELECT id, name, ayat FROM surah ORDER BY id")]
(OUT / "quran.json").write_text(json.dumps(quran, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
# ترجمات وتفسير من Tanzil.net (للاستخدام الشخصي مع نسبة المصدر)؛ كل ملف: قائمة سور، كل سورة قائمة آيات
TRANS = ["ar.muyassar", "en.sahih", "fr.hamidullah", "ur.jalandhry", "id.indonesian", "tr.diyanet"]
(OUT / "tr").mkdir(exist_ok=True)
for tid in TRANS:
    f = OUT / "tr" / f"{tid}.json"
    if f.exists():
        continue
    with urllib.request.urlopen(f"https://tanzil.net/trans/{tid}", timeout=120) as r:
        rows = [l.split("|", 2) for l in r.read().decode("utf-8").splitlines() if l and not l.startswith("#")]
    out = [["" for _ in ayat] for _, ayat in quran]
    for s, a, t in rows:
        out[int(s) - 1][int(a) - 1] = t.strip()
    assert all(all(x) for x in out), tid
    f.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
# خطوط عربية/لاتينية مفتوحة الترخيص (OFL) لاختيارها في الترجمة واسم القارئ
GF = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
FONTS = {"Amiri": "amiri/Amiri-Regular.ttf", "Tajawal": "tajawal/Tajawal-Regular.ttf", "Almarai": "almarai/Almarai-Regular.ttf",
         "Scheherazade": "scheherazadenew/ScheherazadeNew-Regular.ttf", "Lateef": "lateef/Lateef-Regular.ttf"}
(OUT / "fonts").mkdir(exist_ok=True)
for name, path in FONTS.items():
    f = OUT / "fonts" / f"{name}.ttf"
    if not f.exists():
        with urllib.request.urlopen(GF + path, timeout=120) as r:
            f.write_bytes(r.read())
for f in ["hafs.otf", "bsml.ttf"]:
    (OUT / f).write_bytes((TILAWA / "assets" / f).read_bytes())
for i, name in enumerate(backgrounds.PRESETS):
    Image.open(backgrounds.preset_path(name)).convert("RGB").save(OUT / f"bg{i}.jpg", quality=88)
for f in ["tiny-encoder.int8.onnx", "tiny-decoder.int8.onnx", "tiny-tokens.txt"]:
    if not (OUT / "model" / f).exists():
        with urllib.request.urlopen(MODEL + f, timeout=600) as r:
            (OUT / "model" / f).write_bytes(r.read())
print("assets ready:", sorted(p.name for p in OUT.rglob("*") if p.is_file()))
