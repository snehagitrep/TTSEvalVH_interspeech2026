#!/usr/bin/env python3
"""
Task 2 pipeline (complete): faithfulness audit + word-level harmony classification.

This script reproduces all results reported for Task 2 in the paper:

  1. Load human and TTS vowel data (with harmony labels from merge_harmonytype.py).
  2. Generate speaker-disjoint out-of-fold ATR predictions for human vowels
     using the Task 1 LR classifier (5-fold GroupKFold, Lobanov + backness).
  3. Generate TTS ATR predictions by training on all human tokens.
  4. Run the phonological faithfulness audit: compare gold ATR labels against
     acoustic predictions and report mismatch directionality.
  5. Build word-level feature matrices (Set A acoustic aggregates, Set B trigger-
     target, Set C ATR distribution in gold and predicted variants).
  6. Run Task 2 three-class harmony classification (LR + RF) with H→H CV and
     H→TTS transfer, reporting the gold-vs-predicted gap discussed in §3.3.

Input files
-----------
    human_formant_with_harmony.xlsx
    tts_formant_with_harmony.xlsx

Output files
------------
    human_word_features.xlsx
    tts_word_features.xlsx
    task2_results.xlsx

Usage
-----
    python task2_pipeline.py \
        --human human_formant_with_harmony.xlsx \
        --tts   tts_formant_with_harmony.xlsx \
        --out_dir .
"""

import argparse
import numpy as np
import pandas as pd
import warnings
from scipy.stats import entropy as sp_entropy

from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import GroupKFold
from sklearn.metrics import (accuracy_score, f1_score,
                             classification_report, confusion_matrix)

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

FEAT_TASK1 = ["F1_z", "F2_z", "F3_z", "B1_Hz", "duration_ms", "height_num", "backness_num"]
CLASS_ORDER = ["AgrYes_MixNo", "AgrYes_MixYes", "AgrNo_MixYes"]


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--human",   required=True)
    ap.add_argument("--tts",     required=True)
    ap.add_argument("--out_dir", default=".")
    return ap.parse_args()


def outlier_mask(df):
    mask = pd.Series(True, index=df.index)
    for col, (lo, hi) in OUTLIER_BOUNDS.items():
        mask &= df[col].between(lo, hi)
    return mask


def add_derived(df):
    df["backness_num"] = (df["vowel_label"].map(BACKNESS) == "back").astype(int)
    df["height_num"]   = df["height"].map(HEIGHT_NUM)
    return df


def lobanov(df):
    for f in ["F1_Hz", "F2_Hz", "F3_Hz"]:
        mu = df.groupby("speaker_id")[f].transform("mean")
        sd = df.groupby("speaker_id")[f].transform("std")
        df[f.replace("_Hz", "_z")] = (df[f] - mu) / sd
    return df


def global_z(df):
    for f in ["F1_Hz", "F2_Hz", "F3_Hz"]:
        df[f.replace("_Hz", "_z")] = (df[f] - df[f].mean()) / df[f].std()
    return df


def atr_summary_features(atr_vals, prefix):
    atr_vals = np.asarray(atr_vals, dtype=int)
    n = len(atr_vals)
    p = float(atr_vals.mean()) if n else 0.0
    switches = sum(atr_vals[i] != atr_vals[i - 1] for i in range(1, n))
    return {
        f"{prefix}_count_plus":  int(atr_vals.sum()),
        f"{prefix}_count_minus": int(n - atr_vals.sum()),
        f"{prefix}_prop_plus":   p,
        f"{prefix}_entropy":     0.0 if p in (0.0, 1.0) else float(sp_entropy([p, 1 - p], base=2)),
        f"{prefix}_all_agree":   int(len(set(atr_vals.tolist())) == 1),
        f"{prefix}_majority_atr":int(p >= 0.5),
        f"{prefix}_n_switches":  int(switches),
    }


def build_word_features(group):
    n = len(group)
    if n == 0:
        return None

    rec = {
        "harmony_type": group["harmony_type"].iloc[0],
        "word":         group["word"].iloc[0],
        "filename":     group["filename"].iloc[0],
        "n_vowels":     int(n),
    }

    for feat in ["F1_Hz", "F2_Hz", "F3_Hz", "B1_Hz", "duration_ms"]:
        rec[f"A_mean_{feat}"] = float(group[feat].mean())
    rec["A_sd_F1"]    = float(group["F1_Hz"].std()) if n > 1 else 0.0
    rec["A_sd_F2"]    = float(group["F2_Hz"].std()) if n > 1 else 0.0
    rec["A_range_F1"] = float(group["F1_Hz"].max() - group["F1_Hz"].min()) if n > 1 else 0.0
    rec["A_F1_first"] = float(group["F1_Hz"].iloc[0])
    rec["A_F1_last"]  = float(group["F1_Hz"].iloc[-1])

    trigger = group.iloc[-1]
    target  = group.iloc[0]
    for feat in ["F1_Hz", "F2_Hz", "F3_Hz", "B1_Hz", "duration_ms"]:
        rec[f"B_trigger_{feat}"] = float(trigger[feat])
        rec[f"B_target_{feat}"]  = float(target[feat])
    rec["B_diff_F1"]  = float(target["F1_Hz"] - trigger["F1_Hz"])
    rec["B_diff_F2"]  = float(target["F2_Hz"] - trigger["F2_Hz"])
    rec["B_ratio_F1"] = float(target["F1_Hz"] / trigger["F1_Hz"]) \
                        if float(trigger["F1_Hz"]) != 0.0 else np.nan

    rec["B_trigger_atr"]      = int(trigger["atr_pred"])
    rec["B_target_atr"]       = int(target["atr_pred"])
    rec["B_atr_agree"]        = int(trigger["atr_pred"] == target["atr_pred"])
    rec["B_trigger_atr_gold"] = int(trigger["atr_gold"])
    rec["B_target_atr_gold"]  = int(target["atr_gold"])
    rec["B_atr_agree_gold"]   = int(trigger["atr_gold"] == target["atr_gold"])
    rec["B_trigger_vowel"]    = str(trigger["vowel_label"])
    rec["B_target_vowel"]     = str(target["vowel_label"])
    rec["B_height_match"]     = int(str(trigger["height"]) == str(target["height"]))
    rec["B_trigger_is_iu"]    = int(str(trigger["vowel_label"]) in ["i", "u"])

    rec.update(atr_summary_features(group["atr_gold"].values, "C_gold"))
    rec.update(atr_summary_features(group["atr_pred"].values, "C_pred"))

    return rec


def faithfulness_audit(df, gold_col="atr_gold", pred_col="atr_pred", label=""):
    d = df[df[pred_col].notna()].copy()
    d["mismatch"] = (d[gold_col] != d[pred_col]).astype(int)
    d["overgen"]  = ((d[gold_col] == 0) & (d[pred_col] == 1)).astype(int)
    d["under"]    = ((d[gold_col] == 1) & (d[pred_col] == 0)).astype(int)

    overall = {
        "domain":              label,
        "N":                   len(d),
        "mismatch_rate":       round(d["mismatch"].mean(), 4),
        "overgeneration_rate": round(d["overgen"].mean(), 4),
        "underproduction_rate":round(d["under"].mean(), 4),
        "gold_plus_rate":      round(d[gold_col].mean(), 4),
        "pred_plus_rate":      round(d[pred_col].mean(), 4),
    }

    by_harmony = (d.groupby("harmony_type").agg(
        N=("mismatch", "size"),
        mismatch_rate=("mismatch", "mean"),
        overgeneration_rate=("overgen", "mean"),
        underproduction_rate=("under", "mean"),
    ).round(4).reset_index()) if "harmony_type" in d.columns else pd.DataFrame()

    by_vowel = (d.groupby("vowel_label").agg(
        N=("mismatch", "size"),
        mismatch_rate=("mismatch", "mean"),
        gold_plus_rate=(gold_col, "mean"),
        pred_plus_rate=(pred_col, "mean"),
    ).round(4).reset_index()) if "vowel_label" in d.columns else pd.DataFrame()

    return overall, by_harmony, by_vowel


def make_lr():
    return LogisticRegression(
        penalty="l2", C=1.0, class_weight="balanced",
        solver="lbfgs", max_iter=1000, random_state=42
    )


def make_models():
    return {
        "LR": lambda: LogisticRegression(
            penalty="l2", C=1.0, class_weight="balanced",
            solver="lbfgs", max_iter=1000, random_state=42,
            multi_class="multinomial"
        ),
        "RF": lambda: RandomForestClassifier(
            n_estimators=200, class_weight="balanced",
            min_samples_leaf=5, random_state=42, n_jobs=-1
        ),
    }


def main():
    args = parse_args()

    print("=" * 70)
    print("PART 1: LOAD DATA")
    print("=" * 70)

    human = pd.read_excel(args.human)
    tts   = pd.read_excel(args.tts)

    tp_col = "timepoint %" if "timepoint %" in human.columns else "timepoint"
    human = human[human[tp_col] == 50].copy()
    human = human[human["harmony_type"].notna()].copy()
    human = human.dropna(subset=["speaker_id", "atr_class", "F1_Hz", "F2_Hz",
                                  "F3_Hz", "B1_Hz", "duration_ms",
                                  "vowel_label", "vowel_start", "height"])
    human["filename"]    = human["filename"].astype(str).str.strip()
    human["word"]        = human["word"].astype(str).str.strip()
    human["vowel_label"] = human["vowel_label"].astype(str).str.strip()
    human = human[outlier_mask(human)].copy()
    human = add_derived(human)
    human = lobanov(human)
    human["atr_gold"] = (human["atr_class"] == "+ATR").astype(int)

    tp_col_t = "timepoint" if "timepoint" in tts.columns else "timepoint %"
    tts = tts[tts[tp_col_t] == 50].copy()
    tts = tts[tts["harmony_type"].notna()].copy()
    tts = tts.dropna(subset=["atr_class", "F1_Hz", "F2_Hz", "F3_Hz",
                               "B1_Hz", "duration_ms", "vowel_label",
                               "vowel_start", "height"])
    if "quality_flag" in tts.columns:
        tts = tts[tts["quality_flag"].astype(str).str.lower() == "ok"].copy()
    tts["filename"]    = tts["filename"].astype(str).str.strip()
    tts["word"]        = tts["word"].astype(str).str.strip()
    tts["vowel_label"] = tts["vowel_label"].astype(str).str.strip()
    tts = tts[outlier_mask(tts)].copy()
    tts = add_derived(tts)
    tts = global_z(tts)
    tts["atr_gold"] = (tts["atr_class"] == "+ATR").astype(int)

    print(f"Human: {len(human)} vowel tokens | {human['speaker_id'].nunique()} speakers")
    print(f"TTS:   {len(tts)} vowel tokens | {tts['filename'].nunique()} utterances")

    print("\n" + "=" * 70)
    print("PART 2: ATR PREDICTIONS (Task 1 LR, Lobanov + backness)")
    print("=" * 70)

    y_h   = human["atr_gold"].values
    X_h   = np.nan_to_num(human[FEAT_TASK1].values.astype(float), nan=0.0)
    X_t   = np.nan_to_num(tts[FEAT_TASK1].values.astype(float),   nan=0.0)
    grps  = human["speaker_id"].values

    gkf = GroupKFold(n_splits=5)
    h_oof_pred = np.full(len(y_h), -1, dtype=int)
    h_oof_prob = np.full(len(y_h), np.nan)

    print("\nOut-of-fold human ATR predictions (speaker-disjoint):")
    for fold, (tr, te) in enumerate(gkf.split(X_h, y_h, grps), 1):
        sc = StandardScaler()
        clf = make_lr()
        clf.fit(sc.fit_transform(X_h[tr]), y_h[tr])
        h_oof_pred[te] = clf.predict(sc.transform(X_h[te]))
        h_oof_prob[te] = clf.predict_proba(sc.transform(X_h[te]))[:, 1]
        acc = accuracy_score(y_h[te], h_oof_pred[te])
        print(f"  Fold {fold}: acc={acc:.4f} | speakers={set(grps[te])}")

    human["atr_pred"]  = h_oof_pred
    human["p_plusATR"] = h_oof_prob
    oof_f1 = f1_score(y_h, h_oof_pred, average="macro")
    print(f"\nHuman OOF: Acc={accuracy_score(y_h, h_oof_pred):.4f}  F1={oof_f1:.4f}")

    sc_full = StandardScaler()
    clf_full = make_lr()
    clf_full.fit(sc_full.fit_transform(X_h), y_h)
    tts["atr_pred"]  = clf_full.predict(sc_full.transform(X_t)).astype(int)
    tts["p_plusATR"] = clf_full.predict_proba(sc_full.transform(X_t))[:, 1]
    tts_agree = (tts["atr_gold"] == tts["atr_pred"]).mean()
    print(f"TTS predictions: gold-pred agreement={tts_agree:.4f}")

    print("\n" + "=" * 70)
    print("PART 3: FAITHFULNESS AUDIT")
    print("=" * 70)

    h_ov, h_by_harm, h_by_vow = faithfulness_audit(human, label="Human (OOF)")
    t_ov, t_by_harm, t_by_vow = faithfulness_audit(tts,   label="TTS")

    for label, ov, by_harm, by_vow in [
        ("Human (OOF)", h_ov, h_by_harm, h_by_vow),
        ("TTS",         t_ov, t_by_harm, t_by_vow),
    ]:
        print(f"\n{label} — overall:")
        for k, v in ov.items():
            print(f"  {k}: {v}")
        if len(by_harm):
            print(f"\n{label} — by harmony type:")
            print(by_harm.to_string(index=False))
        if len(by_vow):
            print(f"\n{label} — by vowel:")
            print(by_vow.to_string(index=False))

    print("\n" + "=" * 70)
    print("PART 4: BUILD WORD-LEVEL FEATURES")
    print("=" * 70)

    human = human.sort_values(["speaker_id", "filename", "vowel_start"])
    tts   = tts.sort_values(["filename", "vowel_start"])

    human_records = []
    for (spk, fname), grp in human.groupby(["speaker_id", "filename"]):
        rec = build_word_features(grp)
        if rec is not None:
            rec["speaker_id"] = spk
            human_records.append(rec)
    human_wf = pd.DataFrame(human_records)
    print(f"Human word instances: {len(human_wf)}")
    print(human_wf["harmony_type"].value_counts().to_string())

    tts_records = []
    for fname, grp in tts.groupby("filename"):
        rec = build_word_features(grp)
        if rec is not None:
            rec["speaker_id"] = "tts"
            tts_records.append(rec)
    tts_wf = pd.DataFrame(tts_records)
    print(f"\nTTS word instances: {len(tts_wf)}")
    print(tts_wf["harmony_type"].value_counts().to_string())

    diff = (human_wf["C_pred_prop_plus"] - human_wf["C_gold_prop_plus"]).abs().mean()
    if diff < 0.001:
        print("\nWARNING: C_pred and C_gold are nearly identical — "
              "check that out-of-fold predictions are being used for human data.")
    else:
        print(f"\nSanity: mean |C_pred - C_gold| prop_plus = {diff:.4f} (expected > 0)")

    out = args.out_dir.rstrip("/")
    human_wf.to_excel(f"{out}/human_word_features.xlsx", index=False)
    tts_wf.to_excel(f"{out}/tts_word_features.xlsx", index=False)
    print(f"\nSaved human_word_features.xlsx ({len(human_wf)} rows)")
    print(f"Saved tts_word_features.xlsx ({len(tts_wf)} rows)")

    print("\n" + "=" * 70)
    print("PART 5: TASK 2 CLASSIFICATION")
    print("=" * 70)

    le = LabelEncoder()
    le.fit(CLASS_ORDER)
    human_wf["y"] = le.transform(human_wf["harmony_type"])
    tts_wf["y"]   = le.transform(tts_wf["harmony_type"])
    groups_wf = human_wf["speaker_id"].values

    feat_A = [c for c in human_wf.columns if c.startswith("A_")] + ["n_vowels"]

    b_acoustic = [c for c in human_wf.columns
                  if c.startswith("B_") and
                  c not in ("B_trigger_vowel", "B_target_vowel") and
                  "_atr" not in c.lower() and
                  human_wf[c].dtype in ("float64", "int64", "int32")]
    b_pred_atr = [c for c in ("B_trigger_atr", "B_target_atr", "B_atr_agree")
                  if c in human_wf.columns]
    b_gold_atr = [c for c in human_wf.columns
                  if c.startswith("B_") and "gold" in c and
                  human_wf[c].dtype in ("float64", "int64", "int32")]

    feat_C_gold = [c for c in human_wf.columns if c.startswith("C_gold_")]
    feat_C_pred = [c for c in human_wf.columns if c.startswith("C_pred_")]

    feature_sets = [
        ("A",          feat_A,                        "Acoustic aggregates"),
        ("B_pred",     b_acoustic + b_pred_atr,       "Trigger-target (pred ATR)"),
        ("C_gold",     feat_C_gold,                   "ATR distribution (gold)"),
        ("C_pred",     feat_C_pred,                   "ATR distribution (pred)"),
        ("A+B_gold",   feat_A + b_acoustic + b_gold_atr, "Acoustic + gold ATR"),
        ("A+B_pred",   feat_A + b_acoustic + b_pred_atr, "Acoustic + pred ATR"),
    ]

    gkf2 = GroupKFold(n_splits=5)
    summary = []

    for fs_key, feat_cols, fs_label in feature_sets:
        for model_name, model_fn in make_models().items():
            print(f"\n{'='*65}")
            print(f"  {model_name} | {fs_label} ({len(feat_cols)} features)")
            print(f"{'='*65}")

            X_h2 = np.nan_to_num(human_wf[feat_cols].values.astype(float), nan=0.0)
            X_t2 = np.nan_to_num(tts_wf[feat_cols].values.astype(float),   nan=0.0)
            y_h2 = human_wf["y"].values
            y_t2 = tts_wf["y"].values

            cv_preds = np.zeros(len(y_h2))
            fold_f1s = []
            for tr, te in gkf2.split(X_h2, y_h2, groups_wf):
                sc = StandardScaler()
                m = model_fn()
                m.fit(sc.fit_transform(X_h2[tr]), y_h2[tr])
                preds = m.predict(sc.transform(X_h2[te]))
                cv_preds[te] = preds
                fold_f1s.append(f1_score(y_h2[te], preds, average="macro"))

            hh_f1    = float(np.mean(fold_f1s))
            hh_f1_sd = float(np.std(fold_f1s))
            hh_acc   = accuracy_score(y_h2, cv_preds)
            print(f"\n  H→H: Acc={hh_acc:.4f}  F1={hh_f1:.4f}±{hh_f1_sd:.4f}")
            print(classification_report(y_h2, cv_preds, target_names=CLASS_ORDER))

            sc = StandardScaler()
            m = model_fn()
            m.fit(sc.fit_transform(X_h2), y_h2)
            y_ht = m.predict(sc.transform(X_t2))
            ht_acc = accuracy_score(y_t2, y_ht)
            ht_f1  = f1_score(y_t2, y_ht, average="macro")
            print(f"  H→TTS: Acc={ht_acc:.4f}  F1={ht_f1:.4f}")
            print(classification_report(y_t2, y_ht, target_names=CLASS_ORDER))

            cm = confusion_matrix(y_t2, y_ht)
            print("  Confusion matrix (TTS):")
            hdr = f"  {'':20} " + " ".join(f"{'Pred_'+c[:3]:>10}" for c in CLASS_ORDER)
            print(hdr)
            for i, lbl in enumerate(CLASS_ORDER):
                row = f"  {lbl:<20} " + " ".join(f"{cm[i, j]:>10}" for j in range(3))
                print(row)

            if model_name == "RF":
                print("\n  Top 10 features (Gini importance):")
                for idx in np.argsort(m.feature_importances_)[::-1][:10]:
                    print(f"    {feat_cols[idx]:<30}: {m.feature_importances_[idx]:.4f}")

            summary.append({
                "approach": fs_key, "model": model_name, "features": fs_label,
                "n_features": len(feat_cols),
                "HH_acc": hh_acc, "HH_f1": hh_f1, "HH_f1_sd": hh_f1_sd,
                "HT_acc": ht_acc, "HT_f1": ht_f1,
            })

    print(f"\n{'='*100}")
    print("SUMMARY")
    print(f"{'='*100}")
    hdr = (f"{'Approach':<10} {'Model':<5} {'Features':<30} {'N':>3} "
           f"{'H→H Acc':>10} {'H→H F1':>12} {'H→TTS Acc':>12} {'H→TTS F1':>12}")
    print(hdr)
    print("-" * 100)
    for r in summary:
        print(f"  {r['approach']:<8} {r['model']:<5} {r['features']:<30} "
              f"{r['n_features']:>3} {r['HH_acc']:>10.3f} "
              f"{r['HH_f1']:.3f}±{r['HH_f1_sd']:.3f}  "
              f"{r['HT_acc']:>12.3f} {r['HT_f1']:>12.3f}")

    results_df = pd.DataFrame(summary)
    results_df.to_excel(f"{out}/task2_results.xlsx", index=False)
    print(f"\nSaved task2_results.xlsx")


if __name__ == "__main__":
    main()
