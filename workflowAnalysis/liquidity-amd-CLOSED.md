# Liquidity / CRT / AMD intraday-fade thesis — CLOSED (entry-fill artifact)

**Verdict: DEAD. Do not build. Do not relitigate without a genuinely different mechanism.**
The entire apparent edge was an **entry-fill survivorship artifact** — it exists only at an unrealizable fill price. Under every implementable fill it is net-negative on both feeds. v1 (`release-ultimate-gold-v1-32490`) untouched throughout; this was analysis-only.

## The arc
1. **Discovery** (`gh_liquidity_study.py`): mechanical London-judas fade of the Asian range showed ~+0.18R/trade, both feeds, every year — reopened the additive-engine path under release-manifest §11 trigger #4 (new economic mechanism stated before profitability).
2. **Two expert reviews** (CRT lens + SMC/AMD lens): both leaned "build, but gate on a cost-netted kill-line (net avg-R > +0.08, PF > 1.15)." The CRT reviewer explicitly named the risk that killed it: *"the 'closed back inside' filter is survivorship — you only enter after the manipulation has already failed, conditioning on the reversal existing."*
3. **Phase-1 kill test** (`gh_liquidity_phase1.py`): cost-netted with Vantage's REAL recorded per-bar spread (median $0.06, p90 $0.18), target-agnostic exits (fixed-1R, NY-close), conservative end-of-day-mark scoring, DST offset sweep, news exclusion. **All passed** (Vantage +0.124 conservative, GoldHist +0.082). *But every one of these checks inherited the discovery study's `entry = range extreme` assumption, so none could expose the fill artifact.* The offset sweep did flag one thing: **no session-boundary peak** (monotonic in window placement) — falsifying the AMD/session attribution even while the setup still "passed."
4. **Build step 0** (`gh_meanrev_build0.py`): to build honestly I coded the session-AGNOSTIC rolling-range formulation AND switched to the implementable fill — **enter at market = close of the confirmed reclaim bar** (a plugin acts on a closed bar). The edge **collapsed to net-negative** (Vantage −0.022R, GoldHist −0.064R, nearly every year red). §10 correlation was genuinely negative (−0.12 all-days, −0.24 both-active) but negative correlation cannot rescue a negative-expectancy sleeve (portfolio Sharpe 1.37→0.65, R-DD 13.8→34.6).
5. **Reconciliation** (`gh_fill_reconcile.py`): ran the SESSION fade under three fills × two exits × two feeds:

| Fill | Vantage (asian / fix1) | GoldHist (asian / fix1) | Realizable? |
|---|---|---|---|
| entry = extreme (ah/al) | +0.124 / +0.184 **PASS** | +0.082 / +0.130 **PASS** | **No** |
| entry = close (honest confirm) | −0.063 / −0.046 fail | −0.098 / −0.070 fail | Yes |
| limit-fade (no confirm, eats breakouts) | −0.041 / −0.047 fail | −0.069 / −0.072 fail | Yes |

## Why the extreme-entry is a cheat
To SELL at `ah` (range top) you need a resting sell-limit at `ah`, which fills the instant price pokes above `ah` — **before** you can know it will close back inside (reclaim). Counting only the pokes that reverted (survivorship) while pricing the fill at the pre-reclaim level takes credit for a reversal unconfirmable at fill time. The two honest alternatives both lose: (a) confirm the reclaim → enter at the reclaim close (worse price) → negative; (b) resting limit with no confirmation → filled on breakouts that run → negative. **No fill both gets the good price and only the winners.**

## What was and wasn't refuted
- **Not a cost problem** — real spread is tiny and 0.3×ATR stops make friction a small fraction of R.
- **Not (only) a target tautology** — target-agnostic exits die too; the survivorship was in the ENTRY, not the exit.
- **AMD/session attribution independently falsified** — no session-boundary peak in the offset sweep.
- **The flat-year diversification hook also broke** under the no-lookahead fix (2025 faded as well as the flat years), so even the surviving-on-paper version had lost its rationale.

## Standing conclusion
The gold architecture remains at its research frontier (see `honest-backtest-baseline`); this closes the intraday-fade reopening as a **clean documented negative**. Any future reopening of an intraday/liquidity idea MUST price entries at an implementable fill (closed-bar market or a resting limit that also takes the losers) from the first pass — never at a level conditioned on a not-yet-confirmed reversal.

Evidence: `claude/gate/gh_liquidity_study.py`, `gh_liquidity_phase1.py`, `gh_meanrev_build0.py`, `gh_fill_reconcile.py`; reports `liquidity-amd-phase1.md`, `meanrev-build-step0.md`, this file.
