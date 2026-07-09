# WT-1 Design Audit — Strategy Thesis (§6) & XAUUSD Suitability (§7)

Reviewer: WT-1 (professional-trader, fresh-eye source-only). Static read only. No result metrics used.
Scope: rubric §6 + §7 of `workflowAnalysis/traderEvaluation.md`.
Files read: `traderEvaluation.md`, `UltimateTrader_Inputs.mqh`, `Include/Common/SymbolProfile.mqh`,
`Include/Common/Enums.mqh`, entry plugins (Engulfing, PinBar, MACross, RangeEdgeFade/S3,
FailedBreakReversal/S6, CrashBreakout, Displacement, FalseBreakoutFade), `UltimateTrader.mq5`
(ComputePointScale, ApplySymbolProfile, OnInit wiring, OnTick spread gate),
`CMarketContext::IsDataDay/GetDayType`, `CDayTypeRouter::ClassifyDay`,
`CEnhancedTradeExecutor::CheckSpreadGate`.

---

## §6 — Strategy Thesis Quality

**SCORE: 3 / 5** (acceptable beta; capped by "many patterns, no single central concept + indicator-as-thesis core").

### What a pro expresses vs what the EA expresses
A pro states one edge in plain language: *condition + setup + behavioral reason + invalidation + target*.
The EA does NOT have ONE thesis — it is a **portfolio of ~8 named setups** glued by a quality-tier
cascade. There is, however, a real and defensible **meta-thesis that is honestly enforced**: *gold is
structurally long-biased, so monetize bullish continuation/pullback patterns and only fade
overextensions; the short side is mostly toxic and is suppressed.* This is visible in code, not just docs.

### Evidence the thesis is real (not pure indicator-cross)
- Long-bias is enforced structurally, not asserted: Bearish Engulfing hard-off via
  `g_profileEnableBearishEngulfing=false` (`CEngulfingEntry.mqh:211`, comment "-25.9R/6yr, dominates
  every loss streak"); Bearish MA Cross physically removed (`CMACrossEntry.mqh:216`); S6 short off
  (`CFailedBreakReversal.mqh:191`); short risk halved `g_profileShortRiskMultiplier=0.5`
  (`SymbolProfile.mqh:20`). A pro who knows gold's secular uptrend would do exactly this. **Confirmed.**
- Several setups DO carry a behavioral reason + structural invalidation, not just an indicator flip:
  - S3 RangeEdgeFade (`CRangeEdgeFade.mqh`): validated range box + sweep-below + close-back-inside +
    stealth-trend veto (`:117`) + ≥2R room to opposite edge (`:167`). That is liquidity-sweep-fade
    logic with a structural stop (beyond the swept extreme) and a structural target (opposite inner
    edge). **Confirmed** — genuine thesis.
  - S6 FailedBreakReversal (`CFailedBreakReversal.mqh`): sweeps PDH/PDL + range edges, requires the
    rejection wick beyond the level to exceed the body (`:150`, "proof the level was rejected, not
    lost") and a margin reclaim (`:164`). This is a real stop-run thesis with invalidation = level
    truly lost. **Confirmed.**
  - Rubber Band short (`CCrashBreakoutEntry.mqh`): only fires in a D1 Death-Cross regime, fades price
    > EMA21 + 2×ATR, targets the mean (EMA21), ADX>25 filter. Mean-reversion-in-downtrend thesis with
    a behavioral reason. **Confirmed.**
  - Displacement (`CDisplacementEntry.mqh`): sweep of swing + displacement candle closing back through
    → ICT-style intent. **Confirmed.**

### Evidence of the weak end (indicator-as-thesis)
- The three highest-scored / most-weighted live setups are essentially **lagging candlestick/indicator
  patterns** with HTF-trend gating bolted on:
  - Engulfing (score 92) = "prev bearish + curr bullish + body wraps" (`CEngulfingEntry.mqh:165-171`).
    No liquidity context, no location-in-range test, no "who is on the other side." It is the textbook
    weak thesis the rubric warns about (§6 red flag), rescued only by the H4-trend filter.
  - MA Cross (score 82) = "fast SMA crosses slow SMA on bar[1]" (`CMACrossEntry.mqh:184`). This is the
    literal "X crosses Y" red-flag, with a behavioral rationale that is implicit at best.
  - Pin Bar (score 88) = wick/body ratios + close position (`CPinBarEntry.mqh:159-164`). A reversal
    candle with no requirement that it swept anything or sits at a level.
- So the *strongest-weighted* edges are the *weakest-thesis* ones; the *best-thesis* setups (S3/S6,
  Rubber Band) are tiered lower (B+, score 6) or are minor contributors. A pro would invert this.
- "Who is on the other side?" is answerable for S3/S6/Displacement (trapped breakout traders / swept
  stops) but NOT for Engulfing/PinBar/MACross. Incomplete across the portfolio.
- No single sentence connects all eight setups beyond "patterns that backtested positive on gold."
  The unifying logic is empirical selection, not a market-microstructure concept. **Likely.**

### Design-gap / fix
1. Promote the liquidity-based setups (S3/S6/Displacement) to the thesis core and demote/contextualize
   the bare candlestick patterns (require them to sit at a structural level or sweep before firing —
   the PinBar proximity filter `InpPinBarProximityFilter=false` already exists but is disabled).
2. Write one explicit meta-thesis statement and make each plugin declare which clause it serves.
3. Add an "other-side / draw-on-liquidity" field to the `EntrySignal` so each entry names its target
   liquidity (closes the §6 "behavioral reason" gap for the candlestick setups).

Confidence: **Confirmed** on the code facts; **Likely** on the "no central concept" judgment (a
generous reviewer could call the long-bias filter the central concept — hence 3, not 2).

---

## §7 — XAUUSD-Specific Suitability

**SCORE: 2 / 5** (present but weak/breakable; CAPPED by the dangerous gap: **no active
news/event filter on the production gold config** — the rubric's explicit red flag, and the single
most important XAUUSD-specific risk dimension).

### Genuinely gold-specific design (the strong parts — real, not generic-FX)
- **Per-instrument profile system** (`ApplySymbolProfile()` `UltimateTrader.mq5:260-317` +
  `SymbolProfile.mqh`): gold, USDJPY, GBPJPY get *different setup rosters*, data-driven
  (e.g. Rubber Band + Bearish Pin Bar disabled on JPY; Bearish Engulfing + S6-short enabled on JPY,
  disabled on gold). This is the opposite of the "same settings for EURUSD/BTC/XAUUSD" red flag.
  **Confirmed** — strong differentiator.
- **Minimum stop distance is gold-scaled and large**: `InpMinSLPoints=800` (=$8.00 on a 2-digit gold
  quote) `Inputs:118`, applied as `g_scaledMinSLPoints=InpMinSLPoints*g_pointScale`
  (`UltimateTrader.mq5:229`) and passed into Engulfing/PinBar (`:580-581`), Displacement-via-engines,
  PullbackCont, Liquidity/Session/Expansion engines (`:676,689,697,711`). An $8 floor respects gold
  H1 noise — no unrealistic tight stops on those setups. **Confirmed.**
- **Point auto-scaling** (`ComputePointScale` `:214-240`): all point distances scale by price/2000 so
  the gold-tuned values don't silently misbehave on other instruments. Gold-reference design.
  **Confirmed.**
- **Session model is gold-aware**: GMT-aware session classification (`GetCurrentTradingSession`
  `:381-389`), per-setup session gates with gold-specific reasons (Bull MA Cross blocked in NY
  `CMACrossEntry.mqh:173`; Bearish Pin Bar NY-block / Asia logic `CPinBarEntry.mqh:228-244`), and
  session risk multipliers (London 0.50×, NY 0.90×, `Inputs:460-461`). Not a 24/5 flat template.
  **Confirmed.**
- **Volatility-adaptive sizing + stops + TPs**: vol-regime risk multipliers (`Inputs:194-208`),
  vol-based SL widening (`InpVolHighSLMult/ExtremeSLMult`), regime risk scaling
  (TREND 1.25× / CHOPPY 0.60× / VOLATILE 0.75×, `Inputs:428-432`), adaptive TP by vol bucket
  (`Inputs:182-191`), ATR-velocity risk multiplier (`:72-74`), and a shock-volatility override
  (`InpEnableShockDetection`, bar-range/ATR ≥2.0, `:436-437`). This directly addresses "gold trends
  aggressively and reverses violently." **Confirmed** — strong.
- **Spread guard exists and is wired** (`CheckSpreadGate` `CEnhancedTradeExecutor.mqh:2060`,
  `InpMaxSpreadPoints=50`=$0.50, two independent gates pre-signal `:1806` and at execution). Blocks on
  raw spread blowout, which indirectly catches the news-spread spike. **Confirmed**, but see weakness.
- **TPs are R-multiple / structure based, not fixed tiny pip targets** (regime exit profiles
  `Inputs:386-424`; TP0 0.7R, TP1 1.3–1.5R, TP2 1.8–2.2R) — no "fixed 5–10 pip" red flag. **Confirmed.**

### The capping weakness — news/macro is the rubric's explicit red flag, and it is OFF
- The rubric §7 lists as a red flag: *"No special handling of CPI, FOMC, NFP, rate decisions."* The EA
  has the scaffold (`InpEnableNewsFlat=true`, `InpNewsWindowMinutes=15`, DAY_DATA enum, static blackout
  + MQL5 calendar in `CMarketContext::IsDataDay()` `:1024`) — but it is **hard-gated to the
  multi-strategy router**: `if(!InpEnableMultiStrategy || !InpEnableNewsFlat) return false;`
  (`CMarketContext.mqh:1031`), and `InpEnableMultiStrategy=false` on production (`Inputs:505`). The
  comment itself says it is "constant-false on the production .set → byte-identical."
- The LIVE day classifier on production is `CDayTypeRouter::ClassifyDay()` (`CDayTypeRouter.mqh:39-98`),
  which can ONLY return DAY_TREND / DAY_VOLATILE / DAY_RANGE — **it never returns DAY_DATA**. So on the
  production gold config the EA will happily open a fresh trade into CPI/FOMC/NFP. **Confirmed.**
  For an XAUUSD EA this is the most consequential gold-specific omission, not a cosmetic one →
  it caps §7 at 2 regardless of the strong volatility/session work above. (Mitigant, not a fix: the
  $0.50 spread gate may block entry *if* the broker has already widened spread before the candle, and
  the shock override may flatten *after* the fact — neither is a pre-event stand-aside.)

### Other §7 weaknesses (below pro-grade, not capping)
- **Inconsistent min-stop discipline**: MA Cross hardcodes `m_min_sl_points=150` ($1.50)
  (`CMACrossEntry.mqh:60`), overriding the 800-pt EA floor — the tightest stop in the system and
  arguably inside gold H1 noise for some sessions. Displacement constructor default `min_sl=100`
  (`CDisplacementEntry.mqh:51`) is not overridden at the standalone construction site
  (`UltimateTrader.mq5:657` passes no min_sl), so it relies on `MathMin(pattern_sl, 100pt)` — a $1.00
  floor. The 800-pt gold floor is therefore NOT uniformly enforced across live setups. **Confirmed.**
- **Spread filter is a single static threshold**, not a multiple of trailing-average spread; a pro
  uses a dynamic/percentile spread gate so it adapts to the instrument's own baseline. Beta-acceptable
  only. **Confirmed.**
- **USD / yields / inflation context is only indirect**: macro bias via DXY/VIX symbols
  (`InpDXYSymbol/InpVIXSymbol`) with a price-based fallback when unavailable. There is no direct rate
  / inflation-data awareness beyond the dormant news filter. The rubric accepts "indirectly," so this
  is adequate, not strong. **Likely** (did not read CMacroBias internals).
- **Rollover/illiquid-window block**: weekend close exists (`InpCloseBeforeWeekend`,
  `InpWeekendCloseHour=20`) but I found no explicit daily-rollover spread/illiquidity stand-aside
  beyond the static spread gate. **Inferred.**

### Design-gap / fix (priority order)
1. **Make news-flat live on the production gold config.** Decouple `IsDataDay()` from
   `InpEnableMultiStrategy`; wire the static USD/XAU blackout (and live calendar when available) into
   the production pre-gate so new entries are blocked ±N min around FOMC/CPI/NFP/PPI/PCE — fail CLOSED
   when the calendar is unavailable. This alone would lift §7 toward 3–4.
2. Enforce the 800-pt gold min-SL floor uniformly (or document a per-setup floor with a gold rationale)
   — remove the MA Cross 150 / Displacement 100 silent overrides or justify them per session.
3. Upgrade the spread gate to a rolling-average multiple (e.g. block if spread > 2.5× trailing median).

Confidence: **Confirmed** on the news-gate being off, the profile system, point scaling, min-SL
inconsistency, and the spread gate; **Likely/Inferred** on macro-context depth and rollover handling.

---

## Compact section verdict
- §6 Strategy Thesis Quality: **3/5** — honest, code-enforced long-bias meta-thesis and several real
  liquidity-based setups, but the top-weighted setups are bare candlestick/indicator patterns and there
  is no single central microstructure concept.
- §7 XAUUSD Suitability: **2/5** — strong, genuinely gold-specific volatility/session/profile/min-stop
  design, CAPPED by the dormant news/event filter on the production config (the rubric's explicit red
  flag and gold's #1 risk dimension) plus non-uniform min-stop enforcement.
