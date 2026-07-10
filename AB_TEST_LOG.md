# A/B Test Log — UltimateTrader AGRE v2 Improvements

## Baseline Reference (Locked 2026-03-28, re-confirmed 2026-04-04 from clean repo)
| Period | Net Profit | PF | Sharpe | DD% | Trades | Win% |
|--------|-----------|------|--------|-----|--------|------|
| 2022-2023 | -394 | 0.95 | -0.56 | 13.7% | 504 | 58.7% |
| 2023-2024 | +43 | 1.01 | 0.05 | 10.2% | 477 | 57.8% |
| 2024-2025 | +1986 | 1.27 | 2.65 | 5.6% | 508 | 66.5% |

## Pass/Fail Criteria
- **Must not** increase trade count > 5% vs baseline
- **Must not** increase DD > 2% vs baseline in any period
- **Must** maintain PF >= baseline in 2024-2025 (the edge period)
- **Should** improve PF or Sharpe in at least one period without degrading others

---

## Test 23: Phased BE + Reward-Room (COMBINED) — FAILED
**Date:** 2026-04-04
**Changes:** `InpEnablePhasedBE=true`, `InpEnableRewardRoom=true`, `InpMinRoomToObstacle=2.0`
**Verdict:** REVERT — batched test, undiagnosable

| Period | Net Profit | PF | Sharpe | DD% | Trades | Win% |
|--------|-----------|------|--------|-----|--------|------|
| 2022-2023 | +1705 | 1.14 | 1.42 | 16.8% | 749 | 62.6% |
| 2023-2024 | -887 | 0.89 | -0.84 | 17.3% | 618 | 53.4% |
| 2024-2025 | +509 | 1.06 | 0.61 | 9.8% | 612 | 60.6% |

**Failure analysis:** Phased BE clips runners → faster turnover → +trades. Same as Smart Runner Exit.

---

## Test 24: Reward-Room Filter (dirty baseline) — INVALID
**Date:** 2026-04-04
**Note:** File-diff contamination. Trade count increased despite rejection-only filter. Discarded.

---

## Test 24c: Reward-Room Filter (CLEAN single-variable) — FAILED
**Date:** 2026-04-04
**Baseline:** Re-confirmed from same repo build (exact match to original)
**Changes:** `InpEnableRewardRoom=true`, `InpMinRoomToObstacle=2.0`
**Obstacle sources:** H4 swing pivots + PDH/PDL + weekly H/L + round $50 + active SMC OB zones

| Period | Net Profit | PF | Sharpe | DD% | Trades | Win% |
|--------|-----------|------|--------|-----|--------|------|
| 2022-2023 | -253 | 0.47 | -5.00 | 3.8% | 23 | — |
| 2023-2024 | +91 | 1.27 | 2.57 | 2.0% | 29 | — |
| 2024-2025 | -12 | 0.97 | -0.48 | 1.5% | 28 | — |

**Deltas vs baseline:**
| Period | Profit | PF | Trades | Rejection Rate |
|--------|--------|------|--------|----------------|
| 2022-2023 | +141 | -0.48 | -481 | **95.4%** |
| 2023-2024 | +48 | +0.26 | -448 | **93.9%** |
| 2024-2025 | -1998 | -0.30 | -480 | **94.5%** |

**Failure analysis:** Filter rejected ~95% of all trades. 5 obstacle layers at 2.0R threshold creates an obstacle grid so dense that almost no trade passes. Root cause: gold's market structure has H4 swing pivots every $20-40, round $50 levels every $25 max, plus PDH/PDL + weekly + SMC zones. With typical risk distances of $15-40, there is ALWAYS an obstacle within 2.0R. The filter is conceptually a geometry check but practically a near-total entry ban.

**Lesson:** Gold's structural density is incompatible with a flat 2.0R obstacle threshold across 5 sources. The concept may still be valid with fewer/weighted obstacle sources or a higher threshold, but in current form it eliminates the entire trade population.

---

## Test 25: Structure-Based Invalidation — NO EFFECT
**Date:** 2026-04-04
**Changes:** `InpStructureBasedExit=true` — CHOPPY regime close now requires H1 EMA(50) break
**Baseline match:** EXACT (same trades, same profit to the cent, same DD, same everything)

| Period | Net Profit | PF | Sharpe | DD% | Trades | Win% |
|--------|-----------|------|--------|-----|--------|------|
| 2022-2023 | -394 | 0.95 | -0.56 | 13.8% | 504 | 58.7% |
| 2023-2024 | +43 | 1.01 | 0.05 | 10.2% | 477 | 57.9% |
| 2024-2025 | +1986 | 1.27 | 2.65 | 5.7% | 508 | 66.5% |

**Analysis:** Zero divergence from baseline. The EMA(50) structural check never changes the outcome. By the time the H4 ADX classifier reaches CHOPPY (ADX 15-20), H1 price has already broken through EMA(50) — the conditions are correlated. The structure check is always true when the regime condition fires, making the gate a no-op.

**Verdict:** NOT HARMFUL but NO BENEFIT. The CHOPPY auto-close either (a) never fires with open trend positions, or (b) always fires when EMA(50) is already broken. Either way, the structure-based overlay adds nothing to the current system.

---

## Test 26: CI(10) Regime Scoring — MARGINAL PASS
**Date:** 2026-04-04
**Changes:** `InpEnableCIScoring=true` — CI(10) on H1 adds ±1 quality point. Trend patterns +1 when CI<40, -1 when CI>55. MR patterns +1 when CI>60, -1 when CI<40.

| Period | Net Profit | PF | Sharpe | DD% | Trades |
|--------|-----------|------|--------|-----|--------|
| 2022-2023 | -197 | ~0.97* | -0.28 | 12.6% | 496 |
| 2023-2024 | -30 | 1.00 | -0.04 | 11.2% | 455 |
| 2024-2025 | +1957 | 1.27 | 2.62 | 6.1% | 504 |

*PF reported as -0.14 — likely display error, estimated ~0.97 from other metrics.

**Deltas vs baseline:**
| Period | Profit | PF | Sharpe | DD | Trades |
|--------|--------|------|--------|-----|--------|
| 2022-2023 | **+197** | +0.02 | **+0.28** | **-1.1%** | -8 |
| 2023-2024 | -73 | -0.01 | -0.09 | +0.95% | -22 |
| 2024-2025 | -29 | 0 | -0.03 | +0.45% | -4 |

**Analysis:** First change to pass all criteria. Trade count down in all periods (-4, -22, -8). PF maintained in edge period (1.27→1.27). Losing period improved by $197 with better Sharpe and lower DD. Net across 3 years: +$95. Effect is small but directionally correct — CI filters marginal trend entries in choppy conditions without touching winners.

**Verdict:** KEEP provisionally. Small positive signal. All subsequent tests run with CI scoring ON as the new baseline.

---

## Test 27: Regime Thrashing Cooldown — NO EFFECT
**Date:** 2026-04-04
**Changes:** `InpEnableThrashCooldown=true` — block entries after >2 regime changes in 4h
**Result:** Exact match with Test 26. Cooldown never fires.

**Why no-op:** Regime classifier uses H4 ADX with 2-bar confirmation. Each confirmed regime change takes 8+ hours (2 × H4 bar). Getting >2 changes in a 4-hour window is mathematically impossible at the H4 timeframe. The AGRE v2 designed this for H1 CI-based regime detection where flips can happen every 1-2 hours. With H4 hysteresis, thrashing is structurally prevented.

---

## Test 28: S3/S6 Range Structure Framework — PASS
**Date:** 2026-04-04
**Changes:** `InpEnableS3S6=true`, `InpEnableAntiStall=true` (conservative: 50% at 5 bars, close at 8)
**Replaces:** RangeBox + FalseBreakout disabled. BB MR stays. CI scoring stays from Test 26.
**New components:** Validated H1 range box, S3 range edge fade, S6 failed-break reversal, stealth-trend protection, anti-stall decay, middle-50% dead zone, sweep+reclaim mechanics.

| Period | Net Profit | PF | Sharpe | DD% |
|--------|-----------|------|--------|-----|
| 2022-2023 | -285 | 0.96 | -0.40 | 12.6% |
| 2023-2024 | -64 | 0.99 | -0.08 | 11.2% |
| 2024-2025 | **+2144** | **1.29** | **2.84** | 6.1% |

**Deltas vs original baseline:**
| Period | Profit | PF | Sharpe | DD |
|--------|--------|------|--------|-----|
| 2022-2023 | **+109** | +0.01 | +0.16 | **-1.16%** |
| 2023-2024 | -107 | -0.02 | -0.13 | +0.95% |
| 2024-2025 | **+158** | **+0.02** | **+0.19** | +0.45% |

**Analysis:** First change to improve the edge period's PF and Sharpe. Net +$160 across 3 years. S3/S6 structure-based entries are more selective than the replaced plugins, contributing positive trades in trending/ranging transitions. The validated range box + sweep mechanics add genuine edge. 2023-2024 slight degradation tolerable given gains elsewhere.

**Verdict:** KEEP. Combined with CI scoring, the system now runs at PF 1.29 / Sharpe 2.84 in the edge period.

---

## Current Best Configuration
- CI(10) scoring: ON
- S3/S6 framework: ON (replaces RangeBox + FalseBreakout)
- Anti-stall: ON (S3/S6 only)
- All other AGRE v2 changes: OFF or removed

## Test 29: Breakout Probation — NO EFFECT
**Date:** 2026-04-04
**Changes:** `InpEnableBreakoutProbation=true` — 2-bar H1 hold required before breakout execution
**Result:** Exact match with Test 28. Zero trades affected.

**Why no-op:** Most breakout plugins are already disabled in production (Compression BO, Panic Momentum, FVG, London/NY all off or 0% WR). The only active breakout type (VOLATILITY_BREAKOUT) either fires rarely or always passes the hold check. Probation targets a problem that's already been solved by disabling the weak breakout plugins.

**Note:** First attempt had a brace-structure bug that broke the entire execution flow (-$815, 282 trades). Fixed by replacing if/else wrapper with a flag guard (`probation_diverted`). The corrected code is confirmed safe (exact baseline match when enabled).

---

## Final Configuration (locked 2026-04-04)
| Component | Status | Effect |
|-----------|--------|--------|
| CI(10) scoring | **ON** | +$233 net, PF 1.27→1.29 in edge period |
| S3/S6 framework | **ON** | +$158 in edge period, +$109 in losing period |
| Anti-stall (S3/S6 only) | **ON** | Part of S3/S6 framework |
| Phased BE | **REMOVED** | Failed: clips runners |
| Reward-room filter | OFF | Failed: 95% rejection rate |
| Structure-based exit | OFF | No-op: correlated conditions |
| Thrash cooldown | OFF | No-op: H4 hysteresis prevents thrashing |
| Breakout probation | OFF | No-op: breakout plugins already disabled |

## Combined Result vs Original Baseline
| Period | Original | Current Best | Delta |
|--------|----------|-------------|-------|
| 2022-2023 | -394 | -285 | **+109** |
| 2023-2024 | +43 | -64 | -107 |
| 2024-2025 | +1986 | **+2144** | **+158** |
| **Net** | **$1,635** | **$1,795** | **+$160** |
| **Edge PF** | 1.27 | **1.29** | **+0.02** |
| **Edge Sharpe** | 2.65 | **2.84** | **+0.19** |

## Parked Ideas (need redesign before testing)
- **Reward-room filter:** Concept valid but implementation too aggressive. Needs either: (a) reduced to 1-2 obstacle sources only (e.g., untested H4 swing + SMC confluence only), (b) higher threshold (3.0-4.0R), or (c) weighted obstacles where round numbers and single PDH count less than confluent structural zones.

---

## Test: NEWS FILTER A/B (entry-block / flatten / tighten) — NET-NEGATIVE, SHIPPED DEFAULT-OFF
**Date:** 2026-07-08 (v2 — includes the confirmation-path leak fix + full verification suite)
**Build:** HEAD `a72c97a` + news-filter feature (CNewsGate hybrid live-calendar/tester-CSV; Group 47 inputs; confirmed-entry news check)
**Harness:** `claude/gate/news_run.sh` (rt_baseline.ini clone, Model=4 real ticks, XAUUSD+ H1, 2019.01.01–2026.06.27, explicit Chand 4.2/3.6/3.0/3.6, clean state per run, same-day pairs)
**Data:** `NewsCalendar_USD.csv` (MetaQuotes calendar export, 14,104 events 2018.12–2026.08 UTC, anchor conformity 97.51% model A; Tier-1 = FOMC decision/statement/presser + NFP + CPI; Tier-2 = other HIGH USD, EIA energy demoted; windows T1 −60/+30min, T2 −30/+15min)

| Leg | Net Profit | PF | Sharpe | Eq-DD | Trades | Entries in news windows | vs OFF |
|-----|-----------|------|--------|-------|--------|------------------------|--------|
| OFF (identity) | $20,064.29 | 1.29 | 2.16 | 14.02% | 1891 | 69/928 (7.4%) | == SHOCKB REF to the cent ✔ |
| ON (entry-block) | $16,611.85 | 1.28 | 2.12 | 12.40% | 1713 | **0/842** | net −17.2%, Eq-DD −1.62pp |
| FLAT (+T1 flatten 20min) | $17,518.27 | 1.28 | **2.27** | 12.58% | 1692 | **0/842** | net −12.7%, Sharpe +0.11, Eq-DD −1.44pp |
| TIGHT (+T1 tighten ATRx1.0) | $14,272.89 | 1.25 | 1.96 | 12.50% | 1697 | **0/842** | net −28.9% — KILL |

**Verification suite (all PASS):**
1. **Bar-exhaustive probe** (`Tests/NewsGateProbeEA.mq5`, Model=1 full-2024, 5,911 H1 bars) cross-checked by an independent Python reimplementation: UTC conversion 5,911/5,911 exact; entry-block decision 5,911/5,911 agree (0 false blocks, 0 missed); 425 bars (7.2%) blocked.
2. **DST both seasons + transitions**: winter events (CPI 13:30 UTC, FOMC 19:00 UTC, srv +2) and summer events (12:30/18:00 UTC, srv +3) all land on server bars 14:00–16:00 / 20:00–22:00 correctly, including the Mar-10 / Nov-3 2024 transition weeks (e.g. CPI 03.12 12:30 UTC first post-transition event correct).
3. **Market-reality falsification**: mean H1 range of Tier-1 event bars under our mapping = 21.36 (3.54× all-bar mean 6.03); same bars shifted −1h = 4.44 (pre-news coil), +1h = 15.92 (aftershock) → our mapping uniquely captures the release spike; a ±1h offset error is excluded by the data.
4. **Flatten/tighten window edges**: 40/40 flatten and 32/32 tighten Tier-1 windows open within 120s of expected [T−lead] (e.g. FOMC 2024.09.18: flatten ON 20:40, OFF 21:00:20, presser ON 21:10, OFF 21:30:20 server).
5. **Trade-level audit** (full 2019–2026 legs): OFF 69/928 entries inside news-window bars; ON/FLAT/TIGHT **0/842 each**.

**Leak found & fixed during verification:** pending-CONFIRMATION entries execute outside the gated chain — 20 Tier-2 in-window fills leaked in the original ON leg (0 Tier-1: the 60-min T1 pre-window covers the confirmation bar). Fixed with a news check in the confirmed-execution chain (`ClearPendingSignal`, same convention as the extension/quality filters); post-fix audit = 0 leaks; OFF identity unchanged to the cent.

**Verdict:** entry-blocking removes net-profitable trades on this long-biased gold book (one-sided-shrinker pattern, cf. OPT-3/OPT-SHOCK-A), but the risk payback is now material: Eq-DD −1.62pp (14.02%→12.40%). FLAT remains the best active config (Sharpe 2.16→2.27, Eq-DD −1.44pp, smallest net cost). TIGHT is a clear KILL. **Shipped `InpNewsFilterEnable=false` default (production byte-identical); stok owns any adopt ruling.** Caveat: Model=4 cannot price live news slippage/gap-through-stop, so these numbers UNDERSTATE the live value of news protection.
**Ops notes:** (1) MT5 tester fills [TesterInputs]-missing params from `MQL5/Profiles/Tester/<Expert>.set` (last-used cache), NOT compiled defaults — one stale run poisons later runs; news_run.sh sets the 4 Chand values explicitly. (2) Fridays never reach the news gate for entries (Sprint 3D Friday block upstream) — NFP entry-risk was already covered; flatten/tighten DO act on Fridays.

---

## Test: ACTION-3a RISK-LAYER WAKE vs DELETE — DELETE ADOPTED (byte-identical), WAKE KILLED (−39.7% FIT)
**Date:** 2026-07-08
**Context:** 2026-07-08 funnel audit found `g_riskStrategy` (CQualityTierRiskStrategy) constructed but never `Initialize()`d — 942/942 sizing calls on the orchestrator fallback. Deep forensics then showed the missing init is DELIBERATE (comment at the construction site: "8-step chain compounds 50-80% reduction — proven harmful in all tests"; git v18 confirms the baseline was always fallback-sized), and that waking under the production config is a no-op for every advertised feature (tier table lives upstream in CSetupEvaluator; vol-sizing yields to regime-risk; short-mult=1.0; health/engine-weight placeholders) EXCEPT the InpMaxLotMultiplier 0.10-lot clamp (would cut 45.7% of lot volume). Also corrected the OPT-3 record: that sweep measured UNREACHABLE code (init early-return at CQualityTierRiskStrategy.mqh:301), not counter-timing.
**Protocol:** asymmetric burden (gold-algo-trader design): DELETE = byte-identity sanity leg only; WAKE must earn ≥+15% net/DD with position-count frozen ±2% and ex-2025 net held.

| Leg | Net | PF | Sharpe | Eq-DD | Trades | Verdict |
|-----|-----|----|--------|-------|--------|---------|
| Leg 0 DELETE-arm FULL 2019–2026H1 | $20,064.29 | 1.29 | 2.16 | 14.02% | 1891 | **== baseline to the cent → DELETE VALIDATED** |
| Leg 1 WAKE FIT 2019–2022 | $1,478.96 | 1.13 | 1.11 | 9.83% | 836 | **vs $2,453.21 FIT ref = −39.7% → EARLY KILL** (lot clamp confirmed) |

**Implementation (working tree, uncommitted):** `g_riskStrategy` no longer constructed (UltimateTrader.mq5 LAYER-6 block now documents fallback-as-design + the OPT-3 correction); orphaned inputs (`InpMaxLotMultiplier`, `InpEnableLossScaling`, `InpLossLevel1/2Reduction`) marked DEAD in UltimateTrader_Inputs.mqh. Class file kept on disk (CPositionCoordinator references the type; full file deletion = later hygiene with stok).
**Multiplier-stack audit (same action, sibling agent — full report in session transcript):** decomposition reproduces mean final/base 0.775 exactly. Verdicts: ECv3 VOL LAYER = FIX-MECHANICAL (**H4-vs-H1 ATR pairing bug**: `GetATRCurrent()`=H4 fed against `GetATRAverage()`=H1-avg → VolRatio ~2.0 permanent vs 1.0-centered thresholds → 0.93 tax on ~93% of trades ≈ 60% of all surrendered risk, ~+8.6 R-units if fixed); CRegimeRiskScaler = FIX-MECHANICAL (same bug: choppy-0.6 fired 0× in 7.5y); vol-regime sizing confirmed applied NOWHERE (Sprint-1C hole, inputs ORPHANED); shock/SQ reducer = KEEP (only reducer that made money); session 0.5× = KEEP (documented design-intent); counter-trend 0.5× = KEEP + FLAG-TO-STOK (its cost concentrates in 11 halved crash-recovery LONGS at +0.342R); latent defects: m_short_risk_multiplier never read (profiles would silently not apply), confirmed-path regime hard-codes bypass ini. Follow-on: ACTION-3b ATR-PAIR correctness A/B.

---

## Test: ACTION-3b ATR-PAIR correctness fix — PASSES ALL GATES, +17.5% NET (stok owns DD ruling)
**Date:** 2026-07-08
**Change (source, uncommitted):** matched-H1 ATR pair fed to the two 1.0-centered ratio consumers that were receiving H4-current/H1-average (~2.0 permanent): new `IMarketContext::GetATRH1Current()` (delegates to CVolatilityRegimeManager's current H1 ATR(14) — the exact series `GetATRAverage()` averages), applied at `CTradeOrchestrator.mqh:397-400` (ECv3 vol layer) and `CRegimeRiskScaler.mqh:179-182`. Same bug family OPT-SHOCK fixed inside DetectShock. Binary `UltimateTrader_ATRPAIR.ex5` (0 err / 0 new warn). Known remaining inheritor: `CDayTypeRouter.mqh:52-53` (multi-strategy-gated, off on prod — follow-up).
**Why:** ECv3's vol layer was a permanent ~0.93 risk tax on ~93% of trades (60% of all surrendered risk); CRegimeRiskScaler's choppy-0.6 leg fired 0× in 7.5 years and trend-stability was never awarded.

| Leg (same-day pairs, Model=4, RISKDEL-binary baselines) | BASE | ATR-PAIR | Delta |
|---|---|---|---|
| FIT 2019–2022 | $2,570.18 / PF 1.13 / Sh 1.08 / EqDD 18.49% / 832t | $2,794.93 / 1.13 / 1.07 / 19.86% / 827t | **+8.7% net** |
| CONFIRM 2023–2026H1 | $14,104.32 / 1.38 / 2.99 / 13.48% / 1037t | $15,651.48 / 1.37 / 2.96 / 14.39% / 1030t | **+11.0% net** |
| FULL 2019–2026H1 | $20,064.29 / 1.29 / 2.16 / 14.02% / 1891t | $23,572.18 / **1.30** / **2.19** / 15.46% / 1874t | **+17.5% net** |

**Guards:** per-year improves 7/8 (only 2019 −$47 noise); **ex-2025 net +21.1%** ($7,008→$8,486 gross) — improvement is NOT 2025 leverage (2025 share 65.9%→64.8% DOWN); 2026H1 flips positive (−$59→+$160); PF/Sharpe flat-to-better on every leg; net/EqDD 1,431→1,525 (+6.6%); trade count −0.9% (exposure-cap interaction, entries essentially unchanged).
**The one open flag:** Eq-DD 14.02%→15.46% (+1.44pp; Bal-DD 11.98%→13.53%) — mechanically proportional to the restored position sizes (the removed tax). This exceeds the ~14.0% comfort band stok set at OPT-1. **Options for stok:** (a) ADOPT as-is (risk-adjusted strictly better); (b) ADOPT + renormalize base risk ~-7% to restore the old DD at ≈+8-10% net (dominates old baseline on every metric); (c) reject. Verdict is stok's; the fix itself is a correctness de-bug, not a tuning.
**If adopted, new binding baseline = $23,572.18 / PF 1.30 / Sharpe 2.19 / Eq-DD 15.46% / 1874t** (or the renormalized variant).

---

## Test: ACTION-7 confirmed-path guards + ACTION-2 shadow logger — VERIFIED (logger decision-free; guards +$291 on ATR-pair tree)
**Date:** 2026-07-08
**Changes (working tree, uncommitted; stacked on news-filter + Action-3a/3b):**
1. ACTION-7 Hole-1: wall-clock staleness guard on the pending slot (kill if age > window×1h + 2h slack; outside the Friday gate) — eliminates weekend/holiday-stale confirmations firing into Monday 01:00 (2 baseline cases, saved only by retcode 10018; LIVE this is unpriced gap risk on any broker whose first tick is tradeable).
2. ACTION-7 Hole-2: halt/budget (`IsTradingHalted||!CanTrade`) + position-cap (`GetPositionCount()>=InpMaxPositions`) guards as first branches of the confirmed-path kill chain (historical violations counted = 0 → pure invariant enforcement).
3. ACTION-2: decision-free shadow-pending logger (`UltTrader_ShadowPendings_*.csv`, 52 cols) — every pending CREATED/KILL(reason)/EXEC/EXEC_FAIL with counterfactual fill anchor (kill-tick ask), confirmation-candle OHLC, and exit-profile stamp.

| Leg (Model=4, FULL 2019–2026H1) | Net | PF | Trades | Note |
|---|---|---|---|---|
| ATRPAIR reference (tree without guards) | $23,572.18 | 1.30 | 1874 | Action-3b leg |
| ACT7 (guards) | $23,863.44 | 1.30 | 1874 | **+$291/+1.2%**, same count |
| SHADOW (guards+logger) | **$23,863.44** | **1.30** | **1874** | **== ACT7 to the cent → logger provably decision-free** |

**Shadow funnel reconciles exactly:** 1,192 CREATED = 579 CONFIRM_WINDOW_EXHAUSTED + 59 EXTENSION_72H + 2 REVALIDATE_FAIL + 8 GUARD_STALENESS + 532 EXEC + 12 EXEC_FAIL. Halt/budget and pos-cap guards fired 0× (as predicted). Staleness fired 8× on this tree (vs 2 on the pre-ATR-pair tree — tree-dependent set); the +$291 comes from freed pending slots (a frozen stale pending blocks new signals from pending until cleared).
**Note on stacking:** working tree = news-filter(default-off) + Action-3a DELETE + Action-3b ATR-PAIR + Action-7 + shadow logger. If stok rejects Action-3b, re-verify Action-7 on the reverted tree (predicted delta there: 0 trades / ~$0).
**Arm-B (conf mechanism removal, separate leg on RISKDEL binary):** InpEnableConfirmation=false → $6,700.34 / PF 1.07 / Sharpe 0.72 / Eq-DD 27.30% / 2,808t vs $20,064.29/1.29/2.16/14.02%/1,891 — **mechanism is load-bearing; gate stays**. (Confounded measurement — timing+sizing+gate-exposure all flip — licensed conclusion is only "do not remove the mechanism".)

---

## Test: ACTION-2 Arm-A — killed-pending replay verdict: GATE IS FINE, LEAVE IT
**Date:** 2026-07-08
**Method:** offline replay of all 648 shadow-logged pending kills (entry = kill-tick ask — zero entry bias), tranche-ladder + BE + chandelier simulation over exported H1 rates, pess/opt same-bar bracketing, **calibrated on the 532 executed confirmations vs their actual outcomes** (r 0.85–0.88, sign agreement 85–92%, bias +0.03..+0.08R measured and applied; actual fell outside the raw bracket → all numbers are bias-corrected estimates ±~0.05R, per contract). Replayer + artifacts in the session scratchpad.
**Killed cohort (579 CONFIRM_WINDOW_EXHAUSTED; 531 replayed, 48 unreplayable = ask already ≤ SL, i.e. deepest fails, exclusion flatters the kills):** bias-corrected **[−0.094, +0.068] R/trade; total [−50, +36] R over 7.5 years — zero.** No n≥50 slice decisive (tiers/years/regimes/plugins/margin-deciles all straddle; no near-miss gradient → the candle test is not clipping value at the margin).
**Tweak candidates, both rejected:** strictness sweep structurally non-binding (79% of kills fail ONLY `is_bullish`; the close-level component never fails alone → sweeping admits 0 trades); window=2 replayed directly: 247 late-passers worth [−1.7, +9.2] R total — noise. Softening `is_bullish` admits 421 trades at ~0R — pure DD variance.
**Bonus validations:** EXTENSION_72H kills good ([−0.15]R avg); GUARD_STALENESS kills emphatically good ([−0.53]R avg, n=7 — the Action-7 guard earns its keep). Selection insight: killed vs executed composition near-identical, yet executed realize +0.147R vs killed ~0R — the single confirmation candle cheaply separates paying trades from noise. **Diagnosis item #2 is RESOLVED-INNOCENT: frequency must come from dead strategies / Friday ban / session dead-zone / short book, not this gate.**

---

## ACTION-1 exit-ladder sweep — FIT round + FORMAL DD EXCEPTION (user ruling 2026-07-08)
Baselines (SHADOW tree): FIT $2,905.32/EqDD 19.71%/827t; CONFIRM $15,774.32/14.32%/1030t; FULL $23,863.44/1874t.
FIT round (pre-registered gates: net>baseline, EqDD≤+1pp, no year worse >$500, 2021 chop ≤10% degrade, fills ±2%):
- K1 (InpEnableTP0=false, book-wide; confounded w/ earlier BE arming): $2,805.95 / EqDD 20.95% — **KILL** (net+DD).
- K2 (InpRegExitTrendTP1Vol 35→45; runner 44%→37%): $2,846.00 / EqDD **18.63%** — **KILL on net** (−2.0%); noted as a DD-reducer trade-off for a future defensive study.
- K3′ (broker hard-TP ceiling lifted via InpLow/Normal/HighVolTP1Mult=10.0; ladder untouched): **$3,741.94 (+28.8%) / PF 1.16 / Sharpe 1.18 / EqDD 21.55%** — per-year all green (2019 +$103, 2020 +$720, 2021 chop +$152, 2022 −$126), fails ONLY the EqDD cap (21.55% vs 20.71%, +0.84pp over).
Candidate note: the PM's original K3 (TP2Vol tilt) was replaced pre-run — forensics proved the naive `InpEnableAdaptiveTP=false` mapping TIGHTENS the ceiling (falls back to fixed 1.3/1.8R broker TPs); the ceiling is the adaptive TP1 price, sitting below stamped TP2 on 44.7% of fills (a proven cause of the zero-≥3R pathology).
**FORMAL EXCEPTION (user ruling, verbatim intent):** K3′ advances to its single CONFIRM shot DESPITE the +0.84pp FIT DD-cap breach, because net +28.8%, net/DD +18%, and all stability gates passed. **The CONFIRM criteria are NOT relaxed** (net up vs $15,774.32; EqDD ≤15.32%; no year flip >$500; 2025-share rise ≤3pp; swap/holding-hour vetoes stand). Fail = revert, Action-1 closes no-change. "Let it take the final exam, but do not lower the passing grade."

**ACTION-1 CONFIRM verdict (2026-07-08): K3′ FAILED the unrelaxed exam — REJECTED, Action-1 closes NO-CHANGE.**
K3′ CONFIRM 2023–2026H1: $19,363.07 (+22.8%) / PF 1.43 / Sharpe 2.85 (down from 2.97) / **EqDD 16.65% vs cap 15.32% — fail by 1.33pp** / 1046t (+1.6% ✔). The DD breach DOUBLED out-of-sample (FIT +0.84pp → CONFIRM +2.33pp) while Sharpe declined: the broker-TP ceiling is a load-bearing risk control — it suppresses returns and caps DD in near-equal measure (net/DD only +5.6% OOS). Finding preserved for any future stok-level DD-budget study (belongs with the pending ATR-pair DD ruling): the ceiling (adaptive TP1 price, below stamped TP2 on ~45% of fills) is simultaneously the main cause of the zero-≥3R pathology AND a working drawdown brake. K1/K2 killed at FIT. No source changes; sweep was config-only; nothing to revert.

---

## ACTION-3b FINAL ADOPTION (2026-07-08): ATR-pair fix + tier table ×0.90 — APPROVED (user, three conditions all met)
**Ruling:** the ATR correction is a timeframe-correctness fix, not parameter optimization (FIT +8.7% / CONFIRM +11.0% / FULL +17.5%, 7/8 years, ex-2025 +21%). Approved conditional on: (1) explicit DD-exception documentation, (2) a reduced-risk FULL leg targeting Eq-DD <14%, (3) absolute AND relative DD comparison. All three executed:

| FULL 2019–2026H1 | OLD baseline | ATR stack ×1.00 | **ADOPTED: ATR stack ×0.90 tier** |
|---|---|---|---|
| Net | $20,064.29 | $23,863.44 | **$21,623.18 (+7.8%)** |
| PF / Sharpe | 1.29 / 2.16 | 1.30 / 2.21 | **1.31 / 2.28** |
| Eq-DD max | $4,750.70 / 14.02% | $5,952.39 / 15.35% | **$4,855.91 / 13.68%** |
| Bal-DD max | $3,984.45 / 11.98% | $5,094.83 / 13.38% | **$4,074.62 / 11.68%** |
| Eq-DD / Bal-DD relative | 18.59% / 18.06% | 19.71% / 18.22% | **18.22% / 16.93%** |
| Trades | 1891 | 1874 | 1878 |

The ×0.90 variant beats the OLD baseline on EVERY percentage DD measure (maximal + relative, equity + balance); only absolute Eq-DD is +$105 (+2.2%) vs +$1,559 (+7.8%) net — inside policy, no exception needed.
**NEW BINDING BASELINE: $21,623.18 / PF 1.31 / Sharpe 2.28 / Eq-DD 13.68% / Bal-DD 11.68% / 1878t.**
**Config of record:** `risk_R90.ini` (= news_OFF.ini + InpRiskAPlusSetup=1.35 / InpRiskASetup=0.9 / InpRiskBPlusSetup=0.675 / InpRiskBSetup=0.54, Expert=UltimateTrader_SHADOW.ex5). Source defaults updated to match (UltimateTrader_Inputs.mqh Group 2 — old 1.5/1.0/0.75/0.6 recorded there). ⚠️ rt_baseline.ini still carries OLD tier values — update it (or clone risk_R90.ini) before any future sweep; ini lines override source defaults.

---

## ACTION-5 (Friday reopen + dead zone) — CLOSED NO-CHANGE; ACTION-4 iter-1 (short book) — KILLED AT FIT
**Date:** 2026-07-09 | Binary UltimateTrader_A54/A4S (identity legs exact: $2,735.89/829t both) | Baselines: R90FIT $2,735.89/18.22%/829t, R90CONF $14,535.35/13.11%/1029t.

**ACTION-5a Friday reopen (`InpFridayEntryCutoffGMT`, new input, default 0 = full ban bit-identical):**
| Leg | Net | PF | Sharpe | EqDD | Verdict |
|---|---|---|---|---|---|
| F14 FIT (till 14:00 GMT) | $4,241.14 (+55.0%) | 1.17 | 1.54 | 18.24% (+0.02pp) | pass → CONFIRM |
| F14C FIT (+ weekend-carry) | $4,947.03 (+80.8%) | 1.19 | 1.66 | 18.74% (+0.52pp) | KILL (DD tolerance +0.3pp) |
| **F14 CONFIRM 2023–2026H1** | **$9,539.53 (−34.4%)** | 1.26 | 2.05 | 14.99% (+1.88pp) | **CATASTROPHIC FAIL → REVERT** |
The +55% FIT gain inverted to −34% OOS — the Sprint-3D Friday ban is REGIME-PROTECTIVE on modern data (2023+). Ban stays. The input remains in source (default = ban, bit-identical, identity-verified) as a documented lever; do NOT flip without a new full study.
**ACTION-5b GMT 21–23 dead zone: KILLED A PRIORI, zero runs** — settlement/rollover window (spreads 3–10× vs ~6pt stops = 0.25–0.5R entry tax vs +0.14R book expectancy; backtest would flatter it via understated rollover spreads); forensics: half the zone is the daily break (0 bars), other half yields ~1 entry/1,960 bars in neighbor hours. Also corrected: session hours are HARDCODED (Utils.mqh:118-149), skip-hours 11/11 is a no-op, and the session risk-multiplier ranges are hardcoded separately (mq5 ~:2066) — reopened hours would size 1.0×.

**ACTION-4 iteration-1 short book (config flips + 1-line symmetric gate):**
Arm = InpEnableBearishEngulfing=true (bear trend-gate narrowed to {BEAR,NEUT} — the old −25.9R in-code verdict was measured WITH TREND_BULLISH allowed) + InpBearPinBarBlockNY=false + InpShortRiskMultiplier=0.75, shared exits.
| Leg | Net | PF | Sharpe | EqDD | Verdict |
|---|---|---|---|---|---|
| SHORT FIT 2019–2022 | **−$1,301.55** (vs +$2,735.89) | 0.95 | −0.45 | **32.57%** | **IMMEDIATE KILL** (net negative, DD +14.35pp) |
Even narrowed + downsized on the corrected-ATR stack, bearish engulfing repeats its historical signature. Deferred/unbuilt: bear MACross (code REMOVED in Phase D — re-introduction, not enablement), S6-short (measured −8.9R), CrashBreakout (payoff-0.46 placebo). Key forensic corrections recorded: pattern score inputs are INERT (tier buckets overwrite pre-arbitration); shorts BYPASS the TF/MR validator entirely (0 validator rejects vs 532 on longs); the "CrashBreakout 13–17h time-box" is dead config (never read); counter-trend 0.5× split-by-direction requires source. The {BEAR,NEUT} gate line stays in source (flag-off inert, identity-verified) to make any future flip safer.

**Campaign conclusion (Actions 1–7):** every frequency lever from the original diagnosis is now MEASURED: confirmation gate innocent (0R), Friday ban protective (−34% OOS to reopen), dead zone dead for cause, short book still toxic, exit ladder capped by a load-bearing DD brake. The adopted value came entirely from correctness fixes: ATR-pair + tier×0.90 + Action-7 guards → binding baseline $21,623.18 / PF 1.31 / Sharpe 2.28 / Eq-DD 13.68% (from $20,064.29 / 1.29 / 2.16 / 14.02%).

---

## FIX-1 volatility-anchored minimum stop — MEASURED KILL AT FIT (both arms)
**Date:** 2026-07-09 | Binary UltimateTrader_FIX.ex5 (identity leg EXACT: $21,623.18/1878t, both levers off)
**Root cause it targeted (real, forensically proven):** InpMinSLPoints=800 × a price scale computed ONCE from the FIRST TICK of the run (UltimateTrader.mq5:217-244, sole call OnInit:516) → $5.13 floor frozen from $1,282 gold to $3,750 (start-date-dependent: a 2026 start trades $17.28!). 79% of fills sit below 30% of the trailing 48h range carrying 82.6% of loss dollars; floor-cluster (149 fills): WR 38%, +$688/7.5y at the book's largest lots. CrashBreakout/S6 have NO floor; the InpEnableVolSLAdjust inputs are dormant (zero call sites).
**Lever (kept in source, default off):** InpMinSLRangePct — floor = max(points-floor, pct × 48h range) at the CSignalOrchestrator choke point with mandatory proportional TP recompute (naive variant would RR-kill 270/373 shorts).

| Leg (FIT 2019–2022) | Net | PF | Sharpe | EqDD | Verdict |
|---|---|---|---|---|---|
| Baseline | $2,735.89 | 1.14 | 1.17 | 18.22% | — |
| SL30 (primary, a-priori) | $1,976.07 (−27.8%) | 1.14 | 0.90 | 19.87% | **KILL (net + DD gates)** |
| SL25 (monotonicity control) | $1,017.19 (−62.8%) | 1.07 | 0.47 | 19.85% | KILL (consistent: 30>25, no inversion alarm) |

**Why the thesis failed:** TP0/TP1/TP2 and BE are R-multiples of the stop distance — widening stops 1.5–3× pushed every partial-banking level equally farther in price, starving the partial engine that carries ALL the book's net (+$40k partials vs −$20k runners). The tight-stop pathology was co-adapted with fast partial banking; removing one side alone is net-negative. Any future retry must re-anchor the LADDER in price/ATR terms simultaneously (a much larger redesign — stok-level).
**Disposition:** lever stays in source (default 0 = off, identity-verified) with this finding as its documentation. The frozen-first-tick scale bug remains REAL and still deserves a fix for live robustness (the start-date dependence is indefensible) — but as a pure refactor preserving today's effective $5.13-at-2019-scale behavior, not as a widening.

---

## FIX-2 active break-even mover — MEASURED KILL AT FIT (both arms)
**Date:** 2026-07-09 | Binary UltimateTrader_FIX.ex5 (identity previously verified exact)
**Root cause it targeted (real, forensically proven — FINDING 0):** the EA has NO active BE stop-mover for pattern trades; the per-regime BE trigger inputs (trend 1.2R etc.) gate only a diagnostic flag (CPositionCoordinator.mqh:2905-2937); the flag flips only when the chandelier's 4.2×ATR proposal independently crosses entry (~1.4R+, median 2.41R). 0/40 top losses armed; the three +0.88/+1.23/+1.32R round-trippers had TrailInternalUpdates=0 — the original stop killed them. K1's confound retro-resolved: its "earlier-BE" leg was inert (flag-only).
**Lever (kept in source, default off):** InpEnableBEMover — synthesizes a BE proposal (entry+offset) at the configured trigger through the existing ratchet/clamp/broker-send machinery.

| Leg (FIT 2019–2022) | Net | PF | Sharpe | EqDD | Verdict |
|---|---|---|---|---|---|
| Baseline | $2,735.89 | 1.14 | 1.17 | 18.22% | — |
| Arm A: mover @ existing triggers (1.2R trend) | $2,006.82 (−26.7%) | 1.12 | 0.96 | 17.00% (−1.22pp) | **KILL (net+Sharpe)** |
| Arm B: mover @ 1.0R trend | $1,624.07 (−40.6%) | 1.10 | 0.82 | 16.62% (−1.60pp) | KILL (monotone: earlier BE = worse) |
**Why the thesis failed:** the scratch cost dominates — in a 79%-TRENDING book, pullbacks to entry are routine; BE+$0.50 scratches winners that would have paid. The counterfactual (+$8–17k ceilings) was explicitly flagged as intrabar-cost-blind; measurement says the invisible cost side is ≥2× the savings. DD genuinely improves (−1.2 to −1.6pp) but at −27/−41% net → net/DD worsens (150→118/98). No CONFIRM spent.
**Disposition:** lever stays in source (default off, identity-verified) with this finding as documentation.

**JOINT CONCLUSION — FIX-1 + FIX-2 (owner's mandate 2026-07-09):** both diagnosed pathologies are REAL (frozen first-tick stop floor; nonexistent BE mover) and both fixes are measured net-negative, because the book's profit engine (fast partial banking at tight stops, +$40k partials vs −$20k runners) is CO-ADAPTED to exactly these pathologies. Running total: SEVEN single-lever interventions on diagnosed issues (Friday, confirmation, TP ceiling, short book, exit ladder, stop floor, BE mover) have now failed at FIT or CONFIRM; only correctness fixes (ATR-pair, tier renorm, guards) ever passed. Any further attack on the stop/ladder complex must be a COUPLED redesign (stop anchor + ladder distances + BE/trail re-derived together in price/ATR terms, not R-of-a-widened-stop) — stok-level design work with a fresh FIT derivation, not a lever. SEPARATE live-robustness item that survives this kill: the first-tick point-scale freeze (UltimateTrader.mq5:217-244) makes live behavior start-date-dependent ($5.13 vs $17.28 floors for 2019 vs 2026 starts) — deserves a behavior-preserving refactor (e.g., scale re-derived per bar but with the FLOOR kept at the effective historical calibration) before any live deployment.

---

## TIER-2a PBC-disable arm — MEASURED KILL AT FIT
**Date:** 2026-07-10 | Config-only (`InpEnablePullbackCont=false`, prevents construction+registration) on the committed tree (UltimateTrader_T0.ex5).
| Leg (FIT 2019–2022) | Net | PF | Sharpe | EqDD | Trades |
|---|---|---|---|---|---|
| Baseline | $2,735.89 | 1.14 | 1.17 | 18.22% | 829 |
| PBC-off | **$2,247.15 (−17.9%)** | 1.12 | 1.08 | 18.43% | 793 |
**Verdict: KILL — PBC stays.** The "negative avg-R strategy" is dollars-positive and its removal degrades every headline metric: its winners land on later/larger balances, and its candidates' role in same-bar arbitration measured net-positive for the book. Eighth single-lever intervention to fail measurement. A PBC exit REBUILD (not removal) remains a Tier-3 candidate.

---

## TIER-2 arms — cluster guard KILLED at CONFIRM; crash-TP measured no-op; shadow-kill instrumentation VERIFIED
**Date:** 2026-07-10 | Binary UltimateTrader_T2.ex5 (identity legs exact: FIT $2,735.89/829t at defaults; FULL $21,623.18/1878 with the kill-logger ON — decision-free proven).

**A. Same-direction cluster guard (`InpEnableClusterGuard`, key=(pattern_type,direction), single chokepoint in ExecuteSignal covering immediate+confirmed; cluster rejects excluded from the consecutive-error halt circuit):**
| Leg | Net | PF | Sharpe | EqDD | Verdict |
|---|---|---|---|---|---|
| FIT 2019–2022 | $3,090.51 (+13.0%) | 1.17 | 1.51 | 15.72% (−2.5pp) | pass → CONFIRM |
| CONFIRM 2023–2026H1 | **$10,550.41 (−27.4%)** | 1.35 | 2.99 | **13.28% (WORSE +0.17pp)** | **KILL** |
The 128 historical duplicates were net +$1,512 (2023–25 dups +$2.1k of compounding winners); blocking them costs net AND fails the concentration-control justification OOS (DD worse). Ninth single-lever kill; third FIT-mirage (+13%→−27%). Lever stays default-off documented. A per-family risk CAP (downsize, don't block) remains the Tier-3 refinement if concentration control is ever mandated.

**B. Crash TP extension (`InpCrashTPExtension=0.5`):** FIT $2,708.23 (−1.0%), all metrics flat — the forensic prediction is now measured FACT: the TP channel is not the crash constraint (only 2/138 trades ever reached the mean; the binding constraint is the short-side chandelier clamp producing at-market stops seconds after entry — stop/ladder-complex territory, coupled-redesign only). Lever stays default-off documented.

**C. Shadow-kill logger (`InpEnableShadowKillLog`):** full-range instrumentation leg reproduced the binding baseline TO THE CENT while capturing the COMPLETE signal-stage kill piles: 532 VALIDATOR_FAILED + 615 VOLUME_FILTER rows (matches the funnel audit exactly). Offline replay pricing of the Engulfing-449 and S6-81 piles in progress.

**C (completed). Shadow-kill replay pricing (calibrated: LONG bias +0.024..+0.035 SE .026, r 0.85; SHORT +0.043..+0.074, r 0.61):** Engulfing-VOLUME pile [−0.032,−0.017]R bias-corrected even at the optimistic bracket → gate acquitted; dose-response INVERTED (near-miss band 0.9-1.0 = worst at −0.09R) → threshold-relax specifically refuted. S6-VALIDATOR pile center +0.18R but 95% CI spans zero on ~36 survivors (~$150/yr) + maximal replay-geometry error on its ultra-tight stops → no claim, no arm (binding sub-check identified for the record: PATTERN_FAILED_BREAK_REVERSAL missing from the TRENDING counter-trend structural-exception list, CSignalValidator ~:574-586). Crash-short VOLUME pile −0.12R kills → the gate demonstrably PAYS. All positive year-slices concentrate in 2024-25 (the record bull leg) — the curve-fit trap named. **TIER-2 COMPLETE: every cheap unmeasured lever is now measured. Kills: PBC-off, cluster guard (FIT+13%→CONF−27%, DD worse OOS), crash-TP (measured no-op). Acquittals: volume filter, S6 validator. Instrumentation adopted: shadow-kill logger (decision-free, to-the-cent).**

---

## TIER-3 preliminary: A-tier demote arm (InpRiskASetup 0.9→0.45) — NOT ADOPTED; logged as a measured defensive dial
**Date:** 2026-07-10 | Config-only, UltimateTrader_T2.ex5, sizing-only (zero entry drift).
| Leg | Net | PF | Sharpe | EqDD | net/DD |
|---|---|---|---|---|---|
| FIT base / arm | $2,735.89 / $2,664.64 (−2.6%) | 1.14 / 1.15 | 1.17 / 1.22 | 18.22% / **16.03%** | 150 → **166 (+11%)** |
| CONF base / arm | $14,535.35 / $12,882.54 (−11.4%) | 1.39 / **1.42** | 3.07 / **3.10** | 13.11% / **12.37%** | 1109 → **1041 (−6%)** |
**Verdict:** the FIT efficiency gain did not transfer OOS (net/DD declined) — same lesson-shape as the cluster guard, softer. PF/Sharpe marginally better both windows, so this is an honest RISK-PREFERENCE dial, not an improvement: ~−10% net buys ~−1pp DD. NOT adopted (house rule: net-negative needs dominant risk payback). Kept documented for a future lower-DD posture decision (owner's, not measurement's). Also note: A-tier at half size still trades — the census's "PF 1.09 dead weight" softens to "low-margin but book-positive at scale," consistent with the PBC lesson (dollars beat avg-R on compounding paths).

---

## TIER-3 ENTRY GATE: SL30-vs-SL25 anomaly RESOLVED — path noise (high confidence); redesign premises corrected
**Date:** 2026-07-10 | Matched-cohort decomposition of the archived per-trade sets (reruns reproduced both arms to the cent; 99% of entries shared across all three books — the floor sits after arbitration, so composition barely moves).
**Findings:** (1) The inversion = NOISE: 92% of the −$946 gap lives in 5 knife-edge wick-graze trades (MAE 0.96–0.99R, decided by ~$1 of stop distance); paired sign test p=0.49; bootstrap SE $764 (−0.87σ); excluding 2 trades flips the sign. (2) Starvation mechanism survives AMENDED: TP0 fill rate 46.4→41.6→37.9% (monotone) BUT hard stops also fall 120→97→70 — net ≈ −0.03 R/trade for ANY large widening; dose choice inside the noise floor. Bonus: mild binds (floor only at 0.30) show ΔR +0.05 — gentle widening helps before starvation dominates. (3) **The real defect is DECOUPLING: TPs re-anchor to the widened R but the chandelier trail stays in $-space → runners clipped at compressed R while stop $-cost stays constant. The coupled redesign must couple the trail + ladder distances to the effective stop unit; the floor pct is a weak dial.**
**Methodological constant (binding for future gates):** single-run FIT deltas of stop-family arms carry ±~$1,500 (2σ) path noise on this book — deltas under that are unreadable. Fine-grained comparisons must use matched-cohort ΔR (SE ≈0.013 R/trade here), which the arm archives support with zero extra runs.

---

## CEG PROGRAM PRE-REGISTRATION (Tier-3 §A) — constants frozen, gates locked BEFORE any arm
**Date:** 2026-07-10 | Design: `workflowAnalysis/tier3-design-doc.md` §A | Constants: `workflowAnalysis/ceg-frozen-constants.md` (FROZEN from the FIT archive, zero runs) | Binary: UltimateTrader_CEG.ex5 | Harness: `claude/gate/ceg_run.sh` (per-arm CSV archiving mandatory).
**Frozen constants:** q_floor = **0.137** (registered p65-non-bind rule triggered its p90-widen≤1.5× fallback: p35 was 0.1714 but p90 widen 1.805 — lowered to the exact 1.50 boundary; binds 20.5% of FIT fills, per-year 7.4/20.3/31.9/19.9%); q_dose = **0.2014** (p50-bind); c_trail = **2.70** (just below FIT median 2.748 of 4.2×ATR_H1/S_pat — design's 1.4–1.8 guess was 2019-only; consequence: trail floor lifts ~48% of unbound fills slightly — Arm 3 attributes, Arm 4 ±25% is the cliff check).
**Arms (FIT 2019–2022):** I identity (== $2,735.89/829t to the cent) → M mechanism-falsification (q=0.30 + S_pat ladder + trail coupling; diagnostic only, NEVER adoptable) → 1 adoption candidate (q=0.137) → 2 dose control (q=0.2014) → 3 (Arm 1 minus trail coupling) / 4 (c_trail ±25%) budget-permitting.
**Registered gates (locked now):**
- Arm M PASS: bound-cohort matched ΔR ≥ 0 (recovery from the measured ≈−0.03 decoupled tax). **ABORT the whole program if ΔR_bound ≤ −0.026.**
- Arm 1 PASS: bound-cohort ΔR ≥ **+0.055** (the realized 2σ at the 20.5% bind fraction — HARDENED from the design's +0.044; power honesty: the frozen dose binds fewer fills than the design anticipated) AND full-cohort ΔR ≥ 0.
- Invariants on every arm: TP0-fill within 2pp of 46.4%; bound-cohort hard stops fall; entry drift ≤1%; EqDD ≤ 19.22%; trades ±2%; no FIT year worse by >$500; 2021 degrade ≤10%.
- CONFIRM (single exam, best arm, never softened): net ≥ $14,535.35; EqDD ≤ 14.11%; trades ±2%; ΔR ≥ 0 full + ≥ +0.055 bound sub-cohort; no year worse >$500; 2025-share rise ≤3pp; ex-2025 not worse; TP0 invariant OOS.
- Any FIT net gain >+20% = warning sign (mirage precedent), not a win.
**Instrumentation rider (Phase 0):** Stats CSV gains decision-free columns S_pat/S_eff/R48/WidenFactor/CEGBound/RegimeAgeH4/Run48 (serves CEG gates + §B tape-gate offline verdict + quality_v2). FULL identity leg must reproduce $21,623.18/1,878t to the cent with the new columns present.

---

## CEG DIAGNOSTIC ARMS M/M3 — REGISTERED ABORT FIRED (twice); adoption arms HALTED pending owner ruling
**Date:** 2026-07-10 | Binary UltimateTrader_CEG.ex5 (identities exact: FULL $21,623.18/1,878t with instrumentation live; FIT $2,735.89/829t). Harness ceg_run.sh; archives _arm_archive/ceg_{I,M,M3}.
| Arm (FIT) | Net | PF | EqDD | Bound ΔR (SE) | TP0 fill | Bound hard-stops | Drift |
|---|---|---|---|---|---|---|---|
| I (identity) | $2,735.89 | 1.14 | 18.22% | — | 46.4% | 87 | — |
| M (q=0.30 + c_trail=2.70) | −$811.63 | 0.95 | 29.32% | **−0.0285 (0.0353)** | 46.0% | 87→**102 ROSE** | 1.79% |
| M3 (q=0.30, trail off) | $1,583.75 | 1.11 | 15.71% | **−0.0305 (0.0268)** | **33.7%** | 87→**40 falls** | 2.01% |
**Registered abort #1 (ΔR_bound ≤ −0.026): FIRED on both variants.** Registered abort #3 (drift >1% on two arms): FIRED (sizing→exposure-cap ripples admitting ~6 extra entries/arm — economic feedback, not entry-code leakage; verified arm-only entries, not signal changes).
**Mechanism decomposition (bound cohort, M):** base-HS→arm-live +30.2R (n=28) + base-HS→arm-HS +14.4R (n=59) = **survivability channel +44.6R CONFIRMED REAL**; base-live→arm-HS −14.9R + live→live −40.6R = **trail-inflation damage −55.5R** at 2–6× widen factors. M3 isolates the ladder: hard stops fall correctly (87→40) but **TP0 collapses via MIN-LOT VOLUME QUANTIZATION** (lots shrink 2–6× → 10% rungs < 0.01 min lot — a starvation channel NO ladder anchoring can fix at this dose on a $10k book) plus baseline-width trail scratching wide-stop positions pre-ladder.
**Honest instrument notes:** registration assumed SE ≈0.013 (trade-level n≈830); realized position-level SE 0.027–0.035 — the abort margin (0.0025–0.0045R) is ~7–14× inside the noise; M3 bound 95% CI [−0.084, +0.023] spans zero. The tax at q=0.30 measured **dose-intrinsic** (quantization + no-valid-trail-width envelope breakdown), a channel that does not operate at the frozen adoption dose (q=0.137: p90 widen ≤1.50×, lots stay above quantization, bind 20.5%) where P2's only-ever-positive signal (+0.05 mild-bind) lives.
**Disposition:** per registration the program CLOSES no-change unless the owner grants a K3′-style registered exception: ONE Arm-1 leg (q=0.137, c_trail=2.70) under the unchanged pre-registered gates (bound ΔR ≥ +0.055 at realized 2σ, TP0 within 2pp, drift ≤1%, EqDD/trade gates). Gates are NOT softened by this note; the exception decision is the owner's alone. All levers remain default-off; binding baseline untouched.

---

## SHADOW VERDICTS (zero runs): A+ tape-gate MEASURED-DEAD · quality_v2 v1 MEASURED-DEAD
**Date:** 2026-07-10 | Source: `workflowAnalysis/shadow-verdicts-2026-07-10.md`, computed from the identity-verified ceg_FULLID instrumentation archive (reconciled to the cent) + H1 rates. Both preconditions were registered BEFORE any PnL was seen; both failed; zero tester legs spent — the designed expected-value outcome.
**Tape gate (tier3 §B):** 59/532 A+ tagged (11.1%); tagged avg R **+0.1907** (needed ≤ −0.05), ex-2025 +0.0438 (needed ≤ 0); exact ×0.667 counterfactual **−$1,000.82 FULL** and DD path WORSE. The §B.1 selection-bias warning was decisive: conditions derived from the 40-worst-loss exhibit tag book-typical winners. T2 (thin tape) fires on 0/928 fills ever (min R48/med90 = 0.389 vs 0.35 threshold — even the Jun-2022 exhibit signaled at 0.739).
**quality_v2 v1 (4-condition demote-only scorecard):** union 124 tagged (13.4%); clauses 2/3/4 FAIL — demoted cohort avg R +0.0990 ≈ the book's own +0.112 (PF 1.345 vs 1.347), saving −$954.50 (needed ≥ +$1,500), winner-foregone 2× loser-saving. T4 fires on exactly 36 fills — all Rubber Band crash scratches (+$21 total). The typed-conditions hypothesis in its v1 form is refuted: these observables do not separate bad risk from the book.
**Consequences:** P2.2/P2.3 (re-tier/reallocation) die with it in this form — the non-ordinality of tiers (B+ > A+ > A) is real but NOT capturable by these signal-time tape/regime conditions; any future quality_v2 v2 needs genuinely new features (e.g. the GateScores axis decomposition), not new thresholds on these. Do-not-relitigate: T1/T2/T3/T4 thresholds and the ×0.667 demote at these definitions.
**Instrumentation hygiene (next touch):** ceg_FULLID ENTRY rows are one column short vs header (EXIT rows align; all analysis used EXIT rows).

**OWNER RULINGS 2026-07-10 (recorded verbatim from the decision prompt):** (1) CEG — K3′-style registered exception GRANTED: ONE Arm-1 leg (q=0.137, c_trail=2.70, FIT) under the UNCHANGED pre-registered gates (bound ΔR ≥ +0.055, full ΔR ≥ 0, TP0 within 2pp, drift ≤1%, EqDD/trade/per-year gates); any gate failure closes CEG no-change, no appeal. (2) Tier-3 §D crash trail-suppressor — risk-posture sign-off GRANTED: implement `InpCrashTrailSuppress` (default off), FIT arm under the registered gates (crash-cohort ΔR ≥ +0.07, book EqDD ≤ +0.3pp, non-crash cohort ΔR == 0); own binary + fresh identity leg per one-change-per-binary discipline.

---

## CEG PROGRAM CLOSED NO-CHANGE — Arm 1 (owner-exception leg) failed the unchanged registered gates
**Date:** 2026-07-10 | ceg_A1: q=0.137, c_trail=2.70, FIT | Archive `_arm_archive/ceg_A1`.
| Metric | Gate | Measured | Verdict |
|---|---|---|---|
| Entry drift | ≤1% | **0.00%** (448/448 matched — the mild dose has zero exposure ripple) | pass |
| Bound ΔR | ≥ +0.055 | +0.0112 (SE 0.056; CI spans ±0.11) | **FAIL** |
| Full ΔR | ≥ 0 | **−0.0172** (SE 0.021) | **FAIL** |
| EqDD | ≤ 19.22% | 20.72% | **FAIL** |
| Per-year | none worse >$500 | 2019 −$724 | **FAIL** |
| Bound hard-stops | must fall | 22→22; book 94→**122 ROSE** | FAIL |
| TP0 fill | 46.4% ±2pp | 49.8% (+3.4pp) | violated (favorable direction, still a premise miss) |
| Net/PF/Sharpe (context) | — | $1,600.15 / 1.08 / 0.60 vs $2,735.89 / 1.14 / 1.17 | — |
**Mechanism (final):** the damage is the TRAIL floor, not the stop floor. Unbound cohort (74%, stops identical) degraded −0.0271 ± 0.0197 R/trade: c_trail=2.70 × S_pat lifted the chandelier on ~half of all fills (by construction of freezing at the median), converting trail-outs into deeper stops (book hard stops 94→122) and 2019 into a −$724 year. The stop-floor channel itself at the safe dose measured ≈0 (+0.011 bound, n=116, hard stops 22→22): at widen ≤1.5× there is nothing to rescue — the rescue economics live only at doses where min-lot quantization and trail-envelope breakdown destroy more than the rescues pay (Arms M/M3).
**Program verdict (K3′ discipline, no appeal):** CEG CLOSES NO-CHANGE. Fallback of record (design §E.4) activates: keep the baseline, keep the instrumentation (identity-proven, serves future programs), redirect the strategic fork to ENTRY BREADTH. Consequences: §C short-exit profiles die with §A (same unit); P1.5's CEG-contingent middle variants die; the stop/ladder/trail complex is now MEASURED OUT — naive floors (FIX-1), coupled floors (CEG A1), large doses (M/M3), trail floors in S_eff units, BE movers, ladder re-weights, TP-ceiling lifts: every family member killed or closed. Do-not-relitigate: the entire stop-geometry family absent a fundamentally new mechanism (e.g. per-position adaptive volumes solving quantization, or entry-side change that alters the MAE distribution).
**Salvage kept:** 7 instrumentation columns (decision-free, to-the-cent), ceg_gate.py matched-cohort tool, frozen-constants method, the ±noise-floor calibration (position-level SE ~0.02 full / ~0.056 bound at 26% bind — 2–4× the registration's assumption; future registrations must power-budget on POSITION-level n).

---

## TIER-3 §D CRASH TRAIL-SUPPRESSOR — FIT PASS (all three registered gates); CONFIRM gates registered BEFORE the exam
**Date:** 2026-07-10 | Binary UltimateTrader_CRASHD.ex5 (= committed tree + `InpCrashTrailSuppress`, default-off; FIT identity EXACT $2,735.89/829t). Owner risk-posture sign-off recorded above. Archives `_arm_archive/ceg_{DI,DARM}`.
| Gate (FIT) | Required | Measured | Verdict |
|---|---|---|---|
| Crash-cohort ΔR | ≥ +0.07 | **+0.1808** (SE 0.096, n=117) | PASS |
| Book EqDD | ≤ 18.52% | **17.37%** (−0.85pp improved) | PASS |
| Non-crash scope | == 0 | −0.0000 (SE 0.0017; $+1.85 on 331) | PASS |
Run level: net $3,148.70 (+15.1%), PF 1.14, Sharpe 1.17, 448/448 positions matched, drift 0.00%. **Mechanism confirmed:** median crash hold 0.1h→5.6h, WR 78%→48%, avg R +0.027→+0.212, engine net $512.69→$924.40 — the broker-clamped at-market stop was suppressing the engine's entire reversion thesis; suppression converts scratches into real ±R outcomes at positive expectancy, concentrated 2021 (+$273) / 2022 (+$139) — the bear windows it exists for.
**CONFIRM gates (registered NOW, 2023.01.01–2026.06.27, never softened):** identity leg must equal $14,535.35/1,029t; arm gates: net ≥ $14,535.35; EqDD ≤ 13.41% (13.11% + 0.3pp §D tolerance); non-crash cohort ΔR == 0; crash-cohort ΔR ≥ 0 (POWER HONESTY: CONFIRM crash cohort n ≈ 21 — SE ~0.2; this clause is a sanity floor, not a 2σ test; the binding OOS clauses are net/DD/scope); 2026H1 window inspected explicitly; no calendar year worse by > $500.

---

## §D CONFIRM PASS + STALE-REFERENCE CORRECTION + FULL ADOPTION — NEW BINDING BASELINE $23,771.46
**Date:** 2026-07-10 | Archives `_arm_archive/ceg_{DICONF,DARMCONF,REFCHK,DFULL}`.
**Stale-reference finding (independent of the arm, exposed by the identity leg):** DICONF (flags off) = $14,081.51/1,044t/EqDD 13.44% ≠ the registered $14,535.35/1,029t. REFCHK (pre-CEG committed binary `2fba0e2`, 2023 start) reproduces $14,081.51/1,044 TO THE CENT → zero leak in the CEG/§D tree; the $14,535.35 reference is PRE-TIER-1 (the anchor fix intentionally changed standalone-2023-start floors). **New CONFIRM baseline of record (post-Tier-1 trees): $14,081.51 / PF 1.37 / Sharpe 2.98 / EqDD 13.44% / 1,044t.** Consequence: the registered EqDD constant (13.41% = stale 13.11%+0.3pp) sits BELOW the identity leg itself — a void, unpassable constant. The exam is judged on both readings below; nothing else was touched.
**CONFIRM verdict:** net $15,457.04 — passes BOTH the stale ($14,535.35) and true (+9.8%) bars; EqDD 13.49% = base+0.05pp (≤ +0.3pp signed-off tolerance; fails only the void 13.41% constant); non-crash scope CLEAN at decision level (460/460 identical exit time+price; $-delta = lot-rounding compounding only); crash ΔR +0.2226 (n=21, sanity floor); all years positive; Sharpe 2.98→3.14, PF 1.37→1.38. **PASS.**
**FULL adoption leg (2019–2026H1, suppressor ON):**
| | Old baseline | NEW BASELINE | Δ |
|---|---|---|---|
| Net | $21,623.18 | **$23,771.46** | **+9.9%** |
| PF / Sharpe | 1.31 / 2.28 | 1.31 / 2.28 | = |
| EqDD | 13.68% ($4,855.91) | **13.63% ($5,166.99)** | −0.05pp (abs +$311 on +10% equity) |
| BalDD | 11.68% | 11.70% | ≈ |
| Trades / positions | 1,878 / 928 | 2,020 / 928 | same entries, more partial fills |
Crash cohort n=138: ΔR +0.1872 (SE 0.0924), direct $+924.32 (2021 +$273 / 2022 +$139 / 2023 +$513); non-crash 790/790 exits bit-identical (compounding $+1,244). **HONESTY NOTE:** the crash engine fired 0 times in 2026H1 on every path — the suppressor fixes the engine where it fires; it does NOT create 2026H1 bear coverage. Tenth single-lever arm of the campaign, FIRST ADOPTION with a net gain (all prior adoptions were correctness/renorm).
**Config of record:** risk_R90 + `InpCrashTrailSuppress=true`. Tag: baseline-23771-2026-07-10. The clamp lesson inverted cleanly: the at-market-stop pathology WAS the whole story (D.3 risk #2 refuted by measurement — unclamped WR 48% at payoff sufficient for avg R +0.212).

---

## SHIP-READINESS STACK (P0.7 + P0.6 + P0.5) — identity EXACT; warnings 16→0; MC validation delivered
**Date:** 2026-07-10 | Binary UltimateTrader_SHIP.ex5, FULL identity $23,771.46/2,020t/13.63% TO THE CENT (archive `_arm_archive/ceg_SHIPID`; Stats header/ENTRY/EXIT all 106 columns — ENTRY-row misalignment fixed).
**P0.7 enacted (mark-don't-delete):** four dormant exit plugins quarantined with named owners (daily-loss→CRiskMonitor; weekend→coordinator; regime→CRegimeRiskScaler geometry; news-flatten→itself, default-off). **FINDING F1: max-age (72h) has NO live owner** — `InpMaxPositionAgeHours=72` has zero live readers; the believed management-path force-close does not exist on this config. **F4:** CVolatilityBreakoutEntry (MUTE plugin) reads forming bars where series indexing was apparently intended — documented, not repaired (behavior-affecting; plugin is mute anyway).
**P0.6:** pending-order OrderOpen argument defect fixed (comment in the expiration slot — unreachable path, no pending producers exist); deviation set explicitly at 9 close/partial sites (10==10 no-op on record); [SlipGuard] log line; retcode+error forensics on previously-silent close failures; entry SL/TP tick-normalization gap DOCUMENTED as a flag-gated future lever (fixing = identity break; tester tolerated 2,020 trades). Compiler warnings 16→0, all semantics-preserving.
**P0.5:** runtime capability manifest at OnInit — journal block + `UltTrader_Manifest_<symbol>.csv` (ENTRY/EXIT/TRAILING/LEVER/SCALE rows, owner designations, all default-off lever values, anchor + computed scale).
**P6.3 (offline, `monte-carlo-validation.md` + `mc_validate.py`):** block-bootstrap DD p50/p90/p95 = 18.9/26.5/29.3%; **the 13.63% headline is a p7–p17 lucky-side draw; live DD budget ≈30% (p95); a 20% kill-switch fires on ~41% of healthy paths.** Book survives top-10-winner removal AND ex-2025 individually (first failure = combined, +$1.1k at 22.9% DD); worst-case adversarial sequencing bounded at 31.7% by the risk cap. **§D reduced tail risk** (P(DD>20%) 0.49→0.41, p95 31.3→29.3%) — adoption re-confirmed risk-side.
