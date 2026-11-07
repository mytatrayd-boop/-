"""يبني دفتر Kaggle (mashhad_kaggle.ipynb) ويضمّن فيه mashhad.py كما هو، فالدفتر لا يحتاج المستودع.

التشغيل: python3 tool/build_notebook.py
"""
from pathlib import Path

import nbformat as nbf

HERE = Path(__file__).resolve().parent
src = (HERE / "mashhad.py").read_text(encoding="utf-8")

nb = nbf.v4.new_notebook()
nb.metadata = {
    "kernelspec": {"name": "python3", "display_name": "Python 3", "language": "python"},
    "language_info": {"name": "python"},
    "kaggle": {"accelerator": "gpu", "isInternetEnabled": True, "isGpuEnabled": True},
}
nb.cells = [
    nbf.v4.new_markdown_cell(
        "# مشهد — فيديو بحركة حقيقية من فكرة مكتوبة\n\n"
        "**قبل التشغيل (مرة واحدة):**\n"
        "1. من القائمة اليمنى ← Settings: اختر **Accelerator: GPU T4 x2** وفعّل **Internet: On**.\n"
        "2. من Add-ons ← Secrets: أضف مفتاح Gemini باسم `GEMINI_API_KEY` (مجاني من aistudio.google.com) وفعّله لهذا الدفتر.\n\n"
        "**كل مرة:** عدّل الفكرة والمدة في الخلية 3، ثم **Run All**. "
        "يمكنك إغلاق الصفحة إذا شغّلته بـ **Save Version ← Save & Run All**، والفيديو يظهر في Output.\n\n"
        "إن انقطعت الجلسة، شغّله مرة أخرى بنفس الفكرة: يكمل من آخر مشهد اكتمل (ما دام مجلد العمل موجوداً)."
    ),
    nbf.v4.new_code_cell(
        "# 1) تثبيت المكتبات (دقيقة إلى دقيقتين)\n"
        "!pip install -q \"diffusers>=0.33,<0.37\" ftfy edge-tts openai imageio imageio-ffmpeg\n"
        "!ffmpeg -version | head -1\n"
        "!nvidia-smi --query-gpu=name,memory.total --format=csv"
    ),
    nbf.v4.new_code_cell("%%writefile mashhad.py\n" + src),
    nbf.v4.new_code_cell(
        "# 3) الإعدادات — عدّل هنا فقط\n"
        "IDEA = \"رحلة قطرة ماء من السحابة إلى البحر\"   # فكرة الفيديو (بالعربية)\n"
        "SECONDS = 60          # المدة بالثواني، حتى 120 (دقيقتان)\n"
        "VOICE = None          # بدون صوت. لتعليق عربي: \"ar-SA-HamedNeural\" (رجل) أو \"ar-SA-ZariyahNeural\" (امرأة)\n"
        "STYLE = \"cinematic, realistic, natural light, smooth camera motion\"  # أسلوب الصورة\n"
        "\n"
        "# اختياري: اكتب المشاهد بنفسك بدل Gemini (اتركها None لتكتبها Gemini)\n"
        "# MY_SCENES = [{\"prompt\": \"A raindrop falling from a dark cloud, slow motion\", \"narration\": \"تبدأ الحكاية من السماء\"}]\n"
        "MY_SCENES = None"
    ),
    nbf.v4.new_code_cell(
        "# 4) التشغيل — المرحلة الطويلة هي توليد المقاطع\n"
        "import importlib, mashhad\n"
        "importlib.reload(mashhad)\n"
        "try:\n"
        "    from kaggle_secrets import UserSecretsClient\n"
        "    KEY = UserSecretsClient().get_secret(\"GEMINI_API_KEY\")\n"
        "except Exception:\n"
        "    KEY = None\n"
        "settings = mashhad.Settings(IDEA, seconds=SECONDS, voice=VOICE, style=STYLE,\n"
        "                            work_dir=\"/kaggle/working/mashhad_out\")\n"
        "final = mashhad.run(settings, api_key=KEY, scenes=MY_SCENES)"
    ),
    nbf.v4.new_code_cell(
        "# 5) مشاهدة الفيديو وتنزيله (أو من تبويب Output)\n"
        "from IPython.display import Video, FileLink, display\n"
        "display(Video(str(final), embed=False, width=640))\n"
        "display(FileLink(\"mashhad_out/final.mp4\"))"
    ),
]
for c in nb.cells:
    if c.cell_type == "code":
        c.outputs = []
        c.execution_count = None

out = HERE.parent / "mashhad_kaggle.ipynb"
nbf.write(nb, out)
print(f"كُتب {out}")
