# EVAL-WT4 — Pullback + Rubber-Band (edge grading)

**Scope:** `CPullbackContinuationEngine` (PBC) + `CCrashBreakoutEntry` (Rubber-Band short).
**Method:** clean-room, source-only (PLAN + the two `.mqh` + `UltimateTrader_Inputs.mqh`). `all_trades_v15.csv` = directional cross-ref ONLY (Model-1 caveat — never the verdict).
**Constraints:** static/structural edge grading; no backtests.

Rubric reminder: Class ∈ {Real structural · Naive/indicator · Curve-fit/fragile · Look-ahead-dependent · No-edge-on-gold}. Scorecard each 0–2 /10: (1) structural fidelity, (2) directional justification for gold, (3) filter soundness (causal vs date-overfit), (4) look-ahead cleanliness (a 0 caps the claim), (5) robustness cross-ref (CSV directional, Model-1). Positive edge credited only if fidelity≥1 AND look-ahead=2 AND robustness≥1.

---

## CSV directional cross-reference (Model-1 v15 — directional ONLY)

Dataset span (ENTRY rows): 2019(81) 2020(110) 2021(100) 2022(112) 2023(106) 2024(139) 2025(143). Healthy counts every year; no 2026 yet.

**PBC: ZERO trades in v15.** No `PullbackContinuationEngine` in EngineName; no `Pullback`/`PBC`/`BREAKOUT_RETEST` pattern rows; engines present are PinBar/Engulfing/CrashBreakout/MACross/FailedBreakReversal/ExpansionEngine only. PBC was either disabled in the model that produced v15 or lost per-bar `qualityScore` ranking on every bar it fired (its 70–92 internal score collapses to a tier; see WT4-04). **No directional read available for PBC** → robustness axis is *uninformative*, not confirming.

**Rubber-Band Short (Death Cross): 104 closed trades.**
- Total +13.35R, avgR **+0.128/trade**, win **49%** (51W / 53L). Capped winners (max **+1.39R**, target = EMA21 mean), losses to −1.35R, **median Total_R = −0.04R** → per-trade edge is thin; it lives on win-rate × the ~1.3R cap, not on big winners. Top-3 winners = 30% of total R (not single-outlier-dependent).
- avgMAE_R 0.69 / avgMFE_R 0.86 → trades routinely give back most of the favorable excursion; the EMA21 target is being hit close to peak (consistent with a mean-reversion fade).
- All A+/A tier (qualityScore hardcoded 80 → SETUP_A_PLUS), so `InpRubberBandAPlusOnly=true` does not thin it.
- **Year concentration (decisive):** 2021 **+8.98R** (49 trades, 51% win), 2022 **+6.06R** (44 trades, 50% win), 2023 **−1.69R** (11 trades, 36% win). **2019, 2020, 2024, 2025 = ZERO trades.** The D1 death-cross gate (EMA50<EMA200) never engaged in gold's bull years, so the strategy was *dormant*, not losing — but the entire positive contribution is one ~18-month bear episode (2021H2→2022), and the tail (2023) was already negative.

---

## Strategy 1 — CPullbackContinuationEngine (PBC)

### Structural read (from code)
4-step trend-pullback-continuation, long & short, H1, closed-bar `[1]` indexed. ADX≥18 (`m_min_adx`, wired `InpPBCMinADX=18`).
- **Step A `IsTrendValid`** (370–390): H4 trend must match direction; ADX≥18; optional macro veto (long blocked if macro≤−3, short if macro≥+3). Causal, direction-aligned.
- **Step B `DetectPullback`** (395–490): finds swing extreme over `[1..20]`, measures retrace; gates depth 0.6–1.8×ATR and duration 2–10 bars. Real pullback geometry.
- **Step C `IsPullbackExhausted`** (495–544): **2-of-4** score — (1) late body < 0.8× early body, (2) lows stop extending (within 0.2 ATR), (3) bar[1] closes beyond prior bar's high/low, (4) close beyond a 30% retrace anchor. *Condition 1 auto-passes (`else score++`) when pullback <4 bars or rearm* → on the common short/2–3-bar pullback the gate is effectively **2-of-3**, and conditions 3 & 4 overlap heavily with the Step-D reclaim (a bar that closes above prior high and above the 30% anchor is most of what the reclaim re-tests). So the "exhaustion" filter is **weaker and less independent than its 2-of-4 label implies** — partly redundant with Step D, partly subjective. Not look-ahead, just soft.
- **Step D `IsContinuationTriggerValid`** (549–579): reclaim = bar[1] body ≥ `m_signal_body_atr`×ATR (wired **0.20**, not the ctor 0.35 — WT4-03) AND close beyond max(high[2],high[3]) for long / min(low[2],low[3]) for short, AND correct candle color. This is the real, causal trigger.
- **Entry/SL/TP** (1002–1024): entry = live ASK/BID; SL = pullback extreme ± max(0.20×ATR, `m_min_sl_points`×point); TP1 = entry ± risk×1.3 (fixed 1.3R). Structural SL anchor. Long uses confirmation (`RequiresConfirmation()=true`); the short path is symmetric.
- **Quality** (584–616): 78/80 base + modifiers, clamped **70–92** — a high floor that does not map cleanly to the 0–10 setup enum (WT4-04).
- **Multi-cycle / rearm path** (TryRearmEntry 829–952): latent — `InpPBCEnableMultiCycle=false`. A v18 fix re-derives the rearm SL from fresh closed bars instead of the live-bid-seeded `pullbackLow` (comment 881–888). Correct, but dead by default; grade the live first-cycle path.

### Look-ahead cleanliness
**Clean.** ATR uses `atr_buf[1]` (closed bar; the 6.9 fix comment at 746 confirms `[0]` forming-bar was the prior bug, now corrected). All swing/pullback/exhaustion/reclaim logic reads `[1..]` closed bars. Only entry *price* uses live ASK/BID, which is correct (you fill at market on signal). H4/D1 trend & ADX come from `m_context` (assumed closed-bar per Phase-0 map; not re-audited here). No forming-bar value feeds a gate. **Look-ahead = 2.**

### Edge class & scorecard
- **Class: Naive/indicator-with-structure (trend-pullback-continuation), borderline curve-fit on parameters.** It is a legitimately-shaped continuation entry (real swing/pullback/reclaim geometry), not a pure indicator cross, but the depth band (0.6–1.8×ATR), duration band (2–10), body 0.20, ADX 18, cooldown 5, and the 2-of-4→effectively-2-of-3 exhaustion gate are a stack of tunables with no causal anchor to gold specifically — and `InpPBCSignalBodyATR=0.20` carries an A/B-tuning comment (+$613). That is parameter search, not a structural prior.
- (1) Structural fidelity **1/2** — matches "pullback continuation" in shape; exhaustion gate is soft/redundant and partly auto-passes.
- (2) Directional justification for gold **1/2** — long-side rides gold's structural uptrend (sound); short-side is allowed but fights it and has no demonstrated support (CSV shows zero PBC shorts; textbook on this repo, gold-H1 shorts broadly fail).
- (3) Filter soundness **0/2** — causal in spirit but the bands + body 0.20 are date-tuned; the "-0.5R/38 trades on prior core" input comment is an admission it was net-negative and is on re-test.
- (4) Look-ahead cleanliness **2/2** — closed-bar clean (ATR fix verified in source).
- (5) Robustness cross-ref **0/2** — *uninformative*: zero PBC trades in v15, so no directional confirmation exists (cannot credit; per rubric, robustness≥1 is required for positive edge).
- **Score: 4/10.** Positive-edge gate **FAILS** (robustness < 1). **Verdict: not a credited edge on the static evidence — a plausibly-shaped but over-parameterized continuation entry whose own input comment flags prior net-negative results and which produced no trades to corroborate it.** Keep only as an explicitly A/B-gated re-test against the v18/v19 baseline; kill if PF<1.0 or avgR<0 over 2019–2026.

---

## Strategy 2 — CCrashBreakoutEntry (Rubber-Band short, short-only)

### Structural read (from code)
Two-stage, **short-only**, fade-to-mean:
- **Gate (Step 1, 175–196):** Death Cross on **D1** — EMA50 < EMA200, both from closed bar `[1]` (6.9 fix at 179–184; `d1_close=iClose(...,D1,1)` closed). This is the regime gate that makes the strategy dormant outside bear regimes. `death_cross_exists=(ema50<ema200)`; if also `d1_close<ema50`, `m_bear_regime_active=true` (the latter flag is informational — it is NOT required to arm the short; the short arms on the cross alone).
- **Trigger (Step 2, 198–272):** H1 EMA21, ATR, ADX all closed-bar `[1]` (6.9 fix 212–218). `extension_threshold = EMA21 + ATR×2.0`. If **live BID** > threshold AND H1 ADX ≥ 25 → SELL. SL = entry + ATR×1.5; **TP = EMA21 (the mean)**; reject if rr<1.0 (degenerate guardrail, comment 246–251). qualityScore hardcoded **80**.
- This is a textbook **rubber-band mean-reversion fade**: in a confirmed D1 downtrend, fade an H1 rally that has stretched ≥2 ATR above the H1 mean, target the snap-back to EMA21. Concept and code agree.

### Look-ahead cleanliness
**Clean, by design.** All three H1 indicators and both D1 EMAs read `[1]` closed bars (the 6.9 fixes are present and correct). The **only** live read is `current_price = SYMBOL_BID` at 225, used for the extension trigger — this is an *intentional front-run* of the reversal (you must compare live price to a closed-bar threshold to fade it), documented at 224 and 212–214. That is the correct way to arm a fade; it is not repaint of a decision input. **Look-ahead = 2.**

### Directional / regime justification (the core question)
This is the EA's **only real short**, on a **structurally-bullish** asset. The death-cross D1 gate is exactly the right design response: instead of shorting gold blindly (which the repo shows fails — bearish patterns net-negative on gold H1), it **only arms when gold itself has flipped to a confirmed D1 downtrend** (EMA50<EMA200), and even then only fades *overextended counter-rallies* back toward the mean rather than selling breakdowns. That is a causal, regime-appropriate short: it is mechanically incapable of fighting a bull trend because the gate suppresses it there.

The CSV bears this out **directionally**: zero trades in 2019/2020/2024/2025 (no D1 death cross in bull years — correctly dormant, not bleeding), +8.98R in 2021 and +6.06R in 2022 (the real 2021H2→2022 bear/range episode), and −1.69R in the 2023 tail as the regime decayed. So it is a **real mean-reversion edge that is genuine *within* its regime, but rare and episode-concentrated**: ~93 of 104 lifetime trades and 100% of the positive R come from a single ~18-month window. It is not "noise" (the gate is causal, look-ahead clean, win 49–51% with a positive payoff in-regime), but it is **not a persistent edge** — it is a conditional one that sleeps for years at a time.

### Edge class & scorecard
- **Class: Real structural edge — regime-gated mean-reversion fade — but rare/episodic, not persistent.**
- (1) Structural fidelity **2/2** — code is a faithful death-cross-gated rubber-band fade; concept↔code match exactly.
- (2) Directional justification for gold **2/2** — the single best-justified short in the EA: it shorts gold *only* when gold has confirmed a D1 downtrend, and fades overextension rather than selling weakness. Causally sound on a bull-biased asset.
- (3) Filter soundness **2/2** — gate (D1 cross), trigger (≥2ATR over mean), ADX≥25, rr≥1.0 floor are all causal, not date-fit. ATR-relative thresholds make it self-scaling across vol regimes (portable, not pinned to a price level).
- (4) Look-ahead cleanliness **2/2** — closed-bar indicators; live BID is an intentional, legitimate fade-trigger front-run.
- (5) Robustness cross-ref **1/2** — directionally positive (+13.35R, 49% win) but **episode-concentrated to 2021–2022, decaying by 2023, dormant otherwise**; Model-1 caveat; cannot claim persistence. Credit 1, not 2.
- **Score: 9/10.** Positive-edge gate **PASSES** (fidelity 2, look-ahead 2, robustness 1).

### SHORT-SIDE VIABILITY VERDICT (the EA's only real short)
**Viable as a conditional, regime-gated edge — NOT as an always-on short.** It is a genuine mean-reversion edge, correctly architected so it cannot fight gold's structural uptrend (the D1 death-cross gate is the right answer to the "structurally-bullish asset" problem). Its directional evidence is positive but **entirely contingent on a sustained D1 bear/death-cross regime, which appeared once in 2021–2022 and not at all in 2019/2020/2024/2025.** Expect it to contribute **nothing for years** and then matter a lot in the next sustained gold downtrend. Treat it as **regime insurance / a dormant short hedge**, not a workhorse: it is the right thing to keep on (it pays in the only conditions a gold short should ever be taken, and stays out otherwise), but the EA effectively has **no functioning short in trending-bull years** — a portfolio reality WT-8 should weight (the book is one long-gold bet whenever gold is rising, with the short engine asleep).

---

## Defects (plan schema)

**WT4-01 · CrashBreakout short is dormant outside D1 death-cross regimes (one episode in 6yr) · MEDIUM · Confirmed · Trading-edge/portfolio · `Include/EntryPlugins/CCrashBreakoutEntry.mqh:189` (gate) + CSV year slice**
Evidence: gate `death_cross_exists=(ema50<ema200)` on D1; CSV shows 0 trades 2019/2020/2024/2025, all 104 in 2021–2023, all positive R in 2021–2022.
Impact: the EA's only real short produces no protection in trending-bull years; the realized book is effectively long-only most of the time. Not a code bug — a design/portfolio limitation to surface in the report.
Check: WT-8 portfolio reconciliation; confirm no other live short carries directional edge.
Disposition: By-design (intended regime gate) — report as a coverage limitation, not a bug.

**WT4-02 · PBC produced zero trades in the v15 model → robustness unverifiable · MEDIUM · Confirmed · Methodology/edge · `Include/EntryPlugins/CPullbackContinuationEngine.mqh` (whole) + CSV EngineName slice**
Evidence: no PullbackContinuationEngine / Pullback / BREAKOUT_RETEST rows in `all_trades_v15.csv`; engine is `InpEnablePullbackCont=true` in current inputs.
Impact: PBC's edge cannot be directionally corroborated; its own input comment says "-0.5R/38 trades on prior core." Any "PBC works" claim rests on structure alone. Likely cause: per-bar `qualityScore` ranking (70–92) loses to PinBar/Engulfing on every shared bar, or PBC was off in the v15 model.
Check: reconcile with U7 (per-bar best-score ranking) + WT-8; an isolated PBC-only run (out of static scope) is the only way to credit it.
Disposition: Needs-test.

**WT4-03 · PBC reclaim body threshold: ctor default 0.35 vs wired input 0.20 (tuning divergence) · LOW · Confirmed · Numeric/config · `CPullbackContinuationEngine.mqh:146,224,558` + `UltimateTrader_Inputs.mqh:374`**
Evidence: ctor `signal_body_atr=0.35`; `InpPBCSignalBodyATR=0.20` with comment "A/B tested: 0.20 beats 0.35 (+$613...)". Wired input reaches the gate (the EA passes it), so the live threshold is 0.20.
Impact: confirms the wired value governs (not the stale ctor default) — reconciliation point only; and flags that the looser 0.20 body is a curve-fit pick (lower bar = more, weaker reclaims). No correctness bug.
Check: confirm EA constructor call passes `InpPBCSignalBodyATR` positionally; treat 0.20 as the live value in any edge claim.
Disposition: By-design (tuning) — note in data-contradiction resolution.

**WT4-04 · PBC quality score (70–92) does not map to the 0–10 setup-tier enum · LOW · Suspected · Architecture/scoring · `CPullbackContinuationEngine.mqh:584-616`**
Evidence: `CalculateQualityScore` returns 70–92; the EntrySignal/ranking layer elsewhere uses an 8–10/6–7/4–5/3 band (Phase-0 enum). A 70–92 value handed into a 0–10 comparator either always saturates A+ or is rescaled somewhere not in this file.
Impact: if not rescaled, PBC always ranks max and would *win* per-bar ranking (contradicting WT4-02's "loses ranking" hypothesis) — the two findings bound the truth; one must be wrong. Determines whether PBC ever trades.
Check: U7/U3 — find where qualityScore is normalized to the tier enum; reconcile against WT4-02.
Disposition: Needs-test (cross-unit).

**WT4-05 · PBC exhaustion gate is 2-of-4 in name, ~2-of-3 in practice, and partly redundant with the reclaim · LOW · Likely · Edge/filter-soundness · `CPullbackContinuationEngine.mqh:495-544`**
Evidence: condition 1 auto-passes (`else score++`) when barsCount<4 or rearm; conditions 3 (`close[1]>high[2]`) and 4 (close beyond 30% anchor) overlap the Step-D reclaim test.
Impact: the "exhaustion" filter is weaker and less independent than advertised → inflates apparent confluence; over-filtered/subjective per the KEY QUESTION. Edge-materiality low (it loosens, not biases).
Check: WT-7 filter-stack reconciliation (which gates actually bind).
Disposition: By-design but over-stated — report as soft-filter.
