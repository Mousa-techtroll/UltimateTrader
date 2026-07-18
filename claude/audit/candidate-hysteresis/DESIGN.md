# Candidate: regime/chandelier hysteresis — intended-semantics decision + design

Fixes QA finding #1 (the shipped trail-coupling defect). Isolated candidate; NOT combined with any other
QA fix. Production stays `baseline-session-breakout-utc-34858` (Stats `1ed88d41` / Events `8f15fe94`) until
this candidate's A/B + adoption decision.

## Step 1 (required) — is the intended state GLOBAL once-per-bar market hysteresis, or PER-POSITION exit hysteresis?

**Decision: GLOBAL once-per-bar MARKET hysteresis.** Evidence (all inputs are market properties,
position-independent), `CPositionCoordinator.mqh:3690-3719`:
- The hysteresis is driven by `rScore = m_regime_scaler.Evaluate(*m_context)` — the **market** regime risk
  class, computed from `CMarketContext`, identical for every open position on a given bar.
- `m_regime_hold_bars` counts *"how many consecutive bars the MARKET regime class has held"*; the switch
  gate is `m_regime_hold_bars >= 3`; `liveProfile.chandelierMult = GetExitProfile(rScore.riskClass)` is the
  **regime's** exit profile. None of these reference the position.
- The code comment states it: *"Hysteresis: regime must hold for 3 bars before trailing multiplier changes"*
  (`:3686`). Regime is a market property.

⇒ The state (`m_smoothed_chand_mult`, `m_regime_hold_bars`, `m_last_regime_class`, `m_last_regime_bar`,
`:103-106`) is a **market-regime smoothing clock**, and belongs in the same once-per-bar, book-independent
place as the `CMarketContext::Update` snapshot — NOT inside the per-position management loop.

**The bug:** it is advanced only inside `ApplyTrailingPlugins`, reached only from the per-position loop,
which early-returns on an empty book (`:2003`) and skips sleeve/file positions. So `m_regime_hold_bars`
counts "bars where the book was non-empty" (undercount across empty gaps) and `m_smoothed_chand_mult`
persists stale, and is inherited by the next position to open ⇒ the open/close timing of unrelated positions
perturbs every other position's chandelier multiplier → trailing stop → exit. (Empirically: the 460-trade
session-breakout ripple, `candidate-B/VALIDATION.md §3`.)

## Step 2 — the fix (advance once per bar, book-independent; do NOT advance in the per-position loop)

New `CPositionCoordinator::UpdateRegimeHysteresis()` performs the `:3696-3719` advance ONCE, guarded by
`cur_bar != m_last_regime_bar`, and stores the resolved multiplier in `m_smoothed_chand_mult`. It is called
**once per new H1 bar from `OnTick`'s new-bar block, right after the market-state update** (beside
`g_stateManager.UpdateMarketState()`), so the hold-bar counter tracks wall-clock market bars regardless of
the open-position set. `ApplyTrailingPlugins` no longer advances the state — it READS `m_smoothed_chand_mult`
(the resolved market multiplier) and layers the existing per-position floors (entry-locked chandelier floor,
CEG trail floor) on top, unchanged.

**Reversible + baseline-preserving candidate flag:** `input bool InpRegimeHysteresisPerBar = false;`
- `false` (default) = legacy per-position-loop advance ⇒ must reproduce baseline `1ed88d41` EXACTLY
  (identity leg — proves the ONLY change under `true` is the hysteresis site, and gives a clean kill-switch).
- `true` = the fix (once-per-bar market hysteresis).
The flag defaults to the baseline so production is unchanged; the A/B measures `true`; adoption (if the A/B
passes) flips the default in a follow-up. The fix path (`true`) does NOT advance coordinator state in the
per-position loop — it reads the once-per-bar-resolved value.

## Step 3 — A/B (baseline-moving; direction non-obvious)

- **Identity leg:** `InpRegimeHysteresisPerBar=false` → Stats `1ed88d41` / Events `8f15fe94` / 869. MUST pass.
- **Fix leg:** `InpRegimeHysteresisPerBar=true` → net / positions / PF / Sharpe / EqDD / recovery vs baseline.
- **First-divergence attribution:** the first trade (by exit time) whose Stats row differs baseline→fix, and why.
- **Cross-feed validation:** re-run both legs on `XAUUSD_GOLDHISTORY` (Model=1) — does the fix's direction hold?
- **Adoption decision** recorded here; separate candidate commit + artifacts. Not adopted without owner greenlight.
