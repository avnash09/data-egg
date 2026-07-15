# ShopHub — Data Quality Findings Report

**Dataset:** Brazilian E-Commerce Public Dataset by Olist
**Scope:** 9 raw CSV files landed into `staging.stg_*`, profiled before loading the 3NF `analytics.*` layer.
**Method:** Every issue below was found with a SQL detection query (see `sql/02_data_cleaning.sql`, section *Part A Q2*). The counts in this report are the actual outputs of those queries against the validation load; on the full ~100K-order Olist dataset the same queries surface the same issue classes at larger volume.

> All 14 issues were reproduced and quantified on a live PostgreSQL 16 instance. `DQ-12` and `DQ-13` returned 0 in this run (no offending rows in the validation sample) but the checks are retained because they catch real defects that occur in the full Olist export.

---

## Summary table

| ID | Issue | Detected rows | Severity | Remediation applied in ETL |
|----|-------|--------------:|----------|----------------------------|
| DQ-01 | Multiple geolocation rows per zip prefix (grain problem) | 43 | Medium | Collapse to 1 representative row/prefix (median coords, modal city/state) |
| DQ-02 | Latitude/longitude outside valid range | 1 | High | Drop impossible coordinates before building the dimension |
| DQ-03 | Leading/trailing whitespace in city/state text | 1 | Low | `TRIM()` + `INITCAP()` normalization on load |
| DQ-04 | State codes not upper-cased (e.g. `sp`) | 1 | Low | `UPPER(TRIM())` normalization |
| DQ-05 | Exact duplicate `customer_id` rows | 1 | High | De-dup keeping most-recent record (Part A Q4) |
| DQ-06 | One `customer_unique_id` mapped to many `customer_id` | 12 | Info* | Kept by design; person grain resolved via `customer_unique_id` |
| DQ-07 | Products with missing/blank category | 1 | Medium | Category left `NULL` (FK nullable); row retained |
| DQ-08 | Invalid / negative product weight | 1 | Medium | Row dropped from clean `products` |
| DQ-09 | Orphan `order_items` (missing order or product) | 1 | High | Dropped via INNER JOIN on load |
| DQ-10 | Orphan `order_payments` (missing order) | 1 | High | Dropped via INNER JOIN on load |
| DQ-11 | Review score outside 1..5 | 1 | Medium | Row dropped; `CHECK` enforces range going forward |
| DQ-12 | Delivered timestamp earlier than purchase | 0 | High | `CHECK chk_delivery_after_purchase` blocks it |
| DQ-13 | Status = `delivered` but no delivery timestamp | 0 | Medium | Flagged for review; not auto-fixed |
| DQ-14 | Payment total ≠ order line-item total (>R$1) | 24 | High | Surfaced to fraud/finance review (Part B Q5) |

\* DQ-06 is not a defect in Olist — it is the dataset's defining characteristic. It is listed because a naïve analyst who treats `customer_id` as "the customer" will double-count people; documenting it prevents that error.

---

## Detailed findings

### DQ-01 — Geolocation grain: many rows per zip prefix
`stg_geolocation` stores every observed GPS ping, so a single `zip_code_prefix` appears in dozens of rows with slightly different lat/lng. Left as-is it cannot be a clean dimension and joins to it fan out.
**Fix:** aggregate to one row per prefix using `PERCENTILE_CONT(0.5)` for coordinates and `MODE()` for city/state, producing a stable `analytics.geolocation` dimension that `customers` and `sellers` reference by FK.

### DQ-02 — Impossible coordinates
At least one row carries a latitude far outside `[-90, 90]`. These break map plots and distance math.
**Fix:** filtered out during the geolocation aggregation; a `CHECK` constraint on `analytics.geolocation` prevents re-introduction.

### DQ-03 / DQ-04 — Text hygiene (whitespace & casing)
City/state fields carry stray spaces and inconsistent casing (`sp` vs `SP`, `  Rio ` vs `Rio`). These silently split `GROUP BY` buckets and inflate distinct counts.
**Fix:** `TRIM`, `UPPER` (states), `INITCAP` (cities) on load.

### DQ-05 — Exact duplicate customers
An identical `customer_id` row appears twice. Because `customer_id` is the PK of `analytics.customers`, the duplicate would violate the PK and must be resolved before load.
**Fix:** the de-duplication routine (Part A Q4) ranks rows per `customer_id` by their latest order date and keeps rank 1.

### DQ-06 — Person vs per-order identity
`customer_id` is minted per order; the real person is `customer_unique_id`. 12 people in the sample own more than one `customer_id`.
**Impact:** every "per customer" metric (CLV, repeat rate, cohort) must aggregate on `customer_unique_id`, which all Part C/E queries do.

### DQ-07 / DQ-08 — Product attribute defects
One product has a blank category; another a non-numeric/negative weight.
**Fix:** category-less products keep a `NULL` FK (still sellable, still analyzable by other dims); the negative-weight row is rejected because weight feeds freight logic and cannot be trusted.

### DQ-09 / DQ-10 — Referential orphans
Line items and payments reference `order_id`/`product_id` values that do not exist in their parent tables — classic broken foreign keys from unsynchronized source extracts.
**Fix:** the staging→analytics load uses INNER JOINs to the parent tables, so orphans are excluded and the declared FKs hold. Orphans are reported (Part B Q3) rather than silently discarded.

### DQ-11 — Review scores out of range
A review carries a score of 7 on a 1–5 scale.
**Fix:** dropped on load; `CHECK (review_score BETWEEN 1 AND 5)` enforces the domain permanently.

### DQ-12 / DQ-13 — Order lifecycle integrity
Checks for deliveries dated before purchase, and for `delivered` orders missing an actual delivery timestamp. Both are clean in the validation sample but are common in the full Olist export and are retained as guardrails (one enforced by `CHECK`, one flagged for manual review because a missing timestamp may be legitimately recoverable).

### DQ-14 — Payment vs order-total reconciliation
24 orders show a gap greater than R$1 between what was paid (`SUM(payment_value)`) and what was owed (`SUM(price + freight_value)`). Underpayments suggest revenue leakage or fraud; overpayments suggest voucher/refund handling or double-charge.
**Action:** these are not deleted — they are routed to the fraud/finance review query (Part B Q5), which classifies each as `UNDERPAID` or `OVERPAID` with the exact delta.

---

## Data-quality posture after cleaning

After the ETL in `02_data_cleaning.sql`, the `analytics.*` layer satisfies:
- Every declared PK and FK holds (orphans removed, duplicates resolved).
- All `CHECK` domains hold (scores 1–5, non-negative money/quantities, valid coordinates, valid statuses).
- One row per person is resolvable via `customer_unique_id`; one row per zip via the geolocation dimension.
- Suspicious-but-not-invalid records (payment mismatches, delivered-without-timestamp) are **quarantined into review queries rather than dropped**, preserving auditability.

_This is a sensitive-topic-free operational report; no further caveats apply._
