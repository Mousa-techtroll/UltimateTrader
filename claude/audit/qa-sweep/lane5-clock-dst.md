# Lane 5 — Clock / Session / DST correctness audit

Scope: every clock consumer post the F1 fix (composed `CSessionBreakoutEntry` breakout-window
clock now DST-aware via `InpSessionBreakoutDST`, resolved like `CSessionEngine`). Read-only static
analysis + empirical anchoring from decoded archived TradeEvents. Baseline of record:
`baseline-session-breakout-utc-34858` (869 pos / $34,858.89); kill-switch `InpSessionBreakoutDST=false`
→ $32,503.03 / 865.

---

## 0. Effective config (verified — `claude/audit/current-canonical.set`, decoded)

| Input | Effective | Consumer |
|---|---|---|
| `InpTesterDSTFix` | **true** | CSessionEngine, CMarketContext, CFileEntry, AND co-condition for composed breakout |
| `InpSessionBreakoutDST` | **true** | composed `CSessionBreakoutEntry` breakout clock (F1) |
| `InpBrokerGMTOffset` | 3 | legacy fixed fallback (flag-off only) + dead standalone breakout |
| `InpNewsWinterGMTOffset` | 2 | CNewsGate `ServerToUtc` base |
| `InpNewsServerFollowsUSDST` | true | CNewsGate +1h US-DST |
| `InpEnableSessionEngine` | true | ⇒ g_sessionEngine LIVE (global clock service) AND standalone breakout NOT registered (`UltimateTrader.mq5:1389`) |
| `InpEnableExpansionEngine` | true | ⇒ composed breakout LIVE |
| `InpEnableSessionBreakout` | true | standalone gate — but suppressed by `:1389 if(!InpEnableSessionEngine)` |
| `InpEnableMultiStrategy` | false | CMarketContext DAY_DATA news-flat path unreachable |
| `InpSignalSource` | BOTH(2) | `register_patterns=true` (`:1257`) |
| `InpTradeAsia/London/NY` | true / true / true | `IsSessionAllowed` (still blocks the GMT 21–23 union gap) |
| `InpFridayEntryCutoffGMT` | 0 | full server-Friday ban (`fri_gmt_hour>=0` always true) |

**Live clock-consumer inventory (prod):** (a) `g_sessionEngine` = single DST-aware clock SERVICE
(`GetGMTHour`/`GetGMTOffset`), consumed by Friday gate, `IsSessionAllowed`, executor spread/session-risk,
CMACross/CPinBar/CLiquidity, audit session; (b) composed `CSessionBreakoutEntry` inside `CExpansionEngine`
(its OWN clock: raw-server range + DST-aware breakout); (c) `CNewsGate.ServerToUtc` (InpEnableNewsFlat path).
Dead: standalone `g_sessionBreakout` (constructed `:1387`, `SetGMTOffset(3)` `:1388`, but never registered/
Initialized on prod → fully inert). `CMarketContext.GMTHourOf` reachable only via DAY_DATA (multi-strategy off).

**Consistency verdict: PASS.** No live consumer is left on the wrong flag or carries an independent/stale
clock. The composed breakout correctly uses the NEW `InpSessionBreakoutDST` as its primary gate. The range
(raw-server, offset 0) and breakout (DST-aware +2/+3) clocks are genuinely independent as intended, and the
`InpSessionBreakoutDST` / `InpTesterDSTFix` split is genuinely scoped as intended. Findings below are latent
config traps, one real live-vs-tester divergence, and maintenance hazards — none changes the frozen prod baseline.

---

## Findings (ranked by severity × baseline risk)

### 1. `InpSessionBreakoutDST=true` is NECESSARY-not-SUFFICIENT in the tester — silent co-dependency on `InpTesterDSTFix`  — **INTENDED-but-FRAGILE**
**FACT.** `CSessionBreakoutEntry.Initialize` (`CSessionBreakoutEntry.mqh:144-153`):
```
if(InpSessionBreakoutDST){
   m_bo_gmt_offset = (TimeCurrent()-TimeGMT())/3600;              // =0 in tester
   if(m_bo_gmt_offset==0 && MQL_TESTER && InpTesterDSTFix){       // <-- co-condition
      m_tester_dst_fix=true; m_bo_gmt_offset=CTimeOffset::BrokerGMTOffset(...); }}
```
In the tester `TimeGMT()==TimeCurrent()` so `m_bo_gmt_offset=0` always; the DST-aware breakout only arms when
`InpTesterDSTFix` is ALSO true. So the new $34,858 baseline requires **both** flags; the kill (`SB-DST=false`
→ $32,503) is clean and exact (block skipped ⇒ `m_bo_gmt_offset=0`, `m_tester_dst_fix=false` ⇒ raw-server =
legacy A). The trap is the "on" direction: setting `InpSessionBreakoutDST=true` with `InpTesterDSTFix=false`
is a **no-op** (breakout stays raw-server), yet the input label ("composed breakout-window DST-correct") implies
standalone effect.
- **Failure scenario:** a maintainer flips `InpTesterDSTFix=false` to test legacy-session-engine behavior while
  leaving `InpSessionBreakoutDST=true`, expecting the DST-aware breakout to persist; it silently reverts too,
  and a reproduction that "should" be $34,858-with-legacy-engine instead lands on a third number, mis-attributed.
- **Fix sketch:** either (a) document the co-dependency in the input comment, or (b) decouple — arm the breakout
  DST on `InpSessionBreakoutDST` alone in the tester (drop `&& InpTesterDSTFix` from `:148`) so the flag is
  self-contained. (b) would re-baseline; do NOT apply without a run.
- **Baseline impact:** NONE on prod (both true). Reproduction-integrity landmine only.

### 2. Twice-a-year 1h DST-transition ambiguity NEVER touches a live bar — **BENIGN (proven safe)**
**FACT.** `CTimeOffset::BrokerGMTOffset` (`CTimeOffset.mqh:66-70`) two-pass: `utc_guess=server-2h`,
`IsUsDst(utc_guess)?3:2`. The only ambiguous instant is the transition hour. Transitions are fixed by
`NthSundayUtc`: spring = 2nd Sunday March **+07:00 UTC** (`:44`), fall = 1st Sunday Nov **+06:00 UTC** (`:47`) —
`NthSundayUtc` returns a **Sunday** by construction (`:77-86`). Gold/XAUUSD is closed Fri ~21:00 UTC → Sun
~21:00 UTC, so 06:00–08:00 UTC Sunday is deep in the weekend gap: the spring "skipped" server hour and the fall
"repeated" server hour have **no H1 bar** to gate. Verified spring-forward maps the first summer server bar
(Mon) to +3 correctly and fall-back resolves the repeated hour to +2 (winter) — both post-weekend, unambiguous.
- **Baseline impact:** none; documented residual ambiguity is unreachable for this instrument. Doctrine-clean.

### 3. LIVE clock freezes at init; TESTER is per-bar — session/breakout vs news clock can drift 1h live — **BUG (live only), HYPOTHESIS on magnitude**
**FACT (code).** Live paths resolve the offset ONCE and freeze it:
`CSessionEngine.Initialize:317` (`m_gmt_offset` frozen), composed breakout `:146-147` (`m_bo_gmt_offset` frozen,
`m_tester_dst_fix` stays false live). Neither re-resolves per-bar live. By contrast `CNewsGate` re-resolves
`m_live_offset_sec` every 6h refresh (`CNewsGate.mqh:546`), and the tester is exact per-bar via `CTimeOffset`.
- **Failure scenario:** an EA left running across a US-DST switch keeps the stale offset until restart. For the
  window between the transition and the next restart, `GetGMTHour` (Friday gate, `IsSessionAllowed`, executor
  spread/risk, MACross/PinBar session gates) and the composed breakout window all run **1h off**, and disagree
  with the news clock (which self-corrects within 6h). London/NY breakout windows fire 1h early/late.
- **HYPOTHESIS:** live PnL impact unmeasurable from read-only artifacts (no live logs / tester never exercises
  the frozen-live path). Needs live-forward instrumentation: log `GetGMTOffset()` daily and diff against
  `CTimeOffset::BrokerGMTOffset(TimeCurrent())`.
- **Fix sketch:** live path — recompute `m_gmt_offset`/`m_bo_gmt_offset` per-bar (or per-6h like news) instead of
  once in `Initialize`. Tester-only baseline is unaffected (tester uses the per-bar `m_tester_dst_fix` branch already).
- **Baseline impact:** NONE on the tester baseline (869/$34,858). Live-robustness defect.

### 4. Composed breakout Asian RANGE clock is offset 0 (raw-server) because `SetGMTOffset` is never called on it — **INTENDED / maintenance hazard**
**FACT.** `CExpansionEngine.mqh:384` constructs `new CSessionBreakoutEntry(m_context)` — context only; all timing
params default so `m_gmt_offset=0`. `SetGMTOffset` is called ONLY on the dead standalone (`UltimateTrader.mq5:1388`,
verified sole call site). So the LIVE breakout's Asian range (`UpdateAsianRange:274`, membership loop `:305`,
freeze gate) runs on **raw server hours [0,8)** while `GetGMTHour` (breakout window) is DST-aware (+2/+3). This is
the documented "range-DST rejected / breakout-DST adopted" split (`CSessionBreakoutEntry.mqh:47-52,244-246,271`)
and is baked into the frozen baseline.
- **Empirical confirmation (FACT):** decoded pre-F1 archives — session-breakout `ENTRY_OPENED` fills cluster at
  **server hour 08 (London) / 13 (NY)** exactly, i.e. offset-0 raw-server window (`Logs/p513_ab/Alive_TradeEvents.csv`:
  9× @08, 3× @13; `claude/gate/TradeEvents_2024.csv`: 2× @08, 1× @13). Under the F1 fix the same fills move to
  server ~10–11/15–16 (winter) — I could NOT verify the post-fix window empirically: no decoded
  `baseline-session-breakout-utc-34858` TradeEvents in the read-only archive (all decoded TradeEvents present are
  pre-F1, offset-0). Instrumentation to close this: decode the 34858-tag run's TradeEvents and histogram
  session-BO fill server-hours (expect 10–12 / 15–16).
- **Range→breakout invariant holds both seasons:** range freezes at server 08 (offset 0), breakout at server
  10–11 (winter, off=2) / 11–12 (summer, off=3) → always freeze-before-breakout, gap 2–3h. No look-ahead.
- **Hazard:** a maintainer who "fixes" the apparently-missing `SetGMTOffset(InpBrokerGMTOffset=3)` on the composed
  instance (the standalone has it) would shift the Asian range 3h and destroy the baseline.
- **Fix sketch:** none needed. Add a code comment at `CExpansionEngine.mqh:384` stating "offset 0 is intentional
  (raw-server range); do NOT call SetGMTOffset — baseline-frozen."
- **Baseline impact:** none as-is; a well-meaning "fix" WOULD change 869/$34,858.

### 5. Two independent encodings of the same broker-DST model (CTimeOffset hard-coded 2/3 vs CNewsGate input-driven) — **latent config trap, HYPOTHESIS**
**FACT.** `CTimeOffset::BrokerGMTOffset` hard-codes winter=2/summer=3 (`:69`). `CNewsGate.ServerToUtc`
(`CNewsGate.mqh:188-198`) computes offset as `InpNewsWinterGMTOffset + (InpNewsServerFollowsUSDST&&IsUsDst?1:0)`.
They agree numerically ONLY because `InpNewsWinterGMTOffset==2` on prod. Both share the same `IsUsDst`
(CNewsGate forwards to CTimeOffset, `:171`), so the DST boundary is single-source — but the BASE offset is not.
- **Failure scenario:** setting `InpNewsWinterGMTOffset=3` (confusing it with the summer value — the input comment
  even mentions "InpBrokerGMTOffset=3 is the SUMMER value") silently desyncs news gating from session gating by
  1h. The live sanity WARN (`CNewsGate.mqh:124-129`) is live-only and compares against the input model, not against
  `CTimeOffset`; there is NO tester cross-check that the two encodings agree.
- **Fix sketch:** have `CNewsGate` derive its tester base from `CTimeOffset::BrokerGMTOffset` (single source), or add
  an init-time assert `InpNewsWinterGMTOffset==2` under the tester. Described only.
- **Baseline impact:** none on prod; latent.

### 6. Friday ban mixes server day-of-week with GMT-hour cutoff — **BENIGN (moot on prod)**
**FACT.** `UltimateTrader.mq5:2419-2425`: `is_friday` from `TimeToStruct(TimeCurrent())` = **server** Friday;
`fri_gmt_hour` from `g_sessionEngine.GetGMTHour` = **GMT**. On prod `InpFridayEntryCutoffGMT=0` ⇒ `fri_gmt_hour>=0`
always true ⇒ full server-Friday ban, DST-awareness of the hour is irrelevant. Fail-closed default `24` when clock
unknown (`:2424`) is correct (g_sessionEngine never NULL on prod). If someone sets the cutoff to 14, the day boundary
(server, rolls at UTC 21:00/22:00 Thu) and the hour (GMT) are on different frames — a 2–3h skew at the Friday edge.
- **Baseline impact:** none (cutoff=0).

### 7. All secondary consumers route through the single DST-aware service — **FACT / consistency PASS**
`CMACrossEntry.mqh:176`, `CPinBarEntry.mqh:231,240`, `CLiquidityEngine.mqh:1176`, `CEnhancedTradeExecutor.mqh:212,2199`,
`CSignalOrchestrator.mqh:51,492`, `UltimateTrader.mq5:414,2854` all call `g_sessionEngine.GetGMTHour/GetGMTOffset`.
No plugin holds an independent clock. `IsSessionAllowed` (`Utils.mqh:154`) uses `GetGMTOffset()` (DST-aware) and, with
all three sessions enabled, still vetoes the **GMT 21:00–23:00** union gap (Asia 23–08 ∪ London 8–16 ∪ NY 13–21) — a
live DST-aware gate, not a no-op. `GetGMTHour(server_time)` and `GetGMTOffset()` (which resolves at `TimeCurrent()`)
are read at the same instant by every caller → offset/hour internally consistent.

### 8. Linkage: the F1 clock fix is the driver of the sweep's motivating 3.B interference — **FACT (cross-lane)**
The F1 fix moves session-breakout fills from server-08/13 (empirically shown, offset 0) to server ~10–11/15–16
(DST-aware). That changes the SET and TIMING of open positions on those bars, which feeds the shared
per-bar chandelier/regime counter (`CPositionCoordinator` Surface 3.B, advanced by whichever position is processed
first) → altered trailing stops/exits on UNRELATED positions. This is exactly "two unrelated trades exited at
different prices because a session-breakout position's timing changed." **The clock change is CORRECT; 3.B (other
lane's domain) is the propagator** — not a clock defect. Explains the 865→869 / PnL delta between kill and baseline.

---

## FACTS vs HYPOTHESES summary
- **FACTS (counted/verified):** effective config table; live-consumer inventory; DST transitions always land on a
  market-closed Sunday (unreachable ambiguity); composed range clock = offset 0 (sole `SetGMTOffset` site is the dead
  standalone); legacy composed breakout fires at server 08/13 (12 fills, two archives); all secondary consumers share
  one DST-aware service; `SB-DST`/`TesterDSTFix` co-dependency in the tester.
- **HYPOTHESES (need instrumentation):** live 1h drift PnL magnitude (needs live offset-diff log, Finding 3);
  post-F1 breakout server-hour window (needs decoded 34858-tag TradeEvents, Finding 4); news/session desync under a
  mis-set `InpNewsWinterGMTOffset` (Finding 5).
- **Baseline (869 / $34,858.89):** NO finding changes it as-configured. Findings 1 & 4 are reproduction landmines
  that a careless flag-flip or "cleanup" would trip; Finding 3 is a live-only robustness gap.

## Key files
- `/mnt/c/Trading/UltimateTrader/Include/Utils/CTimeOffset.mqh` (US-DST resolver, two-pass `:66-70`)
- `/mnt/c/Trading/UltimateTrader/Include/EntryPlugins/CSessionBreakoutEntry.mqh` (`:47-52,144-153,240-254,259-282` — split clocks)
- `/mnt/c/Trading/UltimateTrader/Include/EntryPlugins/CExpansionEngine.mqh:384` (composed instance, no SetGMTOffset)
- `/mnt/c/Trading/UltimateTrader/Include/EntryPlugins/CSessionEngine.mqh` (`:311-358` init, `:488-511` getters — global service)
- `/mnt/c/Trading/UltimateTrader/Include/MarketAnalysis/CNewsGate.mqh:177-198` (independent offset encoding)
- `/mnt/c/Trading/UltimateTrader/Include/MarketAnalysis/CMarketContext.mqh:1050-1117` (ResolveGMTOffset/GMTHourOf, DAY_DATA-gated)
- `/mnt/c/Trading/UltimateTrader/Include/EntryPlugins/CFileEntry.mqh:92-137` (EU-DST legacy, inert — no CSV loaded)
- `/mnt/c/Trading/UltimateTrader/Include/Common/Utils.mqh:118-162` (IsSessionAllowed / IsXSession)
- `/mnt/c/Trading/UltimateTrader/UltimateTrader.mq5:1387-1418` (registration), `:2419-2425` (Friday gate)
