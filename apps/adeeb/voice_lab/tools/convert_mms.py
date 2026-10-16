#!/usr/bin/env python3
"""T0: convert an MMS-TTS VITS checkpoint to a sherpa-onnx model (int8).

Same recipe as sherpa-onnx's own vits-mms.py (shipped inside its published
vits-mms-* models), but with the original VITS code (jaywalnut310/vits) and
a hard gate: tokens.txt must be Arabic script (ARCHITECTURE §17.4, D29).

Usage:
  convert_mms.py --src DIR --vits DIR --out DIR   # full conversion
  convert_mms.py --check-tokens tokens.txt        # gate only

--src holds G_100000.pth, config.json, vocab.txt from
https://huggingface.co/facebook/mms-tts/tree/main/models/ara
"""

import argparse
import collections
import os
import sys

# Arabic letters U+0621..U+064A (hamza .. yeh) minus tatweel.
ARABIC_LETTERS = {chr(c) for c in range(0x0621, 0x064B) if c != 0x0640}
MIN_ARABIC_LETTERS = 28


def fail(msg):
    print(f"::error::{msg}", flush=True)
    sys.exit(1)


def check_tokens(path):
    tokens = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            # "<token> <id>"; the token itself may be a space.
            tok, _, _ = line.rpartition(" ")
            tokens.append(tok)
    arabic = sorted({t for t in tokens if t in ARABIC_LETTERS})
    latin = sorted({t for t in tokens if len(t) == 1 and t.isascii() and t.isalpha()})
    print(f"tokens: {len(tokens)}; Arabic letters: {len(arabic)} {''.join(arabic)}")
    print(f"Latin letters: {len(latin)} {''.join(latin)}")
    if len(arabic) < MIN_ARABIC_LETTERS or len(latin) > len(arabic):
        fail(
            f"tokens.txt is not Arabic script ({len(arabic)} Arabic letters, "
            f"{len(latin)} Latin). The model needs romanization: T0 fails, "
            "switch to the fallback voice (D29)."
        )
    if latin:
        print(f"::warning::tokens.txt also has Latin letters: {''.join(latin)}")
    print("tokens.txt gate: PASS (Arabic script)")


def write_tokens(symbols, path):
    # Same as sherpa-onnx vits-mms.py: upper case maps to the same id.
    upper = [s.upper() for s in symbols]
    dup = {k for k, n in collections.Counter(upper).items() if n > 1}
    with open(path, "w", encoding="utf-8") as f:
        for i, tok in enumerate(symbols):
            f.write(f"{tok} {i}\n")
            if tok.lower() != tok.upper() and len(tok.upper()) == 1 and tok.upper() not in dup:
                f.write(f"{tok.upper()} {i}\n")


def add_meta(path, meta):
    import onnx

    model = onnx.load(path)
    existing = {p.key for p in model.metadata_props}
    for k, v in meta.items():
        if k not in existing:
            p = model.metadata_props.add()
            p.key, p.value = k, str(v)
    onnx.save(model, path)


def convert(src, vits_dir, out):
    import torch

    sys.path.insert(0, vits_dir)
    import utils  # noqa: E402  (from vits)
    from models import SynthesizerTrn  # noqa: E402

    os.makedirs(out, exist_ok=True)
    hps = utils.get_hparams_from_file(os.path.join(src, "config.json"))
    if str(hps.data.training_files).split(".")[-1] == "uroman":
        fail("config.json says the model is trained on uroman (Latin) text.")

    with open(os.path.join(src, "vocab.txt"), encoding="utf-8") as f:
        symbols = [x.replace("\n", "") for x in f.readlines()]
    tokens = os.path.join(out, "tokens.txt")
    write_tokens(symbols, tokens)
    check_tokens(tokens)  # fail before spending time on export

    net = SynthesizerTrn(
        len(symbols),
        hps.data.filter_length // 2 + 1,
        hps.train.segment_size // hps.data.hop_length,
        **hps.model,
    )
    ckpt = torch.load(os.path.join(src, "G_100000.pth"), map_location="cpu")
    state = ckpt.get("model", ckpt)
    missing, unexpected = net.load_state_dict(state, strict=False)
    missing = [k for k in missing if not k.startswith("enc_q.")]
    if missing:
        fail(f"checkpoint is missing {len(missing)} weights, e.g. {missing[:5]}")
    print(f"loaded checkpoint; unexpected keys ignored: {len(unexpected)}")
    net.eval()

    class OnnxModel(torch.nn.Module):
        def __init__(self, m):
            super().__init__()
            self.m = m

        def forward(self, x, x_lengths, noise_scale, length_scale, noise_scale_w):
            return self.m.infer(
                x=x,
                x_lengths=x_lengths,
                noise_scale=noise_scale,
                length_scale=length_scale,
                noise_scale_w=noise_scale_w,
            )[0]

    x = torch.randint(low=1, high=10, size=(1, 50), dtype=torch.int64)
    args = (
        x,
        torch.tensor([50], dtype=torch.int64),
        torch.tensor([1.0]),
        torch.tensor([1.0]),
        torch.tensor([1.0]),
    )
    fp32 = os.path.join(out, "model.onnx")
    with torch.no_grad():
        torch.onnx.export(
            OnnxModel(net),
            args,
            fp32,
            opset_version=13,
            input_names=["x", "x_length", "noise_scale", "length_scale", "noise_scale_w"],
            output_names=["y"],
            dynamic_axes={"x": {0: "N", 1: "L"}, "x_length": {0: "N"}, "y": {0: "N", 2: "L"}},
        )
    meta = {
        "model_type": "vits",
        "comment": "mms",
        "url": "https://huggingface.co/facebook/mms-tts/tree/main/models/ara",
        "add_blank": int(hps.data.add_blank),
        "language": "Arabic",
        "frontend": "characters",
        "n_speakers": int(hps.data.n_speakers),
        "sample_rate": hps.data.sampling_rate,
    }
    print("meta_data", meta)
    add_meta(fp32, meta)
    quantize(fp32, os.path.join(out, "model.int8.onnx"), meta)


def quantize(fp32, int8, meta):
    from onnxruntime.quantization import QuantType, quantize_dynamic

    quantize_dynamic(fp32, int8, weight_type=QuantType.QUInt8)
    add_meta(int8, meta)  # keep sherpa-onnx metadata on the int8 file
    for p in (fp32, int8):
        print(f"{os.path.basename(p)}: {os.path.getsize(p) / 1e6:.1f} MB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src")
    ap.add_argument("--vits")
    ap.add_argument("--out")
    ap.add_argument("--check-tokens")
    ap.add_argument("--quantize-only", help="fp32 onnx to quantize (local test)")
    a = ap.parse_args()
    if a.check_tokens:
        check_tokens(a.check_tokens)
    elif a.quantize_only:
        quantize(a.quantize_only, os.path.join(a.out, "model.int8.onnx"), {})
    else:
        if not (a.src and a.vits and a.out):
            ap.error("--src, --vits and --out are required")
        convert(a.src, a.vits, a.out)


if __name__ == "__main__":
    main()
