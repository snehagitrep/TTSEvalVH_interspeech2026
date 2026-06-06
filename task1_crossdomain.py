#!/usr/bin/env python3
"""
Task 1: Cross-domain ATR vowel classification (Table 2 in the paper).

Trains logistic regression (LR) and random forest (RF) classifiers on
Lobanov-normalised acoustic features to predict binary ATR category, then
evaluates transfer in all four directions:

    H→H    5-fold speaker-disjoint CV on human speech (baseline)
    H→TTS  train on all human, test on TTS
    TTS→TTS  5-fold stratified CV on TTS alone
    TTS→H  train on all TTS, test on human speech

Input files
-----------
    human_formant_with_harmony.xlsx
    tts_formant_with_harmony.xlsx

Usage
-----
    python task1_crossdomain.py \
        --human human_formant_with_harmony.xlsx \
        --tts   tts_formant_with_harmony.xlsx
"""

import argparse
import numpy as np
import pandas as pd
import warnings

from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import GroupKFold, StratifiedKFold
from sklearn.metrics import accuracy_score, f1_score, classification_report

warnings.filterwarnings("ignore")


BACKNESS = {
    "i": "front", "e": "front", "ɛ": "front",
    "u": "back",  "ʊ": "back",  "o": "back", "ɔ": "back", "ɑ": "back",
}
HEIGHT_NUM = {"high": 0, "mid": 1, "low": 2}

OUTLIER_BOUNDS = dict(
    B1_Hz=(0, 400),
    F1_Hz=(150, 1200),
    F2_Hz=(500, 3500),
    F3_Hz=(1500, 4500),
)

FEAT_NORM = ["F1_z", "F2_z", "F3_z", "B1_Hz", "duration_ms", "height_num", "backness_num"]
VOWEL_ORDER = ["i", "e", "ɛ", "o", "ɔ", "u", "ʊ", "ɑ"]


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--human", required=True,
                    help="human_formant_with_harmony.xlsx")
    ap.add_argument("--tts",   required=True,
                    help="tts_formant_with_harmony.xlsx")
    return ap.parse_args()


def apply_outlier_filter(df):
    mask = pd.Series(True, index=df.index)
    for col, (lo, hi) in OUTLIER_BOUNDS.items():
        mask &= df[col].between(lo, hi)
    return df[mask].copy()


def add_derived_features(df):
    df["backness_num"] = (df["vowel_label"].map(BACKNESS) == "back").astype(int)
    df["height_num"]   = df["height"].map(HEIGHT_NUM)
    return df


def lobanov_normalize(df):
    for f in ["F1_Hz", "F2_Hz", "F3_Hz"]:
        mu = df.groupby("speaker_id")[f].transform("mean")
        sd = df.groupby("speaker_id")[f].transform("std")
        df[f.replace("_Hz", "_z")] = (df[f] - mu) / sd
    return df


def global_z(df):
    for f in ["F1_Hz", "F2_Hz", "F3_Hz"]:
        df[f.replace("_Hz", "_z")] = (df[f] - df[f].mean()) / df[f].std()
    return df


def print_per_vowel(data_df, y_true, y_pred):
    print(f"    {'Vowel':<8} {'ATR':>6} {'N':>6} {'Acc':>8}")
    print(f"    {'-'*32}")
    for v in VOWEL_ORDER:
        mask = data_df["vowel_label"] == v
        if not mask.any():
            continue
        yt = y_true[mask.values]
        yp = y_pred[mask.values]
        acc = (yt == yp).mean()
        atr = data_df.loc[mask, "atr_class"].iloc[0]
        print(f"      {v:<6} {atr:>6} {mask.sum():>6} {acc:>8.4f}")


def make_models():
    return {
        "LR": lambda: LogisticRegression(
            penalty="l2", C=1.0, class_weight="balanced",
            solver="lbfgs", max_iter=1000, random_state=42
        ),
        "RF": lambda: RandomForestClassifier(
            n_estimators=200, class_weight="balanced",
            min_samples_leaf=5, random_state=42, n_jobs=-1
        ),
    }


def main():
    args = parse_args()

    human = pd.read_excel(args.human)
    tts   = pd.read_excel(args.tts)

    human = human[human["timepoint"] == 50].copy()
    human = human.dropna(subset=["speaker_id", "atr_class"])
    human["vowel_label"] = human["vowel_label"].str.strip()
    human = apply_outlier_filter(human)
    human = add_derived_features(human)
    human = lobanov_normalize(human)

    tts = tts[tts["timepoint"] == 50].copy()
    tts = tts.dropna(subset=["atr_class", "F1_Hz", "F2_Hz", "F3_Hz", "B1_Hz"])
    tts["vowel_label"] = tts["vowel_label"].str.strip()
    if "quality_flag" in tts.columns:
        tts = tts[tts["quality_flag"].astype(str).str.lower() == "ok"]
    tts = apply_outlier_filter(tts)
    tts = add_derived_features(tts)
    tts = global_z(tts)

    human_words = set(human["word"].unique())
    tts["word_overlap"] = tts["word"].isin(human_words).map(
        {True: "overlapping", False: "unique"})

    y_h = (human["atr_class"] == "+ATR").astype(int).values
    y_t = (tts["atr_class"]   == "+ATR").astype(int).values
    groups = human["speaker_id"].values

    X_h = human[FEAT_NORM].values
    X_t = tts[FEAT_NORM].values

    print(f"Human: {len(y_h)} tokens, {human['speaker_id'].nunique()} speakers")
    print(f"TTS:   {len(y_t)} tokens "
          f"({(tts['word_overlap']=='overlapping').sum()} overlapping, "
          f"{(tts['word_overlap']=='unique').sum()} unique)")

    gkf = GroupKFold(n_splits=5)
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    summary = []

    for model_name, model_fn in make_models().items():
        print(f"\n{'='*70}")
        print(f"  {model_name}")
        print(f"{'='*70}")

        # H→H
        print("\n  --- H→H (5-fold speaker-disjoint CV) ---")
        cv_h = np.zeros(len(y_h))
        for tr, te in gkf.split(X_h, y_h, groups):
            sc = StandardScaler()
            m = model_fn()
            m.fit(sc.fit_transform(X_h[tr]), y_h[tr])
            cv_h[te] = m.predict(sc.transform(X_h[te]))
        hh_acc = accuracy_score(y_h, cv_h)
        hh_f1  = f1_score(y_h, cv_h, average="macro")
        print(f"  Acc={hh_acc:.4f}  F1={hh_f1:.4f}")
        print(classification_report(y_h, cv_h, target_names=["-ATR", "+ATR"]))
        print("  Per-vowel:")
        print_per_vowel(human, y_h, cv_h)

        # H→TTS
        print("\n  --- H→TTS ---")
        sc = StandardScaler()
        m = model_fn()
        m.fit(sc.fit_transform(X_h), y_h)
        y_ht = m.predict(sc.transform(X_t))
        ht_acc = accuracy_score(y_t, y_ht)
        ht_f1  = f1_score(y_t, y_ht, average="macro")
        print(f"  Acc={ht_acc:.4f}  F1={ht_f1:.4f}")
        print(classification_report(y_t, y_ht, target_names=["-ATR", "+ATR"]))
        for subset, label in [("overlapping", "Overlapping"), ("unique", "Unique")]:
            mask = (tts["word_overlap"] == subset).values
            if mask.sum() > 0:
                sub_acc = accuracy_score(y_t[mask], y_ht[mask])
                sub_f1  = f1_score(y_t[mask], y_ht[mask], average="macro")
                print(f"  {label} ({mask.sum()} tokens): Acc={sub_acc:.4f}  F1={sub_f1:.4f}")
        print("  Per-vowel (all TTS):")
        print_per_vowel(tts, y_t, y_ht)

        # TTS→TTS
        print("\n  --- TTS→TTS (5-fold stratified CV) ---")
        sc_t = StandardScaler()
        X_t_s = sc_t.fit_transform(X_t)
        cv_t = np.zeros(len(y_t))
        for tr, te in skf.split(X_t_s, y_t):
            m2 = model_fn()
            m2.fit(X_t_s[tr], y_t[tr])
            cv_t[te] = m2.predict(X_t_s[te])
        tt_acc = accuracy_score(y_t, cv_t)
        tt_f1  = f1_score(y_t, cv_t, average="macro")
        print(f"  Acc={tt_acc:.4f}  F1={tt_f1:.4f}")
        print(classification_report(y_t, cv_t, target_names=["-ATR", "+ATR"]))
        print("  Per-vowel:")
        print_per_vowel(tts, y_t, cv_t)

        # TTS→H
        print("\n  --- TTS→H ---")
        m3 = model_fn()
        m3.fit(X_t_s, y_t)
        y_th = m3.predict(sc_t.transform(X_h))
        th_acc = accuracy_score(y_h, y_th)
        th_f1  = f1_score(y_h, y_th, average="macro")
        print(f"  Acc={th_acc:.4f}  F1={th_f1:.4f}")
        print(classification_report(y_h, y_th, target_names=["-ATR", "+ATR"]))
        print("  Per-vowel:")
        print_per_vowel(human, y_h, y_th)

        summary.append({
            "model": model_name,
            "H→H F1":   hh_f1, "H→TTS F1": ht_f1,
            "TTS→TTS F1": tt_f1, "TTS→H F1": th_f1,
        })

    print(f"\n{'='*80}")
    print("SUMMARY (Macro F1)")
    print(f"{'='*80}")
    print(f"{'Model':<6} {'H→H':>10} {'H→TTS':>10} {'TTS→TTS':>10} {'TTS→H':>10}")
    print("-" * 50)
    for r in summary:
        print(f"  {r['model']:<4} {r['H→H F1']:>10.4f} {r['H→TTS F1']:>10.4f} "
              f"{r['TTS→TTS F1']:>10.4f} {r['TTS→H F1']:>10.4f}")


if __name__ == "__main__":
    main()
