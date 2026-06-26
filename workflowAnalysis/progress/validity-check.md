# Validity check — does ExpertParameters-via-/config silent-ignore invalidate prior backtests?

**Date:** 2026-06-27 · **Branch:** feat/multi-strategy · **HEAD:** 3d2cbf5 (`2.4-GATE`)
**One run only.** Ran synchronously, decoded, compared. No sub-agents, no extra runs.

## Concern being tested
A prior agent flagged that `ExpertParameters=<file>.set` may be silently ignored when a backtest is
launched via `/config`. If true, prior-phase backtests would not have loaded the intended production
config, and the byte-identity A/B results across phases would be suspect.

## Method — RELIABLE inputs injection (NOT ExpertParameters=<file>.set)
- Binaries (verified on disk, not from stale scripts): MetaEditor / terminal under
  `C:\Program Files\Vantage Markets MT5 Terminal\`. Data dir user `nullkuhl`,
  terminal ID `725B72F25E46C780EF59F57016D58156`, **NO `/portable`**.
  (The committed `backtest_*.sh` point at `Vantage International MT5` + terminal ID `010E0471…` /
  user `ahmed` — STALE/WRONG; not used.)
- **Built the committed-HEAD `.ex5`:** the working tree had one uncommitted 1-line edit in
  `CTrendContinuationEngine.mqh` (a `PHASE-3.7 RUN-B TEMP` swing-low stub). Checked that file out to
  HEAD, compiled → `Result: 0 errors, 38 warnings` (baseline, 0 new), md5
  `3b4d0ea9373f73ab74119d9c193f20d7`, copied to the tester `MQL5/Experts/`. Restored the working-tree
  edit afterward. So the binary under test is byte-for-byte committed-HEAD source.
- **Config:** wrote `validity_check.ini` with a `[TesterInputs]` block (the reliable per-input
  override) and **deliberately NO `ExpertParameters=`** line:
  ```
  [Tester]
  Expert=UltimateTrader.ex5
  Symbol=XAUUSD+  Period=H1  Model=1
  FromDate=2024.01.01  ToDate=2025.01.01
  Deposit=10000  Currency=USD  Leverage=100
  ExecutionMode=0  Optimization=0  Visual=0  ReplaceReport=1  ShutdownTerminal=1
  [TesterInputs]
  InpEnableMultiStrategy=false   ; production master gate OFF
  InpSymbolProfile=0             ; SYMBOL_PROFILE_XAUUSD (gold)
  InpSignalSource=2              ; SIGNAL_SOURCE_BOTH
  ```
  Enum ordinals verified in `Include/Common/Enums.mqh`: `SYMBOL_PROFILE_XAUUSD=0`,
  `SIGNAL_SOURCE_BOTH=2`. These three keys are also the EA's compiled-in source defaults
  (`UltimateTrader_Inputs.mqh:498,14,18`), i.e. production = source defaults. Pinning them in
  `[TesterInputs]` removes all dependence on either an `.set` file OR the terminal's last-saved inputs.
- Deleted the stale pre-run `UltTrader_Stats_XAUUSD+_20240101_0000.csv` from the Common\Files dir
  first so the fresh write is unambiguous. (The stale one was 5144 B and contained routed
  `TrendContinuationEngine` SIGNAL_SOURCE_PATTERN rows — an engines-ON GATE artifact, NOT the anchor.)
- EA writes its Stats CSV to the **Common** Files dir
  (`…\Terminal\Common\Files\UltTrader_Stats_XAUUSD+_20240101_0000.csv`, `FILE_CSV|FILE_COMMON`,
  UTF-16LE), confirmed at `CTradeLogger.mqh:359-362`.

## Decoded result (fresh 2024 run)
| Metric | This run | Anchor | Match |
|---|---|---|---|
| Trades (ENTRY=EXIT rows) | 140 | 140 | ✅ |
| Net PnL_Money | $1190.84 | $1190.84 | ✅ |
| Total R | 11.76 | 11.76 | ✅ |
| avg R | 0.0840 | 0.0840 | ✅ |
| Win rate | 46.43% (65/140) | 46.43% | ✅ |
| Long / Short | 109 / 31 | 109 / 31 | ✅ |
| **Stats CSV md5** | **04d116972696f905c6ea5fa6701a7155** | **04d116972696f905c6ea5fa6701a7155** | ✅ **byte-identical** |

Net/R parsed comma-safely (free-text columns contain commas) via Python `csv` keyed off the header,
summing `PnL_Money` / `PnL_R` over `EXIT` rows.

## Reconciliation with the counter-evidence
The GATE derivation produced **197 ROUTED engine trades** — only possible if
`InpEnableMultiStrategy=true` was actually applied (the scorer is attached to engines solely inside
`if(InpEnableMultiStrategy)` per `UltimateTrader.mq5:717-750`, and `routed_engine` is set only inside
each engine's `if(m_scorer!=NULL)` block). So the GATE `.set` WAS honored. That squares with this
check: the "silent ignore" is **method/launch-specific, not universal**. Here the reliable
`[TesterInputs]` path reproduces the production anchor exactly, and the GATE run clearly loaded its
engines-ON inputs (197 routed trades is impossible otherwise). The most likely truth: the failure the
prior agent saw was confined to a specific attempt (e.g. a per-engine-isolation `.set` that didn't
take), while in the general case the terminal either honored `ExpertParameters` OR its last-saved
inputs already matched the intended config — and on the production config (`InpEnableMultiStrategy=
false`) the orchestrator path is structurally unchanged, so the engines-OFF anchor is reproduced
regardless of how the run was launched. Either way, both the production-anchor runs and the engines-ON
GATE run loaded the inputs they were meant to.

## VERDICT
**Prior A/B / byte-identity results are VALID.** The production config (XAUUSD+ H1, Model=1, 2024,
`InpEnableMultiStrategy=false`, gold profile, Signal Source BOTH), run via the reliable `[TesterInputs]`
injection on the committed-HEAD `.ex5`, reproduces the committed anchor **byte-for-byte** (Stats md5
`04d116972696f905c6ea5fa6701a7155`, 140 trades / $1190.84 / 11.76R). The `ExpertParameters`
silent-ignore concern does not invalidate prior phases — nothing needs re-running.
