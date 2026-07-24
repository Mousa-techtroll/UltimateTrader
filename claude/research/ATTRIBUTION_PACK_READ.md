# Descriptive attribution pack — READ (PROTECT/PARTIAL/HYST, full period). DESCRIPTIVE ONLY.

Raw pack: `ATTRIBUTION_PACK.txt`. This is descriptive characterization, NOT used for tuning. It materially
tempers the finalist story — the apparent portfolio edge is fragile.

## 1. The portfolio gain is COLLATERAL, not a direct Engulfing-exit improvement
| variant | portfolio Δ | DIRECT Engulfing Δ | COLLATERAL (non-Eng) Δ |
|---|---|---|---|
| PROTECT | +1,169 | **−987** | +2,156 |
| PARTIAL | +516 | −1,695 | +2,212 |
| HYST | +899 | −1,765 | +2,664 |
The Engulfing trades themselves get WORSE; the whole gain (and more) is non-Engulfing collateral — a slot-cascade
artifact (changed exit timing frees baseline slots → different, better non-Engulfing entries). Fragile: this depends
on exact slot-timing interactions that will NOT reliably generalize forward.

## 2. Clipping reduced at R-level, but not in $
Remaining-MFE give-back: control 1.14R → variant ~0.80R (the intended mechanism WORKS — less winner give-back).
But changed-trade R nets ~0 (CLIPPED ≈ −21..−28R vs HELPFUL ≈ +21..+28R) and the DIRECT $ still drops, because
the variants cut R on HIGH-$ winners and add R on LOW-$ trades (risk-weighting). So the mechanism is real but does
not, on its own, make the Engulfing book more profitable.

## 3. The most-forward-predictive period is the WORST
Per-year net Δ (control→variant): gains sit in 2019-2023; 2024/2025 mixed-to-flat; **2026 H1 strongly NEGATIVE for
all** (PROTECT −1,460, PARTIAL −1,859, HYST −2,263 vs control). 2025 (biggest year, ~$21k) is ~flat. The recent
slice — the closest proxy to forward — degrades under every variant.

## Honest conclusion
The wave-2 variants are a PROMISING HISTORICAL EXPLORATION, not clean OOS winners and not production-ready. Their
full-period + GH "edge" is (a) collateral/slot-cascade rather than direct, (b) risk-weighting-sensitive, and (c)
negative on the most recent data. The direct, honest measure of each candidate = its OWN virtual-ledger
counterfactual on NEW forward data (per-trade, no slot-cascade), which is what the forward shadow will produce.
Do NOT promote on this historical evidence. Forward shadow first, with pre-registered criteria.
