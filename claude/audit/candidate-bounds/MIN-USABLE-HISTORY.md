# Task D — minimum usable history at each bounds site (reconsideration basis)

Directive: *"Reconsider the byte-identical short-history bounds patch for adoption after defining the
minimum usable history at each site."*

"Minimum usable history" = the fewest H1 bars the downstream read-loop needs so that **every index it
accesses is in range**. It is `max_index_accessed + 1`. The patch's job is to `return` (skip the scan)
whenever fewer than that are available, instead of the old `<= 0` / `> 0` guard that proceeds on *any*
non-empty copy and then indexes past the (short-copied, dynamically-resized) array.

## Per-site derivation

| # | Method / file:line | Copies (requested) | Loop bound | Deepest index read | **Min usable history** | Patch guard | Guard vs min |
|---|---|---|---|---|---|---|---|
| 1 | `CTrendDetector::DetectHigherHighs` :218 | `n = swing_lookback+5` | `i < swing_lookback+3` | `high[i+2]` ⇒ `swing_lookback+4` | **`swing_lookback+5`** | `< n` | **exact** |
| 2 | `CTrendDetector::DetectLowerLows` :256 | `n = swing_lookback+5` | `i < swing_lookback+3` | `low[i+2]` ⇒ `swing_lookback+4` | **`swing_lookback+5`** | `< n` | **exact** |
| 3 | `CSMCOrderBlocks::ScanForOrderBlocks` :779-782 | `n = ob_lookback+5` | `i < ob_lookback` | `high[i+1]`/`low[i+1]` ⇒ `ob_lookback` | **`ob_lookback+1`** | `< n` | safe, **+4 conservative** |
| 4 | `CSMCOrderBlocks::ScanForFairValueGaps` :848-849 | `n = ob_lookback` | `i < ob_lookback-2` | `high[i+2]`/`low[i+2]` ⇒ `ob_lookback-1` | **`ob_lookback`** | `< n` | **exact** |
| 5 | `CSMCOrderBlocks::DetectSwingPoints` :889-890 | `n = ob_lookback` | `i < bars-lookback` | `high[i+lookback]` ⇒ `bars-1` | **`ob_lookback`** | `< n` | **exact** |
| 6 | `CSMCOrderBlocks::ScanForLiquidityPools` :1019-1021 | `n = ob_lookback` (from shift 1) | `i < bars-1`, `j < bars` | `high[j]`/`time[i]` ⇒ `bars-1` | **`ob_lookback`** | `< n` | **exact** |
| 7 | `CAdaptiveTPManager::UpdateATRHistory` :399 | `n = m_atr_history_size` | `i < m_atr_history_size` | `atr_buffer[i]` ⇒ `size-1` | **`m_atr_history_size`** | `>= n` | **exact** |

## What the derivation proves

1. **Six of seven guards are the exact minimum** — the new guard fires precisely when the loop would
   otherwise read out of range, and never sooner. No usable history is discarded.
2. **Site 3 is conservative by 4 bars** — it requires `ob_lookback+5` but the loop only needs `ob_lookback+1`.
   This over-strictness is *harmless and desirable*: the only inputs it rejects are histories of length
   `ob_lookback+1 … ob_lookback+4`, i.e. the first 1–4 bars of an ultra-short symbol, exactly the warm-up
   window where order-block detection has no meaningful context anyway. Keeping the uniform "require the
   full requested copy" convention is cleaner and maintainable; it is byte-identical wherever full history
   exists.
3. **The old guards are genuinely unsafe on truncated history — Site 7 is the sharp case.** `CopyBuffer`
   into a *dynamic* `AS_SERIES` array resizes the array to the **copied** count, not the requested count. A
   partial copy of `k < m_atr_history_size` bars leaves `atr_buffer` with `k` elements, yet the averaging
   loop unconditionally reads `atr_buffer[0 … m_atr_history_size-1]` → **array-out-of-range** (a critical
   runtime error that aborts `OnTick`). The old `> 0` guard permits exactly this. The patch's
   `>= m_atr_history_size` forecloses it. Sites 1–6 have the same shape via the `<= 0` guards.

## Reconsideration verdict

The prior DO-NOT-ADOPT rested on a single failed gate: ACCEPTANCE-2 could not *reproduce a tester halt*,
because the MT5 tester warm-loads full symbol history so the truncation never occurs in backtest. The
min-usable-history derivation reframes the benefit correctly: this is **not** a backtest-failure fix (there
is none) but a **proven-latent live-robustness hardening** — the guards now provably match the exact minimum
history each site needs, and the old guards provably OOB on any real short copy (fresh/newly-listed symbol,
post-gap history, a broker serving limited bars, or a lookback config larger than available history).

That is the **identical profile on which SL-sync was just adopted**: byte-identical on the shipped backtest,
a genuine correctness + live-robustness improvement, risk-neutral. For consistency and correctness,
**ADOPT** — verified byte-identical on the *new* baseline (`d6549628` / $34,940.18) first, since the SL-sync
adoption changed `CPositionCoordinator` (disjoint from these three files, so identity is expected but must be
proven, not assumed).
