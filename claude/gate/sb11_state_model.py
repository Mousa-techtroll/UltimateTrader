#!/usr/bin/env python3
"""
SB-1.1 Correction & Bear Event state model — OFFLINE prototype (stdlib only, deterministic).

Program: UltimateTrader short-book program, phase SB-1.1 (workflowAnalysis/short-book-tracker.md).
Registered acceptance: AB_TEST_LOG.md "SB PROGRAM PRE-REGISTRATION" (2026-07-11).

Modes:
  python3 sb11_state_model.py dists            -> unconditional feature distributions (threshold-freezing aid)
  python3 sb11_state_model.py run [states_csv] -> full pipeline: label H1 bars, write states CSV,
                                                  run-length stats, monthly table, episode detection,
                                                  2024-25 false-positive audit, Stats-archive join, worst-40 map

Conventions (frozen):
  - Server time as-is from XAUUSD_H1_rates.csv (Vantage, GMT+2/3). No timezone shifting.
  - H4 buckets: hour // 4 -> 00/04/08/12/16/20 server (MT5 H4 alignment). Buckets formed from
    whatever H1 bars exist (weekend/holiday gaps close buckets early, as MT5 does).
  - D1 buckets: server calendar date (MT5 D1 alignment, server midnight).
  - ALL features are closed-bar: the state at H1 bar T uses only H4/D1 bars fully closed at or
    before T's open. D1-block features use the last COMPLETED day (iClose(D1,1) semantics).
  - EMA: SMA-seeded at index n-1, then recursive (standard). ATR/ADX: Wilder(14).
  - Bearish close = close < previous close (down-day convention, matches market-structure doc).
"""
import csv
import sys
from collections import defaultdict
from datetime import datetime

RATES_PATH = "/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/XAUUSD_H1_rates.csv"
STATS_PATH = ("/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/"
              "_arm_archive/ceg_SF1FULL/UltTrader_Stats_XAUUSD+_20190101_0000.csv")
DEFAULT_STATES_OUT = "/mnt/c/Trading/UltimateTrader/claude/gate/sb11_states.csv"
LABEL_START = datetime(2019, 1, 1)

# =============================================================================
# FROZEN CONSTANTS — chosen a-priori from unconditional distributions (dists mode)
# and round conventions BEFORE any validation scoring. See sb11-state-model.md §2.
# =============================================================================
# Windows (round conventions: 1 day = 6 H4 bars; 5 days = 30 H4; 1 month = 20 D1 / 120 H4)
D1_SLOPE_BARS   = 5      # D1 EMA50 slope lookback (1 week)
H4_SLOPE_BARS   = 30     # H4 EMA50 slope lookback (5 days)
PCT_WINDOW      = 30     # H4 bars for %-closes-below-EMA (5 days)
DD_FAST_BARS    = 20     # D1 bars for pullback drawdown (1 month)
DD_SLOW_BARS    = 60     # D1 bars for correction drawdown (3 months)
ATR_BASE_H4     = 120    # H4 bars for ATR baseline mean (1 month)
ATR_BASE_D1     = 60     # D1 bars for ATR baseline mean (3 months)
BREAK_LOOKBACK  = 30     # H4 bars a support break stays "recent" (5 days)
BREAK_PEN_ATR   = 0.25   # decisive break: close < level - 0.25 x ATR_H4 (quarter-ATR convention)
SUPPORT_MIN_AGE = 12     # H4 bars a pivot-low level must have HELD before its break counts (2 days)
ZZ_ATR_MULT     = 1.0    # zigzag swing filter: opposite pivot needs >= 1.0 x ATR_H4(14) move
FRACTAL_WING    = 2      # 5-bar fractal (2 bars each side); pivot confirmed 2 bars after

# Bear-score thresholds (percentile anchors from dists mode, FROZEN before validation scoring):
#   roc20 p25 = -1.5%, p10 = -3.9% -> -1.5% / -4%
#   roc5  p25 = -1.0%, p10 = -2.4% -> -1.0% / -2.5%
#   dd60  p50 = 4.2%, p75 = 6.4%, p90 = 9.4% -> 4% / 7% / 10%
ROC20_MILD, ROC20_DEEP   = -0.015, -0.04   # D1 20-day RoC
ROC5_MILD,  ROC5_DEEP    = -0.01, -0.025   # D1 5-day RoC
DD60_T1, DD60_T2, DD60_T3 = 0.04, 0.07, 0.10  # drawdown from 60-day D1 high
PCT_BELOW_T     = 0.60   # % of last 30 H4 closes below EMA
ADX_TREND       = 25.0   # conventional ADX trend threshold
CONSEC_D1_A, CONSEC_D1_B = 3, 5
CONSEC_H4_T     = 5

# Bear-score points (blocks: D1 structure 30 / momentum 30 / H4 structure 30 / events 10)
PTS = dict(
    d1_close_below_ema50 = 6,
    d1_ema50_slope_neg   = 6,
    d1_death_cross       = 8,   # EMA50 < EMA200
    d1_close_below_ema200= 6,
    d1_adx_downtrend     = 4,   # ADX>=25 AND close<EMA50
    roc20_mild = 4,  roc20_deep = 10,   # graded (deep replaces mild)
    roc5_mild  = 3,  roc5_deep  = 6,
    dd60_t1 = 5, dd60_t2 = 10, dd60_t3 = 14,
    h4_ema21_lt_50   = 4,
    h4_ema50_lt_200  = 5,
    h4_ema50_slope_neg = 4,
    h4_pct_below21   = 3,
    h4_pct_below50   = 3,
    h4_lh_ll         = 6,
    h4_support_break = 5,   # break of confirmed H4 support within 30 bars, close still below
    ev_failed_reclaim = 4,  # reclaim attempted and rejected within 30 bars
    ev_consec_d1_a = 2, ev_consec_d1_b = 4,   # graded
    ev_consec_h4   = 2,
)

# State machine (hysteresis)
ENTER_AC, EXIT_AC     = 50, 35
ENTER_BT, EXIT_BT     = 65, 50
ENTER_BEAR, EXIT_BEAR = 75, 60   # BEAR_TREND additionally requires D1 confirm (cross or close<EMA200)
MIN_DWELL_H4          = 6        # min H4 bars in a state before DE-escalation (escalation immediate)
EXIT_CONFIRM_H4       = 3        # consecutive H4 closes satisfying exit condition to de-escalate
RALLY_FRAC            = 0.382    # Fibonacci convention: BEAR_RALLY overlay retrace fraction
VOL_H4_ENTER, VOL_H4_EXIT = 1.75, 1.50   # H4 ATR14 / mean(prior 120)
VOL_D1_ENTER, VOL_D1_EXIT = 1.50, 1.30   # D1 ATR14 / mean(prior 60)
RANGE_ADX_ENTER, RANGE_ADX_EXIT = 18.0, 22.0
RANGE_DD60_MAX, RANGE_ROC20_ABS = 0.04, 0.02
PULLBACK_DD20_ENTER, PULLBACK_DD20_EXIT = 0.03, 0.015   # dd20 p50 = 2.4%, p75 = 4.4% -> 3% enter

BEAR_FAMILY = {"ACTIVE_CORRECTION", "BEAR_TRANSITION", "BEAR_TREND", "BEAR_RALLY"}
SEVERITY = {"BULL_TREND": 0, "RANGE": 0, "BULL_PULLBACK": 1, "VOLATILE_TRANSITION": 1,
            "ACTIVE_CORRECTION": 2, "BEAR_RALLY": 2, "BEAR_TRANSITION": 3, "BEAR_TREND": 4}

# Hand-labeled episodes (short-side-market-structure.md §1.1) + registered D1 death-cross refs
EPISODES = [
    ("E1  COVID",        datetime(2020, 3, 9),  datetime(2020, 3, 19), None),
    ("E2a 2020H2",       datetime(2020, 8, 6),  datetime(2020, 11, 30), datetime(2021, 3, 4)),
    ("E2b 2021Q1",       datetime(2021, 1, 5),  datetime(2021, 3, 8),  datetime(2021, 3, 4)),
    ("E3  Jun-21",       datetime(2021, 6, 1),  datetime(2021, 6, 29), None),
    ("E4  2022 bear",    datetime(2022, 3, 8),  datetime(2022, 9, 26), datetime(2022, 7, 1)),
    ("E5  2023",         datetime(2023, 5, 4),  datetime(2023, 10, 5), datetime(2023, 10, 5)),
    ("E6  2024-11",      datetime(2024, 10, 30), datetime(2024, 11, 14), None),
    ("E7a 2025-05",      datetime(2025, 5, 6),  datetime(2025, 5, 14), None),
    ("E7b 2025-Q4",      datetime(2025, 10, 20), datetime(2025, 10, 29), None),
    ("E8  2026H1",       datetime(2026, 1, 28), datetime(2026, 6, 24), datetime(2026, 7, 8)),
]


# ----------------------------------------------------------------------------- indicators
def ema_series(vals, n):
    out = [None] * len(vals)
    if len(vals) < n:
        return out
    seed = sum(vals[:n]) / n
    out[n - 1] = seed
    k = 2.0 / (n + 1)
    for i in range(n, len(vals)):
        out[i] = out[i - 1] + k * (vals[i] - out[i - 1])
    return out


def wilder_atr(h, l, c, n=14):
    m = len(c)
    tr = [None] * m
    for i in range(1, m):
        tr[i] = max(h[i] - l[i], abs(h[i] - c[i - 1]), abs(l[i] - c[i - 1]))
    out = [None] * m
    if m <= n:
        return out
    seed = sum(tr[1:n + 1]) / n
    out[n] = seed
    for i in range(n + 1, m):
        out[i] = (out[i - 1] * (n - 1) + tr[i]) / n
    return out


def wilder_adx(h, l, c, n=14):
    m = len(c)
    adx = [None] * m
    if m <= 2 * n:
        return adx
    plus_dm, minus_dm, tr = [0.0] * m, [0.0] * m, [0.0] * m
    for i in range(1, m):
        up, dn = h[i] - h[i - 1], l[i - 1] - l[i]
        plus_dm[i] = up if (up > dn and up > 0) else 0.0
        minus_dm[i] = dn if (dn > up and dn > 0) else 0.0
        tr[i] = max(h[i] - l[i], abs(h[i] - c[i - 1]), abs(l[i] - c[i - 1]))
    s_p, s_m, s_t = sum(plus_dm[1:n + 1]), sum(minus_dm[1:n + 1]), sum(tr[1:n + 1])
    dx = [None] * m
    for i in range(n + 1, m):
        s_p = s_p - s_p / n + plus_dm[i]
        s_m = s_m - s_m / n + minus_dm[i]
        s_t = s_t - s_t / n + tr[i]
        if s_t <= 0:
            continue
        pdi, mdi = 100.0 * s_p / s_t, 100.0 * s_m / s_t
        dx[i] = 100.0 * abs(pdi - mdi) / (pdi + mdi) if (pdi + mdi) > 0 else 0.0
    first = n + 1
    seed_vals = [dx[i] for i in range(first, first + n) if dx[i] is not None]
    if len(seed_vals) < n:
        return adx
    adx[first + n - 1] = sum(seed_vals) / n
    for i in range(first + n, m):
        adx[i] = (adx[i - 1] * (n - 1) + (dx[i] if dx[i] is not None else 0.0)) / n
    return adx


# ----------------------------------------------------------------------------- data
def load_h1(path):
    rows = []
    with open(path, "r", newline="") as f:
        rd = csv.reader(f, delimiter=";")
        next(rd)
        for r in rd:
            if len(r) < 5:
                continue
            t = datetime.strptime(r[0], "%Y.%m.%d %H:%M")
            rows.append((t, float(r[1]), float(r[2]), float(r[3]), float(r[4])))
    return rows


class Bars:
    def __init__(self):
        self.t, self.o, self.h, self.l, self.c = [], [], [], [], []

    def add(self, t, o, h, l, c):
        self.t.append(t); self.o.append(o); self.h.append(h); self.l.append(l); self.c.append(c)

    def __len__(self):
        return len(self.t)


def resample(h1):
    """Return (h4, d1, h1_h4idx, h1_d1idx): closed-bar indices available AT each H1 bar's open.
    h1_h4idx[i] = index of last H4 bar fully closed before H1 bar i begins (-1 if none)."""
    h4, d1 = Bars(), Bars()
    h4_key = d1_key = None
    cur4 = curd = None
    h1_h4idx, h1_d1idx = [], []
    for (t, o, h, l, c) in h1:
        k4 = (t.date(), t.hour // 4)
        kd = t.date()
        if k4 != h4_key:
            if cur4 is not None:
                h4.add(*cur4)
            h4_key, cur4 = k4, [t.replace(hour=(t.hour // 4) * 4, minute=0), o, h, l, c]
        else:
            cur4[2] = max(cur4[2], h); cur4[3] = min(cur4[3], l); cur4[4] = c
        if kd != d1_key:
            if curd is not None:
                d1.add(*curd)
            d1_key, curd = kd, [datetime(t.year, t.month, t.day), o, h, l, c]
        else:
            curd[2] = max(curd[2], h); curd[3] = min(curd[3], l); curd[4] = c
        h1_h4idx.append(len(h4) - 1)
        h1_d1idx.append(len(d1) - 1)
    if cur4 is not None:
        h4.add(*cur4)
    if curd is not None:
        d1.add(*curd)
    return h4, d1, h1_h4idx, h1_d1idx


# ----------------------------------------------------------------------------- swing structure (H4)
class SwingEngine:
    """5-bar fractal pivots + ATR-filtered zigzag alternation. All state as of closed bars only."""

    def __init__(self, h4, atr):
        self.h4, self.atr = h4, atr
        self.pivots = []            # list of (type 'H'/'L', bar_idx, price)
        self.breaks = []            # dicts: level, break_bar, last_fail_bar
        self._broken_levels = set()

    def _try_add(self, ptype, idx, price):
        if self.pivots and self.pivots[-1][0] == ptype:
            # same type: keep the more extreme
            _, pi, pp = self.pivots[-1]
            if (ptype == "H" and price > pp) or (ptype == "L" and price < pp):
                self.pivots[-1] = (ptype, idx, price)
        else:
            a = self.atr[idx]
            if self.pivots and a is not None:
                if abs(price - self.pivots[-1][2]) < ZZ_ATR_MULT * a:
                    return
            self.pivots.append((ptype, idx, price))

    def on_close(self, t):
        h4 = self.h4
        i = t - FRACTAL_WING
        if i >= FRACTAL_WING:
            win_h = h4.h[i - FRACTAL_WING:i + FRACTAL_WING + 1]
            win_l = h4.l[i - FRACTAL_WING:i + FRACTAL_WING + 1]
            if h4.h[i] >= max(win_h) and h4.h[i] > h4.h[i - 1] and h4.h[i] > h4.h[i + 1]:
                self._try_add("H", i, h4.h[i])
            if h4.l[i] <= min(win_l) and h4.l[i] < h4.l[i - 1] and h4.l[i] < h4.l[i + 1]:
                self._try_add("L", i, h4.l[i])
        # support break: first DECISIVE close below the latest confirmed pivot-low level
        lows = [p for p in self.pivots if p[0] == "L"]
        a_now = self.atr[t]
        if lows and a_now is not None:
            lvl_bar, lvl = lows[-1][1], lows[-1][2]
            key = (lvl_bar, round(lvl, 2))
            if (h4.c[t] < lvl - BREAK_PEN_ATR * a_now and key not in self._broken_levels
                    and t - lvl_bar >= SUPPORT_MIN_AGE):
                self._broken_levels.add(key)
                self.breaks.append({"level": lvl, "break_bar": t, "last_fail_bar": None})
        # failed-reclaim scan on recent breaks: attempt reached the level, closed decisively below
        for b in self.breaks:
            if t - b["break_bar"] <= BREAK_LOOKBACK and t > b["break_bar"] and a_now is not None:
                if h4.h[t] >= b["level"] and h4.c[t] < b["level"] - BREAK_PEN_ATR * a_now:
                    b["last_fail_bar"] = t

    def features(self, t):
        highs = [p for p in self.pivots if p[0] == "H"]
        lows = [p for p in self.pivots if p[0] == "L"]
        lh = len(highs) >= 2 and highs[-1][2] < highs[-2][2]
        ll = len(lows) >= 2 and lows[-1][2] < lows[-2][2]
        active_break = any(0 <= t - b["break_bar"] <= BREAK_LOOKBACK and self.h4.c[t] < b["level"]
                           for b in self.breaks)
        failed_reclaim = any(b["last_fail_bar"] is not None and
                             0 <= t - b["last_fail_bar"] <= BREAK_LOOKBACK
                             for b in self.breaks)
        return lh and ll, active_break, failed_reclaim


# ----------------------------------------------------------------------------- feature assembly
class FeatureEngine:
    def __init__(self, h4, d1):
        self.h4, self.d1 = h4, d1
        self.h4_ema21 = ema_series(h4.c, 21)
        self.h4_ema50 = ema_series(h4.c, 50)
        self.h4_ema200 = ema_series(h4.c, 200)
        self.h4_atr = wilder_atr(h4.h, h4.l, h4.c, 14)
        self.h4_adx = wilder_adx(h4.h, h4.l, h4.c, 14)
        self.d1_ema50 = ema_series(d1.c, 50)
        self.d1_ema200 = ema_series(d1.c, 200)
        self.d1_atr = wilder_atr(d1.h, d1.l, d1.c, 14)
        self.d1_adx = wilder_adx(d1.h, d1.l, d1.c, 14)
        self.swings = SwingEngine(h4, self.h4_atr)
        self._h4_consec = [0] * len(h4)
        for i in range(1, len(h4)):
            self._h4_consec[i] = self._h4_consec[i - 1] + 1 if h4.c[i] < h4.c[i - 1] else 0
        self._d1_consec = [0] * len(d1)
        for i in range(1, len(d1)):
            self._d1_consec[i] = self._d1_consec[i - 1] + 1 if d1.c[i] < d1.c[i - 1] else 0

    def d1_feats(self, d):
        """Features of the last COMPLETED day d (index into d1)."""
        d1 = self.d1
        f = {}
        c = d1.c[d]
        e50, e200 = self.d1_ema50[d], self.d1_ema200[d]
        f["close_below_ema50"] = (e50 is not None and c < e50)
        f["ema50_slope_neg"] = (e50 is not None and d >= D1_SLOPE_BARS and
                                self.d1_ema50[d - D1_SLOPE_BARS] is not None and
                                e50 < self.d1_ema50[d - D1_SLOPE_BARS])
        f["death_cross"] = (e50 is not None and e200 is not None and e50 < e200)
        f["close_below_ema200"] = (e200 is not None and c < e200)
        adx = self.d1_adx[d]
        f["adx"] = adx
        f["adx_downtrend"] = (adx is not None and adx >= ADX_TREND and f["close_below_ema50"])
        f["roc5"] = (c / d1.c[d - 5] - 1.0) if d >= 5 else 0.0
        f["roc20"] = (c / d1.c[d - 20] - 1.0) if d >= 20 else 0.0
        w20 = d1.h[max(0, d - DD_FAST_BARS + 1):d + 1]
        w60 = d1.h[max(0, d - DD_SLOW_BARS + 1):d + 1]
        f["dd20"] = (max(w20) - c) / max(w20) if len(w20) >= 10 else 0.0
        f["dd60"] = (max(w60) - c) / max(w60) if len(w60) >= 20 else 0.0
        a = self.d1_atr[d]
        base = [x for x in self.d1_atr[max(0, d - ATR_BASE_D1):d] if x is not None]
        f["atr_ratio"] = (a / (sum(base) / len(base))) if (a is not None and len(base) >= 20) else 1.0
        f["consec_bear"] = self._d1_consec[d]
        return f

    def h4_feats(self, t):
        h4 = self.h4
        f = {}
        c = h4.c[t]
        e21, e50, e200 = self.h4_ema21[t], self.h4_ema50[t], self.h4_ema200[t]
        f["ema21_lt_50"] = (e21 is not None and e50 is not None and e21 < e50)
        f["ema50_lt_200"] = (e50 is not None and e200 is not None and e50 < e200)
        f["ema50_slope_neg"] = (e50 is not None and t >= H4_SLOPE_BARS and
                                self.h4_ema50[t - H4_SLOPE_BARS] is not None and
                                e50 < self.h4_ema50[t - H4_SLOPE_BARS])
        lo = max(0, t - PCT_WINDOW + 1)
        n21 = n50 = na = 0
        for j in range(lo, t + 1):
            if self.h4_ema21[j] is not None and self.h4_ema50[j] is not None:
                na += 1
                if h4.c[j] < self.h4_ema21[j]:
                    n21 += 1
                if h4.c[j] < self.h4_ema50[j]:
                    n50 += 1
        f["pct_below21"] = n21 / na if na >= 10 else 0.0
        f["pct_below50"] = n50 / na if na >= 10 else 0.0
        f["close_gt_ema21"] = (e21 is not None and c > e21)
        a = self.h4_atr[t]
        base = [x for x in self.h4_atr[max(0, t - ATR_BASE_H4):t] if x is not None]
        f["atr_ratio"] = (a / (sum(base) / len(base))) if (a is not None and len(base) >= 40) else 1.0
        f["adx"] = self.h4_adx[t]
        f["consec_bear"] = self._h4_consec[t]
        f["lh_ll"], f["support_break"], f["failed_reclaim"] = self.swings.features(t)
        return f


def bear_score(d1f, h4f):
    p = PTS
    s = 0
    parts = {}
    def add(name, pts):
        nonlocal s
        if pts:
            s += pts
            parts[name] = pts
    add("d1_close_below_ema50", p["d1_close_below_ema50"] if d1f["close_below_ema50"] else 0)
    add("d1_ema50_slope_neg", p["d1_ema50_slope_neg"] if d1f["ema50_slope_neg"] else 0)
    add("d1_death_cross", p["d1_death_cross"] if d1f["death_cross"] else 0)
    add("d1_close_below_ema200", p["d1_close_below_ema200"] if d1f["close_below_ema200"] else 0)
    add("d1_adx_downtrend", p["d1_adx_downtrend"] if d1f["adx_downtrend"] else 0)
    r20 = d1f["roc20"]
    add("roc20", p["roc20_deep"] if r20 <= ROC20_DEEP else (p["roc20_mild"] if r20 <= ROC20_MILD else 0))
    r5 = d1f["roc5"]
    add("roc5", p["roc5_deep"] if r5 <= ROC5_DEEP else (p["roc5_mild"] if r5 <= ROC5_MILD else 0))
    dd = d1f["dd60"]
    add("dd60", p["dd60_t3"] if dd >= DD60_T3 else (p["dd60_t2"] if dd >= DD60_T2 else
        (p["dd60_t1"] if dd >= DD60_T1 else 0)))
    add("h4_ema21_lt_50", p["h4_ema21_lt_50"] if h4f["ema21_lt_50"] else 0)
    add("h4_ema50_lt_200", p["h4_ema50_lt_200"] if h4f["ema50_lt_200"] else 0)
    add("h4_ema50_slope_neg", p["h4_ema50_slope_neg"] if h4f["ema50_slope_neg"] else 0)
    add("h4_pct_below21", p["h4_pct_below21"] if h4f["pct_below21"] >= PCT_BELOW_T else 0)
    add("h4_pct_below50", p["h4_pct_below50"] if h4f["pct_below50"] >= PCT_BELOW_T else 0)
    add("h4_lh_ll", p["h4_lh_ll"] if h4f["lh_ll"] else 0)
    add("h4_support_break", p["h4_support_break"] if h4f["support_break"] else 0)
    add("ev_failed_reclaim", p["ev_failed_reclaim"] if h4f["failed_reclaim"] else 0)
    cd = d1f["consec_bear"]
    add("ev_consec_d1", p["ev_consec_d1_b"] if cd >= CONSEC_D1_B else
        (p["ev_consec_d1_a"] if cd >= CONSEC_D1_A else 0))
    add("ev_consec_h4", p["ev_consec_h4"] if h4f["consec_bear"] >= CONSEC_H4_T else 0)
    return s, parts


# ----------------------------------------------------------------------------- state machine
class StateMachine:
    """Severity ladder S in {0,2,3,4} driven by bear score B with hysteresis; overlays for
    BEAR_RALLY (S>=2), and VOLATILE/RANGE/PULLBACK/BULL at S=0.
    Escalation: immediate on H4 close. De-escalation: needs state age >= MIN_DWELL_H4 AND the
    exit condition true on EXIT_CONFIRM_H4 consecutive H4 closes."""

    def __init__(self):
        self.S = 0
        self.label = "BULL_TREND"
        self.label_age = 0        # H4 bars in current reported label
        self.s_age = 0            # H4 bars at current severity level
        self.exit_streak = 0
        self.vol_on = False
        self.range_on = False
        self.pullback_on = False
        self.sub_age = 999
        self.ep_low = None        # running low since S>=2 entry (BEAR_RALLY anchor)
        self.ep_high = None       # 60d D1 high frozen at S>=2 entry
        self.transitions = []     # (h4_time, from_label, to_label, B, margin)

    def _severity_target(self, B, d1f):
        bear_ok = d1f["death_cross"] or d1f["close_below_ema200"]
        if B >= ENTER_BEAR and bear_ok:
            return 4
        if B >= ENTER_BT:
            return 3
        if B >= ENTER_AC:
            return 2
        return 0

    def _exit_cond(self, B):
        if self.S == 4:
            return B < EXIT_BEAR
        if self.S == 3:
            return B < EXIT_BT
        if self.S == 2:
            return B < EXIT_AC
        return False

    def update(self, t, h4bars, B, d1f, h4f):
        prev_label = self.label
        target = self._severity_target(B, d1f)

        if target > self.S:                                   # escalation: immediate
            if self.S == 0:
                self.ep_low = h4bars.l[t]
                w = d1f["dd60_ref_high"]
                self.ep_high = w
            self.S = target
            self.s_age = 0
            self.exit_streak = 0
        else:
            if self._exit_cond(B):
                self.exit_streak += 1
            else:
                self.exit_streak = 0
            if (self.exit_streak >= EXIT_CONFIRM_H4 and self.s_age >= MIN_DWELL_H4 and self.S > 0):
                self.S = {4: 3, 3: 2, 2: 0}[self.S]
                self.s_age = 0
                self.exit_streak = 0
                if self.S == 0:
                    self.ep_low = self.ep_high = None

        # ---- overlays
        if self.S >= 2:
            self.ep_low = min(self.ep_low, h4bars.l[t]) if self.ep_low is not None else h4bars.l[t]
            rally = False
            if self.ep_high and self.ep_high > self.ep_low:
                frac = (h4bars.c[t] - self.ep_low) / (self.ep_high - self.ep_low)
                rally = frac >= RALLY_FRAC and h4f["close_gt_ema21"]
            base = {2: "ACTIVE_CORRECTION", 3: "BEAR_TRANSITION", 4: "BEAR_TREND"}[self.S]
            new_label = "BEAR_RALLY" if rally else base
        else:
            # sub-state hysteresis at S=0
            vol_enter = h4f["atr_ratio"] >= VOL_H4_ENTER or d1f["atr_ratio"] >= VOL_D1_ENTER
            vol_stay = h4f["atr_ratio"] >= VOL_H4_EXIT or d1f["atr_ratio"] >= VOL_D1_EXIT
            self.vol_on = vol_enter or (self.vol_on and vol_stay)
            adx = d1f["adx"] if d1f["adx"] is not None else 99.0
            rng_enter = adx < RANGE_ADX_ENTER and d1f["dd60"] < RANGE_DD60_MAX and abs(d1f["roc20"]) < RANGE_ROC20_ABS
            rng_stay = adx < RANGE_ADX_EXIT and d1f["dd60"] < DD60_T2 and abs(d1f["roc20"]) < 0.03
            self.range_on = rng_enter or (self.range_on and rng_stay)
            pb_enter = d1f["dd20"] >= PULLBACK_DD20_ENTER
            pb_stay = d1f["dd20"] > PULLBACK_DD20_EXIT
            self.pullback_on = pb_enter or (self.pullback_on and pb_stay)
            if self.vol_on:
                cand = "VOLATILE_TRANSITION"
            elif self.range_on:
                cand = "RANGE"
            elif self.pullback_on:
                cand = "BULL_PULLBACK"
            else:
                cand = "BULL_TREND"
            if prev_label in BEAR_FAMILY or prev_label == cand:
                new_label = cand
                if prev_label in BEAR_FAMILY:
                    self.sub_age = 0
            else:
                # dwell between bull-side sub-states
                if self.sub_age >= MIN_DWELL_H4 or prev_label not in ("BULL_TREND", "BULL_PULLBACK",
                                                                      "RANGE", "VOLATILE_TRANSITION"):
                    new_label = cand
                    self.sub_age = 0
                else:
                    new_label = prev_label

        self.s_age += 1
        self.sub_age += 1
        if new_label != prev_label:
            thr = {2: ENTER_AC, 3: ENTER_BT, 4: ENTER_BEAR}.get(SEVERITY.get(new_label, 0), 0)
            margin = B - thr if new_label in BEAR_FAMILY else 0
            self.transitions.append((h4bars.t[t], prev_label, new_label, B, margin))
            self.label = new_label
            self.label_age = 1
        else:
            self.label_age += 1
        return self.label


# ----------------------------------------------------------------------------- pipeline
def build_states():
    h1 = load_h1(RATES_PATH)
    h4, d1, h1_h4idx, h1_d1idx = resample(h1)
    fe = FeatureEngine(h4, d1)
    sm = StateMachine()

    # walk H4 bars in order; a bar t is "closed" once bar t+1 exists. We process closes and
    # record (state, score, age) effective from the close time onward.
    n4 = len(h4)
    # map: for each closed H4 index t, the last completed D1 index at that close time
    d1_idx_at_h4close = []
    di = 0
    for t in range(n4):
        close_time = h4.t[t + 1] if t + 1 < n4 else None
        # last completed day strictly before the next bar's open date:
        # the day of h4 bar t is completed iff next H4 bar is a later date
        pass
    # simpler: precompute completed-day index per H4 close: day d is complete once a bar with a
    # later date exists. At close of h4 bar t (i.e., when bar t+1 opens), completed days are all
    # dates < h4.t[t+1].date().
    d1_dates = [x.date() for x in d1.t]
    states_by_h4 = [None] * n4   # (label, score, label_age) effective AFTER h4 bar t closes
    dptr = -1
    for t in range(n4 - 1):
        next_date = h4.t[t + 1].date()
        while dptr + 1 < len(d1_dates) and d1_dates[dptr + 1] < next_date:
            dptr += 1
        fe.swings.on_close(t)
        if dptr < 0:
            continue
        d1f = fe.d1_feats(dptr)
        w60 = d1.h[max(0, dptr - DD_SLOW_BARS + 1):dptr + 1]
        d1f["dd60_ref_high"] = max(w60) if w60 else None
        h4f = fe.h4_feats(t)
        B, _parts = bear_score(d1f, h4f)
        label = sm.update(t, h4, B, d1f, h4f)
        states_by_h4[t] = (label, B, sm.label_age)

    # H1 labels: state from the last CLOSED H4 bar before this H1 bar
    labels = []
    for i, (t, *_r) in enumerate(h1):
        cur4 = h1_h4idx[i]
        closed = cur4 - 1
        if closed >= 0 and states_by_h4[closed] is not None:
            lab, sc, age = states_by_h4[closed]
        else:
            lab, sc, age = "BULL_TREND", 0, 0
        labels.append((t, lab, sc, age))
    return h1, h4, d1, fe, sm, states_by_h4, labels


# ----------------------------------------------------------------------------- dists mode
def pctiles(vals, ps=(5, 10, 25, 50, 75, 90, 95)):
    v = sorted(vals)
    out = []
    for p in ps:
        if not v:
            out.append(None)
            continue
        k = (len(v) - 1) * p / 100.0
        f = int(k)
        c = min(f + 1, len(v) - 1)
        out.append(v[f] + (v[c] - v[f]) * (k - f))
    return out


def run_dists():
    h1 = load_h1(RATES_PATH)
    h4, d1, _, _ = resample(h1)
    fe = FeatureEngine(h4, d1)
    print(f"H1 bars {len(h1)}  H4 bars {len(h4)}  D1 bars {len(d1)}")
    print(f"range {h1[0][0]} -> {h1[-1][0]}")

    dd = {"roc5": [], "roc20": [], "dd20": [], "dd60": [], "atr_ratio": [], "adx": [], "consec": []}
    for d in range(60, len(d1)):
        f = fe.d1_feats(d)
        for k in ("roc5", "roc20", "dd20", "dd60", "atr_ratio", "consec_bear"):
            key = "consec" if k == "consec_bear" else k
            if f.get(k if k != "consec_bear" else "consec_bear") is not None:
                dd[key].append(f[k])
        if f["adx"] is not None:
            dd["adx"].append(f["adx"])
    hh = {"atr_ratio": [], "adx": [], "pct21": [], "pct50": [], "lhll": 0, "brk": 0, "fr": 0, "n": 0,
          "consec": []}
    for t in range(len(h4) - 1):
        fe.swings.on_close(t)          # interleaved: features below see only pivots/breaks <= t
        if t < 220:
            continue
        f = fe.h4_feats(t)
        hh["atr_ratio"].append(f["atr_ratio"])
        if f["adx"] is not None:
            hh["adx"].append(f["adx"])
        hh["pct21"].append(f["pct_below21"])
        hh["pct50"].append(f["pct_below50"])
        hh["consec"].append(f["consec_bear"])
        hh["n"] += 1
        hh["lhll"] += f["lh_ll"]
        hh["brk"] += f["support_break"]
        hh["fr"] += f["failed_reclaim"]

    def prt(name, vals, fmt="{:+.4f}"):
        ps = pctiles(vals)
        print(f"{name:14s} " + "  ".join((fmt.format(x) if x is not None else "  --  ") for x in ps))

    print("\n=== D1 unconditional (p5/p10/p25/p50/p75/p90/p95), n=%d ===" % len(dd["roc20"]))
    prt("roc5", dd["roc5"]); prt("roc20", dd["roc20"])
    prt("dd20", dd["dd20"], "{:.4f}"); prt("dd60", dd["dd60"], "{:.4f}")
    prt("atr_ratio", dd["atr_ratio"], "{:.3f}"); prt("adx", dd["adx"], "{:.1f}")
    for thr, key in ((ROC20_MILD, "roc20"), (ROC20_DEEP, "roc20")):
        share = sum(1 for x in dd[key] if x <= thr) / len(dd[key])
        print(f"  share {key} <= {thr:+.3f}: {share:.1%}")
    for thr, key in ((ROC5_MILD, "roc5"), (ROC5_DEEP, "roc5")):
        share = sum(1 for x in dd[key] if x <= thr) / len(dd[key])
        print(f"  share {key} <= {thr:+.3f}: {share:.1%}")
    for thr in (DD60_T1, DD60_T2, DD60_T3):
        share = sum(1 for x in dd["dd60"] if x >= thr) / len(dd["dd60"])
        print(f"  share dd60 >= {thr:.2f}: {share:.1%}")
    for thr in (PULLBACK_DD20_ENTER,):
        share = sum(1 for x in dd["dd20"] if x >= thr) / len(dd["dd20"])
        print(f"  share dd20 >= {thr:.2f}: {share:.1%}")
    share = sum(1 for x in dd["atr_ratio"] if x >= VOL_D1_ENTER) / len(dd["atr_ratio"])
    print(f"  share d1 atr_ratio >= {VOL_D1_ENTER}: {share:.1%}")
    share = sum(1 for x in dd["adx"] if x < RANGE_ADX_ENTER) / len(dd["adx"])
    print(f"  share d1 adx < {RANGE_ADX_ENTER}: {share:.1%}")
    for thr in (CONSEC_D1_A, CONSEC_D1_B):
        share = sum(1 for x in dd["consec"] if x >= thr) / len(dd["consec"])
        print(f"  share consec D1 down >= {thr}: {share:.1%}")

    print("\n=== H4 unconditional, n=%d ===" % hh["n"])
    prt("atr_ratio", hh["atr_ratio"], "{:.3f}"); prt("adx", hh["adx"], "{:.1f}")
    prt("pct_below21", hh["pct21"], "{:.3f}"); prt("pct_below50", hh["pct50"], "{:.3f}")
    share = sum(1 for x in hh["atr_ratio"] if x >= VOL_H4_ENTER) / hh["n"]
    print(f"  share h4 atr_ratio >= {VOL_H4_ENTER}: {share:.1%}")
    for key, lab in (("lhll", "LH+LL active"), ("brk", "support break active"), ("fr", "failed reclaim active")):
        print(f"  share {lab}: {hh[key]/hh['n']:.1%}")
    for thr in (PCT_BELOW_T,):
        s21 = sum(1 for x in hh["pct21"] if x >= thr) / hh["n"]
        s50 = sum(1 for x in hh["pct50"] if x >= thr) / hh["n"]
        print(f"  share pct_below21 >= {thr}: {s21:.1%}   pct_below50 >= {thr}: {s50:.1%}")
    share = sum(1 for x in hh["consec"] if x >= CONSEC_H4_T) / hh["n"]
    print(f"  share consec H4 down >= {CONSEC_H4_T}: {share:.1%}")

    # D1 death-cross dates on this file (SMA-seeded EMAs)
    e50, e200 = fe.d1_ema50, fe.d1_ema200
    print("\n=== computed D1 EMA50/200 crossings (this file, SMA-seeded) ===")
    for d in range(1, len(d1)):
        if e50[d] is None or e200[d] is None or e50[d - 1] is None or e200[d - 1] is None:
            continue
        if (e50[d - 1] >= e200[d - 1]) and (e50[d] < e200[d]):
            print(f"  DEATH cross {d1.t[d].date()}")
        if (e50[d - 1] <= e200[d - 1]) and (e50[d] > e200[d]):
            print(f"  golden cross {d1.t[d].date()}")


# ----------------------------------------------------------------------------- run mode
def month_key(t):
    return f"{t.year}-{t.month:02d}"


def run_full(states_out):
    h1, h4, d1, fe, sm, states_by_h4, labels = build_states()

    # ---- states CSV (H1 shadow ledger)
    with open(states_out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["BarTime", "State", "Score", "StateAgeH4"])
        for (t, lab, sc, age) in labels:
            if t >= LABEL_START:
                w.writerow([t.strftime("%Y.%m.%d %H:%M"), lab, sc, age])
    n_out = sum(1 for (t, *_x) in labels if t >= LABEL_START)
    print(f"[csv] wrote {n_out} H1 rows -> {states_out}")

    # ---- run-length statistics on the H4-level label sequence (2019+)
    seq = [(h4.t[t], states_by_h4[t][0]) for t in range(len(h4) - 1)
           if states_by_h4[t] is not None and h4.t[t] >= LABEL_START]
    runs = []
    cur, start, cnt = None, None, 0
    for tm, lab in seq:
        if lab != cur:
            if cur is not None:
                runs.append((cur, start, prev_tm, cnt))
            cur, start, cnt = lab, tm, 0
        cnt += 1
        prev_tm = tm
    runs.append((cur, start, prev_tm, cnt))
    print("\n=== state run-length stats (H4 bars; 2019-01-01 .. end) ===")
    per = defaultdict(list)
    for lab, s, e, n in runs:
        per[lab].append(n)
    total_bars = len(seq)
    print(f"{'state':22s} {'runs':>5s} {'medLen':>7s} {'meanLen':>8s} {'maxLen':>7s} {'bars%':>7s}")
    for lab in ("BULL_TREND", "BULL_PULLBACK", "RANGE", "VOLATILE_TRANSITION",
                "ACTIVE_CORRECTION", "BEAR_RALLY", "BEAR_TRANSITION", "BEAR_TREND"):
        v = per.get(lab, [])
        if not v:
            print(f"{lab:22s} {0:5d}")
            continue
        sv = sorted(v)
        med = sv[len(sv) // 2] if len(sv) % 2 else (sv[len(sv)//2 - 1] + sv[len(sv)//2]) / 2
        print(f"{lab:22s} {len(v):5d} {med:7.1f} {sum(v)/len(v):8.1f} {max(v):7d} "
              f"{100.0*sum(v)/total_bars:6.1f}%")
    years = (seq[-1][0] - seq[0][0]).days / 365.25
    print(f"total transitions: {len(runs)-1}  over {years:.2f}y  = {(len(runs)-1)/years:.1f}/year")
    bear_runs = [r for r in runs if r[0] in BEAR_FAMILY]
    print(f"bear-family runs: {len(bear_runs)}")

    # consolidated bear-family episodes (contiguous bear-family H4 bars)
    fam_runs = []
    cur, start, cnt = None, None, 0
    for tm, lab in seq:
        fam = lab in BEAR_FAMILY
        if fam != cur:
            if cur:
                fam_runs.append((start, prev2, cnt))
            cur, start, cnt = fam, tm, 0
        cnt += 1
        prev2 = tm
    if cur:
        fam_runs.append((start, prev2, cnt))
    print(f"consolidated bear-family episodes (any AC/BT/BEAR/RALLY): {len(fam_runs)}")

    # ---- monthly table
    print("\n=== monthly dominant state (share of H1 bars) ===")
    bym = defaultdict(lambda: defaultdict(int))
    for (t, lab, sc, age) in labels:
        if t >= LABEL_START:
            bym[month_key(t)][lab] += 1
    print(f"{'month':8s} {'dominant':22s} {'share':>6s} {'2nd':22s} {'share':>6s} {'bear%':>6s} {'vol%':>5s}")
    for m in sorted(bym):
        d = bym[m]
        tot = sum(d.values())
        top = sorted(d.items(), key=lambda kv: -kv[1])
        bear = sum(v for k, v in d.items() if k in BEAR_FAMILY) / tot
        vol = d.get("VOLATILE_TRANSITION", 0) / tot
        second = top[1] if len(top) > 1 else ("", 0)
        print(f"{m:8s} {top[0][0]:22s} {top[0][1]/tot:6.0%} {second[0]:22s} "
              f"{(second[1]/tot if second[1] else 0):6.0%} {bear:6.0%} {vol:5.0%}")

    # ---- episode detection
    print("\n=== episode detection (first H4 close labeled ACTIVE_CORRECTION or worse) ===")
    print("bear-family = ACTIVE_CORRECTION / BEAR_TRANSITION / BEAR_TREND / BEAR_RALLY "
          "(VOLATILE_TRANSITION reported separately, not counted as detection)")
    h4seq = [(h4.t[t], states_by_h4[t][0], states_by_h4[t][1]) for t in range(len(h4) - 1)
             if states_by_h4[t] is not None]
    for (name, peak, trough, cross) in EPISODES:
        # search window: from peak to trough + 10 days
        det = None
        vol_det = None
        for (tm, lab, sc) in h4seq:
            if tm < peak or tm > trough:
                continue
            if lab in BEAR_FAMILY and det is None:
                det = (tm, lab, sc)
            if lab == "VOLATILE_TRANSITION" and vol_det is None:
                vol_det = (tm, lab, sc)
            if det:
                break
        line = f"{name:12s} peak {peak.date()}  "
        if det:
            lag_peak = (det[0] - peak).days
            line += f"first bear-label {det[0].strftime('%Y-%m-%d %H:%M')} ({det[1]}, B={det[2]}) " \
                    f"= peak+{lag_peak}d"
            if cross:
                lead = (cross - det[0]).days
                line += f"  | D1 cross {cross.date()} -> detected {lead}d EARLIER" if lead > 0 else \
                        f"  | D1 cross {cross.date()} -> detected {-lead}d LATER"
        else:
            line += "NOT DETECTED inside episode window"
            if cross:
                line += f" (cross {cross.date()})"
        if vol_det and (det is None or vol_det[0] < det[0]):
            line += f"  [VOLATILE from {vol_det[0].strftime('%Y-%m-%d %H:%M')}]"
        print(line)

    # ---- false-positive audit 2024-25
    print("\n=== 2024-2025 bear-family runs (false-positive audit) ===")
    audit = [(s, e, n) for (s, e, n) in fam_runs if s.year in (2024, 2025)]
    print(f"{'start':16s} {'end':16s} {'H4bars':>6s} {'days':>5s} {'maxDD60':>8s} {'minClose':>9s} {'closeRet':>8s}")
    for (s, e, n) in audit:
        days = (e - s).days
        dd_vals, closes = [], []
        for dd_i, dt in enumerate(d1.t):
            if s <= dt <= e:
                closes.append(d1.c[dd_i])
                w60 = d1.h[max(0, dd_i - DD_SLOW_BARS + 1):dd_i + 1]
                if len(w60) >= 20:
                    dd_vals.append((max(w60) - d1.c[dd_i]) / max(w60))
        mx = max(dd_vals) if dd_vals else 0.0
        ret = (closes[-1] / closes[0] - 1.0) if len(closes) >= 2 else 0.0
        print(f"{s.strftime('%Y-%m-%d %H:%M'):16s} {e.strftime('%Y-%m-%d %H:%M'):16s} "
              f"{n:6d} {days:5d} {mx:8.1%} {min(closes) if closes else 0:9.2f} {ret:8.1%}")
    bear_bars_2425 = sum(1 for (tm, lab) in seq if tm.year in (2024, 2025) and lab in BEAR_FAMILY)
    tot_2425 = sum(1 for (tm, lab) in seq if tm.year in (2024, 2025))
    print(f"2024-25 bear-family share of H4 bars: {bear_bars_2425}/{tot_2425} = "
          f"{bear_bars_2425/tot_2425:.1%}")

    # ---- join with Stats archive
    print("\n=== state x existing-book results (952-position archive, join on EntryTime) ===")
    lab_by_h1 = {t: (lab, sc) for (t, lab, sc, age) in labels}
    trades = []
    with open(STATS_PATH, "r", encoding="utf-16-le", newline="") as f:
        rd = csv.reader(f)
        hdr = next(rd)
        hdr[0] = hdr[0].lstrip("﻿")
        ix = {k: i for i, k in enumerate(hdr)}
        for r in rd:
            if not r or r[0] != "EXIT":
                continue
            et = r[ix["EntryTime"]]
            try:
                edt = datetime.strptime(et, "%Y.%m.%d %H:%M")
            except ValueError:
                continue
            bar = edt.replace(minute=0)
            lab, sc = lab_by_h1.get(bar, (None, None))
            trades.append(dict(
                entry=edt, dir=r[ix["Direction"]], pat=r[ix["Pattern"]], regime=r[ix["Regime"]],
                pnl=float(r[ix["Total_PnL"]]) if r[ix["Total_PnL"]] else 0.0,
                rr=float(r[ix["Total_R"]]) if r[ix["Total_R"]] else 0.0,
                state=lab, score=sc))
    print(f"joined {sum(1 for t in trades if t['state'])}/{len(trades)} positions")
    agg = defaultdict(lambda: [0, 0.0, 0.0])
    for t in trades:
        if t["state"] is None:
            continue
        k = (t["state"], t["dir"])
        agg[k][0] += 1
        agg[k][1] += t["pnl"]
        agg[k][2] += t["rr"]
    print(f"{'state':22s} {'dir':6s} {'n':>4s} {'net$':>10s} {'sumR':>8s} {'avgR':>7s}")
    for lab in ("BULL_TREND", "BULL_PULLBACK", "RANGE", "VOLATILE_TRANSITION",
                "ACTIVE_CORRECTION", "BEAR_RALLY", "BEAR_TRANSITION", "BEAR_TREND"):
        for dr in ("LONG", "SHORT"):
            n, pnl, rr = agg.get((lab, dr), [0, 0.0, 0.0])
            if n:
                print(f"{lab:22s} {dr:6s} {n:4d} {pnl:10.2f} {rr:8.2f} {rr/n:7.3f}")
    # grouped: bull-family vs bear-family
    print("\ngrouped (bear-family = AC/BT/BEAR/RALLY):")
    g = defaultdict(lambda: [0, 0.0, 0.0])
    for t in trades:
        if t["state"] is None:
            continue
        fam = "BEAR-FAM" if t["state"] in BEAR_FAMILY else (
            "VOLATILE" if t["state"] == "VOLATILE_TRANSITION" else "BULL/RANGE")
        k = (fam, t["dir"])
        g[k][0] += 1; g[k][1] += t["pnl"]; g[k][2] += t["rr"]
    for fam in ("BULL/RANGE", "VOLATILE", "BEAR-FAM"):
        for dr in ("LONG", "SHORT"):
            n, pnl, rr = g.get((fam, dr), [0, 0.0, 0.0])
            if n:
                print(f"{fam:12s} {dr:6s} {n:4d} {pnl:10.2f} {rr:8.2f} {rr/n:7.3f}")

    # ---- worst-40 losses: what does the model call those bars?
    print("\n=== 40 worst losses (by Total_PnL): model state at entry vs EA Regime tag ===")
    worst = sorted((t for t in trades if t["state"] is not None), key=lambda t: t["pnl"])[:40]
    cnt = defaultdict(int)
    reg = defaultdict(int)
    for t in worst:
        cnt[t["state"]] += 1
        reg[t["regime"]] += 1
    for k, v in sorted(cnt.items(), key=lambda kv: -kv[1]):
        print(f"  model {k:22s} {v}")
    for k, v in sorted(reg.items(), key=lambda kv: -kv[1]):
        print(f"  EA-regime {k:12s} {v}")
    print("  detail (entry, dir, pat, $, model state, EA regime):")
    for t in worst:
        print(f"  {t['entry'].strftime('%Y-%m-%d %H:%M')} {t['dir']:5s} {t['pat'][:28]:28s} "
              f"{t['pnl']:9.2f}  {t['state']:20s} {t['regime']}")

    # ---- transition log tail (confidence)
    print(f"\ntransitions logged: {len(sm.transitions)}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "run"
    if mode == "dists":
        run_dists()
    else:
        out = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_STATES_OUT
        run_full(out)
