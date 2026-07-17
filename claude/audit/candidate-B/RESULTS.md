# Candidate-B adoption campaign — RESULTS

Against the pre-registered gate (`adoption-gate.md`). Production held at `baseline-input-cleanup-388`.

## 0. Figure reconciliation (same run, Arm B primary)
| figure | value | basis |
|---|---:|---|
| Gross profit − gross loss | $118,799.24 − $83,940.35 = **$34,858.89** | MT5 report net (commission-net) |
| Σ Total_PnL (EA CSV) | $35,430.21 | gross of commission |
| **commission/swap** | **$571.32** | the gap (EA Total_PnL is pre-cost; MT5 net is post-cost) |
| final balance | **$44,858.89** | $10,000 + report net |
| peak closed balance | ≈$49.8k net / $50.3k gross @ 2026-02 | curve reconstruction |
| equity peak (floating) | ≈$50.5k | report Eq-DD > Bal-DD confirms floating add |
A parity: Σ Total_PnL $33,046.72 vs report $32,503.03 → commission $543.69. The "$50k" sighting = Arm B peak equity, real.

## 1. Metric panel — A (prod) vs B (candidate), primary feed
| metric | A | B | note |
|---|---:|---:|---|
| net (report) | $32,503.03 | **$34,858.89** | B +$2,355.86 |
| profit factor | 1.40 | **1.42** | B better |
| Sharpe | 2.87 | **2.96** | B better (G2 ✅) |
| Recovery Factor (report) | **4.81** | 4.47 | B worse; 0.93× (G2 ✅ ≥0.90×, but a risk flag) |
| Equity DD max | 14.12% | 15.22% | B carries more DD |
| Balance DD max | $4,916 | $6,125 | B +$1,209 |
| peak→end giveback | $3,596 | $4,918 | B +$1,322 |
| longest underwater | 618 d | 618 d | equal |
| positions | 865 | 869 | B +4 |

## 2. Yearly net (gross) — B beats A every year 2019–2025, REVERSES in 2026H1
2019 +56 · 2020 +117 · 2021 +16 · 2022 +107 · 2023 +686 · 2024 +808 · 2025 +1,953 · **2026 −1,360**.
The advantage is broad (not one-year), but the forward-most window (2026H1) goes the wrong way.

## 3. Concentration ablations (G3) — B ≥ A survives ALL ✅
| ablation | Δ(B−A) | B≥A |
|---|---:|:--:|
| full | +$2,383 | ✅ |
| ex-largest-trade | +$2,276 | ✅ |
| ex-best-5-trades | +$1,870 | ✅ |
| ex-best-year / ex-2025 | +$430 | ✅ |
| ex-2026 | +$3,743 | ✅ |
Not one-trade / one-year driven. **G3 PASS.**

## 4. Cost stress (G4)
- **Analytical** (per-position adverse cost): B trades only 4 more positions, so its edge is cost-insensitive —
  break-even at **$595.87/position** of added round-trip cost (realistic is $5–30). **Refutes "B just trades more." G4 PASS.**
- **Real spread stress** (tester, Model=1, primary XAUUSD+, **Spread=40** pts vs ~6 normal):
  A $41,387.63 → B **$43,012.26** = **+$1,624.63** (PF 1.46 both, Sharpe B 3.31 > A 3.25). Under materially
  wider spread + synthetic execution, **B still beats A**. **G4 PASS.**
- Direction is robust across every execution condition; only magnitude moves:
  M4 real-ticks **+$2,356** · M1/Spread-40 **+$1,625** · GoldHistory M1 **+$840**. (Sign robust, size not.)

## 5. Cross-history (G5) — GoldHistory, Model=1 ✅
GH A $28,685.51 → GH B $29,525.79 (**+$840.28**). Session-book direction non-negative on both feeds
(composed Δ: primary +$92, GH +$533). Direction replicates; **G5 PASS**. But magnitude collapses **9×**
(primary ripple +$2,291 → GH +$243) — the size is not feed-robust.

## 6. Coupling mechanism (G6) — INTENDED COMPOUNDING, not a bug ✅
The 460-trade "ripple" is **balance-based position sizing**, proven trade-by-trade:
- For every ripple trade, entry price, exit price, SL, trail updates, chandelier mult, exit reason,
  MAE/MFE, hold time, partial structure are **byte-identical** A vs B. Only `LotSize` (and thus
  `Total_PnL`) differ.
- Driver is `EntryBalance`: e.g. 2026-01-27 Pullback — same RiskPct 0.68 & RiskDistance 105.58, but
  balance A $43,952 vs B $47,964 → RiskMoney = RiskPct%×balance → lots 0.02 vs 0.03 → same price move,
  more money. (Big R-swings on small trades are lot **quantization**: 0.02→0.03 is +50% lots on +9% risk.)
- Code: `CTradeOrchestrator.mqh:563` risk money = `AccountInfoDouble(ACCOUNT_BALANCE)`; `:862`
  `entry_balance = ACCOUNT_BALANCE`. Standard compounding.
**Verdict: the A→B system-level gain is a legitimate, intended compounding effect — NOT a shared-state
or ordering bug.** It is NOT invalid. But it IS *leverage*: the amplification of re-timing ~14 session
fills through balance-based sizing, which is why it (a) is 9× smaller on the second feed, (b) reverses in
2026H1, (c) carries proportionally more drawdown (worse recovery factor). The **direct** session-timing
edge is immaterial (+$92).

## Gate scorecard
| gate | result |
|---|---|
| G1 Return | ✅ PASS (B > A net) |
| G2 Risk-adjusted | ⚠️ PASS-borderline (Sharpe ✅; Recovery 0.93× — worse, above the 0.90× floor) |
| G3 Concentration | ✅ PASS (all ablations) |
| G4 Cost stress | ✅ PASS (analytical break-even $596/pos; real Spread-40 leg B +$1,625 > A) |
| G5 Cross-history | ✅ PASS direction (magnitude not robust) |
| G6 Mechanism | ✅ PASS — intended compounding, not a bug |

## VERDICT (pre-registered INCONCLUSIVE clause)
All six mechanical gates pass (G2 borderline). **BUT** the pre-registration's explicit INCONCLUSIVE
condition — *"robust direction but immaterial magnitude with a worse recovery factor"* — is exactly met:
the direct session edge is +$92; the headline +$2.4k is intended-but-path-dependent compounding leverage
that is 9× smaller cross-feed, negative in 2026H1, and bought with a worse recovery factor.

**→ Do NOT merge to production on backtest evidence. INCONCLUSIVE → forward-validation candidate.**
The correctness core (breakout window fires on a **fixed-UTC** clock — svr 10/11 & 15/16 — instead of
the legacy fixed broker-hour svr-08/13; NOT proven to be the *session-local* London/NY open, which
requires the timing-semantics test) is directionally sound and defensible to carry into shadow/forward
validation at production risk — but the +$2.4k must not be booked as a repeatable edge. Production stays
`baseline-input-cleanup-388`. Range-DST (Arm C) and full-DST (Arm 1/D) remain rejected.
