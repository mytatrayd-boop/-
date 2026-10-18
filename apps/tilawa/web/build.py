"""يجهّز ملفات صفحة تلاوة (تعمل كلها في المتصفح) في مجلد واحد للنشر.

    python web/build.py OUT_DIR

ينزّل نموذج التعرف الصوتي (نسخة ONNX مضغوطة) ومحرك تشغيله، ويقسم كل ملف أكبر من 14 ميجا إلى أجزاء
(حدّ النشر للملف الواحد 15 ميجا)، والصفحة تعيد تجميعها. يحتاج أصول setup_assets.py (النص والخطوط).
"""
import json, shutil, sqlite3, sys, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from tilawa import backgrounds  # noqa: E402

MODEL = "https://huggingface.co/aaqibhabib/whisper-base-ar-quran-onnx/resolve/main/"
BASE_GEN = "https://huggingface.co/openai/whisper-base/resolve/main/generation_config.json"
TJS = "https://registry.npmjs.org/@huggingface/transformers/-/transformers-3.7.5.tgz"
PART = 14 * 1024 * 1024


def fetch(url):
    with urllib.request.urlopen(url, timeout=600) as r:
        return r.read()


def split(data, out, folder, name, manifest):
    """يكتب الملف أجزاءً (أسماؤها بالنسبة لجذر الصفحة) ويسجلها في manifest تحت مساره الأصلي."""
    parts = []
    for i in range(0, len(data), PART):
        p = f"{folder}/{name}.{i // PART:02d}.wasm"  # امتداد يقبله النشر؛ المحتوى بايتات خام
        (out / p).write_bytes(data[i:i + PART])
        parts.append(p)
    manifest[f"{folder}/{name}"] = {"parts": parts, "size": len(data)}


def main(out):
    out = Path(out)
    (out / "model" / "onnx").mkdir(parents=True, exist_ok=True)
    (out / "assets").mkdir(exist_ok=True)
    manifest = {}

    # النموذج: إعداداته، وإعدادات التوليد من whisper-base الأصلي (لغة ومهمة)، والملفات المضغوطة
    for f in ["config.json", "preprocessor_config.json", "tokenizer.json", "tokenizer_config.json"]:
        (out / "model" / f).write_bytes(fetch(MODEL + f))
    (out / "model" / "generation_config.json").write_bytes(fetch(BASE_GEN))
    for f in ["encoder_model_quantized.onnx", "decoder_model_merged_quantized.onnx"]:
        split(fetch(MODEL + "onnx/" + f), out, "model/onnx", f, manifest)

    # محرك ONNX (wasm) من نفس نسخة transformers.js التي تحمّلها الصفحة
    import io, tarfile
    with tarfile.open(fileobj=io.BytesIO(fetch(TJS))) as t:
        wasm = t.extractfile("package/dist/ort-wasm-simd-threaded.jsep.wasm").read()
    split(wasm, out, "assets", "ort.wasm", manifest)

    # نص المصحف (Tanzil كما هو) والخطوط والخلفيات الجاهزة
    con = sqlite3.connect(ROOT / "assets" / "quran.db")
    quran = [[name, [t for (t,) in con.execute("SELECT text FROM ayah WHERE surah=? ORDER BY ayah", (i,))]]
             for i, name, _ in con.execute("SELECT id, name, ayat FROM surah ORDER BY id")]
    (out / "assets" / "quran.json").write_text(json.dumps(quran, ensure_ascii=False, separators=(",", ":")),
                                              encoding="utf-8")
    shutil.copy(ROOT / "assets" / "hafs.otf", out / "assets" / "hafs.otf")
    shutil.copy(ROOT / "assets" / "bsml.ttf", out / "assets" / "bsml.ttf")
    for i, name in enumerate(backgrounds.PRESETS):
        from PIL import Image
        Image.open(backgrounds.preset_path(name)).convert("RGB").save(out / "assets" / f"bg{i}.jpg", quality=88)
    (out / "assets" / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    shutil.copy(Path(__file__).parent / "tilawa.html", out / "tilawa.html")
    print(json.dumps(manifest, indent=1))


if __name__ == "__main__":
    main(sys.argv[1])
