# SB-2.1 — CONT (H4/H1 lower-high CONTINUATION short) — implementable, look-ahead-free spec

**Date:** 2026-07-11 · **Author:** stok (trading-analyst design task; READ-ONLY — no source edits, no tester runs)
**Program:** `workflowAnalysis/short-book-tracker.md` §SB-2.1 · **Registration:** `AB_TEST_LOG.md` "SB-2.1 PRE-REGISTRATION — H4/H1 lower-high CONTINUATION engine (owner's designated primary short)"
**Baseline of record:** $23,856.89 / 952 positions (tag `baseline-23856-2026-07-11`).
**Routing:** SHORT-only SLEEVE strategy → `CTradeOrchestrator::ExecuteSleeveSignal(signal, "CONT")` (SB-0.1 gateway, validated baseline-isolation-exact across 4 CREV runs). CONT supplies the entry signal (SL + TP prices), the family tag `"CONT"`, and a per-severity `riskPercent`. The sleeve owns max-1-position, slot reservation, risk/DD/daily halts, baseline non-displacement. **CONT never touches the baseline entry path.**
**State source:** `CMarketContext::GetBearState()` → `InpBearStateSource=LEDGER` = the frozen validated `sb11_states.csv` (100.0000% verified, SB-1.1). CONT **reads** the state; it never recomputes it.

> **Design register discipline.** Everything below is fixed **a-priori** and marked **FROZEN** — no post-results tuning. Anchors: state = `sb11-state-model.md`; market structure / pre-killed traps = `short-side-market-structure.md`; economics = `short-side-economics.md`; the arm→trigger + sleeve + exit-branch pattern = `CCrevEntry.mqh` / `CPositionCoordinator::ManageCrevPosition` / `sb12-crev-spec.md`. **The CREV lesson (why the fade failed) is carried by construction:** CREV FADED a rally at the mean and lost (v2 FIT 4/4 losers, avg R −0.765) because gold fades squeeze and broken levels reclaim (breakdown-retest PF 0.57, 51/53 reclaim rate). **CONT is the opposite stance:** it does not fade the bounce — it sells the *resumption of the down-leg*, entering **with** the bear momentum on a confirmed break of prior structure, stop above a **confirmed** lower high. The SETUP is decoupled from the TRIGGER **from the start** (the CREV v1 starvation lesson): structure latches, the trigger fires within an arm window.

---

## 0. What CONT is, in one paragraph

CONT is a **trend-continuation short** that fires **only inside a validated bear structure** (SB-1.1 severity ≥ 2, with an explicit H4 lower-low + H4 lower-high structural gate). It waits for a **completed continuation pattern on H1**: a bearish impulse that printed a **lower low**, a pullback UP into a mean/level/38–62% zone that made a **confirmed lower high** (below the pre-impulse swing high), and then the **resumption BOS** — a closed bar **below the impulse (pullback-origin) low**. It sells that break, stops above the lower high, banks a fast partial at the nearer of the next structural support or 1R, a second partial at the next H4 support, and trails a small runner on confirmed lower highs while the state stays bearish, with a 48h time-box. It is **not** a fade of the lower high (that is CREV, closed), **not** a breakdown-*retest*-touch (killed, PF 0.57), **not** a standalone candlestick (owner rule), and **not** a crash-low chase (over-extension veto). It is the structural continuation short the owner registered as the **primary professional short strategy**, gated by the SB-1.1 state ledger and dose-controlled by severity.

**One-line CONT-vs-CREV distinction (do not conflate — this is the whole point):** CREV sells the *rejection candle at the lower high* (counter-trend fade, sells into strength → squeezed). CONT waits for the *break of the prior low below that lower high* (with-trend continuation, sells weakness after structure confirms → not a fade). Same lower-high object, opposite trade.

---

## 1. HTF gate (item 1)

**Rule.** At the **new-H1-bar** evaluation (§12), CONT may **arm** only when **ALL** hold on closed bars/confirmed pivots:

1. **State severity gate.** `BearStateSeverity(GetBearState()) ≥ 2` — the BEAR_FAMILY {`ACTIVE_CORRECTION`(2), `BEAR_RALLY`(2), `BEAR_TRANSITION`(3), `BEAR_TREND`(4)}. This is the exact registered SB-1.2-amended gate reused (`Enums.mqh` `BearStateSeverity()`). It **encodes H4 bearish momentum and regime**: the SB-1.1 bear score B that drives severity contains F9 (H4 EMA21<EMA50), F11 (H4 EMA50 slope<0) and the D1 structure blocks. **Therefore CONT adds NO separate H4-EMA momentum gate and NO H4 EMA handle** — "H4 momentum bearish" is the severity≥2 gate (owner's item-1 choice: *"the SB-1.1 severity already encodes this"*). Confluence honesty: momentum is counted here, once.
2. **H4 lower low (explicit, hard).** Using the 5-bar fractal pivot rule (§4) on the **H4** series: let `IL4` = the most recent confirmed H4 pivot low (index ≥ 3) and `PL4` = the prior confirmed H4 pivot low. Require `IL4 < PL4`. *(This is a hard structural gate, NOT merely implied by severity: severity≥2 can be reached via D1/momentum blocks without F14/LH+LL currently active, so the explicit H4-LL check is additive, not double-counted.)*
3. **H4 lower high (explicit, hard).** Let `SH4` = the most recent confirmed H4 pivot high and `SH4prev` = the prior confirmed H4 pivot high. Require `SH4 < SH4prev` — the current rally high is below the prior H4 swing high.

If any of (1)–(3) fails, or fewer than two confirmed H4 pivots of a needed type exist in the `CONT_H4_LOOKBACK`(=30) window, CONT does **not** arm (structure undefined = stand down).

**State bar-freshness (no look-ahead).** The ledger stamps the last **closed H4**'s state onto each H1 bar, keyed on `iTime(H1,1)`. CONT reads the state as of the last closed H1 bar; the forming bar's state is never read.

**State exit while in a position → HOLD to CONT's own exits (item-1 ruling, same as CREV).** Once open, a state change (including a flip out of BEAR_FAMILY) does **not** force-close or re-manage. The position is bounded by its own SL, TP1, TP2, lower-high trail, and the 48h max-hold (§8). The state is an *entry* gate; force-managing on the overlay-churny state (BEAR_RALLY median run 3 H4 bars) would add a noisier second exit trigger. Bounded time + structural stop make force-management strictly worse. **FROZEN.**

---

## 2. H1 impulse → lower low (item 2)

All indices H1 unless stated. `ATR = ATR14(H1)` Wilder, closed value `[1]`. `EMA21/EMA50 = EMA(21/50, close, H1)[1]`.

**Locate the impulse (closed bars only).**
- `IL` = the most recent **confirmed H1 pivot low** (§4 rule, index ≥ 3) inside `[3..CONT_L_LH]` (=24).
- `ILprev` = the prior confirmed H1 pivot low. Require **lower low:** `IL < ILprev`.
- `SH0` = the **pre-impulse swing high** = the most recent confirmed H1 pivot high **older than `IL`** (i.e. at a higher series index than the `IL` pivot bar) inside the window.
- **Minimum impulse size:** `SH0 − IL ≥ CONT_X_IMP × ATR`, `CONT_X_IMP = 1.5`. (1.5×ATR = the rubber-band 1R unit on this book — a genuine impulse leg, not chop.)

If `IL`, `ILprev` or `SH0` are undefined in the window → do not arm.

`IL` is the **pullback-origin low**: it is both the §5 continuation TRIGGER level and the §10 dedup anchor. `SH0` and `IL` define the **measured impulse** used for the §3 retrace fraction.

---

## 3. Retrace / pullback into a lower high (items 3 + 4)

The pullback is the up-leg from `IL`. `LH1` = the most recent **confirmed H1 pivot high newer than `IL`** (series index below the `IL` pivot bar) inside the window.

**Retrace fraction** (of the measured impulse): `retr = (LH1 − IL) / (SH0 − IL)`.

**Valid lower high (item 4).** `LH1 < SH0` **AND** `retr ∈ [CONT_MIN_RETR, CONT_MAX_RETR] = [0.382, 0.886]`.
- Lower bound `0.382` = a genuine pullback, not a shallow one-bar pause.
- Upper bound `0.886` = must remain a lower high with structural room; excludes near-full retraces that are really failed continuations. (`LH1 < SH0` already forbids ≥ 1.0.)

**Retrace zone reached (item 3)** — at least one arm (all buffers `× ATR`, `CONT_K_ZONE = 0.25`):
- **Fib arm:** `retr ≤ CONT_FIB_HI = 0.618` (the owner's 38–62% band; auto-qualifies inside `[0.382,0.618]`).
- **EMA arm:** `LH1 ≥ EMA21 − K_ZONE×ATR`  **OR**  `LH1 ≥ EMA50 − K_ZONE×ATR` (tagged the H1 mean within a quarter-ATR).
- **Broken-support arm:** `LH1` retested a former support now acting as resistance from below — reuse CREV's `BrokenLevelRetest(lvl, LH1, close@LH1, IL, ATR)`: decisive break (`IL < lvl − 0.25×ATR`), retest tag (`LH1 ≥ lvl − 0.25×ATR`), still under (`close < lvl`).

So the zone reduces to: `retr ∈ [0.382, 0.886]` **AND** (`retr ≤ 0.618` **OR** EMA-tag **OR** broken-support). A 38.2–61.8% retrace always qualifies; a deeper 61.8–88.6% retrace qualifies only if it tags a mean/level.

**Anti-trap note (do NOT confuse with the killed breakdown-retest).** The broken-support arm here is only a *retrace-zone qualifier for the SETUP* — CONT never enters on the touch of a level. Entry is the §5 break of `IL` **after** the lower high is confirmed. The killed pattern (market-structure §4.3.1, PF 0.57) entered on the retest touch of a broken level; CONT enters on the *resumption of the down-leg through prior structure*, with the confirmed lower high above it as the stop reference.

When §1+§2+§3+§4 all pass on the closed bar `[1]`, **LATCH ARMED** (§ state machine): stamp `IL` (trigger level + dedup anchor), `LH1` (invalidation level + stop anchor), `SH0`, the arm bar time, and which zone arm(s) fired (for §14 scoring). **No trade this bar.**

---

## 4. Pivot rule (FROZEN, reused verbatim from CCrevEntry / SB-1.1 §2.1)

**5-bar fractal.** Bar `i` is a **pivot high** iff `H[i] > H[i−1]` AND `H[i] > H[i+1]` AND `H[i] ≥ H[i−2]` AND `H[i] ≥ H[i+2]` (strict vs the two immediate neighbours, ≥ vs the outer two). Mirror for **pivot low** (`<`,`<`,`≤`,`≤`). Confirmed only when bars `i−2..i+2` are closed → on a series with index 1 = last closed bar, the newest usable index is `i = 3`. Applied identically to the H1 and H4 series (`IsPivotHigh`/`IsPivotLow`). No zigzag/ATR-alternation filter (raw fractals; the SB-1.1 zigzag lives inside the ledger and is not re-derived). The lower high is the **same object** as SB-1.1 F14 and the SMC/ICT "lower high" — **counted once** (the §14 +3 base).

---

## 5. Continuation TRIGGER (item 5) — within the arm window

**Owner rule (binding):** a bearish candle pattern may confirm **only inside this validated structure**, never standalone. So the trigger fires **only** while ARMED (§1–§4 already validated) and within `CONT_M_ARM` (=12) bars of the arm bar. All reads are the **closed** bar `[1]`.

**Primary trigger — the resumption BOS (FROZEN):**
```
close[1] < IL          // a closed bar closes below the impulse / pullback-origin low
```
This is a genuine new lower low = break of structure in the trend direction = the down-leg resuming. Entry is **with** momentum (selling weakness), not into a rally — the structural reason CONT is expected more robust than the CREV fade.

**Secondary quality overlay — displacement (does NOT create a separate entry level).** The same `close[1] < IL` break, when it occurs on a **bearish displacement** candle, earns a §14 quality point:
```
bearish_close = (close[1] < open[1]) AND (close[1] < close[2])
range         = high[1] − low[1]
displacement  = bearish_close AND (range ≥ CONT_DISP_ATR × ATR) AND
                (close[1] ≤ low[1] + range/3)          // close in lower third
```
Displacement is a *strength grade* on the break, never a standalone trigger — satisfying the owner rule (candles only confirm inside validated structure).

**Failed-reclaim (documented, INACTIVE in v1).** A failed-reclaim variant (poke above `LH1` intrabar, close back below) is the nearest cousin of the killed breakdown-retest and risks reintroducing the reclaim trap; it is **not active** in v1. Flagged in §16 for the owner.

On a trigger, recompute §7 stop, §5-room, §6 over-extension, §10 dedup/cooldown; if all pass → emit the SHORT. On any partial miss, **stay ARMED** (within the window).

---

## 6. Invalidation + squeeze veto (item 6)

**ARM invalidation (clear the latch, no trade)** — any of:
1. `close[1] > LH1` — a closed bar closes above the lower-high level → structure broken to the upside (rally resumed / we were early).
2. `severity < 2` — left BEAR_FAMILY.
3. `CONT_M_ARM` (=12) bars elapsed since the arm bar.

**Squeeze veto at the trigger (carried from CREV, FROZEN `CONT_P_OVEREXT = 3.0`):**
```
if  close[1] < EMA50 − CONT_P_OVEREXT × ATR   →   VETO this trigger (stay armed)
```
Selling a break when price already sits ≥ 3×ATR below the H1 EMA50 is chasing a **waterfall** into the 1.9–5.9×ATRd squeeze envelope (market-structure §2.2, §4.3.6). 3× = the upper cluster of observed squeeze multiples. **FROZEN.** *(Judgment call, §16: a continuation engine is meant to ride down-legs, so this veto may be too tight for exactly the E8 waterfalls — flagged as the obvious loosen/off A/B, not tuned pre-evidence.)*

---

## 7. Stop (item 7) — FROZEN `CONT_BUF_STOP = 0.5`

Structural stop above the **confirmed lower high** + spread + ATR buffer:
```
spread_price = SymbolInfoInteger(SYMBOL_SPREAD) × _Point      // XAUUSD+: 1 point = 0.01
SL           = LH1 + spread_price + CONT_BUF_STOP × ATR
entry        = live BID at trigger time                       // fill price, not a bar peek
stopDist     = SL − entry   (> 0 required)                    // SHORT stop above entry
R            = stopDist
```
No candle-size-only stop. The stop lives above the structure that must NOT be reclaimed for the continuation thesis to hold (a close above `LH1` is the §6 invalidation), plus one spread (a SHORT is stopped on the ASK) plus a half-ATR buffer. **FROZEN.**

**Geometry note (honest).** Entry ≈ just below `IL`; SL above `LH1`. So `R ≈ (LH1 − IL) + buffer` = the pullback height + 0.5×ATR. A 38–62% pullback on a ≥1.5×ATR impulse gives `R ≈ 0.6–1.4×ATR` — tight and asymmetric. Deeper (to 0.886) retraces inflate `R` and are naturally filtered by the §5 room gate. **A structural stop survives one reclaim, not the $105–$664 mega-squeeze class** (market-structure §2.2); the mitigants are the state gate, the confirmed-lower-high requirement, the over-extension veto, and the 48h time-box — not a wider (uneconomic) stop.

---

## 8. Targets / exits (item 8) — reuse the CREV exit-branch template

All partials are **price-level** (structural), managed by a CONT-pattern-scoped coordinator branch that **mirrors `ManageCrevPosition`** verbatim in shape (price partials → LH trail → max-hold → permanent chandelier suppression). `R = stopDist`.

**TP1 — fast partial, 50% (`CONT_TP1_VOL = 50`).** The nearer (higher price = banked first) of the next structural support or 1R:
```
recentH1Low = highest confirmed H1 pivot low at index 3..CONT_SUP_H1_LOOKBACK(24) that is < entry
TP1_price   = MAX( recentH1Low (if it exists),  entry − CONT_TP1_R × R )      // CONT_TP1_R = 1.0
```
(If `recentH1Low` doesn't exist — we are at fresh lows — `TP1_price = entry − 1.0×R`.) **Precedence:** the prior swing low takes precedence *when it is nearer than 1R* (MAX = higher = banked first, the fast-harvest doctrine, market-structure §2.3 / economics §2.3); otherwise 1R.

**TP2 — structural partial, 30% (`CONT_TP2_VOL = 30`).** The next H4 support below TP1:
```
TP2_price = highest confirmed H4 pivot low at index 3..CONT_SUP_H4_LOOKBACK(30) that is < TP1_price
fallback (none in window): TP2_price = entry − CONT_TP2_FALLBACK_R × R          // = 2.0
```

**Runner — 20% (`CONT_RUNNER_VOL = 20`), lower-high structure trail (the ONLY SL ratchet), FROZEN `CONT_TRAIL_BUF = 0.5`.** Reuse `FindTwoRecentPivotHighs` + the CREV ratchet:
```
On each new confirmed H1 pivot high P that is LOWER than the previous confirmed pivot high:
    candidateSL = P + CONT_TRAIL_BUF × ATR + spread_price
    SL = MIN(SL, candidateSL)     // SHORT SL only ratchets DOWN; must stay above cur price
```
No fixed TP on the runner (broker TP cleared at the TP1 partial, exactly as `ManageCrevPosition` does). **Runner managed only while severity ≥ 2** is satisfied by the max-hold + LH-trail; no separate state-flip force-close (item-1 ruling).

**Max-hold time-box (FROZEN `CONT_MAXHOLD_H = 48`).** Force-close all remaining lots at `bars_open ≥ 48` closed H1 bars (two sessions; flat-or-banked-into-Asia — the overnight-bid finding, market-structure §2.1/§2.3). Reuse the `bars_since_entry` counter and `StampExitRequest`/`ClosePosition("CONT_MAXHOLD")`.

**NO generic chandelier clamp.** CONT positions are **excluded from all `CChandelierTrailing` proposals for the life of the position** — extend the existing `ApplyTrailingPlugins` pattern-scoped guard to `pattern_type == PATTERN_CONT_SHORT` (permanent, like CREV's, not gate-then-release). The LH trail is the only trail; the entry-stamped hard SL/TP are never widened.

---

## 9. Per-severity dose (item 9) — FROZEN

Monotone in the SB-1.1 severity ladder, full reserved for the D1-confirmed state — the **same band and ordering as CREV** (owner ruling of record: reduced in transition, full only in confirmed BEAR_TREND):

| State | Severity | CONT `riskPercent` | FROZEN |
|---|---|---:|---|
| `ACTIVE_CORRECTION` / `BEAR_RALLY` | 2 | **0.25%** | ✅ |
| `BEAR_TRANSITION` | 3 | **0.30%** | ✅ |
| `BEAR_TREND` (D1-confirmed) | 4 | **0.35%** | ✅ |

**Justification.** Monotone-increasing dose is **more** justified for a *continuation* engine than it was for CREV's fade: continuation is highest-probability in a **confirmed, sustained** downtrend (BEAR_TREND, D1-confirmed), and most squeeze-prone in the violent first leg (ACTIVE_CORRECTION) and deep counter-trend rallies (BEAR_RALLY). Full (0.35%) at BEAR_TREND, reduced (0.25%) at sev-2. This deliberately does **not** act on the measured +0.403R `BEAR_TRANSITION` inversion (SB-1.1 §4) — recorded, not acted on pre-evidence, exactly as the CREV ruling requires. **FROZEN.**

**Sleeve-cap interaction (implementation-binding).** The gateway clamps `sleeve_risk = min(signal.riskPercent, InpSleeveRiskPct)`. For the 0.35% BEAR_TREND dose to pass unclamped, the FIT config sets **`InpSleeveRiskPct = 0.35`** (family/total caps `InpSleeveMaxFamilyRiskPct`/`InpSleeveMaxTotalRiskPct` default 0.40 > 0.35, so a single full-dose CONT position is admitted; `InpSleeveMaxPositions = 1`). Downstream reducers (EC v3, counter-trend cut, exposure rescale) may only reduce further.

---

## 10. Dedup / cooldown (item 10) — FROZEN

**"Same impulse" (no re-entry within one continuation leg).** At each CONT entry, stamp `traded_impulse_low_time` and `traded_impulse_low_price = IL`. A new CONT candidate is **rejected as SAME_IMPULSE** unless **either**:
- (a) a **new confirmed H1 pivot low** has formed since `traded_impulse_low_time` that is **lower** than `traded_impulse_low_price` (a fresh, distinct continuation leg deeper down); **or**
- (b) price has closed **above** `LH1 + CONT_BUF_STOP × ATR` for the traded structure (the prior structure is invalidated to the upside).

**Hard min-spacing (FROZEN `CONT_CD_DEDUP = 6` H1 bars).** No two CONT entries within 6 H1 bars regardless of (a)/(b).

**Post-loss cooldown (FROZEN `CONT_CD_LOSS = 24` H1 bars).** After any CONT position closes with realized `R < 0`, block all new CONT entries for 24 H1 bars (one day) — stops CONT re-selling the same reclaim/squeeze that just stopped it (the worst short losses cluster as intraday squeeze deaths, economics §4). Reuse the coordinator's family-scoped loss stamp (mirror the `sleeve_family == "CREV"` branch for `"CONT"`).

Dedup state (`traded_impulse_low_time/price`, `LH1` of the traded structure, last-entry bar, last-loss bar) is CONT-internal, runtime-only, recomputable from bar history after a restart (no new persisted decision state).

---

## 11. FROZEN constants table (all a-priori; no post-results tuning)

| Name | Value | Where | A-priori justification / anchor |
|---|---:|---|---|
| `CONT_MIN_SEV` | 2 | §1 | severity≥2 = BEAR_FAMILY incl BEAR_RALLY (SB-1.2 amendment); encodes H4 momentum (F9/F11) + regime. |
| `PIVOT` | 5-bar fractal, confirm +2, usable idx ≥3 | §1,§2,§3,§4,§8,§10 | SB-1.1 §2.1 / CCrevEntry swing rule (closed-bar, no look-ahead). |
| `CONT_H4_LOOKBACK` | 30 (H4 bars) | §1 | SB-1.1 F15 window (5 days) for the H4 LL/LH pivots. |
| `CONT_L_LH` | 24 (H1 bars) | §2,§3 | One day of H1 for the operative swing high/low (= CREV L_LH). |
| `CONT_X_IMP` | 1.5 (×ATR14 H1) | §2 | Min impulse = the rubber-band 1R stretch unit on this book; a real impulse, not chop. |
| `CONT_MIN_RETR` | 0.382 | §3 | Fib 38.2% — genuine pullback floor. |
| `CONT_MAX_RETR` | 0.886 | §3 | Fib 88.6% — must remain a lower high with room; excludes near-full retraces. |
| `CONT_FIB_HI` | 0.618 | §3 | Owner's 38–62% band; fib-arm auto-qualify ceiling. |
| `CONT_K_ZONE` | 0.25 (×ATR14 H1) | §3 | Quarter-ATR proximity to EMA/level (= CREV; SB-1.1 quarter-ATR convention). |
| `CONT_M_ARM` | 12 (H1 bars) | §5,§6 | Arm→trigger window = half a session; **longer than CREV's 6 on purpose** — continuation resolves slower than a fade rejection; the a-priori anti-starvation choice. |
| `CONT_DISP_ATR` | 1.0 (×ATR14 H1) | §5,§14 | Displacement-candle range floor (quality overlay, not a trigger level). |
| `CONT_P_OVEREXT` | 3.0 (×ATR14 H1 below EMA50) | §6 | Upper squeeze cluster (1.9–5.9×ATRd); "too deep to sell the break" waterfall guard. |
| `CONT_BUF_STOP` | 0.5 (×ATR14 H1) | §7,§10 | Half-ATR structural buffer above the lower high (= CREV). |
| `CONT_MINRR` | 1.5 | §5 | Honest asymmetric room floor net of costs (= CREV; realized short avg R small, MFE artifact stripped — economics §2.3). |
| `CONT_SUP_H1_LOOKBACK` | 24 (H1 bars) | §8 | One day; nearest H1 support / TP1 recent low. |
| `CONT_SUP_H4_LOOKBACK` | 30 (H4 bars) | §8 | SB-1.1 F15 support window (5 days); TP2 target. |
| `CONT_TP1_R` | 1.0 (R) | §8 | The "or 1R" arm of the fast partial (first-R harvest). |
| `CONT_TP2_FALLBACK_R` | 2.0 (R) | §8 | Fallback objective when no H4 support below TP1. |
| `CONT_TP1_VOL`/`TP2_VOL`/`RUNNER_VOL` | 50/30/20 (%) | §8 | Front-loaded short shape (tier3 §C / economics §6, direction-scoped) (= CREV). |
| `CONT_TRAIL_BUF` | 0.5 (×ATR14 H1) | §8 | Buffer above each confirmed lower high for the runner trail (= CREV). |
| `CONT_MAXHOLD_H` | 48 (hours) | §8 | Two sessions; flat-or-banked-into-Asia (market-structure §2.1/§2.3) (= CREV). |
| `CONT_CD_DEDUP` | 6 (H1 bars) | §10 | Min spacing between entries (= CREV). |
| `CONT_CD_LOSS` | 24 (H1 bars) | §10 | One-day post-loss cooldown = SB-1.1 hysteresis unit (= CREV). |
| `CONT_DOSE_SEV2/3/4` | 0.25/0.30/0.35 (%) | §9 | Monotone in severity; full reserved for D1-confirmed BEAR_TREND (= CREV band; more justified for continuation). |
| `CONT_QUAL_MIN_FIRE` | 3 (SETUP_B) | §14 | Any fully-valid setup already scores ≥3; score is telemetry + future dial, dose is severity-driven. |
| `CONT_TP1_MIN_BODY` | 1 × `_Point` | §5,§14 | Div-by-zero guard on the displacement body ratio (matches CPinBarEntry/CREV). |
| `InpSleeveRiskPct` (FIT config) | 0.35 (%) | §9 | Cap so the full-dose state passes the sleeve `min()` unclamped. |

---

## 12. No-look-ahead audit (every condition names the bar index it reads)

**Contract:** CONT evaluates **once per new H1 bar** (§12b). The forming bar `[0]` is **never** read for OHLC. Only closed bars `[1],[2],…`, confirmed fractal pivots (index ≥ 3, H1 and H4), and indicator buffers at `[1]` are read. The **entry fill price** is the live BID at trigger time — a fill price, not a peek at an unclosed bar (identical convention to `CCrevEntry`/`CCrashBreakoutEntry`).

| Condition | Reads | Bar/handle | Closed? |
|---|---|---|---|
| State gate (§1.1) | `GetBearState()` → `BearStateSeverity` | ledger keyed on `iTime(H1,1)` = last closed H4's state | ✅ |
| H4 LL / LH (§1.2/1.3) | confirmed H4 pivot highs & lows | H4 series `[≥3]` (fractal needs +2 closed) | ✅ |
| Impulse LL + `SH0` (§2) | confirmed H1 pivot lows/highs, `ATR[1]` | H1 `[≥3]`, ATR `[1]` | ✅ |
| Retrace + lower high (§3/§4) | `LH1`,`IL`,`SH0`, `EMA21[1]`,`EMA50[1]`,`ATR[1]`, `Lb` | H1 `[≥3]`, EMA/ATR `[1]`; `Lb` from confirmed pivots | ✅ |
| Trigger BOS (§5) | `close[1]` vs stamped `IL` | H1 `[1]` | ✅ |
| Displacement overlay (§5) | `open[1]`,`close[1]`,`high[1]`,`low[1]`,`close[2]`,`ATR[1]` | H1 `[1]`,`[2]` | ✅ |
| ARM invalidation (§6) | `close[1]` vs `LH1`; severity; window count vs `arm_bar_time` | H1 `[1]`; ledger; series time | ✅ (time compare only) |
| Squeeze veto (§6) | `close[1]`,`EMA50[1]`,`ATR[1]` | H1 `[1]` | ✅ |
| Stop (§7) | `LH1`, `ATR[1]`, spread | H1 `[≥3]`/`[1]`, live spread | ✅ / live spread (fill-time cost) |
| Room (§5) | confirmed H1/H4 pivot lows below entry, spread | H1/H4 `[≥3]`, live spread | ✅ |
| TP1/TP2 (§8) | confirmed H1/H4 pivot lows, `R` | H1/H4 `[≥3]` | ✅ |
| Runner LH trail (§8) | new confirmed H1 pivot highs, `ATR[1]` | H1 `[≥3]`, ATR `[1]` | ✅ |
| Max-hold (§8) | `iTime(H1,0)`, `bar_time_at_entry` | current bar **time only** | ✅ (time compare only) |
| Dedup/cooldown (§10) | stamped times/prices, confirmed pivots, `close[1]` | H1 `[1]`,`[≥3]` | ✅ |

**The single live read is the entry BID and the current spread** — fill-time execution facts, not bar OHLC. Everything that *decides* whether to fire is closed-bar.

### 12b. Where CONT is driven

Mirror the CREV OnTick block (`UltimateTrader.mq5` ~line 2604), in the `isNewBar` block, **after** `UpdateMarketState()` (ledger advanced) and **after** baseline entry logic (baseline slot counts current), byte-identical to today when off:
```
if(InpEnableShortSleeve && InpEnableCONT && g_contEntry != NULL)   // both default OFF
{
   g_contEntry.SetLastLossBar(g_posCoordinator.GetContLastLossBar());   // §10 cooldown anchor
   EntrySignal contSig = g_contEntry.CheckForEntrySignal();             // closed-bar; ≤1 signal
   if(contSig.valid)
   {
      SPosition contPos = g_tradeOrchestrator.ExecuteSleeveSignal(contSig, "CONT");
      if(contPos.ticket > 0)
         g_contEntry.NotifyEntryFilled(iTime(_Symbol, PERIOD_H1, 1));   // §10 stamp
   }
}
```
CONT emits **at most one signal per bar** (single candidate; no cascade). Identity when off is guaranteed: `InpEnableShortSleeve` and `InpEnableCONT` both default OFF, `g_contEntry` stays NULL, and no baseline count/exposure site sees a sleeve position (SB-0.1 audit).

---

## 13. Arm→trigger state machine (states, latch fields, invalidation)

**States:** `IDLE` → `ARMED` → (fill → `IDLE` via `NotifyEntryFilled`) or (invalidation → `IDLE`).

**Latch fields (runtime-only, recomputable, NOT persisted; every member dead when the engine is not instantiated):**
- `m_armed` — a continuation setup is latched.
- `m_arm_bar_time` — `iTime(H1,1)` at ARM (the `M_ARM` window origin).
- `m_impulse_low` (`IL`) — the trigger level (break below = fire) **and** the dedup anchor.
- `m_lower_high` (`LH1`) — the stop anchor (§7) **and** the upside-invalidation level (§6).
- `m_pre_impulse_high` (`SH0`) — for the retrace fraction + telemetry.
- `m_arm_ema21` / `m_arm_ema50` / `m_arm_broken` (+ `m_arm_broken_level`) — which zone arm(s) fired at ARM (§14 scoring).
- Pending stamp `m_pending_impulse_low` / `m_pending_impulse_time`, committed by `NotifyEntryFilled` only on a real fill.

**Phase 1 — `TryArm` (when NOT armed):** §1 (HTF) + §2 (impulse LL) + §3/§4 (retrace zone + valid lower high) on `[1]` → latch `ARMED`, stamp the fields, print, **no trade**.

**Phase 2 — `TryTrigger` (when ARMED):** enforce the window/invalidations first — locate the arm bar in the series; `barsSince > CONT_M_ARM` → clear; a closed bar since ARM with `close > LH1` → clear (upside invalidation); `severity < 2` handled by the caller → clear. Then on `[1]`: §5 primary BOS (`close[1] < IL`) → §7 stop/entry → §5 room ≥1.5R → §6 squeeze veto → §10 dedup/cooldown → build + emit the SELL; stage the dedup stamp (committed on fill). Any partial miss → stay `ARMED`.

This is the **exact CCrevEntry two-phase shape** (`m_armed`/`TryArm`/`TryTrigger`/`NotifyEntryFilled`), with the CREV *fade at the anchor* replaced by the CONT *break below IL*, and the CREV `maxHighSince > anchor` early-invalidation replaced by the CONT `close > LH1` upside invalidation.

---

## 14. Quality-scoring criteria (0–10; maps to `ENUM_SETUP_QUALITY`)

Score is **telemetry + a future dose dial**; v1 dose is **severity-driven (§9), not score-driven**. A fully-valid setup scores ≥3 = `SETUP_B` (`CONT_QUAL_MIN_FIRE`).

| Points | Earned when | Band it pushes toward |
|---:|---|---|
| +3 | Base: HTF gate + impulse-LL + retrace-zone + valid lower high + BOS trigger + room + not-over-extended all pass | `SETUP_B` (3) |
| +2 | `severity == 4` (BEAR_TREND, D1-confirmed) [+1 if sev 3; +0 if sev 2] — continuation strongest in confirmed trend | → `SETUP_B_PLUS`/`SETUP_A` |
| +2 | Room RR ≥ 2.0 (vs the 1.5 floor) | → `SETUP_A` |
| +1 | Trigger bar is a bearish **displacement** (§5 overlay) | |
| +1 | Retrace tagged **EMA50** (deeper mean) rather than only EMA21/fib | |
| +1 | Broken-support retest **coincided** with the EMA zone (level+mean confluence) | → `SETUP_A_PLUS` |

Cap at 10. Map by repo bands (`SETUP_A_PLUS` 8–10, `SETUP_A` 6–7, `SETUP_B_PLUS` 4–5, `SETUP_B` 3, else `SETUP_NONE`). **Confluence honesty:** the lower high is scored **once** (the +3 base) — it is the same object as SB-1.1 F14 and the SMC/ICT lower high; H4 momentum is counted once in the severity gate, not re-added.

---

## 15. Plugin + sleeve + exit-branch mapping

**Plugin.** New `class CContinuationEntry : public CEntryStrategy` in `Include/EntryPlugins/CContinuationEntry.mqh` (C-prefix + role suffix; internal name `"CONT"`), mirroring `CCrevEntry`:
- **Handles (`Initialize`):** `iMA(H1,21,EMA,CLOSE)`, `iMA(H1,50,EMA,CLOSE)`, `iATR(H1,14)` (shared, refcounted). `CopyHigh/Low(PERIOD_H1)` and `CopyHigh/Low(PERIOD_H4)` for the fractal scans. **No D1 handle** (state from ledger). **No H4 EMA handle** (momentum encoded by severity, §1.1).
- **Context:** holds `IMarketContext*` for `GetBearState()`; `SetContext` as in the reference plugins. `RequiresConfirmation() → false` (the BOS trigger IS the confirmation, owner rule).
- **`CheckForEntrySignal()`** returns an `EntrySignal` with `valid`, `symbol=_Symbol`, `action="SELL"`, `source=SIGNAL_SOURCE_PATTERN`, `entryPrice=BID`, `stopLoss=SL` (§7); **`takeProfit1 = TP2_price` (FAR, = broker TP so the `ExecuteSignal` RR/reward-room gate passes at ≥1.5R)**, `takeProfit2 = TP1_price` (NEAR, carried for the coordinator branch), `takeProfit3 = 0` — **the exact CREV field convention** (`ManageCrevPosition` reads NEAR = `pos.tp2`, FAR = `pos.tp1`). `riskPercent =` §9 dose; `patternType = PATTERN_CONT_SHORT` (new enum); `qualityScore`/`setupQuality` = §14; `comment="CONT Continuation-Short"`; `plugin_name="CONT"`.

**New enum.** `PATTERN_CONT_SHORT` appended at the **END** of `ENUM_PATTERN_TYPE` in `Include/Common/Enums.mqh` (after `PATTERN_CREV_FADE`, so no existing ordinal shifts — `PersistedPosition.pattern_type` serializes as int). **Do not reuse** `PATTERN_CRASH_BREAKOUT` or `PATTERN_CREV_FADE` (would misfire their scoped branches).

**Sleeve routing.** `ExecuteSleeveSignal(signal, "CONT")` already enforces: master switch, SELL-only, sleeve max-positions (`InpSleeveMaxPositions=1`), slot reserve (`InpSleeveSlotReserve=2`), per-family + total risk caps, sleeve DD/daily halts, account backstops. `"CONT"` is a distinct family from `"CREV"` (family risk cap applies per family). CONT supplies only the signal + family + dose. **No CONT-specific risk/halt logic.**

**Exit ownership — CONT-pattern-scoped coordinator branch (mirror `ManageCrevPosition`).**
1. In the management loop (`CPositionCoordinator` ~line 2051, beside the CREV branch): `if(m_positions[i].is_sleeve && m_positions[i].pattern_type == PATTERN_CONT_SHORT) { ManageContPosition(i); continue; }` — bypasses the regime exit-profile stamp entirely.
2. `ManageContPosition(i)` = a near-copy of `ManageCrevPosition(i)` with CONT labels (`CONT_TP1`/`CONT_TP2`/`CONT_LH_TRAIL`/`CONT_MAXHOLD`): MAE/MFE, 48h max-hold, 50% at NEAR (`pos.tp2`), 30% at FAR (`pos.tp1`, broker TP cleared at TP1), LH structure trail via `FindTwoRecentPivotHighs` (down-only). *(Optionally factor a shared `ManageSleeveShortPosition(i, family)` since CONT and CREV are byte-identical in exit shape; mirroring keeps telemetry labels distinct and the one-change-per-binary boundary clean — implementer's call.)*
3. Extend the `ApplyTrailingPlugins` permanent chandelier-suppression guard to `pattern_type == PATTERN_CONT_SHORT`.
4. Extend the post-loss cooldown stamp (~line 3084) to `sleeve_family == "CONT"` (add `m_cont_last_loss_bar` + `GetContLastLossBar()`, mirroring the CREV members).

**Inputs to add** (default OFF/neutral so identity holds): `InpEnableCONT=false` (plugin master; needs `InpEnableShortSleeve` too). FIT-run values: `InpEnableShortSleeve=true`, `InpEnableCONT=true`, `InpSleeveRiskPct=0.35`, `InpBearStateSource=LEDGER`. All §11 constants are **compile-time frozen `#define`s inside the plugin**, not tunable inputs.

With `InpEnableShortSleeve=false` (default) no CONT position exists → every branch is dead and identity to the cent is preserved (the SB-0.1 guarantee, verified exact across 4 CREV runs).

---

## 16. Fill-count sanity estimate

**Why CONT should NOT starve like CREV.** CREV fired 3 (v1) / 4 (v2) times in 7.5y because it required a bearish **rejection candle to close back below the mean** inside a narrow window — a rare co-occurrence at a specific price. CONT's trigger is a **close below a stamped structural low (`IL`)** — a *frequent, decisive event* once armed, and the arm itself (a confirmed lower high after an impulse LL) is common in every grinding bear leg.

**Opportunity base (SB-1.1 / market-structure):** 10,908 severity≥2 H1 bars (24.5% of all; 1,560 in 2026). Bear legs with real continuation structure: E2a/E2b (2020H2–2021Q1 distribution), E4 (2022 grind, the richest), E5 (2023 grind), E8 (2026H1 crash-with-rips), plus fragments (E3, E6). The market-structure doc counts **failed-high sweep structures per episode** (E2a 14, E4 14, E5 15, E8 16 ≈ **59** across the four majors, "roughly one per week") — the raw material for structural shorts. On H1, impulse→lower-high→breakdown structures are at least as frequent as those daily sweeps.

**Estimate (arithmetic, honest).** Take ~59 daily-scale structures across the four majors as the anchor, add ~15–25% for intraday H1 structures the daily count misses, then apply the funnel: retrace-zone qualify (~70%), IL-break within `M_ARM=12` (~75%), room ≥1.5R (~65%), over-extension veto (~85% pass), dedup/same-impulse/6-bar spacing (~70% survive). Composite ≈ 0.70·0.75·0.65·0.85·0.70 ≈ **0.20** → **~14–18 in-episode from the four majors alone**, plus the fragments and the deeper 2026H1 (severity≥2 rich). **Central estimate ≈ 30–60 fills over 2019–2026, concentrated ~two-thirds in E4/E5/E8.** That comfortably clears the registered **≥20–30 production bar** and the ~15 coverage floor — the structural advantage over CREV.

**If it would plausibly yield < 15** (starvation risk): the tightest gates are (a) the retrace-zone conjunction and (b) room ≥1.5R. **Adjust the STRUCTURE, not the thresholds post-hoc:** widen `CONT_M_ARM` (12→18/24 — give the break more time) or `CONT_MAX_RETR` (0.886→0.95 — accept deeper pullbacks that stay lower highs) — both are structural, not sensitivity loosening. Do **not** drop `CONT_MINRR` below 1.5 (that chases an R the tape rarely pays — economics §2.3). Any such change is an a-priori re-registration before the run, never a post-result tune.

---

## 17. What would falsify this design

CONT is registered **killed no-change on any FIT-gate failure** (AB_TEST_LOG SB-2.1). On the pre-registered **FIT 2019–2022 / CONFIRM 2023–2026H1** split (LEDGER state, `InpEnableShortSleeve=true`, `InpEnableCONT=true`, `InpSleeveRiskPct=0.35`):

1. **Identity breach:** the 952 baseline positions are not bit-identical (`baseline-23856-2026-07-11`) — a **bug**, not a judgment call (the sleeve slot-reserve guarantees it; verified exact 4×).
2. **FIT:** incremental avg R < 0, or book EqDD worsens by > +0.30pp, or any calendar year worse by > $500, or a **bull-pullback loss cluster dominates** the P&L, or sleeve DD breaches `InpSleeveMaxDDPct`.
3. **CONFIRM:** direct CONT contribution not positive, not positive in > 1 distinct bearish leg, a single year is a majority of incremental profit, DD gate breach, or ex-2025 worse.
4. **Structural falsifiers specific to this design:**
   - **The #1 risk — reclaim.** CONTINUATION is **untested on this tape**; its nearest tested cousin, breakdown-**retest**, is **dead (PF 0.57)** because gold reclaims broken levels **51 of 53** times (market-structure §1.2). If that structural reclaim tendency also swallows the IL-break (price closes below `IL`, then V-reverses through `LH1` before TP1) → CONT is a bear trap and FIT avg R goes negative → **CLOSE**. CONT's *design defense* is that it (a) waits for a **confirmed lower high** (not the first dip), (b) sells the **break of prior structure with momentum** (not a fade into strength), and (c) stops above the lower high — but this is a **hypothesis, not a measured edge**. State it plainly: the honest prior on "does trend-continuation-short work on secular-bull gold H1" is **skeptical**, and the FIT is the test.
   - If fills concentrate in `ACTIVE_CORRECTION`/`BEAR_RALLY` (the squeeze-prone legs) and lose there while `BEAR_TREND`/`BEAR_TRANSITION` are empty → the state gate is catching the wrong leg; revisit gating on confirmed-trend only.
   - If the `CONT_MAXHOLD` (48h) exits systematically bank negative R → the time-box is wrong; 24h/72h are the registered revisit.
   - If < ~15 fills → underpowered like CREV; §16 structural adjustment (a-priori re-registration), not a threshold tune.

**Power honesty (registered):** expected CONT fills ~30–60; if realized nearer 20–30, cohort ΔR SE is still meaningful but the **binding** gates are net-$/DD/scope/participation, cohort-R a sanity floor. Do not adopt on a net-$ print inside the ±$1,500 noise floor. Zero direct contribution is a **live, acceptable** outcome *only if the DD/identity gates hold and the trades did not bleed* — but note the SB-2.1 mandate is "primary professional short," so unlike CREV (whose purchase was pure DD-coverage), a merely-zero CONT that also fails to participate in E4/E5/E8 is a coverage failure, not a pass.

---

## 18. Judgment calls the owner may want to revisit (raw)

1. **Trigger = close below the impulse low `IL` (the resumption BOS), NOT a nearer minor-low break — the biggest call.** This makes CONT a *true continuation* (wait for the new lower low, sell weakness) rather than a disguised fade of the lower high. A nearer trigger (break of a micro-swing low just under `LH1`) would give earlier/more entries and a tighter R, but it drifts back toward CREV's *sell-into-strength* squeeze problem. I chose the BOS-below-IL because it is the only trigger that structurally distinguishes CONT from the closed CREV fade. If FIT shows late/few entries, the nearer-low variant is the registered A/B — but it is a *different* (more fade-like) strategy and should be re-registered, not silently swapped.
2. **Over-extension veto `CONT_P_OVEREXT=3.0`.** A continuation engine is *meant* to ride down-legs, so a 3×ATR-below-EMA50 veto may reject exactly the E8 waterfall continuations the strategy exists to catch. I carried CREV's 3.0 as a squeeze guard; the honest A/B is looser (4.0) or off. Flagged; not tuned pre-evidence.
3. **`CONT_M_ARM=12` (vs CREV's 6).** The a-priori anti-starvation choice (continuation resolves slower than a fade). 6/18/24 are the neighbours; if fills starve, widen the *window* (structure), don't loosen thresholds.
4. **Dose ordering monotone-increasing (full at BEAR_TREND).** Same band as CREV; **more** justified for continuation (strongest in confirmed trend) but still ignores the measured +0.403R `BEAR_TRANSITION` inversion — recorded, not acted on. If the owner wants to act on the measured cell, that is a registered post-evidence proposal.
5. **H4 momentum = severity≥2 (no separate H4-EMA gate).** Avoids a redundant handle and double-counting. If the owner wants an *independent* H4 EMA21<EMA50 confirmation (belt-and-suspenders), it is a one-line add — but it would be confluence the severity gate already contains, so I left it out.
6. **Failed-reclaim secondary trigger left INACTIVE in v1.** It is the nearest cousin of the killed breakdown-retest; activating it risks reintroducing the reclaim trap. Flagged; the displacement overlay (a quality grade on the IL break, never standalone) is the only "candle" influence in v1, honoring the owner rule.
7. **`CONT_MAX_RETR=0.886`, `CONT_X_IMP=1.5`, `CONT_MINRR=1.5`.** Structural thresholds. If fills starve, widen `MAX_RETR`/`M_ARM` (structure); never drop `MINRR` (chases an R the tape does not pay). Any change = a-priori re-registration.
