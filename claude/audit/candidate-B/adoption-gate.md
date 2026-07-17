# Adoption gate — `candidate-session-breakout-dst-only-B`

**Candidate.** Composed `CSessionBreakoutEntry`: **DST-correct the breakout-window clock only**
(`GetGMTHour` at the window check), Asian **range-construction clock left legacy** (fixed broker hour).
= research flags `InpResSessBreakoutDST=true`, `InpResSessRangeDST=false`. Frozen build `SESSB.ex5`
md5 `4e589f6f…`, primary Stats md5 `1ed88d41`.

**Production stays `baseline-input-cleanup-388` until this gate returns PASS or FAIL. No tuning of the
candidate to pass — criteria below are fixed before the campaign analytics.**

## What this gate must decide
1. Is Arm B genuinely better than production A, on **risk-adjusted** and **robust** terms — not just
   higher raw net?
2. Is the A→B system-level gain an **intended portfolio effect** (legit) or a **shared-state / ordering
   bug** (spurious, and a defect to file)? *A gain routed through portfolio interaction is NOT invalid
   by that fact alone.*

## Pre-registered PASS criteria (ALL must hold)

- **G1 Return.** B net ≥ A net on the primary feed. *(seed: A $32,503.03 / B $34,858.89)*
- **G2 Risk-adjusted.** B does not degrade risk-adjusted return: **Recovery Factor ≥ 0.90 × A** AND
  **Sharpe ≥ A**. Rationale: B may carry more drawdown; adoption requires the extra profit not to come
  at a materially worse net/DD. *(seed: A Rec 4.81 / Sharpe 2.87; B Rec 4.47 / Sharpe 2.96 — B Rec =
  0.93× ✓ borderline, Sharpe ✓)*
- **G3 Concentration robustness.** B ≥ A must survive **every** ablation: ex-largest-trade,
  ex-best-5-trades, ex-best-year, ex-2025, ex-2026. If B beats A only because of one trade / one year,
  **FAIL**.
- **G4 Cost stress.** B ≥ A must survive escalating adverse per-fill costs (spread + slippage +
  commission) up to a realistic worst case. Because B trades more (869 vs 865 pos, +12 deals), higher
  costs penalize B more — this directly tests "B just trades more." Threshold: B stays ≥ A at
  +$20/position of added round-trip cost; report the break-even cost where B crosses below A.
- **G5 Cross-history.** B ≥ A on the independent GoldHistory feed (already: GH B $29,525.79 > GH A
  $28,685.51 ✓), AND the **session-book** direction is non-negative on both feeds (primary composed
  +$92, GH composed +$533 ✓). If the total-level B>A does not replicate cross-feed, **FAIL**.
- **G6 Mechanism.** The A→B coupling is diagnosed as an **intended** portfolio/exposure/management
  effect, NOT a shared-state or ordering bug. If a bug is found driving the 460-trade exit ripple,
  **FAIL** the candidate AND file the bug as a separate defect (the "gain" would be spurious).

## FAIL / INCONCLUSIVE
- **FAIL** if any of G1–G6 fails, OR if the advantage is one-trade/one-year concentrated (G3), OR
  reverses under cost stress (G4) or cross-history (G5), OR is bug-driven (G6).
- **INCONCLUSIVE** (non-appealable, do-not-relitigate) allowed if the picture is genuinely mixed —
  e.g., robust direction but immaterial magnitude with a worse recovery factor — in which case
  production stays 388 and the candidate is shelved, not merged.

## Metric panel (A vs B, to be filled by the campaign)
peak equity · peak closed balance · final balance · peak-to-end giveback · balance DD · equity DD ·
recovery factor · Sharpe · underwater duration · yearly net · per-ablation net · cost-stress curve ·
GoldHistory replication · coupling mechanism verdict.

## Wiring note (only relevant IF PASS)
Adoption = promote `InpResSessBreakoutDST` from a `#ifdef RESEARCH_SESSION` research flag to a real
production input (breakout-window DST on the composed instance), Asian range untouched — its own
identity baseline + commit, never folded into another change. Full-DST (Arm 1/D) and range-DST (Arm C)
remain rejected directions regardless of this gate's outcome.
