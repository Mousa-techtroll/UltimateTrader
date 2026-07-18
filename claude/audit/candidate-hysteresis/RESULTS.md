# Candidate hysteresis — A/B results + adoption decision

Isolated candidate (QA#1). Flag `InpRegimeHysteresisPerBar` (default **false** = baseline). Binary
`f2d64948`, compiled 0/0. NOT combined with any other QA fix.

## A/B (identity-gated)

| Leg | flag | Net | Positions | Stats md5 | Δ vs baseline |
|---|---|---:|---:|---|---:|
| **Identity** (primary) | false | $34,858.89 | 869 | `1ed88d41` | **0 (EXACT baseline)** ✓ |
| **Fix** (primary) | true | $34,513.99 | 869 | `944b9447` | **−$344.90 (−1.0%)** |
| Identity (GoldHistory) | false | $29,525.79 | 820 | `1276ffa1` | 0 (exact GH baseline) ✓ |
| **Fix** (GoldHistory) | true | $28,809.01 | 820 | `562f2ff7` | **−$716.78 (−2.4%)** |

- **Identity legs reproduce the baseline EXACTLY on both feeds** ⇒ the candidate scaffold is behavior-neutral
  and the kill-switch is clean; the *only* behavioral change under `true` is the hysteresis site.
- **The fix costs net on BOTH feeds, same direction** (−1.0% / −2.4%), **same position count** (the coupling
  changes exits, not entries). Cross-feed-consistent ⇒ the coupling was genuinely (mildly) profitable, not a
  baseline-specific fluke.

## First-divergence attribution (entry-key; tickets renumber across runs so ticket-join is invalid)
- Same 869 entries (0 added / 0 removed); **87 / 869 exits differ (10%)**, summed Δ −$346.19 ≈ report −$344.90.
- **Diffuse, not concentrated:** Δ by exit year — 2019 +$25, 2020 −$21, 2021 +$13, 2022 −$77, 2023 −$13,
  2024 −$16, 2025 −$121, 2026 −$137. No single trade or year dominates.
- First divergence: `Bearish Pin Bar SHORT` entry 2019-01-07 02:00 — same chandelier mult (4.20) but the
  corrected once-per-bar trajectory trailed the SL to 1288.45 vs 1289.39, exiting 4 min earlier (here +$16
  *better*). Mechanism confirmed: the fix alters the smoothed-multiplier path on some bars → different SL
  ladder → different exit price/time, exactly the coupling channel — now made position-timing-independent.

## ADOPTION DECISION — DO NOT ADOPT by default (keep flag=false). Correct, but net-negative with no risk benefit.

The fix is a genuine correctness/robustness improvement — it makes the chandelier/regime hysteresis a pure
function of the market (wall-clock once-per-bar), so a position's exit no longer depends on the open/close
timing of *unrelated* positions (the shipped trail-coupling defect, and a latent source of the path-dependence
that made backtest edges like candidate-B partly illusory). **But** it costs **−1.0% (primary) / −2.4% (GH)**
net, cross-feed-consistent, with **no compensating risk benefit** (identical position count; DD not improved).

Per the honest-baseline discipline, a net-negative change with no demonstrated risk/robustness *payoff* is not
adopted. Correctness of an internal hysteresis clock — though real — does not here translate into a measurable
gain that justifies −1–2.4%. **Therefore:** production stays `baseline-session-breakout-utc-34858` (`1ed88d41`);
the fix is retained as a **documented, flagged, cross-feed-validated correctness option** (`InpRegimeHysteresisPerBar`,
default false). If forward-robustness (position-timing-independent exits, cleaner future A/Bs) is later
prioritized over the small backtest cost, the owner can flip the flag — that is an explicit, informed choice,
not a default. INCONCLUSIVE-lean-hold; do-not-relitigate the mechanism (proven once-per-bar market hysteresis).

Artifacts: `_arm_archive/sess_{HYSID,HYSFIX,GHHYSID,GHHYSFIX}`. Design: `DESIGN.md`.
