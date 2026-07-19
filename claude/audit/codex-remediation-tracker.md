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
| L4-1 | High | **ROOT-CAUSED LIMITATION (held)** | 2* | live-default | 4 approaches FAIL: raw −43%, global-recal −22.7%, engine-aware v1 −20.4%, evidence-gated v2 −77%. ROOT CAUSE: exhaustion-evidence ANTI-predictive (ev≥2 loses; alpha is moderate-fade). Do-not-relitigate | ⏸ held | flag-off | rejected |
| L2-4 | Med | REDESIGN MEASURED (not adopted) | 2r | live-default | adaptive-confirm inert(W3 −$41)/net-neg(W>=4); strength separation REAL (weak-fresh −0.046R) but confirmation-duration timeline load-bearing; signal-filter lever <1% deferred | held | flag-off | ~0 |
| L2-3 | Med | CONFIRMED | 2 | live-default | range-box reset vs prior box | ☐ | | |
| L2-5 | Med | CONFIRMED | 2 | live-default | SMC zone close-rule on [1] | ☐ | | |
| L2-6 | Med | CONFIRMED | 2 | live-default | trend swing closed right-wings | ☐ | | |
| L3-3 | Med | CONFIRMED | 2 | backtest | vol-BO cooldown on fill not emit | ☐ | | |
| L3-4 | Med | CONFIRMED | 2 | backtest | equal-tier explicit tie-breaker | ↻ REDESIGN | first-fix rejected (−$742) | defect-open |
| L4-3 | Med | CONFIRMED | 2 | live-default(long) | no-break tolerance in range/ATR units | ☐ | | |
| L4-4 | Med | CONFIRMED | 2 | live-default | revalidation reruns dynamic gates | ☐ | | |
| L1-1 | High | CONFIRMED | 2/1 | live-default | daily-halt refresh at OnTick top | ☐ | | |
| L1-4 | Med | CONFIRMED (benign) | 2 | live-default | enforce confirmed-path gates (−$578) | ↻ REDESIGN | first-fix rejected (−$1,881) | defect-open |
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

- **Tier-2 individual** (flag-on vs d6549628): BYTE-IDENTICAL (free): L2-3,L2-5,L2-6,L1-1,L3-3. Net-down/risk-up: L4-3 −$511 (PF1.44/Sh3.05/DD12.8), L4-4 −$1,937 (PF1.44/Sh3.04/DD13.3). Net-down: L3-4 −$742, L1-4 −$1,881, L2-4 −$3,627(−10.4%). L4-1 raw −$15,064 (architectural redesign, NOT merged).
- **COMBINED all-on (10 non-L4-1 correctness fixes)**: primary **c83b61f6 / $29,186.97 / 810 / PF 1.43 / Sharpe 2.95 / EqDD 11.31%** (−16.5% net BUT −26% drawdown, PF up, return/DD 22.9->25.8). GH **ec5b9c33 / $21,985.32 / 752** (−25.5%).
- **TIER1** (L6-2/L6-3/L1-2 + L7-1..L7-4 combined): primary **d6549628 / \$34,940.18 / 869** = baseline EXACT (byte-identical). GH **b501fecb / \$29,525.85 / 820** (+\$0.06 = L6-3 tick-snap on GH tick!=point; primary binding feed unchanged). Adversarial-reviewed SOUND. Commits 5b056bb + e5c7b8e, tag fix-tier1-liverobustness-34940.
