# UltimateTrader Gold v1 — Production Release Manifest

**Release tag:** `release-ultimate-gold-v1-32490` · **Frozen:** 2026-07-13 · **Status:** SHIP / consolidate (subtractive-optimization frontier reached; next phase = forward operational validation, not backtesting).

## 1 · Frozen artifacts (pin exactly — reject deployment on any mismatch)
| Item | Value |
|---|---|
| Source commit | `eee95ed` (branch `feat/multi-strategy`; last source-affecting commit `fbd25b9`) |
| EX5 hash (md5) | `7a10211eece460922be11ff4ca718499` (`UltimateTrader.ex5`, deployed as `UltimateTrader_FREEZE_SD.ex5`) |
| Config-of-record | `risk_R90.ini` md5 `cebf95788d43fbb3936b4fd9ce02659c` |
| Broker / terminal | Vantage Markets MT5 (Vantage Markets MT5 Terminal build) |
| Symbol | `XAUUSD+` (H1) — confirm suffix/contract-size/tick-value/lot-step live before Stage 2 |
| Deposit / leverage (reference run) | $10,000 / 1:100 |
| Backtest window / model | 2019.01.01 → 2026.06.27, **Model 4 (real ticks)** |
| Deployment date | (set at go-live) |

## 2 · Reference metrics (canonical release run, archive `idrun_SDID`)
Reproduce to the cent before deploying; a divergence means the environment differs.

| Metric | Value |
|---|--:|
| **Net profit** | **$32,490.33** |
| **Positions** | **865** (report trades 1,895 / deals 2,760) |
| **Sharpe** | **2.87** |
| Profit Factor | 1.41 |
| Expected payoff | $17.15 |
| Equity DD (max) | $6,758.36 (14.14%) |
| Balance DD (max) | $5,279.95 (11.37%) |
| **R-based DD (max)** | **13.8 R** ← the operational drawdown-tolerance anchor |

**Strategy-level positions:** PinBar 418 · Engulfing 160 · Crash 150 · MACross 58 · PBC 43 · Expansion 26 · FailedBreakReversal 10.

Cross-validation (same config, other feeds/models): prod-M1 2019-25 ≈ $40.4k; GoldHistory 2019-25 ≈ $28.8k; positive across 2011-17 / 2013-15 / 2016-17 / 2006-10.

## 3 · Adopted behavior — the ONLY enabled changes (config-of-record pins)
```
InpTesterDSTFix=true                 # Phase-0.5 DST correction (tester-only; live auto-detect untouched)
InpCrashRequireFreshDeathCross=true  # Crash fires only on a fresh (<150 D1-bar) death-cross
InpEngulfingRegimePolicy=1           # block bullish Engulfing in the raw D1 death-cross
InpEngulfingBlockSetupA=true         # block Engulfing SETUP_A tier (macro-contaminated, neg-R in 4 windows)
InpPBCBlockSetupA=true               # block PullbackContinuation SETUP_A tier (tier inversion)
```
Provenance: `baseline-dst-24829` → `baseline-crashfresh-24829` → `baseline-engulf-27146` → `baseline-pbc-29628` → `baseline-enga-32490` → **this release**. Manifests: `crash-adoption-manifest`, `engulfing-adoption-manifest`, `pbc-adoption-manifest`, `engulfing-a-adoption-manifest`.

## 4 · Compiled-but-disabled experimental inputs (leave at default = identity)
`InpEngulfingBodyRatio=0.8` · `InpPinBarFlatRiskPct=0.0` · `InpVolFilterEngulfing/Crash/VolBreakout=true` · `InpMaxSameDirRisk=0.0` / `InpSameDirCapResize=false`. All proven identity ($32,490.33/865). Do not enable without a new adoption campaign.

## 5 · CLOSED — do-not-relitigate without genuinely new evidence
Engulfing candle-tightening (structural 44% portability ceiling) · PinBar tier-risk flattening (fails cross-feed) · Volume-filter removal/softening (validated healthy hard gate; ablations lose $3.6–15k/feed) · Same-direction exposure caps (DD is breadth-driven; cost >>5% net) · Generic BE/trailing/ladder/TP-ceiling geometry (measured-closed) · Standalone-entry subgroup gating (no cross-feed-stable negative cohort). Evidence: `goldhistory-engulfing-arm2`, `pinbar-flatrisk`, `volume-filter-audit`, `exposure-cap-audit`, `exit-attribution`, `standalone-audit`.

## 6 · Deployment rehearsal (clean terminal, before any capital)
1. Install frozen EX5 + `risk_R90.ini` on a clean terminal; verify md5s (§1).
2. Confirm symbol suffix, contract size, tick value, lot step, min-lot.
3. Confirm server-time / DST behaviour (live path uses auto-detect, NOT the tester `InpTesterDSTFix`).
4. Confirm news-calendar data + any external dependency resolves (or is off).
5. Confirm terminal restart + VPS restart recovery.
6. Confirm existing-position reconstruction (state file rebuild).
7. Confirm duplicate-entry prevention (one signal → one order).
8. Confirm partial-close behaviour under the broker's min-lot rules.
9. Confirm logs + CSV telemetry write and rotate.
10. Execute one controlled **minimum-lot** trade through the full lifecycle (entry → partials → trail → exit).

## 7 · Staged-risk rollout (promote on completed trades + operational correctness, not calendar time)
`Stage 1 shadow (no orders)` → `Stage 2 min risk` → `Stage 3 25%` → `Stage 4 50%` → `Stage 5 full`.
At each stage verify vs the release reference: signal counts by engine, rejection counts by gate, entry slippage, spread at entry, sizing accuracy, partial-close execution, commission/swap, exit-reason distribution, realized R vs tester expectation.

## 8 · Live drift controls (distribution-based, not equity-curve-based)
A live loss can be normal; a **distribution shift** is the alarm. Monitor rolling and compare to the release-reference distributions: signals/fills per strategy, long/short mix, grade distribution, volume-filter pass rate, D1 death-cross state, rejection-reason mix, avg initial risk, slippage/spread, avg R, win rate, DD ($ and R), consecutive losses, max simultaneous exposure. Key ratios vs reference: PinBar/Engulfing/Crash share of fills; SETUP_A rejection counts (should be non-zero — the adopted blocks are firing).

## 9 · Operational kill switches (PAUSE NEW ENTRIES; existing trades managed)
Trigger on: sizing materially ≠ requested risk · duplicate orders · repeated stop/partial rejection · wrong server-time / D1-state · data gaps or stale bars · directional/total exposure over configured limits · lost state after restart · implausible strategy/gate distribution shift · **live R-drawdown beyond the release tolerance (anchor: 13.8R max; set the pause threshold as a multiple of the validated R-DD distribution, not a cash figure).**

## 10 · Future research policy
This release branch is **immutable except verified correctness defects**. Any additive engine lives on `research/additive-engine-*` and must prove, against this frozen release: positive standalone expectancy · low correlation with existing daily returns · net improvement after arbitration + exposure limits · both-feed validation · older-regime validation · no R-DD degradation · sufficient trade count · a clear economic thesis stated before implementation. Do not add an engine merely because the subtractive frontier was reached.

## Strategic conclusion
Preserve the validated system, prove it operates correctly live, collect forward evidence, and reopen research only when live telemetry flags a specific discrepancy or a genuinely independent new-edge thesis emerges. **Banked as UltimateTrader Gold v1 — $32,490.33 / 865 / Sharpe 2.87.**

---

## 11 · Research frontier reached — transition to forward validation
The historical gold-only optimization program is **closed**. Nine successive investigations (3 adopted edges → this release; 6 suspected weaknesses vetted to confident negatives; 2 rejected upside theses — regime sizing overlay, Gold-v2 opportunity engines) establish the correctly-scoped conclusion:

> Within the current architecture and available historical evidence, **no additional gold-only entry filter, exit change, sizing overlay, exposure rule, additive opportunity sleeve or weak-regime governor has shown sufficient cross-feed, cross-era and portfolio-level value to justify production complexity. The architecture has reached its research frontier on the currently available data** — not an absolute ceiling.

What the research also established (record for context): the EA is **not** a hard-bull-only system — SLOW_DRIFT is its *strongest* state, CHOPPY_UPTREND its biggest earner, and EXPANSION/BEAR/VOLATILE-TWOWAY all profitable; the state-level edge is broader than the annual $ distribution suggests. Its weak states (CORRECTION, RANGE_BOUND) are genuine but not economically large, and the remaining losses are the **necessary losing tail of positive strategies** — not separable at entry, not an exit-capture defect, not stacking, not the volume gate, not the tier map. Gold-v2 research is archived **CLOSED — no production action** (`research/gold-v2-opportunity-geometry`; reason: governor ceiling below materiality). The analyses are not failures — they proved the apparent opportunity gaps were already captured or too small to exploit.

**The next useful evidence must come from OUTSIDE the exhausted historical dataset → forward validation, not more backtesting.** Sequence: shadow execution → minimum executable risk → staged rollout (§6–8), tracking **R, not just dollars** (short-run live $ is sequence noise; behavioural + normalized-R drift is the signal). Primary question at each stage: *does the live EA behave like the frozen backtest system?*

### Research-reopening triggers (do NOT reopen on a losing month)
Reopen historical research ONLY on one of:
1. **Behavioural discrepancy** — a strategy/gate behaves materially differently live than in the release data (e.g. signal frequency doubles, volume-filter pass-rate shifts sharply, Pin Bar/Engulfing contribution collapses, lot sizing/partials diverge from tester, live spread/slippage eats far more R than modelled).
2. **New independent evidence** — enough genuinely new gold history accumulates to test the conclusions *outside* the already-inspected periods.
3. **Specific repeated live weakness** — a broad, interpretable cohort repeatedly fails live and was not represented historically.
4. **New economic thesis** — a new gold mechanism proposed *before* seeing its profitability, with a plausible market explanation and an observable setup — not another rearrangement of current indicators.

**Transition, in one line:** *Stop optimizing the backtest. Start validating the frozen behaviour in forward execution.*
