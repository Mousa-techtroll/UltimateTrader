#!/usr/bin/env python3
"""Trade-level metrics for a research Stats CSV (UTF-16). Rich metrics beyond net:
PF, expectancy, per-trade R-Sharpe, equity drawdown, direct-profile R, winner clipping,
loss distribution, concentration. Also exact common-entry identity (SignalID sets) and
lab action-distribution audit. Usage:
  analyze.py metrics <stats.csv> [profile=engulf|pbc]
  analyze.py identity <stats_a.csv> <stats_b.csv>      # common-entry set diff
  analyze.py actions <lab.csv>                          # ACCEPT/REJECT/... audit + req vs applied
"""
import csv, sys, io, statistics as st

def rows(path):
    with io.open(path, 'r', encoding='utf-16', newline='') as f:
        r = csv.reader(f)
        header = next(r)
        idx = {name: i for i, name in enumerate(header)}
        for rec in r:
            if rec:
                yield idx, rec

def col(idx, rec, name, cast=str, default=None):
    i = idx.get(name)
    if i is None or i >= len(rec) or rec[i] == '':
        return default
    try:
        return cast(rec[i])
    except Exception:
        return default

def exits(path):
    out = []
    for idx, rec in rows(path):
        if rec[0] == 'EXIT':
            out.append((idx, rec))
    return out

def entry_keys(path):
    """Multiset of STABLE entry identities (bartime|engine|dir|EntryPrice). The SignalID's
    trailing global counter is volatile (shifts with any upstream eval change) and is dropped,
    so this is a true common-entry check, not a counter artifact."""
    keys = []
    for idx, rec in rows(path):
        if rec[0] == 'ENTRY':
            sid = col(idx, rec, 'SignalID', str, '')
            stable = '|'.join(sid.split('|')[:3])
            keys.append(stable + '|' + col(idx, rec, 'EntryPrice', str, ''))
    return keys

def fnum(idx, rec, name, d=0.0):
    return col(idx, rec, name, float, d)

def metrics(path, profile=None):
    ex = exits(path)
    n = len(ex)
    tot_pnl = [fnum(i, r, 'Total_PnL') for i, r in ex]
    tot_r   = [fnum(i, r, 'Total_R') for i, r in ex]
    mfe_r   = [fnum(i, r, 'MFE_R') for i, r in ex]
    eng     = [col(i, r, 'EngineName', str, '') for i, r in ex]
    net = sum(tot_pnl)
    wins = [p for p in tot_pnl if p > 0]; losses = [p for p in tot_pnl if p < 0]
    gp, gl = sum(wins), -sum(losses)
    pf = gp / gl if gl > 0 else float('inf')
    win_rate = len(wins) / n if n else 0
    exp_r = st.mean(tot_r) if tot_r else 0
    exp_m = st.mean(tot_pnl) if tot_pnl else 0
    r_sharpe = (st.mean(tot_r) / st.pstdev(tot_r)) if len(tot_r) > 1 and st.pstdev(tot_r) > 0 else 0
    # equity drawdown (chronological as stored) — peak-to-trough of cumulative Total_PnL
    eq = 0.0; peak = 0.0; maxdd = 0.0
    for p in tot_pnl:
        eq += p; peak = max(peak, eq); maxdd = max(maxdd, peak - eq)
    # direct-profile R
    prof_sub = {'engulf': 'Engulf', 'pbc': 'PullbackContinuation'}.get(profile)
    if prof_sub:
        pr = [(tr, pm) for tr, pm, e in zip(tot_r, tot_pnl, eng) if prof_sub in e]
        prof_n = len(pr); prof_sumr = sum(x[0] for x in pr); prof_meanr = (prof_sumr/prof_n) if prof_n else 0
        prof_net = sum(x[1] for x in pr)
    else:
        prof_n = prof_sumr = prof_meanr = prof_net = 0
    # winner clipping: fat-tail trades (MFE_R>=2) capture ratio Total_R / MFE_R
    fat = [(tr, m) for tr, m in zip(tot_r, mfe_r) if m >= 2.0]
    cap = [max(0.0, tr) / m for tr, m in fat if m > 0]
    fat_capture = st.mean(cap) if cap else None
    # loss distribution
    loss_r = sorted([tr for tr in tot_r if tr < 0])
    def pct(a, q):
        if not a: return None
        k = (len(a)-1)*q; f = int(k); c = min(f+1, len(a)-1)
        return a[f] + (a[c]-a[f])*(k-f)
    # concentration: top-10 winners' share of gross profit; top 5% share
    win_sorted = sorted(wins, reverse=True)
    top10 = sum(win_sorted[:10]) / gp if gp > 0 else 0
    k5 = max(1, int(len(win_sorted)*0.05))
    top5pct = sum(win_sorted[:k5]) / gp if gp > 0 else 0
    print(f"file={path}")
    print(f"  trades={n}  net={net:,.2f}  PF={pf:.3f}  win%={win_rate*100:.1f}")
    print(f"  expectancy: {exp_r:+.4f} R/trade  ({exp_m:+.2f} $/trade)   R-Sharpe(per-trade)={r_sharpe:.3f}")
    print(f"  equityDD(max peak-trough of cum PnL) = {maxdd:,.2f}")
    print(f"  losses: n={len(loss_r)} avg={st.mean(loss_r) if loss_r else 0:+.3f}R  p50={pct(loss_r,.5)}  p10(worst-ish)={pct(loss_r,.1)}  worst={loss_r[0] if loss_r else 0:+.2f}R")
    print(f"  winner-clipping (MFE_R>=2): n={len(fat)}  mean capture(Total_R/MFE_R)={fat_capture if fat_capture is None else round(fat_capture,3)}")
    print(f"  concentration: top10 winners = {top10*100:.1f}% of gross profit;  top5% winners = {top5pct*100:.1f}%")
    if prof_sub:
        print(f"  DIRECT-PROFILE[{profile}]: n={prof_n}  sumR={prof_sumr:+.2f}  meanR={prof_meanr:+.4f}  net={prof_net:,.2f}")

def identity(a, b):
    ka, kb = entry_keys(a), entry_keys(b)
    sa, sb = set(ka), set(kb)
    only_a = sa - sb; only_b = sb - sa
    print(f"common-entry identity:  A={len(ka)} entries  B={len(kb)} entries  shared={len(sa & sb)}")
    print(f"  only in A (dropped in B): {len(only_a)}   only in B (added in B): {len(only_b)}")
    print(f"  EXACT COMMON-ENTRY IDENTITY: {'YES' if not only_a and not only_b else 'NO'}")
    for k in list(only_a)[:8]: print(f"    -A {k}")
    for k in list(only_b)[:8]: print(f"    +B {k}")

def actions(path):
    # lab telemetry is tab-delimited FILE_ANSI; ENTRY rows carry Action(11) ReqRisk(13) ApplRisk(14)
    from collections import Counter
    act = Counter(); req_app = []
    ACT = {'0':'ACCEPT','1':'REJECT','2':'RISK_DOWN','3':'RISK_UP','4':'WAIT','5':'RECLASS'}
    with io.open(path,'r',encoding='latin-1') as f:
        for line in f:
            p = line.rstrip('\n').split('\t')
            if p and p[0]=='ENTRY' and len(p)>14:
                a = p[10]; act[ACT.get(a,a)] += 1
                try: req_app.append((float(p[12]), float(p[13])))
                except: pass
    total = sum(act.values())
    print(f"lab ENTRY verdicts (n={total}):")
    for k,v in act.most_common(): print(f"    {k:10s} {v:5d}  ({100*v/total:.1f}%)" if total else k)
    diff = [ (rq,ap) for rq,ap in req_app if abs(rq-ap)>1e-9 ]
    print(f"  requested!=applied risk mult: {len(diff)} of {len(req_app)}")
    for rq,ap in diff[:6]: print(f"    req={rq:.2f} applied={ap:.2f}")

if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'metrics':
        metrics(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif cmd == 'identity':
        identity(sys.argv[2], sys.argv[3])
    elif cmd == 'actions':
        actions(sys.argv[2])
