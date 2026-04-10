# Position Lifecycle

> UltimateTrader EA | Updated 2026-04-10

---

## Processing Order (ManageOpenPositions, every tick)

1. Weekend closure check
2. MAE/MFE update
3. EC v3 Layer 2 feed: open-trade stress metrics (forward-looking data, currently disabled)
4. TP0 cascade: 0.7R profit triggers close of 15% of original lots
5. TP1 cascade: 1.3R profit triggers close of 40% of remaining lots
6. TP2 cascade: 1.8R profit triggers close of 30% of remaining lots
7. Early invalidation (DISABLED: -26.9R)
8. Smart runner exit (DISABLED: -$8K)
9. Universal stall (DISABLED: -$4,189)
10. Anti-stall (S3/S6 only): 5 M15 bars triggers 50% reduction + BE; 8 bars triggers close
11. Runner promotion (DISABLED)
12. Apply trailing plugins (Chandelier)
13. Check exit plugins

---

## TP Cascade Detail

| Level | Trigger | Volume | Stage After |
|---|---|---|---|
| TP0 | 0.7R profit | 15% of original | INITIAL -> TP0_HIT |
| TP1 | 1.3R profit | 40% of remaining | TP0_HIT -> TP1_HIT |
| TP2 | 1.8R profit | 30% of remaining | TP1_HIT -> TP2_HIT |
| Runner | Chandelier trail | Remaining ~36% of original | TP2_HIT -> CLOSED |

---

## Chandelier Trailing

- **Formula (long):** `new_sl = HighestHigh(10) - ATR(14) x 3.0`
- Regime-adaptive multiplier (2.5-3.5x range)
- Min profit before trailing starts: 60 points
- SL can never loosen (only tighten)
- Trail send policies: EVERY_UPDATE, LOCK_STEPS (BE/1R/2R/3R), BAR_CLOSE, RUNNER_POLICY

---

## Breakeven

| Parameter | Value |
|---|---|
| Trigger | 0.8R profit (regime-specific override) |
| Offset | 50 points above entry (auto-scaled by symbol price) |
| Activation | Armed when trailing SL reaches BE level |

---

## Exit Plugins

| # | Plugin | Behavior |
|---|---|---|
| 1 | RegimeAwareExit | Close on CHOPPY + H1 EMA50 structure break, or macro opposition (score >=+/-3) |
| 2 | DailyLossHaltExit | Daily P&L <= -3% triggers close-all and halt |
| 3 | WeekendCloseExit | Friday 20:00 server time |
| 4 | MaxAgeExit | 120 hours max hold |
| 5 | StandardExitStrategy | 48h + losing, or -30% loss, or +50% profit partial |

---

## Anti-Stall (S3/S6 bounded trades only)

Prevents mean-reversion trades from stalling in no-man's-land.

| Condition | Action |
|---|---|
| Stage 1: 5+ M15 bars, <0.8R profit | Reduce to 50% + move SL to BE |
| Stage 2: 8+ M15 bars, <1.0R profit | Close remainder (only if trailing SL not at BE) |

---

## Regime Exit Profiles

Each regime gets frozen TP/trailing/BE parameters locked at trade entry time.

| Parameter | Trending | Normal | Choppy | Volatile |
|---|---|---|---|---|
| Chandelier mult | 3.5x | 3.0x | 2.5x | 3.0x |
| BE trigger | 1.2R | 1.0R | 0.7R | 0.8R |
| TP0 dist / vol | 0.7R / 10% | 0.7R / 15% | 0.5R / 20% | 0.6R / 20% |
| TP1 dist / vol | 1.5R / 35% | 1.3R / 40% | 1.0R / 40% | 1.3R / 40% |
| TP2 dist / vol | 2.2R / 25% | 1.8R / 30% | 1.4R / 35% | 1.8R / 30% |

- **TRENDING:** Wider Chandelier (3.5x), wider TPs, slower BE (1.2R) -- let winners run
- **CHOPPY:** Tighter Chandelier (2.5x), tighter TPs, faster BE (0.7R) -- protect capital
- **VOLATILE:** Moderate Chandelier (3.0x), reduced TPs, quick BE (0.8R)
