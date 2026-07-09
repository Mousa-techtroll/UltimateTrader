# UltimateTrader — Entry-Strategy Census & Honest Performance Reflection

**Purpose.** A complete census of every entry strategy in the EA — its logic (source-verified), category tags, activation status under the binding production config, long/short splits, and measured results — reflected against the plain-English guide `workflowAnalysis/how-this-ea-works.md`, and ending with an honest answer to *"why is this EA underperforming buy-and-hold gold?"*

**Data basis (all fresh, one run).**
- Backtest: `risk_R90.ini` (binding baseline), `UltimateTrader_SHADOW.ex5`, XAUUSD+ H1, Model=4 (real ticks), 2019.01.01–2026.06.27, $10,000 deposit. Report headline: **Net $21,623.18 / PF 1.31 / Sharpe 2.28 / Equity-DD 13.68% / 1,878 report-trades** (run of 2026-07-09 19:27).
- Per-position results: `UltTrader_Stats_XAUUSD+_20190101_0000.csv` — **928 positions** (ENTRY+EXIT pairs). The report's 1,878 "trades" are *deals* including partial closes at TP0/TP1/TP2; positions = 928.
- Candidate funnel: `UltTrader_Candidates_XAUUSD+_20190101_0000.csv` — 4,889 rows = **3,274 unique candidates** (1,615 winners are logged twice: once as PASS, once as WINNER).
- Buy-and-hold: `XAUUSD_H1_rates.csv` (server-time H1 closes).
- Reconciliation note (FACT): the Stats CSV per-position PnL sums to **$22,117.61** vs the report's **$21,623.18** — a −$494.43 (2.2%) delta, consistent with swap/commission not being included in the CSV's PnL_Money. All per-strategy dollar figures below are CSV-basis.

**Headline.** Of ~20 entry strategies that exist in the source, **7 produced every one of the 928 fills**. Three bullish candlestick patterns (Pin Bar, Engulfing, MA Cross) are **77% of fills and 89% of profit**. Five registered plugins produced **zero candidates in 7.5 years**. The EA's CAGR (**16.6%**) is a statistical tie with buy-and-hold gold (**16.8%**) over the same window — achieved at **half the drawdown** (13.68% vs 28.58%) and **12.4% time-in-market**. Risk-adjusted, the EA wins clearly; on absolute wealth, it ties the benchmark it trades.

---

## 1. Census table — every entry strategy

Status legend — **LIVE**: registered, produced candidates and fills this run. **REGISTERED-MUTE**: registered and running every bar, produced zero candidates in 7.5 years. **DEAD**: not registered / not constructed under the binding config (reason given). Candidate and fill counts are from this run's CSVs; "Cands" = candidate rows per plugin (arbitration winners are logged twice — PASS then WINNER — so the column sums to 4,889 rows; deduplicated on SignalID the book saw 3,274 unique candidates).

| Strategy | Status | Tags (active) | Cands | Fills | Net $ | PF | avg R | WR | L/S fills |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| Engulfing — bull | **LIVE** | candlestick, momentum, trend-following, volume(filter) | 1,853 | 238 | +7,190.56 | 1.36 | +0.129 | 45.0% | 238/0 |
| Engulfing — bear | **DEAD** — `InpEnableBearishEngulfing=false` (ini:192; profile default also false) | candlestick | 0 | 0 | — | — | — | — | — |
| Pin Bar — bull | **LIVE** | candlestick, trend-following | 1,232 | 207 | +6,454.73 | 1.34 | +0.154 | 43.5% | 207/0 |
| Pin Bar — bear | **LIVE** (NY-blocked ≥13:00 GMT) | candlestick, mean-reversion, session-time | 494 | 209 | +3,145.80 | 1.22 | +0.091 | 40.7% | 0/209 |
| MA Cross — bull | **LIVE** (NY-blocked) | momentum, trend-following, session-time | 399 | 61 | +2,829.08 | 1.62 | +0.244 | 47.5% | 61/0 |
| MA Cross — bear | **DEAD** — removed at source, Phase D (`CMACrossEntry.mqh:216`, "PF 0.59") | momentum | — | — | — | — | — | — | — |
| LiquiditySweep | **DEAD** — `InpEnableLiquiditySweep=false` → never registered (`UltimateTrader.mq5:628`) | liquidity | 0 | 0 | — | — | — | — | — |
| RangeBox | **DEAD** — replaced by S3/S6 branch (`UltimateTrader.mq5:656`) | mean-reversion | 0 | 0 | — | — | — | — | — |
| FalseBreakoutFade | **DEAD** — replaced by S3/S6 branch (`UltimateTrader.mq5:657`) | liquidity, mean-reversion | 0 | 0 | — | — | — | — | — |
| RangeEdgeFade (S3) | **REGISTERED-MUTE** — 0 candidates in 7.5y | mean-reversion (M15) | 0 | 0 | — | — | — | — | — |
| FailedBreakReversal (S6) | **LIVE, long-only** (`InpEnableS6Short=false`) | liquidity, mean-reversion (M15) | 116 | 11 | +393.19 | 2.87 | +0.240 | 72.7% | 11/0 |
| VolatilityBreakout | **REGISTERED-MUTE** — volatile-regime-only gate, 0 candidates | breakout | 0 | 0 | — | — | — | — | — |
| CrashBreakout (Rubber Band) | **LIVE, short-only** | crash-regime, mean-reversion, session-time, volume(filter) | 488 | 138 | +503.48 | 1.70 | +0.024 | 79.0% | 0/138 |
| FileEntry | **CONSTRUCTED-MUTE** — `telegram_signals.csv` does not exist in tester Files | external-signal | 0 | 0 | — | — | — | — | — |
| Displacement | **REGISTERED-MUTE** — 0 candidates in 7.5y | liquidity, SMC-structure | 0 | 0 | — | — | — | — | — |
| SessionBreakout | **DEAD** — never registered (`UltimateTrader.mq5:699-700`: skipped when `InpEnableSessionEngine=true`) | session-time, breakout | 0 | 0 | — | — | — | — | — |
| PullbackContinuation | **LIVE** | trend-following, momentum | 233 | 45 | +621.30 | 1.21 | **−0.032** | 44.4% | 26/19 |
| Expansion (IC mode only; CompressionBO off) | **LIVE** | breakout, momentum | 74 | 19 | +979.47 | 1.56 | +0.127 | 47.4% | 12/7 |
| LiquidityEngine (Displacement+OBRetest modes on; FVG/SFP off) | **REGISTERED-MUTE** — 0 candidates in 7.5y | SMC-structure, liquidity | 0 | 0 | — | — | — | — | — |
| SessionEngine (all 4 modes off) | **REGISTERED-MUTE** — mode flags all false in ini AND at source default | session-time, breakout | 0 | 0 | — | — | — | — | — |
| TrendContinuation engine | **DEAD** — not constructed (`InpEnableMultiStrategy=false`, `UltimateTrader.mq5:763`) | trend-following | — | — | — | — | — | — | — |
| ReversalSweep engine | **DEAD** — not constructed (same gate) | liquidity | — | — | — | — | — | — | — |
| RangeReversion engine | **DEAD** — not constructed (same gate) | mean-reversion | — | — | — | — | — | — | — |
| **TOTAL** | | | **3,274** | **928** | **+22,117.61** | **1.35** | **+0.112** | **49.2%** | **555/373** |

**Registered-plugin scoreboard (FACT, re-verified this run):** 12 plugins registered (Engulfing, PinBar, MACross, S6, S3, VolBreakout, Crash, Displacement, LiquidityEngine, SessionEngine, ExpansionEngine, PullbackContinuation). 7 produced candidates; **5 produced zero candidates in 7.5 years** (S3, VolBreakout, Displacement, LiquidityEngine, SessionEngine) — confirmed by absence from the Candidates CSV, which logs every candidate any plugin emits. FileEntry runs outside the orchestrator and is mute for lack of its CSV. The three multi-strategy engines are never `new`-ed. SessionBreakout is constructed but never registered.

**The funnel (FACT, arithmetic reconciles exactly):**

```
3,274 unique candidates
 ├─ 1,611 REJECTED by orchestrator gates
 │    ├─ 615 VOLUME_FILTER        (Engulfing 449, Crash 166 — only "breakout-class" patterns are volume-checked)
 │    ├─ 532 VALIDATOR_FAILED     (long-bias ladder / trend / SMC counter-OB / MR conditions)
 │    ├─ 361 QUALITY_BELOW_THRESHOLD (tier scoring < B+)
 │    └─ 103 LOW_CONFIDENCE_30    (pattern confidence)
 ├─ 1,663 PASSED all gates
 │    └─ 48 lost same-bar arbitration (another plugin won the hour)
 ├─ 1,615 WINNERS (one per H1 bar max)
 │    ├─ 677 died awaiting/failing next-bar confirmation
 │    ├─ 10 died at execution level (caps/spread) after skipping confirmation
 │    └─ 928 FILLED  ← every fill's SignalID is in the winner set
```

---

## 2. Per-strategy sections

Tag taxonomy used: candlestick-pattern / SMC-structure / liquidity / volume / momentum / trend-following / mean-reversion / breakout / session-time / crash-regime / external-signal. Where a strategy *advertises* a component that the config disables, the tag list above and the notes below say what is actually active.

> **A global "advertised vs active" fact that applies to all of them:** the EA's live entry book contains **zero SMC-structure generators** — SMC exists only as a *filter* inside `CSignalValidator`. Even there, the configured confluence floor `InpSMCMinConfluence=55` is a **no-op**: `m_smc_min_confluence` is stored and printed but never compared (`CSignalValidator.mqh:41,67,77,81`); the live floor is a hardcoded `confluence_score < 40` reject (`CSignalValidator.mqh:195`) plus the counter-order-block block (`:181-192`). Likewise the **volume filter applies only to patterns classed as "breakout"** — Engulfing, VolatilityBreakout, CrashBreakout (`CSignalValidator.mqh:112-117`) — so Pin Bar, MA Cross, PBC, Expansion, S6 are never volume-checked.

### 2.1 Pin Bar (bull + bear) — LIVE, the volume leader

- **Logic (verified).** On the closed H1 candle: rejection wick > 1.5× body with opposing wick < 0.8× body (`CPinBarEntry.mqh:159-160, 248-249`). Bull side trades with the H4 trend gate; bear side is blocked from 13:00 GMT (NY) when `InpBearPinBarBlockNY=true` (`CPinBarEntry.mqh:238-242`; code comment at `:237`: London shorts +4.4R, NY shorts −1.9R). The legacy Asia-only bear gate is off (`InpBearPinBarAsiaOnly=false`).
- **Tags active:** candlestick-pattern; trend-following (bull, via H4 gate); mean-reversion (bear = fading rallies); session-time (bear NY block). Not volume-checked.
- **Doc says:** "a candle with a long tail and small body... Both directions, but the bearish side is blocked during New York" (§3) — accurate, including the wick ratios and the 13:00 GMT block.
- **Data shows (FACT):** 1,726 candidates (1,232 L / 494 S) → 416 fills (207 L / 209 S), net **+$9,600.53**, PF 1.29, avg R +0.123, WR 42.1%, payoff 1.76. Present every year. Bull side: +$6,454.73 (PF 1.34). Bear side: +$3,145.80 (PF 1.22, avg R +0.091) — profitable overall but lumpy: +$1,520 in 2023 and +$1,126 in 2025 vs negative 2019/2024/2026. Warning sign: **2026 YTD PinBar is −$2,847, and −$2,620 of that is the bull side** — the pattern's worst year is happening inside gold's 28% correction.
- **Insight (interpretation):** KEEP. It is the EA's single biggest earner and the only live strategy with a genuine two-sided book. The 2026 bull-side bleed is regime-consistent (longs in a falling market) rather than pattern decay; the bear side's NY block is one of the few short-suppressions with a positive measured residual (London bear pin bars are the survivors).

### 2.2 Engulfing (bull only) — LIVE, second engine

- **Logic (verified).** Closed H1 candle fully wraps the prior opposite-color body at ≥ 80% body ratio and body > 0.3×ATR, in H4-trend agreement (`CEngulfingEntry.mqh:171-174`). Bear side exists in code but is gated off by `g_profileEnableBearishEngulfing` = `InpEnableBearishEngulfing=false` (`CEngulfingEntry.mqh:216`; source comment at `:209`: "Dominates every major loss streak").
- **Tags active:** candlestick-pattern; momentum; trend-following. **Volume filter ACTIVE** — the validator classes Engulfing as a breakout pattern; VOLUME_FILTER is its #1 killer (449 of 807 rejects).
- **Doc says:** "a single up-candle that completely swallows the previous down-candle... Long only on default" (§3) — accurate.
- **Data shows (FACT):** 1,853 candidates (the most prolific generator) → 238 fills, net **+$7,190.56**, PF 1.36, avg R +0.129, WR 45.0%, payoff 1.67. Highly regime-dependent: 2021–2023 were all negative (−$131/−$383/−$436) then 2024–2026 delivered +$7,628 (+$1,686/+$4,071/+$1,871). Only a 12.8% candidate→fill rate — the tightest funnel of any live plugin.
- **Insight (interpretation):** KEEP. It is the purest "gold is trending hard" expression and earned most of its 7.5-year profit in the 2024–25 super-trend. The volume filter (449 kills) is the biggest single gate on it; the campaign has not (in the artifacts here) measured what those 449 kills were worth — that is the one instrumentation gap on this strategy. The bear side should stay off: the fresh FIT arm (2026-07-09 campaign run) measured **−$1.3k** when enabled — the source comment's "dominates every major loss streak" is corroborated by measurement.

### 2.3 MA Cross (bull only, bear removed) — LIVE, best expectancy of the big three

- **Logic (verified).** Fast MA(10) crosses above slow MA(21) between closed bars [2]→[1] on H1, trending regime, H4 agreement; bull entries blocked in NY (`InpBullMACrossBlockNY=true`). The bearish cross was **deleted from the source** in Phase D — `CMACrossEntry.mqh:216`: "BEARISH MA CROSS: REMOVED in Phase D (was dead if(false); PF 0.59...)".
- **Tags active:** momentum; trend-following; session-time (NY block). Not volume-checked.
- **Doc says:** "a fast 10-bar average crossing above a slow 20-bar average... Long only; blocked during New York" (§3) — accurate except the slow period is **21**, not 20 (`InpMASlowPeriod=21`).
- **Data shows (FACT):** 399 candidates → 61 fills, net **+$2,829.08**, PF 1.62, avg R **+0.244** (best of the three patterns), WR 47.5%, payoff 1.79, capture 19.6% (nearly 2× the book average). Positive in 5 of 8 years; −$850 in 2026 YTD.
- **Insight (interpretation):** KEEP, and note it as evidence that *less frequent + stronger trigger* beats *more frequent + weaker trigger* in this pipeline: it fills 4× less often than Engulfing yet banks 2× the per-trade R. The bear-side removal is justified at source (PF 0.59 measured before deletion).

### 2.4 CrashBreakout / Rubber Band — LIVE, the 79%-WR placebo

- **Logic (verified).** Step 1: D1 death cross (EMA50 < EMA200 on closed D1) must exist (`CCrashBreakoutEntry.mqh:~190-200`). Step 2: short when live price stretches > H1 EMA21 + 2.0×ATR with H1 ADX ≥ 25 (`m_extension_atr_mult=2.0`, `m_rubber_band_min_adx=25`), only 13:00–17:00 GMT (`InpCrashStartHour/EndHour`), max spread 40. B+ quality is rejected outright when `InpRubberBandAPlusOnly=true` (`CSignalOrchestrator.mqh:761`: "B+ loses -4.0R across 22 trades").
- **Tags active:** crash-regime; mean-reversion (fades rallies back to the H1 mean); session-time; **volume filter ACTIVE** (166 kills).
- **Doc says:** "only wakes up in a confirmed gold downtrend; shorts the snap-back... Short only" (§3) — accurate on mechanics, but the doc omits both the 13–17 GMT window and the A+/A-only gate.
- **Data shows (FACT):** 488 candidates → 138 fills, all short, all in **2021–2023 only** (49/68/21 — gold's only death-cross era in the window). Net **+$503.48** (2.3% of book profit from 14.9% of fills), PF 1.70, WR **79.0%**, but avg R **+0.024** and payoff **0.45** (avg win $11.23 vs avg loss $24.86). Total banked: 3.3R across 138 trades. Capture 10.0%.
- **Insight (interpretation):** This is the previously-measured placebo, re-confirmed: a high-WR strategy whose winners are ~half the size of its losers nets almost nothing — 138 trades for $503. It doesn't hurt (PF 1.70, tiny sizes), and it's the only thing that trades in bear regimes, but as constructed it is *activity, not edge*. KILL-or-fix candidate: either widen its targets (it exits at the EMA21 mean, structurally capping wins at fractions of R) or accept it as a regime-diversification token that pays ~nothing.

### 2.5 PullbackContinuation — LIVE, negative expectancy in R

- **Logic (verified).** H4 trend + ADX ≥ 18 (`CPullbackContinuationEngine.mqh:378`), price pulls back 0.6–1.8 ATR over 2–10 H1 bars with fading momentum, then a reclaim candle (body ≥ 0.35×ATR... configured `InpPBCSignalBodyATR=0.2`) closes back over the prior highs; target 1.3R; choppy-day block on.
- **Tags active:** trend-following; momentum. Not volume-checked; multi-cycle re-arm off.
- **Doc says:** "buys the dip inside an uptrend (or sells the bounce in a downtrend)" (§3) — accurate.
- **Data shows (FACT):** 233 candidates → 45 fills (26 L / 19 S), net **+$621.30** but avg R **−0.032** — the R-book is negative; the dollars are positive only because its occasional winners landed on later (larger) account balances. Its MFE capture is **−3.1%**: it visits +45.9R of open profit across its trades and banks −1.4R. Shorts: 19 fills, −$135.70, avg R −0.187.
- **Insight (interpretation):** The prior campaign verdict ("PBC avg-R negative history") re-verifies exactly. This strategy finds real moves (positive MFE) and then gives all of it back — a management/exit mismatch, not a signal-quality problem. FIX-or-KILL: as configured it adds 45 trades of noise and negative R; its short side is the worst live short book per-trade. If kept, it is the natural first patient for any capture-ratio work because its gap between "seen" and "kept" profit is total.

### 2.6 Expansion Engine (Institutional-Candle mode only) — LIVE, thin but honest

- **Logic (verified).** Detects an "institutional" H1 candle with body ≥ 1.8×ATR (`InpInstCandleMult=1.8`; doc says 2× — the default; ini overrides to 1.8) closing near its extreme (`CExpansionEngine.mqh:702`), waits 2–5 bars of consolidation (`:759,770`), then enters on the break of the big candle's extreme. The CompressionBO squeeze mode is **off** (`InpExpCompressionBO=false`).
- **Tags active:** breakout; momentum. ("Volume" here is candle size, not tick volume — not volume-tagged.)
- **Doc says:** "energy building then releasing: an oversized institutional candle then a coil then a break, or a volatility squeeze" (§3) — accurate mechanics; on this config only the first mode exists.
- **Data shows (FACT):** 74 candidates → 19 fills (12 L / 7 S), net **+$979.47**, PF 1.56, avg R +0.127, WR 47.4%. Nearly all activity 2024–2026 (14 of 19 fills) — it fires in high-ATR regimes.
- **Insight (interpretation):** KEEP. Small but positive, two-sided, and the only live *breakout* expression in the book. It is the closest thing the EA has to a diversifier that actually pays.

### 2.7 FailedBreakReversal (S6) — LIVE, long-only, boutique

- **Logic (verified).** On the last 3 closed M15 candles: a spike ≥ 0.20×(H1 ATR) through a key level (validated range-box edge, prior-day high/low), wick > body, then a reclaim close back through the level (`CFailedBreakReversal.mqh:82-120+`). Short side hard-gated off: `if(!g_profileEnableS6Short) return` (`:191`), `InpEnableS6Short=false`.
- **Tags active:** liquidity (stop-hunt reversal); mean-reversion; M15 trigger.
- **Doc says:** "price spikes past an important level to grab orders, then reclaims it... Long only on default (short off)" (§3) — accurate.
- **Data shows (FACT):** 116 candidates → 11 fills over 7.5 years, net **+$393.19**, PF 2.87 (best in book), avg R +0.240, WR 72.7%, capture 29.3% (best in book). VALIDATOR_FAILED kills 81 of its 93 rejects — the long-bias ladder eats most of its candidates.
- **Insight (interpretation):** KEEP but irrelevant at this size — 1.5 fills/year. Its per-trade numbers are the best in the EA, which makes the 81 validator kills the most interesting unmeasured pile in the funnel; the campaign's S6-short arm measured **−8.9R**, so the suppressed short side stays rightly off. Growing S6's long side (looser validator interaction) is one of the few *unmeasured* frequency levers left.

### 2.8 The five registered-but-mute plugins (zero candidates in 7.5 years)

FACT: none of these emitted a single candidate row this run. Re-verified, not assumed.

| Plugin | Why it is mute (verified mechanism) |
|---|---|
| **RangeEdgeFade (S3)** | Registered and updated every bar (`g_rangeBoxDetector.Update()` at `UltimateTrader.mq5:1539`), but requires a *validated* range box AND no stealth-trend AND an M15 sweep-and-reclaim at the box edge with RSI extreme and ≥2:1 room (`CRangeEdgeFade.mqh:113-140+`). The conjunction has never once been true on gold H1/M15 in 7.5 years. Structurally over-specified for this symbol. |
| **VolatilityBreakout** | `IsCompatibleWithRegime()` returns true **only** for `REGIME_VOLATILE` (`CVolatilityBreakoutEntry.mqh:153`), then still needs ADX ≥ 25 + H4 EMA-stack agreement + Donchian/Keltner break. The doc itself calls it "effectively dormant by design... ~zero trades" — confirmed: exactly zero. |
| **Displacement** | Needs a sweep (wick below the swing low, close back above) within ~3 bars AND a displacement candle with **body ≥ 1.8×ATR** closing decisively beyond the swept level, in TRENDING/VOLATILE H4 regime (`CDisplacementEntry.mqh:192-230`). An H1 gold candle with a 1.8×ATR body immediately after a sweep-reclaim is rare enough to be non-existent in this window. The doc presents it as an active scout — over-advertised. |
| **LiquidityEngine** | Registered with Displacement + OB-Retest modes on (`UltimateTrader.mq5:715`; FVG/SFP off per ini). Its displacement mode shares the 1.8×ATR-body problem above; OB-Retest needs price inside a prior institutional-candle zone + bullish H1 structure + rejection candle, and stands aside on DATA days / restricts to displacement on VOLATILE days (`CLiquidityEngine.mqh:~104+`). Net measured output: zero. The doc's flagship "smart-money" engine has never traded. |
| **SessionEngine** | All four modes false in the binding ini (`InpSessionLondonBO/NYCont/SilverBullet/LondonClose=false`) — and **also false at source default** (`UltimateTrader_Inputs.mqh:355-356`, comments: "DISABLED: 0% WR in backtest"). It is registered purely as infrastructure: it is the EA's GMT clock and Asian-range builder. **The doc is wrong here** — §3 claims "two modes on by default: London Breakout and NY Continuation." No session-engine mode has been on, in config or defaults. |

**Insight (interpretation):** these five are the EA's entire advertised SMC/liquidity/session-breakout repertoire, and none of it exists in practice. That has two consequences: (1) the plain-English doc materially over-states the diversity of the live book ("about twelve scouts" — §3 — is technically true of registration and false of behavior); (2) the "breadth" lever for improving returns is not "switch them on" — four of the five are mute *with their enables on*, because their internal conditions never fire. They need re-parameterization or redesign, not activation.

### 2.9 The never-registered / never-constructed set

- **LiquiditySweep** (`InpEnableLiquiditySweep=false` → `RegisterEntryPlugin(...,false)` returns early at `UltimateTrader.mq5:373` — not registered), **RangeBox** and **FalseBreakoutFade** (explicitly disabled when the S3/S6 branch is active, `UltimateTrader.mq5:656-657`), **Momentum filter as entry** (`InpEnableMomentum=false`).
- **SessionBreakout**: constructed, then registration skipped entirely because `InpEnableSessionEngine=true` (`UltimateTrader.mq5:699-700`; source comment: "SessionBreakout DEAD when InpEnableSessionEngine=true"). Since SessionEngine's own modes are all off, **the EA has no live session-breakout of any kind** — Asian-range/London-open logic exists in three places and trades in none.
- **TrendContinuation / ReversalSweep / RangeReversion engines**: inside `if(InpEnableMultiStrategy)` (`UltimateTrader.mq5:763-792`) with `InpEnableMultiStrategy=false` — never constructed. The 4-engine scaffold is entirely dormant.
- **FileEntry**: constructed and initialized (SignalSource=BOTH, `UltimateTrader.mq5:687-691`) but its `telegram_signals.csv` does not exist in the tester's Files — zero external signals. All its ~30 ini parameters are dead weight on this config.

---

## 3. The long vs short book

**FACT (this run):**

| Book | Fills | Net $ | PF | avg R | WR | Share of fills | Share of profit |
|---|---:|---:|---:|---:|---:|---:|---:|
| LONG | 555 | +18,416.72 | 1.39 | +0.151 | 45.6% | 59.8% | 83.3% |
| SHORT | 373 | +3,700.89 | 1.22 | +0.053 | 54.7% | 40.2% | 16.7% |

Short book composition: Bear Pin Bar 209 (+$3,145.80), CrashBreakout 138 (+$503.48), PBC-short 19 (−$135.70), Expansion-short 7 (+$187.31). The short side wins more often (54.7% vs 45.6%) and earns a third as much per trade (avg R 0.053 vs 0.151) — it is a book of small fades inside a secular uptrend.

**The bear-side suppressions (all verified in source, measured verdicts noted):**
1. **Bearish Engulfing OFF** — `InpEnableBearishEngulfing=false`; source comment "Dominates every major loss streak" (`CEngulfingEntry.mqh:209`); campaign FIT arm (2026-07-09) measured **−$1.3k** when enabled. Suppression is evidence-backed.
2. **Bear MA Cross REMOVED at source** — Phase D deletion, PF 0.59 measured before removal (`CMACrossEntry.mqh:216`).
3. **S6 short OFF** — `InpEnableS6Short=false` (`CFailedBreakReversal.mqh:191`); campaign measured **−8.9R** when tried.
4. **Bear Pin Bar NY block** — `InpBearPinBarBlockNY=true`; code comment: London +4.4R / NY −1.9R (`CPinBarEntry.mqh:237`). The 209 bear-pin-bar fills that remain are the London/Asia survivors.
5. Note: `InpShortRiskMultiplier=1.0` on this config — shorts are *not* size-penalized; they are gate-penalized.

**Interpretation:** the thin short book is not an oversight — it is the residue of repeated measurements that shorting gold 2019–2026 loses money almost everywhere except two narrow niches (non-NY bear pin bars, death-cross rubber bands). The asymmetry is earned. The cost is structural: in gold's two meaningful corrections (2021–22 chop, 2026 H1 crash) the EA has almost nothing that profits from downside — 2026 YTD it is net +$628 while its long patterns bleed.

---

## 4. Buy-and-hold comparison (formulas shown)

**Setup (FACT).** $10,000 of unleveraged spot gold, bought at the first H1 bar of 2019 in `XAUUSD_H1_rates.csv`, held to the last bar ≤ 2026.06.27. Server time.

```
Entry:  2019.01.02 01:00 open  = 1,282.51
Exit:   2026.06.26 23:00 close = 4,088.02
Ounces: 10,000 / 1,282.51                   = 7.797 oz
Final:  7.797 × 4,088.02                    = $31,875
Total:  4,088.02 / 1,282.51 − 1             = +218.8%
Years:  2019-01-02 → 2026-06-26             = 7.48 y
CAGR:   (4,088.02/1,282.51)^(1/7.48) − 1    = +16.76%/y
MaxDD (H1 closes): 1 − 3,972.79/5,562.48    = 28.58%
        peak 2026.01.29 07:00 → trough 2026.06.24 20:00
```

**EA on the identical window (FACT):**

```
Net:    $21,623.18 on $10,000 deposit → final $31,623.18
Total:  21,623.18 / 10,000                  = +216.2%
CAGR:   (3.16232)^(1/7.48) − 1              = +16.64%/y
MaxDD:  13.68% (report equity DD)
Time in market: union of the 928 position intervals = 8,137h of 65,590h = 12.4%
```

(If you have seen "+116.2%" quoted for this baseline: no combination of the report numbers produces it — $21,623.18 of profit on a $10,000 deposit is +216.2% total. The formulas above are checkable from the artifacts.)

**Head-to-head:**

| Metric | Buy & hold gold | EA (binding baseline) |
|---|---:|---:|
| Total return | +218.8% | +216.2% |
| CAGR | 16.76% | 16.64% |
| Max drawdown | 28.58% | 13.68% |
| Return / MaxDD | 7.7 | **15.8** |
| Time in market | 100% | **12.4%** |

**Matched-drawdown equivalent (rough, linear approximation — ignores compounding path and financing costs):** to hold gold at the EA's 13.68% DD budget you scale exposure by 13.68/28.58 = **0.479×**, giving ≈ 0.479 × 218.8% = **+104.7%**. The EA delivered +216.2% at that DD — roughly **2.1× the DD-matched hold**. Inverting: levering the EA to gold's 28.6% DD (~2.1×) would project ~+450%, though the campaign's sizing sweeps (e.g. `InpMaxTotalExposure` raise) came back KILL, so treat that projection as arithmetic, not an available action.

**The 2024–26 sub-period (FACT):** gold ran 2,063.63 → 4,088.02 = **+98.1%**. The EA earned $16,859.64 of its $22,117.61 CSV profit (76.2%) in 2024–26; on its start-2024 equity ($15,257.97 CSV basis) that is **+110.5%** — it modestly *beat* gold during gold's own run. Conversely 2019–2023: gold +60.9%, EA +52.6% ($5,258 on $10,000, CAGR ~8.8%). And **2025 alone is $13,741.70 — 62% of all profit in one of eight years**.

**Endpoint honesty (interpretation):** this window ends *inside* gold's 28.6% H1-close drawdown (Jan–Jun 2026). At the January 2026 peak, buy-and-hold stood at +333.7% (5,562.48/1,282.51 − 1) and the comparison would have looked far worse for the EA; measured to the June trough-ish endpoint, they tie. Any "EA vs hold" verdict on a trending asset is endpoint-sensitive in both directions — the DD and exposure numbers are the durable part of the comparison, not the total-return tie.

---

## 5. Why is this EA underperforming? — the honest synthesis

First, the precise claim. **Risk-adjusted, it is not underperforming**: 2× the return of a DD-matched gold hold, Sharpe 2.28, 12.4% market exposure, half the drawdown. **On absolute wealth it merely ties buy-and-hold** — over a window in which gold delivered one of the best trend decades any asset has offered. That tie, with all this machinery, is the thing to explain. Five measured reasons:

**1. It is effectively ~2 strategies, not ~20 (FACT).** 715 of 928 fills (77.0%) and $19,620 of $22,118 profit (88.7%) come from three bullish candlestick triggers — Pin Bar, Engulfing, MA Cross — which are all the *same trade*: a bullish H1 momentum candle in an H4 uptrend, differing only in trigger shape. Strategy #2 is the short fade book (bear pin bar + rubber band), of which the rubber band is a measured placebo (138 trades, 79% WR, payoff 0.45, +$503 ≈ 3.3R total). The engines contribute 75 fills and ~$2.0k. Everything else — the entire SMC/liquidity/session/breakout repertoire, 5 registered plugins plus 3 unconstructed engines plus 2 unregistered breakout plugins — produced **zero candidates**. The EA's correlation to "long gold" in its profitable regime is therefore near-total: it earns when gold trends (2024–26 = 76% of profit, 2025 alone = 62%), exactly when buy-and-hold earns, and it has no engine that makes real money any other time (2019–2021 total: +$1,186 over three years).

**2. The capture ceiling (FACT, measured this run).** Across all 928 positions the book visited **978.0R of favorable excursion (sum MFE_R) and banked 103.5R (sum PnL_R) — a 10.6% capture ratio** (prior campaign run: 11.9%; same order). Per winner-strategy it is 10.0–10.3% for the three big patterns; only MA Cross (19.6%) and S6 (29.3%) exceed it; PBC is *negative* (−3.1%). The TP ladder (TP0 0.7R/15%, TP1 1.3R/40%, TP2 1.8R/30%, chandelier runner) is designed to bank early — and the campaign measured the broker-TP ceiling as a **load-bearing DD brake**: arms that loosened it bought more upside capture at more drawdown and did not survive OOS. The 13.68% DD and the 10.6% capture are two sides of the same design decision. You cannot keep this DD profile and also ride gold's full trend.

**3. The frequency levers are measured-and-closed (campaign FACTS, re-checked where artifacts allow).** 928 fills in 390 weeks is 2.4 trades/week. The funnel kills 49% of unique candidates at the gates and then 42% of arbitration winners in the confirmation pipeline (677 of 1,615). The obvious "trade more" knobs were each tried and measured: Friday-reopen arm **−34% OOS**; confirmation-gate kills re-priced at **~0R** (the 677 confirmation deaths were not stolen profit); bearish-engulfing arm **−$1.3k**; S6-short **−8.9R**; exposure-cap raise: sweep **KILL**; loss-scaler: dormant no-op. The gates are not eating a hidden fortune — they are removing roughly-zero-EV trades, which is why removing them fails out-of-sample.

**4. What beating buy-and-hold would actually require (rough math).** The book realizes ~$214 per R at current sizing ($22,118 / 103.5R). To beat gold's +218.8% by, say, 50% (≈ +$11k more) you need one of:
   - **Capture:** 10.6% → ~16% at the same trade set (avg R +0.111 → +0.17). The only measured-open capture paths so far are exit-side: the regime-exit trail widen 1.2× (OPT-1, OOS-confirmed, committed) and the shock-detector dead-leg fix (OPT-SHOCK Arm B, committed) — incremental, not 1.5×. PBC's −3.1% capture is the cheapest single target (it forfeits ~46R of excursion outright).
   - **Breadth:** ~+460 equally-good fills over the window (≈ +1.2/week). Closed paths: everything in point 3. Open-but-unbuilt: the five mute plugins are *not* a reserve — they are mute with enables on and need redesign; the one unmeasured pile with good per-trade stats is S6's 81 VALIDATOR_FAILED kills (PF 2.87 on its survivors).
   - **Leverage:** ~1.5× the whole book → ~20% DD, still under gold's 28.6%. Arithmetically open, empirically unblessed (sizing sweeps KILLed; the R90 scaling *is* the tuned point).
   None of the three is measured-open at the required magnitude today. That is the honest answer.

**5. The asymmetry is the design, and 2026 is showing its bill (FACT + interpretation).** Every bear-side suppression in §3 was individually evidence-based, but their sum is an EA that cannot monetize gold's corrections: 2026 YTD the market handed it a 28% drawdown to trade against and it netted +$628 while its long patterns bled −$2.8k through it. A trend-following long book with a placebo short book will, by construction, approximate buy-and-hold's return with better risk numbers — which is precisely what the measurement shows.

**Bottom line for the owner (interpretation).** This EA is a *drawdown-management machine wrapped around one good idea* (buy bullish H1 momentum candles in gold uptrends). Judged as a risk-adjusted vehicle, it beats holding gold decisively and its 12% exposure leaves 88% of capital free. Judged as a wealth-maximizer against its own underlying, it ties, and the measured levers to break the tie are nearly all closed — the credible open ones are exit-side capture (proven direction, small size), fixing or killing PBC (negative-R, negative-capture), re-pricing Engulfing's 449 volume-filter kills and S6's 81 validator kills (both uncounted), and redesigning — not enabling — the dead SMC/liquidity/session repertoire if breadth is ever to be real.

---

## Appendix A — Per-plugin capture and payoff (this run)

| Plugin | Fills | sum PnL_R | sum MFE_R | Capture | Payoff (avg win $ / avg loss $) |
|---|---:|---:|---:|---:|---:|
| PinBarEntry | 416 | +51.0 | 500.4 | 10.2% | 1.76 |
| EngulfingEntry | 238 | +30.7 | 297.4 | 10.3% | 1.67 |
| MACrossEntry | 61 | +14.9 | 76.0 | 19.6% | 1.79 |
| CrashBreakoutEntry | 138 | +3.3 | 32.7 | 10.0% | 0.45 |
| FailedBreakReversal | 11 | +2.6 | 9.0 | 29.3% | 1.08 |
| ExpansionEngine | 19 | +2.4 | 16.6 | 14.6% | 1.73 |
| PullbackContinuationEngine | 45 | **−1.4** | 45.9 | **−3.1%** | 1.52 |
| **Book** | **928** | **+103.5** | **978.0** | **10.6%** | — |

## Appendix B — Fills and net $ by plugin and year (this run)

| Plugin | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | 2026 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| PinBar (fills) | 44 | 40 | 46 | 55 | 59 | 73 | 66 | 33 |
| PinBar ($) | +54 | +348 | +567 | +1,250 | +2,198 | +330 | +7,700 | −2,847 |
| Engulfing (fills) | 33 | 31 | 11 | 20 | 33 | 44 | 56 | 10 |
| Engulfing ($) | +289 | +223 | −131 | −383 | −436 | +1,686 | +4,071 | +1,871 |
| MACross (fills) | 10 | 4 | 8 | 2 | 12 | 8 | 14 | 3 |
| MACross ($) | −141 | +254 | −157 | −194 | +1,002 | +768 | +2,146 | −850 |
| Crash (fills) | 0 | 0 | 49 | 68 | 21 | 0 | 0 | 0 |
| Crash ($) | 0 | 0 | +154 | +359 | −9 | 0 | 0 | 0 |
| PBC (fills) | 7 | 3 | 2 | 7 | 5 | 13 | 6 | 2 |
| PBC ($) | −260 | +301 | −325 | +524 | −425 | −485 | +234 | +1,057 |
| Expansion (fills) | 0 | 0 | 2 | 2 | 1 | 5 | 4 | 5 |
| Expansion ($) | 0 | 0 | +6 | +162 | −58 | +208 | −295 | +957 |
| S6 (fills) | 0 | 1 | 1 | 2 | 1 | 3 | 1 | 2 |
| S6 ($) | 0 | +15 | −12 | +44 | +39 | −17 | −115 | +440 |
| **Year total ($)** | **−58** | **+1,141** | **+103** | **+1,762** | **+2,310** | **+2,490** | **+13,742** | **+628** |

## Appendix C — Quality-tier results (this run)

| Tier | Fills | Net $ | PF | avg R | Base risk (this config — R90 scale, not the doc's defaults) |
|---|---:|---:|---:|---:|---|
| A+ | 532 | +18,046.64 | 1.42 | +0.138 | 1.35% (doc says 1.5%) |
| A | 297 | +1,473.71 | 1.09 | +0.041 | 0.90% (doc says 1.0%) |
| B+ | 99 | +2,597.26 | 1.73 | +0.179 | 0.675% (doc says 0.75%) |

*(A-tier is the weak link: 32% of fills, PF 1.09. B+ outperforming A is a small-sample quirk worth watching, n=99.)*

---

*Method notes: CSVs decoded from UTF-16LE; per-position PnL from EXIT rows' PnL_Money/PnL_R; candidate funnel deduplicated on SignalID (WINNER rows re-log their PASS row); every fill's SignalID joins to a WINNER row (928/928); buy-and-hold from H1 closes (intrabar wicks would deepen the 28.58% DD slightly); "time in market" is the union of entry→exit intervals over calendar hours. All file:line references verified against the working tree on 2026-07-09 (branch feat/multi-strategy).*
