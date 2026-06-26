#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from pathlib import Path


OUT_DIR = Path(__file__).resolve().parent
TRADE_AUDIT = OUT_DIR / "trade_audit_master.csv"


NEGATIVE_EXIT_ISSUES = {
    "trailing_stop_too_tight",
    "premature_exit",
    "breakeven_exit_too_early",
    "take_profit_too_close",
}


def load_rows() -> list[dict[str, str]]:
    with TRADE_AUDIT.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def as_float(value: str | None) -> float:
    if value is None:
        return 0.0
    value = value.strip()
    if value == "":
        return 0.0
    try:
        return float(value)
    except ValueError:
        return 0.0


def pct(part: int, whole: int) -> float:
    if whole <= 0:
        return 0.0
    return 100.0 * part / whole


def mean(values: list[float]) -> float:
    if not values:
        return 0.0
    return sum(values) / len(values)


def money(rows: list[dict[str, str]]) -> float:
    return sum(as_float(row["Total_PnL"]) for row in rows)


def total_r(rows: list[dict[str, str]]) -> float:
    return sum(as_float(row["Total_R"]) for row in rows)


def bad_trade_pct(rows: list[dict[str, str]]) -> float:
    return pct(sum(1 for row in rows if row["Verdict"] != "acceptable_win"), len(rows))


def bad_entry_pct(rows: list[dict[str, str]]) -> float:
    return pct(sum(1 for row in rows if row["EntryGrade"] == "bad"), len(rows))


def bad_exit_pct(rows: list[dict[str, str]]) -> float:
    return pct(sum(1 for row in rows if row["ExitGrade"] == "bad"), len(rows))


def summarize_selector(
    rows: list[dict[str, str]],
    lever: str,
    selector,
    rationale: str,
    code_touchpoint: str,
    confidence: str,
) -> dict[str, object]:
    subset = [row for row in rows if selector(row)]
    patterns = Counter(row["Pattern"] for row in subset)
    sessions = Counter(row["Session"] for row in subset)
    regimes = Counter(row["Regime"] for row in subset)
    return {
        "Lever": lever,
        "Trades": len(subset),
        "PnL_Delta": round(-money(subset), 2),
        "R_Delta": round(-total_r(subset), 2),
        "Removed_PnL": round(money(subset), 2),
        "Removed_R": round(total_r(subset), 2),
        "BadTradePct": round(bad_trade_pct(subset), 1),
        "BadEntryPct": round(bad_entry_pct(subset), 1),
        "BadExitPct": round(bad_exit_pct(subset), 1),
        "TopPatterns": "|".join(f"{name}:{count}" for name, count in patterns.most_common(3)),
        "TopSessions": "|".join(f"{name}:{count}" for name, count in sessions.most_common(3)),
        "TopRegimes": "|".join(f"{name}:{count}" for name, count in regimes.most_common(3)),
        "Rationale": rationale,
        "CodeTouchpoint": code_touchpoint,
        "Confidence": confidence,
    }


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def format_num(value: float) -> str:
    return f"{value:.2f}"


def main() -> None:
    rows = load_rows()
    base_pnl = money(rows)
    base_r = total_r(rows)

    entry_levers = [
        summarize_selector(
            rows,
            "Enable global long-extension filter (block LONG when Prev_72h_Return_Pct >= 1.5)",
            lambda r: r["Direction"] == "LONG" and as_float(r["Prev_72h_Return_Pct"]) >= 1.5,
            "This is the cleanest remaining entry leak. Long continuation entries after a strong 72h surge are net negative across the current sample.",
            "UltimateTrader_Inputs.mqh:213-214 and UltimateTrader.mq5:1402-1417",
            "high",
        ),
        summarize_selector(
            rows,
            "Hard-block countertrend shorts flagged as countertrend_short_vs_recent_uptrend",
            lambda r: r["EntryIssue"] == "countertrend_short_vs_recent_uptrend",
            "The current half-risk treatment is not enough. These shorts still lose heavily, mostly in Rubber Band Short.",
            "Include/Core/CTradeOrchestrator.mqh:347-375",
            "high",
        ),
        summarize_selector(
            rows,
            "Block Bullish MA Cross (Confirmed) at SETUP_B_PLUS",
            lambda r: r["Pattern"] == "Bullish MA Cross (Confirmed)" and r["Quality"] == "SETUP_B_PLUS",
            "Bullish MA Cross still has a weak B+ subset even though the broader pattern is positive.",
            "UltimateTrader_Inputs.mqh:207 and setup thresholds in UltimateTrader_Inputs.mqh:245-249",
            "medium",
        ),
        summarize_selector(
            rows,
            "Block Bullish Pin Bar (Confirmed) in VOLATILE regime",
            lambda r: r["Pattern"] == "Bullish Pin Bar (Confirmed)" and r["Regime"] == "VOLATILE",
            "Bullish Pin Bar remains fragile in volatile conditions even after the runner tightening pass.",
            "Regime scoring and exit profile inputs in UltimateTrader_Inputs.mqh:385-423",
            "medium",
        ),
        summarize_selector(
            rows,
            "Block standard-managed Bullish Pin Bar longs after >=1.5% 72h extension",
            lambda r: (
                r["Pattern"] == "Bullish Pin Bar (Confirmed)"
                and r["Direction"] == "LONG"
                and r["RunnerExitMode"] == "RUNNER_EXIT_STANDARD"
                and as_float(r["Prev_72h_Return_Pct"]) >= 1.5
            ),
            "This is the most toxic surviving Bullish Pin Bar slice. The promoted subset is elite; the standard-managed extended subset is not.",
            "UltimateTrader.mq5:1402-1417 plus runner promotion logic in Include/Core/CPositionCoordinator.mqh:500-582",
            "high",
        ),
    ]
    entry_levers.sort(key=lambda row: float(row["R_Delta"]), reverse=True)

    top_entry_pack_selectors = [
        lambda r: r["Direction"] == "LONG" and as_float(r["Prev_72h_Return_Pct"]) >= 1.5,
        lambda r: r["EntryIssue"] == "countertrend_short_vs_recent_uptrend",
        lambda r: r["Pattern"] == "Bullish MA Cross (Confirmed)" and r["Quality"] == "SETUP_B_PLUS",
    ]
    entry_pack_rows = [
        row
        for row in rows
        if any(selector(row) for selector in top_entry_pack_selectors)
    ]

    strong_exit_rows = [
        row
        for row in rows
        if row["ExitIssue"] in NEGATIVE_EXIT_ISSUES
        and as_float(row["Entry_Favorable_R_24h"]) >= 1.0
        and as_float(row["Entry_Followthrough_24h"]) >= 60.0
        and as_float(row["Exit_Missed_R_24h"]) >= 1.0
    ]

    exit_buckets: list[dict[str, object]] = []
    grouped_exits: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    for row in strong_exit_rows:
        grouped_exits[(row["Pattern"], row["ExitIssue"])].append(row)

    for (pattern, exit_issue), subset in grouped_exits.items():
        missed_r = sum(as_float(row["Exit_Missed_R_24h"]) for row in subset)
        opportunity_money = sum(
            as_float(row["Exit_Missed_R_24h"]) * as_float(row["EntryRiskMoney"])
            for row in subset
        )
        management_modes = Counter(row["ManagementIssue"] for row in subset if row["ManagementIssue"])
        runner_modes = Counter(row["RunnerExitMode"] for row in subset if row["RunnerExitMode"])
        exit_buckets.append(
            {
                "Pattern": pattern,
                "ExitIssue": exit_issue,
                "Trades": len(subset),
                "RealizedPnL": round(money(subset), 2),
                "RealizedR": round(total_r(subset), 2),
                "MissedR24h": round(missed_r, 2),
                "Opportunity24hMoney": round(opportunity_money, 2),
                "Recovery10Pct": round(opportunity_money * 0.10, 2),
                "Recovery15Pct": round(opportunity_money * 0.15, 2),
                "AvgEntryFollowthrough24h": round(mean([as_float(row["Entry_Followthrough_24h"]) for row in subset]), 1),
                "AvgExitScore24h": round(mean([as_float(row["Exit_Score_24h"]) for row in subset]), 1),
                "MainManagementModes": "|".join(f"{name}:{count}" for name, count in management_modes.most_common(3)),
                "MainRunnerModes": "|".join(f"{name}:{count}" for name, count in runner_modes.most_common(3)),
            }
        )
    exit_buckets.sort(key=lambda row: float(row["Opportunity24hMoney"]), reverse=True)

    management_exit_rows: list[dict[str, object]] = []
    management_groups: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        if row["ExitIssue"] in NEGATIVE_EXIT_ISSUES:
            management_groups[(row["ManagementIssue"], row["ExitIssue"])].append(row)

    for (management_issue, exit_issue), subset in management_groups.items():
        management_exit_rows.append(
            {
                "ManagementIssue": management_issue,
                "ExitIssue": exit_issue,
                "Trades": len(subset),
                "RealizedPnL": round(money(subset), 2),
                "RealizedR": round(total_r(subset), 2),
                "MissedR24h": round(sum(as_float(row["Exit_Missed_R_24h"]) for row in subset), 2),
                "AvgExitScore24h": round(mean([as_float(row["Exit_Score_24h"]) for row in subset]), 1),
            }
        )
    management_exit_rows.sort(key=lambda row: float(row["MissedR24h"]), reverse=True)

    pattern_runner_rows: list[dict[str, object]] = []
    for pattern in {
        "Bullish Pin Bar (Confirmed)",
        "Bullish Engulfing (Confirmed)",
        "Bullish MA Cross (Confirmed)",
        "Bearish Pin Bar",
    }:
        subset = [row for row in rows if row["Pattern"] == pattern]
        by_runner: dict[str, list[dict[str, str]]] = defaultdict(list)
        for row in subset:
            by_runner[row["RunnerExitMode"]].append(row)
        for runner_mode, runner_subset in by_runner.items():
            pattern_runner_rows.append(
                {
                    "Pattern": pattern,
                    "RunnerExitMode": runner_mode,
                    "Trades": len(runner_subset),
                    "PnL": round(money(runner_subset), 2),
                    "TotalR": round(total_r(runner_subset), 2),
                    "BadTradePct": round(bad_trade_pct(runner_subset), 1),
                    "AvgMissedR24h": round(mean([as_float(row["Exit_Missed_R_24h"]) for row in runner_subset]), 2),
                    "AvgFollowthrough24h": round(mean([as_float(row["Entry_Followthrough_24h"]) for row in runner_subset]), 1),
                }
            )
    pattern_runner_rows.sort(key=lambda row: (row["Pattern"], row["RunnerExitMode"]))

    top_exit_5 = exit_buckets[:5]
    top_exit_5_money = sum(float(row["Opportunity24hMoney"]) for row in top_exit_5)

    scenario_rows = [
        {
            "Scenario": "Entry Pack A: extension filter + countertrend-short block + BMACross B+ block",
            "Type": "entry",
            "TradesAffected": len(entry_pack_rows),
            "ModeledPnLUplift": round(-money(entry_pack_rows), 2),
            "ModeledRUplift": round(-total_r(entry_pack_rows), 2),
            "Assumption": "Remove the three highest-confidence toxic entry slices.",
        },
        {
            "Scenario": "Exit Pack A: recover 10% of top-5 strong bad-exit buckets",
            "Type": "exit",
            "TradesAffected": sum(int(row["Trades"]) for row in top_exit_5),
            "ModeledPnLUplift": round(top_exit_5_money * 0.10, 2),
            "ModeledRUplift": 0.0,
            "Assumption": "Improve BE/trailing/TP handling only enough to recover 10% of the measured missed-move pool.",
        },
        {
            "Scenario": "Exit Pack B: recover 15% of top-5 strong bad-exit buckets",
            "Type": "exit",
            "TradesAffected": sum(int(row["Trades"]) for row in top_exit_5),
            "ModeledPnLUplift": round(top_exit_5_money * 0.15, 2),
            "ModeledRUplift": 0.0,
            "Assumption": "Same as Exit Pack A, but with a stronger management improvement.",
        },
        {
            "Scenario": "Combined A: Entry Pack A + Exit Pack A",
            "Type": "combined",
            "TradesAffected": len(entry_pack_rows) + sum(int(row["Trades"]) for row in top_exit_5),
            "ModeledPnLUplift": round(-money(entry_pack_rows) + top_exit_5_money * 0.10, 2),
            "ModeledRUplift": round(-total_r(entry_pack_rows), 2),
            "Assumption": "Highest-confidence entry cleanup plus modest exit recovery.",
        },
        {
            "Scenario": "Combined B: Entry Pack A + Exit Pack B",
            "Type": "combined",
            "TradesAffected": len(entry_pack_rows) + sum(int(row["Trades"]) for row in top_exit_5),
            "ModeledPnLUplift": round(-money(entry_pack_rows) + top_exit_5_money * 0.15, 2),
            "ModeledRUplift": round(-total_r(entry_pack_rows), 2),
            "Assumption": "Highest-confidence entry cleanup plus stronger exit recovery.",
        },
    ]

    summary = {
        "base_pnl": round(base_pnl, 2),
        "base_r": round(base_r, 2),
        "trades": len(rows),
        "top_entry_pack_pnl_uplift": round(-money(entry_pack_rows), 2),
        "top_entry_pack_r_uplift": round(-total_r(entry_pack_rows), 2),
        "top_exit_5_money_pool": round(top_exit_5_money, 2),
        "top_exit_5_recovery_10pct": round(top_exit_5_money * 0.10, 2),
        "top_exit_5_recovery_15pct": round(top_exit_5_money * 0.15, 2),
    }

    write_csv(OUT_DIR / "major_entry_levers.csv", entry_levers)
    write_csv(OUT_DIR / "major_exit_levers.csv", exit_buckets)
    write_csv(OUT_DIR / "major_management_exit_levers.csv", management_exit_rows)
    write_csv(OUT_DIR / "major_pattern_runner_split.csv", pattern_runner_rows)
    write_csv(OUT_DIR / "major_combined_scenarios.csv", scenario_rows)
    with (OUT_DIR / "major_profitability_summary.json").open("w", encoding="utf-8") as handle:
        json.dump(
            {
                "summary": summary,
                "entry_levers": entry_levers,
                "exit_buckets": exit_buckets,
                "management_exit_buckets": management_exit_rows,
                "pattern_runner_split": pattern_runner_rows,
                "scenarios": scenario_rows,
            },
            handle,
            indent=2,
        )

    management_none_rows = [row for row in rows if row["ManagementIssue"] == "none"]
    management_none_entry_issues = Counter(
        row["EntryIssue"] for row in management_none_rows if row["EntryIssue"] and row["EntryIssue"] != "mixed"
    )

    lines: list[str] = []
    lines.append("# Major Profitability Analysis")
    lines.append("")
    lines.append(
        f"Base detailed-sample performance is `{format_num(base_pnl)}` across `{len(rows)}` closed trades, or `{format_num(base_r)}`R."
    )
    lines.append("")
    lines.append("## Main Read")
    lines.append("")
    lines.append(
        f"- The biggest theoretical lever is still exit capture on already-good trades. The top five strong bad-exit buckets hold `{format_num(top_exit_5_money)}` of measured 24h missed-move value."
    )
    lines.append(
        f"- The highest-confidence immediate lever is entry cleanup, not broader risk or looser trailing. Entry Pack A alone models `+{format_num(-money(entry_pack_rows))}` and `+{format_num(-total_r(entry_pack_rows))}R`."
    )
    lines.append(
        "- The current code comment that the 72h long-extension filter is a no-op is outdated. The current trade audit shows the opposite."
    )
    lines.append(
        "- Bullish Pin Bar is not uniformly bad. The promoted subset is strong, but the standard-managed extended subset is still a major drag."
    )
    lines.append("")
    lines.append("## Ranked Entry Levers")
    lines.append("")
    for row in entry_levers:
        lines.append(
            f"- {row['Lever']}: `{row['Trades']}` trades, modeled uplift `+{format_num(float(row['PnL_Delta']))}` and `+{format_num(float(row['R_Delta']))}R`, bad-trade rate `{format_num(float(row['BadTradePct']))}%`. Touchpoint: `{row['CodeTouchpoint']}`."
        )
    lines.append("")
    lines.append("## Ranked Exit Levers")
    lines.append("")
    for row in top_exit_5:
        lines.append(
            f"- {row['Pattern']} / {row['ExitIssue']}: `{row['Trades']}` trades, `{format_num(float(row['Opportunity24hMoney']))}` measured missed-move value, `10%` recovery = `+{format_num(float(row['Recovery10Pct']))}`, `15%` recovery = `+{format_num(float(row['Recovery15Pct']))}`."
        )
    lines.append("")
    lines.append("## Key Design Clues")
    lines.append("")

    bpb_standard = next(
        (
            row
            for row in pattern_runner_rows
            if row["Pattern"] == "Bullish Pin Bar (Confirmed)" and row["RunnerExitMode"] == "RUNNER_EXIT_STANDARD"
        ),
        None,
    )
    bpb_promoted = next(
        (
            row
            for row in pattern_runner_rows
            if row["Pattern"] == "Bullish Pin Bar (Confirmed)" and row["RunnerExitMode"] == "RUNNER_EXIT_PROMOTED"
        ),
        None,
    )
    if bpb_standard and bpb_promoted:
        lines.append(
            f"- Bullish Pin Bar split: standard-managed = `{bpb_standard['Trades']}` trades for `{format_num(float(bpb_standard['TotalR']))}R`; promoted = `{bpb_promoted['Trades']}` trades for `{format_num(float(bpb_promoted['TotalR']))}R`. The problem is not the whole pattern. It is the weak subset."
        )

    lines.append(
        f"- `ManagementIssue=none` is still slightly negative at `{format_num(money(management_none_rows))}`. The top remaining entry drags inside that bucket are `{', '.join(f'{name}:{count}' for name, count in management_none_entry_issues.most_common(3))}`."
    )
    lines.append(
        "- Countertrend short losses are still making it through despite risk reduction. That means the next fix should be blocking or re-qualifying them, not just sizing them down."
    )
    lines.append("")
    lines.append("## Implementation Order")
    lines.append("")
    lines.append(
        "- Phase 1: enable the 72h long-extension filter and remove the stale no-op comment in `UltimateTrader_Inputs.mqh:213-214` and `UltimateTrader.mq5:1402-1417`."
    )
    lines.append(
        "- Phase 2: hard-block `countertrend_short_vs_recent_uptrend` instead of only halving risk in `Include/Core/CTradeOrchestrator.mqh:347-375`."
    )
    lines.append(
        "- Phase 3: tighten Bullish MA Cross B+ qualification and optionally suppress Bullish Pin Bar in VOLATILE regimes."
    )
    lines.append(
        "- Phase 4: retune exit capture for strong trend trades. The primary knobs are the regime exit profile and TP0/TP1/TP2 volumes in `UltimateTrader_Inputs.mqh:387-447`, plus BE/trailing behavior in `Include/Core/CPositionCoordinator.mqh:1621-1809` and `Include/Core/CPositionCoordinator.mqh:2328-2425`."
    )
    lines.append(
        "- Phase 5: keep runner promotion selective. The data supports promoted runners; it does not support broad relaxed management on standard trades."
    )
    lines.append("")
    lines.append("## Best Current Package")
    lines.append("")
    for row in scenario_rows:
        lines.append(
            f"- {row['Scenario']}: modeled uplift `+{format_num(float(row['ModeledPnLUplift']))}`. {row['Assumption']}"
        )

    with (OUT_DIR / "major_profitability_analysis.md").open("w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")

    print(f"Wrote {OUT_DIR / 'major_profitability_analysis.md'}")
    print(f"Wrote {OUT_DIR / 'major_entry_levers.csv'}")
    print(f"Wrote {OUT_DIR / 'major_exit_levers.csv'}")
    print(f"Wrote {OUT_DIR / 'major_management_exit_levers.csv'}")
    print(f"Wrote {OUT_DIR / 'major_pattern_runner_split.csv'}")
    print(f"Wrote {OUT_DIR / 'major_combined_scenarios.csv'}")
    print(f"Wrote {OUT_DIR / 'major_profitability_summary.json'}")


if __name__ == "__main__":
    main()
