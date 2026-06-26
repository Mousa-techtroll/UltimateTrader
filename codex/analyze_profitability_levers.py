#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from pathlib import Path


OUT_DIR = Path(__file__).resolve().parent
TRADE_AUDIT = OUT_DIR / "trade_audit_master.csv"


def mean(values: list[float]) -> float | None:
    if not values:
        return None
    return sum(values) / len(values)


def fmt_num(value: float | None, digits: int = 2) -> str:
    if value is None:
        return "n/a"
    return f"{value:.{digits}f}"


def fmt_pct(value: float | None, digits: int = 1) -> str:
    if value is None:
        return "n/a"
    return f"{value:.{digits}f}%"


def pct(part: int, whole: int) -> float | None:
    if whole <= 0:
        return None
    return 100.0 * part / whole


def load_rows() -> list[dict[str, str]]:
    with TRADE_AUDIT.open() as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    rows = load_rows()
    base_pnl = sum(float(row["Total_PnL"] or 0.0) for row in rows)

    scenarios = [
        {
            "Scenario": "Disable Bearish Pin Bar outside Asia",
            "Category": "entry_filter",
            "selector": lambda r: r["Pattern"] == "Bearish Pin Bar" and r["Session"] != "ASIA",
            "Rationale": "Bearish Pin Bar is strongly positive in Asia and materially negative in London/NewYork.",
        },
        {
            "Scenario": "Disable Bullish MA Cross in NewYork",
            "Category": "entry_filter",
            "selector": lambda r: r["Pattern"] == "Bullish MA Cross (Confirmed)" and r["Session"] == "NEWYORK",
            "Rationale": "Bullish MA Cross is consistently better in Asia/London than NewYork.",
        },
        {
            "Scenario": "Disable Rubber Band Short B+",
            "Category": "entry_filter",
            "selector": lambda r: r["Pattern"] == "Rubber Band Short (Death Cross)" and r["Quality"] == "SETUP_B_PLUS",
            "Rationale": "Rubber Band Short loses money in B+ quality; A/A+ are the profitable subsets.",
        },
        {
            "Scenario": "Disable Bullish Pin Bar outside TRENDING regime",
            "Category": "entry_filter",
            "selector": lambda r: r["Pattern"] == "Bullish Pin Bar (Confirmed)" and r["Regime"] != "TRENDING",
            "Rationale": "Bullish Pin Bar is positive in trending conditions and negative outside them.",
        },
        {
            "Scenario": "Disable longs after >1.5% 72h rise",
            "Category": "entry_filter",
            "selector": lambda r: (
                r["Direction"] == "LONG"
                and r["Prev_72h_Return_Pct"]
                and float(r["Prev_72h_Return_Pct"]) > 1.5
            ),
            "Rationale": "The current long book loses money when entering after very strong 72h upside extension.",
        },
    ]

    scenario_rows: list[dict[str, object]] = []
    for scenario in scenarios:
        cut = [row for row in rows if scenario["selector"](row)]
        removed_pnl = sum(float(row["Total_PnL"] or 0.0) for row in cut)
        scenario_rows.append(
            {
                "Scenario": scenario["Scenario"],
                "Category": scenario["Category"],
                "TradesRemoved": len(cut),
                "RemovedPnL": round(removed_pnl, 2),
                "NewPnL": round(base_pnl - removed_pnl, 2),
                "Delta": round(-removed_pnl, 2),
                "Rationale": scenario["Rationale"],
            }
        )

    combined_entry_rows = [
        row
        for row in rows
        if any(
            scenario["selector"](row)
            for scenario in scenarios[:4]
        )
    ]
    combined_removed_pnl = sum(float(row["Total_PnL"] or 0.0) for row in combined_entry_rows)
    scenario_rows.append(
        {
            "Scenario": "Combined robust entry filters",
            "Category": "entry_filter_combo",
            "TradesRemoved": len(combined_entry_rows),
            "RemovedPnL": round(combined_removed_pnl, 2),
            "NewPnL": round(base_pnl - combined_removed_pnl, 2),
            "Delta": round(-combined_removed_pnl, 2),
            "Rationale": "Combines the four most robust pattern/session/regime filters.",
        }
    )

    exit_issue_set = {
        "trailing_stop_too_tight",
        "premature_exit",
        "breakeven_exit_too_early",
        "take_profit_too_close",
    }
    strong_exit_opportunity = 0.0
    strong_exit_count = 0
    for row in rows:
        ef = row["Entry_Followthrough_24h"]
        missed_r = row["Exit_Missed_R_24h"]
        risk_money = row["EntryRiskMoney"]
        if (
            row["ExitIssue"] in exit_issue_set
            and ef
            and missed_r
            and risk_money
            and float(ef) >= 60.0
        ):
            strong_exit_opportunity += float(missed_r) * float(risk_money)
            strong_exit_count += 1

    for fraction in (0.10, 0.15, 0.20, 0.25):
        delta = strong_exit_opportunity * fraction
        scenario_rows.append(
            {
                "Scenario": f"Recover {int(fraction * 100)}% of strong-trade missed move",
                "Category": "exit_management",
                "TradesRemoved": strong_exit_count,
                "RemovedPnL": 0.0,
                "NewPnL": round(base_pnl + delta, 2),
                "Delta": round(delta, 2),
                "Rationale": "Only applies to strong-followthrough trades currently cut by trailing/BE/TP exits.",
            }
        )

    pattern_rows: list[dict[str, object]] = []
    top_patterns = [
        "Bearish Pin Bar",
        "Bullish Engulfing (Confirmed)",
        "Bullish Pin Bar (Confirmed)",
        "Rubber Band Short (Death Cross)",
        "Bullish MA Cross (Confirmed)",
    ]
    for pattern in top_patterns:
        subset = [row for row in rows if row["Pattern"] == pattern]
        for dimension in ("Session", "Quality", "Regime"):
            buckets: dict[str, list[dict[str, str]]] = defaultdict(list)
            for row in subset:
                buckets[row[dimension]].append(row)
            for bucket, bucket_rows in buckets.items():
                pattern_rows.append(
                    {
                        "Pattern": pattern,
                        "Dimension": dimension,
                        "Bucket": bucket,
                        "Trades": len(bucket_rows),
                        "NetPnL": round(sum(float(row["Total_PnL"] or 0.0) for row in bucket_rows), 2),
                        "AvgPnL": round(sum(float(row["Total_PnL"] or 0.0) for row in bucket_rows) / len(bucket_rows), 2),
                        "WinRatePct": round(
                            100.0 * sum(1 for row in bucket_rows if row["Result"] == "WIN") / len(bucket_rows),
                            1,
                        ),
                        "BadEntryPct": round(
                            100.0 * sum(1 for row in bucket_rows if row["EntryGrade"] == "bad") / len(bucket_rows),
                            1,
                        ),
                        "BadExitPct": round(
                            100.0 * sum(1 for row in bucket_rows if row["ExitGrade"] == "bad") / len(bucket_rows),
                            1,
                        ),
                    }
                )

    exit_rows: list[dict[str, object]] = []
    by_pattern: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        by_pattern[row["Pattern"]].append(row)
    for pattern, subset in sorted(by_pattern.items(), key=lambda item: len(item[1]), reverse=True):
        if len(subset) < 20:
            continue
        strong_bad = [
            row
            for row in subset
            if row["ExitIssue"] in exit_issue_set
            and row["Entry_Followthrough_24h"]
            and float(row["Entry_Followthrough_24h"]) >= 60.0
            and row["Exit_Missed_R_24h"]
            and row["EntryRiskMoney"]
        ]
        if not strong_bad:
            continue
        opportunity = sum(float(row["Exit_Missed_R_24h"]) * float(row["EntryRiskMoney"]) for row in strong_bad)
        exit_rows.append(
            {
                "Pattern": pattern,
                "StrongBadExitTrades": len(strong_bad),
                "Opportunity24hMoney": round(opportunity, 2),
                "RealizedPnLOnThoseTrades": round(sum(float(row["Total_PnL"] or 0.0) for row in strong_bad), 2),
                "AvgMissedR24h": round(mean([float(row["Exit_Missed_R_24h"]) for row in strong_bad]), 2),
                "MainExitIssues": "|".join(
                    f"{issue}:{count}"
                    for issue, count in Counter(row["ExitIssue"] for row in strong_bad).most_common(4)
                ),
            }
        )

    exit_rows.sort(key=lambda row: float(row["Opportunity24hMoney"]), reverse=True)

    with (OUT_DIR / "profitability_levers.json").open("w") as handle:
        json.dump(
            {
                "base_pnl": round(base_pnl, 2),
                "scenario_rows": scenario_rows,
                "pattern_rows": pattern_rows,
                "exit_rows": exit_rows,
            },
            handle,
            indent=2,
        )

    write_csv(OUT_DIR / "profitability_scenarios.csv", scenario_rows)
    write_csv(OUT_DIR / "pattern_filter_map.csv", pattern_rows)
    write_csv(OUT_DIR / "exit_opportunity_map.csv", exit_rows)

    lines: list[str] = []
    lines.append("# Profitability Improvement Plan")
    lines.append("")
    lines.append(f"Base detailed-sample PnL: `{fmt_num(base_pnl)}` across `{len(rows)}` closed trades.")
    lines.append("")
    lines.append("## Highest-Impact Levers")
    lines.append("")
    lines.append("### 1. Entry Filters")
    lines.append("")
    for row in [item for item in scenario_rows if item["Category"] in {"entry_filter", "entry_filter_combo"}]:
        lines.append(
            f"- {row['Scenario']}: remove `{row['TradesRemoved']}` trades, improve PnL by `{fmt_num(float(row['Delta']))}`. {row['Rationale']}"
        )
    lines.append("")
    lines.append("### 2. Exit Management")
    lines.append("")
    lines.append(
        f"- Strong-trade exit opportunity pool: `{strong_exit_count}` trades with `{fmt_num(strong_exit_opportunity)}` of 24h missed-move value."
    )
    for row in [item for item in scenario_rows if item["Category"] == "exit_management"]:
        lines.append(
            f"- {row['Scenario']}: estimated uplift `{fmt_num(float(row['Delta']))}`, taking sample PnL to `{fmt_num(float(row['NewPnL']))}`."
        )
    lines.append("")
    lines.append("## Pattern-Level Filters")
    lines.append("")
    lines.append("- `Bearish Pin Bar`: keep Asia; London and NewYork are the main drag.")
    lines.append("- `Bullish MA Cross`: avoid NewYork unless re-qualified with stronger filters.")
    lines.append("- `Rubber Band Short`: keep A/A+ only; B+ is net negative.")
    lines.append("- `Bullish Pin Bar`: require `TRENDING` regime; non-trending subsets are negative.")
    lines.append("- Long continuation trades are vulnerable when the previous 72h rise already exceeds `1.5%`; add an extension filter or require a pullback before entry.")
    lines.append("")
    lines.append("## Exit Priorities")
    lines.append("")
    for row in exit_rows[:8]:
        lines.append(
            f"- {row['Pattern']}: `{row['StrongBadExitTrades']}` strong trades are leaving `{fmt_num(float(row['Opportunity24hMoney']))}` on the table. Main issues: `{row['MainExitIssues']}`."
        )
    lines.append("")
    lines.append("## Implementation Order")
    lines.append("")
    lines.append("- Phase 1: apply the robust entry filters first. They are the cleanest, lowest-risk gains.")
    lines.append("- Phase 2: loosen trend exit handling for strong-followthrough trades, especially trailing and breakeven logic.")
    lines.append("- Phase 3: rebalance risk toward the best long continuation subsets instead of increasing global risk.")

    with (OUT_DIR / "profitability_improvement_plan.md").open("w") as handle:
        handle.write("\n".join(lines) + "\n")

    print(f"Wrote {OUT_DIR / 'profitability_improvement_plan.md'}")
    print(f"Wrote {OUT_DIR / 'profitability_scenarios.csv'}")
    print(f"Wrote {OUT_DIR / 'pattern_filter_map.csv'}")
    print(f"Wrote {OUT_DIR / 'exit_opportunity_map.csv'}")
    print(f"Wrote {OUT_DIR / 'profitability_levers.json'}")


if __name__ == "__main__":
    main()
