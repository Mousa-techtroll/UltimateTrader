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

## Reading
- ALL models: ENGINEERING PASS + BEHAVIOR PASS → they belong in the shared architecture (kept, versioned, off-by-default).
- ECON: NOT_PROMOTED (historical null / collateral edge) or PENDING_FORWARD (in the forward-shadow queue). NONE is REJECTED_AS_BAD_CODE.
- Shadow-capability: exit models have full virtual-ledger counterfactuals; entry models are verdict-loggable (an
  entry changes the trade set, so its counterfactual is admission-level, not per-trade P&L on baseline trades — a
  documented distinction, not a gap).
- NEXT capability work: extend the platform to every active signal type (Crash, PinBar, Expansion, MACross,
  FailedBreakReversal, sleeves) with explicit policy selection + regime modifiers — see PLATFORM_ROADMAP.md.
