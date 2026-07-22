# FROZEN — Intent-Score Weight Vectors (Wave 0.4)

**Owner:** orchestrator (single writer). **Consumer:** builder A1 (`CMomentumSnapshotter.GetIntentScores`). **Consumer of the scores:** the 5 bundles (read the 0..100 `IntentScore.score` + `.available`).
**Status:** FROZEN for build. **Thresholds that KEY off these scores (e.g. trend-Trailing) are provisional until Wave-5 telemetry reveals the actual score distribution, then re-tuned before Wave-6 activation (QA F6).**

## Conventions
- Each score is `clamp(0, 100, 50 + Σ wᵢ · cᵢ)` where `cᵢ ∈ [-1, +1]` is the normalized contribution of a P1 momentum feature and `wᵢ` is its point weight. Base 50 = neutral.
- **Availability (never fabricate):** a score's `.available` is TRUE **only if every P1 feature with a non-zero weight below is `available`.** If any required feature is unavailable, the score is `{score:0, available:false}` and consuming bundles abstain.
- P1 features (all closed-bar): `trend` (signed −1..+1), `impulse` (0..1), `acceleration` (signed), `deceleration` (signed, ≥0 = stalling), `overextension` (0..1), `exhaustion` (0..1), `reversal_confirm` (0..1), `bear_state_score` (0..100 → normalize /100), `ema_relationship` (signed −1..+1, + = price above EMAs).
- P2 features (`pullback_recovery`, `breakout`, `divergence`) are `available:false` at build; scores that would use them run on the P1 proxy below and MUST NOT reference a P2 field until it is implemented (they'd taint availability). Direction handling: for a SHORT position, flip the sign of `trend` and `ema_relationship` before applying (so "trend supports my position" reads correctly either side).

## Weight tables (point weights; blank = 0)

| feature (cᵢ) | trend_continuation | pullback | breakout | mean_reversion | exhaustion_reversal | crash |
|---|---:|---:|---:|---:|---:|---:|
| trend (dir-adj)        | +30 | +18 | +12 |  −22 | −18 |     |
| ema_relationship (dir) | +15 | +6  | +12 |  −10 | −8  | +12 |
| acceleration           | +12 | −6  | +16 |      | −6  | +8  |
| deceleration           | −14 | +14 | −12 |  +6  | +8  | −6  |
| impulse                | +8  |     | +18 |  −6  |     | +14 |
| overextension          | −10 | +8  |     |  +20 | +16 |     |
| exhaustion             | −12 | +6  |     |  +22 | +26 |     |
| reversal_confirm       | −18 | −10 | −8  |  +12 | +24 |     |
| bear_state_score /100  |     |     |     |      |     | +40 |
| **required-available set** | trend,ema,accel,decel,overext,exh,rev | trend,ema,decel,overext,exh,rev | trend,ema,accel,decel,impulse,rev | trend,ema,decel,overext,exh,rev | trend,ema,accel,decel,overext,exh,rev | ema,accel,decel,impulse,bear |

Notes per score:
- **trend_continuation** — high when an aligned trend is accelerating and NOT exhausted/reversing. The trend-Trailing candidate keys off THIS (widen/hold while high; suppress widening as it falls). The load-bearing score.
- **pullback** — high when the trend is intact but momentum has decelerated with a mild overextension reset and no reversal confirmation. P2 `pullback_recovery` will later dominate; the P1 proxy is deliberately conservative.
- **breakout** — P1 proxy (impulse+acceleration+ema); the P2 `breakout` structural feature will replace the proxy weight when built.
- **mean_reversion** — stub family; provided for taxonomy/telemetry completeness only.
- **exhaustion_reversal** — high on overextension+exhaustion+confirmed rejection against the move.
- **crash** — dominated by `bear_state_score` (already a 0..100 primitive) with impulse/accel modifiers; this is the only score whose backbone is an existing validated signal.

## Change control
Weights are frozen for the build + shadow campaign. Any change after Wave-5 (threshold re-tune) is an orchestrator-only edit here + a re-run of the affected telemetry, logged in this file.
