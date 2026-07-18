# Authoritative input-count reconciliation (post SL-sync adoption)

Closes the directive item *"Reconcile the authoritative input count and canonical .set afterward."*

## Two different counts — do not conflate them

| Count | Value | What it is |
|---|---|---|
| Raw `input` decl lines in source | **411** | Every `input …` line, including BOTH branches of the two `#ifdef RESEARCH_CANDIDATES … #else …` guards and every `input group "…"` panel separator. Double-counts the guarded flags. |
| Production-effective `input` lines | **409** | What the preprocessor emits when `RESEARCH_CANDIDATES` / `AUDIT_BUILD` / `RESEARCH_SESSION` are **absent** (the production compile). = 411 − 2 guarded-out flags (`InpVolRegimeClosedBar`, `InpRegimeHysteresisPerBar` take their `#else const` branch). Still includes `input group` separators, which are not settable pins. |
| **Authoritative canonical pin count** | **390** | Settable inputs pinned in `claude/audit/current-canonical.set`. This is the config-of-record count. |

## The authoritative count: 388 → 390

Verified by diffing the canonical `.set` at `baseline-input-cleanup-388` against the new baseline:

```
388-tag pins: 388 | now pins: 390
304a305 > InpSLResyncOnFail=true
319a321 > InpSessionBreakoutDST=true
```

The delta is **exactly** the two adopted flags and nothing else:
- `+ InpSessionBreakoutDST=true` (fixed-UTC breakout window — prior adoption)
- `+ InpSLResyncOnFail=true` (SL internal↔broker re-sync — this adoption)

No other pin drifted. The two **rejected** candidate flags (`InpVolRegimeClosedBar`,
`InpRegimeHysteresisPerBar`) were removed from the production input **surface** — they are now
`const` under `#else` and never appear in the tester panel or the `.set` — so adopting two and
rejecting two nets the pin count from 388 to 390 with a fully accounted-for ledger.

## Consistency check
- `.set` pin count (`grep -c '=' current-canonical.set`) = **390** ✓ matches 388 + 2.
- release-identity-manifest-34940.json records `canonical_set_pins: 390`, `canonical_set_sha256:
  bd7c0275…`, `removed_from_surface: [InpRegimeHysteresisPerBar, InpVolRegimeClosedBar]`.
- The 409/411 source-declaration numbers are intentionally NOT the authoritative count and never
  were; they include `input group` separators (panel headings) that are not settable pins.

**Reconciled. Task-C input-surface cleanup is closed.**
