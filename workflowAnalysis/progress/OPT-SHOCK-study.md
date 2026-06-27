# OPT-SHOCK — STUDY (execution log) — shock-detector [0]→[1] + ATR-denom fix, A/B + C0

**Binding spec:** `OPT-SHOCK-DESIGN.md` (stok). **Root cause:** `OPT-SHOCK-rootcause.md`.
**In-tree:** `/mnt/c/Trading/UltimateTrader`, branch `feat/multi-strategy`, committed HEAD `ae7428c`.
**Env:** Model=4 (real ticks), XAUUSD+ H1, clean state per run, deposit 10000 USD / leverage 100. SYNCHRONOUS, one terminal job.
**Readout method (OPT-1/2/3 canonical):** Net/PF/Sharpe/Eq-DD/Bal-DD/Trades = tester report HTM headline. Positions + avg-R = `Common/Files/UltTrader_TradeEvents_XAUUSD+_<FROMID>_0000.csv` (col7=EXIT_FILL count = positions; col27=CurrentR mean = avg-R; col26=CSV net). Firing counts = grep `[ShockDetector]` / `[ShockGate]` / `[ShockBlockProbe]` from the per-run agent-log slice.

**Slices:** FIT 2019.01.01→2022.12.31 · CONFIRM 2023.01.01→2026.06.27 · FULL 2019.01.01→2026.06.27.
**C0-FULL on file (NOT a run):** $20,069.23 / PF 1.29 / Sharpe 2.14 / Eq-DD 13.97% / Bal-DD 11.92% / avg-R 0.169 / 928 pos.
**C0-FIT sanity target (must reproduce):** $2,453.21 / PF 1.12 / Sharpe 1.02 / Eq-DD 18.31% / Bal-DD 16.73% / avg-R 0.0820 / 448 pos.

---

## 1. THE THREE CONFIGS / ARM EDITS

- **C0** = committed HEAD `ae7428c` (spread-only; bar/M5 legs degenerate-0.00). Binary `UltimateTrader_SHOCKC0.ex5`.
- **Arm A** = correctness fix in `Include/Execution/CEnhancedTradeExecutor.mqh::DetectShock`:
  - new private helper `GetClosedATR(tf, period=14)` — handle-free closed-bar TR average (mirrors `CMarketContext::GetATRVelocity` 643-663).
  - H1 leg: `iHigh/iLow(PERIOD_H1, 0)` → `(...,1)`; denominator `atr_h1` → `h1_atr = GetClosedATR(PERIOD_H1,14)`.
  - M5 leg: `iHigh/iLow(PERIOD_M5, 0)` → `(...,1)`; denominator → same `h1_atr` (intentional M5/H1 ratio per §1c).
  - guard `if(h1_atr <= 0) return state;`. Thresholds 3.0/2.0/0.8/0.5 UNCHANGED. EXTREME logic UNCHANGED (range/M5/spread EXTREME all → hard block). Binary `UltimateTrader_SHOCKA.ex5`.
- **Arm B** = Arm A + EXTREME-demotion in the classify block: range_ratio>3.0 OR m5_ratio>0.8 → MODERATE 50% down-size path (is_shock=true, intensity=1.0 → shock_factor 0.5) INSTEAD of is_extreme; ONLY spread_ratio>3.0 keeps is_extreme (hard block). Binary `UltimateTrader_SHOCKB.ex5`.

### md5s (load==fresh asserted per arm; ALL THREE DISTINCT — A≠B≠C0 verified)
| Arm | binary | md5 (load-path == fresh) |
|---|---|---|
| C0 | `UltimateTrader_SHOCKC0.ex5` (pristine HEAD ae7428c) | `4ed2e8ca94b0a9c661374783b59d7eb5` |
| A  | `UltimateTrader_SHOCKA.ex5` | `065d0ea92df44ce6b7f5c672862ff445` |
| B  | `UltimateTrader_SHOCKB.ex5` | `c320c4f6643e6007c7832884cf62f35b` |

C0 built from pristine `git checkout HEAD -- CEnhancedTradeExecutor.mqh` (only tracked source diff was my A/B shock edits; tree otherwise clean vs HEAD — matches OPT-3 "tracked tree clean" provenance), then working tree restored to A/B version.

### Compile results (all 0-err / 16-warn = baseline; my added GetClosedATR introduced NO new warnings)
| Arm | Result line |
|---|---|
| A  | `Result: 0 errors, 16 warnings, 8299 ms` |
| B  | `Result: 0 errors, 16 warnings, 8135 ms` |
| C0 | `Result: 0 errors, 16 warnings, 8669 ms` |

---

## 2. NON-ZERO-RATIO SANITY (HARD GATE — first Arm-A run) — **PASS**

**C0-FIT firing signature (bug baseline — spread-only):** bar_range_ratio = 0.00 and m5_range_ratio = 0.00 on **0/2452** firings; only spread live. 1863 EXTREME hard-blocks ALL spread-driven (max spread 248). Exactly the root-cause signature.

**Arm A-FIT firing signature (fix took effect):** bar_range_ratio **NON-ZERO on 4557/4557** firings, m5_range_ratio NON-ZERO on **4553/4557**. Live sample values: BarRange/ATR = 1.16 / 0.85 / 2.18 / 2.10 / 1.98; M5/ATR = 0.68 / 0.49 / 0.53 / 0.45 / 0.54; max bar 7.06, max M5 3.69. **The dead legs are now LIVE → sanity GATE PASSED, study proceeds.**

(Decode note: MT5 tester agent-log rotates/truncates mid-study, so byte-offset slicing under-reads; firing counts re-extracted rotation-robustly by filtering the agent log on the per-arm Expert tag `UltimateTrader_SHOCK<arm>`. TradeEvents CSV is snapshotted per-run to `shock_csv/TE_<TAG>.csv` because its symbol+start-date filename key is shared across runs.)

---

## 3. FIT TABLE (2019–2022, deltas vs C0-FIT)

C0-FIT (binary-provenance sanity — **reproduces OPT-2/3 C0-FIT cell to the cent**):
**Net $2,453.21 / PF 1.12 / Sharpe 1.02 / Eq-DD 18.31% / Bal-DD 16.73% / avg-R 0.0820 / 448 pos** (832 trades). PASS.

| Cfg | Net $ | ΔNet% vs C0 | PF | Sharpe | Eq-DD | Bal-DD | avg-R | Pos |
|---|---|---|---|---|---|---|---|---|
| C0 | 2,453.21 | — | 1.12 | 1.02 | 18.31% | 16.73% | 0.0820 | 448 |
| A  | 2,448.62 | **−0.19%** | 1.13 | 1.07 | 18.03% | 16.33% | 0.0808 | 430 |
| B  | 2,583.04 | **+5.29%** | 1.13 | 1.08 | 18.49% | 16.84% | 0.0820 | 448 |

### Firing counts by leg × tier (per arm, FIT)
**C0:** firings 2452 (EXTREME 1863 / MOD 589). bar MOD 0 / EXT 0; spread MOD 589 / EXT 1862; M5 MOD 0 / EXT 0. Gate EXTREME 1863, Moderate 589. (bar/M5 dead — the bug.)
**A:** firings 4557 (distinct bars EXTREME 2282 / MOD 2275). bar MOD 1058 / EXT 232; spread MOD 593 / EXT 1843; M5 MOD 1291 / EXT 293. **Gate EXTREME 2282, Moderate 2275.**
**B:** firings 4573 (distinct bars EXTREME 1864 / MOD 2709). bar MOD 1057 / EXT 233; spread MOD 589 / EXT 1863; M5 MOD 1290 / EXT 294. **Gate EXTREME 1864 (= spread-EXTREME only), Moderate 2709.** The arm difference is exact: B's EXTREME blocks (1864) ≈ C0's spread blocks (1863); A's extra ~418 EXTREME blocks (2282−1864) are the range/M5-EXTREME hard-blocks that B demotes to 50% down-sizes (hence B's +434 Moderate down-sizes).

### Arm-A amputation probe (blocked-bar → next-H1 up-continuation)
Joined each EXTREME-block bar-time against H1 OHLC (`GoldHistory/XAU_1h_data.csv`; generic-XAU TZ caveat — directional corroboration only).
- **A (all 2282 EXTREME blocks, 2261 matched):** next-bar UP 51.8% / DOWN 47.9%, mean block-bar return **+0.0051%** — essentially **direction-neutral** (mostly the 1843 spread blocks, which ARE direction-agnostic by design §2b). No strong up-continuation-amputation signature.
- **The 440 range/M5-EXTREME bars A blocks but B demotes (439 matched):** UP 51.0% (mean +0.214%) / DOWN 49.0% (mean −0.250%), net mean **−0.0134%** — also **direction-neutral / slightly down-tilted**. The design's "range EXTREME amputates the best up-legs" hypothesis is **NOT strongly corroborated on FIT**: these bars are roughly symmetric. So A's hard block neither badly amputates NOR buys risk reduction; B's down-size simply keeps them as (halved) entries that net out marginally additive (B net +$134 over A).
- **B (1864 EXTREME = spread-only, 1843 matched):** UP 51.8% / DOWN 48.0%, mean +0.0092% — direction-agnostic spread blocks, as intended.

### FIT gate evaluation (SAFETY bar OR CORRECTNESS-FLOOR bar; deltas vs C0-FIT)
- **A:** net −0.19% (≥98% ✓), Eq-DD 18.03% (−0.28pp, improved; not worse ✓), Sharpe +0.05 (<+0.10), PF +0.01 (✓), avg-R −0.0012 (≥C0−0.005 ✓). Misses SAFETY (Sharpe +0.05 not +0.10; Eq-DD −0.28pp not −0.75pp). **PASSES CORRECTNESS-FLOOR** (net ≥98%, Eq-DD not worse, PF/avg-R in tol). No KILL (give-back 0.19% ≪ 8%; amputation not corroborated). → **A PASSES FIT.**
- **B:** net +5.29% (≥98% ✓✓), Eq-DD 18.49% (+0.18pp worse, ≤0.30pp ✓), Sharpe +0.06 (<+0.10), PF +0.01 (✓), avg-R 0.0820 (= C0 ✓). Misses SAFETY (Eq-DD +0.18pp worse not −0.75pp; Sharpe +0.06 not +0.10). **PASSES CORRECTNESS-FLOOR** (net far ≥98%, Eq-DD within 0.30pp, PF/avg-R in tol). → **B PASSES FIT.**

**Both arms advance to CONFIRM.** B is the stronger FIT result (net +5.29% at flat avg-R vs A's net-flat). Adoption preference (§4.5) favors B unless A buys ≥0.5pp more Eq-DD at comparable net — A's Eq-DD is 0.46pp lower than B's (18.03 vs 18.49) but at −5.5% lower net, so A does NOT meet the "≥0.5pp more Eq-DD at COMPARABLE net" bar (net is not comparable; A gives back the gain). Tentative lean: **B**, pending CONFIRM (OOS).

---

## 4. CONFIRM (2023–2026H1) — surviving arm(s) + C0-CONFIRM (OOS)

Both A and B passed FIT → both run OOS, vs C0-CONFIRM (same-slice comparator, run #6).

| Cfg | Net $ | ΔNet% vs C0 | PF | Sharpe | Eq-DD | Bal-DD | avg-R | Pos |
|---|---|---|---|---|---|---|---|---|
| C0 | 14,316.32 | — | 1.38 | 3.01 | 13.52% | 11.58% | 0.2510 | 481 |
| A  | 13,179.40 | **−7.94%** | 1.36 | 2.89 | 13.68% | 11.77% | 0.2467 | 473 |
| B  | 14,101.86 | **−1.50%** | 1.38 | 2.99 | 13.54% | 11.67% | 0.2510 | 481 |

**C0-CONFIRM firing signature:** spread-only (bar/M5 = 0.00 on all 436 firings; max spread 28.17). 217 EXTREME blocks, 219 MODERATE down-sizes — all spread.
**A-CONFIRM firing:** bar+M5 live (non-zero 2055/2055). 510 EXTREME blocks (217 spread + ~293 range/M5 hard-blocks), 1545 MODERATE down-sizes. bar MOD 859/EXT 181; spread MOD 221/EXT 217; M5 MOD 834/EXT 148.

### CONFIRM gate eval (deltas vs C0-CONFIRM)
- **A: FAILS CONFIRM.** Net **−7.94%** → net = 92.06% of C0, **below the 98% CORRECTNESS-FLOOR net bar** (and below the practical SAFETY threshold given A has NO DD/Sharpe win: Eq-DD +0.16pp WORSE, Sharpe −0.12, PF −0.02, avg-R −0.0043). A shrinks the book ~8% OOS WITHOUT buying any risk reduction — the §4 KILL-A amputation/one-sided-shrinker signature, now manifest OOS (A's ~293 range/M5 EXTREME hard-blocks cost ~$1,137 net with worse DD). → **KILL A. No A-FULL run** (early-KILL §4).
- **B-CONFIRM firing:** bar+M5 live (non-zero 2055/2055). **217 EXTREME blocks = spread-only** (= C0's 217 spread blocks exactly → B demotes ALL range/M5 EXTREME), 1838 MODERATE down-sizes.
- **B: PASSES CONFIRM.** Net **−1.50%** → net = 98.50% of C0 **≥98% ✓**; Eq-DD 13.54% (+0.02pp, ≤0.30pp ✓); PF 1.38 (= C0 ✓); avg-R 0.2510 (= C0 ✓). **PASSES CORRECTNESS-FLOOR.** (Misses SAFETY: Eq-DD flat not −0.75pp, Sharpe −0.02 not +0.10 — expected; this is a correctness fix, not a risk-reduction win.) → **B advances to FULL.**

**CONFIRM verdict:** A KILLED (−7.94% OOS, no risk payback — the range/M5 hard-block amputation cost confirmed OOS). B SURVIVES (correctness-floor pass; risk flat, net within 1.5%, PF/avg-R = C0). Only B → FULL.

---

## 5. FULL (2019–2026H1) — adoption candidate = B (A killed at CONFIRM)

C0-FULL on file (NOT re-run): **$20,069.23 / PF 1.29 / Sharpe 2.14 / Eq-DD 13.97% / Bal-DD 11.92% / avg-R 0.169 / 928 pos.**
Adoption tolerance (same set, vs C0-FULL): CORRECTNESS-FLOOR = net ≥98% ($19,667.85), Eq-DD ≤14.27% (≤+0.30pp), PF ≥1.27, avg-R ≥0.164.

| Cfg | Net $ | ΔNet% vs C0-FULL | PF | Sharpe | Eq-DD | Bal-DD | avg-R | Pos |
|---|---|---|---|---|---|---|---|---|
| C0 (on file) | 20,069.23 | — | 1.29 | 2.14 | 13.97% | 11.92% | 0.169 | 928 |
| B (run #7)   | **20,115.26** | **+0.23%** | 1.29 | 2.16 | 14.00% | 11.96% | 0.1690 | 928 |

**B-FULL firing:** bar+M5 live (non-zero 6628/6628 & 6624/6628). 6628 firings; **2082 EXTREME = spread-only** (2081 spread), 4546 MODERATE down-sizes. bar MOD 1916/EXT 414; spread MOD 808/EXT 2081; M5 MOD 2124/EXT 442.

### FULL gate eval (vs C0-FULL)
**B PASSES CORRECTNESS-FLOOR:** net **+0.23%** (≥98% ✓✓, marginally above C0), Eq-DD 14.00% (+0.03pp, ≤+0.30pp ✓), PF 1.29 (= C0, ≥1.27 ✓), avg-R 0.1690 (= C0, ≥0.164 ✓), Sharpe 2.16 (+0.02). (Not SAFETY — no risk-reduction win, as expected for a correctness fix.) **Net-neutral, risk-flat across FIT (+5.29%), CONFIRM (−1.50%), FULL (+0.23%)** — the gate is now correct and interpretable with the direction-blind range/M5 hard-block removed, at essentially zero net/risk cost. **B is ADOPTION-ELIGIBLE.**

---

## 6. VERDICT (recommend; stok rules — NOT self-adopted)

**Recommend: ADOPT Arm B** (B-FULL CLEARED the correctness-floor vs C0-FULL: net +0.23% / PF 1.29 / Sharpe 2.16 / Eq-DD 14.00% / avg-R 0.1690 / 928 pos). **KILL Arm A.**

**Run budget: 7 of ≤8 spent** (C0-FIT, A-FIT, B-FIT, C0-CONFIRM, A-CONFIRM, B-CONFIRM, B-FULL). A-FULL saved by the CONFIRM early-KILL; C0-FULL on file (not re-run).

Reasoning (data, not assertion):
- **Sanity gates PASS:** C0-FIT reproduced the OPT-2/3 cell to the cent ($2,453.21 / Eq-DD 18.31% / avg-R 0.0820 / 448 pos); non-zero-ratio gate PASS (Arm-A bar/M5 ratios non-zero on 4557/4557 & 4553/4557 — the dead legs are now LIVE). The fix is real.
- **A KILLED (CONFIRM):** A gives back **−7.94% net OOS** with **Eq-DD +0.16pp WORSE** and Sharpe −0.12 — it shrinks the book ~8% without buying any risk reduction (the §4 KILL-A one-sided-shrinker/amputation signature, manifest OOS). The amputation probe corroborates the mechanism: the ~440 range/M5-EXTREME bars A hard-blocks but B demotes are direction-NEUTRAL (51% up / 49% down), so a hard block on a direction-blind range signal is the wrong posture — exactly stok's §2a prior. A's extra OOS blocks cost net for nothing.
- **B SURVIVES (FIT +5.29%, CONFIRM −1.50%):** passes the CORRECTNESS-FLOOR on both selection and OOS (net ≥98% C0, Eq-DD flat-to-trivially-different, PF/avg-R = C0). B's EXTREME blocks reduce to spread-only (exactly = C0's spread blocks), demoting all range/M5 EXTREME to 50% down-sizes — the gate is now correct AND interpretable, the dangerous direction-blind hard-block is gone, and risk is held flat.
- **Adoption preference (§4.5):** B preferred over A — A does NOT buy ≥0.5pp more Eq-DD at comparable net (A's net is −5.5% below B's; its 0.46pp-lower FIT Eq-DD evaporates OOS into a +0.16pp-WORSE DD at −8% net). Tie/ambiguity → B; here it is not even close — B dominates A on every OOS axis.

This is the design's intended **ADOPT(B)** path: ship the correctness fix (`[1]` + closed-H1-ATR denom) with the EXTREME range/M5 legs demoted to down-size and spread keeping its hard block — a correct, interpretable safety that holds the risk line at net-neutral. **stok owns the binding ADOPT/commit ruling; not self-signed.**

**Working-tree state:** the in-tree `CEnhancedTradeExecutor.mqh` is the **Arm B** source (the recommended-adopt version). Binaries A/B/C0 all retained in the load path. NOT git-committed (per instructions).
