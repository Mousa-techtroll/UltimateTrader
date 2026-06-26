# Exit Lever Implementation Plan

Date: `2026-04-04`

## Objective

Use the biggest remaining profitability lever in the current EA: improve winner retention on strong-followthrough trades without widening initial risk or increasing global risk-per-trade.

This plan is based on the current audit outputs in `codex/` and the live code paths that manage TP, breakeven, trailing, and broker SL updates.

## Why This Is The Biggest Lever

- The latest profitability analysis shows a strong-trade exit opportunity pool of `160` trades and `39450.10` of 24h missed-move value.
- Recovering only `10%` of that missed move models about `+3945.01`, which is materially larger than the remaining robust entry-filter gains.
- The top opportunity patterns are `Bullish Pin Bar (Confirmed)`, `Bullish Engulfing (Confirmed)`, `Bearish Pin Bar`, and `Bullish MA Cross (Confirmed)`.
- The dominant exit-failure labels are still `trailing_stop_too_tight`, `breakeven_exit_too_early`, and `premature_exit`.

## Code Diagnosis

### 1. The EA already stamps per-trade exit profiles, but trailing is only partially honoring them

- Entry-time exit profiles are stamped into the position in [UltimateTrader.mq5](/mnt/c/Trading/UltimateTrader/UltimateTrader.mq5:1162), [UltimateTrader.mq5](/mnt/c/Trading/UltimateTrader/UltimateTrader.mq5:1291), and [UltimateTrader.mq5](/mnt/c/Trading/UltimateTrader/UltimateTrader.mq5:1553).
- TP distances/volumes and BE trigger are actually used later in [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1192) and [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1913).
- `exit_chandelier_mult` is also stamped per trade in the position struct, but it is not currently used by runtime trailing. The trailing path recomputes a live regime multiplier and pushes that into the active Chandelier plugin in [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1821).

### 2. Broker SL updates are still too aggressive for good runners

- When `InpBatchedTrailing=false`, every improved internal SL is sent to the broker in [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1969).
- That behavior matches the audit outcome: many strong trades are not bad entries, they are good entries that get clipped by broker-side trailing before the move finishes.

### 3. Chandelier trailing has no awareness of trade quality, pattern, or lifecycle stage

- The current Chandelier implementation in [CChandelierTrailing.mqh](/mnt/c/Trading/UltimateTrader/Include/TrailingPlugins/CChandelierTrailing.mqh:110) only knows ATR, lookback, price, and current SL.
- It does not distinguish:
  - high-quality trend continuation vs ordinary trade
  - pre-TP1 vs post-TP1
  - runner mode vs capital-protection mode

### 4. Partial profit-taking is still meaningful on trend trades, but it is a secondary leak

- Current regime profiles are initialized in [UltimateTrader.mq5](/mnt/c/Trading/UltimateTrader/UltimateTrader.mq5:688) from [UltimateTrader_Inputs.mqh](/mnt/c/Trading/UltimateTrader/UltimateTrader_Inputs.mqh:385).
- The current `TRENDING` profile closes about `56.1%` of the position by TP2, leaving roughly `43.9%` as runner.
- That is not the main problem by itself. The bigger issue is that the remaining runner is still being tightened too quickly afterward.

### 5. Anti-stall logic can still interfere with good trades

- The anti-stall path in [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1530) is not the primary lever, but it appears in some missed-move cases and should be carved out from the new runner mode.

## Implementation Principles

- Do not widen initial stop-loss.
- Do not increase global risk per trade.
- Keep weak and mixed-quality trades protected.
- Change only one management behavior per phase so the impact stays measurable.
- Make every change auditable in the existing `Stats` and `TradeEvents` logs.

## Phase 0: Strengthen Exit Telemetry

Goal: make the next backtest tell us exactly whether the fix worked for the right reason.

Files:
- [Structs.mqh](/mnt/c/Trading/UltimateTrader/Include/Common/Structs.mqh:133)
- [CTradeLogger.mqh](/mnt/c/Trading/UltimateTrader/Include/Display/CTradeLogger.mqh:530)
- [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1817)

Changes:
- Add per-trade fields for:
  - `runner_exit_mode`
  - `runner_promoted_in_trade`
  - `runner_promotion_time`
  - `trail_send_policy`
  - `last_trail_gate_reason`
  - `last_effective_chandelier_mult`
  - `last_live_chandelier_mult`
  - `last_entry_locked_chandelier_mult`
- Log when a trade is promoted into runner mode.
- Log why a broker SL update was sent or suppressed.

Acceptance:
- No behavior change.
- New logs show the exact effective trailing profile and broker-update gate per trade.

## Phase 1: Add Runner Exit Mode

Goal: classify only the strongest trades into a management path designed to retain large moves.

Files:
- [Structs.mqh](/mnt/c/Trading/UltimateTrader/Include/Common/Structs.mqh:172)
- [UltimateTrader_Inputs.mqh](/mnt/c/Trading/UltimateTrader/UltimateTrader_Inputs.mqh:385)
- [UltimateTrader.mq5](/mnt/c/Trading/UltimateTrader/UltimateTrader.mq5:1162)
- [UltimateTrader.mq5](/mnt/c/Trading/UltimateTrader/UltimateTrader.mq5:1291)
- [UltimateTrader.mq5](/mnt/c/Trading/UltimateTrader/UltimateTrader.mq5:1553)

Changes:
- Add a feature flag such as `InpEnableRunnerExitMode`.
- Add a small allowlist for the highest opportunity patterns:
  - `Bullish Pin Bar (Confirmed)`
  - `Bullish Engulfing (Confirmed)`
  - `Bullish MA Cross (Confirmed)`
  - `Bearish Pin Bar`
- Add initial eligibility rules at entry:
  - minimum setup quality `A`
  - minimum engine confluence threshold
  - regime must be `TRENDING`, or `NORMAL` with stronger confluence
  - block runner mode for extended long entries already known to be weak after excessive 72h upside extension
- Add in-trade promotion for late-emerging runners:
  - promote if trade reaches `>= 1.0R` before major adverse action
  - do not promote weak/reversal candidates

Acceptance:
- Trades are tagged as `standard` or `runner`.
- No trailing or TP behavior changes yet.

## Phase 2: Rewrite Broker-Trailing Cadence

Goal: stop sending every internal trailing improvement to the broker on trades that should be allowed to breathe.

Files:
- [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1817)
- [UltimateTrader_Inputs.mqh](/mnt/c/Trading/UltimateTrader/UltimateTrader_Inputs.mqh:438)

Changes:
- Keep internal stop tracking exactly as it is.
- Replace the single `InpBatchedTrailing` switch with a policy function, for example:
  - `TRAIL_SEND_EVERY_UPDATE`
  - `TRAIL_SEND_LOCK_STEPS`
  - `TRAIL_SEND_BAR_CLOSE`
  - `TRAIL_SEND_RUNNER_POLICY`
- Add `ShouldSendBrokerTrail(...)` inside `ApplyTrailingPlugins`.
- For `runner` trades, send broker SL only when one of these happens:
  - the trade first reaches BE lock
  - locked-in profit improves by at least `0.5R` up to `2R`
  - above `2R`, locked-in profit improves by at least `0.75R` or `1.0R`
  - a new H1 bar closes and locked-R improved materially
- Add a minimum time/bar cooldown between broker `PositionModify` calls for runner trades.
- Keep standard trades on the current behavior initially so the first impact stays isolated.

Acceptance:
- Internal trailing counts should remain high.
- Broker trailing updates should fall materially on runner trades.
- `trailing_stop_too_tight` should drop first on the top opportunity patterns.

## Phase 3: Make Trailing Multiplier And Activation Runner-Aware

Goal: stop the trailing engine from tightening good trades too early.

Files:
- [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1821)
- [CChandelierTrailing.mqh](/mnt/c/Trading/UltimateTrader/Include/TrailingPlugins/CChandelierTrailing.mqh:110)
- [UltimateTrader_Inputs.mqh](/mnt/c/Trading/UltimateTrader/UltimateTrader_Inputs.mqh:385)

Changes:
- Stop ignoring the stamped `pos.exit_chandelier_mult` for strong trades.
- Use an effective multiplier rule such as:
  - `standard`: current live-regime behavior
  - `runner`: `max(pos.exit_chandelier_mult, live_chand_mult, runner_min_chand_mult)`
- Add delayed trailing activation for runner trades:
  - do not allow Chandelier to start before a minimum profit threshold such as `1.0R` or after TP0 capture
- Do not let a runner trade tighten because the live regime briefly downgrades after entry.
- Keep the plugin interface simple if possible; prefer computing the effective multiplier and activation gate in `CPositionCoordinator` rather than making every trailing plugin stateful.

Acceptance:
- Strong trades should show fewer early trail hits before TP1/TP2.
- `breakeven_exit_too_early` and `trailing_stop_too_tight` should both improve.

## Phase 4: Add Runner-Specific BE And Partial Profiles

Goal: keep more size on the best trades after the initial move is confirmed.

Files:
- [UltimateTrader_Inputs.mqh](/mnt/c/Trading/UltimateTrader/UltimateTrader_Inputs.mqh:385)
- [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1192)
- [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1913)

Changes:
- Introduce optional runner-specific exit inputs instead of changing the global regime profiles for all trades.
- First-pass test values should be conservative:
  - later BE for runners, for example `1.5R`
  - keep TP0 small, or reduce it only slightly if needed
  - smaller TP1 and TP2 volumes than the current trend profile
  - wider TP2 distance for runner trades
- Target runner retention:
  - current `TRENDING` profile leaves about `43.9%`
  - first test should target roughly `52%` to `58%` remaining after TP2 on runner trades only
- Keep `NORMAL`, `CHOPPY`, and `VOLATILE` standard trades unchanged in the first pass.

Acceptance:
- The EA should realize more on the same strong trades without meaningfully worsening weak-trade control.

## Phase 5: Exempt Runner Trades From Anti-Stall Exits

Goal: avoid cutting obvious runners with protection logic intended for slow or failing trades.

Files:
- [CPositionCoordinator.mqh](/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh:1530)

Changes:
- Skip anti-stall full close for runner trades.
- If needed, allow only a softer partial reduction instead of full closure.
- Require lower MFE and lower confluence before anti-stall can act on a runner-eligible trade.

Acceptance:
- `anti_stall_exit_left_large_move` should become rare on runner trades.

## Recommended Delivery Order

1. Telemetry only.
2. Runner classification only.
3. Broker trailing cadence rewrite.
4. Runner-aware trailing multiplier and activation.
5. Runner-specific BE and TP profile.
6. Anti-stall carve-out.

This order isolates the biggest leak first: aggressive broker-side stop tightening.

## Validation Plan

### Compile And Safety

- Compile after every phase.
- Confirm no change in entry count unless the phase explicitly changes classification rules.

### Backtest Order

1. `2024`
2. `2025`
3. `2023`
4. `2022`
5. `2020-2021`

Reason:
- `2024` and `2025` are the clearest winner-retention years.
- `2022` and `2023` guard against overfitting to only strong bull trends.
- `2020-2021` confirm that protection on mixed years is not broken.

### Audit Checks After Each Phase

Re-run the existing `codex` analysis pack and compare:

- report net profit
- profit factor
- average exit score 24h
- average missed 24h R
- count of `trailing_stop_too_tight`
- count of `breakeven_exit_too_early`
- count of `premature_exit`
- opportunity-pattern realized R on:
  - `Bullish Pin Bar (Confirmed)`
  - `Bullish Engulfing (Confirmed)`
  - `Bearish Pin Bar`
  - `Bullish MA Cross (Confirmed)`

### Success Thresholds

- Recover at least `10%` of the current strong-trade missed-move pool over the detailed sample.
- Reduce bad exits on strong-followthrough trades by at least `25%`.
- Improve 2024 and 2025 exit scores without giving back the current profitability gains in 2022 and 2023.

## What Not To Do First

- Do not increase global risk.
- Do not widen initial stops.
- Do not globally loosen all trailing for every strategy.
- Do not remove major entry families before fixing the runner-management path, because the current largest upside is still on exit quality, not entry quantity.

## Immediate Next Engineering Task

Implement Phase 0 and Phase 1 together in one small pass, then Phase 2 as the first behavior-changing pass.

That gives the next backtest a clean answer to the most important question: how much of the remaining missed-move pool is coming specifically from broker-side stop cadence rather than from TP sizing or signal quality.
