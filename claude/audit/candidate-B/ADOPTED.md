# ADOPTED — candidate-session-breakout-dst-only-B merged to production (2026-07-18)

Owner greenlit the merge after the validation battery returned PASS (`VALIDATION.md`). Candidate-B is now
the **production default**; the prior Gold-v1 baseline ($32,503.03) is retained behind a kill-switch.

## The change (one isolated, reversible edit)
The composed `CSessionBreakoutEntry` **breakout-window clock** is now DST-aware (fixed-UTC), resolved like
`CSessionEngine` (live: auto-detected `TimeCurrent−TimeGMT`; tester + `InpTesterDSTFix`: per-bar
`CTimeOffset::BrokerGMTOffset`). This resolves audit finding **F1** (the composed engine was the one live
consumer keying off raw broker-server time). The Asian **range** clock is unchanged (raw-server) — range-DST
was rejected (Arm C).

- New input: **`InpSessionBreakoutDST = true`** (`UltimateTrader_Inputs.mqh`). Input surface 388 → **389**
  (`current-canonical.set` updated; audit emitter row added). Full 18-field ledger regen = follow-up.
- Files: `CSessionBreakoutEntry.mqh` (breakout clock + init resolution), `CTimeOffset.mqh` unchanged from
  388, `UltimateTrader_Inputs.mqh` (+1 input), `UltimateTrader.mq5` (emitter row).

## New binding baseline
| | value |
|---|---|
| Net profit | **$34,858.89** (was $32,503.03; +$2,355.86 / +7.25%) |
| PF / Sharpe / Recovery | 1.42 / 2.96 / 4.47 |
| Equity DD | 15.22% |
| Positions | 869 |
| Config | `risk_R90.ini` (`cebf9578`) as-is, `InpSessionBreakoutDST` defaults true |
| Stats md5 | **`1ed88d41`** · Events md5 `8f15fe94` |
| Tag | `baseline-session-breakout-utc-34858` |

## Identity proofs (trade-exact)
- Production merged build, default → **Stats `1ed88d41` / $34,858.89 / 869** = frozen candidate SESSB byte-for-byte (Stats AND Events).
- Kill-switch `InpSessionBreakoutDST=false` → **Stats `96415ff0` / $32,503.03 / 865** = EXACT prior Gold-v1 baseline.
- Both compiled 0 errors / 0 warnings.

## Rollback
Runtime, no recompile: set `InpSessionBreakoutDST=false` → reverts to the exact prior baseline ($32,503.03).
Recommended: forward/shadow-track the live book against the 2026H1 caveat (candidate lagged the baseline that
half-year); flip the kill-switch if forward results disappoint.

## Superseded / rejected (unchanged)
full-DST (Arm 1/D), range-DST (Arm C), London-local, NY-local. Latent trail-coupling defect
(`DEFECT-trail-coupling.md`) remains open for independent investigation.
