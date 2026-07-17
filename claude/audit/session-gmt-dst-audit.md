# Session / GMT / DST Operational-Correctness Audit

**Scope:** active-session handling and GMT/DST correctness in the UltimateTrader gold EA.
**Mode:** READ-ONLY trace + calculation. No production behavior, value, or file changed. This is a **FINDING for a future separate fix**, not a fix.
**Frozen at:** tag `baseline-input-cleanup-388` (388 inputs). `git describe --tags` = `baseline-input-cleanup-388`.
**Ledger:** `/home/nullkuhl/.claude/jobs/6ec97821/tmp/arc_stats.csv` (UTF-16LE; 865 trades, ENTRY+EXIT rows).

> Working-tree caveat: the repo's working-tree `UltimateTrader.mq5` is **0 bytes** (`M` in git status). All EA line numbers below are read from `git show baseline-input-cleanup-388:UltimateTrader.mq5` (3369 lines). Include files (`Include/**`) are byte-identical to the tag for every file cited here (verified: only `.mq5` differs among the audited files).

---

## The DST model (single source of truth)

`Include/Utils/CTimeOffset.mqh:66` `BrokerGMTOffset(server_time)` returns **+3 during US-DST (summer), +2 otherwise (winter)**, switching on the US-DST Sundays (2nd Sun Mar 07:00 UTC → 1st Sun Nov 06:00 UTC). Broker server clock = **GMT+2 winter / GMT+3 summer**. `server_hour H ⇔ GMT hour (H − offset)`.

The DST-1 resolver is armed **only in the tester** and only when `InpTesterDSTFix=true` (default true, `UltimateTrader_Inputs.mqh:107`). It is wired into exactly two clock services:
- `CSessionEngine::GetGMTHour()/GetGMTOffset()` (`Include/EntryPlugins/CSessionEngine.mqh:488, 508`) via `m_tester_dst_fix` (armed at `:344`).
- `CMarketContext::GMTHourOf()` (`Include/MarketAnalysis/CMarketContext.mqh:1106`) via its own `m_tester_dst_fix` (armed at `ResolveGMTOffset()` `:1066`).

**Live (non-tester)** never arms the resolver: both services fall back to a **frozen `m_gmt_offset`** captured ONCE at init from `TimeCurrent()−TimeGMT()` (`CSessionEngine.mqh:317`, `CMarketContext.mqh:1052`). See Finding F2.

---

## 1. Active-session consumer inventory

`g_sessionEngine` (the standalone `CSessionEngine`, declared `UltimateTrader.mq5:162`, `new` at `:1410`, registered enabled at `:1416`) is the **DST-aware clock backbone**: it produces ~0 signals of its own (Finding F3) but its `GetGMTHour()/GetGMTOffset()` are consumed as a time service by nearly every other session consumer. `CMarketContext::GMTHourOf()` is a second, independent DST-aware clock used only by the news gate.

Classification key: **[DST-AWARE]** = winter+2 / summer+3 per-timestamp via `CTimeOffset` (tester) or frozen auto-detected offset (live). **[GMT-0/RAW-SERVER]** = keys off raw broker-server time, offset never applied. **[N/A default]** = clock is DST-aware but the default input makes DST irrelevant.

| # | Consumer | file:line | Exact comparison | Clock | Class |
|---|----------|-----------|------------------|-------|-------|
| 1 | Session eligibility gate (`InpTradeAsia/London/NY`) | `CSignalOrchestrator.mqh:492` → `Utils.mqh:118/129/140/154` | `IsSessionAllowed(asia,london,ny, g_sessionEngine.GetGMTOffset())`; Asia `h>=23‖h<8`, London `[8,16)`, NY `[13,21)` (GMT) | `g_sessionEngine.GetGMTOffset()` | **DST-AWARE** |
| 2 | Session risk multiplier (`InpEnableSessionRiskAdjust=true`) — **IMMEDIATE path only** | `UltimateTrader.mq5:2839–2857` | `gmt=g_sessionEngine.GetGMTHour(...)`; London `[8,13)`→`InpLondonRiskMultiplier=0.50`, NY `[13,21)`→`InpNewYorkRiskMultiplier=0.90`, else 1.0 | `g_sessionEngine.GetGMTHour()` | **DST-AWARE** |
| 3 | Friday entry cutoff (`InpFridayEntryCutoffGMT=0`) | `UltimateTrader.mq5:2408–2411` | `is_friday && (g_sessionEngine.GetGMTHour(...) >= InpFridayEntryCutoffGMT)` | `g_sessionEngine.GetGMTHour()` | **DST-AWARE** (N/A at default 0 = full-ban) |
| 4 | Bear-Pin NY block (`InpBearPinBarBlockNY=true`) | `CPinBarEntry.mqh:238–243` | `if(g_sessionEngine.GetGMTHour(...) >= 13) return` (block NY) | `g_sessionEngine.GetGMTHour()` | **DST-AWARE** |
| 4b | Bear-Pin Asia-only gate (`g_profileBearPinBarAsiaOnly=true`) | `CPinBarEntry.mqh:228–234` | `gmt=GetGMTHour; if(gmt>=8 && gmt<23) return` (non-Asia block) | `g_sessionEngine.GetGMTHour()` | **DST-AWARE** |
| 5 | Bull-MA-Cross NY block (`g_profileBullMACrossBlockNY=true`) | `CMACrossEntry.mqh:173–179` | `if(g_sessionEngine.GetGMTHour(...) >= 13) return` (block NY) | `g_sessionEngine.GetGMTHour()` | **DST-AWARE** |
| 6 | `GetCurrentTradingSession()` — stamps `entry_session` + the CSV **Session** column | `UltimateTrader.mq5:409–416` (stamped at `:2335/2570/3032/3201`) | `h=g_sessionEngine.GetGMTHour(...)`; `<8`→ASIA, `<13`→LONDON, else NEWYORK (GMT) | `g_sessionEngine.GetGMTHour()` | **DST-AWARE** |
| 7 | Validator Asia MR-short allows | `CSignalValidator.mqh:394, 413, 465` | `IsAsiaSession(g_sessionEngine.GetGMTOffset())` | `g_sessionEngine.GetGMTOffset()` | **DST-AWARE** |
| 8 | Liquidity-Engine SFP session label (forensic log only) | `CLiquidityEngine.mqh:1176–1178` | `sfp_gmt=g_sessionEngine.GetGMTHour(...)`; `<8`ASIA `<16`LONDON else NY | `g_sessionEngine.GetGMTHour()` | **DST-AWARE** (logging) |
| 9 | News blackout schedule (NFP/CPI/PPI/FOMC) | `CMarketContext.mqh:1106/1126/1145` | `GMTHourOf(bar_open)`; flags **both** DST candidate hours (12‖13, 18‖19) | `CMarketContext::GMTHourOf()` | **DST-AWARE** (dual-hour, DST-robust) |
| 10 | Standalone `CSessionEngine` 5 modes (Asian/London-BO/NY-cont/SilverBullet/LondonClose) | `CSessionEngine.mqh:412, 417–482` | internal `GetGMTHour` gating | self (DST-aware) | **DST-AWARE but MUTED — 0 fills** |
| 11 | Standalone `CSessionBreakoutEntry` `g_sessionBreakout` | `UltimateTrader.mq5:1385–1388` | `SetGMTOffset(InpBrokerGMTOffset=3)`; registered **only if `!InpEnableSessionEngine`** | fixed +3 (not DST) | **DORMANT on prod** (`InpEnableSessionEngine=true`) |
| **12** | **Composed `CSessionBreakoutEntry` inside `CExpansionEngine`** — the LIVE session-fill producer | **`CExpansionEngine.mqh:384` (`new`), `:387` (`SetContext` only), invoked `:521–533`** | own `GetGMTHour` with **`m_gmt_offset=0`**; Asian `[0,8)`, London-open `[8,9)`, NY-open `[13,14)` — all **raw server hour** | **raw server (offset 0)** | **GMT-0 / RAW-SERVER — NOT DST-corrected** |

### Confirmation of the known issue (consumer #12)

- `new CSessionBreakoutEntry(m_context)` at `CExpansionEngine.mqh:384` passes **only `context`** ⇒ constructor defaults apply: `asian_start=0, asian_end=8, london_start=8, london_end=9, ny_start=13, ny_end=14, gmt_offset=0` (`CSessionBreakoutEntry.mqh:62–76`).
- The next line (`:387`) calls **`SetContext(m_context)` only**. Repo-wide grep: **`SetGMTOffset` is defined once (`CSessionBreakoutEntry.mqh:113`) and called once — at `UltimateTrader.mq5:1386` on the DORMANT `g_sessionBreakout`, NEVER on the composed `m_session_breakout`.** So the composed instance keeps `m_gmt_offset = 0` for its entire life.
- `GetGMTHour()` (`CSessionBreakoutEntry.mqh:214–225`) computes `hour = dt.hour − m_gmt_offset = dt.hour − 0` ⇒ **returns the raw broker-server hour** and calls it "GMT". `UpdateAsianRange()` (`:270`) does the same for the M15 bar loop.
- **Hardcoded Asian window (verified): server hours `[0, 8)`** — the composed instance uses the constructor **default `asian_end = 8`**, and ignores `InpAsianRangeStartHour(0)/InpAsianRangeEndHour(7)/InpLondonOpenHour/InpNYOpenHour` entirely (those inputs reach only the standalone `g_sessionBreakout` at `:1385`). Note the standalone uses `asian_end=7`; the composed uses `8` — an additional silent inconsistency.
- It is NOT affected by `InpTesterDSTFix`: it never touches `CTimeOffset` and has no `m_tester_dst_fix` path.

---

## 2. Effective winter vs summer windows (GMT terms)

Broker server = GMT+2 winter / GMT+3 summer. `GMT = server_hour − offset`.

### DST-aware consumers (#1–#10) — anchored to true GMT (stable), drift in server time
Their GMT windows are constant year-round; only the *server* time they fire at shifts +1h in summer.

| Boundary | GMT window (both halves) | Server time WINTER (+2) | Server time SUMMER (+3) |
|---|---|---|---|
| Asia session (#1) | GMT `[23,8)` | svr `[1,10)` | svr `[2,11)` |
| London session (#1) | GMT `[8,16)` | svr `[10,18)` | svr `[11,19)` |
| NY session (#1) | GMT `[13,21)` | svr `[15,23)` | svr `[16,24)` |
| London risk 0.50× (#2) | GMT `[8,13)` | svr `[10,15)` | svr `[11,16)` |
| NY risk 0.90× (#2) | GMT `[13,21)` | svr `[15,23)` | svr `[16,24)` |
| Bear-Pin / Bull-MA NY block (#4,#5) | GMT `≥13` | svr `≥15` | svr `≥16` |
| Session-of-day cut (#6) | ASIA `[0,8)` / LON `[8,13)` / NY `[13,24)` | +2 | +3 |
| Friday cutoff (#3) | GMT `≥ InpFridayEntryCutoffGMT` (default 0 ⇒ all) | — | — |

### GMT-0 composed instance (#12) — anchored to raw SERVER hour (stable in server), **drifts in true GMT**
Its server windows are fixed year-round; therefore its true-GMT meaning slides **1 hour earlier in summer than winter**.

| Composed window | Server hour (fixed) | **Actual TRUE GMT — WINTER (+2)** | **Actual TRUE GMT — SUMMER (+3)** | Intended GMT (header comment) | Error |
|---|---|---|---|---|---|
| Asian range build | svr `[0,8)` | GMT `[22,6)` (prev-day 22:00→06:00) | GMT `[21,5)` | "Asian" | shifted, 1h DST drift |
| London-open breakout | svr `[8,9)` | **GMT `[6,7)`** | **GMT `[5,6)`** | GMT `[8,9)` | **−2h winter / −3h summer**; 1h DST drift |
| NY-open continuation | svr `[13,14)` | **GMT `[11,12)`** | **GMT `[10,11)`** | GMT `[13,14)` | **−2h winter / −3h summer**; 1h DST drift |

**The 1-hour DST misalignment, explicit:** the composed instance keys on server hour H, whose true GMT is `H−2` in winter but `H−3` in summer. Its "London breakout" therefore fires at **GMT 06:00 in winter but GMT 05:00 in summer** (its "NY continuation" at GMT 11:00 winter / 10:00 summer). A correctly DST-anchored consumer keeps a constant GMT hour across the boundary; the composed instance moves by exactly 1 GMT-hour twice a year, and additionally sits a **constant 2h (winter) / 3h (summer) before** its own GMT-labeled intent — i.e. it is running on the **wrong clock (server, not GMT)** entirely. In server-hour terms it fires its "London" window at svr 08:00, whereas the DST-aware London-8-GMT window (#1/#2) fires at svr 10:00 (winter) / 11:00 (summer): a **2–3 hour offset** between the two families.

---

## 3. Trade-impact comparison (from the frozen ledger)

**Portfolio:** 865 trades, **+149.16 R / +$33,046.72** net (this ledger's totals).

**Session distribution (ENTRY rows, DST-aware `Session` column via consumer #6):**

| Session (DST-aware label) | ENTRY count |
|---|---|
| ASIA | 339 |
| LONDON | 270 |
| NEWYORK | 256 |

**Engine attribution (ENTRY):** PinBar 418, Engulfing 160, CrashBreakout 150, MACross 58, PullbackCont 43, **ExpansionEngine 26**, FailedBreakReversal 10. **`SessionEngine` (standalone #10): 0 fills — MUTED confirmed.** `g_sessionBreakout` (#11): 0 fills (dormant).

**Reconciling the "26 fills":** the audit's "26" = **ExpansionEngine total**, but only **12** are the GMT-0-composed session fills (comment `Asian Breakout London`×9 + `London Continuation NY`×3, all `EngineName=ExpansionEngine`, `EngineMode=MODE_LONDON_BREAKOUT`). The other **14** are the engine's native **IC Breakout** modes (`IC Breakout Long/Short (Consol=N bars)`) which are **not time-gated** and thus **unaffected** by the DST issue. So the misalignment's P&L surface is the **12 composed fills**, not 26.

**The misalignment made visible in the data** — every composed fill's DST-aware `Session` label contradicts its own pattern name:

| Composed pattern | Fires at server hour | True GMT | DST-aware `Session` label | Count |
|---|---|---|---|---|
| "Asian Breakout **London**" | 08:00 (100%) | 06:00 (winter) | **ASIA** (all 9) | 9 |
| "**London** Continuation **NY**" | 13:00 (100%) | 10:00 (summer) | **LONDON** (all 3) | 3 |

The server-hour histogram is a clean `{8:9, 13:3}` — **100% pinned to the raw server window, invariant to DST**. That is precisely the defect: the fills do **not** move with DST, so relative to true GMT they drift, and they land in the *wrong* GMT session (a "London" breakout executing in the Asian GMT window; a "NY" continuation executing in the London GMT window).

**Bounded P&L exposure of the 12 GMT-0-composed session fills:**

| | Value |
|---|---|
| Net R | **+2.04 R** |
| Net money | **+$1,435.90** |
| Share of portfolio money | **4.35 %** |
| Share of portfolio R | **1.37 %** |
| Per-trade range (money) | **−$450.84 … +$1,220.19** |
| Winners / losers | 5 / 7 |

Per-trade ledger (all 12):

| Ticket | Pattern | EntryTime (server) | srvH | DST | trueGMT | Total_R | Total_PnL |
|---|---|---|---|---|---|---|---|
| 819 | Asian Breakout London | 2021.12.01 08:00 | 8 | winter | 6 | −0.39 | −16.18 |
| 846 | Asian Breakout London | 2022.01.06 08:00 | 8 | winter | 6 | +1.50 | +225.59 |
| 1080 | London Continuation NY | 2022.09.06 13:00 | 13 | summer | 10 | −1.01 | −61.44 |
| 1729 | Asian Breakout London | 2024.01.17 08:00 | 8 | winter | 6 | +0.50 | +88.36 |
| 1766 | Asian Breakout London | 2024.03.05 08:00 | 8 | winter | 6 | +1.71 | +521.99 |
| 1777 | London Continuation NY | 2024.03.11 13:00 | 13 | summer | 10 | −1.01 | −122.64 |
| 2568 | Asian Breakout London | 2025.11.17 08:00 | 8 | winter | 6 | −0.15 | −60.04 |
| 2594 | Asian Breakout London | 2025.12.15 08:00 | 8 | winter | 6 | −0.77 | −450.84 |
| 2605 | Asian Breakout London | 2025.12.31 08:00 | 8 | winter | 6 | −0.91 | −174.77 |
| 2646 | Asian Breakout London | 2026.01.28 08:00 | 8 | winter | 6 | +1.64 | +1220.19 |
| 2657 | Asian Breakout London | 2026.02.02 08:00 | 8 | winter | 6 | −0.78 | −334.84 |
| 2746 | London Continuation NY | 2026.06.10 13:00 | 13 | summer | 10 | +1.71 | +600.52 |

(Sampling note: this ledger's 9 "London" fills all landed in winter and 3 "NY" fills all in summer — an artifact of the small population, not of the mechanism. The mechanism fires at server 8/13 in *both* halves; only the true-GMT label differs.)

---

## Findings (for a future separate fix — not fixed here)

- **F1 (material misalignment).** The composed `CSessionBreakoutEntry` inside `CExpansionEngine` (`:384`) runs on **raw broker-server time (`m_gmt_offset=0`)**, never receiving `SetGMTOffset`/the DST-1 resolver. Its "London breakout" fires at **GMT 06:00 winter / 05:00 summer** and its "NY continuation" at **GMT 11:00 winter / 10:00 summer** — a constant **2h (winter) / 3h (summer)** ahead of its own GMT-labeled intent, plus a **1-hour DST drift** across the US-DST boundary. Empirically all 12 of its fills are session-mislabeled (9 "London" tagged ASIA, 3 "NY" tagged LONDON). Bounded historical impact: **12 trades, +2.04R / +$1,435.90 net (4.35% of portfolio P&L)**, per-trade −$451…+$1,220.
- **F2 (secondary, live-only).** The DST-1 per-timestamp resolver runs **only in the tester**. Live arms neither `m_tester_dst_fix`; both `CSessionEngine` and `CMarketContext` freeze a single `TimeCurrent()−TimeGMT()` offset at init. Correct at start-up but goes **1h stale after each DST transition until the EA is restarted**. Affects consumers #1–#9 live, not the tester numbers.
- **F3 (context).** `SessionEngine` (#10) is registered enabled yet fires **0 signals** in the frozen ledger; its value is purely as the DST-aware **clock service** for #1–#8. `g_sessionBreakout` (#11) is dormant on prod (`InpEnableSessionEngine=true`). The composed instance (#12) is the *only* live session-timed entry generator — and it is the one uncorrected consumer.
- **F4 (silent input divergence).** The composed instance ignores `InpAsianRangeStartHour/EndHour/InpLondonOpenHour/InpNYOpenHour` and hardcodes `0/8/8/9/13/14`; its Asian window (`asian_end=8`) even differs from the standalone's `InpAsianRangeEndHour=7`.

## Verdict (plain language)

The session/GMT/DST handling is **operationally correct for every consumer that routes through the DST-aware clock services (`g_sessionEngine`/`CMarketContext`) in the tester** — the eligibility gate, session risk multipliers, Friday cutoff, Bear-Pin/Bull-MA NY blocks, session-of-day tagging, and the news gate are all DST-1 correct (winter +2 / summer +3). It is **NOT correct in exactly one active place: the `CSessionBreakoutEntry` composed inside `CExpansionEngine`**, which keys its Asian/London/NY windows off **raw broker-server time with a zero GMT offset** — it never gets `SetGMTOffset` or the DST-1 resolver. That single consumer is wrong by **2 hours in the US-winter half and 3 hours in the US-summer half** (its labeled "London 8 GMT" window actually fires at GMT 06:00 winter / 05:00 summer; "NY 13 GMT" at GMT 11:00 winter / 10:00 summer), with the winter↔summer step being the classic **1-hour DST misalignment**. Bounded historical trade impact from the frozen ledger: **12 fills, net +2.04R / +$1,435.90 (4.35% of portfolio P&L), −$451…+$1,220 per trade** — small and slightly net-positive in aggregate, so not a P&L emergency, but a genuine correctness defect (every one of those fills executes in the *wrong* GMT session, as the ASIA/LONDON labels on their "London"/"NY" pattern names prove). Recommended future fix: propagate the DST-1 offset into the composed instance (mirror `g_sessionEngine`), i.e. call `m_session_breakout.SetGMTOffset(...)`/route it through `CTimeOffset` at `CExpansionEngine.mqh:387`, and reconcile the hardcoded window hours with the `Inp*` session inputs — to be validated as its own change, not folded into this audit.
