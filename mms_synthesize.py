#!/usr/bin/env python3
"""
Batch-synthesize Assamese speech using Meta MMS TTS (facebook/mms-tts-asm).

Reads a manifest CSV produced by prepare_manifest.py and writes two WAV files
per row: the full carrier sentence and the isolated target word.

Usage
-----
    python mms_synthesize.py \
        --manifest mms_pilot_manifest.csv \
        --out_dir outputs/mmstts

GPU (optional):
    python mms_synthesize.py --manifest ... --out_dir ... --device cuda:0

Dependencies: transformers>=4.33, torch, soundfile, tqdm
License note: MMS-TTS weights are released under CC-BY-NC 4.0.
"""

import argparse
import csv
from pathlib import Path

import torch
import soundfile as sf
from tqdm import tqdm
from transformers import VitsModel, AutoTokenizer


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest",  required=True,
                    help="CSV with columns: utt_id, variant, carrier_text, target_word")
    ap.add_argument("--out_dir",   required=True,
                    help="Root directory for output WAV files")
    ap.add_argument("--model_id",  default="facebook/mms-tts-asm",
                    help="HuggingFace model ID")
    ap.add_argument("--device",    default="cpu",
                    help="Torch device string, e.g. cpu or cuda:0")
    ap.add_argument("--dtype",     default="float32",
                    choices=["float32", "float16", "bfloat16"])
    ap.add_argument("--max_chars", type=int, default=400,
                    help="Skip utterances longer than this many characters")
    ap.add_argument("--seed",      type=int, default=0)
    return ap.parse_args()


def read_manifest(path):
    with open(path, encoding="utf-8") as f:
        sample = f.read(2048)
        f.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample, delimiters=[",", "\t", ";", "|"])
            reader = csv.DictReader(f, dialect=dialect)
        except csv.Error:
            f.seek(0)
            reader = csv.DictReader(f)
        return list(reader)


def synthesize(model, tokenizer, text, device):
    inputs = tokenizer(text, return_tensors="pt")
    inputs = {k: v.to(device) for k, v in inputs.items()}
    with torch.no_grad():
        wav = model(**inputs).waveform
    return wav.squeeze().detach().cpu().float().numpy()


def main():
    args = parse_args()
    torch.manual_seed(args.seed)

    dtype_map = {"float32": torch.float32, "float16": torch.float16,
                 "bfloat16": torch.bfloat16}
    device = torch.device(args.device)

    rows = read_manifest(args.manifest)

    cols = set().union(*(r.keys() for r in rows))
    if "text" not in cols and "carrier_text" in cols:
        for r in rows:
            r["text"] = r.get("carrier_text", "")

    usable = [r for r in rows if (r.get("text") or "").strip()]
    skipped_long = sum(1 for r in usable if len(r["text"]) > args.max_chars)

    print(f"Manifest rows: {len(rows)} total, {len(usable)} with text, "
          f"{skipped_long} over {args.max_chars}-char limit")

    if not usable:
        raise SystemExit("No usable rows found. Check your manifest.")

    tokenizer = AutoTokenizer.from_pretrained(args.model_id)
    model = VitsModel.from_pretrained(args.model_id)
    model = model.to(device=device, dtype=dtype_map[args.dtype])
    model.eval()

    sr = getattr(model.config, "sampling_rate", 16000)
    out_root = Path(args.out_dir)
    out_root.mkdir(parents=True, exist_ok=True)

    for idx, r in enumerate(tqdm(rows, desc="Synthesizing")):
        carrier = (r.get("carrier_text") or r.get("text") or "").strip()
        target  = (r.get("target_word") or "").strip()

        if not carrier or len(carrier) > args.max_chars:
            continue

        utt_id  = r.get("utt_id") or r.get("utt") or f"row{idx:04d}"
        variant = r.get("variant", "orig")

        carrier_dir = out_root / f"{variant}_carrier"
        carrier_dir.mkdir(parents=True, exist_ok=True)
        wav = synthesize(model, tokenizer, carrier, device)
        sf.write(carrier_dir / f"{utt_id}.wav", wav, sr, subtype="PCM_16")

        if target:
            target_dir = out_root / f"{variant}_target"
            target_dir.mkdir(parents=True, exist_ok=True)
            wav_t = synthesize(model, tokenizer, target, device)
            sf.write(target_dir / f"{utt_id}.wav", wav_t, sr, subtype="PCM_16")


if __name__ == "__main__":
    main()
