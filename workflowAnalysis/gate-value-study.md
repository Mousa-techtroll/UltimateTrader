# Gate-Value Study — do the short gates remove BAD trades or GOOD ones?

**Date:** 2026-07-11 · **Analyst:** gold-algo-trader · **Mode:** offline statistical (no tester runs, no source edits)
**Script:** `claude/gate/gate_value_study.py` (deterministic, stdlib-only) · **Raw output:** scratchpad `gate_run.txt`, `addendum_run.txt`, `gate_study_results.json`
**Data:** `GoldHistory/XAU_1h_data.csv` — 124,887 H1 bars, **2004-06-11 → 2025-12-31** (22 years; weekdays only, 0 dup timestamps).
**State ledger:** extended by re-pointing the validated `sb11_state_model.py` loader at the 22-year feed.

> **FACTS** = measured numbers. **JUDGMENT** = my interpretation as PM. Kept separate throughout.

---

## 0. Read this first (the one-paragraph verdict)

**FACT.** A standardized short taken at *every* H1 bar and managed by the TMF exit has **E[R] = −0.0355** (WR 70.8%, avgWin +0.358R, avgLoss −0.989R, **payoff ratio 0.36**, breakeven-WR **73.4%**). It is negative in **every** era, including the 2011-2015 bear (−0.0108, t = −2.8). **JUDGMENT.** The gold-short book is a *structurally* negative-expectancy scalp whose ceiling is set by the **exit**, not the entry gates: the TMF banks winners at ~0.36R while losers pay ~1R, so it needs 73% WR and gets 71%. Against that backdrop the gate audit splits cleanly: the *cheap* gates (below-EMA50/200, D1 death-cross, not-Friday) genuinely remove bad shorts (+0.02–0.04R lift, t = 4–9, robust across eras); the *expensive* gates that do the ~95% starving — **room ≥ 1.2R, the over-extension veto, volume-confirm, session, lower-high** — have **zero or significantly NEGATIVE lift**. They remove good/neutral trades. The starvation is real and it buys no edge.

---

## 1. Methodology

### 1.1 Standardized short-outcome metric (dependent variable) — Step 1
For every H1 bar *t*: entry = close[t]; stop = max(high[t−5..t]) + 0.5·ATR14(H1)[t]; risk **R** = stop − entry (>0 always).
- **realized-R (metric of record):** TMF exit — bank at the closer-to-entry of {1R target, nearest lower H1 swing low}; −1R if stop touched; time-exit at 48h close otherwise. Bounded in [−1, +1].
- **MFE_R / MAE_R** over the next 48h; **forward raw return** at 24h/48h.
- **Touch-order convention:** *adverse-first* (if a bar touches both stop and target, assume the stop). Pessimistic; bounded by the sensitivity table in §6.

### 1.2 Gates (Step 2) — binary conditions on **closed** data at bar *t*
State severity (sev2/3/4, extended ledger); location (close<EMA50, close<EMA200, lower-high); trigger (EMA21 zone-tag + close<EMA21 + down-close); room-to-support (sweep k); over-extension veto (sweep m); RR-to-far-TP≥1.3; volume>rolling-20-mean; day-of-week; session; D1 death-cross; H4 EMA21<EMA50.

### 1.3 State-ledger extension — sanity
Re-ran `sb11_state_model.py` over the 22-year feed. **On the 2019-2026 overlap (40,713 bars) vs the validated `sb11_states.csv`: exact-label agreement 96.6%, severity agreement 97.8%.** The two feeds share identical timestamps and near-identical prices (median close diff 0.06). **JUDGMENT:** extension trustworthy; the ~3% label drift is warmup/feed micro-differences, immaterial to severity-band lift.

### 1.4 Statistical power
Base sample = 124,687 bars (valid outcome + EMA200 warmup). Lift SE = √(SE_pass² + SE_fail²). Era means carry SE 0.002–0.008 (era n = 17k–37k) → era-level negativity is 2–13 SE from zero (**real**). Single-gate lifts of ±0.02–0.04 carry t = 3–9 (**real**). Deep-stack cohorts (§4) collapse to n = 18–434 → **no statistical claim possible**; flagged inline.

### 1.5 Honest caveats
- Data ends **2025-12-31**, so era "2023-2026" is really **2023-2025** (n = 17,217).
- Pre-2011 volume is tick-count (median 200) not real volume → the volume gate's 2004-2010 cell is unreliable; its 2011+ signal is not.
- Session gate uses server-hour (feed TZ ≈ GMT+2/3, *unverified*) → treat the session verdict as directional.
- One short per bar overlaps heavily; lifts are *relative* rankings, not a tradeable P&L.

---

## 2. Unconditional short expectancy (the baseline every gate is measured against) — FACT

| Era | n | E[R] | SE | WR |
|---|---:|---:|---:|---:|
| ALL 2004-2025 | 124,687 | **−0.0355** | 0.0019 | 70.8% |
| 2004-2010 | 37,093 | −0.0400 | 0.0037 | 68.0% |
| 2011-2015 (big bear) | 29,162 | **−0.0108** | 0.0038 | 73.8% |
| 2016-2018 | 17,623 | −0.0342 | 0.0050 | 72.2% |
| 2019-2022 | 23,592 | −0.0343 | 0.0043 | 72.0% |
| 2023-2025 (record bull) | 17,217 | −0.0710 | 0.0053 | 68.4% |

**Payoff decomposition (unconditional):** WR 70.8%, avgWin **+0.358R**, avgLoss **−0.989R**, payoff **0.362**, breakeven-WR **73.4%**.
**JUDGMENT:** the 2.6-pt gap between actual WR (71) and breakeven WR (73) is the whole problem. Even the big bear is the *least* negative era, not a positive one — under the metric of record.

---

## 3. Per-gate value (LIFT = E[R|pass] − E[R|fail]) — Step 3 — FACT

Whole-sample, sorted by lift. `t` = lift / SE_lift.

| Gate | base% (pass) | E[R] pass | E[R] fail | **LIFT** | t | Verdict |
|---|---:|---:|---:|---:|---:|---|
| **dow_not_friday** | 80.5 | −0.0270 | −0.0706 | **+0.0435** | **+8.9** | KEEP (top lever) |
| **dow_mon_tue** | 40.0 | −0.0164 | −0.0483 | +0.0319 | +8.2 | KEEP |
| **loc_close<EMA200** | 44.1 | −0.0236 | −0.0449 | +0.0212 | **+5.6** | KEEP |
| **loc_close<EMA50** | 45.9 | −0.0245 | −0.0448 | +0.0203 | **+5.3** | KEEP |
| **align_D1_deathcross** | 27.0 | −0.0222 | −0.0404 | +0.0182 | +4.3 | KEEP (regime) |
| state_sev2 (only) | 14.3 | −0.0220 | −0.0378 | +0.0158 | +2.9 | keep-ish |
| trig_ema21_reject | 18.3 | −0.0284 | −0.0371 | +0.0087 | +2.2 | timing only |
| state_sev≥2 | 31.6 | −0.0307 | −0.0377 | +0.0070 | +1.7 | weak |
| align_H4_ema21<50 | 43.6 | −0.0317 | −0.0385 | +0.0067 | +1.8 | weak |
| room_k0.5 | 38.6 | −0.0343 | −0.0363 | +0.0020 | +0.4 | ≈zero |
| **loc_lower_high** | 49.0 | −0.0370 | −0.0341 | **−0.0030** | −0.8 | DROP (no edge) |
| state_sev3 | 8.1 | −0.0320 | −0.0358 | +0.0038 | +0.5 | weak |
| **state_sev4** (BEAR_TREND) | 9.2 | −0.0430 | −0.0348 | **−0.0082** | −1.3 | do NOT weight up |
| **room_k1.0** | 23.0 | −0.0473 | −0.0320 | **−0.0154** | −2.5 | DROP/starves |
| **sess_London_NY** | 44.1 | −0.0448 | −0.0282 | **−0.0165** | −4.2 | DROP/invert |
| **room_k1.2** (prime suspect) | 19.5 | −0.0507 | −0.0318 | **−0.0189** | **−2.9** | **DROP** |
| **rr_far≥1.3** (≈room) | 18.0 | −0.0523 | −0.0318 | −0.0205 | −3.0 | DROP |
| **room_k1.5 / k2.0** | 15.7 / 11.4 | −0.052 / −0.056 | −0.033 | −0.019 / −0.023 | −2.6/−2.7 | DROP |
| **vol_above_avg** | 40.9 | −0.0523 | −0.0239 | **−0.0284** | **−7.3** | DROP/invert |
| **overext_m3** (pass = NOT extended) | 91.3 | −0.0382 | −0.0079 | **−0.0303** | **−4.6** | **DROP/invert** |
| overext_m2 | 82.5 | −0.0409 | −0.0102 | −0.0306 | −6.5 | DROP/invert |

### 3b. LIFT by era (robustness is the verdict, not the point estimate) — FACT
`+lift` = removes bad shorts in that era; `−lift` = removes good shorts.

| Gate | 2004-2010 | 2011-2015 | 2016-2018 | 2019-2022 | 2023-2025 |
|---|---:|---:|---:|---:|---:|
| dow_not_friday | +0.059 | +0.045 | +0.053 | +0.038 | +0.008 | **← positive all 5 eras** |
| dow_mon_tue | +0.060 | +0.011 | +0.027 | +0.023 | +0.023 | positive all 5 |
| loc_close<EMA50 | −0.003 | +0.006 | +0.069 | +0.032 | +0.017 | positive 4/5 |
| loc_close<EMA200 | +0.029 | −0.009 | +0.049 | +0.005 | +0.026 | positive 4/5 |
| align_D1_deathcross | +0.021 | **+0.033** | −0.042 | −0.006 | −0.285 (n=299) | **bear-only** |
| state_sev2 | +0.025 | +0.005 | −0.014 | +0.027 | −0.011 | mixed |
| loc_lower_high | −0.009 | −0.001 | +0.010 | −0.001 | −0.016 | ≈0 all eras |
| room_k1.2 | −0.005 | +0.003 | −0.049 | −0.019 | −0.042 | neg/flat 4/5 |
| overext_m3 | −0.043 | −0.012 | −0.034 | −0.019 | −0.035 | **neg all 5** |
| vol_above_avg | −0.016 | −0.043 | −0.036 | −0.016 | −0.039 | **neg all 5** |
| sess_London_NY | −0.001 | −0.022 | −0.030 | −0.033 | −0.005 | neg all 5 |

**JUDGMENT.**
- **D1 death-cross** is a *conditional* gate: its lift is +0.033 in the 2011-2015 bear but −0.28 (n=299) in 2023-2025. That negative is a feature — see §5: in the record bull the gate mostly *refused to fire*, and the few times it did were bull-traps. Its true value is **regime gating (sit-out), not per-trade lift.**
- **overext & volume are harmful in every single era** — the strongest robustness signal in the study, and it points the wrong way for a starving book.
- **lower-high** is ≈0 everywhere → pure participation tax.

---

## 4. Marginal stack — Step 4 — FACT (start = severity≥2 cohort, n=39,364, E[R]=−0.0307, WR 71.9%)

Add one gate at a time; `marg_lift` = E[R|kept] − E[R|dropped] *within the running cohort*.

| + gate | keep n | E[R] kept | dropped n | E[R] dropped | marg_lift | cohort E[R] |
|---|---:|---:|---:|---:|---:|---:|
| +close<EMA50 | 20,851 | −0.0234 | 18,513 | −0.0389 | **+0.0155** | → −0.0234 |
| +close<EMA200 | 19,719 | −0.0221 | 1,132 | −0.0464 | **+0.0243** | → −0.0221 |
| +lower_high | 12,091 | −0.0247 | 7,628 | −0.0179 | **−0.0068** | → −0.0247 (worse) |
| +D1_deathcross | 6,407 | −0.0159 | 5,684 | −0.0348 | **+0.0189** | → −0.0159 |
| +H4_ema21<50 | 5,975 | −0.0165 | 432 | −0.0068 | −0.0097 | → −0.0165 |
| +trig_ema21 | 1,579 | −0.0238 | 4,396 | −0.0139 | −0.0099 | → −0.0238 (worse) |
| **+overext_m3** | 1,424 | −0.0364 | 155 | **+0.0921** | **−0.1285** | → −0.0364 |
| +room_k1.2 | **48** | +0.0833 | 1,376 | −0.0406 | +0.1239 | → +0.0833 *(n=48, NOISE)* |
| +rr≥1.3 | 39 | +0.1282 | 9 | −0.1111 | +0.2393 | *(n=39, NOISE)* |
| +vol_above_avg | 18 | +0.0000 | 21 | +0.2381 | −0.2381 | *(n=18, NOISE)* |

**JUDGMENT — this table is the smoking gun.**
1. The gate that starves hardest, **over-extension (m3)**, dumps a cohort whose E[R] was **+0.0921** — it throws away the *winners* (deeply-extended trend continuations) and keeps the near-EMA50 shorts that get squeezed. It is not neutral; it is **inverted**.
2. After overext + room, the cohort is **48 bars out of an initial 39,364** — a 99.9% cull. That is the owner's "~95% filtered," and everything past `+overext` is statistical noise. The +0.083 / +0.128 "edge" from room/rr is 48- and 39-bar mirages.
3. The room gate's apparent marginal *lift* is a payoff artifact, not entry selection — see §6.

---

## 5. Room-k and over-ext-m sweeps — Step 5 — FACT (within severity≥2 cohort)

### 5a. ROOM-k (room to nearest lower H1 swing low ≥ k·R; "open road" passes)
| k | n_pass | base% | E[R] pass | E[R] fail | lift |
|---:|---:|---:|---:|---:|---:|
| 0.0 (off) | 39,364 | 100 | −0.0307 | — | — |
| **0.5** | 14,235 | 36.2 | −0.0187 | −0.0375 | **+0.0188** |
| 1.0 | 8,031 | 20.4 | −0.0320 | −0.0304 | −0.0016 |
| **1.2** | 6,784 | 17.2 | −0.0332 | −0.0302 | **−0.0030** |
| 1.5 | 5,432 | 13.8 | −0.0341 | −0.0302 | −0.0039 |
| 2.0 | 3,989 | 10.1 | −0.0279 | −0.0310 | +0.0031 |
| 3.0 | 2,529 | 6.4 | −0.0240 | −0.0312 | +0.0072 |

**room_k1.2 by era (within sev≥2):** +0.0365 / −0.0081 / −0.0445 / −0.0169 / +0.0372 → *inconsistent, negative in the two most-populated bear-adjacent eras.*

**Open-road vs defined-support (Addendum D, within sev≥2):**
| bucket | n | E[R] | WR |
|---|---:|---:|---:|
| open-road (no support <entry) | 1,485 | −0.0375 | 47.0% |
| defined-support, room[0,0.5) | 25,129 | −0.0375 | **82.8%** |
| defined-support, room[**0.5,1.0**) | 6,204 | **−0.0014** | 58.7% |
| room[1.0,1.5) | 2,599 | −0.0276 | 48.6% |
| room[1.5,2.5) | 2,345 | −0.0439 | 47.9% |
| room[2.5+) | 1,602 | −0.0166 | 49.1% |

**JUDGMENT — room≥1.2 is mis-thresholded on BOTH ends.** The only near-breakeven band is **room[0.5, 1.0)**. The [0,0.5) band has an 83% hit rate but −0.037 E[R] (tiny clipped wins vs full-R losses). Demanding **≥1.2R** lands squarely in the worst zone (−0.028 to −0.044) *and* cuts to 17% participation. **Best room-k ≈ 0.5** (exclude only the sub-0.5R clip-zone); ≥1.0 and above destroy edge. The gate's design intuition ("don't short into support") is **backwards for a TMF book** — the TMF *wants* nearby support to bank at.

### 5b. OVER-EXT-m (pass = close ≥ EMA50 − m·ATR; within severity≥2)
| m | n_pass | base% | E[R] pass | E[R] fail | lift |
|---:|---:|---:|---:|---:|---:|
| 2 | 31,055 | 78.9 | −0.0351 | −0.0142 | −0.0209 |
| 3 | 34,956 | 88.8 | −0.0325 | −0.0162 | −0.0163 |
| 4 | 37,370 | 94.9 | −0.0325 | +0.0038 | −0.0363 |
| 6 | 39,150 | 99.5 | −0.0315 | +0.1072 | −0.1387 |

**JUDGMENT.** Every threshold has **negative** lift, and the vetoed (over-extended) cohort improves monotonically to +0.107R. The over-extension veto is a mean-reversion filter applied to a trend-following short; in bears price extends and *keeps going*. **Best m = OFF (or ≥6).** Keep it only if you also flip the book to fade (different strategy).

---

## 6. Exit-convention sensitivity — the real ceiling — FACT (Addendum C)

| Touch order / TMF target | ALL E[R] | 2011-2015 E[R] |
|---|---:|---:|
| ADV-first / swing-clip *(metric of record)* | −0.0355 | −0.0108 |
| ADV-first / **1R-only** (no swing clip) | −0.0197 | **+0.0496** |
| FAV-first / swing-clip | +0.0006 | +0.0199 |
| FAV-first / 1R-only | +0.0073 | **+0.0752** |

**JUDGMENT — this is the most important table in the study.** Removing the swing-low clip (letting winners run to the full 1R target instead of banking at the first support) is worth **+0.016R unconditionally and FLIPS the 2011-2015 bear from −0.011 to +0.050**, even under pessimistic adverse-first accounting. The intrabar touch-order uncertainty (ADV vs FAV) is worth ~0.036R, so the honest unconditional read is **"break-even ± a cost's width."** The room gate's §4 marginal "edge" is the *same* payoff mechanism bought at 40× the participation cost: it only helps because reaching a far target lets winners approach 1R. **You do not need the room gate to get that — you need to stop clipping winners at support.**

---

## 7. Does a minimal, high-value gate SET clear zero? — FACT (Addendum B)

| Gate set | fires (% of bars) | E[R] | 2004-10 | 2011-15 | 2016-18 | 2019-22 | 2023-25 |
|---|---:|---:|---:|---:|---:|---:|---:|
| below_EMA200 | 44.1% | −0.0236 | −0.023 | −0.015 | −0.008 | −0.031 | −0.054 |
| below_EMA200 + notFri | 35.5% | −0.0173 | −0.016 | −0.007 | +0.002 | −0.029 | −0.051 |
| below_EMA50&200 | 34.8% | −0.0199 | −0.023 | −0.010 | +0.001 | −0.027 | −0.052 |
| **MINIMAL: <EMA50&200 + D1-deathcross + notFri** | **8.5%** | **+0.0077** | +0.053 | +0.013 | +0.009 | −0.031 | **0 fires** |
| MINIMAL + sev≥2 | 6.5% | +0.0085 | +0.038 | +0.015 | −0.004 | −0.022 | 0 fires |
| full-gauntlet-ish (+overext_m3 +room1.2) | **0.3%** | +0.069 | −0.250 | +0.166 | 0.000 | −0.130 | 0 fires |

**JUDGMENT.**
- **MINIMAL set** = the four robust gates only. E[R] +0.0077 (overall SE ≈ 0.0057, **t ≈ 1.4 — indistinguishable from breakeven**, be honest). Its value is *robustness*: non-negative in 4/5 eras and, critically, it **fired 0 trades in the 2023-2025 record bull** (D1 never death-crossed) — it *auto-benched itself* through the −0.071 bloodbath. It fires **8.5%** of bars — ~40× the full gauntlet.
- **full-gauntlet-ish** collapses to 0.3% (434 bars / 22 yrs ≈ 20/yr). Its +0.069 is **noise-dominated and fails in 2 of 4 populated eras** (−0.25 in 2004-2010, −0.13 in 2019-2022). No statistical claim possible. This is the current starvation, and it is curve-fit to the 2011-2015 bear.

---

## 8. Ranked verdict — which gates earn their place

Ranked by (lift × cross-era robustness). **KEEP / DROP / INVERT / RE-THRESHOLD.**

| Rank | Gate | Action | Rationale (FACT → JUDGMENT) |
|---|---|---|---|
| 1 | **dow_not_friday** | **KEEP** | +0.0435, t=8.9, positive all 5 eras. Highest-value, near-free (Friday shorts E[R] −0.071). |
| 2 | **loc_close<EMA200** | **KEEP** | +0.0212, t=5.6, positive 4/5. Long-trend location. |
| 3 | **loc_close<EMA50** | **KEEP** | +0.0203, t=5.3, positive 4/5. Complementary; marg +0.0155 in stack. |
| 4 | **align_D1_deathcross** | **KEEP as regime sit-out** | +0.0182; +0.033 in the big bear; **0 fires in the record bull** = its real value. |
| 5 | dow_mon_tue | KEEP (optional) | +0.0319, positive all 5; front-loads the week. |
| 6 | state_sev2 / sev≥2 | KEEP LIGHT | sev2 +0.0158 (t=2.9); sev≥2 only +0.007. Use as context, don't over-weight. |
| 7 | trig_ema21_reject | KEEP as TIMING | +0.0087; defines entry moment, not edge. Neutral-to-mild. |
| — | align_H4_ema21<50 | NEUTRAL | +0.0067, weak, marg −0.010. Optional. |
| — | **loc_lower_high** | **DROP** | −0.003, ≈0 all eras, marg −0.007. Pure participation tax. |
| — | **state_sev4 (BEAR_TREND)** | **DO NOT up-weight** | −0.0082: deepest-bear shorts do *worse* (exhaustion/rallies). |
| — | **sess_London_NY** | **DROP (consider invert)** | −0.0165, neg all 5. Off-hours shorts better (TZ-caveated). |
| — | **room_k1.2 / rr≥1.3** | **RE-THRESHOLD → 0.5, or DROP** | −0.0189 (t=−2.9); best band is room[0.5,1.0); ≥1.2 is the worst zone. Starvation culprit #1. |
| — | **over-extension veto** | **DROP (or INVERT)** | −0.0303 (t=−4.6), neg all 5; vetoes the +0.092R winners. Starvation culprit #2. |
| — | **vol_above_avg** | **DROP (consider invert)** | −0.0284 (t=−7.3), neg all 5. High-vol = capitulation/squeeze. |

### The starvation culprits (high filter · low-or-negative lift), in order
1. **Over-extension veto** — culls to ~2-4% marginal, throws away the winners (marg −0.13).
2. **Room ≥ 1.2R** — culls to 17%, negative lift, mis-thresholded (best is 0.5).
3. **Volume-confirm** — 41% cull, significantly harmful every era.
4. **Session (London/NY)** — negative every era.
5. **Lower-high** — 51% cull for exactly zero edge.

### Best swept parameters (FACT)
- **Room-k: 0.5** (require a *little* room to skip the sub-0.5R clip-zone; NOT 1.0/1.2/1.5).
- **Over-ext-m: OFF** (any finite m has negative lift; the vetoed cohort is the profitable one).

### Recommended minimal high-value gate set (JUDGMENT)
`close<EMA50 AND close<EMA200 AND D1-EMA50<EMA200 (death-cross regime) AND day≠Friday`, optionally `+ severity≥2` and the EMA21-reject **as the entry trigger**. Drop room≥1.2, over-extension, volume, session, lower-high. This fires **8.5% of bars (~40× the current gauntlet)** and is non-negative in 4/5 eras while **auto-benching in bull markets**. **Then fix the exit** (§6): stop clipping winners at the first swing low — that lever (worth +0.016R and a bear-era sign flip) dwarfs any single gate.

---

## 9. Direct answers to the owner's questions

- **Do the gates remove bad trades or good ones?** *Split.* The cheap gates (EMA50/200, D1 death-cross, not-Friday) remove **bad** shorts. The expensive gates doing the ~95% starving (room≥1.2, over-extension, volume, session, lower-high) remove **good/neutral** shorts — **the starvation buys no edge and, for over-extension, destroys it.**
- **Best room-k?** **≈0.5.** 1.2 is empirically the worst region *and* the biggest starver.
- **Do shorts have edge in the 2011-2015 bear?** Under the metric of record (adverse-first + swing-clip), **marginally NO** (−0.0108, t=−2.8). Remove the swing-clip and **YES** (+0.0496); apply the MINIMAL gate set and **YES, suggestively** (+0.0125, t=1.8). **The bear is where shorts work — but the current exit/gates strip the edge even there.**
- **Recommended minimal set?** §8 above.

### Risk / curve-fit honesty
- The MINIMAL set's overall +0.0077 is **not statistically distinguishable from zero** (t≈1.4). Its case is robustness + bull-market self-benching, not a big point estimate.
- Every conclusion here is measured on **one instrument, one exit family, overlapping bars, adverse-first pessimism.** These are *relative gate rankings*, not a promise of live P&L. Re-validate any adopted change in the tester before it becomes binding.
- The single highest-confidence, lowest-curve-fit change is **not a gate at all — it is removing the winner-clipping from the TMF exit** (§6).
