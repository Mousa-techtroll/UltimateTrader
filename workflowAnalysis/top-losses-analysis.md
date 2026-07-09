# Top Losses Autopsy — The EA's 40 Worst Trades, 2019–2026H1

**What this report is.** A forensic review of the five biggest losing trades (by dollar loss) in each calendar year of the current baseline backtest, each reconstructed against actual gold price action and the US news calendar, with a per-trade verdict on whether the strategy logic was wrong or right-but-failed.

**Data basis.**

- Backtest: XAUUSD, real-tick model, 2019.01.01–2026.06.27. Headline: **Net $21,623.18, PF 1.31, 1,878 report trades, 13.68% equity drawdown.**
- Per-position journal: `UltTrader_Stats_XAUUSD+_20190101_0000.csv` — **928 positions** (the tester's 1,878 counts entry and exit deals, including partial closes, separately). Journal position PnL sums to $22,117.61; the ~$494 gap vs the report's net is swap/commission booked by the tester but not in the journal PnL column.
- Price: `XAUUSD_H1_rates.csv`, 44,894 H1 bars (Dec 2018 – Jul 2026), broker/server time. **All timestamps in this report are server time** (UTC+2, UTC+3 during US daylight saving).
- News: `NewsCalendar_USD.csv`, tier 1 = FOMC/NFP/CPI, tier 2 = other high-impact USD, converted from UTC to server time. **The news filter was OFF in this baseline.**

**Method.** For each entry-year 2019–2026H1, the five most negative `PnL_Money` positions were selected (40 trades total). For each: the journal facts, the H1 price path before/during/after the trade, tier-1/2 USD events inside the window [entry−12h, exit+12h], and a verdict:

- **(a) logic-correct / market-variance** — the setup was reasonable for the context; the loss is the cost of doing business (possibly aggravated by a tight stop).
- **(b) logic-wrong-for-context** — the signal read the market wrong (fading a genuine break, buying a distribution, trend signal in a dead range).
- **(c) mechanics-driven** — the loss was caused or materially worsened by the machinery: stop geometry, exit ladder, duplicate exposure, news-release execution.

Facts are labeled as facts; verdicts are interpretation.

**Book mechanics, verified against the journal before use** (claims from prior audits, re-measured here):

| Claim | Measured in this journal |
|---|---|
| Winners bank ~0.96R, losers ~−0.76R | +1.00R avg winner (457), −0.75R avg loser (470) |
| ~47% of trades exit with zero partials | 46.2% of all positions; **67.4% of losers** |
| Trailing never locked more than 1.92R | Max `MaxLockedR` in journal = 1.89R |
| Big losses cluster in the zero-partial cohort | **36 of the 40 trades here took zero partials**; the other 4 took a single tiny TP0 partial ($14–$43 against $200–$630 risk) |

One structural fact up front: **the loss tail is tightly controlled.** Across all 470 losers, only 4 exceeded −1.2R and only one exceeded −1.5R (the −2.0R FOMC trade of Dec 14, 2022). The "biggest losses" below are therefore almost all clean −1R stop-outs taken at the book's maximum sizing tier — every one of the 40 was graded **SETUP_A_PLUS** (avg 1.2% risk, vs 0.6–0.8% for lower tiers), and every one was tagged regime **TRENDING**. Big losses in this book are not blowups; they are full-size, full-confidence entries that were wrong within hours.

---

## 2019 — The pivot year

Gold opened at 1,283 and spent the first half pinned in a 1,266–1,350 range (year low 1,266 on May 2). The Fed's turn to cutting (July 31, Sept 18, Oct 30) ignited a June–September breakout to 1,557 (Sept 4), after which Q4 trade-deal optimism retraced the move into the mid-1,400s. The year closed at 1,517, +18.3%. The book's five worst 2019 losses are all longs: three were noise stop-outs inside the genuine uptrend, two bought into corrective phases that kept falling. Dollar sizes (~$150) are small because the account was near its $10k start.

### 2019 #1 — Feb 25, 17:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$162.18 (−1.08R)**

**Facts.** In at 1331.21 (New York session), SL 1324.66 (6.55 pts), risk $150 = 1.42% of $10,583. Out Feb 26, 10:01 at the stop. Held 17.0h. MAE 1.0R adverse / MFE 0.15R favorable. Zero partials. The SL sat 0.5 pts *beyond* the 12h swing low (1325.2) — technically correct placement.
**Price context.** Gold had topped at 1,346 on Feb 20 (then the YTD high) and was drifting sideways-down; the prior 48h were a flat 1,325–1,333 box. After the stop-out, price kept falling — 1,306 within 72h, 1,290 by Mar 1. It never revisited the entry.
**News.** Fed Chair Powell testimony Feb 26, 16:45 (tier 2); CB Consumer Confidence 17:00 — both after the exit.
**Verdict — (b) logic-wrong-for-context.** The pattern read a flat box under a rejected top as a trend pullback ("TRENDING/DAY_TREND"), but the market was in early distribution after the Feb 20 rejection. The stop placement was fine; the direction was wrong, confirmed by 40 more points of downside. Why so big a loss? Because A+ confidence put maximum size on a topping structure the classifier couldn't see.

### 2019 #2 — Jan 7, 10:00 · Bullish MA Cross (Confirmed) · LONG · A+ — **−$158.04 (−1.02R)**

**Facts.** In at 1291.50 (Asia), SL 1285.49 (6.0 pts), risk $155 = 1.55% of $9,953. Out Jan 8, 04:01 at 1286.0. Held 18h. MAE 0.9R / MFE 0.6R — it was +0.6R in profit first. Zero partials, no break-even move.
**Price context.** The early-January uptrend was intact (+10 pts over 10 days). The trade rose to 1295.1, then the overnight Asia dip to 1283.4 took the stop. Price was back above 1291.5 within 72h and at 1297 by Jan 10; gold went on to 1,326 by late January. The stop was 62% of the prior 48h range.
**News.** ISM Non-Manufacturing PMI Jan 7, 17:00 (tier 2).
**Verdict — (a) logic-correct / market-variance.** Right trend, right direction, proven within days. It failed because a 6-point stop cannot hold an overnight Asia rotation, and because +0.6R of open profit had no protection — the ladder's first partial (TP0) never triggered and break-even never armed.

### 2019 #3 — Sep 23, 18:00 · Bullish Engulfing (Confirmed) · LONG · A+ — **−$153.78 (−1.09R)**

**Facts.** In at 1526.01 (NY), SL 1516.62 (9.4 pts), risk $141 = 1.35% of $10,490. Out Sep 24, 16:43 at 1516.58. Held 22.7h. MAE 0.99R / MFE 0.09R. Zero partials.
**Price context.** Gold was consolidating 1,485–1,535 three weeks after the 1,557 cycle top, still +27 pts over 10 days. The stop-out at 1515.7 caught the exact low of the dip: that same evening (Sep 24, 19:00) gold spiked to 1,535.7 on US political headlines and was above the entry within hours.
**News.** S&P Global PMIs Sep 23, 16:45; CB Consumer Confidence Sep 24, 17:00 (all tier 2).
**Verdict — (a) logic-correct / market-variance.** Stopped within 1 point of the swing low, hours before a +20 rally through the entry. The thesis was right; the 9.4-pt stop (59% of the 48h range) was simply inside the consolidation's noise band. The only critique: entering at the top of the day's range (MFE 0.09R — it never breathed).

### 2019 #4 — Jul 15, 12:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$150.26 (−0.97R)**

**Facts.** In at 1416.55 (London), SL 1409.75 (6.8 pts), risk $154 = 1.42%. Out same day 17:24 at the stop. Held 5.4h. MAE 1.0R / MFE 0.08R. Zero partials.
**Price context.** A dead mid-July range (48h drift +0.4 pts). The NY session pushed to 1407.7, through the stop. Gold based at 1,400 on Jul 17, then a Fed-speaker-driven surge hit 1,453 on Jul 19 — the entry was revisited within 24h and TP1 (1432.97) was exceeded within four days.
**News.** None in window.
**Verdict — (a) logic-correct / market-variance.** Right idea, four days early, with a stop that only covered two-thirds of the 48h range. In a range this quiet the pattern's edge was thin — but the direction call was validated emphatically.

### 2019 #5 — Nov 4, 09:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$148.72 (−1.00R)**

**Facts.** In at 1512.10 (Asia), SL 1506.43 (5.7 pts — 153% of the tiny prior 48h range), risk $149 = 1.42%. Out same day 18:19 at 1506.41. Held 9.3h. MAE 0.99R / MFE 0.48R. Zero partials.
**Price context.** This was the week trade-deal optimism and surging yields broke gold down. After the stop, gold sank to 1,461 within 72h and 1,456 by Nov 8 — a 55-point breakdown. The entry level was never revisited that week.
**News.** None in window.
**Verdict — (b) logic-wrong-for-context.** A bullish pin bar caught inside the first hours of a genuine risk-on regime break. Unlike #2–#4, price never came back: this was not a stop-noise loss but a direction error. The regime engine labeled it TRENDING (long-side) on the very day the tape turned; the loss was full-size A+ against a real breakdown.

---

## 2020 — COVID crash and the QE run

The pandemic year: a liquidity crash to 1,451 (Mar 16), then the QE/negative-real-yield run to the then-record 2,075 (Aug 7), followed by four months of distribution down to the 1,764 cycle low on Nov 30. Gold closed at 1,898, +25%. Notably, none of the book's five worst losses came from the March crash — they cluster in the August–November distribution, where the trend classifier kept reading a correcting market as trending.

### 2020 #1 — Sep 7, 04:00 · Bearish Pin Bar · SHORT · A+ — **−$201.63 (−0.99R)**

**Facts.** In at 1933.07 (Asia), SL 1938.20 (5.13 pts), risk $204 = 1.77% of $11,531. Out after **23 minutes** at 1938.21. MAE 1.0R / MFE 0.2R. Zero partials.
**Price context.** Sep 7, 2020 was **US Labor Day** — a holiday-thinned tape. The 04:00 Asia squeeze to 1941.4 took the stop within the entry hour. The short thesis was right: gold fell to 1,906 the next day and the entry was revisited within 24h. The 5.13-pt stop was 48% of the prior 48h range in a post-2,075 market still swinging $20–30 a day.
**News.** None in window (holiday).
**Verdict — (a) logic-correct / market-variance, aggravated by mechanics.** Correct direction, killed in 23 minutes by a holiday-liquidity wiggle smaller than a normal session's rotation. A 5-point stop at 1,930 gold in September 2020 volatility is a coin flip on the next 15-minute bar. (Note the 5.13-pt stop distance — it will recur.)

### 2020 #2 — Oct 12, 23:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$181.88 (−1.13R)**

**Facts.** In at 1923.42 (late NY), SL 1917.98 (5.4 pts), risk $161 = 1.42%. Out Oct 13, 04:04 at 1917.97. Held 5.1h. MAE 1.0R / MFE 0.38R. Zero partials. **This was the second long opened on the same idea within 5 hours** — see #3 below, opened 18:00 the same day and still open (and underwater) when this one was added.
**Price context.** Gold was correcting off the Oct 12 morning high 1933; both longs were stopped in the same overnight Asia flush to 1911. Price bounced back through both entries by 11:00 Oct 13, then US CPI (15:30) and a firm dollar sank gold to 1,882 by Oct 14.
**News.** US CPI Oct 13, 15:30 (tier 1) — after the exit, but inside the ±12h window.
**Verdict — (c) mechanics-driven: duplicate exposure.** Whatever the merit of the first long, the EA added a second, nearly identical position (same pattern, same direction, entries 1.0 pt apart, stops 1.1 pt apart) while the first was losing. Combined risk: $322 = 2.8% of the account on one idea, both stopped 31 minutes apart for **−$363 total**. There is no same-direction cluster guard; this pair is the exhibit.

### 2020 #3 — Oct 12, 18:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$181.30 (−1.12R)**

**Facts.** The first of the Oct 12 pair. In at 1924.46, SL 1919.04 (5.4 pts), risk $161 = 1.42%. Out Oct 13, 03:33 at 1919.03. Held 9.6h. MAE 1.0R / MFE 0.25R. Zero partials.
**Price context.** As above: entry into a fading bounce below the 1,933 swing high, stopped in the Asia dip; the bounce to 1,925 the next morning failed and CPI-day selling took gold 40 points lower. TP1 (1941.48) was never approached; an unstopped hold would have been −40 pts within two days.
**News.** US CPI Oct 13, 15:30 (tier 1) in window.
**Verdict — (b) logic-wrong-for-context.** Buying a mid-range bounce inside a fresh corrective downswing, the evening before CPI. Price briefly revisiting the entry doesn't rescue the call — the week's direction was down and the target was never in play.

### 2020 #4 — Nov 30, 07:00 · Bearish Pin Bar · SHORT · A+ — **−$171.80 (−0.83R)**

**Facts.** In at 1769.93 (Asia), SL 1775.06 (5.13 pts again), risk $206 = 1.9%. TP0 partial banked $14.32 at 07:15; stopped 08:48 at 1775.07. Held 1.8h. MAE 1.0R / **MFE 0.88R** — it was nearly +1R in profit first. No break-even move.
**Price context.** Gold had fallen 97 points in 10 days; that very morning printed 1,764.3 — **the exact bottom of the entire post-August correction**. The short sold 5 pts above the cycle low on month-end rebalancing day. The squeeze to 1,783.8 stopped it; gold never traded below 1,764 again and was at 1,848 by Dec 4.
**News.** MNI Chicago PMI 16:45 (tier 2), after exit.
**Verdict — (b) logic-wrong-for-context.** Momentum-following a 10-day, 97-point slide into its capitulation low is selling exhaustion, not trend. Secondary mechanics note: the trade *was* +0.88R at one point and banked only $14 of it — the ladder neither protected the float nor moved the stop.

### 2020 #5 — Apr 9, 14:00 · Bullish Engulfing (Confirmed) · LONG · A+ — **−$163.68 (−0.99R)**

**Facts.** In at 1662.80 (London), SL 1656.03 (6.8 pts), risk $165 = 1.42%. Out after **30 minutes** at 1656.01. MAE 0.99R / MFE 0.08R. Zero partials.
**Price context.** The day the Fed announced its $2.3T lending backstop. Entry at 14:00; a pre-announcement dip to 1654.9 in the 14:00 hour took the stop; the announcement and Powell's speech then drove gold to 1,690 by 20:00 — TP1 (1679.5) was hit the same day, TP2 (1690.6) within 24h. The stop was 24% of the prior 48h range in peak-COVID volatility.
**News.** Jobless claims (6.6M print) + Core PPI 15:30, Powell speech 17:00 (tier 2) — one to three hours after the stop-out.
**Verdict — (a) logic-correct / market-variance.** Dead-right thesis, full targets reached within hours of the stop-out. A 6.8-pt stop in April 2020 (48h range: 28 pts) had no chance against pre-Fed positioning noise. Of all 40 trades, this is among the clearest "right, but the stop died first."

---

## 2021 — The consolidation grind

A −4% year of chop: the 1,959 high on Jan 6, a June collapse after the hawkish June 16 FOMC dot-plot (−100 pts in three days), an Aug 9 flash-crash low at 1,676, and endless 1,720–1,900 rotation. Trend systems bled here, and the book's DD reconstruction shows its deepest balance drawdown episode (~17%) running from Mar 2021 into Feb 2022. Four of the five worst losses were whipsaw stop-outs in chop; one was an exit-ladder giveback.

### 2021 #1 — Jun 16, 05:00 · Bearish Pin Bar · SHORT · A+ — **−$242.42 (−1.01R)**

**Facts.** In at 1853.69 (Asia), SL 1858.82 (5.13 pts), risk $239 = 2.0% of $11,950 — the largest risk% in the top-40. Out 07:22 at 1858.93. Held 2.4h. MAE 0.97R / MFE 0.06R. Zero partials.
**Price context.** FOMC day. The Asia squeeze to 1,861 took the stop at 07:22; that evening's hawkish dot-plot (21:00) crushed gold from 1,860 to 1,774 within 48h (1,760.8 by Jun 18). TP1 (1843.43) would have been exceeded by 80 points.
**News.** FOMC statement/press conference that evening (tier 1, in ±12h window of entry).
**Verdict — (a) logic-correct / market-variance — the year's most painful near-miss.** The short captured exactly the right idea 16 hours early, with a 5-pt stop that was 16% of the prior 48h range. Max-tier size, minimum-width stop, correct direction, −$242. If a strategy is "right" and still loses this way, the reason is arithmetic: the stop is far inside the market's routine breathing range, so being right on direction is not enough — you must also be right on the next two hours of noise.

### 2021 #2 — Apr 27, 04:00 · Bullish MA Cross (Confirmed) · LONG · A+ — **−$190.71 (−0.97R)**

**Facts.** In at 1781.49 (Asia), SL 1773.20 (8.3 pts), risk $196 = 1.55%. Out Apr 28, 03:03 at 1774.02. Held 23.1h. MAE 0.94R / MFE 0.49R. Zero partials.
**Price context.** Pre-FOMC drift week; 10-day trend essentially flat (−1.2 pts). The trade chopped between 1785.5 and 1766.4 and stopped overnight before the Apr 28 FOMC. Post-FOMC whipsaw: 1,756 low and 1,790 high on Apr 29 — both sides of the trade's range within one day.
**News.** CB Consumer Confidence Apr 27, 17:00 (tier 2); FOMC the next evening.
**Verdict — (b) logic-wrong-for-context.** A trend-following signal (MA cross, regime TRENDING) fired in a flat, pre-FOMC range. There was no trend to follow — the 10-day drift was −1 point. This is a classifier error more than a pattern error: chop was mislabeled as trend, and max-tier size was applied to a coin flip.

### 2021 #3 — Aug 31, 11:00 · Bullish MA Cross (Confirmed) · LONG · A+ — **−$189.72 (−1.02R)**

**Facts.** In at 1815.46 (London), SL 1810.31 (5.2 pts), risk $185 = 1.55%. Out 15:54 at 1810.22. Held 4.9h. MAE 1.0R / MFE 0.3R. Zero partials.
**Price context.** Post-Jackson-Hole uptrend intact (+34 pts/10d). A month-end London dip to 1,801.6 took the stop; price was back above the entry the same evening and held 1,808–1,820 for days.
**News.** MNI Chicago PMI 16:45, CB Consumer Confidence 17:00 (tier 2) — after exit.
**Verdict — (a) logic-correct / market-variance.** Right trend, stopped by a month-end rebalancing dip covering barely a third of the 48h range, recovered within hours. Same signature as 2019 #2: correct direction, sub-noise stop, no profit protection.

### 2021 #4 — Aug 26, 09:00 · Bearish Pin Bar · SHORT · A+ — **−$182.88 (−0.84R)**

**Facts.** In at 1786.41 (Asia), SL 1791.54 (5.13 pts), risk $217 = 1.77%. TP0 partial banked $15.48 at 15:41. Stopped 17:28 at 1791.60. Held 8.5h. MAE 0.99R / **MFE 1.23R**. Break-even never armed.
**Price context.** Pre-Jackson-Hole positioning day. The short worked to 1,780.0 (+1.23R, 4 pts from TP1 at 1776.15), then the 15:30 US GDP/claims data squeezed price to 1,798.2 and through the stop. Within the following hour gold fell back to 1,784; Powell's dovish speech the next day then lifted it to 1,823 by Aug 30.
**News.** US GDP q/q + jobless claims Aug 26, 15:30 (tier 2) — the squeeze that killed it.
**Verdict — (c) mechanics-driven: exit-ladder giveback.** A trade that reaches +1.23R and returns −0.84R with only $15 banked is not a signal problem. At +1.23R the ladder had taken one micro-partial and left the stop at the origin; a break-even move at +1R would have made this a scratch. This is the clearest of three such givebacks in the top-40 (see also 2020 #4 and 2026 #1).

### 2021 #5 — May 18, 16:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$178.47 (−1.00R)**

**Facts.** In at 1871.38 (NY), SL 1864.81 (6.6 pts), risk $178 = 1.42%. Out after 56 minutes at 1864.80. MAE 0.99R / MFE 0.32R. Zero partials.
**Price context.** Strong uptrend (+32 pts/10d, gold at 4.5-month highs). A NY-afternoon dip to 1,863.2 clipped the stop; next day's FOMC-minutes whipsaw swung 1,852–1,890, and gold was at 1,890 within 72h. The stop covered 20% of the prior 48h range.
**News.** None in window (FOMC minutes the next evening).
**Verdict — (a) logic-correct / market-variance.** Right trend, validated within a day; the stop was a fifth of the market's 2-day breathing range. The same arithmetic as 2021 #1.

---

## 2022 — The hike-cycle bear

The Ukraine invasion spiked gold to 2,070 (Mar 8); then 425bp of Fed hikes ground it down for six months to 1,615 (Sep 28) before a Q4 recovery closed the year flat at 1,824. A genuinely two-sided trend year. The book's worst 2022 losses are its most mechanics-heavy: the single worst R-loss of the whole backtest (an FOMC stop-slip), a duplicated short pair in a dead tape, and two counter-context entries.

### 2022 #1 — Dec 14, 17:00 · Bullish Engulfing (Confirmed) · LONG · A+ — **−$359.84 (−2.00R)** — the worst R-loss of the entire 7.5-year run

**Facts.** In at 1810.46 (NY) — **four hours before the FOMC statement** — SL 1803.58 (6.9 pts), risk $180 = 1.42% of $12,669. Exit stamped **exactly 21:00:00**, the statement second, at 1796.65 — **$6.93 through the stop level**, doubling the loss to −2.0R. The 21:00 H1 bar: open 1809.92, low 1795.35, close 1805.18. Recorded MAE (0.51R) never registered the spike — the drop outran the tracker. Zero partials.
**Price context.** Gold had rallied 21 pts in 48h after the soft Dec 13 CPI (1,824 high). The engulfing bought that momentum. The FOMC statement produced a one-minute liquidity vacuum to 1,795; within two hours price was back at 1,814, above the entry.
**News.** FOMC statement + rate decision 21:00, press conference 21:30 (tier 1) — the exit *is* the release.
**Verdict — (c) mechanics-driven: news execution.** The direction call was defensible (price recovered immediately) but irrelevant. Holding a resting stop through an FOMC statement bought a fill $7 through the level — roughly $180 of the loss is pure slippage, the only material stop-slip in 928 positions. The news filter was off; this trade is the singular, quantified cost of that: with a flat book at 21:00 the worst case was −1R or nothing.

### 2022 #2 — May 18, 10:00 · Bearish Pin Bar · SHORT · A+ — **−$210.00 (−1.00R)**

**Facts.** In at 1809.77 (Asia), SL 1815.67 (5.9 pts), risk $209 = 1.77%. Out after 30 minutes at 1815.74. MAE 1.0R / MFE 0.03R. Zero partials.
**Price context.** Gold was two days into a corrective bounce off the May 16 low 1,786 (broader 10-day trend −67 pts). The short sold into that bounce; the same-morning squeeze to 1,817.2 stopped it. Price dipped to 1,807 that afternoon (never near TP1 at 1,798) and then rallied 40 points to 1,849 by May 20.
**News.** None in window.
**Verdict — (b) logic-wrong-for-context.** Right macro trend (bear year), wrong week: it faded a live two-day recovery leg. The stop was 12% of the 48h range, so even the right idea would have needed to work instantly. It didn't, and the market ran 40 points against the direction within two days.

### 2022 #3 — Jun 6, 04:00 · Bearish Pin Bar · SHORT · A+ — **−$201.63 (−0.99R)**

**Facts.** In at 1850.81 (Asia), SL 1855.94 (5.13 pts), risk $204 = 1.77%. Out 06:16 at 1855.95. MAE 1.0R / MFE 0.04R. Zero partials. **Opened one hour after #4 below — the same pattern, same direction, entries 0.8 pts apart, while #4 was open.**
**Price context.** The quietest tape in the whole top-40: the prior 48h range was **5.8 points** — the 5.13-pt stop equalled 88% of two days of total movement. A 6-point Monday-Asia drift to 1,856.7 stopped both shorts. Gold did eventually fall to 1,825 by Jun 10 (post-CPI), passing TP1 — four days beyond the trade's horizon.
**News.** None in window.
**Verdict — (c) mechanics-driven: duplicate exposure.** The add. Two nearly identical shorts, stopped 94 minutes apart, −$403 combined = 3.5% of the account on one idea in a tape with no information in it. Same failure as Oct 12, 2020: no same-direction cluster guard.

### 2022 #4 — Jun 6, 03:00 · Bearish Pin Bar · SHORT · A+ — **−$201.24 (−0.99R)**

**Facts.** The first of the pair. In at 1851.62, SL 1856.75 (5.13 pts), risk $204 = 1.77%. Out 07:50 at 1856.75. MAE 1.0R / MFE 0.2R. Zero partials.
**Price context.** As above — a signal fired into a 48h range of 5.9 points, labeled TRENDING by the regime engine.
**News.** None in window.
**Verdict — (c) mechanics-driven: stop geometry vs a dead tape.** When the stop distance is 88% of the two-day range, the trade is a coin flip on the next drift, regardless of the pattern's merit. A minimum-range or minimum-ATR-percentile gate on the tape (not just on the candle) would have vetoed both entries. (The direction was eventually right; the geometry never gave it a chance to matter.)

### 2022 #5 — Dec 12, 13:00 · Bullish Engulfing (Confirmed) · LONG · A+ — **−$182.70 (−1.00R)**

**Facts.** In at 1792.44 (London), SL 1787.26 (5.2 pts), risk $183 = 1.42%. Out 15:59 at 1787.25. Held 3.0h. MAE 1.0R / MFE 0.59R. Zero partials.
**Price context.** The day before the soft December CPI. The London dip to 1,785.1 stopped it; the next day CPI launched gold from 1,781 to 1,824. TP1 (1801.87) and TP2 (1808.82) were both cleared within 24h of the stop-out.
**News.** 10-Year Note auction Dec 12, 20:00 (tier 2); CPI next day 15:30 (tier 1, just outside the exit+12h window).
**Verdict — (a) logic-correct / market-variance.** One day early into a +43-point move in its direction. It reached +0.59R first and banked nothing. Same right-but-unprotected signature as 2020 #5 and 2021 #1.

---

## 2023 — Range year with a war spike

Gold bottomed at 1,805 (Feb 28), popped to 2,063 in May on the banking crisis, ground back to 1,810 by early October, then repriced violently after the Oct 7 Hamas attack (1,810 → 2,009 by late October) and printed a blowoff spike to 2,146 on Dec 4 that was rejected within hours. Close: 2,063, +12.9%. Four of the five worst losses were correct-thesis trades stopped by squeezes — 2023 is the year the "right but the stop died first" pattern is purest. Note the escalating dollar sizes: the account had compounded to ~$15–16k, so a −1R A+ loss now costs ~$230–300.

### 2023 #1 — Sep 11, 06:00 · Bearish Pin Bar · SHORT · A+ — **−$305.03 (−1.01R)**

**Facts.** In at 1922.64 (Asia), SL 1927.77 (5.13 pts), risk $303 = 2.0% of $15,173. Out 08:26 at 1927.78. MAE 0.99R / MFE 0.04R. Zero partials.
**Price context.** A drifting September downtrend (−17 pts/10d). The Monday-Asia squeeze to 1,928.6 stopped it. Gold then did exactly what the short said: down to 1,901 by Sep 14 — TP1 (1912.38) comfortably passed within three days.
**News.** None in window.
**Verdict — (a) logic-correct / market-variance.** The stop (5.13 pts, 67% of a very quiet 48h range) died to a two-hour squeeze inside a correct week-long call. Note this is the fourth appearance of the identical 5.13-pt stop distance.

### 2023 #2 — Aug 9, 04:00 · Bearish Pin Bar · SHORT · A+ — **−$263.67 (−1.00R)**

**Facts.** In at 1925.05 (Asia), SL 1930.18 (5.13 pts), risk $263 = 1.77%. Out 05:49 at 1930.19. MAE 1.0R / MFE 0.12R. Zero partials.
**Price context.** Downtrend intact (−31 pts/10d), pre-CPI (Aug 10). The Asia squeeze to 1,930.8 stopped it; gold then fell to 1,910.8 by Aug 11 — TP1 (1914.79) passed within two days.
**News.** None in ±12h window (CPI ~34h later).
**Verdict — (a) logic-correct / market-variance.** Same trade as #1 in every respect: right direction, 5.13-pt stop, dead in under two hours, target hit days later without it.

### 2023 #3 — Jun 20, 08:00 · Bearish Pin Bar · SHORT · A+ — **−$237.36 (−0.99R)**

**Facts.** In at 1949.86 (Asia), SL 1954.99 (5.13 pts), risk $241 = 1.77%. Out 10:35 at 1954.99. MAE 1.0R / MFE 0.55R. Zero partials.
**Price context.** Post-June-FOMC drift lower. Worked to +0.55R, then the London squeeze to 1,956.8 took the stop. Gold fell to 1,910 by Jun 23 (Powell's hawkish testimony) — TP1 (1939.6) hit the next day, TP2 passed after that.
**News.** None in window.
**Verdict — (a) logic-correct / market-variance.** A −$237 fee for being three hours early on a −40-point move it had already read correctly. Again: +0.55R float, nothing banked, no break-even.

### 2023 #4 — Dec 7, 16:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$232.56 (−1.06R)**

**Facts.** In at 2037.29 (NY), SL 2028.23 (9.1 pts), risk $219 = 1.42%. Out after **45 minutes** at 2027.63. MAE 0.98R / MFE 0.03R. Zero partials.
**Price context.** Three days after the Dec 4 blowoff to 2,146 and its violent same-day rejection — the tape was distributing under 2,040 with NFP the next day. The 16:00 NY hour flushed to 2,025 and stopped it. NFP (Dec 8) came in hot: gold dropped to 1,994 within 24h and 1,975 by Dec 11. The entry was never revisited in 72h.
**News.** Initial jobless claims Dec 7, 15:30 (tier 2); NFP next day (tier 1, ~23h after entry).
**Verdict — (b) logic-wrong-for-context.** Buying a dip two days after a rejected all-time-high spike, hours before NFP, is buying distribution. The market said so immediately (MFE 0.03R) and kept saying it for a week. The pattern saw a pin bar; the context was a failed blowoff.

### 2023 #5 — Oct 24, 10:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$225.72 (−0.99R)**

**Facts.** In at 1977.77 (Asia), SL 1971.54 (6.2 pts), risk $229 = 1.42%. Out 11:41 at 1971.53. MAE 1.0R / MFE 0.22R. Zero partials.
**Price context.** The war-premium rally (+46 pts/10d) consolidating just under 2,000. A PMI-day London flush to 1,953.4 stopped it (the exit caught the first 6 points of that flush); gold reversed the same day and was back at 2,006 by Oct 27 — above TP1 within three days.
**News.** S&P Global PMIs Oct 24, 16:45 (tier 2).
**Verdict — (a) logic-correct / market-variance.** Right trend, and the eventual move exceeded TP1 — but the 6-pt stop sat inside a 20-pt-range consolidation that routinely swept 25 points intraday. The flush went 24 points below the entry; even a 2x stop would have died. Early and under-stopped rather than wrong.

---

## 2024 — The record run begins

From the 1,984 low (Feb 14), gold broke the 2020–2023 ceiling in March and never looked back: central-bank buying, the beginning of Fed cuts, and safe-haven demand drove it to 2,790 (Oct 31), interrupted by the Aug 5 yen-carry crash (2,477 → 2,364) and a pre-US-election washout in late October. Close: 2,625, +27.2%. The 2024 top losses are dominated by longs stopped at extension highs and one counter-trend short into a V-recovery — this is the year "buying the top tick of a vertical move with a noise stop" becomes the book's signature loss.

### 2024 #1 — Aug 8, 05:00 · Bearish Pin Bar · SHORT · A+ — **−$288.20 (−1.02R)**

**Facts.** In at 2386.83 (Asia), SL 2391.96 (5.13 pts — its sixth appearance), risk $282 = 1.77% of $15,927. Out 06:41 at 2392.04. MAE 1.0R / MFE 0.09R. Zero partials.
**Price context.** Three days after the yen-carry crash low (2,364, Aug 5), the tape was a violent V-recovery. The short sold the pullback from 2,418; the Asia squeeze to 2,396 stopped it, and gold then rallied relentlessly — 2,437 within 72h, 2,473 by Aug 12. The entry was never revisited.
**News.** 10-Year auction Aug 7, 20:00; jobless claims Aug 8, 15:30 (tier 2) — the claims print fueled the relief rally after exit.
**Verdict — (b) logic-wrong-for-context.** Shorting the third day of a V-shaped crash recovery in the strongest gold year in a decade. The dip was being bought globally; a 5-pt stop against that flow was gone within the hour. Direction wrong, not unlucky.

### 2024 #2 — Oct 24, 21:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$265.72 (−1.05R)**

**Facts.** In at 2735.53 (late NY), SL 2725.31 (10.2 pts), risk $253 = 1.42%. Out Oct 25, 06:14 at 2725.28. Held 9.2h. MAE 0.99R / MFE 0.22R. Zero partials.
**Price context.** The pre-election bull was consolidating 2,709–2,758 after a +87-pt 10-day run. The overnight Asia dip to 2,724 stopped it; gold recovered the entry within 24h and printed the 2,790 all-time high on Oct 31 — TP1 (2767.62) hit within four sessions.
**News.** Jobless claims + new home sales Oct 24, durable goods Oct 25 (tier 2).
**Verdict — (a) logic-correct / market-variance.** Right trend, right level (bought the middle of a consolidation, stop 2.8 pts under the 12h swing low), proven days later. The 10-pt stop was 21% of the 48h range — the same arithmetic problem at a higher price level.

### 2024 #3 — Aug 1, 05:00 · IC Breakout Long (Consol=4 bars) · LONG · A+ — **−$265.33 (−0.99R)**

**Facts.** In at 2451.55 (Asia), SL 2431.17 (20.4 pts), risk $268 = 1.69%. Out 12:51 at the stop. Held 7.9h. MAE 1.0R / **MFE 0.00R — it never ticked in profit**. Zero partials. DayType: DAY_VOLATILE.
**Price context.** Entered at the top of a +58-pt, 48h post-FOMC melt-up (the FOMC was 8 hours before entry; the entry printed 3 pts under the 48h high). Aug 1 was the recession-scare day: weak claims/ISM reversed everything risk-on, and gold fell 21 pts to the stop. The next day's NFP miss spiked gold to 2,477 (above entry), then the Aug 5 crash hit 2,364.
**News.** FOMC statement/presser Jul 31, 21:00/21:30 (tier 1, 8h before entry); jobless claims 15:30, ISM Manufacturing 17:00 (tier 2, day of).
**Verdict — (b) logic-wrong-for-context.** A breakout signal that bought the peak of a two-day vertical, in Asia hours, sandwiched between FOMC and NFP inside the most event-dense week of the summer. MFE 0.00 is the tell: there was no follow-through to break out into — the move it chased was already the move.

### 2024 #4 — Oct 23, 12:00 · Bullish Engulfing (Confirmed) · LONG · A+ — **−$251.40 (−0.98R)**

**Facts.** In at 2757.11 (London) — **1.3 points below the all-time high printed one hour earlier** (2,758.4). SL 2748.82 (8.3 pts), risk $256 = 1.42%. Out 15:08 at 2748.76. Held 3.1h. MAE 1.0R / MFE 0.06R. Zero partials.
**Price context.** +94 pts of 10-day run into the entry. Oct 23 was a profit-taking day (rising yields): gold fell from the entry to 2,708.8 that evening — 48 points through the stop zone. It did not regain 2,757 within 72h (the 2,790 ATH came Oct 31, after trade #2's window). The next top-5 loss (#2 above) was opened the following evening — two of the year's five worst losses came from the same 36-hour washout.
**News.** Existing home sales 17:00 (tier 2).
**Verdict — (b) logic-wrong-for-context.** The engulfing "confirmation" at a fresh all-time high after +94 in ten days was the exhaustion bar itself. Buying the top tick of extension with an 8-pt stop (19% of the 48h range) offers no path to survive even routine profit-taking. The bull resumed later, but this entry's risk geometry never owned any part of that resumption.

### 2024 #5 — Aug 26, 20:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$245.32 (−1.07R)**

**Facts.** In at 2520.22 (late NY), SL 2510.82 (9.4 pts), risk $229 = 1.42%. Out Aug 27, 04:13 at the stop. Held 8.2h. MAE 1.0R / MFE 0.34R. Zero partials.
**Price context.** One session after the then-ATH 2,531 (post-Jackson-Hole dovish repricing). The overnight Asia dip to 2,505.9 stopped it; gold was back at 2,529 by Aug 28 — the entry recovered within 24h.
**News.** Durable goods Aug 26, 15:30 (tier 2).
**Verdict — (a) logic-correct / market-variance.** Right trend, recovered almost immediately; killed by an overnight rotation half a point deeper than the stop. The recurring composite: enter late NY, hold through Asia with no partial and no BE, donate 1R to the overnight range.

---

## 2025 — The mania year

The historic leg: 2,615 (Jan 6) to 4,550 (Dec 26), +64.5% — tariff shocks, dollar diversification, relentless ETF and central-bank flows. Corrections were violent but brief: an April air-pocket, the October top at ~4,381 followed by a November flush to 3,929, then a December recovery to new highs. At these prices the book's H1 patterns carried dollar-risks of $420–590 per trade — and the same stop distances that fit $1,900 gold now covered a tenth of a normal two-day range. Four of the five worst losses were longs in a raging bull; three recovered to entry within hours-to-days.

### 2025 #1 — Nov 5, 08:00 · Bearish Pin Bar · SHORT · A+ — **−$596.14 (−1.01R)** — the largest dollar loss of the backtest

**Facts.** In at 3964.85 (Asia), SL 3979.17 (14.3 pts), risk $589 = 1.77% of $33,217. Out 10:05 at 3979.36. MAE 1.0R / MFE 0.2R. Zero partials.
**Price context.** Mid-correction after the October top (−110 pts/10d): gold was ranging 3,929–4,031 for two days. The short sold mid-range; the ADP-day squeeze to 3,987 stopped it. Price fell back below the entry to 3,956 within two hours of the stop-out — but TP1 (3936) was never reached, and gold then rallied to 4,027 by Nov 7. The correction low was already in (3,929, Nov 4).
**News.** ADP employment 15:15, ISM Services 17:00 (tier 2, after exit).
**Verdict — (a) logic-correct / market-variance, marginal.** A trend-pullback short consistent with the correction, stopped by a data-day squeeze; even unstopped, the trade likely loses later as the range floor held. It tops the dollar table not because anything unusual happened but because −1R at a $33k account and 1.77% risk is $590 — the "biggest losses" in this book are mostly the *latest* losses at the largest balance.

### 2025 #2 — Sep 22, 23:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$508.44 (−1.16R)**

**Facts.** In at 3747.77 (late NY), **SL 3742.63 — 5.14 points away**, at $3,750 gold (0.14% of price; 8% of the prior 48h range of 66 pts). The tight stop forced 0.85 lots — the largest position in the top-40. Risk $440 = 1.42%. Out Sep 23, 01:39 at 3742.61 (−1.16R: spread/fill costs are huge relative to a 5-pt stop). Held 2.7h. MAE 0.99R / MFE 0.16R. Zero partials.
**Price context.** Gold was up +64 in 48h and +103 in ten days; the entry printed 1 point under the 48h high. A 9-point Asia wiggle to 3,738 stopped it. Gold hit 3,791 within twelve hours of the stop-out and never looked back that week.
**News.** None in window.
**Verdict — (c) mechanics-driven: stop geometry.** The identical ~5.13-pt stop distance that appeared at $1,850 gold (2021–2023) reappears here at $3,748 — it did not scale with price or volatility. A stop equal to 8% of the two-day range is spread-level noise, and the sizing engine converts that tight stop into maximum lots, so the noise is harvested at maximum dollar cost. The thesis was correct within hours; no stop this narrow could have collected it.

### 2025 #3 — Jul 17, 23:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$473.33 (−1.12R)**

**Facts.** In at 3339.90 (late NY), SL 3333.55 (6.3 pts = 9% of the 48h range), risk $423 = 1.38%. Out Jul 18, 08:58 at the stop, to the tick. Held 10h. MAE 1.0R / MFE 0.68R. Zero partials.
**Price context.** A mid-July consolidation week (3,310–3,377). The trade reached +0.68R overnight, then the London dip printed **exactly** the stop (3,333.55, the low of the entire post-exit window) and reversed. Gold was at 3,438 by Jul 23; TP1 (3355) hit within two sessions.
**News.** Retail sales + jobless claims + Philly Fed Jul 17, 15:30 (tier 2, pre-entry).
**Verdict — (a) logic-correct / market-variance.** Stopped at the absolute low of the move, +0.68R float unbanked, thesis fully validated within days. Right, and mechanically unprotected — the same two-part signature as 2021 #4 and 2023 #3.

### 2025 #4 — Nov 11, 12:00 · Bullish Engulfing (Confirmed) · LONG · A+ — **−$454.41 (−0.98R)**

**Facts.** In at 4141.99 (London), SL 4128.29 (13.7 pts = 9% of a 151-pt 48h range), risk $462 = 1.42%. Out 16:32 at 4128.25. Held 4.5h. MAE 1.0R / MFE 0.34R. Zero partials.
**Price context.** The shutdown-end rally: +142 points in 48 hours into the entry. A NY air-pocket to 4,097 (−45 from entry) took the stop; gold was back above 4,142 within 24h and at 4,245 by Nov 13.
**News.** None in window.
**Verdict — (a) logic-correct / market-variance, with the 2024 #4 caveat.** The trend call was right and quickly proven, but buying after +142/48h with a stop covering 9% of that range is the mania-era version of buying extension with a noise stop: in this tape, −45-point shakeouts inside intact rallies were routine, and the stop guaranteed full participation in each one.

### 2025 #5 — Dec 3, 07:00 · Bullish MA Cross (Confirmed) · LONG · A+ — **−$449.48 (−0.99R)**

**Facts.** In at 4222.45 (Asia), SL 4189.17 (33.3 pts), risk $454 = 1.43%. Out Dec 4, 05:02 at 4190.28. Held 22h. MAE 0.96R / MFE 0.58R. Zero partials.
**Price context.** A choppy consolidation week (4,164–4,265) between the November recovery and the December FOMC. The trade churned 4,187–4,242 for a day, was +0.58R at one point, and stopped in the next Asia session. Gold reached 4,259 by Dec 5 and chopped 4,170–4,259 into the FOMC — the cross had no trend to ride.
**News.** ADP 15:15, ISM Services 17:00 Dec 3; jobless claims Dec 4 (tier 2).
**Verdict — (b) logic-wrong-for-context.** Same failure as April and August 2021: a trend-continuation signal at full A+ size in a data-week range. The 33-pt stop was actually reasonably sized (33% of the 48h range) — the problem wasn't geometry but the absence of a trend, which the TRENDING regime label failed to detect.

---

## 2026 H1 — Blowoff and unwind

The mania climaxed at 5,599 on Jan 29 after a near-vertical January (+238 points in one 48h stretch mid-month), then spent five months unwinding: a −330-point single-day crash leg on Mar 3, a grinding correction through the spring, a 3,959 low on Jun 24, closing the test window (Jun 27) around 4,088, −5.5% YTD. Trading this half-year meant surviving 100–250-point two-day ranges. The book's worst losses split evenly: two exit-ladder/geometry casualties inside correct calls, two shakeout victims in the January–February mania, and one long bought straight into the March crash.

### 2026 #1 — May 19, 07:00 · Bearish Pin Bar · SHORT · A+ — **−$486.73 (−0.86R)**

**Facts.** In at 4545.08 (Asia), SL 4555.67 (10.6 pts = 10% of a 109-pt 48h range), risk $566 = 1.77% of $31,918. TP0 partial banked $36.95 at 08:22. **MFE 1.32R** (low 4,531; TP1 at 4,523.9 missed by 7 pts). Squeezed to 4,559.4 and stopped 10:55 at 4,555.96. Break-even never armed.
**Price context.** A corrective, two-sided May tape (−143 pts/10d). After the stop-out, gold fell to 4,453.6 by the next morning — the short's TP1 passed by 70 points within 24 hours.
**News.** None in window.
**Verdict — (c) mechanics-driven: exit-ladder giveback.** The third and largest of the round-trips: +1.32R of open profit, $37 banked out of $566 risked, stop never moved, then a 28-point squeeze converted a near-target winner into −$487 — one day before the thesis paid in full. Any break-even arm at +1R turns this into a scratch; a 0.5R lock turns it positive.

### 2026 #2 — Feb 10, 05:00 · Bullish Engulfing (Confirmed) · LONG · A+ — **−$475.38 (−0.99R)**

**Facts.** In at 5038.47 (Asia), SL 5012.16 (26.3 pts = 22% of a 122-pt 48h range), risk $483 = 1.42%. Out 07:27 at 5012.09. Held 2.5h. MAE 1.0R / **MFE 0.00R**. Zero partials.
**Price context.** Deep mania: +220 points over ten days, entry after a +46 48h push. The Asia dip to 5,011 stopped it; gold hit 5,119 the next day (entry recovered within 24h), then flushed to 4,878 the day after — a 240-point two-day whipsaw.
**News.** Retail sales Feb 10, 15:30 (tier 2, after exit).
**Verdict — (a) logic-correct / market-variance.** In a tape swinging 240 points in 48 hours, a 26-point stop participates in every rotation. The direction was fine (5,119 next day); the loss is the entry fee the mania charged everyone trading it at this granularity. Sub-verdict: MFE 0.00 again marks a chase entry at a local top.

### 2026 #3 — Jan 21, 06:00 · IC Breakout Long (Consol=2 bars) · LONG · A+ — **−$452.56 (−0.72R)**

**Facts.** In at 4845.15 (Asia), SL 4783.61 (61.5 pts = 25% of a **250-pt** 48h range), risk $633 = 1.91% — the largest dollar risk in the top-40. TP0 partial banked $43.07 at 08:27. Out 21:35 at 4790.11 (runner stopped). Held 15.6h. MAE 0.89R / MFE 0.70R. DayType: DAY_VOLATILE.
**Price context.** The January parabola: +238 points in the 48h before entry, +347 over ten days. The trade rode to 4,888.5 (+0.70R), then the intraday shakeout dropped 130 points to 4,756 and took the stop. Gold regained the entry within 24h and printed **5,598.6 on Jan 29** — 750 points above the entry, eight days later.
**News.** None in window.
**Verdict — (a) logic-correct / market-variance — the most expensive shakeout of the run.** Everything about the read was right, the stop was generously sized by any historical standard, and it still sat inside the mania's intraday shakeout amplitude. This trade is the outer bound of the lesson: in January 2026, *no* fixed initial stop inside 25% of the 2-day range survived, and the exit ladder (TP0 only, no BE, trail never engaged above +0.70R) captured $43 of a 750-point idea.

### 2026 #4 — Apr 22, 04:00 · Bearish Pin Bar · SHORT · A+ — **−$445.20 (−1.00R)**

**Facts.** In at 4740.02 (Asia), **SL 4747.91 — 7.9 pts, 5% of a 165-pt 48h range** — the worst stop-to-noise ratio in the entire selection. Risk $446 = 1.42%. Out after **23 minutes** at 4747.94. MAE 0.96R / MFE 0.5R. Zero partials.
**Price context.** The day after a −107-point crash day inside the spring correction (48h high 4,833, low 4,668). The short sold near the bottom of that move; a V-bounce to 4,758.8 stopped it within the entry hour. Gold then fell to 4,657.8 by Apr 24 — TP1 (4724) passed within two days.
**News.** None in window.
**Verdict — (c) mechanics-driven: stop geometry.** Direction right (again), but an 8-point stop when the market's two-day range is 165 points is not a trade — it's a bet on the next quarter-hour. It reached +0.5R inside its 23 minutes and banked nothing. Fifth appearance of the pattern: pin-bar shorts in Asia with stops an order of magnitude smaller than realized volatility.

### 2026 #5 — Mar 3, 10:00 · Bullish Pin Bar (Confirmed) · LONG · A+ — **−$440.55 (−0.99R)**

**Facts.** In at 5327.83 (Asia), SL 5278.91 (48.9 pts = 31% of the 48h range), risk $444 = 1.33%. Out 11:25 at the stop. Held 1.4h. MAE 1.0R / MFE 0.17R. Zero partials.
**Price context.** Five weeks after the 5,599 top, the tape was a sequence of lower highs. The pin bar bought a bounce at 5,328; ninety minutes later the March 3 crash leg was underway: gold hit **4,996 the same day** — 330 points below the entry — and did not revisit 5,328 in the following week.
**News.** None in window.
**Verdict — (b) logic-wrong-for-context.** The regime engine still said TRENDING/DAY_TREND while the market executed the third down-leg of a post-blowoff distribution. This is 2019 #5 / 2023 #4 at ten times the price: buying single-bar bullish patterns in a crashing regime the classifier cannot name. The stop, decently sized for a trend pullback, was irrelevant — nothing long survived Mar 3.

---

## Cross-year synthesis

### What the 40 losses have in common (facts)

| Signature | Count / measure |
|---|---|
| Quality tier | **40/40 SETUP_A_PLUS** (the max-risk tier: avg 1.2% risk vs 0.6–0.8% for A/B+; risk 1.33–2.0% on these trades) |
| Regime tag at entry | **40/40 TRENDING** (incl. a 5.9-pt two-day range, Jun 2022, and the Mar 2026 crash day) |
| Pattern family | Pin bars 27/40 (14 bearish, 13 bullish), engulfing 7, MA cross 4, IC breakout 2 — 34/40 are one/two-candle patterns |
| Direction | 26 long / 14 short; **all 14 shorts were Asia-session entries** |
| Session | Asia 23, New York 11, London 6 |
| Zero partials | 36/40 (other 4 banked a single $14–$43 TP0 partial) |
| Break-even armed | **0/40** |
| Had ≥0.3R open profit before losing | 18/40 (≥0.5R: 10/40; three trades saw +0.88R, +1.23R, +1.32R) |
| Price returned to the entry level within 72h of exit | **34/40** |
| Median hold | 3.9h (18/40 under 3h; two trades died in 23 minutes) |
| Stop distance vs prior-48h range | median **30%**, mean 37%; six trades ≤10%, worst 5% |
| Identical 5.13–5.14-pt stop distance | **10/40**, spanning 2020–2025 and price levels $1,850 → $3,750 |
| R outcome | 37/40 between −0.72R and −1.16R; one −2.0R (the Dec 2022 FOMC stop-slip — the only material slippage event in 928 positions) |
| Weekend gaps / swap-driven losses | **0/40** (longest hold 23.1h; none held over a weekend) |
| Tier-1/2 USD event within [entry−12h, exit+12h] | 23/40 (58%) — **below** the 74% base rate across all 928 trades; tier-1 specifically: 4/40 |
| Inside a >4% balance-drawdown episode | 24/40 (episodes reconstructed from the journal: ~17% Mar 2021→Feb 2022, ~16% Oct 2023→Jun 2024, ~15% Dec 2022→Mar 2023, ~11% Feb→Jun 2026, among others) |

**Verdict tally:** (a) logic-correct / market-variance **20**, (b) logic-wrong-for-context **12**, (c) mechanics-driven **8**.

**Dollar weight:** these 40 trades lost **$11,175.41** — 17.6% of the book's $63,663.67 gross losses (470 losers), and the equivalent of 52% of the run's final net profit. Their mean loss ($279) is 2.6× the median loser ($109) almost entirely because of *when* they occurred (larger balance) and *what tier* they were (A+ sizing), not because of R-blowouts.

### The three biggest structural lessons (interpretation)

**1. The stop does not know what gold costs.** The book's dominant loss mechanism is a stop that is small relative to the market's routine breathing range: median 30% of the prior two-day range, repeatedly ≤10% in 2025–26, with a literally identical 5.13-pt distance recurring from $1,850 gold to $3,750 gold — behavior consistent with a fixed floor/cap in the stop calculation that never rescaled with price or volatility. The consequence is measured, not hypothetical: **34 of 40 losses saw price back at the entry within 72 hours**, and in at least a dozen the original TP1 was hit within days of the stop-out. The strategy's direction engine is mostly right in these worst losses; the geometry loses the money. And because position size is derived from stop distance, the tightest stops carry the biggest lots — noise is harvested at maximum dollar cost (2025 #2 is the canonical exhibit). The cheapest fix in expectancy terms is not a better signal; it is a volatility-anchored minimum stop (e.g., a floor expressed as a percentile of the trailing 48h range) with size reduced accordingly.

**2. The exit ladder neither banks nor defends.** Zero of the 40 ever armed break-even. Eighteen had at least +0.3R of open profit and gave all of it back; three round-tripped from +0.88R, +1.23R and +1.32R to full or near-full losses while banking $14–$43. Combined with the already-verified ceiling on the winner side (no trade ever locked more than 1.89R), the ladder is asymmetric in the wrong direction: it clips winners early via TP0-sized partials yet leaves losers unprotected at full size until −1R. A break-even arm (or partial lock) somewhere at +0.8R to +1R would, on these 40 alone, have converted three of the worst losses (~$900) into scratches and softened several others — with the usual caveat that the same rule would scratch some eventual winners elsewhere in the book; that trade-off needs a full re-run, not extrapolation from the loss tail.

**3. Losses concentrate exactly where the book is most confident, and the confidence labels are wrong at turning points.** Every one of the 40 was an A+ (max size) trade in a "TRENDING" regime — including trades taken inside a 6-point two-day range (Jun 2022, twice), at the top tick of +94/+142/+238-point verticals (Oct 2024, Nov 2025, Jan 2026), at capitulation lows (Nov 2020), and on the morning of a −330-point crash day (Mar 2026). Twelve of forty verdicts are "logic-wrong-for-context," and nearly all share one shape: single-candle patterns trusted at full size during regime *transitions* — post-blowoff distributions and V-reversals — that the classifier still labels as trend. Add the two duplicated same-idea pairs (Oct 12, 2020 and Jun 6, 2022: four trades, ~$766, no same-direction cluster guard) and the FOMC stop-slip (Dec 14, 2022: the only −2R in 7.5 years, ~$180 of it pure through-the-stop slippage with the news filter off). Notably, the news filter is *not* the missing piece the loss tail might suggest: top-loss trades overlap the high-impact calendar *less* than the book's base rate (58% vs 74%), and only one of the 40 was actually killed by a release. The recurring killers are geometry, ladder, and regime mislabeling — in that order.

---

## Verification appendix

Selection universe: 928 positions parsed from the journal (470 losers, 457 winners; journal position PnL +$22,117.61; gross losses $63,663.67). Grouping key: **entry-time calendar year**. Selection: 5 most negative `PnL_Money` per year; 8 years ⇒ 40 rows. The 40 rows sum to **−$11,175.41**. All prices/times as recorded in the journal (server time).

| Year | # | Entry (server) | Pattern | Dir | PnL $ | PnL R | Partials | Hold |
|---|---|---|---|---|---|---|---|---|
| 2019 | 1 | 2019-02-25 17:00 | Bullish Pin Bar (Confirmed) | LONG | −162.18 | −1.08 | 0 | 17.0h |
| 2019 | 2 | 2019-01-07 10:00 | Bullish MA Cross (Confirmed) | LONG | −158.04 | −1.02 | 0 | 18.0h |
| 2019 | 3 | 2019-09-23 18:00 | Bullish Engulfing (Confirmed) | LONG | −153.78 | −1.09 | 0 | 22.7h |
| 2019 | 4 | 2019-07-15 12:00 | Bullish Pin Bar (Confirmed) | LONG | −150.26 | −0.97 | 0 | 5.4h |
| 2019 | 5 | 2019-11-04 09:00 | Bullish Pin Bar (Confirmed) | LONG | −148.72 | −1.00 | 0 | 9.3h |
| 2020 | 1 | 2020-09-07 04:00 | Bearish Pin Bar | SHORT | −201.63 | −0.99 | 0 | 0.4h |
| 2020 | 2 | 2020-10-12 23:00 | Bullish Pin Bar (Confirmed) | LONG | −181.88 | −1.13 | 0 | 5.1h |
| 2020 | 3 | 2020-10-12 18:00 | Bullish Pin Bar (Confirmed) | LONG | −181.30 | −1.12 | 0 | 9.6h |
| 2020 | 4 | 2020-11-30 07:00 | Bearish Pin Bar | SHORT | −171.80 | −0.83 | 1 | 1.8h |
| 2020 | 5 | 2020-04-09 14:00 | Bullish Engulfing (Confirmed) | LONG | −163.68 | −0.99 | 0 | 0.5h |
| 2021 | 1 | 2021-06-16 05:00 | Bearish Pin Bar | SHORT | −242.42 | −1.01 | 0 | 2.4h |
| 2021 | 2 | 2021-04-27 04:00 | Bullish MA Cross (Confirmed) | LONG | −190.71 | −0.97 | 0 | 23.1h |
| 2021 | 3 | 2021-08-31 11:00 | Bullish MA Cross (Confirmed) | LONG | −189.72 | −1.02 | 0 | 4.9h |
| 2021 | 4 | 2021-08-26 09:00 | Bearish Pin Bar | SHORT | −182.88 | −0.84 | 1 | 8.5h |
| 2021 | 5 | 2021-05-18 16:00 | Bullish Pin Bar (Confirmed) | LONG | −178.47 | −1.00 | 0 | 0.9h |
| 2022 | 1 | 2022-12-14 17:00 | Bullish Engulfing (Confirmed) | LONG | −359.84 | −2.00 | 0 | 4.0h |
| 2022 | 2 | 2022-05-18 10:00 | Bearish Pin Bar | SHORT | −210.00 | −1.00 | 0 | 0.5h |
| 2022 | 3 | 2022-06-06 04:00 | Bearish Pin Bar | SHORT | −201.63 | −0.99 | 0 | 2.3h |
| 2022 | 4 | 2022-06-06 03:00 | Bearish Pin Bar | SHORT | −201.24 | −0.99 | 0 | 4.8h |
| 2022 | 5 | 2022-12-12 13:00 | Bullish Engulfing (Confirmed) | LONG | −182.70 | −1.00 | 0 | 3.0h |
| 2023 | 1 | 2023-09-11 06:00 | Bearish Pin Bar | SHORT | −305.03 | −1.01 | 0 | 2.4h |
| 2023 | 2 | 2023-08-09 04:00 | Bearish Pin Bar | SHORT | −263.67 | −1.00 | 0 | 1.8h |
| 2023 | 3 | 2023-06-20 08:00 | Bearish Pin Bar | SHORT | −237.36 | −0.99 | 0 | 2.6h |
| 2023 | 4 | 2023-12-07 16:00 | Bullish Pin Bar (Confirmed) | LONG | −232.56 | −1.06 | 0 | 0.8h |
| 2023 | 5 | 2023-10-24 10:00 | Bullish Pin Bar (Confirmed) | LONG | −225.72 | −0.99 | 0 | 1.7h |
| 2024 | 1 | 2024-08-08 05:00 | Bearish Pin Bar | SHORT | −288.20 | −1.02 | 0 | 1.7h |
| 2024 | 2 | 2024-10-24 21:00 | Bullish Pin Bar (Confirmed) | LONG | −265.72 | −1.05 | 0 | 9.2h |
| 2024 | 3 | 2024-08-01 05:00 | IC Breakout Long (Consol=4 bars) | LONG | −265.33 | −0.99 | 0 | 7.9h |
| 2024 | 4 | 2024-10-23 12:00 | Bullish Engulfing (Confirmed) | LONG | −251.40 | −0.98 | 0 | 3.1h |
| 2024 | 5 | 2024-08-26 20:00 | Bullish Pin Bar (Confirmed) | LONG | −245.32 | −1.07 | 0 | 8.2h |
| 2025 | 1 | 2025-11-05 08:00 | Bearish Pin Bar | SHORT | −596.14 | −1.01 | 0 | 2.1h |
| 2025 | 2 | 2025-09-22 23:00 | Bullish Pin Bar (Confirmed) | LONG | −508.44 | −1.16 | 0 | 2.7h |
| 2025 | 3 | 2025-07-17 23:00 | Bullish Pin Bar (Confirmed) | LONG | −473.33 | −1.12 | 0 | 10.0h |
| 2025 | 4 | 2025-11-11 12:00 | Bullish Engulfing (Confirmed) | LONG | −454.41 | −0.98 | 0 | 4.5h |
| 2025 | 5 | 2025-12-03 07:00 | Bullish MA Cross (Confirmed) | LONG | −449.48 | −0.99 | 0 | 22.0h |
| 2026 | 1 | 2026-05-19 07:00 | Bearish Pin Bar | SHORT | −486.73 | −0.86 | 1 | 3.9h |
| 2026 | 2 | 2026-02-10 05:00 | Bullish Engulfing (Confirmed) | LONG | −475.38 | −0.99 | 0 | 2.5h |
| 2026 | 3 | 2026-01-21 06:00 | IC Breakout Long (Consol=2 bars) | LONG | −452.56 | −0.72 | 1 | 15.6h |
| 2026 | 4 | 2026-04-22 04:00 | Bearish Pin Bar | SHORT | −445.20 | −1.00 | 0 | 0.4h |
| 2026 | 5 | 2026-03-03 10:00 | Bullish Pin Bar (Confirmed) | LONG | −440.55 | −0.99 | 0 | 1.4h |

Supporting numbers quoted in the text (all recomputed from the three source files): 928 positions / 470 losers / 457 winners; avg winner +1.00R / avg loser −0.75R; 46.2% zero-partial overall, 67.4% among losers; max locked trail 1.89R; 4 losers ≤ −1.2R, 1 ≤ −1.5R; tier-1/2 news events parsed: 4,198; news-window base rate 74% (690/928); DST conversion per the second-Sunday-March / first-Sunday-November rule.
