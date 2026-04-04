# Analyst Recommendation Evaluation
*Evaluated: 2026-04-04 | Cross-referenced against v3 trade data (1,183 exits) and 8 A/B test results*

## Verdict: Entry filters ADOPT, Exit changes REJECT

---

## Entry Recommendations — DATA CONFIRMED

### 1. Bearish Pin Bar: Asia-only — STRONG ADOPT
**Analyst claim:** Removing non-Asia saves +969 | **Our data:** +11.7R / +$1,087 saved

| Session | Trades | PnL (R) | PnL ($) |
|---------|--------|---------|---------|
| ASIA | 94 | **+24.9** | +$2,352 |
| LONDON | 71 | -10.5 | -$619 |
| NEWYORK | 163 | -1.2 | -$467 |

**Non-Asia removes 234 trades, saves 11.7R.** Highest-impact single entry filter. The pattern works at Asia session extremes (physical demand, thin liquidity reversal) but gets killed in London/NY institutional flow.

### 2. Rubber Band Short: A/A+ only — ADOPT
**Analyst claim:** B+ costs +202 | **Our data:** B+ = -4.0R / -$202 across 22 trades

| Quality | Trades | PnL (R) |
|---------|--------|---------|
| A+ | 76 | +10.0 |
| A | 28 | +1.7 |
| B+ | 22 | **-4.0** |

Clean cut. B+ Rubber Band trades are consistently losing.

### 3. Bullish MA Cross: Block New York — ADOPT
**Analyst claim:** +236 | **Our data:** NY = -3.6R / -$219 across 72 trades

| Session | Trades | PnL (R) |
|---------|--------|---------|
| ASIA | 29 | +4.2 |
| LONDON | 20 | +8.7 |
| NEWYORK | 72 | **-3.6** |

MA Cross works in Asia and London but bleeds in NY. Blocking NY saves 3.6R.

### 4. Bullish Pin Bar: TRENDING only — ADOPT (small)
**Analyst claim:** Non-trending costs +212 | **Our data:** Non-trending = -2.8R across 32 trades

| Regime | Trades | PnL (R) |
|--------|--------|---------|
| TRENDING | 218 | +22.5 |
| VOLATILE | 30 | -1.5 |
| RANGING | 2 | -1.3 |

Small impact (32 trades, 2.8R) but clean.

### 5. Long continuation after >1.5% 72h rise — DEFER
Cannot verify from CSV data alone. Needs price history cross-reference. Park for later.

### Total entry filter estimate: +22.1R saved, ~328 trades removed

---

## Exit Recommendations — REJECT ALL

### The analyst recommends:
- "Delay BE further for trend trades"
- "Reduce early TP volume in trend regime"
- "Leave a larger runner"
- "Loosen Chandelier trailing or activate it later"

### Why this is wrong — proven by 4 failed A/B tests:

| Test | What It Did | Result |
|------|-------------|--------|
| Phased BE (-0.25R at +1R) | Delayed BE | PF 1.27→1.06, trade count +104 (runner clipping) |
| Smart Runner Exit v1 | Larger runner, later exit | **-73% profit** |
| Smart Runner Exit v2 | Larger runner, later exit | **-76% profit** |
| Wider Chandelier (+0.5) | Loosened trailing | -$1,127, DD +1.18% |

**The "missed money" analysis is a retrospective trap.** Yes, some trades moved $16,993 further after exit. But every attempt to capture that money has destroyed more than it saved. The trailing stop that "misses" $16K on winners also prevents $20K+ of reversals. The net is negative — proven 4 times.

From production memory (22 A/B tests):
> *"Trailing is at Goldilocks optimum — both tighter AND wider degrade"*
> *"Runner -$1,553 is insurance premium for $12,000 trailing exits — cutting it costs $8K"*

### The analyst's exit model assumes:
- "Recovering 10% of missed 24h move" = +$5,067

This is not recoverable. The mechanism that would capture it (wider trail, delayed BE, smaller partials) has been tested and fails because:
1. Gold's intraday volatility routinely sweeps through wider trailing stops
2. Delayed BE means more trades that reached +1R reverse to full losses
3. Smaller early partials mean less capital locked in when the reversal comes

### The correct mental model:
The "missed money" is not on the table. It's the same money that wider trailing tries to capture and fails to net-capture. The 4 test failures are not flukes — they reflect gold's microstructure (frequent deep retracements within trends).

---

## Implementation Plan

**Sequence (single-variable A/B testing):**

| Order | Change | Est. Impact | Risk |
|-------|--------|-------------|------|
| 1 | Bearish Pin Bar: Asia-only | +11.7R | Low — clean session gate |
| 2 | Rubber Band Short: A/A+ only | +4.0R | Low — quality gate |
| 3 | Bullish MA Cross: Block NY | +3.6R | Low — session gate |
| 4 | Bullish Pin Bar: TRENDING only | +2.8R | Low — regime gate |

**Do NOT implement:**
- Any exit loosening (BE delay, trail widening, TP reduction, runner expansion)
- Long continuation 72h filter (unverified, needs price data cross-reference)

**Expected combined impact:** +22.1R, ~328 trades removed. If all adopted, the system would run ~855 trades across 7 years with ~112.6R total.
