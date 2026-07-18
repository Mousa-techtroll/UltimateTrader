# Candidate: short-history array-bounds fix (QA#7) — results + decision

> **RECONSIDERATION (Task D, post SL-sync baseline `d6549628` / $34,940.18): ADOPTED.**
> The directive required reconsidering this patch *after defining the minimum usable history at each site*.
> That derivation (`MIN-USABLE-HISTORY.md`) proves each new guard is the **exact** minimum (6 sites exact, 1
> conservative by 4 bars in the harmless warm-up direction) and that the old `<= 0` / `> 0` guards are
> **genuinely unsafe on a real short copy** — sharpest at `CAdaptiveTPManager::UpdateATRHistory`, where a
> partial `CopyBuffer` resizes the dynamic array shorter than `m_atr_history_size` yet the averaging loop
> still reads to `size-1` → array-out-of-range (aborts `OnTick`). That reframes the benefit from the
> unreproducible "un-break a failing run" (there is none — the tester warm-loads full history) to a
> **proven-latent live-robustness hardening at zero backtest cost** — the identical profile on which SL-sync
> was adopted. **Re-proven byte-identical on the new baseline:** BNDFIX2 primary = Stats `d6549628` /
> $34,940.18 / 869 / Events `e413cbd8` (exact); GoldHistory leg = Stats `f11c4b2c` / $29,525.79 / 820 (exact). Decision below (original
> DO-NOT-ADOPT) is **SUPERSEDED** — see `MIN-USABLE-HISTORY.md`.

---
## Original assessment (superseded by the Task-D reconsideration above)


Isolated candidate. Tightens six copy-guards so a partial CopyX can't out-of-range the read loops:
- `CTrendDetector.mqh` ~218/256: `CopyHigh/Low(...,bars_needed,...) <= 0` → `< bars_needed`.
- `CSMCOrderBlocks.mqh` ~779/848/889/1019 (11 guards): `<= 0` → `< bars_to_copy` / `< bars`.
- `CAdaptiveTPManager.mqh` ~399: `CopyBuffer(...,m_atr_history_size,...) > 0` → `>= m_atr_history_size`.
Rationale: `CopyX` returns exactly the requested count when full history exists ⇒ byte-identical where the
lookback is available; a short copy now skips gracefully instead of indexing past the resized AS_SERIES array.

## ACCEPTANCE-1 — byte-identical production: **PASS**
`sessclock_run.sh BNDFIX` (XAUUSD+, Model=4, risk_R90.ini, InpRegimeHysteresisPerBar default false):
**Stats md5 `1ed88d41` / 869 EXIT** — byte-identical to the binding baseline. The fix is a proven no-op on
the 2019+ book (full pre-history ⇒ CopyX returns the full count ⇒ unchanged behavior).

## ACCEPTANCE-2 — previously-failing cross-feed run: **NOT REPRODUCIBLE**
Lane 7's finding (six sites "halt the tester" on short history) was a **code-pattern hypothesis, not an
observed failure** (lane 7 noted no journal logs were archived to confirm it). Attempt to reproduce:
- GoldHistory data begins **2004.01.01** (earliest trade in the run). Ran the **pre-fix** binary
  (`GHHYSID`, has the imperfect guards) on `XAUUSD_GOLDHISTORY` FromDate 2004.01.01 (= the data boundary,
  where pre-history < lookback): **it COMPLETED — Total Net Profit $38,246.96, 0 array-out-of-range in the
  tester log, full report.** The **post-fix** binary (`BNDFIX`) on the same: **identical $38,246.96.**
- Conclusion: the MT5 Strategy Tester supplies the full lookback even at the data boundary (it loads all
  symbol data and warms up before the EA's first OnTick), so the imperfect `<= 0` guards **never actually
  OOB** on the available GoldHistory feed. The "previously-failing run" the fix was meant to un-break does
  not exist on this data. (The identical net + both runs lacking the EA Stats CSV confirm the missing CSV is
  a benign GH-symbol logging quirk, not a crash — the pre-fix run did not terminate early.)

## DECISION — DO NOT ADOPT (directive gate not met); byte-identical defensive hardening, held.
The directive required BOTH byte-identical production AND completion of a previously-failing run. ACCEPTANCE-1
passes; **ACCEPTANCE-2 cannot be satisfied** — there is no reproducible failing run to fix. The fix is
*strictly more correct* (the guards genuinely should require the full count) and *byte-identical everywhere
tested* (2019+ `1ed88d41`; GH-2004 $38,246.96), i.e. **zero cost, zero observed benefit**. Per the honest-
baseline discipline (no production change without a demonstrated benefit) and the directive's own dual gate,
it is **not adopted**. Retained as a documented, byte-identical defensive-hardening candidate: if a future
symbol/config is ever loaded with genuinely truncated pre-history (shorter than the tester warm-up provides),
these guards would prevent an OOB — but that condition is not present today. **Correction to lane 7: the six
OOB sites are a latent code-imperfection, NOT an active tester-halting bug.** Production baseline
`baseline-session-breakout-utc-34858` (`1ed88d41`) unchanged. Not combined with any other QA fix.
