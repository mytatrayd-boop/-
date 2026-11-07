"""مشهد — يحوّل فكرة مكتوبة إلى فيديو بحركة حقيقية (حتى دقيقتين) على كرت Kaggle المجاني.

المراحل:
1. plan_scenes: Gemini يقسّم الفكرة إلى مشاهد (وصف إنجليزي للصورة + جملة تعليق عربية).
2. make_voices: تعليق صوتي عربي لكل مشهد (edge-tts المجاني).
3. make_clips: نموذج Wan 2.1 (1.3B) يولّد مقطعاً ~5 ثوانٍ لكل مشهد.
4. assemble: ffmpeg يضبط طول كل مقطع على صوته ويجمعها في final.mp4.

كل مرحلة تحفظ نتائجها في مجلد العمل وتتخطى ما اكتمل، فإعادة التشغيل تكمل من حيث توقفت.
"""
from __future__ import annotations

import asyncio
import json
import math
import os
import re
import shutil
import subprocess
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Callable

MAX_SECONDS = 120          # الحد الأقصى المعتمد: دقيقتان (D3)
SCENE_SECONDS = 5          # طول مقطع Wan الواحد: 81 إطاراً على 16 إطاراً/ث
SCENE_TARGET = 7.2        # طول المشهد النهائي المقيس: صوت عربي 8-12 كلمة + هامش (تجربة 2026-11-07: 36ث لخمسة مشاهد)
MAX_STRETCH = 1.5          # أقصى إبطاء للمقطع ليلحق بطول الصوت قبل تجميد آخر إطار

GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/openai/"
GEMINI_MODELS = ("gemini-3.8-flash", "gemini-3.5-flash", "gemini-flash-latest")

WAN_NEGATIVE = (
    "Bright tones, overexposed, static, blurred details, subtitles, text, watermark, "
    "style, works, paintings, images, still picture, overall gray, worst quality, low quality, "
    "JPEG compression residue, ugly, incomplete, extra fingers, poorly drawn hands, "
    "poorly drawn faces, deformed, disfigured, misshapen limbs, fused fingers, "
    "messy background, three legs, many people in the background, walking backwards"
)


@dataclass
class Settings:
    idea: str
    seconds: int = 60
    voice: str | None = None   # None = بدون تعليق صوتي (اختيار المالك). مثال: "ar-SA-HamedNeural"
    style: str = "cinematic, realistic, natural light, smooth camera motion"
    work_dir: str = "mashhad_out"
    seed: int = 42
    # إعدادات Wan
    model_id: str = "Wan-AI/Wan2.1-T2V-1.3B-Diffusers"
    width: int = 832
    height: int = 480
    num_frames: int = 81
    fps: int = 16
    steps: int = 30
    guidance: float = 5.0

    def __post_init__(self):
        if not self.idea or not self.idea.strip():
            raise ValueError("اكتب فكرة الفيديو أولاً.")
        self.seconds = max(SCENE_SECONDS, min(int(self.seconds), MAX_SECONDS))

    @property
    def scene_count(self) -> int:
        per = SCENE_TARGET if self.voice else SCENE_SECONDS
        return max(1, round(self.seconds / per))


@dataclass
class Scene:
    prompt: str        # وصف بالإنجليزية لنموذج الفيديو
    narration: str     # جملة التعليق بالعربية


# ---------------------------------------------------------------- 1. السيناريو

def build_plan_prompt(s: Settings) -> str:
    n = s.scene_count
    per = SCENE_TARGET if s.voice else SCENE_SECONDS
    return f"""You are a video director. Turn the idea below into exactly {n} consecutive scenes
for a {s.seconds}-second video. Each scene is one shot of about {per:.0f} seconds.

Idea (may be Arabic): {s.idea}

Return ONLY a JSON array of {n} objects, no other text:
[{{"prompt": "...", "narration": "..."}}]

Rules:
- "prompt": English, 40-70 words, describes ONE continuous shot: subject, action/motion,
  setting, camera movement, lighting. Visual style for every scene: {s.style}.
  Repeat key visual details (characters' look, colors, place) in every prompt so scenes stay consistent.
  No text, letters, logos or subtitles in the image.
- "narration": Modern Standard Arabic, 8 to 12 words, spoken over that shot. The narrations
  together tell one coherent story with an opening and an ending."""


def parse_scenes(text: str, expected: int) -> list[Scene]:
    """يستخرج المشاهد من رد النموذج، ويقبل رداً محاطاً بـ ```json أو بنص زائد."""
    m = re.search(r"\[.*\]", text, re.S)
    if not m:
        raise ValueError("رد Gemini لا يحتوي قائمة مشاهد JSON.")
    data = json.loads(m.group(0))
    scenes = []
    for item in data:
        if not isinstance(item, dict):
            continue
        prompt = str(item.get("prompt", "")).strip()
        narration = str(item.get("narration", "")).strip()
        if prompt:
            scenes.append(Scene(prompt, narration))
    if not scenes:
        raise ValueError("رد Gemini لا يحتوي مشاهد صالحة.")
    if len(scenes) < expected:
        raise ValueError(f"Gemini أعاد {len(scenes)} مشاهد بدل {expected}.")
    return scenes[:expected]


def plan_scenes(s: Settings, api_key: str, attempts: int = 4) -> list[Scene]:
    from openai import OpenAI

    client = OpenAI(api_key=api_key, base_url=GEMINI_BASE_URL, timeout=120, max_retries=0)
    last: Exception | None = None
    for i in range(attempts):
        model = GEMINI_MODELS[min(i, len(GEMINI_MODELS) - 1)]
        try:
            r = client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": build_plan_prompt(s)}],
                temperature=0.7,
            )
            return parse_scenes(r.choices[0].message.content or "", s.scene_count)
        except Exception as e:  # نعيد المحاولة: الرد قد يكون ناقصاً أو الخدمة مشغولة
            last = e
            time.sleep(2 * (i + 1))
    raise RuntimeError(f"تعذّر كتابة السيناريو: {last}")


# ---------------------------------------------------------------- 2. الصوت

def make_voices(scenes: list[Scene], work: Path, voice: str) -> list[Path | None]:
    import edge_tts

    async def one(text: str, out: Path):
        await edge_tts.Communicate(text, voice).save(str(out))

    paths: list[Path | None] = []
    for i, sc in enumerate(scenes):
        out = work / f"voice_{i:02d}.mp3"
        if not sc.narration:
            paths.append(None)
            continue
        if not (out.exists() and out.stat().st_size > 0):
            for attempt in range(3):
                try:
                    asyncio.run(one(sc.narration, out))
                    break
                except Exception as e:
                    out.unlink(missing_ok=True)
                    if attempt == 2:
                        raise RuntimeError(f"تعذّر توليد الصوت للمشهد {i + 1}: {e}")
                    time.sleep(2)
        paths.append(out)
    return paths


# ---------------------------------------------------------------- 3. المقاطع

ClipMaker = Callable[[Scene, int, Path], None]


def wan_clip_maker(s: Settings) -> ClipMaker:
    """يحمّل Wan مرة واحدة ويعيد دالة تولّد مقطعاً لكل مشهد."""
    import torch
    from diffusers import AutoencoderKLWan, WanPipeline
    from diffusers.utils import export_to_video

    # كروت T4 وP100 لا تدعم bfloat16، فنستخدم float16 فيها.
    dtype = torch.bfloat16 if torch.cuda.is_bf16_supported() else torch.float16
    vae = AutoencoderKLWan.from_pretrained(s.model_id, subfolder="vae", torch_dtype=torch.float32)
    pipe = WanPipeline.from_pretrained(s.model_id, vae=vae, torch_dtype=dtype)
    pipe.enable_model_cpu_offload()  # يُبقي في الكرت الجزء الذي يعمل فقط (16GB لا تكفي للكل)

    def make(scene: Scene, index: int, out: Path) -> None:
        g = torch.Generator("cpu").manual_seed(s.seed + index)
        frames = pipe(
            prompt=f"{scene.prompt} {s.style}",
            negative_prompt=WAN_NEGATIVE,
            height=s.height,
            width=s.width,
            num_frames=s.num_frames,
            num_inference_steps=s.steps,
            guidance_scale=s.guidance,
            generator=g,
        ).frames[0]
        tmp = out.with_suffix(".tmp.mp4")
        export_to_video(frames, str(tmp), fps=s.fps)
        tmp.rename(out)

    return make


def make_clips(scenes: list[Scene], work: Path, maker: ClipMaker,
               log: Callable[[str], None] = print) -> list[Path]:
    paths = []
    for i, sc in enumerate(scenes):
        out = work / f"clip_{i:02d}.mp4"
        if out.exists() and out.stat().st_size > 0:
            log(f"المشهد {i + 1}/{len(scenes)}: موجود مسبقاً، تخطّي.")
        else:
            t = time.time()
            maker(sc, i, out)
            log(f"المشهد {i + 1}/{len(scenes)}: تم في {(time.time() - t) / 60:.1f} دقيقة.")
        paths.append(out)
    return paths


# ---------------------------------------------------------------- 4. التجميع

def media_duration(path: Path) -> float:
    r = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=True,
    )
    return float(r.stdout.strip())


def fit_timing(clip_dur: float, audio_dur: float | None, tail: float = 0.4) -> tuple[float, float]:
    """(معامل الإبطاء، ثواني تجميد آخر إطار) ليصبح المقطع بطول صوته + هامش قصير."""
    if not audio_dur:
        return 1.0, 0.0
    target = audio_dur + tail
    if target <= clip_dur:
        return 1.0, 0.0
    stretch = min(target / clip_dur, MAX_STRETCH)
    pad = max(0.0, target - clip_dur * stretch)
    return round(stretch, 4), round(pad, 3)


def _run(cmd: list[str]) -> None:
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"ffmpeg فشل:\n{r.stderr[-1500:]}")


def build_segment(clip: Path, voice: Path | None, out: Path, fps: int) -> None:
    clip_dur = media_duration(clip)
    audio_dur = media_duration(voice) if voice else None
    stretch, pad = fit_timing(clip_dur, audio_dur)
    vf = f"setpts={stretch}*PTS,fps={fps}"
    if pad > 0:
        vf += f",tpad=stop_mode=clone:stop_duration={pad}"
    vf += ",format=yuv420p"
    total = clip_dur * stretch + pad
    cmd = ["ffmpeg", "-y", "-i", str(clip)]
    if voice:
        cmd += ["-i", str(voice)]
    else:
        cmd += ["-f", "lavfi", "-i", "anullsrc=r=24000:cl=mono"]
    cmd += [
        "-filter_complex", f"[0:v]{vf}[v];[1:a]aresample=24000,apad[a]",
        "-map", "[v]", "-map", "[a]", "-t", f"{total:.3f}",
        "-c:v", "libx264", "-preset", "medium", "-crf", "20",
        "-c:a", "aac", "-b:a", "128k", "-ac", "1", "-ar", "24000",
        str(out),
    ]
    _run(cmd)


def assemble(clips: list[Path], voices: list[Path | None], work: Path, fps: int) -> Path:
    segs = []
    for i, (c, v) in enumerate(zip(clips, voices)):
        seg = work / f"seg_{i:02d}.mp4"
        build_segment(c, v, seg, fps)
        segs.append(seg)
    lst = work / "segments.txt"
    lst.write_text("".join(f"file '{p.name}'\n" for p in segs), encoding="utf-8")
    final = work / "final.mp4"
    _run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(lst),
          "-c", "copy", "-movflags", "+faststart", str(final)])
    return final


# ---------------------------------------------------------------- التشغيل الكامل

def load_or_plan(s: Settings, work: Path, api_key: str | None,
                 scenes: list[dict] | None = None) -> list[Scene]:
    plan = work / "plan.json"
    if plan.exists():
        saved = json.loads(plan.read_text(encoding="utf-8"))
        if saved.get("idea") == s.idea and saved.get("seconds") == s.seconds:
            return [Scene(**x) for x in saved["scenes"]]
    # فكرة جديدة: نحذف مقاطع وأصوات الفكرة السابقة حتى لا تختلط بها
    for old in [*work.glob("clip_*"), *work.glob("voice_*"), *work.glob("seg_*")]:
        old.unlink()
    if scenes:  # مشاهد كتبها المالك بنفسه (بدون Gemini)
        result = [Scene(str(x["prompt"]), str(x.get("narration", ""))) for x in scenes]
    else:
        if not api_key:
            raise RuntimeError("لا يوجد مفتاح Gemini. أضفه في Kaggle Secrets باسم GEMINI_API_KEY.")
        result = plan_scenes(s, api_key)
    plan.write_text(json.dumps({"idea": s.idea, "seconds": s.seconds,
                                "scenes": [asdict(x) for x in result]},
                               ensure_ascii=False, indent=2), encoding="utf-8")
    return result


def run(s: Settings, api_key: str | None = None, maker: ClipMaker | None = None,
        scenes: list[dict] | None = None, log: Callable[[str], None] = print) -> Path:
    work = Path(s.work_dir)
    work.mkdir(parents=True, exist_ok=True)
    if not shutil.which("ffmpeg"):
        raise RuntimeError("ffmpeg غير مثبت.")

    log(f"١) السيناريو: {s.scene_count} مشاهد لفيديو {s.seconds} ثانية…")
    sc = load_or_plan(s, work, api_key, scenes)
    for i, x in enumerate(sc, 1):
        log(f"   {i}. {x.narration}")

    if s.voice:
        log("٢) التعليق الصوتي…")
        voices = make_voices(sc, work, s.voice)
    else:
        log("٢) بدون تعليق صوتي.")
        voices = [None] * len(sc)

    log("٣) توليد المقاطع (هذه المرحلة الطويلة)…")
    loaded: list[ClipMaker] = []

    def lazy(scene: Scene, index: int, out: Path) -> None:
        if not loaded:  # لا نحمّل Wan إلا إذا بقي مشهد لم يُولَّد
            log("   تحميل نموذج Wan (أول مرة قد تأخذ 10 دقائق)…")
            loaded.append(maker or wan_clip_maker(s))
        loaded[0](scene, index, out)

    clips = make_clips(sc, work, lazy, log)

    log("٤) جمع الفيديو…")
    final = assemble(clips, voices, work, s.fps)
    log(f"تم: {final} ({media_duration(final):.0f} ثانية)")
    return final
