#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
exit_attribution.py  --  Wave-6 counterfactual attribution for the exit-momentum platform.

OFFLINE analyzer of the three shadow-telemetry sinks defined (FROZEN) in
    claude/audit/exit-telemetry-schema.md
It READS the CSVs and PRINTS / WRITES a markdown report. It touches NO EA code, no state,
and makes no trading decision -- it only attributes the counterfactual "what if we had run
the candidate loosening policy" deltas that the CounterfactualExit sink already computed.

The three sinks (comma-separated, '.' decimal, GMT timestamps 'yyyy.MM.dd HH:mm:ss',
unavailable feature -> EMPTY cell, never a fabricated number):

  Sink 3  CfExit  (UltTrader_CfExit_*.csv)  -- one row per (position x candidate policy) close
      CloseTime,Ticket,Family,Intent,BundleId,Direction,EntryTime,EntryPrice,InitialRiskR,
      Actual_ExitTime,Actual_ExitPrice,Actual_ExitR,Actual_Reason,
      Cf_Policy,Cf_ExitTime,Cf_ExitPrice,Cf_ExitR,Cf_Reason,
      Cf_DeltaR,Cf_Captured,Cf_Givenback
  Sink 2  ExitProp (UltTrader_ExitProp_*.csv) -- one row per open position per evaluated bar
      Time,Ticket,Family,Intent,BundleId,Direction,BarsSinceEntry,CurrentR,MfeR,MaeR, ...
  Sink 1  MomSnap (UltTrader_MomSnap_*.csv)  -- one row per closed H1 bar (raw feature tape)
      BarTime,Ready,Trend,TrendAv, ... IS_Crash,IS_CrashAv

What it produces (Wave-6 adoption decision, per-FAMILY and per-BUNDLE):
  1. Counterfactual net-R (sum Cf_DeltaR) with a MONTH-BLOCK BOOTSTRAP CI (mean + 5/95;
     flags when the CI includes 0).
  2. Exit-capture BOTH ways: total Cf_Captured (MFE gained) vs total Cf_Givenback (MFE
     surrendered), netted -- a loosening policy must be net-positive [contract T3].
  3. Winner-clipping: winner cohort (MFE >= ~1.5R) vs reverser cohort (reached ~1R then
     lost) -- reports the policy's dR on each; the danger is a NEGATIVE d on winners.
  4. Concentration: %-of-benefit from the top-2 trades / single best calendar-month /
     single year(regime) -- flags any > ~50%.
  5. Cross-feed: with both primary + gh CfExit files, joins on Ticket/EntryTime and reports
     Cf_DeltaR SIGN-AGREEMENT % (target >= ~95%) plus an ex-2025 slice [contract T4].
  6. A RANKED list of loosening candidates by risk-adjusted counterfactual benefit -- the
     Wave-6.1 "is trend-trail actually top-ranked?" check [contract T8].

Robust to partial / early telemetry: missing files, missing columns, and empty cells all
degrade to "n/a" rather than crashing or fabricating. Stdlib only; pandas/numpy are used
only for a faster bootstrap when present, otherwise a pure-python path runs.

USAGE
  # single feed, print to stdout
  python3 exit_attribution.py --cfexit UltTrader_CfExit_XAUUSD_20260722.csv

  # enrich winner-clipping with true MFE from the proposal tape, add feature readiness
  python3 exit_attribution.py \
      --cfexit  UltTrader_CfExit_XAUUSD_20260722.csv \
      --exitprop UltTrader_ExitProp_XAUUSD_20260722.csv \
      --momsnap UltTrader_MomSnap_XAUUSD_20260722.csv \
      --out claude/audit/exit-attribution-report.md

  # cross-feed sign-agreement (primary vs GoldHistory), explicit feed labels
  python3 exit_attribution.py \
      --cfexit primary_CfExit.csv gh_CfExit.csv --feed primary gh \
      --out report.md
"""

import argparse
import csv
import io
import math
import os
import random
import sys
import zlib
from collections import defaultdict, OrderedDict

# ------------------------------------------------------------------ optional numpy
try:
    import numpy as _np  # noqa: F401
    HAVE_NUMPY = True
except Exception:
    HAVE_NUMPY = False

# ------------------------------------------------------------------ tunables (spec ~values)
WINNER_MFE_R = 1.5     # winner cohort: MFE >= ~1.5R
REVERSER_MFE_R = 1.0   # reverser cohort: reached ~1R ...
SIGN_TARGET = 0.95     # cross-feed sign-agreement target
CONC_FLAG = 0.50       # concentration flag threshold (>50%)
EPS = 1e-9             # sign epsilon
BOOT_ITERS = 4000      # month-block bootstrap resamples
DEFAULT_SEED = 12345

# =================================================================== CSV reading
def _decode_bytes(raw):
    """MT5 FILE_COMMON sinks may be UTF-16 (default) or UTF-8; detect via BOM/NULs."""
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    if raw[:3] == b"\xef\xbb\xbf":
        return raw.decode("utf-8-sig")
    # no BOM: sniff NUL bytes -> UTF-16 without BOM, else UTF-8, else latin-1
    if b"\x00" in raw[:400]:
        try:
            return raw.decode("utf-16")
        except Exception:
            return raw.decode("utf-16-le", errors="replace")
    try:
        return raw.decode("utf-8")
    except Exception:
        return raw.decode("latin-1")


def _norm_header(h):
    return h.strip().lstrip("﻿").strip()


class Table(object):
    """A tolerant CSV view: header->index map + raw rows; missing column -> ''. """
    def __init__(self, name, header, rows):
        self.name = name
        self.header = header
        self.rows = rows
        self._idx = {}
        for i, h in enumerate(header):
            # keep first occurrence; also index a lowercase alias
            self._idx.setdefault(h, i)
            self._idx.setdefault(h.lower(), i)

    def has(self, col):
        return col in self._idx or col.lower() in self._idx

    def _i(self, col):
        if col in self._idx:
            return self._idx[col]
        return self._idx.get(col.lower())

    def get(self, row, col, default=""):
        i = self._i(col)
        if i is None or i >= len(row):
            return default
        return row[i]

    def __len__(self):
        return len(self.rows)


def read_table(path, name):
    """Read a CSV into a Table; returns (Table or None, warning-or-None)."""
    if not path:
        return None, None
    if not os.path.exists(path):
        return None, "MISSING FILE: %s" % path
    try:
        with open(path, "rb") as fh:
            raw = fh.read()
    except Exception as exc:  # pragma: no cover - io error
        return None, "READ ERROR %s: %s" % (path, exc)
    if not raw.strip():
        return Table(name, [], []), "EMPTY FILE: %s" % path
    text = _decode_bytes(raw)
    reader = csv.reader(io.StringIO(text))
    try:
        header = next(reader)
    except StopIteration:
        return Table(name, [], []), "NO HEADER: %s" % path
    header = [_norm_header(h) for h in header]
    rows = [r for r in reader if any(c.strip() for c in r)]
    return Table(name, header, rows), None


# =================================================================== field coercion
def fnum(s):
    """Empty / unparseable cell -> None (NEVER fabricated). Handles '.' decimals."""
    if s is None:
        return None
    s = s.strip()
    if s == "" or s.lower() in ("nan", "na", "null", "none"):
        return None
    try:
        return float(s)
    except ValueError:
        return None


def month_key(ts):
    """'yyyy.MM.dd HH:mm:ss' -> 'yyyy-MM'  (robust to blanks / odd separators)."""
    if not ts:
        return None
    t = ts.strip().replace("/", ".").replace("-", ".")
    parts = t.split(".")
    if len(parts) >= 2 and len(parts[0]) == 4 and parts[0].isdigit():
        mm = parts[1].split(" ")[0]
        return "%s-%s" % (parts[0], mm.zfill(2))
    return None


def year_key(ts):
    m = month_key(ts)
    return m.split("-")[0] if m else None


# =================================================================== CfExit model
class CfRow(object):
    __slots__ = ("close_time", "ticket", "family", "intent", "bundle", "direction",
                 "entry_time", "init_risk_r", "actual_r", "actual_reason",
                 "cf_policy", "cf_exit_r", "cf_reason", "delta_r", "captured",
                 "givenback", "month", "year", "feed")

    def key(self):  # cross-feed join key
        return (self.ticket, self.entry_time)


def parse_cfexit(table, feed):
    """Table -> list[CfRow]. Derives Cf_DeltaR from exit R's if that column is absent."""
    out = []
    if table is None:
        return out
    for r in table.rows:
        row = CfRow()
        row.feed = feed
        row.close_time = table.get(r, "CloseTime").strip()
        row.ticket = table.get(r, "Ticket").strip()
        row.family = table.get(r, "Family").strip() or "(unlabeled)"
        row.intent = table.get(r, "Intent").strip()
        row.bundle = table.get(r, "BundleId").strip() or "(unlabeled)"
        row.direction = table.get(r, "Direction").strip()
        row.entry_time = table.get(r, "EntryTime").strip()
        row.init_risk_r = fnum(table.get(r, "InitialRiskR"))
        row.actual_r = fnum(table.get(r, "Actual_ExitR"))
        row.actual_reason = table.get(r, "Actual_Reason").strip()
        row.cf_policy = table.get(r, "Cf_Policy").strip() or "(unlabeled)"
        row.cf_exit_r = fnum(table.get(r, "Cf_ExitR"))
        row.cf_reason = table.get(r, "Cf_Reason").strip()
        row.delta_r = fnum(table.get(r, "Cf_DeltaR"))
        if row.delta_r is None and row.cf_exit_r is not None and row.actual_r is not None:
            row.delta_r = row.cf_exit_r - row.actual_r      # documented fallback
        row.captured = fnum(table.get(r, "Cf_Captured"))
        row.givenback = fnum(table.get(r, "Cf_Givenback"))
        row.month = month_key(row.close_time) or month_key(row.entry_time)
        row.year = year_key(row.close_time) or year_key(row.entry_time)
        out.append(row)
    return out


def ticket_mfe_from_exitprop(table):
    """ExitProp -> {ticket: max MfeR}. Authoritative MFE for winner-clipping cohorts."""
    mfe = {}
    if table is None or not table.has("Ticket") or not table.has("MfeR"):
        return mfe
    for r in table.rows:
        tk = table.get(r, "Ticket").strip()
        v = fnum(table.get(r, "MfeR"))
        if tk == "" or v is None:
            continue
        if tk not in mfe or v > mfe[tk]:
            mfe[tk] = v
    return mfe


# =================================================================== month-block bootstrap
def month_block_bootstrap(rows, value_of, iters=BOOT_ITERS, seed=DEFAULT_SEED, label=""):
    """Calendar-month block bootstrap of a SUM statistic.

    Buckets each row's value by its calendar month, then resamples K months (K = #months
    observed) WITH REPLACEMENT and sums -- the spread reflects month-to-month variance.
    Returns dict(observed, mean, lo(5%), hi(95%), ci_includes_zero, n_months, n) or None.
    Deterministic: seeded from `seed` xor a stable hash of `label`.
    """
    by_month = defaultdict(float)
    n = 0
    for r in rows:
        v = value_of(r)
        if v is None:
            continue
        m = getattr(r, "month", None) or "?"
        by_month[m] += v
        n += 1
    if not by_month:
        return None
    months = list(by_month.keys())
    sums = [by_month[m] for m in months]
    observed = sum(sums)
    k = len(months)
    stable = zlib.crc32((label or "").encode("utf-8"))
    if k == 1:
        # single month: no month-to-month resampling possible; CI degenerate
        return dict(observed=observed, mean=observed, lo=observed, hi=observed,
                    ci_includes_zero=(abs(observed) < EPS), n_months=1, n=n,
                    degenerate=True)
    if HAVE_NUMPY:
        rng = _np.random.RandomState((seed ^ stable) & 0x7FFFFFFF)
        arr = _np.asarray(sums, dtype=float)
        idx = rng.randint(0, k, size=(iters, k))
        reps = arr[idx].sum(axis=1)
        reps.sort()
        mean = float(reps.mean())
        lo = float(reps[int(0.05 * iters)])
        hi = float(reps[int(0.95 * iters)])
    else:
        rnd = random.Random(seed ^ stable)
        reps = []
        for _ in range(iters):
            s = 0.0
            for _ in range(k):
                s += sums[rnd.randrange(k)]
            reps.append(s)
        reps.sort()
        mean = sum(reps) / len(reps)
        lo = reps[int(0.05 * len(reps))]
        hi = reps[int(0.95 * len(reps))]
    return dict(observed=observed, mean=mean, lo=lo, hi=hi,
                ci_includes_zero=(lo <= 0.0 <= hi), n_months=k, n=n, degenerate=False)


# =================================================================== formatting helpers
def fr(x, dp=3):
    return "n/a" if x is None else ("%+.*f" % (dp, x))


def fu(x, dp=3):  # unsigned
    return "n/a" if x is None else ("%.*f" % (dp, x))


def pct(x, dp=1):
    return "n/a" if x is None else ("%.*f%%" % (dp, 100.0 * x))


def yn(b):
    return "YES" if b else "no"


class Report(object):
    def __init__(self):
        self.buf = []

    def __call__(self, *lines):
        for ln in lines:
            self.buf.append(ln)

    def text(self):
        return "\n".join(self.buf) + "\n"


# =================================================================== metric sections
def group_by(rows, keyfn):
    g = OrderedDict()
    for r in rows:
        k = keyfn(r)
        g.setdefault(k, []).append(r)
    return g


def net_r_table(w, rows, keyfn, title, seed):
    w("## %s" % title, "")
    if not rows:
        w("_no CfExit rows._", "")
        return
    have_delta = any(r.delta_r is not None for r in rows)
    if not have_delta:
        w("_Cf_DeltaR unavailable (and not derivable) in this telemetry -- skipped._", "")
        return
    w("| group | n | tickets | Sum dR (obs) | boot mean | 5% | 95% | CI incl 0? |",
      "|---|--:|--:|--:|--:|--:|--:|:--:|")
    groups = group_by(rows, keyfn)
    # order by observed net dR descending
    ordered = sorted(groups.items(),
                     key=lambda kv: sum((r.delta_r or 0.0) for r in kv[1]), reverse=True)
    for k, rs in ordered:
        bs = month_block_bootstrap(rs, lambda r: r.delta_r, seed=seed, label="netr:%s" % k)
        ntk = len({r.ticket for r in rs if r.ticket})
        if bs is None:
            w("| %s | %d | %d | n/a | n/a | n/a | n/a | n/a |" % (k, len(rs), ntk))
            continue
        flag = "**INCL 0**" if bs["ci_includes_zero"] else "clear"
        deg = " (1mo)" if bs.get("degenerate") else ""
        w("| %s | %d | %d | %s | %s | %s | %s | %s%s |" %
          (k, len(rs), ntk, fr(bs["observed"]), fr(bs["mean"]),
           fr(bs["lo"]), fr(bs["hi"]), flag, deg))
    w("")


def capture_both_ways(w, rows, keyfn, title):
    w("## %s" % title, "")
    cap_any = any(r.captured is not None for r in rows)
    give_any = any(r.givenback is not None for r in rows)
    if not (cap_any or give_any):
        w("_Cf_Captured / Cf_Givenback columns empty in this telemetry -- capture "
          "analysis skipped (never fabricated)._", "")
        return
    w("A loosening policy must net-POSITIVE (captures more MFE than it surrenders).", "")
    w("| group | n | Sum Captured | Sum Givenback | NET (cap-give) | net-positive? |",
      "|---|--:|--:|--:|--:|:--:|")
    groups = group_by(rows, keyfn)
    tot_c = tot_g = 0.0
    for k, rs in sorted(groups.items()):
        c = sum(r.captured for r in rs if r.captured is not None)
        g = sum(r.givenback for r in rs if r.givenback is not None)
        net = c - g
        tot_c += c
        tot_g += g
        w("| %s | %d | %s | %s | %s | %s |" %
          (k, len(rs), fu(c), fu(g), fr(net), yn(net > EPS)))
    net = tot_c - tot_g
    w("| **ALL** | %d | %s | %s | %s | %s |" %
      (len(rows), fu(tot_c), fu(tot_g), fr(net), yn(net > EPS)))
    w("")


def winner_clipping(w, rows, mfe_by_ticket, per_policy=True):
    w("## Winner-clipping cohorts", "")
    if mfe_by_ticket:
        w("_MFE source: ExitProp MfeR (max per ticket) -- authoritative._", "")
        def mfe_of(r):
            return mfe_by_ticket.get(r.ticket)
    else:
        w("_MFE source: PROXY = max(Actual_ExitR, Cf_ExitR) -- ExitProp not supplied, "
          "so cohort membership is a floor (true MFE >= proxy)._", "")
        def mfe_of(r):
            cands = [x for x in (r.actual_r, r.cf_exit_r) if x is not None]
            return max(cands) if cands else None

    def cohort(r):
        m = mfe_of(r)
        if m is None:
            return "unknown"
        if m >= WINNER_MFE_R:
            return "winner (MFE>=%.1fR)" % WINNER_MFE_R
        if m >= REVERSER_MFE_R and (r.actual_r is not None and r.actual_r < 0):
            return "reverser (>=%.1fR then lost)" % REVERSER_MFE_R
        return "other"

    order = ["winner (MFE>=%.1fR)" % WINNER_MFE_R,
             "reverser (>=%.1fR then lost)" % REVERSER_MFE_R, "other", "unknown"]

    def render(subset, header):
        w(header)
        w("| cohort | n | mean dR | Sum dR | flag |", "|---|--:|--:|--:|:--:|")
        buck = group_by(subset, cohort)
        for c in order:
            rs = buck.get(c)
            if not rs:
                continue
            ds = [r.delta_r for r in rs if r.delta_r is not None]
            if not ds:
                w("| %s | %d | n/a | n/a | |" % (c, len(rs)))
                continue
            mean = sum(ds) / len(ds)
            flag = ""
            if c.startswith("winner") and mean < -EPS:
                flag = "**CLIPS WINNERS**"
            w("| %s | %d | %s | %s | %s |" % (c, len(rs), fr(mean), fr(sum(ds)), flag))
        w("")

    render(rows, "**All candidate policies pooled**")
    if per_policy:
        pol = group_by(rows, lambda r: r.cf_policy)
        if len(pol) > 1:
            for p, rs in sorted(pol.items()):
                render(rs, "**Policy: %s**" % p)


def concentration(w, rows, title, flag_threshold=CONC_FLAG):
    w("## %s" % title, "")
    deltas = [(r, r.delta_r) for r in rows if r.delta_r is not None]
    if not deltas:
        w("_no Cf_DeltaR values -- concentration skipped._", "")
        return
    net_total = sum(d for _, d in deltas)
    pos_total = sum(d for _, d in deltas if d > 0)
    basis = net_total if net_total > EPS else pos_total
    basis_lbl = "net total dR" if net_total > EPS else "gross-positive dR (net<=0)"
    w("Benefit basis = %s = %s." % (basis_lbl, fr(basis)), "")
    if basis <= EPS:
        w("_No positive benefit to concentrate -- flags n/a._", "")
        return
    # top-2 TRADES (aggregate dR by ticket so a trade counts once)
    by_ticket = defaultdict(float)
    for r, d in deltas:
        by_ticket[r.ticket or ("row%d" % id(r))] += d
    top_trades = sorted(by_ticket.items(), key=lambda kv: kv[1], reverse=True)[:2]
    top2 = sum(v for _, v in top_trades)
    # best month / best year
    by_month = defaultdict(float)
    by_year = defaultdict(float)
    for r, d in deltas:
        by_month[r.month or "?"] += d
        by_year[r.year or "?"] += d
    best_m = max(by_month.items(), key=lambda kv: kv[1])
    best_y = max(by_year.items(), key=lambda kv: kv[1])

    def line(lbl, val, detail):
        share = val / basis
        flag = "**CONCENTRATED**" if share > flag_threshold else "ok"
        w("| %s | %s | %s | %s | %s |" % (lbl, fr(val), pct(share), flag, detail))

    w("| source | dR | share of benefit | flag | detail |",
      "|---|--:|--:|:--:|---|")
    line("top-2 trades", top2,
         ", ".join("%s=%s" % (t, fr(v)) for t, v in top_trades))
    line("best month", best_m[1], best_m[0])
    line("best year (regime)", best_y[1], best_y[0])
    w("")


def cross_feed(w, rows_by_feed, seed):
    w("## Cross-feed sign-agreement (Cf_DeltaR)", "")
    feeds = [f for f in rows_by_feed if rows_by_feed[f]]
    if not ("primary" in feeds and "gh" in feeds):
        w("_N/A -- needs BOTH a primary and a gh CfExit file (have: %s)._"
          % (", ".join(feeds) or "none"), "")
        return

    def index(rs):
        # (ticket, entry_time) -> {policy: deltaR}  ; skip rows w/o delta
        idx = {}
        for r in rs:
            if r.delta_r is None:
                continue
            idx.setdefault((r.ticket, r.entry_time), {})[r.cf_policy] = (r.delta_r, r.year)
        return idx

    pi = index(rows_by_feed["primary"])
    gi = index(rows_by_feed["gh"])
    common = set(pi) & set(gi)
    if not common:
        w("_0 common (Ticket, EntryTime) keys across feeds -- cannot compute agreement._", "")
        return

    def sign(x):
        if x > EPS:
            return 1
        if x < -EPS:
            return -1
        return 0

    def agreement(exclude_2025=False):
        agree = total = 0
        for key in common:
            pol_common = set(pi[key]) & set(gi[key])
            for p in pol_common:
                pv, py = pi[key][p]
                gv, gy = gi[key][p]
                if exclude_2025 and (py == "2025" or gy == "2025"):
                    continue
                total += 1
                if sign(pv) == sign(gv):
                    agree += 1
        return agree, total

    a, t = agreement(False)
    rate = (a / t) if t else None
    w("Common (Ticket, EntryTime) keys: **%d**   |   matched policy comparisons: **%d**"
      % (len(common), t), "")
    w("| slice | compared | sign-agree | rate | target %d%% |"
      % int(SIGN_TARGET * 100), "|---|--:|--:|--:|:--:|")
    w("| all | %d | %d | %s | %s |"
      % (t, a, pct(rate), yn(rate is not None and rate >= SIGN_TARGET)))
    a2, t2 = agreement(True)
    rate2 = (a2 / t2) if t2 else None
    w("| ex-2025 | %d | %d | %s | %s |"
      % (t2, a2, pct(rate2), yn(rate2 is not None and rate2 >= SIGN_TARGET)))
    w("")
    # does the edge survive ex-2025 (net dR sign + CI)?
    ex25 = [r for r in rows_by_feed["primary"] if r.year != "2025"]
    bs_all = month_block_bootstrap(rows_by_feed["primary"], lambda r: r.delta_r,
                                   seed=seed, label="xfeed-all")
    bs_ex = month_block_bootstrap(ex25, lambda r: r.delta_r, seed=seed, label="xfeed-ex25")
    if bs_all and bs_ex:
        survives = (bs_all["observed"] > 0) and (bs_ex["observed"] > 0) \
            and (not bs_ex["ci_includes_zero"])
        w("Primary net dR: all=%s (CI %s..%s), ex-2025=%s (CI %s..%s) -> edge survives "
          "ex-2025: **%s**" % (fr(bs_all["observed"]), fr(bs_all["lo"]), fr(bs_all["hi"]),
                               fr(bs_ex["observed"]), fr(bs_ex["lo"]), fr(bs_ex["hi"]),
                               yn(survives)), "")
    w("")


def ranked_candidates(w, rows, keyfn, key_label, mfe_by_ticket, seed):
    w("## Ranked loosening candidates -- %s" % key_label, "")
    w("Rank key = **risk-adjusted benefit** = month-block-bootstrap 5% lower bound of "
      "Sum dR (conservative; ties broken by mean). This drives the Wave-6.1 "
      "\"is trend-trail top-ranked?\" check.", "")
    if not any(r.delta_r is not None for r in rows):
        w("_no Cf_DeltaR -- ranking skipped._", "")
        return None
    groups = group_by(rows, keyfn)

    def winner_delta(rs):
        if mfe_by_ticket:
            def mfe(r):
                return mfe_by_ticket.get(r.ticket)
        else:
            def mfe(r):
                cs = [x for x in (r.actual_r, r.cf_exit_r) if x is not None]
                return max(cs) if cs else None
        ds = [r.delta_r for r in rs
              if r.delta_r is not None and mfe(r) is not None and mfe(r) >= WINNER_MFE_R]
        return (sum(ds) / len(ds)) if ds else None

    scored = []
    for k, rs in groups.items():
        bs = month_block_bootstrap(rs, lambda r: r.delta_r, seed=seed, label="rank:%s" % k)
        if bs is None:
            continue
        cap = sum(r.captured for r in rs if r.captured is not None) if \
            any(r.captured is not None for r in rs) else None
        give = sum(r.givenback for r in rs if r.givenback is not None) if \
            any(r.givenback is not None for r in rs) else None
        netcap = (cap - give) if (cap is not None and give is not None) else None
        scored.append(dict(key=k, n=len(rs), obs=bs["observed"], mean=bs["mean"],
                           lo=bs["lo"], hi=bs["hi"], incl0=bs["ci_includes_zero"],
                           netcap=netcap, wdelta=winner_delta(rs)))
    scored.sort(key=lambda d: (d["lo"], d["mean"]), reverse=True)
    w("| rank | %s | n | Sum dR | boot mean | 5%% | net capture | winner dR | verdict |"
      % key_label, "|--:|---|--:|--:|--:|--:|--:|--:|---|")
    for i, d in enumerate(scored, 1):
        verdict = []
        if d["incl0"]:
            verdict.append("CI incl 0")
        if d["netcap"] is not None and d["netcap"] <= 0:
            verdict.append("capture-negative")
        if d["wdelta"] is not None and d["wdelta"] < 0:
            verdict.append("clips winners")
        v = "; ".join(verdict) if verdict else "candidate OK"
        w("| %d | %s | %d | %s | %s | %s | %s | %s | %s |" %
          (i, d["key"], d["n"], fr(d["obs"]), fr(d["mean"]), fr(d["lo"]),
           fr(d["netcap"]) if d["netcap"] is not None else "n/a",
           fr(d["wdelta"]) if d["wdelta"] is not None else "n/a", v))
    w("")
    # trend-trail top-ranked check
    def is_trend_trail(k):
        s = str(k).lower()
        return ("trend" in s) or ("trail" in s)
    tt = [(i, d) for i, d in enumerate(scored, 1) if is_trend_trail(d["key"])]
    if scored:
        top = scored[0]["key"]
        if tt:
            best_rank = tt[0][0]
            w("**Wave-6.1 check:** best trend/trail candidate = `%s` at rank **#%d** "
              "(of %d). Top-ranked overall = `%s`. Trend-trail IS top-ranked: **%s**."
              % (tt[0][1]["key"], best_rank, len(scored), top,
                 yn(best_rank == 1)), "")
        else:
            w("**Wave-6.1 check:** no trend/trail-named candidate present in this "
              "telemetry; top-ranked = `%s`." % top, "")
    w("")
    return scored


def momsnap_readiness(w, table):
    if table is None:
        return
    w("## Feature-tape readiness (MomSnap)", "")
    if len(table) == 0:
        w("_MomSnap empty._", "")
        return
    n = len(table)
    ready = 0
    if table.has("Ready"):
        for r in table.rows:
            v = table.get(r, "Ready").strip()
            if v in ("1", "true", "True"):
                ready += 1
    w("Closed H1 bars: **%d**   |   Ready==1: **%d** (%s)"
      % (n, ready, pct(ready / n if n else None)), "")
    # availability rates for *Av flag columns
    av_cols = [h for h in table.header if h.endswith("Av")]
    if av_cols:
        w("", "| feature | availability (Av==1) |", "|---|--:|")
        for c in av_cols:
            on = 0
            for r in table.rows:
                if table.get(r, c).strip() == "1":
                    on += 1
            w("| %s | %s |" % (c[:-2], pct(on / n if n else None)))
    w("")


# =================================================================== main
def infer_feed(path):
    base = os.path.basename(path).lower()
    toks = set(t for t in base.replace(".", "_").replace("-", "_").split("_") if t)
    if "gh" in toks or "goldhistory" in toks or "goldhist" in toks:
        return "gh"
    return "primary"


def build_parser():
    p = argparse.ArgumentParser(
        prog="exit_attribution.py",
        description="Offline counterfactual attribution over exit-momentum shadow telemetry.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Example:\n  python3 exit_attribution.py --cfexit primary_CfExit.csv "
               "gh_CfExit.csv --feed primary gh --exitprop ExitProp.csv --out report.md")
    p.add_argument("--cfexit", nargs="+", metavar="CSV",
                   help="One or more CounterfactualExit CSVs (2 => cross-feed section).")
    p.add_argument("--momsnap", metavar="CSV", help="MomentumSnapshot CSV (readiness only).")
    p.add_argument("--exitprop", metavar="CSV",
                   help="ExitPolicyProposals CSV (supplies authoritative MFE for cohorts).")
    p.add_argument("--feed", nargs="*", choices=["primary", "gh"], default=None,
                   help="Feed label(s) parallel to --cfexit; inferred from filename if omitted.")
    p.add_argument("--out", metavar="PATH", help="Write markdown report here (else stdout).")
    p.add_argument("--seed", type=int, default=DEFAULT_SEED, help="Bootstrap RNG seed.")
    p.add_argument("--iters", type=int, default=BOOT_ITERS, help="Bootstrap resamples.")
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    global BOOT_ITERS
    BOOT_ITERS = args.iters
    warnings = []

    if not args.cfexit:
        build_parser().print_help()
        print("\nERROR: --cfexit is required (at least one CounterfactualExit CSV).",
              file=sys.stderr)
        return 2

    # ---- load CfExit file(s), assign feed labels
    feed_labels = list(args.feed) if args.feed else []
    all_rows = []
    rows_by_feed = defaultdict(list)
    loaded = []
    for i, path in enumerate(args.cfexit):
        if i < len(feed_labels):
            feed = feed_labels[i]
        else:
            feed = infer_feed(path)
        tbl, warn = read_table(path, "CfExit")
        if warn:
            warnings.append(warn)
        rows = parse_cfexit(tbl, feed)
        all_rows.extend(rows)
        rows_by_feed[feed].extend(rows)
        loaded.append((path, feed, len(rows), tbl.header if tbl else []))

    exitprop_tbl, w2 = read_table(args.exitprop, "ExitProp")
    if w2:
        warnings.append(w2)
    momsnap_tbl, w1 = read_table(args.momsnap, "MomSnap")
    if w1:
        warnings.append(w1)
    mfe_by_ticket = ticket_mfe_from_exitprop(exitprop_tbl)

    # =============================================================== report
    w = Report()
    w("# Exit-Momentum Counterfactual Attribution Report", "")
    w("_Offline analysis of shadow telemetry (schema: exit-telemetry-schema.md). "
      "No EA code touched; no fabricated numbers -- empty telemetry cells stay 'n/a'._", "")
    w("")
    w("## 0. Data overview", "")
    w("| CfExit file | feed | rows | Cf_DeltaR present | Capture cols present |",
      "|---|---|--:|:--:|:--:|")
    for path, feed, nrows, header in loaded:
        hset = set(header)
        w("| %s | %s | %d | %s | %s |" %
          (os.path.basename(path), feed, nrows,
           yn("Cf_DeltaR" in hset or ("Cf_ExitR" in hset and "Actual_ExitR" in hset)),
           yn("Cf_Captured" in hset and "Cf_Givenback" in hset)))
    ntk = len({r.ticket for r in all_rows if r.ticket})
    npol = len({r.cf_policy for r in all_rows})
    months = sorted({r.month for r in all_rows if r.month})
    years = sorted({r.year for r in all_rows if r.year})
    w("", "Total CfExit rows: **%d**  |  distinct tickets: **%d**  |  candidate policies: "
      "**%d**  |  families: **%d**  |  bundles: **%d**"
      % (len(all_rows), ntk, npol,
         len({r.family for r in all_rows}), len({r.bundle for r in all_rows})))
    w("Calendar span: **%s .. %s** across **%d** months, years: %s"
      % (months[0] if months else "n/a", months[-1] if months else "n/a",
         len(months), ", ".join(years) if years else "n/a"))
    w("MFE source for cohorts: **%s**  |  numpy bootstrap: **%s**  |  seed=%d, iters=%d"
      % ("ExitProp MfeR" if mfe_by_ticket else "proxy max(Actual,Cf) exit-R",
         yn(HAVE_NUMPY), args.seed, args.iters), "")
    if warnings:
        w("", "**Warnings:**")
        for wn in warnings:
            w("- %s" % wn)
    w("")

    if not all_rows:
        w("**No CfExit rows loaded -- nothing to attribute.** "
          "(Telemetry likely not yet generated; re-run after a shadow campaign.)", "")
        _emit(w.text(), args.out)
        return 0

    # 1. net-R per family / per bundle (with month-block bootstrap CI)
    net_r_table(w, all_rows, lambda r: r.family,
                "1. Counterfactual net-R by FAMILY (month-block bootstrap CI)", args.seed)
    net_r_table(w, all_rows, lambda r: r.bundle,
                "1b. Counterfactual net-R by BUNDLE", args.seed)

    # 2. capture both ways
    capture_both_ways(w, all_rows, lambda r: r.family,
                      "2. Exit-capture both ways by FAMILY (T3)")

    # 3. winner-clipping
    winner_clipping(w, all_rows, mfe_by_ticket)

    # 4. concentration
    concentration(w, all_rows, "4. Concentration of benefit (all candidates pooled)")

    # 5. cross-feed
    cross_feed(w, rows_by_feed, args.seed)

    # 6. ranked candidates (by policy, then by bundle)
    ranked_candidates(w, all_rows, lambda r: r.cf_policy, "candidate policy (Cf_Policy)",
                      mfe_by_ticket, args.seed)
    ranked_candidates(w, all_rows, lambda r: r.bundle, "bundle (BundleId)",
                      mfe_by_ticket, args.seed)

    # aux: momsnap readiness
    momsnap_readiness(w, momsnap_tbl)

    w("---", "",
      "_Methodology: month-block bootstrap resamples calendar months with replacement "
      "(spread = month-to-month variance of the SUM). Winner cohort MFE>=%.1fR; reverser "
      "MFE>=%.1fR AND actual loss. Concentration flags >%d%% of benefit from top-2 trades / "
      "best month / best year. Cross-feed target sign-agreement >=%d%%. A loosening "
      "candidate should show: CI clear of 0, net-positive capture, non-negative winner dR, "
      "and low concentration._"
      % (WINNER_MFE_R, REVERSER_MFE_R, int(CONC_FLAG * 100), int(SIGN_TARGET * 100)))

    _emit(w.text(), args.out)
    return 0


def _emit(text, out):
    if out:
        try:
            with open(out, "w", encoding="utf-8") as fh:
                fh.write(text)
            print("wrote report -> %s (%d bytes)" % (out, len(text)), file=sys.stderr)
        except Exception as exc:  # pragma: no cover
            print("could not write %s: %s\n" % (out, exc), file=sys.stderr)
            sys.stdout.write(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    sys.exit(main())
