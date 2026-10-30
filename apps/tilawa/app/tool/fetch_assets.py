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
for f in ["hafs.otf", "bsml.ttf"]:
    (OUT / f).write_bytes((TILAWA / "assets" / f).read_bytes())
for i, name in enumerate(backgrounds.PRESETS):
    Image.open(backgrounds.preset_path(name)).convert("RGB").save(OUT / f"bg{i}.jpg", quality=88)
for f in ["tiny-encoder.int8.onnx", "tiny-decoder.int8.onnx", "tiny-tokens.txt"]:
    if not (OUT / "model" / f).exists():
        with urllib.request.urlopen(MODEL + f, timeout=600) as r:
            (OUT / "model" / f).write_bytes(r.read())
print("assets ready:", sorted(p.name for p in OUT.rglob("*") if p.is_file()))
