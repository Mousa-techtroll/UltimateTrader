# Plan v3 — Joint Entry×Exit optimization (factorial, evidence-led)

Supersedes v2. Revisions per owner directive: formal factorial interaction (diagnostic, not sole
gate); direct-vs-portfolio isolation (controls NOT required identical in the portfolio run); temporal
dev/confirm/holdout splits before calibration; Engulfing confirmatory / PBC exploratory; no sweeps.

## 0. Frozen control (published identity)
`claude/research/baseline-e40fa9f/IDENTITY-MANIFEST.json` — main HEAD `e40fa9f`, canonical config
(real-RSI active), EX5 md5 `4c49e7a3`, and Stats/Events md5 for both feeds. Baselines:
PRIMARY $34,085.46 / PF 1.47 / Sharpe 3.10 / 814 (`03ad126b`); GH $24,074.29 / PF 1.39 / Sharpe 2.93 /
763 (`ad3cbd3d`). Per-engine MFE/MAE/expectancy/capture tables regenerated from these frozen artifacts.
Every arm is judged vs this; the C arm must reproduce these Stats/Events md5 byte-for-byte.

## 1. Method — 4-arm factorial per profile
2×2: entry-change {off,on} × exit-change {off,on} → **C** (control), **E** (entry-only), **X**
(exit-only), **EX** (combined). Implemented as **TWO orthogonal flags per profile** — an ENTRY flag
and an EXIT flag — both default-off (so C == the frozen baseline). C = both off · E = entry-flag on ·
X = exit-flag on · **EX = BOTH flags on**. EX is the EXACT COMPOSITION of E and X; there is **no
EX-specific behavior anywhere** — this guarantees I = EX−E−X+C is a clean factorial contrast, not a confound.

**Factorial interaction (DIAGNOSTIC, not the sole gate):**
  I = EX − E − X + C
on the chosen robust objective. I>0 = synergy (entry & exit reinforce); I<0 = interference. I is
reported as evidence; it does NOT by itself decide adoption.

**Adoption rule for the joint (EX) profile — ALL of:**
1. **EX beats C** on ROBUST risk-adjusted performance — expectancy÷avg-loss, cross-checked by PF &
   Sharpe — on BOTH feeds AND the late-sample validation + expanding walk-forward (not the dev period).
2. **EX outperforms OR complements the isolated arms** — EX ≥ max(E, X) on the robust objective, i.e.
   the combination adds value beyond the better single change (I≥0 supports this; a mildly negative I is
   permissible only if EX still clearly beats C and both single arms and the holdout).
3. Passes feed-portability (primary↔GH sign-agreement) AND walk-forward.
If EX is merely additive/independent (I≈0) OR fails to beat the better single arm, do NOT adopt a
"joint" profile — adopt the single arm (E or X) that independently clears rule 1+3, or nothing.
Report all four arms + all comparisons on every result, including nulls.

## 2. Temporal design (split BEFORE calibration)
Full period 2019.01.01–2026.06.27, split up front:
- **Development** 2019.01–2022.12 — the ONLY period thresholds may be selected from.
- **Confirmation** 2023.01–2024.12 — validate the FROZEN thresholds (no re-tuning).
- **Late-sample validation** 2025.01–2026.06 — a validation window, NOT a true holdout: prior project
  work has already INSPECTED 2025, so it is not untouched. Contains the biggest primary year → a useful
  stress window, but it does NOT count as clean out-of-sample.
- **Expanding walk-forward** — anchored, expanding out-of-sample segments across the whole period.
- **GENUINE untouched validation = EXPANDING WALK-FORWARD + FUTURE demo/live data.** No in-sample window
  (2025 late-sample included) substitutes for forward data the model has never seen.
- **GoldHistory = FEED-PORTABILITY test on all splits, NOT a substitute for temporal OOS.** A change
  must survive BOTH the feed swap AND the temporal validation; either alone is insufficient.
- **Small-n caveat (binding):** per-engine per-split n is tiny (Engulfing ≈60/30/35; PBC ≈20/10/10).
  Splits are DIRECTIONAL; the holdout is the primary OOS proof; PBC's splits are near-uninformative
  (hence exploratory — it earns a directional read, never a confirmatory claim).

## 3. Isolation — direct effect vs portfolio collateral
- **Direct flag isolation (MUST be clean; verified SEPARATELY from the portfolio run):** each E/X flag
  branches ONLY inside its target engine's entry gate (E) or its target profile's exit logic (X).
  Proven by (a) code review that the flag guards only the target's decision, and (b) a direct isolation
  check confirming that, per candidate, ONLY the target engine's admit/exit decisions change. This
  rules out DIRECT cross-engine coupling (a real leak).
- **Portfolio collateral (measured + CLASSIFIED, NOT required zero):** in the full portfolio backtest,
  control engines (PinBar/Crash/Expansion) MAY shift because portfolio state is shared. Each control
  delta is classified as:
  - **Exposure displacement** — a target trade took a position/exposure slot (MaxPositions/Exposure).
  - **Arbitration displacement** — single-signal-per-bar: target won/lost a bar vs a control candidate.
  - **Equity-sizing displacement** — target P&L moved account equity → control's equity-based lot shifted.
  - **Daily-limit displacement** — target hit a daily trade/loss cap → a control trade was blocked.
  These are legitimate collateral, not leaks. **Report DIRECT profile effects (the target engine's own
  trades) separately from portfolio collateral effects.** Adoption weighs the direct effect AND the net
  portfolio economics, with collateral attributed.

## 4. Wave-1 profiles (contracts FROZEN — `wave1-profile-contracts.md`)
- **TREND_ENGULF — primary CONFIRMATORY.** Entry: closed-bar momentum + structural room. Exit:
  momentum-deterioration + engulf-origin invalidation. (Fresh evidence: less feed-degradation than PBC
  → the more robust of the two headroom candidates, inverting the prior framing.)
- **TREND_PBC — EXPLORATORY** (n≈40/feed, GH expectancy collapse 0.265→0.044). Entry: pullback/recovery
  quality. Exit: parent-structure invalidation + no-progress. ONE entry hyp, ONE exit hyp, minimal
  parameters only; a directional read, never a confirmatory claim.
Thresholds selected LATER, from development-period data only, never to fit a practitioner number, never
violating a contract non-goal.

## 5. Practitioner panel = HYPOTHESIS GENERATION ONLY
The 4-perspective web panel produced the hypotheses; it does NOT choose parameters and does NOT override
current-main evidence. Sources + claim + EA mapping published in v2 §3 (retained). Every parameter comes
from the frozen data.

## 6. Reporting (published per arm, per feed, per split)
Three separated blocks + robustness, with DIRECT (target engine) and PORTFOLIO (collateral) split out:
- **Entry quality:** fills, win%, avg R, %reaching 0.5R/1R/2R MFE, MAE distribution, quality-tier mix,
  population change vs C.
- **Exit capture:** fat-tail MFE-capture (MFE≥2R) + all-winner capture, give-back (0.8–1.5R), winner-
  clipping (ΔR on MFE≥1.5R cohort — negative = veto), time-in-trade.
- **Combined economics:** net, PF, Sharpe, EqDD, expectancy, concentration (top-2 / best month / best
  year share), loss cohort (%never-0.5R, avg-loss-R).
- **Robustness:** primary↔GH sign-agreement; walk-forward segments; the locked holdout.
- **Published comparisons every time:** EX vs C, EX vs E, EX vs X, and I = EX−E−X+C.

## 7. Guardrails
- **No broad parameter sweeps.** One coherent entry thesis + one coherent exit thesis per profile;
  minimal thresholds set from dev-period distributions.
- **PinBar/Crash/Expansion = untouched controls** — verify DIRECT isolation (their decision logic is not
  touched); their PORTFOLIO trades may shift as classified collateral (§3), which is expected, not a leak.
- Do NOT conclude "the global profile is optimal" from one failed Engulfing/PBC/trend-widen arm — a null
  is scoped to that profile/arm.
- Do-not-relitigate still binds: no fixed TP, no faster cut/BE-fast, no stop-geometry, no non-bull
  governor; time/no-progress cuts fire only on the never-0.5R cohort; loss book ~invariant on the direct effect.

## 8. Sequencing & deliverables
1. ✅ Frozen control + identity manifest + fresh per-engine tables.
2. ✅ Qualitative profile contracts frozen (`wave1-profile-contracts.md`).
3. Select minimal thresholds from the DEVELOPMENT period only (per contract; no sweep).
4. Implement 4 isolated flags per profile (C/E/X/EX), default-off; **direct-isolation check + C
   byte-identity gate (reproduce `03ad126b`/`ad3cbd3d`)** before any measurement.
5. Run {C,E,X,EX} × {primary, GH} × {dev, confirm, late-sample, expanding-walk-forward}; per profile
   `claude/research/wave1-<profile>/{DESIGN,RESULTS}.md` with the §6 report + interaction + decision.
6. Engulfing (confirmatory) is the headline; PBC (exploratory) is a directional companion. Update memory
   + honest-baseline with each adopt/reject + deltas. Wave 2 only after Wave-1 evidence.
