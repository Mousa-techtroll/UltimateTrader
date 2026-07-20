# Risk-profile candidate: PinBar-TREND-A @ SETUP_A ×0.5 risk-downgrade — REJECTED (cross-feed)
Isolated portfolio-risk candidate (NOT an L4-1 bug fix). InpCohortDowngrade + subtype=7 + tier=SETUP_A + mult=0.5.
Evaluated on return/DD, PF, Sharpe, cross-feed portability, year stability (NOT net).
- PRIMARY: $30,841 (−5.4%) / PF 1.47→1.50 / Sharpe 3.13→3.17 / EqDD 11.32→9.98% (−12%). Risk-IMPROVING.
- GOLDHISTORY: $21,010 (−12.8%) / PF 1.39→1.38 / Sharpe 2.99→**2.87** / closed-DD −11%. Does NOT preserve
  PF/Sharpe; net degrades disproportionately; 2023 flips +$834→−$170.
VERDICT: fails the owner's cross-feed bar ("GH must preserve/improve PF/Sharpe without disproportionate net
degradation") — primary-feed-specific, like closed-bar ATR. NOT adopted. Lever kept flag-off (byte-identical).
Production stays baseline-codex-seven-32617 / c051f97b / $32,617.90.
