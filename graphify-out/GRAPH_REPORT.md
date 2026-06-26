# Graph Report - .  (2026-05-16)

## Corpus Check
- 88 files · ~183,849 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 555 nodes · 648 edges · 63 communities detected
- Extraction: 79% EXTRACTED · 21% INFERRED · 0% AMBIGUOUS · INFERRED: 139 edges (avg confidence: 0.57)
- Token cost: 0 input · 0 output

## God Nodes (most connected - your core abstractions)
1. `main()` - 27 edges
2. `main()` - 20 edges
3. `Codex Trade Audit README` - 19 edges
4. `Docs Overview` - 18 edges
5. `clean_text()` - 12 edges
6. `Exit Lever Implementation Plan` - 12 edges
7. `main()` - 10 edges
8. `parse_report_summary()` - 8 edges
9. `AB Test Log Document` - 8 edges
10. `CMarketContext (7 sub-analyzers)` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Strategy Reference Catalog` --semantically_similar_to--> `UltimateTrader Complete Reference`  [INFERRED] [semantically similar]
  STRATEGY_REFERENCE.md → ULTIMATETRADER_COMPLETE_REFERENCE.md
- `Structural Invalidation (vs MAE/MFE)` --semantically_similar_to--> `Bug: Early Invalidation Destroys -26.90R`  [INFERRED] [semantically similar]
  GM_ANALYSIS.txt → CD_ANALYSIS.txt
- `EA Architecture Guide` --semantically_similar_to--> `UltimateTrader Complete Reference`  [INFERRED] [semantically similar]
  EA_ARCHITECTURE_GUIDE.md → ULTIMATETRADER_COMPLETE_REFERENCE.md
- `Shadow Trail Concept (close on candle close)` --semantically_similar_to--> `CChandelierTrailing (default 3.0x ATR)`  [INFERRED] [semantically similar]
  KESTREL_UNIFIED_PLAN.txt → EA_ARCHITECTURE_GUIDE.md
- `Strategy Audit (Superseded)` --semantically_similar_to--> `Strategy Reference Catalog`  [INFERRED] [semantically similar]
  StrategyAudit.md → STRATEGY_REFERENCE.md

## Hyperedges (group relationships)
- **Three-Analyst Synthesis Sources** — cd_analysis_doc, gp_analysis_doc, gm_analysis_doc [EXTRACTED 1.00]
- **Three Critical Exit/Trailing Bugs** — bug_all_6_trailing_run, bug_early_invalidation_destroyer, bug_tp1_tp2_not_implemented [EXTRACTED 1.00]
- **Barbell Dual-Path Trio** — confirmed_path, immediate_path, barbell_capital_allocation [EXTRACTED 1.00]
- **Bearish Engulfing disable consensus** — bya_bearish_engulfing_loser, sa_bearish_engulfing_loser, mf_three_problems [EXTRACTED 1.00]
- **Momentum filter evolution** — mfd_filter_a_05pct, dgc_prior_24h_long_filter, v9_72h_filter_too_aggressive [EXTRACTED 0.90]
- **Exit management triad** — tp0_mechanism, runner_mechanism, chandelier_trail [EXTRACTED 1.00]
- **Exit-Lever Runner Trailing Cluster** — codex_exit_lever_plan, runner_phase2_broker_cadence, runner_phase3_trailing_runner_aware, broker_sl_too_aggressive, chandelier_no_quality_awareness, exit_label_trailing_too_tight [EXTRACTED 0.95]
- **Entry Filter A/B Cycle (Audit-Runtime Lossy)** — codex_extension_filter_rerun, codex_countertrend_block_rerun, codex_prior24_final_rerun, codex_prior24_diagnosis, audit_runtime_lossy_problem [INFERRED 0.90]
- **Runner Management Evolution Cycle** — codex_runner_rerun, codex_runner_narrowing_rerun, codex_chandelier_floor_rerun, runner_exit_mode_concept, engine_confluence_zero_bug, broad_runner_overshoot [EXTRACTED 0.95]

## Communities

### Community 0 - "Architecture Bug Catalog"
Cohesion: 0.06
Nodes (49): Alpha Source: 25 Trailing Exits = +42.68R, Backtest 168 Trades Mar2025-Mar2026, Bug: All 6 Trailing Plugins Run Simultaneously, Bug: Double Volatility Risk Adjustment, Bug: Early Invalidation Destroys -26.90R, Bug: First-Signal-Wins Priority, Bug: Hybrid Trailing Capped at Entry-10pts, Bug: London Session Net Loser (+41 more)

### Community 1 - "Codex Filter A/B Reruns"
Cohesion: 0.05
Nodes (42): Audit-to-Runtime Translation Lossy Problem, GMT Hardcoding / DST Bug, All 6 Trailing Plugins Run Simultaneously Bug, Bullish Pin Bar Promoted Subset (Strong), Bullish Pin Bar Standard-Managed (Weak), Countertrend Short Block Rerun Review, 72h Extension Filter Rerun Review, Prior-24h Filter Rerun Diagnosis (+34 more)

### Community 2 - "Trade Audit Pipeline"
Cohesion: 0.15
Nodes (31): annual_market_stats(), build_case_line(), choose_candidate_row(), choose_risk_row(), classify_report_exit_comment(), classify_trade(), clean_text(), evaluate_directional_move() (+23 more)

### Community 3 - "Runner Exit Lever Plan"
Cohesion: 0.08
Nodes (27): Broad Runner Management Overshoot, Broker SL Updates Too Aggressive, InpRunnerUseEntryLockedChandFloor=true, Chandelier 3.0x ATR H1, Chandelier Lacks Quality/Stage Awareness, Entry-Locked Chandelier Floor Rerun Review, Exit Lever Implementation Plan, Runner Narrowing Rerun Review (+19 more)

### Community 4 - "Expansion & SMC Engines"
Cohesion: 0.07
Nodes (27): Bug: FVG Mode Uses SMC Confluence Proxy, Bug: OB Retest SL Ignores OB Boundary, Bug: Squeeze Counter Counts Per Tick Not Bar, EA 10-Layer Plugin Architecture, Expansion Mode: Compression Breakout, Expansion Mode: Institutional Candle BO, Expansion Mode: Panic Momentum, CExpansionEngine (+19 more)

### Community 5 - "Gold Trade Report Builder"
Cohesion: 0.19
Nodes (23): annual_market_stats(), Bar, build_markdown(), classify_exit_reason(), clean_text(), evaluate_entry_window(), evaluate_exit_window(), find_row() (+15 more)

### Community 6 - "Bearish Year Analysis"
Cohesion: 0.09
Nodes (25): Bearish Engulfing -33.35R bad years, Structural long bias bleeds in flat years, v1 baseline: -27.78R in 2020-2023, BE removal would flip bad years -15.82R to +16.08R, v2: Bearish Engulfing disable failed, v3 confirmed: BE, SB, S6 Short removed, 251 trades wasted MFE>0.5R (-116.89R), Chandelier ATR trailing stop (+17 more)

### Community 7 - "Risk Model & Tiers (v18)"
Cohesion: 0.09
Nodes (25): Core Truths (~30 Experiments), Counter-Trend MA200 0.5x, Daily Loss Halt 3%, Docs Overview, Docs Risk Model, EC v3 Equity Curve Risk Controller, Exit System Locked (6 Failures), Fallback Tick-Value Lot Sizing (+17 more)

### Community 8 - "Analyst Strategy Evaluations"
Cohesion: 0.11
Nodes (19): Bearish Pin Bar Asia-only filter (+11.7R), Exit-loosening rejected (5 failed A/B tests), Bullish MA Cross block NY (+3.6R), Bullish Pin Bar TRENDING only (+2.8R), Rubber Band Short A/A+ only (+4R), Analyst Eval: Entry adopt, Exit reject, ASIA session, Bearish Pin Bar (+11 more)

### Community 9 - "Barbell Architecture Reference"
Cohesion: 0.11
Nodes (18): Barbell Capital Allocation Architecture, UltimateTrader Complete Reference, Confirmed Path (Growth Engine, full risk), Designed vs Reality Table (dead systems), EA Architecture Guide, Immediate Path (Stabilizer, reduced risk), Lesson: Runner Losses are Insurance Premium for Tail Captures, Pillar: Breakout/Expansion (+10 more)

### Community 10 - "Momentum Filter Sweep (A-F)"
Cohesion: 0.12
Nodes (16): evaluate_filter(), filter_A(), filter_B(), filter_C(), filter_D(), filter_E(), filter_F(), find_nearest_idx() (+8 more)

### Community 11 - "Deep Gold Context Analysis"
Cohesion: 0.13
Nodes (6): find_d1_idx_before(), find_h4_idx_before(), is_toxic_prior_move(), Find the index of the last daily bar with datetime <= dt., Find the index of the last H4 bar with datetime <= dt., Returns True if trade should be blocked by prior-move filter.

### Community 12 - "Gold Regime & ATR Filters"
Cohesion: 0.13
Nodes (15): Top Sharpe strategies under-capitalized, 2025 PF 2.22 vs 2024 1.52, ATR Q3 dead zone (-0.01 avg R), ATR Q5 best regime (+0.30 avg R), Combined filters remove 161 toxic, +36.6R, Prior 24h<0% blocks LONG -16.2R bleed, DIP: Prior 24h + sizing uplift + ATR gate, Filter bull-safe: 0 blocks in 2024-25 (+7 more)

### Community 13 - "Major Profitability Analyzer"
Cohesion: 0.35
Nodes (13): as_float(), bad_entry_pct(), bad_exit_pct(), bad_trade_pct(), format_num(), load_rows(), main(), mean() (+5 more)

### Community 14 - "Codex Analyst Plan Eval"
Cohesion: 0.14
Nodes (14): Analyst ATR Q3 Dead-Zone Claim (Stale), Analyst Coverage Gap Observation, Analyst Prior-24h Momentum Filter Claim, Analyst Strategy Sizing Uplift Claim, Analyst Plan Evaluation (2026-04-05), Major Profitability Analysis, Profitability Improvement Plan, Combined Pack B (+2859.87) (+6 more)

### Community 15 - "Strategy Analysis Script"
Cohesion: 0.15
Nodes (2): normalize_pattern(), Group S6 and Pullback Continuation variants into families.

### Community 16 - "v3 Strategy Verdicts"
Cohesion: 0.15
Nodes (13): Bearish Engulfing strategy, v3: 1183 trades, +90.47R, +$8412, Top 5 actions: disable BE/S6Short/SB, v3 transform: $7102 to $8412, 52.9R to 90.5R, v3: zero major net-losing strategies, SETUP_B_PLUS quality tier, S6 Failed Break Short, Bearish Engulfing -$900/-25.9R (682 trades) (+5 more)

### Community 17 - "A/B Test Log"
Cohesion: 0.18
Nodes (11): Test 23: Phased BE + Reward-Room FAILED, Test 24c: Reward-Room Filter FAILED, Test 25: Structure-Based Invalidation NO EFFECT, Test 26: CI(10) Regime Scoring MARGINAL PASS, Test 27: Regime Thrashing Cooldown NO EFFECT, Test 28: S3/S6 Range Structure Framework PASS, Test 29: Breakout Probation NO EFFECT, Baseline Locked 2026-03-28 (+3 more)

### Community 18 - "Findings Lessons & Dead Inputs"
Cohesion: 0.18
Nodes (11): Bug: Confirmed Signals Missed Session/Regime Multipliers, 15 Dead/Ineffective Inputs Identified, EA Findings Report (Analyst Regression), Key Lessons from Findings, Lesson: Dynamic Trailing Beats Entry-Locked Exits, Lesson: Fallback Sizing Outperformed by 10x, Lesson: Test One Change At A Time, Profit Collapse $6,140 to $561 Root Cause (+3 more)

### Community 19 - "Position Management Docs"
Cohesion: 0.2
Nodes (11): Anti-Stall (S3/S6 5/8 M15 Bars), Bearish Engulfing DISABLED, Docs Position Management, Docs Strategies, ManageOpenPositions Processing Order, Regime Exit Profiles (Locked At Entry), S3 Range Edge Fade, S6 Failed Break Reversal (+3 more)

### Community 20 - "Post-SL Re-entry Analysis"
Cohesion: 0.29
Nodes (9): analyze(), build_bar_index(), find_bar_at_or_after(), load_gold_h1(), load_stopped_trades(), Find the index of the first bar at or after target_dt., Returns list of dicts sorted by datetime, keyed by datetime for lookup., Build a dict mapping datetime -> index for O(1) lookup. (+1 more)

### Community 21 - "Analyze v3 Script"
Cohesion: 0.25
Nodes (2): loss_streaks(), Return list of consecutive loss streak lengths.

### Community 22 - "Profitability Levers Script"
Cohesion: 0.39
Nodes (5): fmt_num(), load_rows(), main(), mean(), write_csv()

### Community 23 - "Layered Architecture Docs"
Cohesion: 0.29
Nodes (7): Docs Architecture, Strict Dependency Layer Model, IMarketContext 7 Components, OnTick Signal-to-Execution Flow, Plugin System (Layer 3), Binary State Persistence (ULTR + CRC32), Symbol Profile System (XAU/JPY/AUTO)

### Community 24 - "CSV File Signals"
Cohesion: 0.29
Nodes (7): CSV Dedup Key Set (m_executedKeys), CSV Format (DateTime/Symbol/Action/Risk/E/SL/TP), Docs CSV File Signals, Docs Input Parameters Reference, GetEETOffset DST Logic, FILE_MODE_STRICT, InpSignalSource=BOTH

### Community 25 - "Observability Ledgers"
Cohesion: 0.33
Nodes (6): Candidate Signal Ledger, Feedback State Ledger, Observability Workstream, Risk Decision Ledger, System Revision Plan, Trade Lifecycle Ledger

### Community 26 - "Hardcode Param Fixes"
Cohesion: 0.33
Nodes (6): All defaults aligned to hardcoded values, Crash Detector: 9 params wired, Pattern Scores: 9 params wired, Short Protection: 4 params wired, SMC Order Blocks: 8 params wired, Volatility Breakout: 8 params wired

### Community 27 - "Performance Stats"
Cohesion: 0.4
Nodes (5): Analyst Regression Recovery (3 stages), EA Strategy Analysis (Final Production), Optimization Journey 22 A/B Tests, Performance: $10,864 / PF 1.58 / DD 3.38% / Sharpe 4.91, PerformanceStats Document

### Community 28 - "Momentum Deep Dive"
Cohesion: 0.5
Nodes (0): 

### Community 29 - "Session Range Fade"
Cohesion: 0.5
Nodes (2): Simulate a trade forward using next 8 H1 bars., simulate_trade()

### Community 30 - "Cluster 30"
Cohesion: 0.5
Nodes (0): 

### Community 31 - "Cluster 31"
Cohesion: 0.5
Nodes (4): 8-Gate Validation Pipeline, CSetupEvaluator (0-10 quality scoring), CSignalOrchestrator (8-gate pipeline), CSignalValidator (TF/MR validation)

### Community 32 - "Cluster 32"
Cohesion: 0.5
Nodes (4): CAdaptiveTPManager, CEnhancedTradeExecutor, Fallback Sizing Formula, CTradeOrchestrator

### Community 33 - "Cluster 33"
Cohesion: 0.5
Nodes (4): Zero trades reaching +2R reversed to loss, TP0 closed: 76.3% WR vs 6.6% not closed, v3 TP0 yes/no delta +785R, TP0 partial close mechanism

### Community 34 - "Cluster 34"
Cohesion: 0.67
Nodes (3): Deep cluster baseline: 858 trades, +107.47R, Holding sweet spot 24-48h (+0.638 avg R), After WIN: 52.3% WR; After LOSS: 37.7%

### Community 35 - "Cluster 35"
Cohesion: 0.67
Nodes (3): Big move coverage gap: 48.6% missed entirely, 64% of big moves missed, Friday block validated (89 missed big moves)

### Community 36 - "Cluster 36"
Cohesion: 0.67
Nodes (3): FVG fails: PF 0.57, every year negative, Recommendation: permanent kill FVG entries, FVGs on gold H1 = momentum, not imbalance

### Community 37 - "Cluster 37"
Cohesion: 0.67
Nodes (3): Post-SL re-entry concept, Marginal: 49% WR, +0.016 avg R, 67% dbl-stop, 42.8% reclaim rate; 65% on bar 1

### Community 38 - "Cluster 38"
Cohesion: 0.67
Nodes (3): 78.6% overlap with S3, no additive value, REJECT: -121.21R, 34.9% WR, 1/7 positive years, Only 20.8% reach opposite boundary

### Community 39 - "Cluster 39"
Cohesion: 1.0
Nodes (2): CQualityTierRiskStrategy (uninitialized), Rationale: Fallback Sizing Beats 8-Step Chain 10x

### Community 40 - "Cluster 40"
Cohesion: 1.0
Nodes (2): 93% TRENDING classification even in ranging, TRENDING regime classification

### Community 41 - "Cluster 41"
Cohesion: 1.0
Nodes (2): Anti-stall +0.121 avg R (23 trades), Weekend closures +0.803 avg R (18 trades)

### Community 42 - "Cluster 42"
Cohesion: 1.0
Nodes (2): MAE>=1R survival 0.3% (death sentence), Winners median MAE 0.28R; losers 0.89R

### Community 43 - "Cluster 43"
Cohesion: 1.0
Nodes (2): London worst session bad years (-26.67R), LONDON session

### Community 44 - "Cluster 44"
Cohesion: 1.0
Nodes (2): 100 Files Corpus, 558 nodes, Graphify Out Report Summary

### Community 45 - "Cluster 45"
Cohesion: 1.0
Nodes (1): Compile and Run Guide

### Community 46 - "Cluster 46"
Cohesion: 1.0
Nodes (1): Compile Log (0 errors 38 warnings)

### Community 47 - "Cluster 47"
Cohesion: 1.0
Nodes (1): CMarketFilters (confidence scoring)

### Community 48 - "Cluster 48"
Cohesion: 1.0
Nodes (1): CRiskMonitor

### Community 49 - "Cluster 49"
Cohesion: 1.0
Nodes (1): CRegimeRiskScaler

### Community 50 - "Cluster 50"
Cohesion: 1.0
Nodes (1): CDayTypeRouter

### Community 51 - "Cluster 51"
Cohesion: 1.0
Nodes (1): Lesson: 76% SL Rate is a Feature

### Community 52 - "Cluster 52"
Cohesion: 1.0
Nodes (1): Strategy: Bullish MA Cross (PF 2.15)

### Community 53 - "Cluster 53"
Cohesion: 1.0
Nodes (1): Strategy: Bearish Engulfing

### Community 54 - "Cluster 54"
Cohesion: 1.0
Nodes (1): Strategy: Bullish Engulfing

### Community 55 - "Cluster 55"
Cohesion: 1.0
Nodes (1): Strategy: PBC Long

### Community 56 - "Cluster 56"
Cohesion: 1.0
Nodes (1): Scenario Backtest Matrix (Y1-Y3, R1-R7)

### Community 57 - "Cluster 57"
Cohesion: 1.0
Nodes (1): v2: Silver Bullet successfully removed

### Community 58 - "Cluster 58"
Cohesion: 1.0
Nodes (1): Clustered trades outperform isolated

### Community 59 - "Cluster 59"
Cohesion: 1.0
Nodes (1): Toxic hour+direction combos

### Community 60 - "Cluster 60"
Cohesion: 1.0
Nodes (1): InpEnableLossScaling gate added

### Community 61 - "Cluster 61"
Cohesion: 1.0
Nodes (1): InpRSIPeriod wired (2 files)

### Community 62 - "Cluster 62"
Cohesion: 1.0
Nodes (1): v1 strategy summary (14 strategies)

## Knowledge Gaps
- **243 isolated node(s):** `Return list of consecutive loss streak lengths.`, `Find the index of the last H4 bar with datetime <= dt.`, `Find the index of the last daily bar with datetime <= dt.`, `Returns True if trade should be blocked by prior-move filter.`, `Find index of nearest bar <= target time.` (+238 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Cluster 39`** (2 nodes): `CQualityTierRiskStrategy (uninitialized)`, `Rationale: Fallback Sizing Beats 8-Step Chain 10x`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 40`** (2 nodes): `93% TRENDING classification even in ranging`, `TRENDING regime classification`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 41`** (2 nodes): `Anti-stall +0.121 avg R (23 trades)`, `Weekend closures +0.803 avg R (18 trades)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 42`** (2 nodes): `MAE>=1R survival 0.3% (death sentence)`, `Winners median MAE 0.28R; losers 0.89R`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 43`** (2 nodes): `London worst session bad years (-26.67R)`, `LONDON session`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 44`** (2 nodes): `100 Files Corpus, 558 nodes`, `Graphify Out Report Summary`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 45`** (1 nodes): `Compile and Run Guide`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 46`** (1 nodes): `Compile Log (0 errors 38 warnings)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 47`** (1 nodes): `CMarketFilters (confidence scoring)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 48`** (1 nodes): `CRiskMonitor`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 49`** (1 nodes): `CRegimeRiskScaler`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 50`** (1 nodes): `CDayTypeRouter`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 51`** (1 nodes): `Lesson: 76% SL Rate is a Feature`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 52`** (1 nodes): `Strategy: Bullish MA Cross (PF 2.15)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 53`** (1 nodes): `Strategy: Bearish Engulfing`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 54`** (1 nodes): `Strategy: Bullish Engulfing`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 55`** (1 nodes): `Strategy: PBC Long`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 56`** (1 nodes): `Scenario Backtest Matrix (Y1-Y3, R1-R7)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 57`** (1 nodes): `v2: Silver Bullet successfully removed`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 58`** (1 nodes): `Clustered trades outperform isolated`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 59`** (1 nodes): `Toxic hour+direction combos`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 60`** (1 nodes): `InpEnableLossScaling gate added`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 61`** (1 nodes): `InpRSIPeriod wired (2 files)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Cluster 62`** (1 nodes): `v1 strategy summary (14 strategies)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Exit Lever Implementation Plan` connect `Runner Exit Lever Plan` to `Codex Analyst Plan Eval`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **Why does `Docs Overview` connect `Risk Model & Tiers (v18)` to `Runner Exit Lever Plan`, `Position Management Docs`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Why does `Major Profitability Analysis` connect `Codex Analyst Plan Eval` to `Codex Filter A/B Reruns`, `Runner Exit Lever Plan`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Are the 26 inferred relationships involving `main()` (e.g. with `parse_report_summary()` and `parse_dt_seconds()`) actually correct?**
  _`main()` has 26 INFERRED edges - model-reasoned connections that need verification._
- **Are the 19 inferred relationships involving `main()` (e.g. with `load_price_bars()` and `read_html_rows()`) actually correct?**
  _`main()` has 19 INFERRED edges - model-reasoned connections that need verification._
- **Are the 11 inferred relationships involving `clean_text()` (e.g. with `parse_float()` and `parse_int()`) actually correct?**
  _`clean_text()` has 11 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Return list of consecutive loss streak lengths.`, `Find the index of the last H4 bar with datetime <= dt.`, `Find the index of the last daily bar with datetime <= dt.` to the rest of the system?**
  _243 weakly-connected nodes found - possible documentation gaps or missing edges._