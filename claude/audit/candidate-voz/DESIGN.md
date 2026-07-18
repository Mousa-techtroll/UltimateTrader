# Candidate: closed-bar vol-regime ATR with frequency-matched threshold (Task E)

## Directive
*"For the closed-bar ATR work, test frequency-matched threshold recalibration rather than rejecting
closed-bar semantics using thresholds calibrated on forming-bar data."*

## Semantics — what the flag changes
`CVolatilityRegimeManager::Update()` (:241) reads the current H1 ATR to classify the volatility regime:
```
current_atr = InpVolRegimeClosedBar ? atr_buffer[1] : atr_buffer[0];
```
- `atr_buffer[0]` = the **forming** bar's ATR (production default). At the once-per-bar Update moment the
  forming bar has just opened, so its true-range is near-zero and iATR(14)'s [0] value is **deflated**
  (measured median `atr0` ≈ **6.5%** below the closed value).
- `atr_buffer[1]` = the last **closed** bar's ATR (the candidate). Fully formed, not deflated.

The regime feeds two production-live gates, both keyed on `(VOL_HIGH || VOL_EXTREME)`, which is exactly
`atr_ratio >= InpVolNormalThresh` (1.0), where `atr_ratio = current_atr / average_atr`:
1. `CExpansionEngine::IsExpansionContext()` (:550-552) — the coarse gate admitting the composed
   session/expansion sub-strategies (with a directional H4 trend).
2. `CMarketContext::GetDayType()` (:1019-1021) — `DAY_VOLATILE` classification stamped onto each signal.

`average_atr` is computed by `UpdateATRHistory()` independently of the flag, so it is **identical** in both
modes. Therefore switching forming→closed multiplies `atr_ratio` by ~`k = atr1/atr0` (median 1.0646) and
**inflates** the `>= 1.0` gate rate. The OR'd expansion term (`atr[N]/atr[N-1] >= 1.5`) is negligible
(0.11% of bars) and scale-invariant to `k`, so the gate is entirely regime-driven.

## Why the prior rejection was confounded
The earlier closed-bar A/B held `InpVolNormalThresh` at its forming-calibrated **1.0** and measured
−2.1%/−5.4%. But at 1.0 the closed-bar gate fires on **44.9%** of bars vs the forming baseline's **34.8%** —
a **+10.1pp / +29% relative** inflation. That over-admits marginal expansion contexts; the loss reflects
*more (lower-quality) entries*, not the *quality* of closed-bar classification. Apples-to-oranges.

## Frequency-match (measure-only AUDIT pass, behavior-neutral → reproduced `d6549628`/$34,940.18)
`AUDIT_VOLRATIO` (AuditCounters.mqh) logged `(time, atr0, atr1, avg)` for all **44,267** H1 Update bars
(2019–2026). Offline (`recalib_voz.py`):

| | forming (atr0) | closed@1.0 (atr1) |
|---|---|---|
| regime `P(ratio≥1.0)` | 0.3477 | 0.4491 |
| expansion `P(≥1.5)` | 0.0011 | 0.0009 |
| **combined `vol_expanding`** | **0.3480** (target) | **0.4493** (inflated) |

Solving `P(atr1/avg ≥ T) OR expansion = 0.3480` gives **`T* = 1.074`** (closed gate rate 0.3482,
|diff| 0.0001) — i.e. scale the threshold by the same `k` the numerator shifted by (`1.0 × 1.0646 ≈ 1.074`).

## A/B design (this candidate)
Build with `RESEARCH_CANDIDATES` (re-exposes `InpVolRegimeClosedBar`). Legs vs baseline `d6549628`/$34,940.18:
- **REV** — `closed=false, normal=1.0` → must reproduce `d6549628` (research-build neutrality/reversibility).
- **MATCH** — `closed=true, normal=1.074` → the frequency-matched candidate (the directive's test).
- **DEF** — `closed=true, normal=1.0` → default control, reproduces the prior rejection basis on the new baseline.
- **MATCH-GH** — GoldHistory cross-feed for the candidate.
- First-divergence attribution on entry-key (EntryTime, EngineName, Direction, round(EntryPrice,2)).

## Adoption rule
Adopt only if the frequency-matched candidate is **net-and-risk non-negative** vs baseline on BOTH feeds
(closed-bar is the more correct semantics, so at matched frequency it should be ≥ baseline if the quality
argument holds). If MATCH ≈ baseline (neutral) it is a correctness-hardening adopt-or-hold call; if MATCH < baseline
even at matched frequency, closed-bar semantics are genuinely worse here and stay rejected — but now on a
fair, frequency-controlled basis, not the confounded one.
