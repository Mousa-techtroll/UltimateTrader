# EVAL-WT5 — Risk / Sizing Model (stok, clean-room, static)

Scope: `CQualityTierRiskStrategy`, `CEquityCurveRiskController` (EC v3), `CRegimeRiskScaler`,
`CRiskMonitor`, and the full multiplicative multiplier stack in OnTick + `CTradeOrchestrator::ExecuteSignal`.
Reasoned from CODE. CSV (`all_trades_v15.csv`) used as DIRECTIONAL cross-reference only (Model-1 artifact).

---

## VERDICT (headline)

**Risk-model grade: C+ (sound core, dead plumbing, one structurally-dead tier, cap that doesn't bind).**

Fixed-fractional sizing is **arithmetically correct** and the design philosophy (tier → base risk, then
graded de-risking via EC/session/regime, hard per-trade cap, portfolio backstop, daily-loss halt) is coherent
and conservative for gold. BUT:

1. **The headline risk plugin (`CQualityTierRiskStrategy`) is DEAD at sizing time** — never `Initialize()`d,
   so it returns invalid and the orchestrator's **inline fallback** does the actual lot math. Steps 2–7 of the
   plugin (loss-scaling, vol-adjust, short-protection, health, engine-weight, plugin-cap) **never run**. Final
   risk % is still correct (fallback trusts the already-stacked `signal.riskPercent`), but a large block of
   "risk logic" in the codebase is inert. (RISK-01, HIGH.)
2. **SETUP_B tier is structurally unreachable** — `InpPointsBSetup=7` == `InpPointsASetup=7`, and the
   classifier checks A (≥7) before B (≥7). The 0.6% B band can never be assigned. B+ (0.75%) is the de-facto
   floor tier. (RISK-02, MEDIUM — by-design per comment, but means the "4-tier" model is a 3-tier model.)
3. **The 2.0% per-trade cap never binds on the observed data** — the in-code comment claims A+ "routinely HITS
   2.0%", but the multiplier stack is net-**reductive** in practice (session 0.50×/0.90× + EC floor pull risk
   DOWN). Model-1 CSV: max realized RiskPct = **1.21%** across 791 entries, avg **0.76%**, zero trades ≥1.5%.
   The cap is a dead backstop, not the realized sizing driver. (RISK-03, MEDIUM — doc/comment vs code/data.)
4. **Constructor-vs-wired divergence is BENIGN** — the stale constructor-comment defaults (A+2.0/A1.5/B+1.0/B0.5)
   do NOT reach sizing. Base risk comes from `CSetupEvaluator` constructed with the LIVE inputs
   (A+1.5/A1.0/B+0.75/B0.6, `UltimateTrader.mq5:561`). The plugin's `GetBaseRiskFromQuality` (which reads the
   live `Inp*` anyway) is dead code on the live path. No wrong number reaches sizing. (Resolved: wired value wins.)

No double-reduction bug found in the **live** path (the two known double-reduction traps are explicitly guarded).

---

## THE FULL ORDERED MULTIPLIER CHAIN (live engine path, non-file)

Seed → stack → cap → size → portfolio cap. Each step mutates `signal.riskPercent`.

| # | Step | Location | Range / value | Notes |
|---|------|----------|--------------|-------|
| 0 | **Base risk = tier × pattern mult** | `CSetupEvaluator::GetRiskForQuality` (CSetupEvaluator.mqh:340–383), seeded `CSignalOrchestrator.mqh:773,783` | tier {A+1.5, A1.0, B+0.75, B0.6} × pattern {MA 1.15, Pin 1.05, Engulf 1.05, BO/engines 1.00} | B tier dead (RISK-02). Pattern mult can push A+ MA to 1.5×1.15 = **1.725%** before any reducer. |
| 1 | **Session risk mult** | OnTick `UltimateTrader.mq5:1858–1888` | London **0.50×**, NY **0.90×**, Asia 1.00× | Biggest single reducer. Multiplicative. |
| 2 | **Wednesday mult** | OnTick `:1892–1904` | 0.85× — **OFF** (`InpEnableWednesdayReduction=false`) | Inert on prod. |
| 3 | **Combined shock × session-quality** | OnTick `:1906–1924` | `shock_factor`∈[0.5,1.0] × `sq_factor`∈(0,1.0], **floored at `InpMinSessionRiskFactor`=0.25** | Two reducers combined ONCE and floored (FIX 5.5) — prevents the historic double-reduction-to-zero. Extreme shock instead BLOCKS the bar. |
| 4 | **Regime risk scaler** | OnTick `:1944–1955` → `CRegimeRiskScaler::ApplyToRisk` (CRegimeRiskScaler.mqh:250) | TRENDING **1.25×**, NORMAL 1.00×, CHOPPY 0.60×, VOLATILE 0.75×; floored at `risk×0.50` | Only AMPLIFYING multiplier in routine use (TRENDING 1.25×). CHOPPY ~never fires on gold (per other recon). |
| 5 | **Quality-trend boost** | OnTick `:1963–1982` | A+ 1.08×, B+ 0.88× — **OFF** (`InpEnableQualityTrendBoost=false`) | Inert on prod. |
| 6 | **ATR-velocity boost** | OnTick `:1986–2002` | **1.15×** when ATR accel > 15% and not mean-reversion | ON. Amplifying. |
| 7 | **EC v3 composite** | `CTradeOrchestrator::ExecuteSignal` `:394–413` → `CEquityCurveRiskController::GetRiskMultiplier` (CEquityCurveRiskController.mqh:472) | **[~0.59 … 1.00]** — only applied when `<1.0` (one-sided reducer). Composite = core[0.70–1.00] × vol[0.90–1.05] × fwd(OFF=1.0) × strat(OFF=1.0); global floor `0.70×0.90×0.92 ≈ 0.5796` | Core EC floor 0.70 (`InpECv2MinMult`). During warmup (<50 closed trades): `WarmupMult 1.0 × vol`, clamped [0.70,1.00]. Vol & core can each only reduce here. |
| 8 | **Short protection** | `ExecuteSignal :416–423` | `InpShortRiskMultiplier` — **1.0× on gold (OFF)** | Inert on prod (USDJPY/GBPJPY profiles would bite). |
| 9 | **HARD PER-TRADE CAP** | `ExecuteSignal :435–442` | `min(maxRiskPercent, InpMaxRiskPerTrade)` = **2.0%** (file: `InpFileMaxRiskPerTrade` 2.0%) | Clamps the *upper* tail of the stack. **Never binds on observed data** (RISK-03). |
| 10 | **Sizing** | `m_risk_strategy.CalculatePositionSizeFromSignal` `:452` → **returns INVALID (uninitialized)** → orchestrator **fallback** `:479–497` | lots = (balance × risk%/100) / (risk_ticks × tick_value) | Plugin Steps 2–7 SKIPPED (RISK-01). Fallback math is correct fixed-fractional. |
| 11 | **Counter-trend 200-EMA halving** | `ExecuteSignal :510–540` | 0.5× **and re-sizes lots** | Applied AFTER lot calc, correctly recomputes lots. Rare for long-biased gold (longs above 200EMA). |
| 12 | **PORTFOLIO EXPOSURE CAP** | `ExecuteSignal :559–630` | lot scaled so `open_risk + new ≤ InpMaxTotalExposure`=**5.0%**; hard-reject if headroom < 1 min-lot | open_risk = sum of **frozen entry-risk** (RISK-04). SL never touched. Correct lot-floor handling (no round-up breach). |

**Effective worst-case amplification before cap:** base(A+ MA 1.725%) × regime(1.25) × ATR-vel(1.15) ≈ **2.48%**
→ clamped to 2.0%. So the cap CAN bind in the trending+accelerating A+ MA corner — but the routine session
reducers (London 0.5×, NY 0.9×) dominate and the realized distribution tops out at 1.21% (Model-1).

**Net character of the stack:** one strong reducer (session), one moderate amplifier (regime TRENDING 1.25),
one small amplifier (ATR-vel 1.15), one graded reducer (EC, floor 0.70). On the observed data the reducers win
→ realized risk ≈ 0.5–1.2%, well under tier base. The stack is **net-conservative**, not incoherent.

---

## FINDINGS (schema)

### RISK-01 — Risk plugin never initialized; sizing silently falls through to orchestrator fallback
- **Severity:** HIGH · **Confidence:** Confirmed · **Category:** WT-5 risk-model / D10
- **Location:** `UltimateTrader.mq5:853` (construct, no Initialize); `CTradeStrategy.mqh:30` (`m_isInitialized=false`);
  `CQualityTierRiskStrategy.mqh:301–305` (early invalid return); `CTradeOrchestrator.mqh:458–497` (fallback).
- **Evidence:** `g_riskStrategy = new CQualityTierRiskStrategy(...)` is the ONLY touch; grep for
  `g_riskStrategy.Initialize` / `m_risk_strategy.Initialize` returns nothing. Base default `m_isInitialized=false`.
  `CalculatePositionSizeFromSignal` line 301: `if(!m_isInitialized){ result.reason="not initialized"; return result; }`
  → `result.isValid` stays false → orchestrator `risk_strategy_valid=false`, `lot_size=0` → inline fallback at
  `:479` sizes the trade.
- **Impact:** Plugin Steps 2–7 (consecutive-loss scaling, vol-regime adjust, short-protection, health, engine-weight,
  plugin-level cap, margin pre-check) are **all bypassed**. Final risk % is still correct (fallback uses the already
  fully-stacked `signal.riskPercent`), and the orchestrator independently applies the 2.0% cap + counter-trend +
  exposure cap, so **no wrong-size trade results** — but a major "risk safety" surface is inert and the
  `OrderCalcMargin` free-margin pre-check (plugin :411–421) does NOT run on the live path.
- **Check:** Grep for any `Initialize()` call on the risk strategy; confirm log line "CQualityTierRiskStrategy
  initialized:" never appears in tester logs. Confirm fallback `fallback_sizing_used=true` in `LogRiskAudit`.
- **Disposition:** Confirmed-bug (latent). Either wire `g_riskStrategy.Initialize()` (re-animates Steps 2–7 —
  test impact first, esp. loss-scaling which the OPT-3 comment deliberately keeps dormant) OR delete the dead
  plugin and make the orchestrator fallback the documented sizing path.

### RISK-02 — SETUP_B tier (0.6%) is structurally unreachable; "4-tier" model is 3-tier
- **Severity:** MEDIUM · **Confidence:** Confirmed · **Category:** WT-5 / tier design
- **Location:** `UltimateTrader_Inputs.mqh:285–288` (`InpPointsBSetup=7` == `InpPointsASetup=7`);
  `CSetupEvaluator.mqh:330–334` (classifier: `if(points>=m_points_a) return SETUP_A;` before
  `if(points>=m_points_b) return SETUP_B;`).
- **Evidence:** Ladder evaluates A (≥7) → B+ (≥6) → B (≥7). B's threshold equals A's, and A is tested first, so
  no point total ever routes to B. CSV confirms: **0 SETUP_B trades** in 791 entries (A+ 505, A 224, B+ 62).
- **Impact:** The B-tier 0.6% risk band is dead config. The effective floor tier is B+ (0.75%). Squeezes the
  low-quality band exactly as the plan hypothesized — by design (comment: "7 = same as A, filters B/B+").
- **Disposition:** By-design (intentional filter), but report: the model markets four tiers and ships three.

### RISK-03 — 2.0% per-trade cap never binds on observed data; in-code comment overstates realized risk
- **Severity:** MEDIUM · **Confidence:** Likely (Model-1 directional) · **Category:** WT-5 / doc-vs-code
- **Location:** `CTradeOrchestrator.mqh:426–442` (comment: A+ "routinely HITS this 2.0% cap … TRUE realized A+
  risk is 2.0%"). CSV `all_trades_v15.csv` col RiskPct.
- **Evidence:** Across 791 entries: max RiskPct **1.21%**, avg **0.76%**, **zero** ≥1.5%, **zero** ≥1.99%.
  The session reducers (London 0.50×, NY 0.90×) + EC floor dominate; the worst-case 2.48% pre-cap corner
  (A+ MA × TRENDING × ATR-vel, Asia session) evidently doesn't co-occur often enough to surface.
- **Impact:** The cap is a tail backstop, not the realized sizing driver. The comment's claim that "the edge was
  earned at 2.0% capped sizing" is contradicted by the artifact — the edge was earned at ~0.5–1.2% realized.
  Materiality: low for safety (conservative is fine), but the doc-narrative anchors future tuning on a false premise.
- **Disposition:** Needs-test (re-confirm on a non-Model-1 run before acting). Flag the comment as inaccurate.

### RISK-04 — Portfolio exposure cap counts FROZEN entry-risk, over-counting safe trailed runners
- **Severity:** LOW · **Confidence:** Confirmed · **Category:** WT-5 / D9 exposure math
- **Location:** `CTradeOrchestrator.mqh:559–630` (cap) consuming `CPositionCoordinator::GetTotalOpenRiskPct`
  (:1022) → `CalculatePositionRiskDollars` (:314–337).
- **Evidence:** Risk dollars = `entry_risk_amount` (frozen) or `original_sl`-based distance × original_lots —
  **never the current trailed SL**. A runner trailed to breakeven/profit still counts its full initial 1R against
  the 5% ceiling.
- **Impact:** The 5% cap is **conservative** — it rejects/scales new adds sooner than true live risk warrants
  (it treats de-risked runners as still-at-full-risk). One-directional error (never under-counts), so it can only
  cost opportunity, never breach. Matches the OPT-2 input comment. Acceptable for a backstop.
- **Disposition:** By-design. Note: a live-SL-aware exposure sum would free headroom for additional long adds —
  do NOT change without confirming that's desired (more concurrent correlated long-gold = more correlated risk).

---

## DD-REGIME COHERENCE (0.70 EC floor + 3% daily + 5% portfolio)

- **EC v3 (CEquityCurveRiskController):** continuous, hysteresis-banded (3-trade confirm), rate-limited
  (step-down 0.08, step-up 0.05 per trade), warmup 50 trades, recovery-bias softening. Floor **0.70×** core.
  Composite global floor ≈ **0.58×** (core 0.70 × vol 0.90 × fwd 0.92), but fwd/strat layers are OFF, so the
  *live* floor is ~**0.70 × 0.90 = 0.63×**. This is the EA's **only adaptive drawdown control** and it is sound:
  graded, lagged appropriately, one-sided (only de-risks below 1.0 at the apply site). Sensible for gold's
  long-bias — it won't slam size to zero into a dip (the design intent called out in the OPT-3 comment).
- **Daily-loss halt (CRiskMonitor, 3%):** equity-anchored single-source-of-truth, resets only on new day,
  independent from the consecutive-error halt (a post-error success canNOT lift a loss halt). Clean. Correct.
- **Portfolio cap (5%):** fail-safe backstop, frozen-risk basis (RISK-04, conservative). Lot-scales then
  hard-rejects with no daily-counter increment — correct, no round-up breach.
- **Consecutive-loss scaler (CQualityTierRiskStrategy):** DORMANT (RISK-01 makes it dead anyway; even if wired,
  the OPT-3 comment documents it fires 0× due to close-time-counter vs sizing-time-read + reset-on-win). The EC
  controller is the de-facto loss-streak governor. Coherent — no redundant double-reduction because the dormant
  one doesn't fire.

**Coherence verdict:** The three live DD layers (EC graded reducer, 3% daily hard halt, 5% portfolio backstop)
are **non-overlapping and coherent** — graded continuous control + a daily circuit-breaker + an aggregate ceiling.
No double-reduction in the live path. The dead/dormant layers (plugin loss-scaling, short-protection on gold,
Wednesday, quality-boost, EC fwd/strat) are inert, not conflicting. Conservative bias is appropriate for a
single-asset, ~90%-long-correlated book.

## DOUBLE-REDUCTION AUDIT (the explicit guards)
- Vol-regime vs regime-scaler: guarded — `ApplyVolatilityAdjustment` returns early when
  `InpVolRegimeYieldsToRegimeRisk && InpEnableRegimeRisk` (CQualityTierRiskStrategy.mqh:112). (Also moot under RISK-01.)
- Shock vs session-quality: combined ONCE and floored at 0.25 (OnTick :1912–1913). No compounding across bars
  (fresh locals each bar). 
- Short-mult double-apply (historic 0.5×0.5=0.25): fixed — removed from CSignalOrchestrator (:770–772 comment),
  lives only in `ExecuteSignal` short-protection (OFF on gold).
- Vol-regime applied twice (historic): removed from `ExecuteSignal` (:542–546 comment).
**No live double-reduction found.**

---

## RESOLVED CONTRADICTIONS
- **Constructor risk defaults vs wired inputs:** WIRED inputs reach sizing. Base risk = `CSetupEvaluator`
  built with `InpRiskAPlusSetup..InpRiskBSetup` (1.5/1.0/0.75/0.6) at `UltimateTrader.mq5:561`. The plugin's
  commented constructor defaults (2.0/1.5/1.0/0.5) are stale comments only; `GetBaseRiskFromQuality` reads the
  same live `Inp*` and is dead anyway (RISK-01). **No stale value reaches sizing.**
- **Scorer tier thresholds vs evaluator:** `InpPointsBSetup=7` collides with A=7 → B unreachable (RISK-02).
