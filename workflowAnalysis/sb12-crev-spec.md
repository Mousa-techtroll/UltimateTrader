# SB-1.2 — CREV (Correction-state Rally-fadE, short) — implementable, look-ahead-free spec

**Date:** 2026-07-11 · **Author:** stok (trading-analyst design task; READ-ONLY — no source edits, no tester runs)
**Program:** `workflowAnalysis/short-book-tracker.md` §SB-1.2 · **Registration:** `AB_TEST_LOG.md` "SB-1.2 CREV PRE-REGISTRATION (2026-07-11)"
**Baseline of record:** $23,856.89 / 952 positions (tag `baseline-23856-2026-07-11`)
**Routing:** SHORT-only SLEEVE strategy → `CTradeOrchestrator::ExecuteSleeveSignal(signal, "CREV")` (SB-0.1 gateway). CREV supplies the entry signal (SL + TP prices), the family tag `"CREV"`, and a per-state `riskPercent` request. The sleeve owns max-1-position, slot reservation, risk/DD/daily halts, baseline non-displacement. **CREV never touches the baseline entry path.**
**State source:** `CMarketContext::GetBearState()` — for the CREV backtest this is `InpBearStateSource=LEDGER` = the frozen validated `sb11_states.csv` (100.0000% verified, SB-1.1). CREV **reads** the state; it never recomputes it.

> **Design register discipline.** Everything below is fixed **a-priori**. Every numeric constant is stated once, justified by a round convention or an unconditional-distribution / measured anchor, and marked **FROZEN** — no post-results tuning. Where a doc already measured a number I cite it as the anchor (market-structure = `short-side-market-structure.md`; economics = `short-side-economics.md`; state = `sb11-state-model.md`). This spec does not re-propose any do-not-relitigate item; the pre-killed traps in §11 are avoided by construction.

---

## 0. What CREV is, in one paragraph

CREV is a **rally-FADE short** that fires **only inside a validated correction/bear state**, at the moment a counter-trend rally into the H1 mean (EMA21/EMA50) or into a broken-support level **fails** with a bearish-rejection close under a valid **lower high**, with measured **room to the next structural support** below and **no downward over-extension**. It banks fast (partial at the nearer of a recent H1 low or 1R), takes a second partial at the next H4 structural support, and trails a small runner on **confirmed lower highs** — never on a generic chandelier — with a hard **48h time-box**. It is *not* a breakdown-chaser, *not* a stretch-momentum short, and *not* a standalone candlestick pattern. It is the structural rally-fade the owner registered, gated by the SB-1.1 state ledger and dose-controlled by state.

---

## 1. State gate (item 1)

**Rule.** At the **new-H1-bar** evaluation (see §12), read `state = GetBearState()`. CREV may **arm** only when:

```
state ∈ { BEAR_STATE_ACTIVE_CORRECTION, BEAR_STATE_BEAR_TRANSITION, BEAR_STATE_BEAR_TREND }
```

All other labels **block** CREV: `BULL_TREND`, `BULL_PULLBACK`, `RANGE`, `VOLATILE_TRANSITION`, and — **note** — `BEAR_RALLY` (see the flagged judgment call, §13). This is the exact registered set (AB_TEST_LOG SB-1.2 line: "State gate: ACTIVE_CORRECTION / BEAR_TRANSITION / BEAR_TREND only").

- `VOLATILE_TRANSITION` is a **measured short-veto** (−0.057 avg R, −$1,955; SB-1.1 §6.2) and is where the E7-class air pockets live — excluded by construction.
- `BULL_PULLBACK` is the **knife-catch** state (−0.196; SB-1.1 §4) — excluded.

**State bar-freshness (no look-ahead).** The ledger stamps the state of the last **closed H4** onto each H1 bar, keyed on `iTime(H1,1)` (SB-1.1 CLOSED note; AB_TEST_LOG "no-look-ahead keyed on iTime(H1,1)"). CREV reads the state as of the last closed H1 bar. The forming bar's state is never read.

**State exit while in a position → HOLD to CREV's own exits. Do NOT force-manage.** (item 1 ruling)
Once a CREV position is open, a subsequent state change (including a flip to `BEAR_RALLY`, `VOLATILE_TRANSITION`, or a bull label) does **not** trigger any close or re-management. The position is bounded by its own SL, TP1, TP2, lower-high trail, and the 48h max-hold (§8). **Justification:** the state is an *entry* gate; the position's thesis is the specific rejected impulse, whose risk is already bounded in price (structural SL) and in time (48h). A state-exit force-close would add a second, noisier exit trigger subject to the documented **BEAR_RALLY-overlay churn** (median overlay run 3 H4 bars = 12h; SB-1.1 §3.1) and to family-boundary flapping — exactly the behavior SB-1.1 tells us to *not* gate trade decisions on ("gate on family+severity, the overlay churns"). Bounded time + structural stop make force-management strictly worse here. **FROZEN.**

---

## 2. Rally leg (item 2)

The rally leg establishes "price has rallied toward the H1 mean or into a broken level" as a computable condition on **closed bars only**. All indices are H1 unless stated. `ATR = ATR14(H1)`, Wilder, closed value `[1]`. `EMA21 = EMA(21, close, H1)[1]`, `EMA50 = EMA(50, close, H1)[1]`.

**A rally is present at bar [1] iff BOTH:**

1. **Counter-trend rise (min size):** the close has risen at least `X_RALLY × ATR[1]` above the lowest low of the rally window:
   `close[1] − Low(low[1..N_RALLY]) ≥ X_RALLY × ATR[1]`, with `N_RALLY = 6`, `X_RALLY = 1.0`.
   (A ≥1-ATR bounce over the last quarter-day = a genuine counter-trend leg, not chop.)

2. **Reached a fade zone** — at least one of the two arms:
   - **EMA arm:** `high[1] ≥ EMA21 − K_ZONE × ATR[1]`  **OR**  `high[1] ≥ EMA50 − K_ZONE × ATR[1]`
     (the rally high tagged, or exceeded, the H1 EMA21 or EMA50 within a quarter-ATR), with `K_ZONE = 0.25`.
   - **Broken-support arm:** there exists a level `Lb` = a confirmed H1 or H4 pivot low (§4 pivot rule) that was **broken to the downside** — a later closed bar closed `< Lb − 0.25×ATR_that_TF` (SB-1.1 break rule, F16) — and the rally has retested it **from below**: `high[1] ≥ Lb − K_ZONE × ATR[1]` **and** `close[1] < Lb` (still under the broken level = level now acting as resistance).

**Anti-trap note (do not confuse with the killed breakdown-retest).** The broken-support arm is a *rally target*, not an *entry*. CREV never enters on the touch of `Lb`; it requires the momentum-turn trigger (§3) + lower high (§4) + room (§5). The killed pattern (market-structure §4.3.1, PF 0.57) was *entering on the retest touch* — CREV enters on the **failure** of that retest, with the trigger candle and structure carrying the burden. This is the "FAILED reclaim, not the touch" distinction the tracker flags for SB-2.2.

---

## 3. Momentum-turn / bearish-rejection trigger (item 3)

**Owner rule (binding):** bearish candle patterns are the **final trigger only, inside the validated structure** — never a standalone engulfing/pin. So the trigger fires **only** after §1 (state), §2 (rally), §4 (lower high), §5 (room), §6 (no over-extension) all pass. The trigger itself is evaluated on the **closed** bar `[1]`:

**Trigger bar [1] is a bearish rejection iff ALL:**

1. **Bearish close:** `close[1] < open[1]` **AND** `close[1] < close[2]` (down-close and down vs the prior close — the SB-1.1 "bearish close" convention).
2. **Upper-wick rejection:** `upper_wick[1] ≥ W_WICK × body[1]`, where
   `body[1] = |close[1] − open[1]|` (require `body[1] ≥ 1×_Point` to avoid div-by-zero, matching CPinBarEntry),
   `upper_wick[1] = high[1] − max(open[1], close[1])`, with `W_WICK = 1.0`.
3. **Rejected the zone:** the bar's high reached the fade zone (`high[1]` satisfied the §2 EMA-arm or broken-support-arm inequality) **and** the close came back below the zone anchor it tagged:
   - if the EMA21 arm fired: `close[1] < EMA21`;
   - else if the EMA50 arm fired: `close[1] < EMA50`;
   - else (broken-support arm): `close[1] < Lb`.

No RSI/stochastic is required (kept minimal and falsifiable). The candle IS the momentum turn, and the structure gates carry the confirmation burden per the owner rule.

---

## 4. Valid lower high (item 4)

**Pivot rule (FROZEN, reused from SB-1.1 §2.1 adapted to H1).** A **5-bar fractal**: bar `i` is a **pivot high** iff `high[i] ≥ high[i−1], high[i−2], high[i+1], high[i+2]` **and** `high[i] > high[i−1]` **and** `high[i] > high[i+1]` (strict vs the two immediate neighbours). Confirmed only when bars `i−2..i+2` are all **closed**. Reading at the new-bar tick (bars ≥1 closed), the newest **confirmable** pivot high is at index `i = 3` (uses bars 1..5). Mirror definition for **pivot low**. *(No zigzag/ATR-alternation filter is needed here — CREV uses raw fractals for the LH and support scans; the SB-1.1 zigzag filter lives inside the ledger and is not re-derived.)*

**Valid lower high condition.** Let `rallyHigh = High(high[1..N_RALLY])` (the rally's high). Let `priorSwingHigh` = the **most recent confirmed H1 pivot high** at index `3..L_LH`, `L_LH = 24`. The rally must be a lower high:

```
rallyHigh < priorSwingHigh
```

If no confirmed pivot high exists in `[3..24]`, CREV **does not arm** (structure undefined = stand down). This is the same object as SB-1.1's F14 "LH+LL" and the ICT/SMC "lower high" — **counted once**, not stacked as separate confluence.

---

## 5. Downside room to next structural support (item 5)

**Locate support below entry from closed bars.** `entry` = current BID at signal time (§12). Search **confirmed** pivot lows (§4 rule):
- **H1 support:** highest-priced confirmed H1 pivot low at index `3..24` that is `< entry`.
- **H4 support:** highest-priced confirmed H4 pivot low at index `3..30` that is `< entry` (30 H4 bars = the SB-1.1 F15 window).

Define `nextSupport` = the **nearest support below entry** = `max(H1support, H4support)` among those that exist and are `< entry`. (Nearest = highest price below entry = the first liquidity the fade must clear.)

**Room gate (net of costs), FROZEN `MINRR = 1.5`:**
```
spread_price = SymbolInfoInteger(SYMBOL_SPREAD) × _Point           // XAUUSD+: 1 point = 0.01
stopDist     = SL − entry                                          // SL from §7, a SHORT stop above entry
room         = entry − nextSupport
require:  (room − spread_price)  ≥  MINRR × (stopDist + spread_price)
```
If no `nextSupport` exists in either window → CREV **does not arm** (no measurable objective = stand down).

**Why 1.5, not 2.0.** The a-priori archetype sim used a 2R target (market-structure appendix), but the **realized** short economics show the harvest is fast and the winner distribution tops out well under a hard 2R at p90 once you strip the TP artifact (economics §2.3: median first +1R in 2–5h; §1.1 short avg R +0.123). 1.5 is the honest asymmetric floor that is *stricter* than the crash engine's own degenerate-config floor of 1.0 (`CCrashBreakoutEntry` line 311) and looser than an unrealistic 2.0. **FROZEN.**

**Anti-trap.** Room is measured to support **below**, which CREV **exits into** (TP2), not an entry we sell into. The 51/53 reclaim fact (market-structure §1.2) makes *selling a broken level from above* a trap; CREV's geometry is the opposite — fade a rally from above, harvest into support below, and bank there rather than expect a walk-away.

---

## 6. Over-extension veto (item 6)

**Rule (FROZEN `P_OVEREXT = 3.0`):** veto the setup when, at the trigger bar, price is still violently stretched **below** the H1 EMA50 despite the rally:
```
if  close[1] < EMA50 − P_OVEREXT × ATR[1]   →   VETO (do not arm)
```
**Justification.** A rally-fade needs the rally to have carried price back toward the mean. If even at the fade trigger the close sits ≥3 ATR under the EMA50, the tape is a **waterfall** (E8-class), where the next counter-move is the **1.9–5.9×ATRd squeeze** documented in market-structure §2.2 — fading here is "crash-day momentum chasing" (pre-killed trap §11.6) selling near a low into the squeeze envelope. 3× is the upper cluster of observed squeeze multiples (market-structure §1.1 "squeezes ≥2×ATRd" and §2.2's 1.9–5.9× range), used as the "too deep to fade the mean" ceiling. **FROZEN.**

---

## 7. Stop (item 7)

**Structural stop above the rally/pullback high + spread + ATR buffer (FROZEN `BUF_STOP = 0.5`):**
```
rallyHigh = High(high[1..N_RALLY])            // the swept rally high
SL        = rallyHigh + spread_price + BUF_STOP × ATR[1]
```
No fixed candle-size-only stop. The stop lives above the structure the rally failed at, plus one spread (a SHORT is stopped on the ASK) plus a half-ATR structural buffer. **FROZEN.**

**Honesty note (market-structure §2.2):** a structural stop survives *one* sweep, not the $105–$664 mega-squeeze class. CREV accepts that some fades are stopped by squeezes; the mitigants are the state gate (§1), the over-extension veto (§6), and the 48h time-box (§8) — not a wider stop (a 3×ATRd stop is uneconomic under fixed-fractional sizing; market-structure §2.2).

---

## 8. Targets / exits (item 8)

All partials are **price-level** targets (structural), managed for the CREV position. `R = stopDist = SL − entry`.

**TP1 — fast partial, 50% (`TP1_VOL = 50`).** Bank at the **nearer** of a recent H1 low or 1R:
```
recentH1Low = highest confirmed H1 pivot low at index 3..24 that is < entry   // = the H1support from §5 if it exists
TP1_price   = MAX( recentH1Low (if it exists),  entry − TP1_R × R )           // TP1_R = 1.0
```
(`MAX` = the higher price = the nearer target = bank fastest, per the fast-harvest doctrine, market-structure §2.3 / economics §2.3.) If `recentH1Low` doesn't exist, `TP1_price = entry − 1.0×R`.

**TP2 — structural partial, 30% (`TP2_VOL = 30`).** Bank at the **next H4 structural support below TP1**:
```
TP2_price = highest confirmed H4 pivot low at index 3..30 that is < TP1_price
fallback (none in window): TP2_price = entry − TP2_FALLBACK_R × R             // TP2_FALLBACK_R = 2.0
```

**Runner — 20% (`RUNNER_VOL = 20`), lower-high structure trail.** Ratchet the stop to the **most recent confirmed lower high + buffer** (FROZEN `TRAIL_BUF = 0.5`):
```
On each new confirmed H1 pivot high P (§4) that is LOWER than the previous confirmed pivot high:
    candidateSL = P + TRAIL_BUF × ATR[1] + spread_price
    SL = MIN(SL, candidateSL)          // SHORT stop only ever ratchets DOWN (tightens); never loosens
```
The runner has **no fixed TP** — it rides the descending lower-high structure until stopped or timed out.

**Max-hold time-box (FROZEN `MAXHOLD_H = 48`).** Force-close **all** remaining CREV lots when
`(iTime(H1,0) − open_time) ≥ MAXHOLD_H × 3600` (equivalently ≥48 closed H1 bars since entry).
**Justification:** the fade pays in the first 2–5h and the MFE envelope is largely realized by 24–72h (market-structure §2.3); winners' excursion peaks at 36h (economics §2.3); §2.1's overnight-bid finding says a gold short is a *session rental*, biased flat-or-banked, not a position. 48h = two sessions — a round compromise between "24h captures most MFE" and the sim's 72h horizon — that caps squeeze-exposure time. **FROZEN** (24/72 are the neighbours the owner may revisit; see §13).

**NO generic chandelier clamp (the §D guard — item 8, explicit).**
CREV positions must be **excluded from all `CChandelierTrailing` proposals for the life of the position.** On a rally-fade the price is near/above the mean at entry, so a chandelier proposing from lows far below turns into an at-market clamp seconds after entry (the exact §D pathology: median hold 0.1h, `CPositionCoordinator` §D comment, `tier3-design-doc.md §D`). The **only** trail on a CREV position is the lower-high structure trail above. Mechanically this is the **same pattern-scoped suppression §D already implements** (`CPositionCoordinator::ApplyTrailingPlugins`, the `trail_suppress_pattern` branch, lines ~3260–3274): CREV extends that scoping so the chandelier is suppressed **unconditionally** for CREV positions (not merely "until a bar closes below EMA21" — CREV replaces the chandelier outright with the LH trail, it does not gate-then-release it). The entry-stamped hard SL/TP prices are never widened by any trail.

---

## 9. Impulse dedup / cooldown (item 9)

**"Same bearish impulse" (no re-entry within it).** At each CREV entry, stamp `faded_high_time` and `faded_high_price = rallyHigh`. A new CREV candidate is **rejected as SAME_IMPULSE** unless **either**:
- (a) a **new confirmed H1 pivot high** has formed since `faded_high_time` that is **lower** than `faded_high_price` (a fresh, distinct lower high = a new fade-able rally leg); **or**
- (b) price has closed **above** `faded_high_price + BUF_STOP × ATR[1]` (the prior impulse is structurally invalidated to the upside — and the state gate will typically have flipped anyway).

**Hard min-spacing (FROZEN `CD_DEDUP = 6`).** Regardless of (a)/(b), no two CREV entries within `CD_DEDUP = 6` H1 bars (the ≥6-bar spacing used in the market-structure fade-hold anatomy and the CREV-seed sim, appendix).

**Post-loss cooldown (FROZEN `CD_LOSS = 24`).** After any CREV position closes with realized `R < 0`, block **all** new CREV entries for `CD_LOSS = 24` H1 bars (one day). **Justification:** the worst-20 short losses cluster as intraday squeeze deaths (economics §4, median hold 2.4h); a day's cooldown stops CREV re-fading the same squeeze that just stopped it. 24 H1 bars = the SB-1.1 1-day hysteresis unit (6 H4 bars). **FROZEN.**

The dedup state (`faded_high_time`, `faded_high_price`, last-CREV-entry bar time, last-CREV-loss bar time) is CREV-internal and must be recomputable from bar history / the sleeve ledger after a restart (no new persisted decision state required beyond what the sleeve already restores).

---

## 10. Per-state risk (item 10) — FROZEN dose

Dose ruling of record (owner, 2026-07-11): **SPEC AS WRITTEN** — reduced risk in `BEAR_TRANSITION`, full only in confirmed `BEAR_TREND`; the measured **+0.403R BEAR_TRANSITION** inversion (SB-1.1 §4) is **recorded, NOT acted on** pre-evidence. CREV requests, per state, a `riskPercent` inside the frozen 0.25–0.35% band:

| State | Severity (SB-1.1) | CREV `riskPercent` | FROZEN |
|---|---|---:|---|
| `ACTIVE_CORRECTION` | S=2 (unconfirmed, violent first leg) | **0.25%** | ✅ |
| `BEAR_TRANSITION` | S=3 (structure confirmed, D1 not yet) | **0.30%** | ✅ |
| `BEAR_TREND` | S=4 (**D1-confirmed**) | **0.35%** | ✅ |

**Justification.** Monotone in the SB-1.1 **severity ladder** (S=2→0.25, S=3→0.30, S=4→0.35), equal 0.05 steps spanning the frozen band, with **full (0.35%) reserved for the D1-confirmed state** exactly as the ruling requires ("full only in confirmed BEAR_TREND"), and `BEAR_TRANSITION` **reduced** (0.30 < 0.35) exactly as required. This deliberately does **not** act on the +0.403R measured inversion (which would put `BEAR_TRANSITION` highest) and treats `ACTIVE_CORRECTION`'s violence leg as the lowest dose (consistent with its realized −0.019R, SB-1.1 §6.1). *(This differs from the pre-registration's illustrative "AC 0.30 / BT 0.25" ordering, which inverts the severity ladder; see the raw judgment call in §13.)*

**Sleeve-cap interaction (implementation-binding).** The gateway clamps `sleeve_risk = min(signal.riskPercent, InpSleeveRiskPct)` (`CTradeOrchestrator` line ~1183). To let the 0.35% BEAR_TREND dose pass **unclamped**, the CREV FIT config **must set `InpSleeveRiskPct = 0.35`** (top of the owner band; family/total caps `InpSleeveMaxFamilyRiskPct` / `InpSleeveMaxTotalRiskPct` default 0.40 > 0.35, so max-1 CREV position at full dose is admitted). Downstream `ExecuteSignal` reducers (EC v3, counter-trend cut, exposure rescale) may only **reduce** further — the sleeve never increases risk. CREV logs the **requested** per-state dose; the realized risk is what the Stats CSV records, and the FIT archive measures per-state on the requested dose.

---

## 11. Constants table (all FROZEN — no post-results tuning)

| Name | Value | Where | A-priori justification / anchor |
|---|---:|---|---|
| `STATE_SET` | {ACTIVE_CORRECTION, BEAR_TRANSITION, BEAR_TREND} | §1 | Exact registered gate (AB_TEST_LOG SB-1.2). Excludes measured veto states VOLATILE/BULL_PULLBACK and the BEAR_RALLY overlay. |
| `N_RALLY` | 6 (H1 bars) | §2 | Quarter-day rally window; matches the 2–5h first-R harvest scale (market-structure §2.3) and the ≥6-bar spacing in the CREV-seed sim. |
| `X_RALLY` | 1.0 (×ATR14 H1) | §2 | One-ATR counter-trend rise = a real bounce, not chop. Round convention. |
| `K_ZONE` | 0.25 (×ATR14 H1) | §2,§3 | Quarter-ATR proximity band to EMA/level. Same quarter-ATR round convention as SB-1.1's decisive-break buffer (0.25×ATR_H4). |
| `W_WICK` | 1.0 (upper wick ÷ body) | §3 | Rejection tail ≥ body. Lower than a standalone pin (CPinBar 1.5) **on purpose** — the structure gates carry the burden (owner rule: candles only as the final trigger inside validated structure). |
| `PIVOT` | 5-bar fractal, confirm +2, usable index ≥3 | §4,§5,§8,§9 | SB-1.1 §2.1 swing rule (closed-bar, no look-ahead). |
| `L_LH` | 24 (H1 bars) | §4 | One day of H1 for "the prior relevant swing high." Round convention (24h). |
| `MINRR` | 1.5 | §5 | Honest asymmetric floor: stricter than crash's 1.0 degenerate floor, looser than an unrealistic 2.0 (realized short avg R +0.123; MFE artifact stripped — economics §2.3). |
| `SUP_H1_LOOKBACK` | 24 (H1 bars) | §5,§8 | One day; nearest H1 support/recent low. |
| `SUP_H4_LOOKBACK` | 30 (H4 bars) | §5,§8 | SB-1.1 F15 support-break window (30 H4 bars = 5 days). |
| `P_OVEREXT` | 3.0 (×ATR14 H1 below EMA50) | §6 | Upper cluster of observed squeeze multiples (1.9–5.9×ATRd, market-structure §2.2); "too deep to fade the mean." |
| `BUF_STOP` | 0.5 (×ATR14 H1) | §7,§9 | Half-ATR structural buffer above the swept rally high. Round convention. |
| `TP1_R` | 1.0 (R) | §8 | The "or 1R" arm of the fast partial; first-R harvest (market-structure §2.3). |
| `TP1_VOL` / `TP2_VOL` / `RUNNER_VOL` | 50 / 30 / 20 (%) | §8 | Front-loaded bank (most off by the structural support), small runner — the front-loaded short shape (tier3 §C / economics §6, direction-scoped). |
| `TP2_FALLBACK_R` | 2.0 (R) | §8 | Fallback objective when no H4 support below TP1. Round convention. |
| `TRAIL_BUF` | 0.5 (×ATR14 H1) | §8 | Buffer above each confirmed lower high for the runner trail. Matches `BUF_STOP`. |
| `MAXHOLD_H` | 48 (hours) | §8 | Two sessions; between "24h captures most MFE" and the 72h sim horizon; caps squeeze-time and honors flat-or-banked-into-Asia (market-structure §2.1/§2.3). |
| `CD_DEDUP` | 6 (H1 bars) | §9 | ≥6-bar min spacing (market-structure fade-hold sim). |
| `CD_LOSS` | 24 (H1 bars) | §9 | One-day post-loss cooldown = SB-1.1 hysteresis unit; avoids re-fading the same squeeze (economics §4). |
| `DOSE_AC` / `DOSE_BT` / `DOSE_BEAR_TREND` | 0.25 / 0.30 / 0.35 (%) | §10 | Monotone in SB-1.1 severity; full reserved for D1-confirmed; does not act on the +0.403R inversion. |
| `InpSleeveRiskPct` (FIT config) | 0.35 (%) | §10 | Cap so the full-dose state passes the sleeve `min()` unclamped. |
| `TP1_MIN_BODY` | 1 × `_Point` | §3 | Div-by-zero guard on body ratio (matches CPinBarEntry). |
| `QUAL_MIN_FIRE` | 3 (SETUP_B) | §14 | Any fully-valid setup already scores ≥3; score is telemetry + future dial, dose is state-driven. |

---

## 12. No-look-ahead audit (every condition names the bar index it reads)

**Contract:** CREV evaluates **once per new H1 bar** (the `isNewBar` block, §12b). The forming bar `[0]` is **never** read for OHLC. Only closed bars `[1]`, `[2]`, … and confirmed fractal pivots (index ≥3) are read. The **entry fill price** is the live BID at signal time — that is a fill price, not a peek at a bar that hasn't closed (identical convention to `CCrashBreakoutEntry` and `CPinBarEntry`).

| Condition | Reads | Bar/handle | Closed? |
|---|---|---|---|
| State gate (§1) | `GetBearState()` | ledger keyed on `iTime(H1,1)` = last closed H4's state | ✅ closed |
| Rally rise (§2.1) | `close[1]`, `low[1..6]`, `ATR[1]` | H1 `[1..6]`, ATR handle buffer `[1]` | ✅ |
| EMA/level zone (§2.2) | `high[1]`, `EMA21[1]`, `EMA50[1]`, `ATR[1]`, `Lb` | H1 `[1]`, EMA/ATR buffers `[1]`; `Lb` from confirmed pivots (≥3) | ✅ |
| Trigger candle (§3) | `open[1]`, `close[1]`, `high[1]`, `close[2]` | H1 `[1]`,`[2]` | ✅ |
| Lower high (§4) | `high[1..6]` (rallyHigh), confirmed H1 pivot highs at 3..24 | H1 `[3..24]` (fractal needs +2 closed) | ✅ |
| Room / support (§5) | confirmed H1 pivot lows 3..24, H4 pivot lows 3..30, spread | H1/H4 `[≥3]`, `SYMBOL_SPREAD` live | ✅ (levels closed; spread is live, used only in the cost adjustment) |
| Over-extension veto (§6) | `close[1]`, `EMA50[1]`, `ATR[1]` | H1 `[1]` | ✅ |
| Stop (§7) | `rallyHigh` (high[1..6]), `ATR[1]`, spread | H1 `[1..6]`, live spread | ✅ / live spread (fill-time cost) |
| TP1/TP2 (§8) | confirmed H1/H4 pivot lows, `R` | H1/H4 `[≥3]` | ✅ |
| Runner LH trail (§8) | new confirmed H1 pivot highs, `ATR[1]` | H1 `[≥3]`, ATR `[1]` | ✅ |
| Max-hold (§8) | `iTime(H1,0)`, `open_time` | current bar **time only** (not its OHLC) | ✅ (time compare only) |
| Dedup/cooldown (§9) | stamped times, confirmed pivots, `close[1]` | H1 `[1]`,`[≥3]` | ✅ |

**The single live read is the entry BID and the current spread** — both are fill-time execution facts, not bar OHLC, exactly as the two reference plugins do it. Everything that *decides* whether to fire is closed-bar.

### 12b. Where CREV is driven

There is currently **no caller** of `ExecuteSleeveSignal` (gateway header: "No callers exist in this build"). CREV is the first sleeve engine and must be wired into `OnTick`'s `isNewBar` block, **after** `g_stateManager.UpdateMarketState()` (so the bear-state ledger has advanced) and **after** the baseline entry logic (so baseline slot counts are current), guarded so the path is byte-identical to today when off:

```
if(InpEnableShortSleeve && InpEnableCREV && g_crevEntry != NULL)   // both default OFF
{
   EntrySignal crevSig = g_crevEntry.CheckForEntrySignal();        // closed-bar; at most one signal
   if(crevSig.valid)
      g_tradeOrchestrator.ExecuteSleeveSignal(crevSig, "CREV");    // sleeve enforces max-1 / caps / halts
}
```
CREV emits **at most one signal per bar** (single candidate; no cascade needed — it is the only sleeve engine). Identity when off is guaranteed: the sleeve master and `InpEnableCREV` both default OFF, and no baseline count/exposure site sees a sleeve position (SB-0.1 audit).

---

## 13. How it maps to the plugin + sleeve interface

**Plugin.** New `class CCrashRallyFadeEntry : public CEntryStrategy` in `Include/EntryPlugins/CCrevEntry.mqh` (C-prefix + role suffix; internal name `"CREV"`). It mirrors `CCrashBreakoutEntry`/`CPinBarEntry`:
- **Handles (Initialize):** `iMA(H1,21,EMA,CLOSE)`, `iMA(H1,50,EMA,CLOSE)`, `iATR(H1,14)` — EMA21(H1)/ATR14(H1) are already created by `CCrashBreakoutEntry` and the coordinator; MT5 refcounts shared handles, so no duplication cost. Also `CopyHigh/CopyLow(PERIOD_H1)` and `CopyHigh/CopyLow(PERIOD_H4)` for the fractal scans. **No new D1 handle** (state comes from the ledger).
- **Context:** holds `IMarketContext*` for `GetBearState()` (and `GetH4Trend()` if wanted for logging). `SetContext` as in the reference plugins.
- **`CheckForEntrySignal()`** returns an `EntrySignal` populated with:
  - `valid`, `symbol=_Symbol`, `action="SELL"`, `source=SIGNAL_SOURCE_PATTERN`.
  - `entryPrice = BID`; `stopLoss = SL` (§7); `takeProfit1 = TP2_price` (§8) — **the full-thesis structural target is stamped as the broker TP so the `ExecuteSignal` RR/reward-room gate passes at ≥1.5R and there is a broker safety exit**; the *partials* (TP1 50%, TP2 30%) and the runner are managed by the CREV exit branch below.
  - `takeProfit2 = TP1_price`, `takeProfit3 = 0` (carry TP1 as a secondary price for the coordinator branch; naming is a convention choice — see the exit-ownership note).
  - `riskPercent =` the per-state dose (§10).
  - `patternType =` a **new** `PATTERN_CREV_FADE` enum member (recommended; do **not** reuse `PATTERN_CRASH_BREAKOUT` — that would misfire the existing §D `InpCrashTrailSuppress` branch and pollute crash telemetry). Add to `ENUM_PATTERN_TYPE` in `Include/Common/Enums.mqh`.
  - `qualityScore =` the §14 score; `comment="CREV Rally-Fade"`.

**Sleeve routing.** `ExecuteSleeveSignal(signal, "CREV")` already enforces: master switch, SELL-only, sleeve max-positions (`InpSleeveMaxPositions=1`), slot reserve (`InpSleeveSlotReserve=2` → CREV opens only when baseline positions ≤ `InpMaxPositions−2`), total/family risk caps, sleeve DD/daily halts, and the account backstops + `InpMaxTotalExposure` via `ExecuteSignal`. CREV supplies **only** the signal + family + per-state risk. **No CREV-specific risk/halt logic is needed** — it is all in the sleeve.

**Exit ownership (the interface reality the owner must confirm — see §15).** Today the sleeve open-path stamps the **regime exit profile** onto sleeve positions (`CTradeOrchestrator` lines ~1252–1267: `exit_tp0/tp1/tp2_distance`, `exit_chandelier_mult`) and the coordinator then runs its R-based TP ladder + chandelier trail. **CREV must NOT use that machinery** (owner spec: CREV-specific exits). The minimal faithful implementation is a **CREV-pattern-scoped exit branch** in `CPositionCoordinator`, gated by `pos.is_sleeve && pos.sleeve_family=="CREV"` (or `pos.pattern_type==PATTERN_CREV_FADE`), that:
1. **Bypasses** the regime-profile stamp for CREV (do not copy `ep.*` onto a CREV position) and instead stamps CREV's **price-based** partials: 50% at `takeProfit2` (TP1_price), 30% at `takeProfit1`(TP2_price). This reuses the existing partial-close plumbing (`PositionClosePartial`, `tp0_lots/tp1_lots` telemetry) but keyed on **price** rather than R-distance — a small, isolated addition next to the existing ladder at `CPositionCoordinator` ~line 2320.
2. **Suppresses the chandelier unconditionally** for CREV positions — extend the existing `trail_suppress_pattern` scoping (`ApplyTrailingPlugins`, ~line 3260) so CREV is never fed a `CChandelierTrailing` proposal (the §D guard, but permanent, not gate-then-release).
3. **Applies the lower-high structure trail** (§8) as the only SL ratchet.
4. **Enforces the 48h max-hold** via the existing `bars_since_entry` counter (already computed at ~line 2583) with a CREV-scoped `StampExitRequest`/`ClosePosition("CREV_MAXHOLD")`.

All four are **pattern/family-scoped** — with `InpEnableShortSleeve=false` (default) no CREV position exists, so every branch is dead and identity to the cent is preserved (the SB-0.1 guarantee).

**Inputs to add** (all default OFF/neutral so identity holds): `InpEnableCREV=false` (plugin master), and the FIT-run value `InpSleeveRiskPct=0.35`. The per-state doses (0.25/0.30/0.35) and all §11 constants are **compile-time frozen constants inside the plugin**, not tunable inputs (freezing discipline — they are not sweepable levers).

---

## 14. Quality-scoring criteria (0–10; maps to `ENUM_SETUP_QUALITY`)

Score is **telemetry + a future dose dial**; for v1 the **dose is state-driven (§10), not score-driven**. A fully-valid setup (all hard gates pass) scores ≥3 = `SETUP_B`, which is the minimum to fire (`QUAL_MIN_FIRE=3`). Points:

| Points | Earned when | Band it pushes toward |
|---:|---|---|
| +3 | Base: state + rally + trigger + valid LH + room + no over-extension all pass | `SETUP_B` (3) |
| +2 | `state == BEAR_TREND` (D1-confirmed) [+1 if `BEAR_TRANSITION`, +0 if `ACTIVE_CORRECTION`] | → `SETUP_B_PLUS`/`SETUP_A` |
| +2 | Room RR ≥ 2.0 (vs the 1.5 floor) | → `SETUP_A` |
| +1 | Trigger upper wick ≥ 2.0×body (strong rejection vs the 1.0 floor) | |
| +1 | Rally faded at **EMA50** (deeper mean) rather than EMA21 | |
| +1 | Broken-support retest **coincided** with the EMA zone (level+mean confluence) | → `SETUP_A_PLUS` |

Cap at 10. Map to the enum by the repo bands (`SETUP_A_PLUS` 8–10, `SETUP_A` 6–7, `SETUP_B_PLUS` 4–5, `SETUP_B` 3, `SETUP_NONE` <3). **Confluence honesty:** the LH is the *same object* as SB-1.1's F14 and the SMC/ICT "lower high" — scored **once** (the +3 base), never triple-counted.

---

## 15. What would falsify this design

CREV is registered to be **killed no-change on any FIT-gate failure** (AB_TEST_LOG SB-1.2). Concretely, the design is falsified / abandoned if, on the pre-registered **FIT 2019–2022 / CONFIRM 2023–2026H1** split (LEDGER state source, `InpEnableShortSleeve=true`, `InpEnableCREV=true`, `InpSleeveRiskPct=0.35`):

1. **Identity breach:** the 952 baseline positions are not bit-identical (`baseline-23856-2026-07-11`) — a **bug**, not a judgment call (the sleeve slot-reserve guarantees it).
2. **FIT incremental avg R < 0**, or **book EqDD worsens by > +0.30pp**, or **any calendar year worse by > $500**, or sleeve DD breaches `InpSleeveMaxDDPct`, or a **normal-bull-period loss cluster dominates** the P&L.
3. **CONFIRM:** direct CREV contribution not positive, or not positive ex-2025, or **no valid contribution in 2023 OR 2026H1**, or the result depends on **1–2 trades**.
4. **Structural falsifiers specific to this design:**
   - If CREV fires **< ~15 times** over the full window (the BEAR_RALLY-exclusion, §13 judgment call, starves it) → underpowered, coverage gate fails.
   - If the fills concentrate in `ACTIVE_CORRECTION` and lose there (the violence-leg squeeze) while `BEAR_TREND`/`BEAR_TRANSITION` are empty → the state gate is fading the wrong leg; revisit including BEAR_RALLY / reading severity.
   - If the **max-hold** exits systematically bank negative R (fades not resolving in 48h) → the time-box is wrong for this instrument; 24h/72h is the registered revisit.

**Power honesty (registered):** expected CREV fills ~20–40 over the full window; cohort ΔR SE will be large. The **binding** gates are net-$/DD/scope/participation; cohort-R is a sanity floor. Do not adopt on a net-$ print inside the ±$1,500 noise floor — adopt on the registered gates only. Zero direct contribution is a **live, acceptable** outcome (the purchase is bear-window coverage + DD tail-shape, market-structure §4.1), provided the DD and identity gates hold.

---

## 16. Judgment calls the owner may want to revisit (raw)

1. **BEAR_RALLY is excluded (biggest one).** `GetBearState()` returns the **overlay label** `BEAR_RALLY` (not the underlying S-severity) once a rally retraces ≥38.2% of the episode range **and** closes above H4 EMA21 (SB-1.1 §2.3). The registered gate {AC, BT, BEAR_TREND} therefore **gates CREV OUT at exactly the deep rallies** — the strongest fade-able bounces, which are also the biggest squeezes ($260–664 rips). Net effect: CREV fades the **shallower** rallies (still labeled bear) and stands down on the deep ones. That is arguably *safer* (deep rallies squeeze hardest), but it (a) reduces fill count and (b) keeps the measured-worst cell (`ACTIVE_CORRECTION` −0.019) while dropping a measured-positive one (`BEAR_RALLY` short +0.088, n=11). The registration says the 3 labels only, so I built to that. **If the owner wants CREV to fade the deep bear-market rallies, either add `BEAR_RALLY` to `STATE_SET` or expose the underlying severity `S` from the ledger and gate on `S≥2` instead of the label.** This is the single change most likely to move CREV's participation.

2. **Per-state dose ordering.** I froze `ACTIVE_CORRECTION 0.25 / BEAR_TRANSITION 0.30 / BEAR_TREND 0.35` (monotone in severity, full reserved for D1-confirmation). The pre-registration's **illustrative** example was `BEAR_TRANSITION 0.25 / ACTIVE_CORRECTION 0.30`, which *inverts* the severity ladder (AC gets more than BT). Neither ordering acts on the measured +0.403R inversion. If the owner prefers the illustrative ordering, swap `DOSE_AC` and `DOSE_BT`. My ordering is the one I can justify from the severity ladder; the example's I cannot.

3. **Max-hold = 48h.** Chosen between the 24h "most MFE captured" and the 72h sim horizon, honoring flat-or-banked-into-Asia. 24h would be more aggressive-harvest (closer to the 4.3h realized median); 72h matches the raw sim. Frozen at 48; flagged as the obvious A/B if participation and hold-time diagnostics suggest otherwise.

4. **Exit ownership requires a coordinator change, not just a signal.** The current sleeve stamps the **regime exit profile + chandelier** onto sleeve positions ("normal exit machinery for now", `CTradeOrchestrator` ~line 1253). CREV's spec **cannot** be satisfied by signal fields alone — it needs the CREV-pattern-scoped exit branch (§13: price-based partials + LH trail + max-hold + permanent chandelier suppression). This is a real, bounded surface addition (mirrors §D's pattern-scoping) and it is the part of "one change per binary" the owner should green-light explicitly. Everything is dead when `InpEnableShortSleeve=false`, so identity is preserved.

5. **`MINRR=1.5` and `TP2_FALLBACK_R=2.0`.** The a-priori sim used 2R targets; realized economics say winners top out under 2R once the TP artifact is stripped. I chose 1.5 as the room floor and 2.0 only as the no-H4-support fallback. If the owner wants the design closer to the seed sim, both go to 2.0 — but that would reduce fill count (fewer setups clear a 2R room gate) and, per the realized data, chase an R the tape rarely pays.

6. **Trigger has no RSI/momentum-oscillator arm.** I kept the trigger candle-only (bearish rejection close + upper wick) inside the structure, per the owner rule. An H1 RSI roll-down or stochastic cross could be added as an *optional* confirmation, but I deliberately left it out to keep the trigger falsifiable and to avoid a "faster MA/oscillator gate" drift toward the pre-killed levers. Flagged in case the owner wants a momentum arm.
