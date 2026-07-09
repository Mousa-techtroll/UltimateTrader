# UltimateTrader — Clean-Room Evaluation: Consolidated Register (Phase 2 merge)

**Status:** Phase-1 fan-out complete (19 units: 12 Wave-1 + 7 Wave-2). Phase-2 reconciliation in progress.
**Method:** source-only, static edge grading, no new backtests; `all_trades_v15.csv` = Model-1 directional cross-reference only.
**Severities marked `[P2]` are pending the two Phase-2 adversarial/compile agents** (impl: `adc942…`, edge: `ad42da…`).

---

## A. Headline thesis (one paragraph)

On the production config, UltimateTrader presents as an ~11-strategy, multi-layer SMC/risk system but **operates as something much smaller**: a single correlated long-gold trend-continuation bet (Engulfing / PinBar / MACross + the long-biased engines) plus **one genuinely diversifying conditional short** (the D1-death-cross Rubber-Band fade), sized by an **inline fallback** sizer, gated mainly by regime + a point-threshold quality tier + the fact that the registered plugin set is long-only. A large fraction of the advertised sophistication is **inert on prod**: the SMC confluence floor (no-op), the RSI/momentum gate (disabled → hardcoded 50), the adaptive risk-scaling steps (risk plugin never initialized), the HTF short-veto (dead path), breakout-probation (dead), the SETUP_B tier (unreachable), and — the most consequential — **the entire exit-plugin layer** (all four never initialized → permanent no-op, including the only structure-aware exit). No CRITICAL (wrong-direction / capital-loss / crash / silent-corruption) defects were found; the register is HIGH-and-below, dominated by **dead/inert advertised features** and a few **live units defects** in the risk-multiplier math.

---

## B. Edge-ranked strategy table (static / structural; CSV = Model-1 directional only)

| Strategy (prod) | Mode | Edge class | /10 | Look-ahead | Credited? | One-line |
|---|---|---|---|---|---|---|
| **CrashBreakout** (Rubber-Band, short-only) | death-cross fade | **Real structural edge** | **9** | clean (2) | **YES** | D1 death-cross arms it only in confirmed gold downtrends, then fades to EMA21 — correct way to short a bull asset; **episodic** (≈one 2021–22 episode, dormant for years). |
| **OB-Retest** (Liquidity engine) | OB-Retest | **Real structural edge — dormant** | 7 | clean (2) | No (inert) | Genuine SMC: closed-bar OB zone ∧ same-dir BOS/CHoCH ∧ rejection; but **0 trades** in artifact — structurally valid, operationally inert. |
| **FailedBreakReversal** (S6) | — | No-edge-on-gold | 7 | clean | No | Most ICT-faithful (sweep→rejection→reclaim), but a **measured loser** (−1.65R / 74 trades); short-disable justified. |
| **Engulfing** (bull, long-only) | — | Naive / indicator | 6 | clean (2) | No | Faithful 2-candle engulf + ATR floor + binding TRENDING gate; zero liquidity/location context — rides gold drift. |
| **Institutional-Candle BO** (Expansion engine) | IC-BO | Naive / indicator | 6 | clean (2) | No | Real expansion→consolidation→break state-machine (not donchian-in-disguise, not SMC); n=4. |
| **PinBar** (bull, long-only) | — | Naive / indicator | 5 | clean (2) | No | Correct rejection geometry but its only location filter (proximity) is **disabled on prod**; weakest long. |
| **MACross** (bull, long-only) | — | Naive / indicator (lagging) | 5 | clean (2) | No | 10/20 **SMA** (mislabeled "EMA") rescued by strictest regime gate; NY block fit to n=60. |
| **RangeEdgeFade** (S3) | — | Curve-fit / fragile | 5 | clean | No | Donchian box + sweep + reclaim, but Fix-4 relaxed edge∧RSI→edge∨RSI; **0 fires**. |
| **Displacement** (Liquidity engine) | Displacement | **Look-ahead-dependent (quarantined)** | 4 | **0 (caps edge)** | No | `liq_score>=2` hard gate reads forming **W1[0]**; score reads forming **D1[0]**. `[P2]` severity. |
| **PullbackContinuation** (PBC) | — | Naive / curve-fit | 4 | clean (2) | No | "2-of-4" exhaustion is really ~2-of-3 + redundant with reclaim; body thresh tuned 0.20 vs ctor 0.35; **0 fires**. |
| **CDisplacementEntry** (discrete plugin) | — | Curve-fit / fragile | 4 | clean | No | Wired `m_context=NULL` → H4-trend/regime gates are **dead code** → direction-agnostic; naive 12-bar Donchian "swing"; **0 fires**. |
| **Session engine** | state-clock | — (emits 0 signals) | — | — | n/a | Live GMT clock used by NY-blocks; never produces a trade signal. |

**Edge tally:** only the **Rubber-Band conditional short** clears the rubric's positive-edge gate (and is episodic). **OB-Retest** is the only other genuinely-structural mode but is dormant (0 trades). Everything else is naive / curve-fit / quarantined / inert. The long book is effectively **one correlated bet behind many triggers**.

---

## C. Implementation findings register (deduped; by severity)

### CRITICAL
*(none found across all 19 units)*

### HIGH

| ID | Title | Location | Status |
|---|---|---|---|
| **RXT-02** | All 4 exit plugins never `Initialize()`d → `CheckExitPlugins` permanent **no-op** (regime-aware structural exit, 72h max-age, daily-loss *position-close*, weekend-close all dead). Backstops: per-position SL, coordinator-native weekend closer (~1712-1723), `CanTrade()` blocks new entries on daily-loss. | `Include/ExitPlugins/*` + `CPositionCoordinator.mqh:3084` | `[P2]` confirming |
| **CTX-10** | `GetATRCurrent()`=**H4** ATR vs `GetATRAverage()`=**H1** ATR → mismatched pair into EC-v3 vol controller → systematically inflates vol ratio in **live** risk-multiplier stack. | `CTradeOrchestrator.mqh:398`, `CRegimeRiskScaler:181`, `CDayTypeRouter:53` | `[P2]` confirming |
| **FILT-04** | RSI sole-sourced from disabled momentum filter → `GetCurrentRSI()` returns hardcoded **50** → kills all RSI-extreme validator exceptions + `CSetupEvaluator` "+3 quality pts" → systematic tier/risk% **deflation**. | `CMomentumFilter` / `CSetupEvaluator` / `CSignalValidator` | Confirmed |
| **ENG-02 / ENG-01 / WT3-01** | Displacement-mode forming **W1[0]** hard gate (`ScoreLiquidityLevel`) + forming **D1[0]** score (`GetLocationPenalty`). Repaint-instability feeding a live gate. **Contested by X1** (running extreme = known-now, not future). | `CLiquidityEngine` (ScoreLiquidityLevel / GetLocationPenalty) | `[P2]` adjudicating (5th contradiction) |
| **EXE-01** | Netting partial-fill ticket bind desync (live send path). | `CEnhancedTradeExecutor.mqh` | Likely |
| **ORC-09** | Daily-loss-halt setter possibly not invoked inside `CanTrade()` — interacts with RXT-02. | `CTradeOrchestrator` / `CRiskMonitor` | `[P2]` tracing |
| **PORT-01 / PORT-02** | Portfolio: "11 strategies" overstates breadth ~2× (one long cluster + one short book); methodology weak (98% zero-slippage fills, in-sample mode curation baked into defaults, direction-asymmetric confirmation). | cross-cutting | Confirmed |

**Reconciled DOWN from HIGH:**
| ID | Was | Now | Reason |
|---|---|---|---|
| **RISK-01** (WT-5) | HIGH | **MEDIUM** | RXT-01 (U8): risk plugin is wired+called; falls to inline fallback; **lot math mathematically identical**; only the adaptive-scaling *surface* (loss/vol/short/health/engine-weight) is inert — and wiring it would double-count vol/short. Lot SIZE correct → not a sizing bug. |
| **CTX-02** (U4) | HIGH | **LOW (on prod)** | Momentum filter disabled on prod (FILT-04) + new-bar-gated (X1 LA-04). Forming-bar [0] look-ahead is **latent** → LOW-on-prod / HIGH-only-if-`InpEnableMomentum`-flipped. |
| **ORC-04** (U3) | HIGH | **LOW (dead path)** | HTF-short-veto gated on `routed_engine` → never fires on prod (long-only, multi-strategy off). |
| **ORC-01** (U3) | HIGH | **LOW (dead path)** | Breakout-probation double-mult on a dead path. |

### MEDIUM (selected — full list in unit files)
- **POS-12** (U1) — recovery-path R-denominator rebuild can stack-fire partial ladder; v4→v5 bump forces it.
- **POS-02** (U1) — Chandelier floor degrades on restart.
- **ORC-02** (U3) — exposure-cap denominator drift (balance-frozen $ risk over equity denominator; also NUM-02/X4).
- **EXE-08** (U2) — session-quality reads forming H1[0] → can trip bar-open gate.
- **DET-01** (X2) — `spread_samples[]` never trimmed → entire-history spread median leaks forward into live entry-block / risk-halve gate.
- **DET-02** (X2) — PBC cooldown gated on a function-`static last_bar` not an instance member (latent across optimization passes).
- **NUM-03** (X4) — live send path never checks STOPS_LEVEL / freeze / normalize on SL/TP.
- **NUM-08** (X4) — pattern-signal TP cascade closes via `NormalizeDouble(lots,2)` not `SYMBOL_VOLUME_STEP` (file ladder uses `NormalizeLots`).
- **LA-05** (X1) — forming-bar BB[0] feeds Chop-Sniper TP calc and can **abort the trade** ("BB too tight for valid R:R"); read [1].
- **RXT-18** (U8) — `CAdaptiveTPManager` reads forming-bar ATR/ADX[0] to size TP distance (folds into X1 census; site X1 didn't list).
- **RXT-14 / RISK-02** (U8/WT-5) — **SETUP_B tier unreachable** (`InpPointsBSetup=7` behind A≥7 → B+ is effective floor). Resolves contradiction-(b).
- **RISK-03** (WT-5) — the 2.0% hard cap **never binds** (max realized 1.21%) — contradicts the in-code comment.
- **PAT-07** (U6) — Displacement-plugin local-swing fallback seeds the swept level from `[2]`, diluting the structural-sweep edge (no look-ahead).
- **CTX-03 / CTX-04** (U4) — forming-bar ATR drives vol regime + risk/SL mult + sizing; macro DXY/VIX degrades to self-referential gold proxy in tester (= FILT-09).
- **SMC-04 / SMC-05** (U5) — the SMC<40 hard-reject is DEAD (`m_smc_enabled` false); the L3 SMC spine ≥25 is a rubber stamp (base 50, add-only). (= FILT-01.)
- Trading-MED: WT1-01..04 (flat per-pattern score; NEUTRAL-permits-long bias leak; PinBar proximity disabled; MACross NY block n=60 fit), WT2-*, WT3-02/03, WT4-01/02 (Rubber-Band episodic; PBC 0-fire unverifiable), ENG-05 (per-mode auto-disable can permanently prune a live mode on noise), PORT MEDs.

### LOW / dead / cosmetic
- WT1-05 (MACross labeled EMA, is SMA), NUM-05 (H1 hard-lock ~196 literals), NUM-06 (dead `g_scaledTrailBEOffset`), NUM-04/07/09 (gold-only price math; `_Symbol` vs position-symbol), CTX-06/07 (uninit-in-ctor handles, happy-path-safe), DET-03 (path-dependent adaptive state — by-design methodology note), PAT-04/05/06 (bounded forming-bar reads in dead/by-design plugins), the ~25-file dead `.mqh` set (X3 manifest: 83 LIVE / 25 DEAD, no dead path wired live), 5 truly-dead inputs incl. mis-annotated `InpScoreBearMACross`.

---

## D. Data-contradiction resolutions

| # | Contradiction | Resolution | Source |
|---|---|---|---|
| (a) | Constructor risk defaults vs wired inputs — which reaches sizing? | **Wired inline fallback** reaches sizing; risk plugin dormant-by-design; lot math identical. | U8 RXT-01 / WT-5 |
| (b) | Scorer tier thresholds 5/6/7/8 vs evaluator B=7 | **SETUP_B unreachable** (`InpPointsBSetup=7` behind A≥7); B+ (6) is effective floor. | U8 RXT-14 / WT-5 RISK-02 |
| (c) | CHOPPY "never fires" vs classifier coding it | Reachable but **near-measure-zero on gold H4** (ADX<15 ⇒ ATR contracting ⇒ routes to RANGING). Dead by construction, not bug. | WT-7 |
| (d) | `all_trades` CSV leaned-on | Model-1 artifact; used **directional only**, never as a verdict, throughout. | all units |
| **(e) NEW** | X1 census (**zero** HIGH look-ahead) vs U7/WT-3 (ENG-01/02 Displacement W1/D1 = HIGH) | `[P2]` adjudicating: X1 = forming-HTF running extreme is known-now (not future); U7/WT-3 = it's a hard gate whose level moves intrabar (repaint-instability). Materiality also hinges on whether the mode fires (LiquidityEngine = 0 trades). | impl `[P2]` |

---

## E. Cross-cutting verdicts

- **Risk/sizing model:** core fixed-fractional lot math is **dimensionally correct** in both plugin and fallback paths (X4); div-by-zero guarded on every axis. But the *adaptive* layer is largely inert (risk plugin dormant) and the **vol ratio is mis-unit'd (H4/H1, CTX-10)**; the 2% cap never binds; RSI-blind tiering deflates risk% (FILT-04).
- **Exits/trailing:** trailing subsystem is clean (only `TRAIL_CHANDELIER` live, closed-bar [1], double ratchet, STOPS_LEVEL clamp). **Exit plugins are a permanent no-op (RXT-02)** — the EA's operative exits are per-position SL, the TP ladder, the Chandelier trail, and the coordinator-native weekend closer only.
- **Filter stack:** "~8 gates" is mostly no-ops on prod; the gates that actually bind are the point-threshold quality tier, the direction-blind ADX/ATR confidence gate, the long-for-longs validator, and **the registered plugin set being long-only**. SMC floor and RSI gate are dead.
- **Look-ahead census:** signal path is `if(isNewBar)`-gated and `CMarketContext::Update()` self-gates once-per-H1-bar, so component forming-bar reads are bar-open snapshots, not intrabar repaint. Residual concerns: the Displacement W1/D1 gate `[P2]`, LA-05 (BB abort), RXT-18 (TP sizing). No CRITICAL/HIGH repaint in the discrete-pattern entry path.
- **Determinism:** live OnTick deterministic; no RNG on live path; all `MQL_TESTER` branches deterministic. Leaks: DET-01 (unbounded spread-median). Path-dependent adaptive state (DET-03) is by-design.
- **Portfolio/methodology:** 2 regime-keyed clusters (75% correlated longs + 25% diversifying short), not 11 independent edges; starvation at generation not ranking; methodology weak-to-moderate (98% zero-slippage, in-sample mode curation in defaults).
- **Dead-code manifest:** 83 LIVE / 25 DEAD `.mqh`; no dead path wired live; `CXAUUSDEnhancer→CMarketCondition→CATRCalculator` chain DEAD (CTX-01, executor built NULL).
- **Numeric/portability:** sizing symbol-aware (point-scale + profiles) but position-management price math is single-symbol/single-TF **gold-H1** (NUM-04/05/07/09).

---

## F. Inert / dead advertised-feature inventory (the spine of the report)

| Advertised feature | Reality on prod | Finding |
|---|---|---|
| SMC confluence floor (40 hard / 60 gate) | `ConfigureSMC` never called → `m_smc_enabled=false` → returns 50/PASS for every signal | FILT-01 / SMC-04/05 |
| RSI-extreme gating + "+3 quality pts" | Momentum filter disabled → `GetCurrentRSI()`=50 always | FILT-04 / CTX-02 |
| Adaptive risk-scaling (loss/vol/short/health/engine-weight) | Risk plugin never initialized → inline fallback (lots identical, scaling steps never run) | RISK-01 / RXT-01 |
| Structure-aware + max-age + daily-loss-close + weekend exits | All 4 exit plugins never initialized → `CheckExitPlugins` no-op | RXT-02 |
| HTF short-veto | Gated on `routed_engine` → never fires on prod | ORC-04 |
| Breakout-probation double-mult | Dead path | ORC-01 |
| SETUP_B risk tier | Unreachable (threshold behind A check) | RXT-14 |
| Multi-strategy router + 4 engines | OFF by default | (Phase-0) |
| Macro DXY/VIX intermarket | Degrades to gold price-proxy in tester | FILT-09 / CTX-04 |
| Session-breakout / LiquiditySweep / RangeBox / FalseBreakFade plugins | Instantiated, never registered/initialized | PAT-09 |

---

## G. Prioritized recommendations (evaluation only — not executed)

1. **Decide the exit-plugin layer (RXT-02).** Either initialize the 4 exit plugins (restores the structure-aware regime exit + daily-loss position-close + 72h max-age) or formally delete them and document that exits = SL/TP-ladder/Chandelier/weekend-native. Kill-criterion: a backtest with the regime-aware exit live must not degrade PF vs current; if it does, the no-op was accidentally beneficial and should be made explicit.
2. **Fix the ATR vol-ratio units (CTX-10).** Make `GetATRCurrent` / `GetATRAverage` the same timeframe; re-confirm the EC-v3 multiplier behaves. Falsifiable: the realized vol ratio distribution should center near 1.0 in normal regimes.
3. **Adjudicate + (if real) fix the Displacement W1/D1 gate (ENG-01/02).** One-line shift 0→1 each; then an isolation test can fairly grade the Displacement mode (currently quarantined).
4. **Resolve RSI sourcing (FILT-04).** Either enable an RSI handle independent of the momentum filter or remove the RSI-dependent tier bonus/exceptions so tiers aren't silently deflated.
5. **Re-state the EA honestly.** Update the strategy count / advertised-feature list to match the operative reality (one long cluster + one conditional short; the inert inventory above).
6. Lower-priority: EXE-01 netting bind, DET-01 spread-median trim, NUM-03 STOPS_LEVEL check, exposure-cap denominator (ORC-02/NUM-02), the dead-input/manifest cleanup.

*(Severities marked `[P2]` finalize when the two Phase-2 agents report; the compile-warning reconciliation appends here.)*
