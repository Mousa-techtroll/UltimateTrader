> STATUS LANGUAGE (see MODEL_GOVERNANCE.md): 'REJECTED'/'null' below means ECONOMICALLY_NOT_PROMOTED
> (engineering + behavior PASS, default-off, kept in the capability set) — NOT rejected-as-bad-code.

# Phase 1 — entry-only OOS evidence (all 6 models, DEFAULT thresholds)

Controls: FULL 34,085/814 · GH 24,074/763 · CONF(23-24) 5,120/237 · LATE(25-26H1) 10,745/163.
Entry-only (exit=RM_CURRENT). Net table (net · PF · Sharpe · pos):

| model | FULL | GH | CONF | LATE |
|---|---|---|---|---|
| E1 Eng-structRoom | 19,174 ·1.40·2.90·689 (−44%) | 20,611 ·1.43·3.39·656 (−14%) | 3,657 (−29%) | 6,296 (−41%) |
| E2 Eng-momSeq | 20,536 ·1.41·2.93·700 (−40%) | 22,110 ·1.45·3.38·672 (−8%) | 3,793 (−26%) | 6,814 (−37%) |
| E3 Eng-confidence | 24,590 ·1.43·2.90·774 (−28%) | 23,864 ·1.42·3.19·736 (−0.9%) | 4,300 (−16%) | 7,292 (−32%) |
| E4 PBC-proxy | 29,235 ·1.44·3.14·773 (−14%) | 23,516 ·1.39·3.13·723 (−2.3%) | 5,048 (−1.4%) | 8,979 (−16%) |
| E5 PBC-realRec | 28,869 ·1.44·3.10·778 (−15%) | 24,095 ·1.39·3.16·727 (+0.09%) | 4,905 (−4.2%) | 8,979 (−16%) |
| E6 PBC-timing | 28,008 ·1.43·3.01·788 (−18%) | 22,130 ·1.37·2.97·738 (−8%) | 4,762 (−7%) | 9,613 (−11%) |

**All entry models are net-negative across all periods** — reject/wait-heavy filters that discard profitable
trades. PBC (E4-E6) milder than Engulfing (E1-E3). Only non-negative cell: E5 on GH (+0.09%).

## Action vocabulary IS fully exercised (full period, per-model)
| model | verdict distribution | direct-profile trades admitted |
|---|---|---|
| E1 | **WAIT 100%** (defers everything) | engulf n=0 (nothing admitted) |
| E2 | WAIT 83% · REJECT 8% · ACCEPT 7% · RISK_DOWN 2% | engulf n=11 @ +0.30R, +$855 |
| E3 | **RISK_DOWN 61%** · REJECT 32% · ACCEPT 6% · RECLASS 1% | engulf n=86 @ +0.23R, +$3,015 |
| E4 | **REJECT 100%** | pbc n=0 |
| E5 | REJECT 88% · ACCEPT 12% | pbc n=5 @ −0.21R, −$102 |
| E6 | REJECT 64% · RECLASS 24% · ACCEPT 12% | pbc n=15 @ −0.03R, +$578 |

## Reads
- The seam + candidate vocabulary WORK end-to-end (WAIT/REJECT/ACCEPT/RISK_DOWN/RECLASS all fire, req==applied risk).
- The models are **discarding profit, not filtering losers**: the admitted profile trades are net-positive
  (E3 engulf +0.23R; control PBC +0.265R), so rejecting/deferring them removes profit → net down. This is a
  DEFAULT-THRESHOLD artifact (depth band [0.30,0.75] rejects 74% of PBC signals whose real depths are 0.14–0.36).
- Rich metrics were flat differentiators here: winner-clipping capture ≈0.66 across all arms incl. control; loss
  avg ≈ −0.78R; concentration top10 ≈12%. EqDD tracks trade count (fewer trades → lower DD, e.g. E1 $2,807 vs ctl $4,562).
- **Standalone entry filtering has limited upside** — the profiles are already net-positive (no obvious removable
  negative sub-cohort, consistent with the prior standalone-breadth audit). The value, if any, is in the
  INTERACTION (entry×exit) — e.g. RECLASS routing to a better exit, or RISK_UP on high-confidence entries — which
  the factorial I = EX − E − X + C is designed to surface. → Phase 4.

Conclusion: entry evidence at default thresholds is COMPLETE and net-negative, but it reflects miscalibrated
thresholds (Phase 3) and does not test interactions (Phase 4). Not a basis to reject the entry models.
