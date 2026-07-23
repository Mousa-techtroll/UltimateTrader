# Independent dev screen — entry & exit models (2019–2022, PRIMARY XAUUSD+ Model4)

Branch `research/exploration-entry-exit`. Master-OFF identity byte-exact (03ad126b/814/$34,085.46 primary,
ad3cbd3d/763/$24,074.29 GH). Entry admission hooked at the **universal gateway** (`CTradeOrchestrator::ExecuteSignal`)
after a first-pass coverage-gap bug (caller-side hook missed the confirmed-pending path → Engulfing entries were
inert and Engulfing exits ran without entry stamps). Results below are AFTER the fix.

Control (DEV_C): **net $5,445.19 · PF 1.24 · Sharpe 2.01 · 422 pos**. NB: dev is a low-profit slice — the full
2019–2026 baseline is $34,085 / 814, so 2019–2022 holds only ~16% of net over ~52% of the trades. Exit gains here
must be re-checked out-of-sample.

## Entry-only (entry model, exit=RM_CURRENT)
| arm | model | net | Δnet | PF | Sharpe | pos | verdict |
|---|---|---|---|---|---|---|---|
| E1 | Eng structural-room A | 4,030.75 | −26% | 1.22 | 1.86 | 376 | harmful |
| E2 | Eng momentum-seq B | 4,076.39 | −25% | 1.22 | 1.87 | 377 | harmful |
| E3 | Eng confidence C | 4,734.74 | −13% | 1.23 | 1.94 | 409 | harmful |
| E4 | PBC recovery-proxy A | 5,032.00 | −7.6% | 1.23 | **2.08** | 400 | net↓ but best Sharpe |
| E5 | PBC real-recovery B | 4,900.58 | −10% | 1.23 | 2.03 | 403 | net↓ |
| E6 | PBC entry-timing C | 4,378.83 | −20% | 1.20 | 1.83 | 406 | harmful |

**No entry model improves dev net.** Every model reduces trade count (REJECT/WAIT) and net. E4 (PBC proxy) is the
only one to raise Sharpe (2.08). Entry models look like net-negative filters on this slice.

## Exit-only (exit model, entry=RM_CURRENT — trade count ~unchanged)
| arm | model | net | Δnet | PF | Sharpe | pos | verdict |
|---|---|---|---|---|---|---|---|
| X1 | Eng structural A | 5,445.19 | 0 | 1.24 | 2.01 | 422 | **inert** (origin=SL ≈ broker SL) |
| X2 | Eng momentum B | 3,790.11 | −30% | 1.20 | 1.70 | 423 | harmful |
| X3 | Eng confidence C | 3,914.22 | −28% | 1.21 | 1.75 | 423 | harmful |
| X4 | PBC recovery-proxy A | 5,449.12 | +0.07% | 1.24 | 2.05 | 422 | ~flat (weak +) |
| **X5** | **PBC real-recovery B** | **5,598.35** | **+2.8%** | **1.25** | **2.13** | 422 | **LEAD FINALIST** |
| X6 | PBC entry-timing C | 5,445.19 | 0 | 1.24 | 2.01 | 422 | inert |

**X5 (PBC exit B, recovery-fade) is the single clear positive**: +2.8% net, Sharpe 2.01→2.13, identical trade
count — a pure exit-timing gain driven by the lab-owned running peak-of-recovery + recovery_confirmed feature.
X4 (PBC exit A) is neutral-positive. Engulfing exits are inert (X1/X6) or harmful (X2/X3); the inert ones are a
known artifact of the first-pass `origin=stopLoss` proxy making the structural-close leg redundant with the broker
SL (documented enrichment = supply the true, tighter engine origin).

## Read
- The **PBC "real-recovery" family (B)** is the only source of edge on dev, and only on the **exit** side.
- Engulfing research models add nothing here (entries harmful, exits redundant/harmful) — partly the origin proxy.
- Entry-side research is net-negative on this slice; the interesting finalist is an EXIT model.

## Finalist validation (X5 = PBC exit B, X4 = PBC exit A; exit-only) — REJECTED

| period | control net | X5 net | ΔX5 | X4 net | ΔX4 |
|---|---|---|---|---|---|
| dev 2019–22 | 5,445 | 5,598 | **+2.8%** | 5,449 | +0.1% |
| confirm 2023–24 | 5,120 | 4,630 | **−9.6%** | 4,760 | −7.0% |
| late 2025–26H1 | 10,745 | 9,044 | **−15.8%** | 10,074 | −6.2% |
| full 2019–26 | 34,085 | 29,915 | **−12.2%** | 31,794 | −6.7% |
| GH cross-feed | 24,074 | 23,782 | −1.2% | 24,072 | −0.01% |

All periods exit-only (identical trade counts vs control). **The dev +2.8% was a dev-slice artifact — it reverses
in every out-of-sample period, on the full period, and on the cross-feed.** X5 removes $4,170 (−12%) over the full
period on the SAME 814 trades.

**Behavioral cause (coherent, not a bug):** the recovery-fade exit helps in the choppy 2019–22 slice but **clips
winners in the trending 2023–26 regime** — it exits when a pullback-recovery fades, yet in a trend the pullback
resumes, so it cut a winner. Same entries, worse exits. On GH both are flat-to-slightly-negative.

## CONCLUSION — negative result (baseline protected)
Across the full independent screen (6 entry + 6 exit models) **no candidate improves out-of-sample or cross-feed
performance** at default parameterization:
- Entry models: all net-negative on dev.
- Exit models: only X5/X4 positive on dev; both reverse OOS/full/GH.

The **research infrastructure is complete and validated** — master-OFF identity byte-exact on both feeds, entry
admission covers all four paths (immediate/confirmed/file/sleeve), exit routing through the coordinator's sole-owner
path, sole-owner stamps, durable pending. What the screen shows is that the **candidate MODELS**, at their default
(un-tuned, "deferred") thresholds, do not beat the incumbent logic once you leave the dev slice. This is consistent
with the standing finding that the architecture is at the research frontier on available data.

Cross-model combos were NOT run: their premise is a surviving single-model finalist, and none survived OOS. Combining
a net-negative entry with an OOS-negative exit has no plausible path to positive.

### Open threads (owner's call — none is a promotion)
1. **Threshold selection on dev + OOS re-test** — low expected value (models are already OOS-negative; tuning on the
   dev slice that produced the artifact invites more overfitting), but it is the letter of the original "deferred
   thresholds" plan.
2. **Stamp enrichment** (true engine origin + entry-momentum snapshot) — would fairly re-open the Engulfing exits,
   currently handicapped by the `origin=stopLoss` proxy (structural leg redundant with the broker SL). Engulfing
   standalone entries are rare in the portfolio, so payoff is uncertain.
3. **Forward / shadow validation** — deploy the seam in shadow (log proposals, don't act) to gather live data; the
   standing guidance is that the next real signal is forward validation, not more backtest tuning.

## Phase 2 result — Engulfing stamp enrichment (true origin + entry-momentum)
Removing the origin=stopLoss handicap (true origin = engulf signal-candle extreme, tighter than SL) + snapshotting
entry momentum (momentum_persistence, activating the conjunctive deterioration leg):
| exit | pre-enrich dev | ENRICHED dev | ENRICHED full | ENRICHED GH | Sharpe (dev/full/GH) |
|---|---|---|---|---|---|
| X1 Eng-A struct-room | inert | inert | inert (=34,085) | inert (=24,074) | unchanged |
| X2 Eng-B momentum | −30% | −30% (3,790) | −42% (19,771) | −15% (20,434) | down |
| **X3 Eng-C confidence** | −28% | **+20% (6,558)** | −4.2% (32,641) | **+16% (28,011)** | **2.46 / 3.39 / 3.54 (UP all)** |
Enrichment FLIPS Eng-C from harmful to the first CROSS-FEED-POSITIVE candidate (GH +16% net; Sharpe up everywhere;
full-primary −4.2% net but +9% Sharpe). Validates the origin handicap. Master-OFF identity still byte-exact.
NEXT: Eng-C exit OOS (confirm/late), then it enters the Engulf matrix as a promoted exit.
