# Phase 0.5 — Correctness-Debt Closeout (DST-1 + census + manual)

**Date:** 2026-07-12. Closes the correctness debt surfaced by Phase 0 before any Phase-1 performance experiment. The one materially result-changing item — the tester DST/session clock — was handled as **correctness fix DST-1** (control + corrected legs, audited, adopted), not an ordinary experiment.

## New binding baseline (ADOPTED)

| Metric | Old (buggy DST) | **New (DST-corrected)** | Δ |
|---|---|---|---|
| Net profit (report) | $23,856.89 | **$24,829.05** | +$972.16 (+4.1%) |
| Profit factor | 1.31 | **1.32** | +0.01 |
| Sharpe | 2.21 | **2.26** | +0.05 |
| Equity DD | 13.14% | **13.35%** | +0.21pp |
| Positions | 952 | **950** | −2 |
| CSV-basis net | $24,378.11 | $25,349.52 | +$971.41 |

**Frozen reference:** binary `UltimateTrader_FREEZE_DST.ex5` (md5 `405854d8ddc37de15f0ef67f2f7716ea`) · config `risk_R90.ini` (md5 `9aad2b3e…`, now carries `InpTesterDSTFix=true`) · archive `_arm_archive/freeze_DST/` (950 positions). Reproduce: `identity_run.sh UltimateTrader_FREEZE_DST.ex5 <tag>` (pins `InpTesterDSTFix=true`). The old $23,856.89/952 baseline is superseded.

## Closeout checklist

| Item | Status |
|---|---|
| 1. Fix tester DST/session clock (DST-1) | ✅ Adopted — new baseline $24,829.05 |
| 2. Unify timezone models (one resolver) | ✅ `Include/Utils/CTimeOffset.mqh` — session engine, market context, file entry, news gate all route through it |
| 3. Correct file-entry EU/US DST (BUG-2) | ✅ `CFileEntry::GetEETOffset()` → shared US-DST (inert on config of record; no telegram CSV) |
| 4. Crash time-window decision | ✅ **Option A** — all-day is intended; dead `m_start_hour/m_end_hour` + `InpCrashStartHour/EndHour` removed; behavior-neutral (flag-off leg = $23,856.89/952) |
| 5. Regenerate census on frozen archive | ✅ `entry-strategies-census.md` on the corrected 950 baseline; old 928 census banner-flagged superseded |
| 6. Correct manual runner % + implicit BE | ✅ `06-exits.html` — runner ≈40% of original (full ladder), reach-rates 61/37/16%, BE now correctly implicit |
| 7. Re-freeze corrected baseline | ✅ this document + frozen binary + config pin + archive |

## DST-1 fix — what changed

- **One authoritative resolver** `CTimeOffset::BrokerGMTOffset(server_time)` → +3 during US DST (2nd-Sun-Mar 02:00 → 1st-Sun-Nov 02:00), +2 otherwise. `IsUsDst()` lifted verbatim from the anchor-validated `CNewsGate` model, which now also routes through the shared helper.
- **Tester only.** In the Strategy Tester (`MQLInfoInteger(MQL_TESTER)`), `CSessionEngine` and `CMarketContext::ResolveGMTOffset()` compute the offset per-timestamp instead of the fixed +3. **The LIVE auto-detected path (`TimeCurrent()−TimeGMT()`) is untouched.**
- **Gated** behind `input bool InpTesterDSTFix = true` (new group). `false` = legacy fixed +3 / EU-DST → reproduces the old baseline exactly (used for the control leg).
- **Sign:** only US-winter shifts (offset 3→2), so the computed GMT hour for a winter bar is +1 → every GMT-keyed session window (London/NY risk multiplier, session phases, Asia validator) activates **1 hour earlier in server time**, correcting the "sessions run 1h late all winter" bug.

## Two-leg proof

- **Control (flag off):** `$23,856.89 / 952` — bit-exact to the frozen baseline ⇒ crash cleanup + rename are behavior-neutral and the legacy path is intact.
- **Corrected (flag on):** `$24,829.05 / 950` — adopted. Full comparison in `phase05-dst-audit.md`; implementation diff in `phase05-dst-crash-impl.md`.

## Remaining consistency item (not blocking Phase 1)

The book appendix `ea-book/backtest.html` still cites the pre-DST $23,856.89 / 952 figures throughout its per-year/per-strategy tables. Refreshing it to the corrected $24,829.05 / 950 baseline is a documentation task (deltas are small and structural conclusions unchanged) — flagged for a follow-up pass.
