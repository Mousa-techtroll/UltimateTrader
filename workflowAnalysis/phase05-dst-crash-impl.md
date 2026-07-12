# Phase-0.5 — DST-1 offset fix + crash-window cleanup (implementation record)

**Scope:** two correctness changes in ONE new binary. Compiled 0 errors / 0 warnings; deployed as
`UltimateTrader_DST.ex5`. **No backtest was run** (reserved for the identity/audit legs the owner drives).

- **CHANGE 1 (DST-1):** one authoritative US-DST broker-offset resolver, gated behind a new
  `input bool InpTesterDSTFix = true`. Behavior-changing in the **tester winter** half-year when ON;
  reproduces the frozen baseline exactly when OFF. **LIVE path untouched.**
- **CHANGE 2 (crash-window cleanup, Option A):** removed the dead `m_start_hour`/`m_end_hour` window
  members + their two orphaned inputs. Behavior-neutral (never-read code).

Baseline anchor: `$23,856.89` / 2053 trades / 952 positions on `risk_R90.ini`
(`InpCrashTrailSuppress=true`, `InpRRGateSymmetric=true`). Frozen control = `UltimateTrader_FREEZE.ex5`
(md5 `da12cf88…`, untouched).

---

## Compile / deploy

| Item | Value |
|---|---|
| Compiler | `C:\Program Files\Vantage Markets MT5 Terminal\MetaEditor64.exe` |
| Source compiled | `C:\Trading\UltimateTrader\UltimateTrader.mq5` (working tree, in place) |
| Result | **0 errors, 0 warnings** (9845 ms) |
| Deployed binary | `…\Terminal\725B72F25E46C780EF59F57016D58156\MQL5\Experts\UltimateTrader_DST.ex5` |
| DST md5 | `405854d8ddc37de15f0ef67f2f7716ea` (== freshly-compiled working-tree `UltimateTrader.ex5`) |
| FREEZE md5 | `da12cf88cb6aebeac14b5e0b06107aa6` (unchanged — not overwritten) |

`UltimateTrader.ex5` in the working tree was recompiled (expected). `UltimateTrader_FREEZE.ex5` and all
other named copies in the Experts dir are untouched.

---

## Files touched (8)

1. **NEW** `Include/Utils/CTimeOffset.mqh` — the single authoritative resolver.
2. `Include/MarketAnalysis/CNewsGate.mqh` — `IsUsDst()` now forwards to `CTimeOffset`; dead `NthSundayUtc` removed.
3. `Include/EntryPlugins/CSessionEngine.mqh` — DST-1 fix (member + Initialize + `GetGMTHour` + `GetGMTOffset`).
4. `Include/MarketAnalysis/CMarketContext.mqh` — DST-1 fix (member + `ResolveGMTOffset` + `GMTHourOf`).
5. `Include/EntryPlugins/CFileEntry.mqh` — `GetEETOffset()` EU-DST → shared US-DST (BUG-2), gated.
6. `Include/EntryPlugins/CCrashBreakoutEntry.mqh` — CHANGE 2: dead window members/params removed.
7. `UltimateTrader.mq5` — added `CTimeOffset` include; dropped the two orphaned crash ctor args.
8. `UltimateTrader_Inputs.mqh` — new `InpTesterDSTFix` group; removed `InpCrashStartHour`/`InpCrashEndHour`.

---

## Flag semantics — `InpTesterDSTFix` (default TRUE = corrected)

- **TRUE (default, corrected):** in the **Strategy Tester fallback path only** (where
  `TimeCurrent()-TimeGMT()==0`), `CSessionEngine`, `CMarketContext::ResolveGMTOffset`/`GMTHourOf`, and
  `CFileEntry::GetEETOffset` resolve the broker GMT offset **per-timestamp** on the **US-DST** calendar
  via `CTimeOffset::BrokerGMTOffset` → **+2 winter / +3 summer**.
- **FALSE (legacy):** every one of those sites falls back to the pre-existing behavior — fixed
  `InpBrokerGMTOffset=3` (summer, no DST) for the two session clocks, and the EU-DST calendar for
  `CFileEntry` — so the binary **reproduces the frozen `$23,856.89` baseline exactly**.
- The flag **only** gates the tester offset computation. It never enters the **LIVE** branch (see below).

**LIVE path is untouched (explicit).** The live branch `offset = (TimeCurrent()-TimeGMT())/3600` runs
before any flag check. In live trading the offset is non-zero, so the tester-fallback block is never
entered, `m_tester_dst_fix` stays `false`, and `GetGMTHour`/`GetGMTOffset`/`GMTHourOf` return the frozen
auto-detected `m_gmt_offset` byte-for-byte as before. `InpTesterDSTFix` has **zero effect live**.

**Single source of truth.** `CTimeOffset::IsUsDst()` / `NthSundayUtc()` are lifted **verbatim** from the
anchor-validated `CNewsGate` model (2nd-Sun-Mar 07:00 UTC → 1st-Sun-Nov 06:00 UTC; NFP/CPI/FOMC anchors
PASS at 97.51%). `CNewsGate::IsUsDst()` now forwards to `CTimeOffset`, so there is exactly one copy of
the boundary math. `CNewsGate::ModelOffsetHours` is unchanged, so the news gate's behavior is preserved.

---

## Which session boundaries shift, and in which direction (fix ON)

Only the **US-winter** half-year (~early-Nov → mid-Mar) shifts. **Summer is unchanged** (offset is +3
under both legacy and fix during US DST).

In winter the effective offset drops **3 → 2**. Since `GetGMTHour(bar) = server_hour − offset`, the
**computed GMT hour for a given bar rises by +1** (the clock is corrected forward to true GMT). Equivalently,
every `gmt_hour >= X` session-open test flips true **one server-bar sooner**, so each GMT-keyed window
**activates 1 hour EARLIER in server/wall-clock time** (and closes 1 hour earlier). This *un-does* the bug,
where the fixed +3 made sessions run **1 hour late** all winter.

Winter server-time boundary shift (each edge −1h):

| GMT-keyed window | GMT bounds | Legacy server (offset 3) | Fixed server (offset 2) |
|---|---|---|---|
| Session-risk **London** ×0.50 | [8,13) | [11,16) | **[10,15)** |
| Session-risk **NY** ×0.90 | [13,21) | [16,24) | **[15,23)** |
| Asian range build | [0,7) | [3,10) | **[2,9)** |
| Session-engine London BO | [8,10) | [11,13) | **[10,12)** |
| Session-engine NY continuation | [13,14) | [16,17) | **[15,16)** |
| Session-engine Silver Bullet | [15,16) | [18,19) | **[17,18)** |
| Session-engine London Close | [16,17) | [19,20) | **[18,19)** |
| Asia validator (IsAsiaSession) | ≥23 ‖ <8 | server ≥2 ‖ <11 | **≥1 ‖ <10** |

**On the config of record**, the only *materially-active* winter consumer is the **session-risk multiplier**
(London ×0.50 / NY ×0.90, `UltimateTrader.mq5:2383-2399`, reads `g_sessionEngine.GetGMTHour(TimeCurrent())`).
The session-engine entry phases are OFF (`InpSessionLondonBO/NYCont/SilverBullet/LondonClose=false`); skip-hours
and session gates sit at DST-agnostic defaults; and `CMarketContext::GMTHourOf` (news-flat) is gated behind
`InpEnableMultiStrategy` (constant-false on prod). So the flag-on winter delta on prod flows through the
session-risk multiplier timing (e.g. a true-13:00-GMT NY bar at server 15:00 now correctly gets ×0.90 instead
of the ×0.50 London penalty the buggy run applied).

`GetGMTOffset()` (consumed by `IsAsiaSession`/`IsSessionAllowed` in Utils.mqh, and the skip-hours check) also
returns the per-timestamp offset when the fix is armed — resolved at `TimeCurrent()`, which is the same instant
those helpers evaluate, so they stay consistent. On prod all sessions are allowed and skip zones are disabled,
so this is offset-independent there; the change matters only if a restrictive session/skip filter is enabled.

---

## Per-site before → after

### NEW `Include/Utils/CTimeOffset.mqh`
Self-contained static helper, no Inp dependency, include-guarded.
- `IsUsDst(datetime utc_time)` — verbatim from `CNewsGate` (2nd-Sun-Mar 07:00 UTC → 1st-Sun-Nov 06:00 UTC).
- `NthSundayUtc(int,int,int)` — verbatim from `CNewsGate` (private).
- `BrokerGMTOffset(datetime server_time)` — **NEW**: `utc_guess = server_time − 2h` (two-pass, mirrors
  `CNewsGate::ServerToUtc`), then `IsUsDst(utc_guess) ? 3 : 2`. Winter=+2 / summer=+3 by definition.

### `CNewsGate.mqh`
- Added `#include "../Utils/CTimeOffset.mqh"`.
- `IsUsDst()` body (2nd-Sun-Mar / 1st-Sun-Nov math) → `return CTimeOffset::IsUsDst(utc_time);` (public API preserved
  for `ExportNewsCalendar.mq5` + `ModelOffsetHours`).
- Private `NthSundayUtc()` **removed** (it lived only inside `IsUsDst`; single source now in `CTimeOffset`).
- **Behavior preserved** (byte-identical DST math; `ModelOffsetHours` untouched).

### `CSessionEngine.mqh`
- Added `#include "../Utils/CTimeOffset.mqh"`; new member `bool m_tester_dst_fix` (init `false` in ctor).
- `Initialize()` tester fallback: `if(InpTesterDSTFix){ m_tester_dst_fix=true; m_gmt_offset=CTimeOffset::BrokerGMTOffset(TimeCurrent()); }`
  (seed for log only) `else { m_gmt_offset = InpBrokerGMTOffset; }` (LEGACY fixed +3).
- `GetGMTHour(server_time)`: `offset = m_tester_dst_fix ? CTimeOffset::BrokerGMTOffset(server_time) : m_gmt_offset;`
- `GetGMTOffset()`: `return m_tester_dst_fix ? CTimeOffset::BrokerGMTOffset(TimeCurrent()) : m_gmt_offset;`
- Flag-off / live → `m_tester_dst_fix==false` → both return the frozen `m_gmt_offset` (EXACT legacy).

### `CMarketContext.mqh`
- Added `#include "../Utils/CTimeOffset.mqh"`; new member `bool m_tester_dst_fix` (init `false`).
- `ResolveGMTOffset()` tester branch: same `InpTesterDSTFix` split as the session engine.
- `GMTHourOf(server_time)`: `offset = m_tester_dst_fix ? CTimeOffset::BrokerGMTOffset(server_time) : m_gmt_offset;`
- News-flat path is gated behind `InpEnableMultiStrategy` (false on prod) → byte-identical on prod regardless.

### `CFileEntry.mqh` (BUG-2)
- Added `#include "../Utils/CTimeOffset.mqh"`.
- `GetEETOffset(dt)`: `if(InpTesterDSTFix) return CTimeOffset::BrokerGMTOffset(dt);` (US-DST) else the **unchanged
  legacy EU-DST** calendar (last-Sun-Mar → +3, last-Sun-Oct → +2). Inert on the config of record (no
  `telegram_signals.csv` is loaded → converter never called); unified anyway.

### `CCrashBreakoutEntry.mqh` (CHANGE 2 — behavior-neutral)
- Removed members `int m_start_hour;` / `int m_end_hour;`.
- Removed ctor params `int start_hour = 13, int end_hour = 17,`.
- Removed ctor assignments `m_start_hour = start_hour; m_end_hour = end_hour;`.
- Updated class header comment → "Fires all hours (NO time-of-day gate)…"; updated the dead-member banner
  (7 → 5 members). No live logic path changed — these members were write-only, never read in
  `CheckForEntrySignal()` (grep-confirmed).

### `UltimateTrader.mq5`
- Added `#include "Include/Utils/CTimeOffset.mqh"` in the Common section (after `Common/Utils.mqh`).
- Crash ctor call: dropped `InpCrashStartHour, InpCrashEndHour,` — remaining positional args still map to
  `donchian_period, tp_extension, regime_gate` correctly. The other call site
  (`CReversalSweepEngine.mqh:304`, `new CCrashBreakoutEntry(m_context)`) uses defaults → unaffected.

### `UltimateTrader_Inputs.mqh`
- **Added** `input group "══════ DST / TIMEZONE CORRECTION ══════"` + `input bool InpTesterDSTFix = true;`.
- **Removed** `input int InpCrashStartHour = 13;` and `input int InpCrashEndHour = 17;`; updated the dead
  sub-group banner (7 → 5 inputs). Both were referenced **only** at the Inputs definition and the one crash
  ctor call (grep-confirmed), and fed a never-read member → removal is behavior-neutral. `risk_R90.ini` does
  not contain either key (checked), so no config load is affected; MT5 ignores unknown keys regardless.

---

## Behavior-neutrality of CHANGE 2 (crash window)

`m_start_hour`/`m_end_hour` were assigned in the ctor and **never read** anywhere in the class
(`CheckForEntrySignal()` applies no time-of-day gate — the crash engine already fired every hour). Removing
the members, ctor params, ctor assignments, and the two `InpCrash{Start,End}Hour` inputs is therefore
**exactly behavior-preserving**: no live logic path is touched, and the dropped input values never influenced
any computation. This is identity-neutral by construction; the owner selected Option A (all-hours firing is
intended).

---

## What the owner runs next (NOT run here)
- **Flag-OFF identity leg:** `InpTesterDSTFix=false` → expect **$23,856.89 / 952** (frozen-baseline reproduction).
- **Flag-ON corrected leg:** `InpTesterDSTFix=true` (default) → the winter session-risk-multiplier timing moves
  as tabled above; magnitude is the audit's to measure.
