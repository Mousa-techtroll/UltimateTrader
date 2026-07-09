# DT-7 — Concept Implementation Audit (SOURCE-ONLY, STATIC)

Reviewer: DT-7 (MQL5 implementation reviewer). Paired with WT-9 (trading-side judge).
Scope: Confirm HOW each named trading concept is ACTUALLY COMPUTED in source. Verdict each:
**Faithful / Approximate / Mislabeled-proxy / Not-implemented** with exact computation + file:line.
NO result metrics. NO docs/html/csv/git read. Source `.mq5`/`.mqh` only.

---

(in progress — appended incrementally)

## A. SMC core primitives — `Include/MarketAnalysis/CSMCOrderBlocks.mqh`

### A1. Order Block — verdict: **Mislabeled-proxy (toward Approximate)**
`ScanForOrderBlocks()` CSMCOrderBlocks.mqh:770-836. For a BULLISH OB it requires `close[i+1] < open[i+1]` (bar i+1 is a bearish candle), then an "impulse" `high[i] - low[i+1] >= atr * ob_impulse_atr_mult` (default 1.5), and body% `body/range >= ob_min_body_pct` (0.5). The zone stored is the FULL range `low[i+1]..high[i+1]` of that bearish candle (AddBullishOB :807).
- PARTIALLY faithful: it IS "last opposite-color candle before an impulse," computed on CLOSED bars (copy from index 0 but pattern read at i>=3, and i+1 is older). The opposite-color + impulse + body-filter is the genuine OB recipe.
- BUT the "impulse" is a SINGLE bar's range measured as `high[i]-low[i+1]` (only one candle i after the OB candle), not a multi-bar displacement leg, and crucially it is NOT tied to a BOS/structure break — a real OB is the origin of a move that breaks structure. Here it is "opposite candle + one big next candle ≥1.5 ATR." Zone = entire candle range incl. wicks, not body/open-to-close mitigation block. So it is a reasonable proxy for an OB candle but mislabels a 2-bar momentum pattern as an institutional order block. **Approximate at best; the missing displacement-leg/BOS link makes it a proxy.**

### A2. FVG / imbalance — verdict: **Faithful**
`ScanForFairValueGaps()` :841-877. Bullish FVG: `bullish_gap = low[i] - high[i+2]` and requires `>= fvg_min_gap_points*point` (default 50 pts). With series arrays, i is newer than i+2, so this is the genuine 3-candle gap: candle1(=i+2).high < candle3(=i).low. Bearish mirror `low[i+2] - high[i]` :868. This is the textbook 3-candle FVG (gap between candle1 and candle3 across the middle candle), with a minimum-size filter. Correct indexing and correct definition. Note: it does NOT verify the middle candle is a displacement/impulse bar (any 3 bars with a gap qualify), but the gap geometry itself is exactly right.

### A3. BOS / CHoCH / MSS — verdict: **Approximate**
Swing detection `DetectSwingPoints()` :882-951 is a real fractal pivot: bar i is a swing high if strictly greater than `lookback` bars on each side (lookback = bos_swing_lookback/2 = 10 each side default). Genuine confirmed pivots.
BOS `DetectBreakOfStructure()` :956-1004: compares closed bar [1] high/low vs `m_last_swing_high/low` with edge guard (`prev_high<=swing && current_high>swing`). This is a true break of a confirmed swing pivot on closed bars — faithful in mechanism. CHoCH here is just "BOS in the opposite direction of the previous BOS" (:973, :991) — a directional-flip relabel, not a structural HH/HL→LH/LL sequence test.
A SEPARATE `DetectCHoCH()` :666-729 DOES use a swing sequence: bullish CHoCH = `SL[1]<SL[2]` (prior lower low) then `SH[0]>SH[1]` (recent higher high). This is closer to real CHoCH but uses only the last 5 swings by array order (UpdateCHoCHSwingPoints :741-764 pulls swing_highs/lows independently, NOT interleaved by time), so the "then" (HH AFTER the LL) is NOT actually time-ordered — comment at :693 admits it should "verify the higher high is more recent" but no such check exists. So CHoCH is sequence-shaped but not strictly time-sequenced. **MSS as a named concept: Not-implemented** (no distinct market-structure-shift beyond BOS/CHoCH). Verdict Approximate: real pivots + real break test, but CHoCH/MSS are loose.

### A4. Liquidity sweep — verdict: **Approximate (naive penetration; NO reclaim)**
Pools = equal highs/lows: `ScanForLiquidityPools()` :1009-1097, ATR-derived tolerance (atr*0.03 clamped 20–80 pts) with `>= liquidity_min_touches` (2) — genuine equal-highs/lows clustering on closed bars.
Sweep detection `UpdateLiquidityPools()` :1102-1130: a pool is "swept" the instant closed bar [1] high > pool.price (or low < pool.price). This is NAIVE penetration only — there is NO reclaim/close-back-inside requirement. `CheckRecentLiquiditySweep()` :1135-1152 only adds a recency window (≤3 H1 bars). So "sweep" = "price traded through a prior equal-high/low within 3 bars," not "wick through THEN reclaim." **Inducement: Not-implemented** (no concept of inducement / trap liquidity beyond equal-highs pools). Verdict Approximate — pools are real, the THEN-reclaim half of the definition is absent here (reclaim is done elsewhere in sweep-reversal plugins — to confirm).

### A5. SMC score / supports_long-short — verdict: **Faithful to its own (non-standard) additive scheme**
`CalculateSMCScore()` :1652-1677 is a fixed additive tally (in bull OB +30, FVG +20, BOS ±25, CHoCH ±35) clamped ±100. GetConfluenceScore :517-597 base 50 + weighted adds. These are arbitrary point weightings, not a standard SMC metric, but they are computed exactly as written (no hidden proxy).

## B. Liquidity-engine displacement modes — `Include/EntryPlugins/CLiquidityEngine.mqh`

### B1. Displacement (Mode 1) — verdict: **Faithful**
`CheckDisplacement()` :530-769. Two genuine stages:
- Sweep: scan bars[2..4] for `low[i] < swing_low - sweep_buf && close[i] > swing_low` (bullish) — wick-through-prior-swing THEN close-back-above. This IS sweep+reclaim. :574 / bearish mirror :677.
- Displacement: bar[1] body `close[1]-open[1] >= atr*m_displacement_atr_mult` (default 1.5) AND `close[1] > swing_low + sweep_buf` :597. Impulse qualified by body-vs-ATR — genuine displacement, not "any large candle."
- Quality boosts (:601-616) add real structure: body/ATR ratio, close-position-in-candle (close_pos>=0.85), and an imbalance/gap check `low[1]-high[2]` (FVG between displacement bar and prior). swing_low/high come from `m_context.GetSwingLow/High()` (to confirm those are real pivots — delegated). Gated by SMC confluence>=40 and liq_score>=2. This is the most faithful SMC implementation in the codebase.

### B2. OB Retest (Mode 2) — verdict: **Approximate**
`CheckOBRetest()` :777-928. Requires `m_context.IsInBullishOrderBlock()` (the CSMCOrderBlocks zone from A1) + recent BOS/CHoCH same direction + rejection candle on bar[1] (`close>open` with lower_wick>=30% body OR body>=atr*0.4). The "OB" faithfulness inherits A1's proxy weakness (it's a 2-bar momentum zone, not a displacement-origin OB). The retest+rejection+BOS-confluence logic itself is sound. SL = ATR*0.8, TP = 3R — fixed, NOT structural (not placed below the OB). Verdict Approximate, capped by A1.

### B3. FVG Mitigation (Mode 3) — verdict: **Approximate / proxy-leaning**
`CheckFVGMitigation()` :937-1129. Primary trigger is EITHER `m_context.IsInBullishFVG()` (real FVG zone from A2 — faithful) OR a PROXY `fvg_proxy = (confluence>=55 && !in_bull_ob)` :978 — i.e. "high SMC score and not in an OB" stands in for "in an FVG." It does add an inline 3-candle structure re-check `low[3] > high[1]` :1000 (genuine gap geometry on bars 1&3) but if that fails it still fires when confluence>=50. So the mode CAN trigger with no actual FVG present (proxy path). Mitigation = price entering zone + rejection candle. Verdict Approximate because of the confluence-proxy fallback that mislabels a score threshold as an FVG fill.

### B4. SFP / Swing Failure (Mode 4) — verdict: **Faithful**
`CheckSFP()` :1139-1410+. Finds fractal high/low over bars[5..25], validates as true 2-bar fractal (:1213-1233), then bar[1] must `low[1] < fractal_low - sfp_buffer && close[1] > fractal_low` AND `close[1]>open[1]` (bullish) — wick-through-prior-extreme THEN close-back-inside. This is textbook SFP / sweep+reclaim. Plus VOLUME confirmation: bar[1] tick volume >= avg(bars[2..11]) hard gate (:1181) — note this is `CopyTickVolume` = MT5 tick count, NOT real traded volume. Optional RSI divergence (+5 quality). liq_score>=2 structural gate. Faithful SFP; the "volume" is tick-count only (see G).

### B5. Premium/Discount, OTE, killzones, Power-of-3 — verdict: **Mostly Not-implemented / crude proxy**
- Premium/discount: `GetLocationPenalty()` :1517-1531 computes `position = (bid - daily_low)/daily_range` of the CURRENT FORMING D1 bar (iHigh/iLow PERIOD_D1,0) and penalizes 30-70% (mid-range). This is a crude intraday-range-position proxy, NOT a premium/discount of a dealing range / swing leg. No 50% equilibrium of an impulse leg, no fib. Mislabeled-proxy at best.
- OTE (optimal trade entry / 0.62-0.79 fib): **Not-implemented** (no fib retracement entry zone anywhere in this engine).
- Killzones: only a coarse session label by GMT hour (`sfp_session = <8 ASIA, <16 LONDON, NY`) used for LOGGING only :1178 — not a killzone gate. **Not-implemented as a trade filter** here.
- Power-of-3 (AMD accumulation-manipulation-distribution): **Not-implemented**.
- Liquidity hierarchy `ScoreLiquidityLevel()` :1489-1512 IS real: prev-day H/L (atr*0.3 → score 3), week H/L (atr*0.5 → score 4), SMC-zone confluence → 3, else 1. Genuine multi-level liquidity map for sweep grading.

## C. Structure / trend / regime — CMarketContext, CTrendDetector, CRegimeClassifier

### C1. Swing points GetSwingHigh/Low — verdict: **Mislabeled-proxy**
CMarketContext.mqh UpdateSwingPoints ~:1076-1112. `m_swing_high = max(CopyHigh(H1, shift1, lookback=20))`, `m_swing_low = min(CopyLow(...))`. This is a ROLLING 20-bar high/low water-mark on closed H1 bars — NOT a confirmed fractal pivot. It is labeled "swing" but is a Donchian extreme. CRITICAL: this is the `swing_low/high` consumed by CLiquidityEngine.CheckDisplacement (B1) and CDisplacementEntry. So the "sweep of a swing" is actually "sweep of the 20-bar extreme." The sweep+reclaim mechanic (B1) stays valid, but the swept LEVEL is a rolling extreme, not a structural pivot. Downgrades the "swing" label to proxy.
(Note: CSMCOrderBlocks.DetectSwingPoints (A3) DOES use strict fractals, and CTrendDetector.DetectHigherHighs/LowerLows uses strict 4-neighbor fractals — so the codebase has BOTH a real fractal swing and a fake "swing"; the engines mostly consume the fake one.)

### C2. GetRecentBOS — verdict: **delegates to A3** (Approximate)
CMarketContext.mqh :728-736 wraps `m_smc_order_blocks.GetLastBOS()` (falls back to GetLastCHoCH). No independent computation. Inherits A3 verdict.

### C3. Trend (CTrendDetector) — verdict: **Faithful to a price-vs-EMA + structure model (NOT pure indicator-cross)**
CTrendDetector.mqh UpdateTimeframe ~:134-207. EMA20/EMA50 (MODE_EMA, PRICE_CLOSE) on D1/H4/H1, all read on CLOSED bar [1]. Bullish = close[1]>ma_fast AND close[1]>ma_slow; bearish mirror; plus "early" states gated on making_hh/making_ll. making_hh/ll (:212-283) ARE strict fractals (high[i] > i-1,i-2,i+1,i+2) with 50pt noise filter and 3-swing-ascending confirmation. This is a legitimate trend model combining price/EMA location with real HH/LL structure — more than a naive MA cross. Used as H4/D1 directional bias gate throughout.

### C4. Regime (CRegimeClassifier) — verdict: **Faithful (ADX+ATR+BBW with hysteresis)**
CRegimeClassifier.mqh ClassifyRegimeRaw ~:250-347, H4: iADX(14), iATR(14), iBands(20,2.0), closed bar [1]. VOLATILE if atr_ratio>1.3 or 2-bar-confirmed expansion; CHOPPY if ADX<15 & atr_ratio~1.0 & bbwidth<1.5%; TRENDING if ADX>20 (hold 18) & 0.8<=atr_ratio<=1.3; RANGING if ADX<15 (hold 18) & atr<avg*0.9; transition zone handled. atr_average = mean of 50 closed H4 bars. Genuine multi-factor regime classifier with hysteresis — this is real, not cosmetic. Distinct compression state is NOT explicit (CHOPPY ~ low-vol proxy; compression-vs-expansion lives in CExpansionEngine — pending).

## D. Premium/Discount, dealing range, draw-on-liquidity — CMarketContext (Multi-Strategy redesign)

### D1. Dealing range / equilibrium / premium-discount — verdict: **Faithful (now), but partial consumption**
CMarketContext.mqh D1DealingRangeHigh/Low :762-786 = highest-high / lowest-low over 20 CLOSED D1 bars (ICT IPDA 20-day window). GetEquilibrium :793-800 = midpoint. IsInDiscount/IsInPremium :802-814 = price below/above equilibrium. This is a genuine ICT dealing-range premium/discount on a real HTF window (decorrelated from the SL swing per Phase 2.4 comments). FAITHFUL computation.
Consumers (grep): CReversalSweepEngine (:112-117 location gate), CTrendContinuationEngine (:377-378 discount gate for longs), CRangeReversionEngine (:89-94), CConfluenceScorer (:219-220, +2 points if long-in-discount/short-in-premium). So premium/discount IS wired as a real gate/score in the multi-strategy engines and the scorer — NOT dormant. NOTE: the legacy CLiquidityEngine instead uses the crude GetLocationPenalty (B5) and does NOT use GetEquilibrium. So two parallel premium/discount implementations exist; the newer one is faithful, the engine-local one is a proxy.

### D2. Draw on liquidity — verdict: **Faithful (simple)**
GetDrawOnLiquidity :820-845 = nearest UN-swept prior-day/prior-week H or L in the trade direction (iHigh/iLow D1/W1 shift1). A real "draw on liquidity" target = nearest HTF pool. Consumed by CTrendContinuationEngine (:88), CReversalSweepEngine (:171), CConfluenceScorer (:204). Faithful, though limited to PDH/PDL/PWH/PWL (no equal-highs cluster as draw target).

## E. Sweep + reclaim across reversal/fade plugins (delegated read, exact triggers confirmed)

### E1. CFailedBreakReversal — verdict: **Faithful (strongest sweep+reclaim)**
CheckForEntrySignal :82+. Level = range-box edge or PDH/PDL. LONG requires: wick pierces level by >=0.20*ATR_H1 (:133), lower_wick>=35% of M15 range (:137-140), portion-below-level > body (rejection proof, :149-150), close back above level (reclaim, :154-158), closed-bar confirm close in [level+0.10ATR, level+0.75ATR] band (:160-164). Textbook wick-through-THEN-reclaim with rejection magnitude — most faithful sweep model in the repo.

### E2. CRangeEdgeFade — verdict: **Faithful**
:106+. Donchian box edge + sweep_tol. LONG: low[s]<box_low AND (box_low-low[s])<=sweep_tol (SHALLOW only — rejects real breaks) AND close[s]>box_low (reclaim). Closed M15 bars [0..1]. Genuine sweep+reclaim with a shallow-penetration gate.

### E3. CDisplacementEntry — verdict: **Faithful** (but swing = local rolling extreme bars[2..], :170-187, same proxy as C1)
:129+. Sweep low[i]<swing_low-buffer AND close[i]>swing_low (:210); displacement bar[1] body_abs>=atr*1.5 (:221-226). Sweep+reclaim+ATR-qualified impulse. Same as B1, standalone variant.

### E4. CLiquiditySweepEntry — verdict: **Faithful**
:94+. swing from bars[4..], low[i]<swing_low then close[i]>swing_low (:142-145) + M15 closed-bar[1] confirm >swing_low (:152). Pure wick-through-then-reclaim, closed-bar discipline. (swing = rolling min, proxy per C1.)

### E5. CReversalSweepEngine — verdict: **Faithful composer**
:349+. Cascades S6/standalone-sweep/rubber-band; AdoptSignal (:89-238) REQUIRES a structure-shift spine (BOS/CHoCH) OR valid premium/discount location before adopting (:95-132), re-anchors SL to swept swing+ATR buffer. Adds real confluence on top of sub-detector sweeps.

### E6. CFalseBreakoutFadeEntry — verdict: **Approximate / naive-penetration OUTLIER**
:163+. Trigger `recent_high > swing_high` (mere penetration, :258) then a rejection test on the FORMING-relative close (price_rejected: close < swing_high-0.10*range; pct_rejected). NO explicit wick-through-then-close-back-inside on a single closed candle; rejection evaluated on near-real-time close. The one fade plugin that is naive penetration + intrabar rejection rather than confirmed sweep+reclaim. Flag for WT-9 reconciliation.

## F. Expansion / range box / CRT / breakout — CExpansionEngine, CRangeBoxDetector/Entry, session/vol breakout

### F1. Expansion / volatility expansion — verdict: **Approximate (squeeze-release, not ATR-acceleration)**
CExpansionEngine.mqh squeeze :925 `current_squeeze = (bb_upper[1] < keltner_upper && bb_lower[1] > keltner_lower)` — Bollinger(20,2.0) fully inside Keltner(EMA20 ± 1.5*ATR), the classic TTM-squeeze geometry. Requires >=3 consecutive squeeze bars (:940) then a close outside as release. This IS a genuine compression(squeeze)-then-release model — BUT "expansion" is defined purely by the BB-inside-Keltner squeeze ending, NOT by an ATR-acceleration ratio (current ATR vs longer-period ATR) as one might expect from "volatility expansion." ADX>15 momentum gate, rejection-wick filter. Verdict Approximate: a real squeeze-release, reasonably labeled, but the "expansion" measurement is squeeze-exit not a vol-ratio surge. (Regime classifier separately flags REGIME_VOLATILE via atr_ratio>1.3 — that part IS an ATR-ratio expansion, see C4.)

### F2. Range box / consolidation — verdict: **Faithful (as consolidation), Mislabeled if read as CRT**
CRangeBoxDetector.mqh :121-135 = 30-bar H1 Donchian (max high / min low); validates height 0.8–2.5*ATR_D1, width-stability <35% drift, >=4 edge touches in outer 15% (>=1 each side), stealth-trend guard (6/8 M15 closes same side of EMA20). This is a rigorous consolidation/range definition — faithful AS a range box. CRangeBoxEntry adds entry in outer 25%, TP 80%/SL 20% of range, ADX<20, ATR<30. Good consolidation model.

### F3. CRT (Candle Range Theory) — verdict: **Not-implemented**
Repo-wide grep: no CRT model. Genuine CRT = a single defining candle's range, sweep one side, target the opposite side. What exists is MULTI-bar Donchian consolidation (F2). "Range box" is consolidation, NOT CRT. No enum/pattern/mode for candle-range-theory. Explicitly absent — flag for WT-9.

### F4. Session breakout — verdict: **Faithful**
CSessionBreakoutEntry: Asian range = M15 high/low within GMT Asian window (:250-315), validated 0.5–3.0*ATR_H1. London break (:353): `close[1] > asian_high + 0.3*ATR && open[1] < asian_high` (close-beyond + open-on-opposite-side = real displacement break, not naive touch). 2.0R. NY continuation off London close + macro gate. Real session-liquidity breakout.

### F5. Volatility breakout — verdict: **Faithful**
CVolatilityBreakoutEntry: 20-bar Donchian + Keltner(EMA20 ± 1.5*ATR20); long if close > donchian_high+50pt OR close > keltner_upper+50pt (:245); ADX>=25 gate; REGIME_VOLATILE only; 2.5R. Close-beyond-channel breakout — faithful (no extra displacement-body requirement, but close-beyond is the standard channel-breakout trigger).

## G. Orderflow / volume / volume-profile — CMacroBias, CMomentumFilter, Volumes.mqh, repo-wide

### G1. "Volume" source — verdict: **TICK-COUNT only (correctly, but mislabeled wherever called "volume")**
Every volume-consuming decision uses MT5 tick COUNT:
- CMomentumFilter.mqh :211 `iMFI(_Symbol, PERIOD_H1, period, VOLUME_TICK)` — MFI fed by tick volume.
- CLiquidityEngine.mqh :1161 `CopyTickVolume(...12...)` — the SFP volume gate (B4).
- CSignalValidator.mqh :130 `CopyTickVolume(... PERIOD_H1 ...)`.
A `CRealVolumeBuffer` (CopyRealVolume) class exists in TimeSeries.mqh but is NEVER instantiated in any strategy. So all "volume confirmation" = tick count. This is CORRECT engineering for MT5 spot gold (true traded volume / real volume is broker-feed-dependent and typically unavailable on spot-gold CFD), but anywhere the code/comments call it "volume" it is tick count, not contracts. Verdict: faithful-to-tick-volume, but it is NOT a proxy for true traded volume / delta.

### G2. CVD / delta / footprint / absorption / DOM — verdict: **Not-implemented**
Repo grep: zero computed implementations. The only hits are passive error-code enum names (CErrorHandler.mqh ~:343, codes 4800-4804 "Depth of Market..."). No OnBookEvent handler, no MarketBookAdd/MarketBookGet, no CumulativeDelta/footprint/absorption structures. On MT5 spot gold these CANNOT be computed from tick count anyway (no bid/ask aggressor or true delta). Confirmed absent — flag for WT-9.

### G3. Volume profile / POC / value-area / HVN-LVN / TPO — verdict: **Not-implemented**
Repo grep: zero references in Include/ or *.mq5. No distribution-over-window, no POC/VAH/VAL, no TPO. Absent.

### G4. Macro bias — verdict: **Faithful (true intermarket) with self-referential fallback**
CMacroBias.mqh: PRIMARY reads DXY (Dollar Index) H4 close vs iMA(DXY,H4,50,SMA) :81/:192-207 (DXY bearish→gold +2, bullish→-2) and VIX H4 (>20 →+1, <15 →-1) :248-268. Genuine intermarket macro (inverse-USD). FALLBACK (:281-316) when DXY/VIX symbols unavailable: XAUUSD self-referential — live BID vs own D1 EMA200 + H4 EMA20/50 slope (±2/±1). So it is true macro IF the broker provides DXY/VIX symbols; otherwise it degrades to a self-referential HTF trend proxy. Does NOT read US10Y / yields / real-rates. Note: relies on broker symbol names "DXY"/"VIX" being present (SymbolSelect) — broker-dependent.

### G5. Momentum — verdict: **Faithful (multi-oscillator), not a single cross**
CMomentumFilter.mqh: composite score from RSI(14) H1+H4, MACD(12,26,9) H1, Stoch(14,3,3) H1, CCI(20) H1, MFI(14,VOLUME_TICK) H1, mapped to -100..+100 (:374-432); gates block longs if score<=-50 or RSI>75 on both TFs, etc. Adaptive: filter only ACTIVE when high_atr (atr>baseline*1.3) OR high_adx (>30), else bypasses (:292-298). Real multi-factor momentum filter; the MFI leg uses tick volume (G1).

---

## H. CONCEPT-FIDELITY MATRIX (DT-7 implementation verdicts)

| Concept | Where | Verdict | One-line why |
|---|---|---|---|
| Order block | CSMCOrderBlocks ScanForOrderBlocks :770 | Mislabeled-proxy→Approximate | Opposite candle + 1-bar ≥1.5ATR impulse + body%; zone=full candle; NOT tied to BOS/displacement-leg |
| FVG / imbalance | CSMCOrderBlocks ScanForFairValueGaps :841 | Faithful | True 3-candle gap low[i]-high[i+2] with min-size; correct series indexing |
| BOS | DetectBreakOfStructure :956 + fractal swings :882 | Faithful (mechanism) | Strict fractal pivots, closed-bar break with edge guard |
| CHoCH | DetectCHoCH :666 / BOS-flip :973 | Approximate | Swing-sequence shaped but not strictly time-ordered; also a mere BOS-direction flip elsewhere |
| MSS | — | Not-implemented | No distinct market-structure-shift beyond BOS/CHoCH |
| Displacement | CLiquidityEngine CheckDisplacement :530; CDisplacementEntry | Faithful | Sweep+reclaim THEN bar[1] body≥1.5*ATR; quality boosts incl. imbalance gap |
| Liquidity sweep (SMC pools) | UpdateLiquidityPools :1102 | Approximate | Equal-H/L pools real; sweep=naive penetration, NO reclaim (recency-gated only) |
| Liquidity sweep (entry plugins) | CFailedBreakReversal/CRangeEdgeFade/CLiquiditySweepEntry/SFP | Faithful | Wick-through-prior-extreme THEN close-back-inside, closed-bar |
| False-breakout fade | CFalseBreakoutFadeEntry :163 | Approximate | Naive penetration + intrabar rejection; no confirmed closed-bar reclaim (OUTLIER) |
| Inducement | — | Not-implemented | No trap/inducement concept beyond equal-highs pools |
| Premium/discount, dealing range | CMarketContext D1 IPDA :762-814 | Faithful | 20-bar D1 range, equilibrium midpoint, in-discount/premium; wired into scorer + 3 engines |
| (engine-local prem/disc) | CLiquidityEngine GetLocationPenalty :1517 | Mislabeled-proxy | Forming-D1 range-position 30-70% penalty; not equilibrium of a leg |
| Draw on liquidity | CMarketContext GetDrawOnLiquidity :820 | Faithful (simple) | Nearest un-swept PDH/PDL/PWH/PWL in direction |
| OTE (fib 0.62-0.79) | — | Not-implemented | No fib-retracement entry zone anywhere |
| Killzones | session label only (logging) | Not-implemented (as gate) | GMT-hour label for logs; not a trade-time filter in engines |
| Power-of-3 / AMD | — | Not-implemented | No accumulation-manipulation-distribution model |
| CRT (candle range theory) | "range box" = Donchian consolidation | Not-implemented | Multi-bar consolidation relabeled; no single-candle CRT |
| Expansion (compression→) | CExpansionEngine squeeze :925 | Approximate | BB-inside-Keltner squeeze-release (real), but "expansion"=squeeze-exit not ATR-ratio |
| Range box / consolidation | CRangeBoxDetector :121 | Faithful (as consolidation) | 30-bar Donchian + height/width/touch validation |
| Session breakout | CSessionBreakoutEntry :353 | Faithful | Asian-range break, close-beyond + open-opposite-side |
| Volatility breakout | CVolatilityBreakoutEntry :245 | Faithful | Donchian+Keltner close-beyond, ADX>=25, VOLATILE-only |
| Trend / HTF bias | CTrendDetector :134 | Faithful | EMA20/50 price-location + strict HH/LL fractal structure, closed-bar |
| Regime | CRegimeClassifier :250 | Faithful | ADX+ATR-ratio+BBW with hysteresis, H4 closed-bar |
| Macro (intermarket) | CMacroBias :192 | Faithful (+fallback) | DXY-H4-vs-MA50 + VIX; self-ref XAUUSD fallback; no yields |
| Momentum | CMomentumFilter :374 | Faithful | RSI/MACD/Stoch/CCI/MFI composite, adaptive on/off |
| Volume = tick count | iMFI VOLUME_TICK, CopyTickVolume | Faithful-to-tick (not true volume) | All "volume" gates are MT5 tick COUNT; CopyRealVolume class unused |
| CVD / delta / footprint / absorption / DOM | — | Not-implemented | Only error-code enum names; no OnBookEvent/MarketBook |
| Volume profile / POC / VA / HVN-LVN / TPO | — | Not-implemented | Zero references repo-wide |

### Cross-cutting implementation notes for Phase-2 reconciliation
1. TWO "swing" definitions coexist: STRICT fractals (CSMCOrderBlocks, CTrendDetector) vs ROLLING 20-bar extreme (CMarketContext.GetSwingHigh/Low). The displacement/sweep ENGINES consume the ROLLING one, so "sweep of a swing pivot" is really "sweep of the 20-bar Donchian extreme." Sweep+reclaim mechanic faithful; swept LEVEL is a proxy.
2. TWO premium/discount definitions coexist: faithful D1-IPDA equilibrium (CMarketContext, used by scorer + multi-strategy engines) vs crude forming-D1 range-position penalty (legacy CLiquidityEngine). 
3. SMC "sweep" inside CSMCOrderBlocks is naive penetration; the FAITHFUL sweep+reclaim lives in the entry plugins, not the SMC analytics module.
4. OB faithfulness is the weakest SMC primitive (2-bar momentum zone, not displacement-origin/BOS-linked); FVG is the strongest (textbook geometry).
5. All "volume" is tick count — acceptable for MT5 spot gold, but no true orderflow/CVD/profile is or can be computed from it.
