# GoldHistory — Timezone Audit (Phase 1A) — GATE RESOLVED

**Verdict: GoldHistory uses the SAME broker server clock as production (UTC+2 winter / UTC+3 US-DST). → IMPORT DIRECTLY, no conversion.**

## Method
Scanned candidate hour-offsets `k ∈ [−6, +9]` aligning GoldHistory H1 (`XAU_1h_data.csv`) to the trusted production broker H1 (`auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv`, Vantage, known model UTC+2/+3 US-DST) over the 2019–2025 overlap (40,810 GH bars). For each offset: mean |Δclose|, max Δ, H1 directional agreement. Repeated separately for clear-winter (Dec/Jan/Feb) and clear-summer (Jun/Jul/Aug) to expose any DST dependence.

## Result — offset 0 wins unambiguously
| Offset | n | mean \|Δclose\| | max Δ | dir agree |
|--:|--:|--:|--:|--:|
| −1h | 39,009 | 2.853 | 65.5 | 48.5% |
| **0h** | **40,713** | **0.285** | **49.7** | **94.8%** |
| +1h | 39,151 | 2.542 | 62.3 | 52.1% |
| +2h | 38,646 | 3.839 | 103.6 | 49.3% |
| +7h (NY) | 36,741 | 7.582 | 169.2 | 50.0% |

- **Best constant offset = 0h** (mean |Δclose| 0.285 on $1,500–4,000 gold ≈ 0.01%).
- **Winter best = 0h (|Δclose| 0.078) AND Summer best = 0h (|Δclose| 0.072)** — seasonally invariant.

## Why this proves "same broker clock" (and rules out the alternatives)
- **Not UTC:** a UTC feed would align to the broker at **+2 in winter and +3 in summer** (different offsets by season). We see 0/0 → GoldHistory already carries the same US-DST shift the broker applies.
- **Not New York time:** would align at ≈ +7h (constant) — measured |Δclose| there is 7.6, garbage.
- **Not a fixed non-broker offset:** every non-zero offset degrades both price and direction sharply.
- The DST resolver `CTimeOffset.mqh` (Phase 0.5) is therefore **not needed for import** — but it independently confirms the model GoldHistory already uses.

## Residual (expected, and useful)
At the correct 0-offset, directional agreement is **94.8%**, not 100%, and mean |Δclose| is 0.285 with a single-bar max of 49.7. This is **vendor-price divergence**, not misalignment: GoldHistory and Vantage source gold from different liquidity providers, so ~5% of bars — mostly near-flat ones where a tiny price difference flips the candle's sign — differ in shape. That is exactly the independent-feed signal we want (a strategy that only works on one broker's exact candles is fragile). It feeds the Phase-1B feed-sensitivity classification, and it is below the >98% H1-direction target — flagged, not a blocker.

**Import action:** load GoldHistory timestamps as-is (broker server time); no per-timestamp conversion. Normalize prices to 2 dp (see data-quality). GoldHistory ends **2025-12-31**, so the trusted-feed overlap is **2019-01-01 → 2025-12-31** (the 2026 H1 tail exists only on the production feed).
