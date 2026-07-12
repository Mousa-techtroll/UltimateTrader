#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_manual_constants.py  -- Phase-0 field-manual constant generator.

Deterministically derives the numeric constants that the hand-written
"field manual" (workflowAnalysis/ea-book/*.html + how-this-ea-works.md)
cites, directly from the EA configuration, so the docs stop being
hand-maintained.

Sources of truth (in priority order):
  1. UltimateTrader_Inputs.mqh          -- primary `input`/`sinput` decls
  2. Include/**/*.mqh + UltimateTrader.mq5 -- stray `input` decls elsewhere
  3. risk_R90.ini [TesterInputs]        -- config-of-record overrides
  4. curated code literals (grep-resolved file:line) for manual-cited
     numbers that are NOT inputs (session Asia x1.0, counter-trend x0.5,
     the x0.90 tier renorm note).

Emits:
  workflowAnalysis/ea-book/manual-constants.json
  workflowAnalysis/ea-book/manual-constants.md

Python stdlib only. No network. Idempotent (byte-stable output).

Usage:  python3 claude/gate/gen_manual_constants.py
"""

import json
import os
import re
import sys

# ---------------------------------------------------------------------------
# Paths (resolved relative to the repo root = two levels up from this file).
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))

INPUTS_MQH = os.path.join(REPO_ROOT, "UltimateTrader_Inputs.mqh")
MAIN_MQ5 = os.path.join(REPO_ROOT, "UltimateTrader.mq5")
INCLUDE_DIR = os.path.join(REPO_ROOT, "Include")
INI_PATH = (
    "/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/"
    "725B72F25E46C780EF59F57016D58156/risk_R90.ini"
)

OUT_JSON = os.path.join(REPO_ROOT, "workflowAnalysis", "ea-book", "manual-constants.json")
OUT_MD = os.path.join(REPO_ROOT, "workflowAnalysis", "ea-book", "manual-constants.md")

# ---------------------------------------------------------------------------
# 1. Input-declaration parser.
# ---------------------------------------------------------------------------
# Matches: [s]input <type> <Name> = <default>;   // <inline comment>
# Deliberately anchored at line start so commented-out ("// input ...")
# declarations do NOT match.
INPUT_RE = re.compile(
    r"^\s*s?input\s+"
    r"([A-Za-z_]\w*)\s+"              # 1: type
    r"([A-Za-z_]\w*)\s*=\s*"         # 2: name
    r"(.+?)\s*;"                      # 3: default (up to first ;)
    r"\s*(?://\s*(.*))?$"             # 4: optional inline comment
)
GROUP_RE = re.compile(r'^\s*s?input\s+group\s+"(.*?)"')
DECOR_RE = re.compile(r"[═=]+")  # strip the decorative group underline


def _clean_group(raw):
    return DECOR_RE.sub("", raw).strip()


def _coerce(type_str, raw_val):
    """Return a JSON-friendly typed value for a raw MQL default/ini token."""
    v = raw_val.strip()
    low = v.lower()
    if low in ("true", "false"):
        return low == "true"
    # strip a trailing MQL string
    if v.startswith('"') and v.endswith('"'):
        return v[1:-1]
    # enums / identifiers stay as strings
    try:
        if re.fullmatch(r"[-+]?\d+", v):
            return int(v)
        f = float(v)
        return f
    except ValueError:
        return v


def parse_inputs(paths):
    """Parse every active input decl across `paths` (first decl of a name wins).

    Returns dict name -> {type, default, comment, group, source_file, source_line}.
    """
    inputs = {}
    for path in paths:
        if not os.path.isfile(path):
            continue
        rel = os.path.relpath(path, REPO_ROOT)
        cur_group = ""
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for lineno, line in enumerate(fh, start=1):
                gm = GROUP_RE.match(line)
                if gm:
                    cur_group = _clean_group(gm.group(1))
                    continue
                m = INPUT_RE.match(line)
                if not m:
                    continue
                type_str, name, default, comment = m.groups()
                if name in inputs:
                    continue  # first declaration (primary file) wins
                inputs[name] = {
                    "type": type_str,
                    "default": _coerce(type_str, default),
                    "default_raw": default.strip(),
                    "comment": (comment or "").strip(),
                    "group": cur_group,
                    "source_file": rel,
                    "source_line": lineno,
                }
    return inputs


def _iter_include_mqh():
    if not os.path.isdir(INCLUDE_DIR):
        return
    for root, _dirs, files in os.walk(INCLUDE_DIR):
        for fn in sorted(files):
            if fn.endswith(".mqh"):
                yield os.path.join(root, fn)


# ---------------------------------------------------------------------------
# 2. Config-of-record (.ini [TesterInputs]) parser.
# ---------------------------------------------------------------------------
def parse_ini(path):
    """Parse the `Name=value` lines under [TesterInputs]. Graceful on failure."""
    if not os.path.isfile(path):
        return None, "ini not found"
    try:
        overrides = {}
        in_section = False
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                s = line.strip()
                if not s or s.startswith(";"):
                    continue
                if s.startswith("["):
                    in_section = s.lower().startswith("[testerinputs]")
                    continue
                if in_section and "=" in s:
                    k, _, val = s.partition("=")
                    overrides[k.strip()] = val.strip()
        return overrides, None
    except OSError as exc:
        return None, "ini unreadable: %s" % exc


# ---------------------------------------------------------------------------
# 3. Manifest specification.
#    Each entry maps a book-cited constant to its source (an input name, or a
#    grep-resolved code literal). Input-backed rows resolve their value/line
#    from the parsed inputs; literal rows carry value + file:line inline.
#    book_ref = (chapter file, quoted prose phrase) for the mapping note.
# ---------------------------------------------------------------------------
SPEC = [
    # ---- risk_tiers ------------------------------------------------------
    dict(key="risk_a_plus", section="risk_tiers", input="InpRiskAPlusSetup",
         unit="%", book=("04-gauntlet.html", "A+ Top-grade setup 1.35%"),
         note="Per-trade base risk for A+ setups (post x0.90 renorm)."),
    dict(key="risk_a", section="risk_tiers", input="InpRiskASetup",
         unit="%", book=("04-gauntlet.html", "A Strong setup 0.90%"),
         note="Per-trade base risk for A setups (post x0.90 renorm)."),
    dict(key="risk_b_plus", section="risk_tiers", input="InpRiskBPlusSetup",
         unit="%", book=("04-gauntlet.html", "grade table B+ 0.675%"),
         note="Per-trade base risk for B+ setups (post x0.90 renorm)."),
    dict(key="risk_b", section="risk_tiers", input="InpRiskBSetup",
         unit="%", book=("04-gauntlet.html", "grade table B 0.54%"),
         note="Per-trade base risk for B setups (post x0.90 renorm)."),
    dict(key="tier_renorm_factor", section="risk_tiers", literal=True,
         value=0.90, unit="x",
         source_file="UltimateTrader_Inputs.mqh", source_line=54,
         book=("05-sizing.html", "base tiers x0.90 renorm"),
         note="Documentation-only derivation factor (Inputs.mqh:50-54 ACTION-3b "
              "note): base tiers 1.5/1.0/0.75/0.6 x 0.90 = the live tier inputs "
              "above. Not a live code literal; the post-renorm tiers ARE the inputs."),
    dict(key="tier_base_pre_renorm", section="risk_tiers", literal=True,
         value="1.5/1.0/0.75/0.6", unit="%",
         source_file="UltimateTrader_Inputs.mqh", source_line=54,
         book=("05-sizing.html", "base tiers x0.90 renorm"),
         note="Pre-renorm base tier ladder cited in the Inputs.mqh ACTION-3b "
              "comment ('Old values 1.5/1.0/0.75/0.6')."),

    # ---- sizing_dials ----------------------------------------------------
    dict(key="regime_mult_trending", section="sizing_dials", input="InpRegimeRiskTrending",
         unit="x", book=("05-sizing.html", "Trending x1.25"),
         note="Risk multiplier applied in the TRENDING 4h regime."),
    dict(key="regime_mult_normal", section="sizing_dials", input="InpRegimeRiskNormal",
         unit="x", book=("05-sizing.html", "Ranging ~=x1.0"),
         note="NORMAL regime multiplier; RANGING falls through to this (~x1.0)."),
    dict(key="regime_mult_volatile", section="sizing_dials", input="InpRegimeRiskVolatile",
         unit="x", book=("05-sizing.html", "Volatile x0.75"),
         note="Risk multiplier applied in the VOLATILE 4h regime."),
    dict(key="regime_mult_choppy", section="sizing_dials", input="InpRegimeRiskChoppy",
         unit="x", book=("05-sizing.html", "Choppy x0.60"),
         note="Risk multiplier applied in the CHOPPY 4h regime."),
    dict(key="atr_velocity_risk_mult", section="sizing_dials", input="InpATRVelocityRiskMult",
         unit="x", book=("05-sizing.html", "ATR acceleration size boost"),
         note="Risk multiplier when ATR is accelerating past InpATRVelocityBoostPct."),
    dict(key="counter_trend_ema_mult", section="sizing_dials", literal=True,
         value=0.5, unit="x",
         source_file="Include/Core/CTradeOrchestrator.mqh", source_line=599,
         book=("05-sizing.html", "opposes the hourly 200-EMA ... x0.50"),
         note="Hard-coded literal: risk halved when trade direction opposes the "
              "H1 200-EMA vs live price (CTradeOrchestrator.mqh:599-600)."),

    # ---- chandelier ------------------------------------------------------
    dict(key="chandelier_trend", section="chandelier", input="InpRegExitTrendChand",
         unit="xATR", book=("06-exits.html", "Trend clean staircase x4.2"),
         note="Chandelier trailing-stop ATR multiplier, TRENDING regime profile."),
    dict(key="chandelier_normal", section="chandelier", input="InpRegExitNormalChand",
         unit="xATR", book=("06-exits.html", "Normal ordinary / ranging x3.6"),
         note="Chandelier trailing-stop ATR multiplier, NORMAL regime profile."),
    dict(key="chandelier_volatile", section="chandelier", input="InpRegExitVolChand",
         unit="xATR", book=("06-exits.html", "Volatile big fast lurches x3.6"),
         note="Chandelier trailing-stop ATR multiplier, VOLATILE regime profile."),
    dict(key="chandelier_choppy", section="chandelier", input="InpRegExitChoppyChand",
         unit="xATR", book=("06-exits.html", "Choppy messy fakeouts x3.0"),
         note="Chandelier trailing-stop ATR multiplier, CHOPPY regime profile."),
    dict(key="chandelier_fallback", section="chandelier", input="InpTrailChandelierMult",
         unit="xATR", book=("06-exits.html", "chandelier cushion (fallback)"),
         note="Global chandelier fallback multiplier; per-regime profiles override it."),

    # ---- tp_ladder -------------------------------------------------------
    dict(key="tp0_distance_R", section="tp_ladder", input="InpTP0Distance",
         unit="R", book=("06-exits.html", "nibbles 15% at +0.7R"),
         note="TP0 early-partial distance in R-multiples."),
    dict(key="tp0_volume_pct", section="tp_ladder", input="InpTP0Volume",
         unit="%", book=("06-exits.html", "nibbles 15% at +0.7R"),
         note="TP0 close fraction (% of position)."),
    dict(key="tp1_distance_R", section="tp_ladder", input="InpTP1Distance",
         unit="R", book=("06-exits.html", "banks 40% at +1.3R"),
         note="TP1 distance in R-multiples (matches NORMAL regime TP1)."),
    dict(key="tp1_volume_pct", section="tp_ladder", input="InpTP1Volume",
         unit="%", book=("06-exits.html", "banks 40% at +1.3R (close ~40%)"),
         note="TP1 close fraction (~40% of remaining)."),
    dict(key="tp2_distance_R", section="tp_ladder", input="InpTP2Distance",
         unit="R", book=("06-exits.html", "another 30% at +1.8R"),
         note="TP2 distance in R-multiples (matches NORMAL regime TP2)."),
    dict(key="tp2_volume_pct", section="tp_ladder", input="InpTP2Volume",
         unit="%", book=("06-exits.html", "another 30% at +1.8R (close ~30%)"),
         note="TP2 close fraction (~30% of remaining); rest rides the runner."),
    dict(key="break_even_trigger_R", section="tp_ladder", input="InpTrailBETrigger",
         unit="R", book=("06-exits.html", "+0.8R Break-even"),
         note="Break-even trigger in R (global; per-regime BE profiles can override, "
              "e.g. NORMAL InpRegExitNormalBE=1.0)."),

    # ---- gauntlet_thresholds --------------------------------------------
    dict(key="min_rr_ratio", section="gauntlet_thresholds", input="InpMinRRRatio",
         unit="ratio", book=("04-gauntlet.html", "ratio must be >= 1.3"),
         note="Reward:risk gate; reject below this."),
    dict(key="min_sl_to_spread_ratio", section="gauntlet_thresholds", input="InpMinSLToSpreadRatio",
         unit="x", book=("04-gauntlet.html", "the trade's stop (SL >= 3x spread)"),
         note="Entry-sanity gate: reject if SL distance < N x live spread "
              "(reader UltimateTrader.mq5:2453-2463)."),
    dict(key="max_spread_points", section="gauntlet_thresholds", input="InpMaxSpreadPoints",
         unit="points", book=("04-gauntlet.html", "max-spread setting, 50 points on gold"),
         note="Hard spread ceiling; reject entry above it."),
    dict(key="confirmation_window_bars", section="gauntlet_thresholds", input="InpConfirmationWindowBars",
         unit="bars", book=("04-gauntlet.html", "the one-hour confirmation"),
         note="Confirmation candle wait window in H1 bars (1 = the one-bar wait)."),
    dict(key="min_pattern_confidence", section="gauntlet_thresholds", input="InpMinPatternConfidence",
         unit="score", book=("04-gauntlet.html", "confidence scoring gate"),
         note="Minimum pattern confidence score to survive the confidence gate."),
    dict(key="points_a_plus", section="gauntlet_thresholds", input="InpPointsAPlusSetup",
         unit="points", book=("04-gauntlet.html", "grade table (A+ tier)"),
         note="Confluence-point threshold to grade a setup A+."),
    dict(key="points_a", section="gauntlet_thresholds", input="InpPointsASetup",
         unit="points", book=("04-gauntlet.html", "grade table (A tier)"),
         note="Confluence-point threshold to grade a setup A."),
    dict(key="points_b_plus", section="gauntlet_thresholds", input="InpPointsBPlusSetup",
         unit="points", book=("04-gauntlet.html", "grade table (B+ tier)"),
         note="Confluence-point threshold to grade a setup B+."),
    dict(key="points_b", section="gauntlet_thresholds", input="InpPointsBSetup",
         unit="points", book=("04-gauntlet.html", "grade table (B tier)"),
         note="Confluence-point threshold to grade a setup B (7 = same as A)."),

    # ---- caps ------------------------------------------------------------
    dict(key="max_positions", section="caps", input="InpMaxPositions",
         unit="count", book=("04-gauntlet.html", "at most five trades at once"),
         note="Max concurrent open positions."),
    dict(key="max_risk_per_trade", section="caps", input="InpMaxRiskPerTrade",
         unit="%", book=("05-sizing.html", "<= 2% Most the account can lose on any one trade"),
         note="Hard per-trade risk cap; clamped twice (sizing + pre-send)."),
    dict(key="daily_loss_limit", section="caps", input="InpDailyLossLimit",
         unit="%", book=("05-sizing.html", "-3% Daily-loss halt"),
         note="Daily loss limit; halts new trades for the day."),
    dict(key="max_total_exposure", section="caps", input="InpMaxTotalExposure",
         unit="%", book=("05-sizing.html", "<= 5% Combined risk across all open trades"),
         note="Aggregate open-risk cap across all live + candidate positions."),
    dict(key="max_trades_per_day", section="caps", input="InpMaxTradesPerDay",
         unit="count", book=("04-gauntlet.html", "daily trade budget"),
         note="Max new trades initiated per day."),

    # ---- sessions --------------------------------------------------------
    dict(key="session_london_mult", section="sessions", input="InpLondonRiskMultiplier",
         unit="x", book=("05-sizing.html", "London x0.50"),
         note="London-session (GMT 8-13) risk multiplier."),
    dict(key="session_ny_mult", section="sessions", input="InpNewYorkRiskMultiplier",
         unit="x", book=("05-sizing.html", "New York x0.90"),
         note="New-York-session (GMT 13-21) risk multiplier."),
    dict(key="session_asia_mult", section="sessions", literal=True,
         value=1.0, unit="x",
         source_file="UltimateTrader.mq5", source_line=2388,
         book=("05-sizing.html", "Asia x1.0"),
         note="Hard-coded literal: Asia session (GMT 21-8) keeps the x1.0 default "
              "session_mult (UltimateTrader.mq5:2388, comment :2400). No Asia input."),
]


# ---------------------------------------------------------------------------
# 4. Resolve the manifest against parsed inputs + ini.
# ---------------------------------------------------------------------------
SECTION_ORDER = [
    "risk_tiers", "sizing_dials", "chandelier", "tp_ladder",
    "gauntlet_thresholds", "caps", "sessions",
]


def resolve(inputs, overrides):
    sections = {s: {} for s in SECTION_ORDER}
    unresolved = []

    for spec in SPEC:
        key = spec["key"]
        section = spec["section"]
        unit = spec.get("unit", "")
        note = spec.get("note", "")
        book_chap, book_phrase = spec["book"]

        if spec.get("literal"):
            val = spec["value"]
            entry = {
                "value": val,
                "source_default": val,
                "config_of_record": val,
                "input_name_or_literal": "literal",
                "source_file": spec["source_file"],
                "source_line": spec["source_line"],
                "unit": unit,
                "note": note,
                "book_chapter": book_chap,
                "book_phrase": book_phrase,
            }
            sections[section][key] = entry
            continue

        name = spec["input"]
        info = inputs.get(name)
        if info is None:
            unresolved.append({
                "constant_key": key,
                "section": section,
                "input_name": name,
                "search_location": "grep -rn '%s' UltimateTrader_Inputs.mqh Include "
                                   "UltimateTrader.mq5" % name,
                "note": "Input declaration not found by the parser. %s" % note,
            })
            continue

        src_default = info["default"]
        cor_raw = overrides.get(name) if overrides else None
        if cor_raw is not None:
            cor_val = _coerce(info["type"], cor_raw)
        else:
            cor_val = src_default  # config-of-record falls back to source default

        entry = {
            "value": cor_val,
            "source_default": src_default,
            "config_of_record": cor_val,
            "config_of_record_from_ini": cor_raw is not None,
            "differs_from_default": (cor_val != src_default),
            "input_name_or_literal": name,
            "source_file": info["source_file"],
            "source_line": info["source_line"],
            "unit": unit,
            "note": note,
            "book_chapter": book_chap,
            "book_phrase": book_phrase,
        }
        sections[section][key] = entry

    return sections, unresolved


# ---------------------------------------------------------------------------
# 5. Emit JSON + MD.
# ---------------------------------------------------------------------------
def _fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        # trim trailing zeros but keep at least one decimal
        s = ("%f" % v).rstrip("0").rstrip(".")
        return s if s else "0"
    return str(v)


def write_json(sections, unresolved, meta, path):
    payload = {
        "_meta": meta,
        "sections": sections,
        "unresolved": unresolved,
    }
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2, ensure_ascii=True, sort_keys=False)
        fh.write("\n")


def write_md(sections, unresolved, meta, path):
    L = []
    L.append("# Field-Manual Constants Manifest")
    L.append("")
    L.append("> Auto-generated by `claude/gate/gen_manual_constants.py`. "
             "Do NOT hand-edit. Re-run the generator to refresh.")
    L.append("")
    L.append("This manifest derives every numeric constant the field manual "
             "(`workflowAnalysis/ea-book/*.html` + `how-this-ea-works.md`) cites, "
             "directly from `UltimateTrader_Inputs.mqh`, the config-of-record ini, "
             "and grep-resolved code literals. A later pass can diff the book's "
             "prose against the values below.")
    L.append("")
    L.append("- **Inputs parsed:** %d  (primary file: %d)" %
             (meta["inputs_parsed"], meta["inputs_from_primary"]))
    L.append("- **Manual constants resolved:** %d" % meta["resolved"])
    L.append("- **Unresolved:** %d" % meta["unresolved"])
    L.append("- **Config-of-record:** `%s`  (%s)" %
             (meta["ini_basename"], meta["ini_status"]))
    L.append("")

    # ---- mapping note ----------------------------------------------------
    L.append("## Book-to-constant mapping")
    L.append("")
    L.append("Which book chapter + prose phrase maps to which `constant_key`. "
             "Use this to wire/verify the docs against the manifest.")
    L.append("")
    L.append("| Book chapter | Cited phrase | constant_key | section |")
    L.append("|---|---|---|---|")
    for section in SECTION_ORDER:
        for key, e in sections[section].items():
            L.append("| %s | %s | `%s` | %s |" % (
                e["book_chapter"],
                e["book_phrase"].replace("|", "\\|"),
                key, section))
    L.append("")

    # ---- main table ------------------------------------------------------
    L.append("## Resolved constants")
    L.append("")
    L.append("| section | constant_key | value | source_default | "
             "config_of_record | input / literal | source | unit | note |")
    L.append("|---|---|---|---|---|---|---|---|---|")
    for section in SECTION_ORDER:
        for key, e in sections[section].items():
            src = "%s:%s" % (e["source_file"], e["source_line"])
            flag = ""
            if e.get("differs_from_default"):
                flag = " **[COR!=default]**"
            L.append("| %s | `%s` | %s | %s | %s%s | %s | `%s` | %s | %s |" % (
                section, key,
                _fmt(e["value"]),
                _fmt(e["source_default"]),
                _fmt(e["config_of_record"]), flag,
                e["input_name_or_literal"],
                src, e["unit"],
                e["note"].replace("|", "\\|")))
    L.append("")

    # ---- unresolved ------------------------------------------------------
    L.append("## Unresolved")
    L.append("")
    if not unresolved:
        L.append("_None — every manual-cited constant resolved from source or "
                 "config._")
    else:
        L.append("| constant_key | section | input_name | search_location | note |")
        L.append("|---|---|---|---|---|")
        for u in unresolved:
            L.append("| `%s` | %s | %s | `%s` | %s |" % (
                u["constant_key"], u["section"], u.get("input_name", ""),
                u["search_location"], u["note"].replace("|", "\\|")))
    L.append("")

    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(L))


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main():
    scan_paths = [INPUTS_MQH] + sorted(_iter_include_mqh()) + [MAIN_MQ5]
    inputs = parse_inputs(scan_paths)
    inputs_from_primary = sum(
        1 for i in inputs.values()
        if i["source_file"] == os.path.relpath(INPUTS_MQH, REPO_ROOT)
    )

    overrides, ini_err = parse_ini(INI_PATH)
    if overrides is None:
        ini_status = "unreadable -> config-of-record = source default (%s)" % ini_err
        overrides = {}
    else:
        ini_status = "%d override keys parsed" % len(overrides)

    # ini keys that have no declaration among scanned files (informational)
    orphan_ini = sorted(k for k in overrides if k not in inputs)

    sections, unresolved = resolve(inputs, overrides)
    resolved = sum(len(sections[s]) for s in SECTION_ORDER)

    meta = {
        "generator": "claude/gate/gen_manual_constants.py",
        "primary_input_file": os.path.relpath(INPUTS_MQH, REPO_ROOT),
        "ini_basename": os.path.basename(INI_PATH),
        "ini_status": ini_status,
        "inputs_parsed": len(inputs),
        "inputs_from_primary": inputs_from_primary,
        "resolved": resolved,
        "unresolved": len(unresolved),
        "ini_override_keys": len(overrides),
        "ini_orphan_keys_no_decl": orphan_ini,
    }

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    write_json(sections, unresolved, meta, OUT_JSON)
    write_md(sections, unresolved, meta, OUT_MD)

    print("gen_manual_constants: %d inputs parsed (%d from %s), "
          "%d manual-constants resolved, %d unresolved." % (
              meta["inputs_parsed"], meta["inputs_from_primary"],
              meta["primary_input_file"], meta["resolved"], meta["unresolved"]))
    print("  config-of-record: %s (%s)" % (meta["ini_basename"], ini_status))
    if orphan_ini:
        print("  note: %d ini keys have no decl in scanned files (declared "
              "elsewhere / renamed): %s%s" % (
                  len(orphan_ini), ", ".join(orphan_ini[:6]),
                  " ..." if len(orphan_ini) > 6 else ""))
    print("  wrote: %s" % os.path.relpath(OUT_JSON, REPO_ROOT))
    print("  wrote: %s" % os.path.relpath(OUT_MD, REPO_ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
