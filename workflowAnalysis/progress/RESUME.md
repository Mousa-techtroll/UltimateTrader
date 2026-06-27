# RESUME PROTOCOL — autonomous phase-by-phase bug-fix execution

A fresh Claude Code session (after credit-out / context loss) resumes here with **zero re-derivation**. Everything binding is in this file or in `00-STATUS.md`. Source of truth for fix detail: `workflowAnalysis/bug-fix-plan.md`.

---

## (a) Where am I? — find NEXT ACTION
1. Read `workflowAnalysis/progress/00-STATUS.md`. The top **⏭️ NEXT ACTION** line names the next `PENDING` phase.
2. If a phase is `IN-PROGRESS` or `IMPL-DONE` (interrupted mid-phase), resume THAT phase — re-read its phase log `progress/<iter>-<phase>.md` (if started) and the corresponding row in 00-STATUS.
3. If a phase is `QA-FAIL-LOOP` or `PARKED`, do NOT advance past it without resolving (see (d)).
4. Honor `depends_on`: never start a phase whose prerequisite phase is not `COMMITTED` (or `PARKED` with stok sign-off). The two HARD GATES in (e) block whole iterations.

---

## (b) Per-phase execution loop (the QA gate is the TWO AGENTS, not the user)
For the NEXT ACTION phase:

1. **Set status `IN-PROGRESS`** in 00-STATUS; create the phase log from `phase-log-TEMPLATE.md` as `progress/<iter>-<phase>.md`.
2. **Implement (mt5-developer).** Apply ONLY this phase's fix ids, touching only its listed files. **No logic cutting** — a disable is only ever a toggle/registration-level park with stok sign-off, never deleting trading logic. Use the binding stok option/param from (c) for every `touches_trading_logic=Y` fix. Verify each `file:line` against current source first (line numbers drift). Set `IMPL-DONE`.
3. **Compile to 0 errors — the proven gate (negative-control verified).**
   - Binaries (verify, don't trust stale scripts): MetaEditor at `C:\Program Files\Vantage Markets MT5 Terminal\MetaEditor64.exe`, terminal at `...\terminal64.exe`. Data dir user `nullkuhl`, terminal ID `725B72F25E46C780EF59F57016D58156`. Project compiles **in place** (relative includes).
   - Command (the CLI returns BEFORE the log flushes):
     ```
     cd /mnt/c/Trading/UltimateTrader
     rm -f mq5-build.log
     powershell.exe -Command "& 'C:\Program Files\Vantage Markets MT5 Terminal\MetaEditor64.exe' /compile:'C:\Trading\UltimateTrader\UltimateTrader.mq5' /log:'C:\Trading\UltimateTrader\mq5-build.log'" >/dev/null 2>&1
     ```
   - **Detect completion** (do NOT read a stale log): poll until the log exists AND contains a terminal `^Result:` line, then decode UTF-16LE:
     ```
     for i in $(seq 1 40); do
       if [ -f mq5-build.log ] && iconv -f UTF-16LE -t UTF-8 mq5-build.log 2>/dev/null | grep -q "^Result:"; then break; fi
       sleep 1
     done
     iconv -f UTF-16LE -t UTF-8 mq5-build.log | grep -E "^Result:|: error|: warning"
     ```
   - **Pass = 0 errors AND 0 NEW warnings** (baseline is **16** pre-existing warnings as of Phase 6.5 — was 38 through 6.4; Phase 6.5 removed 2 dead health-stack includes that were emitting 22 type-conversion warnings, so the gate is now 0-err / no-new-above-16; quote any delta). MQL **error 106 = include not found** — fix the relative include path / missing `#include`. If errors, fix and re-compile; stay `IMPL-DONE` until clean. Record the verbatim `Result:` line in the phase log.
   - Negative control is already proven live this project (a `#error` yields a non-zero count and deletes the `.ex5`); re-run it only if you suspect a stale gate.
3b. **BIND the binary to the load path (MANDATORY — prevents stale-binary runs).** *(Added after the Phase-5.6 incident: a 7-commit-stale `9dbe9052` binary was silently tested because the fresh repo-path compile never reached the data-dir load path and no md5 assertion gated the run; see `progress/REBASELINE-5-6.md`.)* The compiler writes `C:\Trading\UltimateTrader\UltimateTrader.ex5` (repo); the tester loads `Expert=` from the data-dir `…\Terminal\725B72F25E46C780EF59F57016D58156\MQL5\Experts\`. These are DIFFERENT files — reconcile by md5 EVERY run or a stale data-dir copy is silently tested.
   ```
   DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"; E="$DD/MQL5/Experts"
   rm -f "$E/UltimateTrader.ex5" "$E/UltimateTrader_<phase>.ex5"          # (a) delete data-dir load-path .ex5 BEFORE compiling
   # (b) compile (repo path) — step 3
   cp -p /mnt/c/Trading/UltimateTrader/UltimateTrader.ex5 "$E/UltimateTrader_<phase>.ex5"   # (c) copy FRESH build to the exact load path the .ini names
   FRESH=$(md5sum /mnt/c/Trading/UltimateTrader/UltimateTrader.ex5|awk '{print $1}'); LOAD=$(md5sum "$E/UltimateTrader_<phase>.ex5"|awk '{print $1}')
   [ "$FRESH" = "$LOAD" ] || { echo "STALE-BINARY ABORT: load=$LOAD != fresh=$FRESH"; exit 1; }   # (d) ASSERT — abort if differ
   # (e) record BOTH md5s in the phase log; the .ini Expert= MUST name UltimateTrader_<phase>.ex5 (NEVER the bare UltimateTrader.ex5)
   ```
   - Each A/B leg gets its OWN uniquely-named `_<phase>X.ex5` + its own md5 line in the log; NEVER reuse a `_pNN` filename across phases. The two legs MUST have DISTINCT md5s for a production-affecting fix (same md5 ⇒ you compiled/copied once and ran one binary twice ⇒ the A/B is vacuous).
   - **If a clean-HEAD baseline run diverges from the recorded baseline, suspect a STALE BINARY FIRST** (re-run 3b + assert load-path md5 == intended-source md5) — do NOT attribute to "data/state drift" without first proving the binary. For a baseline-relative P&L claim, also relocate `Common\Files\UltimateTrader_State*.bin/.bak` to start on clean recovery state (a stale state file is a real but SECONDARY confound; the binary md5 assertion is primary).
   - **Current binding baseline (post-6.9 = PLAN COMPLETE, HEAD <6.9 commit>): Net $20,085.56 / PF 1.32 / 928 positions (1742→ deals differ) / Eq-DD 13.02% / Sharpe 2.41.** Superseded the post-6.1 $17,455.34 after Phase 6.9's PBC closed-bar ATR de-repaint (forming-ATR was manufacturing a PBC loss PF 0.635→1.110, +14 positions) + cleaner Crash gate (+7). (Prior anchors: post-6.1 $17,455.34/Stats `3b13ea8f…`/TradeEvents `2222e2f9…`/Candidates `77b07fb1…`/Risk `930cce92…`; post-5.9 $17,455.34; post-5.5 $17,018.83.) A fresh compile of committed HEAD MUST reproduce the post-6.9 figures. (NOTE: the 3 TRADE CSVs — Stats/TradeEvents/Candidates — have held since 5.9; only the Risk CSV md5 shifted at 6.1 from `c152fb4a…`→`930cce92…` because 6.1's retcode classifier changed 13 EXECUTION_FAILED MARKET_CLOSED *diagnostic* rows for never-executed weekend-gap orders — zero trade/P&L impact. Headline + the 3 trade CSVs are the primary baseline; the Risk CSV carries live-only diagnostic deltas.) (History: post-5.5 ed488df was $17,018.83/Eq-DD 12.89%/Stats `08640614…`; 5.8+5.9's closed-bar H4 pivot added +$436.51 on 4 TP-target flips. If a fresh HEAD yields $25,570.97/2011t you are running the stale pre-4.6 `9dbe9052` binary — re-run 3b.) The baseline shifts each production-affecting phase; the invariant is "A reproduces the CURRENT committed HEAD," verified via the 3b md5 assertion.
4. **Targeted / A-B backtest + decode (per the phase's QA criteria).**
   - Use `backtest_symbol.sh XAUUSD <year>` (point its terminal path at the Vantage path above if its hardcoded one fails). Decode the UTF-16LE stats CSV in `Logs/` with `iconv`. Report **actual** numbers — PF, avg-R, net, trade count, max DD — never estimate.
   - For `touches_logic=N` / "no-op on production path" claims: the A/B MUST be **trade-for-trade, SL-for-SL, R-for-R IDENTICAL** on the XAUUSD-only H1 production config. Not identical ⇒ the no-op claim is wrong ⇒ reconcile before merge.
   - For Iteration 3 phases (3.7–3.10): FRESH full 2019–2026 per engine (`InpEnableMultiStrategy=true` + only that `InpEnableEngine*`), plus the 2024–2026 OOS slice, plus per-sub-path marginal contribution. Sweep `InpBOSFreshnessBars {4,6,8,12}` and pick by avg-R.
5. **stok reviews trading impact / A-B numbers / kill criteria.** Hand stok the decoded before/after numbers and the phase's specific stok call-out (from 00-STATUS Notes + the plan). stok confirms the delta is explained by the fix's mechanism and no kill-criterion tripped.
6. **BOTH agents sign off in the phase log** (mt5-developer: compile clean + mechanism correct; stok: trading impact acceptable + kill criteria clear). This two-agent sign-off **IS the QA gate** — do not wait for the user. Set `QA-PASS`.
7. **Commit — separately-measurable.** One phase = one commit so each delta vs the v18 baseline is attributable. Record the commit hash in 00-STATUS (`Commit` column) and the phase log. Set `COMMITTED`.
   - Commit message ends with the Co-Authored-By trailer. Commit ONLY when the loop reaches here (never on a dirty/failing gate).
8. **Advance NEXT ACTION** in 00-STATUS to the next `PENDING` phase (respecting depends_on + hard gates).

---

## (c) Binding stok parameter register (copied from the plan's risk register §6 — these are binding defaults)
| Param | Value | Note |
|---|---|---|
| `SMC_SWEEP_RECENCY_BARS` | **3** | ≤5; longer re-creates stale-latch (1.1) |
| `InpBOSFreshnessBars` | **8** | floor 6 / cap 18; sweep {4,6,8,12} by avg-R per engine (2.2) |
| `InpSpineMinConfluence` | **25** | 0–100; below SMC hard-reject floor 40 (2.3) |
| `InpDealingRangeD1Lookback` | **20** | closed D1 bars (ICT IPDA) (2.4) |
| Tier thresholds `InpPoints*` | **RE-DERIVE** | do NOT carry v18 forward; A+ = top decile expectancy (2.4-GATE) |
| `InpNewsWindowMinutes` | **15** | HIGH-impact USD+XAU only (FOMC/CPI/NFP/PPI/PCE); `InpEnableNewsFlat=true` (3.2) |
| `InpTrendSwingLookback` | **10** | NOT 20 (20 → oversized stop) (3.5) |
| HTF short veto (3.6) | **hard-ON** | no disable input for production |
| `InpMinSessionRiskFactor` | **0.25** | floor on combined session reducers (5.5) |
| Crash `min_rr` | **1.0** | guardrail NOT lever; ≥~1.33 amputates the only profitable short (6.9 Entry-Crash-1) |
| RangeBox `min_rr` | **1.0** | validate before exceeding (6.9 Entry-Candles-6) |
| PBC kill-criterion | **PF<1.0 or avg-R<0** | over 2019–2026 → disable PBC + reconcile STRATEGIES.md (6.9 Entry-Pullback-1) |
| Per-engine kill (Iter 3) | **PF<1.0 OR avg-R<0** | full window AND 2024–26 OOS → sub-path stays OFF |
| `InpMaxTradesPerDay` | **5** | intended SHARED budget (pattern+file) in BOTH mode (4.5) |

---

## (d) Kill-criteria + loop-back-to-stok rule
After every phase QA:
1. Decode actual numbers (never estimate).
2. Evaluate against the phase's pass/fail (kill) criteria (00-STATUS Notes + plan).
3. **If a fix regresses** (unexplained divergence, a no-op claim fails byte-identity, a runtime error) **OR a trading-logic change underperforms** (worse net/maxDD without a mechanism, or a kill-criterion trips):
   - Set the phase `QA-FAIL-LOOP`. Record the decoded before/after in the phase log.
   - **Loop back to stok** with those numbers; stok re-validates and, if needed, supplies a revised binding option (e.g. a different `SMC_SWEEP_RECENCY_BARS` / `InpBOSFreshnessBars` / `InpSpineMinConfluence` / `InpMinSessionRiskFactor` / re-derived tier thresholds).
   - **Do NOT advance** to the next phase/iteration until the regressed phase is reconciled (re-run the loop) or explicitly `PARKED` (toggle/registration-level disable only, with stok sign-off — never a logic cut).
4. **Iteration 3 special loop:** each engine/sub-path that trips the kill-criterion stays OFF and is handed to stok with its fresh decoded PF/avg-R. NOT re-judged on old findings, NOT force-enabled to chase trade count.
5. **Disagreement resolution:** re-read the cited source — the repo wins. No claim survives on assertion.

---

## (e) The two HARD GATES (block whole iterations) + prerequisites
1. **Tier-threshold re-derivation (between Iter 2 and Iter 3).** Phase `2.4-GATE` MUST be `COMMITTED` (re-derived `InpPoints*` on the new post-2.4/2.2/2.3 score distribution, stok-signed) **before any Iter 3 phase starts.** Iter 3 engine sizing is invalid on a re-scaled distribution otherwise. Prereq phases: 2.2, 2.3, 2.4 committed first.
2. **CSessionEngine GMT-clock extraction + MQL5-calendar reliability (before the news-flat work in Phase 3.6, and before the B4 SessionClock helper in 6.9).** `CRegimeRouter` DAY_DATA wiring (3.2) and `GetEAGMTHour()` assume a reliable GMT clock; **CSessionEngine is currently the de-facto GMT clock used live across ~7 files** (deletion was deferred for exactly this reason). Before Phase 3.6:
   - Extract the GMT-hour utility into a standalone source (so it is not coupled to a retired engine), repoint the ~7 callers, prove the on-default clock returns **identical** values pre/post.
   - Verify MQL5 `CalendarValueHistory` availability **in the Strategy Tester** (print a calendar-count on init). It is unreliable/empty in many terminals — `IsDataDay()` MUST fall back to a configurable static blackout list and never throw.
   - If the calendar is unavailable in the tester, ship 3.6 on the static-list fallback and note it; do not block the rest of Iter 3 on a flaky calendar.

Other ordering prerequisites (depends_on / bundling — enforced in 00-STATUS):
- Iter 1 closed-bar BOS (1.2) lands the closed-bar reads that 2.2 spine freshness builds on — verify 1.2 committed before 2.2 commits.
- Trailing cluster Phase 4.7: apply 4.8 → 4.9 → 4.10 IN ORDER within the phase (4.9/4.10 use 4.8's new_sl).
- Phase 5.1 (symbol-match recovery) lands FIRST in Iter 5 (shrinks trail-fix blast radius) before 5.2.
- Phase 6.2 lands AFTER 4.6 (both edit ValidateExecutedVolume).
- Phase 6.8 (doc) sequenced AFTER 4.4 (the file-signal trade-count line changes once CanTrade gates the file path).
- Iter 1 / Iter 2 / Iter 3 short-side coupled fixes (1.7=fix1.8, 2.5, 2.2/2.3, 3.2=fix3.4, 3.5=fix3.6): the HTF short veto (3.5) ships and stays ON before any short path is judged.

---

## Working rules (always)
- Absolute paths only; shell cwd resets between Bash calls.
- Decode UTF-16LE logs/CSVs with `iconv -f UTF-16LE -t UTF-8` before reading — raw looks like garbage.
- Do NOT touch bulk data dirs (`GoldHistory/`, `Logs/`, `Reports/`, `claude/`, `codex/`, `graphify-out/`) or the `.ex5` as source.
- Commit/branch only as the workflow dictates here; the six prior session fixes + the multi-strategy scaffold (A–D) are already in the working tree — preserve them.
