# EVAL-U7 — Entry engines / cascades (READ-ONLY AUDIT)

Scope: `Include/EntryPlugins/` engines (Liquidity, Session, Expansion, PullbackContinuation, + dormant router engines TrendContinuation/ReversalSweep/RangeReversion), `Include/PluginSystem/CMajorStrategyEngine.mqh`, `Include/Validation/CConfluenceScorer.mqh`. Dimensions D1/D4/D9/D10.

Status: COMPLETE. Schema = ID `ENG-NN` · Title · Severity · Confidence · Category · Location · Evidence · Impact · Check · Disposition.

Production-default ground truth (from `UltimateTrader_Inputs.mqh`, verified):
- `InpEnableMultiStrategy=false` → router + Trend/Reversal/Range engines NEVER constructed (dormant). Their `SetModeKillParams(0,0)` / `SetScorer` / `SetGateLogger` GATE wiring is all under that gate too.
- LiquidityEngine: Disp=ON (hardcoded `true` in ConfigureModes call), OBRetest=ON, FVG=**OFF**, SFP=**OFF**, divergence=OFF.
- SessionEngine: LondonBO=**OFF**, NYCont=**OFF**, SilverBullet=**OFF**, LondonClose=**OFF** → **emits ZERO signals** in prod (matches Phase-0 map). Still registered as live GMT clock (`g_sessionEngine.GetGMTHour` consumed by SFP forensic log + CSV path).
- ExpansionEngine: InstCandle=ON, CompressionBO=**OFF**; composed Vol-BO/Session-BO run only inside `IsExpansionContext()`.
- PullbackContinuation: ON; `InpPBCEnableMultiCycle=false` → re-arm path (`TryRearmEntry`) DORMANT.
- Per-mode auto-disable (EvaluateModeKill): ACTIVE on production (default min_trades=15, pf=0.9). `SetModeKillParams(0,0)` only fires under InpEnableMultiStrategy (off).

---

## Findings register

### ENG-01 — `GetLocationPenalty()` reads the FORMING D1 bar (shift 0) and feeds entry quality + confluence — D1 look-ahead/repaint
- Severity: **HIGH** · Confidence: **Confirmed** · Category: D1 (look-ahead/repaint)
- Location: `CLiquidityEngine.mqh:1517-1531` (also `CSessionEngine.mqh:1289-1303`, `CExpansionEngine.mqh:1168-1182` — identical copy in each engine).
- Evidence: `double daily_high = iHigh(_Symbol, PERIOD_D1, 0); double daily_low = iLow(_Symbol, PERIOD_D1, 0); ... position = (bid - daily_low)/daily_range; if(position>0.30 && position<0.70) return -2;`. D1 shift 0 is the **forming** daily bar; its high/low expand intrabar. The function return is added directly to `signal.qualityScore` and `signal.engine_confluence` (e.g. Liquidity Displacement `signal.qualityScore += GetLocationPenalty();` at :651-652, OB-Retest path inherits no penalty but Displacement/SFP do; Session all modes :712/761/865/916/1022/1083/1212/1261; Expansion IC :817-818, Compression :1030-1031). Consuming decision: the orchestrator ranks plugins by `qualityScore`; a mid-range −2 penalty can flip which plugin wins the single per-bar slot, and the penalty value depends on where the *forming* bar's range sits *at scoring tick*, so the same bar can score differently tick-to-tick (repaint within the bar).
- Impact: Non-deterministic ranking/quality within a forming H1 bar; in live trading the penalty is computed against a partial day range so "mid-range" classification differs from the closed-bar truth. Because the EA is H1-bar-clocked (scoring happens on the first tick of a new H1 bar) the *magnitude* is bounded (only the in-progress day's range, evaluated once per H1 bar), but `daily_low`/`daily_high` for the current day are still incomplete vs a true "today's range." Not a future-data leak (uses only data ≤ now), so it's repaint/instability rather than classic look-ahead — but it biases static edge reasoning.
- Check: confirm `iHigh(PERIOD_D1,0)` returns the live forming bar in tester (it does); confirm `GetLocationPenalty()` return is summed into `qualityScore` pre-ranking. Compare to candlestick plugins which never read forming HTF bars.
- Disposition: **Confirmed-bug** (robustness/determinism). Bounded — penalty is small (−2) and OB-Retest (the live Liquidity mode) does NOT apply it; Displacement (live) DOES.

### ENG-02 — `ScoreLiquidityLevel()` compares sweep level to the FORMING W1 bar (shift 0) — W1 look-ahead, gates Displacement+SFP entries
- Severity: **HIGH** · Confidence: **Confirmed** · Category: D1 (look-ahead/repaint)
- Location: `CLiquidityEngine.mqh:1498-1501` inside `ScoreLiquidityLevel()`.
- Evidence: `double week_high = iHigh(_Symbol, PERIOD_W1, 0); double week_low = iLow(_Symbol, PERIOD_W1, 0); if(MathAbs(sweep_level - week_low) < atr*0.5) return 4; if(MathAbs(sweep_level - week_high) < atr*0.5) return 4;`. The W1 shift-0 bar is the forming weekly candle. `ScoreLiquidityLevel()` return is a HARD GATE: Displacement requires `liq_score >= 2` (:587, :690) and SFP requires `liq_score >= 2` (:1252, :1370) before a signal can be produced. `prev_day_high/low` on the line above correctly use D1 shift **1** (:1492-1493 — closed), but the W1 read uses shift 0.
- Impact: A weekly-extreme proximity test against a still-forming weekly high/low. Early in the week the W1 range is tiny so `week_high≈week_low` and almost any sweep within `atr*0.5` scores 4 (passes the gate); late in the week the forming range is near-final. So the gate's pass-rate drifts by day-of-week from incomplete data. The decision it gates (Displacement is the **highest-priority live Liquidity mode**) is a real trade. This is a genuine forming-HTF read feeding a live entry gate.
- Check: confirm `iHigh(PERIOD_W1,0)` is the in-progress week; confirm Displacement (`m_enable_displacement` hardcoded true) and the `>=2` gate are on the live path. SFP is OFF in prod so its exposure is latent.
- Disposition: **Confirmed-bug** (look-ahead/repaint feeding a live gate). Should read W1 shift 1 like the D1 line directly above it.

### ENG-03 — SessionEngine `GetATR()` reads the FORMING bar (shift 0); inconsistent with every other engine's closed-bar ATR
- Severity: **MEDIUM** · Confidence: **Confirmed** · Category: D1/D4 (forming-bar read; determinism)
- Location: `CSessionEngine.mqh:518-524` `GetATR()` → `CopyBuffer(m_handle_atr,0,0,1,buf); return buf[0];`
- Evidence: every other in-scope engine reads closed-bar ATR `[1]`: Liquidity `atr_buf[1]` (:375-377, with explicit "Fix 6: use the CLOSED bar" comment), Expansion `atr_buf[1]` (:657-659), PBC `atr_buf[1]` (:745-746, "Phase 6.9: closed-bar ATR"), and the 3 router engines `[1]`. Session alone copies 1 bar at shift 0 and returns the forming-bar ATR, then uses it for buffer sizing, range validation (`range < atr*m_min_range_atr`), extension thresholds, and SL distances across all 5 modes.
- Impact: Forming-bar ATR repaints intrabar; Session SL/threshold math is non-deterministic within an H1 bar. **Latent only** — all 5 Session modes are OFF in production (`InpSession*=false`), so Session emits no signals; the ATR is computed but never reaches a trade. If any Session mode is re-enabled this becomes an active repaint. The bug pre-dates the "Fix 6" cleanup the other engines received.
- Check: grep confirms `buf[0]` at :523 vs `atr_buf[1]` elsewhere; confirm all `InpSession*` defaults are false.
- Disposition: **Confirmed-bug**, currently dormant (all modes off). Flag for consistency with the Fix-6 closed-bar convention.

### ENG-04 — Priority-cascade "one signal per bar" is correct, but FIRST-VALID wins, NOT best-quality within an engine
- Severity: **LOW** · Confidence: **Confirmed** · Category: D10 (cascade/ranking)
- Location: Liquidity `CheckForEntrySignal` :432-480; Session :403-453; Expansion :466-534.
- Evidence: each engine's cascade returns the first mode that yields `signal.valid` (`if(signal.valid) return signal;`). Priority order is fixed (Liq: Displacement>OBRetest>FVG>SFP; Session: LondonBO>NYCont>SilverBullet>LondonClose; Exp: IC>Compression>VolBO>SessionBO). A later, higher-qualityScore mode is never considered once an earlier mode fires. This is BY DESIGN per the file headers ("Returns at most ONE signal per bar", "priority cascade"). Cross-engine ranking still happens in CSignalOrchestrator across the engines' single outputs.
- Impact: An engine can emit a lower-quality earlier-priority signal while suppressing a higher-quality later mode on the same bar. With only 1-2 live modes per engine in prod (Liq: Disp+OBRetest; Exp: IC only) the collision surface is small. PBC is the exception — it explicitly ranks LONG vs SHORT by `qualityScore` (:815-816).
- Check: confirm fixed-order early returns; confirm orchestrator re-ranks across engines (out of U7 scope — U3).
- Disposition: **By-design**. Note for the portfolio/ranking cross-cut (WT-8).

### ENG-05 — Per-mode auto-disable (EvaluateModeKill) is permanent within a run and re-enable depends only on a 50h timer triggered by a DayType *change*
- Severity: **MEDIUM** · Confidence: **Confirmed** · Category: D2/D10 (state, auto-disable)
- Location: `EvaluateModeKill` Liquidity :484-521, Session :476-513, Expansion :610-648; re-enable in `OnDayTypeChange` Liquidity :260-275, Session :199-214, Expansion :213-228.
- Evidence: thresholds (production): PF<0.9 after ≥15 trades → disable; PF<1.1 after ≥30 → disable; expectancy<0 after ≥40 → disable. Once `auto_disabled=true`, the mode is skipped in the cascade (`!IsModeDisabled(...)` guard). Re-enable ONLY happens in `OnDayTypeChange`, and ONLY if `(TimeCurrent()-disabled_time) > 50*PeriodSeconds(PERIOD_H1)` (50 hours). `OnDayTypeChange` only runs when `SetDayType()` is called with a *different* value (`if(old != dt) OnDayTypeChange(...)`). So a disabled mode with no subsequent day-type transition stays dead for the rest of the run even after 50h elapse.
- Impact: A mode killed early (e.g. 15 trades, transient PF<0.9) can be permanently suppressed if the day-type classification stays constant — re-enable is gated on a state *transition*, not on elapsed time alone. Because the kill is keyed on small samples (15 trades) this can prune a mode on noise. Persisted across runs via ExportModePerformance/ImportModePerformance (state file), so a kill survives restarts. Trade-impacting: it changes which modes can fire.
- Check: confirm re-enable is reachable only inside `OnDayTypeChange`; confirm `SetDayType` is called each bar from OnTick (it is — :1577 `g_liquidityEngine.SetDayType(dayType)`), so transitions DO occur when day-type flips; the risk is a long stable day-type regime.
- Disposition: **Likely-by-design** (intentional auto-kill), but the re-enable coupling to a day-type transition (not pure elapsed time) is a latent trap → Needs-test on small-sample kills.

### ENG-06 — `WriteDiag` opens `StrategyDiagnostic.log` / `PullbackContinuationDiag.log` via FileOpen and (Liquidity) NEVER FileClose's the handle — handle lifecycle
- Severity: **LOW** · Confidence: **Confirmed** · Category: D3 (handle/leak) — file handle, not indicator handle
- Location: Liquidity `WriteDiag` :33-45 (handle `m_diag_handle`), opened lazily, written with `FileFlush`, but **no FileClose in Deinitialize** (`CLiquidityEngine::Deinitialize` :193-206 releases only the 2 indicator handles). PBC `WriteDiag` :180-192 but PBC `Deinitialize` :359-363 DOES `FileClose(m_diag_handle)`.
- Evidence: `m_diag_handle = FileOpen("StrategyDiagnostic.log", FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_SHARE_WRITE);` once, persisted in the member; `Deinitialize()` does not close it. The terminal closes file handles on program unload, so it's not a true leak across the EA lifetime, but the asymmetry (PBC closes, Liquidity doesn't) is a real inconsistency, and `FILE_COMMON` writes to the shared terminal common folder on every signalling bar (with FileFlush each call → I/O cost). The daily-diagnostic block at :382-413 writes once/day; SFP forensic writes are Print(), not the file handle.
- Impact: Cosmetic/robustness. No data-corruption (FileFlush after each write). Liquidity's diag handle stays open until program end; benign but untidy. The `FILE_SHARE_WRITE` + append (`FileSeek SEEK_END`) is correct for re-entrant writes.
- Check: confirm Liquidity Deinitialize has no FileClose; confirm PBC does.
- Disposition: **Confirmed-bug** (LOW) — Liquidity should FileClose `m_diag_handle` in Deinitialize for parity.

### ENG-07 — Dead config: `m_max_disp_bars` is set/configurable but the Displacement sweep window is HARDCODED `for(i=2;i<=4)` — dead member
- Severity: **LOW** · Confidence: **Confirmed** · Category: D7 (dead code)
- Location: `CLiquidityEngine.mqh` member declared :57, set to 3 in ctor :100; the two displacement loops hardcode the window: `for(int i=2;i<=4;i++) // BASELINE: original 3-bar window` (:571 bullish, :674 bearish). `m_max_disp_bars` is never read anywhere.
- Evidence: grep shows `m_max_disp_bars` only at :57 (decl) and :100 (assign); no read site. The comments at :571/:674 say "BASELINE: original 3-bar window" — the configurable member was abandoned in favor of a hardcoded 3-bar (indices 2,3,4) scan.
- Impact: None functional (cosmetic dead member). Misleading: a reader/tuner might think changing `m_max_disp_bars` widens the sweep search; it does nothing.
- Check: grep read-sites of `m_max_disp_bars` (none).
- Disposition: **By-design / dead** (LOW). Remove member or wire it.

### ENG-08 — CConfluenceScorer tier thresholds are non-monotone (8/7/6/7) → SETUP_B is UNREACHABLE; scorer is DORMANT in prod
- Severity: **LOW** (prod) / would be MEDIUM if router enabled · Confidence: **Confirmed** · Category: D10 (scoring/ranking)
- Location: `CConfluenceScorer.mqh` defaults :81-87 (`m_points_b=7` == `m_points_a=7`), tier cascade :283-287, self-diagnostic warning :114-124.
- Evidence: tier mapping is `if(points>=aplus)A+; if(>=a)A; if(>=bplus)B+; if(>=b)B;`. With A=7 and B=7, any `points>=7` already returns SETUP_A before the B test, so SETUP_B (the 0.6% tier) is structurally unreachable. The code itself prints a WARNING about exactly this (:118-123) and deliberately does NOT clamp/reorder. ALSO: max achievable raw score is 9 (header says 9, axes sum 1+2+2+1+1+1+1), and the L3 HARD GATE (:189-190) returns SETUP_NONE unless a fresh+directional BOS/CHoCH OR `GetSMCConfluenceScore(dir) >= 25`. The scorer is ONLY wired under `InpEnableMultiStrategy` (`SetScorer` calls :741/747/753/766), which is false → **the scorer never runs in production**; legacy plugins use the evaluator path (`routed_engine=false`).
- Impact: Dormant in prod (no router). If multi-strategy is ever enabled, SETUP_B can never be assigned — the 0.6% risk tier is dead, and the live A/A+/B+ thresholds (8/7/6) govern. This is documented/intentional per the in-code warning.
- Check: confirm `SetScorer` only under InpEnableMultiStrategy; confirm Configure() is called with Inp* (8/7/6/7) at :729-732.
- Disposition: **By-design** (warned in code), dormant. Flag for the data-contradiction resolution (plan §4b: scorer thresholds vs evaluator B=7).

### ENG-09 — Expansion composed Vol-BO/Session-BO sub-strategies self-certify `engine_confluence=70/65` to pass the scorer spine — confluence inflation
- Severity: **LOW** (prod) · Confidence: **Likely** · Category: D10/D9 (confluence semantics)
- Location: `CExpansionEngine.mqh:512-513` (`if(signal.engine_confluence<=0) signal.engine_confluence=70;`) and :527-528 (`=65;`), inside the `IsExpansionContext()` composed-mode block :499-534.
- Evidence: when a composed sub-strategy returns a valid signal with `engine_confluence<=0`, the engine fabricates a 70/65 value and tags `requiresConfirmation=false`. Comment admits this is to "ensure engine_confluence > 0 so the scorer gate passes." HOWEVER, Phase 2.3 (CConfluenceScorer :173-178) deliberately STOPPED trusting self-certified `engine_confluence` for the spine — the scorer now requires the *objective* `ctx.GetSMCConfluenceScore(dir) >= 25`. So the inflation no longer buys past the spine (when the scorer is wired). But the inflated value still flows to telemetry/`engine_confluence` consumers downstream and, on the legacy path (scorer NULL, prod), is the only confluence the signal carries.
- Impact: Composed Vol-BO/Session-BO signals carry a fabricated 65-70 confluence rather than a measured one. Reaches CPositionCoordinator/telemetry. Bounded (only fires inside expansion-context AND when the sub-strategy doesn't set its own confluence). InstCandle (the live Expansion mode) sets `engine_confluence=70` directly too (:811) — also a fixed self-cert.
- Check: confirm sub-strategies are reached only inside `IsExpansionContext()`; confirm `GetSMCConfluenceScore` is the real spine when scorer wired.
- Disposition: **Likely-by-design** (acknowledged in comments); confluence-inflation is cosmetic now that the spine is objective. LOW.

### ENG-10 — Compression-BO squeeze-bar counter persists across days/regimes with only a per-bar increment guard — stale-state release risk
- Severity: **LOW** (prod: Compression OFF) · Confidence: **Likely** · Category: D2 (state-leakage)
- Location: `CExpansionEngine.mqh:927-1130` (`m_squeeze_bars`, `m_prev_squeeze`, `m_last_squeeze_bar`).
- Evidence: `m_squeeze_bars` increments once per bar while squeezed (:931-935 guards per-bar via `m_last_squeeze_bar != iTime(...,0)`), and the release branch fires a breakout when `m_prev_squeeze && m_squeeze_bars >= m_compression_min_bars`. The counter resets to 0 on a non-squeeze bar that ISN'T a release (:1126) and after a signal. But there is no time-gap / new-session reset: a squeeze that spans a weekend gap or a day-type flip carries its accumulated count. `iTime(PERIOD_H1,0)` (forming bar) is used only as the per-bar de-dupe key (correct usage — bar identity, not a price read).
- Impact: A multi-day squeeze can release into a breakout whose `m_squeeze_bars` count includes stale pre-gap bars. Compression-BO is OFF in production (`InpExpCompressionBO=false`) so dormant. The `iTime(...,0)` use here is NOT look-ahead (identity key only).
- Check: confirm `InpExpCompressionBO=false`; confirm no session/gap reset of `m_squeeze_bars`.
- Disposition: **Likely-by-design**, dormant. LOW.

### ENG-11 — Router engines (Trend/Reversal/Range) are fully DORMANT (never constructed) but are clean on closed-bar discipline
- Severity: **LOW** (dormant) · Confidence: **Confirmed** · Category: D7 (dead/dormant) + D1 (verified clean)
- Location: constructed only inside `if(InpEnableMultiStrategy)` :726-768 (default false). CTrendContinuationEngine ATR `atr_buf[1]` (:386), CReversalSweepEngine `GetClosedATR` returns `buf[1]` (:68), CRangeReversionEngine `GetClosedATR` uses `CopyBuffer(...,1,1,...)` shift-1 (:113-115). All three early-return when `!m_isEnabled` (Trend :357, Reversal :355, Range :338), and the router only sets `m_isEnabled` via `SetActivationWeight(w>0)`.
- Evidence: these three engines were written with explicit closed-bar ATR (comments cite "trap T1"), unlike the older Session GetATR forming-bar read (ENG-03). They are the cleanest engines in the folder but never run in prod.
- Impact: None (dormant). Listed per scope requirement to flag the default-off router engines.
- Check: confirm `InpEnableMultiStrategy=false`; confirm `new C{Trend,Reversal,Range}...` is inside that gate.
- Disposition: **By-design / dormant**. No action.

### ENG-12 — Cross-engine coupling: CLiquidityEngine references global `g_sessionEngine` before it is declared/included — fragile ordering (SFP path, dormant)
- Severity: **LOW** · Confidence: **Confirmed** · Category: D7/D8 (architecture coupling)
- Location: `CLiquidityEngine.mqh:1176-1177` (`g_sessionEngine.GetGMTHour(TimeCurrent())`); include order `UltimateTrader.mq5:65` (Liquidity) precedes `:66` (Session) and the global decl `:151`.
- Evidence: Liquidity's SFP forensic logging calls the EA-global `g_sessionEngine`. Because MQL5 parses all globals before compiling method bodies this compiles, but it is a hidden dependency from a self-contained engine include onto an EA-level global declared two includes later. Guarded `(g_sessionEngine != NULL ? ... : 0)`. The SFP mode is OFF in prod (`InpLiqEngineSFP=false`) so this line is unreached.
- Impact: Compiles today; fragile to include-order/refactor changes; violates plugin self-containment. Dormant (SFP off).
- Check: grep `g_sessionEngine` in CLiquidityEngine.mqh (:1176); confirm include order.
- Disposition: **Confirmed** design smell, LOW, dormant.

### ENG-13 — Displacement SL uses `MathMin(pattern_sl, min_sl_level)` so the MINIMUM-SL floor always WIDENS the stop — SL-anchor math is correct but min-SL is a floor not a clamp
- Severity: **LOW** · Confidence: **Confirmed** · Category: D9 (SL/numeric)
- Location: Liquidity Displacement bull :625-627, OB-Retest bull :831-833, FVG :1016-1018, SFP :1284-1286 (and bearish mirrors with MathMax).
- Evidence: bull: `pattern_sl = sweep_extreme - buffer; min_sl_level = entry - m_min_sl_points*_Point; sl = MathMin(pattern_sl, min_sl_level);`. `MathMin` of two below-entry prices picks the LOWER (further) stop → the min-SL acts as a *minimum distance floor* (SL is at least `m_min_sl_points` away), correct for the stated intent. Bear mirrors with `MathMax` (higher/further). No div-by-zero (risk = |entry-sl| > 0 by construction). TP = entry ± risk*RR is sound. R:R is fixed-labelled (2.5/3.0) and matches geometry. This is CORRECT — logged as a positive verification, not a bug.
- Impact: None — SL geometry is sound across all 4 Liquidity modes and Session/Expansion modes (same pattern). Flag: the min-SL floor can override a tight structural stop, slightly worsening R:R vs the structural ideal, but that's the intended risk-floor behavior.
- Check: trace MathMin/MathMax direction vs entry for each mode.
- Disposition: **By-design / verified-correct**. No action.

### ENG-14 — FVG-mitigation cooldown keyed on `iTime(PERIOD_H1,0)` (forming-bar timestamp) — correct, but FVG mode is OFF in prod
- Severity: **LOW** · Confidence: **Confirmed** · Category: D2 (state) — verified clean
- Location: `CLiquidityEngine.mqh:943-948` and set at :1045/:1121.
- Evidence: `current_bar = iTime(_Symbol,m_timeframe,0); bars_since = (current_bar - m_last_fvg_signal_time)/PeriodSeconds; if(bars_since < m_fvg_cooldown_bars) return;`. Uses the forming bar's OPEN timestamp as a bar-identity key (not a price read) — correct, deterministic per bar. `m_fvg_cooldown_bars=8`. FVG mode is OFF in prod (`InpLiqEngineFVGMitigation=false`).
- Impact: None — verified-clean cooldown logic; dormant anyway.
- Disposition: **Verified-correct**, dormant. No action.

---

## Per-engine mode tables (mode → enabled-by-default? → decides on CLOSED bar?)

### CLiquidityEngine (priority cascade, ≤1 signal/bar; engine_id telemetry=0)
| Mode (priority) | Enabled default? | Decides on closed bar? | Notes |
|---|---|---|---|
| MODE_DISPLACEMENT (P1) | **YES** (hardcoded `true`) | Pattern bars `[1]/[2..4]` CLOSED; ATR `[1]` CLOSED; entry = live ASK/BID. BUT gated by `ScoreLiquidityLevel` which reads **W1 shift 0 (forming)** → ENG-02 look-ahead, and `GetLocationPenalty` reads **D1 shift 0 (forming)** → ENG-01. | Highest priority; the dominant live Liquidity signal |
| MODE_OB_RETEST (P2) | **YES** | bar `[1]` CLOSED; ATR `[1]`; entry live; SMC/BOS from context. No GetLocationPenalty applied. | Cleanest live mode |
| MODE_FVG_MITIGATION (P3) | **NO** (`InpLiqEngineFVGMitigation=false`) | bar `[1..3]` CLOSED; cooldown on bar-identity (clean) | Dormant |
| MODE_SFP (P4) | **NO** (`InpLiqEngineSFP=false`) | fractal bars `[5..25]`, signal `[1]` CLOSED; tick-vol `[1..11]`; ScoreLiquidityLevel W1-forming gate (ENG-02); references g_sessionEngine (ENG-12) | Dormant |

### CSessionEngine (time-gated by GMT hour; engine_id telemetry=1) — **emits ZERO signals in prod**
| Mode | Enabled default? | Decides on closed bar? | Notes |
|---|---|---|---|
| MODE_LONDON_BREAKOUT | **NO** | bar `[1]` CLOSED close/open vs Asian range; **ATR via GetATR()=forming shift 0 (ENG-03)** | Asian range from M15; all OFF |
| MODE_NY_CONTINUATION | **NO** | bar `[1]` CLOSED; forming-bar ATR (ENG-03) | OFF |
| MODE_SILVER_BULLET | **NO** | M15 bars `[1..8]`; entry depends on live BID inside FVG; forming-bar ATR (ENG-03) | OFF |
| MODE_LONDON_CLOSE | **NO** | bar `[1]` CLOSED; day extreme from M15 today; forming-bar ATR (ENG-03) | OFF |
| (Asian range build, hr<7) | n/a (tracking only) | M15 GMT-bucketed | No signal, just state |
Engine remains REGISTERED as the live GMT clock (`GetGMTHour` consumed by SFP forensic log + CSV signal path), so it cannot be deleted even though it signals nothing.

### CExpansionEngine (priority cascade; major-engine base; telemetry id=2)
| Mode (priority) | Enabled default? | Decides on closed bar? | Notes |
|---|---|---|---|
| MODE_PANIC_MOMENTUM | REMOVED (Phase D) | n/a | Dead concept, deleted |
| MODE_INSTITUTIONAL_CANDLE (P2) | **YES** | 2-state machine on bar `[1]` CLOSED; ATR `[1]` CLOSED; entry live | The live Expansion signal; self-certs engine_confluence=70 (ENG-09) |
| MODE_COMPRESSION_BO (P3) | **NO** (`InpExpCompressionBO=false`) | BB/Keltner buffers `[1]`; squeeze counter (ENG-10); `iTime(0)` = bar-id key only | Dormant |
| Vol-BO (P4, composed) | only if `IsExpansionContext()` | sub-strategy's own closed-bar logic (U6) | engine_confluence fabricated 70 (ENG-09) |
| Session-BO (P5, composed) | only if `IsExpansionContext()` | sub-strategy's own logic (U6) | engine_confluence fabricated 65 (ENG-09); SessionBreakout also separately DEAD-registered when SessionEngine on |

### CPullbackContinuationEngine (no ModePerformance; not a CMajorStrategyEngine)
| Path | Enabled default? | Decides on closed bar? | Notes |
|---|---|---|---|
| First-cycle TryDirection (LONG) | **YES** | swing/pullback over CLOSED bars `[1..lookback]`; reclaim on `[1]`; ATR `[1]` CLOSED (Phase 6.9 fix); entry live ASK | Ranks LONG vs SHORT by qualityScore (:815) |
| First-cycle TryDirection (SHORT) | **YES** | same, closed bars | EA's main short source among engines |
| TryRearmEntry (multi-cycle) | **NO** (`InpPBCEnableMultiCycle=false`) | reclaim on `[1]`; SL re-derived from CLOSED bars (Phase 6.9 Entry-Pullback-2 fix); `UpdateCycleState` reads `iHigh/iLow(H1,1)` CLOSED + live BID for rearm depth | Dormant; rearm-depth uses live bid (acknowledged) |

### Router major engines (DORMANT — `InpEnableMultiStrategy=false`, never constructed)
| Engine | Constructed in prod? | Closed-bar ATR? | Notes |
|---|---|---|---|
| CTrendContinuationEngine | NO | YES `atr_buf[1]` | `!m_isEnabled` early-return; clean |
| CReversalSweepEngine | NO | YES `GetClosedATR→buf[1]` | clean |
| CRangeReversionEngine | NO | YES `CopyBuffer(,1,1,)` | clean |
| CConfluenceScorer | NO (SetScorer under gate) | n/a | non-monotone tiers → SETUP_B dead (ENG-08) |
| CMajorStrategyEngine (base) | only via Expansion (always) + dormant 3 | n/a | EmitGateScore/SetGateLogger only fire under InpEnableMultiStrategy |

---

## Summary of dimensions
- **D1 look-ahead/repaint:** ENG-01 (D1 forming → quality/confluence, live for Displacement), **ENG-02 (W1 forming → Displacement/SFP HARD GATE — most material)**, ENG-03 (Session forming ATR, dormant). `iTime(...,0)` uses in Expansion/PBC/FVG are bar-identity keys, NOT price look-ahead (verified clean).
- **D4 array-bounds/Copy short-reads:** all engines guard every `Copy*` with `< n` early-return; ATR copies fetch ≥2 bars before reading `[1]`. No short-read OOB found. (PBC `DetectPullback` loops bound by `i < ArraySize(...)`.)
- **D9 numeric/SL/RR:** ENG-13 — SL-anchor math (MathMin/MathMax floor) verified correct across all live modes; TP=entry±risk*RR sound; no div-by-zero (risk>0 by construction; candle_range/daily_range guarded `>0`).
- **D10 orchestration/cascade:** ENG-04 (first-valid-wins within engine, by-design), ENG-05 (auto-disable + transition-gated re-enable), ENG-08 (scorer tiers, dormant), ENG-09 (confluence self-cert, cosmetic now).
- **Telemetry FileOpen:** ENG-06 — Liquidity `WriteDiag` never FileClose's `m_diag_handle` (PBC does); benign, FileFlush'd, FILE_COMMON.

## Most material for synthesis
1. **ENG-02** (HIGH): W1 forming-bar read gates the live Displacement entry — genuine look-ahead/repaint feeding a real trade decision. Fix = W1 shift 1.
2. **ENG-01** (HIGH): D1 forming-bar location penalty feeds qualityScore ranking for live Displacement (and dormant Session/Expansion). Repaint/determinism.
3. **ENG-05** (MEDIUM): small-sample (15-trade) auto-kill with transition-gated re-enable can permanently prune a live mode on noise.
