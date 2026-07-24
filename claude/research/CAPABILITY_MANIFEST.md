# CAPABILITY MANIFEST — research entry/exit models (what EXISTS and is validated)

Everything here is IMPLEMENTED, versioned (ENUM_RESEARCH_MODEL id / ModelVersion), configurable
(InpResearchEntryModel/InpResearchExitModel), shadow-capable, and DEFAULT-OFF. Status per MODEL_GOVERNANCE.md.
ENG=engineering correctness, BEH=strategy-behavior correctness, ECON=economic production promotion.
NONE is deleted; NONE is "bad code". Economics choose only the canonical ACTIVE profile (see PRODUCTION_MANIFEST.md).

Engineering note (applies to ALL): compile 0/0; master-OFF AND shadow-ON decision identity byte-exact on both feeds
(03ad126b/814, ad3cbd3d/763); no fabrication; closed-bar; sole-owner state; coordinator/risk-gateway routed.

## ENTRY models (Engulfing family, profile 0)
| id | Id() | ver | intended objective | ENG | BEH | ECON |
|---|---|---|---|---|---|---|
| 1 | ENG_A structural-room | 1 | return max: admit high room-to-run continuations w/ momentum confirm | PASS | PASS (aux-momentum wired; admits/downgrades per room+momentum) | NOT_PROMOTED |
| 2 | ENG_B momentum-seq | 1 | return max: admit on confirmed momentum thrust/persistence | PASS | PASS | NOT_PROMOTED |
| 3 | ENG_C confidence | 1 | risk allocation: confidence-graded admission + subtype | PASS | PASS (RISK_DOWN/UP + RECLASS fire per confidence) | NOT_PROMOTED |
| 11 | ENG_alloc | 1 | risk allocation, PRESERVE baseline entries (never reject) | PASS | PASS (down/normal/up/reclass; 0% reject) | PENDING_FORWARD |

## ENTRY models (PBC family, profile 1)
| id | Id() | ver | intended objective | ENG | BEH | ECON |
|---|---|---|---|---|---|---|
| 4 | PBC_A recovery-proxy | 1 | continuation capture (depth+recovery proxy) | PASS | PASS | NOT_PROMOTED |
| 5 | PBC_B real-recovery | 1 | quality continuation (full recovery family) | PASS | PASS | NOT_PROMOTED |
| 6 | PBC_C timing/subtype | 1 | subtype-matched risk (shallow/deep) | PASS | PASS (RECLASS subtypes fire) | NOT_PROMOTED |
| 12 | PBC_state | 1 | continuation-STATE machine; WAIT/downgrade before reject | PASS | PASS (forming/basing/recovery/continuation states) | PENDING_FORWARD |

## EXIT models (Engulfing family, profile 0)
| id | Id() | ver | intended objective | ENG | BEH | ECON |
|---|---|---|---|---|---|---|
| 1 | ENG_A structural | 1 | trend preservation / structural invalidation close | PASS | PASS (conjunctive origin+deterioration) | NOT_PROMOTED |
| 2 | ENG_B momentum | 1 | momentum-reversal exit past origin | PASS | PASS | NOT_PROMOTED |
| 3 | ENG_C confidence | 1 | return max (runners) + risk (tight on low-conf) | PASS | PASS (HI-conf widen / LO-conf tight) | PENDING_FORWARD |
| 7 | ENG_C_gated | 1 | trend preservation: suppress momentum-clip of a winner in a strong trend | PASS | PASS (verified: clip-suppress only in strong-trend developed-winner) | PENDING_FORWARD |
| 8 | ENG_C_protect | 1 | trend preservation + de-risk: tighten a winner instead of closing | PASS | PASS (verified: give-back 1.14→0.80R, clips 29→17) | PENDING_FORWARD |
| 9 | ENG_C_partial | 1 | partial de-risking + runner preservation | PASS | PASS (verified: bank 50% + keep runner on the clip) | PENDING_FORWARD |
| 10 | ENG_C_hyst | 1 | hysteresis: require sustained deterioration (≥2 bars) before closing a winner | PASS | PASS (verified: streak-gated close) | PENDING_FORWARD |

## EXIT models (PBC family, profile 1)
| id | Id() | ver | intended objective | ENG | BEH | ECON |
|---|---|---|---|---|---|---|
| 4 | PBC_A recovery-proxy | 1 | continuation preservation / de-risk on fade | PASS | PASS | NOT_PROMOTED |
| 5 | PBC_B real-recovery fade | 1 | partial de-risking on recovery collapse (lab-owned peak) | PASS | PASS | NOT_PROMOTED |
| 6 | PBC_C subtype | 1 | subtype-matched de-risking (scalp bank / runner) | PASS | PASS | NOT_PROMOTED |

## Crash family (profile 2) — PLATFORM WAVE (3 exit intents + entry classifier)
Lifecycle-hardened (exactly-once partial, monotonic tighten, repeat-suppress, PERSISTED policy stage restored on
restart). Behavior FULLY verified by synthetic tests (UT_ResearchPolicies: 20/20, every branch incl. fade-invalidation).
Does NOT duplicate the production §D crash trail-suppressor (that is a trailing-plugin modulation; these are exit proposals).
| id | Id() | ver | intended objective | ENG | BEH | ECON |
|---|---|---|---|---|---|---|
| 13 | CRASH_A_fade | 1 | rubber-band FADE: bank into the reversion, protect on stall, close on fade-invalidation (default subtype) | PASS | PASS (synthetic 5/5) | PENDING_FORWARD |
| 14 | CRASH_B_continuation | 1 | CONTINUATION: ride the extending crash wide, bank a big extension, close on a bounce | PASS | PASS (synthetic 5/5) | PENDING_FORWARD |
| 15 | CRASH_C_recovery | 1 | RECOVERY: exit ahead of the V-bottom bounce (capital protection) | PASS | PASS (synthetic 5/5) | PENDING_FORWARD |
| 16 | CRASH_entry | 1 | ENTRY classifier: FADE/CONTINUATION/RECOVERY subtype + preservation-first risk allocation | PASS | PASS (synthetic 5/5, never rejects) | PENDING_FORWARD |

## PinBar family (profile 3) — PLATFORM WAVE (2 exit intents + entry classifier)
Lifecycle-hardened + persisted policy stage. Behavior fully verified (UT_ResearchPolicies, every branch).
Entry is ANTI-PREDICTIVE by design (PinBar A+ over-risked historically — see quality-tier-calibration): high
confidence DOWNGRADES, never rejects. Does not duplicate any production trailing behavior.
| id | Id() | ver | intended objective | ENG | BEH | ECON |
|---|---|---|---|---|---|---|
| 17 | PIN_A_reversal | 1 | REVERSAL: target the pin's rejection move, bank at target, protect on stall, close on invalidation | PASS | PASS (synthetic 5/5) | PENDING_FORWARD |
| 18 | PIN_B_continuation | 1 | CONTINUATION: ride the resumption, tighten on a momentum reversal | PASS | PASS (synthetic 2/2) | PENDING_FORWARD |
| 19 | PIN_entry | 1 | ENTRY classifier: reversal/continuation subtype + anti-predictive risk (hi-conf downgrade, never reject) | PASS | PASS (synthetic 2/2) | PENDING_FORWARD |

## Expansion/Breakout family (profile 4) — PLATFORM WAVE (2 exit intents + entry classifier)
Lifecycle-hardened + persisted policy stage. Behavior fully verified (UT_ResearchPolicies, every branch).
Routes by follow-through persistence: a breakout either FOLLOWS THROUGH (ride) or FAILS (fade-guard tighten).
| id | Id() | ver | intended objective | ENG | BEH | ECON |
|---|---|---|---|---|---|---|
| 20 | EXP_A_followthrough | 1 | FOLLOW-THROUGH: ride wide on strong follow-through, bank at measured move, close back-through-origin | PASS | PASS (synthetic 3/3) | PENDING_FORWARD |
| 21 | EXP_B_failbreak | 1 | FAIL-RISK: weak follow-through in profit → tighten hard (fade guard); defers on non-failrisk subtype | PASS | PASS (synthetic 2/2) | PENDING_FORWARD |
| 22 | EXP_entry | 1 | ENTRY classifier: followthrough/failrisk subtype by follow-through strength; downgrade fail-risk | PASS | PASS (synthetic 1/1) | PENDING_FORWARD |

## FailedBreak/Reversal family (profile 5) — PLATFORM WAVE (1 exit intent + entry classifier)
Lifecycle-hardened + persisted policy stage. Behavior fully verified (UT_ResearchPolicies, every branch).
Single reversal thesis: target the reversal move after a failed breakout, close if the failed-break level re-breaks.
| id | Id() | ver | intended objective | ENG | BEH | ECON |
|---|---|---|---|---|---|---|
| 23 | FBR_A_reversal | 1 | REVERSAL: bank at measured move, protect on stall, close on re-break invalidation | PASS | PASS (synthetic 3/3) | PENDING_FORWARD |
| 24 | FBR_entry | 1 | ENTRY classifier: reversal subtype + impulse/room-graded risk (never rejects) | PASS | PASS (synthetic 1/1) | PENDING_FORWARD |

## MA-Cross family (profile 6) — PLATFORM WAVE (1 exit intent + entry classifier)
Lifecycle-hardened + persisted policy stage. Behavior fully verified (UT_ResearchPolicies, every branch).
Trend-runner thesis: ride wide while the trend holds; require SUSTAINED cross-back (≥2 bars via lab deterioration
streak) before closing so a single-bar wobble does not exit a live trend.
| id | Id() | ver | intended objective | ENG | BEH | ECON |
|---|---|---|---|---|---|---|
| 25 | MAC_A_trendrunner | 1 | TREND RUNNER: ride wide on trend, tighten on 1-bar cross-back, close on SUSTAINED cross-back / origin break | PASS | PASS (synthetic 4/4) | PENDING_FORWARD |
| 26 | MAC_entry | 1 | ENTRY classifier: trend subtype + trend-strength-graded risk (upgrade strong, downgrade weak, never rejects) | PASS | PASS (synthetic 1/1) | PENDING_FORWARD |

## Sleeve families (profiles 7/8/9) — SHORT-ONLY, ENTRY-ONLY (own gateway; exits production-managed)
Preservation-first (never reject a gateway-valid sleeve signal); allocate risk by the sleeve's own conviction
feature, matched to its thesis. Off by default (whole sleeve block + research lab both off). Behavior branch-verified.
| id | Id() | ver | intended objective | ENG | BEH | ECON |
|---|---|---|---|---|---|---|
| 27 | SLV_CONT_entry | 1 | CONT trend-continuation short: risk by aligned down-momentum + structural room | PASS | PASS (synthetic 4/4) | PENDING_FORWARD |
| 28 | SLV_CREV_entry | 1 | CREV counter-reversal rally-fade: risk by rally exhaustion + room (centered) | PASS | PASS (synthetic 3/3) | PENDING_FORWARD |
| 29 | SLV_TMF_entry | 1 | TMF regime-participation short: flat dose, light upgrade only on a decisive down-close | PASS | PASS (synthetic 2/2) | PENDING_FORWARD |

## Broker-lifecycle hardening (applies to ALL exit models)
The exit platform is broker-lifecycle correct (see EXECUTION_HARDENING.md): policy stages (partial_done /
sl_locked_r-PROTECTED / policy_stage) advance ONLY on broker/deal CONFIRMATION via an explicit action-state
machine (PROPOSED→PENDING/UNKNOWN→CONFIRMED/REJECTED), never at proposal time. Refined (action,target) repeat-
suppression. Hardened schema-v2 sidecar (magic/CRC/identity/atomic/migration). Crash entry geometry now matches
its classified thesis (classify-before-geometry). Behavior verified by UT_ResearchPolicies (89/89, incl. 17
fault/restart/netting cases). Every registered engine resolves explicitly (COVERAGE_MATRIX.md).

## Reading
- ALL models: ENGINEERING PASS + BEHAVIOR PASS → they belong in the shared architecture (kept, versioned, off-by-default).
- ECON: NOT_PROMOTED (historical null / collateral edge) or PENDING_FORWARD (in the forward-shadow queue). NONE is REJECTED_AS_BAD_CODE.
- Shadow-capability: exit models have full virtual-ledger counterfactuals; entry models are verdict-loggable (an
  entry changes the trade set, so its counterfactual is admission-level, not per-trade P&L on baseline trades — a
  documented distinction, not a gap).
- COVERAGE: the capability platform now spans EVERY registered signal type — 10 profiles: Engulfing (0), PBC (1),
  Crash (2), PinBar (3), Expansion/Breakout (4), FailedBreak/Reversal (5), MA-Cross (6), plus the short-only
  sleeves CONT (7), CREV (8), TMF (9). 29 models, each versioned, configurable, shadow-capable, default-off.
  Every registered production engine resolves EXPLICITLY (family / sleeve / passthrough) — COVERAGE_MATRIX.md.
  Behavior branch-verified by UT_ResearchPolicies (89/89).
- NEXT capability work: optional regime-modifier wrapper (default-identity) over the profiles; research overlays
  for the enabled PASSTHROUGH engines (VolatilityBreakout, Displacement, LiquidityEngine, SessionEngine,
  RangeEdgeFade) if/when warranted. All 29 models are ECON PENDING_FORWARD — none is production-promoted;
  promotion is gated on NEW forward data (FORWARD_SHADOW_PREREGISTRATION.md), never on historical fit.
