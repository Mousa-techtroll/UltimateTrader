# Activation-hardening tracker (on main)

The capability platform is merged into main **default-off** (architectural inclusion). The items below are the
remaining broker-fidelity / true-netting / persistence improvements required BEFORE any research policy is
economically **activated** in production. They do NOT gate inclusion — the default-off architecture stays on main
regardless. Each is off-path while `InpResearchLabEnable=false` (the shipped config), so none affects the current
baseline. Close them per-policy as part of that policy's forward-validation → activation path.

## Broker fidelity
- **BF-1 — direct SL-modify confirmation for TIGHTEN.** Today `ResolveExitAction` for a tighten infers "applied"
  from the position's resulting stop reaching the proposed R after `ApplyTrailingPlugins` (a faithful heuristic).
  Activation should confirm from the actual SL-modify send result for the policy-sourced stop (thread a
  policy-origin flag through the `t==-2` send and confirm on `OrderSend`/retcode).
- **BF-2 — deal-ID-bound CLOSE confirmation.** CLOSE_ALL is marked PENDING on a truthy `ClosePosition` and
  reconciled via `HandleClosedPosition`; a fully `DEAL_POSITION_ID`-bound close confirmation (match the closing
  deal to the ticket) would remove reliance on the settle-retry path for the research stamp.
- **BF-3 — decouple research TIGHTEN from `InpExitPolicyActive`.** A research tighten only reaches the broker when
  `InpExitPolicyActive` is on (`policy_sl_proposal` consumed at `t==-2`). Activation of a research exit that uses
  TIGHTEN must either own its own send path or require that gate explicitly.

## True netting
- **TN-1 — volume-delta lifecycle under netting merges.** The stamp is keyed by ticket; on a true-netting account
  a partial/close is a volume delta, and `ReconcileNettingFill` resyncs `remaining_lots`. Harden the interaction
  so `partial_done`/confirmations map to the reconciled netting volume, not a per-ticket assumption.
- **TN-2 — hedging-mode multi-ticket coverage.** Confirm the confirm-gated flow under hedging (independent tickets
  already unit-tested for state independence; needs a live/hedging integration pass before activation).

## Persistence
- **PN-1 — live-restart reconcile for ALL outstanding action types.** The seam reconcile currently confirms an
  outstanding PENDING/UNKNOWN **partial** against deal history; extend to close/tighten/trail on restart (the
  stamp already carries `pending_action`/`pending_since` for this).
- **PN-2 — real live-restart round-trip.** The hardened schema-v2 sidecar (magic/CRC/identity/atomic) is verified
  synthetically (save→restore→foreign-magic-reject in `UT_ResearchPolicies`); exercise it under an actual
  terminal restart with open positions before activation.
- **PN-3 — multi-symbol / portfolio persistence.** The sidecar is per-symbol (`UltTrader_ResearchStamps_<sym>.bin`);
  a portfolio activation needs a per-symbol-per-magic namespacing review.

## Governance
These are ACTIVATION-hardening tasks, not inclusion blockers. The default-off capability architecture lives on
main now; each item is closed on the path to activating a specific policy, governed by economic evidence
(FORWARD_SHADOW_PREREGISTRATION.md) — never used to keep the architecture separated from main.
