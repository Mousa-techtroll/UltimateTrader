# Phase 0 — Correctness & Reproducibility Report

**Scope:** the 12-item Phase-0 checklist, executed *before* any trading-logic change.
**Baseline of record:** `$23,856.89` net / PF 1.31 / Sharpe 2.21 / EqDD 13.14% / 2,053 trades / **952 positions**, XAUUSD+ H1, Model 4 real ticks, 2019-01-01 → 2026-06-27, $10k / 1:100.
**Git HEAD at freeze:** `c26b2f8` (branch `feat/multi-strategy`).
**Discipline:** no trading logic was altered. The only code change is a behavior-neutral rename (Task 5), proven byte-identical by a full reproduce. Everything else is measurement, tests, tooling, and documentation corrections. Each task has its own evidence file (`workflowAnalysis/phase0-*.md`).

---

## Verdict table

| # | Task | Verdict | Evidence |
|---|------|---------|----------|
| 1 | Freeze source / EX5 / config | ✅ Done | `phase0-freeze-manifest.md` (MD5s, git rev, config) |
| 2 | Reproduce 952 positions | ✅ **Exact to the cent** | frozen binary → $23,856.89 / 952 |
| 3 | Reconcile Session discrepancy | ✅ Resolved + docs fixed | `phase0-session-dormant-reconcile.md` |
| 4 | Four-vs-five dormant | ✅ **Five** dormant | same |
| 5 | Rename hourly "daily 200 EMA" | ✅ Applied, **identity-proven** | `phase0-rename-sizing-proposals.md` |
| 6 | Partial-close arithmetic | ✅ PASS (952/952 real + 40/40 synthetic) | `phase0-unit-tests.md` |
| 7 | Explicit vs implicit break-even | ✅ **IMPLICIT** on config of record | `phase0-unit-tests.md` |
| 8 | Reward geometry long/short | ✅ **Symmetric** (15/15 + 952 real) | `phase0-unit-tests.md` |
| 9 | Broker-native volume | ✅ **Already broker-native** — no change | `phase0-rename-sizing-proposals.md` |
| 10 | GMT/DST/session handling | ⚠️ Correct-with-caveat — 2 bugs logged | `phase0-gmt-dst-validation.md` |
| 11 | Export commission/swap/lots/spread | ✅ Reconciles to the cent | this report §11 |
| 12 | Auto-generate manual from config | ✅ Tool + manifest | `gen_manual_constants.py`, `ea-book/manual-constants.{json,md}` |

---

## Task detail

### 1–2 · Freeze & reproduce — EXACT
Recompiled the config-of-record source (0 errors / 0 warnings), fingerprinted source + binary + `risk_R90.ini`, and deployed the frozen binary as `UltimateTrader_FREEZE.ex5` (`da12cf88…`). Re-running it reproduced the binding baseline **to the cent**: $23,856.89, PF 1.31, Sharpe 2.21, EqDD 13.14%, 2053/3005 deals, 952 positions. Reproduce harness: `claude/gate/freeze_repro.sh`. This is the anchor every later identity check is measured against.

### 3–4 · Session discrepancy & dormant count — RESOLVED
The 12 "session" fills in the Stats CSV (`Asian Breakout London`×9 + `London Continuation NY`×3) are **not** from `CSessionEngine` (which fired 0×, genuinely mute). They are emitted by a `CSessionBreakoutEntry` instance **composed inside `CExpansionEngine`** as its Priority-5 sub-strategy (`CExpansionEngine.mqh:384,520-529`), ungated by the `InpSession*` flags and re-tagged `ExpansionEngine`/`MODE_LONDON_BREAKOUT`. Verified on the authoritative 952 baseline: Expansion = 26 fills = 14 IC + 12 session; all seven live engines sum to 952 exactly.

**Dormant count = FIVE** (RangeEdgeFade/S3, VolatilityBreakout, Displacement, LiquidityEngine, SessionEngine), each with enables ON but internal conditions never satisfied on gold H1 in 7.5y. The book's "5 mute" number was right; its *reasoning* ("no live session-breakout of any kind") was wrong — session-breakout logic trades in one of its three homes (inside Expansion).
**Docs corrected:** `entry-strategies-report.md` (false claim at old line 147, Expansion rows/§2.6) and `ea-book/03-the-scouts.html` (Session-off + Expansion cards now disclose the composed sub-strategy).

### 5 · Rename the hourly "daily 200 EMA" — behavior-neutral
The `InpUseDaily200EMA` toggle drives `iMA(_Symbol, PERIOD_H1, 200, …)` (`CMarketContext.mqh:313`) — the **H1** 200-EMA "tide" line, not D1. Applied: fixed the user-facing input label; renamed the two misnamed members `m_use_daily_200ema → m_use_h1_200ema` and the "Daily 200 EMA Smart Filter" comment in `CTradeOrchestrator.mqh` + `CSignalValidator.mqh`. **The input *key* `InpUseDaily200EMA` was deliberately kept** — it appears in `risk_R90.ini` and 8 other config files; renaming the key would silently break reproduction (MT5 drops unknown keys → compiled default). All changes are variable-name/comment/label only → byte-identical behavior.
**Identity proof — PASSED:** compiled 0/0, deployed `UltimateTrader_RENAME.ex5` (md5 `2c191864…`, byte-different from `FREEZE` due to embedded identifier/comment strings), full 7.5y reproduce = **$23,856.89 / PF 1.31 / Sharpe 2.21 / EqDD 13.14% / 2053 / 952** — identical to the frozen baseline to the cent. The rename is behaviorally byte-identical; the input key `InpUseDaily200EMA` is unchanged, so all config files still load correctly. Identity re-prover: `claude/gate/identity_run.sh UltimateTrader_RENAME.ex5 RENAME`.

### 6 · Partial-close arithmetic — PASS
Two independent checks. **Real data:** all 952 positions — 0 step violations, 0 over-closes, 0 orphan sub-min remainders. **Synthetic edge cases** (`CPositionCoordinator.mqh:2412/2488/2563`): 40/40 across lots {0.01…2.53}; tiny sizes degrade correctly (0.01 rides whole as runner; 0.02 closes 0.01 then skips — never emits a 0.00x lot).
*Latent note (LOW, not a live bug):* the ladder uses `NormalizeDouble(x,2)` (hardcoded 2dp) rather than `SYMBOL_VOLUME_STEP` — identical on XAUUSD+ (step 0.01) but a portability assumption on a coarser-step symbol.

### 7 · Break-even: explicit vs implicit — IMPLICIT
On the config of record, break-even is **implicit**. The explicit mover `SynthesizeBEMoverUpdate` (`CPositionCoordinator.mqh:3166-3208`) is gated behind `InpEnableBEMover` (**default-false, off in `risk_R90.ini`**); the anti-stall explicit BE path needs `InpEnableEarlyInvalidation` (also off). `InpTrailBETrigger=0.8R` only flips the `at_breakeven` *diagnostic flag* once the Chandelier trail has *independently* ratcheted the stop to entry+offset. The 107/952 populated `BE_Time` timestamps observed in the data are that flag recording when the chandelier organically reached BE — **not** an independent mover. This *confirms* (not refutes) the earlier "no active BE mover" finding. Boundary test pinned arming at exactly 0.80R (NO at 0.4R, YES at 0.9/1.0/1.5R).

### 8 · Reward geometry longs vs shorts — SYMMETRIC
With `InpRRGateSymmetric=true`, mirrored long (2000/1990/2013) and short (2000/2010/1987) compute RR = **1.300000 bit-identical**, risk distance symmetric, gate accepts/rejects identically at 1.29/1.30/1.31 for both. Real data agrees: `RiskDistance == |entry−SL|` with **0 mismatches** and **0 sign violations** across 555 longs / 397 shorts. The pre-SF-1 `MathMax` asymmetry was reproduced (short 0.60 REJECT vs long 1.30 ACCEPT) and confirmed removed by the symmetric-reward path (`CTradeOrchestrator.mqh:1339-1345`).

### 9 · Broker-native expected loss — ALREADY CORRECT
Sizing (`CQualityTierRiskStrategy.mqh:375-394`) queries `SYMBOL_TRADE_TICK_VALUE` and `SYMBOL_TRADE_TICK_SIZE`; the denominator reduces algebraically to `stop_distance · tick_value / tick_size` = the broker's exact loss-per-lot, in account currency. No hard-coded `$1/pt`, no missing conversion. **Error on gold: 0%.** The optional `OrderCalcProfit` rewrite is readability-only and identity-preserving on XAUUSD/USD; **not adopted** (zero correctness gain, small non-identity risk on other symbols).

### 10 · GMT/DST/session — CORRECT-WITH-CAVEAT (2 bugs)
- **BUG-1 (MEDIUM) — winter session off-by-one (tester only).** `CSessionEngine::Initialize()` / `CMarketContext::ResolveGMTOffset()` fall back to a fixed `InpBrokerGMTOffset=3` (summer, no DST) in the Strategy Tester; broker data is +2 in winter → the session clock reads 1h behind true GMT ~Nov–Mar (~45% of the year). **Live is unaffected** (offset auto-detected). On the production config the only materially-skewed consumer is the session-risk multiplier boundary timing (session entry modes off, Friday = full ban).
- **BUG-2 (LOW) — EU-vs-US DST** in `CFileEntry::GetEETOffset()`, file-injection path only.
- **INFO** — the crash engine's documented 13:00–17:00 GMT window is **not enforced**: `m_start_hour/m_end_hour` are dead members (`CCrashBreakoutEntry.mqh:56-59`).
- Anchor cross-check (NFP/CPI/FOMC) against `NewsCalendar_USD.csv` **PASS** — the `CNewsGate` US-DST model is correct.
These are **logged, not fixed** (BUG-1 changes backtest results → Phase-1 decision).

### 11 · Commission / swap / lots / spread — reconciled to the cent
From the 3,006-deal frozen report + 952-position Stats CSV:

| Component | Value |
|---|---|
| Gross price P/L | **$29,579.34** |
| Commission | **−$1,042.44** |
| Swap | **−$4,680.01** |
| **Net (report)** | **$23,856.89** |
| Total entry volume | **173.74 lots** (347.48 round-trip) |
| Entry spread cost (Σ spread_pts × lots × $1) | **≈ $1,830.17** |

Reconciliation is exact: `29,579.34 − 1,042.44 − 4,680.01 = 23,856.89`. (The EA's internal `PnL_Money` basis of $24,378.11 already nets most costs; the residual to broker-net is $521.22.)

### 12 · Auto-generate manual from config — tool delivered
`claude/gate/gen_manual_constants.py` (stdlib, idempotent) parses 446 inputs + the config-of-record ini + 3 code literals, and emits `ea-book/manual-constants.json` and `…md` — 41 manual-cited constants resolved, 0 unresolved, each with input name, source file:line, default, config-of-record value, and a book-phrase→constant mapping so the field manual can be verified/regenerated from source instead of hand-maintained.

---

## Findings ledger (for Phase-1 triage — NOT actioned here)

| ID | Severity | Finding | Live impact |
|----|----------|---------|-------------|
| BUG-1 | MEDIUM | Winter session clock off-by-one in tester (fixed +3 fallback) | Skews session-risk-multiplier timing in winter backtests; **live unaffected** |
| BUG-2 | LOW | EU-vs-US DST in `CFileEntry::GetEETOffset()` | File-injection path only |
| INFO-1 | INFO | Crash-engine 13–17 GMT window not enforced (dead members) | Crash fires any hour; docs overstate a window |
| INFO-2 | LOW | Partial-close ladder uses `NormalizeDouble(x,2)` not `SYMBOL_VOLUME_STEP` | None on XAUUSD+; portability only |

## What changed vs what did not
- **Changed:** behavior-neutral rename (Task 5, identity-proven); documentation corrections (session/Expansion in census + book); new tooling (`gen_manual_constants.py`, `freeze_repro.sh`, `identity_run.sh`, `UT_Phase0`).
- **NOT changed:** zero trading logic. Sizing left as-is (already correct). All logged bugs deferred to Phase 1 by design.
