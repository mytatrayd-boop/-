import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tool"))
import mashhad as m  # noqa: E402


def test_settings_clamps_length():
    assert m.Settings("x", seconds=600).seconds == 120
    assert m.Settings("x", seconds=1).seconds == 5
    assert m.Settings("x", seconds=120).scene_count == 24          # بدون صوت: 5 ثوانٍ للمشهد
    assert m.Settings("x", seconds=120, voice="v").scene_count == 17
    assert m.Settings("x", seconds=60, voice="v").scene_count == 8
    with pytest.raises(ValueError):
        m.Settings("  ")


def test_parse_scenes_with_fences_and_extra_text():
    text = 'هذا هو:\n```json\n[{"prompt":"a","narration":"ن1"},{"prompt":"b","narration":"ن2"},{"prompt":"c"}]\n```'
    sc = m.parse_scenes(text, 2)
    assert [s.prompt for s in sc] == ["a", "b"]
    assert sc[0].narration == "ن1"


def test_parse_scenes_rejects_short_or_bad():
    with pytest.raises(ValueError):
        m.parse_scenes('[{"prompt":"a"}]', 3)
    with pytest.raises(ValueError):
        m.parse_scenes("لا يوجد شيء", 1)


def test_fit_timing():
    assert m.fit_timing(5.0, None) == (1.0, 0.0)
    assert m.fit_timing(5.0, 3.0) == (1.0, 0.0)          # الصوت أقصر: لا تغيير
    stretch, pad = m.fit_timing(5.0, 6.1)                 # 6.5 = 5 × 1.3
    assert stretch == pytest.approx(1.3) and pad == 0
    stretch, pad = m.fit_timing(5.0, 9.6)                 # 10 = 5 × 1.5 + 2.5 تجميد
    assert stretch == 1.5 and pad == pytest.approx(2.5)


def fake_clip(scene, index, out: Path):
    """بديل Wan للاختبار: مقطع 5 ثوانٍ 832×480 بـ 16 إطاراً."""
    subprocess.run(["ffmpeg", "-y", "-f", "lavfi", "-i",
                    f"testsrc2=size=832x480:rate=16:duration=5.0625",
                    "-pix_fmt", "yuv420p", str(out)], check=True, capture_output=True)


def silent_voices(monkeypatch, durations):
    def fake(scenes, work, voice):
        out = []
        for i, d in enumerate(durations):
            p = work / f"voice_{i:02d}.mp3"
            subprocess.run(["ffmpeg", "-y", "-f", "lavfi", "-i", f"sine=f=300:d={d}",
                            str(p)], check=True, capture_output=True)
            out.append(p)
        return out
    monkeypatch.setattr(m, "make_voices", fake)


def test_full_run_with_fake_clips(tmp_path, monkeypatch):
    silent_voices(monkeypatch, [3.0, 7.0, 9.6])
    s = m.Settings("اختبار", seconds=15, voice="v", work_dir=str(tmp_path))
    scenes = [{"prompt": f"p{i}", "narration": f"ن{i}"} for i in range(3)]
    final = m.run(s, maker=fake_clip, scenes=scenes, log=lambda *_: None)
    dur = m.media_duration(final)
    # 5.06 + (7.4) + (10.0) ≈ 22.5 ثانية
    assert 21.5 < dur < 23.5
    probe = json.loads(subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(final)],
        capture_output=True, text=True, check=True).stdout)
    kinds = sorted(st["codec_type"] for st in probe["streams"])
    assert kinds == ["audio", "video"]
    plan = json.loads((tmp_path / "plan.json").read_text(encoding="utf-8"))
    assert plan["scenes"][1]["narration"] == "ن1"


def test_resume_skips_existing_clips_and_new_idea_clears(tmp_path, monkeypatch):
    silent_voices(monkeypatch, [2.0])
    calls = []

    def counting(scene, i, out):
        calls.append(i)
        fake_clip(scene, i, out)

    scenes = [{"prompt": "p", "narration": "ن"}]
    s = m.Settings("فكرة", seconds=5, voice="v", work_dir=str(tmp_path))
    m.run(s, maker=counting, scenes=scenes, log=lambda *_: None)
    m.run(s, maker=counting, scenes=scenes, log=lambda *_: None)
    assert calls == [0]                      # المرة الثانية لم تولّد شيئاً
    s2 = m.Settings("فكرة أخرى", seconds=5, voice="v", work_dir=str(tmp_path))
    m.run(s2, maker=counting, scenes=scenes, log=lambda *_: None)
    assert calls == [0, 0]                   # فكرة جديدة: أعاد التوليد


@pytest.mark.skipif(not os.environ.get("MASHHAD_LIVE"), reason="يحتاج إنترنت (MASHHAD_LIVE=1)")
def test_live_gemini_and_voice(tmp_path):
    s = m.Settings("رحلة قطرة ماء من السحابة إلى البحر", seconds=20, voice="ar-SA-HamedNeural", work_dir=str(tmp_path))
    scenes = m.plan_scenes(s, os.environ.get("GEMINI_API_KEY", "dummy"))
    assert len(scenes) == 3 and all(x.prompt and x.narration for x in scenes)
    voices = m.make_voices(scenes, tmp_path, s.voice)
    assert all(m.media_duration(v) > 1 for v in voices)


def test_notebook_embeds_current_code():
    nb = json.loads((Path(__file__).resolve().parents[1] / "mashhad_kaggle.ipynb").read_text(encoding="utf-8"))
    embedded = "".join(nb["cells"][2]["source"]).split("\n", 1)[1]
    src = (Path(__file__).resolve().parents[1] / "tool" / "mashhad.py").read_text(encoding="utf-8")
    assert embedded == src, "شغّل: python3 tool/build_notebook.py"
    for cell in nb["cells"]:
        if cell["cell_type"] == "code":
            text = "".join(cell["source"])
            compile("".join(l for l in text.splitlines(True)
                            if not l.startswith(("!", "%%"))), "cell", "exec")


def test_silent_run(tmp_path):
    s = m.Settings("بدون صوت", seconds=10, work_dir=str(tmp_path))
    assert s.scene_count == 2
    scenes = [{"prompt": "p0"}, {"prompt": "p1"}]
    final = m.run(s, maker=fake_clip, scenes=scenes, log=lambda *_: None)
    assert 9.5 < m.media_duration(final) < 11
