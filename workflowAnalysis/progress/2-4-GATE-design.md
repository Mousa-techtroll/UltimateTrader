# Phase 2.4-GATE — BINDING DESIGN + EXECUTION SPEC (tier-threshold re-derivation)

> **Author:** stok (independent trading analyst). **Status:** DESIGN READY FOR mt5 EXECUTION (no backtest run here, no code edited here).
> **Goal (verbatim from the gate mandate):** re-derive A+/A/B+/B `InpPoints*` thresholds on the NEW max-9 per-signal axis-breakdown distribution over 2019–2026, with **A+ = genuine top decile of realized expectancy**. Do **NOT** carry the v18 `InpPoints*` (8/7/6/7) forward. stok sign-off required before any Iter-3 engine validation (3.7–3.10).

This note resolves the five open methodology questions **bindingly**. mt5 executes exactly what Section 3 specifies; mt5 does not re-litigate the ordering, density plan, or threshold formula.

---

## 0. Why this gate exists (one paragraph, so the spec is not applied blind)

The scorer (`CConfluenceScorer::Score`, `Include/Validation/CConfluenceScorer.mqh`) maps a 0–9 raw point total to a tier via a strict cascade:
`points >= m_points_aplus → A+`, else `>= m_points_a → A`, else `>= m_points_bplus → B+`, else `>= m_points_b → B`, else NONE (lines 199–203).
The live `Inp*` thresholds are **8 / 7 / 6 / 7** (`UltimateTrader_Inputs.mqh:279–282`). Two facts make these invalid for the post-2.4 scorer:

1. **The raw ceiling dropped 10 → 9.** Axis maxes are now HTF-draw 1 + prem/disc 2 + entry-zone 2 + sweep 1 + confirm 1 + flow 1 + killzone 1 = **9** (the `eq>0` sub-point on axis 1 was dropped in 2.4; the `if(points>10) points=10` clamp at :195 is now unreachable). v18's 8/7/6/7 was calibrated on a max-10 distribution.
2. **The distribution shape AND density shifted.** 2.2 (fresh+direction spine), 2.3 (objective spine + expansion-only killzone), and 2.4 (D1-IPDA(20) location de-correlated from the H1-swing SL) all change which signals score and what they score. On gold's structural uptrend the D1-IPDA-20 range sits in **discount** for most pullback bars, so the +2 long-discount axis fires more often → the high end of the distribution is denser and long-skewed.

Carrying 8/7/6/7 forward would mis-tier every engine signal at a now-unreachable ceiling and silently down-tier/mis-size A+. The gate re-derives the four cut points on the **realized-expectancy-ranked** post-2.4 distribution.

Also note the v18 **B-tier-unreachable artifact**: `InpPointsBSetup = 7 == InpPointsASetup = 7`, so `points>=7` always returns A before the B test (Inputs:282 comment confirms this was the intentional `$6,140` filter). The gate decides B-reachability consciously (Section 3.5), per the deferred fix-2.8 note.

---

## 1. ORDERING DECISION (the critical one) — **OPTION (b): REORDER. Land 3.1–3.6 FIRST, then the GATE, then 3.7–3.10.**

**Decision: (b) — engine-correctness fixes 3.1–3.6 land and commit BEFORE the GATE derivation run; the GATE then derives on the corrected-engine distribution; then 3.7–3.10 validate per engine.**

### Justification (binding)

- **The distribution the GATE fits must be the distribution Iter-3 will be judged on.** 3.1–3.6 *change which signals fire and how they score*:
  - **3.1** (S6 gets its range-box) changes the S6/reversal signal population (box-edge sweeps vs degraded PDH/PDL).
  - **3.2 / fix 3.4** (3-mode split: `MODE_RUBBER_BAND`, `MODE_FAILED_BREAK`, `MODE_SFP`) directly changes the **killzone axis 7** outcome — axis 7 awards +1 only for expansion/breakout modes (`CConfluenceScorer.mqh:187–193`); the mode a reversal signal carries decides whether it gets that point, which moves its raw score across a tier boundary.
  - **3.4 / fix 3.5** (`InpTrendSwingLookback=10`) changes trend-continuation SL geometry → entry-zone (axis 3) and prem/disc (axis 2) membership shift.
  - **3.5 / fix 3.6** (HTF-uptrend SHORT veto, hard-ON) **removes negative-expectancy gold shorts from the population entirely.** This is the single most important reason to reorder: if the GATE derives a top-decile A+ threshold on a distribution that still contains shorts the veto will later delete, the realized-expectancy ranking is contaminated by trades that cannot occur in production. The veto must be live so the GATE never sees a vetoed short.
  - **3.6 / fix 3.2** (DAY_DATA news-flat) removes signals on news days; those signals' realized R must not pollute the expectancy ranking.
- **Feasibility is given.** As the mandate notes, 3.1–3.6 are small correctness fixes that **do not depend on the thresholds** — none of them reads `InpPoints*`. So landing them first creates no circular dependency. The dependency runs one way: thresholds depend on the corrected engine population, not vice-versa.
- **Option (a) is rejected** (GATE now, re-check after 3.1–3.6): it would derive thresholds twice and, worse, the "re-check" has no defined acceptance — if the second distribution disagrees with the first, which thresholds ship? It also wastes a full 2019–2026 derivation run on a population we already know is wrong (contains vetoed shorts, mislabeled modes, NULL-box S6). Deriving on a known-stale distribution then hoping the re-check is benign is not a gate, it is a guess.
- **Hybrid is rejected** as unnecessary complexity: there is no subset of 3.1–3.6 that is safe to defer past the GATE. Every one of the six measurably moves the distribution (mode label → axis 7; veto → population; swing-lookback → axes 2/3; news-flat → population; S6 box → population). The clean line is "all correctness in, then derive."

### One binding exception (sequencing detail, not a hybrid)

**3.6 / fix 3.2 (DAY_DATA news-flat) is GATED by the CSessionEngine GMT-clock + calendar-reliability prerequisite** (Risk-Register item 1; bug-fix-plan Iter-3 hard gate). `CalendarValueHistory` is unreliable/empty in the Strategy Tester. Two binding sub-rules:

1. mt5 must land 3.6 with its **mandatory graceful-degradation static-blackout fallback** so it is functional (not throwing, not silently no-op) in the tester BEFORE the GATE run. The GATE run prints the calendar-availability count on init (per the fix-3.2 spec) so we know which path was active.
2. If, on the GATE derivation run, the tester reports the calendar is empty AND the static fallback fires on the documented HIGH-impact USD/XAU dates (FOMC/CPI/NFP/PPI/PCE), that is acceptable — the GATE derives on the static-blackout population. If 3.6 cannot be made functional in the tester at all (neither calendar nor static fallback removes news-day signals), **3.6 is PARKED at the toggle level (`InpEnableNewsFlat=false`) for the GATE run only, recorded as a known caveat**, and re-checked when the GMT-clock prereq is settled. News-day signals are then flagged in the log (Section 3.3) so they can be excluded analytically even if not removed at runtime. This is the only place the GATE tolerates a not-yet-functional 3.x fix, and it is governed by an explicit, pre-existing hard gate.

### Updated phase sequence

```
... 2.4 (COMMITTED) → 3.1 → 3.2 → 3.3 → 3.4 → 3.5 → 3.6 → [2.4-GATE derivation+sign-off] → 3.7 → 3.8 → 3.9 → 3.10 ...
```

The 2.4-GATE row in 00-STATUS.md moves to sit **after 3.6 and before 3.7**. 3.1–3.6 keep their own per-phase QA (compile clean + the byte-identity / fresh-validation gate each already carries). The GATE is the explicit checkpoint that 3.7–3.10 must not start before.

---

## 2. SIGNAL-DENSITY HANDLING PLAN (so the top-decile A+ threshold is statistically real)

The original audit found the OLD engines starved (many fired 0 trades). The GATE's distribution must be **thick enough that "top decile of realized expectancy" is a real boundary, not 2 trades.** Binding plan:

### 2.1 What to enable for the DERIVATION run

- **`InpEnableMultiStrategy = true`** and **all four** `InpEnableEngineTrend / Reversal / Range / Expansion = true`. The GATE needs the full cross-engine score distribution because `InpPoints*` is **one shared threshold set** consumed by all routed engines — it is not per-engine. Deriving on a subset of engines would set a global cut point on a partial distribution.
- **All sub-paths within each engine ON** for the derivation (FVG re-entry + OB-retest + Pullback in trend; S6 + Liquidity-Sweep + Rubber-Band in reversal; BB-MR + OB-retest + FVG-mitigation in range; Displacement + IC + Compression + Panic in expansion). The per-sub-path KILL decisions belong to 3.7–3.10, NOT to the GATE. The GATE wants the **widest honest population** so the expectancy ranking has resolution; 3.7–3.10 then prune.
- This is consistent with the architecture: the engines emit **at most one signal per bar via the priority cascade** with per-mode auto-disable. For the GATE derivation, **per-mode auto-disable must be held OFF** (or its threshold set so it cannot trip mid-run) so a transient early drawdown does not silently shrink the population we are trying to characterize. mt5 confirms the auto-disable toggle/threshold used.

### 2.2 Gate relaxation FOR THE DERIVATION ONLY (then re-tighten)

The hard floors that can starve the distribution before it reaches the scorer are the SMC confluence reject and the spine floor. For the derivation run **only**:

- **Hold `InpSpineMinConfluence = 25`** (the committed 2.3 default). Do **NOT** relax it further for the derivation. Rationale: 25 is already below the validator's 40 hard-reject and below the configurable `m_smc_min_confluence` default 60, so it is necessary-but-weaker — it is not the binding constraint. Relaxing it would admit no-spine signals that production will never trade, contaminating the expectancy ranking exactly like un-vetoed shorts would.
- **Hold `m_smc_min_confluence` / the validator SMC reject at its production default (60 configurable; 40 hard floor).** Do not relax. Same contamination argument: the GATE must rank trades production can actually take.
- **The ONE permitted relaxation:** the GATE may run with the **B-tier and below admitted for LOGGING** even though they will not all ship as tradeable. Concretely: set a **temporary derivation threshold set of `InpPointsAPlusSetup=9, InpPointsASetup=8, InpPointsBPlusSetup=4, InpPointsBSetup=3`** (i.e. admit everything from raw-3 up so every spined signal that reaches the scorer is logged with its tier-as-scored AND its axis breakdown). This is **not** a behavioral relaxation of the spine/SMC floors — those still gate. It only widens which scored signals get *logged and traded* so the realized-R-by-raw-score table is populated across the whole 3–9 range. The four production thresholds are then re-derived FROM that table (Section 3.4) and **re-applied + re-tightened** before 3.7–3.10.

> **Binding principle:** we relax *what gets logged/recorded*, never *what counts as a valid spined signal*. The spine and SMC floors stay at production defaults so every logged trade is one production could take. This keeps the expectancy ranking honest.

### 2.3 Minimum sample size per bucket

- **Per raw-score bucket (integer 3..9): require ≥ 30 realized closed trades** to treat that bucket's mean realized R as a usable estimate. Buckets with < 30 trades are flagged THIN and merged upward into the next-higher populated bucket for the cumulative-from-top expectancy calc (Section 3.4), never used as a standalone cut point.
- **A+ top-decile boundary: require the trades AT-OR-ABOVE the chosen A+ cut to total ≥ 50 realized trades** over the full 2019–2026 window. If the genuine top decile is < 50 trades, A+ is set at the lowest raw score whose at-or-above population reaches 50 (i.e. we widen A+ minimally to reach significance rather than certify a 12-trade "edge").
- **Total spined-and-traded population over 2019–2026: target ≥ 400 trades** for the derivation to be considered adequately dense. (For scale: the v18 locked core cited A+ 544 + A 245 ≈ 789 graded trades across the multi-year reference; ≥400 on the post-fix engine population is a reasonable adequacy bar.)

### 2.4 Fallback if density is inadequate

If, after enabling all engines/sub-paths with floors held at default, the total spined-and-traded population over 2019–2026 is **< 200 trades**, OR fewer than **4 of the 7 integer buckets (3..9) reach ≥30 trades**, the distribution is too thin to set a defensible top-decile A+ threshold. Then:

1. **Do NOT relax the spine/SMC floors to manufacture density** — that would set thresholds on trades production cannot take (the cardinal error this plan rejects).
2. **The thin distribution is itself a finding.** Report it to stok. A scorer that, with all four engines and all sub-paths ON and floors at default, produces < 200 graded trades over 7 years on gold H1 is telling us the corrected engines are **structurally low-frequency** — which is a direct, partial answer to the Iter-3 question "do the engines have an edge." (Density inadequacy ↔ Section 5 kill path.)
3. **Interim threshold:** if a derivation must still ship to unblock 3.7–3.10 on a thin distribution, set **conservative thresholds biased toward fewer A+** (A+ at raw 8–9 with monotonicity per 3.4), explicitly labeled PROVISIONAL, and require 3.7–3.10 to re-confirm per-engine that the A+ population is non-empty and positive-expectancy before any engine is certified ON. A thin GATE never certifies an engine by itself.

---

## 3. EXACT EXECUTION SPEC FOR mt5

### 3.1 Config (.set) for the DERIVATION run

Run on **XAUUSD+ H1, Model = 1 (1-min OHLC)** — the same mode all Phase-1/2 A/B used, so results compare to the locked anchors. Two windows (Section 3.6). Deposit 10000 USD, Leverage 100 (matches `backtest_runner.sh`).

Derivation `.set` (a NEW file, e.g. `UltimateTrader_GATE_derive.set`, so the production `.set` is never mutated):

```
InpEnableMultiStrategy   = true
InpEnableEngineTrend     = true
InpEnableEngineReversal  = true
InpEnableEngineRange     = true
InpEnableEngineExpansion = true

InpSignalSource          = (PATTERN/engine path; NOT FILE)   ; engines must be the signal source
InpSymbolProfile         = 0   (gold)
InpBOSFreshnessBars      = 8    ; HELD at default (do NOT sweep at the GATE — see Section 4)
InpSpineMinConfluence    = 25   ; HELD at default (do NOT relax)
InpDealingRangeD1Lookback= 20   ; HELD at default

; DERIVATION-ONLY logging-width thresholds (admit raw>=3 so the whole 3..9 range is logged+traded):
InpPointsAPlusSetup      = 9
InpPointsASetup          = 8
InpPointsBPlusSetup      = 4
InpPointsBSetup          = 3
InpPointsBSetupOverride  = -1

; HTF short veto (fix 3.6): hard-ON by design, no toggle — confirm it is compiled in and active.
; News-flat (fix 3.2): InpEnableNewsFlat as landed in 3.6 (calendar or static fallback). See Section 1 exception.
; Per-mode auto-disable: HELD OFF (or threshold set unreachable) for the derivation run.
```

All other inputs at production defaults. mt5 records the exact decoded `.set` (UTF-16LE → iconv) in the GATE phase log so the run is reproducible.

### 3.2 Per-signal axis-breakdown LOGGING mt5 must add

The CSV infrastructure **already carries the join key and the realized outcome** — the only new element is the **7-axis breakdown**. Specifically:

- The **Candidates CSV** (`CTradeLogger.mqh:435–436`, written via `LogCandidateDecision`) already logs per-scored-signal: `SignalID, BarTime, Plugin, Pattern, Side, Regime, Session, DayType, ATR, ADX, MacroScore, ValidationStage, Decision, Reason, SMCScore, Quality, QualityScore (the 0–9 raw total), BaseRiskPct, PendingConfirmation, Winner`.
- The **TradeEvents CSV** (`CTradeLogger.mqh` main `m_csv_handle`, EXIT rows at :207/:757) already carries per-trade: `SignalID, Pattern, Direction, Quality, EngineName, EngineMode, DayType, Confluence, EntryTime, RiskPct, ... PnL_R, Total_R` (the realized R outcome) — because `pos.signal_id`, `pos.setupQuality`, `pos.major_engine`, `pos.engine_mode` survive onto the open position.
- **JOIN KEY = `SignalID`** (present in BOTH the Candidates row and the TradeEvents EXIT row). This is how "this trade's axis breakdown" joins to "this trade's realized R." No new key is needed.

**CRITICAL plumbing gap the logging MUST work around (confirmed at source):** scored-but-rejected signals are **dropped before any Candidates row is written.** Each engine sets `candidate.valid = (tier != SETUP_NONE)` (e.g. `CTrendContinuationEngine.mqh:181`), and the orchestrator does `if(!signal.valid) continue;` (`CSignalOrchestrator.mqh:546`) — so a signal that scores raw 0–2 (→ SETUP_NONE) **never produces a candidate row at all.** The seven `AuditCandidate` call sites also log **hardcoded `SETUP_NONE, score=0`** at validator/volume/SMC rejects, so they cannot carry a real axis breakdown either. This means a Candidates-CSV-only log is **truncated at the bottom of the distribution** and cannot see the full 3..9 shape, let alone 0..2. The GATE log must therefore be captured **inside the scorer at the moment of scoring, before the valid-drop**, not at the orchestrator's surviving-candidate audit.

**What mt5 MUST add:**

1. **Expose the 7 per-axis sub-points from `CConfluenceScorer::Score`.** Today `Score()` returns only the tier and `out_score` (the summed 0–9). Add an out-parameter struct (e.g. `SScoreAxes`) or 7 out-ints capturing each axis's awarded points at the moment of scoring:
   - `ax1_htfdraw` (0–1), `ax2_premdisc` (0–2), `ax3_entryzone` (0–2), `ax4_sweep` (0–1), `ax5_confirm` (0–1), `ax6_flow` (0–1), `ax7_killzone` (0–1).
   This is additive (a new overload or an out-param defaulted off) so the production-path byte-identity invariant for the scorer is preserved when the GATE logging is compiled but the router is OFF.
2. **Emit a dedicated GATE per-signal log row from INSIDE the scoring path — for EVERY signal the scorer scored, INCLUDING the SETUP_NONE / raw 0–2 drops.** Do NOT rely on the existing `AuditCandidate`/Candidates path (it is truncated by the valid-drop, per the gap above). The cleanest hook is a new `CTradeLogger::LogGateScore(signal_id, bar_time, side, engine_name, engine_mode, raw_score, tier, ax1..ax7, is_news_day, htf_short_veto_applied)` called right where each engine does `m_scorer.Score(...)` and stamps `setupQuality`/`qualityScore` (`CTrendContinuationEngine.mqh:178–180`, `CReversalSweepEngine.mqh:223–227`, `CRangeReversionEngine.mqh:173–175`, `CExpansionEngine.mqh:597–601`) — i.e. before `candidate.valid` is set and before the orchestrator can `continue`-drop it. Write to a new `Logs/UltTrader_GateScores_<sym>_<window>.csv` (UTF-16LE like the others). The `SignalID` written here is `signal.signal_id` (the same `BarTime|Plugin|Side|seq` built at `CSignalOrchestrator.mqh:591`), so it **joins to TradeEvents `SignalID`** for the realized-R outcome on the signals that actually traded.
   - Columns: `SignalID, BarTime, Side, EngineName, EngineMode, RawScore, Tier, Ax1_HTFDraw, Ax2_PremDisc, Ax3_EntryZone, Ax4_Sweep, Ax5_Confirm, Ax6_Flow, Ax7_Killzone, IsNewsDay, HTFShortVetoApplied`.
   - Because this fires inside the scoring block for all four engines on every scored signal, it captures the **complete** 0..9 distribution (including the SETUP_NONE bottom), which the Candidates CSV structurally cannot.
3. **Realized-R join (unchanged, already present):** the TradeEvents EXIT row carries `SignalID` + **`Total_R`** (`:384`) + `Quality`/`EngineMode`/`DayType`. Join `GateScores.SignalID ⋈ TradeEvents.SignalID`. Signals in GateScores with no matching TradeEvents `SignalID` simply did not trade (SETUP_NONE drops, or lost the per-bar best-signal ranking) → they count in the **shape/density** audit (Section 2.3) but have no realized R for the **expectancy** calc (Section 3.4 Step A). Secondary join `EntryTime+Side` is available as a cross-check.

> **Why not extend the position struct instead:** `SPosition` carries only the tier (`setup_quality`, `:17`), NOT the raw 0–9 score and NOT the axis breakdown (confirmed at source). Adding the full breakdown to `SPosition` is more invasive and unnecessary — the `SignalID` join already threads scorer-side axes to exit-side realized R. Keep the breakdown on the scorer-side GateScores log; join by `SignalID`.

Net new logging surface: **a 7-int axis-breakdown out-param on `Score()` + one new `LogGateScore` writer (16 columns) fired inside the four engines' scoring blocks.** Everything on the realized-R side (SignalID join, Total_R, EngineMode, DayType) already exists.

### 3.3 Window

- **Full window: 2019, 2020, 2021, 2022, 2023, 2024, 2025** via `backtest_all.sh 1` (Model=1), plus **2026 YTD** as available (the data set in `GoldHistory/` and the v18 reference both extend to 2026; today is 2026-06-26). One run per year; decode each `Logs/UltTrader_Candidates_*.csv` and `UltTrader_TradeEvents_*.csv` (UTF-16LE → iconv → UTF-8).
- **OOS slice: 2024–2026** held out and reported separately (the same slice the Iter-3 kill-criterion uses). The thresholds are derived on the FULL window (in-sample includes OOS for the cut-point fit — we do not have enough density to fit on 2019–2023 alone), but the derived thresholds' realized expectancy is **reported broken out on 2024–2026** as a stability check (Section 5).
- mt5 concatenates the per-year decoded Candidates + TradeEvents into two combined tables (key on `SignalID`) for the analysis. Trade CSVs the analysis writes go to `claude/` (UTF-8, reason-over-able); raw tester CSVs stay UTF-16LE in `Logs/`.

### 3.4 HOW to compute realized expectancy per bucket and set the four thresholds (concrete)

Define for each scored-AND-traded signal: its **raw score `s ∈ {3..9}`** (from the axis breakdown) and its **realized `R`** (the TradeEvents `Total_R` for that `SignalID` — total trade R including banked partials, NOT the runner-leg-only `PnL_R`; this matches the fix-4.1 principle that a TP1/TP2-banked trade with a red runner is a net winner).

**Step A — analytic exclusions (apply BEFORE bucketing):**
- Drop signals flagged `IsNewsDay=true` if 3.6 was parked (Section 1 exception) so news-day noise never enters the expectancy ranking.
- Drop any signal with `HTFShortVetoApplied=true` (there should be zero if the veto is live — this is a correctness assertion; if any appear, the veto is not wired and the run is INVALID, loop to stok).
- Drop signals that scored but were never traded (no matching EXIT `SignalID`) from the *expectancy* calc — they have no realized R. (Their score IS still counted in the density/shape audit of Section 2.3.)

**Step B — per-bucket table.** For each integer `s` from 9 down to 3:
- `n[s]` = count of realized trades at exactly raw score `s`
- `meanR[s]` = mean `Total_R` of those trades
- Flag THIN if `n[s] < 30`; merge THIN buckets upward (combine `s` with `s+1`) for the cumulative calc.

**Step C — cumulative-from-top expectancy.** For each candidate cut `c ∈ {9,8,7,6,5,4,3}`, compute the population **at-or-above** `c`:
- `N_ge[c] = Σ_{s>=c} n[s]`, `meanR_ge[c] = (Σ_{s>=c} n[s]·meanR[s]) / N_ge[c]`.
This is the realized expectancy of "everything that would tier ≥ this cut."

**Step D — set the four thresholds:**
- **A+ = the highest cut `c` such that `meanR_ge[c]` is in the top decile of the per-trade realized-R distribution AND `N_ge[c] >= 50`.** Operationally: rank all realized trades by `Total_R`; the 90th-percentile R defines "top-decile expectancy"; choose the smallest-population (highest) raw-score cut whose at-or-above mean R clears that 90th-percentile bar while still totaling ≥ 50 trades. If the genuine top decile is < 50 trades, widen A+ down one raw score at a time until `N_ge >= 50` (Section 2.3 rule). On a max-9 scale this will almost always land A+ at **raw 8 or raw 9** — report which, with the numbers.
- **A = the next cut down** whose `meanR_ge` remains clearly positive (≥ the full-population mean R, i.e. A trades must beat the average graded trade) AND `N_ge[A] - N_ge[A+] >= 30` (the A-only band has ≥30 trades). Typically raw 7 (or 6 if 7 is thin).
- **B+ = the next cut** whose **incremental** band (`B+`-only trades, i.e. scored exactly in the B+ band) still has **mean R ≥ 0**. A band whose incremental mean R is negative does NOT earn a tradeable tier.
- **B = reachability decision (consciously made here, per fix-2.8 / the v18 B==A artifact).** Set `InpPointsBSetup` STRICTLY LESS than `InpPointsBPlusSetup` **only if** the lowest admitted band (raw `B` up to `B+`-1) has **incremental mean R ≥ 0 AND ≥ 30 trades**. Otherwise **leave B unreachable by setting `InpPointsBSetup = InpPointsBPlusSetup`** (the honest "no separate B tier" outcome) and record that the 0.6% B tier is intentionally closed — exactly the v18 design intent, now re-justified on the new distribution instead of inherited.

**Step E — monotonicity requirement (HARD):**
`InpPointsAPlusSetup > InpPointsASetup > InpPointsBPlusSetup >= InpPointsBSetup` (the last `>=` allows the closed-B case). AND realized expectancy must be **monotone non-decreasing with tier**: `meanR(A+) >= meanR(A) >= meanR(B+) >= meanR(B-band)`. If the realized expectancy is NOT monotone in score (e.g. raw-7 trades out-perform raw-8), that is a **scorer-validity failure**, not a threshold-tuning problem — the axes are mis-weighted and the result loops to stok (Section 5), it does NOT get "fixed" by gerrymandering cut points.

**Step F — risk-tier binding.** The four derived `InpPoints*` map to the existing risk tiers unchanged (A+ → 1.5% `InpRiskAPlusSetup`, A → 1.0%, B+ → 0.75%, B → 0.6%, then the regime/session/EC-v3 scaling). The GATE sets the POINT cut points; it does not touch the risk percentages.

### 3.5 Output mt5 hands to stok

A single decoded table (write to `claude/gate_axis_expectancy.csv`, UTF-8) with, per raw score 3..9: `n`, `meanR`, `medianR`, `winrate`, `N_ge`, `meanR_ge`, plus the same broken out on the 2024–2026 OOS slice; the chosen four `InpPoints*` with the Step-D/E justification; the total population and per-bucket density vs the Section-2.3 minimums; the count of dropped news-day / vetoed-short signals; and the proposed `.set` thresholds. **Do NOT write a report .md** — the table + a tight summary in the GATE phase log (`progress/2-4-GATE.md`) is the deliverable.

---

## 4. INTERACTION WITH THE DEFERRED SWEEPS — **fixed at defaults FOR the GATE; swept per-engine in 3.7–3.10.**

**Decision: `InpBOSFreshnessBars` and `InpSpineMinConfluence` are HELD AT THEIR COMMITTED DEFAULTS (8 and 25) for the GATE derivation run. They are NOT swept at the GATE. The `{4,6,8,12}` / spine sweeps happen per-engine in 3.7–3.10 by avg-R, exactly as 2.2 and 2.3 already bindingly recorded.**

### Justification (binding)

- **Separation of concerns.** The GATE answers one question: *given the scorer as committed (2.2/2.3/2.4 defaults), where do the tier cut points fall on the realized-expectancy ranking?* Sweeping freshness/spine simultaneously would make the cut points a function of two other moving parameters → the threshold derivation would be unidentifiable (you cannot attribute a distribution shift to the cut point vs the freshness window).
- **The 2.2 and 2.3 sign-offs already placed these sweeps in 3.8 / per-engine, by avg-R.** 2.2: "`{4,6,8,12}` per-engine avg-R sweep deferred to Phase 3.8." 2.3: "sweep `InpSpineMinConfluence` alongside `InpBOSFreshnessBars` by avg-R per engine on the 2.4-GATE-re-derived distribution." Note the explicit dependency direction in 2.3: the spine/freshness sweeps run **on the GATE-re-derived distribution** — i.e. the GATE must finish FIRST, producing the thresholds, then 3.7–3.10 sweep freshness/spine per engine against those fixed thresholds. Sweeping at the GATE would invert that committed ordering.
- **Stability caveat (recorded, non-blocking):** because the freshness/spine sweeps in 3.7–3.10 will shift each engine's score distribution slightly, the GATE thresholds are derived against the **default-freshness/default-spine** distribution and treated as the **anchor**. If a per-engine sweep in 3.7–3.10 moves an engine's distribution so far that its A+ population becomes empty or negative-expectancy at the GATE thresholds, that is surfaced in that engine's validation (and the engine is judged on its own fresh numbers per the Iter-3 kill-criterion) — the GATE thresholds are NOT re-derived per engine. One global threshold set, derived once, on the default-parameter distribution.

---

## 5. ACCEPTANCE (stok sign-off criteria) + KILL/FALLBACK

### 5.1 What makes the re-derived thresholds VALID (stok sign-off criteria — ALL required)

1. **Ordering honored:** 3.1–3.6 committed before the derivation run; the derivation `.set` has all four engines + sub-paths ON, floors at default, the temporary logging-width thresholds, and (the assertion) **zero `HTFShortVetoApplied=true` signals in the traded population.**
2. **Density adequate:** total spined-and-traded population over 2019–2026 ≥ 400 (target) and ≥ 200 (hard floor); ≥ 4 of 7 integer buckets reach ≥ 30 trades; the A+ at-or-above population ≥ 50. If only the hard floor (200) is met, thresholds ship PROVISIONAL and 3.7–3.10 must re-confirm per engine.
3. **Monotonicity:** `InpPointsAPlusSetup > InpPointsASetup > InpPointsBPlusSetup >= InpPointsBSetup` AND realized mean R monotone non-decreasing with tier (Step E). A non-monotone expectancy curve is a FAIL.
4. **A+ is the genuine top decile:** the chosen A+ cut's at-or-above realized expectancy clears the 90th-percentile per-trade R bar (Step D), not just "the highest bucket."
5. **OOS coherence:** the derived thresholds' tier ordering of realized expectancy **holds in sign** on the 2024–2026 OOS slice (A+ still ≥ A ≥ B+ in mean R on OOS; magnitudes may compress). A full sign-flip on OOS (e.g. A+ negative on 2024–2026) is a FAIL.
6. **No carried-forward v18 constants:** the four thresholds are derived from the table, not set to 8/7/6/7 by default. (They MAY coincide with a v18 value if the data lands there — but only if the table justifies it.)
7. **B-reachability decided consciously** (Step D) with its justification recorded, not inherited.

### 5.2 Kill / fallback — and what a failed derivation MEANS

- **If density is inadequate (< 200 traded signals, or < 4 buckets ≥ 30):** do NOT relax floors to manufacture density (Section 2.4). Report the thin distribution to stok. **This is itself a partial answer to "do the engines have an edge":** corrected engines that, fully enabled with all sub-paths, produce a near-empty graded distribution over 7 years on gold H1 are structurally low-frequency / low-confluence — a finding, not a tuning failure. The GATE then ships PROVISIONAL conservative thresholds (A+ at raw 8–9) and pushes the real edge verdict to the per-engine 3.7–3.10 fresh validation, which judges each engine on its own decoded PF/avg-R against the Iter-3 kill-criterion (PF < 1.0 OR avg-R < 0 over full AND OOS → OFF).
- **If the expectancy curve is non-monotone in score** (higher raw scores do NOT realize higher mean R): this is a **scorer-validity failure** — the post-2.4 axis weighting does not rank trades correctly. Loop to stok. The fix is in the axes (a re-weight or an axis removal), not in the cut points; do NOT gerrymander thresholds to paper over a mis-ranked scorer.
- **If the A+ tier's realized expectancy is ≤ 0 even at the highest raw score (9):** the scorer cannot identify a positive-expectancy top tier on the corrected engine population. This is the strongest negative signal — it says the engines, as corrected, do not produce a gradeable edge on gold H1, and it directly motivates keeping `InpEnableMultiStrategy=false` in production (engines stay OFF, the pattern-only baseline of 140t/$1190.84 (2024) / 129t/$714.29 (2023) and the v18 multi-year reference stand). Report to stok; do NOT force-enable engines to chase the gate.

> **Bottom line on the gate's own honesty:** the GATE is allowed to return "there is no clean top decile here." A derivation that cannot find a monotone, positive, adequately-dense A+ tier has *answered the Iter-3 edge question in the negative* for the shared-scorer path, and that answer is recorded — it is not overridden by loosening floors or hand-placing cut points.

---

## 6. TIGHT SUMMARY FOR mt5 (what to run)

1. Land + commit **3.1 → 3.6** first (HTF short veto live; 3-mode split; S6 box; swing-lookback=10; news-flat functional-or-parked per Section 1).
2. Build a NEW `UltimateTrader_GATE_derive.set`: `InpEnableMultiStrategy=true` + all 4 `InpEnableEngine*=true`, all sub-paths ON, per-mode auto-disable OFF, `InpBOSFreshnessBars=8` / `InpSpineMinConfluence=25` / `InpDealingRangeD1Lookback=20` HELD, derivation logging-width thresholds `9/8/4/3`.
3. Add to `CConfluenceScorer::Score` a 7-axis breakdown out-param (additive, off by default → production byte-identity preserved). Fire a NEW `LogGateScore(...)` writer **inside each engine's scoring block** (before the `candidate.valid`/`continue` drop — the existing Candidates path is truncated by that drop and CANNOT see SETUP_NONE/raw-0–2 signals) to a new `Logs/UltTrader_GateScores_*.csv` with `SignalID, BarTime, Side, EngineName, EngineMode, RawScore, Tier, Ax1..Ax7, IsNewsDay, HTFShortVetoApplied`. Join to TradeEvents on **`SignalID`**; realized outcome = TradeEvents **`Total_R`**.
4. Run **2019–2025 via `backtest_all.sh 1`** + 2026 YTD, Model=1, XAUUSD+ H1; decode all UTF-16LE CSVs.
5. Build `claude/gate_axis_expectancy.csv`: per raw score 3..9 → n, meanR, N_ge, meanR_ge (full window AND 2024–2026 OOS).
6. Derive the four `InpPoints*` by **cumulative-from-top, top-decile A+ (N_ge ≥ 50), monotone, B-reachability decided** (Section 3.4). Re-tighten the production `.set` to those values.
7. Hand stok the table + chosen thresholds + density/monotonicity/OOS checks. **stok sign-off required before 3.7.** Sweeps `InpBOSFreshnessBars`/`InpSpineMinConfluence` stay for 3.7–3.10 (Section 4).

---
*Design authored by stok. No backtest was run and no code was edited in producing this note. mt5 executes Section 3/6 exactly; any deviation (esp. relaxing the spine/SMC floors, or sweeping freshness/spine at the GATE) loops back to stok.*
