# L4-1 v2.1 — reconciliation + P/L decomposition (owner-mandated gate before declaring unfixable)

## Exact executed-trade identity reconciliation (entry-key: EntryTime|Engine|Direction|round(EntryPrice,2))
| | baseline | = common | + removed/newly | unmatched |
|---|---|---|---|---|
| PRIMARY baseline 801 | 801 | 625 | + 176 removed | 0 |
| PRIMARY v2.1 727 | 727 | 625 | + 102 newly | 0 |
| GH baseline 748 | 748 | 585 | + 163 removed | 0 |
| GH v2.1 678 | 678 | 585 | + 93 newly | 0 |
Every executed trade reconciles. (The 39 "unmatched" in the scoring-row AUDIT join are fills that never reach
`EvaluateSetupQuality` — file/early-path entries — not lost trades.) Row types separated: scoring deduped to the
REVALIDATION row (the tier that gated the fill); P/L taken from final EXIT rows via `Total_PnL` (includes TP0/TP1/
TP2 partials); ENTRY rows excluded.

## P/L delta decomposition (v2.1 − baseline), BOTH feeds
| component | PRIMARY (−$12,869) | GH (−$8,580) |
|---|---|---|
| REMOVED trades (v2.1 rejects profitable baseline trades) | **−$7,429** (176) | **−$6,909** (163) |
| NEWLY-ADMITTED trades | **−$227** (102) | **+$217** (93) |
| COMMON size changes (tier→lot) | +$1,151 (84) | +$1,127 |
| COMMON exit changes (tier→exit coupling) | **−$6,482** (470) | **−$3,016** |
| arbitration displacement (residual) | +$118 | +$1 |

## The finding that reopens L4-1
1. **The newly-admitted cohort is NEUTRAL on both feeds** (−$227 / +$217) — it is NOT the failure driver. My prior
   "evidence-supported opposition admits net-losers" conclusion was an artifact of bundling; it is WITHDRAWN.
2. The −$12.9k / −$8.6k failure is entirely **(a) rejecting profitable trades** (−$7.4k / −$6.9k) and **(b) a
   tier→exit coupling** (−$6.5k / −$3.0k — changing a setup's quality tier cascades into different exit geometry).
3. Both dominant losses are STRUCTURALLY AVOIDABLE by the owner's shadow-classification design: no rejection
   (isolated risk-DOWNGRADE instead → keeps the removed profit), change RISK ONLY not the tier (→ no exit
   coupling), admissions SHADOW-ONLY (→ neutral). So the bundled v2.1 verdict does NOT prove L4-1 unfixable.

## But the cohort table sets the ceiling (current book, by SetupSubtype)
Only net-NEGATIVE cohort: `PINBAR_COUNTER_EXHAUSTION` avgR −0.04 (21 trades). Weakest positive:
`PINBAR_TREND_REJECTION`@SETUP_A +0.084 (112). Everything else +0.19…+0.45. The book sits at its subtractive
frontier — an isolated risk-downgrade has small upside. Per the gate it is still BUILT + measured on both feeds
(`InpCohortDowngrade`, risk-only) rather than concluded from this table; adopt only if an isolated cohort change
is positive on BOTH feeds. Ablation is delivered at the outcome level by this decomposition (removed / admitted /
size / exit / arbitration isolated); the scoring-mechanism ablation (signed-trend/macro/subtype/evidence) is
subsumed by the isolated-cohort tests that follow.

## Isolated risk-downgrade results (the gate's final test — primary)
| cohort change (risk-only) | Net | Δ | PF | Sharpe | EqDD |
|---|--:|--:|--:|--:|--:|
| baseline | $32,618 | — | 1.47 | 3.13 | 11.32% |
| PinBar-COUNTER ×0.5 | $32,230 | −$388 | 1.47 | 3.12 | 11.09% |
| PinBar-COUNTER ×0.0 (risk-zero) | $32,059 | −$559 | 1.47 | 3.16 | 10.91% |
| PinBar-TREND-A ×0.5 | $30,841 | −$1,777 | 1.50 | 3.17 | 9.98% |

**NO isolated cohort change proves net-positive.** Risk-zeroing the ONLY net-negative cohort (PinBar-COUNTER,
−0.04 avgR, 21 trades) costs −$559 — the negative-avgR trades are load-bearing via slot/exposure interaction.
With rejection AND tier→exit coupling both eliminated (pure risk-scale), the book still cannot be improved by
shrinking any cohort → SUBTRACTIVE FRONTIER confirmed on fully-isolated evidence.

## L4-1 — FINAL (isolated methodology): held; architecture not improvable, book at subtractive frontier
The v2.1 bundled verdict was corrected (admissions are NEUTRAL, not net-losing); the true loss channels are
rejection + tier→exit coupling; and the isolated design that avoids both STILL yields no net-positive cohort
change. L4-1 held; production `c051f97b` / $32,617.90 unchanged; all code (v1/v2/v2.1/downgrade-lever) flag-off
byte-identical. ONE option surfaced (not adopted): PinBar-TREND-A ×0.5 = −5.4% net for −12% DD + PF 1.50 /
Sharpe 3.17 (risk-for-return, same character as adopted L4-3/L4-4; fails the "prove positive" gate).
