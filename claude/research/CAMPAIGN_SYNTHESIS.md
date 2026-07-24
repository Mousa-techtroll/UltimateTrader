> STATUS LANGUAGE (see MODEL_GOVERNANCE.md): 'REJECTED'/'null' below means ECONOMICALLY_NOT_PROMOTED
> (engineering + behavior PASS, default-off, kept in the capability set) — NOT rejected-as-bad-code.

# Entry×Exit research campaign — complete synthesis (all 4 phases)

Branch `research/exploration-entry-exit`. Master-OFF identity byte-exact throughout (six recompiles):
PRIMARY 03ad126b/814/$34,085.46, GH ad3cbd3d/763/$24,074.29. Baseline never touched. Every candidate recorded.

## What was tested (owner directive: complete the missing evidence, don't stop at the first null)
1. All 6 entry models OOS (full/GH/confirm/late), default thresholds — rich metrics + action audit + common-entry identity.
2. Engulfing stamp enrichment (true origin + entry momentum), Engulfing exits re-tested.
3. Frozen distribution-based threshold calibration (bands→[p20,p80], floors→p20; frozen before outcomes).
4. Aux-momentum wiring fix (Eng-A/PBC-A were untestable).
5. Within-profile entry×exit matrices (Engulf 3×3, PBC 3×3) + factorial I = EX−E−X+C.

## Findings

### Entries — NO selection edge (robust across default / calibrated / aux-wired)
- All 6 net-negative across all periods. Action vocabulary fully exercised (WAIT/REJECT/ACCEPT/RISK_DOWN/RISK_UP/RECLASS).
- Default reject-heavy REMOVES good trades; frozen calibration (looser bands) ADMITS losers (PBC-B direct-profile
  −0.277R on the newly-admitted shallow pullbacks). The default thresholds were CORRECTLY filtering low quality.
- Common-entry identity verified on the stable key (bartime|engine|dir|price): exit-only arms are EXACTLY
  identical to control (clean isolation); entry-only arms change the admitted set as intended.
- Mechanism (direct-profile): the baseline profiles are already net-positive (PBC +0.093..0.265R); no research
  feature-based selection identifies a better subset — it only removes winners or adds losers.

### Exits — trend-fragile (help choppy, clip winners in trends)
- PBC exit B (X5): dev +2.8% artifact → reverses OOS (full −12%, late −16%, GH −1.2%). Direct-profile: clips
  the PBC winners ($4,410→$880 full).
- **Engulfing exit C (X3), ENRICHED: the standout** — enrichment flips it from −28% dev to **+20% dev, +16% GH
  cross-feed, +3.3% confirm, Sharpe UP every period** (2.46/3.39/3.54). BUT late-sample −25%, full −4.2%.
  Same trend-fragility: clips winners in the strong 2025–26 uptrend. NOT robustly promotable.
- Enrichment validated the owner's origin-handicap hypothesis (origin=stopLoss made the structural leg
  redundant with the broker SL; the true engulf-candle extreme is tighter and productive).

### Interactions — real synergies, insufficient magnitude
- NO combo beats control on dev (all 18 EX−C < 0; best E4X5 −447).
- Genuine super-additive I in PBC: E5X5 +474, E6X5 +450, E6X6 +335. But the synergy is one component MITIGATING
  another's damage (X5 rescues E5's bad selection −597→−159), not creating value.
- Adding any entry to the enriched Eng-C exit DESTROYS it (E·X3 I = −1,147/−1,202/−2,355): the entries reject/
  downgrade exactly the trades X3 was profitably exiting.

## Bottom line
The architecture is complete and validated; the candidate models have a consistent behavioral signature —
**no entry selection edge, trend-fragile exits** — and NO single model or within-profile combination is robustly
positive out-of-sample. The one candidate with genuine cross-feed signal (enriched Engulfing exit C: GH +16%,
Sharpe-improving) is trend-fragile (late-sample −25%) and does not combine. This is a far more thorough result
than the initial default-threshold null: the enrichment hypothesis was RIGHT (origin mattered), the calibration
hypothesis was WRONG (defaults were correct; entries have no edge), interactions were PARTIALLY right (synergies
exist but too small).

## Promotion status
- To production: NOTHING (nothing robustly positive; baseline protected).
- Confirm/late/GH: DONE for the finalists (all mixed/negative).
- **Forward shadow**: the enriched Engulfing exit C is the only candidate warranting it — cross-feed-positive +
  Sharpe-improving, trend-fragile. Shadow (log proposals, act on nothing, byte-identical trades) would gather
  forward data on whether its risk-adjusted edge holds live. Requires a small shadow-master addition. Owner's call.
