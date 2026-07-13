# Gold v2 · Candidate A · Phase-1 CRT controls (§4.2)

Every CRT state was scored against four controls on the SAME next-day metrics (see `daily-crt-prediction-study.md` for full tables). The load-bearing metric is the **clean directional win rate** = P(+0.5×ATR before −0.5×ATR from next-day open) and its **edge = MFE−MAE (ATR)**; a driftless coin ≈ 50%/0.0. Controls: opposite-CRT (falsification), seeded-random matched to each state's class balance (placebo), previous-day direction, D1 EMA20 trend.

## Result summary
| State | Aggregate vs controls | LONG leg | SHORT leg | Per-era | Verdict |
|---|---|---|---|---|---|
| **S1** sweep-reclaim | edge +0.023 (Van) / +0.008 (GH) — *below* the trend baselines (0.016–0.018) | mild real (+0.088/+0.028, beats random) | **negative** (−0.036/−0.010) | — | **does not clear** (long-only, thin) |
| **S2** premium/discount reversion | **anti-predictive** — loses to its own opposite on both feeds | worse than random long | negative | — | **killed** (momentum > reversion) |
| **S3** inside-day quartile→continuation | edge +0.190 (Van) / +0.105 (GH) — beats all controls in aggregate | Van +0.153 (beats random); **GH +0.123 ≈ random +0.111 (trend confound)** | Van +0.230; **GH pre-2016 −0.075, dirAcc 34%** | **2016+ only**: Van is 100% post-2016; GH strong 2016+ (+0.218) but weak pre-2016 (+0.025) | **clears the mechanical aggregate, FAILS the stability/frequency sub-bar** |

## Why S3 does not cleanly advance (per program §16 "stable across BOTH feeds" and §14 "not primarily one era")
1. **Era-concentrated.** The edge lives in 2016+. Vantage (2018.12→) *cannot* cross-era-validate at all. On GoldHistory the pre-2016 half is weak (edge +0.025) and its **short leg is outright negative** (−0.075, directional accuracy 34%). Cross-feed agreement exists only *inside* the modern era.
2. **Long leg is a trend proxy on the cross-feed.** GoldHistory S3-LONG edge (+0.123) barely exceeds a random long (+0.111), and a random long's directional accuracy (61.5%) *beats* S3-LONG's (54.9%) — the gold uptrend, not CRT, is carrying most of the long side there.
3. **Low frequency.** ~10 signals/year (Van 76 total, GH 243 total). After the Phase-2 opposite-manipulation + M15-confirmation filter, executable fills would fall well short of the §10 standalone bar (≥150).

## Net
Only S3 shows any genuine directional value, and only as a **modern-era (2016+), low-frequency, partly-trend-confounded** signal — a plausible inside-bar compression→expansion effect, but NOT the stable cross-era/cross-feed edge §16 requires to justify building the Phase-2 M1/M15 event study. S1/S2 are dead.
