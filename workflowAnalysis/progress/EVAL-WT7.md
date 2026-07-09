# EVAL-WT7 — Regime / Session / Macro / Validation Filter Stack

Clean-room, source-only, static. Scope: the GATE CHAIN that filters entries.
Stok subagent. All claims line-anchored. Tick-volume caveat applies (XAUUSD+ spot: no real
volume/DOM; "volume" filters read tick-count proxy only).

Key unit fact pinned across this analysis: **XAUUSD+ quotes 2 decimals → 1 point = 0.01, $1 = 100 points.**
H1-primary EA, but the regime classifier and the ADX the validator reads run on **H4**.

---

## A. EXECUTIVE VERDICT (the headline)

The "filter stack" advertises ~8 interlocking gates. **On the production .set, most of them are
no-ops.** The chain that actually narrows the trade set down to one position/bar is:

1. **Session window** (binds ~2h/day only),
2. **ATR-min** (non-binding — threshold 0.3 vs gold H4 ATR ~8-20),
3. **Quality-tier point threshold** (the REAL binding gate — B+ needs 6 pts, A needs 7, A+ needs 8; B is dead),
4. **Pattern set being long-only on prod** (the true long bias — enforced at registration, not in the validator).

The much-discussed gates — **validator-level SMC confluence, the 200-EMA short-block chain, the
RSI-extreme exceptions, the macro DXY/VIX bias, the momentum filter** — are each either disabled,
fed a constant, or short-circuited by a "Sprint fix" that allows any recognized pattern through.
The long bias is **real and defensible for gold**, but it is **not implemented by the validator
gates** the comments claim; it is implemented by (a) the registered plugin set being long-only and
(b) `IsPriceAboveMA200()` defaulting bullish on warmup. The validator's short-suppression machinery
is **largely decorative**.

---

## B. FILTER-SOUNDNESS MATRIX (gate → checks → sound? → binds or no-op?)

| Gate | File:line | What it checks | Sound for gold? | Binds or NO-OP? |
|---|---|---|---|---|
| **Session window** | Utils.mqh:154-162 | Asia∪London∪NY (all `true` on prod) | OK in principle | **WEAK** — union covers 23:00–21:00 GMT; only 21:00–23:00 GMT (2h) excluded |
| **Skip zone 1/2** | Utils.mqh:73-98; Inputs:271-274 | hour ∈ [skip_start,skip_end) | n/a | **NO-OP** — defaults 11/11 → empty range → always allowed |
| **Regime classify (ADX 20/15)** | CRegimeClassifier.mqh:250-347 | H4 ADX hysteresis 20-enter/18-exit/15-range | Mediocre fit (see §C) | Feeds scoring + validator; classification BINDS but thresholds are H4-calibrated and read by H1 logic |
| **CHOPPY detection** | CRegimeClassifier.mqh:272-275 | ADX<15 ∧ ATR-ratio 0.9–1.1 ∧ BB<1.5% | n/a | **Codeable but near-unreachable** (see §E) |
| **Macro DXY/VIX bias** | CMacroBias.mqh:119-168 | DXY trend + VIX level → ±score | Sound logic | **DEGRADED in tester** — DXY="USDX"/VIX="VIX" rarely load → price-fallback path (§D) |
| **Validator SMC confluence** | CSignalValidator.mqh:163-203; mq5:556-557 | confluence ≥ 40 hard / counter-OB block | Would be sound | **TOTAL NO-OP** — `ConfigureSMC` never called → `m_smc_enabled=false` → returns 50, PASS (FILT-01) |
| **200-EMA short-block chain** | CSignalValidator.mqh:344-508 | multi-exception short suppression vs D1 200EMA | Over-engineered | **NO-OP for shorts** — bypassed entirely at orchestrator:622-630; and even if reached, :417-431 allows ANY pattern (FILT-02, FILT-03) |
| **RSI-extreme exceptions** | CSignalValidator.mqh (is_extreme_*); CSetupEvaluator:188 | RSI>75 / <25 unlock counter-trend + +3 pts | Sound idea | **DEAD** — RSI sourced from disabled momentum filter → always 50 (FILT-04) |
| **Trend-alignment (D1 vs H4)** | CSignalValidator.mqh:511-536 | reject D1/H4 conflict unless RSI exception | Sound | BINDS for **longs** only (shorts bypass); RSI exception dead so it's a hard conflict-reject |
| **Regime-specific logic** | CSignalValidator.mqh:539-672 | per-regime direction/macro gating | Mixed | BINDS for longs; CHOPPY/UNKNOWN branch is long-only-biased and sound |
| **Volume/spread (breakouts)** | CSignalValidator.mqh:122-158 | tick-vol ratio ≥ 1.0 on breakout patterns | Weak (tick-vol proxy) | BINDS only for Engulfing/VolBreakout/Crash; fails-OPEN on copy error |
| **Pattern "confidence"** | CMarketFilters.mqh:150-180 | **ADX/ATR environment gate** (NOT pattern, NOT direction) | Misnamed but causal | BINDS — base 30 + ADX-band + ATR-band; min 40 → needs at least one band. Direction-blind. |
| **ATR-min (trend short)** | CSignalOrchestrator.mqh:656; mq5:911 | current_atr ≥ 0.3 | n/a | **NO-OP** — 0.3 price-units vs gold H4 ATR ~8-20 → always passes (FILT-05) |
| **HTF-uptrend SHORT veto** | CSignalOrchestrator.mqh:630-654 | engine short into H4/D1-bull + price>MA200 → reject | Sound | BINDS **only** for routed-engine shorts (`is_engine`), which require `InpEnableMultiStrategy=true` → **dead on prod** (FILT-06) |
| **Quality-tier threshold** | CSetupEvaluator.mqh:329-334; mq5:559-565 | points ≥ B+(6)/A(7)/A+(8); B(7) dead | The actual edge gate | **THE BINDING GATE** (FILT-07 on dead B tier) |
| **Momentum filter** | CMomentumFilter.mqh; Inputs:168 | RSI/MACD/Stoch/CCI/MFI direction block | Sound if on | **NO-OP** — `InpEnableMomentum=false` → never created (FILT-04 root) |
| **Vol-regime manager** | CVolatilityRegimeManager.mqh | ATR-percentile → risk mult + SL mult | Sound | Risk SCALER, **not an entry gate** — never rejects (WT-5 territory) |
| **CConfluenceScorer (L3 spine)** | CConfluenceScorer.mqh | sweep+structure HARD gate, 7 orthogonal axes | Genuinely sound | **DEAD on prod** — only the 4 router engines call it; `InpEnableMultiStrategy=false` |

---

## C. ARE THE ADX 20/15 REGIME CUTS SOUND FOR GOLD?

**Partly, but with a timeframe-units defect that undermines them.**

- The classifier runs ADX/ATR/BB on **PERIOD_H4** (CRegimeClassifier.mqh:105-107) with hysteresis
  20-enter / 18-exit (TRENDING), 15-enter / 18-exit (RANGING). Hysteresis + 2-bar confirmation +
  thrash-cooldown (lines 176-230) is good engineering and reduces flip-flop. The 20/15 split on H4
  gold is reasonable: H4 gold ADX does sit mostly 15-35, so 20 as the trend line is defensible.
- **DEFECT (FILT-08):** the same ADX value (`GetADXValue()` → regime classifier's **H4** ADX,
  CMarketContext:401-405) is the `current_adx` the validator compares against thresholds that are
  semantically **H1-scaled**: `m_validation_strong_adx=22`, `m_short_trend_max_adx=50`,
  `m_bull_mr_short_adx_cap=17`, breakout `>=26`. H4 ADX and H1 ADX are different distributions
  (H4 ADX is smoother/lower-variance). A "strong trend" cutoff of 22 on H4 ADX is a *different
  market* than 22 on H1 ADX. The CrashDetector RubberBand correctly uses its **own H1 ADX** handle
  (CCrashDetector:114,305) — so the EA mixes H4-ADX gating and H1-ADX gating without reconciling
  the scales. Not catastrophic (most ADX gates are dominated by other no-ops), but the cuts are
  **not cleanly calibrated to the instrument/timeframe they gate.**
- Verdict: **structurally reasonable, calibration-muddled.** The ADX cuts are not over-fit to
  dates, but they're applied across mismatched timeframes.

---

## D. IS THE MACRO DXY/VIX BIAS WIRED WITH LIVE DATA IN THE TESTER?

**No — it runs degraded (price-fallback) in the Strategy Tester, and likely live too.**

- Symbols: `InpDXYSymbol="USDX"`, `InpVIXSymbol="VIX"` (Inputs:225-226). `CMacroBias::Init`
  (CMacroBias.mqh:74-114) calls `SymbolSelect()` on each. In the MT5 Strategy Tester, secondary
  symbols only load if they exist in the broker's symbol list AND have synchronized history;
  "USDX"/"VIX" are non-standard names (Vantage uses different tickers) and VIX especially is
  usually absent. When both fail, `m_dxy_available=false` and `m_vix_available=false`.
- With both unavailable, `Update()` (lines 119-141) takes the **price-fallback** branch
  (`AnalyzePriceFallback`, lines 281-316): it derives a ±2 macro proxy from **gold's own**
  D1 EMA200 + H4 EMA(20/50) slope. So "macro bias" becomes a **second copy of the gold trend**,
  not an intermarket signal. `GetMacroMode()` would report `MACRO_MODE_PRICE_FALLBACK`.
- **Implication (FILT-09):** the macro axis is **not orthogonal** to the trend axis when degraded —
  it is gold-trend-derived. Any "macro confluence" credited in `CSetupEvaluator` Factor-3 (lines
  206-212, which awards +1 even for macro_score==0, so it's nearly free anyway) double-counts the
  trend. And every validator branch keyed on `macro_score` (the strong-bear overrides at
  CSignalValidator:379, :466, :588-604) is reacting to a gold-trend proxy, not a dollar/vol signal.
- Even the price-fallback EMA200 read uses the **live BID** for the price-vs-200 test (CMacroBias:298,
  documented front-run) — fine, but it means the "macro" flips intrabar.
- Verdict: **degraded/forced-fallback in tester.** The intermarket edge the design implies is not
  present; what's measured is a redundant gold-trend echo. (To confirm at runtime: check the log for
  "Price-based macro fallback" lines and `GetMacroMode()`.)

---

## E. CHOPPY-FIRES RESOLUTION (the contradiction)

**Both sides are correct and consistent. The classifier CODES a CHOPPY branch, but on gold H4 the
conjunction is so narrow it effectively never fires — matching the inputs comment "0/815".**

Trace of `ClassifyRegimeRaw()` (CRegimeClassifier.mqh:250-347):
- **Priority 1 VOLATILE** (line 265): fires if `volatility_expanding || atr_ratio > 1.3`.
- **Priority 2 CHOPPY** (lines 272-275): requires **simultaneously**
  `adx < 15` **AND** `atr_ratio ∈ [0.9, 1.1]` **AND** `bb_width < 1.5%`.
- **Priority 4 RANGING** (lines 300-305): `adx<15` (or ≤18 hold) **AND** `atr_current < atr_average*0.9`
  → i.e. `atr_ratio < 0.9`.

The CHOPPY band needs ADX<15 with **flat** ATR (ratio 0.9–1.1) and a **compressed** BB (<1.5% of price).
On gold H4, when ADX falls below 15 the ATR is almost always **contracting** (ratio < 0.9), which
routes the bar to RANGING (Priority 4) instead. The thin slice where ATR is *exactly* flat (0.9–1.1)
AND BB is tight AND ADX<15, all at once, is a near-measure-zero event in gold H4 data. So:
- The inputs comment (Inputs:61: "CHOPPY regime never occurs on gold (0/815 trades)") is
  **empirically true**.
- The classifier "coding it" is **also true** — the branch exists and is logically reachable.
- **Resolution:** no contradiction. CHOPPY is **dead by construction on gold H4**, not by a bug.
  Consequence: every downstream CHOPPY-keyed gate is inert — `InpStructureBasedExit`,
  `InpAutoCloseOnChoppy`, `InpPBCBlockChoppy`, the CHOPPY regime-exit profile (Inputs:407-413),
  and `CSetupEvaluator` Factor-2's `regime==REGIME_CHOPPY → +0` branch (line 201-202). The
  `REGIME_CHOPPY || REGIME_UNKNOWN` validator branch (CSignalValidator:656) fires only via
  **UNKNOWN** (warmup), never CHOPPY.

---

## F. LONG-BIAS VERDICT (sound structure vs over-fit suppression)

The long bias is **real and defensible for gold's structural uptrend** — but the **mechanism is
mislabeled**. The bias does NOT come from the validator's short-suppression chain (which is
bypassed/no-op'd). It comes from:

1. **The registered plugin set is long-only on prod** (Engulfing/PinBar/MACross are long-only per
   Phase-0 map). This is the legitimate, data-driven bias — bearish patterns measured negative on
   gold, so they're not registered. **Sound.**
2. **`IsPriceAboveMA200()` defaults bullish** when MA200 is unavailable (CMarketContext:489-498,
   `m_ma200_default_bullish=true`). Defensible for gold (long-run uptrend), explicitly configurable
   per-symbol. **Sound, documented.**

Now the short-bypass chain the prompt names — counter-trend penalty → short-risk mult → SMC≥40 →
conf≥40 → ATR-min → HTF-veto — audited link by link:

| Claimed short protection | Reality |
|---|---|
| Full TF/MR validator | **BYPASSED** — shorts skip it entirely (orchestrator:622-630) |
| HTF-uptrend veto | **DEAD on prod** — gated on `is_engine` (routed engines only; multi-strategy off) (FILT-06) |
| ATR-min | **NO-OP** — 0.3 threshold trivially cleared (FILT-05) |
| SMC ≥ 40 | **NO-OP** — validator SMC disabled, returns 50 PASS (FILT-01) |
| Confidence ≥ 40 | BINDS but **direction-blind** — pure ADX/ATR environment gate (CMarketFilters:150) |
| Counter-trend quality penalty | BINDS — shorts earn fewer points; with B+ needing 6/10 this is the real short filter |
| 0.5x short risk mult | Sizing only (WT-5), not a gate |

So for a **non-engine short** on prod, the ONLY binding filters are: (a) the direction-blind
ADX/ATR confidence gate, and (b) the quality-tier point threshold. Everything labelled as
short-specific structural protection is decorative. This is **not** "over-fit suppression" — it's
the opposite: the suppression was progressively **disabled** by "Sprint fix" relaxations
(CSignalValidator:417-431, :543-554, :611-633), and the long bias survives because **bearish
patterns aren't registered**, not because shorts are filtered. The 200-EMA chain (lines 344-508)
is ~165 lines of dead/bypassed exception logic.

**Verdict: long bias is sound (data-driven plugin selection + documented MA200 default), but the
validator short-gate machinery is over-built and effectively inert — a maintenance and
false-confidence liability, not an active risk control.**

---

## G. WHICH GATES ACTUALLY BIND vs NO-OP (summary)

**BIND (materially narrow the trade set):**
- Quality-tier point threshold (B+ ≥6, A ≥7, A+ ≥8) — the primary edge gate.
- Pattern "confidence" ADX/ATR environment gate (min 40) — direction-blind, culls dead/quiet regimes.
- Trend-alignment + regime-specific logic — **for longs only** (shorts bypass).
- Long-only registered plugin set (the true bias enforcement, upstream of WT-7).
- Session window — but only the 21:00–23:00 GMT exclusion.
- Volume/spread — only on the 3 breakout pattern types, fails-open on error.

**NO-OP / DEAD on prod:**
- Validator SMC confluence (FILT-01), 200-EMA short chain (FILT-02/03), RSI-extreme exceptions
  (FILT-04), ATR-min short gate (FILT-05), HTF-uptrend veto (FILT-06), SETUP_B tier (FILT-07),
  momentum filter, CConfluenceScorer L3 spine, CHOPPY branch, skip zones.

---

## H. DEFECT REGISTER (FILT-NN, unified schema)

### FILT-01 — Validator-level SMC confluence gate is a total no-op
- **Severity** MEDIUM · **Confidence** Confirmed · **Category** Filter soundness / dead-gate
- **Location** UltimateTrader.mq5:545-557 (no `ConfigureSMC` call); Include/Validation/CSignalValidator.mqh:74-82, 163-203
- **Evidence** Constructor leaves `m_smc_enabled=false` (CSignalValidator.mqh:66). `ConfigureSMC`
  is never invoked (mq5 comment at :556-557 "Leave validator-level SMC gating disabled"). Thus
  `ValidateSMCConditions` (:165-169) returns `confluence_score=50; return true` for EVERY signal.
  The `<40` hard floor (:195) and the counter-OB block (:181-193) never execute. The configurable
  `m_smc_min_confluence` (default 60, `InpSMCMinConfluence=55`) is **never used by this method at all**.
- **Impact** The "40 hard / 60 gate" SMC floor described in the architecture **does not exist on the
  orchestrator path.** ~0% of signals are rejected here. The real SMC gating only exists inside the
  (dead) CConfluenceScorer L3 spine.
- **Check** grep for `ConfigureSMC(` call sites — none on the live path.
- **Disposition** By-design (comment) but materially misrepresents the filter stack → report.

### FILT-02 — SHORT signals bypass the entire TF/MR validator
- **Severity** HIGH · **Confidence** Confirmed · **Category** Long-bias gate soundness
- **Location** Include/Core/CSignalOrchestrator.mqh:622-664
- **Evidence** `if(sig_type == SIGNAL_SHORT)` branch (:630) routes shorts to only [HTF-veto (dead
  on prod) → ATR-min (no-op)]; `validated=true` at :657 for any short with ATR≥0.3. The full
  `ValidateTrendFollowingConditions`/`ValidateEntryConditions` (the 200-EMA chain, trend alignment,
  regime logic) is reached **only by longs** (:665-680).
- **Impact** All non-engine short structural validation is skipped. Shorts are gated only by the
  direction-blind confidence gate + quality tier. The claimed "5+ interlocking short blocks" are
  unreachable for the very signals they target.
- **Check** Confirm `validated=true` reachable for shorts with no structural test.
- **Disposition** By-design ("Sprint fix") — report as a soundness finding (false-confidence).

### FILT-03 — 200-EMA short-block "allow any pattern" relaxation neuters the chain
- **Severity** MEDIUM · **Confidence** Confirmed · **Category** Filter soundness
- **Location** Include/Validation/CSignalValidator.mqh:417-431 (and symmetrical :543-554, :566-585)
- **Evidence** Even if a short reached the 200-EMA logic, the final fallback (:422-431) sets
  `allow_short=true` for any `pattern_type != PATTERN_NONE`. The "TRENDING EXCEPTION" lists
  (:546-554, :569-575) similarly admit nearly every structural pattern. So the 200-EMA "bias block"
  blocks ~nothing once a recognized pattern is present.
- **Impact** ~165 lines of exception logic collapse to "allow." Confirms the suppression is inert,
  not over-fit. Dead-weight complexity.
- **Disposition** By-design — report.

### FILT-04 — RSI is hardwired to 50; every RSI-extreme exception and the +3 RSI quality bonus are dead
- **Severity** HIGH · **Confidence** Confirmed · **Category** Determinism / dead-gate, scoring
- **Location** Include/MarketAnalysis/CMarketContext.mqh:719-724, 262-265; UltimateTrader_Inputs.mqh:168
- **Evidence** `GetCurrentRSI()` reads `m_momentum_filter.GetAnalysis().rsi_h1`, but returns a
  hardcoded **50** when `m_momentum_filter==NULL` (:721). The filter is created only when
  `m_enable_momentum` (CMarketContext:262); `InpEnableMomentum=false` on prod (Inputs:168) → NULL.
  Therefore `is_extreme_overbought`/`is_extreme_oversold` (CSignalValidator:338-339) are ALWAYS
  false, and `CSetupEvaluator`'s "+3 Quality Points for Extreme RSI" (CSetupEvaluator.mqh:187-192)
  is **never awarded**.
- **Impact** Large. (1) Every RSI-based unlock in the validator is dead: trend-conflict override
  (:522-529), ranging counter-trend (:613-629), volatile counter-trend (:646-647),
  choppy/unknown counter-trend (:658-665). (2) The single biggest scoring axis (+3, enough to lift
  a 5-pt B+ reject to an 8-pt A+) never fires — systematically deflating tiers and the resulting
  risk %. The tier distribution and sizing are computed as if RSI is permanently neutral.
- **Check** Confirm no alternate RSI source feeds the context; confirm `InpEnableMomentum` default.
- **Disposition** Confirmed-bug (silent constant feeding live scoring/gating) — high materiality.

### FILT-05 — Trend short ATR-min gate is non-binding (0.3 vs gold H4 ATR ~8-20)
- **Severity** LOW · **Confidence** Confirmed · **Category** Numeric/units, dead-gate
- **Location** Include/Core/CSignalOrchestrator.mqh:656; UltimateTrader.mq5:911 (`tf_min_atr=0.3`)
- **Evidence** `current_atr = GetATRCurrent()` is the H4 ATR in price units (gold H4 ATR ≈ $8-20).
  The threshold `m_tf_min_atr=0.3` is ~30 points = $0.30 → trivially cleared on every bar.
- **Impact** The only nominally short-specific numeric gate (after the dead HTF-veto) passes ~100%
  of shorts. Effectively no ATR floor.
- **Disposition** Confirmed (likely a units/scale oversight; harmless but misleading) — report.

### FILT-06 — HTF-uptrend SHORT veto is dead on production (gated on routed-engine flag)
- **Severity** MEDIUM · **Confidence** Confirmed · **Category** Dead-gate / long-bias
- **Location** Include/Core/CSignalOrchestrator.mqh:630-654; UltimateTrader_Inputs.mqh:505
- **Evidence** The veto is `if(is_engine && htf_uptrend)`, and `is_engine = signal.routed_engine`
  (orchestrator:566), set only inside an engine's `m_scorer!=NULL` block, which is wired only under
  `InpEnableMultiStrategy` — `false` on prod (Inputs:505). So on the production .set the
  "central guard against negative-expectancy gold shorts" never evaluates.
- **Impact** The most market-structurally sound short filter in the codebase (reject short into
  H4/D1-bull + price>MA200) is inactive on prod. Shorts into the uptrend are gated only by quality
  scoring. (Mitigated by bearish patterns being unregistered, but the guard itself is inert.)
- **Disposition** By-design scoping — report (the protection is illusory on prod).

### FILT-07 — SETUP_B (0.6% tier) is unreachable; threshold ordering non-monotone
- **Severity** LOW · **Confidence** Confirmed · **Category** Scoring / tier logic
- **Location** UltimateTrader_Inputs.mqh:285-288; Include/Validation/CSetupEvaluator.mqh:329-334; CConfluenceScorer.mqh:114-124
- **Evidence** Thresholds A+=8, A=7, B+=6, **B=7** (Inputs:288, "same as A"). The cascade
  `if(points>=B) return SETUP_B` with B=7 is unreachable because `points>=7` already returned
  SETUP_A. So tiers collapse to: ≥8 A+, =7 A, =6 B+, <6 reject. The 0.6% B tier never assigns.
  CConfluenceScorer:114-124 explicitly WARNs about this exact non-monotone ordering.
- **Impact** Minimum admitted tier is B+ (6 pts → 0.75% risk), not B (0.6%). The effective entry bar
  is **6/10 points**. Combined with FILT-04 (the +3 RSI axis dead), reaching 6 points is the real
  constraint. Intentional per Inputs comment ("filters B/B+ — proven in $6,140 baseline").
- **Disposition** By-design — report (the "B tier" in docs is dead).

### FILT-08 — Validator ADX thresholds applied to H4 ADX but scaled as if H1
- **Severity** MEDIUM · **Confidence** Likely · **Category** Filter soundness / units
- **Location** CRegimeClassifier.mqh:105 (H4 ADX); CMarketContext.mqh:401-405; CSignalValidator.mqh:357,368,373 (thresholds 17/22/50/26)
- **Evidence** `GetADXValue()` returns the regime classifier's **H4** ADX. The validator compares
  it to `m_validation_strong_adx=22`, `m_short_trend_max_adx=50`, `m_bull_mr_short_adx_cap=17`, and
  a literal `>=26.0` breakout cap (CSignalValidator:362) — bands that read like H1-ADX values. H4
  and H1 ADX are different distributions; the CrashDetector uses a separate H1 ADX (CCrashDetector:114).
- **Impact** The ADX gates are not calibrated to a single, consistent timeframe. A "strong trend"
  (ADX>22) on H4 is a materially rarer/stronger condition than on H1, so the strong-trend
  short-blocks fire less often than the literals suggest. Mostly masked by the other no-ops.
- **Check** Confirm no H1-ADX path overrides `GetADXValue()` in the validator.
- **Disposition** Needs-test (calibration), report.

### FILT-09 — Macro bias degrades to a gold-trend echo in the tester (not intermarket)
- **Severity** MEDIUM · **Confidence** Likely · **Category** Filter soundness / data availability
- **Location** Include/MarketAnalysis/CMacroBias.mqh:74-141, 281-316; UltimateTrader_Inputs.mqh:225-226
- **Evidence** DXY="USDX"/VIX="VIX" rarely resolve in the Strategy Tester (non-standard tickers,
  VIX usually absent). On failure, `Update()` (:125-141) uses `AnalyzePriceFallback` — a ±2 proxy
  from gold's OWN D1 EMA200 + H4 EMA slope. So `macro_score` becomes a redundant gold-trend signal,
  not a dollar/vol read.
- **Impact** The macro axis is non-orthogonal to trend when degraded. `CSetupEvaluator` Factor-3
  (+1 even at macro==0, lines 206-212) and every `macro_score`-keyed validator branch react to a
  gold-trend echo. Any "macro confluence" claim double-counts the trend. Backtests do not validate
  an intermarket edge.
- **Check** Runtime: `GetMacroMode()==MACRO_MODE_PRICE_FALLBACK`; log line "Price-based macro fallback".
- **Disposition** Needs-test (verify symbol availability on the Vantage tester feed) — report.

### FILT-10 — Volume/spread breakout filter reads tick-volume proxy and fails-open
- **Severity** LOW · **Confidence** Confirmed · **Category** Filter soundness (data caveat)
- **Location** Include/Validation/CSignalValidator.mqh:122-158
- **Evidence** `CopyTickVolume(_Symbol, PERIOD_H1, ...)` on XAUUSD+ spot returns **tick count**, not
  contracts (spot gold has no real volume). On copy failure (:131-134) it logs "PASSING" and returns
  true (fail-open). Applies only to Engulfing/VolBreakout/Crash (IsBreakoutPattern, :112-117).
- **Impact** The "institutional volume confirmed" log (:156) is misleading — it's tick-activity, a
  weak proxy on OTC gold. A real volume edge cannot be claimed. Narrow scope; fail-open means it
  rarely rejects.
- **Disposition** By-design (data limitation) — report with tick-volume caveat.

---

## I. NOTES / CROSS-LINKS FOR RECONCILIATION
- FILT-04 (RSI=50) materially interacts with WT-5 (sizing) and WT-1/2 (pattern edge): tiers are
  systematically deflated; any per-tier expectancy measured in the CSV reflects RSI-blind scoring.
- FILT-01/02/03/06 collectively mean "the short suppression chain" is NOT what protects the
  long-only result — the **registered plugin set** is. Hand to WT-8 (portfolio): the long bias is a
  single correlated bet enforced upstream of this gate stack.
- The genuinely sound, well-engineered piece here is the **regime hysteresis + thrash-cooldown**
  (CRegimeClassifier:176-230) and the **CConfluenceScorer L3 hard gate** — but the latter is dead on prod.
- Tick-volume caveat (XAUUSD+ spot): any "volume"/"flow" confluence (FILT-10, CConfluenceScorer ax6)
  is a tick-count proxy, not real orderflow. GC/MGC futures would be the real-volume proxy.
- CAdaptivePriceValidator (in scope) depends on CMarketCondition; referenced by CEnhancedTradeExecutor
  (execution layer) — confirm with U2 whether it is instantiated on the live exec path or dead.

STATUS: COMPLETE (static, source-only). All claims line-anchored above.
