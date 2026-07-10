# Short-Side Forensics — Complete Long/Short Asymmetry Map

Date: 2026-07-11 (read-only investigation; no source edits, no tester runs)

**Config of record:** `/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/risk_R90.ini`
(Expert=UltimateTrader_SHADOW.ex5, XAUUSD+ H1, 2019.01.01–2026.06.27, Model 4).
**Archive of record (funnel + counts):** `_arm_archive/ceg_DFULL` (Common Files, UTF-16LE) — its ini is
byte-identical to risk_R90 in [TesterInputs] except CEG params explicitly 0/false there (CEG off in both;
risk_R90 omits them → compiled defaults 0/false, verified `UltimateTrader_Inputs.mqh:132,609-611`; the
`UltimateTrader_SHADOW.set` tester cache does not contain them either). 928 positions: **555 LONG / 373 SHORT**.

Key effective inputs (stated because every claim below depends on them):
`InpShortRiskMultiplier=1.0`, `InpEnableBearishEngulfing=false`, `InpEnableS6Short=false`,
`InpBearPinBarBlockNY=true`, `InpBearPinBarAsiaOnly=false`, `InpBullMACrossBlockNY=true`,
`InpLongExtensionFilter=true (0.5%)`, `InpEnableMultiStrategy=false`, `InpEnableConfirmation=true (strictness 0.9, window 1 bar)`,
`InpMinRRRatio=1.3`, `InpMinRRShortCrash=1.3`, `InpEnableSessionRiskAdjust=true (London 0.5 / NY 0.9)`,
`InpEnableRegimeRisk=true (Trend 1.25/Normal 1.0/Choppy 0.6/Vol 0.75)`, `InpUseDaily200EMA=true`,
`InpEnableCrashDetector=true`, `InpCrashTrailSuppress=true`, `InpEnableS3S6=true`, `InpEnableSMC=true`,
`InpSignalSource=2 (BOTH)`, `InpEnableSessionQualityGate=true (block 0.25 / reduce 0.5)`, `InpNewsFilterEnable=false`.

---

## 1. FUNNEL RECONCILIATION (ceg_DFULL, 2019–2026H1)

Candidates CSV rows reconcile exactly: LONG 2,562 unique + 1,216 WINNER dup-rows = 3,778; SHORT 709 + 399 = 1,108.

| Stage | LONG | SHORT | Source |
|---|---|---|---|
| Unique candidates (plugin emissions reaching orchestrator) | 2,562 | 709 | Candidates CSV, rows excl. FINAL |
| VALIDATOR reject | **532** | **0** | Candidates (`VALIDATOR,REJECT`) |
| VOLUME reject | 449 | 163 | Candidates |
| CONFIDENCE reject | 84 | 19 | Candidates |
| QUALITY reject (SETUP_NONE) | 246 | 115 | Candidates |
| SMC reject | 0 | 0 | Candidates (gate dead — §3.4) |
| Qualified (QUALITY,PASS) | 1,251 | 412 | Candidates |
| Lost same-bar arbitration | 35 | 13 | 1,251−1,216 / 412−399 |
| FINAL WINNER | 1,216 | 399 | Candidates (`FINAL,WINNER`) |
| → stored PENDING (confirmation) | 1,192 | **0** | ShadowPendings CREATED |
| → immediate execution attempts | 24 | 399 | winners − pendings |
| Pending killed: CONFIRM_WINDOW_EXHAUSTED | 579 | 0 | ShadowPendings KILL |
| Pending killed: EXTENSION_72H (long-only filter) | 59 | 0 | ShadowPendings KILL |
| Pending killed: GUARD_STALENESS / REVALIDATE_FAIL | 8 / 2 | 0 | ShadowPendings KILL |
| Pending EXEC / EXEC_FAIL | 532 / 12 | 0 | ShadowPendings |
| Risk-audit rows | 569 | 399 | Risk CSV (LONG: 555 EXECUTED + 1 RR + 1 EXPOSURE_CAP + 12 EXEC_FAIL; 1-row discrepancy vs 568 expected, unresolved, ≤0.2%) |
| REJECT_RR_BELOW_MIN | **1** | **26** | Risk CSV ExecutionOutcome |
| **FILLS** | **555** | **373** | Stats ENTRY rows (= 928 = report positions) |

Short funnel reconciles to the trade: 709 → 412 → 399 → 373 fills + 26 RR kills. **Candidate→fill conversion:
SHORT 52.6% vs LONG 21.7%** — shorts convert 2.4× better because they skip the validator AND the confirmation
pipeline. The short problem is not breadth-after-candidacy; it is (a) candidate generation (2,562 vs 709 — the
bear sides of 3 plugins are amputated), (b) sizing haircuts, (c) quality misallocation, (d) exit clipping.

Per-year unique candidates (L/S): 2019 336/70 · 2020 249/28 · 2021 347/215 · 2022 276/172 · 2023 399/103 · 2024 382/47 · 2025 411/44 · 2026 162/30.

Per-year fills & PF:

| Year | LONG n / net / PF | SHORT n / net / PF |
|---|---|---|
| 2019 | 64 / +$106 / 1.04 | 30 / −$164 / 0.81 |
| 2020 | 61 / +$1,020 / 1.27 | 18 / +$121 / 1.15 |
| 2021 | 40 / −$391 / 0.85 | 79 / +$778 / 1.25 |
| 2022 | 45 / +$682 / 1.28 | 111 / +$1,209 / 1.26 |
| 2023 | 76 / +$872 / 1.17 | 56 / +$2,050 / 1.65 |
| 2024 | 110 / +$3,242 / 1.38 | 36 / −$481 / 0.83 |
| 2025 | 120 / +$13,358 / 1.82 | 27 / +$1,430 / 1.60 |
| 2026H1 | 39 / +$565 / 1.08 | 16 / −$112 / 0.97 |
| **Total** | **555 / +$19,455 / 1.394 (WR 45.6%, avgR +0.151)** | **373 / +$4,831 / 1.227 (WR 43.4%, avgR +0.123)** |

Exit economics by direction: capture ratio (ΣPnL_R/ΣMFE_R) SHORT 17.1% vs LONG 23.2%; median hold SHORT 4.9h
vs LONG 11.9h; TP2 partials SHORT 28/373 (7.5%) vs LONG 129/555 (23.2%); BREAKEVEN_ARMED SHORT 12 vs LONG 95;
trail updates/position SHORT 0.97 vs LONG 3.09; weekend-close exits SHORT 0 vs LONG 24.

---

## 2. THE ASYMMETRY TABLE

Direction key: **AS** = anti-short, **PS** = pro-short (anti-long), **N** = neutral/symmetric-in-form.
"Effect" marks mechanisms that are symmetric in code but directionally loaded by gold's bull composition.

| # | Mechanism | File:line | Exact condition | Cuts | Measured firing count | Live on config of record? |
|---|---|---|---|---|---|---|
| 1 | Bearish MA Cross removed from plugin | CMACrossEntry.mqh:216-217 | bear branch deleted ("REMOVED in Phase D... PF 0.59"); plugin emits BUY only | AS | 267 L candidates, 0 S possible | YES (structural) |
| 2 | Bearish Engulfing disabled | CEngulfingEntry.mqh:214-217 + UltimateTrader.mq5:285 | `g_profileEnableBearishEngulfing`(=InpEnableBearishEngulfing=**false**) && trend∈{BEAR,NEUTRAL} | AS | 1,330 L candidates, 0 S emitted in 7.5y | YES (input-dead) |
| 3 | S6 Failed-Break short side disabled | CFailedBreakReversal.mqh:191 | `if(!g_profileEnableS6Short) return` (InpEnableS6Short=**false**) | AS | 105 L candidates, 0 S | YES (input-dead) |
| 4 | Bear Pin Bar NY/evening block | CPinBarEntry.mqh:238-244 | `InpBearPinBarBlockNY && gmt_hour >= 13` → no bear pin 13:00-23:59 GMT; bull pin has NO session block | AS | Bear-pin fills: Asia 121, London 88, **NY 0** | YES |
| 5 | Bull-pin proximity-to-high filter (long-only) | CPinBarEntry.mqh:176-196 | `InpPinBarProximityFilter` — **false** | PS(form) | 0 | NO (off) |
| 6 | Crash engine is SELL-only | CCrashBreakoutEntry.mqh:316 (+280-310) | Rubber Band: price > EMA21+2.0×ATR, ADX≥25, death-cross regime, hours 13-17, internal rr≥1.0 floor | PS | 347 S candidates → 138 fills (PF 1.325) | YES |
| 7 | SHORT validator bypass | CSignalOrchestrator.mqh:647-689 | `if(sig_type==SIGNAL_SHORT)` → skip full TF/MR validator; only `current_atr >= m_tf_min_atr` | PS | Validator rejects: **L 532 / S 0**; short ATR-min kills: 0 | YES |
| 8 | SHORT revalidation bypass | CSignalOrchestrator.mqh:1140-1146 | pending SHORT revalidation = ATR-min only | PS | 0 (shorts never pend) | YES (moot) |
| 9 | Entire CSignalValidator short-protection block = dead code | CSignalValidator.mqh:281-668; params mq5:733-738 | InpBullMRShortAdxCap=17, InpShortTrendMinADX=22, InpShortTrendMaxADX=50, InpShortMRMacroMax=0, InpBullMRShortMacroMax=−3 — consumed only by Validate*Conditions, which shorts never reach (both call sites gated) | N (dead) | 0 possible | NO — dead code |
| 10 | HTF-uptrend SHORT veto (routed engines only) | CSignalOrchestrator.mqh:670-679; stamp CMajorStrategyEngine.mqh:104-110 | `is_engine && ((H4 bull ∨ D1 bull) && price>MA200)`; `is_engine`=`routed_engine` requires InpEnableMultiStrategy=**false** | AS(form) | **0 firings in all 8 GateScores years** (560 rows, 297 SHORT) | NO — structurally dead |
| 11 | SHORT confirmation-candle skip | CSignalOrchestrator.mqh:1025-1026 | `skip_confirmation = !requiresConfirmation ∥ best_is_mr ∥ (best_sig_type==SIGNAL_SHORT)` | PS | Pendings: L 1,192 (648 die = 54.4%) / S **0** | YES |
| 12 | Bypass "protections" claimed in comments (0.5× short mult, SMC, confidence) | CSignalOrchestrator.mqh:650-653, 1024 | 0.5× mult: `InpShortRiskMultiplier<1.0` false at 1.0 (CTradeOrchestrator.mqh:477); SMC: `ConfigureSMC` has **zero callers** → m_smc_enabled=false → always passes score 50 (CSignalValidator.mqh:66,168); confidence: direction-blind env gate (CMarketFilters.mqh:150-180, pattern string unused) | — | SMC rejects 0/0; short-mult log lines 0 | **2 of 4 dead, 2 direction-blind** |
| 13 | Bear-regime +2 quality points for shorts | CSetupEvaluator.mqh:115-119 | `isBearRegime && signal==SIGNAL_SHORT` (bear regime = CCrashDetector death-cross state) | PS | Bear regime active 133/789 logged days 2019-22 (ShortDiagnostic); per-signal count not logged | YES |
| 14 | Bear-regime tier upgrades (BB-Mean→A, MACross→B+) | CSetupEvaluator.mqh:100-112 | comment-token match "BB Mean"/"MA Cross" on SHORT in bear regime | PS(form) | 0 — no live plugin emits those tokens as shorts (#1, BB-MR plugin removed) | NO — dead |
| 15 | +3 quality for extreme RSI (either tail) | CSetupEvaluator.mqh:186-192 | `rsi>75 ∨ rsi<25` → +3 points, direction-blind; promotes overbought bear-pins into A+ tier at InpRiskAPlusSetup=1.35% (2× B+ 0.675%) | **AS (effect)** | A+ bear pins n=116: PF **1.008**, avgR −0.002, WR 34.5% vs B+ n=37 PF **2.402**; A n=56 PF 1.486. Crash: A+ n=87 PF 1.13 vs A n=51 PF 2.00 | YES |
| 16 | Bull/Bear score inputs never reach ranking | CSignalOrchestrator.mqh:840-841 | non-engine `signal.qualityScore` overwritten with tier bucket {10/7/5/3} — InpScoreBullPinBar=88 / InpScoreBearPinBar=15 / etc. discarded | N (dead) | all legacy signals | NO — dead inputs |
| 17 | Same-bar L/S arbitration | CSignalOrchestrator.mqh:855 | strict `>` on qualityScore; ties keep earlier-registered plugin (bull-heavy: Engulfing, PinBar bull branch first) | AS | 13 bars with both sides qualified → **LONG won 13/13** | YES |
| 18 | Session/skip-zone bypass in bear regime | CSignalOrchestrator.mqh:490-510 | `if(!isBearRegime)` wraps session filter + skip zones | PS | not separately logged | YES (skip zone itself no-op: start=end=11) |
| 19 | RR gate measures LONG reward to FAR TP, SHORT reward to NEAR TP | CTradeOrchestrator.mqh:384 (same idiom :1016) | `reward = MathAbs(MathMax(tp1,tp2) − entry)` — for SHORT the numerically-larger price is the *nearer* TP1 | **AS (bug-class)** | RR kills: **S 26 / L 1**. Breakdown: 18 PBC shorts at "RR 1.30"−ε (PBC sets only TP1 at exactly 1.3R — CPullbackContinuationEngine.mqh:928,937; TP2 autofilled 1.8R is ignored by MathMax for shorts), 8 IC-Breakout shorts at 0.61–1.00 | YES |
| 20 | RR relax for shorts in VOLATILE/CHOPPY | CTradeOrchestrator.mqh:390-400 | `effective_min_rr = InpMinRRShortCrash` | PS(form) | no-op: 1.3 == 1.3 | NO-OP |
| 21 | Session risk haircut applies to IMMEDIATE path only — i.e. to shorts | UltimateTrader.mq5:2277-2306 (adjust), 1996-1998 (comment: "Session scaling remains active for immediate signals only (shorts)"), CTradeOrchestrator.mqh:1067-1070 (confirmed path re-applies stored mult ≡ 1.0) | London ×0.5 (GMT 8-13), NY ×0.9 (GMT 13-21), Asia ×1.0 — set only after "Only immediately-executable signals reach here" | **AS (deliberate)** | Executed sessionMult: **SHORT 150×0.5 + 51×0.9 + 172×1.0 (mean 0.785)** vs LONG 532 CONFIRMED all ×1.000 + 23 immediates (mean 0.996) | YES |
| 22 | Shock + session-quality risk REDUCERS also immediate-only | UltimateTrader.mq5:2161-2205 (compute), 2330-2341 (apply, immediate block) | `shock_factor×sq_factor` floored at InpMinSessionRiskFactor=0.25 — applied where session mult is applied | AS | not in CSVs (journal-only Print) — uncounted | YES (magnitude unquantified) |
| 23 | Detection-time blocks (shock block, session-quality<0.25 block, SpreadGate, ThrashCooldown, NewsGate) | UltimateTrader.mq5:2190-2234 | gate `CheckForNewSignals()` for the bar — both directions | N | not direction-split | YES (news off) |
| 24 | Regime-risk multiplier differs by path: immediates get the 1.25× TRENDING boost, confirmed longs are capped at 1.0 | immediate: mq5:2371-2375 (`ApplyToRisk`, InpRegimeRiskTrending=1.25); confirmed: mq5:1984-1994 (Choppy 0.6/Volatile 0.7/Ranging 0.75, "TRENDING + NORMAL stay at 1.0") | path split, not direction test | PS | mean regimeMult **SHORT 1.186 (287/373 boosted >1.0)** vs **LONG 0.980 (16/555)** | YES |
| 25 | Counter-trend 200-EMA 0.5× risk cut | CTradeOrchestrator.mqh:571-601 | `(SHORT && entry>MA200) ∨ (LONG && entry<MA200)` → risk ×0.5, lots resized | **AS (effect)** | Executed: **SHORT 172/373 (46.1%) halved vs LONG 11/555 (2.0%)** | YES |
| 26 | ApplyShortProtection (risk plugin) | CQualityTierRiskStrategy.mqh:124-138 | SELL only; VB/Crash exempt; {BB_MR, RANGE_BOX, FBF} ×0.7 hardcoded; else ×g_profileShortRiskMultiplier=1.0 | AS(form) | 0 — no live short emitter carries the 0.7× patterns (RangeBox/FBF plugins de-registered by S3S6 swap mq5:807-808; S3 emits PATTERN_RANGE_EDGE_FADE; S6 shorts off) | NO — dead on record |
| 27 | Second short-mult choke | CTradeOrchestrator.mqh:476-484 | `sig_type==SIGNAL_SHORT && InpShortRiskMultiplier<1.0` | AS(form) | 0 at mult=1.0 | NO-OP |
| 28 | Net sizing outcome (all multipliers) | Risk CSV | — | **AS** | mean final/base risk: **SHORT 0.702 vs LONG 0.932**; mean final risk **SHORT 0.817% vs LONG 1.127%** (bases ≈equal 1.16/1.21) | measured |
| 29 | Long-extension (momentum-exhaustion) filter — longs only | UltimateTrader.mq5:422-480, 432 `if(!g_profileLongExtensionFilter ∥ !is_buy_signal) return false`; kill at 2245-2260 + pending path | 72h rise ≥0.5% AND weekly EMA20 falling → block LONG | PS | **59 long pendings killed (EXTENSION_72H)**; immediate-path blocks unlogged in CSV | YES |
| 30 | Bull MA-Cross NY block | CMACrossEntry.mqh:173 (`g_profileBullMACrossBlockNY`=true) | bull MA cross suppressed in NY session | PS | not separately logged (267 L candidates survived it) | YES |
| 31 | Chandelier trail formula | CChandelierTrailing.mqh:186-207 | LONG: HighestHigh(7)−mult×ATR; SHORT: LowestLow(7)+mult×ATR — symmetric | N | — | YES |
| 32 | Chandelier skips SELL positions with no SL | CChandelierTrailing.mqh:146-147 | `pos_type==SELL && current_sl<=0 → return` (no long twin) | AS(form) | ~0 (EA always sets SL) | YES (inert) |
| 33 | Broker STOPS_LEVEL/freeze clamp on trail sends | CPositionCoordinator.mqh:3061-3104 (clamp), 3106-3119 (ratchet re-check) | symmetric code; clamp pushes SL to close_px±min_dist (at-market stop) | **AS (effect)** | `+STOPS_LEVEL_CLAMP` broker sends: **SHORT 93 events / 9 positions — ALL "Bearish Pin Bar"** vs LONG 10 events / 3 positions. The 9 clamped bear-pin shorts all exited as scratch wins (R +0.02…+0.15, hold 0.0-5.2h) — runners forfeited | YES |
| 34 | §D crash trail-suppressor — crash SHORTS only | CPositionCoordinator.mqh:3007-3017 (+3003-3005: "LONG crash positions are deliberately never suppressed") | `InpCrashTrailSuppress && pattern==PATTERN_CRASH_BREAKOUT && direction==SIGNAL_SHORT && !unlocked` | PS (protective), but **scope excludes bear pins** — see #33 | crash shorts: 0 clamp events post-§D (vs bear pins 93) | YES |
| 35 | Crash TP at EMA21 mean (short-only geometry) | CCrashBreakoutEntry.mqh:301 + Inputs.mqh:248 (InpCrashTPExtension=0, ini-missing → default) | `tp = ema21 − 0×(entry−ema21)`; input comment: "only 2/138 trades ever reached the mean" | N (crash-internal) | 138 fills PF 1.325 | YES |
| 36 | Macro-opposition force close | CRegimeAwareExit.mqh:184-194 | BUY closed at macro ≤ −3; SELL closed at macro ≥ +3 (gold macro skews positive → would hit shorts) | AS(form) | **0 — plugin never Initialize()'d** (quarantined dormant duplicate, mq5:978-1005); no macro-flatten events in TradeEvents | NO — dormant |
| 37 | Adaptive TP / BB TP / structure targets | CAdaptiveTPManager.mqh:325-361, 434-474 | symmetric per-direction math (support/resistance mirrored, sanity floors 0.8R/1.2R both sides) | N | — | YES |
| 38 | Mute registered plugins (both-direction capable) | registrations mq5:825 (VolBreakout), 847 (Displacement), 863-868 (LiquidityEngine OBRetest), 802-804 (S3 RangeEdgeFade), 872-880 (SessionEngine, 4 modes all false) | 0 candidate rows from any of the five in 7.5y | N (cuts both; shrinks the already-thin short source set more) | 0 emissions each | registered but mute |
| 39 | Weekend close / max-age / daily-loss / exposure caps / thrash / spread | various | direction-blind | N | weekend exits L24/S0 (composition — shorts don't survive to Friday) | YES |

**Tally: 39 mechanisms mapped. Anti-short and live-or-effective: 11 (#1,2,3,4,15,17,19,21,22,25,33 — plus net-sizing outcome #28). Pro-short and live: 9 (#6,7,11,13,18,24,29,30,34). Dead / no-op / dormant on the config of record: 10 (#5,9,10,12-partial,14,16,20,26,27,36). Neutral/symmetric: the rest.**

---

## 3. BRIEF ITEMS, VERIFIED

### 3.1 Confirmation skip (item 1)
Verified at CSignalOrchestrator.mqh:1025-1026. The comment (:1021-1024) claims bypass protection =
"quality scoring + 0.5x risk multiplier + SMC". On the config of record: 0.5× mult **dead** (InpShortRiskMultiplier=1.0;
both choke points #26/#27 no-op), SMC **dead** (ConfigureSMC never called — zero callers repo-wide; validator gate
auto-passes with score 50), confidence scoring live but **direction-blind** (environment gate; pattern arg unused).
The only live "protection" is tier scoring — which the +3 RSI bonus (#15) inverts into a damage amplifier.
Effect measured: 0 short pendings ever created; 100% of short winners go straight to execution; 532 of 1,192 long
pendings survive to EXEC (44.6%).

### 3.2 Validator bypass (item 2)
Verified at CSignalOrchestrator.mqh:647-705 (+1140-1146 revalidation). Counted: L 532 / S 0 validator rejects;
the short-side ATR-min residual check killed 0 in 7.5y. Confirmed independently in ShortDiagnostic.log (2019-2022 leg):
840 short signals, 0 "REJECTED by validator", 0 "ATR too low", 0 SMC, 0 HTF-veto; kills there were quality (181)
and confidence (23). Consequence: the whole Group-3 short-protection input family and the 200-EMA short-exception
ladder (CSignalValidator.mqh:358-505: macro≤−3 override, H4-bear+ADX cap, RSI≥75, Asia+ADX<17 exceptions) is
**unreachable code** — shorts never enter the function; longs take the TRENDING/counter-trend exception paths
(CSignalValidator.mqh:517-668).

### 3.3 HTF short veto (item 3)
Logic at CSignalOrchestrator.mqh:670-679; CSV stamp at CMajorStrategyEngine.mqh:104-110 (`dir==SIGNAL_SHORT &&
cand.routed_engine && (H4∨D1 bullish) && price>MA200`). GateScores_2019-2026 (UTF-8 BOM): **HTFShortVetoApplied=YES
count = 0 in every year** (rows/yr: 44/66/92/86/85/86/76/25; SHORT rows present each year, e.g. 34 in 2019, 58 in 2022).
On the production config it is additionally structurally dead: `routed_engine` requires InpEnableMultiStrategy=true.

### 3.4 Quality/scoring (item 4)
The promoter is Factor 1.5 (+3 extreme RSI, CSetupEvaluator.mqh:186-192, thresholds 75/25 wired at mq5:752) plus the
bear-regime +2 (:115-119); tier thresholds A+=8, A=7, B+=6, B=7 (InpPoints*). Measured on fills: **A+ bear pins
n=116 PF 1.008 avgR −0.002 WR 34.5% vs B+ bear pins n=37 PF 2.402 avgR +0.274** (A n=56 PF 1.486). Same shape on
crash shorts: A+ n=87 PF 1.13 vs A n=51 PF 2.00. A+ tier risk = 1.35% vs B+ 0.675% — the scorer concentrates 2× capital
on the measurably worst short bucket. The direction-conditional upgrades (:100-112) are dead (no live token emitter).
The InpScoreBear*/Bull* inputs never influence ranking (#16).

### 3.5 Sizing chain (item 5) — full multiplier stack for a SHORT vs LONG on the config of record
Order of application (immediate path = every short): tier base (GetRiskForQuality × pattern mult 1.05/1.15) →
session mult (mq5:2286-2291; L0.5/NY0.9/Asia1.0) → Wednesday (off) → shock×session-quality reducer (floor 0.25) →
regime `ApplyToRisk` (Trend 1.25 ✓boost) → [orchestrator] ECv3 (≤1.0, direction-blind) → short-mult choke (no-op @1.0) →
cap 2.0% → risk-plugin (loss-scaling, vol-adjust skipped when RegimeRisk on, ApplyShortProtection no-op, health, engine
weight) → counter-trend 200EMA ×0.5 (46.1% of shorts) → exposure cap.
Confirmed path (96% of longs): tier base → stored session mult ≡1.0 → regime mult ∈{1.0,0.75,0.7,0.6} (no boost) →
same orchestrator tail. **Measured net: SHORT mean final 0.817% (0.702× base) vs LONG 1.127% (0.932× base).**
The two big anti-short legs: session-immediate coupling (mean 0.785 vs 0.996) and counter-trend (172 vs 11 halved);
the regime-boost path split (1.186 vs 0.980) is the pro-short offset.

### 3.6 Exits (item 6)
Chandelier short math verified symmetric (LowestLow(7)+mult×ATR, CChandelierTrailing.mqh:197-207; lookback
InpTrailSwingLookback=7, not 15 — 15 is the crash engine's separate InpBOChandelierLookback). The M4-FIX clamp
(CPositionCoordinator.mqh:3061-3104) is symmetric in code; incidence is not: **93 SHORT clamped broker sends across
9 positions — every one a Bearish Pin Bar — vs 10 LONG across 3.** §D's suppressor (:3007-3017) is scoped
`pattern==PATTERN_CRASH_BREAKOUT && direction==SIGNAL_SHORT` only, so the identical at-market-stop geometry the
crash engine was cured of still executes on bear-pin shorts (entered stretched above EMA21 at RSI extremes →
LowestLow+4.2×ATR proposes near/below market → clamped to ASK+stops_level). The 9 affected shorts all closed as
scratch wins (+0.02R…+0.15R, holds 0.0-5.2h). Ladder reach: TP2 SHORT 7.5% vs LONG 23.2%; BE armed S 12 vs L 95.

### 3.7 Entry plugins (item 7) — who can emit SHORT on the config of record
Live short emitters (candidates→winners→fills): **PinBar bear** 285→209→209 fills (all Asia/London), **CrashBreakout**
347→138→138, **PBC short** 55→36→19 fills (18 lost at RR gate, 1 other), **ExpansionEngine short** 22→16→9 fills
(5 "Asian Breakout London" S, 2 "London Continuation NY" S via composed session sub-strategy, IC shorts mostly RR-killed).
Long-only-in-practice: Engulfing (bear input-dead), MACross (bear code-deleted), S6 (short profile-dead).
Registered-but-mute both ways (0 candidates in 7.5y): standalone VolBreakout, Displacement, LiquidityEngine (OBRetest),
S3 RangeEdgeFade, SessionEngine (all 4 modes false; alive only as GMT clock). FileEntry: registered
(InpSignalSource=2=BOTH) but produced no pattern-funnel rows; telegram_signals.csv path — no fills attributed in archive.
Net: the short book = 56% bear pins + 37% crash + 7% engines; the long book has 3 additional high-volume sources.

### 3.8 RR/TP gates (item 8)
The RR≥1.3 gate itself is direction-blind, but its reward measurement is not (#19): `MathMax(tp1,tp2)` selects the
FAR target for longs and the NEAR target for shorts. Counted kills: 26 SHORT vs 1 LONG. 18 of the 26 are PBC shorts
whose plugin-set TP1 is exactly 1.3R (bid/ask drift + rounding puts measured RR at 1.30−ε); their auto-filled 1.8R TP2
would pass, and does pass for identical-geometry PBC longs (0 long PBC kills). The same near-TP idiom sits in the
confirmed-path min-RR boost (:1016-1026) — latent only, since shorts never take that path. FIX-1 (InpMinSLRangePct)
is 0.0 → its stale-short-TP hazard is dormant. Adaptive-TP/BB/structure derivations are symmetric (§3.6, #37).

### 3.9 News/session/day filters (item 9)
News gate: off (InpNewsFilterEnable=false), and direction-blind when on. Day router (CDayTypeRouter): no direction
tokens. Session allow-list (Asia/London/NY all true) and skip-hours (11-11 = inert): direction-blind, but both are
**bypassed entirely during bear regime** (CSignalOrchestrator.mqh:490) — pro-short. The de-facto direction-conditional
session filters are #4 (bear-pin NY block) and #30 (bull-MACross NY block), plus #21's session-sizing coupling.

---

## 4. FACTS vs INTERPRETATION

### FACTS (counted from artifacts / verified at file:line)
1. Funnel: L 2,562→1,251→1,216→555 fills; S 709→412→399→373 fills; 0 short validator rejects vs 532 long; 0 short pendings; 26 S vs 1 L RR kills. Fills match the 928-position archive exactly.
2. All four claimed short-bypass protections: two dead (0.5× mult at 1.0; SMC never enabled), two direction-blind.
3. HTF short veto: 0 recorded firings 2019-2026; needs InpEnableMultiStrategy=true to even execute.
4. Sizing: mean final/base SHORT 0.702 vs LONG 0.932; session mult 0.785 vs 0.996 (532/532 confirmed longs at 1.000); counter-trend halving 172/373 vs 11/555; regime mult 1.186 vs 0.980.
5. Quality: A+ bear pins PF 1.008 (n=116, 31% of the short book, sized 1.35%) vs B+ 2.402 (n=37, 0.675%).
6. Clamp: 93 short clamp-sends / 9 positions, 100% bear pins, all scratch exits ≤0.15R; long side 10/3. §D scope excludes them by pattern filter.
7. Direction economics: S PF 1.227 / capture 17.1% / median 4.9h vs L 1.394 / 23.2% / 11.9h; TP2 reach 7.5% vs 23.2%.
8. Arbitration: 13 both-side bars, LONG 13-0.
9. Bear sides amputated on 3 of the 4 highest-volume candidate sources (Engulfing 1,330L, MACross 267L, S6 105L: zero short twins live).
10. The session-scaling asymmetry is documented as intentional in-source (mq5:1996-1998).

### INTERPRETATION
- **Protective (measured evidence supports keeping some form):** counter-trend 0.5× (short WR is worse; but it halves the GOOD shorts too — untargeted); bear-pin NY block (was measured −1.9R in NY historically per comment); crash-engine internal rr≥1.0 floor; §D suppressor (crash clamp events now 0).
- **Arbitrary/historical (no current measured justification on this config):** Engulfing-bear and S6-short blanket disables (regime-conditional bear markets 2021-22 show shorts outperforming longs — S PF 1.25/1.26 vs L 0.85/1.28); session-haircut-by-execution-path (an accident of WHERE the multiplier lives, then locked in by an A/B on longs, not on shorts); InpScoreBear* inputs and the whole validator short-protection family (dead); HTF veto (dead scaffolding).
- **Damage amplifiers (anti-short in effect, actionable):** (a) +3 extreme-RSI promotion → 2× capital on PF≈1.0 A+ bear pins — the single largest measured short-side capital misallocation; (b) MathMax near-TP RR measurement — a genuine direction bug killing ~6.5% of short winners, concentrated on PBC (18/55 short candidates die at the last gate); (c) clamp geometry on non-crash shorts — 9 forfeited runners (counterfactual PnL unknowable without replay); (d) short trades systematically sized 27% lighter while the short book's positive years (2021-23: +$4,037 combined) were its heaviest-candidate years.
- The 2.4× better candidate→fill conversion for shorts is NOT evidence of short health — it means the short book's quality control happens nowhere (no validator, no confirmation) while its quantity is throttled upstream (source amputation) and downstream (sizing), i.e. the EA takes FEWER, WORSE-vetted, SMALLER shorts.

### Instrumentation gaps (cannot be counted from existing artifacts)
- shock_factor / sq_factor per-trade magnitudes (journal Print only — no CSV column); needed to price #22.
- Immediate-path long-extension blocks and bear-regime session-bypass utilization (no CSV rows).
- Bear-regime +2 firing count per signal (WriteShortDiag doesn't log points breakdown).
- Counterfactual PnL of the 9 clamped bear-pin shorts and the 26 RR-killed shorts (needs shadow replay).
- ShortDiagnostic.log covers 2019-2022 only; per-year bypass telemetry for 2023+ requires re-run with the same flag.
