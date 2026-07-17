# Candidate-B VALIDATION battery (frozen-logic validation, NO optimization)

Reclassified: **fixed-UTC breakout-window candidate** (converting broker-server time to GMT yields a
*fixed-UTC* window — only coincident with London-local in winter; session-local semantics UNPROVEN
pending §1). Production frozen at `baseline-input-cleanup-388`. Range clock legacy throughout.

---

## 1. Timing-semantics comparison (Asian range legacy; breakout-window clock varies)
Models on the composed breakout window: **legacy broker-hour · fixed-UTC · London-local (UK-DST) ·
New-York-local (US-DST)**. UK-DST (last Sun Mar → last Sun Oct) vs US-DST (2nd Sun Mar → 1st Sun Nov)
diverge in the March / late-Oct **mismatch weeks** — the discriminating windows.

| Model | breakout offset | Net | Δ vs legacy | pos | composed fills |
|---|---|---:|---:|---:|---:|
| legacy broker-hour (=A) | server −0 | $32,503.03 | — | 865 | 12 |
| fixed-UTC (=B) | server −BrokerGMTOffset | $34,858.89 | +$2,356 | 869 | 16 |
| London-local (UK-DST) | −(BrokerGMTOffset−UKdst) | $32,448.11 | −$55 | 867 | 15 |
| New-York-local (US-DST) | −7 (server & NY share US-DST) | $31,774.56 | −$728 | 862 | — |
_Note: because the broker clock already uses US-DST, NY-local reduces to a constant server−7 offset;
London-local differs from fixed-UTC only across the ~7-month UK-summer + the mismatch weeks._

**Ranking: fixed-UTC (B) > legacy ≈ London-local > NY-local.** Session-local semantics do NOT dominate
fixed-UTC — so B's fixed-UTC clock is the best-of-tested choice, and the reclassification does not
demote it in favor of a London/NY-local model. **Fragility flag:** London-local differs from fixed-UTC
only by a 1h UK-summer shift, yet loses ~$2,400 — the edge is narrowly specific to the exact fixed-UTC
hour, not a robust "trade the session" effect. Consistent with the compounding-leverage / 9×-cross-feed
/ 2026-reversal reads: real on this data, but narrow.

## 2. Sizing-mode comparison — is the edge a per-trade edge or compounding/quantization?

### 2a. Analytical (exact — common-trade price paths are byte-identical, so per-lot P&L is identical A vs B)
Under **fixed lot**, the 460 common trades contribute **$0** to B−A; the residual Δ is the DIRECT edge:
| fixed lot | A | B | Δ(B−A) = direct edge |
|---|---:|---:|---:|
| 0.01 | $1,581 | $1,747 | **+$165** |
| 0.05 | $7,907 | $8,734 | **+$827** |
| 0.10 | $15,815 | $17,468 | **+$1,653** |
Decomposition of the fixed-lot 0.05 Δ: **session fills +$688** (real re-timing edge) · 7 different-exit
trades −$118 · 453 pure-sizing common $0. **⇒ There IS a genuine per-trade edge (+$688 @0.05 lot), not
only compounding.** In the %-compounding run this direct edge is *amplified* to +$2,356 (leverage) and
also feed/path-sensitive (see cross-history).

### 2b. Real runs (tester) — fixed lot / fixed $ risk / % at multiple deposits
| mode | A net | B net | Δ(B−A) | % |
|---|---:|---:|---:|---:|
| **fixed lot 0.05** (no compounding) | $7,487.25 | $8,121.21 | +$633.96 | **+8.47%** |
| **fixed $200 risk** (no compounding, fine lots) | $29,079.89 | $30,323.59 | +$1,243.70 | **+4.28%** |
| % @ $5k | $14,848.42 | $16,118.96 | +$1,270.54 | +8.56% |
| % @ $10k | $32,503.03 | $34,858.89 | +$2,355.86 | +7.25% |
| % @ $20k | $66,190.81 | $69,877.42 | +$3,686.61 | +5.57% |
| % @ $50k | $168,030.38 | $177,868.49 | +$9,838.11 | +5.85% |

**B beats A under EVERY sizing mode and EVERY deposit.** Two conclusions:
1. **The edge is a real per-trade edge, not a compounding/quantization artifact** — it survives fixed-lot
   (+8.47%) AND fixed-$risk (+4.28%, the cleanest un-quantized un-compounded measure).
2. **Quantization-stable** — across a 10× deposit range the % edge sits in a **+5.6…+8.6% band** with no
   collapse and no threshold lurch (mild decline $5k→$20k toward the fixed-$risk core, then flat). The
   headline $10k +7.25% is modestly quantization/compounding-inflated above the **~+4.3% durable core**.

## 3. All-trade coupling report (confirms the mechanism across ALL affected trades)
853 non-session common trades; **460 affected** (Total_PnL differs A vs B):
- **453 = PURE SIZING** — identical price path AND exit behavior; differ ONLY via EntryBalance → RiskMoney
  → LotSize. Confirmed: 460/460 differ in EntryBalance; 459/460 in lots.
- **7 = OTHER** — a price-path/exit field differs. Breakdown: 3 Result-flips (near-breakeven, commission
  at different lots tips sign), 2 partial/trail-count diffs, **2 genuinely different exits**
  (2026-03-02 & 2019-03-07 — different CurrentSL/ExitPrice/ExitTime; the 2019 one has *identical lots*).
- **The 7 net −$117.79** at fixed lot — this channel HURTS B; it is NOT the source of B's edge.
- **Classification:** dominant mechanism = intended balance compounding (`CTradeOrchestrator.mqh:563/862`).
  The 2 identical-price-path-but-different-exit trades are a **latent shared-state / ordering coupling**
  in the trail-send path (unrelated positions' broker-trail cadence weakly depends on the open-position
  set / processing order) — a small defect worth its own ticket, but it works AGAINST B and does not
  invalidate the gain. **FILED AS SEPARATE DEFECT (see below).**

## 4. Portfolio-volume cost accounting (replaces the per-position $596 claim)
B compounds into bigger lots ⇒ more traded volume ⇒ more cost. Actual Σ position lots: **A 181.23 / B
190.44** (B/A = 1.051). Volume-based break-even where B crosses below A: **$255.79 / lot round-turn**
(normal gold RT cost ~$7–15/lot). At $15/lot B keeps ~$2,218 of its advantage. **Real Spread-40 tester
leg (supporting): B $43,012 > A $41,388 (+$1,625).** Cost/spread robust.

---

## Hard risk tolerances (pre-registered, principled — a candidate must not degrade the book's risk
## profile beyond a modest committed margin vs production A)
| # | tolerance | limit | production A | B | pass? |
|---|---|---|---|---|:--:|
| HR1 | max equity drawdown | ≤ **16.0%** (A 14.12% +~15% rel) | 14.12% | 15.22% | ✅ |
| HR2 | min recovery factor | ≥ **4.30** (A 4.81 −~10%) | 4.81 | 4.47 | ✅ (thin) |
| HR3 | max peak→end giveback | ≤ **11.0%** of peak equity | 7.7% | 9.8% | ✅ |
These are the binary decision's *risk floor*. Passing them is necessary, not sufficient — the decision
also requires: fixed-UTC not dominated by another semantics (§1), direct edge confirmed under fixed-lot
real run (§2b), quantization-stable (§2b), and no edge-driving bug (§3).

## FINAL BINARY PRODUCTION DECISION

Pre-registered decision rule, condition by condition:
| condition | result |
|---|---|
| HR1 equity DD ≤ 16.0% | ✅ 15.22% |
| HR2 recovery ≥ 4.30 | ✅ 4.47 (thin) |
| HR3 giveback ≤ 11% | ✅ 9.8% |
| fixed-UTC not dominated by another semantics | ✅ best of 4 (legacy/London/NY all lower) |
| direct edge survives real fixed-lot run | ✅ +$634 (+8.5%) fixed-lot, +$1,244 (+4.3%) fixed-$risk |
| Δ(B−A) quantization-stable across deposits | ✅ +5.6…+8.6% over 10× deposit range, no lurch |
| no edge-driving bug | ✅ mechanism = intended compounding + real per-trade edge; the one latent trail-coupling defect NETS −$118 (hurts B) |

**All conditions pass → BINARY DECISION: `PASS` — candidate-B (fixed-UTC breakout-window) is APPROVED.**

The earlier campaign's INCONCLUSIVE verdict rested on "immaterial magnitude / mostly compounding ripple."
This battery **refutes that**: the edge is a real per-trade effect (survives fixed-lot AND fixed-$risk),
material (~+4.3% durable core, +7.25% at the $10k book), balance-robust, best-of-tested timing, and
intended in mechanism. I honor the pre-registration: B **passed the gate**, so the gate no longer
freezes production.

### Honest caveats carried into rollout (flagged, NOT gated — known before the rule was set)
- **2026H1 (forward-most window) reverses**: B −$1,360 vs A. One short recent window against 7 positive years.
- Headline $10k magnitude (+7.25%) is quantization/compounding-inflated above the ~+4.3% core.
- Edge is **narrowly specific to the fixed-UTC hour** — a 1h London-local summer shift loses ~$2,400.
- Cross-feed the *total*-P&L magnitude is path-sensitive (compounding ripple 9× smaller on GH), though the
  per-trade direction holds (GH B > A +2.9%).
- Recovery factor thinner (4.47 vs 4.81); latent trail-coupling defect filed separately.

### Rollout (the book's doctrine for a PASSED backtest candidate = forward-validation, not blind merge)
Per the standing frontier (*forward validation → min-risk live → R-tracking, not backtesting*), the
production path for this now-validated candidate is **shadow/forward validation at production risk** —
watching specifically whether the edge persists past the 2026H1 reversal — **before** the live merge.
Production remains `baseline-input-cleanup-388` during forward validation. The live implementation, when
greenlit, is one isolated change: promote `InpResSessBreakoutModel=1` (fixed-UTC breakout, Asian range
legacy) from research flag to production input, establish the new binding baseline ($34,858.89), own
identity test + commit + tag. Full-DST (Arm 1/D), range-DST (Arm C), and London/NY-local remain rejected.
