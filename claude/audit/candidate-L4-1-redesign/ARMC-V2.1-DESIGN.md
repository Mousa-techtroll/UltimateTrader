# L4-1 Arm C v2.1 — corrected setup-level architecture (supersedes v2 measurement)

The v2 result (−77%, "evidence anti-predictive") is INVALIDATED as a test of the design: v2 violated the
setup-level requirement and biased the evidence gate. v2.1 corrects six things and re-gates before any verdict.

## Corrections (all mandatory)
1. **Emission-stamped subtype + intent, propagated through the pipeline.** The EMITTING setup stamps
   `setup_subtype` + `engine_intent` on `EntrySignal` at creation; the fields propagate signal → pending →
   revalidation → exec → position → persistence → exit/Stats-CSV (mirror the existing `signal_id` chain). The
   evaluator CONSUMES the stamped subtype — it does NOT infer it from `plugin_name`.
2. **Split multi-role engines into explicit subtypes at emission.** PinBar (and any multi-role engine) stamps
   the specific role it detected: e.g. `PINBAR_TREND_REJECTION` (rejecting a level in the H4-trend direction =
   continuation/pullback) vs `PINBAR_COUNTER_EXHAUSTION` (rejecting against the H4 trend = reversal). The plugin
   knows its structural context at emission; it stamps accordingly. Same for Engulfing (continuation vs
   reversal) and any Crash/FailedBreak variants.
3. **Evidence FAMILIES, not a raw count.** Group evidence into families and require the RIGHT family for the
   intent — do not sum unlike signals:
   - STRUCTURAL rejection: directional OB / FVG / S-R zone.
   - EXHAUSTION (momentum): directional RSI extreme.
   - SWEEP: liquidity-sweep (recency-gated).
   - FAILED-BREAK: the failed-break/reclaim geometry.
   - REVERSAL-CONFIRMATION: a timestamp-paired structure event (see #4).
   **Plain ATR/volatility expansion is CONTEXT, NOT directional reversal evidence** — it may modulate, never
   qualify, a counter reward. A counter/reversal setup earns opposition credit only from ≥1 DIRECTIONAL family
   (structural OR exhaustion OR sweep OR failed-break) that matches the signal direction — not from ATR alone.
4. **Timestamp-paired structure events, not a bare enum.** Replace `GetRecentBOS()`-as-enum with a paired
   `{type, time, level}` BOS/CHoCH event, direction-matched and recency-gated, so a stale structure can't count
   as fresh reversal confirmation (this also aligns with the L2-1 finding).
5. **Scoring-stage identity in attribution.** Add a `stage` field (INITIAL vs REVALIDATION) to the AUDIT row so
   the two rows sharing one `signal_id` are distinguishable; the fill's effective tier is the REVALIDATION row
   when `InpFullRevalidation` is on.
6. **Correct dual-policy tier reporting.** The AUDIT must derive both tiers from the ACTUAL EFFECTIVE thresholds
   (the production `InpPoints*Setup` ladder, plus any live offset), and compute the LEGACY tier INDEPENDENTLY of
   any experiment flag/offset (a clean production-behavior mirror), so legacy vs v2.1 is an honest A/B.

## Gate (before any verdict)
- Compile PRODUCTION build → flag-off must reproduce `c051f97b` / $32,617.90 / 801 EXACTLY.
- Compile AUDIT build → reconcile candidate→exit IDs (every fill's `signal_id` joins to a scored row; the
  stamped subtype on the fill == the stamped subtype at scoring).
- ONLY THEN run Arm C v2.1 (`InpEAAv2` on the corrected evaluator) on PRIMARY + GoldHistory.
- Pre-registered criteria unchanged (ARMC-V2-DESIGN.md): net ≥ −2% & PF/Sharpe/DD ≥ baseline primary; GH ≥ −5%;
  retained profitable counter/mixed R ≥ 90%; legacy-removed R ≤ 0; newly-admitted avg R ≥ 0; no cohort sign flip.
- If v2.1 clears → adopt; else the "evidence anti-predictive" conclusion is RE-TESTED on a clean implementation
  and only then is L4-1 concluded. L1-4/L3-4 stay queued until this gate completes.

## Build order
A. Propagation infra: EntrySignal `setup_subtype`+`engine_intent` fields + emission stamping (split PinBar/
   Engulfing) + thread through pending/exec/position/persistence/exit + Stats column. (Uses the signal_id chain
   map from the candidate-ID recon.)
B. Evaluator v2.1: consume stamped subtype; evidence families; timestamp-paired structure; stage identity;
   effective-threshold independent dual-policy AUDIT.
C. Gate + measure (primary + GH).
