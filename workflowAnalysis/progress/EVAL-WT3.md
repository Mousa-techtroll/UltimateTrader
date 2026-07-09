# EVAL-WT3 — Liquidity & Expansion engines (edge)

Clean-room, source-only, static. Scope: the LIVE engine modes —
`CLiquidityEngine` **OB-Retest** (+ its live **Displacement**) and
`CExpansionEngine` **Institutional-Candle BO**. Disabled-mode rationale read.
CSV (`all_trades_v15.csv`) = directional cross-reference ONLY (Model-1 artifact).

Files read (line-anchored evidence below):
- `Include/EntryPlugins/CLiquidityEngine.mqh` (1–1533, full)
- `Include/EntryPlugins/CExpansionEngine.mqh` (1–1184, full)
- `Include/MarketAnalysis/CMarketContext.mqh` (SMC accessors 500–760)
- `Include/MarketAnalysis/CSMCOrderBlocks.mqh` (OB/BOS scan 282–400, 770–876, 956–1020)
- `Include/PluginSystem/{CTradeStrategy,CEntryStrategy,CMajorStrategyEngine}.mqh` (enabled-default trace)
- `UltimateTrader.mq5` (wiring 676–699, 757–767)
- `UltimateTrader_Inputs.mqh` (mode toggles 319–357)

---

## WIRING (what is actually LIVE on prod)

`UltimateTrader.mq5:676–678`
```
g_liquidityEngine = new CLiquidityEngine(ctx, InpDisplacementATRMult, 45.0, g_scaledMinSLPoints);
g_liquidityEngine.ConfigureModes(true, InpLiqEngineOBRetest, InpLiqEngineFVGMitigation, InpLiqEngineSFP, InpUseDivergenceFilter);
```
With inputs (`UltimateTrader_Inputs.mqh:335–338`): Displacement=`true` (hardcoded 1st arg),
OB-Retest=`true`, FVG-Mit=`false`, SFP=`false`. → **LIVE: Displacement + OB-Retest.**

`UltimateTrader.mq5:697–698`
```
g_expansionEngine = new CExpansionEngine(ctx, InpInstCandleMult, InpCompressionMinBars, g_scaledMinSLPoints);
g_expansionEngine.ConfigureModes(InpExpInstitutionalCandle, InpExpCompressionBO, InpInstCandleMult, InpCompressionMinBars);
```
With inputs (`:354–355`): Inst-Candle=`true`, Compression=`false`. → **LIVE: Institutional-Candle BO.**
Composed Vol-BO / Session-BO sub-modes are gated behind `IsExpansionContext()` AND
`m_isEnabled` — but `m_isEnabled` defaults `true` (`CTradeStrategy:29`) and the router is
OFF on prod (`InpEnableEngineExpansion=false`), so the engine DOES run, and the composed
modes can fire if `IsExpansionContext()` is satisfied (vol-expanding + non-neutral H4).

**Resolved (was an open trap): `m_isEnabled` is `true` by default** (`CTradeStrategy:29`).
The `if(!m_isEnabled) return;` gate at `CExpansionEngine:446` is only meaningful under the
router (which sets it from activation weight). On the legacy prod path the Expansion engine
is NOT zero-signal. Cross-ref CSV confirms it traded (8 ENTRY rows).

---

## LIVE MODE 1 — CLiquidityEngine OB-Retest

**Edge class: REAL STRUCTURAL EDGE (low-confidence / effectively dormant).**
**Scorecard: 7/10** — fidelity 2, gold-direction 1, filter 1, look-ahead 2, robustness 1.

### Structural fidelity (2/2) — this is genuine SMC, not a proxy
`CLiquidityEngine.mqh:809–862` (bullish) / `871–924` (bearish). The trigger requires the
THREE real SMC ingredients simultaneously, AND-gated:
1. **Real order-block zone**: `m_context.IsInBullishOrderBlock()` (`:811`) → resolves to
   `CSMCOrderBlocks` price-in-zone test (`CMarketContext:547–559` → `CSMCOrderBlocks:326–351`).
   The OB itself is a textbook last-opposite-candle-before-impulse zone formed from CLOSED
   bars (`CSMCOrderBlocks:788–835`, loop `i=3…lookback`, refs `i`/`i+1`, body% + impulse≥ATR×mult
   gates). This is a correct OB definition, not a moving-average or S/R proxy.
2. **Real BOS/CHoCH in the same direction**: `(recent_bos == BOS_BULLISH || CHOCH_BULLISH)`
   (`:813`). `GetRecentBOS()` (`CMarketContext:728–736`) prefers BOS, falls back to CHoCH, both
   from `CSMCOrderBlocks` structural break detection on bars [1]/[2] (`:964–967`, closed).
3. **Rejection candle**: bar[1] closes in direction with wick≥30%×body OR body≥0.4×ATR
   (`:816–825`). A reasonable rejection proxy.

This is a faithful "BOS → return to OB → rejection" SMC continuation entry. The function
header (`:771–776`) names exactly this and the code matches it. **Answer to the key question:
OB-Retest correctly requires BOS/CHoCH + a real OB zone + a rejection candle — genuine SMC,
not a loose proxy.**

### Look-ahead cleanliness (2/2) — CLEAN
OB-Retest's inputs are all closed-bar:
- OB zone built from bars ≥3 (`CSMCOrderBlocks:788`), forming-bar [0] never referenced.
- BOS/CHoCH from bars [1]/[2] (`:964–967`).
- Rejection candle reads `open[1..2]/close[1..2]` etc. via `Copy*(…,0,3,…)` then uses index [1]
  (`CLiquidityEngine:795–798`, `:816`). ATR uses `atr_buf[1]` (`:377`).
- The "in OB / in zone" test uses live `SYMBOL_BID` (`CSMCOrderBlocks:306`) — a legit live quote
  for an entry decision, NOT a forming-HTF-bar read.
- **OB-Retest does NOT call `GetLocationPenalty()` or `ScoreLiquidityLevel()`** — the two
  forming-HTF-bar look-ahead helpers (`CLiquidityEngine:1517–1531` reads `iHigh/iLow(D1,0)`;
  `:1489–1512` reads `iHigh/iLow(W1,0)`). Those contaminate Displacement/FVG/SFP, NOT OB-Retest.
  So OB-Retest is the cleanest mode in the engine.

### Directional justification for gold (1/2)
H4-trend gated correctly: bullish only when `h4_trend != TREND_BEARISH` (`:809`), bearish only
when `!= TREND_BULLISH` (`:871`). The header comments (`:806–808`, `:868`) document that the
analyst removed and then RESTORED the BOS gate and the H4 gate after a bearish-OB-in-bull-market
loss (-$1,036, 73T, 35.6% WR). On structurally-bullish gold the bearish branch will rarely pass
the H4 gate, so the mode is effectively long-biased — correct posture. Not a full 2 because the
mode still ALLOWS shorts in `TREND_NEUTRAL` and there is no hard long-only lock like the discrete
candlestick plugins carry; it leans on the H4 gate + downstream orchestrator short-veto.

### Filter soundness (1/2)
Causal filters (BOS recency, OB membership, H4 trend) — sound. BUT note OB-Retest does NOT
self-gate on SMC confluence (it only STAMPS `engine_confluence` at `:850`/`:911` for telemetry;
the `>=40` confluence gate exists only in Displacement at `:620`/`:723`, not here). The real
confluence floor for OB-Retest is the downstream `CSignalValidator` (40 hard / 60 default gate).
Fixed `qualityScore=82` bull / `80` bear (`:846`/`:907`) is a hardcoded constant, not derived —
mild curve-fit smell, but it maps to the A-tier band and is not date-conditional. SL = ATR×0.8
(`:831`) + min-SL floor; TP = 3R fixed (`:837`). The 3R fixed target is optimistic for gold H1
(measured tier expectancy is small-positive, not 3R), but it is structurally consistent.

### Robustness cross-reference (1/2 — Model-1, directional only)
`all_trades_v15.csv` (791 trades): **`MODE_OB_RETEST` = 0 trades. The entire LiquidityEngine
EngineName = 0 ENTRY rows.** So in this artifact OB-Retest NEVER won the per-bar `qualityScore`
ranking and/or its triple-AND gate (in-OB AND matching-direction BOS AND rejection, all on the
same closed bar) never co-occurred. Credit 1 (not 0): structure is sound and look-ahead-clean,
but the realized contribution is ZERO — **the edge is real but dormant.** Caveat: this is one
Model-1 artifact, not a per-strategy isolation run; "0 trades" = starved in combined ranking,
not proven "0 signals ever." A proper verdict needs an isolation backtest.

**Net OB-Retest: a correctly-built, look-ahead-clean SMC continuation entry that contributes
nothing in practice. Positive edge is CREDITED per rubric (fidelity≥1 AND look-ahead=2 AND
robustness≥1) but with explicit low confidence — it is structurally valid and operationally
inert. Recommend an isolation run to decide keep-vs-cut; do not assume it helps.**

---

## LIVE MODE 2 — CLiquidityEngine Displacement (live, quarantined by look-ahead)

**Edge class: LOOK-AHEAD-DEPENDENT.**
**Scorecard: 4/10** — fidelity 2, gold-direction 1, filter 1, **look-ahead 0 (CAPS the edge)**,
robustness 0.

### Structural fidelity (2/2)
`:530–768`. Sweep of swing low/high on bars[2..4] (wick beyond swing−buffer, close back inside)
+ bar[1] displacement candle (body≥ATR×`InpDisplacementATRMult`=1.8) + close beyond swing+buffer
+ SMC confluence≥40 (`:620`/`:723`). This is a legitimate ICT sweep→displacement model and the
sweep/displacement reads are closed-bar (bars 1–4 from `Copy*(…,0,6,…)`).

### Look-ahead cleanliness (0/2 — CAPS edge claim)
Confirmed peer finding (ENG-01/ENG-02). Displacement's quality/score path consumes TWO
forming-HTF-bar reads that feed the live entry decision:
- `ScoreLiquidityLevel()` (`:1489–1512`) reads `iHigh/iLow(PERIOD_W1, 0)` — the FORMING weekly
  bar — and returns the `liq_score` whose `>=2` gate at `:587`/`:690` is a HARD entry gate.
  The forming-weekly high/low repaints intra-week, so whether a sweep "scores 2" can change
  after the fact → **look-ahead feeding a hard gate (ENG-02).**
- `GetLocationPenalty()` (`:1517–1531`) reads `iHigh/iLow(PERIOD_D1, 0)` — the FORMING daily
  bar — and adds to `qualityScore`/`engine_confluence` at `:651–652`/`:754–755` → **forming-day
  location penalty feeding the score (ENG-01).**
Per the rubric a look-ahead score of 0 caps the edge claim and quarantines the mode. Any apparent
Displacement edge cannot be trusted from a static read; it must be re-derived after the
forming-bar reads are changed to shift-1 (closed) HTF bars.

### Other axes
Gold-direction 1 (H4-gated, same posture as OB-Retest, leans on gate not hard-lock).
Filter 1 (`liq_score>=2`, regime factor, body/close/imbalance quality boosts are causal, but the
`liq_score` gate is itself the contaminated input). Robustness 0 — **`MODE_DISPLACEMENT` = 0
trades in the CSV**, so no directional support and a look-ahead-tainted score to boot.

**Net Displacement: quarantined. Structurally a real sweep+displacement model, but its hard
liq-score gate and its score both depend on forming-HTF-bar look-ahead, and it produced 0 trades
in the Model-1 artifact. Do not credit edge until the W1/D1 forming reads are fixed to shift-1
and an isolation backtest is run.**

---

## LIVE MODE 3 — CExpansionEngine Institutional-Candle BO

**Edge class: NAIVE/INDICATOR (range-breakout state machine) — NOT classic SMC.**
**Scorecard: 6/10** — fidelity 1, gold-direction 1, filter 1, look-ahead 2, robustness 1.

### Is it a real institutional-candle→consolidation→break, or a momentum/donchian BO?
`CExpansionEngine:672–889`. It IS a genuine two-state machine, NOT a plain donchian breakout:
- **IC_SCANNING** (`:693–744`): detect an "institutional candle" on bar[1] = body≥ATR×`m_inst_candle_mult`
  (=2.0) AND close in the top/bottom 25% of range (`(close−low)/range≥0.75`). This is a real
  "large directional displacement candle" definition (close-near-extreme), reasonable.
- **IC_CONSOLIDATING** (`:749–886`): require ≥2 and ≤5 bars of price staying INSIDE the IC
  range (`still_inside`), then a CLOSE beyond the IC extreme in the IC's direction (`:781`/`:832`)
  → entry. SL = opposite IC extreme (`:784`/`:835`), TP1 = 1×IC-range, TP2 = 2×IC-range (`:791`/`:842`).

So the structure is "big candle → it brackets a small consolidation → break of that bracket in
the big candle's direction" — a legitimate expansion/continuation pattern with a real range and a
real consolidation requirement. It is **closer to a Power-of-3 / institutional-candle continuation
than to a donchian breakout** (donchian = break N-bar extreme with no candle-quality or
consolidation requirement). The "donchian in disguise" suspicion is REJECTED.

**But it is not classic ICT SMC** — there is no BOS/CHoCH, no order-block zone, no liquidity-pool
draw, no premium/discount. It is a price-action volatility-expansion pattern. Hence fidelity 1
(faithful to its OWN named concept; not the broader SMC the engine sits beside). The direction
is set purely by the IC's own colour — there is no H4/trend alignment gate inside the IC mode
itself (unlike Compression-BO which checks H4 at `:988`). Direction-quality therefore rests on
the downstream orchestrator short-veto + the structurally-bullish gold tape.

### Look-ahead cleanliness (2/2 — CLEAN)
All OHLC reads use `Copy*(…,0,3,…)` then index [1]/[2] (closed) (`:684–688`, `:695`, `:754`).
ATR from `atr_buf[1]` (`:653–660`). State transitions advance on closed bars
(`m_ic_consolidation_bars++` per processed bar). The one caveat: `GetLocationPenalty()` (`:1168–1182`,
reads `iHigh/iLow(D1,0)` forming-daily) IS called on IC entry (`:817`/`:868`) — same ENG-01
forming-day look-ahead as the Liquidity engine. Impact here is BOUNDED: it only adjusts
`qualityScore`/`engine_confluence` by ±0 or −2 (a mid-range penalty), it is NOT a hard gate, and
the IC trigger (the break) is itself a hard structural close. So the look-ahead biases only the
RANKING/tier slightly, not the trigger. Net look-ahead = 2 with a documented minor ENG-01 leak
in the score (flag, do not quarantine — the trigger is clean).

### Other axes
Gold-direction 1 — IC mode has no internal trend gate; relies on tape + orchestrator veto.
Filter 1 — body≥2×ATR, close-near-extreme, 2–5 bar consolidation window are causal, not
date-fit; `qualityScore=76` fixed (`:806`/`:857`) hardcoded (mild). Day-type gate: off on
DAY_RANGE (`:453`) — sound (don't trade expansion in balance).
Robustness 1 — **CSV: 8 ENTRY rows, all `IC Breakout Long`, 4 closed EXITs all WIN**
(Total_R = 0.62, 0.23, 0.48, 1.09 → AvgR ≈ +0.605R), confirmation used, Confluence=70. n=4 is far
too small for significance — credit 1 (directionally positive, all-long matching gold's uptrend)
but explicitly note the sample is anecdotal.

**Net Institutional-Candle: a real (non-SMC) expansion-continuation state machine, look-ahead-
clean at the trigger (minor ENG-01 leak only in the score), tiny but positive directional sample,
all-long on bullish gold. CREDITED positive edge per rubric (fidelity≥1, look-ahead=2,
robustness≥1) at LOW confidence due to n=4.**

---

## DISABLED-MODE RATIONALE — data-driven or fit?

| Mode | Flag | Stated reason (input comment) | Read |
|---|---|---|---|
| FVG-Mitigation | `InpLiqEngineFVGMitigation=false` (`:336`) | "PF 0.61 in 2024–26, consistent loser" | **DATA-DRIVEN.** A specific OOS-period PF below 1.0 is a falsifiable kill-criterion. Consistent with gold-H1 FVGs behaving as momentum, not gaps to fill. Also the FVG code (`:937–1129`) is the loosest mode — fires on a `confluence>=55 && !in_OB` PROXY (`:978`) when no real FVG zone, AND consumes the ENG-01/ENG-02 look-ahead helpers. Disabling it removes a weak, partly-look-ahead-tainted mode. Sound. |
| SFP | `InpLiqEngineSFP=false` (`:337`) | "0% WR in 5.5mo backtest" | **DATA-DRIVEN.** 0% WR is an unambiguous kill. SFP (`:1139–1473`) is structurally the heaviest mode (fractal scan + volume gate + liq-score) but on gold-H1 spot it relies on TICK volume (not real volume — the orderflow caveat) and also consumes the forming-HTF look-ahead. A measured 0% WR justifies disabling regardless. Sound. |
| Compression-BO | `InpExpCompressionBO=false` (`:355`) | "PF 1.48 in 2023, PF 0.52 in 2024–26 — inconsistent, net −$240" | **DATA-DRIVEN, and the RIGHT call.** This is the textbook signature of a CURVE-FIT mode: profitable in one in-sample year, unprofitable OOS, net-negative overall. Disabling a regime-inconsistent, net-negative mode is correct anti-overfit discipline. (The Compression code at `:895–1133` is otherwise a legitimate BB-inside-Keltner squeeze-release with a rejection-wick filter and ADX>15 gate — the concept is fine, the gold-H1 edge is not.) Sound. |

**All three disable decisions are data-driven (each cites a falsifiable PF/WR/net figure), not
arbitrary fit.** The pattern is consistent and honest: keep the modes with positive/neutral OOS
behaviour, cut the ones that are inconsistent or negative OOS. No evidence of disabling winners or
keeping losers. The one nuance: these reasons come from PRIOR backtests (Model-1 lineage), so they
inherit the Model-1 caveat — but the DIRECTION of each decision (cut sub-1.0-PF / 0%-WR /
regime-inconsistent modes) is defensible on its face.

---

## LOOK-AHEAD-IMPACT SUMMARY (for reconciliation weighting)

| Mode | Live? | Look-ahead | Feeds | Trading impact |
|---|---|---|---|---|
| OB-Retest | YES | NONE | — | Clean. Edge real but 0 trades (dormant). |
| Displacement | YES | ENG-02 (W1 forming → `liq_score>=2` HARD gate) + ENG-01 (D1 forming → score) | gate + score | **CRITICAL to its edge claim** — caps edge to 0, quarantine. 0 trades in CSV. |
| Inst-Candle | YES | ENG-01 only (D1 forming → score, ±2) | score/tier only, NOT trigger | **MINOR** — biases ranking slightly; trigger is a clean closed-bar break. Flag, don't quarantine. |
| FVG-Mit | off | ENG-01+ENG-02 + proxy | n/a | moot (disabled). Reinforces the disable. |
| SFP | off | ENG-01+ENG-02 + tick-vol | n/a | moot (disabled). |

The ENG-01/ENG-02 forming-bar look-ahead lives in the shared helpers `GetLocationPenalty()`
(D1,0) and `ScoreLiquidityLevel()` (W1,0), duplicated in BOTH engines. Fixing them to shift-1 is
a one-line-each change that would (a) un-quarantine Displacement for a fair isolation test and
(b) remove the minor IC ranking bias. Recommend to Track-A/synthesis as a HIGH (look-ahead biasing
results) finding even though OB-Retest itself is clean.

---

## DEFECTS (plan schema)

### WT3-01 — Displacement live edge depends on forming-bar look-ahead (HIGH / Confirmed / Edge)
- **Location**: `CLiquidityEngine.mqh:587,690` (gate) ← `:1489–1512 ScoreLiquidityLevel` reads
  `iHigh/iLow(PERIOD_W1,0)`; `:651–652,754–755` (score) ← `:1517–1531 GetLocationPenalty` reads
  `iHigh/iLow(PERIOD_D1,0)`.
- **Evidence**: forming W1 high/low at index 0 repaints intra-week; `liq_score>=2` is a HARD entry
  gate, so a sweep can become tradeable/untradeable after the fact. Consuming decision = the
  bullish/bearish Displacement entry block.
- **Impact**: any backtested Displacement edge is optimistically biased; cannot be statically
  credited. Per rubric, look-ahead=0 caps Displacement at no-credit.
- **Check**: synthesis — change W1/D1 reads to shift-1, re-run isolation; compare trade count & R.
- **Disposition**: Confirmed-bug (look-ahead). NOTE: peer-unit ENG-01/ENG-02 — same root, recorded
  here for trading impact, not re-audited.

### WT3-02 — Institutional-Candle score carries the same ENG-01 forming-day leak (MEDIUM / Confirmed / Edge)
- **Location**: `CExpansionEngine.mqh:817,868` call `:1168–1182 GetLocationPenalty` → `iHigh/iLow(D1,0)`.
- **Evidence**: forming-daily range used for a ±2 mid-range penalty added to `qualityScore`/
  `engine_confluence`. Affects per-bar RANKING/tier, not the trigger (the IC range break is a
  closed-bar `close[1]` test).
- **Impact**: bounded — can flip which signal wins a tie or which tier is assigned; cannot fabricate
  an IC entry. Lower materiality than WT3-01.
- **Check**: shift-1 the D1 reads; confirm IC trade set unchanged at trigger level.
- **Disposition**: Confirmed-bug (minor look-ahead).

### WT3-03 — OB-Retest is structurally sound but operationally inert (MEDIUM / Likely / Edge-methodology)
- **Location**: `CLiquidityEngine.mqh:777–928`; CSV cross-ref.
- **Evidence**: `MODE_OB_RETEST` = 0 ENTRY rows in `all_trades_v15.csv` (791 trades); whole
  LiquidityEngine = 0 rows. Triple-AND gate (in-OB ∧ same-dir BOS/CHoCH ∧ rejection on one closed
  H1 bar) rarely co-occurs, and when a candidate exists it must still out-rank the candlestick
  plugins on `qualityScore` (OB-Retest fixed 82/80 vs Engulfing/PinBar dynamic). 
- **Impact**: a "live" mode that contributes ~nothing — dead weight / false sense of SMC coverage.
- **Check**: isolation backtest (OB-Retest only) → does it generate ANY signals, at what R? Decide
  keep-vs-cut. Model-1 caveat: 0 trades here ≠ 0 signals ever.
- **Disposition**: Needs-test.

### WT3-04 — OB-Retest fixed qualityScore + fixed 3R TP not derived (LOW / Suspected / Edge)
- **Location**: `:846,907` (`qualityScore=82/80`), `:837,898` (TP=3R fixed).
- **Evidence**: hardcoded constants; 3R is optimistic vs measured small-positive tier expectancy on
  gold H1. Not date-conditional, so low severity.
- **Check**: if WT3-03 keeps the mode, sweep TP multiple / derive score from rejection quality.
- **Disposition**: Needs-test.

### WT3-05 — IC mode has no internal trend-alignment gate (LOW / Likely / Edge)
- **Location**: `CExpansionEngine.mqh:781,832` — direction = IC candle colour only; no H4 check
  (contrast Compression-BO `:988` which does check H4).
- **Evidence**: a bearish IC in bull gold would fire short purely on the candle; only the downstream
  orchestrator short-veto / tape stops it. CSV shows 0 IC shorts ever traded → veto is holding, but
  the mode itself is not self-protecting.
- **Impact**: bounded by downstream veto; would matter if veto config changed.
- **Disposition**: By-design (relies on orchestrator), flag.

---

## FINAL EDGE GRADES (WT-3)

| Live mode | Edge class | /10 | Look-ahead | Confidence |
|---|---|---|---|---|
| **OB-Retest** (Liquidity) | Real structural edge (dormant) | **7** | Clean (2) | Low — 0 trades in artifact |
| **Displacement** (Liquidity) | **Look-ahead-dependent (quarantined)** | **4** | 0 — CAPS edge | None until W1/D1 fixed |
| **Institutional-Candle BO** (Expansion) | Naive/indicator (real expansion SM, not SMC) | **6** | Clean trigger (2), minor ENG-01 in score | Low — n=4 all-win |

**Disabled-mode rationale: all three (FVG-Mit, SFP, Compression-BO) are DATA-DRIVEN, not fit —
each cites a falsifiable sub-1.0-PF / 0%-WR / regime-inconsistent net-negative figure; the cut
direction is correct anti-overfit discipline (Model-1 lineage caveat on the underlying numbers).**

CSV is a Model-1 directional artifact: it shows Liquidity engine 0 trades, IC 4 closed wins
(+0.605R avg). Treat as directional only — not the verdict.
