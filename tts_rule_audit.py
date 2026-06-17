import pandas as pd
import numpy as np

TTS_FORMANT_WITH_HARMONY = "/Users/sneharaybarman/Desktop/Research/assamese_tts_evaluation/tts_formant_with_harmony.xlsx"
TTS_PREDICTIONS = "/Users/sneharaybarman/Desktop/Research/assamese_tts_evaluation/tts_task1_lr_predictions.xlsx"

tts = pd.read_excel(TTS_FORMANT_WITH_HARMONY)
tts = tts[tts["timepoint"] == 50].copy()
tts = tts[tts["harmony_type"].notna()].copy()
if "quality_flag" in tts.columns:
    tts = tts[tts["quality_flag"].astype(str).str.lower() == "ok"].copy()

# outlier filter (match what you use elsewhere)
mask = (
    (tts['B1_Hz'] <= 400) &
    (tts['F1_Hz'].between(150, 1200)) &
    (tts['F2_Hz'].between(500, 3500)) &
    (tts['F3_Hz'].between(1500, 4500))
)
tts = tts[mask].copy()

# merge predictions
pred = pd.read_excel(TTS_PREDICTIONS)
tts["vs_round"] = tts["vowel_start"].round(4)
pred["vs_round"] = pred["vowel_start"].round(4)

tts = tts.merge(
    pred[["filename","vowel_label","vs_round","y_pred_norm","p_plusATR"]],
    on=["filename","vowel_label","vs_round"],
    how="left"
)
tts = tts[tts["y_pred_norm"].notna()].copy()

tts["atr_gold"] = (tts["atr_class"] == "+ATR").astype(int)
tts["atr_pred"] = tts["y_pred_norm"].astype(int)

# -------------------------
# A) overall mismatch
# -------------------------
tts["mismatch"] = (tts["atr_gold"] != tts["atr_pred"]).astype(int)
print("\nOVERALL")
print("N:", len(tts))
print("Mismatch rate:", round(tts["mismatch"].mean(), 3))

# -------------------------
# B) overgeneration / underproduction
# -------------------------
gold_minus = tts[tts["atr_gold"] == 0]
gold_plus  = tts[tts["atr_gold"] == 1]

print("\nCONDITIONED")
print("Gold -ATR → predicted +ATR (overgeneration):", round((gold_minus["atr_pred"] == 1).mean(), 3))
print("Gold +ATR → predicted -ATR (underproduction):", round((gold_plus["atr_pred"] == 0).mean(), 3))

# -------------------------
# C) by harmony type
# -------------------------
print("\nBY HARMONY TYPE")
print(tts.groupby("harmony_type")["mismatch"].mean().round(3).to_string())

# -------------------------
# D) by vowel label
# -------------------------
tbl = tts.groupby("vowel_label").agg(
    N=("vowel_label","size"),
    gold_plus=("atr_gold","mean"),
    pred_plus=("atr_pred","mean"),
    mismatch=("mismatch","mean")
).sort_values("N", ascending=False).round(3)

print("\nBY VOWEL LABEL")
print(tbl.to_string())