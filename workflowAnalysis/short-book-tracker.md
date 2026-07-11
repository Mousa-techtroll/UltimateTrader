# Short-Book Program (SB) — STATUS TRACKER

**Registered:** 2026-07-11 (owner's program spec, delivered verbatim in-session) · **Baseline of record:** $23,856.89 / EqDD 13.14% / 952 positions (tag `baseline-23856-2026-07-11`) · **Evidence base:** `short-side-diagnosis.md` + forensics/economics/market-structure trio (commit `98503ec`), CRH4 FIT-stop (slot isolation + DD dose control = binding retry constraints), SF-1 adoption / SF-2 kill.
**House rules apply:** pre-registered gates, identity-to-the-cent before every arm, default-off levers, FIT derives / one CONFIRM never softened, matched-cohort ΔR on position-level n, per-arm CSV archiving.

**Status legend:** ✅ done · 🟡 partial · 📐 designed · ❌ killed variant · ⬜ not started

---

## Phase 0 — Short-side infrastructure

### SB-0.1 — Dedicated experimental short sleeve (CRITICAL)
- [x] ✅ **DONE 2026-07-11** (engines-off + on-empty acceptance met; engines-on clause measured with the first engine)
  - [x] Gateway `CTradeOrchestrator::ExecuteSleeveSignal` — 10-step check order (master/direction/poscap/slot-reserve/risk caps/DD+daily halts/account backstops → ExecuteSignal chokepoint, exposure ceiling never bypassed)
  - [x] 13 baseline count/exposure sites EXCLUDED (audit table in the implementation report; includes HasOpenSameFamily — the CRH4 breach mechanism); 2 registered-inclusive exceptions (account exposure ceiling, equity-coupled daily halt)
  - [x] Position tagging (is_sleeve + family), state file v6→v7, Stats CSV 106→108, manifest SLEEVE rows, sleeve P&L/DD/daily ledger persisted
  - [x] **Identity EXACT both ways: OFF and ON-empty = $23,856.89/2,053/952 to the cent** (ceg_SLVID/ceg_SLVON)
- Scope: independent short-research sleeve — master switch + per-sleeve limits (max 1 experimental position; incremental risk 0.25–0.40%; sleeve DD cap; daily sleeve loss cap; per-family risk cap; position-slot reservation so no baseline displacement; same-direction concurrency cap; account exposure ceiling still binding; independent sleeve DD tracking; sleeve-tagged positions + separate direct/interaction P&L reporting).
- Existing assets: CRH4's slot-isolation lesson (off-cohort breach mechanism identified: exposure/slot interactions through pos-cap and same-direction machinery); §D/SF harness + cohort analyzer; manifest logging conventions.
- **Acceptance (registered):** engines OFF → 952 positions reproduce exactly, net/DD/lifecycle logs match binding baseline. Sleeve ON with no engine → still identity. Engine ON (later phases) → baseline decisions identical; every sleeve position identifiable; direct + interaction P&L separately reported.

### SB-0.2 — Permanent short-opportunity ledger
- [ ] 🟡 partial by prior work — the offline analogue exists (opportunity map's 48h-chunk down-opportunity accounting; economics' per-era yield table; forensics' funnel counts). Remaining: per-H1-bar market-state column (depends on SB-1.1 state model), per-engine raw/validated/blocked/filled/missed logging (extends the shadow-kill logger pattern), and the six core metrics computed per bearish leg (fills/leg, R per $100 down-opp, profit per bearish quarter, participation rate, DD contribution, bull-period false-positive rate).
- Sequencing: state column rides SB-1.1's shadow phase; engine-proposal logging rides the first sleeve engine's instrumentation leg.

### SB-0.3 — Dedicated short validator
- [ ] ⬜ — evidence base ready: forensics proved shorts bypass the TF/MR validator entirely (0 vs 532 rejects) and every claimed bypass "protection" is dead code on the config of record. Typed paths per family (bearish continuation / breakdown-retest / correction momentum / rally fade / range-edge reversal) with the owner's input list; every candidate logs family, state, passed/failed checks, projected net RR, risk allocation, accept/reject reason.
- Sequencing: after SB-1.1 (validator consumes D1/H4 state) and inside the sleeve (SB-0.1) so validator experiments never touch baseline shorts. NOTE: baseline bear pins / crash remain governed by their current (measured, adopted) path — the new validator governs SLEEVE candidates only, else identity breaks.

---

## Phase 1 — Correction-state and bear-event detection

### SB-1.1 — Correction & Bear Event state model (CRITICAL)
- [x] ✅ **DONE (offline validated + EA-side ledger-as-data 100% verified)** — was: **OFFLINE SHADOW COMPLETE — all 4 registered clauses PASS (first frozen set, revision unused); awaiting owner approval for the EA-side shadow stamp + CREV use**
  - [x] Frozen rule set (sb11-state-model.md, MQL5-implementable) + deterministic prototype + 44,437-bar state ledger (sb11_states.csv)
  - [x] Detection lead vs D1 cross: E5 134d / E8 110d / E4 66d earlier
  - [x] 2024–25 false-positive audit: 1 genuine 3-day mislabel (3.6% bear-label share of bull bars)
  - [x] Stability: 40 bear episodes/7.5y, median 11.5d (rule: gate on family+severity, BEAR_RALLY overlay churns)
  - [x] State×results join: BEAR_TRANSITION shorts +0.403 avg R (n=53) = best cell in the book; BULL_PULLBACK/VOLATILE = short-veto states; **CREV dose inversion of record: full risk in BEAR_TRANSITION, reduced in BEAR_TREND**
  - [x] Owner approved 2026-07-11 (dose ruling: spec as written — reduced risk BEAR_TRANSITION, full BEAR_TREND; measured +0.403R inversion recorded, not acted pre-evidence)
  - [~] EA-side in-binary state model built (CBearStateModel, decision-free, identity exact) but reproduces Python only ~97.4% (mature) — per-feature scoring drift + 2019 warmup; kept as the LIVE-PORT SEED (WIP, commit 91c6043)
  - [x] **Architecture decision (owner 2026-07-11): LEDGER-AS-DATA** — CREV backtest reads the frozen validated `sb11_states.csv` (staged as Common/Files/BearStates_XAUUSD.csv) as a tester file (exact by construction, news-filter hybrid precedent); in-EA model fidelity is a separate live-port task verified on full history. Removes state fidelity as a CREV confound.
  - [x] ✅ Ledger-source reader done + VERIFIED 100.0000% (44,266/44,266 state+full-row vs sb11_states.csv); both identity legs exact. **SB-1.1 DONE — CREV consumes exact validated states.**
- 8 states (BULL_TREND, BULL_PULLBACK, ACTIVE_CORRECTION, BEAR_TRANSITION, BEAR_TREND, BEAR_RALLY, VOLATILE_TRANSITION, RANGE); interpretable feature set (D1/H4 EMA structure+slope, H4 LH/LL sequence, support breaks + failed reclaims, distance from swing high, multi-day RoC, ATR expansion, consecutive bear closes, % closes below H4 EMAs, recovery strength, ADX); transparent state score + transition logic; hysteresis (min H4 bars, separate entry/exit thresholds, state age, transition confidence).
- Deployment: SHADOW ONLY first — offline Python prototype on the H1/H4/D1 rates, validated against the hand-labeled episode table (market-structure doc E1–E8), then long/short results measured by state, then (only if approved) an EA-side shadow stamp (decision-free column, identity leg).
- **Acceptance (registered):** 2023 + 2026H1 corrections detected materially earlier than the D1 death cross (reference: cross printed 2021-03-04 for E2, 11 days after 2026H1 ended for E8); 2024–25 bull pullbacks NOT systematically labeled bear; transitions stable enough to trade; zero live decision changes during shadow.

### SB-1.2 — CREV as the first sleeve strategy (CRITICAL)
- [x] ❌ CLOSED NO-CHANGE: v1 starved (3 fills/7.5y), v2 arm→trigger (4 FIT fills, ALL losers, avg R −0.765 → FAILS FIT gate, no CONFIRM per registration). Rally-fade participation not a validated edge (fades squeeze-prone; breakdown-retest PF 0.57). Baseline isolation EXACT across all 4 CREV runs (sleeve permanently solves the CRH4 failure mode). Levers default-off. → pivot to SB-2.1 (continuation). Original design note:
- [ ] 📐 partially — the market-structure CREV spec (bear-event OR-gate, PF 1.11 reconstructed, traded E5+E8) is the seed, now UPGRADED by the owner's spec: state-driven (ACTIVE_CORRECTION/BEAR_TRANSITION/BEAR_TREND), rally-fade entry (rally to H1 EMA21/50 or broken support, momentum turn, bearish rejection, valid lower high, room-to-support via SB-0.3 validator), sleeve risk rules (0.25–0.35%, max 1, cooldown after loss, reduced risk in BEAR_TRANSITION, full only in BEAR_TREND, no re-entry within same impulse), short-specific exits (partial at recent H1 low/1R, second at structural support, lower-high structure trail, max-hold rule, NO generic chandelier clamp).
- **FIT gates (registered):** incremental avg R ≥ 0; zero baseline displacement; book EqDD ≤ +0.30pp; no year worse >$500; sleeve DD within registered limit; no bull-period loss cluster. **CONFIRM:** positive direct CREV contribution; positive ex-2025; ≥1 valid contribution in 2023 or 2026H1; DD gate; no 1–2-trade dependence.
- Sequencing: strictly after SB-0.1 identity + SB-1.1 shadow approval.

---

## Phase 2 — Genuine bearish continuation

### SB-2.1 — H4/H1 lower-high continuation engine (VERY HIGH)
- [ ] ⬜ — the intended primary professional short strategy. H4 structure (LL + rally below prior swing high + bearish momentum, state-gated) + H1 setup (impulse LL → retrace to EMA21/50/broken support/38–62% → lower high → continuation trigger). **Owner rule of record: bearish candle patterns ONLY as final trigger inside validated structure — never generic bearish Engulfing alone.** Stop above pullback high + spread/structure buffer; TP1 prior low/1R, TP2 next H4 support, runner only while state bearish.
- Acceptance: positive avg R FIT+CONFIRM; positive in >1 bearish leg; no bull-pullback loss cluster; ≥20–30 fills before production consideration; no single-year majority.

### SB-2.2 — Breakdown & failed-reclaim engine (HIGH)
- [ ] ⬜ — NOTE the market-structure agent's a-priori sim measured naive breakdown-retest at PF 0.57 (gold reclaims its levels). The owner's spec differs in the load-bearing detail: entry on FAILED reclaim (reclaim attempted and rejected), not on the retest touch — this is the variant the sim did NOT price. Registered as one entry variant only (first bearish close after failed reclaim); min breakout size vs ATR, volume/momentum, room after costs, not into next support, state ≠ BULL_PULLBACK; per-level cooldown, no repeat entries on the same level.
- Acceptance: incremental avg R positive; stable across ≥2 bearish periods; no slippage cliff; no duplicate entries per level.

---

## Sequencing of record
SB-0.1 (sleeve) → SB-1.1 (offline shadow → approval) → SB-0.3 (validator, sleeve-scoped) + SB-0.2 (ledger columns) → SB-1.2 (CREV, first sleeve arm) → SB-2.1 → SB-2.2. One engine measured at a time; each on its own binary per one-change-per-binary; the sleeve master + all engines default-off forever in source.
