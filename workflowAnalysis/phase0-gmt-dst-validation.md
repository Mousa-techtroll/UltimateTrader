# Phase-0 Validation — Timezone / DST / Session-Window Handling

Scope: static source + CSV analysis, READ-ONLY. XAUUSD H1. No backtests run.
Date: 2026-07-12. Config-of-record assumptions from the production `.set` (session-engine
entry modes OFF; Friday cutoff = full ban; all sessions allowed).

Verdict (one line): **CORRECT-WITH-CAVEAT.** The news/calendar timezone model is correct and
US-DST-accurate (anchors PASS). The *session clock* is DST-blind in the Strategy Tester
(fixed GMT+3, no DST) → a persistent **1-hour "sessions run late" misalignment every winter
half-year** in backtests. It is contained on the production config (session-engine entries
disabled; offset-sensitive gates sit at DST-agnostic defaults) and absent in live trading
(offset auto-detected). Plus one off-by-one **EU-vs-US DST mismatch** in the file-signal path.

---

## 1. The timezone / DST model as implemented

There are **THREE different broker-offset models** in the codebase. They agree in *live*
trading (all auto-detect) but diverge in the *tester*.

### Model A — Session clock (the one the whole EA reads for GMT hours)
`CSessionEngine::Initialize()` — `Include/EntryPlugins/CSessionEngine.mqh:305-334`
`CMarketContext::ResolveGMTOffset()` — `Include/MarketAnalysis/CMarketContext.mqh:1037-1052`

```
offset = (TimeCurrent() - TimeGMT()) / 3600;      // live: real, DST-tracking
if(offset == 0 && MQL_TESTER) offset = InpBrokerGMTOffset;   // tester fallback
```

- **Live:** auto-detected from the terminal; tracks broker DST correctly.
- **Tester:** `TimeGMT()==TimeCurrent()` (offset resolves to 0, per the code's own comment
  at :308-309) → falls back to **`InpBrokerGMTOffset = 3`** (`UltimateTrader_Inputs.mqh:95`),
  a **fixed constant with NO DST logic**. Set once in `Initialize()`, never recomputed
  (`GetGMTHour()`, :460-468, uses the frozen `m_gmt_offset`).
- `InpBrokerGMTOffset=3` is explicitly the **SUMMER** value (comments at `:95` and `:599`).
  So in the tester the session clock is correct in US-summer and **1 hour off all winter**.

### Model B — News gate (matches the CSV) — CORRECT
`CNewsGate` — `Include/MarketAnalysis/CNewsGate.mqh`
- DST calendar `IsUsDst()` (:163-177): **US rules** — starts 2nd Sunday March 07:00 UTC,
  ends 1st Sunday November 06:00 UTC.
- `ModelOffsetHours()` (:182-188): `InpNewsWinterGMTOffset (=2) + 1 during US DST`
  (`InpNewsServerFollowsUSDST = true`, `_Inputs.mqh:599-600`). → **+2 winter / +3 summer, US-DST.**
- Live path (:99-128) auto-detects and even **warns** if the live offset disagrees with this
  model. There is **no equivalent cross-check for the session engine.**

### Model C — File-signal entry (EU-DST) — off vs Model B on transition weeks
`CFileEntry::GetEETOffset()` — `Include/EntryPlugins/CFileEntry.mqh:83-129`, used at :470-471
- **EU rules**: last Sunday March → +3, last Sunday October → +2. This is a *different DST
  calendar* than the US one the broker data actually follows (see §3).

**Design intent (per code comments): the broker is +2 winter / +3 summer, US-DST-aligned.**
Model B implements that faithfully; Model A drops the DST term in the tester; Model C uses the
wrong (EU) DST calendar.

---

## 2. Session-window definitions (exact GMT bounds)

All bounds are `[start, end)` in **GMT hours**, converted from server time via
`GetGMTHour(t) = server_hour − m_gmt_offset (mod 24)` (CSessionEngine.mqh:460-468).

| Window | GMT bounds | Source (file:line) |
|---|---|---|
| Asian **range build** | 00:00–07:00 (`hour∈[0,7)`) | CSessionEngine ctor `asian_start=0,asian_end=7` (:85, :389) |
| London Breakout mode | 08:00–10:00 (`[8,10)`) | `london_start=8, london_end=london_open+2` (:93-94, :403) |
| NY Continuation mode | 13:00–14:00 (`[13,14)`) | `ny_start=13, ny_end=ny_open+1` (:95-96, :416) |
| Silver Bullet mode | 15:00–16:00 (`[15,16)`) | `sb_start=15,sb_end=16` (:97-98, :429) |
| London Close mode | 16:00–17:00 (`[16,17)`) | `lc_start=16,lc_end=17` (:99-100, :442) |
| **Session RISK mult** London ×0.50 | 08:00–13:00 (`[8,13)`) | `UltimateTrader.mq5:2390-2394`; `InpLondonRiskMultiplier=0.50` (`_Inputs.mqh:504`) |
| **Session RISK mult** NY ×0.90 | 13:00–21:00 (`[13,21)`) | `UltimateTrader.mq5:2395-2399`; `InpNewYorkRiskMultiplier=0.90` (`_Inputs.mqh:505`) |
| **Session RISK mult** Asia ×1.0 | else (21:00–08:00) | implicit default `session_mult=1.0` (`UltimateTrader.mq5:2388`) |
| Session **gate** Asia | 23:00–08:00 (`h≥23 \|\| h<8`) | `IsAsiaSession` `Utils.mqh:118-127` |
| Session **gate** London | 08:00–16:00 (`[8,16)`) | `IsLondonSession` `Utils.mqh:129-138` |
| Session **gate** NY | 13:00–21:00 (`[13,21)`) | `IsNewYorkSession` `Utils.mqh:140-149` |
| `GetCurrentSession()` string (telemetry, uses raw `TimeGMT()`, no offset) | Asia 23–08 / London 08–16 / NY 13–21 | `Utils.mqh:51-68` |

Notes:
- Chapter-5 multipliers confirmed: **London ×0.50, NY ×0.90, Asia ×1.0** (`_Inputs.mqh:504-505`).
- The RISK-mult London/NY boundaries (8–13 / 13–21) differ slightly from the session-GATE
  boundaries (8–16 / 13–21) — a deliberate design split, not a bug.
- `GetCurrentSession()` in Utils.mqh reads `TimeGMT()` **without** the broker offset; it is
  cosmetic/telemetry only (no decision consumes it), so its tester value is unreliable but
  harmless.

**Asian range build window (§3 of task): GMT 00:00–06:59** (`[0,7)`), CSessionEngine.mqh:389.

**Friday cutoff (§4 of task):** `UltimateTrader.mq5:1951-1957`
`friday_entry_blocked = (day_of_week==5) && (GetGMTHour(now) >= InpFridayEntryCutoffGMT)`.
Default `InpFridayEntryCutoffGMT = 0` (`_Inputs.mqh:317`) ⇒ **full Friday entry ban** — and
since `hour≥0` is always true, the GMT offset is irrelevant at the default. It only bites the
clock bug if set to e.g. 14. **Weekend guard:** `CWeekendCloseExit` closes Friday at
`InpWeekendCloseHour=20` **server time** (`_Inputs.mqh:93`; plugin `:95-130`) with
`InpWeekendGMTOffset=0` (`CWeekendCloseExit.mqh:19`); also `CPositionCoordinator:1991-1999`
(Fri `hour≥weekend_hour`). These are **server-time-anchored**, so unaffected by the GMT model.

**Crash engine window (§5 of task): documented 13:00–17:00 GMT is NOT enforced.**
`CCrashBreakoutEntry.mqh:48-59` — `m_start_hour(=13)/m_end_hour(=17)` are flagged in-source as
**"future use — never read"** and `:50-53` states *"no ... GMT time-box ... is applied."* Grep
confirms the only references are the ctor assignments (:90-91); `CheckForEntrySignal` never
reads them. **The crash engine fires in any hour.** This is a doc-vs-code discrepancy, not a
timezone bug.

---

## 3. Anchor cross-check vs `GoldHistory/NewsCalendar_USD.csv` — PASS

CSV header: `schema=1; exported_at_utc=2026.07.07; winter_offset=2; anchors_ok_pct=97.51; model=A`.
Events stored in **true UTC**. 91 NFP rows; coverage 2018-12 → forward. No README in
`GoldHistory/` — the header line is the only provenance note (winter_offset + DST model + the
97.51% self-reported bar-alignment score).

| Event class | Winter UTC (observed) | Summer UTC (observed) | ET anchor | Result |
|---|---|---|---|---|
| **NFP** (`nonfarm-payrolls`) | **13:30** (2019-01-04, 2020-01-10, 2023-12-08…) | **12:30** (2019-06-07, 2020-07-02…) | 08:30 ET → 13:30 EST / 12:30 EDT | **PASS** |
| **CPI** (`consumer-price-index`) | **13:30** (2019-01-11, 2019-02-13) | **12:30** (2019-06-12) | 08:30 ET | **PASS** |
| **FOMC** (`fomc-meeting-statement`/`fed-interest-rate-decision`) | **19:00** (2018-12-19, 2019-01-30, 2019-12-11) | **18:00** (2019-03-20, 06-19, 07-31, 09-18) | 14:00 ET → 19:00 EST / 18:00 EDT | **PASS** |

Note: the task prompt's stated NFP mapping ("12:30 winter / 13:30 summer") is inverted; the
**physically correct** mapping is 13:30 UTC winter / 12:30 UTC summer, and the CSV matches the
correct one.

**DST-transition dates confirmed as US (not EU):** NFP on 2023-03-10 = **13:30** (before the
2nd-Sun-Mar switch on 2023-03-12 → still EST), 2023-04-07 = 12:30 (EDT). NFP 2023-11-03 =
**12:30** (before 1st-Sun-Nov fall-back on 2023-11-05 → still EDT), 2023-12-08 = 13:30 (EST).
The event times flip exactly on the US-DST Sundays every year 2019-2026 → the broker data the
CSV was aligned to follows **US DST**, and Model B (CNewsGate) reproduces it. `anchors_ok_pct
= 97.51%` is consistent with clean alignment minus transition-week/edge ambiguity.

**Consequence:** Model B (news) is validated against real anchors and is correct. Model A
(session clock, tester) uses fixed +3 with no DST → it **disagrees with the validated broker
model by 1 hour throughout US-winter** (~early Nov to mid-Mar, ≈45% of the calendar).

---

## 4. Bugs / risks

**BUG-1 (MEDIUM) — Session clock is DST-blind in the tester → 1-hour winter misalignment.**
`CSessionEngine.mqh:317-330` (and mirror `CMarketContext.mqh:1041-1049`). Fallback offset is a
fixed `InpBrokerGMTOffset=3` (summer). Since the broker data actually runs +2 in winter (§3),
`GetGMTHour()` reads **1 hour behind true GMT** all winter, so every GMT-keyed session window
activates **1 hour late** (true-UTC) from ~early-Nov to ~mid-Mar. This is *not* the 3–4-week
transition edge case — it is a persistent ~4.5-month offset in every backtest.
- Live trading is **unaffected** (offset auto-detected, DST-tracking).
- On the production config the blast radius is limited because the offset-sensitive consumers
  are at DST-agnostic defaults: session-engine entry modes all OFF (`InpSessionLondonBO/NYCont/
  SilverBullet/LondonClose=false`, `_Inputs.mqh:387-390`); Friday cutoff = full ban
  (offset-independent); session gate = all sessions allowed (offset-independent).
- What **does** bite the backtest: the **session-risk multiplier** (London ×0.50 / NY ×0.90,
  `UltimateTrader.mq5:2383-2399`) — its 8/13/21 GMT boundaries shift 1h late in winter, so
  trades near session edges are mis-sized (e.g., true-13:00 NY opens still get the ×0.50 London
  penalty; the ×0.90 NY window ends at true-22:00). Also winter Asia-session validator checks
  (`CSignalValidator.mqh:394-465`) and audit-session labels shift 1h.
- **Escalates to HIGH** if any session-engine entry mode, the Session-Breakout entry, a
  non-default `InpFridayEntryCutoffGMT`, or a restrictive `InpTradeAsia/London/NY` is enabled —
  those are the entry-timing gates that a 1-hour winter error would move trades on/off of.

**BUG-2 (LOW) — EU-vs-US DST mismatch in the file-signal path.**
`CFileEntry::GetEETOffset()` (`CFileEntry.mqh:83-129`) uses **EU DST** (last Sun Mar / last Sun
Oct) to timestamp injected signals, while the broker/CSV follow **US DST** (2nd Sun Mar / 1st
Sun Nov). The calendars diverge ~2–3 weeks each March and ~1 week each late-Oct/Nov → injected
signal timestamps are off by 1 hour on those weeks. This is exactly the US-vs-EU class the task
warned about, but confined to the file-injection path (not the live session/news clocks).

**RISK-3 (INFO) — Crash "active window 13:00–17:00 GMT" is not enforced.** Dead members
(`CCrashBreakoutEntry.mqh:56-59`), already annotated in-source. The crash engine has no
time-box; any GMT hour is eligible. Docs claiming a 13–17 window are inaccurate.

**RISK-4 (INFO) — Three uncoordinated offset models.** Nothing reconciles Model A / B / C.
CNewsGate warns on live A-vs-B disagreement (`:121-127`) but there is no such guard for the
tester path, where A and B provably disagree all winter. A single shared DST-aware offset
(promote Model B's `ModelOffsetHours` to the one clock) would remove BUG-1 and BUG-2.

---

## 5. Verdict

**CORRECT-WITH-CAVEAT.**

- News/calendar timezone model: **CORRECT.** US-DST calendar (2nd Sun Mar 07:00 UTC → 1st Sun
  Nov 06:00 UTC), winter offset +2/+3, verified byte-for-byte against NFP/CPI/FOMC UTC anchors
  (all PASS) and against the US-DST transition Sundays 2019-2026. No US-vs-EU error in the news
  path.
- Session-window clock: **BUG (BUG-1, MEDIUM).** DST-blind fixed GMT+3 in the tester → sessions
  run 1 hour late every US-winter (~45% of the calendar) in backtests. Contained on the
  production config (entry gates at DST-agnostic defaults; only the session-risk multiplier and
  telemetry are materially skewed) and **absent in live** (offset auto-detected). Would be HIGH
  if any session-engine entry mode / session-breakout / non-default Friday-or-session filter
  were enabled.
- Secondary: **BUG-2 (LOW)** EU-DST in `CFileEntry` (file-injection only); **RISK-3** crash
  window is nominal-only (not enforced).

**Is it an off-by-one / wrong-DST-calendar bug?** Yes — both. An **off-by-one-hour** clock bug
in the session engine (fixed +3, no DST → 1h late all winter, tester only), and a **wrong-DST-
calendar** bug (EU vs US) in the file-signal path. The news calendar itself is correct.
