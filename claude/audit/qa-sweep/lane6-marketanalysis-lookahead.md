# Lane 6 — Market analysis / regime / indicator correctness + LOOK-AHEAD

Read-only forensic sweep. Domain: `Include/MarketAnalysis/*` (CMarketContext + 7 sub-components +
CBearStateModel/Ledger) and the shift-0 look-ahead spot-checks in the entry engines named by MAP 2.
Effective config verified against real run inis (`auditEvidence/baseline_A/audit_baseline_A.ini`,
`.../risk125_full/...`): **InpEnableMomentum=false, InpEnableVolRegime=true, InpEnableSMC=true,
InpEnableMultiStrategy=false, InpEnableS3S6=true, InpBearStateSource=COMPUTED** (source defaults in
`UltimateTrader_Inputs.mqh:87,177,195,223,547,694`). Baseline = `baseline-session-breakout-utc-34858`
(869 pos / $34,858.89).

## HEADLINE VERDICT (FACT): NO look-ahead in the market-analysis layer

Every gate-feeding computation reads the CLOSED bar `[1]` (or older) or the live tick; no decision reads
future data. The FIX 1.x/Phase-1.2 "forming→closed bar" campaign covered the decision path. The two
shift-0 stragglers that remain (§2 vol-regime, §3 momentum) read the *current forming* bar — **current
data, not future** — are captured once per bar at bar-open and cached, so they cannot repaint intra-bar
and are not look-ahead. This confirms MAP 2's "largely CLEAN" and upgrades it: the spot-check list is
clean too.

### Spot-check engine table (MAP 2 targets) — does index [0] feed the gate?

| Engine:line | Copy | Decision reads | Verdict |
|---|---|---|---|
| `CDisplacementEntry.mqh:148` | ATR shift0 x3 | `atr_buf[1]`; pattern bar[1..], sweep i≥2; entry=live ASK | CLEAN |
| `CEngulfingEntry.mqh:153` | ATR shift0 x2 | `atr_buf[1]`; engulf close[2]/open[2]/close[1]/open[1] | CLEAN |
| `CExpansionEngine.mqh:657` (GetATR) | ATR shift0 x3 | `atr_buf[1]` | CLEAN |
| `CExpansionEngine.mqh:906/916` (squeeze) | BB/Keltner shift0 x3 | `bb_*[1]`, `kelt_*[1]`; breakout close[1]/open[1]/high[1]/low[1] (950-976) | CLEAN |
| `CExpansionEngine.mqh:930` | `iTime(H1,0)` | new-bar identity token only (squeeze-count once/bar) — no price | BENIGN/INTENDED |
| `CFalseBreakoutFadeEntry.mqh:188/197/212` | ATR/ADX/RSI shift0 x2 | `[1]` each; fade current_close=close[1], recent_high=max(high[1],high[2]) | CLEAN (plugin DEAD, InpEnableS3S6=true) |
| `CRangeBoxEntry.mqh:214/223` | ADX/ATR shift0 x2 | `[1]` each; current_close=close[1], confirm close[1]>close[2] | CLEAN (plugin DEAD, InpEnableS3S6=true) |
| `CMACrossEntry.mqh:147-157` | MA shift0 x3, ATR shift0 x2 | cross ma_fast/slow[2]&[1]; SL atr_buf[1] | CLEAN |
| `CLiquidityEngine.mqh:375` | ATR shift0 x2 | `atr_buf[1]` | CLEAN (engine dormant, InpEnableMultiStrategy=false) |
| `CSessionEngine.mqh:560` (GetATR) | ATR shift0 x1 | **returns `buf[0]` (forming)** | see §4 — engine DORMANT, no baseline impact |

CMarketContext own reads verified closed-bar: MA200 `[1]` (`:1254-1255`, FIX 1.9), swing `[1]`
(`:1277-1278`, FIX 1.9), 48h range `[1]` (`:1312-1313`), D1 dealing-range shift 1..lookback
(`:923,936`), DrawOnLiquidity D1/W1 shift 1 (`:978-981`), GetATRVelocity iH/iL/iC shift 1..7
(`:748-750`), GetChoppinessIndex shift 1..11 (`:772-774`). All CLEAN.

---

## RANKED FINDINGS

### 1. FACT / PASS — decision-feeding sub-components are closed-bar; CBearStateModel is look-ahead-hardened
The components whose output actually gates or sleeves entries all read `[1]`:
- `CRegimeClassifier.Update` reads adx/atr/bb/close `[1]` (`:135-160`, Fix 1.4/1.5), ATR avg over realized
  closed-bar count.
- `CTrendDetector.UpdateTimeframe` reads ma/close `[1]` (`:145-163`, Fix 1.3); strength ATR `[1]` (`:308-311`).
- `CCrashDetector` death-cross uses EMA50/EMA200 `[1]` vs `iClose(D1,1)` (`:210-219`); GetD1DeathCross uses
  the same closed `m_ema50/m_ema200` (`:395`).
- **`CBearStateModel`** (feeds CREV/CONT/TMF sleeves + orchestrator stamp — `CSignalOrchestrator.mqh:991-993`,
  `CCrevEntry.mqh:186`, `CContinuationEntry.mqh:209`, `CTMFEntry.mqh:203`) explicitly **skips the forming H1
  bar**: `RefreshBars` loops `for(i=g-1; i>=1; i--)` "Skip index 0 (the forming H1 bar)" (`:337-357`);
  `FinalizeFormingIfNewBucket` finalizes an H4/D1 bucket without reading the incomplete forming H1 bar
  (`:309-329`). This is the one sub-component that CAN drive a live decision, and it is the most carefully
  hardened. CLEAN.

**Baseline impact:** none — this is the confirmation that the 869/$34,858.89 baseline is not built on repainting.

### 2. FACT / BUG(minor) / LIVE — CVolatilityRegimeManager reads forming-bar ATR (only shift-0 read left in a live gate)
`CVolatilityRegimeManager.Update` sets `m_current_analysis.current_atr = atr_buffer[0]` (**forming bar**,
`CVolatilityRegimeManager.mqh:238`) and `UpdateATRHistory` averages the 120-bar buffer starting at index 0
(`:398-407`, includes the forming bar). This is the **only shift-0 read that still feeds a live decision**:
`GetVolatilityRegime()` → `CExpansionEngine.mqh:551-552` gates the "volatile day → displacement-only" path
on `VOL_HIGH || VOL_EXTREME`.
- **NOT look-ahead:** index 0 is current data. `Update()` is guarded once-per-bar (`:219-220`) and first runs
  at OnTick-top on the new bar (`CMarketContext.Update :389`), so `current_atr` is captured at **bar-open first
  tick** and frozen for the whole bar — no intra-bar repaint, deterministic in the Model=4 backtest.
- **Defect:** at bar open TR≈|open−close[1]| so `atr[0]≈(13·atr[1]+gap)/14`, i.e. ~5-7% below the closed
  `atr[1]`. The ratio `current/average` is deflated, occasionally under-classifying VOL_HIGH/EXTREME near the
  1.0/1.3 thresholds. Inconsistent with every other component (all moved to `[1]`). The numerator/average share
  the `[0]` convention so the ratio is internally 1.0-centered (per the ACTION-3b note `:502-510`), which is why
  it was never caught.
- **Failure scenario:** on a bar that gaps/opens hot, the regime the engine sees for that entire bar is one
  notch calmer than the last closed bar actually was; CExpansionEngine may take a non-displacement mode on a bar
  that was genuinely VOL_HIGH.
- **Fix sketch:** read `atr_buffer[1]` for `current_atr` and average `atr_buffer[1..got]` (mirror
  `CRegimeClassifier.mqh:135,152-156`). **Baseline impact: YES, small** — would shift a handful of
  CExpansionEngine mode selections; must be measured, not assumed.

### 3. FACT / BUG(latent) — CMomentumFilter reads index [0] for every indicator (dead on prod)
`CMomentumFilter.Update` reads RSI/MACD/Stoch/CCI/MFI all at index `[0]` (the **forming bar**):
`:321,324,332,335,345,348,355,362`. These feed `GetCurrentRSI()` → CSignalValidator RSI gates
(`CSignalValidator.mqh:283,300,338,341-342`) and the `momentum_score` path.
- **Dead on prod:** `InpEnableMomentum=false` ⇒ `CMarketContext.Init` never constructs `m_momentum_filter`
  (`:303-311`) ⇒ `GetCurrentRSI()` returns constant **50** (`:874-879`). So the shift-0 reads never execute and
  the CSignalValidator RSI gates are no-ops (RSI pinned to 50 → `is_extreme_overbought/oversold` both false,
  bear-regime `RSI<15` never fires). **Cross-lane note** for the validation lane: those RSI gates are inert.
- **If InpEnableMomentum is ever flipped on:** the momentum score / RSI would be the forming-bar first-tick value
  (same forming-bar staleness as §2, not look-ahead). Would need the same `[0]→[1]` conversion.
- **Baseline impact:** none today.

### 4. FACT / BENIGN — CSessionEngine.GetATR() returns forming-bar ATR (dormant engine)
`CSessionEngine.mqh:560-561` copies 1 ATR bar and returns `buf[0]` (forming) — the only spot-check engine that
*returns* index [0] rather than `[1]`. `CSessionEngine` is the dormant live-GMT-clock scaffold
(InpEnableMultiStrategy=false; session fills actually come from CSessionBreakoutEntry composed in
CExpansionEngine, per phase0-correctness). Not polled for entries on prod. **Baseline impact: none.** If ever
activated, promote to a §2-class fix.

### 5. FACT / BENIGN — CSMCOrderBlocks minor shift-0 artifacts (low decision weight on prod)
`InpEnableSMC=true` so CSMCOrderBlocks runs, but it copies scan arrays from shift 0 and mixes conventions:
- OB scan loop starts at `i=3` (forming + 2 newest bars excluded) `:788-834`; FVG loop starts at `i=1` (forming
  excluded) `:854-874` — **correctly forming-bar-free**.
- BOS/CHoCH trigger reads closed `[1]/[2]` (`:964-967`, Phase 1.2 fix) — CLEAN.
- **`DetectSwingPoints`** copies high/low from shift 0 and uses `[0]` as a **centered-window neighbor**: loop
  `i=lookback..`, inner `high[i-j]` with `j≤lookback` reaches `high[0]` (`:889-930`). The most-recent detectable
  swing (`i=lookback`, lookback=bos_lookback/2=10) is compared against the forming bar's high/low.
- **`InvalidateMitigatedZones`** reads `iClose(H1,0)` (forming) for OB touch/mitigation (`:1161`); the touch
  branch is additionally dead (`InpEnableSMCZoneDecay=false`, `:1177`). `GetCurrentATR` reads `[0]` (`:1687`).
- All run once/bar at open (via `CMarketContext.Update :386`), cached and deterministic; `[0]≈open` at that
  instant. SMC decision weight is thin on prod (SMCScore dead per quality-tier memory; confluence floor hardcoded
  `<40` in `CSignalValidator.mqh:198`; `m_smc_min_confluence` is a documented dead store `CMarketContext.mqh:184`).
- **Fix sketch:** copy the swing/mitigation scanners from shift 1 (as BOS already does). **Baseline impact:**
  plausibly near-zero; would need a measured run to confirm SMC gates it anywhere live.

### 6. FACT / BENIGN (dead in tester) — CMacroBias real DXY/VIX path reads forming H4 bar
`AnalyzeDXY`/`AnalyzeVIX` read shift-0 forming H4 bars: `CopyClose(DXY,H4,0,1)` `:204`, DXY MA `[0]` `:205`,
`CopyHigh(DXY,H4,0,30)` `:222`, `CopyClose(VIX,H4,0,1)` `:265`. In the XAUUSD+ tester the DXY/VIX symbols are
unavailable ⇒ `m_dxy_available=m_vix_available=false` ⇒ Update takes `AnalyzePriceFallback` which reads the
**closed** bar `[1]` (`:315-323`, EMA200 D1[1], H4 slope [1] vs [2], with a documented live-BID front-run for
the vs-200 test). So the forming-bar reads are unreachable in the backtest. **Baseline impact: none.**
Live-only correctness note: the real DXY/VIX path should read `[1]`.

### 7. FACT / INTENDED — CCrashDetector rubber-band closed-baseline + live-bid trigger
`CheckRubberBandSignal` reads EMA21/ATR/ADX baseline from closed `[1]` (`:296-305`) and triggers on the live BID
(`:312`) — a documented deliberate front-run of an over-extension against a stable mean (`:307-311`). The
death-cross regime gate (`IsBearRegime`/`GetD1DeathCross`) is fully closed-bar. INTENDED; not look-ahead.

### 8. HYPOTHESIS / BENIGN (latent) — SMC scanners guard `<= 0`, not `< requested`
`ScanForOrderBlocks/ScanForFairValueGaps/DetectSwingPoints` guard the copies with `<= 0` then index up to
`ob_lookback` (`:779-782` then loop to `high[ob_lookback]`; `:848-849,889-890`). On a warmup **short read**
(fewer than `ob_lookback+5≈55` bars copied) the loops would index past the realized count → array-out-of-range.
In practice the tester preloads ≥55 H1 bars before the test window so this never fires; contrast the FIX-campaign
`< N` guards elsewhere. **Baseline impact: none observed.** Instrumentation to confirm: an `#ifdef AUDIT_BUILD`
counter on `got < bars_to_copy` in these three methods.

### 9. FACT / BENIGN — handle refcount balance is correct; one latent constructor nit
Every CMarketContext sub-component releases exactly what it created (dtors: CRegimeClassifier `:94-96`,
CMacroBias `:61-68`, CCrashDetector `:146-150`, CTrendDetector `:54-62`, CVolatilityRegimeManager `:135-137`,
CMomentumFilter `:140-147`, CSMCOrderBlocks `:275-276`); CMarketContext releases `m_handle_ma200_h1` in Deinit
(`:432-436`). Underlying indicators created by multiple owners (e.g. `iATR(H1,14)` in Volatility, Momentum,
Trend, Crash) are MT5-refcounted — each create adds a ref, each dtor releases one → net zero, order-independent.
Confirms MAP 1's refcount-balanced note. **Latent nit:** `CTrendDetector` and `CRegimeClassifier` constructors do
NOT initialize their handle members to `INVALID_HANDLE` (only Crash/Vol/Momentum/SMC do). Their dtors guard with
`!= INVALID_HANDLE`, which uninitialized garbage passes, so a *skipped/failed* `Init()` would
`IndicatorRelease()` a garbage handle. `Init()` is always called immediately after `new` in `CMarketContext.Init`,
so unreached. **Baseline impact: none.** Fix: init handles to `INVALID_HANDLE` in both constructors.

---

## FACTS vs HYPOTHESES
- **FACTS (read from source, config-verified):** §1 (all decision components closed-bar; BearStateModel skips
  [0]), §2 (vol-regime `[0]` read, live via CExpansionEngine), §3 (momentum `[0]` reads, dead via
  InpEnableMomentum=false), §4 (SessionEngine returns `[0]`, dormant), §5 (SMC swing/mitigation `[0]`, low
  weight), §6 (MacroBias real path `[0]`, dead in tester), §7 (crash intended front-run), §9 (refcount balanced).
- **HYPOTHESES (need instrumentation to confirm impact):** §8 short-read OOB (never observed; add AUDIT counter);
  the *magnitude* of §2's baseline effect (needs a `[0]→[1]` A/B run — cannot be counted from static source).

## Baseline-moving candidates
Only **§2** could move the 869/$34,858.89 baseline, and only slightly (a few CExpansionEngine mode selections
near VOL thresholds). Everything else is dead-on-prod, dormant, intended, or latent. No repainting/look-ahead
that would inflate the baseline was found.
