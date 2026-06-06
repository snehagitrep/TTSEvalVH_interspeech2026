#!/usr/bin/env python3
"""
Generate waveform + spectrogram PDFs with F1 overlay (Figure 3 panel).

Produces two PDFs for a given WAV + TextGrid pair:
  <prefix>_signal.pdf   — waveform with vowel boundary markers
  <prefix>_spectgm.pdf  — spectrogram (0–1500 Hz) with F1 track and ATR boundary

The y-axis is cropped to 0–1500 Hz to keep the F1/F2 region clearly visible.
The dashed white line marks the +ATR/–ATR F1 boundary estimated from the human
corpus; its value should be described in the figure caption, not on the figure.

Usage
-----
    python spectrogram.py \
        --wav   wave_spect_figs/mms_leteku.wav \
        --tg    wave_spect_figs/mms_leteku.TextGrid \
        --tier  segments \
        --out   figures/mms_leteku_zoomed

Dependencies: numpy, matplotlib, scipy, tgt, praat-parselmouth
"""

import argparse
import os

import numpy as np
import matplotlib.pyplot as plt
from scipy.io import wavfile
from scipy.signal import spectrogram as scipy_spectrogram
import tgt
import parselmouth
from parselmouth.praat import call


ATR_F1_BOUNDARY = 525   # Hz — midpoint between +ATR and –ATR mid vowels (human corpus)
MAX_FREQ        = 1500  # Hz — crop spectrogram y-axis here


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wav",  required=True, help="Input WAV file")
    ap.add_argument("--tg",   required=True, help="Praat TextGrid file")
    ap.add_argument("--tier", default="segments",
                    help="TextGrid tier containing vowel intervals")
    ap.add_argument("--out",  required=True,
                    help="Output path prefix (without extension)")
    return ap.parse_args()


VOWEL_CHARS = set("ieɛɑɔouʊ")


def is_vowel(label):
    return bool(label and label[0].lower() in VOWEL_CHARS)


def load_segments(tg_path, tier_name):
    tg   = tgt.io.read_textgrid(tg_path)
    tier = tg.get_tier_by_name(tier_name)
    return [(iv.start_time, iv.end_time, iv.text.strip())
            for iv in tier.intervals if iv.text.strip()]


def extract_f1(wav_path, start, end,
               time_step=0.005, max_formant=5500,
               num_formants=5, window_length=0.015):
    snd     = parselmouth.Sound(wav_path)
    segment = snd.extract_part(from_time=start, to_time=end, preserve_times=True)
    formant = call(segment, "To Formant (burg)...",
                   time_step, num_formants, max_formant, window_length, 50)
    n = call(formant, "Get number of frames")
    times, f1s = [], []
    for i in range(1, n + 1):
        t  = call(formant, "Get time from frame number...", i)
        f1 = call(formant, "Get value at time...", 1, t, "Hertz", "Linear")
        times.append(t)
        f1s.append(f1 if f1 != 0 else np.nan)
    return np.array(times), np.array(f1s)


def plot_waveform(wav_path, segments, out_path):
    sr, data = wavfile.read(wav_path)
    if data.ndim > 1:
        data = data[:, 0]
    data     = data.astype(np.float64) / np.max(np.abs(data))
    duration = len(data) / sr
    time     = np.linspace(0, duration, len(data))

    fig, ax = plt.subplots(figsize=(6, 1.2))
    ax.plot(time, data, color="#1f77b4", linewidth=0.4)
    ax.set_xlim(0, duration)
    ax.set_ylim(-1.1, 1.1)

    for start, end, label in segments:
        if is_vowel(label):
            for x in (start, end):
                ax.axvline(x=x, color="red", linestyle="--",
                           linewidth=0.8, alpha=0.7)
            ax.text((start + end) / 2, 0.85, label,
                    ha="center", va="bottom", fontsize=8,
                    color="red", fontweight="bold")

    ax.set_ylabel("Amplitude", fontsize=7)
    ax.tick_params(labelsize=6)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    plt.tight_layout(pad=0.3)
    fig.savefig(out_path, format="pdf", bbox_inches="tight", dpi=300)
    plt.close(fig)
    print(f"Saved waveform: {out_path}")


def plot_spectrogram(wav_path, segments, out_path, max_freq=MAX_FREQ):
    sr, data = wavfile.read(wav_path)
    if data.ndim > 1:
        data = data[:, 0]
    data     = data.astype(np.float64)
    duration = len(data) / sr

    nperseg  = int(sr * 0.005)
    noverlap = int(sr * 0.0025)
    freqs, times, Sxx = scipy_spectrogram(data, fs=sr, nperseg=nperseg,
                                           noverlap=noverlap, window="hamming")
    Sxx_db = 10 * np.log10(Sxx + 1e-10)
    vmax   = Sxx_db.max()

    fig, ax = plt.subplots(figsize=(6, 3))
    ax.pcolormesh(times, freqs, Sxx_db, shading="gouraud",
                  cmap="Blues", vmin=vmax - 60, vmax=vmax)
    ax.set_ylim(0, max_freq)
    ax.set_xlim(0, duration)

    for start, end, label in segments:
        if is_vowel(label):
            for x in (start, end):
                ax.axvline(x=x, color="red", linestyle="--",
                           linewidth=0.8, alpha=0.7)
            ax.text((start + end) / 2, max_freq * 0.90, label,
                    ha="center", va="bottom", fontsize=9,
                    color="red", fontweight="bold")

            try:
                t_f1, f1 = extract_f1(wav_path, start, end)
                valid = ~np.isnan(f1) & (f1 > 100) & (f1 < 1200)
                if np.any(valid):
                    ax.plot(t_f1[valid], f1[valid],
                            color="yellow", linewidth=1.0, alpha=0.85, zorder=5)
                    mid = len(f1[valid]) // 2
                    ax.plot(t_f1[valid][mid], f1[valid][mid],
                            "o", color="yellow", markersize=3, zorder=6,
                            markeredgecolor="black", markeredgewidth=0.4)
            except Exception as exc:
                print(f"  Warning ({label} {start:.3f}–{end:.3f}s): {exc}")

    ax.axhline(y=ATR_F1_BOUNDARY, color="white", linestyle="--",
               linewidth=0.7, alpha=0.6, zorder=4)

    ax.set_ylabel("Frequency (Hz)", fontsize=8)
    ax.set_xlabel("Time (s)", fontsize=8)
    ax.tick_params(labelsize=7)
    ax.set_yticks([0, 250, 500, 750, 1000, 1250, 1500])
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    plt.tight_layout(pad=0.3)
    fig.savefig(out_path, format="pdf", bbox_inches="tight", dpi=300)
    plt.close(fig)
    print(f"Saved spectrogram: {out_path}")


def main():
    args = parse_args()
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    segments = load_segments(args.tg, args.tier)
    print(f"Loaded {len(segments)} segments from tier '{args.tier}'")
    plot_waveform(args.wav, segments, f"{args.out}_signal.pdf")
    plot_spectrogram(args.wav, segments, f"{args.out}_spectgm.pdf")


if __name__ == "__main__":
    main()
