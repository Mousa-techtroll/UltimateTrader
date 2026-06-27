# OPT-SHOCK — Binding DESIGN spec (shock-detector [0]→[1] fix + EXTREME-arm disposition + A/B accept criterion)

**Author:** stok (trading-analyst, binding design ruling).
**Status:** BINDING SPEC. NO implementation here — mt5 executes the source edits, compiles, runs the A/B, and reports against the pre-committed criterion below. stok rules on the result.
**In-tree:** `/mnt/c/Trading/UltimateTrader`. **This is a SOURCE change → own compile + own binary** (not a config sweep like OPT-2/3).
**Inputs cross-read against current HEAD.** Root cause: `OPT-SHOCK-rootcause.md` (confirmed by direct read — both defects verified: forming-`[0]` numerator + closed-H4-ATR denominator).

---

## 0. Baseline (§0 — C0, do NOT re-spend a run on C0-FULL)

**Binding real-tick baseline (OPT-1 ADOPT, on file, regression-confirmed to the cent):**
Net **$20,069.23** / PF **1.29** / Sharpe **2.14** / Eq-DD **13.97%** / Bal-DD **11.92%** / avg-R **0.169** / **928 pos** — XAUUSD+ H1, full 2019–2026-H1, real-tick (Model=4).

**C0 for THIS study = the CURRENTLY-SHIPPED shock detector = "spread-only."** Because the bar-range and M5 legs read forming-`[0]` bars at the new-bar instant they are provably 0.00 on every firing (root-cause §2, cross-model-confirmed §3). So today's shock gate is functionally a single-leg spread gate, and its FULL number is *exactly* the $20,069.23 baseline above. **C0-FULL is therefore on file; do not spend a run on it** (same discipline as OPT-2 §0/§5). C0 must still be run on the FIT slice (2019–2022) as the same-slice comparator and as a binary-provenance sanity check (must reproduce the OPT-2/3 C0-FIT shape — see §6).

---

## 1. THE CORRECTNESS FIX — CONFIRMED + PAIRED ATR-DENOM DECISION

### 1a. The `[0]→[1]` numerator fix — CONFIRMED as the correct correctness repair

The two legs are meant to ask "is the *recent* bar's range abnormally large vs ATR (a fresh volatility spike)?" The only caller fires at the new-H1-bar instant (`if(isNewBar)`, mq5:1454→1759), when the `[0]` bar's first tick has `high==low==open` → range≡0. The meaningful, no-look-ahead reading is the **just-closed bar `[1]`**. This is the dominant repair and it is in-family with the closed-`[1]` idiom used throughout the repo. **CONFIRMED.**

**Guardrail check (no look-ahead):** index `[1]` is strictly *less forward* than `[0]`; `iHigh/iLow` are absolute-indexed timeseries reads (no `ArraySetAsSeries` involved), and at the new-bar firing the `[1]` bar is fully closed. PASS.

### 1b. The ATR-denominator fix — PAIR IT (decision: YES, fix H4→H1, with a units-matched M5 leg)

**Decision: PAIR the ATR-denominator fix with the `[1]` fix. Do NOT ship the `[1]` fix alone against the H4 denominator.**

**Why pair it (not defer):** The root-cause doc offered "leave H4 ATR (conservative)" as option (a). I reject leaving it, for a specific reason: a degenerate denominator does not make the gate "conservatively safe" — it makes the gate's *firing distribution* uninterpretable, which is exactly the OPT-3 failure mode (a gate that looks live but fires on the wrong quantity / never on the intended one). An **H1 bar range over an H4 ATR(14)** is dimensionally mismatched: H4 ATR ≈ (roughly) 2× an H1 ATR in trending gold, so `bar_range_ratio` reads ~half of what the `>2.0/>3.0` thresholds were notionally drawn against, and the M5-over-H4 ratio is mismatched by an even larger factor. The thresholds become meaningless. If we are doing the correctness repair at all, we do it so the ratios are *dimensionally sane and interpretable*, then we re-derive (see 1c). Half-fixing it (right index, wrong-TF denominator) ships a second known-miscalibrated gate — not acceptable for a "safety/correctness" item.

**What the denominator should be:**
- **bar_range leg:** H1 bar range / **H1 ATR(14)**. Numerator and denominator both H1, both closed-bar.
- **M5 leg:** the M5 range should compare against an **M5-scaled ATR**, NOT an H1 ATR. Comparing an M5 range to an H1 ATR is the same dimensional sin. Cleanest in-repo option that needs no new persistent handle: compute the H1 ATR(14) and divide by 12 (12 M5 bars per H1) to get an M5-equivalent ATR, OR read a true M5 ATR. **Ruling: use a true M5 ATR(14)** for the M5 leg — it is the honest comparand and avoids assuming a flat intrabar volatility distribution. (If mt5 finds adding an M5 ATR handle costly, the `H1_ATR/12` proxy is the acceptable fallback — state which was used.)

**How to source the H1 ATR without corrupting shared handles:** the repo already has the idiom — `CMarketContext::GetATRVelocity` (CMarketContext.mqh:643-663) computes an H1 TR series directly from `iHigh/iLow/iClose(PERIOD_H1, i+1)` with a comment explaining *why* it avoids `iATR` handle create/release (shared handles are reference-counted; releasing corrupts other components). **DetectShock must use the same handle-free closed-bar TR-average idiom**, not create/release its own `iATR` handle. Two clean implementation options for mt5 (mt5 picks; both acceptable):
  - **(i) Add a private helper** `double GetClosedATR(ENUM_TIMEFRAMES tf, int period=14)` on `CEnhancedTradeExecutor` that averages closed-bar TR (`iHigh/iLow(tf,i)` for `i=1..period`, `iClose(tf,i+1)` as prev-close) — mirroring the GetATRVelocity idiom — and call it for both PERIOD_H1 and PERIOD_M5.
  - **(ii)** Pass an H1 ATR into DetectShock from the call site and compute the M5 ATR inside. Less clean (caller currently passes the H4 regime ATR); helper (i) is preferred because it keeps the fix localized to the executor and removes the mislabeled `atr_h1` param's dependence on the H4 regime value.

### 1c. THRESHOLD DISPOSITION — the 3.0/2.0/0.8/0.5 numbers are UNVALIDATED → re-derive is NOT free, so handle them thus

The four thresholds (`shock_bar_thresh`=2.0 with the ×1.5 EXTREME multiplier → bar 2.0/3.0; M5 0.5/0.8) were set against a **degenerate 0.00 signal AND an H4 denominator**. They are effectively unvalidated. But re-deriving them properly (a threshold sweep) is a *separate optimization study* and would blow the run budget. **Ruling:** do NOT sweep thresholds in this study. Instead, **hold the threshold semantics fixed and let the units-fix re-anchor them**, because once the denominator is a same/short-TF ATR the existing numbers acquire a sane, conventional meaning:
- bar_range MODERATE at `>2.0× H1 ATR` and EXTREME at `>3.0× H1 ATR` are *reasonable* volatility-spike bands for a closed H1 bar vs its own ATR (a bar 3× its ATR is a genuine outlier). These are defensible defaults, not arbitrary.
- M5 MODERATE `>0.5` / EXTREME `>0.8` of an **M5 ATR** is too *loose* (an M5 bar at 0.8× its own M5 ATR is utterly normal — that would fire constantly). The original 0.5/0.8 were drawn for **M5-range-over-H1-ATR** (where an M5 bar reaching 0.5× a full H1 ATR *is* a fast spike). **So the M5 leg's comparand choice and its thresholds are coupled:** to keep the 0.5/0.8 numbers meaningful, the M5 leg should keep comparing **M5 range to the H1 ATR** (an M5 bar that is 0.5–0.8× of a *whole H1 ATR* is a real fast move). 

**Revised 1b ruling, reconciled with 1c:** keep the M5 leg as **M5 range / H1 ATR** (NOT M5/M5-ATR) — this preserves the 0.5/0.8 thresholds' intended "fast intrabar spike relative to the hourly move" meaning and needs no M5 ATR handle at all. Only the **bar_range leg's denominator** changes (H4 ATR → H1 ATR). So the net denominator change is: **both legs divide by H1 ATR instead of H4 ATR.** The bar leg becomes dimensionally clean (H1/H1); the M5 leg stays an intentional cross-TF "fraction of the hourly range" ratio (M5/H1), which is what its 0.5/0.8 thresholds were authored for. This is the minimal, threshold-preserving denominator fix. **The 3.0/2.0/0.8/0.5 numbers stay as-is**; they are validated *by the A/B firing distribution* (§4 instrumentation) and the accept criterion, not by a separate sweep. If the §4 firing counts show a leg firing absurdly often/never, that is a follow-up threshold study, flagged — not fixed here.

### 1d. EXACT SOURCE EDITS (binding — mt5 implements verbatim semantics)

File: `Include/Execution/CEnhancedTradeExecutor.mqh`, function `DetectShock` (currently 2081-2145).

1. **Replace the H4-regime ATR denominator with a closed H1 ATR computed inside the function.** The incoming `atr_h1` param is mislabeled (it is the H4 regime ATR). Do NOT keep dividing by it. Add/compute a closed H1 ATR(14) via the handle-free idiom (helper option (i) above preferred). Keep the `if(atr_h1 <= 0) return state;` early-out OR replace with `if(h1_atr <= 0) return state;` — guard on whatever denominator is actually used.

2. **Line 2089:** `iHigh(_Symbol, PERIOD_H1, 0)` → `iHigh(_Symbol, PERIOD_H1, 1)`
3. **Line 2090:** `iLow (_Symbol, PERIOD_H1, 0)` → `iLow (_Symbol, PERIOD_H1, 1)`
4. **Line 2092:** `state.bar_range_ratio = bar_range / atr_h1;` → divide by the **H1 ATR** (`bar_range / h1_atr`).
5. **Line 2110:** `iHigh(_Symbol, PERIOD_M5, 0)` → `iHigh(_Symbol, PERIOD_M5, 1)`
6. **Line 2111:** `iLow (_Symbol, PERIOD_M5, 0)` → `iLow (_Symbol, PERIOD_M5, 1)`
7. **Line 2113:** `state.m5_range_ratio = m5_range / atr_h1;` → divide by the **H1 ATR** (`m5_range / h1_atr`) — same H1 ATR as the bar leg (intentional M5/H1 cross-TF ratio, see 1c).

**Do NOT touch:** the spread leg (lines 2094-2107) — guardrail. The `is_better`/floor combine mechanics at mq5:1912-1914. The `EntrySignal`/`SPosition` fields. The classify thresholds 2116-2131 (held fixed per 1c).

**Guardrails restated:** [1] closed-bar only (no forward reach); spread leg untouched; floor (`InpMinSessionRiskFactor=0.25`) and the `shock_factor*sq_factor` combine preserved.

---

## 2. THE EXTREME-ARM RULING — DEMOTE EXTREME TO A DOWN-SIZE (B is the default-favored arm) — but TEST BOTH

**RULING (load-bearing): The EXTREME *range/M5* legs should NOT hard-block on a long-biased gold continuation book. Demote the range-driven EXTREME tier to a (hard) down-size. The SPREAD leg KEEPS its hard block.**

This is a split disposition, and the split is the whole point:

### 2a. Why the range legs must not hard-block (the OPT-3 lesson applied)
The bar-range and M5-range legs are **direction-blind** — they key on |range|, not sign. On a structurally long-biased gold strategy, the highest-range H1 bars are disproportionately **strong up-continuation legs** (gold's best moves are its widest bars). A range-only EXTREME hard-block cannot tell a flash-crash down-spike (worth standing aside) from a powerful breakout up-bar (worth riding) — it would **amputate the best continuation entries** the same way OPT-3 warned a one-sided book-shrinker fights the long bias. A hard block on a direction-blind range signal is therefore the wrong posture for THIS book. The correct posture is **"down-size hard on extreme range, never fully block on range alone."**

### 2b. Why the SPREAD leg KEEPS its hard block
The spread leg is *categorically different*: a spread spike (`spread_ratio > 3.0`) is a **direct illiquidity / dislocation signal** — wide spread means bad fills, slippage, and stop-run risk *regardless of direction*. Standing aside in a genuine spread blow-out (news prints, rollover, thin-Asia dislocation) is defensible and not a directional bet. The spread leg *can* signal real illiquidity, so it earns its hard block. **Keep `spread_ratio > 3.0` → EXTREME → hard block.**

### 2c. Mechanical expression of the ruling (arm B)
In the EXTREME classify branch (2116-2123), separate the spread condition from the range/M5 conditions:
- **Spread EXTREME** (`spread_ratio > 3.0`) → `is_extreme = true` → hard block (existing path, mq5:1760-1764). UNCHANGED.
- **Range/M5 EXTREME** (`bar_range_ratio > 3.0` OR `m5_range_ratio > 0.8`) → **do NOT set `is_extreme`**; instead route to the MODERATE down-size arm at full intensity (`is_shock=true`, `shock_intensity=1.0` → `shock_factor = 1 - 1.0*0.5 = 0.5`, i.e. halve risk, floored by `InpMinSessionRiskFactor=0.25` combined). This is the *hardest* down-size the arm allows — a 50% risk cut on an extreme-range bar — without ever zeroing the entry.

This is implemented at the classify block, not the consumer; the consumer (mq5:1760-1775) already does the right thing once `is_extreme` is reserved for the spread case.

### 2d. But we still TEST the hard-block (arm A) — don't pre-judge with conviction we don't have
The sign is genuinely uncertain and stok does not manufacture confidence. The ruling above is a *prior*, not a verdict. So the A/B tests both dispositions and the data decides:
- **Arm A** = fix (1d) + **EXTREME stays a full hard block** (range/M5/spread all block) — the literal "activate the legs as-authored" config.
- **Arm B** = fix (1d) + **EXTREME demoted for range/M5, spread keeps hard block** (the 2c ruling) — stok's favored prior.
- **C0** = spread-only (shipped/baseline).

If arm A's hard block measurably amputates continuation net with no DD payback, the data confirms the prior and we adopt B (or revert). If arm A *improves* risk-adjusted metrics, the prior is wrong and we follow the data. Either way the EXTREME-arm question is answered empirically, not by assertion.

---

## 3. CANDIDATE ARMS

| Arm | Config | Binary |
|---|---|---|
| **C0** | Spread-only (shipped). Legs degenerate-0.00. = current source. | existing baseline binary; FULL on file ($20,069.23) |
| **A** | Fix (1d: `[1]` + H1-ATR denom). EXTREME = full hard block (range OR M5 OR spread). | new binary `UltimateTrader_OPTSHOCK_A.ex5` |
| **B** | Fix (1d) + EXTREME demoted to 50% down-size for range/M5; spread keeps hard block (2c). | new binary `UltimateTrader_OPTSHOCK_B.ex5` |

All arms are SOURCE-distinct (A/B differ only in the classify branch). Each gets its own compile + md5; verify `load==fresh` and that A's binary differs from B's and from C0.

---

## 4. ACCEPT / KILL CRITERION (pre-committed, OOS-split, OPT-2/3 discipline)

**Framing:** this fix ADDS blocking/down-sizing → it will almost certainly REDUCE net and trade count vs C0. That is expected and is NOT a kill by itself. This is a **safety/correctness** fix: the bar is **risk-adjusted improvement at an acceptable net cost**, OR correctness-alone at flat-to-slightly-lower net. Deltas are measured **vs C0 on the same slice**, **one tolerance set** applied at FIT / CONFIRM / FULL.

### Slices (match OPT-2/3 exactly)
- **FIT:** 2019.01.01 → 2022.12.31 (selection).
- **CONFIRM:** 2023.01.01 → 2026.06.27 (out-of-sample).
- **FULL:** 2019.01.01 → 2026.06.27 (winner vs §0 baseline). C0-FULL = $20,069.23, on file — not re-spent.

### Tolerance set (one set, all slices; deltas vs C0-same-slice)
A candidate arm is a **PASS** on a slice iff it satisfies the **safety bar** OR the **correctness-floor bar**:

- **SAFETY bar (the win condition):** delivers a *risk-adjusted* improvement —
  - **Eq-DD reduced by ≥ 0.75pp** (e.g. FULL 13.97% → ≤ 13.22%), **OR** **Sharpe up ≥ +0.10** (FULL 2.14 → ≥ 2.24);
  - AND net is not gutted: **net ≥ 92% of C0-same-slice** (≤ 8% net give-back tolerated for the DD/Sharpe gain);
  - AND no quality collapse: **PF ≥ C0-PF − 0.03** and **avg-R ≥ C0-avgR − 0.010**.
- **CORRECTNESS-FLOOR bar (adopt-even-if-flat):** because the fix is a genuine correctness repair (the legs are provably dead today), stok will adopt it **even with no DD/Sharpe win** provided it is **net-neutral-to-trivially-negative and risk-neutral**: **net ≥ 98% of C0-same-slice**, **Eq-DD not worse by >0.30pp**, **PF ≥ C0-PF − 0.02**, **avg-R ≥ C0-avgR − 0.005**. Rationale stated explicitly: shipping a 1-of-3 working safety (correct, interpretable legs) is worth a ≤2% net rounding cost when risk is flat — a degenerate gate is a latent liability the next person will trip over.

A candidate must pass on **FIT** to advance to CONFIRM, and pass on **CONFIRM** (OOS) to be eligible for FULL adoption. **FULL is the adoption readout**, judged on the same tolerance set vs the on-file C0-FULL.

### KILL conditions (pre-committed)
- **Arm A KILL (the amputation guard):** if A's net give-back vs C0 is **> 8%** on FIT **AND** A does **not** cut Eq-DD by ≥0.75pp (i.e. it shrinks the book without buying risk reduction) → **A is the OPT-3 one-sided book-shrinker; KILL A** and proceed with B only. Additionally, instrument it: if the §5 firing data shows EXTREME hard-blocks landing predominantly on **subsequently-profitable up-continuation bars** (the amputation signature), that corroborates the KILL regardless of the aggregate.
- **Whole-study KILL:** if **both** A and B fail FIT (neither meets SAFETY nor CORRECTNESS-FLOOR — i.e. the fix costs >2% net with no risk payback even in B) → **KILL the activation; keep the legs corrected in SOURCE but ship with `InpEnableShockDetection` semantics unchanged OR revert to C0** and document that on gold H1 the range/M5 shock legs have no edge (an honest "tested, no edge here" finding, like FVG-Mitigation / Silver Bullet). The `[1]`+H1-ATR source correction may still be committed as a latent-correctness fix even if the gate stays effectively off — stok decides at ruling time.
- **Early-KILL discipline:** if an arm fails FIT, do NOT spend its CONFIRM/FULL runs (OPT-2 §5). Report which arm advanced.

### Adoption preference (if both A and B pass FIT+CONFIRM)
Prefer **B** (stok's prior: range hard-block is the wrong posture for this book) unless **A** beats B on the SAFETY bar by a clear margin (A's Eq-DD ≥0.5pp lower than B's at comparable net) — i.e. only adopt the harder block if the data shows it actively buys risk reduction the down-size can't. Tie/ambiguous → B (the gentler, direction-aware-by-omission arm).

---

## 5. INSTRUMENTATION (mandatory — the OPT-3 "confirm the legs now actually fire" lesson)

The existing `Print("[ShockDetector] …")` at 2137-2141 already emits per-firing leg ratios + tier. That is sufficient raw data; mt5 must **aggregate it from the journal** per arm/slice into:

1. **Firing counts split by leg AND tier**, per arm, per slice:
   - bar-range MODERATE fires / bar-range EXTREME fires
   - M5 MODERATE fires / M5 EXTREME fires
   - spread MODERATE fires / spread EXTREME fires
   - (a single firing can trip multiple legs — count per-leg crossings, and also count distinct shock bars by tier).
2. **EXTREME hard-block landings (arm A only, the amputation probe):** for each bar where A hard-blocked, classify the *next* H1 bar's direction/return — count how many blocked bars were followed by a profitable **up-continuation** that A thereby skipped. This is the direct test of the amputation hypothesis. (Cheapest implementation: a one-line `Print("[ShockBlockProbe] blocked@", time, " nextH1ret=", …)` in the consumer's `is_extreme` branch at mq5:1762, then grep+aggregate. Add only behind the existing block path; do not alter sizing.)
3. **Sanity assertion:** confirm bar_range_ratio and m5_range_ratio are now **non-zero** on firings (root cause was 0.00). If they are still ~0.00, the fix did not take — STOP and report (binary-provenance failure).

Report all three tables in `OPT-SHOCK-RESULT.md`.

---

## 6. RUN BUDGET (≤ 8 Model=4 / real-tick runs; clean-state)

**Environment:** Model=4 (real ticks — the helper scripts' `MODEL` arg; confirm the terminal's real-tick enum value, the script comment lists `3=Every tick real ticks` — use the real-tick value this terminal uses, matching OPT-1/2/3 provenance). XAUUSD+ H1. Clean state (no stray `[TesterInputs]` overrides; SOURCE defaults apply). Each arm = own compile + own binary + md5 + `load==fresh` check.

| # | Run | Slice | Purpose |
|---|---|---|---|
| 1 | **C0 FIT** | 2019–2022 | same-slice comparator + binary-provenance sanity (must reproduce OPT-2/3 C0-FIT shape: $2,453.21 / PF 1.12 / Eq-DD 18.31% / avg-R 0.0820 / 448 pos — proves OPT-1 trail defaults are compiled in) |
| 2 | **A FIT** | 2019–2022 | arm A selection + amputation probe |
| 3 | **B FIT** | 2019–2022 | arm B selection |
| 4 | **A CONFIRM** | 2023–2026H1 | OOS — only if A passes FIT |
| 5 | **B CONFIRM** | 2023–2026H1 | OOS — only if B passes FIT |
| 6 | **A FULL** | 2019–2026H1 | adoption readout — only if A passes FIT+CONFIRM |
| 7 | **B FULL** | 2019–2026H1 | adoption readout — only if B passes FIT+CONFIRM |

- **C0-FULL is NOT a run** (on file: $20,069.23). 
- **C0-CONFIRM** is only needed if FULL-vs-CONFIRM deltas require it; if the on-file FULL + FIT comparator suffice (as in OPT-2), skip it. Budget holds 1 spare (#8) for a C0-CONFIRM if a CONFIRM-slice C0 comparator is needed. **Max 7 spent, ≤8 budgeted.**
- **Early-KILL:** a FIT failure cancels that arm's CONFIRM+FULL (saves 2 runs/arm). If both fail FIT → spend only runs 1-3, KILL per §4.

---

## 7. GUARDRAILS (restated, binding)

1. **No look-ahead:** index `[1]` only (strictly less forward than `[0]`); closed-bar reads; no `ArraySetAsSeries` forward reach. The H1/M5 ATR helper must read closed bars (`i≥1`).
2. **Do not touch the spread leg** (lines 2094-2107) — logic and its hard block preserved (it earns the block per §2b).
3. **Preserve the `is_better` / floor combine mechanics:** `combined = shock_factor * sq_factor`, floored at `InpMinSessionRiskFactor=0.25` (mq5:1912-1914). The B-arm demotion routes through this exact path (down-size, not a new mechanism).
4. **No new shared `iATR` handle create/release** inside DetectShock — use the handle-free closed-bar TR idiom (CMarketContext.mqh:643-663 pattern) to avoid corrupting reference-counted shared handles.
5. **SOURCE change → own binary:** compile 0-err (current 16-warn baseline acceptable), record md5, verify A≠B≠C0 binaries and `load==fresh`.

---

## 8. SUMMARY (the ruling, in one screen)

- **FIX (lines/indices):** `CEnhancedTradeExecutor.mqh` DetectShock — `iHigh/iLow(PERIOD_H1, 0)`→`1` (2089/2090), `iHigh/iLow(PERIOD_M5, 0)`→`1` (2110/2111), and **both** ratios (2092/2113) divide by a **closed H1 ATR(14)** instead of the mislabeled H4 regime ATR. H1 ATR computed via the handle-free closed-bar TR idiom (no new shared handle). M5 leg stays **M5-range/H1-ATR** intentionally (preserves the 0.5/0.8 threshold meaning). Thresholds 3.0/2.0/0.8/0.5 held fixed (re-anchored by the units fix; validated by the A/B firing distribution, not a separate sweep).
- **ATR-denom decision:** PAIR it (H4→H1). A degenerate denominator makes the gate uninterpretable (OPT-3 failure mode), not "conservatively safe." Only the denominator TF changes; thresholds preserved.
- **EXTREME-arm decision:** **DEMOTE the range/M5 EXTREME to a hard 50% down-size; SPREAD keeps its hard block.** Direction-blind range legs must not hard-block a long-biased continuation book (would amputate the strongest up-legs — OPT-3 lesson); a spread spike is a direction-agnostic illiquidity signal and earns its block. This is stok's prior, **tested as arm B vs arm A (full hard block)** — data decides.
- **Candidate arms:** C0 (spread-only/baseline) · A (fix + EXTREME full hard block) · B (fix + EXTREME range/M5 demoted, spread blocks).
- **Accept criterion:** PASS on a slice = SAFETY bar (Eq-DD −≥0.75pp OR Sharpe +≥0.10; net ≥92% C0; PF ≥C0−0.03; avg-R ≥C0−0.010) **OR** CORRECTNESS-FLOOR bar (net ≥98% C0; Eq-DD not worse >0.30pp; PF ≥C0−0.02; avg-R ≥C0−0.005). Must pass FIT→CONFIRM→FULL. **KILL A** if net give-back >8% on FIT with no ≥0.75pp DD cut (amputation). **KILL study** if both A and B fail FIT (>2% net, no risk payback) → keep source corrected, ship gate effectively off, document "no edge on gold H1." Prefer **B** on adoption unless A buys ≥0.5pp more Eq-DD at comparable net.
- **Run count:** ≤8 budgeted, **7 max spent** (C0-FIT, A/B-FIT, A/B-CONFIRM, A/B-FULL; C0-FULL on file; early-KILL saves runs). Model=4 real-tick, clean-state, own binary per arm. Instrument firing counts by leg×tier per arm + arm-A amputation probe (blocked-bar → next-H1 up-continuation) + non-zero-ratio sanity assertion.
