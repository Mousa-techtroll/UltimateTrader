# Forensic Gate Report — configuration & identity reconciliation

Three-run forensic on ONE shared read-only, hashed tick dataset (identical terminal build, tester settings, symbol spec). Trade-by-trade comparison via per-trade Stats + TradeEvents CSVs (not merely net/count/Sharpe).

## Runs
| run | binary | md5 | config | Stats-CSV md5 | TradeEvents md5 | positions |
|---|---|---|---|---|---|---|
| REL | frozen release | 7a10211e | risk_R90.ini (cebf9578) | `96415ff0` | `9c08bcfa` | 865 |
| ARC | current HEAD | a71b3ce0 | risk_R90.ini (cebf9578) | `96415ff0` | `9c08bcfa` | 865 |
| REC | current HEAD | a71b3ce0 | current-canonical 414-pin | `96415ff0` | `9c08bcfa` | 865 |

**REL == ARC == REC — byte-identical trade ledgers (0 differing rows of 1731).**

## Gate conditions
1. Release vs current binary trade-identical — **PASS — REL(7a10211e) == ARC(a71b3ce0) trade-identical: Stats md5 96415ff0, TradeEvents md5 9c08bcfa, 0 differing rows**
2. Historical vs 414-pin config trade-identical — **PASS — REC(414-pin) == ARC(risk_R90.ini) trade-identical: same md5s, 0 differing rows**
3. Audit vs production binary trade-identical — **PASS — PRODB==AUDITB==96415ff0; production emits 0 [EffCfg]**
4. Every classification dimension reconciles to 414 — **PASS — 8/8 dimensions total 414**
5. Manifest identifies exact binary/set/source/data/tester hashes — **PASS — binary/set/source/data/tester hashes recorded (this file)**

## The $12.70 (evidence, not assertion)
NOT tick-backfill-by-assertion: REL==ARC==REC byte-identical (not binary/config/source); 2026.hcc is the SOLE tick file modified after the release (2026-07-17 vs 2026-06-26 freeze on 2019-2025) → the delta is the broker's 2026 current-year tick revision. Release-era 2026 ticks were overwritten (literal trade-diff vs release impossible); tick_data_sha256 pins the set going forward.

Tick mtimes: 2017–2025.hcc frozen **2026-06-26**; **2026.hcc modified 2026-07-17** (sole post-release change). Release measured 2026-07-13. Same release binary on current ticks now yields the current-tick result (REL==ARC), so the $12.70 is isolated to the 2026 current-year tick revision. `tick_data_sha256 ffebf6f8…` pins the dataset going forward.

## 56-pin verification
- all 56 previously-unpinned inputs: runtime-loaded value == compiled default, verified (not assumed); current-canonical.set now sources them from runtime, not declarations

## Reachability call-counters (AUDIT_BUILD)
- CSetupEvaluator tier returns A+/A/B+/B/NONE = **924/483/232/0/358** → **SETUP_B UNREACHABLE** (0 scorer returns).
- CVolatilityBreakoutEntry checked/compat/emitted = **42161/5186/0** → **HISTORICALLY-INACTIVE** (VOLATILE occurred 5186×, engine called, 0 emissions — the breakout trigger never fires; not unreachable-by-regime).

## Cleanup gate
**ALL 5 CONDITIONS PASS → gate OPEN.** Cleanup may proceed one subcategory at a time with per-change identity re-test.
