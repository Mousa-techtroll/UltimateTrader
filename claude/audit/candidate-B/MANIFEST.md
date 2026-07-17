# FREEZE — `candidate-session-breakout-dst-only-B`

Frozen 2026-07-17. Reproducible recipe for the Arm B candidate (breakout-window-DST-only).

## Build recipe
- Source: `baseline-input-cleanup-388` + the 2×2 scaffold `research-patches/session-clock-2x2-scaffold.patch`
  (dormant `#ifdef RESEARCH_SESSION` blocks; production-neutral, proven Stats `96415ff0`).
- Compile with `#define RESEARCH_SESSION` temporarily added after `#property strict` (MQL5 has no `-D`).
- Frozen binary: `MQL5/Experts/UltimateTrader_SESSB.ex5` md5 **`4e589f6f…`** (compiled 0 errors/0 warnings).

## Run recipe (identity-pinned)
- Config: `risk_R90.ini` (md5 `cebf9578`) AS-IS. Symbol XAUUSD+, Model=4 real ticks, 2019.01.01→2026.06.27.
- Research flags: **`InpResSessBreakoutDST=true`, `InpResSessRangeDST=false`**.
- Runner: `claude/gate/sessclock_run.sh UltimateTrader_SESSB.ex5 SESSB InpResSessRangeDST=false InpResSessBreakoutDST=true`

## Frozen result (primary feed)
- Stats md5 **`1ed88d41`** · TradeEvents in archive `Common/Files/_arm_archive/sess_SESSB`.
- Net (report) **$34,858.89** · PF 1.42 · Sharpe 2.96 · Recovery 4.47 · Eq DD 15.22% · 869 pos / 1907 deals.
- Peak closed balance ≈ $49.8k (net) / $50.3k (gross of commission) @ 2026-02; final balance $44,858.89.

## Baseline (production A) for the gate
- `UltimateTrader_SESSA.ex5` / `SESSPROD.ex5` (both flags off) → Stats `96415ff0` = production 388.
- Net $32,503.03 · PF 1.40 · Sharpe 2.87 · Recovery 4.81 · Eq DD 14.12% · 865 pos.

## Cross-history (GoldHistory, Model=1) — preserved
- GH A `85af5e31` $28,685.51 / GH B `1276ffa1` $29,525.79 (+$840.28). Archives `_arm_archive/sessgh_GH{A,B}`.

## Rejected siblings (do not adopt)
- Arm C (range-DST only) `644c54a0` — self-destructs to 0 composed fills, −$2,519.
- Arm D / Arm 1 (full DST) `a8c1e028` — worst live arm on both feeds, −$1,103 / −$1,612.

Gate: `adoption-gate.md`. Study: `../session-clock-decomposition.md`.
