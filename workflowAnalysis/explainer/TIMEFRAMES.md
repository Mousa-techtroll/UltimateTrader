# UltimateTrader — Timeframe Map (Source-Verified)

> **Purpose.** For **every** decision / gate / indicator / entry strategy / risk-dial / exit in the
> LIVE production decision path of the UltimateTrader MQL5 XAUUSD EA, this document states the exact
> **chart timeframe(s)** the data comes from, the **specific data/indicator** read, and a real
> `file:line` anchor. Where it matters for repaint, it notes **forming bar `[0]` vs closed bar `[1]`**.
>
> **Method.** Every entry below was confirmed by reading the actual `.mq5`/`.mqh` source on the repo
> state at authoring (not inferred from docs). The decision *structure* (node IDs N1…, O1…, X1…) is
> the one in `workflowAnalysis/trading-decision-flow.md`; this file adds the **timeframe** behind each
> node. The "WHAT each decision is" lives in `explainer/E1-entries.md` / `E2-risk-money.md` /
> `E3-exits-trailing.md` / `E4-framing-glossary.md`.
>
> **Symbol/account assumptions** (stated, not silent): symbol `XAUUSD+`; **primary decision TF = H1**
> (`iTime(_Symbol, PERIOD_H1, 0)` is the new-bar gate); one entry decision per closed H1 bar; hedging
> vs netting not branched on. Default-config inputs (`UltimateTrader_Inputs.mqh`): `InpMAFastPeriod=10`,
> `InpMASlowPeriod=21`, `InpADXPeriod=14`, `InpATRPeriod=14`, `InpRSIPeriod=14`, `InpBrokerGMTOffset=3`,
> Asian range 0–7 GMT, London open 8 GMT, NY open 13 GMT, Silver Bullet 15–16 GMT.

---

## Headline findings (read this first)

- **Primary decision cadence = H1.** The EA does all once-per-bar logic on a new **H1** bar.
- **Trend / bias uses three TFs at once.** `CTrendDetector` maintains EMA(10/21) **and** ATR(14) on
  **D1, H4 and H1 simultaneously**. `GetTrendDirection()`/`GetDailyTrend()` = **D1**;
  `GetH4Trend()`/`GetH4TrendDirection()` = **H4**; H1 trend is also tracked. All read **closed bar `[1]`**.
- **The "200-EMA" filter is H1, not D1 — despite the input name `InpUseDaily200EMA`.**
  `GetMA200Value()` returns `iMA(_Symbol, PERIOD_H1, 200, EMA, CLOSE)` read at **closed bar `[1]`**.
  Both the long-bias validator gate AND the counter-trend ×0.5 risk halving use this **H1** value
  (compared against the **live Bid/Ask**).
- **Regime classifier = H4.** `CRegimeClassifier` reads ADX(14) / ATR(14) / Bollinger(20,2.0) all on
  **H4**, closed bar `[1]`; ATR-average is the **50-bar H4** mean. So the public `GetADXValue()`,
  `GetATRCurrent()`, `GetATRAverage()` are all **H4**.
- **ATR genuinely mixes timeframes.** Regime ATR (and therefore the shock gate's `GetATRCurrent()`
  and the orchestrator's short ATR floor) is **H4-current `[1]` vs H4-50-bar-average**. But
  `GetATRVelocity()` (the ATR-acceleration risk boost) is computed on **H1** (6 closed bars). And the
  shock detector compares an **H1** bar-range and an **M5** bar-range *against an H1 closed ATR* —
  an explicit cross-TF (M5÷H1) ratio.
- **Macro bias (DXY/VIX) = H4.** `CMacroBias` reads `CopyClose(DXY, PERIOD_H4, …)` and
  `CopyClose(VIX, PERIOD_H4, …)` at **forming bar `[0]`**; price-fallback uses D1-EMA200 `[1]` + H4
  EMA(20/50) `[1]` vs **live Bid**.
- **Momentum (RSI/MACD/Stoch/CCI/MFI) is H1** (RSI also on H4), all read at **forming bar `[0]`**.
- **SMC (order blocks / FVG / liquidity / BOS / swings) = H1**; HTF confluence optionally adds D1/H4.
  Dealing range is **D1** (20-bar IPDA). The SL-anchor swing cache is **H1** closed `[1..N]`.
- **Liquidity levels:** PDH/PDL = **D1** `[1]`; PWH/PWL = **W1** `[1]`.
- **Sessions / Asian range:** the GMT session clock is `CSessionEngine.GetGMTHour()`. The **Asian range
  is built on M15** bars filtered by GMT hour; session breakout triggers are **H1**; Silver Bullet /
  London-close use **M15** FVGs/extremes.
- **Most entry plugins trigger on H1 closed `[1]`** with an **H4** trend gate. Exceptions:
  **S3 RangeEdgeFade and S6 FailedBreakReversal trigger on M15** (with H1 ATR for sizing and D1 PDH/PDL
  for S6); **CrashBreakout** gates on a **D1** death-cross and triggers off **H1** indicators vs **live**
  price; **LiquiditySweepEntry** sweeps on H1 but **confirms on M15 `[1]`**.
- **Trailing/exits are H1.** Chandelier ATR + highest-high/lowest-low lookback are **H1** closed
  `[1..lookback]`; ATR trailing is **H1** `[1]`; the regime-aware exit checks **H1 EMA(50)** vs **H1
  close `[1]`**. The TP ladder and breakeven are **R-multiple** (no TF). Max-age and weekend-close are
  **wall-clock / server time**, not chart bars. The lot-size formula reads **no chart TF at all**
  (pure tick-value math). EC v3 reads **no chart TF** (account equity curve only).

---

## A. The clock / new-bar trigger

- **New-decision timeframe = H1.** `datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0); isNewBar = (currentBarTime != g_lastBarTime)` — forming H1 bar `[0]` open time is the trigger.
  - file: `UltimateTrader.mq5:1449-1451`
  - Seed so the first tick fires: `g_lastBarTime = iTime(_Symbol, PERIOD_H1, 1)` (closed `[1]`). file: `UltimateTrader.mq5:488`
- **Once-per-H1-bar work:** reset `g_session_quality_factor=1.0`; `g_stateManager.UpdateMarketState()` (refreshes all of §B); range-box update; day-type classify; Friday block; pending-confirmation; new-signal generation. file: `UltimateTrader.mq5:1454-1465`, `:1573-1587`
- **Breakout-probation hold check** (DORMANT default) reads **H1 closed `[1]`**: `iClose(_Symbol, PERIOD_H1, 1)`. file: `UltimateTrader.mq5:1480`
- **Per-tick work** (outside the H1 gate): orphan adoption, file/CSV signals, position management, risk-limit check, display. file: `UltimateTrader.mq5:2109-2294`
- **Context's own internal once-per-H1 gate:** `iTime(_Symbol, PERIOD_H1, 0)`. file: `CMarketContext.mqh:308`, `:1034`

---

## B. Market context (`CMarketContext` + analyzers)

### Trend / bias — `CTrendDetector.mqh`
- **D1 trend** = EMA(10) fast / EMA(21) slow on **D1**, plus ATR(14) D1 for strength. Read at **closed `[1]`**. Exposed as `GetTrendDirection()` / `GetDailyTrend()`.
  - handles: `CTrendDetector.mqh:72-73` (`iMA PERIOD_D1`), `:82` (`iATR PERIOD_D1`); update `:105-107`; getter `:115`
- **H4 trend** = EMA(10/21) on **H4** + ATR(14) H4. Closed `[1]`. Exposed as `GetH4Trend()` / `GetH4TrendDirection()`.
  - handles: `CTrendDetector.mqh:75-76`, `:83`; getter `:116`
- **H1 trend** = EMA(10/21) on **H1** + ATR(14) H1. Closed `[1]`.
  - handles: `CTrendDetector.mqh:78-79`, `:84`
- **Trend ATR read** uses closed `[1]`. file: `CTrendDetector.mqh:308-310`

### 200-EMA "bias" filter — **H1** (NOT D1)
- `m_handle_ma200_h1 = iMA(_Symbol, PERIOD_H1, 200, EMA, CLOSE)`. file: `CMarketContext.mqh:277`
- `GetMA200Value()` returns `ma200_buf[1]` (**closed `[1]`**). file: `CMarketContext.mqh:478`, read at `:1069-1070`
- The `InpUseDaily200EMA=true` input name is a misnomer — it gates use of this **H1** EMA, not a D1 one.

### Regime classifier — **H4** — `CRegimeClassifier.mqh`
- ADX(14) **H4**, ATR(14) **H4**, Bollinger(20,2.0) **H4**. file: `CRegimeClassifier.mqh:105-107`
- Reads closed `[1]`: `atr_current = atr[1]`; `atr_average` = mean of the **50** H4 bars `[1..50]`; BB `[1]`; close `CopyClose(PERIOD_H4,0,2)` → `[1]`. file: `:140`, `:148`, `:152-156`
- Volatility-expanding flag = `atr_current > atr_average * 1.3` (H4). file: `:163`
- Public getters: `GetADXValue()`→`GetADX()` (H4 `[1]`), `GetATRCurrent()`→`GetATR()` (H4 `[1]`), `GetATRAverage()` (H4 50-bar). file: `CMarketContext.mqh:401-415`, `CRegimeClassifier.mqh:239-240`

### Macro bias — **H4** — `CMacroBias.mqh`
- DXY MA(50) **H4**; DXY close **H4** `[0]`; DXY highs **H4** `[0]` (30-bar HH). file: `CMacroBias.mqh:81`, `:192-193`, `:210`
- VIX close **H4** `[0]`. file: `CMacroBias.mqh:253`
- Price-fallback: D1-EMA200 `[1]` + H4-EMA(20/50) `[1]` vs **live Bid** (intentional front-run). file: `CMacroBias.mqh:100-102`, `:293-301`, price `:298`

### Momentum — mostly **H1** (RSI also **H4**) — `CMomentumFilter.mqh`, forming `[0]`
- RSI(14) **H1** and **H4**. file: `CMomentumFilter.mqh:198-199`; read `[0]` `:320-324`
- MACD(12/26/9) **H1** `[0]`; Stoch(14/3/3) **H1** `[0]`; CCI(20) **H1** `[0]`; MFI(14) **H1** `[0]`. file: `:202`,`:205`,`:208`,`:211`; reads `:331-361`
- ATR(14) **H1** baseline (50-bar avg) + ADX(14) **H1** for adaptive threshold. file: `:214-215`, `:250`
- RSI divergence on **H1** including forming `[0]`. file: `:446-449`

### ATR — the timeframe-mixing detail
- **Regime ATR (the public `GetATRCurrent` / `GetATRAverage`) = H4** current `[1]` vs **H4 50-bar** average. file: `CRegimeClassifier.mqh:106`, `:148`, `:152-156`
- **ATR velocity = H1.** `GetATRVelocity()` computes true-range on **6 closed H1 bars** (`iHigh/iLow/iClose PERIOD_H1` shift `[1..6]`), recent-3 vs older-3 % change. file: `CMarketContext.mqh:643-663`
- **Vol-regime manager ATR = H1** (current `[0]`; 120-bar history `[1..120]`). file: `CVolatilityRegimeManager.mqh:182`, `:232-238`, `:386-390`
- **Net:** "H4-current vs H1-average" framing is real in the sense that regime decisions are H4 ATR while the velocity/vol-regime dials read H1 ATR — the two coexist in the same bar.

### ADX value
- Public `GetADXValue()` = **H4** ADX(14) `[1]` (regime classifier). file: `CRegimeClassifier.mqh:105`, getter `CMarketContext.mqh:401-404`
- (Crash detector keeps a *separate* H1 ADX(14) for its Rubber-Band logic — see §C CrashBreakout.)

### SMC — order blocks / FVG / liquidity / BOS / swings — **H1** — `CSMCOrderBlocks.mqh`
- ATR(14) **H1** for zone strength. file: `CSMCOrderBlocks.mqh:246`
- Order blocks / FVG / liquidity pools: `CopyHigh/Low/Open/Close(_Symbol, PERIOD_H1, 0, N)` — scans include forming `[0]`. file: `:779-782`, `:848-849`, `:889-890`
- BOS / CHoCH and swing detection use **H1 closed `[1]`/`[2]`** only (no forming bar), timestamps `iTime(PERIOD_H1,1)`. file: `:964-967`, `:1019-1020`, `:1105-1107`
- HTF confluence optionally adds **D1/H4** when `InpSMCUseHTFConfluence` is on.

### Choppiness / dealing range
- Choppiness Index CI(10) on **H1** closed `[1..10]`. file: `CMarketContext.mqh:673-689`
- Dealing range (ICT IPDA): highest-high / lowest-low over **D1** closed `[1..20]` (`InpDealingRangeD1Lookback=20`). file: `CMarketContext.mqh:762-786`
- SL-anchor swing cache: **H1** closed `[1..lookback]`. file: `CMarketContext.mqh:1092-1093`

### Session ranges & liquidity levels
- **Asian range built on M15** (see §C CSessionEngine). file: `CSessionEngine.mqh:567-597`
- **PDH/PDL = D1 `[1]`**; **PWH/PWL = W1 `[1]`**. file: `CMarketContext.mqh:823-826`

### Crash / bear regime (used by validator bypass & CrashBreakout)
- Death cross on **D1**: EMA(50) `[1]` vs EMA(200) `[1]`, and `iClose(PERIOD_D1,1)`. file: `CCrashDetector.mqh:110-111`, `:210-219`
- Rubber-band on **H1**: EMA(21) `[1]`, ATR(14) `[1]`, ADX(14) `[1]`, vs **live Bid**. file: `CCrashDetector.mqh:112-114`, `:296-312`

---

## C. Each live entry strategy

> Pattern plugins are registered when `InpSignalSource ∈ {PATTERN, BOTH}` (default BOTH ⇒ live).
> Most default `m_timeframe = PERIOD_H1` in their constructor and gate on the **H4** trend from context.

### Engulfing — `CEngulfingEntry.mqh`
- **Trigger TF = H1.** `m_timeframe = PERIOD_H1` (ctor default). file: `CEngulfingEntry.mqh:46`; OHLC `CopyOpen/High/Low/Close(_Symbol, m_timeframe, 0, 4)` `:138-141`
- Pattern read on **closed `[1]`** (signal candle) vs `[2]` (prior). file: `:162-171`
- ATR(14) **H1**, uses `atr_buf[1]`. file: `:76`, `:147-150`
- **Gate:** H4 trend via `m_context.GetH4Trend()`. file: `:155`

### PinBar — `CPinBarEntry.mqh`
- **Trigger TF = H1**, pattern on closed `[1]`. file: `CPinBarEntry.mqh:47`, OHLC `:133-136`, pattern `:140-142`
- ATR(14) **H1**. file: `:71`
- **Gates:** H4 trend `:151`; **H1 proximity** filter `iHighest(_Symbol, PERIOD_H1, MODE_HIGH, lookback, 1)` + `iHigh(PERIOD_H1,…)` `:178-181`; Asia/NY session gates via `GetGMTHour()` `:232`, `:240`.

### MA Cross — `CMACrossEntry.mqh`
- **Trigger TF = H1.** Fast MA(10) + slow MA(21) + ATR(14) all on **H1**. file: `:52`, `:81-83`
- Cross detected on **closed bars `[2]`→`[1]`**; ATR `[1]` for SL. file: `:184`, `:157-160`
- **Gates:** H4 trend `:165`; NY session via `GetGMTHour()` `:176-177`.

### Range-Edge Fade — **S3** — `CRangeEdgeFade.mqh`
- **Trigger TF = M15** (hardcoded). Reads `CopyHigh/Low/Close/Open(_Symbol, PERIOD_M15, 1, 2)` — two completed M15 candles. file: `:134-137`
- RSI(14) **M15** (`[1]`); **ATR(14) H1** (`[1]`); **ATR(14) M15** (`[1]`) — **mixes M15 trigger with H1 ATR for sizing**. file: `:78-80`; buffer reads `:36`,`:44`,`:52`
- **Gates:** H1-validated range box; stealth-trend protection. file: `:114`, `:117`

### Failed-Break Reversal — **S6** — `CFailedBreakReversal.mqh`
- **Trigger TF = M15** (hardcoded). `CopyHigh/Low/Close/Open(_Symbol, PERIOD_M15, 1, 3)` — last 3 completed M15. file: `:99-102`; confirm bar `m15_close[0]` (= shift 1, last closed M15) `:161`,`:220`
- **ATR(14) H1** (`[1]`) for spike threshold + **ATR(14) M15** (`[1]`). file: `:59-60`; spike `=0.20*ATR_H1` `:104`
- **Gate:** **D1** PDH/PDL via `iHigh(_Symbol, PERIOD_D1, 1)` / `iLow(_Symbol, PERIOD_D1, 1)`. file: `:120-121`

### Volatility Breakout — `CVolatilityBreakoutEntry.mqh`
- **Trigger TF = H1.** Donchian channel from `m_timeframe`=H1, breakout on `closes[1]` (**closed `[1]`**). file: `:72`, `:223-235`, `:245-246`
- **Keltner on H1** (EMA + ATR), used at `[1]`. file: `:115-116`, `:211-212`
- **Higher-TF directional stack on H4:** EMA(20) **H4** + EMA(50) **H4** (uses `[0]` + `[1]` for slope). file: `:113-114`, `:196-201`
- **Gates:** H4 trend + D1 trend + ADX from context. file: `:188-189`, `:179`

### Crash Breakout (Bear Hunter) — `CCrashBreakoutEntry.mqh`
- **Trigger fires off H1 indicators vs LIVE price** (no closed-bar trigger candle for entry).
- **D1 death-cross gate:** EMA(50) **D1** `[1]` < EMA(200) **D1** `[1]`; confirm `iClose(_Symbol, PERIOD_D1, 1) < D1 EMA50`. file: `:98-99`, `:181-189`, `:195`
- **H1 indicators:** EMA(21) **H1** `[1]`, ATR(14) **H1** `[1]`, ADX(14) **H1** `[1]`. file: `:100-102`, `:215-222`
- Rubber-band short trigger: **live current price** vs `H1 EMA21 + N*ATR_H1`. file: `:228-231`

### Displacement — `CDisplacementEntry.mqh`
- **Trigger TF = H1.** 15 H1 bars; swing in `[2..14]`; sweep `[2..3]`; displacement candle on **closed `[1]`**. file: `:55`, `:163-166`, `:180-186`, `:207`, `:221-226`
- ATR(14) **H1** `[1]`. file: `:85`, `:148-150`
- **Gate:** H4 trend + regime. file: `:195`, `:140`

### Liquidity Sweep — `CLiquiditySweepEntry.mqh`
- **Sweep TF = H1.** `CopyHigh/Low(_Symbol, m_timeframe=H1, …)`; swing `[4..4+lookback]`; sweep in `[1..sweep_bars]` (closed). file: `:46`, `:117-119`, `:134-144`, `:194-204`
- **Confirmation TF = M15** (`m_confirm_tf=PERIOD_M15`): `CopyClose(_Symbol, M15, 0, 2)`, uses **M15 `[1]`** (last closed). file: `:47`, `:150-152`, `:209-211`
- **Gate:** H4 trend. file: `:125`

### Engine — Liquidity (Displacement / OB-Retest / FVG / SFP) — `CLiquidityEngine.mqh`
- **All four modes trigger on H1** (`m_timeframe=PERIOD_H1`). file: `:104`
- ATR(14) **H1** `[1]`; RSI(14) **H1**. file: `:165`, `:173`, `:373-377`
- Displacement 6 H1 bars (body on `[1]`); OB-Retest 3 H1 bars (`[1]`); FVG 4 H1 bars (`[1/2/3]`, GMT-aware H1 time); SFP 26 H1 bars + 12-bar H1 tick volume. file: `:551-596`, `:795-831`, `:943-1000`, `:1152-1209`
- No M15/M5 mixing in this engine — pure H1.

### Engine — Session (the live GMT clock) — `CSessionEngine.mqh`
- **GMT clock:** `GetGMTHour(server_time)` = server time − `m_gmt_offset` (auto from `TimeCurrent()-TimeGMT()`, fallback `InpBrokerGMTOffset=3`). file: `:460-467`, `:311-327`
- **Asian range built on M15:** `CopyHigh/Low/Time(_Symbol, PERIOD_M15, 0, 100)` filtered to GMT hours `[0..7)`. file: `:567-597`
- **London breakout (GMT 8–10):** trigger **H1**, `close[1]` vs `asian_high+buffer`. file: `:671-684`
- **NY continuation (GMT 13–14):** trigger **H1**, `close[1]`. file: `:821-835`
- **Silver Bullet (GMT 15–16):** **M15** FVG detection (10 M15 bars). file: `:954-982`
- **London-close reversal (GMT 16–17):** reversal candle **H1**; day-extreme from **M15**. file: `:1137-1165`
- ATR(14) **H1** for all modes. file: `:336`. **Gate:** H4 trend `:662`.

### Engine — Expansion — `CExpansionEngine.mqh`
- **Trigger TF = H1.** ATR(14)+ATR(20) **H1**, Bollinger(20,2.0) **H1**, Keltner EMA(20)/ATR(20) **H1**. file: `:99`, `:327-336`
- Institutional candle: 3 H1 bars, body vs ATR on `[1]`. file: `:684-708`, `:754`
- Compression breakout: BB/Keltner squeeze on `[1]` (closed). file: `:906-971`
- ATR closed `[1]`. file: `:657-659`. **Gates:** ADX (H4 via context), H4/D1 trend. file: `:956`

### Engine — Pullback Continuation — `CPullbackContinuationEngine.mqh`
- **Trigger TF = H1.** ATR(14) **H1** `[1]`; pullback bars + swing lookback on **H1** `[1..lookback]`. file: `:249`, `:335`, `:745-759`, `:408-463`
- Continuation body vs H1 ATR on `[1]`. file: `:557-558`
- **Gates (higher TF from context):** H4 trend `GetH4TrendDirection()` + D1 trend `GetTrendDirection()` + ADX (H4) + macro score. file: `:372-378`, `:762-763`

---

## D. The safety gates

- **Shock detection** — `CEnhancedTradeExecutor.DetectShock(atr_h1, …)`:
  - Bar-range ratio on **H1 closed `[1]`** (`iHigh/iLow PERIOD_H1, 1`) ÷ **H1** closed ATR(14). file: `CEnhancedTradeExecutor.mqh:2112-2119`
  - Fast-leg ratio on **M5 closed `[1]`** (`iHigh/iLow PERIOD_M5, 1`) ÷ **H1** ATR — explicit **M5÷H1** cross-TF ratio. file: `:2136-2142`
  - Spread spike = **live tick** `SYMBOL_SPREAD` vs 20-sample baseline. file: `:2121-2134`
  - The `atr` passed in is `GetATRCurrent()` = **H4** regime ATR. file: `UltimateTrader.mq5:1758-1759`
- **Session execution-quality gate** — `GetSessionExecutionQuality()`: historical per-session slippage keyed by **GMT hour** + tick spread stability (**live tick**) + tick activity on **H1** (`iTickVolume PERIOD_H1`, `[0]` vs `[1..10]`). file: `CEnhancedTradeExecutor.mqh:2185-2264`
- **Spread gate** — `CheckSpreadGate()` vs `InpMaxSpreadPoints=50`: **live tick** `SYMBOL_SPREAD`. file: `UltimateTrader.mq5:1806`; executor thresholds `CEnhancedTradeExecutor.mqh:207-223`
- **Regime-thrash cooldown** — `IsRegimeThrashing()`: counts **H4** regime changes (>2 in 4h); regime is the H4 classifier. file: `UltimateTrader.mq5:1811`
- **Session-allowed gate (O1)** — `IsSessionAllowed(asia/london/ny)` on **GMT hour** (Asia 0–8, London 8–13, NY 13–24). file: `CSignalOrchestrator.mqh:465-472`
- **Skip-hour gate (O2)** — `IsTradingHourAllowed(start..end)` on **broker-local hour** (default 11..11 = disabled). file: `CSignalOrchestrator.mqh:474-480`
- **SL-to-spread sanity (N36)** — `SL_dist < InpMinSLToSpreadRatio(3.0) × (SYMBOL_SPREAD × _Point)`: **live tick** spread vs signal SL distance. file: `UltimateTrader.mq5:1928-1939`
- **Min R:R (X3)** — `actual_rr < InpMinRRRatio(1.3)`: pure signal geometry (entry/SL/TP prices), **no TF read** (file signals bypass). file: `CTradeOrchestrator.mqh:323-355`
- **Max positions (N32)** — `GetPositionCount() < InpMaxPositions(5)`: position count, **no TF**. file: `UltimateTrader.mq5:1846`
- **Exposure cap (X11)** — `open_risk + risk > InpMaxTotalExposure(5.0)`: account risk %, **no TF**. file: `CTradeOrchestrator.mqh:559-630`
- **HTF-uptrend short veto (O6, routed-engines only/DORMANT)** — `(H4 bullish OR D1 bullish) AND price>MA200(H1)`: **H4 + D1 trend + H1 200-EMA** vs **live Bid**. file: `CSignalOrchestrator.mqh:645-654`
- **Short ATR floor (O7)** — `GetATRCurrent() >= m_tf_min_atr`: **H4** ATR. file: `CSignalOrchestrator.mqh:656-663`
- **Long-extension gate (N13/N31)** — 72h rise from **H4** close `[18]` (`iClose(_Symbol, PERIOD_H4, 18)`) vs entry, AND **W1** EMA(20) falling (`wema[0] > wema[2]`, 2 weeks ago). Mixes **H4** + **W1**. file: `UltimateTrader.mq5:415-460`

### Validator gates (`CSignalValidator.mqh`)
- **ValidateEntryConditions (long bias ladder, O8b)** — 200-EMA = **H1** (`GetMA200Value()`) vs **live Bid**; trend-align uses **D1** (`GetTrendDirection`) + **H4** (`GetH4TrendDirection`); ADX = **H4**. file: `CSignalValidator.mqh:336-507`, `:511-536`
- **ValidateMeanReversionConditions (O8a)** — ADX/ATR band, both **H4** (regime classifier). file: `CSignalValidator.mqh:224-262`
- **ValidateVolumeSpread (O10)** — `CopyTickVolume(_Symbol, PERIOD_H1, 0, 11)` → **H1** `[1]` vs `[2..10]` average. file: `CSignalValidator.mqh:130`
- **ValidateSMCConditions (O11)** — `GetSMCConfluenceScore()` from **H1** SMC zones (+ D1/H4 HTF if enabled). file: `CSignalValidator.mqh:171`

---

## E. Risk dials & sizing

- **Session risk mult (N33)** — keyed by **GMT hour** (London 0.50 / NY 0.90 / Asia 1.0) via `GetGMTHour()`. file: `UltimateTrader.mq5:1858-1888`
- **Wednesday mult (N34, DORMANT)** — `TimeToStruct(TimeCurrent()).day_of_week==3`: server calendar, **no chart TF**. file: `UltimateTrader.mq5:1892-1904`
- **Combined shock×sq factor (N35)** — products of the §D shock (H4-ATR-driven / H1+M5 ranges) and session-quality (GMT/H1/tick) factors. file: `UltimateTrader.mq5:1912-1924`
- **Regime risk scaler (N37)** — `CRegimeRiskScaler.Evaluate()` reads **H4** ADX/ATR (regime classifier) + **H4** trend + **D1** trend from context; no direct chart read of its own. file: `CRegimeRiskScaler.mqh:165-245`
- **Quality-trend boost (N38, DORMANT)** — `GetCurrentRegime()` (**H4**) + setup quality tier; no extra TF. file: `UltimateTrader.mq5:1963-1982`
- **ATR-velocity boost (N39)** — `GetATRVelocity()` on **H1** (6 closed bars), boost ×1.15 if accel > 15%. file: `UltimateTrader.mq5:1986-2002`; velocity `CMarketContext.mqh:643-663`
- **EC v3 risk multiplier (X5)** — `CEquityCurveRiskController`: **account equity curve only**, **zero chart TF reads** (ATR is *passed in*, not read here). file: `CEquityCurveRiskController.mqh:358-504`
- **Counter-trend 200-EMA halving (X10)** — ×0.5 if `short & entry>MA200` or `long & entry<MA200`, where MA200 = **H1** `GetMA200Value()` vs **live** entry (Ask/Bid). file: `CTradeOrchestrator.mqh:510-540`
- **Lot-size formula (X8)** — `CQualityTierRiskStrategy`: sizes from SL distance + `SYMBOL_TRADE_TICK_VALUE`/`SYMBOL_TRADE_TICK_SIZE`/`SYMBOL_POINT`. **No chart-TF / no ATR read** — pure tick-value math. file: `CQualityTierRiskStrategy.mqh:370-395`
- **Reward-room obstacle gate (X4, DORMANT)** — nearest obstacle from **H4** swing pivots (`CopyHigh/Low PERIOD_H4, 1, 100`, closed `[1..100]`) + **D1** PDH/PDL `[1]` + **W1** PWH/PWL `[1]` + round-$50 + **H1** SMC zones. file: `CTradeOrchestrator.mqh:1020-1112`

---

## F. Exits & trailing

- **Initial SL anchor** — set at signal generation (each plugin), passed into `SPosition`; the coordinator does not re-derive it. Plugin SL anchors: H1 ATR (most), H1 swing cache (engines), M15 ATR (S3/S6). Managed in `CPositionCoordinator` thereafter.
- **TP ladder (P3)** — TP0/TP1/TP2 fire on **R-multiples** (`profit_r = (price−entry)/(entry−SL)`); distances come from the stamped regime-exit profile or `InpTP0/1/2Distance`. **No chart-TF read.** file: `CPositionCoordinator.mqh:2051-2240`
- **Breakeven (P4)** — arms on an **R-multiple** trigger (`profit_r_be >= be_trigger`, default `InpTrailBETrigger=0.8R`). **No chart-TF.** file: `CPositionCoordinator.mqh:2904-2937`
- **Anti-stall (P4)** — measured in **wall-clock** minutes (`(TimeCurrent()-open_time)/(15*60)`), not chart bars. file: `CPositionCoordinator.mqh:2485`
- **Chandelier trailing (P5)** — ATR(14) on **H1** (default `m_timeframe=PERIOD_H1`), read at **closed `[1]`**; highest-high / lowest-low over `m_swing_lookback` (`InpBOChandelierLookback=15`) on **H1 closed `[1..lookback]`**; SL = `extreme ∓ ATR×mult`. file: `CChandelierTrailing.mqh:40-55`, `:77-92`, `:149`, `:163-193`
- **ATR trailing (alt P5)** — ATR(14) **H1** `[1]`; SL = `price ∓ ATR×mult`. file: `CATRTrailing.mqh:70-84`, `:141`, `:154-157`
- **Regime-aware trailing multiplier (P5)** — `CRegimeRiskScaler.Evaluate()` → **H4** regime sets the live Chandelier mult per bar. file: `CPositionCoordinator.mqh:2758-2807`
- **Regime-aware exit plugin (P6)** — EMA(50) on **H1** `[1]` vs **H1 close `[1]`** (`iClose(_Symbol, PERIOD_H1, 1)`); long broken if H1 close < EMA50. file: `CRegimeAwareExit.mqh:108`, `:57-66`
- **Max-age exit (P6)** — **wall-clock hours**: `(TimeCurrent() − POSITION_TIME)/3600` vs `InpMaxPositionAgeHours`. **No chart bars.** file: `CMaxAgeExit.mqh:88-94`
- **Weekend-close exit (P6)** — **server time + GMT offset**: Friday after `InpWeekendCloseHour:Minute`. **No chart TF.** file: `CWeekendCloseExit.mqh:98-126`
- **Daily-loss halt (M3 / P6)** — equity-based daily PnL vs `−InpDailyLossLimit(3%)`. **No chart TF.** file: `CRiskMonitor.mqh:173`

---

## Master summary table

> `Forming[0]` = reads the in-progress bar; `Closed[1]` = reads the last completed bar; `live` = tick/quote;
> `R` = R-multiple (no chart TF); `clock` = GMT/server/wall-clock time (no chart bars).

| Component / decision | Timeframe(s) | Data read | Forming[0]/Closed[1] | file:line |
|---|---|---|---|---|
| New-bar trigger / decision cadence | **H1** | `iTime(PERIOD_H1,0)` | Forming[0] (open time) | UltimateTrader.mq5:1449 |
| New-bar seed (first tick) | H1 | `iTime(PERIOD_H1,1)` | Closed[1] | UltimateTrader.mq5:488 |
| Breakout-probation hold (DORMANT) | H1 | `iClose(PERIOD_H1,1)` | Closed[1] | UltimateTrader.mq5:1480 |
| Daily trend (`GetTrendDirection`) | **D1** | EMA(10/21)+ATR(14) D1 | Closed[1] | CTrendDetector.mqh:72-73,82,105 |
| H4 trend (`GetH4Trend`) | **H4** | EMA(10/21)+ATR(14) H4 | Closed[1] | CTrendDetector.mqh:75-76,83,106 |
| H1 trend | H1 | EMA(10/21)+ATR(14) H1 | Closed[1] | CTrendDetector.mqh:78-79,84 |
| 200-EMA bias filter (`GetMA200Value`) | **H1** (not D1) | iMA(PERIOD_H1,200,EMA) | Closed[1] EMA vs live price | CMarketContext.mqh:277,478,1069 |
| Regime classifier | **H4** | ADX(14)/ATR(14)/BB(20,2) H4 | Closed[1] | CRegimeClassifier.mqh:105-107,148 |
| Regime ATR average | **H4** | 50-bar H4 ATR mean | Closed[1..50] | CRegimeClassifier.mqh:152-156 |
| `GetADXValue()` | **H4** | ADX(14) | Closed[1] | CMarketContext.mqh:401; CRegimeClassifier.mqh:105 |
| `GetATRCurrent()`/`GetATRAverage()` | **H4** | ATR(14) current/50-avg | Closed[1] | CMarketContext.mqh:407-415 |
| ATR velocity (`GetATRVelocity`) | **H1** | TR over 6 bars, recent-3÷older-3 | Closed[1..6] | CMarketContext.mqh:643-663 |
| Vol-regime ATR | H1 | ATR(14) current+120-avg | Forming[0]+Closed[1..120] | CVolatilityRegimeManager.mqh:182,232,386 |
| Macro bias DXY/VIX | **H4** | CopyClose(DXY/VIX,H4) | Forming[0] | CMacroBias.mqh:192-193,253 |
| Macro price-fallback | D1+H4 | D1-EMA200[1], H4-EMA(20/50)[1] vs live | Closed[1] + live | CMacroBias.mqh:100-102,293-301 |
| Momentum RSI | **H1 + H4** | RSI(14) | Forming[0] | CMomentumFilter.mqh:198-199,320 |
| Momentum MACD/Stoch/CCI/MFI | **H1** | resp. indicators | Forming[0] | CMomentumFilter.mqh:202-211,331-361 |
| SMC OB/FVG/liquidity | **H1** | CopyHLOC(PERIOD_H1,0,N) | incl. Forming[0] | CSMCOrderBlocks.mqh:779-782,848,889 |
| SMC BOS/CHoCH/swings | **H1** | iHigh/iLow(PERIOD_H1,1/2) | Closed[1]/[2] | CSMCOrderBlocks.mqh:964-967,1019,1105 |
| Choppiness CI(10) | **H1** | iHigh/iLow/iClose H1 | Closed[1..10] | CMarketContext.mqh:673-689 |
| Dealing range (IPDA) | **D1** | iHigh/iLow(PERIOD_D1) 20-bar | Closed[1..20] | CMarketContext.mqh:762-786 |
| SL-anchor swing cache | **H1** | CopyHigh/Low(PERIOD_H1,1,N) | Closed[1..N] | CMarketContext.mqh:1092-1093 |
| PDH / PDL | **D1** | iHigh/iLow(PERIOD_D1,1) | Closed[1] | CMarketContext.mqh:823-824 |
| PWH / PWL | **W1** | iHigh/iLow(PERIOD_W1,1) | Closed[1] | CMarketContext.mqh:825-826 |
| Crash death-cross | **D1** | EMA(50/200)+iClose D1 | Closed[1] | CCrashDetector.mqh:110-111,210-219 |
| Crash rubber-band | **H1** | EMA21/ATR14/ADX14 H1 vs live | Closed[1] + live | CCrashDetector.mqh:112-114,296-312 |
| Engulfing entry | **H1** trigger; H4 gate | OHLC H1[1]/[2]; ATR H1; GetH4Trend | Closed[1] | CEngulfingEntry.mqh:46,138,155 |
| PinBar entry | **H1** trigger; H4 gate; H1 proximity | OHLC H1[1]; ATR H1; iHighest H1; GMT | Closed[1] | CPinBarEntry.mqh:47,133,151,178 |
| MA Cross entry | **H1** trigger; H4 gate | MA(10/21)+ATR(14) H1 cross[2]→[1]; NY GMT | Closed[1]/[2] | CMACrossEntry.mqh:52,81-83,165,184 |
| Range-Edge Fade (S3) | **M15** trigger; **H1 ATR**; M15 ATR | OHLC M15[1..2]; RSI M15; ATR H1+M15 | Closed[1] | CRangeEdgeFade.mqh:78-80,134 |
| Failed-Break Reversal (S6) | **M15** trigger; **H1 ATR**; **D1** levels | OHLC M15[1..3]; ATR H1+M15; D1 PDH/PDL | Closed[1] | CFailedBreakReversal.mqh:59-60,99,120 |
| Volatility Breakout | **H1** trigger; **H4** EMA stack | Donchian/Keltner H1[1]; H4 EMA(20/50); ADX | Closed[1] (H4 slope uses [0]) | CVolatilityBreakoutEntry.mqh:72,113-116,223 |
| Crash Breakout | **D1** gate; **H1** indicators; live trigger | D1 death-cross; H1 EMA21/ATR/ADX vs live | Closed[1] + live | CCrashBreakoutEntry.mqh:98-102,187,228 |
| Displacement | **H1** trigger; H4 gate | 15 H1 bars; ATR H1; GetH4Trend | Closed[1] (sweep [2..3]) | CDisplacementEntry.mqh:55,163,195 |
| Liquidity Sweep | **H1** sweep; **M15** confirm; H4 gate | H1 swing/sweep; M15 close[1]; GetH4Trend | Closed[1] (H1) + M15[1] | CLiquiditySweepEntry.mqh:46-47,117,150 |
| Liquidity Engine (4 modes) | **H1** | OHLC+ATR(14)+RSI(14) H1; SFP tick-vol | Closed[1] | CLiquidityEngine.mqh:104,165,551-1209 |
| Session Engine — GMT clock | clock (GMT) | GetGMTHour = server−offset | now | CSessionEngine.mqh:460-467 |
| Session Engine — Asian range | **M15** | CopyHigh/Low/Time(M15) GMT 0–7 | over M15 bars | CSessionEngine.mqh:567-597 |
| Session Engine — London/NY BO | **H1** | close[1] vs range/level | Closed[1] | CSessionEngine.mqh:671-684,821-835 |
| Session Engine — Silver Bullet | **M15** | M15 FVG (GMT 15–16) | M15 | CSessionEngine.mqh:954-982 |
| Session Engine — London close | **H1** + **M15** | H1 reversal candle; M15 day-extreme | Closed[1] | CSessionEngine.mqh:1137-1165 |
| Expansion Engine | **H1** | ATR(14/20)/BB(20,2)/Keltner H1; ADX(H4) | Closed[1] | CExpansionEngine.mqh:99,327-336,657 |
| Pullback Continuation | **H1** trigger; **H4+D1** gates | ATR(14) H1; pullback H1; GetH4/Daily trend | Closed[1] | CPullbackContinuationEngine.mqh:249,335,372 |
| Shock — bar range | **H1** | iHigh/iLow(H1,1) ÷ H1 ATR | Closed[1] | CEnhancedTradeExecutor.mqh:2112-2119 |
| Shock — fast leg | **M5** ÷ **H1** | iHigh/iLow(M5,1) ÷ H1 ATR | Closed[1] | CEnhancedTradeExecutor.mqh:2136-2142 |
| Shock — spread spike | live | SYMBOL_SPREAD vs 20-sample | live | CEnhancedTradeExecutor.mqh:2121-2134 |
| Session-quality gate | clock(GMT)+H1+live | per-session slippage; H1 tick-vol; spread | Forming[0] tick-vol | CEnhancedTradeExecutor.mqh:2185-2264 |
| Spread gate | live | SYMBOL_SPREAD vs InpMaxSpreadPoints(50) | live | UltimateTrader.mq5:1806 |
| Regime-thrash cooldown | **H4** | H4 regime change count (>2/4h) | Closed[1] | UltimateTrader.mq5:1811 |
| Session-allowed (O1) | clock (GMT) | Asia/London/NY GMT bands | now | CSignalOrchestrator.mqh:465-472 |
| Skip-hour (O2) | clock (broker hour) | InpSkipStartHour..End (def 11..11 off) | now | CSignalOrchestrator.mqh:474-480 |
| HTF-uptrend short veto (O6) | **H4+D1+H1** | H4/D1 bullish AND price>MA200(H1) | Closed[1] + live | CSignalOrchestrator.mqh:645-654 |
| Short ATR floor (O7) | **H4** | GetATRCurrent() >= m_tf_min_atr | Closed[1] | CSignalOrchestrator.mqh:656-663 |
| Long bias ladder (O8b) | **H1**+**H4**+**D1** | MA200(H1) vs live; H4/D1 trend; ADX(H4) | Closed[1] + live | CSignalValidator.mqh:336-536 |
| MR validation (O8a) | **H4** | ADX/ATR band | Closed[1] | CSignalValidator.mqh:224-262 |
| Volume gate (O10) | **H1** | CopyTickVolume(H1,0,11) | Closed[1] vs [2..10] | CSignalValidator.mqh:130 |
| SMC confluence (O11) | **H1** (+D1/H4 HTF) | GetSMCConfluenceScore | Closed[1] | CSignalValidator.mqh:171 |
| Long-extension gate (N13/N31) | **H4 + W1** | iClose(H4,18) rise; W1 EMA(20) slope | Closed[1] (H4[18], W1[0]vs[2]) | UltimateTrader.mq5:415-460 |
| SL-to-spread sanity (N36) | live | SL_dist vs 3×spread | live | UltimateTrader.mq5:1928-1939 |
| Min R:R (X3) | R / none | entry/SL/TP geometry | n/a | CTradeOrchestrator.mqh:323-355 |
| Max positions (N32) | none | position count | n/a | UltimateTrader.mq5:1846 |
| Exposure cap (X11) | none | account risk % | n/a | CTradeOrchestrator.mqh:559-630 |
| Session risk mult (N33) | clock (GMT) | London .50 / NY .90 / Asia 1.0 | now | UltimateTrader.mq5:1858-1888 |
| Wednesday mult (N34, DORMANT) | clock (calendar) | day_of_week==3 | now | UltimateTrader.mq5:1892-1904 |
| Regime risk scaler (N37) | **H4 + D1** | H4 ADX/ATR + H4/D1 trend | Closed[1] | CRegimeRiskScaler.mqh:165-245 |
| Quality-trend boost (N38, DORMANT) | **H4** | GetCurrentRegime + quality tier | Closed[1] | UltimateTrader.mq5:1963-1982 |
| ATR-velocity boost (N39) | **H1** | GetATRVelocity > 15% | Closed[1..6] | UltimateTrader.mq5:1986-2002 |
| EC v3 risk mult (X5) | none | account equity curve | n/a | CEquityCurveRiskController.mqh:358-504 |
| Counter-trend halving (X10) | **H1** | MA200(H1) vs live entry | Closed[1] + live | CTradeOrchestrator.mqh:510-540 |
| Lot-size formula (X8) | none | tick-value/tick-size/point | n/a | CQualityTierRiskStrategy.mqh:370-395 |
| Reward-room obstacle (X4, DORMANT) | **H4 + D1 + W1 + H1** | H4 pivots[1..100]; D1/W1 [1]; SMC(H1) | Closed[1] | CTradeOrchestrator.mqh:1020-1112 |
| TP ladder (P3) | R / none | R-multiples from profile/inputs | n/a | CPositionCoordinator.mqh:2051-2240 |
| Breakeven (P4) | R / none | profit_r >= be_trigger | n/a | CPositionCoordinator.mqh:2904-2937 |
| Anti-stall (P4) | clock (wall) | (now−open)/15min | n/a | CPositionCoordinator.mqh:2485 |
| Chandelier trailing (P5) | **H1** | ATR(14) H1[1]; HH/LL over lookback | Closed[1..lookback] | CChandelierTrailing.mqh:149,163-193 |
| ATR trailing (P5 alt) | **H1** | ATR(14) H1[1]; price∓ATR×mult | Closed[1] + live | CATRTrailing.mqh:141,154-157 |
| Regime-aware trail mult (P5) | **H4** | regime → Chandelier mult | Closed[1] | CPositionCoordinator.mqh:2758-2807 |
| Regime-aware exit (P6) | **H1** | EMA(50) H1[1] vs iClose(H1,1) | Closed[1] | CRegimeAwareExit.mqh:108,57-66 |
| Max-age exit (P6) | clock (wall) | (now−POSITION_TIME)/3600h | n/a | CMaxAgeExit.mqh:88-94 |
| Weekend-close exit (P6) | clock (server+GMT) | Friday after hour:minute | n/a | CWeekendCloseExit.mqh:98-126 |
| Daily-loss halt (M3) | none | equity-based daily PnL | n/a | CRiskMonitor.mqh:173 |

---

## Cross-timeframe mixes flagged (where one decision blends TFs)

1. **Long-extension gate = H4 momentum + W1 trend** — 72h rise from `iClose(H4,18)` AND weekly EMA(20) slope. (`UltimateTrader.mq5:415-460`)
2. **Shock detector = M5 ÷ H1** — an M5 bar-range divided by an **H1** ATR(14), alongside an H1 bar-range ÷ H1 ATR. (`CEnhancedTradeExecutor.mqh:2112-2142`)
3. **ATR split = H4 (regime) vs H1 (velocity/vol-regime)** — `GetATRCurrent/Average` are H4; `GetATRVelocity` and the vol-regime manager are H1. The shock gate seeds H4 ATR into an H1/M5 range comparison. (`CRegimeClassifier.mqh:106` vs `CMarketContext.mqh:643-663`)
4. **HTF short veto = H4 + D1 + H1** — H4 OR D1 bullish AND price above the **H1** 200-EMA. (`CSignalOrchestrator.mqh:645-654`)
5. **Long bias ladder = H1 + H4 + D1** — H1 200-EMA gate, H4 + D1 trend-alignment, H4 ADX. (`CSignalValidator.mqh:336-536`)
6. **Reward-room obstacle scan = H4 + D1 + W1 + H1** — H4 swing pivots, D1/W1 prior-period extremes, H1 SMC zones. (`CTradeOrchestrator.mqh:1020-1112`)
7. **S3/S6 = M15 trigger + H1 ATR (+ D1 levels for S6)** — pattern on M15 but stop sizing from H1 ATR; S6 also reads D1 PDH/PDL. (`CRangeEdgeFade.mqh:78-80`, `CFailedBreakReversal.mqh:59-60,120`)
8. **Liquidity Sweep = H1 sweep + M15 confirmation** — the sweep is detected on H1, the reclaim/confirm close on M15. (`CLiquiditySweepEntry.mqh:117,150`)
9. **Volatility Breakout = H1 Donchian/Keltner + H4 EMA directional stack.** (`CVolatilityBreakoutEntry.mqh:113-116,223`)
10. **Crash Breakout = D1 death-cross gate + H1 indicators vs live price.** (`CCrashBreakoutEntry.mqh:98-102,187,228`)

---

## Notes / caveats

- **Input naming vs reality:** `InpUseDaily200EMA` gates an **H1** 200-EMA, not a D1 one — verified at `CMarketContext.mqh:277` + `CTradeOrchestrator.mqh:513` + `CSignalValidator.mqh:347`.
- **No TF read at all:** lot sizing (`CQualityTierRiskStrategy`), EC v3 (`CEquityCurveRiskController`), min-R:R, max-positions, exposure cap, TP ladder, breakeven, daily-loss halt. These are R-multiple / account / count / live-tick logic.
- **Clock-only (no chart bars):** session-allowed (GMT), skip-hour (broker hour), session risk mult (GMT), Wednesday mult (calendar), anti-stall (wall-clock), max-age (wall-clock hours), weekend-close (server+GMT).
- **Repaint posture:** the EA is conservative — trend/regime/MA200/SMC-BOS/trailing/regime-exit all read **closed `[1]`**. The deliberate forming-`[0]` / live-tick reads are momentum (`[0]`), macro/crash *price* (live, intentional front-run vs a stable closed-bar baseline), SMC zone *scans* (include `[0]`), and execution-time price/spread.
- **Dormant gates** (controlling input OFF on production default) still listed for completeness: O6 HTF short veto (routed engines off), X4 reward-room, N34 Wednesday, N38 quality-trend boost, breakout probation. Their TF reads only matter if the operator flips the flag.
