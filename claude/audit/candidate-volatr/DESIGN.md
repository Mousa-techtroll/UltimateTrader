# Candidate P1: forming-bar ATR in CVolatilityRegimeManager — semantics + design

QA finding #6 (lane 6): the only shift-0 (forming-bar) read still feeding a LIVE gate. Isolated candidate;
production stays `baseline-session-breakout-utc-34858` (`1ed88d41`) until its own adoption decision.

## Semantics — the volatility-regime gate must decide on the CLOSED bar [1]

`CVolatilityRegimeManager::AnalyzeVolatility` copies 2 ATR values (`:232` `CopyBuffer(...,0,0,2,atr_buffer)`:
`[0]`=forming bar, `[1]`=last CLOSED bar) and sets `m_current_analysis.current_atr = atr_buffer[0]` (`:238`) —
the **forming** bar. At bar open the H1 ATR of the still-forming bar is materially deflated (~5–7%; ATR of an
incomplete range), so `atr_ratio = current_atr / average` is understated and the regime **under-classifies**
(fewer VOL_HIGH/VOL_EXTREME). This is a LIVE gate: `GetVolatilityRegime()` feeds
`CExpansionEngine::IsExpansionContext` (`:551` `== VOL_HIGH || VOL_EXTREME`) — the expansion engine's
volatile-day entry branch — plus `CDayTypeRouter` and the display. Every other regime/indicator input in the
codebase decides on the closed bar `[1]` (verified in the sweep); this one is the exception.

**Intended:** the regime's `current_atr` should be the last CLOSED bar's ATR (`atr_buffer[1]`), consistent
with the rest of the market-state snapshot (which is computed once per closed bar).

## Fix (minimal, flagged, baseline-preserving)
`input bool InpVolRegimeClosedBar = false;` (default false = legacy forming-bar `[0]` = baseline; true = fix `[1]`).
Edit `:238`: `m_current_analysis.current_atr = InpVolRegimeClosedBar ? atr_buffer[1] : atr_buffer[0];`
The `CopyBuffer` already fetches 2 values so `[1]` is available; on 2019+ it always returns 2, so the identity
leg (flag=false) is byte-identical. Scope is deliberately minimal — ONLY the flagged live-gate `current_atr`
read. The `UpdateATRHistory` average (`:398-407`) includes the forming bar too, but it is an m_history_size-bar
mean (one forming bar ≈ negligible) and not the flagged gate; left out of this minimal candidate for clean
attribution (note it as a coherence follow-up).

Expected direction: the fix RAISES `current_atr` (closed > forming) ⇒ higher `atr_ratio` ⇒ MORE
VOL_HIGH/EXTREME ⇒ MORE expansion-engine volatile-day gating ⇒ baseline-moving. A/B measures net/risk.
Cross-lane note: `CMomentumFilter` is dead on prod (RSI validator gates inert) — independent of this ATR gate.

## A/B (baseline-moving)
Identity leg (false) → `1ed88d41`/869 exact. Fix leg (true) → net/PF/Sharpe/EqDD vs baseline. GoldHistory
cross-feed (sign). Entry-key first-divergence (tickets renumber). Honest adoption decision in RESULTS.md.
