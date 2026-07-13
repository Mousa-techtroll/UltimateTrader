#!/usr/bin/env python3
# Gold v2 · Candidate D · PHASE 1 — abnormal-move FADE-vs-CONTINUATION event study (analysis only).
# Owner mandate: compare FADE vs CONTINUE on abnormal non-news moves BEFORE designing any entry.
# Frozen defs in workflowAnalysis/abnormal-move-exhaustion-definition.md. Strict no-lookahead, honest ref.
import statistics, datetime
from collections import defaultdict
GHM15="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_15m_data.csv"
VANH1="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
NEWS="/mnt/c/Trading/UltimateTrader/GoldHistory/NewsCalendar_USD.csv"

def load(path, has_spread):
    bars=[]  # (dt_str, y,mo,d,H,Mi, o,h,l,c, spread_or_None)
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; y=int(ts[:4]); mo=int(ts[5:7]); d=int(ts[8:10]); H=int(ts[11:13]); Mi=int(ts[14:16])
                o,h,l,c=float(p[1]),float(p[2]),float(p[3]),float(p[4])
                sp=float(p[6])*0.01 if (has_spread and len(p)>6 and p[6]!="") else None
            except: continue
            bars.append((ts,y,mo,d,H,Mi,o,h,l,c,sp))
    return bars

EPOCH=datetime.datetime(1970,1,1)
def mins(y,mo,d,H,Mi):
    return int((datetime.datetime(y,mo,d,H,Mi)-EPOCH).total_seconds()//60)

def load_news():
    ev=[]  # UTC minutes of HIGH or tier-1 USD events
    with open(NEWS,encoding='utf-8',errors='replace') as f:
        f.readline(); f.readline()  # meta + header
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<7: continue
            try:
                ts=p[0]; imp=p[2]; tier=p[5]
                if not (imp=="HIGH" or tier=="1"): continue
                y=int(ts[:4]); mo=int(ts[5:7]); d=int(ts[8:10]); H=int(ts[11:13]); Mi=int(ts[14:16])
                ev.append(mins(y,mo,d,H,Mi))
            except: continue
    # forbidden 15-min buckets: +/-45min around each event
    forb=set()
    for m in ev:
        for off in range(-45,46,15): forb.add((m+off)//15)
    return forb, ev

FORB, EVENTS = load_news()

def van_utc_off(mo):  # broker->UTC (subtract): winter 2 (Nov-Mar), summer 3 (Apr-Oct)
    return 2 if (mo>=11 or mo<=3) else 3

def atr_series(bars, n=20):
    tr=[]; prevc=None
    for b in bars:
        h,l,c=b[7],b[8],b[9]
        tr.append((h-l) if prevc is None else max(h-l,abs(h-prevc),abs(l-prevc))); prevc=c
    a=[None]*len(bars); s=0.0
    for i in range(len(bars)):
        s+=tr[i]
        if i>=n: s-=tr[i-n]
        if i>=n-1: a[i]=s/n
    return a, tr

def detect_gh_offset(bars, atr, k=4):
    # choose UTC offset maximizing tier-1/HIGH coincidence of abnormal moves
    best=None
    for off in range(-8,9):
        hit=tot=0
        for i in range(21,len(bars)-1):
            a=atr[i-1]
            if not a or a<=0: continue
            b=bars[i]
            if abs(b[9]-b[6]) < k*a: continue
            um=mins(b[1],b[2],b[3],b[4],b[5])-off*60
            tot+=1
            if (um//15) in FORB: hit+=1
        if tot>50:
            r=hit/tot
            if best is None or r>best[1]: best=(off,r,tot)
    return best

def is_news(feed, b, gh_off):
    if feed=='V': um=mins(b[1],b[2],b[3],b[4],b[5])-van_utc_off(b[2])*60
    else: um=mins(b[1],b[2],b[3],b[4],b[5])-gh_off*60
    return (um//15) in FORB

def study(bars, feed, H, k, gh_off, news_excl):
    atr,tr=atr_series(bars,20)
    # accumulators for FADE and CONTINUE, split by move direction (UP move / DOWN move)
    acc=defaultdict(list)  # key -> list of (cleanwin, mfe, mae, retrace, year, movedir)
    for i in range(21,len(bars)-H-1):
        a=atr[i-1]
        if not a or a<=0: continue
        b=bars[i]; mv=b[9]-b[6]
        if abs(mv) < k*a: continue
        if tr[i] > 6*a: continue                       # shock/gap exclusion
        if feed=='V' and b[10] is not None and b[10]>1.0: continue  # extreme spread (~p99 proxy)
        if news_excl and is_news(feed,b,gh_off): continue
        ref=b[9]; up=ref+0.5*a; dn=ref-0.5*a
        movedir='U' if mv>0 else 'D'
        # forward path over horizon
        mx=-1e18; mn=1e18; first=None
        for j in range(i+1,i+1+H):
            hh,ll=bars[j][7],bars[j][8]; mx=max(mx,hh); mn=min(mn,ll)
            if first is None:
                if hh>=up and ll<=dn: first='amb'
                elif hh>=up: first='up'
                elif ll<=dn: first='dn'
        # retrace >=50% of the abnormal bar's range back toward its open
        rng=abs(b[9]-b[6]); halfway = b[6]+0.5*(b[9]-b[6])
        if movedir=='U': retr = 1 if mn<=halfway else 0
        else: retr = 1 if mx>=halfway else 0
        # FADE = opposite the move; CONTINUE = with the move
        if movedir=='U':   # up move: fade=short(down), continue=long(up)
            fade_cw = 1 if first=='dn' else 0; cont_cw = 1 if first=='up' else 0
            fade_mfe=(ref-mn)/a; fade_mae=(mx-ref)/a; cont_mfe=(mx-ref)/a; cont_mae=(ref-mn)/a
        else:              # down move: fade=long(up), continue=short(down)
            fade_cw = 1 if first=='up' else 0; cont_cw = 1 if first=='dn' else 0
            fade_mfe=(mx-ref)/a; fade_mae=(ref-mn)/a; cont_mfe=(ref-mn)/a; cont_mae=(mx-ref)/a
        yr=b[1]
        acc['FADE'].append((fade_cw,fade_mfe,fade_mae,retr,yr,movedir))
        acc['CONT'].append((cont_cw,cont_mfe,cont_mae,retr,yr,movedir))
    return acc

def summ(rows):
    if not rows or len(rows)<20: return None
    n=len(rows); cw=sum(r[0] for r in rows)/n*100
    mfe=statistics.mean(r[1] for r in rows); mae=statistics.mean(r[2] for r in rows)
    retr=sum(r[3] for r in rows)/n*100
    return dict(n=n,cw=cw,mfe=mfe,mae=mae,edge=mfe-mae,retr=retr)
def r_(name,s):
    if s is None: return f"    {name:16s} (n<20)"
    return f"    {name:16s} n={s['n']:4d}  cleanWR={s['cw']:5.1f}%  MFE={s['mfe']:.2f} MAE={s['mae']:.2f} edge={s['edge']:+.3f}  retr50={s['retr']:4.1f}%"

O=[]; W=O.append
W("# Gold v2 · Candidate D · Phase-1 — abnormal-move FADE vs CONTINUATION")
W("Honest ref = signal-bar close. cleanWR = P(favorable 0.5ATR before adverse 0.5ATR within horizon). FADE advances only if it clearly beats CONTINUE and is positive, both feeds, news-excluded, both directions, era-stable.")

ghbars=load(GHM15,False)
det=detect_gh_offset(ghbars, atr_series(ghbars)[0])
gh_off=det[0] if det else 0
W(""); W(f"GoldHistory detected UTC offset = {gh_off:+d}h (abnormal-move/tier1-news coincidence {det[1]*100:.1f}% of {det[2]} moves; a clean spike vs neighbors = news really drives abnormal moves).")

for k in (3,4,5):
    W(""); W(f"## k = {k}× ATR abnormal move")
    for feed,bars,H,label in (('G',ghbars,16,'GoldHistory M15 (H=16=4h)'),('V',load(VANH1,True),4,'Vantage H1 (H=4=4h)')):
        for news_excl in (False,True):
            acc=study(bars,feed,H,k,gh_off,news_excl)
            tag=f"{label}  {'NEWS-EXCLUDED' if news_excl else 'all moves'}"
            W(f"  {tag}")
            W(r_('FADE',summ(acc['FADE'])))
            W(r_('CONTINUE',summ(acc['CONT'])))
            f=summ(acc['FADE']); c=summ(acc['CONT'])
            if f and c:
                verdict = 'FADE>cont' if (f['edge']>c['edge'] and f['edge']>0) else 'continue wins/again fade'
                W(f"      -> {verdict}  (fade edge {f['edge']:+.3f} vs cont edge {c['edge']:+.3f})")

# direction + era split at primary k=4, news-excluded, GH M15
W(""); W("## Direction & era split (k=4, NEWS-EXCLUDED, GoldHistory M15)")
acc=study(ghbars,'G',16,4,gh_off,True)
for side,mvd in (('fade UP-moves (short)','U'),('fade DOWN-moves (long)','D')):
    rows=[r for r in acc['FADE'] if r[5]==mvd]
    W(f"  {side}: "+ (r_('',summ(rows)).strip()))
    for era,(a,b) in (("pre-2016",("0","2016")),("2016+",("2016","9999"))):
        sub=[r for r in rows if str(r[4])>=a and str(r[4])<b]
        s=summ(sub)
        if s: W(f"      {era:9s} "+r_('',s).strip())
txt="\n".join(O)+"\n"
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/abnormal-move-exhaustion.md","w").write(txt)
print(txt)
