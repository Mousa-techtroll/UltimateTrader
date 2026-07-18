# Codex-audit remediation tracker (force-fix-for-correctness campaign)

Branch `fix/codex-remediation` off `d6549628` / $34,940.18 / 869 (primary) + `f11c4b2c` / $29,525.79 / 820 (GH).
Policy: fix ALL confirmed findings; behavior-changers merged regardless of P&L sign; each isolated + reversible;
new baseline re-measured + re-frozen at the end. Validation verdicts from the 7-lane audit-validation pass.

Status legend: ☐ todo · ✍ authoring · 🔬 integrating/measuring · ✅ merged · ⏸ deferred

| ID | Sev | Verdict (validated) | Tier | Reachability | Fix summary | Status | Commit | Δnet |
|---|---|---|---|---|---|---|---|---|
| L6-1 | Crit | CONFIRMED (code) | 1 | netting live (both-safe) | deal-id binding, account-mode reconcile | ☐ | | |
| L6-2 | Crit | CONFIRMED | 1 | live-file | recompute risk_distance after SL widen | ✅ | 5b056bb | 0 (BI primary) |
| L6-3 | Med | CONFIG-MITIGATED | 1 | live cross-sym | tick-grid normalize at send (noop XAU) | ✅ | 5b056bb | 0 (BI primary) |
| L1-2 | High | CONFIRMED | 1 | live-file | reject foreign-symbol file signals | ✅ | 5b056bb | 0 (BI primary) |
| L7-1 | High | CONFIRMED | 1 | live-restart | checksum whole payload + atomic load | ✅ | e5c7b8e | 0 (BI primary) |
| L7-2 | High | CONFIRMED | 1 | live-restart | persist exit_* + partial PnL (P4b) | ✅ | e5c7b8e | 0 (BI primary) |
| L7-3 | High | CONFIRMED | 1 | live-restart | offline-close idempotent accounting | ✅ | e5c7b8e | 0 (BI primary) |
| L7-4 | High | CONFIRMED-DORMANT | 1 | live-file+restart | file TP partials persist | ✅ | e5c7b8e | 0 (BI primary) |
| L4-1 | High | CONFIRMED (material) | 2 | live-default | direction-aware alignment scoring + tier recalib | ☐ | | |
| L2-4 | Med | CONFIRMED | 2 | live-default | H4 confirm only on H4-bar change | ☐ | | |
| L2-3 | Med | CONFIRMED | 2 | live-default | range-box reset vs prior box | ☐ | | |
| L2-5 | Med | CONFIRMED | 2 | live-default | SMC zone close-rule on [1] | ☐ | | |
| L2-6 | Med | CONFIRMED | 2 | live-default | trend swing closed right-wings | ☐ | | |
| L3-3 | Med | CONFIRMED | 2 | backtest | vol-BO cooldown on fill not emit | ☐ | | |
| L3-4 | Med | CONFIRMED | 2 | backtest | equal-tier explicit tie-breaker | ☐ | | |
| L4-3 | Med | CONFIRMED | 2 | live-default(long) | no-break tolerance in range/ATR units | ☐ | | |
| L4-4 | Med | CONFIRMED | 2 | live-default | revalidation reruns dynamic gates | ☐ | | |
| L1-1 | High | CONFIRMED | 2/1 | live-default | daily-halt refresh at OnTick top | ☐ | | |
| L1-4 | Med | CONFIRMED (benign) | 2 | live-default | enforce confirmed-path gates (−$578) | ☐ | | |
| L2-1 | High | CONFIRMED-DORMANT | 3 | toggle | one paired structure event | ☐ | | |
| L2-2 | Med | CONFIRMED-DORMANT | 3 | toggle | sweep recency by pool id | ☐ | | |
| L3-2 | High | CONFIRMED-DORMANT | 3 | toggle | preserve router weight immediate path | ☐ | | |
| L4-2 | Med | CONFIRMED-DORMANT | 3 | toggle | unify routed/legacy score scale | ☐ | | |
| L4-5 | Low | CONFIRMED-DORMANT | 3 | toggle | carry major_engine to position | ☐ | | |
| L1-3 | High | CONFIRMED-DORMANT | 3 | toggle | emergency = entry-only kill | ☐ | | |
| L1-6 | Med | CONFIRMED-DORMANT | 3 | toggle | arbitrate sleeve candidates | ☐ | | |
| L1-7 | Med | CONFIRMED | 3 | live-file+toggle | news guard covers sleeve/file | ☐ | | |
| L3-5 | Med | CONFIRMED-DORMANT | 3 | toggle | independent shared session clock | ☐ | | |
| L5-3 | Low | CONFIRMED-DORMANT | 3 | toggle | single short-protection owner | ☐ | | |
| L8-3 | Med | CONFIRMED-DORMANT | 3 | off-config | profile AUTO / fail-closed | ☐ | | |
| L5-1 | High | PARTIAL | 4 | live marginal | reject below-min lot; recompute risk | ☐ | | |
| L5-2 | Med | PARTIAL | 4 | live near-nil | counter-trend rescale fail-closed | ☐ | | |
| L1-5 | Med | PARTIAL (non-default) | 4 | toggle(win≥2) | incumbent/challenger arbitration | ☐ | | |
| L8-2 | Med | INTENDED-SCOPE | 4 | live-DST | Asian-range per-timestamp DST (⚠ vs prior reject) | ☐ | | |
| L8-5 | Low | CONFIRMED-DORMANT | 4 | audit-build | hash effective profile+overrides | ☐ | | |
| L7-5 | High | CONFIG-MITIGATED (done) | 4 | source-default | flip source default true (belt) | ☐ | | |

**No action (verified INTENDED/BENIGN):** O-1…O-17. O-5 (closed-bar ATR) = this session's Task E. Dead
`CQualityTierRiskStrategy` stays dead (fixes target live `Utils.NormalizeLots`/`CTradeOrchestrator`).

## Run log
- **TIER1** (L6-2/L6-3/L1-2 + L7-1..L7-4 combined): primary **d6549628 / \$34,940.18 / 869** = baseline EXACT (byte-identical). GH **b501fecb / \$29,525.85 / 820** (+\$0.06 = L6-3 tick-snap on GH tick!=point; primary binding feed unchanged). Adversarial-reviewed SOUND. Commits 5b056bb + e5c7b8e, tag fix-tier1-liverobustness-34940.
