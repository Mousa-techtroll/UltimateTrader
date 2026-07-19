# L4-1 Arm C v2 — setup-subtype, evidence-gated, exact-attribution redesign (PRE-REGISTERED)

Reference baselines (frozen, do not alter): production `baseline-codex-seven-32617` = `c051f97b` /
$32,617.90 / PF 1.47 / Sharpe 3.13 / EqDD 11.32% / 801 (primary); GH `fb82104a` / $24,086.34 / 748.
v1 verdict (REJECTED): plugin-coarse intent + blanket counter-credit → over-admits (+95), −20.4%.

## Why v1 failed → what v2 changes
1. **Per-SETUP, not per-plugin.** A plugin emits different setups (e.g. a rejection that is trend-aligned vs a
   counter-trend exhaustion fade). v2 classifies each EMITTED setup into: `TREND_CONTINUATION | PULLBACK |
   BREAKOUT | MEAN_REVERSION | EXHAUSTION_REVERSAL | FAILED_BREAK_REVERSAL | CRASH_CONTINUATION | HYBRID`.
2. **Evidence-gated opposition.** Counter/reversal setups earn quality for opposing the trend ONLY when backed
   by explicit evidence: overextension (ATR/BB distance from mean), exhaustion (RSI extreme), structural
   rejection (wick / S-R / order-block), liquidity sweep, or failed-break. No blanket counter-credit → the
   unsupported direction-blind counter admissions v1 kept are REMOVED; the evidence-backed ones are RETAINED.
3. **Separate context FACTS from strategy INTERPRETATION.** Facts (D1/H4 trend, ADX, macro, RSI, ATR-extension,
   regime, sweep/OB flags) are objective and computed once; the per-intent policy INTERPRETS them (trend wants
   alignment; evidence-backed reversal wants exhaustion-confirmed opposition).
4. **Exact candidate attribution.** A stable candidate id threaded generation→confirmation→execution→position→
   exit (reuse the existing SignalID if it survives; else add), so every fill joins to its scored candidate and
   we can label each as legacy-retained / legacy-removed / newly-admitted and attribute realized R.
5. **No global threshold lowering** (v1's offset sweep floods the book — rejected).

## Cohort measurement (AUDIT build, byte-identical; both scoring policies computed per candidate)
For every scored candidate log: id, legacy_tier, v2_tier, setup_subtype, relationship, evidence_flags. Join to
fills (id → realized R/PnL) from the Stats CSV. Partition:
- **LEGACY-RETAINED** — admitted by both (same-or-similar tier). Target: keep the profitable counter/mixed R.
- **LEGACY-REMOVED** — admitted by legacy, rejected by v2 (unsupported counter). Target: these are net-LOSERS
  (removing them helps); measure their aggregate R.
- **NEWLY-ADMITTED** — rejected by legacy, admitted by v2. Target: non-negative expectancy.

## PRE-REGISTERED acceptance criteria (framework now; numeric bars finalized from the attribution baseline
BEFORE the v2-on A/B run — the legacy cohort R is measured first, then bars are frozen)
Arm C v2 is ADOPTED only if ALL hold vs `c051f97b`:
1. **Net** ≥ −2% ($ ≥ 31,965) primary; **cross-feed GH** ≥ −5% ($ ≥ 22,882).
2. **PF ≥ 1.47**, **Sharpe ≥ 3.13**, **EqDD ≤ 11.32%** (primary — must not degrade the risk-improved book).
3. **Retained profitable counter/mixed R** ≥ 90% of the legacy profitable-counter+mixed R (the alpha is kept).
4. **Legacy-removed cohort** aggregate R ≤ 0 (v2 only removes net-losing unsupported setups; if it removes
   net-winners it fails).
5. **Newly-admitted cohort** expectancy (avg R) ≥ 0 (v2 doesn't add net-negative trades).
6. No per-intent cohort's realized expectancy sign inverts vs legacy.
If any fails → v2 is documented-not-adopted; L4-1 stays held; production stays `c051f97b`. Do NOT force-merge and
do NOT globally lower thresholds to hit a number.

## Build order
1. Recon (running): candidate-id lifecycle + gaps; setup-subtype + evidence catalog.
2. Attribution instrument (AUDIT): log id + both tiers + subtype + evidence; run; establish legacy cohort R;
   FREEZE numeric bars.
3. Build v2 behind `InpEAAv2` (default off = `c051f97b` identity, verified).
4. Measure v2-on: cohort partition + criteria 1-6, both feeds. Adopt only on a clean pass.
