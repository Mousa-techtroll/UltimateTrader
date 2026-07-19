# L4-1 redesign — Phase 1 behavior-neutral audit (results) + Phase 2 policy design

Audit build: `AUDIT_ENGINEREL` recorder (byte-identical `d6549628`/$34,940.18/869), 2005 scored candidates
logged; joined to the baseline fills by nearest-preceding D1/H4 context; relationship recomputed per fill.

## Fills by signal-to-context relationship (whole book)
| relationship | n | net $ | avg $ | WR% |
|---|--:|--:|--:|--:|
| ALIGNED | 513 | +26,540 | 52 | 46 |
| COUNTER | 202 | +4,192 | 21 | 45 |
| MIXED | 140 | +4,202 | 30 | 48 |
| NEUTRAL | 14 | +577 | 41 | 64 |

**ALIGNED is the dominant profit engine (+$26.5k, avg $52) — but COUNTER (+$4.2k) and MIXED (+$4.2k) are
BOTH net-positive.** Raw L4-1 destroys the COUNTER+MIXED cohorts (~$8.4k net) plus down-tier/down-risk
collateral on the rest ≈ the measured −$15k. So counter-trend is a real, smaller, positive edge — not a defect.

## Fills by engine × relationship (net $ / n)
| engine | ALIGNED | COUNTER | NEUTRAL | MIXED | intent (taxonomy) |
|---|--|--|--|--|--|
| EngulfingEntry | **+11,417/147** | · | +511/5 | −268/8 | ALIGNMENT (bull-only) |
| PinBarEntry | **+9,706/266** | **+3,289/76** | +2/7 | −500/69 | REVERSAL (bidirectional!) |
| MACrossEntry | +3,610/55 | · | · | +594/3 | TREND (ALIGNMENT) |
| PullbackContinuationEngine | −88/8 | −377/10 | · | **+3,847/25** | PULLBACK (earns in MIXED) |
| ExpansionEngine | +1,662/20 | +233/6 | +64/2 | +3/2 | BREAKOUT (ALIGNMENT) |
| CrashBreakoutEntry | +98/12 | **+672/106** | · | +512/32 | MEAN-REV fade (COUNTER) |
| FailedBreakReversal | +134/5 | +376/4 | · | +15/1 | REVERSAL (COUNTER) |

## Key structural findings that drive the policy
1. **Alignment engines earn in ALIGNED** — Engulfing (+$11.4k), MACross (+$3.6k), Expansion (+$1.7k). Reward D1/H4 confluence for these. (Engulfing's MIXED −268 and COUNTER≈0 → it should NOT trade counter; alignment reward is correct FOR IT.)
2. **PinBar is genuinely bidirectional** — earns in BOTH ALIGNED (+$9.7k, short in downtrend = rejection that's also trend-aligned) AND COUNTER (+$3.3k, short into uptrend = fade). Its edge is REJECTION QUALITY (wick), not trend relationship. Its MIXED cohort is the only loser (−$500/69) → the real demotable cohort for PinBar is MIXED, not COUNTER.
3. **CrashBreakout is a pure fade** — +$672/106 COUNTER + $512/32 MIXED, only +$98/12 ALIGNED. Reward exhaustion (already death-cross + EMA21-extension gated), never penalize its COUNTER.
4. **PBC earns almost entirely in MIXED** (+$3,847/25) — pullback continuation fires when D1/H4 disagree (the pullback). Its ALIGNED/COUNTER are small negatives. So for PBC, MIXED is the thesis.
5. **The only broadly-negative cohort is MIXED for the alignment/reversal-candle engines** (Engulfing −268, PinBar −500) — a candidate demotion target, but tiny.

## Phase 2 — engine-aware context policy (design)
Replace the single global trend+macro "alignment" points with:
- **Two evaluator outputs:** `context_strength` (direction-neutral: |macro| + trend-agreement + adx band, already computed) and `relationship` (signed: ALIGNED/COUNTER/NEUTRAL/MIXED).
- **Engine intent** carried on the signal (TREND/PULLBACK/BREAKOUT/MEAN_REVERSION/REVERSAL/CRASH/HYBRID), sourced from the taxonomy (plumb a field from the plugin through the signal to the evaluator).
- **Per-intent context policy** for the (previously global) alignment points:
  - TREND / BREAKOUT / PULLBACK-when-aligned (MACross, Engulfing, Expansion): award the alignment points ONLY when ALIGNED × strong context (their profit cohort). No counter reward.
  - MEAN_REVERSION / REVERSAL / CRASH (CrashBreakout, RangeEdgeFade, FailedBreakReversal): award quality from EXHAUSTION/REJECTION (RSI/ATR extension, wick, sweep-reclaim, death-cross regime — reuse the existing Factor-1.5 RSI bonus, generalize it) and DO NOT penalize COUNTER; treat a strong opposing context as confirmation, not demerit.
  - REVERSAL-bidirectional (PinBar): score on rejection quality direction-neutrally (keep both its ALIGNED and COUNTER cohorts); the demotable cohort is its MIXED losers.
  - PULLBACK (PBC): credit MIXED (its thesis); don't reward pure alignment.
- **Thresholds recalibrated per intent/policy**, not globally (the raw-then-global-lower approach floods the book — REJECTED, RESULTS in DESIGN.md).

## Pre-registered acceptance criteria (finalized from Phase 1, BEFORE Arm C)
Arm C adopted only if vs `d6549628`: **net ≥ −2%** (≥ $34,241), **Sharpe ≥ 2.96**, **PF ≥ 1.42**, **EqDD ≤ 15.24%** on primary; **GH net ≥ −5%**; AND the engine×relationship re-attribution shows: Engulfing/MACross/Expansion ALIGNED profit retained (≥95%), PinBar ALIGNED **and** COUNTER retained (≥95% each), CrashBreakout COUNTER retained (≥95%), PBC MIXED retained (≥95%); AND no engine's realized expectancy sign inverts. If Arm C can't clear this, L4-1 remains an open architectural defect (documented), production stays baseline — it does NOT get force-merged raw.
