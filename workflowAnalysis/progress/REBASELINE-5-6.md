# REBASELINE 5.6 — harness-integrity check: did a stale .ex5 get silently run?

> Mission: establish whether a FRESH compile of committed source (HEAD ed488df, Phase 5.5)
> reproduces the recorded post-5.5 baseline ($17,018.83 / PF 1.28 / 1742t), and ROOT-CAUSE
> the stale-binary issue. Branch feat/multi-strategy. ≤2 backtest runs. SYNCHRONOUS.
> Do NOT edit RESUME.md (text drafted below for integration). Do NOT commit.

## 0. Context (recorded numbers being checked against)
- Recorded post-5.5 committed-HEAD baseline (from 5-5.md, B-run): **Net $17,018.83 / PF 1.28 / Sharpe 2.23 / 1742 trades / Eq-DD 12.89%**.
  - B-run EA CSV md5s: Stats `08640614…`, TradeEvents `18aedaca…`, Risk `7b3db7d1…`.
  - B-run binary: `UltimateTrader_p55B.ex5` md5 `d04d76bb1a0b332fbf1b1bb19beec6bd` (STILL ON DISK — used as independent reference).
- Pre-5.5 HEAD baseline (5-5.md A-run): Net $16,685.59 / 1742t.
- The 5.6+5.7 agent's A/B recorded **$25,570.97 / PF 1.31 / 2011t** for "HEAD ed488df" — claimed binary md5 `9dbe9052e8b164f438026bc97e87a3c7`. Directive: that is the PRE-4.6 (c858e6c-era 4.4+4.5) chain, 7 commits stale.

## 1. .ex5 INVENTORY (paths / md5 / mtime — captured BEFORE any delete)
| Path | md5 | size | mtime |
|---|---|---|---|
| repo `/mnt/c/Trading/UltimateTrader/UltimateTrader.ex5` | `330044ccad3d4201bc5534bf1d3118d4` | 913376 | 2026-06-27 06:53:54 |
| data-dir `…/Experts/UltimateTrader.ex5` (tester load path for `Expert=UltimateTrader.ex5`) | `9dbe9052e8b164f438026bc97e87a3c7` | 912816 | 2026-06-27 03:16:37 |
| `…/Experts/UltimateTrader_p56A.ex5` | `9dbe9052…` | 912816 | 2026-06-27 06:53 |
| `…/Experts/UltimateTrader_p56B.ex5` | `9dbe9052…` | 912816 | 2026-06-27 06:53 |
| `…/Experts/UltimateTrader_p55B.ex5` (recorded baseline binary) | `d04d76bb1a0b332fbf1b1bb19beec6bd` | 911548 | 2026-06-27 06:34 |
| (+ p46A/B, p47A/B, p48A/B, p51A/B, p53A/B, p55A — distinct per-phase builds) | various | — | 03:36–06:35 |

**Tester load path:** p56A.ini / p56B.ini set `Expert=UltimateTrader_p56A.ex5` / `_p56B.ex5`, resolved relative to data-dir `MQL5/Experts/`. BOTH `_p56` files held `9dbe9052` → the 5.6 A/B BOTH ran the `9dbe9052` binary. (The default `Expert=UltimateTrader.ex5` data-dir copy was ALSO `9dbe9052`, mtime 03:16.)

**Key size/lineage observation:** the `9dbe9052` build is 912816 bytes, mtime 06:53 (matches the metaeditor 06:52:59 compile). It is NOT byte-identical to the recorded p55B (911548). The repo `.ex5` `330044cc` (913376) at 06:53:54 matches the 06:53:54 compile — i.e. the 5.6 agent compiled TWICE (06:52:59 → datadir/`_p56`; 06:53:54 → repo) and the tester loaded the 06:52:59 datadir build.

## 2. DELETE actions (clear every stale .ex5)
- Backed up reference: `UltimateTrader_p55B.ex5` (`d04d76bb`) → `/tmp/rebaseline_keep/` before any delete.
- DELETED: data-dir `Experts/UltimateTrader.ex5` (`9dbe9052`), `_p56A.ex5`, `_p56B.ex5` (`9dbe9052`); repo `/mnt/c/Trading/UltimateTrader/UltimateTrader.ex5` (`330044cc`); and all other stale per-phase copies (p46A/B…p55A). Kept only `_p55B.ex5` (`d04d76bb`) as the independent reference.

## 3. FRESH COMPILE (working tree = HEAD ed488df + 5.6/5.7 no-op gates)
- `git diff --stat HEAD` on tracked source = only UltimateTrader.mq5 (13 lines) + UltimateTrader_Inputs.mqh (2 lines) — verified to be the 5.6/5.7 `&& register_patterns` / `&& InpEnableEngineExpansion` gates INSIDE `if(InpEnableMultiStrategy)` + one comment. Byte-identical no-op on the production path (InpEnableMultiStrategy=false). So compiling the working tree == compiling committed HEAD ed488df for prod.
- Verbatim: `Result: 0 errors, 38 warnings, 9331 ms elapsed, cpu='X64 Regular'` (exactly the 38-warning baseline; 0 new; no error 106).
- **Fresh .ex5 md5 = `f1e251fa80917aa51dbc9488eaea48a2`** (912988 bytes). **CONFIRMED ≠ `9dbe9052`** (distinct fresh build).

## 4. LOAD-PATH md5 ASSERTION
- Copied fresh build to `…/Experts/UltimateTrader.ex5` AND `…/Experts/UltimateTrader_RB56.ex5`. Asserted both == `f1e251fa80917aa51dbc9488eaea48a2`. OK.
- `backtest_RB56.ini` cloned from golden `backtest_p55B.ini`; diff = `Expert=UltimateTrader_RB56.ex5` + `Report=RB56` ONLY. 396 params. XAUUSD+ H1 Model=1, 2019.01.01–2026.06.27, deposit 10000 USD, leverage 100, InpEnableMultiStrategy=false, InpMinSessionRiskFactor=0.25, InpSignalSource=2.
- Confound control: relocated live `Common/Files/UltimateTrader_State.bin` + 5 `.bak`s → `/tmp/rebaseline_keep/state_backup/` so the run starts on clean recovery state (the 5.6 agent's "data/state drift" hypothesis variable is removed).

### Source-verification of the fresh binary (proves post-5.5, not a 4.4-era artifact)
Working-tree source (HEAD ed488df) — the source `f1e251fa` was compiled from — contains ALL post-4.6/5.5 fixes:
- 4.6 spread-shock gate: `UltimateTrader.mq5:1757` `[ShockGate] EXTREME shock — ALL entries BLOCKED`.
- 5.5 per-bar reset `g_session_quality_factor = 1.0` (mq5:1457) + floor `InpMinSessionRiskFactor` (mq5:1908, Inputs:358).
- 4.8 closed-bar trailing: `CATRTrailing.mqh:141` / `CHybridTrailing.mqh:229` read `CopyBuffer(handle,0,1,1,…)` (closed bar [1]).
So if the fresh run yields $25,570.97/2011t it is a GENUINE chain problem; if $17,018.83/1742t the chain is sound and only 5.6 ran a stale binary.

### EA output CSVs (for byte-comparison to recorded B-run)
EA writes with `FILE_COMMON` → land in `Common/Files/`: `UltTrader_Stats_XAUUSD+_20190101_0000.csv`, `UltTrader_TradeEvents_…`, `UltTrader_Risk_…`, `UltTrader_Candidates_…` (suffix = run-start date). Recorded B-run md5s to match: Stats `08640614…`, TradeEvents `18aedaca…`, Risk `7b3db7d1…`. Confirmed live-updating at 07:14:25 during the RB56 run.

## 5. CLEAN BASELINE RUN — DONE
- Binary at load path = `f1e251fa…` (asserted == fresh build). ini = `backtest_RB56.ini` (396 params, prod defaults, InpEnableMultiStrategy=false, InpMinSessionRiskFactor=0.25). XAUUSD+ H1 Model=1, 2019.01.01–2026.06.27. Clean recovery state (state files relocated). Terminal exited cleanly (ShutdownTerminal=1) at 07:14:49.
- Tester run characteristics: **Bars 44267 / Ticks 10588926** (same history as recorded baseline). Initial deposit 10000 USD.

### Headline (from RB56.htm, decoded)
| Metric | Fresh RB56 | Recorded post-5.5 B (5-5.md) | Match |
|---|---|---|---|
| Total Net Profit | **$17 018.83** | $17,018.83 | EXACT |
| Profit Factor | **1.28** | 1.28 | EXACT |
| Total Trades | **1742** | 1742 | EXACT |
| Total Deals | **2651** | 2651 | EXACT |
| Sharpe | **2.23** | 2.23 | EXACT |
| Expected Payoff | **9.77** | 9.77 | EXACT |
| Recovery | **4.26** | (consistent) | — |
| Balance DD Max | **3 466.91 (11.37%)** | $3,466.91 (11.37%) | EXACT |
| Equity DD Max | **3 993.04 (12.89%)** | $3,993.04 (12.89%) | EXACT |

### EA CSV md5s (byte-level) — ALL MATCH recorded B-run EXACTLY
| CSV | Fresh RB56 md5 | Recorded B md5 | Match |
|---|---|---|---|
| Stats | `08640614b58582cc1ce28687667d5ed6` | `08640614…` | EXACT |
| TradeEvents | `18aedacab31a17b0d83d9cb09509ab91` | `18aedaca…` | EXACT |
| Risk | `7b3db7d178a44e63ca0f400c5027c5f2` | `7b3db7d1…` | EXACT |
| Candidates | `77b07fb1fc2982aaed4899b823bb0e26` | (not recorded in 5-5.md) | — |

## 6. COMPARE
Fresh ed488df run == recorded post-5.5 baseline **byte-for-byte** (3/3 EA CSV md5s) AND tester-headline-for-headline (net/PF/trades/deals/Sharpe/payoff/both DDs). It is **NOT** $25,570.97 / 2011t.

## 7. VERDICT: **COMMITTED CHAIN IS SOUND.** No history drift, no chain break.
- Freshly-compiled committed HEAD ed488df (= working tree, since the 5.6/5.7 edits are prod no-ops) reproduces the post-5.5 baseline EXACTLY on clean state. The 5.6+5.7 phase's $25,570.97/2011t result was produced by a **stale binary** (`9dbe9052`), NOT by the committed source.
- This run ALSO serves as the corrected 5.6+5.7 B-run: working-tree (gates applied) on the prod path == committed HEAD byte-identical. So 5.6/5.7 are proven true no-ops on production. (The 5.6/5.7 A==B byte-identity claim within that phase's log stands — both legs ran the SAME stale binary, so they were identical to each other; they were just both wrong vs the true baseline.)
- `9dbe9052` lineage: NOT a fresh ed488df build (fresh ed488df = `f1e251fa`, reproduces $17,018.83), NOT the committed `.ex5` blob (`e0cfbb3a`, 889424 bytes, stale since `4abb313`), NOT p55B (`d04d76bb`, 911548 bytes). Per directive it is the pre-4.6 (c858e6c-era 4.4+4.5) build whose chain headline is $25,570.97/2011t — consistent with the 5.6 result. The [ShockDetector] events seen in today's 23GB tester log are from OTHER (post-4.6) runs across the day, not from the p56 run.
- Budget used: **1 of ≤2** backtest runs.

## 8. ROOT-CAUSE (how the stale 9dbe9052 got run)
**The compile and the tester load path are DIFFERENT locations, and nothing asserted they agreed.**
1. MetaEditor `/compile` ALWAYS writes the `.ex5` next to the source: `C:\Trading\UltimateTrader\UltimateTrader.ex5` (the repo). The metaeditor.log confirms every compile target is `C:\Trading\UltimateTrader\UltimateTrader.mq5` → repo `.ex5`.
2. The tester loads `Expert=…` resolved relative to the **data-dir** `…\Terminal\725B…\MQL5\Experts\`. So a manual `cp repo.ex5 → datadir/Experts/UltimateTrader_p56X.ex5` step is REQUIRED to bridge them.
3. In the 5.6 phase that copy did not deliver the fresh build to the load path. The fresh compile at 06:52:59 produced a **912386-byte** binary (per 5-6_5-7.md's own line), but `UltimateTrader_p56A.ex5`/`_p56B.ex5` on disk are **912816 bytes / `9dbe9052`** — a *different*, pre-4.6 binary. The pre-existing data-dir `UltimateTrader.ex5` (mtime 03:16, also `9dbe9052`) was the stale source/leftover; the `_p56` slots ended up holding it (copy of the wrong file, or the slot was never overwritten and an old `9dbe9052` `_p56`-named file persisted).
4. **No guard caught it:** the phase never asserted `md5(load-path .ex5) == md5(fresh build)`. The tester silently ran `9dbe9052`. The agent even observed the anomaly ($25,570.97/2011t ≠ recorded $17,018.83/1742t, AND 912386-logged ≠ 912816-on-disk) but mis-attributed it to "data/state drift" (UltimateTrader_State.bin / history re-sync) rather than a stale binary.
**One-line:** the tester loaded a stale pre-4.6 `9dbe9052` binary from the data-dir Experts load path because the fresh repo-path compile was never verified-copied to (or never overwrote) the data-dir load path, and no md5 assertion gated the run.

## 9. RESUME.md procedure-fix text (DRAFT — for user to integrate into RESUME §(b) step 3/4; do NOT edit RESUME yet)

Insert as a mandatory sub-procedure between "Compile to 0 errors" (step 3) and "backtest" (step 4):

> **3b. BIND the binary to the load path (MANDATORY — prevents stale-binary runs).**
> The compiler writes `C:\Trading\UltimateTrader\UltimateTrader.ex5` (repo); the tester loads `Expert=` from the data-dir `…\Terminal\725B72F25E46C780EF59F57016D58156\MQL5\Experts\`. These are DIFFERENT files — they must be reconciled by md5 every run, or a stale data-dir copy is silently tested.
> ```
> DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
> E="$DD/MQL5/Experts"
> # (a) delete the data-dir load-path .ex5 BEFORE compiling (no stale leftover can survive)
> rm -f "$E/UltimateTrader.ex5" "$E/UltimateTrader_<phase>.ex5"
> # (b) compile (repo path) — see step 3
> # (c) copy the FRESH repo .ex5 to the exact load path the .ini's Expert= names
> cp -p /mnt/c/Trading/UltimateTrader/UltimateTrader.ex5 "$E/UltimateTrader_<phase>.ex5"
> # (d) ASSERT load-path md5 == fresh-build md5 — ABORT the phase if they differ
> FRESH=$(md5sum /mnt/c/Trading/UltimateTrader/UltimateTrader.ex5 | awk '{print $1}')
> LOAD=$(md5sum "$E/UltimateTrader_<phase>.ex5" | awk '{print $1}')
> [ "$FRESH" = "$LOAD" ] || { echo "STALE-BINARY ABORT: load=$LOAD != fresh=$FRESH"; exit 1; }
> # (e) record BOTH md5s in the phase log; the .ini Expert= MUST name UltimateTrader_<phase>.ex5 (never the bare UltimateTrader.ex5)
> ```
> Each A/B leg gets its OWN uniquely-named `_<phase>X.ex5` and its own md5 line in the log. NEVER reuse a `_pNN` filename across phases. If a clean-HEAD baseline run diverges from the recorded baseline, suspect a STALE BINARY FIRST (re-run 3b) — do NOT attribute to "data/state drift" without first proving load-path md5 == intended-source md5.
> Also: for a baseline-relative P&L claim, relocate `Common\Files\UltimateTrader_State*.bin/.bak` to start on clean recovery state (a stale state file is a real but SECONDARY confound; the binary md5 assertion is primary).

## 10. Artifacts / cleanup state
- Fresh build: repo `…/UltimateTrader.ex5` = `f1e251fa80917aa51dbc9488eaea48a2`; load copies `…/Experts/UltimateTrader.ex5` and `…/Experts/UltimateTrader_RB56.ex5` = same md5.
- Report: `…/725B…/RB56.htm` ($17,018.83/1.28/1742t). ini: `…/725B…/backtest_RB56.ini`.
- EA CSVs (this run): `Common/Files/UltTrader_{Stats,TradeEvents,Risk,Candidates}_XAUUSD+_20190101_0000.csv`.
- Reference binary preserved: `…/Experts/UltimateTrader_p55B.ex5` (`d04d76bb`) + `/tmp/rebaseline_keep/`.
- State files relocated to `/tmp/rebaseline_keep/state_backup/` (restore if a future run needs the prior live state). All stale `9dbe9052` and per-phase `.ex5` deleted.
- NOT committed (per directive). RESUME.md NOT edited (text above is for user integration).
