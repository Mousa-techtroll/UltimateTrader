# Candidate P2: SL re-sync on modify failure — A/B results + decision

Flag `InpSLResyncOnFail` (default false = baseline). Isolated (QA lane2 #1), not combined. Compiled 0/0.

## A/B (identity-gated)
| Leg | flag | Net | Positions | Stats md5 | Δ vs baseline |
|---|---|---:|---:|---|---:|
| Identity (primary) | false | $34,858.89 | 869 | `1ed88d41` | 0 (EXACT baseline) ✓ |
| **Fix (primary)** | true | $34,940.18 | 869 | `d6549628` | **+$81.29 (+0.23%)** |
| Identity (GoldHistory) | false | $29,525.79 | 820 | `1276ffa1` | 0 (exact) ✓ |
| **Fix (GoldHistory)** | true | $29,525.79 | 820 | `f11c4b2c` | **$0.00 (neutral; md5 differs only via the logged `MODIFY_FAIL_RESYNC` gate-reason)** |

## Attribution + risk
- **Same position count** both feeds — the re-sync changes exit management only, not entries.
- **Only 8 / 869 exits changed** (4 improved, 4 worse, net +$81.50; concentrated 2025 +$107 / 2026 −$26) —
  matching the ≤10 broker-fail-no-later-trail tickets from the exact-baseline recompute. The re-sync fires rarely.
- **Risk IDENTICAL**: PF 1.42, Sharpe 2.96, Recovery 4.47 unchanged; Equity DD 15.22% → 15.24% (+0.02pp).

## DECISION — RECOMMEND ADOPT (first candidate with no cost; owner greenlight to flip the default)
This is the **only candidate so far that is not net-negative.** It is a genuine correctness fix — the
coordinator's internal `pos.stop_loss` must reflect the broker's actual SL; the pre-fix code only re-synced on
`INVALID_STOPS`, so any other broker reject left a phantom advanced SL that silently froze later legitimate
trails. The backtest impact is **noise-level** (+$81 / +0.23% primary, exactly $0 GH, 8 trades, 4-4 split,
risk-identical) — I do NOT claim a P&L edge. The real case is **correctness + live-robustness**: the clean
real-tick tester produced only 60 broker-fails, but LIVE trading (requotes, off-quotes, latency) rejects modifies
far more often, and each un-repaired desync freezes a runner's trail for its life — so the fix's expected value
is materially higher live than the backtest shows, at **zero measured cost and zero risk change**.

**Recommendation: ADOPT** as a correctness/live-robustness hardening — flip `InpSLResyncOnFail` default to true
in a follow-up (its own identity re-confirm + baseline note), OR the owner may hold it flag-off if a strictly-
demonstrated-backtest-benefit bar is required (the +$81 is not that). Meanwhile the flag defaults false so
production stays `baseline-session-breakout-utc-34858` (`1ed88d41`). Unlike the hysteresis/vol-ATR candidates
(correct-but-net-negative → do-not-adopt), this one is correct-and-cost-free → the standout adoption candidate.
Artifacts: `_arm_archive/sess_{SLSID,SLSFIX,GHSLSID,GHSLSFIX}`.
