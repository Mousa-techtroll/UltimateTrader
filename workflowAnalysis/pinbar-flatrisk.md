# PinBar tier→risk flattening — REJECTED (fails cross-feed; A+ carries real edge)

## VERDICT — keep the tier→risk map; flattening loses net everywhere PinBar wins
First arm = flatten all PinBar tiers to one conservative risk (preserves every signal, no block). Real-tick tiers are inverted (expectancy B+ +0.188 > A +0.152 > A+ +0.082 while risk ascends 0.56→0.82→1.27), which *looked* like harmful oversizing. But the 8-window validation refutes it:

- **Real-tick flat@0.9: net −$56 (neutral), PF 1.41→1.44, Sharpe 2.87→3.05, money-EqDD 14.14→13.37% — but R-DD UNCHANGED (14→14).** The DD/Sharpe tick is a lower-variance/lower-net artifact, not real drawdown reduction.
- **Every modern vendor feed LOSES: prod-M1 −$998, GH 2019-25 −$3,454, GH 2018-25 −$4,839, 2006-10 −$980.** Aggregate across 8 windows **−$9,540**.
- Flattening helps ONLY where PinBar loses anyway (2011-17 +$337, 2013-15 +$235, 2016-17 +$215 — shrinking a losing tier cuts losses).
- **PinBar A+ carries GENUINE positive edge on the vendor feeds** (tier-audit avgR: Model-1 +0.134, GH +0.123; real-tick only +0.083). The "anti-predictive A+" is a **real-tick-execution-specific quirk that does not generalize** — likely intrabar tick-path penalty on the larger A+ positions, which the vendor M1 feeds don't share.

flat@0.675 (B+ risk) is strictly worse on net (real-tick −$1,998; even more shrinkage on the winning feeds). All A+-shrinking variants lose net where A+ is positive.

**REJECT.** The tier→risk escalation is NOT harmful cross-feed; PinBar's edge is in the signals AND its A+ tier earns net at higher risk on 3 of 4 feed/model combos. `InpPinBarFlatRiskPct` left in source at identity default 0.0 (dormant, reversible). No adoption; binding baseline stays $32,490.33/865. Next = VOLUME_FILTER simplification.

---

Control = ENGAA baseline (all 5 adopted flags). Arm = + PinBar all-tiers risk 0.9 (preserves every signal). Reused controls proven identity at flat=0 ($32,490.33/865).

| Window | Ctl net/PF/DDr · pos | Arm net/PF/DDr · pos | Δnet | PinBar net (ctl→arm) |
|---|---|---|--:|--:|
| Real-tick 2019-26 | +33,033/1.45/14 · 865 | +32,978/1.48/14 · 865 | **-56** | +11,943→+12,213 |
| Prod-M1 2019-25 | +40,362/1.61/13 · 813 | +39,364/1.64/14 · 813 | **-998** | +20,449→+20,088 |
| GoldHistory 2019-25 | +28,750/1.47/14 · 816 | +25,295/1.48/14 · 816 | **-3,454** | +13,893→+12,073 |
| GoldHistory 2018-25 | +28,554/1.44/26 · 932 | +23,716/1.44/26 · 932 | **-4,839** | +14,520→+11,822 |
| 2011-2017 | +1,276/1.05/22 · 568 | +1,613/1.07/22 · 570 | **+337** | -3,205→-2,853 |
| 2013-2015 bear | +1,896/1.18/9 · 205 | +2,131/1.26/10 · 205 | **+235** | -323→-152 |
| 2016-2017 transition | +91/1.01/19 · 181 | +306/1.04/18 · 181 | **+215** | -712→-539 |
| 2006-2010 holdout | +3,535/1.13/18 · 496 | +2,554/1.10/18 · 497 | **-980** | +3,256→+2,180 |
