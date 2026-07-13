# Gold v2 · Candidate D · Phase-1 — abnormal-move FADE vs CONTINUATION
Honest ref = signal-bar close. cleanWR = P(favorable 0.5ATR before adverse 0.5ATR within horizon). FADE advances only if it clearly beats CONTINUE and is positive, both feeds, news-excluded, both directions, era-stable.

GoldHistory detected UTC offset = +3h (abnormal-move/tier1-news coincidence 8.8% of 1221 moves; a clean spike vs neighbors = news really drives abnormal moves).

## k = 3× ATR abnormal move
  GoldHistory M15 (H=16=4h)  all moves
    FADE             n=2513  cleanWR= 34.5%  MFE=3.59 MAE=3.86 edge=-0.271  retr50=63.9%
    CONTINUE         n=2513  cleanWR= 29.0%  MFE=3.86 MAE=3.59 edge=+0.271  retr50=63.9%
      -> continue wins/again fade  (fade edge -0.271 vs cont edge +0.271)
  GoldHistory M15 (H=16=4h)  NEWS-EXCLUDED
    FADE             n=2357  cleanWR= 34.7%  MFE=3.57 MAE=3.89 edge=-0.322  retr50=63.6%
    CONTINUE         n=2357  cleanWR= 29.4%  MFE=3.89 MAE=3.57 edge=+0.322  retr50=63.6%
      -> continue wins/again fade  (fade edge -0.322 vs cont edge +0.322)
  Vantage H1 (H=4=4h)  all moves
    FADE             n= 252  cleanWR= 29.4%  MFE=1.80 MAE=1.99 edge=-0.187  retr50=37.7%
    CONTINUE         n= 252  cleanWR= 32.5%  MFE=1.99 MAE=1.80 edge=+0.187  retr50=37.7%
      -> continue wins/again fade  (fade edge -0.187 vs cont edge +0.187)
  Vantage H1 (H=4=4h)  NEWS-EXCLUDED
    FADE             n= 148  cleanWR= 31.1%  MFE=1.70 MAE=1.97 edge=-0.267  retr50=36.5%
    CONTINUE         n= 148  cleanWR= 36.5%  MFE=1.97 MAE=1.70 edge=+0.267  retr50=36.5%
      -> continue wins/again fade  (fade edge -0.267 vs cont edge +0.267)

## k = 4× ATR abnormal move
  GoldHistory M15 (H=16=4h)  all moves
    FADE             n= 608  cleanWR= 34.9%  MFE=3.85 MAE=3.91 edge=-0.058  retr50=59.0%
    CONTINUE         n= 608  cleanWR= 22.9%  MFE=3.91 MAE=3.85 edge=+0.058  retr50=59.0%
      -> continue wins/again fade  (fade edge -0.058 vs cont edge +0.058)
  GoldHistory M15 (H=16=4h)  NEWS-EXCLUDED
    FADE             n= 568  cleanWR= 35.4%  MFE=3.88 MAE=3.92 edge=-0.038  retr50=59.7%
    CONTINUE         n= 568  cleanWR= 22.9%  MFE=3.92 MAE=3.88 edge=+0.038  retr50=59.7%
      -> continue wins/again fade  (fade edge -0.038 vs cont edge +0.038)
  Vantage H1 (H=4=4h)  all moves
    FADE             n=  56  cleanWR= 32.1%  MFE=2.30 MAE=2.06 edge=+0.241  retr50=39.3%
    CONTINUE         n=  56  cleanWR= 21.4%  MFE=2.06 MAE=2.30 edge=-0.241  retr50=39.3%
      -> FADE>cont  (fade edge +0.241 vs cont edge -0.241)
  Vantage H1 (H=4=4h)  NEWS-EXCLUDED
    FADE             n=  30  cleanWR= 26.7%  MFE=2.22 MAE=2.08 edge=+0.145  retr50=36.7%
    CONTINUE         n=  30  cleanWR= 23.3%  MFE=2.08 MAE=2.22 edge=-0.145  retr50=36.7%
      -> FADE>cont  (fade edge +0.145 vs cont edge -0.145)

## k = 5× ATR abnormal move
  GoldHistory M15 (H=16=4h)  all moves
    FADE             n=  63  cleanWR= 28.6%  MFE=3.49 MAE=5.00 edge=-1.504  retr50=49.2%
    CONTINUE         n=  63  cleanWR= 19.0%  MFE=5.00 MAE=3.49 edge=+1.504  retr50=49.2%
      -> continue wins/again fade  (fade edge -1.504 vs cont edge +1.504)
  GoldHistory M15 (H=16=4h)  NEWS-EXCLUDED
    FADE             n=  56  cleanWR= 28.6%  MFE=3.67 MAE=5.07 edge=-1.399  retr50=53.6%
    CONTINUE         n=  56  cleanWR= 21.4%  MFE=5.07 MAE=3.67 edge=+1.399  retr50=53.6%
      -> continue wins/again fade  (fade edge -1.399 vs cont edge +1.399)
  Vantage H1 (H=4=4h)  all moves
    FADE             (n<20)
    CONTINUE         (n<20)
  Vantage H1 (H=4=4h)  NEWS-EXCLUDED
    FADE             (n<20)
    CONTINUE         (n<20)

## Direction & era split (k=4, NEWS-EXCLUDED, GoldHistory M15)
  fade UP-moves (short): n= 275  cleanWR= 37.1%  MFE=3.69 MAE=4.10 edge=-0.410  retr50=55.3%
      pre-2016  n= 181  cleanWR= 42.5%  MFE=4.11 MAE=4.38 edge=-0.275  retr50=56.9%
      2016+     n=  94  cleanWR= 26.6%  MFE=2.90 MAE=3.57 edge=-0.670  retr50=52.1%
  fade DOWN-moves (long): n= 293  cleanWR= 33.8%  MFE=4.06 MAE=3.75 edge=+0.310  retr50=63.8%
      pre-2016  n= 206  cleanWR= 38.3%  MFE=4.15 MAE=3.93 edge=+0.220  retr50=62.6%
      2016+     n=  87  cleanWR= 23.0%  MFE=3.83 MAE=3.31 edge=+0.524  retr50=66.7%
