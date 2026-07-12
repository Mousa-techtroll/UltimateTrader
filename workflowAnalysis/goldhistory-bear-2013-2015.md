# The 2013-2015 Sustained-Bear Deep-Dive (GoldHistory, Model=1)

**Headline: the EA HANDLES the sustained bear.** Standalone diagnostic (fresh $10k, 2013-01→2015-12): **+$1,128 net, PF 1.06, Sharpe 0.65, EqDD 20.87%, 366 positions**. Within the continuous 2011-2017 run the 2013-2015 slice is ~flat-to-positive (2013 +$1,475 / 2014 −$23 / 2015 −$362). The bear is **not** the structural failure — that is the 2016 transition (see `goldhistory-structural-2011-2017.md`).

## Long book — shuts down correctly, residual longs weak
- Long fills fall to **45 over 3 years** (~15/yr vs ~77 in 2011) — the reduction mechanism works.
- Residual longs still bled −4.7R / −$858 / PF 0.73. The worst: **Engulfing longs 19 fills, −8.5R, −$1,200, WR 16%, PF 0.41** — buying engulfing candles into a downtrend gets chopped up. Pin-Bar longs held up (+$389). → the long-reduction is fine; the specific weakness is **Engulfing longs in down regimes**.

## Short book — genuine diversification, from the CONTINUATION family
2013-15 shorts net **+9.5R / +$1,946**, ~7× the long participation (321 vs 45 fills) — regime-appropriate. Source, by engine:

| Short engine (2013-15) | Fills | Net $ | PF | WR |
|---|--:|--:|--:|--:|
| **Expansion** | 11 | **+1,352** | 9.12 | 73% |
| **Pullback-Continuation** | 24 | **+1,028** | 2.13 | 50% |
| Crash / Rubber Band | 166 | −57 | 0.99 | 37% |
| Bearish Pin Bar | 120 | −376 | 0.94 | 37% |

**The bear profit is entirely the *continuation* shorts (Expansion + Pullback = +$2,380), not the reversal/crash shorts.** Crash fired the most (166×) for nothing; bearish Pin Bars lost. This is the key structural lesson: when shorts are genuinely needed (a real down-trend), it is the **trend-riding continuation short** that pays — not the mean-reversion Crash/Pin short.

## Implications
1. The modern short-scarcity is **regime-correct** — shorts have real edge only in sustained bears, via continuation. Do NOT manufacture more shorts in the 2019-25 bull.
2. The genuine bear component is **Expansion/Pullback continuation shorts**, not Crash. Crash's modern shine is a narrow 2021-2023 episode; over a real bear it added nothing and (in the transition) destroyed the book.
3. **Engulfing longs** are a defined bear weak-point (−$1,200, 16% WR) — regime-restrict.
4. Bear drawdown (20.87% standalone) is elevated but survivable; the un-survivable 40% only appears when the 2016 transition compounds on top.
