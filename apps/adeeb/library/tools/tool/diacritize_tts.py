#!/usr/bin/env python3
"""Speech-only diacritized text (`tts`) for book paragraphs, with CATT (ED model).

CATT = abjadai/catt (Apache-2.0), official ONNX export, run via catt-tashkeel.
Display, search and quotes keep `text`; `tts` is used only by the audio chunker.

Rules (the library validator checks the result):
- Only Arabic words are changed, and only by adding harakat; every other
  character (punctuation, digits, spaces, \\t and \\n in verse) is kept verbatim.
- A word that already has harakat, tatweel or dagger alef in the source is kept
  as is (the source's own tashkeel wins).
- CATT sees maximal stretches of words separated by single spaces (punctuation
  breaks a stretch, as in voice_lab/tools/compare_tts.py), cut into windows of
  at most WINDOW_CHARS characters (the ED decoder is quadratic in length).
- If CATT's output for a word does not strip back to the same letters, the word
  stays bare. So strip_diacritics(tts) == strip_diacritics(text) always holds.

Usage:
  diacritize_tts.py CATT_ED_DIR LIBRARY_DIR OUT_JSON [--shard I --shards N] [--limit K]
    Diacritizes paragraph I, I+N, I+2N, ... (over all books' latest version,
    in book-id then paragraph order) and writes {paragraph_id: tts} to OUT_JSON.
    A paragraph whose tts would equal its text is omitted.
"""

import argparse
import gzip
import json
import os
import re
import sys
import time
import unicodedata

WINDOW_CHARS = 120
BATCH = 32
LETTERS = "ء-غف-ي"
MARKS = "ـً-ْٰ"  # tatweel, harakat, dagger alef
WORD = re.compile(f"[{LETTERS}{MARKS}]+")
STRIP = re.compile(f"[{MARKS}]")
BARE = re.compile(f"^[{LETTERS}]+$")


def strip_diacritics(s):
    return STRIP.sub("", s)


def latest_books(library_dir):
    books_dir = os.path.join(library_dir, "books")
    for book_id in sorted(os.listdir(books_dir)):
        best, best_v = None, -1
        for name in os.listdir(os.path.join(books_dir, book_id)):
            m = re.fullmatch(rf"{re.escape(book_id)}\.v(\d+)\.json\.gz", name)
            if m and int(m[1]) > best_v:
                best, best_v = name, int(m[1])
        if best:
            yield os.path.join(books_dir, book_id, best)


def paragraphs(library_dir):
    for path in latest_books(library_dir):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            book = json.load(f)
        for ch in book["chapters"]:
            for p in ch["paragraphs"]:
                yield p["id"], p["text"]


def plan(text):
    """Word matches and the CATT windows: lists of indexes into the matches."""
    words = list(WORD.finditer(text))
    windows, cur, cur_len = [], [], 0
    for i, m in enumerate(words):
        joined_by_space = i > 0 and text[words[i - 1].end():m.start()] == " "
        if cur and (not joined_by_space or cur_len + 1 + len(m[0]) > WINDOW_CHARS):
            windows.append(cur)
            cur, cur_len = [], 0
        cur.append(i)
        cur_len += len(m[0]) + (1 if cur_len else 0)
    if cur:
        windows.append(cur)
    return words, windows


def build_tts(text, words, windows, outputs):
    """outputs[w] = CATT output for window w. Returns the diacritized paragraph."""
    replaced = {}
    for idx, out in zip(windows, outputs):
        out_words = out.split(" ")
        if len(out_words) != len(idx):
            continue  # misaligned: the whole window stays bare
        for i, ow in zip(idx, out_words):
            src = words[i][0]
            if BARE.match(src) and strip_diacritics(ow) == src:
                replaced[i] = ow
    parts, pos = [], 0
    for i, m in enumerate(words):
        parts += [text[pos:m.start()], replaced.get(i, m[0])]
        pos = m.end()
    parts.append(text[pos:])
    tts = unicodedata.normalize("NFC", "".join(parts))
    if strip_diacritics(tts) != strip_diacritics(text):
        raise AssertionError("tts letters differ from text")
    return tts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("catt_dir")
    ap.add_argument("library_dir")
    ap.add_argument("out_json")
    ap.add_argument("--shard", type=int, default=0)
    ap.add_argument("--shards", type=int, default=1)
    ap.add_argument("--limit", type=int, default=0, help="first K paragraphs of the shard (benchmark)")
    a = ap.parse_args()

    from catt_tashkeel import CATTEncoderDecoder

    catt = CATTEncoderDecoder(encoder_path=os.path.join(a.catt_dir, "encoder.onnx"),
                              decoder_path=os.path.join(a.catt_dir, "decoder.onnx"))
    todo = [p for n, p in enumerate(paragraphs(a.library_dir)) if n % a.shards == a.shard]
    if a.limit:
        todo = todo[:a.limit]

    planned, inputs = [], []
    for pid, text in todo:
        words, windows = plan(text)
        planned.append((pid, text, words, windows, len(inputs)))
        for idx in windows:
            # Words with source marks are fed bare (context only; they are kept as is).
            inputs.append(" ".join(strip_diacritics(words[i][0]) for i in idx))

    # Sort by length so each batch pads little; the order does not change results.
    order = sorted(range(len(inputs)), key=lambda k: len(inputs[k]))
    outputs = [None] * len(inputs)
    t0, chars = time.time(), sum(map(len, inputs))
    for b in range(0, len(order), BATCH):
        ks = order[b:b + BATCH]
        for k, out in zip(ks, catt.do_tashkeel_batch([inputs[k] for k in ks], batch_size=BATCH, verbose=False)):
            outputs[k] = out
        if (b // BATCH) % 50 == 0:
            print(f"  {b + len(ks)}/{len(inputs)} windows, {time.time() - t0:.0f} s", flush=True)

    result = {}
    for pid, text, words, windows, start in planned:
        tts = build_tts(text, words, windows, outputs[start:start + len(windows)])
        if tts != text:
            result[pid] = tts
    with open(a.out_json, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, sort_keys=True, indent=0)
    secs = time.time() - t0
    print(f"shard {a.shard}/{a.shards}: {len(todo)} paragraphs, {len(inputs)} windows, {chars} chars, "
          f"{len(result)} with tts, {secs:.0f} s ({chars / max(secs, 1e-9):.0f} chars/s)")


if __name__ == "__main__":
    sys.exit(main())
