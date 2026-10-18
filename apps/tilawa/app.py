"""واجهة تلاوة: رفع التلاوة ← اختيار الآيات ← التوقيت ← الخلفية والنص ← إنتاج الفيديو.

    streamlit run app.py
"""
import os, sys, tempfile
from pathlib import Path

import pandas as pd
import streamlit as st

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "engine"))
from render import Style, preview, render  # noqa: E402
from tilawa import backgrounds, quran, timing  # noqa: E402

FONT = str(ROOT / "assets" / "hafs.otf")
WORK = Path(tempfile.gettempdir()) / "tilawa"
WORK.mkdir(exist_ok=True)

st.set_page_config(page_title="تلاوة — مولّد مقاطع القرآن", page_icon="📖", layout="wide")
st.markdown("""<style>
  .stApp, .stMarkdown, label, .stRadio, .stSelectbox, .stSlider, p, h1, h2, h3 { direction: rtl; text-align: right; }
  [data-testid="stSidebar"] { direction: rtl; }
</style>""", unsafe_allow_html=True)

if not (ROOT / "assets" / "quran.db").exists() or not os.path.exists(FONT):
    st.error("الأصول غير مجهزة. شغّل مرة واحدة: python setup_assets.py")
    st.stop()


def save_upload(f, name):
    p = WORK / f"{name}{Path(f.name).suffix.lower()}"
    p.write_bytes(f.getbuffer())
    return str(p)


st.title("📖 تلاوة — مولّد مقاطع القرآن")

# ── 1) التلاوة والآيات ─────────────────────────────────────────
c1, c2 = st.columns([1, 1])
with c1:
    st.subheader("١) التلاوة")
    audio_file = st.file_uploader("ملف التلاوة (صوت أو فيديو)", type=["mp3", "m4a", "wav", "aac", "ogg", "mp4"])
    audio_path = save_upload(audio_file, "audio") if audio_file else None
    if audio_path and st.button("🔎 تعرّف على الآيات ووقّتها تلقائياً", type="primary"):
        from tilawa import sync
        try:
            with st.status("المزامنة الآلية…", expanded=True) as box:
                surah_id, a_from, a_to, auto = sync.auto_sync(audio_path, progress=st.write)
                box.update(label="تمت المزامنة", state="complete", expanded=False)
            st.session_state.update(surah=surah_id, start=a_from, end=a_to, segs=pd.DataFrame(auto),
                                    seg_key=(surah_id, a_from, a_to, audio_file.name))
            st.success(f"سورة {quran.surahs()[surah_id - 1][1]}، الآيات {a_from}–{a_to}، {len(auto)} مقطعاً. راجع الجدول وعدّل ما يلزم.")
        except ValueError as err:
            st.error(f"{err}. اختر السورة والآيات يدوياً.")
    st.caption("أول تشغيل ينزّل نموذج التعرف الصوتي (~300 ميجا).")
with c2:
    st.subheader("٢) الآيات")
    names = {i: f"{i}. {n}" for i, n, _ in quran.surahs()}
    counts = {i: c for i, _, c in quran.surahs()}
    st.session_state.setdefault("surah", 70)
    surah = st.selectbox("السورة", list(names), format_func=names.get, key="surah")
    st.session_state.start = min(st.session_state.get("start", 1), counts[surah])
    st.session_state.end = min(max(st.session_state.get("end", 5), st.session_state.start), counts[surah])
    a1, a2 = st.columns(2)
    start = a1.number_input("من آية", 1, counts[surah], key="start")
    end = a2.number_input("إلى آية", int(start), counts[surah], key="end")

base = quran.segments_for(surah, int(start), int(end))

# ── 3) التوقيت ──────────────────────────────────────────────────
st.subheader("٣) التوقيت")
st.caption("توزيع تقريبي حسب طول كل آية. عدّل البداية والنهاية، أو قسّم الآية لعدة مقاطع (احذف من النص وأضف صفاً)، "
           "أو كرّر مقطعاً إذا أعاده القارئ. زر «تعرّف تلقائياً» يملأ الجدول من الصوت نفسه.")
key = (surah, int(start), int(end), audio_file.name if audio_file else None)
if "segs" not in st.session_state or st.session_state.get("seg_key") != key or st.button("↺ إعادة التوزيع التلقائي"):
    if audio_path:
        b, e = timing.speech_bounds(audio_path)
    else:
        b, e = 0.0, 5.0 * len(base)
    st.session_state.segs = pd.DataFrame(timing.distribute([s["text"] for s in base], b, e))
    st.session_state.seg_key = key
segs_df = st.data_editor(
    st.session_state.segs, num_rows="dynamic", width="stretch", hide_index=True,
    column_config={"text": st.column_config.TextColumn("النص", width="large"),
                   "start": st.column_config.NumberColumn("البداية (ث)", step=0.1, format="%.2f"),
                   "end": st.column_config.NumberColumn("النهاية (ث)", step=0.1, format="%.2f")},
    column_order=["text", "start", "end"])
segments = [r for r in segs_df.dropna().to_dict("records") if str(r["text"]).strip() and r["end"] > r["start"]]
# الجدول بنص Tanzil كما هو؛ الرسم بترميز خط المجمع
font_texts = quran.texts_for_font([s["text"] for s in segments], quran.next_word(surah, int(end)))
render_segments = [{**s, "text": t} for s, t in zip(segments, font_texts)]

# ── 4) الخلفية والنص ────────────────────────────────────────────
st.subheader("٤) الخلفية والنص")
left, right = st.columns([1.3, 1])
with left:
    with st.expander("🖼️ الخلفية", expanded=True):
        kind = st.radio("نوع الخلفية", ["جاهزة", "صورة أو فيديو من جهازي"], horizontal=True)
        if kind == "جاهزة":
            preset = st.radio("اختر", list(backgrounds.PRESETS), horizontal=True)
            bg_path = backgrounds.preset_path(preset)
        else:
            up = st.file_uploader("ارفع صورة أو فيديو", type=["jpg", "jpeg", "png", "webp", "mp4", "mov", "m4v"])
            bg_path = save_upload(up, "background") if up else backgrounds.preset_path("ليل ونجوم")
            st.caption("يُقص تلقائياً إلى 9:16. الفيديو الأقصر من التلاوة يتكرر.")
        dim = st.slider("تعتيم الخلفية", 0.0, 0.8, 0.25, 0.05)
        zoom = st.checkbox("تقريب بطيء (للصور)", True)
    with st.expander("🔤 نص الآيات (الحجم والموضع والمحاذاة)", expanded=True):
        font_size = st.slider("حجم الخط", 30, 120, 60)
        text_y = st.slider("الموضع العمودي (أعلى ← أسفل)", 0.15, 0.90, 0.40, 0.01)
        align = st.radio("المحاذاة", ["توسيط", "يمين", "يسار"], horizontal=True)
        width = st.slider("عرض السطر", 0.5, 0.95, 0.85, 0.01)
        line_gap = st.slider("تباعد الأسطر", 1.3, 2.6, 1.9, 0.1)
        color = st.color_picker("لون النص", "#FFFFFF")
        shadow = st.slider("قوة الظل", 0.0, 1.0, 0.85, 0.05)
        fade = st.slider("مدة الظهور والاختفاء (ث)", 0.0, 1.0, 0.35, 0.05)
    with st.expander("🕌 الترويسة (اسم السورة والبسملة)", expanded=True):
        st.caption("الترويسة ثابتة طوال المقطع ولا تختفي مع الآيات.")
        header_modes = {"إطار المصحف وبسملة مزخرفة": "mushaf", "بسملة مزخرفة": "basmala", "نص عادي": "plain"}
        header_mode = header_modes[st.radio("شكل الترويسة", list(header_modes), horizontal=True)]
        surah_title, basmala = quran.header_for(surah)
        show_name = st.checkbox("اسم السورة", True)
        show_basmala = st.checkbox("البسملة", basmala is not None, disabled=basmala is None,
                                   help="لا بسملة في ترويسة الفاتحة (هي آية فيها) ولا التوبة")
        header_size = st.slider("حجم الترويسة", 24, 90, 46)
        header_y = st.slider("موضع الترويسة", 0.03, 0.40, 0.09, 0.01)
        header_color = st.color_picker("لون الترويسة", "#EBEBEB")

style = Style(font_size=font_size, text_y=text_y, align={"توسيط": "center", "يمين": "right", "يسار": "left"}[align],
              width=width, line_gap=line_gap, color=color, shadow=shadow, fade=fade, header_size=header_size,
              header_y=header_y, header_color=header_color, header_mode=header_mode, dim=dim, zoom=zoom)
header_lines = [surah_title if show_name else None, basmala if show_basmala else None]

with right:
    st.markdown("**معاينة**")
    if segments:
        idx = st.select_slider("المقطع المعروض", options=list(range(len(segments))), value=0,
                               format_func=lambda i: f"{i + 1}") if len(segments) > 1 else 0
        st.image(preview(bg_path, render_segments[idx]["text"], header_lines, FONT, style), width=340)

# ── 5) الإنتاج ──────────────────────────────────────────────────
st.subheader("٥) الإنتاج")
if not audio_path:
    st.info("ارفع ملف التلاوة أولاً.")
elif not segments:
    st.warning("لا توجد مقاطع صالحة في جدول التوقيت.")
elif st.button("🎬 أنتج الفيديو", type="primary"):
    out = str(WORK / f"tilawa_{surah}_{int(start)}-{int(end)}.mp4")
    with st.spinner("جارٍ إنتاج الفيديو…"):
        render(bg_path, audio_path, render_segments, FONT, out, style, header_lines)
    st.columns([1, 2])[0].video(out)
    with open(out, "rb") as f:
        st.download_button("⬇️ تحميل الفيديو", f, file_name=Path(out).name, mime="video/mp4")
