# Short-Side Diagnosis — Synthesis of the Three-Lens Investigation (2026-07-11)

**Question (owner):** "Why is the current EA so bad at shorts? I feel this is a much bigger issue than our long entry strategies."
**Sources:** `short-side-forensics.md` (39-mechanism asymmetry map, funnel reconciliation), `short-side-economics.md` (per-trade decomposition, counterfactual brackets), `short-side-market-structure.md` (episode map, ceiling verdict, program spec). All computed from the binding-baseline archive (`_arm_archive/ceg_DFULL`, $23,771.46 / 928 positions, reconciled to the cent) + H1 rates + source.

---

## Verdict — the hypothesis is half right, and inverted in mechanism

**The EA is not bad AT shorts. It is bad at LETTING shorts exist.** Per trade, the short book is healthy — near parity with longs post-§D (avg R +0.123 vs +0.151) and *better than longs at entry selection* by every exit-independent measure. What's broken is participation and sizing: the pipeline systematically starves, down-sizes, and mis-ranks shorts through a stack of "protections" whose justifications are mostly dead code. **Shorts are not a bigger issue than long entry breadth — they ARE the entry-breadth issue wearing a different label.**

## The five convergent facts

1. **Short entries are GOOD** (economics, decisive): exit-free 48h forward excursion p50 **2.68R vs 2.02R** for longs — better in all four eras; favorable-first ordering 53/41 vs 49/49. The "shorts cap at 2.0R" belief was partially circular: **58% of shorts carry a broker TP stamped exactly 2.00R** (counter-trend adaptive-TP path; longs get 2.41–3.29R), which truncated the measured MFE that motivated the dead §C redesign.
2. **Shorts barely fire** (forensics + market structure): 709 short candidates vs 2,562 long. Upstream amputations: Engulfing/MACross/S6 bear sides effectively dead (Engulfing alone: 1,330 long candidates), bear pins banned NY (fills 121 Asia / 88 London / **0 NY**), crash engine D1-gated out of the two biggest modern bear windows (E5 2023: 0/235 stretch bars pass; E8 2026H1: 0/401). Of 9 shortable episodes 2019–2026, the arsenal fully caught **one** (2022).
3. **Shorts execute at ~0.70× base risk vs 0.93× for longs** (forensics): the session haircut (London 0.5×/NY 0.9×) applies only to the immediate path — which is 100% of shorts and 0% of confirmed longs — and the counter-trend 200-EMA 0.5× hits 46.1% of shorts vs 2.0% of longs. Mean final risk 0.817% vs 1.127%. Every claimed "protection" justifying the confirmation/validator bypass is dead on the config of record (short 0.5× mult = 1.0; SMC gate auto-passes, `ConfigureSMC` has zero callers).
4. **Three concrete mechanical defects** (both code and economics agree):
   - **RR-gate directional bug** (`CTradeOrchestrator.mqh:384`): `MathMax(tp1,tp2)` selects the FAR TP for longs but the NEAR TP for shorts → 26 short kills vs 1 long; 18 are PBC shorts dying at 1.30−ε while their passing 1.8R TP2 is ignored. This is a correctness bug, not a design choice.
   - **The §D pathology lives on in bear pins**: 93 STOPS_LEVEL clamp-sends across bear-pin shorts (§D covers `PATTERN_CRASH_BREAKOUT` only) → all exited as ≤0.15R scratches; short runners after partials round-trip to **−1.00R vs −0.55R** for longs (inert short chandelier).
   - **The +3 extreme-RSI quality bonus promotes the worst shorts into the biggest size** (`CSetupEvaluator.mqh:186-192`): A+ bear pins (31% of the short book) PF 1.008 at 1.35% risk vs B+ bear pins PF 2.402 at 0.675%. (Caution: the inversion is ~1.3σ on avg-R; and the quality_v2/A-demote kills show sizing dials fail OOS — any fix is a NEW registration, not a free lunch.)
5. **Where shorts participate, they pay like the long book's best years** (economics): 2021–23 short yield +1.2–1.4 R/100$oz. 2026H1: 16 fills against the largest down-opportunity in the dataset ($1,416/oz, −26.1%).

## Sizing the prize (honest)

| Path | Value (7.5y-equivalent) | Nature |
|---|---|---|
| Short exit reshaping (§C-shape front-load) | +$0.5–2.4k bracket | measured counterfactual; surrenders 2R-TP rides to buy round-trippers |
| Mechanical fixes (RR bug + bear-pin §D-mirror) | ~$1–3k + tail-shape | correctness + proven §D mechanism, small n |
| **Participation (CREV / bear-event gate)** | **the 2026H1 hole alone priced $3.8–7.6k** | entry breadth; ceiling "insurance with small carry" ($4–8k best case) but buys DD tail-shape exactly where longs bleed |
| Remove shorts entirely | **−$4,831** and re-concentrates 2025-dependence | rejected |

**Ceiling verdict (market structure): insurance with a small carry, not a profit center.** The real purchase is tail shape — the MC says live DD budget (~30% p95) is the binding constraint, and bear windows are exactly where the long book bleeds (2026 YTD −$2.8k).

## Pre-killed traps (do not build)

Breakdown-retest shorts (a-priori sim PF 0.57 — gold reclaims its levels; the retest IS the squeeze starting), London-Judas open fades (PF 0.53 — the Asia-high stop is the pool being swept), bear-pattern breadth on H1 in the record bull (E6/E7 structurally uncatchable), naive short enablement (measured-dead, register), CEG-unit short profiles (died with CEG, register).

## Ranked actionable programs (each a NEW registration, owner-gated)

1. **RR near-TP directional bug fix** — correctness class (like the ATR-pair fix, the only class that ever passed adoption). Cheap: one arm, identity-gated; frees 26 kills incl. 18 PBC shorts.
2. **§D-mirror for bear-pin shorts** — extend the proven trail-suppressor mechanism (or the entry-locked clamp guard) to `PATTERN_PIN_BAR` shorts: 93 clamped sends → scratches, runners −1.00R. Same mechanism §D already proved; small cohort, cohort-ΔR gated.
3. **CREV** — the market-structure agent's bear-event OR-gate on the crash engine (daily close < 20-day low within 15 days, price still ≤ broken level + 1.0×ATRd), with **slot isolation** (enter only at ≤ MaxPositions−2) and **DD dose control** (1 concurrent / 2 per event / monthly cap) designed in to fix both CRH4 FIT-stop failure modes a priori. Reconstructed PF 1.11 raw; traded E5 and E8 where the D1 gate scored 0.
4. *(measure-first, lower conviction)* Session-haircut symmetry and RSI-bonus short-scope — real asymmetries with dead rationales, but they are sizing dials, and the house has killed every sizing dial OOS. Shadow-price offline before any arm.

**Bottom line for the owner:** your instinct that something structural is wrong with shorts is correct — 11 live anti-short mechanisms, most defended by dead code. But the per-trade economics say the short pipeline is the healthiest under-used asset in the book, not its weakest link. The damage is measured in fills that never happen, which makes it the same problem as long entry breadth — and the same fix ranking applies: correctness first (RR bug), proven mechanisms second (§D-mirror), participation third (CREV).
