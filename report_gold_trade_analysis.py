#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import math
import re
from bisect import bisect_right
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable

from lxml import html


REPORT_DIR = Path("reports")
PRICE_FILE = Path("GoldHistory/XAU_15m_data.csv")
OUT_DIR = REPORT_DIR / "analysis"

REPORT_DT_FMT = "%Y.%m.%d %H:%M:%S"
BAR_DT_FMT = "%Y.%m.%d %H:%M"

LOOKAHEADS = {
    "4h": timedelta(hours=4),
    "24h": timedelta(hours=24),
}
TP_LEVELS_R = {
    "tp0": 0.7,
    "tp1": 1.3,
    "tp2": 1.8,
}


@dataclass(frozen=True)
class Bar:
    dt: datetime
    open: float
    high: float
    low: float
    close: float


def clean_text(value: object) -> str:
    return " ".join(str(value or "").replace("\xa0", " ").split())


def parse_float(value: str) -> float | None:
    value = clean_text(value)
    if not value:
        return None
    value = value.replace(" ", "").replace("%", "")
    try:
        return float(value)
    except ValueError:
        return None


def mean(values: Iterable[float]) -> float | None:
    items = list(values)
    if not items:
        return None
    return sum(items) / len(items)


def pct(part: int, whole: int) -> float | None:
    if whole == 0:
        return None
    return 100.0 * part / whole


def score_bucket(score: float | None) -> str:
    if score is None:
        return "na"
    if score >= 60.0:
        return "good"
    if score <= 40.0:
        return "bad"
    return "neutral"


def normalize_signal(comment: str) -> str:
    comment = clean_text(comment)
    comment = re.sub(r" \| Swept .*", "", comment)
    comment = re.sub(r" \(Consol=.*", "", comment)
    comment = re.sub(r" \(Squeeze=.*", "", comment)
    return comment


def read_html_rows(path: Path) -> list[list[str]]:
    text = path.read_text(encoding="utf-16")
    doc = html.fromstring(text)
    return [
        [clean_text("".join(cell.itertext())) for cell in tr.xpath("./th|./td")]
        for tr in doc.xpath("//tr")
    ]


def find_row(rows: list[list[str]], needle: str, exact: bool = False) -> int | None:
    for idx, row in enumerate(rows):
        if exact:
            if row == [needle]:
                return idx
        else:
            if any(needle in cell for cell in row):
                return idx
    return None


def parse_summary(rows: list[list[str]]) -> dict[str, str]:
    start = find_row(rows, "Bars:")
    end = find_row(rows, "Orders")
    if start is None or end is None:
        return {}
    summary: dict[str, str] = {}
    for row in rows[start:end]:
        for idx, cell in enumerate(row[:-1]):
            if cell.endswith(":"):
                summary[cell[:-1]] = row[idx + 1]
    return summary


def parse_inputs(rows: list[list[str]]) -> dict[str, str]:
    start = find_row(rows, "Inputs:")
    end = find_row(rows, "Bars:")
    values: dict[str, str] = {}
    if start is None or end is None:
        return values
    for row in rows[start:end]:
        for cell in row:
            if "=" in cell and not cell.endswith(":"):
                key, val = cell.split("=", 1)
                values[key] = val
    return values


def parse_orders(rows: list[list[str]]) -> list[dict[str, str]]:
    header_idx = None
    for idx, row in enumerate(rows):
        if row[:4] == ["Open Time", "Order", "Symbol", "Type"]:
            header_idx = idx
            break
    deals_idx = find_row(rows, "Deals", exact=True)
    if header_idx is None or deals_idx is None:
        return []

    header = rows[header_idx]
    orders: list[dict[str, str]] = []
    for row in rows[header_idx + 1 : deals_idx]:
        if len(row) != len(header):
            continue
        if not row[0] or not re.match(r"^\d{4}\.\d{2}\.\d{2} ", row[0]):
            continue
        orders.append(dict(zip(header, row)))
    return orders


def parse_deals(rows: list[list[str]]) -> list[dict[str, str]]:
    header_idx = find_row(rows, "Direction")
    if header_idx is None:
        return []
    header = rows[header_idx]
    deals: list[dict[str, str]] = []
    for row in rows[header_idx + 1 :]:
        if len(row) != len(header):
            if deals:
                break
            continue
        if row[0] and re.match(r"^\d{4}\.\d{2}\.\d{2} ", row[0]):
            deals.append(dict(zip(header, row)))
    return deals


def parse_meta(rows: list[list[str]]) -> dict[str, str]:
    values: dict[str, str] = {}
    for label in ("Expert:", "Symbol:", "Period:"):
        idx = find_row(rows, label)
        if idx is None:
            continue
        row = rows[idx]
        for pos, cell in enumerate(row[:-1]):
            if cell == label:
                values[label[:-1]] = row[pos + 1]
                break
    return values


def classify_exit_reason(comment: str) -> str:
    comment = clean_text(comment)
    low = comment.lower()
    if low.startswith("sl"):
        return "sl"
    if low.startswith("tp"):
        return "tp"
    if low.startswith("end of test"):
        return "end_of_test"
    if not comment:
        return "blank"
    return comment


def load_price_bars(path: Path, year_min: int, year_max: int) -> tuple[list[datetime], list[Bar], dict[int, tuple[int, int]]]:
    keep_from = datetime(year_min, 1, 1) - timedelta(days=2)
    keep_to = datetime(year_max + 1, 1, 2)

    times: list[datetime] = []
    bars: list[Bar] = []
    ranges: dict[int, list[int]] = defaultdict(list)

    with path.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter=";")
        for row in reader:
            dt = datetime.strptime(row["Date"], BAR_DT_FMT)
            if dt < keep_from:
                continue
            if dt > keep_to:
                break
            bar = Bar(
                dt=dt,
                open=float(row["Open"]),
                high=float(row["High"]),
                low=float(row["Low"]),
                close=float(row["Close"]),
            )
            idx = len(bars)
            bars.append(bar)
            times.append(dt)
            ranges[dt.year].append(idx)

    year_ranges: dict[int, tuple[int, int]] = {}
    for year, indexes in ranges.items():
        if indexes:
            year_ranges[year] = (indexes[0], indexes[-1] + 1)
    return times, bars, year_ranges


def future_window_indices(times: list[datetime], event_dt: datetime, horizon: timedelta) -> tuple[int, int]:
    start = bisect_right(times, event_dt)
    end = bisect_right(times, event_dt + horizon)
    return start, end


def evaluate_entry_window(
    side: str,
    entry_price: float,
    sl_price: float | None,
    bars: list[Bar],
) -> dict[str, float | bool | None]:
    if not bars:
        return {
            "favorable": None,
            "adverse": None,
            "timing_score": None,
            "followthrough_score": None,
            "favorable_r": None,
            "adverse_r": None,
            "tp0_hit": None,
            "tp1_hit": None,
            "tp2_hit": None,
        }

    future_high = max(bar.high for bar in bars)
    future_low = min(bar.low for bar in bars)
    total_range = future_high - future_low

    if side == "buy":
        favorable = max(0.0, future_high - entry_price)
        adverse = max(0.0, entry_price - future_low)
        timing_score = 50.0 if total_range <= 0 else 100.0 * (future_high - entry_price) / total_range
    else:
        favorable = max(0.0, entry_price - future_low)
        adverse = max(0.0, future_high - entry_price)
        timing_score = 50.0 if total_range <= 0 else 100.0 * (entry_price - future_low) / total_range

    combined = favorable + adverse
    followthrough_score = 50.0 if combined <= 0 else 100.0 * favorable / combined

    risk = None
    favorable_r = None
    adverse_r = None
    tp_hits = {"tp0_hit": None, "tp1_hit": None, "tp2_hit": None}
    if sl_price is not None:
        risk = abs(entry_price - sl_price)
        if risk > 0:
            favorable_r = favorable / risk
            adverse_r = adverse / risk
            for key, threshold in TP_LEVELS_R.items():
                tp_hits[f"{key}_hit"] = favorable >= threshold * risk

    return {
        "favorable": favorable,
        "adverse": adverse,
        "timing_score": timing_score,
        "followthrough_score": followthrough_score,
        "favorable_r": favorable_r,
        "adverse_r": adverse_r,
        **tp_hits,
    }


def evaluate_exit_window(
    trade_side: str,
    exit_price: float,
    bars: list[Bar],
) -> dict[str, float | None]:
    if not bars:
        return {
            "missed_move": None,
            "protected_move": None,
            "exit_score": None,
        }

    future_high = max(bar.high for bar in bars)
    future_low = min(bar.low for bar in bars)

    if trade_side == "buy":
        missed = max(0.0, future_high - exit_price)
        protected = max(0.0, exit_price - future_low)
    else:
        missed = max(0.0, exit_price - future_low)
        protected = max(0.0, future_high - exit_price)

    total = missed + protected
    score = 50.0 if total <= 0 else 100.0 * protected / total

    return {
        "missed_move": missed,
        "protected_move": protected,
        "exit_score": score,
    }


def annual_market_stats(bars: list[Bar]) -> dict[str, float]:
    opens = [bar.open for bar in bars]
    highs = [bar.high for bar in bars]
    lows = [bar.low for bar in bars]
    closes = [bar.close for bar in bars]

    year_open = opens[0]
    year_close = closes[-1]
    abs_walk = sum(abs(closes[idx] - closes[idx - 1]) for idx in range(1, len(closes)))
    returns = [(closes[idx] / closes[idx - 1]) - 1.0 for idx in range(1, len(closes))]
    ret_mean = sum(returns) / len(returns)
    ret_var = sum((ret - ret_mean) ** 2 for ret in returns) / len(returns)

    return {
        "year_open": year_open,
        "year_close": year_close,
        "return_pct": 100.0 * (year_close - year_open) / year_open,
        "high": max(highs),
        "low": min(lows),
        "range_pct": 100.0 * (max(highs) - min(lows)) / year_open,
        "trend_efficiency": abs(year_close - year_open) / abs_walk if abs_walk else 0.0,
        "ann_vol_pct": math.sqrt(ret_var) * math.sqrt(252 * 24 * 4) * 100.0,
    }


def summarize_scores(items: list[dict[str, object]], key: str) -> dict[str, float | int | None]:
    values = [float(item[key]) for item in items if item.get(key) is not None]
    good = sum(1 for value in values if value >= 60.0)
    bad = sum(1 for value in values if value <= 40.0)
    neutral = len(values) - good - bad
    return {
        "avg": mean(values),
        "count": len(values),
        "good_pct": pct(good, len(values)),
        "neutral_pct": pct(neutral, len(values)),
        "bad_pct": pct(bad, len(values)),
    }


def report_numeric(summary: dict[str, str], key: str) -> float | None:
    value = summary.get(key)
    return parse_float(value) if value is not None else None


def build_markdown(summary_rows: list[dict[str, object]]) -> str:
    lines: list[str] = []
    lines.append("# Gold vs Report Trade Analysis")
    lines.append("")
    lines.append("Source data:")
    lines.append("- MT5 HTML reports from `reports/`")
    lines.append("- Gold price history from `GoldHistory/XAU_15m_data.csv`")
    lines.append("")
    lines.append("Method notes:")
    lines.append("- MT5 `Total Trades` in these reports maps to closed trade events / exit events, not unique entry positions.")
    lines.append("- Entry evaluation uses the next full 15-minute bar after entry and measures 4h / 24h forward quality.")
    lines.append("- Exit evaluation uses the next full 15-minute bar after exit and measures whether the exit protected against reversal or left further favorable move on the table.")
    lines.append("- TP0/TP1/TP2 hit flags are forward price-path checks against the entry SL-defined risk distance inside the 24h window. They do not infer within-bar sequencing.")
    lines.append("")
    lines.append(
        "| Year | Gold Return | Gold Range | EA Net | PF | DD | Entry 24h | TP1 24h | TP2 24h | Exit 24h | SL Exit 24h | TP Exit 24h | Blank Exit 24h |"
    )
    lines.append(
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
    )

    for row in summary_rows:
        report = row["report"]
        market = row["market"]
        entry = row["entry"]
        exit_stats = row["exit"]
        exit_reason = row["exit_reason_breakdown"]

        def avg_reason(reason: str) -> str:
            info = exit_reason.get(reason)
            if not info or info["avg_exit_score_24h"] is None:
                return "n/a"
            return f"{info['avg_exit_score_24h']:.1f}"

        lines.append(
            "| {year} | {gold_return:.2f}% | {gold_range:.2f}% | {net:.2f} | {pf:.2f} | {dd:.2f}% | {entry24:.1f} | {tp1:.1f}% | {tp2:.1f}% | {exit24:.1f} | {sl24} | {tp24} | {blank24} |".format(
                year=row["year"],
                gold_return=market["return_pct"],
                gold_range=market["range_pct"],
                net=report["net_profit"],
                pf=report["profit_factor"],
                dd=report["drawdown_rel_pct"],
                entry24=entry["avg_followthrough_24h"],
                tp1=entry["tp1_hit_24h_pct"],
                tp2=entry["tp2_hit_24h_pct"],
                exit24=exit_stats["avg_exit_score_24h"],
                sl24=avg_reason("sl"),
                tp24=avg_reason("tp"),
                blank24=avg_reason("blank"),
            )
        )

    lines.append("")
    lines.append("## Per-Year Notes")
    lines.append("")
    for row in summary_rows:
        market = row["market"]
        entry = row["entry"]
        exit_stats = row["exit"]
        exit_reason = row["exit_reason_breakdown"]
        signals = row["top_signals"]
        bullish = row["signal_bias"]["bullish_or_long"]
        bearish = row["signal_bias"]["bearish_or_short"]

        lines.append(f"### {row['year']}")
        lines.append(
            "- Gold regime: return {0:.2f}%, range {1:.2f}%, annualized 15m volatility {2:.2f}%, trend efficiency {3:.3f}.".format(
                market["return_pct"],
                market["range_pct"],
                market["ann_vol_pct"],
                market["trend_efficiency"],
            )
        )
        lines.append(
            "- EA result: net {0:.2f}, profit factor {1:.2f}, drawdown {2:.2f}%.".format(
                row["report"]["net_profit"],
                row["report"]["profit_factor"],
                row["report"]["drawdown_rel_pct"],
            )
        )
        lines.append(
            "- Entries: avg 24h timing {0:.1f}, avg 24h follow-through {1:.1f}, TP0/TP1/TP2 hit in 24h = {2:.1f}% / {3:.1f}% / {4:.1f}%.".format(
                entry["avg_timing_24h"],
                entry["avg_followthrough_24h"],
                entry["tp0_hit_24h_pct"],
                entry["tp1_hit_24h_pct"],
                entry["tp2_hit_24h_pct"],
            )
        )
        lines.append(
            "- Exits: avg 24h exit score {0:.1f}; SL {1}, TP {2}, blank {3}.".format(
                exit_stats["avg_exit_score_24h"],
                "n/a" if exit_reason.get("sl", {}).get("avg_exit_score_24h") is None else f"{exit_reason['sl']['avg_exit_score_24h']:.1f}",
                "n/a" if exit_reason.get("tp", {}).get("avg_exit_score_24h") is None else f"{exit_reason['tp']['avg_exit_score_24h']:.1f}",
                "n/a" if exit_reason.get("blank", {}).get("avg_exit_score_24h") is None else f"{exit_reason['blank']['avg_exit_score_24h']:.1f}",
            )
        )
        lines.append(
            f"- Signal bias: bullish/long-pattern entries {bullish}, bearish/short-pattern entries {bearish}."
        )
        lines.append(
            "- Most common signals: " + ", ".join(
                f"{item['signal']} ({item['count']})" for item in signals[:5]
            ) + "."
        )
        lines.append("")

    return "\n".join(lines)


def main() -> None:
    report_paths = sorted(REPORT_DIR.glob("ReportTester-*.html"))
    years = [int(re.search(r"(\d{4})", path.name).group(1)) for path in report_paths]
    if not report_paths:
        raise SystemExit("No report HTML files found in reports/")
    if not PRICE_FILE.exists():
        raise SystemExit(f"Missing price file: {PRICE_FILE}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    bar_times, bars, year_ranges = load_price_bars(PRICE_FILE, min(years), max(years))

    summary_rows: list[dict[str, object]] = []
    entry_rows: list[dict[str, object]] = []
    exit_rows: list[dict[str, object]] = []

    for path in report_paths:
        year = int(re.search(r"(\d{4})", path.name).group(1))
        rows = read_html_rows(path)
        meta = parse_meta(rows)
        summary = parse_summary(rows)
        inputs = parse_inputs(rows)
        orders = parse_orders(rows)
        deals = parse_deals(rows)

        order_by_id = {item["Order"]: item for item in orders}
        deal_by_order = {
            item["Order"]: item
            for item in deals
            if item.get("Order") and item["Type"] != "balance"
        }

        if year not in year_ranges:
            raise SystemExit(f"No price bars loaded for year {year}")
        market_bars = bars[year_ranges[year][0] : year_ranges[year][1]]
        market = annual_market_stats(market_bars)

        year_entry_rows: list[dict[str, object]] = []
        year_exit_rows: list[dict[str, object]] = []
        signal_bias = Counter()

        for order_id, order in order_by_id.items():
            deal = deal_by_order.get(order_id)
            if deal is None:
                continue

            order_time = datetime.strptime(order["Time"], REPORT_DT_FMT)
            order_type = order["Type"]
            volume = parse_float(deal["Volume"])
            price = parse_float(deal["Price"])
            commission = parse_float(deal["Commission"]) or 0.0
            swap = parse_float(deal["Swap"]) or 0.0
            profit = parse_float(deal["Profit"]) or 0.0
            net_profit = profit + commission + swap
            comment = clean_text(order["Comment"])

            if deal["Direction"] == "in":
                signal = normalize_signal(comment)
                low_comment = signal.lower()
                if "bullish" in low_comment or " long" in low_comment or low_comment.endswith(" long"):
                    signal_bias["bullish_or_long"] += 1
                elif "bearish" in low_comment or " short" in low_comment or low_comment.endswith(" short"):
                    signal_bias["bearish_or_short"] += 1
                else:
                    signal_bias["other"] += 1

                sl_price = parse_float(order["S / L"])
                tp_price = parse_float(order["T / P"])
                entry_record: dict[str, object] = {
                    "year": year,
                    "report_file": path.name,
                    "order_id": order_id,
                    "time": order_time.strftime(REPORT_DT_FMT),
                    "side": order_type,
                    "signal": signal,
                    "volume": volume,
                    "entry_price": price,
                    "sl_price": sl_price,
                    "tp_price": tp_price,
                }
                for label, horizon in LOOKAHEADS.items():
                    start, end = future_window_indices(bar_times, order_time, horizon)
                    metrics = evaluate_entry_window(order_type, price, sl_price, bars[start:end])
                    for key, value in metrics.items():
                        entry_record[f"{key}_{label}"] = value
                year_entry_rows.append(entry_record)
                entry_rows.append(entry_record)
            elif deal["Direction"] == "out":
                trade_side = "buy" if order_type == "sell" else "sell"
                reason = classify_exit_reason(comment)
                exit_record: dict[str, object] = {
                    "year": year,
                    "report_file": path.name,
                    "order_id": order_id,
                    "time": order_time.strftime(REPORT_DT_FMT),
                    "exit_order_type": order_type,
                    "trade_side": trade_side,
                    "reason": reason,
                    "volume": volume,
                    "exit_price": price,
                    "profit": profit,
                    "commission": commission,
                    "swap": swap,
                    "net_profit": net_profit,
                }
                for label, horizon in LOOKAHEADS.items():
                    start, end = future_window_indices(bar_times, order_time, horizon)
                    metrics = evaluate_exit_window(trade_side, price, bars[start:end])
                    for key, value in metrics.items():
                        exit_record[f"{key}_{label}"] = value
                year_exit_rows.append(exit_record)
                exit_rows.append(exit_record)

        by_signal: dict[str, list[dict[str, object]]] = defaultdict(list)
        for item in year_entry_rows:
            by_signal[str(item["signal"])].append(item)

        top_signals: list[dict[str, object]] = []
        for signal, items in sorted(by_signal.items(), key=lambda kv: len(kv[1]), reverse=True)[:10]:
            top_signals.append(
                {
                    "signal": signal,
                    "count": len(items),
                    "avg_timing_24h": mean(
                        float(row["timing_score_24h"])
                        for row in items
                        if row["timing_score_24h"] is not None
                    ),
                    "avg_followthrough_24h": mean(
                        float(row["followthrough_score_24h"])
                        for row in items
                        if row["followthrough_score_24h"] is not None
                    ),
                    "avg_favorable_r_24h": mean(
                        float(row["favorable_r_24h"])
                        for row in items
                        if row["favorable_r_24h"] is not None
                    ),
                    "avg_adverse_r_24h": mean(
                        float(row["adverse_r_24h"])
                        for row in items
                        if row["adverse_r_24h"] is not None
                    ),
                    "tp1_hit_24h_pct": pct(
                        sum(1 for row in items if row["tp1_hit_24h"] is True),
                        sum(1 for row in items if row["tp1_hit_24h"] is not None),
                    ),
                    "tp2_hit_24h_pct": pct(
                        sum(1 for row in items if row["tp2_hit_24h"] is True),
                        sum(1 for row in items if row["tp2_hit_24h"] is not None),
                    ),
                }
            )

        exit_reason_breakdown: dict[str, dict[str, object]] = {}
        by_reason: dict[str, list[dict[str, object]]] = defaultdict(list)
        for item in year_exit_rows:
            by_reason[str(item["reason"])].append(item)
        for reason, items in by_reason.items():
            exit_reason_breakdown[reason] = {
                "count": len(items),
                "avg_exit_score_4h": mean(
                    float(row["exit_score_4h"])
                    for row in items
                    if row["exit_score_4h"] is not None
                ),
                "avg_exit_score_24h": mean(
                    float(row["exit_score_24h"])
                    for row in items
                    if row["exit_score_24h"] is not None
                ),
                "avg_missed_24h": mean(
                    float(row["missed_move_24h"])
                    for row in items
                    if row["missed_move_24h"] is not None
                ),
                "avg_protected_24h": mean(
                    float(row["protected_move_24h"])
                    for row in items
                    if row["protected_move_24h"] is not None
                ),
                "good_pct_24h": pct(
                    sum(
                        1
                        for row in items
                        if row["exit_score_24h"] is not None and float(row["exit_score_24h"]) >= 60.0
                    ),
                    sum(1 for row in items if row["exit_score_24h"] is not None),
                ),
            }

        summary_rows.append(
            {
                "year": year,
                "meta": meta,
                "inputs_subset": {
                    key: inputs.get(key)
                    for key in (
                        "InpMaxRiskPerTrade",
                        "InpMaxTotalExposure",
                        "InpDailyLossLimit",
                        "InpEnableTP0",
                        "InpTP0Distance",
                        "InpTP0Volume",
                        "InpTP1Distance",
                        "InpTP1Volume",
                        "InpTP2Distance",
                        "InpTP2Volume",
                        "InpEnableAntiStall",
                        "InpEnableRegimeExit",
                    )
                },
                "market": market,
                "report": {
                    "net_profit": report_numeric(summary, "Total Net Profit"),
                    "profit_factor": report_numeric(summary, "Profit Factor"),
                    "expected_payoff": report_numeric(summary, "Expected Payoff"),
                    "recovery_factor": report_numeric(summary, "Recovery Factor"),
                    "sharpe_ratio": report_numeric(summary, "Sharpe Ratio"),
                    "drawdown_rel_pct": parse_float(summary.get("Balance Drawdown Relative", "").split("%", 1)[0]),
                    "gross_profit": report_numeric(summary, "Gross Profit"),
                    "gross_loss": report_numeric(summary, "Gross Loss"),
                    "total_trades": int(parse_float(summary.get("Total Trades", "0")) or 0),
                    "profit_trades_text": summary.get("Profit Trades (% of total)"),
                    "long_trades_text": summary.get("Long Trades (won %)"),
                    "short_trades_text": summary.get("Short Trades (won %)"),
                    "avg_hold_time": summary.get("Average position holding time"),
                    "max_hold_time": summary.get("Maximal position holding time"),
                    "entry_orders": len(year_entry_rows),
                    "exit_events": len(year_exit_rows),
                },
                "entry": {
                    "count": len(year_entry_rows),
                    "avg_timing_4h": mean(
                        float(row["timing_score_4h"])
                        for row in year_entry_rows
                        if row["timing_score_4h"] is not None
                    ),
                    "avg_timing_24h": mean(
                        float(row["timing_score_24h"])
                        for row in year_entry_rows
                        if row["timing_score_24h"] is not None
                    ),
                    "avg_followthrough_4h": mean(
                        float(row["followthrough_score_4h"])
                        for row in year_entry_rows
                        if row["followthrough_score_4h"] is not None
                    ),
                    "avg_followthrough_24h": mean(
                        float(row["followthrough_score_24h"])
                        for row in year_entry_rows
                        if row["followthrough_score_24h"] is not None
                    ),
                    "avg_favorable_r_24h": mean(
                        float(row["favorable_r_24h"])
                        for row in year_entry_rows
                        if row["favorable_r_24h"] is not None
                    ),
                    "avg_adverse_r_24h": mean(
                        float(row["adverse_r_24h"])
                        for row in year_entry_rows
                        if row["adverse_r_24h"] is not None
                    ),
                    "tp0_hit_24h_pct": pct(
                        sum(1 for row in year_entry_rows if row["tp0_hit_24h"] is True),
                        sum(1 for row in year_entry_rows if row["tp0_hit_24h"] is not None),
                    ),
                    "tp1_hit_24h_pct": pct(
                        sum(1 for row in year_entry_rows if row["tp1_hit_24h"] is True),
                        sum(1 for row in year_entry_rows if row["tp1_hit_24h"] is not None),
                    ),
                    "tp2_hit_24h_pct": pct(
                        sum(1 for row in year_entry_rows if row["tp2_hit_24h"] is True),
                        sum(1 for row in year_entry_rows if row["tp2_hit_24h"] is not None),
                    ),
                    "good_followthrough_24h_pct": pct(
                        sum(
                            1
                            for row in year_entry_rows
                            if row["followthrough_score_24h"] is not None
                            and float(row["followthrough_score_24h"]) >= 60.0
                        ),
                        sum(1 for row in year_entry_rows if row["followthrough_score_24h"] is not None),
                    ),
                },
                "exit": {
                    "count": len(year_exit_rows),
                    "avg_exit_score_4h": mean(
                        float(row["exit_score_4h"])
                        for row in year_exit_rows
                        if row["exit_score_4h"] is not None
                    ),
                    "avg_exit_score_24h": mean(
                        float(row["exit_score_24h"])
                        for row in year_exit_rows
                        if row["exit_score_24h"] is not None
                    ),
                    "avg_missed_24h": mean(
                        float(row["missed_move_24h"])
                        for row in year_exit_rows
                        if row["missed_move_24h"] is not None
                    ),
                    "avg_protected_24h": mean(
                        float(row["protected_move_24h"])
                        for row in year_exit_rows
                        if row["protected_move_24h"] is not None
                    ),
                    "good_exit_24h_pct": pct(
                        sum(
                            1
                            for row in year_exit_rows
                            if row["exit_score_24h"] is not None
                            and float(row["exit_score_24h"]) >= 60.0
                        ),
                        sum(1 for row in year_exit_rows if row["exit_score_24h"] is not None),
                    ),
                },
                "signal_bias": {
                    "bullish_or_long": signal_bias.get("bullish_or_long", 0),
                    "bearish_or_short": signal_bias.get("bearish_or_short", 0),
                    "other": signal_bias.get("other", 0),
                },
                "top_signals": top_signals,
                "exit_reason_breakdown": exit_reason_breakdown,
            }
        )

    summary_rows.sort(key=lambda item: int(item["year"]))

    with (OUT_DIR / "year_market_trade_summary.json").open("w") as handle:
        json.dump(summary_rows, handle, indent=2)

    with (OUT_DIR / "year_market_trade_summary.md").open("w") as handle:
        handle.write(build_markdown(summary_rows))

    if entry_rows:
        entry_fields = list(entry_rows[0].keys())
        with (OUT_DIR / "entries_detailed.csv").open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=entry_fields)
            writer.writeheader()
            writer.writerows(entry_rows)

    if exit_rows:
        exit_fields = list(exit_rows[0].keys())
        with (OUT_DIR / "exits_detailed.csv").open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=exit_fields)
            writer.writeheader()
            writer.writerows(exit_rows)

    print(f"Wrote {OUT_DIR / 'year_market_trade_summary.json'}")
    print(f"Wrote {OUT_DIR / 'year_market_trade_summary.md'}")
    print(f"Wrote {OUT_DIR / 'entries_detailed.csv'}")
    print(f"Wrote {OUT_DIR / 'exits_detailed.csv'}")


if __name__ == "__main__":
    main()
