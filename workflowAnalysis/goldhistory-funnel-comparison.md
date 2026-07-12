# GoldHistory Funnel Comparison — production vs GoldHistory (2019-2025, Model=1)

| Stage | PROD | GoldHistory |
|---|--:|--:|
| Candidate-decisions | 4525 | 4591 |
| WINNER | 1509 | 1546 |
| PASS | 1556 | 1597 |
| REJECT | 1460 | 1448 |
| → Fills (positions) | 893 | 885 |

**Reject reasons (kill counts):**

| Reason | PROD | GoldHistory |
|---|--:|--:|
| VOLUME_FILTER | 565 | 534 |
| VALIDATOR_FAILED | 482 | 490 |
| QUALITY_BELOW_THRESHOLD | 341 | 356 |
| LOW_CONFIDENCE_30 | 72 | 68 |

The funnel shapes are near-identical between feeds — the gate stack rejects similar volumes, confirming the pipeline itself is feed-stable. The differences live in *which* candidates each gate catches (see gate-stability + threshold-flips).
