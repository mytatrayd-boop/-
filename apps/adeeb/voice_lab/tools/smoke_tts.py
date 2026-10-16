#!/usr/bin/env python3
"""T0 CI smoke test: load model.int8.onnx in sherpa-onnx, speak one prose and
one verse paragraph from library/books, write WAVs and print RTF (CI CPU, not
the owner's phone).

Usage: smoke_tts.py MODEL_DIR BOOKS_DIR OUT_DIR
"""

import glob
import gzip
import json
import os
import sys
import time

import sherpa_onnx
import soundfile as sf


def first_paragraphs(books_dir):
    prose = verse = None
    for path in sorted(glob.glob(os.path.join(books_dir, "*", "*.json.gz"))):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            book = json.load(f)
        for ch in book["chapters"]:
            for p in ch["paragraphs"]:
                kind = p.get("kind", "prose")
                if kind == "prose" and prose is None and 40 < len(p["text"]) <= 300:
                    prose = p["text"]
                if kind == "verse" and verse is None:
                    verse = p["text"].split("\n")[0].replace("\t", " ")
        if prose and verse:
            break
    return [("prose", prose), ("verse", verse)]


def main():
    model_dir, books_dir, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    cfg = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                model=os.path.join(model_dir, "model.int8.onnx"),
                lexicon="",
                tokens=os.path.join(model_dir, "tokens.txt"),
            ),
            num_threads=2,
        ),
    )
    if not cfg.validate():
        sys.exit("::error::invalid sherpa-onnx config")
    t = time.time()
    tts = sherpa_onnx.OfflineTts(cfg)
    print(f"model load: {time.time() - t:.2f} s")
    for name, text in first_paragraphs(books_dir):
        if not text:
            continue
        t = time.time()
        audio = tts.generate(text, sid=0, speed=1.0)
        gen = time.time() - t
        secs = len(audio.samples) / audio.sample_rate
        if secs < 0.5:
            sys.exit(f"::error::{name}: no audio generated ({secs:.2f} s)")
        sf.write(os.path.join(out, f"{name}.wav"), audio.samples, audio.sample_rate)
        print(f"{name}: {len(text)} chars, {secs:.2f} s audio, RTF {gen / secs:.3f} (CI CPU)")
        with open(os.path.join(out, f"{name}.txt"), "w", encoding="utf-8") as f:
            f.write(text + "\n")


if __name__ == "__main__":
    main()
