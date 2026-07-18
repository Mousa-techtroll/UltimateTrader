# QA-sweep Lane 3 — Entry-signal pipeline / arbitration / confirmation

Read-only forensic audit. Domain: engine poll loop, single-winner arbitration, pending-confirmation
path, sleeve/file bypass paths, funnel reconciliation. Focus files: `CSignalOrchestrator.mqh`,
`CTradeOrchestrator.mqh`, `UltimateTrader.mq5`.

## Effective config (config of record proxy: `claude/audit/canonical-production.set`; risk_R90.ini absent from tree)
All values below are the *effective* values I reasoned against (default merged with the .set override):

| Input | Effective | Consequence for this lane |
|---|---|---|
| `InpSignalSource` | 2 = BOTH | pattern plugins registered; file path live in code (but no CSV → 0 file fills) |
| `InpEnableConfirmation` | true | confirmed path ACTIVE — **57% of baseline fills** (532/928, see F0) |
| `InpConfirmationWindowBars` | 1 | single-bar window → pending resolved before next signal → **0 pending overwrites** |
| `InpSoftRevalidation` | false | FULL revalidation on confirmed path (`RevalidatePending`) — near-inert (F4) |
| `InpMaxPositions` / `InpMaxTradesPerDay` | 5 / 5 | poscap + daily budget |
| `InpEnableShockDetection` | **true** | shock gate LIVE — immediate-only (F1) |
| `InpEnableSessionQualityGate` | **true** | session-quality block LIVE — immediate-only (F1) |
| `InpEnableThrashCooldown` | **true** | thrash gate LIVE — immediate-only (F1) |
| `InpMaxSpreadPoints` | 50 | spread gate LIVE — immediate-only, no executor backstop (F1/F2) |
| `InpMinSLToSpreadRatio` | 3.0 | entry-sanity SL≥3×spread LIVE — immediate-only (F1) |
| `InpNewsFilterEnable` | false | news gate OFF on BOTH paths (confirmed re-check dead → not a divergence) |
| `InpEnableConfirmedQualityFilter` | false | confirmed-only quality filter INERT (0 shadow kills) |
| `InpEnableMultiStrategy` | false | router engines NOT ranked; `GateScores_*.csv` are from a DIFFERENT run (F6) |
| `InpEnableShortSleeve` / CREV/CONT/TMF | false | sleeve engines NULL, `ExecuteSleeveSignal` never called (F5) |
| `InpEnableS3S6` / `InpEnableSessionEngine` | true / true | reg order: after MACross come S6/S3; SessionBreakout dead, SessionEngine live |

Live baseline plugins (fills, from baseline_A): PinBarEntry 416, EngulfingEntry 238, CrashBreakoutEntry 138,
MACrossEntry 61, PullbackContinuationEngine 45, ExpansionEngine 19, FailedBreakReversal 11. (No router
engines, no SessionEngine/SessionBreakout, no file/sleeve — confirms the config above.)

---

## FACTS — funnel (baseline_A, 928-fill legacy relative of the frozen 869 baseline; see F6 provenance)
Source: `auditEvidence/baseline_A/UltTrader_Candidates_XAUUSD+_20190101_0000.csv` (4889 audit rows, UTF-16LE),
`.../UltTrader_Stats_...csv`, and pending lifecycle from `claude/gate/tmp_shadow_2326.csv` (2023–2026 window).

```
candidate audit rows (all stages)            4889
  REJECT VALIDATOR                             532
  REJECT VOLUME                                615
  REJECT CONFIDENCE                            103
  REJECT QUALITY                               361
QUALIFIED (QUALITY|PASS)                      1663
  → arbitration discards (F3)                   48   (47 multi-cand bars; 46×2, 1×3)
winner-bars (FINAL|WINNER, 1 per bar)         1615
  → winner→fill shortfall                      687   (dominated by confirmation-window exhaustion)
FILLS                                          928   (immediate 396 + confirmed 532)
```
Pending lifecycle (shadow log, 2023–2026, reconciles exactly 675 = 328+6+341):
```
CREATED                675
  EXEC (→fill)         328   (48.6% of pendings convert)
  EXEC_FAIL              6   (executor reject: cluster/exposure)
  KILL                 341
    CONFIRM_WINDOW_EXHAUSTED   317   (93% of kills — confirmation candle never confirmed in 1 bar)
    EXTENSION_72H               18   (confirmed-path long-extension filter — ACTIVE, material)
    GUARD_STALENESS              5   (market-closure gap staleness guard)
    REVALIDATE_FAIL              1   (revalidation gate near-inert)
    GUARD_HALT_OR_BUDGET         0
    GUARD_POSCAP                 0
    OVERWRITTEN                  0   (impossible at window=1)
```
**The confirmation gauntlet — not arbitration — is the entry funnel's dominant leak.** Confirmation-window
exhaustion alone kills 47% of pending signals (INTENDED — the confirmation candle IS the quality gate).

---

## Findings (ranked by severity × frozen-baseline impact)

### F1 — BUG (divergent gate chain): the confirmed path admits entries that the immediate path would BLOCK — for 5 gates that are all LIVE on the baseline, on the path that carries 57% of fills
**Evidence.** Immediate path pre-flight (`UltimateTrader.mq5:2726→2810`, section 3) runs, before executing a
fresh signal: shock (`:2739-2759`, extreme→`shock_blocked`), session-quality block (`:2762-2769`,
`quality<InpExecQualityBlockThresh`→`shock_blocked`), spread (`:2789` `CheckSpreadGate()`), thrash
(`:2794` `IsRegimeThrashing()`), and entry-sanity SL≥3×spread (`:2919-2938`). The **confirmed path**
(`:2456-2573`) runs a *different* gate set: it re-checks only halt/budget (`:2488`), poscap (`:2503`),
extension (`:2512`), confirmed-quality-filter (`:2533`, inert), and news (`:2542`). It contains **no shock,
no session-quality, no spread, no thrash, and no SL-to-spread sanity** check before
`ProcessConfirmedSignal` (`:2573` → `CTradeOrchestrator.mqh:953` → `ExecuteSignal`).

The maintainers already recognised this exact hazard class and re-added the news gate to the confirmed
path with the rationale (`:2538-2541`): *"confirmations execute OUTSIDE the gated chain, so without this
check a signal born on a clean bar can fill INSIDE a news window 1-2 bars later."* That rationale applies
**verbatim** to shock, session-quality, spread, and thrash — which were left un-re-added. Effective config
has all four ON (`InpEnableShockDetection/SessionQualityGate/ThrashCooldown=true`, `InpMaxSpreadPoints=50`,
`InpMinSLToSpreadRatio=3.0`), so the divergence is **live, not latent**.

**Failure scenario.** Engulfing/PinBar/MACross long qualifies on a clean H1 bar → stored pending. Next H1
bar prints an extreme volatility shock (or a >2×/4h regime-thrash, or spread blows past 50pts). A fresh
signal that bar is blocked by `shock_blocked`/thrash/spread; the CARRIED pending is confirmed and fills at
full pattern risk with none of those gates consulted. 532 of 928 baseline fills (57%) and 328 confirmed
fills in 2023–2026 traversed this ungated path.

**Tag: BUG (gate-parity oversight).** The direction of PnL impact is not determinable from artifacts (a shock/thrash bar can be a good or bad entry), so this is a correctness/consistency defect, not an asserted PnL loss.

**Fix sketch.** Hoist the four block conditions the immediate path computes (extreme-shock, session-quality
< block threshold, `!CheckSpreadGate()`, `IsRegimeThrashing()`) and the SL-to-spread sanity into a shared
`PassEntryPreflight()` helper called by BOTH the confirmed branch (before `ProcessConfirmedSignal`) and the
immediate branch — exactly as `ShouldBlockLongExtensionCore` is already shared between the two paths. Do
NOT port the SIZING reducers (see note under F1a).

**Baseline impact.** WOULD change 869/$34,858.89 **iff** any confirmed fill landed on a blocked bar. FACT:
the structural exposure (57% of fills ungated). HYPOTHESIS: the count of mis-admitted fills — requires
instrumentation (see "Instrumentation needed").

#### F1a — INTENDED (do not conflate with F1): the confirmed path also omits the SIZING reducers, and that is deliberate
`shock_factor`/`sq_factor` (`:2905-2917`), session risk multiplier (`:2851-2881`), Wednesday/ATR-velocity/
quality-trend-boost are all immediate-only. `:2568-2570` documents this: *"Session scaling NOT applied to
confirmed signals… Adding it caused -27% PnL."* Keep this exclusion. F1 is strictly about the **block**
gates, not the sizing multipliers.

### F2 — BUG (false-safety comment): P2-08 claims the executor has its own spread check; it does not
`UltimateTrader.mq5:2781-2784` asserts *"The executor (CTradeExecutor) also has its own internal spread
check at execution time."* Verified false: the only spread REJECT is `CheckSpreadGate()`
(`CEnhancedTradeExecutor.mqh:2068-2082`, rejects on `m_max_spread_points`), and it is invoked from exactly
one call site — `UltimateTrader.mq5:2789`, the immediate pre-flight. `ExecuteTradeWithRetries` /
`ExecuteTrade` / `ExecuteTradeAttempt` never call it and never reject on spread (the spread reads at
`:2130`/`:2239` feed shock/session-quality sampling, not a gate). So there is **no execution-time spread
backstop for the confirmed, sleeve, or file paths** — the spread limb of F1 has no safety net, contrary to
the code's own comment. Side effect: `CheckSpreadGate()` also appends to `spread_samples[]`, so the shock
`spread_ratio` / session `spread_stability` baselines are only fed on ticks the immediate pre-flight runs.
**Tag: BUG (documentation asserts a guard that isn't there).** **Fix sketch:** either add a spread reject
inside `ExecuteTradeAttempt` (covers all paths), or delete the misleading comment and cover spread via the
F1 shared preflight. **Baseline impact:** same as F1's spread limb.

### F3 — BENIGN/INTENDED (hypothesis CLOSED with counts): single-winner-per-bar arbitration starvation is small and merit-based, not high-frequency crowding
`CSignalOrchestrator.mqh:459-958` collects-and-ranks; the strict `>` at **`:903`**
(`signal.qualityScore > best_quality_score`, `best` init -1) keeps one winner per bar and, on ties, the
**earliest-registered** plugin wins (loop iterates `m_entry_plugins` in registration order;
`UltimateTrader.mq5:1260-1494`). Engulfing is registered index 0 (`:1260`) → wins all ties.

FACTS (baseline_A Candidates CSV): over 2019–2026, **47** bars had ≥2 qualified candidates (46×2, 1×3) →
**48** validated candidates discarded by arbitration = **2.9% of the 1663 qualified**. Winners on those
bars: Engulfing 36, PinBar 11 — i.e. the winner carried the highest qualityScore (A+ Engulfing = 10), not
merely earliest registration. Most-starved validated engines: MACrossEntry 13, CrashBreakoutEntry 13,
PinBar 12, PullbackCont 7, Expansion 2, S6 1. The high-frequency PinBar (45% of the book) does **not**
dominate starvation — it loses more collisions (12) than it wins (11). **No high-frequency engine is
crowding out a validated one at material scale.** The registration-order tie-break is order-sensitive but
immaterial at 48 lifetime discards. **Tag: BENIGN.** No fix warranted. **Baseline impact:** none (rescuing
48 setups over 7.5y is not a lever; and a pending-bound winner would still discard the same losers).

### F4 — BENIGN (verified): the confirmed path's re-added guards and the divergence hazards MAP2 flagged are all null on baseline
- Halt/budget (`:2488`) and poscap (`:2503`) re-checks: **0** shadow kills each — the earlier same-tick
  fill never halted/capped before a confirmed fill (matches the source's own "baseline counts are 0").
- Pending OVERWRITE starvation: **0** (window=1 → stage-7 pending processing resolves the pending before
  stage-9 can store a new one; `StorePendingSignal` overwrite path `:1289-1294` is unreachable here).
- Extension-filter wording divergence (MAP2 #6): NOT present — both paths call the single core
  `ShouldBlockLongExtensionCore` (`UltimateTrader.mq5:431`); the immediate site uses a thin wrapper
  (`:491-501`). Identical logic.
- Full revalidation double-jeopardy (`RevalidatePending` `:1167-1228`, re-runs the trend/MR validator):
  near-inert — **1** REVALIDATE_FAIL in 675 pendings. Not a funnel leak; window-exhaustion is.

### F5 — BENIGN (verified): sleeve + file bypass paths respect caps as-mutated, but are dead on baseline
The CREV/CONT/TMF sleeve drivers (`UltimateTrader.mq5:3121-3169`) and the file path (`:3256-3339`) run
AFTER the confirmed (stage 7) and immediate (stage 12) entries in the same tick, and each reads
`GetBaselinePositionCount`, open-risk, `IsTradingHalted`, `CanTrade` **as mutated by whichever fired
first** — ordering is correct. `ExecuteSleeveSignal` (`CTradeOrchestrator.mqh:1194-1357`) enforces sleeve
poscap, slot-reserve (`GetBaselinePositionCount > InpMaxPositions - InpSleeveSlotReserve`), sleeve
total/family risk caps, sleeve+account halts, then routes through `ExecuteSignal` so the `InpMaxTotalExposure`
ceiling (which DELIBERATELY counts sleeve risk, `:640-647`) still binds. It intentionally does NOT consume
the daily trade budget (documented). The file path gates on poscap+halt+`CanTrade` (daily budget). **All
moot on the config of record:** sleeve masters off → `g_crev/cont/tmfEntry == NULL` (`:1327-1372`) → drivers
dead; no signal CSV → 0 file fills (Stats Source = 100% SIGNAL_SOURCE_PATTERN). **Tag: BENIGN.** No baseline
impact. (If sleeve/file are ever enabled, re-audit: the sleeve exposure ceiling is the ONLY cap that sees
sleeve risk on the baseline path — a same-tick sleeve fill can rescale/reject a later baseline entry via
`GetTotalOpenRiskPct`, which is by design.)

### F6 — FACT (reconciliation caveat + provenance): the archived CSVs do NOT reconcile to the frozen 869 baseline
- The frozen baseline artifacts (`baseline-session-breakout-utc-34858`, Stats md5 `1ed88d41`, Events
  `8f15fe94`, 869 positions) are **not present in the working tree** (checked `Logs/`, `auditEvidence/`,
  `claude/gate/`; no md5 match).
- `claude/gate/{Stats,TradeEvents,GateScores}_*.csv` are from a **multi-strategy engine run**
  (`InpEnableMultiStrategy=true`: `GateScores` has EngineName=ReversalSweepEngine/TrendContinuationEngine;
  1264 ENTRY_OPENED across years) — a DIFFERENT config than the 869 baseline. Do not reconcile 869 against
  these.
- `auditEvidence/baseline_A` is the closest available legacy relative: **928** fills, pre-dating the shipped
  DST-1/crash-freshness/Engulfing-death-cross/PBC-A/Engulfing-A fixes that trimmed 928→869. The funnel in
  this report is baseline_A's; its **structure** (arbitration ~2.9% loss; confirmation-window exhaustion as
  the dominant leak; 57% confirmed-fill share) transfers to the 869 baseline, but the absolute counts do not.

---

## Instrumentation needed (to convert F1/F6 hypotheses to facts)
1. **F1 mis-admit count.** Stamp, on every confirmed EXEC, the immediate-path block booleans evaluated at
   the confirmation bar (`shock.is_extreme`, `session_quality<block`, `!CheckSpreadGate()`,
   `IsRegimeThrashing()`, SL<3×spread). Count confirmed fills where any is true → the exact number of fills
   F1's fix would remove, and their realized R → the PnL delta. Cheap: reuse the `AUDIT_BUILD`
   behavior-neutral pattern (MAP3); no decision change.
2. **F6 reconciliation.** Re-run the frozen 869 config with `Candidates` + shadow-pending logging on to get
   candidate→qualified→winner→pending→fill for the actual baseline (the 4889/1663/1615/928 numbers here are
   baseline_A's).
