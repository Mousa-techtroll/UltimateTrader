# Runtime Diagnostics Results (AUDIT_BUILD, behavior-neutral)

Captured from a full 2019-2026 run of the AUDIT_BUILD binary on the 388-pin config, pinned tick
cache. The counters are decision-free: both the production (diagnostics compiled out) and audit
(diagnostics active) binaries reproduced Stats md5 `96415ff0` + TradeEvents md5 `9c08bcfa` — proven
behavior-neutral.

| Diagnostic | Count | Interpretation |
|---|---|---|
| BE trigger flat / stamped (CPositionCoordinator:3200) | **0 / 0** | The trailing-loop BE resolution is never reached (BE is implicit; InpEnableBEMover=false). The flat `InpTrailBETrigger` is not consumed here. (Active BE-move is the anti-stall path at :3920, gated by InpEnableAntiStall — not this site.) |
| TP1 flat / stamped | **0 / 93,789,845** | The flat `InpTP1Distance/Volume` (and by extension TP0/TP2) fallback is **NEVER consumed** — every position carries a stamped regime exit profile (`exit_tp*>0`). |
| Chandelier live-regime / smoothed / flat-pre-hysteresis | **85,635,949 / 8,153,895 / 1** | The flat `InpTrailChandelierMult` default is the effective value **exactly once** (first evaluation). Thereafter always live-regime or smoothed-previous. Effectively dead. |
| VIX usable-bars / data-starved | **44,267 / 0** | `AnalyzeVIX` CopyClose returned usable H4 bars on **every** call — **VIX IS LIVE** on the tester feed. |

## Corrections to prior findings
- **VIX is NOT data-starved.** The earlier "VIX resolves but 21 bytes → contributes 0" was wrong: the
  macro VIX leg computes a real -1/0/+1 from live VIX H4 data on all 44,267 calls. → `InpVIXElevated`
  (20) and `InpVIXLow` (15) are **live, material** inputs (like DXY), not dormant. Ledger note updated.
- **The Flat/fallback exit set is effectively dead** (BE 0, TP 0, Chandelier 1 of ~93.8M). This refines
  the exit-profile design audit: the flat set is NOT a NORMAL duplicate (values differ) AND is
  essentially never the effective value → it is a **dead-fallback deprecation candidate** (a future
  gated-off-style, identity-preserving cleanup — prove reachability then const-deprecate), NOT a merge.
