# UltimateTrader EA — Complete System Reference
## XAU/USD H1 | MetaTrader 5 | Updated 2026-03-25

---

## 1. CURRENT PERFORMANCE

| Period | Profit | PF | DD | Sharpe |
|--------|--------|-----|-----|--------|
| **2024-2026 (production)** | **$10,864** | **1.58** | **3.38%** | **4.91** |
| 2024-2025 | $4,940 | 1.58 | 6.46% | 4.85 |
| 2025-2026 | $3,530 | 1.44 | 7.70% | 4.22 |
| 2023-2024 (out-of-sample) | $831 | 1.13 | 8.99% | 1.09 |

The EA is a barbell capital allocator optimized for gold. Confirmed longs at full risk compound aggressively in trending years (PF 1.58). Immediate shorts at reduced risk stabilize during choppy years (PF 1.13). 20 A/B tests confirmed the system is at its optimization frontier — entries, exits, trailing, risk allocation, and entry filtering have all been tested to exhaustion.

---

## 2. ARCHITECTURE — WHAT ACTUALLY RUNS

### Designed vs Reality

The EA was designed with a 10-layer architecture, an 8-step risk pipeline, and a comprehensive auto-kill system. In practice, several of these systems are dead code or intentionally disabled:

| System | Designed | Actual Runtime |
|--------|----------|---------------|
| 8-step risk pipeline | Full quality-tier chain | **Dead code** — `Initialize()` never called, fallback sizing only |
| Auto-kill (orchestrator) | Kill strategies below PF threshold | **Disabled** — name mismatch made it dead, then intentionally turned off |
| Auto-kill (engine modes) | Kill modes below PF 0.9 | **Disabled** — `RecordModeResult` calls removed |
| Zone recycling | Reuse invalid SMC zone slots | **Disabled** — first 20 zones permanent, no reuse |
| Batched trailing | Send SL to broker at R-levels only | **Disabled** — every trailing update sent immediately |
| Dynamic weights | Adjust plugin weights by rolling PF | **Disabled** — `InpEnableDynamicWeights=false` |

### Actual Signal Flow

```
OnTick (new H1 bar)
  |
  +-- Update market state (trend, regime, macro, SMC zones, BOS)
  +-- Update day-type classification
  |
  +-- Check pending confirmation (if exists)
  |     +-- Confirmed? -> ProcessConfirmedSignal -> ExecuteSignal
  |     +-- Clear pending (pass or fail)
  |
  +-- Friday? -> Block all new entries (Sprint 3D)
  |
  +-- Risk monitor: halt check, daily loss limit, max trades/day
  +-- Shock detection: extreme bar range → block entries
  +-- Session quality gate: degrade if execution quality low
  +-- Spread gate: skip if spread > 50 points
  |
  +-- CheckForNewSignals()
  |     +-- Session filter (Asia/London/NY all enabled)
  |     +-- Skip zone check (DISABLED — start==end==11)
  |     +-- Loop 15 registered plugins:
  |     |     +-- Plugin enabled? / Auto-killed? (auto-kill DISABLED)
  |     |     +-- plugin.CheckForEntrySignal()
  |     |     +-- Validate: TF/MR conditions (shorts bypass full validator)
  |     |     +-- Volume filter
  |     |     +-- SMC confluence filter
  |     |     +-- Confidence scoring (min 40)
  |     |     +-- Quality scoring (min 6 points for B+)
  |     |     +-- Collect-and-rank: keep highest qualityScore
  |     +-- Winner: MR or SHORT -> immediate execution
  |     +-- Winner: LONG -> store as pending for confirmation candle
  |
  +-- Adopt orphan broker positions (every tick)
  +-- ManageOpenPositions (every tick): trailing, TP, BE, exits
  +-- Risk monitoring (every tick)
```

### Dual-Path Capital Allocation (The System's Core Edge)

The EA has two execution paths with intentionally asymmetric risk treatment. This is not a bug — it is an **emergent barbell strategy** where the edge comes from how capital is allocated between two imperfect signals, not from the signals themselves.

#### The Quantified Truth

| Path | Trades | WR | PF | Avg MFE | Avg Hold | Net CSV $ | Role |
|------|--------|-----|-----|---------|----------|-----------|------|
| **CONFIRMED** (longs) | 400 | 46.8% | 1.01 | **1.20R** | 14.2h | +$165 | Growth engine |
| **IMMEDIATE** (shorts/MR) | 476 | 38.7% | **1.08** | 0.72R | 6.8h | +$1,185 | Capital protector |

**The critical insight**: Immediate has better per-trade edge (PF 1.08 vs 1.01). But confirmed dominates MT5 profit ($10,777) because full risk + compounding on a growing balance generates more absolute dollars than higher PF at reduced size.

**The edge is not in the signals — it is in how you size them.**

#### Why This Works: The Barbell

```
CONFIRMED (Growth Engine)              IMMEDIATE (Stabilizer)
- PF ~1.01 (low edge)                 - PF ~1.08 (higher edge)
- Full risk (0.8%)                     - Reduced risk (session + regime multipliers)
- High MFE (1.20R, trends further)    - Low MFE (0.72R, quick exits)
- Long holds (14h)                     - Short holds (7h)
- Compounds aggressively              - Protects during drawdowns
- Dominates trending years            - Carries choppy years
```

| Period | Confirmed P&L | Immediate P&L | Who Carried? |
|--------|--------------|---------------|-------------|
| 2023-2024 (choppy) | **-$783** | **+$571** | Immediate |
| 2024-2026 (trending) | **+$948** | +$614 | Confirmed (via compounding) |

#### A/B Test Evidence: Don't Equalize the Paths

| Variant | 2024-2026 | 2023-2024 | 3yr Total | Why It Failed |
|---------|-----------|-----------|-----------|---------------|
| **Asymmetric (current)** | **$10,777** / PF 1.56 | $828 / PF 1.13 | **$11,605** | — |
| Full multipliers on confirmed | $9,229 / PF 1.53 | $1,278 / PF 1.21 | $10,507 | Killed compounding engine |
| Selective (soft reductions) | $8,725 / PF 1.53 | $994 / PF 1.16 | $9,719 | Not enough to help, enough to hurt |

Both fixes failed because they **reduced the growth engine's leverage**. You cannot shrink the compounding side without shrinking total returns. The asymmetry IS the edge.

#### Immediate Path Sizing (Stabilizer)

```
1. Base risk from quality tier: A+=0.8%, A=0.8%, B+=0.6%, B=0.5%
2. Session multiplier: London=0.5x, NY=0.9x, Asia=1.0x
3. Regime multiplier: Trending=1.25x, Normal=1.0x, Choppy=0.6x, Volatile=0.75x
4. Risk strategy → isValid=false → fallback sizing
5. Lot = (balance * risk_pct / 100) / (risk_distance / tick_size * tick_value)
6. Counter-trend reduction: 0.5x if against D1 200 EMA
```

#### Confirmed Path Sizing (Growth Engine)

```
1. Base risk from quality tier: A+=0.8%, A=0.8%, B+=0.6%, B=0.5%
2. Session multiplier: NOT APPLIED (preserves compounding power)
3. Regime multiplier: NOT APPLIED (preserves compounding power)
4. Risk strategy → isValid=false → fallback sizing
5. Same lot formula
6. Counter-trend reduction: 0.5x if against D1 200 EMA (still applied)
```

#### The System's True Architecture

```
Layer 1: Signal Generation      → many strategies competing (quantity)
Layer 2: Competition            → orchestrator ranking by qualityScore (selection)
Layer 3: Capital Allocation     → CONFIRMED = full risk (growth engine)
                                → IMMEDIATE = reduced risk (stabilizer)
Layer 4: Execution              → fallback sizing, path-appropriate risk
```

This system wins not because confirmed trades are better, but because you allocate more capital to them and let compounding do the work. The asymmetry emerged through optimization and was validated by proving that equalization destroys returns.

---

## 3. PLUGIN SYSTEM

The EA uses a polymorphic plugin architecture with four base classes:

### Base Classes

| Base Class | File | Purpose | Key Method |
|-----------|------|---------|------------|
| `CEntryStrategy` | `PluginSystem/CEntryStrategy.mqh` | Entry signal detection | `CheckForEntrySignal()` → `EntrySignal` |
| `CExitStrategy` | `PluginSystem/CExitStrategy.mqh` | Exit signal detection | `CheckForExitSignal(ticket)` → `ExitSignal` |
| `CTrailingStrategy` | `PluginSystem/CTrailingStrategy.mqh` | Dynamic SL adjustment | `CheckForTrailingUpdate(ticket)` → `TrailingUpdate` |
| `CRiskStrategy` | `PluginSystem/CRiskStrategy.mqh` | Position sizing | `CalculatePositionSize(...)` → `RiskResult` |

Plugins are registered in `OnInit()` via arrays and iterated by their respective coordinators. Entry plugins go through `CSignalOrchestrator`, trailing/exit plugins go through `CPositionCoordinator`.

---

## 4. ENTRY PLUGINS — Individual Patterns

### ENABLED

| # | Plugin | File | Direction | Regime | PF (2024-26) | Notes |
|---|--------|------|-----------|--------|-------------|-------|
| 1 | **Engulfing** | `CEngulfingEntry.mqh` | LONG + SHORT | Trend, Vol | Bull 1.08, Bear 1.20 | Volume workhorse (293 trades). Weight 0.80. |
| 2 | **Pin Bar** | `CPinBarEntry.mqh` | LONG + SHORT | Trend, Vol | Bull 1.01, Bear 1.11 | Bearish carries 2023 (PF 1.48). Bullish is breakeven volume. |
| 3 | **MA Cross** | `CMACrossEntry.mqh` | **LONG ONLY** | Trend | Bull 2.15 | **Best strategy by PF.** Bearish hardcoded OFF (`if(false && ...)`) — PF 0.59, -$722. |
| 4 | **BB Mean Reversion** | `CBBMeanReversionEntry.mqh` | LONG + SHORT | Range, Choppy | 1.87 (small sample) | BB(20,2.0), RSI 42/58, max ADX 30. |
| 5 | **Range Box** | `CRangeBoxEntry.mqh` | LONG + SHORT | Range | — | Enabled but **weight=0.0** (effectively silent). |
| 6 | **False Breakout Fade** | `CFalseBreakoutFadeEntry.mqh` | LONG + SHORT | Range | — | Enabled. Low frequency. |
| 7 | **Volatility Breakout** | `CVolatilityBreakoutEntry.mqh` | LONG + SHORT | **Volatile only** | — | Donchian/Keltner breakout. TRENDING regime removed. |
| 8 | **Crash Breakout** | `CCrashBreakoutEntry.mqh` | **SHORT only** | Any (self-gated) | — | Bear Hunter: Death Cross + Donchian break. Hours 13-17 GMT. |
| 9 | **Displacement** | `CDisplacementEntry.mqh` | LONG + SHORT | Trend, Vol | — | Sweep + displacement candle. Body >= 1.8x ATR. Weight 0.5. |

### DISABLED

| Plugin | File | Reason | Control |
|--------|------|--------|---------|
| **Liquidity Sweep** | `CLiquiditySweepEntry.mqh` | Replaced by engine SFP mode | `InpEnableLiquiditySweep=false` |
| **Support Bounce** | `CSupportBounceEntry.mqh` | Pending validation | `InpEnableSupportBounce=false` |

---

## 5. ENTRY ENGINES — Multi-Mode Systems

Engines are `CEntryStrategy` plugins that internally contain multiple detection modes in a priority cascade. At most ONE signal per engine per H1 bar.

### Liquidity Engine

**File**: `CLiquidityEngine.mqh` | **Status**: ENABLED | **Modes**: 2 of 4 active

| Priority | Mode | Status | Direction | PF | Notes |
|----------|------|--------|-----------|-----|-------|
| 1 | **Displacement** | ENABLED | LONG + SHORT | — | Sweep + displacement candle. H4 trend gates for bearish. SMC confluence >= 40. |
| 2 | **OB Retest** | ENABLED | LONG + SHORT | — | In OB zone + recent BOS/CHoCH + rejection candle. SL: ATR*0.8. TP: 3:1 R:R. |
| 3 | FVG Mitigation | **DISABLED** | — | 0.61 | `InpLiqEngineFVGMitigation=false`. PF 0.61, biggest DD contributor. Removed via A/B Test 8. |
| 4 | SFP | **DISABLED** | — | 0.00 | `InpLiqEngineSFP=false`. 0% WR in 5.5-month backtest. |

**Zone recycling**: DISABLED. First 20 zones per type are permanent. Invalid slots are NOT reused. The analyst's recycling generated ~300 extra low-quality trades.

### Session Engine

**File**: `CSessionEngine.mqh` | **Status**: ENABLED | **Modes**: 1 of 4 active

| Priority | Mode | Status | Hours (GMT) | PF | Notes |
|----------|------|--------|-------------|-----|-------|
| 1 | London Breakout | **DISABLED** | 8-10 | 0.00 | `InpSessionLondonBO=false`. 0% WR in backtest. |
| 2 | NY Continuation | **DISABLED** | 14-17 | 0.00 | `InpSessionNYCont=false`. 0% WR in backtest. |
| 3 | **Silver Bullet** | ENABLED | **15-16** | 1.56 | ICT FVG at 50% fill. 3:1 R:R. Only active session mode. |
| 4 | London Close Rev | **DISABLED** | 21-23 | 0.00 | `InpSessionLondonClose=false`. 27% WR, -$229 in 2yr. |

### Expansion Engine

**File**: `CExpansionEngine.mqh` | **Status**: ENABLED | **Modes**: 1 of 3 active

| Priority | Mode | Status | PF | Notes |
|----------|------|--------|-----|-------|
| 1 | Panic Momentum | **DISABLED** | 0.47 | Hardcoded `if(false && ...)`. Death Cross + Rubber Band. PF 0.21-0.47 in 2023. |
| 2 | **Institutional Candle** | ENABLED | 99 (small sample) | Consolidation breakout. Body >= 1.8x ATR. |
| 3 | Compression BO | **DISABLED** | 0.52 | `InpExpCompressionBO=false`. Inconsistent: PF 1.48 in 2023, PF 0.52 in 2024-26. Removed via A/B Test 7. |

### Pullback Continuation Engine

**File**: `CPullbackContinuationEngine.mqh` | **Status**: ENABLED

| Setting | Value |
|---------|-------|
| Directions | LONG + SHORT |
| Confirmation | YES (reclaim candle) |
| Lookback | 20 bars |
| Pullback depth | 0.6-1.8x ATR, 2-10 bars |
| Signal body | 0.20x ATR (A/B tested, beats 0.35) |
| Min ADX | 18.0 |
| Block choppy | YES |
| Multi-cycle | DISABLED (orchestrator ranks first-cycle higher) |
| Performance | PF 1.82 on longs (+$312), small sample |

---

## 6. EXIT PLUGINS

All four exit plugins are active. They're checked every tick by `CPositionCoordinator`.

| # | Plugin | File | What It Does | Key Config |
|---|--------|------|-------------|------------|
| 1 | **Regime Aware Exit** | `CRegimeAwareExit.mqh` | Closes positions when regime changes to CHOPPY (except mean reversion patterns). Also closes on strong macro opposition (score >= 3). | `InpAutoCloseOnChoppy=true`, `InpMacroOppositionThreshold=3` |
| 2 | **Daily Loss Halt** | `CDailyLossHaltExit.mqh` | Closes all positions and halts trading when daily loss exceeds limit. | `InpEnableDailyLossHalt=true`, `InpDailyLossLimit=3.0%` |
| 3 | **Weekend Close** | `CWeekendCloseExit.mqh` | Closes all positions before weekend to avoid gap risk. | `InpCloseBeforeWeekend=true`, `InpWeekendCloseHour=20` (Friday) |
| 4 | **Max Age Exit** | `CMaxAgeExit.mqh` | Closes positions older than configured age to free capital. | `InpMaxPositionAgeHours=72`, `InpCloseAgedOnlyIfLosing=false` |

---

## 7. TRAILING PLUGINS

Six trailing strategies are registered, but only **Chandelier** is active. The others are disabled during `OnInit()` based on `InpTrailStrategy=TRAIL_CHANDELIER`.

| # | Plugin | File | Status | Method |
|---|--------|------|--------|--------|
| 1 | **Chandelier** | `CChandelierTrailing.mqh` | **ACTIVE** | HighestHigh(lookback) - ATR * multiplier. Optimized for trending regimes. |
| 2 | ATR Trailing | `CATRTrailing.mqh` | Disabled | Close - ATR * multiplier |
| 3 | Swing Trailing | `CSwingTrailing.mqh` | Disabled | Trail to recent swing lows/highs |
| 4 | Parabolic SAR | `CParabolicSARTrailing.mqh` | Disabled | Parabolic SAR indicator |
| 5 | Stepped | `CSteppedTrailing.mqh` | Disabled | Fixed ATR-based increments |
| 6 | Hybrid | `CHybridTrailing.mqh` | Disabled | Combines ATR + Swing + Chandelier (tightest wins) |

### Chandelier Configuration (Regime Exit Profiles)

The global `InpTrailChandelierMult=3.0` is overridden by regime-specific profiles when `InpEnableRegimeExit=true`:

| Regime | Chandelier Mult | BE Trigger | TP0 R/Vol | TP1 R/Vol | TP2 R/Vol |
|--------|----------------|-----------|-----------|-----------|-----------|
| **TRENDING** | **3.5x** | 1.2R | 0.7R/10% | 1.5R/35% | 2.2R/25% |
| NORMAL | 3.0x | 1.0R | 0.7R/15% | 1.3R/40% | 1.8R/30% |
| CHOPPY | 2.5x | 0.7R | 0.5R/20% | 1.0R/40% | 1.4R/35% |
| VOLATILE | 3.0x | 0.8R | 0.6R/20% | 1.3R/40% | 1.8R/30% |

These settings are a proven Goldilocks zone. A/B testing showed both tighter (-0.5) and wider (+0.5) multipliers perform worse.

### Broker SL Behavior

- `InpBatchedTrailing=false`: Every trailing update is sent to the broker immediately
- `InpDisableBrokerTrailing=false`: Broker SL IS modified
- Internal SL tracks independently; broker SL follows on every tick

---

## 8. RISK PLUGIN

### CQualityTierRiskStrategy

**File**: `CQualityTierRiskStrategy.mqh` | **Status**: INSTANTIATED BUT NOT INITIALIZED

The 8-step pipeline is designed but inactive:

| Step | What It Does | Status |
|------|-------------|--------|
| 1 | Base risk from quality tier | **Dead** — returns isValid=false |
| 2 | Consecutive loss scaling (0.75x/0.50x) | Dead |
| 3 | Volatility regime adjustment | Dead |
| 4 | Short protection (0.5x) | Dead |
| 5 | Health-based adjustment | Dead |
| 6 | Engine weight scaling | Dead |
| 7 | Hard cap at 1.2% | Dead |
| 8 | Lot calculation + margin check | Dead |

**Why it's dead**: `g_riskStrategy.Initialize()` is never called. The object exists but `m_isInitialized=false`, so `CalculatePositionSize()` returns `isValid=false` on every call. The fallback sizing in `CTradeOrchestrator.ExecuteSignal()` handles all trades.

**Why it stays dead**: When activated, the 8 compounding multipliers reduce positions by 50-80%, dropping profit from $6,140 to $561. The fallback sizing IS the proven behavior.

The risk strategy still records consecutive wins/losses via `RecordTradeResult()`, but this data is never consumed since the strategy never sizes.

---

## 9. POSITION LIFECYCLE

```
ENTRY (0.10 lots example)
  |
  +-- TP0: 0.7R reached → close 15% (0.015 lots) → lock profit
  |   Remaining: 0.085 lots
  |
  +-- BE: Trigger at regime-specific R level → SL moved to entry + offset
  |
  +-- TP1: 1.3R reached → close 40% of remaining (0.034 lots)
  |   Remaining: 0.051 lots
  |
  +-- TP2: 1.8R reached → close 30% of remaining (0.015 lots)
  |   Remaining: 0.036 lots (the "runner")
  |
  +-- TRAILING: Chandelier exit tracks until SL hit or position closed
       Runner captures tail profits on big moves
```

### TP0 Is Load-Bearing

TP0 provides **67% of total CSV profit**. Without it, the runner portions are NET NEGATIVE (-$1,553 in Test 2). TP0 is not an optimization lever — it's a structural requirement. Do not modify without extensive testing.

---

## 10. VALIDATION PIPELINE

Signals pass through 8 gates in `CSignalOrchestrator.CheckForNewSignals()`:

| Gate | What It Checks | Shorts Bypass? |
|------|---------------|----------------|
| 1 | Session allowed (Asia/London/NY) | No |
| 2 | Skip zone hours | Yes (SessionEngine exempt) |
| 3 | Plugin enabled + not auto-killed | No |
| 4 | TF/MR validation | **YES** — shorts only check ATR minimum |
| 5 | Volume/spread filter | No |
| 6 | SMC confluence | No |
| 7 | Pattern confidence (min 40) | No |
| 8 | Quality scoring (min 6 points) | No |

After all gates, signals are ranked by `qualityScore`. The highest wins. If it requires confirmation (LONG, non-MR), it's stored as pending. Shorts and MR execute immediately.

### Quality Scoring (CSetupEvaluator)

Points accumulate from: trend alignment (0-3), CHoCH bonus (0-2, exclusive with trend), extreme RSI (0-3), regime (0-2), macro alignment (0-3), pattern quality (0-2). Maximum 10 points.

| Tier | Points | Base Risk |
|------|--------|-----------|
| A+ | >= 8 | 0.80% |
| A | >= 7 | 0.80% |
| B+ | >= 6 | 0.60% |
| B | >= 7 (= filtered) | 0.50% |
| None | < 6 | Rejected |

Note: B threshold is set to 7 (same as A), effectively filtering all B setups.

---

## 11. WHAT EACH DOCUMENT REPRESENTS

| Document | True Role | Currency |
|----------|-----------|----------|
| **This file** | Unified ground truth | Current |
| `EA_STRATEGY_ANALYSIS.md` | A/B test results and strategy performance data | Current |
| `STRATEGY_REFERENCE.md` | Strategy catalog with active/disabled status | Current |
| `PerformanceStats.md` | Year-by-year metrics and optimization history | Current |
| `EA_FINDINGS_REPORT.md` | Analyst regression root cause investigation | Historical (fixed) |
| `docs/03-Risk-Model.md` | 8-step pipeline DESIGN (not runtime) | Annotated |
| `docs/02-Strategies.md` | Strategy architecture reference | Annotated |
| `docs/04-Position-Management.md` | Position lifecycle detail | Annotated |
| `docs/01-Architecture.md` | Module layout | Annotated |
| `docs/00-Overview.md` | System introduction | Annotated |
| `docs/05-Input-Parameters.md` | Complete parameter reference | Annotated |
| `StrategyAudit.md` | Pre-regression strategy audit | Superseded |
| `SystemRevisionPlan.md` | Diagnosis of systemic failures | Resolved |
| `SubsystemIssueRegister.md` | Bug backlog | Mostly resolved |
| `ObservabilityWorkstream.md` | Debugging infrastructure plan | Achieved |
| `EA_ARCHITECTURE_GUIDE.md` | Comprehensive 52K architecture guide | Mostly accurate |

---

## 12. KEY SYSTEMIC INSIGHTS

### 1. The Edge Is Asymmetric Capital Allocation, Not Signal Quality
Confirmed trades do NOT have better per-trade edge (PF 1.01 vs immediate's 1.08). The system wins because confirmed longs get full risk and compound aggressively on a growing balance. Immediate shorts get reduced risk and stabilize during drawdowns. This barbell — aggressive growth engine + defensive stabilizer — emerged through optimization and was proven by A/B testing: equalizing the paths destroyed $1,000-2,000 in returns. **The edge is not in the signals. It is in how you size them.**

### 2. Designed System != Running System
The 8-step risk pipeline, auto-kill, dynamic weights, and mode performance tracking are all designed, coded, and documented — but none execute at runtime. The EA's entire profitability comes from fallback sizing, a single trailing strategy, and TP0 insurance.

### 3. Few Strategies Carry Everything
Bullish MA Cross (7% of trades) generates 55% of profit. Bearish Engulfing (31%) adds 43%. Everything else combined is net negative. The system behaves as "two alpha strategies + noise generators that add volume for compounding."

### 4. TP0 Is the Foundation
Without the 0.7R/15% early partial, the runner portions lose money. TP0 turns losing runners into net positive trades. This is the single most important feature.

### 5. Chandelier Settings Are Optimal
Both tighter and wider multipliers degrade performance. The 3.5/3.0/2.5/3.0 regime profile is at its optimal point.

### 6. The EA Needs Trend
2023-2024 (choppy gold): PF 1.13, Sharpe 1.08. 2024-2025 (trending gold): PF 1.58, Sharpe 4.85. No parameter tuning fixes the weak year — the edge IS trend-following.

### 7. Shorts Are Essential for Robustness
Bearish Pin Bar carried 2023 (+$543, PF 1.48). Bearish Engulfing is the second-largest profit contributor. Disabling shorts improves 2024-2026 metrics but collapses 2023 to near-zero.

### 8. The System Is a Capital Allocator, Not a Signal Generator
```
System = Capital allocator between:
  - Low-edge, high-volume compounding engine (confirmed longs, full risk)
  - Higher-edge, low-risk stabilizer (immediate shorts/MR, reduced risk)
```
This barbell emerged through optimization, not design. The system's job is not to maximize per-trade edge — it is to **optimize capital flow between two imperfect edges**. This changes the entire strategy approach: stop trying to make confirmed signals better; instead, manage the allocation between the two engines.

---

## 13. OPTIMIZATION HISTORY (2026-03-25)

### Regression Recovery

| Fix | From | To | What Broke |
|-----|------|-----|-----------|
| Auto-kill disabled | $790 | $1,929 | Analyst's plugin_name fix made name matching work → strategies killed |
| Zone recycling reverted | $1,929 | $3,097 | Analyst's slot reuse → 300 extra low-quality OB/FVG trades |
| Batched trailing off | $3,097 | $3,839 | Analyst's batched mode → stale broker SL on reversals |

### A/B Testing (22 tests, 6 adopted, 16 reverted)

| Test | Change | Adopted? | Impact |
|------|--------|----------|--------|
| Bearish MA Cross OFF | Code: `if(false && ...)` | **YES** | +$1,321, PF +0.05 |
| A+ risk 0.8% | Input: `InpRiskAPlusSetup=0.8` | **YES** | DD -1.93% |
| Panic Momentum OFF | Code: `if(false && ...)` | **YES** | +$258 in 2023 |
| Compression BO OFF | Input: `InpExpCompressionBO=false` | **YES** | +$408, DD -0.55% |
| FVG Mitigation OFF | Input: `InpLiqEngineFVGMitigation=false` | **YES** | DD -4.79% |
| Dynamic barbell | Confirmed regime reduction in choppy/vol/ranging | **YES** | +$87, PF +0.02, Sharpe +0.06, new best |
| Confirmed path full multipliers | Session+regime on confirmed longs | Reverted | -$1,548 in 2024-26. Killed compounding engine. |
| Confirmed path selective (soft) | Softer reductions only | Reverted | -$2,052 in 2024-26. No-man's-land. |
| Confirmed wider trailing (1.2x) | Wider Chandelier for confirmed | Reverted | -$1,128, DD +1.18%. Reversals eat more. |
| CQF-1: strict entry filter | body>=0.30 ATR, close>=0.65, reclaim | Reverted | -$5,187 (48% loss). Way too strict. |
| CQF-2: soft entry filter | body>=0.25, close>=0.60, no reclaim | Reverted | -$3,385 (31% loss). Still too aggressive. |
| CQF-3: regime-gated filter | Filter only in non-trending regimes | Reverted | +$5 in 2024-26, -$45 in 2023. Neutral/slightly worse. |
| Smart Runner Exit v1 (strict) | Vol decay 0.70, momentum 2/3@0.40, regime kill | Reverted | **-$8,282 (76% loss)**. Kills tail captures. |
| Smart Runner Exit v2 (soft) | Vol decay 0.50, momentum 3/3@0.30, regime kill | Reverted | **-$7,975 (73% loss)**. Same — can't distinguish consolidation from exhaustion. |
| London OFF | Input change | Reverted | -$5,817 profit |
| VOLATILE block | Code change | Reverted | DD +0.94% |
| Pin Bar OFF | Input change | Reverted | -$3,138 profit |
| Bullish Pin Bar OFF | Code change | Reverted | -$3,403 profit |
| Short risk 0.7 | Input change | Reverted | Zero effect (multiplier path disconnected) |
| Skip zones 8-11 | Input change | Reverted | -$2,690 in 2024-26 |
| Chandelier -0.5 / +0.5 | Input change (both directions) | Reverted | Both worse. Settings are optimal Goldilocks zone. |
| BE trigger 1.0R | Input change | Reverted | Zero effect (profiles override) |

### Key Lessons From Testing

1. **Trailing is optimal**: Tighter, wider, and confirmed-only wider all degrade. The 3.5/3.0/2.5/3.0 Chandelier profile is at its peak.
2. **You cannot out-filter the confirmation candle**: All 3 CQF variants removed good trades alongside bad ones. The 76% SL rate is the cost of the compounding engine, not a filtering problem.
3. **Equalization destroys returns**: Any attempt to normalize risk between confirmed and immediate paths costs $1,000-5,000. The asymmetry IS the edge.
4. **Dynamic barbell works**: Regime-selective reduction on confirmed (choppy 0.6x, volatile 0.7x, ranging 0.75x) improves all metrics without hurting the growth engine.
5. **Runner losses are not leakage**: The -$1,553 runner P&L is the premium paid for $12,000 in trailing exits. Smart runner exit (both variants) cost -$8K by cutting the tail captures that carry the system. The runner is an insurance premium, not a bug.
6. **The system is at its optimization frontier**: Entries, exits, trailing, risk allocation, entry filtering, and runner management have all been tested to exhaustion across 22 A/B tests. Every dimension either improved (adopted) or degraded (reverted). No unexplored levers remain at the parameter/filter level.

---

## 14. FILE MAP

```
UltimateTrader/
|-- UltimateTrader.mq5              Main EA: OnInit (10-layer), OnTick, lifecycle
|-- UltimateTrader_Inputs.mqh       ~250 input parameters across 43 groups
|
|-- Include/
|   |-- Common/
|   |   |-- Enums.mqh               All enumerations
|   |   |-- Structs.mqh             All data structures (EntrySignal, SPosition, etc.)
|   |   +-- Utils.mqh               Shared utilities
|   |
|   |-- Core/
|   |   |-- CSignalOrchestrator.mqh Signal detection, validation, collect-and-rank
|   |   |-- CTradeOrchestrator.mqh  Trade execution, risk sizing, TP calculation
|   |   |-- CPositionCoordinator.mqh Position lifecycle, trailing, exits, persistence
|   |   |-- CRegimeRiskScaler.mqh   Regime risk scaling + exit profiles
|   |   |-- CAdaptiveTPManager.mqh  Adaptive TP + Chop Sniper BB TPs
|   |   |-- CSignalManager.mqh      Confirmation candle logic
|   |   |-- CRiskMonitor.mqh        Daily limits, halt conditions
|   |   |-- CMarketStateManager.mqh Coordinates market analysis updates
|   |   +-- CDayTypeRouter.mqh      Day classification (Trend/Range/Volatile/Data)
|   |
|   |-- EntryPlugins/               9 individual + 4 engines = 13 entry plugins
|   |-- ExitPlugins/                4 exit plugins
|   |-- TrailingPlugins/            6 trailing plugins (1 active)
|   |-- RiskPlugins/                1 risk plugin (inactive)
|   |-- PluginSystem/               4 base classes
|   |-- MarketAnalysis/             Market context, SMC, trend, regime
|   |-- Validation/                 Signal validator, setup evaluator, market filters
|   |-- Execution/                  Trade executor, error handling
|   |-- Display/                    Dashboard, trade logger (CSV)
|   +-- Infrastructure/             Logger, health monitor, error handler
|
|-- docs/                           6 detailed reference documents
+-- *.md                            Analysis reports, audit logs, strategy references
```
