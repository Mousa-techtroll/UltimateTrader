# Phase-1 Quality-Tier Calibration Audit — FINDINGS (analysis only, no scorer changes)

Baseline **idrun_PBCA = $29,627.93 / 925** (tag `baseline-pbc-29628`). Tier→risk map **B+ 0.675% · A 0.900% · A+ 1.350%** (A = 1.33× B+). Point bands **B+ =6, A =7 (a 1-point sliver), A+ ≥8**. Logged `QualityScore` is bucketed to the tier (B+→5, A→7, A+→10), so the 3-tier table **is** the raw-score→R curve. Raw tables: `tier-calibration-audit.md` (per-engine, bootstrap CI) + `tier-rawscore-audit.md` (components).

## PIVOTAL ANSWER — SETUP_A is NOT intrinsically negative; it is engine-specific + mildly oversized
Portfolio SETUP_A is **+0.123 R (90% CI [+0.01, +0.23])** — positive, the *weakest* tier, at 1.25× B+'s risk. Portfolio-wide it is mildly **oversized relative to its expectancy, not intrinsically broken**. The intrinsic negativity is confined to specific engines. **There is NO global A defect to root-cause** — the hypothesis that opened this campaign does not survive the audit.

### Portfolio monotonicity (raw-score→R curve is only mildly non-monotonic)
| Tier | Fills | AvgR | 90%CI | PF | WR | Risk% | netR | net$ |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| B+ | 109 | +0.141 | [-0.01,+0.30] | 1.37 | 49% | 0.61 | +15.3 | +2,854 |
| A | 282 | +0.123 | [+0.01,+0.23] | 1.29 | 43% | 0.77 | +34.6 | +4,209 |
| A+ | 534 | +0.175 | [+0.10,+0.26] | 1.40 | 45% | 1.19 | +93.4 | +23,105 |

All three tiers cluster in a **narrow +0.12–0.18 R band** despite a 2× risk spread — the tier system barely differentiates *expectancy*; A+ earns most of the dollars through fill count + risk, not per-trade edge. A dips slightly below B+ (mild non-monotonicity) but stays positive.

### Per-engine A tier — the inversion is engine-specific
| Engine | A avgR (n) | vs B+ / A+ | verdict |
|---|--:|---|---|
| **EngulfingEntry** | **−0.072 (61)** | B+ +0.198 · A+ +0.247 | **negative — block-worthy** |
| PullbackContinuation | −0.439 (pre-block) | — | already blocked (adopted) |
| ExpansionEngine | −0.086 (8) | B+ +0.127 · A+ +0.399 | negative but n=8 (noise) |
| CrashBreakout | +0.245 (56) | (no B+) · A+ +0.175 | healthy (A best) |
| MACrossEntry | +0.214 (25) | B+ −0.168 · A+ +0.477 | healthy (monotonic) |
| PinBarEntry | +0.154 (128) | B+ +0.175 · A+ +0.080 | positive (but see §PinBar) |

A global block or global risk-equalization would **harm** Crash/MACross/PinBar, whose A tiers are positive.

### Engulfing A is robustly negative across ALL windows (a block would be robust)
| Window | B+ | A | A+ |
|---|--:|--:|--:|
| Real-tick 2019-26 | +0.210 (21) | **−0.068 (61)** | +0.248 (139) |
| Model-1 prod 2019-25 | +0.185 (22) | **−0.083 (58)** | +0.247 (133) |
| GoldHistory 2019-25 | −0.078 (20) | **−0.111 (49)** | +0.128 (126) |
| 2011-2017 OOS | −0.245 (8) | **−0.094 (18)** | +0.299 (49) |

Negative on both execution models, both vendor feeds, and the OOS era — the same robustness profile that justified the PBC block. For Engulfing the score is predictive only at the **top** (A+ strong everywhere); A and B+ are both weak, and A is consistently the worst.

## Component attribution — the A band is macro-contaminated (matches the a-priori hypothesis)
| Tier (Engulfing) | MacroScore | SMCScore | ADX | avgR |
|---|--:|--:|--:|--:|
| B+ | 0.05 | 50.0 | 30.4 | +0.198 |
| A | **0.70** | 50.0 | 31.9 | −0.072 |
| A+ | 1.45 | 50.0 | 35.7 | +0.247 |

Engulfing's A band is **"marginal pattern lifted into A by moderate MacroScore"** — exactly the *weak-pattern + correlated-context-bonus = SETUP_A* failure the owner predicted. Two scorer-hygiene findings: **SMCScore is a dead constant (50.0)** contributing nothing to differentiation, and **MacroScore is the dominant tier driver**.

## PinBar — a SEPARATE, larger problem: the score is anti-predictive (risk-map, not eligibility)
| Window | B+ | A | A+ |
|---|--:|--:|--:|
| Real-tick 2019-26 | +0.175 | +0.142 | **+0.083** |
| Model-1 prod | +0.242 | +0.245 | **+0.134** |
| GoldHistory | +0.116 | +0.198 | +0.123 |
| 2011-2017 | +0.055 | −0.059 | **−0.105** |

PinBar A+ is the **lowest-expectancy** tier in 3 of 4 windows yet gets the **most risk (1.27%)**. It only *loses* in 2011-17; on modern data it's low-R over-risked. This is a **risk-map inefficiency (over-allocation to PinBar A+), not eligibility** — 418 fills, the biggest engine. Fix = flatten PinBar's tier→risk, not a block.

## Decision-hierarchy mapping (owner's own criteria)
- ~~A negative across most engines → global block~~ — **NO** (A positive for 4 of 6 engines).
- ~~A weak/breakeven → equalize A risk to B+~~ — portfolio A is positive; equalizing shrinks a net-positive tier → likely net-negative. Not indicated.
- **Only PBC & Engulfing A negative → engine-specific blocks, leave global scorer unchanged — BEST MATCH.**
- ~~Raw score non-monotonic → drop tier-based risk~~ — portfolio curve is only mildly non-monotonic; not broken enough to abandon tiers globally. (But PinBar's tier→risk *is* unjustified — a targeted, not global, fix.)

## Recommended arm phase (pre-registered arms, re-ranked by evidence)
1. **Arm D — engine-specific Engulfing-A block** (robust 4-window negative, same proven mechanism as PBC). The principled next production arm; validate on all 8 windows before adoption. Expected ≈ +$500 direct + slot-freeing indirect, DD-neutral-to-better.
2. **PinBar tier→risk flattening** (separate follow-on): stop giving PinBar A+ 2× B+ risk when its A+ is its lowest-expectancy tier. Risk-map fix on the biggest engine.
3. **Scorer hygiene / Arm E** (higher-risk, later): the dead SMCScore and the macro over-weight that contaminates the A band are the *root* of the inversion — but since the global score barely differentiates R, a rebuild must clear a high bar. Global A block and global risk-equalization are **contra-indicated**.
