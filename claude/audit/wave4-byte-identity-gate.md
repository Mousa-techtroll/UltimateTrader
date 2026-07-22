# Wave 4 — Byte-Identity Gate Result (PASSED, both feeds exact)

**Branch:** `feat/exit-momentum-platform`. **Binary:** `UltimateTrader.ex5` md5 `685f633b9cddbbba351cc311828df44e` (full platform integrated, masters OFF = canonical).
**Config:** `risk_R90.ini` as-is (canonical), no exit-platform flags passed → all new inputs default off.
**Runs:** `claude/gate/sessclock_run_gh.sh` (GH, Model 1) + `claude/gate/sessclock_run.sh` (primary, Model 4), 2019.01.01→2026.06.27.

## Result — exact match on both feeds

| Feed | Metric | Baseline anchor | This build | Verdict |
|---|---|---|---|---|
| GoldHistory | Stats md5 | `2713e2983afc3a4a0f137544de15d3d4` | `2713e2983afc3a4a0f137544de15d3d4` | ✅ EXACT |
| GoldHistory | Net / PF | $24,086.34 / 1.39 | $24,086.34 / 1.39 | ✅ |
| Primary | Events md5 | `a289b95a2903549f40d61efbf301b550` | `a289b95a2903549f40d61efbf301b550` | ✅ EXACT |
| Primary | Net / PF / Sharpe | $33,318.24 / 1.47 / 3.16 | $33,318.24 / 1.47 / 3.16 | ✅ |
| Primary | EXIT rows (positions) | 801 | 801 | ✅ EXACT |

(Primary Stats md5 differs — `d359d9d2…` — but the primary identity primitive is the **Events** md5, which matches exactly; the Stats "canonical target 865" comment in the runner is stale from the pre-drift Gold-v1 config and is not the anchor. GH's identity primitive IS the Stats md5, matched exactly.)

## What this proves
The complete dormant platform — the new enums/structs/SPosition fields, the momentum snapshotter (constructed + driven per bar when a master gate is on, NULL/skipped when off), the coordinator's immediate strategy-exit seam, the shadow telemetry sinks, and the account-safety seam — changes **nothing** in the backtest when `InpExitPolicyShadow` and `InpExitPolicyActive` are both off (the shipped default). Byte-identical to the `main` baseline, to the cent, on both feeds.

## Scope covered by this gate
Waves 0–2 (contracts + 7 builders) + Wave 1a/1b/1c/1e (construction, drive, immediate seam, telemetry, account-safety seam). **Not yet in this build:** persistence v9 + fill-stamp (Wave 1d), Contract-B trail consumption + immediate-ACT (deferred to activation). Persistence v9 is byte-identical to the backtest (state written, never read back in a tester pass; separate `.bin`, not part of the Events/Stats primitive) and will re-gate + get a `UT_` migration test.

## Next
1. Persistence v9 + v8→v9 migration + `UT_MigrationV8toV9` + fill-stamp `mom_at_entry` → re-gate.
2. Shadow campaign: `InpExitPolicyShadow=true` → re-prove identity to the cent (decision-free) → collect telemetry both feeds.
3. Attribution (`exit_attribution.py`) → blunt-widen control → trend trailing-modulation activation A/B with the full evidence pack.
