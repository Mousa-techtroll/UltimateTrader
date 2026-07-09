# EVAL-PHASE2-EDGE — Trading-materiality scoring + edge↔implementation reconciliation

Phase 2 adjudication (stok). READ-ONLY, static. Clean-room: reasoned from SOURCE + the
Phase-1 EVAL-* scorecards (our own outputs) + targeted source re-verification of every
load-bearing fact. `claude/all_trades_v15.csv` = directional cross-ref ONLY (Model-1 caveat).

Materiality scale (trading impact): **0** cosmetic/dead-path · **1** minor · **2** material ·
**3** changes the realized edge/risk profile.

Source re-verifications performed this pass (not taken on trust):
- FILT-04: `CMarketContext.mqh:719-724` `GetCurrentRSI(){ if(m_momentum_filter==NULL) return 50; ...}`;
  `InpEnableMomentum=false` (`UltimateTrader_Inputs.mqh:168`) → filter never constructed → RSI≡50. CONFIRMED.
- CTX-10: `CRegimeClassifier.mqh:106` ATR = `iATR(_Symbol,PERIOD_H4,..)` (current); `CVolatilityRegimeManager.mqh:182`
  avg = `iATR(_Symbol,PERIOD_H1,14)`. H4-current / H1-average ratio CONFIRMED.
- CrashBreakout: `CCrashBreakoutEntry.mqh` D1 EMA50/EMA200 read `[1]` (CopyBuffer widened to 2),
  `d1_close=iClose(_Symbol,PERIOD_D1,1)`; H1 EMA21/ATR/ADX read `[1]`; only `SYMBOL_BID` is live (fade trigger).
  Registered `UltimateTrader.mq5:645` gated on `InpEnableCrashDetector(true) && g_profileEnableCrashBreakout`;
  `g_profileEnableCrashBreakout` only set false on the JPY profile (`:293`) → ENABLED on XAUUSD prod. CONFIRMED.

---

## TASK A — Materiality of every surviving HIGH implementation finding

| Finding | Trading impact | Why it does / doesn't move real P&L or risk |
|---|:---:|---|
| **RXT-02** — 4 exit plugins never `Initialize()`d → `CheckExitPlugins` no-op | **2** | Material but not edge-defining. The only *structure-aware* exit (`CRegimeAwareExit` macro-opposition / H1-EMA50 structure close), the **72h max-age close** (NO backstop), and the **daily-loss position-close** all silently never fire. BUT three backstops blunt it: per-position SL is intact (no naked risk), the coordinator-native weekend closer (`CPositionCoordinator.mqh:1712-1723`) still flattens Friday, and `CRiskMonitor.CanTrade()` still BLOCKS new entries at the 3% daily loss (it just can't *close* the open ones). Real cost = open positions can ride past 72h and through a macro-flip / 3%-day without a managed exit, leaning entirely on SL+trail. On a long-biased gold book in an uptrend that rarely bites, but it is a genuine lost capital-protection layer the EA is *configured to use* → 2, not 3. |
| **CTX-10** — H4-current ATR / H1-average ATR ratio feeds the EC-v3 vol input | **1** | Systematic mis-measure, bounded effect. H4 ATR is structurally ~2–4× H1 ATR, so `GetATRCurrent()/GetATRAverage()` reads "volatility" permanently HIGH. Direction of the sizing error: the EC-v3 **vol layer can only REDUCE** risk (clamped ≤1.0 at apply, floor ~0.90), and an inflated ratio reads as "expanding vol" → it pulls the vol multiplier toward its 0.90 floor more often than warranted → **systematic slight UNDER-risking** (and a small spurious ATR-velocity context bias). It never *over*-sizes. Because the live floors are shallow (vol 0.90, EC core 0.70) and the dominant reducer is session (0.5×/0.9×), the realized $-impact is small — a few bps of risk shaved. Mis-sizing is real and one-directional (conservative), hence 1 not 0; not 2 because it cannot push risk *up* and the magnitude is capped by the 0.90 vol floor. |
| **FILT-04** — RSI hardwired to 50 (momentum filter off) → kills RSI-extreme validator exceptions AND the CSetupEvaluator "+3 extreme-RSI" quality points | **2** | Material to selection/sizing, but it *deflates*, not distorts-randomly. With RSI≡50: (1) every RSI-unlock in `CSignalValidator` is dead — the trend-conflict / ranging / volatile / choppy counter-trend overrides never open, so a D1↔H4 conflict is a HARD reject for longs (the validator is *stricter*, not looser). (2) The single biggest scoring axis (+3, `CSetupEvaluator.mqh:187-192`) never awards, so tiers are systematically pulled DOWN and with them risk% — every realized A+/A/B+ was reached *without* RSI help. Net effect: fewer counter-trend entries + lower tiers + smaller size = a **consistently more conservative** EA than the config implies; the measured per-tier expectancy in the CSV is RSI-blind. It changes *which* trades fire and at *what size*, so 2 — but it does not corrupt direction or fabricate trades, so not 3. (Trading note: on gold OTC an RSI gate is a weak filter anyway; losing it costs little real edge.) |
| **ENG-01 / ENG-02 / WT3-01** — Displacement-mode W1/D1 forming-bar reads (look-ahead/repaint feeding `liq_score>=2` HARD gate + qualityScore) | **0** | Quarantine-worthy in principle, **dead in practice**. ENG-02's forming-W1 read gates a *live* Displacement entry and ENG-01's forming-D1 penalty biases its score — genuine look-ahead. BUT the entire LiquidityEngine = **0 ENTRY rows** in the Model-1 artifact; Displacement never won the per-bar ranking and/or its triple condition never co-occurred. A look-ahead that contaminates a mode which fires zero trades moves zero realized P&L. Score 0 for *current realized* impact — with the explicit caveat that this is a latent landmine: it MUST be fixed to shift-1 before any Displacement isolation backtest, or that test inherits the bias. (Materiality is conditional on the mode ever firing; today it doesn't.) |
| **RISK-01 / RXT-01** — dormant adaptive risk-scaling surface (`CQualityTierRiskStrategy` never `Initialize()`d → orchestrator inline fallback sizes; only loss/vol/short/health/engine-weight scaling is inert) | **1** | Lots are **identical** to what the live path produces — the fallback trusts the already-fully-stacked `signal.riskPercent`, and the orchestrator independently applies the 2.0% cap + counter-trend halving + 5% exposure cap. So no wrong-size trade results → not 2. What is genuinely lost: the plugin's consecutive-loss scaler, vol-regime adjust, short-protection, health throttle, engine-weight, and the `OrderCalcMargin` free-margin pre-check never run. The loss-scaler is documented to fire 0× anyway (close-time-counter vs sizing-time-read), and EC-v3 is the de-facto loss-streak governor, so the *missing adaptive reductions* would mostly duplicate EC-v3 — not having them costs little incremental drawdown control. The one real gap is the absent margin pre-check (a broker-reject edge case, not a sizing error). Net: a large inert "risk logic" surface that the live path already substitutes for → 1. |
| **EXE-01** — netting partial-fill ticket-bind desync | **1** | Real-money relevant but low-probability and bounded. On a *netting* account, a partial fill (`posVol < requested` by >1 step) fails the volume-matched adoption in `ValidatePositionExists`, so the new position binds via the looser history-deal path instead — `CPositionCoordinator` re-discovers and adopts the actual open position, so the trade is not lost, but its tracked lot/ticket can transiently desync from the true partial fill. Impact is conditional on (a) a netting broker AND (b) a partial fill — gold market orders on the target broker fill in full almost always, and the EA's symbol is MARKET-execution. Worst realized case = a mis-tracked partial that the coordinator reconciles; it cannot open a wrong-direction or oversized trade. Real but rare → 1 (would be 2 on a routinely-partial-filling venue). |
| **ORC-04** — HTF-uptrend SHORT veto never fires (gated on `routed_engine`, router OFF) | **0** | Dead path, but flag the *consequence*. The veto code is unreachable on prod (`is_engine` is constant-false without `InpEnableMultiStrategy`). Materiality of the *bug itself* = 0 (nothing changes vs intended live behavior). The trading consequence worth recording: live shorts therefore have **no HTF-trend veto at all** — the only short gates are the (non-binding, FILT-05) ATR-min floor + downstream SMC/confidence. On gold the realized shorts are the death-cross-gated Rubber-Band + Bearish Pin, both already regime-self-protecting, so the absent veto did not produce bad shorts in the artifact. Impact ≈ 0 as a bug; a latent gap if a non-self-gating short engine were ever enabled. |
| **ORC-01** — breakout-probation double-mult (re-applies session×regime already baked into the stored signal) | **0** | Confirmed double-application math error, but on a **dead path** — `InpEnableBreakoutProbation=false` default, so the stored-signal re-multiply at `mq5:1498-1499` never executes. Zero realized impact. Becomes a real over/under-sizing bug only if probation is ever enabled (then it would double-count session+regime on probation trades). Impact = 0 today. |
| **PORT-01** — 6 of 12 enabled strategies fire 0 trades in 7yr (ranking/generation starvation) | **2** | Material to the *interpretation* of the edge, not to per-trade P&L. The "11-strategy" framing overstates diversification ~2×: only 6 ever trade, and 3 longs supply ~70% of trades. The dead-fire set (VolBreakout, Displacement, RangeEdgeFade/S3, OB-Retest, PullbackEngine, SessionEngine) contributes nothing — false confidence + wasted compute, and it means the realized edge rests on a much narrower base than the config advertises. It doesn't change the P&L of the trades that *did* fire, but it changes the honest description of where the edge comes from → 2. |
| **PORT-02** — strict `>` + 4-value bucket ranking → registration-order tie-bias (Engulfing wins all A+ ties) | **2** | Material to the realized strategy mix. Legacy patterns collapse onto {10,7,5,3}; 64% of signals are A+(=10); strict `>` keeps the first-registered (Engulfing) on every tie → PinBar/MACross systematically under-fire on shared-signal bars. Since Engulfing, PinBar, MACross have *different* per-tier expectancy (MACross avgR +0.31 vs Engulfing +0.156 in the artifact), the tie-bias actively shifts the realized blend toward the lower-avgR pattern. It changes which trades the book actually takes → 2. (The ranker also has no granularity — a 0–10 scale using 4 values — so it cannot express the quality differences it claims to rank on.) |

**Task-A summary by impact:** 2 = {RXT-02, FILT-04, PORT-01, PORT-02}; 1 = {CTX-10, RISK-01/RXT-01, EXE-01};
0 = {ENG-01/02/WT3-01, ORC-04, ORC-01}. No surviving HIGH scored 3 — none of them, in the prod
config, *changes the direction or fabricates/oversizes* a live trade; the highest-impact items
(RXT-02, FILT-04) reshape *selection, sizing-conservatism, and capital-protection coverage*, and the
portfolio HIGHs (PORT-01/02) reshape the *honest description* of the edge, but the realized R-stream
of the trades that fired is governed by intact SL/trail/cap plumbing.

---

## TASK B — Edge↔implementation reconciliation (the 2 "real structural edge" strategies)

### B1 — CCrashBreakoutEntry (Rubber-Band short, 9/10, credited) → **SURVIVES 9/10**
- **D1 death-cross gate computes on CLOSED bars, wired inputs:** `CCrashBreakoutEntry.mqh` reads
  `ema50_buf[1]`/`ema200_buf[1]` (CopyBuffer deliberately widened 1→2 to use index `[1]`) and
  `d1_close=iClose(_Symbol,PERIOD_D1,1)`. `death_cross_exists=(ema50<ema200)` is the regime gate; it
  arms on the cross alone (the `d1_close<ema50` flag is informational). VERIFIED at source.
- **EMA21 fade computes on closed bars:** H1 `ema21_buf[1]`, `atr_buf[1]`, `adx_buf[1]` all closed;
  `extension_threshold = EMA21 + ATR×2.0`; trigger compares **live `SYMBOL_BID`** to that closed-bar
  threshold — the one live read, and it is the *correct* way to arm a fade (you must compare live price
  to a fixed mean to fade the stretch). Not a repaint of a decision input. Look-ahead = 2 stands.
- **Registered + enabled on prod:** `RegisterEntryPlugin(g_crashEntry, InpEnableCrashDetector(true) &&
  g_profileEnableCrashBreakout && register_patterns)`; `g_profileEnableCrashBreakout` is set false ONLY
  on the JPY profile (`mq5:293`) → on XAUUSD it is enabled. The plugin is live, not a dead default.
- **Verdict: 9/10 SURVIVES.** Fidelity 2 (faithful death-cross-gated rubber-band fade), gold-direction 2
  (the gate makes it mechanically incapable of fighting the bull trend — exactly the right answer to
  shorting a structurally-bullish asset), filter 2 (causal, regime-gated, not date-fit), look-ahead 2
  (clean; only the fade trigger is live BID, by design), robustness 1 (Model-1 directional, episode-
  concentrated). Positive-edge gate passes (fidelity≥1 ∧ look-ahead=2 ∧ robustness≥1).
- **Episodic-dormancy caveat (restated, decisive):** this is a *conditional* edge, NOT a persistent one.
  All ~93 of 104 lifetime trades and 100% of the positive R come from a single ~18-month D1
  death-cross window (2021H2→2022: +8.98R then +6.06R); 2023 tail already −1.69R; **0 trades in
  2019/2020/2024/2025** (no D1 death cross in bull years → correctly dormant, not bleeding). Treat it as
  regime insurance / a dormant short hedge that pays only in a sustained gold downtrend and contributes
  nothing for years at a time. The 9/10 grades the *structure and cleanliness*, not a promise of
  continuous P&L.

### B2 — OB-Retest (CLiquidityEngine, 7/10, dormant) → **7/10 STANDS as a STRUCTURAL grade; robustness uninformative**
- **Triple AND-gate computes on CLOSED bars, wired engine config:** the trigger requires, simultaneously,
  (1) price in a real OB zone (`CSMCOrderBlocks` last-opposite-candle-before-impulse, built from bars ≥3,
  forming bar never referenced), (2) a same-direction BOS/CHoCH (`GetRecentBOS()` from bars `[1]/[2]`),
  and (3) a rejection candle on bar `[1]` (wick≥30%×body or body≥0.4×ATR). ATR from `atr_buf[1]`. The
  only live read is `SYMBOL_BID` for the in-zone test — a legitimate "where is price now" entry check.
  Crucially, OB-Retest does **NOT** call `GetLocationPenalty()` (D1-forming) or `ScoreLiquidityLevel()`
  (W1-forming) — the two ENG-01/ENG-02 look-ahead helpers contaminate Displacement/FVG/SFP, **not**
  OB-Retest. So this is the cleanest mode in the engine; look-ahead = 2. VERIFIED via WT3 + U7 line refs.
- **Mode is REACHABLE on the wired config:** `ConfigureModes(true, InpLiqEngineOBRetest=true, FVG=false,
  SFP=false)` — OB-Retest is enabled (priority P2, behind Displacement P1). The engine runs on the legacy
  prod path (`m_isEnabled` defaults true). So it is not gated off — it is *config-reachable*.
- **"Inert" = structural starvation, NOT a config choice.** It produced **0 ENTRY rows** in the Model-1
  artifact. The cause is not a disable flag — it is that (a) the triple-AND (in-OB ∧ same-dir BOS/CHoCH ∧
  rejection, all on one closed H1 bar) rarely co-occurs, and (b) when a candidate does exist it carries a
  *fixed* qualityScore 82/80 that must out-rank the candlestick plugins in the per-bar single-slot
  ranking — and with 64% of signals tying at A+ and strict-`>` registration-order bias (PORT-02), it
  loses. So it is starved by the conjunction-rarity + ranking, not switched off. That distinction matters:
  enabling it differently won't help; only loosening the conjunction or changing the ranker would.
- **Verdict: the 7/10 STRUCTURAL grade STANDS** (fidelity 2, look-ahead 2 confirmed clean and computed on
  closed bars with wired inputs — it is not a stale default or a dead mode), **but robustness is
  uninformative** (0 trades = no realized evidence either way; the robustness-1 credit per rubric is a
  floor for "structurally sound + clean," not a measured edge). It is correctly classed **real-but-inert**:
  a genuine, look-ahead-clean SMC continuation entry that contributes **nothing** in practice. Do NOT
  assume it helps the book; it needs an isolation backtest to decide keep-vs-cut. Model-1 caveat: "0 trades"
  = starved in combined ranking, not proven "0 signals ever."

---

## TASK C — TRUE operative edge & risk posture (one honest sentence each)

**Operative edge:** Stripped of its inert subsystems and 6 zero-firing "strategies," the EA's real,
realized edge is a single regime-conditioned bet — **buy gold dips in an uptrend through a few
near-redundant long triggers (Engulfing/PinBar/MACross, ~75% of trades, internally highly correlated and
tie-biased toward Engulfing), with a genuinely diversifying death-cross-gated mean-reversion short that
pays only in a sustained gold downtrend (one ~18-month episode in six years) and sleeps otherwise** —
i.e. a thin small-positive-expectancy long-continuation factor plus dormant short insurance, on
unrealistic zero-slippage, in-sample-curated fills.

**Risk posture:** The live risk machine is **net-conservative and mostly intact where it matters** —
correct fixed-fractional sizing, an EC-v3 graded drawdown reducer, a 3% daily-loss new-entry halt, a 5%
portfolio cap, and intact per-position SL/trail — but a large band of *adaptive* protection is silently
asleep (uninitialized risk plugin, dormant exit plugins so no managed 72h-max-age / daily-loss-close /
macro-opposition exit, a structurally-dead B tier, an RSI gate frozen at 50, and a mildly vol-inflating
H4/H1 ATR mismatch that only ever shaves size), so the EA under-risks rather than over-risks and its true
exposure is one correlated long-gold book defended chiefly by stop-losses and a daily circuit-breaker
rather than by the adaptive logic the codebase appears to contain.
