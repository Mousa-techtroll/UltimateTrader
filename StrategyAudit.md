# UltimateTrader EA — Strategy Audit (Final)
## Backtest: XAUUSD+ H1 | Mar 2024 — Mar 2026 (2 Years)

> **SUPERSEDED (2026-03-25):** This audit predates the analyst regression and subsequent optimization. Current configuration: $10,777 / PF 1.56 / DD 3.40% / Sharpe 4.85. See `STRATEGY_REFERENCE.md` for active strategy catalog and `EA_STRATEGY_ANALYSIS.md` for current analysis.

### Original configuration | $4,823 net profit | PF 1.58 | 4.6% DD

---

## Final Strategy Results

### Profitable Strategies

| Strategy | Engine | Trades | WR% | PnL | PF | Direction |
|---|---|---|---|---|---|---|
| LiqEng Bull FVG Mitigation | Liquidity | 57 | 63.2% | **+$410** | 1.19 | Long only |
| Bearish Engulfing | Legacy | 86 | 50.0% | **+$334** | 1.14 | Short only |
| Compression BO | Expansion | 3 | 100% | **+$210** | 999 | Short only |
| Silver Bullet | Session | 5 | 40% | **+$55** | 1.55 | Mixed |
| BB Mean Reversion | Legacy | 2 | 50% | **+$10** | 1.44 | Short only |

### Unprofitable / Marginal Strategies

| Strategy | Engine | Trades | WR% | PnL | Issue |
|---|---|---|---|---|---|
| Bullish Engulfing | Legacy | 81 | 53.1% | -$481 | Coord-tracked loss (broker-TP wins offset this in MT5) |
| IC Breakout | Expansion | 2 | 50% | -$79 | Too few trades, marginal |

### Strategies at Zero Trades (Enabled but Silent)

| Strategy | Why Zero | Fixable? | Attempted Fix | Result |
|---|---|---|---|---|
| Displacement | liq_score ≥2 + SMC ≥40 + sweep timing | Tried: lowered gates | REVERTED — flooded system with losers |
| OB Retest | Zone expiration broken (zones never expire, never accumulate properly) | Tried: time-based expiration | REVERTED — also increased bad FVG entries |
| Volatility Breakout | ADX>25 + H4 EMA slope + Donchian break combined too strict | Added REGIME_TRENDING | 0 trades still — H4 slope filter is bottleneck |
| Range Box | REGIME_RANGING rare + tight touch proximity | Not attempted | Low priority |
| Panic Momentum | No Death Cross (gold bull market) | N/A | Correct behavior |
| Crash Breakout | No Death Cross | N/A | Correct behavior |

### Disabled Strategies

| Strategy | Why Disabled | Could Enable? |
|---|---|---|
| LiqEng SFP | 0% WR in 5.5mo backtest | Needs redesign |
| Pin Bar | 23% WR, -$603 | No |
| MA Cross | AvgR -0.9, pure drag | No |
| London Breakout | 0% WR | Needs more data |
| NY Continuation | 0% WR | Needs more data |
| London Close Rev | 27% WR, -$229 | No — fading gold trends is dangerous |
| Early Invalidation | -26.90R net destroyer | Only with structural logic redesign |

---

## What We Learned from the Strategy Audit

### Gates That Must NOT Be Lowered

| Gate | Original Value | Tested Value | Result of Lowering |
|---|---|---|---|
| liq_score | ≥ 2 | ≥ 1 | +162 extra trades, -$2,000 PnL, DD 12.96% |
| SMC confluence (Displacement) | ≥ 40 | ≥ 25 | More losing FVG entries |
| SMC confluence (FVG) | ≥ 40 | ≥ 30 | FVG PnL dropped from +$410 to -$336 |
| H4 trend gate (bearish SMC) | h4 != BULLISH | Removed | Bearish OB -$1,036, Bearish FVG -$1,042 |

**Lesson: The SMC quality gates are correctly calibrated for gold. They look restrictive but they filter out the 70%+ of setups that would lose money.**

### Bearish SMC vs Bearish Engulfing — Why One Works and the Other Doesn't

| | Bearish Engulfing | Bearish SMC (OB/FVG/Displacement) |
|---|---|---|
| Approach | Simple pattern, quick trade | Structural zone-based, requires zone to hold |
| Hold time | Short (avg ~3-5h) | Longer (zone must attract price, then reject) |
| In bull market | Catches pullbacks, quick exit | Zones get blown through by trend |
| WR in bull trend | 50% (survivable) | 7-36% (catastrophic) |
| H4 gate needed? | No (short exposure time) | **Yes** (long exposure, trend kills it) |

### Zone Expiration — The Unsolved Problem

The OB/FVG zone expiration system has a fundamental design flaw:
- `formed_bar` stores the **scan loop index** (2, 5, 15), not an absolute bar number
- `Bars()-1` returns total history length (10,000+), making all zones expire instantly
- Time-based expiration works mathematically but increases zone count, letting in more low-quality entries
- The original code (no expiration) is actually the safest — zones are invalidated by price (mitigation), not age

**To properly fix this:** The `formed_bar` field needs to store an absolute reference (either `Bars() - i` at scan time, or use `formed_time` exclusively). This requires refactoring CSMCOrderBlocks.ScanForOrderBlocks() — a medium-complexity change best done in a dedicated sprint.

---

## Strategy Performance Summary: What Drives the $4,823 Profit

The MT5 net profit comes from three sources:

1. **Broker-TP wins** (~$3,500+): Positions that hit the 1.3R TP level quickly. These are mostly longs during gold's uptrend. Not tracked in our CSV but visible in MT5.

2. **TP0 partial profits** ($2,179): 161 partial closes at 0.5R capturing early profit. This is the safety net that makes many breakeven/small-loss trades positive.

3. **Trailing exits** ($4,155): 44 trailing exits with 100% WR. These are the big runners — the alpha source.

The coordinator-tracked PnL (+$460) is the "hard trades" net result. The real performance is the MT5 number.

---

## Recommended Next Steps (If Further Optimization Desired)

| Priority | Action | Risk | Expected Impact |
|---|---|---|---|
| 1 | Walk-forward test (train on 2024, test on 2025-26) | Low | Validate robustness |
| 2 | Optimize Chandelier multiplier (test 2.5, 3.0, 3.5, 4.0) | Low | Could improve trailing capture |
| 3 | Test TP0 at 0.7R instead of 0.5R | Medium | Fewer partials but larger capture |
| 4 | Refactor CSMCOrderBlocks formed_bar to absolute indices | Medium | Enable proper zone expiration → unlock OB Retest |
| 5 | Add H4 slope relaxation to Volatility Breakout | Low | May enable breakout trades |
| 6 | Test on different gold pairs (XAUEUR, XAUGBP) | Low | Diversification |
