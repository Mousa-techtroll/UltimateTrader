# Arm 1 — DST-corrected composed-session clock (RESEARCH PATCH, not adopted)

Patch: arm1-dst-composed-session.patch (propagates CTimeOffset DST-aware offset into the
CExpansionEngine-composed CSessionBreakoutEntry; offset only, no session-hour inputs changed).
Artifacts: arm1-stats.csv (md5 a8c1e028), arm1-report.htm.

## Measured true impact (388-pin config, pinned tick cache)
| | Baseline 388 | Arm 1 | Δ |
|---|---|---|---|
| Net profit | $32,503.03 | $31,399.56 | **−$1,103.47** |
| Positions | 865 | 868 | +3 |
| PF | 1.40 | 1.40 | — |
| Sharpe | 2.87 | 2.81 | −0.06 |
| Recovery | 4.81 | 4.06 | −0.75 |

Composed session fills: 12 → 15; window shifted server-8/13 → server-10/11 (London) + 15/16 (NY),
i.e. the +2h winter / +3h summer DST correction landed. NET REGRESSION −$1,103.47.

STATUS: preserved, not adopted / not rejected. The −$1,103.47 conflates the DST effect on Asian
RANGE construction vs the BREAKOUT window. The 2×2 decomposition — see
`claude/audit/session-clock-decomposition.md` — now separates them: Arm 1 (= arm D, full DST) is
reproduced EXACTLY by the split-flag research build (Stats md5 a8c1e028), and the decomposition
shows the −$1,103.47 = a POSITIVE breakout-window effect (+$2,356 primary / +$840 cross-history)
overwhelmed by a NEGATIVE range-construction effect (−$2,519 / −$1,561, which drives the composed
strategy to 0 fills). Cross-history + concentration (done) confirm: neither clock is a bankable
edge (session book moves only ±$0.1–0.5k; the multi-$k swing is ~96% feed-sensitive portfolio
ripple). Full-DST (this patch) is the WORST live arm on both feeds — do not adopt as-is.
