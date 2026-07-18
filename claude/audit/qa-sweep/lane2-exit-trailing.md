# QA-sweep Lane 2 — Position-management / exit / trailing correctness

Domain: `Include/Core/CPositionCoordinator.mqh` per-position loop (`ManageOpenPositions` `:2001`, loop `:2060`).
Read-only static audit + read-only python over archived per-trade CSVs. NO source edits / compile / terminal64.

## Provenance of counted evidence (read this before trusting any number)
The archived CSVs used for counts are `claude/gate/{Stats,TradeEvents}_2019..2026.csv`:
**1264 `ENTRY_OPENED` / 1261 `EXIT_FILL`** across 2019–2026, `Source=SIGNAL_SOURCE_PATTERN` only, NO
CREV/CONT/TMF patterns (short sleeve OFF). This is **NOT** the 869-position binding baseline artifact
(`baseline-session-breakout-utc-34858`, Stats md5 `1ed88d41`) — it is a fuller/adjacent run. Treat the
**counts as indicative frequencies of each exit mechanic**; the **code defects below are config-invariant**
and present in the binding baseline (same coordinator, same effective exit config verified below). Ticket
numbers RESET per year, so all per-trade aggregation is keyed by (year-file, ticket).

## Effective exit config (verified: source defaults ∩ `auditEvidence/baseline_A/audit_baseline_A.ini`)
LIVE: `InpEnableTP0=true` (TP0 0.7R / 15% of ORIGINAL), `InpTP1*=1.3R/40% of remaining`, `InpTP2*=1.8R/30%
of remaining` — but the effective per-tier R/vol come from the **frozen per-position regime exit profile**
(`InpEnableRegimeExit=true`, `InpEnableRegimeRisk=true`); `InpEnableAntiStall=true`;
`InpTrailChandelierMult=3.0` (regime-scaled live); `InpTrailBETrigger=0.8`, `InpTrailBEOffset=50`;
`InpBatchedTrailing=false`→ trail policy `TRAIL_SEND_EVERY_UPDATE`; `InpDisableBrokerTrailing=false`;
`InpAutoScalePoints=true`.
DEAD (const or config-off, verified): `InpEnableRunnerExitMode=false` **(const, non-overridable)**,
`InpEnableSmartRunnerExit=false` (const), `InpRunnerRegimeConditional=false` (const),
`InpEnableEarlyInvalidation=false`, `InpEnableBEMover=false`, universal stall `if(false&&…)` `:2805`,
`InpEnableCEG=false`, `InpCrashTrailSuppress/InpPinTrailSuppress=false`, `InpEnableShortSleeve=false`
(CREV/CONT/TMF managers `:3270/:3431/:3588` unreachable), FILE ladder (`:2119`, no file signals in tester).
CONFIRMED inert by CSV: `RunnerExitMode` = `RUNNER_EXIT_STANDARD` on **1261/1261** exits; 0 `RUNNER_*` /
`EARLY_INVALIDATION` / universal-stall events; **0/1261** exits used the flat `InpTP*`/`InpTrailBETrigger`
fallback (every position carries a valid frozen exit profile → no stale-profile mismatch; the flat-fallback
branches `:2405-2412`,`:3202`,`:3927` are dead — matches AUDIT_BUILD).

---

## RANKED FINDINGS

### 1. [BUG — HIGH] Internal `pos.stop_loss` desyncs from the broker and is never re-synced; the plugin ratchets on the REAL broker SL while the coordinator gates on the phantom one → later legitimate trails are silently blocked.
**Two code roots, both in ApplyTrailingPlugins:**
- **Clamp is gated on `min_dist > 0`** (`:3854` `if(min_dist > 0.0 && sl_point > 0.0)`). `min_dist =
  max(STOPS_LEVEL, FREEZE_LEVEL)*point`. When the broker/tester reports STOPS_LEVEL=FREEZE_LEVEL=0 the entire
  wrong-side clamp block (`:3844-3902`) is skipped, so a chandelier proposal on the WRONG side of market is
  committed verbatim.
- **Revert is gated on ONE retcode** (`:4048` `if(trail_retcode == TRADE_RETCODE_INVALID_STOPS)`). The real
  tester failures carry a different retcode, so the desync-correcting revert never runs.

The chandelier legitimately proposes `highest(closed bars[1..N]) − k·ATR` (`CChandelierTrailing.mqh:195`,
closed-bar only — NO look-ahead), which during a deep pullback can sit ABOVE market; its own `should_update`
only checks "better than current broker SL" (`:215`), never "on the correct side of market." The coordinator
is supposed to clamp/close but does neither when `min_dist=0`.

**Counted evidence (all-years archive):**
- **381 `TRAIL_BROKER_FAIL`; 381/381 KEPT the failed internal SL (0 reverts).** Gate reason stayed
  `EVERY_UPDATE` on 380 (never `INVALID_STOPS_REVERT`) → the revert path executed 0 times all-run.
- **244 `TRAIL_INTERNAL` committed an SL on the wrong side of market** (63 LONG NewSL>market, 181 SHORT
  NewSL<market) — physically impossible stops accepted into `pos.stop_loss`.
- **53/1261 (4.2%) exits report `MaxLockedR ≥ 0.5` but `Total_R ≤ 0`** — coordinator "believed" ≥0.5R was
  locked that never materialized (proxy: mixes phantom-lock inflation + legit BE give-back).
- **Walkthrough — 2022 ticket 197 (`Failed Break Long`, entry 1840.98, origSL 1836.51):** 05:51:40 chandelier
  `TRAIL_INTERNAL` SL→**1847.43** ($6.45 ABOVE entry, i.e. "+1.4R locked" at R=0.14, above the 1841.6 market);
  broker `TRAIL_BROKER_FAIL`; NO revert (next event OldSL still 1847.43); final `CurrentSL` 1847.74 never
  reached the broker either → trade rode the ORIGINAL 1836.51 broker stop to a lucky 1.5R TP.
**Mechanism of loss:** plugin reads `current_sl = PositionGetDouble(POSITION_SL)` (real broker SL,
`CChandelierTrailing.mqh:139`); coordinator `is_better` gate reads `pos.stop_loss` (phantom, `:3829`). After a
desync, every legit tighter proposal (new_sl > broker_sl but < phantom) is rejected by `is_better` → broker SL
frozen → on reversal the trade round-trips instead of locking profit.
**Fix sketch:** (i) remove the `min_dist>0` guard — clamp to a valid side even at STOPS_LEVEL=0 (≥1-tick
floor); (ii) if a proposal is wrong-side-of-market, emit a CLOSE (chandelier exit) instead of an impossible
stop; (iii) on ANY modify failure re-read `POSITION_SL` into `pos.stop_loss` (re-sync) rather than reverting
only on retcode 10016.
**Baseline impact: YES** (changes trailing outcomes; direction non-obvious → serialized re-run needed).

### 2. [BUG — MED/HIGH] Anti-stall stage-1 has no once-per-trade latch; it re-fires every tick, halving remaining lots down to min_lot.
Guard `if(m15_bars_open>=5 && profit_r_as<0.8 && !at_breakeven)` (`:2875`) relies SOLELY on `at_breakeven`
latching to stop re-entry, but the BE move only sets `at_breakeven` **`if(improves)`** (`:2919-2927`). When
`pos.stop_loss` is already ≥ `be_sl` — whether from the finding-1 phantom desync OR a legitimate post-spike
chandelier trail — `improves=false`, `at_breakeven` never latches, and the 50%-reduce partial (`:2878`) runs
again next tick.
**Counted evidence:** 15 `ANTI_STALL_PARTIAL` events over 10 trades (all correctly
`PATTERN_FAILED_BREAK_REVERSAL`, "S6: Failed Break Long"). **4/10 fired 2–3× within 20–40 s** with `BE_Time`
never stamped: 2022/197 ×3 (0.11→0.05→0.02→0.01 lots), 2022/187 ×2, 2022/54 ×2, 2022/197… . The 6 trades
where BE DID arm fired anti-stall exactly once — confirming the latch=`at_breakeven` dependence. Ticket 197's
runner was shredded to 0.01 lot before riding to the 1.5R TP → `Total_R 0.35` instead of the full runner
(~1.15R clipped on that trade).
**Failure scenario:** any FailedBreak that spikes then pulls back with SL already at/above BE gets its
remaining halved every tick to min_lot, gutting the runner.
**Fix sketch:** add a dedicated `anti_stall_reduced` bool to `SPosition`, set on the first stage-1 partial,
and gate re-entry on it (independent of `at_breakeven`).
**Baseline impact: YES** (FailedBreak cohort).

### 3. [BUG — MED] TP0 partial and anti-stall stage-1 stack on the same trade in the [tp0_distance, 0.8)R window.
Loop order runs TP0 (`:2414`) BEFORE anti-stall (`:2833`); anti-stall stage-1 guards only `!tp1_closed`
(`:2838`), not `!tp0_closed`/stage. In the overlap window (regime-scaled tp0_distance ≤ R < 0.8) both fire on
one tick: TP0 removes 15% of ORIGINAL, then anti-stall halves the remainder — a double reduction the
"reduce to 50%" design didn't intend.
**Counted evidence:** **5/10** anti-stall trades also carry a `TP0_PARTIAL` (2022/187, 2023/340, 2024/235,
2025/66, 2025/458); e.g. 2022/187: TP0 at R=0.74 (rem 0.12→0.10) then two anti-stall reduces (→0.05→0.02).
**Fix sketch:** gate anti-stall stage-1 on `stage==STAGE_INITIAL` (or `!tp0_closed`) so the two are mutually
exclusive.
**Baseline impact: YES** (small cohort).

### 4. [BUG — LOW / DETERMINISM] Partial-close ladder collapses for small compounding-derived lots, and the min_lot boundary makes exit behavior lot-quantization-sensitive.
TP0 closes `NormalizeDouble(original_lots·15%,2)`, TP1/TP2 `NormalizeDouble(remaining·vol%,2)` (ROUND); the
FILE/CREV/CONT paths use `NormalizeLots` (FLOOR, `Utils.mqh:41`) — inconsistent quantizer. Each tier caps at
`remaining − min_lot`, so a tier that can't leave ≥ min_lot is SKIPPED.
**Counted evidence:** **165/1261 (13.1%) trades have OriginalLots ≤ 0.03**; **38 at 0.01** — for these the
entire TP0/TP1/TP2 ladder is inert (can never split), the trade rides fully to the broker SL/TP.
PartialCloseCount: 622 trades =0, 304 =1, 181 =2, 154 =3.
**Determinism link (the "OriginalLots differs, price path identical" class):** `OriginalLots` is
EC/compounding-derived (MAP1 coupling 5.E), so an unrelated position's timing can bump it one 0.01 step; near
the ≤0.03 boundary that step flips how many partials fire → different realized PnL, and via the
`at_breakeven`/anti-stall coupling (finding 2) it can also change exit price/time. **Important attribution:**
in the pattern path, exit PRICE/TIME is otherwise fully price-driven and lot-INDEPENDENT — so lot
quantization is primarily a **PnL-determinism** issue and only a SECONDARY exit-divergence contributor; the
PRIMARY unrelated-trade exit divergence is finding 5 (3.B).
**Fix sketch:** skip the tiered ladder (single close) when `original_lots < 2·min_lot`; unify the quantizer
(floor everywhere).
**Baseline impact: YES if changed; small.**

### 5. [BUG — the shipped 3.B, in-lane confirmation] Chandelier regime-mult smoothing state is coordinator-global and only advances on bars where a baseline position reaches ApplyTrailingPlugins.
`m_smoothed_chand_mult`/`m_regime_hold_bars`/`m_last_regime_bar/class` (`:103-106`) are advanced inside
`ApplyTrailingPlugins` (`:3697-3719`) by whichever position is processed first that bar. `ManageOpenPositions`
early-returns on an empty book (`:2003`), and file/CREV/CONT/TMF `continue` before the advance (`:2080-2119`),
so the hold-counter **freezes on bars with no qualifying open position** and resumes stale. The
`m_regime_hold_bars>=3` hysteresis (`:3710`) then gates `effective_chand_mult` (`:3725`,→`SetMultiplier`
`:3763`) → the SET+TIMING of unrelated open positions changes THIS position's trailing multiplier / stop /
exit. Regime scaler is live in baseline (`InpEnableRegimeExit=true`; CSV `EffectiveChandelierMult` varies
3.00/3.50). This is PHASE0's root-caused shipped bug; independently confirmed here as squarely in-lane.
**Fix sketch:** derive regime-hold from `CMarketContext` history each bar (single writer/bar, book-
independent) instead of advancing it inside the per-position loop.
**Baseline impact: YES — it IS the baseline.**

---

## VERIFIED-CORRECT / INTENDED / BENIGN (ruled out, do not chase)
- **RemovePosition reverse-loop safety (`:1361-1370`): SAFE.** Forward-shift compaction touches only indices
  ABOVE the removed one (already processed in the reverse loop); only ever called from `HandleClosedPosition`
  (loop top, `:2065`) and `CloseAllPositions`' own reverse loop. No reindex hazard.
- **Just-closed-still-counted (MAP2 #7):** plugin/early/anti-stall/runner `ClosePosition` (`:3017` etc.) do
  NOT `RemovePosition` that tick; removal deferred to next tick's `PositionSelectByTicket` fail. Within-tick
  there is no re-processing (`continue` or end-of-body), so this is a cross-position ADMISSION over-count
  (lane-1 domain), not an exit-correctness bug here.
- **Runner-exit-mode system fully DEAD** (`InpEnableRunnerExitMode` const false): promotion
  (`MaybePromoteRunnerExitMode :692`), entry-lock (`InitializeRunnerExitMode :645`), runner/batched trail
  policies (`:753/:721`), and the entry-locked chandelier floor (`ShouldPreserveEntryLockedChandelierFloor
  :849` → always false) are all inert. Large dead surface — INTENDED (config), flagged for awareness.
- **Break-even is PASSIVE/incidental** (BEMover off): `at_breakeven` is only set as a side effect of a
  chandelier update that happens to reach the BE level (`:3942-3945`); there is no dedicated stop-to-BE move.
  198 `BREAKEVEN_ARMED` events all-run. PF-relevant design fact, not a bug.
- **FILE-path & CREV/CONT ignored-return broker modifies** (`:2164,:2220,:2289,:2349,:3331,:3492`) are a
  latent internal/broker desync class identical in spirit to finding 1, but **INERT in baseline** (no
  file/sleeve positions). Flag if file-signals or sleeves are ever enabled.
- **Chandelier plugin uses closed bars only** (`CChandelierTrailing.mqh:163,177,179`) — no look-ahead; the
  above-market proposals in finding 1 are legitimate chandelier math on a pullback, not a plugin bug.

## FACTS vs HYPOTHESES
**FACTS (counted/quoted):** 381/381 broker-fail no-revert; 244 wrong-side internal SL commits; RunnerExitMode
100% STANDARD; 0/1261 flat-fallback uses; 10 anti-stall trades all FailedBreak, 4 multi-fire, 5 TP0-stacked;
165/1261 lots ≤0.03 (38 at 0.01); 53/1261 MaxLockedR≥0.5 with Total_R≤0; ticket 197/187/235 walkthroughs.
**HYPOTHESES (need a serialized instrumented re-run to quantify $ / R impact):** the exact retcode the tester
returns on a wrong-side modify (only that it is NOT 10016, since 0 reverts fired); the net baseline P&L sign
of fixing findings 1–3 (each both clips winners and cuts losers); how many of the 53 phantom-lock trades are
desync-driven vs legitimate BE give-back; per-trade R clipped by anti-stall shredding beyond ticket 197.
