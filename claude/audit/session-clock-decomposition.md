# Session-clock 2×2 decomposition — range-construction × breakout-window

**Question.** The composed `CSessionBreakoutEntry` (inside `CExpansionEngine`) runs on a **legacy
fixed broker-hour clock** (`m_gmt_offset = 0`). Arm 1 — DST-correcting the *whole* instance —
regressed **−$1,103.47**. Before choosing any timing semantics (or doing Arm 2 / Arm 3), separate
the DST effect on the two independent clock consumers:

- **Range-construction clock** — `UpdateAsianRange()` (which M15 bars form the Asian range, and the
  freeze-gate). Controlled by research flag `InpResSessRangeDST`.
- **Breakout-window clock** — `GetGMTHour()` at the window check (when the London `[8,9)` / NY
  `[13,14)` server-hour windows fire). Controlled by research flag `InpResSessBreakoutDST`.

**Governance.** Production is **frozen at `baseline-input-cleanup-388`** throughout. The two flags
live only in a `#define RESEARCH_SESSION` build; the production 388 surface and legacy behavior are
unchanged. No Asian-end input touched (that is Arm 2, not performed). No live-DST refresh (Arm 3).

---

## Build & identity validation (the scaffold is provably clean)

| Build | `#define` | Stats md5 | Meaning |
|---|---|---|---|
| Production (388) | none | `96415ff0` | byte-identical to baseline — `#ifdef` edits are behavior-neutral |
| Research, Arm A (both flags off) | `RESEARCH_SESSION` | `96415ff0` | **null-state identity** — disarmed research build == production, zero scaffold contamination |
| Research, Arm D (both flags on) | `RESEARCH_SESSION` | `a8c1e028` | **exactly reproduces Arm 1** (`arm1-stats.csv` md5 `a8c1e028`) — split flags recompose to the single-flag patch |

Both compile **0 errors / 0 warnings**. Any A→{B,C,D} difference is therefore purely the DST flag(s),
nothing else. Config: `risk_R90.ini` as-is (`cebf9578`), Model=4 real ticks, XAUUSD+, 2019.01.01→2026.06.27.

---

## Primary feed (XAUUSD+, real ticks) — the 2×2

| Arm | Range clock | Breakout clock | Net (report) | Δ vs A | Pos | Composed fills | Composed net |
|-----|-------------|----------------|-------------:|-------:|----:|---------------:|-------------:|
| **A** | legacy | legacy | **$32,503.03** | — | 865 | 12 | +$1,435.90 |
| **B** | legacy | **DST** | **$34,858.89** | **+$2,355.86** | 869 | 16 | +$1,527.91 |
| **C** | **DST** | legacy | **$29,983.78** | **−$2,519.25** | 853 | **0** | $0.00 |
| **D** | DST | DST | $31,399.56 | −$1,103.47 | 868 | 15 | +$598.65 |

**Separation achieved — the two clocks carry opposite-signed effects:**
- **Breakout-window DST alone (B): +$2,355.86.** Moving *only* the firing window to true GMT helps.
- **Range-construction DST alone (C): −$2,519.25.** DST-shifting *only* the Asian-range bars hurts —
  and it drives the composed strategy to **0 fills**: the range is built on DST-shifted bars while the
  breakout window still checks legacy server hours, so the two never align and no setup ever triggers.
- **Both (D): −$1,103.47.** Additive prediction = $32,339.64; actual $31,399.56 ⇒ **−$940 negative
  interaction**. Arm 1 (= D) *conflated* the +breakout and −range effects into a single misleading loss.

So the naive reading of Arm 1 ("DST-correcting the session clock loses money, keep legacy") is wrong in
mechanism: the breakout-window correction is *positive*; it is the range-construction correction (and
its interaction) that sinks the full-DST arm.

---

## BUT — the +$2,356 is NOT a session-strategy edge. It is a portfolio-coupling ripple.

Decomposing arm B's +$2,383.49 (analyzer basis; report Δ +$2,355.86, the ~$28 gap is commission on 4
extra fills) into the session book vs the rest of the book:

| Component | Δ vs A | What it is |
|---|---:|---|
| Composed session fills themselves | **+$92.01** | the actual session strategy (12→16 fills, re-timed) |
| **Non-composed common trades (same entries, changed EXITS)** | **+$2,291.48** | **portfolio ripple** |

- Of 853 common trades, **460 non-composed trades** (PullbackContinuation, PinBar, Engulfing — largely
  2026) have a **different exit P&L** in B vs A, while their **entries are identical** (0 added / 0
  removed non-composed). Only 393 non-composed common trades are exit-identical.
- Mechanism: re-timing ~14 sparse session fills perturbs shared portfolio/exit-management state
  (exposure occupancy, regime/day-type, trailing/chandelier coordination) enough to cascade into the
  *exits* of hundreds of unrelated positions. The top movers are $100–$310 swings on 2026 pin-bar /
  pullback / engulfing trades that have nothing to do with the session windows.
- The same ripple, opposite sign, explains C and D: C ripple −$1,101.38 (on top of losing the whole
  +$1,435.90 composed book → 0 fills); D ripple −$263.64 (composed book −$837.25).

**The session strategy contributes ±$0–1.5k across all four clock models; the multi-thousand-dollar arm
spreads are dominated by chaotic coupling onto the rest of the book, not by session timing.** This is a
robustness red flag, not an edge — it is precisely the "12–15 fills, don't call it an edge" hazard.

---

## Composed-session footprint & concentration (why the session book cannot support an edge claim)

**Server-hour footprint (the clock working as intended):**

| Arm | fills | London hours | NY hours |
|---|---|---|---|
| A (legacy) | 12 | 9 @ svr **08** | 3 @ svr **13** |
| B (DST breakout) | 16 | 5 @ **10** + 5 @ **11** (winter/summer split) | 3 @ **15** + 3 @ **16** |
| C (DST range only) | 0 | — | — |
| D (DST both) | 15 | 4 @ 10 + 6 @ 11 | 2 @ 15 + 3 @ 16 |

The DST breakout clock does exactly what it should — splitting each window across the US-DST boundary
(svr 10 winter / 11 summer for "London"). But the **volume is ~2 fills/year over 7.5 years.**

**Sign-flipping year to year (composed net by year, $):**

| Arm | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | 2026 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| A (legacy) | — | — | −16 | +164 | — | +488 | **−686** | **+1,486** |
| B (DST bo) | +53 | +57 | −21 | +275 | +678 | +845 | −35 | **−323** |
| D (DST both) | +53 | −168 | — | −19 | +250 | +806 | −0 | −323 |

The session book's own P&L **changes sign** between clock models in the same year (2025: −$686→−$35;
2026: **+$1,486→−$323**). A strategy whose per-year contribution flips sign when you move its window by
2 hours, on ~2 fills/year, has **no stable edge to preserve or fix** — under either clock.

**Concentration (ex-largest-trade / ex-best-year), whole book:**

| Arm | Net | ex-largest single trade | ex-best year (2025) |
|---|---:|---:|---:|
| A | $32,503 (rpt) / $33,047 (sum) | $31,625 (−$1,422 PinBar 2026-06-22) | $14,581 (2025 = $18,466) |
| B | $34,859 / $35,430 | $33,901 (−$1,530 PinBar 2026-06-22) | $15,011 (2025 = $20,419) |
| C | $29,984 / $30,509 | $29,203 (−$1,306 PinBar 2025-10-06) | $12,172 |
| D | $31,400 / $31,946 | $30,550 (−$1,396 PinBar 2025-10-06) | $12,823 |

The single largest trade in **every** arm is a **Pin Bar, not a session fill**, and 2025 (a non-session
year) supplies more than half of every arm's profit. The arm-to-arm spread is not concentrated in the
session fills — it is diffused across the ripple on hundreds of non-session trades.

---

## Cross-history support (independent GoldHistory feed, `XAUUSD_GOLDHISTORY`, Model=1)

Full 2×2 re-run on the independent vendor-candle feed (canonical config, commission-free, generated
ticks). Absolute levels differ from the primary feed (Model=1 synthetic + different candles) — the test
is whether the **sign/direction** of each clock effect **replicates**.

| Arm | GH Net | Δ vs GH-A | GH pos | GH composed fills |
|---|---:|---:|---:|---:|
| A | $28,685.51 | — | 816 | 9 |
| **B** (DST breakout) | $29,525.79 | **+$840.28** | 820 | 13 |
| **C** (DST range) | $27,124.17 | **−$1,561.34** | 807 | **0** |
| **D** (DST both) | $27,073.27 | **−$1,612.24** | 816 | 9 |

**Every sign replicates** — breakout-DST +, range-DST −, full-DST −, on both feeds. So the directions
are **not** random. But decomposing the GH deltas the same way separates *what* is consistent:

| Arm | Δ total (primary / GH) | Δ **session book** (primary / GH) | **Ripple** (primary / GH) |
|---|---|---|---|
| B (DST breakout) | +$2,356 / **+$840** | **+$92 / +$533** ✅ same sign | +$2,291 / **+$243** ⚠️ 9× smaller |
| C (DST range) | −$2,519 / −$1,561 | −$1,436 / −$731 (both → 0 fills) | −$1,101 / −$894 |
| D (DST both) | −$1,103 / −$1,612 | −$837 / −$639 | −$264 / −$1,037 |

Two distinct robustness verdicts fall out:
- **The session strategy's *own* directional response IS feed-robust.** Breakout-DST helps the session
  book on both feeds (+$92 / +$533); range-DST zeroes it out (0 fills) on both. Firing the breakout at
  the *true* London/NY open (svr 10/11, 15/16) rather than the premature legacy svr-08/13 is the mildly
  better design — consistently.
- **The headline total-P&L magnitude is NOT feed-robust.** The portfolio ripple that made the primary
  feed's B look like +$2.4k (ripple +$2,291) is only +$243 on GH — a ~9× collapse. The multi-thousand
  swing is feed/tick-path-sensitive coupling, exactly as predicted; it is not bankable.

---

## Conclusion (pre-registered against the directive)

1. **Range and breakout effects ARE separated** — opposite signs (breakout-DST **+**, range-DST **−**),
   −$940 interaction; Arm 1's −$1,103 was a *conflation* of a positive breakout effect and a larger
   negative range effect, not evidence that "DST-correcting the session clock loses money."
2. **The directions are cross-history-robust; the magnitudes are not.** On BOTH feeds: DST-correcting
   the **breakout window** helps (session book +$92 / +$533), DST-correcting the **range** breaks the
   strategy to 0 fills (−), and **both together is the worst live arm** (−). But the session book's gain
   is **immaterial** (~$0.1–0.5k over 7.5y, ~2 fills/yr, per-year sign-flipping), and the eye-catching
   +$2.4k of primary-B is **~96% portfolio-coupling ripple** (460 unrelated trades' exits) that shrinks
   9× on the second feed.
3. **Do NOT conclude any window is "more profitable" in a bankable sense.** The supportable statement is
   directional and small: *the legacy breakout window fires ~2–3h before the true London/NY open and is
   mildly suboptimal; the legacy Asian range is correct and must NOT be DST-shifted.* This is a
   correctness nuance, not an edge — the 9–16-fill sample and the non-robust ripple forbid an edge claim.
4. **If the composed clock is ever revisited (a future, separate decision):** the *only* supported
   direction is **breakout-window-DST-only (arm B), Asian range left on the legacy clock** — never the
   full-DST Arm 1/D (worst on both feeds), never range-DST (arm C, self-destructs). Even arm B is not
   warranted on P&L grounds alone (immaterial + non-robust magnitude); it would be a *correctness* change
   requiring its own baseline and adoption gate.
5. **Decision deferred by design; production untouched.** Timing semantics remain unchosen. Production
   stays at `baseline-input-cleanup-388` (legacy fixed broker-hour). Arm 1 stays a preserved research
   patch, neither adopted nor rejected. No Arm 2 (hardcoded Asian-end → `InpAsianRangeEndHour`) and no
   Arm 3 (live-DST refresh) are performed.

---

### Reproducibility

- Builds: production `#ifdef`-neutral (Stats `96415ff0`); research `#define RESEARCH_SESSION` (arm flags
  `InpResSessRangeDST` / `InpResSessBreakoutDST`). Arm A `96415ff0`, Arm D `a8c1e028` (= Arm 1).
- Primary Stats md5: A `96415ff0`, B `1ed88d41`, C `644c54a0`, D `a8c1e028`.
- GH Stats md5: A `85af5e31`, B `1276ffa1`, C `579edd73`, D `4cf8e809`.
- Runners: `claude/gate/sessclock_run.sh` (primary), `sessclock_run_gh.sh` (cross-history);
  analyzer `claude/gate/sessclock_analysis.py`. Config `risk_R90.ini` (`cebf9578`).
- Arm archives: `Common/Files/_arm_archive/sess_SESS{A,B,C,D}` and `sessgh_GH{A,B,C,D}`.
