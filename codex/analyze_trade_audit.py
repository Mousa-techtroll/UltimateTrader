#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import math
import re
from bisect import bisect_right
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Iterable

from lxml import html


ROOT_DIR = Path(__file__).resolve().parent.parent
OUT_DIR = Path(__file__).resolve().parent
REPORT_DIR = ROOT_DIR / "reports"
LOG_DIR = ROOT_DIR / "Logs"
PRICE_1M_FILE = ROOT_DIR / "GoldHistory" / "XAU_1m_data.csv"
PRICE_15M_FILE = ROOT_DIR / "GoldHistory" / "XAU_15m_data.csv"

LOG_YEARS = [2020, 2021, 2022, 2023, 2024, 2025]
REPORT_YEARS = [2019, 2020, 2021, 2022, 2023, 2024, 2025]

REPORT_DT_FMT = "%Y.%m.%d %H:%M:%S"

SECONDS_1H = 3600
SECONDS_4H = 4 * SECONDS_1H
SECONDS_24H = 24 * SECONDS_1H
SECONDS_48H = 48 * SECONDS_1H
SECONDS_72H = 72 * SECONDS_1H


@dataclass(frozen=True)
class ReportSummary:
    year: int
    net_profit: float | None
    profit_factor: float | None
    expected_payoff: float | None
    sharpe_ratio: float | None
    drawdown_rel_pct: float | None
    total_trades: int | None
    profit_trades_text: str
    long_trades_text: str
    short_trades_text: str
    avg_hold_time: str
    max_hold_time: str


def clean_text(value: object) -> str:
    return " ".join(str(value or "").replace("\xa0", " ").split())


def parse_float(value: object) -> float | None:
    text = clean_text(value).replace("%", "").replace(" ", "")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def parse_int(value: object) -> int | None:
    text = clean_text(value)
    if not text:
        return None
    try:
        return int(float(text))
    except ValueError:
        return None


def mean(values: Iterable[float]) -> float | None:
    items = [float(value) for value in values]
    if not items:
        return None
    return sum(items) / len(items)


def pct(part: int, whole: int) -> float | None:
    if whole <= 0:
        return None
    return 100.0 * part / whole


def fmt_num(value: float | None, digits: int = 2) -> str:
    if value is None:
        return "n/a"
    return f"{value:.{digits}f}"


def fmt_pct(value: float | None, digits: int = 1) -> str:
    if value is None:
        return "n/a"
    return f"{value:.{digits}f}%"


def parse_dt_seconds(text: str, cache: dict[str, int]) -> int:
    day_key = text[:10]
    ordinal = cache.get(day_key)
    if ordinal is None:
        year = int(day_key[0:4])
        month = int(day_key[5:7])
        day = int(day_key[8:10])
        ordinal = date(year, month, day).toordinal()
        cache[day_key] = ordinal
    hour = int(text[11:13])
    minute = int(text[14:16])
    second = int(text[17:19]) if len(text) >= 19 else 0
    return ordinal * 86400 + hour * 3600 + minute * 60 + second


def parse_bar_ts(text: str, cache: dict[str, int]) -> int:
    day_key = text[:10]
    ordinal = cache.get(day_key)
    if ordinal is None:
        year = int(day_key[0:4])
        month = int(day_key[5:7])
        day = int(day_key[8:10])
        ordinal = date(year, month, day).toordinal()
        cache[day_key] = ordinal
    hour = int(text[11:13])
    minute = int(text[14:16])
    return ordinal * 86400 + hour * 3600 + minute * 60


def normalize_pattern(text: str) -> str:
    value = clean_text(text)
    value = re.sub(r"\s+\|\s+Swept .*", "", value)
    value = re.sub(r"\s+\(Consol=.*", "", value)
    value = re.sub(r"\s+\(Squeeze=.*", "", value)
    return value


def bucket_score(score: float | None) -> str:
    if score is None:
        return "unknown"
    if score >= 60.0:
        return "good"
    if score <= 40.0:
        return "bad"
    return "neutral"


def read_utf16_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-16", newline="") as handle:
        return list(csv.DictReader(handle))


def read_report_rows(path: Path) -> list[list[str]]:
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
        elif any(needle in cell for cell in row):
            return idx
    return None


def parse_report_summary(path: Path, year: int) -> tuple[ReportSummary, list[dict[str, object]]]:
    rows = read_report_rows(path)

    start = find_row(rows, "Bars:")
    end = find_row(rows, "Orders")
    summary_map: dict[str, str] = {}
    if start is not None and end is not None:
        for row in rows[start:end]:
            for idx, cell in enumerate(row[:-1]):
                if cell.endswith(":"):
                    summary_map[cell[:-1]] = row[idx + 1]

    order_header_idx = None
    for idx, row in enumerate(rows):
        if row[:4] == ["Open Time", "Order", "Symbol", "Type"]:
            order_header_idx = idx
            break

    deals_idx = find_row(rows, "Deals", exact=True)
    orders: dict[str, dict[str, str]] = {}
    if order_header_idx is not None and deals_idx is not None:
        header = rows[order_header_idx]
        for row in rows[order_header_idx + 1 : deals_idx]:
            if len(row) != len(header):
                continue
            if not row[0] or not re.match(r"^\d{4}\.\d{2}\.\d{2} ", row[0]):
                continue
            orders[row[1]] = dict(zip(header, row))

    deal_header_idx = find_row(rows, "Direction")
    report_exit_records: list[dict[str, object]] = []
    if deal_header_idx is not None:
        header = rows[deal_header_idx]
        for row in rows[deal_header_idx + 1 :]:
            if len(row) != len(header):
                if report_exit_records:
                    break
                continue
            if not row[0] or not re.match(r"^\d{4}\.\d{2}\.\d{2} ", row[0]):
                continue
            deal = dict(zip(header, row))
            if deal.get("Type") == "balance" or deal.get("Direction") != "out":
                continue
            order = orders.get(deal.get("Order", ""), {})
            report_exit_records.append(
                {
                    "time": clean_text(deal.get("Time")),
                    "ts": None,
                    "type": clean_text(deal.get("Type")),
                    "price": parse_float(deal.get("Price")),
                    "volume": parse_float(deal.get("Volume")),
                    "commission": parse_float(deal.get("Commission")) or 0.0,
                    "swap": parse_float(deal.get("Swap")) or 0.0,
                    "profit": parse_float(deal.get("Profit")) or 0.0,
                    "order": clean_text(deal.get("Order")),
                    "deal": clean_text(deal.get("Deal")),
                    "comment": clean_text(order.get("Comment") or deal.get("Comment")),
                }
            )

    report = ReportSummary(
        year=year,
        net_profit=parse_float(summary_map.get("Total Net Profit")),
        profit_factor=parse_float(summary_map.get("Profit Factor")),
        expected_payoff=parse_float(summary_map.get("Expected Payoff")),
        sharpe_ratio=parse_float(summary_map.get("Sharpe Ratio")),
        drawdown_rel_pct=parse_float(
            clean_text(summary_map.get("Balance Drawdown Relative", "")).split("%", 1)[0]
        ),
        total_trades=parse_int(summary_map.get("Total Trades")),
        profit_trades_text=clean_text(summary_map.get("Profit Trades (% of total)")),
        long_trades_text=clean_text(summary_map.get("Long Trades (won %)")),
        short_trades_text=clean_text(summary_map.get("Short Trades (won %)")),
        avg_hold_time=clean_text(summary_map.get("Average position holding time")),
        max_hold_time=clean_text(summary_map.get("Maximal position holding time")),
    )
    return report, report_exit_records


def classify_report_exit_comment(comment: str) -> str:
    low = clean_text(comment).lower()
    if not low:
        return "blank"
    if low.startswith("sl"):
        return "sl"
    if low.startswith("tp"):
        return "tp"
    if low.startswith("end of test"):
        return "end_of_test"
    if low.startswith("weekend"):
        return "weekend"
    return "other"


def load_15m_bars(min_year: int, max_year: int) -> tuple[list[int], list[float], list[float], list[float], list[float], dict[int, tuple[int, int]]]:
    keep_from = date(min_year, 1, 1).toordinal() * 86400 - (3 * SECONDS_24H)
    keep_to = date(max_year + 1, 1, 2).toordinal() * 86400

    times: list[int] = []
    opens: list[float] = []
    highs: list[float] = []
    lows: list[float] = []
    closes: list[float] = []
    year_ranges: dict[int, list[int]] = defaultdict(list)
    cache: dict[str, int] = {}

    with PRICE_15M_FILE.open("r", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=";")
        for row in reader:
            ts = parse_bar_ts(row["Date"], cache)
            if ts < keep_from:
                continue
            if ts > keep_to:
                break
            idx = len(times)
            times.append(ts)
            opens.append(float(row["Open"]))
            highs.append(float(row["High"]))
            lows.append(float(row["Low"]))
            closes.append(float(row["Close"]))
            year = int(row["Date"][:4])
            year_ranges[year].append(idx)

    compact_ranges: dict[int, tuple[int, int]] = {}
    for year, indexes in year_ranges.items():
        compact_ranges[year] = (indexes[0], indexes[-1] + 1)
    return times, opens, highs, lows, closes, compact_ranges


def load_1m_bars(min_year: int, max_year: int) -> tuple[list[int], list[float], list[float], list[float], list[float]]:
    keep_from = date(min_year, 1, 1).toordinal() * 86400 - (4 * SECONDS_24H)
    keep_to = date(max_year + 1, 1, 3).toordinal() * 86400

    times: list[int] = []
    opens: list[float] = []
    highs: list[float] = []
    lows: list[float] = []
    closes: list[float] = []
    cache: dict[str, int] = {}

    with PRICE_1M_FILE.open("r", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=";")
        for row in reader:
            ts = parse_bar_ts(row["Date"], cache)
            if ts < keep_from:
                continue
            if ts > keep_to:
                break
            times.append(ts)
            opens.append(float(row["Open"]))
            highs.append(float(row["High"]))
            lows.append(float(row["Low"]))
            closes.append(float(row["Close"]))
    return times, opens, highs, lows, closes


def annual_market_stats(opens: list[float], highs: list[float], lows: list[float], closes: list[float]) -> dict[str, float]:
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
        "ann_vol_pct": math.sqrt(ret_var) * math.sqrt(252 * 24 * 4) * 100.0 if returns else 0.0,
    }


def choose_candidate_row(rows: list[dict[str, str]]) -> dict[str, str] | None:
    if not rows:
        return None

    def sort_key(row: dict[str, str]) -> tuple[int, int]:
        priority = 0
        if clean_text(row.get("Winner")) == "YES":
            priority += 3
        if clean_text(row.get("ValidationStage")) == "FINAL":
            priority += 2
        if clean_text(row.get("Decision")) in {"WINNER", "PASS"}:
            priority += 1
        ts = parse_dt_seconds(clean_text(row.get("BarTime")) + ":00", {}) if len(clean_text(row.get("BarTime"))) == 16 else parse_dt_seconds(clean_text(row.get("BarTime")), {})
        return priority, ts

    return sorted(rows, key=sort_key)[-1]


def choose_risk_row(rows: list[dict[str, str]]) -> dict[str, str] | None:
    if not rows:
        return None

    def sort_key(row: dict[str, str]) -> tuple[int, str]:
        priority = 1 if "EXECUTED" in clean_text(row.get("ExecutionOutcome")) else 0
        return priority, clean_text(row.get("Time"))

    return sorted(rows, key=sort_key)[-1]


def side_is_long(direction: str) -> bool:
    return clean_text(direction).upper() in {"LONG", "BUY"}


def window_slice(times: list[int], start_ts: int, end_ts: int) -> tuple[int, int]:
    return bisect_right(times, start_ts), bisect_right(times, end_ts)


def evaluate_directional_move(
    is_long: bool,
    ref_price: float,
    risk_distance: float | None,
    highs: list[float],
    lows: list[float],
) -> dict[str, float | None]:
    if not highs or not lows:
        return {
            "favorable": None,
            "adverse": None,
            "favorable_r": None,
            "adverse_r": None,
            "score": None,
        }

    future_high = max(highs)
    future_low = min(lows)
    total_range = future_high - future_low

    if is_long:
        favorable = max(0.0, future_high - ref_price)
        adverse = max(0.0, ref_price - future_low)
        timing_score = 50.0 if total_range <= 0 else 100.0 * (future_high - ref_price) / total_range
    else:
        favorable = max(0.0, ref_price - future_low)
        adverse = max(0.0, future_high - ref_price)
        timing_score = 50.0 if total_range <= 0 else 100.0 * (ref_price - future_low) / total_range

    favorable_r = favorable / risk_distance if risk_distance and risk_distance > 0 else None
    adverse_r = adverse / risk_distance if risk_distance and risk_distance > 0 else None
    followthrough = 50.0 if (favorable + adverse) <= 0 else 100.0 * favorable / (favorable + adverse)

    return {
        "favorable": favorable,
        "adverse": adverse,
        "favorable_r": favorable_r,
        "adverse_r": adverse_r,
        "score": followthrough,
        "timing": timing_score,
    }


def evaluate_exit_window(
    is_long: bool,
    exit_price: float,
    risk_distance: float | None,
    highs: list[float],
    lows: list[float],
) -> dict[str, float | None]:
    if not highs or not lows:
        return {
            "missed_move": None,
            "protected_move": None,
            "missed_r": None,
            "protected_r": None,
            "exit_score": None,
        }

    future_high = max(highs)
    future_low = min(lows)
    if is_long:
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
        "missed_r": missed / risk_distance if risk_distance and risk_distance > 0 else None,
        "protected_r": protected / risk_distance if risk_distance and risk_distance > 0 else None,
        "exit_score": score,
    }


def lookback_return(times: list[int], closes: list[float], ref_ts: int, lookback_seconds: int) -> float | None:
    now_idx = bisect_right(times, ref_ts) - 1
    prev_idx = bisect_right(times, ref_ts - lookback_seconds) - 1
    if now_idx < 0 or prev_idx < 0:
        return None
    prev_close = closes[prev_idx]
    now_close = closes[now_idx]
    if prev_close == 0:
        return None
    return 100.0 * (now_close - prev_close) / prev_close


def simplify_exit_request(reason: str) -> str:
    value = clean_text(reason)
    if not value:
        return "broker_or_blank"
    if value.startswith("ANTI_STALL_CLOSE"):
        return "anti_stall_close"
    if value.startswith("RUNNER_EXIT"):
        return "runner_exit"
    if value.startswith("EARLY_INVALIDATION"):
        return "early_invalidation"
    if value.lower().startswith("weekend"):
        return "weekend"
    return value


def summarize_events(events: list[dict[str, str]]) -> dict[str, object]:
    counts = Counter(clean_text(event.get("EventType")) for event in events)
    reasons = Counter(clean_text(event.get("EventReason")) for event in events if clean_text(event.get("EventReason")))
    return {
        "event_count": len(events),
        "event_types": "|".join(f"{key}:{counts[key]}" for key in sorted(counts)),
        "top_event_reason": reasons.most_common(1)[0][0] if reasons else "",
        "anti_stall_partial_count": counts.get("ANTI_STALL_PARTIAL", 0),
        "exit_request_count": counts.get("EXIT_REQUEST", 0),
        "exit_trigger_count": counts.get("EXIT_TRIGGER", 0),
        "had_breakeven_event": counts.get("BREAKEVEN_ARMED", 0) > 0,
        "had_trailing_event": counts.get("TRAIL_INTERNAL", 0) > 0 or counts.get("TRAIL_BROKER_OK", 0) > 0,
        "had_trailing_failures": counts.get("TRAIL_BROKER_FAIL", 0) > 0,
        "had_tp0_event": counts.get("TP0_PARTIAL", 0) > 0,
        "had_tp1_event": counts.get("TP1_PARTIAL", 0) > 0,
        "had_tp2_event": counts.get("TP2_PARTIAL", 0) > 0,
        "last_event_type": clean_text(events[-1].get("EventType")) if events else "",
        "last_event_reason": clean_text(events[-1].get("EventReason")) if events else "",
    }


def classify_trade(record: dict[str, object]) -> tuple[str, str, str, str, str, str, float]:
    total_r = record.get("Total_R")
    favorable_r_24h = record.get("Entry_Favorable_R_24h")
    adverse_r_24h = record.get("Entry_Adverse_R_24h")
    followthrough_24h = record.get("Entry_Followthrough_24h")
    pre_exit_mfe_r = record.get("Market_MFE_R_ToExit") or record.get("MFE_R")
    exit_score_24h = record.get("Exit_Score_24h")
    exit_missed_r_24h = record.get("Exit_Missed_R_24h")
    exit_protected_r_24h = record.get("Exit_Protected_R_24h")
    ret_24h = record.get("Prev_24h_Return_Pct")
    year_return = record.get("Year_Gold_Return_Pct")
    direction = clean_text(record.get("Direction"))
    report_exit_type = clean_text(record.get("ReportExitType"))
    exit_request = simplify_exit_request(clean_text(record.get("ExitRequestReason")))
    had_be = bool(record.get("HadBreakevenEvent"))
    had_trailing = bool(record.get("HadTrailingEvent"))
    trail_failures = parse_int(record.get("TrailBrokerFailures")) or 0

    entry_grade = "neutral"
    entry_issue = "mixed"
    if favorable_r_24h is not None and adverse_r_24h is not None:
        if favorable_r_24h < 0.4 and adverse_r_24h >= 1.0:
            entry_grade = "bad"
            entry_issue = "no_edge_fast_adverse_move"
        elif followthrough_24h is not None and followthrough_24h <= 35.0 and (pre_exit_mfe_r or 0.0) < 0.8:
            entry_grade = "bad"
            entry_issue = "poor_followthrough"
        elif direction == "SHORT" and total_r is not None and total_r < 0 and ret_24h is not None and ret_24h > 0.6:
            entry_grade = "bad"
            entry_issue = "countertrend_short_vs_recent_uptrend"
        elif direction == "LONG" and total_r is not None and total_r < 0 and ret_24h is not None and ret_24h < -0.6:
            entry_grade = "bad"
            entry_issue = "countertrend_long_vs_recent_downtrend"
        elif favorable_r_24h >= 1.3 and (followthrough_24h or 0.0) >= 60.0:
            entry_grade = "good"
            entry_issue = "strong_followthrough"
        elif favorable_r_24h >= 0.8 and adverse_r_24h <= 0.6:
            entry_grade = "good"
            entry_issue = "decent_location"

    exit_grade = "neutral"
    exit_issue = "mixed"
    if pre_exit_mfe_r is not None and total_r is not None and exit_missed_r_24h is not None:
        if pre_exit_mfe_r >= 1.5 and total_r <= 0.25:
            exit_grade = "bad"
            if had_be:
                exit_issue = "premature_breakeven_on_good_trade"
            elif had_trailing:
                exit_issue = "trailing_gave_back_large_move"
            elif exit_request == "anti_stall_close":
                exit_issue = "anti_stall_closed_good_trade_early"
            else:
                exit_issue = "gave_back_large_open_profit"
        elif exit_missed_r_24h >= 1.0 and (exit_score_24h or 50.0) <= 35.0:
            exit_grade = "bad"
            if exit_request == "anti_stall_close":
                exit_issue = "anti_stall_exit_left_large_move"
            elif had_be:
                exit_issue = "breakeven_exit_too_early"
            elif had_trailing:
                exit_issue = "trailing_stop_too_tight"
            elif report_exit_type == "tp":
                exit_issue = "take_profit_too_close"
            else:
                exit_issue = "premature_exit"
        elif exit_score_24h is not None and exit_score_24h >= 60.0:
            exit_grade = "good"
            exit_issue = "protected_against_reversal"
        elif exit_protected_r_24h is not None and exit_missed_r_24h is not None and exit_protected_r_24h >= exit_missed_r_24h:
            exit_grade = "good"
            exit_issue = "reasonable_exit"

    management_issue = "none"
    if exit_grade == "bad" and had_be:
        management_issue = "breakeven"
    elif exit_grade == "bad" and had_trailing:
        management_issue = "trailing"
    elif exit_request == "anti_stall_close" or (parse_int(record.get("AntiStallPartialCount")) or 0) > 0:
        management_issue = "anti_stall"
    elif trail_failures > 0:
        management_issue = "broker_trailing_failures"

    verdict = "mixed"
    if entry_grade == "bad" and exit_grade == "bad":
        verdict = "bad_entry_bad_exit"
    elif entry_grade == "bad":
        verdict = "bad_entry"
    elif exit_grade == "bad":
        verdict = "bad_exit"
    elif entry_grade == "good" and exit_grade == "good":
        verdict = "good_trade"
    elif total_r is not None and total_r > 0.5:
        verdict = "acceptable_win"
    elif total_r is not None and total_r < -0.5:
        verdict = "acceptable_loss"

    primary_cause = exit_issue if exit_grade == "bad" and entry_grade != "bad" else entry_issue
    if entry_grade == "bad" and exit_grade == "bad":
        primary_cause = f"{entry_issue}+{exit_issue}"

    severity = 0.0
    if total_r is not None and total_r < 0:
        severity += abs(total_r)
    if favorable_r_24h is not None and favorable_r_24h < 0.5:
        severity += 0.5 - favorable_r_24h
    if adverse_r_24h is not None and adverse_r_24h > 1.0:
        severity += adverse_r_24h - 1.0
    if pre_exit_mfe_r is not None and total_r is not None and pre_exit_mfe_r > max(total_r, 0.0):
        severity += max(0.0, pre_exit_mfe_r - max(total_r, 0.0)) * 0.5
    if exit_missed_r_24h is not None:
        severity += max(0.0, exit_missed_r_24h - 0.5) * 0.4
    if direction == "SHORT" and year_return is not None and year_return > 15.0 and total_r is not None and total_r < 0:
        severity += 0.25

    return entry_grade, entry_issue, exit_grade, exit_issue, management_issue, verdict, severity


def build_case_line(record: dict[str, object], kind: str) -> str:
    return (
        f"- {kind}: {record['Year']} | {record['Pattern']} | {record['Direction']} | "
        f"Entry {record['EntryTime']} | Exit {record['ExitTime']} | "
        f"Total {fmt_num(record['Total_PnL'])} ({fmt_num(record['Total_R'])}R) | "
        f"Entry={record['EntryIssue']} | Exit={record['ExitIssue']} | "
        f"Missed24h={fmt_num(record['Exit_Missed_R_24h'])}R | "
        f"MFE={fmt_num(record['Market_MFE_R_ToExit'])}R"
    )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    report_summaries: dict[int, ReportSummary] = {}
    report_exits_by_year: dict[int, list[dict[str, object]]] = {}
    report_exit_index_by_year: dict[int, dict[int, list[dict[str, object]]]] = {}

    for year in REPORT_YEARS:
        report_path = REPORT_DIR / f"ReportTester-{year}.html"
        if not report_path.exists():
            continue
        summary, exits = parse_report_summary(report_path, year)
        report_summaries[year] = summary
        report_exits_by_year[year] = exits
        ts_index: dict[int, list[dict[str, object]]] = defaultdict(list)
        cache: dict[str, int] = {}
        for item in exits:
            if item["time"]:
                ts = parse_dt_seconds(str(item["time"]), cache)
                item["ts"] = ts
                ts_index[ts - (ts % 60)].append(item)
        report_exit_index_by_year[year] = ts_index

    t15_times, t15_opens, t15_highs, t15_lows, t15_closes, t15_year_ranges = load_15m_bars(min(REPORT_YEARS), max(REPORT_YEARS))
    t1_times, t1_opens, t1_highs, t1_lows, t1_closes = load_1m_bars(min(REPORT_YEARS), max(REPORT_YEARS))

    year_market: dict[int, dict[str, float]] = {}
    for year, (start, end) in t15_year_ranges.items():
        year_market[year] = annual_market_stats(
            t15_opens[start:end], t15_highs[start:end], t15_lows[start:end], t15_closes[start:end]
        )

    all_trade_records: list[dict[str, object]] = []
    year_summary_rows: list[dict[str, object]] = []
    strategy_summary_rows: list[dict[str, object]] = []
    strategy_global_summary_rows: list[dict[str, object]] = []
    exit_summary_rows: list[dict[str, object]] = []
    management_summary_rows: list[dict[str, object]] = []
    reconciliation_rows: list[dict[str, object]] = []
    report_only_year_rows: list[dict[str, object]] = []

    dt_cache: dict[str, int] = {}

    for year in LOG_YEARS:
        stats_path = LOG_DIR / f"UltTrader_Stats_XAUUSD+_{year}0101_0000.csv"
        events_path = LOG_DIR / f"UltTrader_TradeEvents_XAUUSD+_{year}0101_0000.csv"
        candidates_path = LOG_DIR / f"UltTrader_Candidates_XAUUSD+_{year}0101_0000.csv"
        risk_path = LOG_DIR / f"UltTrader_Risk_XAUUSD+_{year}0101_0000.csv"

        stats_rows = read_utf16_csv(stats_path)
        event_rows = read_utf16_csv(events_path)
        candidate_rows = read_utf16_csv(candidates_path)
        risk_rows = read_utf16_csv(risk_path)

        event_map: dict[str, list[dict[str, str]]] = defaultdict(list)
        for row in event_rows:
            event_map[clean_text(row.get("Ticket"))].append(row)
        for ticket in event_map:
            event_map[ticket].sort(key=lambda item: clean_text(item.get("Time")))

        candidate_map: dict[str, list[dict[str, str]]] = defaultdict(list)
        for row in candidate_rows:
            candidate_map[clean_text(row.get("SignalID"))].append(row)

        risk_map: dict[str, list[dict[str, str]]] = defaultdict(list)
        for row in risk_rows:
            risk_map[clean_text(row.get("SignalID"))].append(row)

        exit_rows = [row for row in stats_rows if clean_text(row.get("RowType")) == "EXIT"]

        trade_records: list[dict[str, object]] = []
        report_matches = 0
        stats_total_pnl = 0.0

        for row in exit_rows:
            ticket = clean_text(row.get("Ticket"))
            signal_id = clean_text(row.get("SignalID"))
            direction = clean_text(row.get("Direction"))
            is_long = side_is_long(direction)
            entry_time = clean_text(row.get("EntryTime"))
            exit_time = clean_text(row.get("ExitTime"))
            if not entry_time or not exit_time:
                continue

            entry_ts = parse_dt_seconds(entry_time, dt_cache)
            exit_ts = parse_dt_seconds(exit_time, dt_cache)
            entry_price = parse_float(row.get("EntryPrice")) or 0.0
            exit_price = parse_float(row.get("ExitPrice")) or 0.0
            original_sl = parse_float(row.get("OriginalSL"))
            risk_distance = abs(entry_price - original_sl) if original_sl is not None else None
            pattern = normalize_pattern(clean_text(row.get("Pattern")))
            engine_name = clean_text(row.get("EngineName"))
            total_pnl = parse_float(row.get("Total_PnL")) or 0.0
            total_r = parse_float(row.get("Total_R"))
            stats_total_pnl += total_pnl

            entry_1h_start, entry_1h_end = window_slice(t1_times, entry_ts, entry_ts + SECONDS_1H)
            entry_4h_start, entry_4h_end = window_slice(t1_times, entry_ts, entry_ts + SECONDS_4H)
            entry_24h_start, entry_24h_end = window_slice(t1_times, entry_ts, entry_ts + SECONDS_24H)
            entry_48h_start, entry_48h_end = window_slice(t1_times, entry_ts, entry_ts + SECONDS_48H)
            hold_start, hold_end = window_slice(t1_times, entry_ts, exit_ts)
            exit_4h_start, exit_4h_end = window_slice(t1_times, exit_ts, exit_ts + SECONDS_4H)
            exit_24h_start, exit_24h_end = window_slice(t1_times, exit_ts, exit_ts + SECONDS_24H)
            exit_48h_start, exit_48h_end = window_slice(t1_times, exit_ts, exit_ts + SECONDS_48H)

            entry_1h = evaluate_directional_move(is_long, entry_price, risk_distance, t1_highs[entry_1h_start:entry_1h_end], t1_lows[entry_1h_start:entry_1h_end])
            entry_4h = evaluate_directional_move(is_long, entry_price, risk_distance, t1_highs[entry_4h_start:entry_4h_end], t1_lows[entry_4h_start:entry_4h_end])
            entry_24h = evaluate_directional_move(is_long, entry_price, risk_distance, t1_highs[entry_24h_start:entry_24h_end], t1_lows[entry_24h_start:entry_24h_end])
            entry_48h = evaluate_directional_move(is_long, entry_price, risk_distance, t1_highs[entry_48h_start:entry_48h_end], t1_lows[entry_48h_start:entry_48h_end])
            hold_move = evaluate_directional_move(is_long, entry_price, risk_distance, t1_highs[hold_start:hold_end], t1_lows[hold_start:hold_end])
            exit_4h = evaluate_exit_window(is_long, exit_price, risk_distance, t1_highs[exit_4h_start:exit_4h_end], t1_lows[exit_4h_start:exit_4h_end])
            exit_24h = evaluate_exit_window(is_long, exit_price, risk_distance, t1_highs[exit_24h_start:exit_24h_end], t1_lows[exit_24h_start:exit_24h_end])
            exit_48h = evaluate_exit_window(is_long, exit_price, risk_distance, t1_highs[exit_48h_start:exit_48h_end], t1_lows[exit_48h_start:exit_48h_end])

            events = event_map.get(ticket, [])
            event_summary = summarize_events(events)
            candidate = choose_candidate_row(candidate_map.get(signal_id, []))
            risk = choose_risk_row(risk_map.get(signal_id, []))

            report_exit = None
            report_candidates: list[dict[str, object]] = []
            minute_key = exit_ts - (exit_ts % 60)
            exit_index = report_exit_index_by_year.get(year, {})
            for offset in (-60, 0, 60):
                report_candidates.extend(exit_index.get(minute_key + offset, []))
            if report_candidates:
                scored: list[tuple[float, dict[str, object]]] = []
                for item in report_candidates:
                    item_price = item.get("price")
                    if item_price is None:
                        continue
                    ts_penalty = abs(int(item.get("ts") or 0) - exit_ts) / 60.0
                    price_penalty = abs(float(item_price) - exit_price)
                    scored.append((price_penalty + ts_penalty, item))
                if scored:
                    scored.sort(key=lambda pair: pair[0])
                    report_exit = scored[0][1]
                    report_matches += 1

            report_exit_comment = clean_text(report_exit.get("comment")) if report_exit else ""
            report_exit_type = classify_report_exit_comment(report_exit_comment)
            last_trail_reason = clean_text(row.get("LastTrailReason"))
            if last_trail_reason.startswith("Chandelier Trail"):
                last_trail_kind = "chandelier"
            elif last_trail_reason:
                last_trail_kind = "other"
            else:
                last_trail_kind = "none"
            runner_exit_mode = clean_text(row.get("RunnerExitMode"))
            runner_managed = runner_exit_mode not in {"", "RUNNER_EXIT_STANDARD"}

            record: dict[str, object] = {
                "Year": year,
                "Ticket": ticket,
                "SignalID": signal_id,
                "Pattern": pattern,
                "Direction": direction,
                "Source": clean_text(row.get("Source")),
                "Regime": clean_text(row.get("Regime")),
                "Quality": clean_text(row.get("Quality")),
                "Session": clean_text(row.get("Session")),
                "EngineName": engine_name,
                "EngineMode": clean_text(row.get("EngineMode")),
                "DayType": clean_text(row.get("DayType")),
                "Spread": parse_float(row.get("Spread")),
                "Slippage": parse_float(row.get("Slippage")),
                "EntryTime": entry_time,
                "ExitTime": exit_time,
                "EntryPrice": entry_price,
                "ExitPrice": exit_price,
                "OriginalSL": original_sl,
                "OriginalTP1": parse_float(row.get("OriginalTP1")),
                "TP2": parse_float(row.get("TP2")),
                "RiskDistance": risk_distance,
                "EntryRiskMoney": parse_float(row.get("EntryRiskMoney")),
                "RiskPct": parse_float(row.get("RiskPct")),
                "LotSize": parse_float(row.get("LotSize")),
                "HoldingHours": parse_float(row.get("HoldingHours")),
                "Result": clean_text(row.get("Result")),
                "PnL_Money": parse_float(row.get("PnL_Money")),
                "Total_PnL": total_pnl,
                "Total_R": total_r,
                "MAE_R": parse_float(row.get("MAE_R")),
                "MFE_R": parse_float(row.get("MFE_R")),
                "PartialCloseCount": parse_int(row.get("PartialCloseCount")),
                "PartialRealized_PnL": parse_float(row.get("PartialRealized_PnL")),
                "TP0_Closed": clean_text(row.get("TP0_Closed")),
                "TP0_Lots": parse_float(row.get("TP0_Lots")),
                "TrailInternalUpdates": parse_int(row.get("TrailInternalUpdates")),
                "TrailBrokerUpdates": parse_int(row.get("TrailBrokerUpdates")),
                "TrailBrokerFailures": parse_int(row.get("TrailBrokerFailures")),
                "LastTrailReason": last_trail_reason,
                "LastTrailKind": last_trail_kind,
                "MaxLockedR": parse_float(row.get("MaxLockedR")),
                "RunnerExitMode": runner_exit_mode,
                "RunnerManaged": runner_managed,
                "RunnerPromotedInTrade": clean_text(row.get("RunnerPromotedInTrade")),
                "RunnerPromotionTime": clean_text(row.get("RunnerPromotionTime")),
                "TrailSendPolicy": clean_text(row.get("TrailSendPolicy")),
                "LastTrailGateReason": clean_text(row.get("LastTrailGateReason")),
                "EffectiveChandelierMult": parse_float(row.get("EffectiveChandelierMult")),
                "LiveChandelierMult": parse_float(row.get("LiveChandelierMult")),
                "EntryLockedChandelierMult": parse_float(row.get("EntryLockedChandelierMult")),
                "LastBrokerTrailTime": clean_text(row.get("LastBrokerTrailTime")),
                "ExitRequestReason": clean_text(row.get("ExitRequestReason")),
                "ExitReason": clean_text(row.get("ExitReason")),
                "Year_Gold_Return_Pct": year_market.get(year, {}).get("return_pct"),
                "Year_Gold_Range_Pct": year_market.get(year, {}).get("range_pct"),
                "Prev_24h_Return_Pct": lookback_return(t1_times, t1_closes, entry_ts, SECONDS_24H),
                "Prev_72h_Return_Pct": lookback_return(t1_times, t1_closes, entry_ts, SECONDS_72H),
                "Entry_Favorable_R_1h": entry_1h["favorable_r"],
                "Entry_Adverse_R_1h": entry_1h["adverse_r"],
                "Entry_Followthrough_1h": entry_1h["score"],
                "Entry_Favorable_R_4h": entry_4h["favorable_r"],
                "Entry_Adverse_R_4h": entry_4h["adverse_r"],
                "Entry_Followthrough_4h": entry_4h["score"],
                "Entry_Favorable_R_24h": entry_24h["favorable_r"],
                "Entry_Adverse_R_24h": entry_24h["adverse_r"],
                "Entry_Followthrough_24h": entry_24h["score"],
                "Entry_Favorable_R_48h": entry_48h["favorable_r"],
                "Entry_Adverse_R_48h": entry_48h["adverse_r"],
                "Entry_Followthrough_48h": entry_48h["score"],
                "Market_MFE_R_ToExit": hold_move["favorable_r"],
                "Market_MAE_R_ToExit": hold_move["adverse_r"],
                "Exit_Missed_R_4h": exit_4h["missed_r"],
                "Exit_Protected_R_4h": exit_4h["protected_r"],
                "Exit_Score_4h": exit_4h["exit_score"],
                "Exit_Missed_R_24h": exit_24h["missed_r"],
                "Exit_Protected_R_24h": exit_24h["protected_r"],
                "Exit_Score_24h": exit_24h["exit_score"],
                "Exit_Missed_R_48h": exit_48h["missed_r"],
                "Exit_Protected_R_48h": exit_48h["protected_r"],
                "Exit_Score_48h": exit_48h["exit_score"],
                "EventCount": event_summary["event_count"],
                "EventTypes": event_summary["event_types"],
                "TopEventReason": event_summary["top_event_reason"],
                "AntiStallPartialCount": event_summary["anti_stall_partial_count"],
                "ExitRequestCount": event_summary["exit_request_count"],
                "ExitTriggerCount": event_summary["exit_trigger_count"],
                "HadBreakevenEvent": event_summary["had_breakeven_event"],
                "HadTrailingEvent": event_summary["had_trailing_event"],
                "HadTrailingFailures": event_summary["had_trailing_failures"],
                "HadTP0Event": event_summary["had_tp0_event"],
                "HadTP1Event": event_summary["had_tp1_event"],
                "HadTP2Event": event_summary["had_tp2_event"],
                "ReportExitComment": report_exit_comment,
                "ReportExitType": report_exit_type,
                "CandidatePlugin": clean_text(candidate.get("Plugin")) if candidate else "",
                "CandidateDecision": clean_text(candidate.get("Decision")) if candidate else "",
                "CandidateReason": clean_text(candidate.get("Reason")) if candidate else "",
                "CandidateQualityScore": parse_float(candidate.get("QualityScore")) if candidate else None,
                "CandidateATR": parse_float(candidate.get("ATR")) if candidate else None,
                "CandidateADX": parse_float(candidate.get("ADX")) if candidate else None,
                "CandidateMacroScore": parse_float(candidate.get("MacroScore")) if candidate else None,
                "RiskBasePct": parse_float(risk.get("BaseRiskPct")) if risk else None,
                "RiskRequestedPct": parse_float(risk.get("RequestedRiskPct")) if risk else None,
                "RiskFinalPct": parse_float(risk.get("FinalRiskPct")) if risk else None,
                "RiskCounterTrendReduced": clean_text(risk.get("CounterTrendReduced")) if risk else "",
                "RiskCounterTrendMultiplier": parse_float(risk.get("CounterTrendMultiplier")) if risk else None,
                "RiskExecutionOutcome": clean_text(risk.get("ExecutionOutcome")) if risk else "",
            }

            entry_grade, entry_issue, exit_grade, exit_issue, management_issue, verdict, severity = classify_trade(record)
            record["EntryGrade"] = entry_grade
            record["EntryIssue"] = entry_issue
            record["ExitGrade"] = exit_grade
            record["ExitIssue"] = exit_issue
            record["ManagementIssue"] = management_issue
            record["Verdict"] = verdict
            record["SeverityScore"] = severity

            trade_records.append(record)
            all_trade_records.append(record)

        report_summary = report_summaries.get(year)
        report_net = report_summary.net_profit if report_summary else None
        reconciliation_rows.append(
            {
                "Year": year,
                "StatsTrades": len(trade_records),
                "StatsTotalPnL": round(stats_total_pnl, 2),
                "ReportNetProfit": report_net,
                "Difference_StatsMinusReport": None if report_net is None else round(stats_total_pnl - report_net, 2),
                "MatchedReportExits": report_matches,
                "ReportExitMatchPct": pct(report_matches, len(trade_records)),
            }
        )

        by_pattern: dict[str, list[dict[str, object]]] = defaultdict(list)
        by_exit_type: dict[str, list[dict[str, object]]] = defaultdict(list)
        by_verdict = Counter()
        for record in trade_records:
            by_pattern[str(record["Pattern"])].append(record)
            by_exit_type[str(record["ReportExitType"])].append(record)
            by_verdict[str(record["Verdict"])] += 1

        for pattern, items in sorted(by_pattern.items(), key=lambda item: len(item[1]), reverse=True):
            strategy_summary_rows.append(
                {
                    "Year": year,
                    "Pattern": pattern,
                    "Trades": len(items),
                    "NetPnL": round(sum(float(item["Total_PnL"] or 0.0) for item in items), 2),
                    "AvgR": mean(float(item["Total_R"]) for item in items if item["Total_R"] is not None),
                    "WinRatePct": pct(sum(1 for item in items if clean_text(item["Result"]) == "WIN"), len(items)),
                    "BadEntryPct": pct(sum(1 for item in items if item["EntryGrade"] == "bad"), len(items)),
                    "BadExitPct": pct(sum(1 for item in items if item["ExitGrade"] == "bad"), len(items)),
                    "BadTradePct": pct(sum(1 for item in items if item["Verdict"] in {"bad_entry", "bad_exit", "bad_entry_bad_exit"}), len(items)),
                    "AvgEntry24hR": mean(float(item["Entry_Favorable_R_24h"]) for item in items if item["Entry_Favorable_R_24h"] is not None),
                    "AvgAdverse24hR": mean(float(item["Entry_Adverse_R_24h"]) for item in items if item["Entry_Adverse_R_24h"] is not None),
                    "AvgExitMissed24hR": mean(float(item["Exit_Missed_R_24h"]) for item in items if item["Exit_Missed_R_24h"] is not None),
                    "AvgExitScore24h": mean(float(item["Exit_Score_24h"]) for item in items if item["Exit_Score_24h"] is not None),
                    "TrailingTradePct": pct(sum(1 for item in items if item["HadTrailingEvent"]), len(items)),
                    "BreakevenTradePct": pct(sum(1 for item in items if item["HadBreakevenEvent"]), len(items)),
                    "RunnerManagedPct": pct(sum(1 for item in items if item["RunnerManaged"]), len(items)),
                }
            )

        for exit_type, items in sorted(by_exit_type.items()):
            exit_summary_rows.append(
                {
                    "Year": year,
                    "ReportExitType": exit_type,
                    "Trades": len(items),
                    "NetPnL": round(sum(float(item["Total_PnL"] or 0.0) for item in items), 2),
                    "AvgR": mean(float(item["Total_R"]) for item in items if item["Total_R"] is not None),
                    "AvgExitScore24h": mean(float(item["Exit_Score_24h"]) for item in items if item["Exit_Score_24h"] is not None),
                    "AvgMissed24hR": mean(float(item["Exit_Missed_R_24h"]) for item in items if item["Exit_Missed_R_24h"] is not None),
                    "BadExitPct": pct(sum(1 for item in items if item["ExitGrade"] == "bad"), len(items)),
                }
            )

        year_summary_rows.append(
            {
                "Year": year,
                "Trades": len(trade_records),
                "ReportNetProfit": report_net,
                "StatsNetPnL": round(stats_total_pnl, 2),
                "GoldReturnPct": year_market.get(year, {}).get("return_pct"),
                "GoldRangePct": year_market.get(year, {}).get("range_pct"),
                "AvgEntryFollowthrough24h": mean(float(item["Entry_Followthrough_24h"]) for item in trade_records if item["Entry_Followthrough_24h"] is not None),
                "AvgEntryFavorable24hR": mean(float(item["Entry_Favorable_R_24h"]) for item in trade_records if item["Entry_Favorable_R_24h"] is not None),
                "AvgEntryAdverse24hR": mean(float(item["Entry_Adverse_R_24h"]) for item in trade_records if item["Entry_Adverse_R_24h"] is not None),
                "AvgExitScore24h": mean(float(item["Exit_Score_24h"]) for item in trade_records if item["Exit_Score_24h"] is not None),
                "AvgExitMissed24hR": mean(float(item["Exit_Missed_R_24h"]) for item in trade_records if item["Exit_Missed_R_24h"] is not None),
                "BadEntryPct": pct(sum(1 for item in trade_records if item["EntryGrade"] == "bad"), len(trade_records)),
                "BadExitPct": pct(sum(1 for item in trade_records if item["ExitGrade"] == "bad"), len(trade_records)),
                "BadTradePct": pct(sum(1 for item in trade_records if item["Verdict"] in {"bad_entry", "bad_exit", "bad_entry_bad_exit"}), len(trade_records)),
                "CountertrendShortLosses": sum(1 for item in trade_records if item["EntryIssue"] == "countertrend_short_vs_recent_uptrend"),
                "TrailingTrades": sum(1 for item in trade_records if item["HadTrailingEvent"]),
                "BreakevenTrades": sum(1 for item in trade_records if item["HadBreakevenEvent"]),
                "RunnerManagedTrades": sum(1 for item in trade_records if item["RunnerManaged"]),
                "RunnerPromotedTrades": sum(1 for item in trade_records if item["RunnerExitMode"] == "RUNNER_EXIT_PROMOTED"),
                "RunnerManagedPct": pct(sum(1 for item in trade_records if item["RunnerManaged"]), len(trade_records)),
                "AntiStallTrades": sum(1 for item in trade_records if (item["AntiStallPartialCount"] or 0) > 0 or simplify_exit_request(str(item["ExitRequestReason"])) == "anti_stall_close"),
                "ReportSLPct": pct(sum(1 for item in trade_records if item["ReportExitType"] == "sl"), len(trade_records)),
                "ReportTPPct": pct(sum(1 for item in trade_records if item["ReportExitType"] == "tp"), len(trade_records)),
                "LongTrades": sum(1 for item in trade_records if item["Direction"] == "LONG"),
                "ShortTrades": sum(1 for item in trade_records if item["Direction"] == "SHORT"),
                "BadEntryBadExitTrades": by_verdict.get("bad_entry_bad_exit", 0),
                "GoodTrades": by_verdict.get("good_trade", 0),
            }
        )

    if 2019 in report_summaries:
        report_only_year_rows.append(
            {
                "Year": 2019,
                "DetailLevel": "report_only",
                "ReportNetProfit": report_summaries[2019].net_profit,
                "ProfitFactor": report_summaries[2019].profit_factor,
                "DrawdownRelPct": report_summaries[2019].drawdown_rel_pct,
                "TotalTrades": report_summaries[2019].total_trades,
                "GoldReturnPct": year_market.get(2019, {}).get("return_pct"),
                "GoldRangePct": year_market.get(2019, {}).get("range_pct"),
                "Notes": "Detailed lifecycle logs are not present for 2019; only report-level analysis is possible.",
            }
        )

    all_trade_records.sort(key=lambda item: (int(item["Year"]), clean_text(item["EntryTime"]), clean_text(item["Ticket"])))
    year_summary_rows.sort(key=lambda item: int(item["Year"]))
    strategy_summary_rows.sort(key=lambda item: (int(item["Year"]), -int(item["Trades"]), str(item["Pattern"])))
    exit_summary_rows.sort(key=lambda item: (int(item["Year"]), str(item["ReportExitType"])))
    reconciliation_rows.sort(key=lambda item: int(item["Year"]))

    by_pattern_global: dict[str, list[dict[str, object]]] = defaultdict(list)
    by_management_issue: dict[str, list[dict[str, object]]] = defaultdict(list)
    for record in all_trade_records:
        by_pattern_global[str(record["Pattern"])].append(record)
        by_management_issue[str(record["ManagementIssue"])].append(record)

    for pattern, items in sorted(by_pattern_global.items(), key=lambda item: len(item[1]), reverse=True):
        strategy_global_summary_rows.append(
            {
                "Pattern": pattern,
                "Trades": len(items),
                "NetPnL": round(sum(float(item["Total_PnL"] or 0.0) for item in items), 2),
                "AvgR": mean(float(item["Total_R"]) for item in items if item["Total_R"] is not None),
                "WinRatePct": pct(sum(1 for item in items if clean_text(item["Result"]) == "WIN"), len(items)),
                "BadEntryPct": pct(sum(1 for item in items if item["EntryGrade"] == "bad"), len(items)),
                "BadExitPct": pct(sum(1 for item in items if item["ExitGrade"] == "bad"), len(items)),
                "BadTradePct": pct(sum(1 for item in items if item["Verdict"] in {"bad_entry", "bad_exit", "bad_entry_bad_exit"}), len(items)),
                "LongTrades": sum(1 for item in items if item["Direction"] == "LONG"),
                "ShortTrades": sum(1 for item in items if item["Direction"] == "SHORT"),
                "BullYearNetPnL_2024_2025": round(sum(float(item["Total_PnL"] or 0.0) for item in items if int(item["Year"]) in {2024, 2025}), 2),
                "WeakYearsNetPnL_2020_2023": round(sum(float(item["Total_PnL"] or 0.0) for item in items if int(item["Year"]) in {2020, 2021, 2022, 2023}), 2),
                "AvgEntry24hR": mean(float(item["Entry_Favorable_R_24h"]) for item in items if item["Entry_Favorable_R_24h"] is not None),
                "AvgAdverse24hR": mean(float(item["Entry_Adverse_R_24h"]) for item in items if item["Entry_Adverse_R_24h"] is not None),
                "AvgExitMissed24hR": mean(float(item["Exit_Missed_R_24h"]) for item in items if item["Exit_Missed_R_24h"] is not None),
                "RunnerManagedPct": pct(sum(1 for item in items if item["RunnerManaged"]), len(items)),
            }
        )

    for issue, items in sorted(by_management_issue.items(), key=lambda item: len(item[1]), reverse=True):
        management_summary_rows.append(
            {
                "ManagementIssue": issue,
                "Trades": len(items),
                "NetPnL": round(sum(float(item["Total_PnL"] or 0.0) for item in items), 2),
                "AvgR": mean(float(item["Total_R"]) for item in items if item["Total_R"] is not None),
                "AvgExitScore24h": mean(float(item["Exit_Score_24h"]) for item in items if item["Exit_Score_24h"] is not None),
                "AvgExitMissed24hR": mean(float(item["Exit_Missed_R_24h"]) for item in items if item["Exit_Missed_R_24h"] is not None),
                "BadExitPct": pct(sum(1 for item in items if item["ExitGrade"] == "bad"), len(items)),
                "BadTradePct": pct(sum(1 for item in items if item["Verdict"] in {"bad_entry", "bad_exit", "bad_entry_bad_exit"}), len(items)),
            }
        )

    strategy_global_summary_rows.sort(key=lambda item: (-int(item["Trades"]), float(item["NetPnL"])))
    management_summary_rows.sort(key=lambda item: (-int(item["Trades"]), str(item["ManagementIssue"])))

    bad_trades = [
        record
        for record in sorted(all_trade_records, key=lambda item: float(item["SeverityScore"]), reverse=True)
        if record["Verdict"] in {"bad_entry", "bad_exit", "bad_entry_bad_exit"} or (record["Total_R"] is not None and float(record["Total_R"]) <= -0.75)
    ]
    bad_exits = [
        record
        for record in sorted(
            [item for item in all_trade_records if item["ExitGrade"] == "bad"],
            key=lambda item: (
                float(item["Exit_Missed_R_24h"] or 0.0),
                float(item["Market_MFE_R_ToExit"] or 0.0),
                float(item["SeverityScore"] or 0.0),
            ),
            reverse=True,
        )
    ]

    trade_fields = list(all_trade_records[0].keys()) if all_trade_records else []
    if trade_fields:
        with (OUT_DIR / "trade_audit_master.csv").open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=trade_fields)
            writer.writeheader()
            writer.writerows(all_trade_records)

    if bad_trades:
        with (OUT_DIR / "bad_trades.csv").open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(bad_trades[0].keys()))
            writer.writeheader()
            writer.writerows(bad_trades)

    if bad_exits:
        with (OUT_DIR / "bad_exits.csv").open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(bad_exits[0].keys()))
            writer.writeheader()
            writer.writerows(bad_exits)

    for filename, rows in (
        ("year_summary.csv", year_summary_rows),
        ("strategy_summary.csv", strategy_summary_rows),
        ("strategy_global_summary.csv", strategy_global_summary_rows),
        ("exit_summary.csv", exit_summary_rows),
        ("management_summary.csv", management_summary_rows),
        ("report_reconciliation.csv", reconciliation_rows),
        ("report_only_years.csv", report_only_year_rows),
    ):
        if not rows:
            continue
        with (OUT_DIR / filename).open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)

    json_payload = {
        "year_summary": year_summary_rows,
        "report_only_years": report_only_year_rows,
        "report_reconciliation": reconciliation_rows,
        "top_bad_trades": bad_trades[:50],
        "top_bad_exits": bad_exits[:50],
    }
    with (OUT_DIR / "analysis_summary.json").open("w") as handle:
        json.dump(json_payload, handle, indent=2)

    lines: list[str] = []
    lines.append("# UltimateTrader Trade Audit")
    lines.append("")
    lines.append("## Coverage")
    lines.append("")
    lines.append("- Detailed trade lifecycle analysis: 2020 to 2025.")
    lines.append("- Report-only year: 2019.")
    lines.append("- Trade source of truth: `Logs/UltTrader_Stats_*.csv` EXIT rows.")
    lines.append("- Lifecycle source: `Logs/UltTrader_TradeEvents_*.csv`.")
    lines.append("- Setup context: `Logs/UltTrader_Candidates_*.csv` and `Logs/UltTrader_Risk_*.csv`.")
    lines.append("- Exit reconciliation: MT5 HTML reports in `reports/`.")
    lines.append("- Market path source: `GoldHistory/XAU_1m_data.csv` for trade scoring and `GoldHistory/XAU_15m_data.csv` for yearly regime stats.")
    lines.append("")
    lines.append("## Year Summary")
    lines.append("")
    lines.append("| Year | Gold Return | Report Net | Trades | Bad Entry | Bad Exit | Bad Trade | Avg Exit Score 24h | Avg Missed 24h R | Long / Short |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for row in year_summary_rows:
        lines.append(
            f"| {row['Year']} | {fmt_pct(row['GoldReturnPct'], 2)} | {fmt_num(row['ReportNetProfit'])} | {row['Trades']} | "
            f"{fmt_pct(row['BadEntryPct'])} | {fmt_pct(row['BadExitPct'])} | {fmt_pct(row['BadTradePct'])} | "
            f"{fmt_num(row['AvgExitScore24h'], 1)} | {fmt_num(row['AvgExitMissed24hR'], 2)} | {row['LongTrades']} / {row['ShortTrades']} |"
        )
    if report_only_year_rows:
        lines.append("")
        lines.append("2019 is excluded from the detailed table because the lifecycle logs are missing. It remains available in `report_only_years.csv`.")

    lines.append("")
    lines.append("## Global Findings")
    lines.append("")

    overall_bad_entry_pct = pct(sum(1 for item in all_trade_records if item["EntryGrade"] == "bad"), len(all_trade_records))
    overall_bad_exit_pct = pct(sum(1 for item in all_trade_records if item["ExitGrade"] == "bad"), len(all_trade_records))
    overall_bad_trade_pct = pct(sum(1 for item in all_trade_records if item["Verdict"] in {"bad_entry", "bad_exit", "bad_entry_bad_exit"}), len(all_trade_records))
    overall_runner_pct = pct(sum(1 for item in all_trade_records if item["RunnerManaged"]), len(all_trade_records))
    lines.append(f"- Detailed sample size is {len(all_trade_records)} closed trades from 2020 to 2025.")
    lines.append(f"- Across the detailed years, bad-entry trades are {fmt_pct(overall_bad_entry_pct)}, bad-exit trades are {fmt_pct(overall_bad_exit_pct)}, and any bad-trade verdict is {fmt_pct(overall_bad_trade_pct)}.")
    lines.append(f"- Runner-managed trades are {fmt_pct(overall_runner_pct)} of the detailed sample; `trade_audit_master.csv` now includes runner mode, promotion, and broker-trail cadence columns.")

    if strategy_summary_rows:
        worst_patterns = [
            row
            for row in sorted(
                [item for item in strategy_summary_rows if int(item["Trades"]) >= 8],
                key=lambda item: (
                    float(item["NetPnL"]),
                    -(float(item["BadTradePct"] or 0.0)),
                ),
            )
        ][:8]
        lines.append("- Weakest recurring patterns by net result and bad-trade rate:")
        for row in worst_patterns:
            lines.append(
                f"  - {row['Year']} | {row['Pattern']} | trades={row['Trades']} | net={fmt_num(row['NetPnL'])} | "
                f"avgR={fmt_num(row['AvgR'])} | bad-entry={fmt_pct(row['BadEntryPct'])} | bad-exit={fmt_pct(row['BadExitPct'])}"
            )

    if strategy_global_summary_rows:
        lines.append("- Weakest strategies across all detailed years:")
        weakest_global = sorted(
            [item for item in strategy_global_summary_rows if int(item["Trades"]) >= 8 and float(item["NetPnL"]) < 0],
            key=lambda item: (float(item["NetPnL"]), -float(item["BadTradePct"] or 0.0)),
        )[:8]
        for row in weakest_global:
            lines.append(
                f"  - {row['Pattern']} | trades={row['Trades']} | net={fmt_num(row['NetPnL'])} | "
                f"2024-2025={fmt_num(row['BullYearNetPnL_2024_2025'])} | 2020-2023={fmt_num(row['WeakYearsNetPnL_2020_2023'])} | "
                f"bad-entry={fmt_pct(row['BadEntryPct'])} | bad-exit={fmt_pct(row['BadExitPct'])}"
            )

    lines.append("")
    lines.append("## Exit / Management Findings")
    lines.append("")
    worst_exit_types = [
        row
        for row in sorted(
            [item for item in exit_summary_rows if int(item["Trades"]) >= 20],
            key=lambda item: (float(item["AvgExitScore24h"] or 50.0), -float(item["AvgMissed24hR"] or 0.0)),
        )
    ][:10]
    for row in worst_exit_types:
        lines.append(
            f"- {row['Year']} | exit={row['ReportExitType']} | trades={row['Trades']} | avg exit score 24h={fmt_num(row['AvgExitScore24h'], 1)} | "
            f"avg missed 24h={fmt_num(row['AvgMissed24hR'])}R | bad exits={fmt_pct(row['BadExitPct'])}"
        )
    if management_summary_rows:
        lines.append("- Management buckets:")
        for row in management_summary_rows[:6]:
            lines.append(
                f"  - {row['ManagementIssue']} | trades={row['Trades']} | net={fmt_num(row['NetPnL'])} | "
                f"avg exit score 24h={fmt_num(row['AvgExitScore24h'], 1)} | avg missed 24h={fmt_num(row['AvgExitMissed24hR'])}R"
            )

    lines.append("")
    lines.append("## Worst Trade Cases")
    lines.append("")
    for record in bad_trades[:25]:
        lines.append(build_case_line(record, "trade"))

    lines.append("")
    lines.append("## Worst Exit Cases")
    lines.append("")
    for record in bad_exits[:25]:
        lines.append(build_case_line(record, "exit"))

    lines.append("")
    lines.append("## Recommendations")
    lines.append("")
    lines.append("- Cut or heavily re-filter patterns that stay negative across multiple years and carry both high bad-entry and high bad-exit rates in `strategy_summary.csv`.")
    lines.append("- Separate entry failure from management failure. Trades with weak 24h follow-through are strategy-quality problems; trades with strong MFE but poor realized R are exit-management problems.")
    lines.append("- Focus on short setups in bullish gold regimes first. The audit explicitly tags countertrend short losses, which are a repeated drag in up years.")
    lines.append("- Review trades marked `premature_breakeven_on_good_trade`, `trailing_gave_back_large_move`, and `anti_stall_exit_left_large_move` before changing entries. These are management leaks, not signal leaks.")
    lines.append("- Use `bad_trades.csv` and `bad_exits.csv` as the case-review queue. They are already ranked by severity so the highest-value fixes come first.")

    with (OUT_DIR / "README.md").open("w") as handle:
        handle.write("\n".join(lines) + "\n")

    print(f"Wrote {OUT_DIR / 'README.md'}")
    print(f"Wrote {OUT_DIR / 'trade_audit_master.csv'}")
    print(f"Wrote {OUT_DIR / 'bad_trades.csv'}")
    print(f"Wrote {OUT_DIR / 'bad_exits.csv'}")
    print(f"Wrote {OUT_DIR / 'year_summary.csv'}")
    print(f"Wrote {OUT_DIR / 'strategy_summary.csv'}")
    print(f"Wrote {OUT_DIR / 'strategy_global_summary.csv'}")
    print(f"Wrote {OUT_DIR / 'exit_summary.csv'}")
    print(f"Wrote {OUT_DIR / 'management_summary.csv'}")
    print(f"Wrote {OUT_DIR / 'report_reconciliation.csv'}")
    print(f"Wrote {OUT_DIR / 'analysis_summary.json'}")


if __name__ == "__main__":
    main()
