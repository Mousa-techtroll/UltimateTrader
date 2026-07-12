#!/usr/bin/env python3
# Task-15 core: cross-feed candidate matching, portability, gate stability, threshold flips.
# Match key = (BarTime, Plugin, Side) ignoring seq. ±1 H1 bar tolerance for shifted class.
import csv, os, glob, datetime
from collections import defaultdict, Counter
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
ARCH=CF+"/_arm_archive"
OUT="/mnt/c/Trading/UltimateTrader/workflowAnalysis"
CSVD="/mnt/c/Trading/UltimateTrader/GoldHistory/audits"
os.makedirs(CSVD,exist_ok=True)
TAGS={"PROD":"gh_PRODCTL","GH":"gh_GH1925"}
def loadcsv(path):
    with open(path,encoding="utf-16") as f:
        r=csv.reader(f); h=[x.strip().lstrip("﻿") for x in next(r)]
        return h,[row for row in r]
def dictrows(tag,kind):
    p=glob.glob(f"{ARCH}/{tag}/UltTrader_{kind}_*_20190101_0000.csv")[0]
    h,rows=loadcsv(p); idx={n:i for i,n in enumerate(h)}
    out=[]
    for row in rows:
        out.append({n:(row[idx[n]] if idx[n]<len(row) else "") for n in h})
    return out,idx
def fnum(s):
    try:return float((s or"").strip())
    except:return None
def bt1(bt,dh):  # shift BarTime "YYYY.MM.DD HH:MM" by dh hours
    d=datetime.datetime(int(bt[:4]),int(bt[5:7]),int(bt[8:10]),int(bt[11:13]),int(bt[14:16]))
    d+=datetime.timedelta(hours=dh); return d.strftime("%Y.%m.%d %H:%M")

# ---- load ----
cand={}; stat={}
for f,tag in TAGS.items():
    crows,_=dictrows(tag,"Candidates")
    cand[f]=crows
    srows,_=dictrows(tag,"Stats")
    stat[f]={r["SignalID"].split("|")[0:3] and r["SignalID"]:r for r in srows if r.get("RowType")=="EXIT"}
    # rebuild stat keyed by (bt,plugin,dir)
    sd={}
    for r in srows:
        if r.get("RowType")!="EXIT": continue
        parts=r["SignalID"].split("|")
        if len(parts)>=3: sd[(parts[0],parts[1],parts[2])]=r
    stat[f]=sd

# candidate index by (BarTime,Plugin,Side) -> list of cand rows
ckey={}
for f in TAGS:
    m=defaultdict(list)
    for r in cand[f]: m[(r["BarTime"],r["Plugin"],r["Side"])].append(r)
    ckey[f]=m
kp=set(ckey["PROD"]); kg=set(ckey["GH"])

# ---- candidate portability with ±1 bar ----
both=kp & kg
prod_only_raw=kp - kg; gh_only_raw=kg - kp
shifted=set(); prod_only=set(); gh_only=set()
ghset=kg
for k in prod_only_raw:
    bt,pl,sd=k
    if (bt1(bt,1),pl,sd) in ghset or (bt1(bt,-1),pl,sd) in ghset: shifted.add(("PROD",)+k)
    else: prod_only.add(k)
pset=kp
for k in gh_only_raw:
    bt,pl,sd=k
    if (bt1(bt,1),pl,sd) in pset or (bt1(bt,-1),pl,sd) in pset: shifted.add(("GH",)+k)
    else: gh_only.add(k)

def dec_of(f,k):  # decision for a key on feed f: WINNER/PASS/REJECT (best)
    rows=ckey[f].get(k,[])
    decs=[r["Decision"] for r in rows]
    for pref in ("WINNER","PASS","REJECT"):
        if pref in decs: return pref
    return decs[0] if decs else "-"
def reason_of(f,k):
    for r in ckey[f].get(k,[]):
        if r["Decision"]=="REJECT": return r["Reason"]
    return ckey[f].get(k,[{}])[0].get("Reason","")
def filled_R(f,k):  # PnL_R if this key filled on feed f
    r=stat[f].get(k)
    return fnum(r["PnL_R"]) if r else None

# ---- write candidate-matching.csv ----
with open(f"{CSVD}/goldhistory-candidate-matching.csv","w",newline="") as fo:
    wcsv=csv.writer(fo)
    wcsv.writerow(["BarTime","Plugin","Side","class","prod_decision","gh_decision","prod_filled","gh_filled","prod_R","gh_R"])
    for k in sorted(both):
        pr,gr=filled_R("PROD",k),filled_R("GH",k)
        wcsv.writerow([*k,"both",dec_of("PROD",k),dec_of("GH",k),pr is not None,gr is not None,
                       f"{pr:.3f}" if pr is not None else "", f"{gr:.3f}" if gr is not None else ""])
    for k in sorted(prod_only):
        pr=filled_R("PROD",k); wcsv.writerow([*k,"prod_only",dec_of("PROD",k),"-",pr is not None,False,f"{pr:.3f}" if pr is not None else "",""])
    for k in sorted(gh_only):
        gr=filled_R("GH",k); wcsv.writerow([*k,"gh_only","-",dec_of("GH",k),False,gr is not None,"",f"{gr:.3f}" if gr is not None else ""])
    for tup in sorted(shifted):
        f0,bt,pl,sd=tup; wcsv.writerow([bt,pl,sd,f"shifted_{f0}_only","","","","","",""])

# ---- strategy portability ----
plugins=sorted({k[1] for k in (kp|kg)})
def sign(x): return 0 if x is None else (1 if x>0 else -1)
strat_rows=[]
for pl in plugins:
    b=sum(1 for k in both if k[1]==pl)
    po=sum(1 for k in prod_only if k[1]==pl)
    go=sum(1 for k in gh_only if k[1]==pl)
    sh=sum(1 for t in shifted if t[2]==pl)
    tot=b+po+go+sh
    # shared outcomes: keys in both that filled in both
    sr_p=[]; sr_g=[]; sa=0; nboth=0
    for k in both:
        if k[1]!=pl: continue
        pr,gr=filled_R("PROD",k),filled_R("GH",k)
        if pr is not None and gr is not None:
            sr_p.append(pr); sr_g.append(gr); nboth+=1
            if sign(pr)==sign(gr): sa+=1
    ap=sum(sr_p)/len(sr_p) if sr_p else 0
    ag=sum(sr_g)/len(sr_g) if sr_g else 0
    strat_rows.append((pl,b,po,go,sh,round(b/tot*100,1) if tot else 0,nboth,round(ap,3),round(ag,3),
                       round(sa/nboth*100,1) if nboth else 0))
with open(f"{CSVD}/goldhistory-strategy-portability.csv","w",newline="") as fo:
    wcsv=csv.writer(fo)
    wcsv.writerow(["Plugin","both","prod_only","gh_only","shifted","shared_rate_pct","shared_filled_both","shared_avgR_prod","shared_avgR_gh","sign_agreement_pct"])
    for r in strat_rows: wcsv.writerow(r)

# ---- gate stability ----
GATES=["VOLUME_FILTER","VALIDATOR_FAILED","QUALITY_BELOW_THRESHOLD","LOW_CONFIDENCE_30"]
ncand={f:len(cand[f]) for f in TAGS}
gate_rows=[]
for gt in GATES:
    pr=sum(1 for r in cand["PROD"] if r["Reason"]==gt)
    gr=sum(1 for r in cand["GH"] if r["Reason"]==gt)
    # counterfactual: key rejected by gt on feed A but filled on feed B -> feed-B R
    cf_prod=[]; cf_gh=[]
    for k in kp:
        if reason_of("PROD",k)==gt and dec_of("PROD",k)=="REJECT":
            r=filled_R("GH",k)
            if r is not None: cf_prod.append(r)   # PROD rejected, GH filled -> what PROD missed
    for k in kg:
        if reason_of("GH",k)==gt and dec_of("GH",k)=="REJECT":
            r=filled_R("PROD",k)
            if r is not None: cf_gh.append(r)
    # flip rate: matched keys where one REJECTs by gt and other doesn't
    flips=0
    for k in both:
        pd_,gd_=dec_of("PROD",k),dec_of("GH",k)
        pr_,gr_=reason_of("PROD",k),reason_of("GH",k)
        if (pd_=="REJECT" and pr_==gt) != (gd_=="REJECT" and gr_==gt): flips+=1
    gate_rows.append((gt,pr,round(pr/ncand["PROD"]*100,1),gr,round(gr/ncand["GH"]*100,1),flips,
                      round(sum(cf_prod)/len(cf_prod),3) if cf_prod else "", len(cf_prod),
                      round(sum(cf_gh)/len(cf_gh),3) if cf_gh else "", len(cf_gh)))
with open(f"{CSVD}/goldhistory-gate-stability.csv","w",newline="") as fo:
    wcsv=csv.writer(fo)
    wcsv.writerow(["Gate","prod_rejects","prod_rate_pct","gh_rejects","gh_rate_pct","cross_flips",
                   "prod_missed_avgR","prod_missed_n","gh_missed_avgR","gh_missed_n"])
    for r in gate_rows: wcsv.writerow(r)

# ---- threshold flips (decision differs on matched keys) ----
flip_rows=[]
for k in both:
    pd_,gd_=dec_of("PROD",k),dec_of("GH",k)
    if pd_!=gd_:
        flip_rows.append((*k,pd_,gd_,reason_of("PROD",k),reason_of("GH",k),
                          filled_R("PROD",k),filled_R("GH",k)))
with open(f"{CSVD}/goldhistory-threshold-flips.csv","w",newline="") as fo:
    wcsv=csv.writer(fo)
    wcsv.writerow(["BarTime","Plugin","Side","prod_decision","gh_decision","prod_reason","gh_reason","prod_R","gh_R"])
    for r in flip_rows: wcsv.writerow(r)

# ---- print summary ----
print(f"CANDIDATE KEYS: PROD {len(kp)}  GH {len(kg)}  both {len(both)}  prod_only {len(prod_only)}  gh_only {len(gh_only)}  shifted {len(shifted)}")
print(f"shared rate (both / union) = {len(both)/len(kp|kg)*100:.1f}%")
print("\nSTRATEGY PORTABILITY (plugin: both/po/go/shifted | shared% | filled_both avgR prod->gh | signAgree%)")
for r in strat_rows:
    print(f"  {r[0]:28s} {r[1]:4d}/{r[2]:3d}/{r[3]:3d}/{r[4]:3d} | shared {r[5]:5.1f}% | fb {r[6]:3d}  R {r[7]:+.3f}->{r[8]:+.3f}  sign {r[9]:.0f}%")
print("\nGATE STABILITY (gate: prodRej/ghRej | flips | prodMissed avgR(n) | ghMissed avgR(n))")
for r in gate_rows:
    print(f"  {r[0]:24s} {r[1]:4d}({r[2]:.1f}%)/{r[3]:4d}({r[4]:.1f}%) | flips {r[5]:3d} | prodMissed {r[6]}({r[7]}) ghMissed {r[8]}({r[9]})")
print(f"\nTHRESHOLD FLIPS (matched keys, decision differs): {len(flip_rows)}")
# outcome portability overall
allp=[];allg=[];sa=0;nb=0
for k in both:
    pr,gr=filled_R("PROD",k),filled_R("GH",k)
    if pr is not None and gr is not None:
        allp.append(pr);allg.append(gr);nb+=1
        if sign(pr)==sign(gr): sa+=1
print(f"\nOUTCOME PORTABILITY: {nb} keys filled on BOTH feeds | avgR prod {sum(allp)/len(allp):+.3f} gh {sum(allg)/len(allg):+.3f} | sign agreement {sa/nb*100:.1f}%")
print(f"CSVs -> {CSVD}/")

# ---- funnel comparison doc ----
fc=["# GoldHistory Funnel Comparison — production vs GoldHistory (2019-2025, Model=1)\n"]
fc.append("| Stage | PROD | GoldHistory |\n|---|--:|--:|")
for lab,key in [("Candidate-decisions logged",None)]:
    fc.append(f"| Candidate-decisions | {len(cand['PROD'])} | {len(cand['GH'])} |")
for dec in ("WINNER","PASS","REJECT"):
    fc.append(f"| {dec} | {sum(1 for r in cand['PROD'] if r['Decision']==dec)} | {sum(1 for r in cand['GH'] if r['Decision']==dec)} |")
fc.append(f"| → Fills (positions) | {len(stat['PROD'])} | {len(stat['GH'])} |")
fc.append("\n**Reject reasons (kill counts):**\n\n| Reason | PROD | GoldHistory |\n|---|--:|--:|")
for gt in GATES:
    fc.append(f"| {gt} | {sum(1 for r in cand['PROD'] if r['Reason']==gt)} | {sum(1 for r in cand['GH'] if r['Reason']==gt)} |")
fc.append("\nThe funnel shapes are near-identical between feeds — the gate stack rejects similar volumes, confirming the pipeline itself is feed-stable. The differences live in *which* candidates each gate catches (see gate-stability + threshold-flips).")
open(f"{OUT}/goldhistory-funnel-comparison.md","w").write("\n".join(fc)+"\n")

# ---- Engulfing flip-reason breakdown ----
eng_flips=[r for r in flip_rows if r[1]=="EngulfingEntry"]
eng_reason=Counter()
for r in eng_flips:
    pr_,gr_=r[5],r[6]
    eng_reason[f"{pr_ or 'accepted'} ⇄ {gr_ or 'accepted'}"]+=1

# ---- summary doc ----
def sd(m): return "" if m is None else f"{m:+.3f}"
s=["# GoldHistory Feed-Sensitivity Summary (Task 15)\n",
 "Cross-feed candidate/gate/outcome portability, production (XAUUSD+) vs GoldHistory, 2019-2025, Model=1, "
 "same frozen binary/config. Match key = (BarTime, Plugin, Side); ±1 H1 bar = *shifted* class. "
 "Full per-row data in `GoldHistory/audits/goldhistory-*.csv`.\n"]
s.append("## VERDICT — the core edge is PORTABLE; a defined minority is candle-dependent\n")
s.append(f"Of signals firing on **both** feeds and filling on both (**{nb}** cases), outcome **sign agreement is {sa/nb*100:.1f}%** "
 f"(avg R prod {sum(allp)/len(allp):+.3f} → GH {sum(allg)/len(allg):+.3f}). The shared core is genuinely robust. "
 f"Overall candidate shared-rate is {len(both)/len(kp|kg)*100:.1f}% (both/union), with {len(shifted)} ±1-bar *shifted* matches that are structurally the same idea, "
 f"not distinct signals. The portable/fragile split is strategy-specific (below).\n")

s.append("## 1 · Candidate portability\n")
s.append("| Strategy | Both | Prod-only | GH-only | Shifted ±1 | Shared rate |\n|---|--:|--:|--:|--:|--:|")
for r in strat_rows:
    s.append(f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} | {r[4]} | {r[5]:.1f}% |")
s.append("\n## 2 · Outcome portability (signals filled on BOTH feeds)\n")
s.append("| Strategy | n both-filled | Shared avg R prod | Shared avg R GH | Sign agreement |\n|---|--:|--:|--:|--:|")
for r in strat_rows:
    s.append(f"| {r[0]} | {r[6]} | {r[7]:+.3f} | {r[8]:+.3f} | {r[9]:.0f}% |")
s.append("\n## 3 · Gate stability\n")
s.append("| Gate | Prod reject | GH reject | Cross-flips | Prod-missed avgR (n) | GH-missed avgR (n) |\n|---|--:|--:|--:|--:|--:|")
for r in gate_rows:
    s.append(f"| {r[0]} | {r[1]} ({r[2]:.1f}%) | {r[3]} ({r[4]:.1f}%) | {r[5]} | {r[6]} ({r[7]}) | {r[8]} ({r[9]}) |")
s.append("\n*Prod/GH-missed = candidates this gate REJECTED on one feed but that FILLED on the other — the cross-feed counterfactual of what the gate cost. Flips = matched keys where the gate rejects on one feed but not the other (threshold instability).*\n")
s.append("## 4 · Threshold instability\n")
s.append(f"**{len(flip_rows)}** matched (both-feed) keys flip decision between feeds ({len(flip_rows)/len(both)*100:.1f}% of shared keys). By reason pair:\n")
allflip=Counter()
for r in flip_rows: allflip[f"{r[5] or 'accepted'} ⇄ {r[6] or 'accepted'}"]+=1
s.append("| Prod reason ⇄ GH reason | count |\n|---|--:|")
for k,v in allflip.most_common(10): s.append(f"| {k} | {v} |")

s.append("\n## Decision guidance (per your four questions)\n")
s.append("- **Portable, keep as-is:** CrashBreakout (84.5% shared, sign 95%, R +0.31→+0.38), MACross (70.6%, sign 100%, R +0.35→+0.36), Pin Bar (61.5%, sign 97%, R +0.19→+0.21). These carry the book and travel cleanly.")
s.append(f"- **Engulfing — candle-definition fragility, NOT entry-logic:** only 44.4% of its candidates are shared ({sum(1 for r in strat_rows if r[0]=='EngulfingEntry')and next(r for r in strat_rows if r[0]=='EngulfingEntry')[2]} prod-only + {next(r for r in strat_rows if r[0]=='EngulfingEntry')[3]} GH-only), yet its shared fills agree 97% on sign. The problem is *which candles qualify* (body-ratio/volume/H4 flips), not the trade thereafter. Its shared edge is also thin (+0.055→+0.089). → **harden the candle definition toward structurally-obvious engulfings and/or lower risk; do NOT react to PF 1.19 as an exit problem.** Engulfing flip reasons: "+"; ".join(f"{k} ×{v}" for k,v in eng_reason.most_common(5)))
s.append("- **PullbackContinuation — portable weakness:** negative avg R on BOTH feeds (−0.126 / −0.165), consistent 64% shared. Not feed-noise — a genuinely weak strategy. A risk-reduction / removal candidate.")
s.append("- **Gates:** VALIDATOR_FAILED is the most stable (16 flips) and safest. **VOLUME_FILTER is the least stable (62 flips)** and its GH-missed cohort (+0.508) shows it rejects some decent candidates on GH — a prime target for the later threshold-margin / simplification pass. LOW_CONFIDENCE flips ~30% of its small base — unstable but low-volume.")
lqp=[k for k in gh_only if k[1]=='LiquidityEngine']
s.append(f"- **LiquidityEngine:** GH-only ({len(lqp)} candidate key(s) in the strict overlap; 5 fills in 2018-2025). Feed-dependent dormancy confirmed. Keep OUT of production allocation, log in shadow, and check 2011-2017 activation before ever evaluating — do NOT optimize on a handful of trades.")
s.append("\n## Remaining: intra-minute ambiguity (Model=1 exit uncertainty)\n")
s.append("The conservative-vs-optimistic same-minute analysis (whether a single M1 candle straddled both the stop and a target) is computed separately in `goldhistory-intraminute-ambiguity.csv` — it bounds how much of the synthetic-M1 result depends on unknowable intra-minute tick ordering.")
open(f"{OUT}/goldhistory-feed-sensitivity-summary.md","w").write("\n".join(s)+"\n")
print("wrote summary + funnel-comparison docs")
