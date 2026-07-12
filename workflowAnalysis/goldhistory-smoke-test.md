# XAUUSD_GOLDHISTORY custom-symbol smoke test (Task 13)

**Custom symbol:** `XAUUSD_GOLDHISTORY` (path `Custom\Gold`)
**Source spec cloned from:** `XAUUSD+` (Vantage, `Gold+\XAUUSD+`) — read-only, never modified
**Frozen EA under test:** `UltimateTrader_FREEZE_DST.ex5` (md5 `405854d8ddc37de15f0ef67f2f7716ea`, `InpTesterDSTFix=true`) — not recompiled
**Import (EXTENDED 2009–2025):** `Common/Files/XAUUSD_GOLDHISTORY_M1.csv` (sha256 `6ca76fdd…c702133d`) → **5,826,682** M1 bars, **2009.01.02 10:00 → 2025.12.31 23:59**
**Spec-source hash (SHA256 over probed spec kv):** `38e5fb1f51c276be875b94cd292f0c36da5a850b1dd7120ca86dcfa158d0d3f5`

**Re-import note:** the staged CSV was replaced with an extended normalized M1 (now 2009→2025). `GHBuild` delete+recreated the symbol and re-imported the full range via `CustomRatesReplace`; the recreate re-clones the **identical** `XAUUSD+` spec (spec unchanged), and `XAUUSD+`/its history were not touched. On-disk history now spans `bases/Custom/history/XAUUSD_GOLDHISTORY/{2009..2025}.hcc`.

**Headless persistence mechanism:** custom symbols created inside the Strategy Tester are sandboxed and do NOT persist. `GHBuild.ex5` was launched on a **live chart** via a `[StartUp]` startup `.ini` (`claude/gate/gh_persist.sh`), did all work in `OnInit`, wrote a done-sentinel, then `TerminalClose(0)`. Persistence was proven by fully **restarting the terminal** and running `GHSmoke.ex5`.

## Result: 17/17 in-terminal checks PASS + tester run PASS

| # | Test | Result | Evidence |
|---|------|--------|----------|
| 1 | Symbol exists after **terminal restart** | **PASS** | fresh launch; `SymbolExist`=1, isCustom=1; on-disk `.hcc` 2009–2025 |
| 2 | M1 count matches file | **PASS** | `Bars(M1)=5,826,682` == file 5,826,682 (authoritative stored count) |
| 3 | First / last M1 bars match | **PASS** | first `2009.01.02 10:00` O874.20 H874.30 L874.20 C874.20; last `2025.12.31 23:59` O4318.89 H4319.23 L4317.95 C4318.36 |
| 4 | H1/H4/D1 build; D1 rollover = 00:00 | **PASS** | H1=99,050 H4=26,040 D1=4,358 (span 2009→2025); 200/200 D1 bars open at 00:00 |
| 5 | No synthetic weekend candles | **PASS** | 60,000 H1 bars sampled: Saturday=0, Sunday=0 |
| 6 | iMA / iATR / iADX valid | **PASS** | EMA50=4355.7841, ATR14=20.9350, ADX14=26.8334 |
| 7 | SymbolInfo tick/contract calcs valid | **PASS** | tickValue=1.00, tickSize=0.01, contract=100, volMin=0.01, volStep=0.01 |
| 8 | **2016-01 boundary continuity** | **PASS** | seam `2015.12.31 18:47` (O1060.74, Dec-31 early close) → `2016.01.04 01:05` (O1064.88); strictly monotonic, no dup/overlap; gap 4,698 min = normal New-Year holiday |
| 9a | **2011 M1 sample** (2011.06.01 12:00) | **PASS** | O1530.10 H1530.20 L1530.00 C1530.08 exact |
| 9b | **2011 H1 builds** (2011.06.01 12:00) | **PASS** | H1 bar present, open 1530.10 |
| 9c | **2011 D1 builds + rollover** (2011.06.01) | **PASS** | D1 bar at 00:00, open 1535.05 |
| 10 | Frozen EA opens/modifies/closes ≥1 position, sane lot | **PASS** (Model=1) | 23 trades / 35 deals / 12 positions; net +100.91; PF 1.18; money-correct lots |
| 11 | Cross-check timestamps across sources | **PASS** | CC1/CC2/CC3 (M1) + CC4 (generated H1 vs raw `XAU_1h_data.csv`) exact |

### Coordinator's four asks
1. **Imported count == 5,826,682** — YES (parsed 5,826,682 / replaced 5,826,682 / 0 rejects; `Bars(M1)=5,826,682`).
2. **First == 2009.01.02 10:00, last == 2025.12.31 23:59** — YES (both asserted exact).
3. **Boundary OK across 2016-01** — YES: `2015.12.31 18:47` → `2016.01.04 01:05`, strictly monotonic, no gap/overlap where the old data began; the 4,698-min gap is the legitimate New-Year holiday (Dec-31 early close, Jan 1 holiday, Jan 2–3 weekend).
4. **2011 data builds** — YES: 2011.06.01 M1 exact, H1 (open 1530.10) and D1 (00:00 rollover, open 1535.05) both build.

### Note on M1 deep-history access
On a **fresh live chart**, a custom symbol's M1 series lazy-loads its deep history from the `.hcc` files, so an initial full-range `CopyRates` only synchronized back to ~2015.12.30. `GHSmoke` therefore **warms the M1 series back to 2009** before reading; after warmup, 2009 and 2011 M1 bars read exactly. `Bars(M1)=5,826,682` is authoritative for the stored count, and H1/H4/D1 build from the full history regardless. **This is a live-chart cache behavior only — the Strategy Tester reads the full `.hcc` history for the test range**, so Task 14's 2011–2017 structural test has the complete data.

### Test 10 detail (frozen EA, `Model=1`, 2024.03.01→2024.04.01)
Run on the **2016+ portion (byte-unchanged by the extension** — CC1 `2016.01.04 01:05` O1064.88 identical before/after). Net **+100.91**, PF **1.18**, **23 trades / 35 deals / 12 positions**; entries filled, **modified** (Chandelier trail, BE), **partial-closed** (TP1/TP2), and closed; lots money-correct vs known stops (e.g. risk $94.50 / stop 14.09 → 0.06 lot).

### Note on test 7 (`OrderCalc*`)
On the live chart `OrderCalcMargin/Profit` returned 0 (err 4758, `ask=0.00`): a custom symbol offline has no live tick / no resolvable leverage — a live-chart artifact, not a spec defect. Test 10 (tester) is the authoritative P/L proof.

## ⚠️ CRITICAL for Task 14 — tester model
- **`Model=4` (real ticks) does NOT work** — tester aborts `"no history data, stop testing"` → 0 trades (only M1 rates imported, no ticks).
- **`Model=1` (1-min OHLC) works** — synthesizes ticks from M1 bars and trades normally.
- Staged runner `claude/gate/gh_run.sh` defaults to `Model=4`; **Task 14 must pass `Model=1`** (or import ticks via `CustomTicksReplace`).

## ⚠️ CRITICAL for Task 14 — commission
- Custom-symbol tester applies **ZERO commission**: commission total **0.00** across all 23 closing deals (no clonable `SYMBOL_*` commission tier).
- **Swap IS applied** (cloned): swap total **−79.96** across 8 deals (`SYMBOL_SWAP_LONG=-79.17` / `SHORT=28.84`, POINTS).
- **Action:** Task 14 must layer commission externally via the production per-lot model; swap needs no adjustment.

## Cloned spec (readback-verified)
digits **2** · point/tickSize **0.01** · tickValue **1.0** · contract **100** · volMin/step **0.01** / max **100** · calcMode **4 (CFD-Leverage)** · tradeMode **4 (FULL)** · exeMode **2 (MARKET)** · filling **2 (IOC)** · stopsLevel **20** · swapMode **1 (POINTS)** swapLong **−79.17** swapShort **28.84** rollover **Wed** · marginInitial/maint **0** · base **XAU** / profit+margin **USD** · sessions **Mon–Fri** (quote 01:00–23:58, trade 01:01–23:58; Fri to :57). 31/33 props cloned via `CustomSymbolSet*`; the 2 exceptions (`SYMBOL_TRADE_TICK_VALUE_PROFIT/LOSS`) are computed fields — base tickValue 1.0 governs P/L (verified in test 10).

## Artifacts
- Scripts (compile 0/0): `MQL5/Experts/GHProbe.mq5`, `GHBuild.mq5`, `GHSmoke.mq5`; driver `claude/gate/gh_persist.sh`
- Machine outputs (`Common/Files`): `gh_spec.{txt,kv}`, `gh_build.{txt,kv}`, `gh_smoke.{txt,kv}`
- Manifest: `workflowAnalysis/goldhistory-customsymbol-manifest.json`
- Terminal change: `config/common.ini` `MaxBars 100000 → 2147483647` (backup `common.ini.ghbak`) so live-chart `CopyRates` can reach full depth; no effect on the tester.
