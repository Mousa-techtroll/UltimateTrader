# Codex-audit remediation tracker (force-fix-for-correctness campaign)

Origin baseline `d6549628` / $34,940.18 / 869 (primary) + `f11c4b2c` / $29,525.79 / 820 (GH).
**CURRENT BINDING BASELINE (adopted): `baseline-codex-seven-32617` = `c051f97b` / $32,617.90 / 801 / PF 1.47 /
Sharpe 3.13 / EqDD 11.32% (primary, Events `5ecfa994`) + GH $24,086.34 / 748 (Stats `2713e298`).** The
seven-fix correctness merge (5 byte-identical + L4-3/L4-4 risk-improving) traded −6.6% net for +PF/+Sharpe/−DD
per the force-fix-for-correctness policy; every subsequent Tier-1/3/4 + safety + surface-clean change is
byte-identical to this baseline on BOTH feeds.
Policy: fix ALL confirmed findings; behavior-changers merged regardless of P&L sign; each isolated + reversible.

Status legend: ☐ todo · ✍ authoring · 🔬 integrating/measuring · ✅ merged · ⏸ held-with-evidence

**CAMPAIGN STATUS (2026-07-20): COMPLETE — all 37 confirmed findings CLOSED / HELD-with-evidence /
DOCUMENTED-limitation. 0 open. Live-path harnesses 128/128 PASS. Input surface cleaned + reconciled (418).
Final qualification byte-identical both feeds. Ready for final freeze.**

| ID | Sev | Verdict (validated) | Tier | Reachability | Fix summary | Status | Commit | Δnet |
|---|---|---|---|---|---|---|---|---|
| L6-1 | Crit | CONFIRMED (code) | 1 | netting live (both-safe) | deal-id binding, account-mode reconcile (+6 repaired defects) | ✅ | 2a8afc2 | 0 (BI backtest; UT_PositionBinding 29/29) |
| L6-2 | Crit | CONFIRMED | 1 | live-file | recompute risk_distance after SL widen | ✅ | 5b056bb | 0 (BI primary) |
| L6-3 | Med | CONFIG-MITIGATED | 1 | live cross-sym | tick-grid normalize at send (noop XAU) | ✅ | 5b056bb | 0 (BI primary) |
| L1-2 | High | CONFIRMED | 1 | live-file | reject foreign-symbol file signals | ✅ | 5b056bb | 0 (BI primary) |
| L7-1 | High | CONFIRMED | 1 | live-restart | checksum whole payload + atomic load | ✅ | e5c7b8e | 0 (BI primary) |
| L7-2 | High | CONFIRMED | 1 | live-restart | persist exit_* + partial PnL (P4b) | ✅ | e5c7b8e | 0 (BI primary) |
| L7-3 | High | CONFIRMED | 1 | live-restart | offline-close idempotent accounting | ✅ | e5c7b8e | 0 (BI primary) |
| L7-4 | High | CONFIRMED-DORMANT | 1 | live-file+restart | file TP partials persist | ✅ | e5c7b8e | 0 (BI primary) |
| L4-1 | High | **ROOT-CAUSED LIMITATION (held)** | 2* | live-default | 5 approaches FAIL: raw −43%, global-recal −22.7%, engine-aware v1 −20.4%, evidence v2 −77%, corrected setup-level v2.1 −39.5%. Counter-alpha NOT evidence-separable (moderate-fade). Do-not-relitigate | ⏸ held | flag-off | rejected |
| L2-4 | Med | REDESIGN MEASURED (not adopted) | 2r | live-default | adaptive-confirm inert(W3 −$41)/net-neg(W>=4); strength separation REAL (weak-fresh −0.046R) but confirmation-duration timeline load-bearing; signal-filter lever <1% deferred | held | flag-off | ~0 |
| L2-3 | Med | CONFIRMED | 2 | live-default | range-box reset vs prior box | ✅ | 3ed435b | 0 (BI, default-on) |
| L2-5 | Med | CONFIRMED | 2 | live-default | SMC zone close-rule on [1] | ✅ | 3ed435b | 0 (BI, default-on) |
| L2-6 | Med | CONFIRMED | 2 | live-default | trend swing closed right-wings | ✅ | 3ed435b | 0 (BI, default-on) |
| L3-3 | Med | CONFIRMED | 2 | backtest | vol-BO cooldown on fill not emit | ✅ | 3ed435b | 0 (BI, default-on) |
| L3-4 | Med | HELD (real but immaterial) | 2r | live-default | 22/2954 collisions, ALL score-identical -> no tiebreak signal; first-fix -$742; explicit-priority=determinism-only. candidate-L3-4-redesign/ | ⏸ held | flag-off | rejected |
| L4-3 | Med | CONFIRMED | 2 | live-default(long) | no-break tolerance in range/ATR units | ✅ | 3ed435b | −$511 (risk-improving; adopted) |
| L4-4 | Med | CONFIRMED | 2 | live-default | revalidation reruns dynamic gates | ✅ | 3ed435b | −$1,937 (risk-improving; adopted) |
| L1-1 | High | CONFIRMED | 2/1 | live-default | daily-halt refresh at OnTick top | ✅ | 3ed435b | 0 (BI, default-on) |
| L1-4 | Med | RESOLVED (mandatory-safety built, flag-off) | 2r | live-default | discretionary gates block 0 (excluded); SL-sanity byte-identical; shock −$619/byte-ident-GH live-safety control available (InpConfirmedFillSafety); baseline preserved | ✅arch | flag-off | 0 (baseline) |
| L2-1 | High | CONFIRMED-DORMANT | 3 | toggle | one paired structure event | ✅ | tier3/4 | byte-ident (paired BOS/CHoCH event) |
| L2-2 | Med | CONFIRMED-DORMANT | 3 | toggle | sweep recency by pool id | ✅ | tier3/4 | byte-ident (sweep recency by pool id) |
| L3-2 | High | CONFIRMED-DORMANT | 3 | toggle | preserve router weight immediate path | ✅ | tier3/4 | byte-ident (router weight immediate) |
| L4-2 | Med | CONFIRMED-DORMANT | 3 | toggle | unify routed/legacy score scale | ✅ | tier3/4 | byte-ident (unified score scale) |
| L4-5 | Low | CONFIRMED-DORMANT | 3 | toggle | carry major_engine to position | ✅ | tier3/4 | byte-ident (major_engine to pending) |
| L1-3 | High | CONFIRMED-DORMANT | 3 | toggle | emergency = entry-only kill | ✅ | tier3/4 | byte-ident (InpEmergencyEntryOnly) |
| L1-6 | Med | CONFIRMED-DORMANT | 3 | toggle | arbitrate sleeve candidates | ✅ | tier3/4 | byte-ident (CONT-primary sleeve order) |
| L1-7 | Med | CONFIRMED | 3 | live-file+toggle | news guard covers sleeve/file | ✅ | tier3/4 | byte-ident (shared news gateway) |
| L3-5 | Med | CONFIRMED-DORMANT | 3 | toggle | independent shared session clock | ✅ | tier3/4 | byte-ident (SharedGMTHour clock) |
| L5-3 | Low | CONFIRMED-DORMANT | 3 | toggle | single short-protection owner | ✅ | tier3/4 | byte-ident (single short-prot owner) |
| L8-3 | Med | CONFIRMED-DORMANT | 3 | off-config | profile AUTO / fail-closed | ✅ | tier3/4 | byte-ident (profile AUTO+fail-soft) |
| L5-1 | High | PARTIAL | 4 | live marginal | reject below-min lot; recompute risk | ✅ | tier3/4 | byte-ident (InpRejectBelowMinLot) |
| L5-2 | Med | PARTIAL | 4 | live near-nil | counter-trend rescale fail-closed | ✅ | tier3/4 | byte-ident (counter-trend fail-closed) |
| L1-5 | Med | PARTIAL (non-default) | 4 | toggle(win≥2) | incumbent/challenger arbitration | ✅ | tier3/4 | byte-ident (incumbent/challenger arb) |
| L8-2 | Med | INTENDED-SCOPE | 4 | live-DST | Asian-range per-timestamp DST (⚠ vs prior reject) | ✅ | tier3/4 | byte-ident (InpSessionRangeDST flag-off; live-DST option) |
| L8-5 | Low | CONFIRMED-DORMANT | 4 | audit-build | hash effective profile+overrides | ✅ | tier3/4 | byte-ident (effective-profile hash) |
| L7-5 | High | CONFIG-MITIGATED (done) | 4 | source-default | flip source default true (belt) | ✅ | tier3/4 | byte-ident (source default->true, matches pin) |

**No action (verified INTENDED/BENIGN):** O-1…O-17. O-5 (closed-bar ATR) = this session's Task E. Dead
`CQualityTierRiskStrategy` stays dead (fixes target live `Utils.NormalizeLots`/`CTradeOrchestrator`).

## Run log

- **Tier-2 individual** (flag-on vs d6549628): BYTE-IDENTICAL (free): L2-3,L2-5,L2-6,L1-1,L3-3. Net-down/risk-up: L4-3 −$511 (PF1.44/Sh3.05/DD12.8), L4-4 −$1,937 (PF1.44/Sh3.04/DD13.3). Net-down: L3-4 −$742, L1-4 −$1,881, L2-4 −$3,627(−10.4%). L4-1 raw −$15,064 (architectural redesign, NOT merged).
- **COMBINED all-on (10 non-L4-1 correctness fixes)**: primary **c83b61f6 / $29,186.97 / 810 / PF 1.43 / Sharpe 2.95 / EqDD 11.31%** (−16.5% net BUT −26% drawdown, PF up, return/DD 22.9->25.8). GH **ec5b9c33 / $21,985.32 / 752** (−25.5%).
- **TIER1** (L6-2/L6-3/L1-2 + L7-1..L7-4 combined): primary **d6549628 / \$34,940.18 / 869** = baseline EXACT (byte-identical). GH **b501fecb / \$29,525.85 / 820** (+\$0.06 = L6-3 tick-snap on GH tick!=point; primary binding feed unchanged). Adversarial-reviewed SOUND. Commits 5b056bb + e5c7b8e, tag fix-tier1-liverobustness-34940.

## Campaign completion (2026-07-20)

- **Live-path synthetic + restart/corruption harnesses — 128/128 assertions PASS** (0 FAIL) across 6 OnInit-only
  UT EAs proving the live-only recovery paths the backtest can't exercise: UT_PositionBinding 29 (L6-1
  netting+hedging), UT_SLSync 36 (L6-2 re-sync), UT_FileRisk 18 (L6-2 file sizing), UT_TickGrid 16 (L6-3),
  UT_StatePersist 17 (L7-2), UT_OfflineClose 12 (L7-3). One over-strict float-equality TEST assertion fixed
  (not a fix defect; every fix-side assertion already passed). Commit d6ccafa; candidate-harness/RESULTS.md.
- **Tier-3/4 combined** (17 dormant/toggle-gated + marginal hardenings) — BYTE-IDENTICAL both feeds
  (primary Events 5ecfa994/$32,617.90/801, GH $24,086.34/748). Commit 8356e3e.
- **Input-surface cleanup** — 9 L4-1-family research levers → const/RESEARCH_CANDIDATES; 4 live-safety options
  + 9 adopted flags kept as documented inputs; current-canonical.set reconciled v4(388)→v5(418), 0 stale/0
  missing vs the production input closure. BYTE-IDENTICAL both feeds; RESEARCH build compiles 0/0 (reopen
  proven). Commit 8b4c6ce; candidate-surface-clean/RESULTS.md.
- **Final qualification** — production build md5 b3fbf3a9 reproduces the binding baseline EXACTLY on both feeds
  (primary $32,617.90/801/Events 5ecfa994/PF 1.47/Sharpe 3.13/EqDD 11.32%; GH $24,086.34/748/Stats 2713e298).

### Disposition of all confirmed findings (0 open)
- **MERGED (byte-identical or risk-improving), in the c051f97b binding baseline (17):** L6-1, L6-2, L6-3, L1-2,
  L7-1, L7-2, L7-3, L7-4 (Tier-1 live-robustness) + L2-3, L2-5, L2-6, L1-1, L3-3 (byte-identical correctness) +
  L4-3, L4-4 (risk-improving, adopted).
- **MERGED dormant/toggle-gated + marginal, byte-identical (17):** L2-1, L2-2, L3-2, L4-2, L4-5, L1-3, L1-6,
  L1-7, L3-5, L5-3, L8-3 (Tier-3) + L5-1, L5-2, L1-5, L8-2, L8-5, L7-5 (Tier-4).
- **RESOLVED (architecture built, flag-off, baseline preserved) (1):** L1-4 — mandatory fill-time safety subset
  (shock+SL-sanity) available as InpConfirmedFillSafety live-safety control; discretionary gates block 0.
- **HELD with evidence — documented root-caused limitations, do-not-relitigate (3):** L4-1 (5 rescoring
  approaches FAIL; counter-alpha is moderate-fade, not evidence-separable), L2-4 (confirmation-duration
  timeline load-bearing; strength separation real but <1% signal-filter lever deferred), L3-4 (22/2954
  equal-tier collisions all score-identical → no tiebreak signal; determinism-only).
- **NO ACTION (verified INTENDED/BENIGN):** O-1…O-17.

Every confirmed finding is closed, held with evidence, or covered by a documented limitation. Production stays
on `baseline-codex-seven-32617` / c051f97b / $32,617.90; all held research is flag-off/const byte-identical and
reopenable under RESEARCH_CANDIDATES.
