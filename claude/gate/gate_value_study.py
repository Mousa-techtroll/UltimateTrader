#!/usr/bin/env python3
"""
GATE-VALUE STUDY (offline, deterministic, stdlib-only).

Question (owner): the short engines starve because a stacked gauntlet filters ~95% of
short triggers. Do those gates remove BAD shorts or GOOD ones? Evaluate every short
gate/filter statistically against actual forward gold returns across 22 years of H1
history (2004-2025), including the sustained bears (2008, 2011-2015, 2018) absent from
the 2019-2026 tester window.

Pipeline:
  Step 1  standardized short-outcome metric per H1 bar (TMF realized-R + MFE/MAE + fwd ret)
  Step 2  enumerate gates (binary conditions on closed data at bar t)
  Step 3  per-gate LIFT = E[R|pass] - E[R|fail], with n/SE, split by era
  Step 4  marginal stack (start from severity>=2, add gates one at a time)
  Step 5  room-k / over-ext-m sweeps
  Verdict ranking is assembled in the .md by the analyst; this script prints the FACTS.

Reuses the validated SB-1.1 state model (sb11_state_model.py) by pointing its loader at
the 22-year GoldHistory feed instead of the 2019-2026 tester feed.

Usage:  python3 gate_value_study.py
Outputs: prints structured tables; writes machine artifacts into the scratchpad.
"""
import csv
import math
import sys
import os
from datetime import datetime, date
from collections import defaultdict, Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sb11_state_model as sb  # noqa: E402

GOLD_H1 = "/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"
STATES_VALIDATED = "/mnt/c/Trading/UltimateTrader/claude/gate/sb11_states.csv"
SCRATCH = "/tmp/claude-1000/-mnt-c-Trading-UltimateTrader/6ec97821-06de-4fd5-8001-8b466ca26df2/scratchpad"

# -------- study constants (frozen) --------
SWING_HI_LOOKBACK = 5      # stop = max(high[t-5..t]) + 0.5*ATR14  (t-5..t inclusive)
ATR_BUF = 0.5
MAXHOLD = 48              # H1 bars, TMF max-hold
FRACTAL = 2              # 5-bar fractal (2 each side) for H1 swings
SUPPORT_LOOKBACK = 240   # H1 bars to search for nearest lower swing low (~10 trading days)
EMA_ZONE_ATR = 0.25      # EMA21 zone-tag tolerance
ZONE_BARS = 3            # last N bars for EMA21 zone tag
ROOM_KS = [0.5, 1.0, 1.2, 1.5, 2.0]
OVEREXT_MS = [2, 3, 4]   # plus 'off'
RR_MIN = 1.3

ERAS = [("2004-2010", 2004, 2010), ("2011-2015", 2011, 2015),
        ("2016-2018", 2016, 2018), ("2019-2022", 2019, 2022),
        ("2023-2026", 2023, 2026)]


def era_of(y):
    for name, lo, hi in ERAS:
        if lo <= y <= hi:
            return name
    return None


# ----------------------------------------------------------------- indicators (H1-native)
def sma_ema(vals, n):
    return sb.ema_series(vals, n)


def fractal_swings(highs, lows, wing):
    """Return (conf_high_idx, conf_low_idx): index arrays where swing confirmed.
    A swing high at i (high[i] strict max of window i-wing..i+wing) is CONFIRMED at bar i+wing.
    Returns list of (confirm_bar, pivot_bar, price) for highs and lows separately."""
    n = len(highs)
    chi, clo = [], []
    for i in range(wing, n - wing):
        wh = highs[i - wing:i + wing + 1]
        wl = lows[i - wing:i + wing + 1]
        if highs[i] >= max(wh) and highs[i] > highs[i - 1] and highs[i] > highs[i + 1]:
            chi.append((i + wing, i, highs[i]))
        if lows[i] <= min(wl) and lows[i] < lows[i - 1] and lows[i] < lows[i + 1]:
            clo.append((i + wing, i, lows[i]))
    return chi, clo


def main():
    print("=== loading 22-year gold H1 & building extended state ledger ===", flush=True)
    sb.RATES_PATH = GOLD_H1
    # build_states reads RATES_PATH at call time; labels cover ALL bars regardless of LABEL_START
    h1, h4, d1, fe, sm, states_by_h4, labels = sb.build_states()
    n = len(h1)
    t_arr = [r[0] for r in h1]
    o = [r[1] for r in h1]; hi = [r[2] for r in h1]; lo = [r[3] for r in h1]; cl = [r[4] for r in h1]
    print(f"H1 bars: {n}  span {t_arr[0]} .. {t_arr[-1]}", flush=True)

    # severity per H1 bar from extended labels
    sev = [sb.SEVERITY.get(lab, 0) for (_t, lab, _s, _a) in labels]
    lab_arr = [lab for (_t, lab, _s, _a) in labels]

    # ---- sanity: reproduce sb11_states.csv on 2019-2026 overlap ----
    val = {}
    with open(STATES_VALIDATED) as f:
        rd = csv.reader(f); next(rd)
        for row in rd:
            val[row[0]] = row[1]
    agree = tot = 0
    sev_agree = 0
    for i in range(n):
        key = t_arr[i].strftime("%Y.%m.%d %H:%M")
        if key in val:
            tot += 1
            if val[key] == lab_arr[i]:
                agree += 1
            if sb.SEVERITY.get(val[key], 0) == sev[i]:
                sev_agree += 1
    print(f"[sanity] overlap bars vs sb11_states.csv: {tot}  exact-label agree {agree/tot*100:.1f}%  "
          f"severity agree {sev_agree/tot*100:.1f}%", flush=True)

    # ---- H1-native indicators ----
    print("=== computing H1 indicators & swings ===", flush=True)
    ema21 = sma_ema(cl, 21)
    ema50 = sma_ema(cl, 50)
    ema200 = sma_ema(cl, 200)
    atr = sb.wilder_atr(hi, lo, cl, 14)
    chi, clo = fractal_swings(hi, lo, FRACTAL)

    # For each bar t, precompute "last confirmed swing high price" and "prior swing high price"
    # (confirmed => confirm_bar <= t). Walk pointers.
    last_sh = [None] * n   # most recent confirmed swing-high price at/just before t
    prev_sh = [None] * n
    ci = 0
    cur_sh = prv_sh = None
    for t in range(n):
        while ci < len(chi) and chi[ci][0] <= t:
            prv_sh = cur_sh
            cur_sh = chi[ci][2]
            ci += 1
        last_sh[t] = cur_sh
        prev_sh[t] = prv_sh

    # confirmed swing lows: keep a running list of (confirm_bar, pivot_bar, price) for
    # nearest-lower-support lookups. We'll binary-walk by confirm_bar.
    clo_confirm = [c[0] for c in clo]
    clo_price = [c[2] for c in clo]

    def nearest_lower_swinglow(t, entry):
        """highest-priced confirmed swing low with price < entry, within SUPPORT_LOOKBACK bars.
        Returns price or None (no support beneath => open road)."""
        best = None
        # iterate swing lows confirmed at/before t, pivot within lookback
        # linear scan bounded; find range via simple back-walk over confirmed list
        # binary search rightmost confirm_bar <= t
        loi, hii = 0, len(clo_confirm)
        while loi < hii:
            mid = (loi + hii) // 2
            if clo_confirm[mid] <= t:
                loi = mid + 1
            else:
                hii = mid
        j = loi - 1
        while j >= 0:
            pb = clo[j][1]
            if pb < t - SUPPORT_LOOKBACK:
                break
            p = clo_price[j]
            if p < entry and (best is None or p > best):
                best = p
            j -= 1
        return best

    # completed-day index per H1 bar (iClose(D1,1) semantics: last day strictly before t.date())
    d1_dates = [x.date() for x in d1.t]
    comp_d1 = [None] * n
    di = -1
    for t in range(n):
        cur_date = t_arr[t].date()
        while di + 1 < len(d1_dates) and d1_dates[di + 1] < cur_date:
            di += 1
        comp_d1[t] = di if di >= 0 else None

    # last CLOSED H4 index per H1 bar (matches build_states: closed = h1_h4idx[i]-1)
    # rebuild h1_h4idx via resample (already have via build_states internals? recompute cheaply)
    _h4b, _d1b, h1_h4idx, h1_d1idx = sb.resample(h1)

    # ---- Step 1: short-outcome metric per bar ----
    print("=== simulating TMF short outcome per bar ===", flush=True)
    realizedR = [None] * n
    mfeR = [None] * n
    maeR = [None] * n
    fret24 = [None] * n
    fret48 = [None] * n
    roomR = [None] * n     # room to nearest lower H1 swing low, in R (None => open road)
    Rdist = [None] * n

    for t in range(n):
        if atr[t] is None or t < SWING_HI_LOOKBACK or t + 1 >= n:
            continue
        entry = cl[t]
        swing_hi = max(hi[t - SWING_HI_LOOKBACK:t + 1])
        stop = swing_hi + ATR_BUF * atr[t]
        R = stop - entry
        if R <= 0:
            continue
        Rdist[t] = R
        sl = nearest_lower_swinglow(t, entry)
        if sl is not None:
            roomR[t] = (entry - sl) / R
        # TMF target price: closer-to-entry of {1R target, nearest swing low}
        tgt_1r = entry - R
        if sl is not None and sl > tgt_1r:      # support nearer than 1R
            tp = sl
        else:
            tp = tgt_1r
        # forward sim
        end = min(t + MAXHOLD, n - 1)
        outcome = None
        min_low = float('inf'); max_high = float('-inf')
        for j in range(t + 1, end + 1):
            max_high = max(max_high, hi[j])
            min_low = min(min_low, lo[j])
            if hi[j] >= stop:                    # adverse-first convention
                outcome = -1.0
                break
            if lo[j] <= tp:
                outcome = (entry - tp) / R
                break
        if outcome is None:
            outcome = (entry - cl[end]) / R      # time-exit at 48h close
        realizedR[t] = outcome
        # MFE/MAE over realized window (use full 48h horizon regardless of exit for context)
        h_end = min(t + MAXHOLD, n - 1)
        seg_hi = max(hi[t + 1:h_end + 1]); seg_lo = min(lo[t + 1:h_end + 1])
        mfeR[t] = (entry - seg_lo) / R
        maeR[t] = (seg_hi - entry) / R
        if t + 24 < n:
            fret24[t] = (cl[t + 24] - entry) / entry * 100.0
        if t + 48 < n:
            fret48[t] = (cl[t + 48] - entry) / entry * 100.0

    # ---- Step 2: gate booleans per bar ----
    print("=== evaluating gates ===", flush=True)

    def down_close(t):
        return t >= 1 and cl[t] < cl[t - 1]

    def ema21_zone_tag(t):
        if ema21[t] is None or atr[t] is None:
            return False
        for k in range(max(0, t - ZONE_BARS + 1), t + 1):
            if ema21[k] is not None and atr[k] is not None:
                if hi[k] >= ema21[k] - EMA_ZONE_ATR * atr[k]:
                    return True
        return False

    def h4_align(t):
        c4 = h1_h4idx[t] - 1
        if c4 < 0:
            return False
        e21, e50 = fe.h4_ema21[c4], fe.h4_ema50[c4]
        return e21 is not None and e50 is not None and e21 < e50

    def d1_deathcross(t):
        dd = comp_d1[t]
        if dd is None:
            return False
        e50, e200 = fe.d1_ema50[dd], fe.d1_ema200[dd]
        return e50 is not None and e200 is not None and e50 < e200

    # base sample: bars with a valid outcome and full indicator warmup
    base_idx = [t for t in range(n) if realizedR[t] is not None and ema200[t] is not None
                and era_of(t_arr[t].year) is not None]
    print(f"base sample (valid outcome + EMA200 warmup): {len(base_idx)} bars "
          f"({base_idx and t_arr[base_idx[0]]} .. {t_arr[base_idx[-1]]})", flush=True)

    # define gate lambdas returning bool for a bar t
    gates = {}
    gates["state_sev>=2"] = lambda t: sev[t] >= 2
    gates["state_sev2"] = lambda t: sev[t] == 2
    gates["state_sev3"] = lambda t: sev[t] == 3
    gates["state_sev4"] = lambda t: sev[t] == 4
    gates["loc_close<EMA50"] = lambda t: ema50[t] is not None and cl[t] < ema50[t]
    gates["loc_close<EMA200"] = lambda t: cl[t] < ema200[t]
    gates["loc_lower_high"] = lambda t: (last_sh[t] is not None and prev_sh[t] is not None
                                         and last_sh[t] < prev_sh[t])
    gates["trig_ema21_reject"] = lambda t: (ema21_zone_tag(t) and ema21[t] is not None
                                            and cl[t] < ema21[t] and down_close(t))
    gates["overext_off"] = lambda t: True
    for m in OVEREXT_MS:
        gates[f"overext_m{m}"] = (lambda t, m=m: ema50[t] is not None and atr[t] is not None
                                  and cl[t] >= ema50[t] - m * atr[t])
    for k in ROOM_KS:
        gates[f"room_k{k}"] = (lambda t, k=k: roomR[t] is None or roomR[t] >= k)  # open road passes
    gates["rr_far>=1.3"] = lambda t: roomR[t] is None or roomR[t] >= RR_MIN
    gates["align_D1_deathcross"] = lambda t: d1_deathcross(t)
    gates["align_H4_ema21<50"] = lambda t: h4_align(t)
    gates["vol_above_avg"] = None  # computed below (needs volume); see below

    # volume gate: volume[t] >= mean(prior 20). Need volume from file (build_states dropped it).
    vol = load_volume(GOLD_H1, t_arr)
    volavg = rolling_mean(vol, 20)
    gates["vol_above_avg"] = lambda t: (vol[t] is not None and volavg[t] is not None
                                        and vol[t] >= volavg[t])
    # day-of-week gates
    gates["dow_not_friday"] = lambda t: t_arr[t].weekday() != 4
    gates["dow_mon_tue"] = lambda t: t_arr[t].weekday() in (0, 1)
    # session (server-time hour): London+NY core = 08..17 (server). TZ ~ GMT+2/3 (documented caveat)
    gates["sess_London_NY"] = lambda t: 8 <= t_arr[t].hour <= 17

    # ---- Step 3: per-gate lift by era ----
    stats_rows = compute_gate_stats(gates, base_idx, realizedR, t_arr)

    # ---- Step 4: marginal stack from severity>=2 ----
    marginal_rows = compute_marginal(gates, base_idx, realizedR, t_arr, sev)

    # ---- Step 5: room-k / over-ext-m sweeps (within severity>=2 cohort) ----
    sweep_rows = compute_sweeps(base_idx, realizedR, roomR, sev, ema50, atr, cl, t_arr)

    # ---- unconditional baselines ----
    all_R = [realizedR[t] for t in base_idx]
    print("\n=== UNCONDITIONAL short expectancy (base sample) ===")
    print(f"ALL bars: {fmt(all_R)}")
    for name, l, h in ERAS:
        er = [realizedR[t] for t in base_idx if l <= t_arr[t].year <= h]
        print(f"  {name}: {fmt(er)}")

    # ---- ADDENDA (PM cuts) ----
    addendum(base_idx, realizedR, roomR, sev, t_arr, cl, hi, lo, atr, ema50, ema200,
             comp_d1, fe, h1_h4idx, n)

    # write machine artifacts
    dump(stats_rows, marginal_rows, sweep_rows, all_R, base_idx, realizedR, t_arr, sev,
         roomR, mfeR, maeR)
    print("\nDONE", flush=True)


def payoff(vals, label):
    m, se, nn = mean_se(vals)
    wins = [x for x in vals if x > 0]
    losses = [x for x in vals if x < 0]
    aw = sum(wins) / len(wins) if wins else 0.0
    al = sum(losses) / len(losses) if losses else 0.0
    wr = len(wins) / nn if nn else float('nan')
    payoff_ratio = (aw / -al) if al < 0 else float('nan')
    be_wr = (-al) / (aw - al) if (aw - al) != 0 else float('nan')  # breakeven WR
    print(f"  {label:34s} n={nn:6d} WR={wr*100:5.1f}% avgWin={aw:+.3f} avgLoss={al:+.3f} "
          f"payoff={payoff_ratio:.3f} E[R]={m:+.4f} BE_WR={be_wr*100:4.1f}%")


def addendum(base_idx, realizedR, roomR, sev, t_arr, cl, hi, lo, atr, ema50, ema200,
             comp_d1, fe, h1_h4idx, n):
    print("\n=== ADDENDUM A: payoff decomposition (why every cohort is negative) ===")
    payoff([realizedR[t] for t in base_idx], "UNCONDITIONAL")

    # ADDENDUM B: candidate minimal high-value sets (drop the harmful/starving gates)
    def d1dc(t):
        dd = comp_d1[t]
        if dd is None:
            return False
        e50, e200 = fe.d1_ema50[dd], fe.d1_ema200[dd]
        return e50 is not None and e200 is not None and e50 < e200
    combos = {
        "below_EMA200 only": lambda t: cl[t] < ema200[t],
        "below_EMA200 + notFri": lambda t: cl[t] < ema200[t] and t_arr[t].weekday() != 4,
        "below_EMA50&200": lambda t: ema50[t] and cl[t] < ema50[t] and cl[t] < ema200[t],
        "MINIMAL: <EMA50&200 + D1dc + notFri":
            lambda t: ema50[t] and cl[t] < ema50[t] and cl[t] < ema200[t] and d1dc(t)
            and t_arr[t].weekday() != 4,
        "MINIMAL + sev>=2":
            lambda t: ema50[t] and cl[t] < ema50[t] and cl[t] < ema200[t] and d1dc(t)
            and t_arr[t].weekday() != 4 and sev[t] >= 2,
        "FULL-GAUNTLET-ish (+overext_m3 +room1.2)":
            lambda t: ema50[t] and cl[t] < ema50[t] and cl[t] < ema200[t] and d1dc(t)
            and t_arr[t].weekday() != 4 and sev[t] >= 2
            and cl[t] >= ema50[t] - 3 * atr[t] and (roomR[t] is None or roomR[t] >= 1.2),
    }
    print("\n=== ADDENDUM B: candidate gate SETS — frequency + expectancy + by-era ===")
    for cname, fn in combos.items():
        idx = [t for t in base_idx if fn(t)]
        vals = [realizedR[t] for t in idx]
        m, se, nn = mean_se(vals)
        per_day = nn / (len(base_idx) / 22.0)  # approx trades/yr scaling
        print(f"\n  [{cname}]  fires {nn} bars ({nn/len(base_idx)*100:.1f}% of sample)")
        payoff(vals, "  overall")
        for ename, l, h in ERAS:
            ev = [realizedR[t] for t in idx if l <= t_arr[t].year <= h]
            mm, ss, nnn = mean_se(ev)
            wr = sum(1 for x in ev if x > 0) / nnn * 100 if nnn else float('nan')
            print(f"      {ename}: n={nnn:5d} E[R]={mm:+.4f} SE={ss:.4f} WR={wr:4.1f}%")

    # ADDENDUM C: exit-convention sensitivity (bound the pessimism of adverse-first + swing-clip)
    print("\n=== ADDENDUM C: exit-convention sensitivity (unconditional + 2011-2015 bear) ===")
    for fav_first in (False, True):
        for clip in (True, False):
            vals_all = []; vals_bear = []
            for t in base_idx:
                r = sim_variant(t, cl, hi, lo, atr, roomR, n, fav_first, clip)
                if r is None:
                    continue
                vals_all.append(r)
                if 2011 <= t_arr[t].year <= 2015:
                    vals_bear.append(r)
            ma, _, na = mean_se(vals_all); mb, _, nb = mean_se(vals_bear)
            tag = f"{'FAV-first' if fav_first else 'ADV-first'} / {'swing-clip' if clip else '1R-only'}"
            print(f"  {tag:26s} ALL E[R]={ma:+.4f} (n={na}) | 2011-2015 E[R]={mb:+.4f} (n={nb})")

    # ADDENDUM D: room — open-road vs defined-support
    print("\n=== ADDENDUM D: room gate — open-road (None) vs defined-support split (sev>=2) ===")
    coh = [t for t in base_idx if sev[t] >= 2]
    none_r = [realizedR[t] for t in coh if roomR[t] is None]
    def_r = [realizedR[t] for t in coh if roomR[t] is not None]
    print(f"  open-road (no support<entry within 240b): {fmt(none_r)}  ({len(none_r)/len(coh)*100:.1f}% of sev>=2)")
    print(f"  defined-support:                          {fmt(def_r)}")
    # among defined-support only, does MORE room help?
    print("  within defined-support, by room bucket:")
    for lo_, hi_ in [(0, 0.5), (0.5, 1.0), (1.0, 1.5), (1.5, 2.5), (2.5, 99)]:
        v = [realizedR[t] for t in coh if roomR[t] is not None and lo_ <= roomR[t] < hi_]
        if v:
            print(f"    room[{lo_},{hi_}): {fmt(v)}")


def sim_variant(t, cl, hi, lo, atr, roomR, n, fav_first, clip):
    """Re-simulate TMF short with alternate conventions. clip=True banks at swing low if nearer
    than 1R (original TMF); clip=False uses pure 1R target."""
    if atr[t] is None or t < 5 or t + 1 >= n:
        return None
    entry = cl[t]
    swing_hi = max(hi[t - 5:t + 1])
    stop = swing_hi + 0.5 * atr[t]
    R = stop - entry
    if R <= 0:
        return None
    tgt_1r = entry - R
    if clip and roomR[t] is not None and roomR[t] < 1.0:
        tp = entry - roomR[t] * R  # nearest support nearer than 1R
    else:
        tp = tgt_1r
    end = min(t + 48, n - 1)
    for j in range(t + 1, end + 1):
        hit_stop = hi[j] >= stop
        hit_tp = lo[j] <= tp
        if hit_stop and hit_tp:
            return (entry - tp) / R if fav_first else -1.0
        if hit_stop:
            return -1.0
        if hit_tp:
            return (entry - tp) / R
    return (entry - cl[end]) / R


def load_volume(path, t_arr):
    vmap = {}
    with open(path) as f:
        rd = csv.reader(f, delimiter=';'); next(rd)
        for r in rd:
            if len(r) < 6:
                continue
            t = datetime.strptime(r[0], "%Y.%m.%d %H:%M")
            vmap[t] = float(r[5])
    return [vmap.get(t) for t in t_arr]


def rolling_mean(vals, n):
    out = [None] * len(vals)
    s = 0.0; q = []
    for i, v in enumerate(vals):
        if v is None:
            q = []; s = 0.0; continue
        q.append(v); s += v
        if len(q) > n:
            s -= q.pop(0)
        if len(q) == n:
            out[i] = s / n
    return out


def mean_se(vals):
    n = len(vals)
    if n == 0:
        return (float('nan'), float('nan'), 0)
    m = sum(vals) / n
    if n < 2:
        return (m, float('nan'), n)
    var = sum((x - m) ** 2 for x in vals) / (n - 1)
    return (m, math.sqrt(var / n), n)


def fmt(vals):
    m, se, n = mean_se(vals)
    wr = sum(1 for x in vals if x > 0) / len(vals) * 100 if vals else float('nan')
    return f"n={n:6d}  E[R]={m:+.4f}  SE={se:.4f}  WR={wr:4.1f}%"


def compute_gate_stats(gates, base_idx, realizedR, t_arr):
    rows = []
    print("\n=== STEP 3: per-gate lift (whole sample) ===")
    print(f"{'gate':22s} {'base%':>6s} {'n_pass':>7s} {'E[R]pass':>9s} {'E[R]fail':>9s} "
          f"{'LIFT':>8s} {'SE_lift':>8s}")
    for gname, fn in gates.items():
        if fn is None:
            continue
        p = [realizedR[t] for t in base_idx if fn(t)]
        f = [realizedR[t] for t in base_idx if not fn(t)]
        mp, sep, npass = mean_se(p)
        mf, sef, nfail = mean_se(f)
        lift = mp - mf
        selift = math.sqrt((sep ** 2 if sep == sep else 0) + (sef ** 2 if sef == sef else 0))
        base_pct = npass / len(base_idx) * 100
        print(f"{gname:22s} {base_pct:6.1f} {npass:7d} {mp:+9.4f} {mf:+9.4f} {lift:+8.4f} {selift:8.4f}")
        row = {"gate": gname, "base_pct": base_pct, "n_pass": npass, "Ep": mp, "Ef": mf,
               "lift": lift, "se": selift, "by_era": {}}
        for ename, l, h in ERAS:
            pe = [realizedR[t] for t in base_idx if fn(t) and l <= t_arr[t].year <= h]
            fe_ = [realizedR[t] for t in base_idx if not fn(t) and l <= t_arr[t].year <= h]
            mpe, _, npe = mean_se(pe)
            mfe, _, nfe = mean_se(fe_)
            row["by_era"][ename] = (mpe - mfe if (npe and nfe) else float('nan'), npe, mpe, mfe)
        rows.append(row)
    # print era breakdown
    print("\n=== STEP 3b: per-gate LIFT by era  (lift [n_pass]) ===")
    hdr = f"{'gate':22s}" + "".join(f"{e[0]:>18s}" for e in ERAS)
    print(hdr)
    for row in rows:
        line = f"{row['gate']:22s}"
        for ename, _, _ in ERAS:
            lift, npe, _, _ = row["by_era"][ename]
            line += f"{lift:+9.4f}[{npe:5d}]" if lift == lift else f"{'n/a':>18s}"
        print(line)
    return rows


def compute_marginal(gates, base_idx, realizedR, t_arr, sev):
    print("\n=== STEP 4: marginal stack (base = severity>=2 cohort) ===")
    downstream = ["loc_close<EMA50", "loc_close<EMA200", "loc_lower_high",
                  "align_D1_deathcross", "align_H4_ema21<50", "trig_ema21_reject",
                  "overext_m3", "room_k1.2", "rr_far>=1.3", "vol_above_avg"]
    base_gate = gates["state_sev>=2"]
    cohort = [t for t in base_idx if base_gate(t)]
    rows = []
    cur = cohort
    m0, se0, n0 = mean_se([realizedR[t] for t in cur])
    print(f"start severity>=2: {fmt([realizedR[t] for t in cur])}")
    rows.append({"step": "sev>=2", "n": n0, "ER": m0, "marg_lift": 0.0, "destroyed": 0})
    for g in downstream:
        fn = gates[g]
        keep = [t for t in cur if fn(t)]
        drop = [t for t in cur if not fn(t)]
        mk, sek, nk = mean_se([realizedR[t] for t in keep])
        md, sed, nd = mean_se([realizedR[t] for t in drop])
        # marginal lift = E[R|kept by this gate within cohort] - E[R|dropped by this gate]
        marg = mk - md if (nk and nd) else float('nan')
        prev_m = mean_se([realizedR[t] for t in cur])[0]
        print(f"  +{g:20s} keep n={nk:6d} E[R]={mk:+.4f} | dropped n={nd:6d} E[R]={md:+.4f} "
              f"| marg_lift(kept-dropped)={marg:+.4f} | cohortE {prev_m:+.4f}->{mk:+.4f}")
        rows.append({"step": g, "n": nk, "ER": mk, "ER_dropped": md, "marg_lift": marg,
                     "destroyed": nd})
        cur = keep
    return rows


def compute_sweeps(base_idx, realizedR, roomR, sev, ema50, atr, cl, t_arr):
    print("\n=== STEP 5a: ROOM-k sweep (nearest lower H1 swing low; within severity>=2) ===")
    coh = [t for t in base_idx if sev[t] >= 2]
    rows = {"room": [], "overext": []}
    print(f"{'k':>5s} {'n_pass':>7s} {'base%':>6s} {'E[R]pass':>9s} {'E[R]fail':>9s} {'lift':>8s}")
    for k in [0.0] + ROOM_KS + [3.0]:
        p = [realizedR[t] for t in coh if roomR[t] is None or roomR[t] >= k]
        f = [realizedR[t] for t in coh if not (roomR[t] is None or roomR[t] >= k)]
        mp, _, npass = mean_se(p); mf, _, nf = mean_se(f)
        lift = mp - mf if (npass and nf) else float('nan')
        print(f"{k:5.1f} {npass:7d} {npass/len(coh)*100:6.1f} {mp:+9.4f} "
              f"{(mf if nf else float('nan')):+9.4f} {lift:+8.4f}")
        rows["room"].append({"k": k, "n": npass, "Ep": mp, "Ef": mf, "lift": lift})
    # ALSO: era robustness of room_k1.2 vs off
    print("\n  room_k1.2 lift by era (within sev>=2):")
    for ename, l, h in ERAS:
        sub = [t for t in coh if l <= t_arr[t].year <= h]
        p = [realizedR[t] for t in sub if roomR[t] is None or roomR[t] >= 1.2]
        f = [realizedR[t] for t in sub if not (roomR[t] is None or roomR[t] >= 1.2)]
        mp, _, npass = mean_se(p); mf, _, nf = mean_se(f)
        lift = mp - mf if (npass and nf) else float('nan')
        print(f"    {ename}: n_pass={npass:5d} E[R]pass={mp:+.4f} lift={lift:+.4f}")

    print("\n=== STEP 5b: OVER-EXT-m sweep (pass = close >= EMA50 - m*ATR; within severity>=2) ===")
    print(f"{'m':>5s} {'n_pass':>7s} {'base%':>6s} {'E[R]pass':>9s} {'E[R]fail':>9s} {'lift':>8s}")
    for m in OVEREXT_MS + [6]:
        def passm(t, m=m):
            return ema50[t] is not None and atr[t] is not None and cl[t] >= ema50[t] - m * atr[t]
        p = [realizedR[t] for t in coh if passm(t)]
        f = [realizedR[t] for t in coh if not passm(t)]
        mp, _, npass = mean_se(p); mf, _, nf = mean_se(f)
        lift = mp - mf if (npass and nf) else float('nan')
        print(f"{m:5d} {npass:7d} {npass/len(coh)*100:6.1f} {mp:+9.4f} "
              f"{(mf if nf else float('nan')):+9.4f} {lift:+8.4f}")
        rows["overext"].append({"m": m, "n": npass, "Ep": mp, "Ef": mf, "lift": lift})
    return rows


def dump(stats_rows, marginal_rows, sweep_rows, all_R, base_idx, realizedR, t_arr, sev,
         roomR, mfeR, maeR):
    import json
    out = {
        "n_base": len(base_idx),
        "uncond": mean_se(all_R),
        "gates": [{k: (v if k != "by_era" else {e: list(x) for e, x in v.items()})
                   for k, v in r.items()} for r in stats_rows],
        "marginal": marginal_rows,
        "sweeps": sweep_rows,
    }
    with open(os.path.join(SCRATCH, "gate_study_results.json"), "w") as f:
        json.dump(out, f, indent=1, default=str)
    print(f"[dump] wrote {os.path.join(SCRATCH, 'gate_study_results.json')}")


if __name__ == "__main__":
    main()
