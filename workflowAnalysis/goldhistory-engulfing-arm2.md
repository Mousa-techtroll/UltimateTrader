# Engulfing Arm 2 (stronger candle definition) — REJECTED

**Objective:** improve Engulfing's 44% cross-feed portability by keeping only structurally-obvious engulfing candles, without touching Arm-1's death-cross gate, confirmation, volume, grade, risk, exits, arbitration, or the H4 requirement. Control = the adopted Arm-1 baseline **$27,145.66 / 944** (real-tick).

## VERDICT — no candle-geometry lever improves portability; all tightening only cuts profit. KEEP the current detector.

The forensic proves the premise is false, and the arms confirm it empirically:
- **The primary metric does not move the right way.** Candidate shared-feed rate: **44.1% (control) → 43.4% (body-ratio 1.5×)** — slightly *worse*. Tightening removes ~19% of candidates but pulls them proportionally from shared *and* vendor-only classes, so portability is unchanged.
- **Every tightening step destroys profit.** Real-tick: 1.5× = −$2,289 (−8.4%); 2.0× = −$9,299 (−34%). At 2.0× the book keeps 94% of positions but only **66% of profit** — the tightening removes *disproportionately profitable* candidates. The moderate engulfs (ratio 1–2×) carry the edge; the "structurally obvious" ≥2× ones do not. This is the exact opposite of the ideal (remove more vendor-noise than shared profit).
- **No drawdown benefit** (EqDD 13.31% control → 13.43% @1.5× → 15.51% @2.0×).

## Forensic — why: no candle feature discriminates vendor-only from shared candidates
Bar alignment verified: `BarTime` = decision bar [0]; engulf candle = [1] (`BarTime−1h`), prev = [2] (`BarTime−2h`) — 100% satisfy the detector rule. **The current detector already requires a full ≥100% body wrap** (`open[1]≤close[2] && close[1]≥open[2]` forces signal body ≥ prev body); the `body_engulf_pct=0.8` param was redundant. In practice the engulf is *already very strong* — median body ratio **2.94×**. So "90/100/110%" are all below the median (no-ops); the only binding lever is a body ratio >1.0.

Geometry by feed class (2019-25, Arm-1-on population) — **identical across classes**, so tightening cannot preferentially remove vendor noise:

| Feature | Shared | Prod-only | GH-only |
|---|---|---|---|
| Body ratio (curr/prev), median | 2.78 | 3.12 | 3.04 |
| Body/ATR, median | 0.34 | 0.36 | 0.36 |
| Close location (0-1), median | 0.86 | 0.83 | 0.86 |
| Upper-wick/body, median | 0.22 | 0.26 | 0.22 |
| Fraction with ratio <1.5 (removed @1.5) | 20% | **18%** | 21% |
| Fraction with body/ATR <0.4 | 60% | **56%** | 58% |

At the marginal end the vendor-only classes are *no more* concentrated than shared — often *less*. The ~40% of candidates that are feed-specific have the **same geometry** as the portable ones; they differ only because the underlying vendor OHLC bars differ. **The 44% portability ceiling is structural (feed bar differences), not a weak-candle-definition problem a stricter detector could fix.**

## Arms (pre-registered)
Input added: `InpEngulfingBodyRatio` (default **0.8 = identity**; wrap already forces ≥1.0). Identity proven: body=0.8 reproduces **$27,145.66 / 944 exactly**.

| Arm | Real-tick net | Pos | EqDD | vs control | Note |
|---|--:|--:|--:|--:|---|
| Control (0.8×) | $27,145.66 | 944 | 13.31% | — | Arm-1 baseline (exact) |
| **A: Engulfing OFF** | $14,273.73 | 732 | 17.08% | **−$12,872** | Engulfing is load-bearing (~½ the book's net) |
| **B: ratio 1.5×** | $24,856.68 | 910 | 13.43% | −$2,289 | shared rate 44.1%→43.4% |
| **B: ratio 2.0×** | $17,847.01 | 887 | 15.51% | −$9,299 | keeps 94% pos / 66% profit |

Feed-matching (Model-1, prod-M1 vs GH 2019-25): tightening to 1.5× drops prod +$33,915→+$30,590 and GH similarly, Engulfing net R prod +32.2→+25.4 / GH +9.1→+8.3, fills 213→177 / 195→155, sign-agreement unchanged 96% — profit down, portability flat.

## Arms C / D / E — not warranted
- **Arm C (body/ATR floor):** pre-registered to run *only if the forensic shows vendor-only bodies are systematically small.* It shows the opposite (60/56/58% <0.4 ATR — identical). **Not triggered**, per the owner's own rule.
- **Arm D (wick/close-location):** the forensic shows close-location (all ~0.85) and upper-wick (all ~0.22) are identical across feed classes, and candidates already close strong. No discrimination available; Arm B already proved any fill-cut on this load-bearing strategy costs profit with no portability gain. **Pre-rejected.**
- **Arm E (combination):** requires a winning single feature to combine. There is none. **Moot.**

## Disposition
**No adoption. Binding baseline UNCHANGED at $27,145.66 / 944 (tag `baseline-engulf-27146`).** `InpEngulfingBodyRatio` stays in source at the identity default 0.8 (not pinned in config of record) as a documented, reversible, proven-identity lever. Engulfing's portability is at its structural frontier; the profit path is elsewhere. Recommend closing Arm 2 and moving to the next production target (same-direction exposure caps, PullbackContinuation reassessment, or VOLUME_FILTER simplification).
