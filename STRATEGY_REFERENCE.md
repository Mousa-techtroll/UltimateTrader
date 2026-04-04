# UltimateTrader Strategy Reference
## Complete Strategy Catalog — Current Code State (2026-03-25)

---

## ACTIVE STRATEGIES

### Individual Entry Plugins

#### 1. Engulfing Entry
- **File**: `Include/EntryPlugins/CEngulfingEntry.mqh`
- **Directions**: LONG + SHORT
- **Signals**: Bullish Engulfing (score 92), Bearish Engulfing (score 75)
- **Regime**: TRENDING, VOLATILE
- **Confirmation**: Longs use confirmation candle; shorts skip
- **Performance**: Bullish PF 1.08 (+$545), Bearish PF 1.20 (+$1,062) — workhorse strategy
- **Key Params**: Body engulf ratio 0.8, ATR SL 1.5x, RR target 2.0
- **Weight**: 0.80

#### 2. Pin Bar Entry
- **File**: `Include/EntryPlugins/CPinBarEntry.mqh`
- **Directions**: LONG + SHORT
- **Signals**: Bullish Pin Bar (score 88), Bearish Pin Bar (score 60)
- **Regime**: TRENDING, VOLATILE
- **Confirmation**: Longs use confirmation candle; shorts skip
- **Performance**: Bullish PF 1.01 (breakeven volume), Bearish PF 1.11 (+$317, carries 2023)
- **Key Params**: Wick-to-body ratio 1.5x, close in 70%+ of range
- **Weight**: 1.0

#### 3. MA Cross Entry (LONG ONLY)
- **File**: `Include/EntryPlugins/CMACrossEntry.mqh`
- **Directions**: LONG only (bearish disabled via `if(false && ...)`)
- **Signals**: Bullish MA Cross (score 82)
- **Regime**: TRENDING
- **Confirmation**: Longs use confirmation candle
- **Performance**: Bullish PF 2.15 (+$1,369) — **best strategy by PF**
- **Key Params**: Fast MA 10, Slow MA 21, SL factor 0.67x (tighter), min SL 150pts
- **Weight**: 1.0
- **Note**: Bearish MA Cross disabled (PF 0.59, -$722 over 2yr)

#### 4. BB Mean Reversion Entry
- **File**: `Include/EntryPlugins/CBBMeanReversionEntry.mqh`
- **Directions**: LONG + SHORT
- **Regime**: RANGING, CHOPPY
- **Confirmation**: Shorts skip (mean reversion)
- **Performance**: Small sample, PF 1.87 on shorts
- **Key Params**: BB(20,2.0), RSI oversold 42 / overbought 58, max ADX 30, max ATR 30
- **Weight**: 1.0

#### 5. Range Box Entry
- **File**: `Include/EntryPlugins/CRangeBoxEntry.mqh`
- **Directions**: LONG + SHORT
- **Regime**: RANGING
- **Confirmation**: Standard
- **Key Params**: Range lookback 30, min range 200pts, max 5000pts, entry zone 25%
- **Weight**: 0.0 (effectively disabled by weight)

#### 6. False Breakout Fade Entry
- **File**: `Include/EntryPlugins/CFalseBreakoutFadeEntry.mqh`
- **Directions**: LONG + SHORT
- **Regime**: RANGING
- **Confirmation**: Standard
- **Key Params**: Swing lookback 20, max ADX 30, min RR 1.2
- **Weight**: 1.0 (enabled but rarely fires)

#### 7. Volatility Breakout Entry
- **File**: `Include/EntryPlugins/CVolatilityBreakoutEntry.mqh`
- **Directions**: LONG + SHORT
- **Regime**: VOLATILE only (TRENDING removed to match baseline)
- **Confirmation**: Standard
- **Key Params**: Donchian 14, Keltner EMA 20/ATR 20/Mult 1.5, min ADX 26, cooldown 4 bars
- **Weight**: 1.0

#### 8. Crash Breakout Entry (Bear Hunter)
- **File**: `Include/EntryPlugins/CCrashBreakoutEntry.mqh`
- **Directions**: SHORT only
- **Regime**: Any (self-gated by Death Cross detection)
- **Confirmation**: N/A (short = immediate)
- **Key Params**: D1 EMA50 < EMA200, ATR mult 1.1, SL ATR 2.5, hours 13-17 GMT
- **Weight**: 1.0

#### 9. Displacement Entry (Standalone)
- **File**: `Include/EntryPlugins/CDisplacementEntry.mqh`
- **Directions**: LONG + SHORT
- **Regime**: TRENDING, VOLATILE
- **Confirmation**: Standard (longs)
- **Key Params**: Displacement body 1.8x ATR, sweep buffer 30pts
- **Weight**: 0.5

---

### Entry Engines

#### 10. Liquidity Engine
- **File**: `Include/EntryPlugins/CLiquidityEngine.mqh`
- **Enabled Modes**:
  - **Displacement**: Sweep + displacement candle (priority 1)
  - **OB Retest**: Order block retest with BOS + rejection candle (priority 2)
- **Disabled Modes**:
  - FVG Mitigation (`InpLiqEngineFVGMitigation=false`) — PF 0.61, biggest DD contributor
  - SFP (`InpLiqEngineSFP=false`) — 0% WR in 5.5mo
- **Directions**: LONG + SHORT
- **H4 Gates**: Bearish signals blocked when H4 is BULLISH
- **OB Retest Requirements**: In bullish/bearish OB zone + recent BOS/CHoCH + rejection candle + ATR*0.8 SL
- **Note**: Zone recycling is disabled — only first 20 zones per type are tracked

#### 11. Session Engine
- **File**: `Include/EntryPlugins/CSessionEngine.mqh`
- **Enabled Modes**:
  - **Silver Bullet**: ICT FVG at 50% fill, hours 15-16 GMT
- **Disabled Modes**:
  - London Breakout (`InpSessionLondonBO=false`) — 0% WR
  - NY Continuation (`InpSessionNYCont=false`) — 0% WR
  - London Close Rev (`InpSessionLondonClose=false`) — 27% WR, -$229
- **Directions**: LONG + SHORT

#### 12. Expansion Engine
- **File**: `Include/EntryPlugins/CExpansionEngine.mqh`
- **Enabled Modes**:
  - **Institutional Candle BO**: Consolidation breakout, body 1.8x ATR
- **Disabled Modes**:
  - Panic Momentum (hardcoded `if(false && ...)`) — PF 0.47, pure loser
  - Compression BO (`InpExpCompressionBO=false`) — inconsistent PF across years
- **Directions**: LONG + SHORT

#### 13. Pullback Continuation Engine
- **File**: `Include/EntryPlugins/CPullbackContinuationEngine.mqh`
- **Directions**: LONG + SHORT
- **Confirmation**: YES — reclaim candle confirms continuation
- **Performance**: PF 1.82 on longs (+$312), small sample
- **Key Params**: Lookback 20, pullback 2-10 bars, depth 0.6-1.8x ATR, signal body 0.20 ATR, min ADX 18
- **Multi-cycle**: Disabled (orchestrator ranks first-cycle higher)

---

## DISABLED STRATEGIES

| Strategy | File | Reason | Control |
|----------|------|--------|---------|
| Bearish MA Cross | `CMACrossEntry.mqh` | PF 0.59, -$722 | `if(false && ...)` hardcoded |
| FVG Mitigation | `CLiquidityEngine.mqh` | PF 0.61, DD contributor | `InpLiqEngineFVGMitigation=false` |
| SFP | `CLiquidityEngine.mqh` | 0% WR in 5.5mo | `InpLiqEngineSFP=false` |
| Panic Momentum | `CExpansionEngine.mqh` | PF 0.47, pure loser | `if(false && ...)` hardcoded |
| Compression BO | `CExpansionEngine.mqh` | Inconsistent PF | `InpExpCompressionBO=false` |
| London Breakout | `CSessionEngine.mqh` | 0% WR | `InpSessionLondonBO=false` |
| NY Continuation | `CSessionEngine.mqh` | 0% WR | `InpSessionNYCont=false` |
| London Close Rev | `CSessionEngine.mqh` | 27% WR, -$229 | `InpSessionLondonClose=false` |
| Liquidity Sweep | `CLiquiditySweepEntry.mqh` | Replaced by engine SFP | `InpEnableLiquiditySweep=false` |
| Support Bounce | `CSupportBounceEntry.mqh` | Pending validation | `InpEnableSupportBounce=false` |
| Multi-cycle PBC | `CPullbackContinuationEngine.mqh` | Loses to first-cycle ranking | `InpPBCEnableMultiCycle=false` |

---

## SIGNAL FLOW SUMMARY

```
OnTick (new H1 bar)
  |
  +-- Check pending confirmation (if exists)
  |     +-- Confirmed? -> ProcessConfirmedSignal -> ExecuteSignal
  |     +-- Clear pending
  |
  +-- Friday? -> Block all entries
  |
  +-- Risk monitor check (halt/daily limit)
  +-- Shock detection gate
  +-- Session quality gate
  +-- Spread gate
  |
  +-- CheckForNewSignals()
        |
        +-- Session filter (Asia/London/NY)
        +-- Skip zone check (disabled: 11/11/11/11)
        |
        +-- Loop all plugins:
        |     +-- Auto-kill check (DISABLED globally)
        |     +-- Plugin.CheckForEntrySignal()
        |     +-- Validate: TF/MR conditions (shorts bypass)
        |     +-- Volume filter
        |     +-- SMC confluence filter
        |     +-- Confidence scoring (min 40)
        |     +-- Quality scoring (min 6 points)
        |     +-- Collect-and-rank (best qualityScore wins)
        |
        +-- Winner: MR or SHORT -> immediate execution
        +-- Winner: LONG -> store as pending (confirmation candle)
```

---

## POSITION LIFECYCLE

```
ENTRY -> TP0 (0.7R, 15%) -> BE trigger -> TP1 (1.3R, 40%) -> TP2 (1.8R, 30%) -> Trailing
```

### Regime Exit Profiles (dynamic trailing)

| Regime | BE Trigger | Chandelier | TP0 R/Vol | TP1 R/Vol | TP2 R/Vol |
|--------|-----------|------------|-----------|-----------|-----------|
| TRENDING | 1.2R | 3.5x | 0.7R/10% | 1.5R/35% | 2.2R/25% |
| NORMAL | 1.0R | 3.0x | 0.7R/15% | 1.3R/40% | 1.8R/30% |
| CHOPPY | 0.7R | 2.5x | 0.5R/20% | 1.0R/40% | 1.4R/35% |
| VOLATILE | 0.8R | 3.0x | 0.6R/20% | 1.3R/40% | 1.8R/30% |

### Risk Scaling

| Regime | Entry Risk Multiplier |
|--------|----------------------|
| TRENDING | 1.25x |
| NORMAL | 1.00x |
| CHOPPY | 0.60x |
| VOLATILE | 0.75x |

| Session | Risk Multiplier |
|---------|----------------|
| ASIA | 1.00x |
| LONDON | 0.50x |
| NY | 0.90x |

| Quality | Base Risk |
|---------|-----------|
| A+ | 0.80% |
| A | 0.80% |
| B+ | 0.60% |
| B | 0.50% |

---

## FILE REFERENCE

| File | Purpose |
|------|---------|
| `UltimateTrader.mq5` | Main EA: OnInit (10-layer), OnTick, lifecycle |
| `UltimateTrader_Inputs.mqh` | All input parameters (~250+) |
| `Include/Core/CSignalOrchestrator.mqh` | Signal detection, validation, collect-and-rank |
| `Include/Core/CTradeOrchestrator.mqh` | Trade execution, risk sizing, TP calculation |
| `Include/Core/CPositionCoordinator.mqh` | Position lifecycle, trailing, exits, persistence |
| `Include/Core/CRegimeRiskScaler.mqh` | Regime risk scaling + exit profiles |
| `Include/Common/Structs.mqh` | All data structures |
| `Include/Common/Enums.mqh` | All enumerations |
| `Include/Validation/CSignalValidator.mqh` | TF/MR validation logic |
| `Include/Validation/CSetupEvaluator.mqh` | Quality scoring (0-10 points) |
| `Include/MarketAnalysis/CSMCOrderBlocks.mqh` | SMC zones, BOS, CHoCH, swing detection |
| `Include/Display/CTradeLogger.mqh` | CSV logging, candidates, risk audit |
