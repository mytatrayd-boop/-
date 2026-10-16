#!/usr/bin/env python3
"""T0b listening comparison (D29 amendment): the same 4 paragraphs in 4 variants.

  A = MMS ara as is            B = CATT diacritizer, then MMS
  C = piper ar_JO-SA_miro-high D = CATT, then miro

Writes p1_A.wav .. p4_D.wav and texts.txt (exact source text, TTS input, and
CATT output per paragraph). CATT runs from its official ONNX export (ED model);
the same model is also quantized to int8 here to check on-device size and that
the int8 output stays close.

Usage: compare_tts.py MMS_DIR MIRO_DIR CATT_ED_DIR BOOKS_DIR OUT_DIR
"""

import gzip
import json
import os
import re
import sys
import time

import sherpa_onnx
import soundfile as sf
from catt_tashkeel import CATTEncoderDecoder
from onnxruntime.quantization import QuantType, quantize_dynamic

# 2 prose + 2 verse, by stable paragraph id (library/books/*/<book>.v1.json.gz).
PARAGRAPHS = [
    ("p1", "kalila-b002-p00005"),  # prose
    ("p2", "uyun-b001-p00004"),  # prose
    ("p3", "bayan-b001-p00026"),  # verse
    ("p4", "kamil-b001-p00075"),  # verse
]
HARAKAT = set(chr(c) for c in range(0x064B, 0x0653))
# What CATT keeps (its remove_non_arabic); everything else is kept verbatim.
ARABIC_RUN = re.compile("[ء-غف-ي]+(?: +[ء-غف-ي]+)*")


def load_paragraph(books_dir, pid):
    book = pid.split("-")[0]
    with gzip.open(os.path.join(books_dir, book, f"{book}.v1.json.gz"), "rt", encoding="utf-8") as f:
        for ch in json.load(f)["chapters"]:
            for p in ch["paragraphs"]:
                if p["id"] == pid:
                    return p["text"]
    sys.exit(f"::error::paragraph {pid} not found")


def tts_input(text):
    # Verse: hemistich tab -> comma pause, line break -> full stop.
    return text.replace("\t", "، ").replace("\n", ". ")


def diacritize(model, text):
    # CATT drops punctuation; diacritize each Arabic run and keep the rest as is.
    runs = ARABIC_RUN.findall(text)
    out = iter(model.do_tashkeel_batch(runs, verbose=False))
    return ARABIC_RUN.sub(lambda m: next(out), text)


def tts(model_path, tokens, data_dir=""):
    cfg = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                model=model_path, lexicon="", tokens=tokens, data_dir=data_dir
            ),
            num_threads=2,
        ),
    )
    if not cfg.validate():
        sys.exit(f"::error::invalid sherpa-onnx config for {model_path}")
    return sherpa_onnx.OfflineTts(cfg)


def token_set(path):
    with open(path, encoding="utf-8") as f:
        return {line.rstrip("\n").rpartition(" ")[0] for line in f}


def mb(path):
    return os.path.getsize(path) / 1e6


def main():
    mms_dir, miro_dir, catt_dir, books_dir, out = sys.argv[1:6]
    os.makedirs(out, exist_ok=True)

    enc, dec = os.path.join(catt_dir, "encoder.onnx"), os.path.join(catt_dir, "decoder.onnx")
    catt = CATTEncoderDecoder(encoder_path=enc, decoder_path=dec)
    q_dir = os.path.join(catt_dir, "int8")
    os.makedirs(q_dir, exist_ok=True)
    for name in ("encoder", "decoder"):
        quantize_dynamic(os.path.join(catt_dir, f"{name}.onnx"), os.path.join(q_dir, f"{name}.onnx"),
                         weight_type=QuantType.QInt8)
    catt_q = CATTEncoderDecoder(encoder_path=os.path.join(q_dir, "encoder.onnx"),
                                decoder_path=os.path.join(q_dir, "decoder.onnx"))
    fp32 = mb(enc) + mb(dec)
    int8 = mb(os.path.join(q_dir, "encoder.onnx")) + mb(os.path.join(q_dir, "decoder.onnx"))
    print(f"CATT ED ONNX: fp32 {fp32:.1f} MB, int8 {int8:.1f} MB (encoder+decoder)")

    voices = {
        "MMS": (tts(os.path.join(mms_dir, "model.int8.onnx"), os.path.join(mms_dir, "tokens.txt")),
                token_set(os.path.join(mms_dir, "tokens.txt"))),
        "miro": (tts(os.path.join(miro_dir, "ar_JO-SA_miro-high.onnx"), os.path.join(miro_dir, "tokens.txt"),
                     os.path.join(miro_dir, "espeak-ng-data")), None),
    }
    mms_harakat = sorted(HARAKAT & voices["MMS"][1])
    print(f"MMS tokens.txt harakat: {len(mms_harakat)} of 8 {' '.join(f'U+{ord(h):04X}' for h in mms_harakat)}")

    lines = [
        "Adeeb voice comparison (D29 amendment). Same text, 4 variants:",
        "A = MMS ara as is | B = CATT then MMS | C = piper ar_JO-SA_miro-high | D = CATT then miro",
        f"CATT = abjadai/catt ED model, official ONNX (fp32 {fp32:.1f} MB; int8 {int8:.1f} MB).",
        f"MMS tokens.txt has {len(mms_harakat)} of 8 harakat; harakat not in it are skipped by MMS in B.",
        "",
    ]
    for key, pid in PARAGRAPHS:
        src = load_paragraph(books_dir, pid)
        plain = tts_input(src)
        t = time.time()
        dia = diacritize(catt, plain)
        catt_s = time.time() - t
        dia_q = diacritize(catt_q, plain)
        same = sum(a == b for a, b in zip(dia, dia_q)) / max(len(dia), len(dia_q))
        print(f"{key} {pid}: CATT fp32 {catt_s:.2f} s (CI CPU); int8 vs fp32 char agreement {same:.1%}")
        lines += [
            f"[{key}] {pid}",
            f"source text (exact):\n{src}",
            f"TTS input, plain (A, C):\n{plain}",
            f"TTS input, CATT diacritized (B, D):\n{dia}",
            f"CATT int8 output (for comparison only, not spoken; {same:.1%} same as fp32):\n{dia_q}",
            "",
        ]
        for variant, voice, text in (("A", "MMS", plain), ("B", "MMS", dia), ("C", "miro", plain), ("D", "miro", dia)):
            engine = voices[voice][0]
            t = time.time()
            audio = engine.generate(text, sid=0, speed=1.0)
            gen = time.time() - t
            secs = len(audio.samples) / audio.sample_rate
            if secs < 0.5:
                sys.exit(f"::error::{key}_{variant}: no audio generated ({secs:.2f} s)")
            sf.write(os.path.join(out, f"{key}_{variant}.wav"), audio.samples, audio.sample_rate)
            print(f"  {key}_{variant}.wav ({voice}): {secs:.1f} s audio, RTF {gen / secs:.3f} (CI CPU)")
    with open(os.path.join(out, "texts.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
