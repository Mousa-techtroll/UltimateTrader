# UltimateTrader EA — Compile & Run Guide

## Paths

| Item | Path |
|------|------|
| **Source directory** | `/mnt/c/Trading/UltimateTrader/` |
| **MT5 Data directory** | `/mnt/c/Users/ahmed/AppData/Roaming/MetaQuotes/Terminal/010E047102812FC0C18890992854220E/` |
| **MT5 Experts target** | `<MT5_DATA>/MQL5/Experts/` |
| **MT5 Experts/Include target** | `<MT5_DATA>/MQL5/Experts/Include/` |
| **MetaEditor compiler** | `/mnt/c/Program Files/Vantage International MT5/MetaEditor64.exe` |
| **Build log** | `/mnt/c/Users/ahmed/mq5-build.log` |

## Step 1: Copy EA Files to MT5

The EA uses a relative `Include/` folder inside the Experts directory (confirmed: `MQL5/Experts/Include/` exists with all subfolders). Copy the main EA files and the entire Include tree, overwriting old versions.

```bash
# Variables
SRC="/mnt/c/Trading/UltimateTrader"
DST="/mnt/c/Users/ahmed/AppData/Roaming/MetaQuotes/Terminal/010E047102812FC0C18890992854220E/MQL5/Experts"

# Copy main EA file + inputs header (overwrite)
cp -f "$SRC/UltimateTrader.mq5" "$DST/"
cp -f "$SRC/UltimateTrader_Inputs.mqh" "$DST/"

# Copy entire Include tree (overwrite, preserve structure)
cp -rf "$SRC/Include/"* "$DST/Include/"
```

### One-liner version:
```bash
SRC="/mnt/c/Trading/UltimateTrader" && DST="/mnt/c/Users/ahmed/AppData/Roaming/MetaQuotes/Terminal/010E047102812FC0C18890992854220E/MQL5/Experts" && cp -f "$SRC/UltimateTrader.mq5" "$SRC/UltimateTrader_Inputs.mqh" "$DST/" && cp -rf "$SRC/Include/"* "$DST/Include/"
```

## Step 2: Compile

MetaEditor must be called with Windows-style paths (even from WSL, the .exe expects backslash paths).

```bash
# Find MetaEditor (run once, note the path)
find /mnt/c -name "metaeditor64.exe" 2>/dev/null

# Compile (adjust METAEDITOR path as needed)
METAEDITOR="/mnt/c/Program Files/MetaTrader 5/metaeditor64.exe"

"$METAEDITOR" \
  /compile:"C:\Users\Ahmed\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E\MQL5\Experts\UltimateTrader.mq5" \
  /log:"C:\Users\ahmed\mq5-build.log" \
  /inc:"C:\Users\Ahmed\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E\MQL5"
```

## Step 3: Check Build Log

```bash
cat "/mnt/c/Users/ahmed/mq5-build.log"
```

Look for:
- `0 error(s)` = success
- Any `error` lines = fix needed (file:line format)
- `warning` lines = review but usually safe

## Step 4: Verify .ex5 Was Produced

```bash
ls -la "/mnt/c/Users/ahmed/AppData/Roaming/MetaQuotes/Terminal/010E047102812FC0C18890992854220E/MQL5/Experts/UltimateTrader.ex5"
```

The timestamp should match the compile time.

## Step 5: Run Backtest

1. Open MetaTrader 5
2. Strategy Tester (Ctrl+R)
3. Select: `UltimateTrader` EA
4. Symbol: `XAUUSD` (or broker-specific variant)
5. Period: H1
6. Date range: 2025.03.22 to 2026.03.22 (match original backtest)
7. Modeling: Every tick based on real ticks (preferred) or Every tick
8. Initial deposit: Same as original ($10,000 or as used)
9. Run

## Quick Reference: Full Deploy Command

```bash
# Deploy + Compile (paste as one block)
SRC="/mnt/c/Trading/UltimateTrader"
DST="/mnt/c/Users/ahmed/AppData/Roaming/MetaQuotes/Terminal/010E047102812FC0C18890992854220E/MQL5/Experts"
METAEDITOR="/mnt/c/Program Files/MetaTrader 5/metaeditor64.exe"

echo "=== Copying files ===" && \
cp -f "$SRC/UltimateTrader.mq5" "$SRC/UltimateTrader_Inputs.mqh" "$DST/" && \
cp -rf "$SRC/Include/"* "$DST/Include/" && \
echo "=== Compiling ===" && \
"$METAEDITOR" \
  /compile:"C:\Users\Ahmed\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E\MQL5\Experts\UltimateTrader.mq5" \
  /log:"C:\Users\ahmed\mq5-build.log" \
  /inc:"C:\Users\Ahmed\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E\MQL5" && \
echo "=== Build log ===" && \
cat "/mnt/c/Users/ahmed/mq5-build.log"
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `metaeditor64.exe` not found | Open MetaTrader 5 GUI, go to Help > About, note the install path. Or search: `find /mnt/c -name "metaeditor64.exe" 2>/dev/null` |
| `cannot open file` in build log | Include path wrong. Ensure `/inc:` points to the MQL5 root (parent of Experts and Include) |
| `undeclared identifier` | Missing include or circular dependency. Check the specific file:line in the error |
| `.ex5` not updated | MetaTrader may lock the file if running. Close the EA/chart first, recompile |
| WSL can't run .exe | Ensure WSL2 interop is enabled: `echo 1 > /proc/sys/fs/binfmt_misc/WSLInterop` or run from PowerShell/cmd instead |
