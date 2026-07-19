# L4-1 — engine-aware setup-evaluator redesign (architectural defect, unresolved)

## Status
L4-1 is an **unresolved architectural defect**, NOT intended behavior and NOT a simple bug. The raw global
directional-alignment patch (−43%, PF 1.35/Sharpe 2.55) and its global threshold recalibration (best RECAL3
−22.7%, PF 1.27/Sharpe 1.93, floods the book) are BOTH REJECTED — they apply trend-following semantics
uniformly and destroy the book's counter-trend/reversal alpha. Production stays on the current baseline
(`d6549628` / $34,940.18) with `InpDirectionalAlignment` default-off while this redesign runs.

## Root diagnosis
`CSetupEvaluator` **conflates two independent concepts**:
1. **Context strength** — how strong/directional is the market context (D1/H4 trend magnitude, macro magnitude,
   ADX, regime). Direction-NEUTRAL.
2. **Signal-to-context relationship** — how does THIS signal relate to the context: aligned / counter-trend /
   neutral / mixed. SIGNED.
Today the "alignment" points reward context strength as if all engines were trend-following. But a
mean-reversion or reversal engine EARNS its edge by trading AGAINST a strong (exhausted) context — so for those
engines, "counter-trend" is the thesis, not a demerit. The raw fix wrongly penalizes them.

## Target architecture (two independent outputs + engine intent)
1. Evaluator emits **context_strength** (direction-neutral scalar) and **relationship** (signed:
   aligned/counter/neutral/mixed) separately.
2. Every entry engine carries an explicit **intent classification**: `TREND | PULLBACK | BREAKOUT |
   MEAN_REVERSION | REVERSAL | CRASH | HYBRID`.
3. An **engine-specific context policy** maps (intent, context_strength, relationship) → quality points:
   - TREND / PULLBACK / BREAKOUT engines: reward ALIGNMENT with a strong directional context.
   - MEAN_REVERSION / REVERSAL engines: earn quality ONLY through explicit exhaustion (RSI/BB extremes),
     structural rejection (S/R, order-block, liquidity sweep), and reversal confirmation — NOT alignment.
     A strong opposing context is a POSITIVE for these (fading an exhausted move), not a demerit.
   - CRASH / HYBRID: bespoke.
4. **Thresholds recalibrated PER ENGINE or PER POLICY**, never globally.

## Phased plan (parallel subagents; pre-register criteria before Arm C)
- **Phase 1 — behavior-neutral audit (AUDIT_BUILD, byte-identical `d6549628`).** Instrument the evaluator to log,
  per SCORED CANDIDATE and joinable to FILLS: engine, signal direction, D1/H4 trend dir, macro score, derived
  relationship class, context_strength, assigned tier. Cross with the per-trade Stats CSV (PnL_R by engine).
  Deliver: candidate + trade performance **by engine × relationship** (aligned/counter/neutral/mixed) — which
  engines are counter-trend, and how each relationship-class performs per engine.
- **Phase 2 — engine-intent taxonomy.** Classify every registered entry engine (TREND/…/HYBRID) from source
  evidence (entry logic, not names).
- **Phase 3 — Arm C (engine-aware).** Implement the two-output evaluator + engine-specific policy behind a flag;
  per-engine/policy threshold recalibration. **Pre-register acceptance criteria BEFORE any A/B run** (below).
- **Phase 4 — validate + decide** on primary + GoldHistory + per-engine attribution vs the pre-registered bar.

## Pre-registered acceptance criteria (to be finalized from the Phase-1 audit, BEFORE Arm C testing)
Arm C is adopted ONLY if, vs `d6549628` baseline:
- Net ≥ baseline − 2% AND Sharpe ≥ baseline (≥ 2.96) AND PF ≥ baseline (≥ 1.42) AND EqDD ≤ baseline (≤ 15.24%)
  on the PRIMARY feed; AND net not worse than −5% on GoldHistory (portability);
- per-engine attribution shows the counter-trend/reversal engines RETAIN their edge (their aligned-vs-counter
  performance split matches the Phase-1 audit's profitable cohorts) while trend engines' alignment reward is
  intact;
- no engine's realized expectancy inverts sign vs baseline.
(These are provisional; the Phase-1 audit refines the exact per-engine bars, still pre-registered before Arm C.)
