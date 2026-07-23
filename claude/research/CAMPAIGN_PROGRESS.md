# Entry×Exit research campaign — progress ledger

Branch `research/exploration-entry-exit`. Master-OFF identity byte-exact (03ad126b/814/$34,085.46 primary,
ad3cbd3d/763/$24,074.29 GH). Owner directive: do NOT close the campaign at the first default-model null; complete
missing evidence (entry OOS, Engulfing enrichment, threshold calibration, cross-model interactions) first.
Tools: `analyze.py` (rich metrics + common-entry identity + action audit), `screen_leg.sh` (one arm),
telemetry `UltTrader_ResearchLab_<sym>.csv` (per-signal features + verdicts).

## Methodology corrections already banked
- **Common-entry identity**: verify on the STABLE key (bartime|engine|dir|price), NOT SignalID (trailing global
  counter is volatile) and NOT position count. Exit-only X5 confirmed EXACT (814/814) entries vs control — clean isolation.
- **Direct-profile R** is the sharp lens: PBC exit B drops the 41 PBC trades from +$4,410/+0.265R to +$880/+0.047R —
  it directly clips PBC winners (not a portfolio artifact).
- **Default thresholds are miscalibrated** → most signals rejected: PBC entry A rejects 100%, entry B rejects 87%.
  PBC pullback_depth real dist (dev n=19): p20=0.144 p50=0.185 p80=0.360; default admit band [0.30,0.75] rejects
  74% as "shallow". recovery_conf mostly 1.0 (REC_HI=0.70 fine). 17% feature-unavailable. DEPTH is the binding gate.

## Phase 1 — entry-only OOS (all 6 models × full/GH/confirm/late), DEFAULT thresholds
STATUS: running (`entry_oos.sh`, 24 runs, pre-enrichment binary md5 f45074ad). Analyze with rich metrics +
action audit per arm once done. Expectation: harmful at defaults (reject-everything removes profitable trades);
this is the "before calibration" baseline the owner asked to complete.

## Phase 2 — Engulfing stamp enrichment  (CODED + COMPILED 0/0; identity + re-test PENDING)
- True origin: `EntrySignal.struct_origin` = engulf signal-candle extreme (low[1]/high[1]), set in CEngulfingEntry;
  ExecuteSignal open-stamp passes it as origin (tighter than SL → real structural leg, not SL-redundant). Data-only.
- Entry momentum: lab OnPositionOpened self-sources `entry_impulse` = momseq.momentum_persistence (the EXACT measure
  CEngulfCandA_Exit.LiveImpulse reads now) → activates the conjunctive deterioration leg (was dead: entry_impulse_ok=false).
- NEXT: recompiled binary → master-OFF identity gate (struct_origin is data-only, must stay byte-exact) → `engulf_retest.sh`
  (ER_ tags, X1/X2/X3 on dev+full+GH). Supporting-swing + structural-room stamps NOT added (current Engulf exit
  candidates don't consume them; origin+momentum are what they read).

## Phase 3 — minimal distribution-based threshold calibration  (PENDING)
Freeze each selection rule from the dev FEATURE distribution BEFORE computing outcomes (no profit optimization).
First target: PBC entry depth band → ~[p20,p80]=[0.14,0.36] (from the dist above). Calibrate each model's binding
thresholds (entry + exit), freeze, re-run + OOS. Thresholds are #defines in the candidate files.

## Phase 4 — within-profile cross-model matrices  (PENDING)
Engulf entries A/B/C × Engulf exits A/B/C (9) and PBC A/B/C × PBC A/B/C (9), with control + E-only + X-only to
compute the factorial I = EX − E − X + C. Promote only a few survivors to confirm/late/GH/forward-shadow.
Negative standalone E and X effects do NOT rule out a positive interaction.

## Rejected so far (do not re-run without calibration/enrichment)
- PBC exit A/B at DEFAULT thresholds: dev-positive artifact, reverse OOS (X5 full −12%, GH −1.2%). See DEV_SCREEN_FINDINGS.md.
