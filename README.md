# Towards a Phonology-Informed Evaluation of Multilingual TTS

We propose a classifier-based framework that audits TTS output against
language-specific phonological patterns using human speech as a benchmark. The
test case is Assamese advanced tongue root (ATR) vowel harmony evaluated against Meta's MMS TTS
(`facebook/mms-tts-asm`).

---

## Overview

The pipeline has the following stages, each implemented as a standalone script:

```
1. mms_synthesize.py     — batch-synthesize speech with MMS TTS
   └── FormantPro.praat  — extract formants in Praat (manual step)
4. task1_crossdomain.py  — Task 1: vowel-level ATR classification (Table 2)
5. task2_pipeline.py     — Task 2: faithfulness audit + harmony classification (Tables 3–4)
   spectrogram.py        — reproduce spectrogram panel (Fig 3 inset)
```

---

## Requirements

```bash
pip install -r requirements.txt
```

`spectrogram.py` additionally requires [Praat](https://www.praat.org/) to be
installed on your system (used internally by `praat-parselmouth`).

Tested with Python 3.9–3.11.

---

## Data

Human recordings were collected from 14 adult native speakers of Assamese
(upper Assam region). Due to speaker privacy, raw audio is not redistributed.
A sample of the formant measurements extracted from those recordings
(`human_formant_output_merged.xlsx`) are available in the data release
accompanying the paper.

The TTS formant log (`mms_formantlog_merged.xlsx`) and the stimulus word list
(`assamese_tts_pilot_stimuli.csv`) are also included in the data release.

---

## Reproducing the results

### Step 0 — install dependencies

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### Step 1 — synthesize TTS audio (optional; skip if using the provided formant log)

```bash
python prepare_manifest.py \
    --stimuli assamese_tts_pilot_stimuli.csv \
    --outdir  outputs \
    --manifest mms_pilot_manifest.csv

python mms_synthesize.py \
    --manifest mms_pilot_manifest.csv \
    --out_dir  outputs/mmstts
```

### Step 2 — formant extraction in Praat (manual)

Open Praat, load `FormantPro.praat`, and run it on the synthesized WAV files.
Save the output as `mms_formantlog_merged.xlsx`. The same script was used for
the human recordings. Outlier bounds applied downstream:
F1 150–1200 Hz, F2 500–3500 Hz, F3 1500–4500 Hz, B1 ≤ 400 Hz.

<!-- 
### Step 3 — merge harmony labels

```bash
python merge_harmonytype.py \
    --stimuli assamese_tts_pilot_stimuli.csv \
    --human   human_formant_output_merged.xlsx \
    --tts     mms_formantlog_merged.xlsx \
    --out_dir .
```

Outputs: `human_formant_with_harmony.xlsx`, `tts_formant_with_harmony.xlsx`.-->


### Step 3 — Task 1: cross-domain ATR classification

```bash
python task1_crossdomain.py \
    --human human_formant_with_harmony.xlsx \
    --tts   tts_formant_with_harmony.xlsx
```

<!-- Prints Table 2 (Acc and macro F1 for all four transfer directions, LR and RF).-->


### Step 4 — Task 2: faithfulness audit + harmony classification

```bash
python task2_pipeline.py \
    --human   human_formant_with_harmony.xlsx \
    --tts     tts_formant_with_harmony.xlsx \
    --out_dir .
```

<!-- 
Prints Tables 3 and 4. Saves `human_word_features.xlsx`,
`tts_word_features.xlsx`, and `task2_results.xlsx`.-->


For the spectrogram panel (Figure 3 inset), provide matching WAV and TextGrid
files:

```bash
python spectrogram.py \
    --wav  wave_spect_figs/mms_leteku.wav \
    --tg   wave_spect_figs/mms_leteku.TextGrid \
    --tier segments \
    --out  figures/mms_leteku_zoomed
```

---

## Adapting to other phonological contrasts

The framework generalises to any contrast with measurable acoustic correlates
and a human baseline. The minimum required changes are:

1. Replace the binary ATR label column with your target feature.
2. Update the feature columns in `task1_crossdomain.py` and `task2_pipeline.py`
   (`FEAT_TASK1`, `FEAT_NORM`).
3. Adjust the outlier bounds to match the formant range of your language.
4. Provide a new stimuli CSV and formant log in the same column format.

