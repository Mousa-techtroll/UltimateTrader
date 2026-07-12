# Phase-0 Reconcile — "Session" fills & dormant-strategy count (READ-ONLY forensics)

Config of record: XAUUSD H1, pattern-source, all short-dev flags OFF
(`InpShortOnlyMode/InpEnableShortSleeve/InpEnableCREV/InpEnableCONT/InpEnableTMF=false`),
`InpCrashTrailSuppress=true`, `InpRRGateSymmetric=true`.

## 0. DATA-PROVENANCE CAVEAT (read first — a fact, not a nitpick)

The archive path the task cites — `_arm_archive/ceg_SF1FULL/UltTrader_Stats_XAUUSD+_20190101_0000.csv` —
**does not exist on disk** (nor does any `_arm_archive/`, `ceg_*`, or `*SF1*` directory).
The closest surviving artifact, and the one used for every count below, is:

- `/mnt/c/Trading/UltimateTrader/auditEvidence/baseline_A/UltTrader_Stats_XAUUSD+_20190101_0000.csv`
  (byte-identical in content to `auditEvidence/baseline_B/…`; both are the A/B control leg, run 2026-07-10).
- Its run config: `auditEvidence/baseline_A/audit_baseline_A.ini` (plain ASCII, `[TesterInputs]`).
- Its report: `auditEvidence/baseline_A/audit_baseline_A.htm`.

This surviving file **does not match the task's headline numbers**:

| Metric | Task said (ceg_SF1FULL) | baseline_A/B (measured) |
|---|---|---|
| Positions (ENTRY rows) | 952 | **928** |
| Report Net Profit | $23,856.89 | **$21,623.18** (PF 1.31) |
| CSV-basis PnL | $24,378.11 | **$22,117.61** (Σ Total_PnL over 928 EXIT rows) |

So `baseline_A` is a **near-neighbour arm of the same config family, not the exact `$23,856.89` SF1FULL run** (that run's CSV is gone). It is nonetheless the correct file to answer these two questions because (a) it is the only surviving full-window run whose session-pattern counts land exactly on the task's "~12", and (b) its effective enables match the current source defaults line-for-line (verified §3), so the pattern→engine mapping and the dormant set are config-invariant across the family. Every finding below is a **code fact** (pattern→engine) or a **config fact** (enables) that does not depend on the missing $23,856.89 CSV. Counts are FACTS from `baseline_A`; if the exact SF1FULL CSV is restored, only the raw fill totals could shift by a handful — the classification will not.

Column indices in the Stats CSV (0-based): RowType=0, Pattern=3, Direction=4, Source=5, Regime=6, Quality=7, Session=8, EngineName=9, EngineMode=10, PnL_Money=44, PnL_R=45. One position = one ENTRY row + one EXIT row (928 each).

---

## 1. The "session" fills: exact strings, counts, and true source engine (FACT)

Parsing the 928 ENTRY rows, exactly **12 fills** carry session-flavored pattern strings:

| Pattern string | Count | Direction split |
|---|---|---|
| `Asian Breakout London` | **9** | 4 LONG / 5 SHORT |
| `London Continuation NY` | **3** | 1 LONG / 2 SHORT |
| **Total "session" fills** | **12** | 5 LONG / 7 SHORT |

**The CSV attributes all 12 to `EngineName = ExpansionEngine`, `EngineMode = MODE_LONDON_BREAKOUT`, `Source = SIGNAL_SOURCE_PATTERN`** — NOT to `SessionEngine` and NOT to a standalone `SessionBreakout`. `SessionEngine` and standalone `SessionBreakout` appear **zero** times in the EngineName column.

### Why the string says "session" but the engine says "Expansion"

The pattern strings are authored in **`CSessionBreakoutEntry`**, but the signals are **emitted through `CExpansionEngine`**, which *composes* a `CSessionBreakoutEntry` instance as an internal sub-strategy and re-stamps the owner fields. Chain:

- **String origin** — `Include/EntryPlugins/CSessionBreakoutEntry.mqh`:
  - `:373` and `:414` → `signal.comment = "Asian Breakout London";` (bullish / bearish)
  - `:506` and `:548` → `signal.comment = "London Continuation NY";` (bullish / bearish)
- **Composition + emission** — `Include/EntryPlugins/CExpansionEngine.mqh`:
  - `:384` constructs the sub-strategy unconditionally in `Initialize()`: `m_session_breakout = new CSessionBreakoutEntry(m_context);`
  - `:520-529` "Priority 5: Session Breakout" — calls `m_session_breakout.CheckForEntrySignal()`, then **overwrites `signal.engine_mode = MODE_LONDON_BREAKOUT`** (`:526`), then `TagAndScore(signal)` (`:530`).
  - `:148` `GetName()` returns `"ExpansionEngine"` — this is what the Stats writer records as EngineName.
  - The composed sub-strategy is **not gated by `ConfigureModes`** (which only sets `m_enable_ic`/`m_enable_compression`); it fires whenever `IsExpansionContext()` is true (`:498-529`, `IsExpansionContext` at `:557+` = VOL_HIGH/EXTREME or expanding AND non-neutral H4 trend). This is why it fires even though every `InpSession*` mode flag is false.

**Reconciliation (the precise answer to "census wrong vs pattern mislabeled"):** *Neither framing is exactly right.* The census's claim that **`CSessionEngine` is mute is TRUE** (it produced 0 fills — §3). The pattern string is **not** mislabeled — those 12 trades really are Asian-range/London-open breakout setups. They are simply emitted by a **different, LIVE engine (`CExpansionEngine`) that reuses the `CSessionBreakoutEntry` class as a composed sub-strategy**, so they wear an "ExpansionEngine / MODE_LONDON_BREAKOUT" nameplate. Session-breakout *logic* is alive and trades 12×; the *engine the docs call "the Session engine"* (`CSessionEngine`) is genuinely dormant.

---

## 2. Authoritative registered-engine → fill-count table (FACT)

Every `RegisterEntryPlugin(...)` call in `UltimateTrader.mq5` evaluated against the effective config
(`audit_baseline_A.ini`). "Enabled?" = the boolean actually passed to `RegisterEntryPlugin`.

| # | Plugin (GetName) | mq5 reg line | Effective enable gate | Enabled? | Fills | Status |
|---|---|---|---|---|---|---|
| 1 | PinBarEntry | 821 | `InpEnablePinBar(true) && register_patterns(true)` | ✅ | **416** | LIVE (209 bear + 207 bull) |
| 2 | EngulfingEntry | 820 | `InpEnableEngulfing(true) && rp` | ✅ | **238** | LIVE |
| 3 | CrashBreakoutEntry | 877 | `InpEnableCrashDetector(true) && g_profileEnableCrashBreakout && rp` | ✅ | **138** | LIVE (Rubber Band short) |
| 4 | MACrossEntry | 823 | `InpEnableMACross(true) && rp` | ✅ | **61** | LIVE |
| 5 | PullbackContinuationEngine | 997 | `if(InpEnablePullbackCont(true) && rp)` → reg `true` | ✅ | **45** | LIVE |
| 6 | ExpansionEngine | 984 | `if(InpEnableExpansionEngine(true) && rp)` → reg `true` | ✅ | **19** | LIVE = **12 composed Session-BO (MODE_LONDON_BREAKOUT) + 7 IC-Breakout-Long** |
| 7 | FailedBreakReversal (S6) | 842 | `register_patterns` (inside `InpEnableS3S6=true`) | ✅ | **11** | LIVE |
| 8 | RangeEdgeFade (S3) | 847 | `register_patterns` (inside `InpEnableS3S6=true`) | ✅ | **0** | **DORMANT** |
| 9 | VolatilityBreakoutEntry | 868 | `InpEnableVolBreakout(true) && rp` | ✅ | **0** | **DORMANT** |
| 10 | DisplacementEntry | 943 | `InpEnableDisplacementEntry(true) && rp` | ✅ | **0** | **DORMANT** |
| 11 | LiquidityEngine | 964 | `if(InpEnableLiquidityEngine(true) && rp)` → reg `true` | ✅ | **0** | **DORMANT** |
| 12 | SessionEngine | 976 | `if(InpEnableSessionEngine(true) && rp)` → reg `true` | ✅ | **0** | **DORMANT** (all 4 sub-modes off) |

Live-fill reconciliation: 416+238+138+61+45+19+11 = **928** ✅ (matches ENTRY-row count and the EngineName Counter exactly). `Source` is `SIGNAL_SOURCE_PATTERN` for all 928.

**Registered-but-NOT-enabled (a different category — not counted as "dormant registered"):**
- `LiquiditySweepEntry` — `InpEnableLiquiditySweep=false` (mq5:822) → not enabled.
- `RangeBoxEntry`, `FalseBreakoutFadeEntry` — registered `false` (mq5:850-851) because `InpEnableS3S6=true` routes into the S3/S6 branch.
- **Standalone `SessionBreakout` (`g_sessionBreakout`)** — mq5:947-948 wraps its registration in `if(!InpEnableSessionEngine)`; since `InpEnableSessionEngine=true`, **the registration is skipped entirely** (source comment at mq5:946: "inert on prod — SessionBreakout DEAD when InpEnableSessionEngine=true"). It never enters `g_entryPlugins`. (Note: this is the *standalone* instance; the *composed* instance inside CExpansionEngine is the one that trades — §1.)
- `TrendContinuationEngine / ReversalSweepEngine / RangeReversionEngine` — inside `if(InpEnableMultiStrategy)` (mq5:1010), and `InpEnableMultiStrategy=false` → never `new`-ed.
- `FileEntry` — constructed only for FILE/BOTH source and runs outside the orchestrator; its CSV is absent → 0.

---

## 3. Corrected dormant list + count + per-engine mechanism (FACT + mechanism)

**Dormant count = FIVE, not four.** The five registered-AND-enabled entry plugins that produced zero fills across the full 2019–2026H1 window are:

| Dormant plugin | Effective enable | Mechanism it never fires (file:line) |
|---|---|---|
| **RangeEdgeFade (S3)** | `InpEnableS3S6=true` → registered | Requires a *validated* range box + no stealth-trend + M15 sweep-and-reclaim at box edge + RSI extreme + ≥2:1 room (`CRangeEdgeFade.mqh:113-140+`). Conjunction never true on gold H1/M15 in 7.5y. |
| **VolatilityBreakout** | `InpEnableVolBreakout=true` → registered | `IsCompatibleWithRegime()` returns true **only** for `REGIME_VOLATILE` (`CVolatilityBreakoutEntry.mqh:153`), then still needs ADX≥25 + H4 EMA-stack + Donchian/Keltner break. Also composed inside CExpansionEngine (`CExpansionEngine.mqh:371,502-517`) and fired 0 there too. |
| **Displacement** | `InpEnableDisplacementEntry=true` → registered | Needs a sweep + a displacement candle with body ≥1.8×ATR closing beyond the swept level in TRENDING/VOLATILE H4 (`CDisplacementEntry.mqh:192-230`). Non-existent on H1 gold in-window. |
| **LiquidityEngine** | `InpEnableLiquidityEngine=true` → registered (mq5:959-964) | Displacement mode shares the 1.8×ATR-body problem; OB-Retest needs price inside a prior IC zone + bullish H1 structure + rejection, stands aside on DATA days (`CLiquidityEngine.mqh:~104+`). Net output 0. |
| **SessionEngine** | `InpEnableSessionEngine=true` → registered `true` (mq5:968-976) | `ConfigureModes(InpSessionLondonBO, InpSessionNYCont, InpSessionSilverBullet, InpSessionLondonClose, …)` at mq5:975 with **all four = false** (ini AND source default `UltimateTrader_Inputs.mqh:387-390`, comments "DISABLED: 0% WR"). Every mode gate is off → emits nothing. Kept loaded as the GMT clock / Asian-range builder. |

Effective-vs-default check (ini overrides land on the SAME value as source defaults, so no `.set`-cache ambiguity):
`InpEnableSessionEngine=true` (dflt Inputs.mqh:386), `InpSessionLondonBO/NYCont/SilverBullet/LondonClose=false` (dflt :387-390),
`InpEnableExpansionEngine=true` (:397), `InpExpInstitutionalCandle=true` (:398), `InpExpCompressionBO=false` (:399),
`InpEnableLiquidityEngine=true` (:378), `InpEnableVolBreakout=true` (:150), `InpEnableDisplacementEntry=true` (:363),
`InpEnableS3S6=true` (:88), `InpEnablePullbackCont=true` (:412), `InpEnableMultiStrategy=false` (:549), `InpEnableSessionBreakout=true` (:364, but neutralized by the `!InpEnableSessionEngine` guard).

**Why the "4 vs 5" premise is refuted:** the task's reasoning ("if Session fired 12×, dormant = FOUR") assumes the 12 session fills came from `CSessionEngine`. They did not — they came from `CExpansionEngine` (already among the 7 LIVE plugins, row 6 above). `CSessionEngine` itself fired **0**. So it stays in the dormant set and the count remains **FIVE**. The 12 fills do not move any plugin between the live and dormant columns.

---

## 4. What to correct in the two docs (one paragraph)

**`workflowAnalysis/entry-strategies-report.md`** is mostly right — line 47 already counts five dormant, and line 39 already books the 19 fills (split shown as 12/7 long/short) under Expansion — but it has two precision defects to fix: (a) **line 147 is factually wrong** — "the EA has no live session-breakout of any kind — Asian-range/London-open logic exists in three places and trades in none" — it trades in **one** of the three (the `CSessionBreakoutEntry` instance *composed inside* `CExpansionEngine`, `CExpansionEngine.mqh:384,520-529`), producing **12 fills**: 9 "Asian Breakout London" + 3 "London Continuation NY"; and (b) the Expansion rows (line 39 header "IC mode only", §2.6 line 116) should be relabeled **"IC mode + composed Session-Breakout sub-strategy (MODE_LONDON_BREAKOUT)"**, noting that only 7 of its 19 fills are IC-Breakout-Long and the other 12 are the session-breakout sub-strategy (5 long / 7 short). No change to the dormant count (5) or the 928-fill reconciliation. **`workflowAnalysis/ea-book/03-the-scouts.html`** needs the same disclosure in narrative form: the "Expansion" scout (≈lines 205-211, currently pure "quiet-then-explosive" IC/compression breakout) should say it also runs a composed Asian-range/London-open **Session-Breakout** sub-strategy that is the source of ~63% of its trades; and the "Session engine — Off" card (lines 195-203) should keep its "off/0-WR" claim for `CSessionEngine` but add one clause that session-breakout *logic* nonetheless trades **inside the Expansion engine** — otherwise a reader concludes gold's session-breakout book is dead when it actually contributes 12 fills. The chapter's headline arithmetic (line 237: "five of the twelve produced zero … really about seven scouts") is **correct and needs no change**.
