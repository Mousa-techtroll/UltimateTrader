> ⚠️ **PRELIMINARY — superseded by the executable test** (`candidate-F-executable-FROZEN.md` + `gh_candidateF_exec.py`). This Phase-1 screen used +3 fixed TZ, no CIs, and an ATR-edge (not net R). The +0.038 ATR below is a price movement, not a tradeable expectancy. See the executable study for the adopt/close decision.

# Gold v2 · Candidate F · Phase-1 — compression -> failed-expansion FADE vs breakout CONTINUATION
Honest fill: fade entry = close of the confirmed return-inside bar. FADE advances only if it beats re-break/continuation and is positive, both feeds, news-excluded, both directions, era-stable.

## GoldHistory M15  (fresh compression-breakouts=8906, failed=5781 = 65%)
  Breakout base rate (from breakout close): does the breakout CONTINUE?
    CONT U           n=4596  cleanWR= 41.1%  edge=+0.044
    (fade U)         n=4596  cleanWR= 58.9%  edge=-0.044
    CONT D           n=4310  cleanWR= 37.5%  edge=-0.007
    (fade D)         n=4310  cleanWR= 62.5%  edge=+0.007
  Failed-breakout FADE (from confirmed return-inside close) vs RE-BREAK:
    FADE U-brk       n=2923  cleanWR= 41.9%  edge=+0.061
    REBRK U-brk      n=2923  cleanWR= 44.2%  edge=-0.061
        -> FADE>rebreak
    FADE D-brk       n=2858  cleanWR= 42.5%  edge=+0.014
    REBRK D-brk      n=2858  cleanWR= 44.8%  edge=-0.014
        -> FADE>rebreak
    FADE all         n=5781  cleanWR= 42.2%  edge=+0.038
      pre-2016  n=2858  cleanWR= 42.1%  edge=+0.032
      2016+     n=2923  cleanWR= 42.3%  edge=+0.044

## Vantage H1  (fresh compression-breakouts=4532, failed=2446 = 54%)
  Breakout base rate (from breakout close): does the breakout CONTINUE?
    CONT U           n=2469  cleanWR= 45.4%  edge=+0.025
    (fade U)         n=2469  cleanWR= 54.6%  edge=-0.025
    CONT D           n=2063  cleanWR= 42.4%  edge=-0.001
    (fade D)         n=2063  cleanWR= 57.6%  edge=+0.001
  Failed-breakout FADE (from confirmed return-inside close) vs RE-BREAK:
    FADE U-brk       n=1287  cleanWR= 43.6%  edge=+0.049
    REBRK U-brk      n=1287  cleanWR= 43.3%  edge=-0.049
        -> FADE>rebreak
    FADE D-brk       n=1159  cleanWR= 44.0%  edge=-0.083
    REBRK D-brk      n=1159  cleanWR= 44.5%  edge=+0.083
        -> rebreak/continuation wins
    FADE all         n=2446  cleanWR= 43.8%  edge=-0.014
      2016+     n=2446  cleanWR= 43.8%  edge=-0.014
