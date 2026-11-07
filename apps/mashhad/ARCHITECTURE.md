# البنية — مشهد

**ليست Flutter/Firebase** (انظر D1): الأداة دفتر Kaggle يعمل على كرت سحابي مجاني، يُفتح من المتصفح (حتى من الجوال).

| الملف | الدور |
|---|---|
| `tool/mashhad.py` | كل المنطق: السيناريو، الصوت، المقاطع، التجميع، الاستئناف |
| `tool/build_notebook.py` | يبني `mashhad_kaggle.ipynb` ويضمّن فيه `mashhad.py` كما هو |
| `mashhad_kaggle.ipynb` | الملف الذي يرفعه المالك إلى Kaggle |
| `tests/test_mashhad.py` | اختبارات (Wan مستبدل بمقاطع اصطناعية من ffmpeg) |

## التدفق
فكرة ← Gemini (واجهة OpenAI المتوافقة، `gemini-3.8-flash` ثم بدائل) ← `plan.json`
← edge-tts ← `voice_XX.mp3` ← Wan 2.1 T2V 1.3B عبر diffusers (832×480، 81 إطاراً، 16 إطاراً/ث، 30 خطوة، float16 على T4، تفريغ إلى المعالج) ← `clip_XX.mp4`
← ffmpeg (ضبط الطول + صوت) ← `seg_XX.mp4` ← دمج ← `final.mp4`.

## الأسرار
مفتاح Gemini في Kaggle Secrets باسم `GEMINI_API_KEY`. لا يُكتب في أي ملف.

## بعد تعديل الكود
`python3 tool/build_notebook.py && python3 -m pytest -q tests`
