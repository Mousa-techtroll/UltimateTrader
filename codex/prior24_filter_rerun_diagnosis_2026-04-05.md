# Prior24 Filter Rerun Diagnosis

The first rerun after adding the prior-24h continuation-long filter was **not a valid A/B result**.

Observed facts:

- `reports/` files had fresh timestamps and showed:
  - `InpPrior24hContinuationLongFilter=true`
  - `InpPrior24hContinuationMinPct=0.0`
  - `InpPrior24hContinuationH4Bars=6`
- `codex` outputs were unchanged from the previous baseline.
- Raw logs contained **zero** `[Prior24hFilter]` events.

Conclusion:

- The first implementation only gated the **immediate execution** path.
- The targeted continuation longs mostly enter through the **pending confirmation** flow.
- So the rerun was effectively a no-op for this filter.

Fix applied:

- Added the same prior-24h continuation-long gate to the confirmed pending-signal path in [UltimateTrader.mq5](/mnt/c/Trading/UltimateTrader/UltimateTrader.mq5).
- MT5 compile result after the fix: `0 errors, 35 warnings`.

Action:

- Rerun the yearly backtests again with the new build.
- The next valid rerun should produce `[Prior24hFilter]` log entries if the gate is actually active.
