# OPT-0 — REAL-TICK BASELINE (Model=4) — methodology switch

Goal: re-state the production baseline NUMBER under accurate modelling ("Every tick based on
real ticks" = Model=4) so the optimization menu tunes against a trustworthy figure. The
look-ahead FIXES are mode-independent and unchanged; this is a PURE MEASUREMENT run on committed
HEAD. No source/config changes.

- Branch `feat/multi-strategy`, committed HEAD = `2a39bc1` (plan-complete), source-tip `b0595e6`.
- Binaries: MetaEditor / terminal64 under `C:\Program Files\Vantage Markets MT5 Terminal\`.
- Data dir: `C:\Users\nullkuhl\AppData\Roaming\MetaQuotes\Terminal\725B72F25E46C780EF59F57016D58156`.
- Prior standard = Model=1 (1-min OHLC) baseline: **Net $20,085.56 / PF 1.32 / 928 positions /
  Eq-DD 13.02% / Sharpe 2.41** (full 2019.01.01-2026.06.27, XAUUSD+ H1).

---

## STEP 1 — Real-tick availability for XAUUSD+ (VERIFIED AVAILABLE, full range)

Tick base on disk: `bases/VantageMarkets-Live/ticks/XAUUSD+` (real-tick `.tkc` monthly caches).

- BEFORE probing, only 3 months were cached (202604/05/06) — that is just what had been
  downloaded; it is NOT the broker's coverage limit.
- Requesting Model=4 over a date range triggers an ON-DEMAND real-tick download from the Vantage
  history server. The 2019.06 + 2026.05 probes pulled the **entire 2019.06 -> 2026.06 range**:
  **85 monthly `.tkc` files now cached, earliest `201906.tkc`, latest `202606.tkc`** (valid
  MetaQuotes tick caches; header "Copyright 2000-2026, MetaQuotes Ltd.").

### Probes (all Model=4, full 396-param production config, XAUUSD+ H1)
Authoritative modelling indicator = the STANDARD tester report's "% real ticks" row (NOT the
agent-log "generate N ticks" wording, which appears even in real-tick mode — it is the count of
ticks fed to the test engine, incl. bar-boundary synthetic ticks).

| Probe month | Report "% real ticks" | Runtime (wall) | Verdict |
|---|---|---|---|
| 2019.06 | **93% real ticks** | ~127s (incl. full-range download) | real ticks present, slightly thin |
| 2026.05 | **100% real ticks** | ~17s | real ticks present |
| 2025.10 | **100% real ticks** | ~19s | real ticks present |

CONCLUSION (step 1): **Real ticks ARE available for XAUUSD+ across the FULL 2019.01 - 2026.06
window.** The full-baseline run's history-sync phase downloaded all of Jan-May 2019 too;
`.tkc` cache now = **90 months, earliest `201901.tkc`, latest `202606.tkc`** (all 12 of 2019
present). 2019.06 graded 93% real ticks, recent months 100%. The full re-baseline over
2019.01.01-2026.06.27 IS FEASIBLE — broker real-tick gold history starts at/before Jan 2019.

INTERPRETATION TRAP AVOIDED: agent log says `XAUUSD+: generate 15674748 ticks` even on real-tick
runs — that wording is NOT proof of generation. The report's "% real ticks" row is the truth.
`config/terminal.ini` persisted `TicksMode=4` / `LastTicksMode=4` confirming Model 4 engaged.

---

## STEP 2 — Compile HEAD + 3b binary binding

Compile (verbatim Result):
```
Result: 0 errors, 16 warnings, 8877 ms elapsed, cpu='X64 Regular'
```
0 errors, 16 warnings = exactly the post-6.5 baseline (no new warnings). PASS.

3b md5 binding (load path = data-dir Experts):
```
FRESH(repo)     = 43325ba9619a4fa63f4649a29c61c1dc
LOAD(_RT.ex5)   = 43325ba9619a4fa63f4649a29c61c1dc   ASSERT PASS (== fresh)
```
Probe binary `_RTPROBE.ex5` md5 = `43325ba9619a4fa63f4649a29c61c1dc` (same fresh build).

---

## STEP 3 — Real-tick baseline run (Model=4) — PENDING (in progress)
.ini = clone of `backtest_p69A.ini` (396 params, InpEnableMultiStrategy=false, all engines false),
ONLY `Model=1->4` changed (+ Expert name + Report name). Range 2019.01.01-2026.06.27.
[Tester] Model=4 ; Symbol=XAUUSD+ ; Period=H1 ; Deposit=10000 ; Leverage=100.

(Runtime + metrics + yearly split filled after the run.)

## BASELINE-ANCHOR CLARIFICATION (flag for the user)
The committed-HEAD Model-1 A/B legs produced DIFFERENT nets from a BYTE-IDENTICAL config:
- `p69_A.htm`: Net **$17,455.34** / PF 1.28 / Sharpe 2.26 / Eq-DD Max 12.64% / Total Trades 1742 (deals).
- `p69_B.htm`: Net **$20,085.56** (the RESUME.md post-6.9 baseline).
`diff backtest_p69A.ini backtest_p69B.ini` (ex header) = EMPTY -> same 396 params, same Model=1,
same range, same committed binary. Same config + same binary -> two different nets is the
signature of a STATE-FILE / determinism confound (RESUME.md 3b warns a stale
`Common\Files\UltimateTrader_State.bin` is a real but secondary P&L confound; one such file,
1051 bytes, is present). The instruction's comparison anchor = the B-leg $20,085.56 / PF 1.32 /
928 positions / Eq-DD 13.02% / Sharpe 2.41. My rt_baseline.ini cloned the (identical) A-leg
config, Model 1->4 only. NOTE: this A/B Model-1 non-determinism is itself a reason real-tick
remeasurement is worthwhile, and means the rt vs Model-1 delta carries this confound — flagged.

## STEP 3 — Real-tick baseline run (Model=4) — COMPLETE
- .ini = `rt_baseline.ini`, clone of `backtest_p69A.ini`, ONLY changed: `Model=1`->`Model=4`,
  Expert `_p69A.ex5`->`_RT.ex5`, Report `p69_A`->`rt_baseline`. `diff` (ex 3 header lines) = EMPTY.
- [Tester] **Model=4** ; Symbol=XAUUSD+ ; Period=H1 ; From 2019.01.01 To 2026.06.27 ;
  Deposit=10000 ; Leverage=100 ; InpEnableMultiStrategy=false ; 396 params.
- **RUNTIME (wall-clock): 5m 47s** (tester "test passed" timing = 5m 03s test + 4s history sync;
  history was PRE-CACHED by the step-1 probes — a cold run would add the one-time tick download
  ~3-4 min). 429,309,840 real ticks processed.
- **History Quality: 99% real ticks** (report row) — genuine real-tick run confirmed.

## STEP 4 — Real-tick baseline metrics (from rt_baseline.htm + TradeEvents CSV)
HEADLINE (authoritative = standard report):
- **Net $13,267.13 | PF 1.24 | Sharpe 1.90 | Eq-DD Max 13.26% | Bal-DD Max 12.26% | 1793 trades (deals)**
- Gross Profit $68,100.63 / Gross Loss -$54,833.50 / Expected Payoff $7.40 / Recovery 3.73
- Win rate 71.83% (1288 W / 505 L) ; Avg profit $52.87 / Avg loss -$107.68
- Short 600 (71.50% won) / Long 1193 (72.00% won)
- 929 positions (ENTRY_OPENED/EXIT_FILL) — matches the "928 positions" baseline notion (+1).

PER-YEAR (TradeEvents EventPnL by year ; 929 closed positions ; portfolio avg-R 0.131):
| Year | Net $ | Pos | AvgR |
|---|---|---|---|
| 2019 | 253.07 | 94 | 0.113 |
| 2020 | 1.08 | 77 | 0.071 |
| 2021 | 1074.81 | 121 | 0.088 |
| 2022 | 789.94 | 157 | -0.011 |
| 2023 | -230.28 | 132 | -0.001 |
| 2024 | 1534.32 | 146 | 0.097 |
| 2025 | 10763.02 | 146 | 0.552 |
| 2026 (H1) | -465.53 | 56 | 0.030 |
| TOTAL | 13720.43 | 929 | 0.131 |
(CSV-summed EventPnL $13,720.43 vs report Net $13,267.13: ~$453 gap = swap/commission/open-mark;
report is the headline. **2025 carries the book** — $10,763 of $13,267, avg-R 0.552 vs ~0.0-0.1
elsewhere; 2022-23 are flat/negative, 2026-H1 negative.)

## STEP 5 — Model-1 vs Real-tick comparison + characterization
| Metric | Model-1 (p69_B baseline) | Real-tick (Model=4, 99%) | Delta |
|---|---|---|---|
| Net | $20,085.56 | **$13,267.13** | **-$6,818.43 (-33.9%)** |
| PF | 1.32 | **1.24** | -0.08 |
| Sharpe | 2.41 | **1.90** | -0.51 |
| Eq-DD Max | 13.02% | **13.26%** | +0.24pp |
| Trades (deals) | (~928 pos) 1793→ | 1793 deals / 929 pos | ~flat |
(Note p69_A leg was $17,455.34 from the SAME config — see anchor caveat above. Even vs the
LOWER A-leg, real-tick is -$4,188 / -24%.)

CHARACTERIZATION — where real-tick diverges:
- **Direction: real-tick is materially WORSE** (-34% net, -0.5 Sharpe), PF/DD roughly intact.
  This is the textbook real-tick penalty: the bid/ask spread and intrabar tick path are real, so
  fills, partial-TP touches and trailing stops resolve on the true sequence instead of optimistic
  M1-OHLC interpolation. ~Same trade count -> the edge per trade shrank (avg-R/expected-payoff
  $10.02 Model-1 -> $7.40 real-tick), not the trade frequency.
- **Where it bites: fills/exits on the real intrabar path.** With ~same 929 positions, the loss is
  in P&L-per-trade, consistent with (a) real spread widening the entry/exit, (b) closed-bar
  trailing/TP now measured against the true intrabar high/low so more trails get tagged and more
  TP1/TP2 partials resolve less favorably. The look-ahead FIXES are unaffected (mode-independent);
  this simply re-prices the SAME logic on honest ticks.
- **Spread-shock gate now sees real spread variation:** the `[ShockDetector]` SPREAD leg is LIVE
  under real ticks (Spread/Avg ~2.07-2.10, MODERATE shocks fire) — that real spread variation is
  part of why fills are worse than Model-1's fixed/optimistic spread.

[ShockDetector] FINDING (the bar-range/M5 legs):
- 161 ShockDetector firings sampled across the run. **BarRange/ATR and M5/ATR are STILL 0.00 on
  EVERY firing** even under 99% real ticks — they did NOT come alive. Only the Spread leg fires.
- => The degenerate 0.00 on the bar-range / M5-shock legs is a **CODE-LEVEL computation issue in
  the shock detector, NOT a Model-1 modelling artifact** (real intrabar ticks did not populate
  them). The shock gate is effectively SPREAD-ONLY. Flag for the optimization menu / a future fix.

---

## RESUME.md EDIT DRAFT (for the user to integrate)
Switch the standard from Model=1 to Model=4 and record the real-tick baseline + usable range.

1) In §(b) step 4 (backtest), CHANGE the model instruction to:
   "Use **Model=4 (Every tick based on real ticks)** as the standard — real ticks are available
    for XAUUSD+ over the FULL 2019.01.01-2026.06.27 (History Quality 99%; broker gold ticks start
    ≤Jan-2019). A full-range real-tick run ≈ **6 min wall-clock** once ticks are cached
    (`bases/VantageMarkets-Live/ticks/XAUUSD+`, 90 monthly `.tkc`); a COLD first run adds a
    one-time ~3-4 min tick download. Model-1 (1-min OHLC) is DEPRECATED for baselining."

2) In §3b, REPLACE the binding-baseline line with:
   "**REAL-TICK binding baseline (Model=4, committed HEAD 2a39bc1, 99% real ticks, full
    2019.01.01-2026.06.27, XAUUSD+ H1, InpEnableMultiStrategy=false):
    Net $13,267.13 / PF 1.24 / Sharpe 1.90 / Eq-DD Max 13.26% / Bal-DD Max 12.26% /
    1793 deals (929 positions) / portfolio avg-R 0.131.** Per-year: 2025 carries it
    ($10,763, avg-R 0.55); 2022-23 flat/neg; 2026-H1 -$466. The prior Model-1 figure
    ($20,085.56 / PF 1.32 / Sharpe 2.41) is SUPERSEDED — it overstated net by ~34% via optimistic
    M1-OHLC fills. Reproduce via `rt_baseline.ini` (clone of p69A, Model 1->4 only). NOTE the
    persistent A/B Model-1 non-determinism ($17,455 vs $20,085 from identical config) — re-anchor
    on the real-tick number going forward."

3) Add a note: "[ShockDetector] bar-range & M5 legs read 0.00 even under real ticks => code-level
   bug, shock gate is spread-only; address before tuning the shock gate."

Artifacts:
- Report: `…/Terminal/725B72F25E46C780EF59F57016D58156/rt_baseline.htm` (+ .ini same dir).
- Per-strategy CSV: `…/Terminal/Common/Files/backtest_results_20260626.csv`.
- TradeEvents CSV: `…/Terminal/Common/Files/UltTrader_TradeEvents_XAUUSD+_20190101_0000.csv`.
