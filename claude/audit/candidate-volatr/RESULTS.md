# Candidate P1: forming-bar ATR — A/B results + decision

Flag `InpVolRegimeClosedBar` (default false = baseline). Binary compiled 0/0. Isolated (QA#6), not combined.

## A/B (identity-gated)
| Leg | flag | Net | Positions | Stats md5 | Δ vs baseline |
|---|---|---:|---:|---|---:|
| Identity (primary) | false | $34,858.89 | 869 | `1ed88d41` | 0 (EXACT baseline) ✓ |
| **Fix (primary)** | true | $34,112.14 | 874 | `6725de5f` | **−$746.75 (−2.1%), +5 pos** |
| Identity (GoldHistory) | false | $29,525.79 | 820 | `1276ffa1` | 0 (exact GH baseline) ✓ |
| **Fix (GoldHistory)** | true | $27,923.16 | 822 | `dc2583ff` | **−$1,602.63 (−5.4%), +2 pos** |

Identity legs reproduce the baseline exactly on both feeds ⇒ scaffold neutral, kill-switch clean.
**The fix costs net on BOTH feeds and ADDS fills** — cross-feed-consistent.

## First-divergence attribution (entry-key; primary)
Same-key set: COMMON 869, **ADDED 5, REMOVED 0**.
- **5 ADDED fills, all `ExpansionEngine`, net −$296.15** — the direct mechanism: closed-bar ATR raises
  `current_atr` → higher `atr_ratio` → more VOL_HIGH/EXTREME → `IsExpansionContext` admits 5 more volatile-day
  entries (net losers).
- **283 COMMON trades changed exits, net −$456.27** — the vol regime also feeds `CDayTypeRouter` → day-type →
  exit geometry, so the regime shift ripples into common trades' exits (first divergence: 2019-01-03 MACross).
- Total −$752.42 ≈ report −$746.75. Diffuse by year (2023 −$287, 2025 −$458 worst; 2024 +$241 only positive).

## DECISION — DO NOT ADOPT (net-negative both feeds + adds risk; no benefit)
The fix is the *correct* semantics — the vol-regime gate should classify on the last CLOSED bar, not the
still-forming bar (the ~5–7% forming-bar ATR deflation was under-classifying VOL_HIGH/EXTREME). But
empirically the under-classification was *beneficial*: it suppressed 5 marginal expansion-engine volatile-day
fills (net losers) and held a favorable day-type/exit path. Correcting it costs **−2.1% (primary) / −5.4%
(GH)** AND adds fills (+5/+2 = more exposure) with **no risk benefit**. Note the "look-ahead" is mild — it is
the *incomplete current* bar's ATR, not future data — so the correctness case is weaker than a true repaint.
Per the honest-baseline discipline, **not adopted**: production stays `baseline-session-breakout-utc-34858`
(`1ed88d41`); retained as a documented, cross-feed-validated correctness option (`InpVolRegimeClosedBar`,
default false). Same class as the hysteresis candidate: a real internal-correctness fix that the specific
book monetizes in reverse. Owner may flip for forward cleanliness at a measured ~2–5% cost. Artifacts:
`_arm_archive/sess_{VATRID,VATRFIX,GHVATRID,GHVATRFIX}`.
