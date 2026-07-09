# Professional-Trader Design Audit — Synthesis (Phase 2)

**Method:** source-only, static, no result metrics. 16 audit units (10 + 6) across two tracks (stok trading-judgment, mt5-developer engineering), against the trader's beta-stage framework. Two adversarial cross-checks running (`XCHECK-IMPL`, `XCHECK-EDGE`).
**Cells marked `[XC]` are pending cross-check confirmation.**

---

## A. Headline verdict

**Professional-alignment score ≈ 60 / 100** (raw 75/125 → 60.0; weighted-bucket method → ~60 — the two methods agree). **Band: upper "Conceptually incomplete / promising-but-incomplete."** Both adversarial cross-checks returned **zero overturns** except the reward-room contradiction (resolved against WT-3: the obstacle veto is OFF by default → §10 lowered 3→2).

But the number is *not* the verdict — the framework's doctrine is that **one critical red flag caps professional standing**, and the EA trips at least one: **on the production config it has no live news protection and fails-open when the calendar is unavailable** (8 units independently hit the same `InpEnableMultiStrategy`-gated dead path). So the honest verdict is:

> **Promising beta with professional-grade RISK and TRADE-MECHANICS engineering, but NOT yet professional-grade as a trading PROCESS — it must fix a small set of high-leverage gaps before live/serious testing.**

**One-sentence strengths/gaps (framework Part N):**
- **Strongest area:** risk & safety design — risk-from-stop sizing, layered equity-based hard limits, and a *verifiably clean* anti-martingale/anti-grid posture (§20 = 5/5), plus structure-anchored stops and pro-grade restart/order-error handling.
- **Weakest area:** "knowing when not to trade" — the news gate is dormant, there's no chop/extended-candle/revenge-flip stand-aside, and entries are market-on-close with no location discipline.
- **Main professional-trader gap:** it trades *into* the #1 gold risk (high-impact news) and chases price, while presenting ~12 setups that are largely **one correlated long-gold bet**, and ships its most sophisticated decision layer switched **off**.

---

## B. 25-section scorecard (0–5; weakest-critical-area caps)

| # | Section | Score | Unit | One-line |
|---|---|:--:|---|---|
| 1 | Strategy thesis (§6) | **3** | WT-1 | Code-enforced long-bias meta-thesis + real-edge setups, but top-weighted setups are bare patterns; no single unifying concept. |
| 2 | XAUUSD suitability (§7) | **2** | WT-1 | Genuinely gold-specific sizing/sessions, capped by the dormant news filter + non-uniform min-SL. |
| 3 | Professional decision stack (15-wt) | **3** | WT-2 | Context-before-entry is real, but no first-class bias STATE and the pro stack is dormant. |
| 4 | HTF bias (§8) | **3** | WT-2 | Multi-TF bias genuinely gates, but MA/price-relative not structural; no explicit state object. |
| 5 | Regime classification (§9) | **3** | WT-2 | Real hysteresis-guarded regime that gates + scales risk; alphabet missing Compression/News/Reversal live. |
| 6 | Liquidity map (§10) | **2** | WT-3 / XC | Obstacle map is built but the reward-room veto is **OFF by default** (`InpEnableRewardRoom=false`, Inputs:122) and liquidity-as-target is dead code → liquidity is neither target nor active permission-veto live; only sweep-grading uses it. |
| 7 | Session intelligence (§11) | **2** | WT-3 | Real GMT clock + frozen Asian range, capped by NO rollover/dead-liquidity block + DST-blind killzones. |
| 8 | News/macro risk (§12) | **1** | WT-4 | Well-built calendar machinery is dead on prod + fails-open in tester — trades through CPI/FOMC/NFP. |
| 9 | Setup definition (§13) | **3** | WT-5 | Named/falsifiable (S6 pro-grade), but core setups are candle-shape + brittle free-text comment key. |
| 10 | Entry quality (§14) | **2** | WT-5 | Market-on-close, no limit/pullback/retest/OTE; no single-candle extension cap → chases by design. |
| 11 | Confirmation quality (§15) | **2** | WT-5 | Lagging "next bar same direction," not thesis-tied; arrives after an already-market entry. |
| 12 | Stop/invalidation (§16) | **4** | WT-6 | Structure-anchored (sweep-extreme SL), never widened post-entry (XC: never-widen re-verified); gaps are flat (non-ATR) buffers. |
| 13 | Target/exit (§17) | **4** | WT-6 | Min-RR enforced pre-entry + reward-room gate + closed-bar H4-swing TPs; structure TP averaged not capped. |
| 14 | Trade management (§18) | **4** | WT-6 | Setup-specific (profit-gated BE, allowlisted runners, regime-aware exit; XC HOLD); per-regime profiles config-gated. |
| 15 | Risk model (§19) | **4** | DT-1 | Risk-from-stop sizing + layered equity-based hard limits; gaps: no weekly-loss / max-losses lockout. |
| 16 | Anti-martingale/grid (§20) | **5** | DT-1 / XC | Verifiably clean — adversarial refute failed; no averaging-down, no post-loss multiplier, no stop-widening, no grid; codebase is exit-biased. |
| 17 | Prop/account rule (§21) | **3** *(sep)* | DT-1 | Equity/floating daily DD done right; lacks total/trailing-DD + pre-breach floating buffer. |
| 18 | Execution realism (§22) | **3** | DT-2 | Spread gate + capped retcode-first retries; max-slippage is DEAD code; no failure cooldown. |
| 19 | Broker/symbol spec (§23) | **3** | DT-2 | Correct tick-value sizing; NO init-time spec-validation gate; unknown symbol → XAUUSD default. |
| 20 | Explainability (§24) | **3** | DT-5 | Rich candidate + post-trade journaling; no stop/target-reason fields; safety NO_TRADE skips Print-only. |
| 21 | No-trade decision (§25) | **4** | WT-7 | Named, logged reject reasons + one-best-per-bar; capped by the dormant news stand-aside. |
| 22 | State machine (§28) | **4** | DT-3 | Risk gate before signal gen; signal/execution separated; god-methods + no explicit global state. |
| 23 | Parameter governance (§29) | **2** | DT-3 | ~356–403 inputs, no config version, no init range-validation, optimization stamps inlined in live params. |
| 24 | Error handling/fail-safe (§30) | **3** | DT-4 | 8/14 cases fail-closed; 3 fail-open (no TERMINAL_CONNECTED / ACCOUNT_TRADE_ALLOWED / init spec). |
| 25 | Unit-test readiness (§31) | **3** | DT-4 | Real Tests/ harness, but production classes not isolatable → assert against drift-prone replicas. |

**Added dimensions (reported alongside, not in the 100):** setup-stack correlation **2/5** (one correlated long-gold bet, only a position-count cap) · multi-TF coherence **4/5** (explicit conflict-resolution) · dormant-module/complexity **2/5** (~20 dead files; advertised plugin architecture is not the live mechanism).

---

## C. 20-scenario decision-trace (Pass/Fail vs professional expectation)

**Trading (WT-8):** 1 Pass(4) · 2 Pass-weak(3) · 3 Pass(3) · 4 Pass(4) · **5 FAIL(2)** `[XC]` · 8 Pass(4) · **9 FAIL(2)** · **10 FAIL(1)** · 11 Pass(4) · 12 Pass(3) · 13 Pass(3) · **14 FAIL(1)** · **20 FAIL(2)**.
**Engineering (DT-6):** **6 FAIL(1)** · 7 Pass(4) · **15 FAIL(2)** · 16 Pass(5) · 17 Pass(5) · 18 Pass(4) · 19 Pass(5).

**Scenario agreement rate ≈ 13/20 Pass (65%)** — "mixed; needs refinement" band. The 7 fails cluster on **stand-aside discipline** (news ×2, chop, extended-candle chase, revenge-flip, HTF-conflict, buy-into-PDH) — the EA's defining weakness is *restraint*, not mechanics.

---

## D. 5 readiness gates

| Gate | Status | Why |
|---|---|---|
| 1 Concept | **Pass (caveat)** | Thesis present, setups named, invalidation + targets exist, no-trade conditions exist — but no single central concept. |
| 2 Professional process | **Partial** | HTF bias/regime/session/liquidity present, logs no-trade — but does NOT block bad context (news, chop). |
| 3 Risk | **PASS** | Risk-from-stop, equity daily-loss halt, exposure cap, no martingale, emergency stop, margin check. The strong gate. |
| 4 Execution | **Partial FAIL** | Spread/retry/restart/logging present, but max-slippage dead, no init broker-spec validation gate. |
| 5 Auditability | **Partial FAIL** | Good candidate logging, but no stop/target-reason fields and safety NO_TRADE skips are Print-only. |

---

## E. Red-flag checklist (framework Part L)

**Critical red flags present:**
- ☑ **No news protection on the live config** (dormant behind `InpEnableMultiStrategy=false`).
- ☑ **Fails open when calendar unavailable** (the conservative static fallback is gated off in production).
- ☑ **Can trade during unclear/choppy conditions** (CHOPPY never classifies; no NY-lunch dead-zone) — scenario 9.
- ◻ **Buy into obvious liquidity without a plan** — scenario 5; `[XC]` pending reward-room-gate resolution.

**Critical red flags ABSENT (confirmed strengths):** no hard-stop-missing, **no martingale/grid/lot-multiplier**, no stop-widening, daily-loss limit present, spread filter present, fixed-lot sizing absent (risk-based), broker symbol partially validated, HTF context present, regime classification present, explanation log present.

**Serious design concerns present:** too many parameters (~356–403); same logic across sessions (largely); no time-stop beyond 72h MaxAge universally; no cooldown after a loss / execution failure; setup-stack is one correlated bet; advertised plugin architecture is not the live mechanism.

---

## F. Trading-concept fidelity matrix (WT-9 trading ↔ DT-7 implementation)

| Concept | Trading (WT-9) | Implementation (DT-7) | Combined |
|---|---|---|---|
| FVG / imbalance | Genuine (but FVG-Mit mode fires w/o FVG) | Faithful (3-candle gap) | **Genuine** (mode caveat) |
| Displacement | Genuine | Faithful (sweep+reclaim then ≥1.5·ATR body) | **Genuine** |
| BOS | Genuine | Faithful (fractal pivot + closed-bar break) | **Genuine** |
| Sweep + reclaim (S6/S3 entries) | Genuine | Faithful (wick-through then close-back) | **Genuine** |
| Premium/discount (CMarketContext) | Genuine (IPDA) | Faithful (D1 20-bar dealing range) | **Genuine — in context layer** |
| Premium/discount (live entry engines) | Naive-proxy | Mislabeled (`GetLocationPenalty` forming-D1 range %) | **Naive-proxy — what engines consume** |
| "Swing" pivot (engines) | n/a | Mislabeled (`GetSwingHigh/Low` = 20-bar Donchian) | **Proxy — "sweep of swing" = sweep of 20-bar extreme** |
| Order block | Partial | Approximate (not tied to BOS/displacement leg) | **Partial** |
| CHoCH | Partial | Approximate (not strictly time-ordered) | **Partial** |
| Liquidity sweep (SMC module) | Partial | Approximate (naive penetration, no reclaim) | **Partial** |
| Macro/intermarket | Partial | Faithful w/ DXY+VIX, **proxy fallback to gold-MA** | **Partial (degrades silently)** |
| Volatility/compression squeeze | Genuine | Faithful (BB-inside-Keltner) | **Genuine** |
| Breaker block | Claimed | Not-implemented (enum only) | **Absent** |
| Inducement | Claimed | Not-implemented | **Absent (SMC's signature idea)** |
| OTE | Claimed | Not-implemented | **Absent** |
| Power-of-3 / AMD / Judas | Claimed | Not-implemented | **Absent** |
| CRT (candle-range theory) | Claimed | Not-implemented (range-box substituted) | **Absent** |
| Orderflow (CVD/delta/footprint/DOM) | Claimed-but-absent | Not-implemented (tick volume only) | **Unsupported-by-data (correctly absent)** |
| Volume profile (POC/VA/HVN-LVN) | Claimed-but-absent | Not-implemented (zero refs) | **Unsupported-by-data (correctly absent)** |

**Read:** the EA's *real* concept edge is a faithful displacement / sweep-reclaim / squeeze / BOS process with a genuine IPDA premium-discount model **in the context layer** — but the **live entry engines consume proxy versions** (20-bar Donchian "swing," forming-D1 "premium/discount"), and roughly half the advertised ICT/SMC vocabulary (inducement, OTE, breaker, P3/AMD, CRT) and all orderflow/volume-profile are **not implemented**. The orderflow/volume absence is *correct* (uncomputable on OTC-spot tick volume); the concern is naming/feature-inflation, not fabricated math.

---

## G. Prioritized pre-test fix roadmap

1. **Make news protection live & fail-closed** — decouple `IsDataDay()` from `InpEnableMultiStrategy`; add a router-independent `if(InpEnableNewsFlat && IsDataDay()) skip+log NO_TRADE_NEWS_WINDOW` to the always-on OnTick entry gate; ensure the static blackout engages when the calendar is unavailable. *(Fixes §12, scenarios 6 & 15, two critical red flags — highest leverage.)*
2. **Add stand-aside discipline** — a single-candle extension cap on the core candle setups (no chasing), a chop/NY-lunch dead-zone or make CHOPPY reachable, and a post-loss / flip-flop cooldown. *(Fixes scenarios 9, 10, 14.)*
3. **Add entry-location quality** — a limit/retrace entry layer + confirm the reward-room/PDH obstacle gate is ON by default. *(Fixes §14, scenario 5.)*
4. **Budget the correlated long book** — per-direction / per-family risk budget, not just `InpMaxPositions`. *(Fixes setup-correlation.)*
5. **Close the execution/audit gaps** — wire `CheckSlippage` so `InpMaxSlippagePoints` is live; add an `OnInit` broker-spec validation gate (`INIT_FAILED` on bad specs); add a post-failure cooldown; add stop-reason/target-reason fields + structured NO_TRADE journal rows.
6. **Govern the parameters** — add a config version, init-time range validation on dangerous inputs (cap risk inputs), and prune the ~20 dead source files / dormant engine stack or document them as inert.
7. **Stop over-claiming concepts** — either build or remove the enum-only/absent concepts (breaker, inducement, OTE, CRT) and rename the proxy "swing"/"premium-discount" the live engines consume; have the engines consume the faithful `CMarketContext` versions.

*(Severities/numbers finalize when XCHECK-IMPL & XCHECK-EDGE report — chiefly the reward-room-gate default, which sets scenario 5 and part of §10/§14.)*
