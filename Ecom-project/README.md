# SQL Mastery — Assignment 1: The E-Commerce Analytics Challenge

A complete analytics database for **"ShopHub"**, built on the **Brazilian E-Commerce
Public Dataset by Olist**. Covers schema design, data-quality cleaning, and 30
questions spanning aggregations, joins, subqueries/CTEs, window functions,
stored procedures, and query optimization.

- **Target engine:** PostgreSQL 14+ (developed and **fully validated on PostgreSQL 16.14**).
- **Every script in this submission was executed end-to-end against a live database with zero errors.** See `docs/execution_evidence.txt`.
- MySQL 8.0 porting notes are included below and inline where syntax differs.

---

## Folder structure

```
SQL_Mastery_Assignment_1/
├── README.md                         <- you are here
├── run_all.sh                        <- one-command build (schema -> load -> clean -> query -> optimize)
├── ERD/
│   ├── shophub_erd.png               <- ERD image (raster)
│   ├── shophub_erd.svg               <- ERD image (vector)
│   └── shophub_erd.mermaid           <- ERD source (Mermaid)
├── sql/
│   ├── 00_load_staging.sql           <- \copy raw Olist CSVs into staging
│   ├── 01_schema.sql                 <- Part A: 3NF schema, keys, constraints, data-dictionary comments
│   ├── 02_data_cleaning.sql          <- Part A Q2/Q4 + Part B: DQ checks, dedup, ETL, transactions, orphans, fraud
│   ├── 03_queries.sql                <- Parts C, D, E, F
│   └── 04_optimization.sql           <- Part G: stored procedures + indexes/EXPLAIN ANALYZE
├── reports/
│   ├── data_quality_findings.md      <- 14 documented data-quality issues
│   ├── data_dictionary.md            <- generated from the live catalog + COMMENTs
│   └── performance_optimization_report.md  <- EXPLAIN ANALYZE before/after + tuning notes
└── docs/
    ├── execution_evidence.txt        <- full clean-run capture (proof of execution)
    └── SCREENSHOTS_README.md          <- where/how to add your own screenshots
```

## How to run

```bash
# 1) download the Olist CSVs from Kaggle into a folder, then:
./run_all.sh /path/to/olist_csv_folder            # creates & builds the "shophub" DB

# or step by step:
psql -c "CREATE DATABASE shophub;"
psql -d shophub -f sql/01_schema.sql
psql -d shophub -v datadir='/path/to/olist' -f sql/00_load_staging.sql
psql -d shophub -f sql/02_data_cleaning.sql
psql -d shophub -f sql/03_queries.sql
psql -d shophub -f sql/04_optimization.sql
```

---

## Where each of the 30 questions is answered

| # | Question | File | Locator |
|---|----------|------|---------|
| **A1** | 3NF schema + ERD | `ERD/*`, `sql/01_schema.sql` | whole file |
| **A2** | 10+ data-quality issues | `sql/02_data_cleaning.sql`, `reports/data_quality_findings.md` | `DQ-01..DQ-14` |
| **A3** | Tables with types, PK/FK, constraints | `sql/01_schema.sql` | Section 2 |
| **A4** | Remove duplicate customers, keep most recent | `sql/02_data_cleaning.sql` | *Part A Q4* |
| **A5** | Data dictionary | `reports/data_dictionary.md` (+ `COMMENT ON` in `01`) | whole file |
| **B1** | Insert with transactions (COMMIT/ROLLBACK) | `sql/02_data_cleaning.sql` | *Part B Q1* |
| **B2** | Same email, different name/address | `sql/02_data_cleaning.sql` | *Part B Q2* |
| **B3** | Orphan records | `sql/02_data_cleaning.sql` | *Part B Q3* |
| **B4** | Registered but never ordered | `sql/02_data_cleaning.sql` | *Part B Q4* |
| **B5** | Fraud: payment ≠ order total | `sql/02_data_cleaning.sql` | *Part B Q5* |
| **C1** | Monthly revenue + MoM growth % | `sql/03_queries.sql` | *C1* |
| **C2** | Top 10 products by revenue per category | `sql/03_queries.sql` | *C2* |
| **C3** | CLV + customer segmentation | `sql/03_queries.sql` | *C3* |
| **C4** | ROLLUP / CUBE sales report | `sql/03_queries.sql` | *C4* |
| **C5** | Seasonal patterns by category | `sql/03_queries.sql` | *C5* |
| **D1** | Customer 360 view | `sql/03_queries.sql` | *D1* |
| **D2** | Bought electronics but never books | `sql/03_queries.sql` | *D2* |
| **D3** | Seller best-seller per category | `sql/03_queries.sql` | *D3* |
| **D4** | Market-basket via self-join | `sql/03_queries.sql` | *D4* |
| **D5** | Orders with shipping delays | `sql/03_queries.sql` | *D5* |
| **E1** | Customers above state average | `sql/03_queries.sql` | *E1* |
| **E2** | 2nd-highest product per category | `sql/03_queries.sql` | *E2* |
| **E3** | Category hierarchy (recursive CTE) | `sql/03_queries.sql` | *E3* |
| **E4** | Purchases in 3+ consecutive months | `sql/03_queries.sql` | *E4* |
| **F1** | 7-day moving average of daily orders | `sql/03_queries.sql` | *F1* |
| **F2** | Order gaps with LAG() | `sql/03_queries.sql` | *F2* |
| **F3** | Rank sellers by revenue per state | `sql/03_queries.sql` | *F3* |
| **F4** | Running totals + % contribution | `sql/03_queries.sql` | *F4* |
| **G1** | Dynamic discount stored procedure | `sql/04_optimization.sql` | *Part G Q1* |
| **G2** | Optimize with EXPLAIN ANALYZE + indexes | `sql/04_optimization.sql`, `reports/performance_optimization_report.md` | *Part G Q2* |

---

## Key design decisions & dataset adaptations

The Olist dataset does **not** ship every column some questions assume (there is
no email, customer name, or free-text address). Rather than invent columns, each
gap is handled with the faithful analog and documented:

1. **`customer_id` is per-order; `customer_unique_id` is the person.** This is
   Olist's defining quirk. All person-level metrics (CLV, repeat purchases, "above
   state average") aggregate on `customer_unique_id`. De-duplication (A4) keeps the
   most recent record per `customer_id`.
2. **B2 "same email, different name/address"** → the real analog is the same
   physical person (`customer_unique_id`) appearing with different location
   attributes (zip/city). That query is provided.
3. **B4 "registered but never ordered"** → in Olist a `customer_id` is minted at
   order time, so the strict version is usually empty. Both the classic
   `LEFT JOIN … IS NULL` pattern **and** the business-meaningful person-grain
   version (no *delivered* order) are provided.
4. **Geolocation grain.** The raw geolocation file has many rows per zip prefix.
   It is collapsed to one representative row per prefix (median coordinates, modal
   city/state) so it can serve as a clean dimension with enforceable FKs.
5. **E3 recursive hierarchy.** Olist categories are flat, so a small
   super-category tree (`analytics.category_tree`) is synthesized to demonstrate a
   genuine recursive CTE, then walked to produce depth + path.
6. **Revenue convention.** "Revenue" = `SUM(order_items.price)` for
   non-cancelled orders; freight is treated as a pass-through cost and excluded
   from revenue but shown where relevant.

---

## MySQL 8.0 porting notes

Everything here runs on MySQL 8.0 with a few adjustments:

- **CUBE (C4):** MySQL has no `CUBE`. Use `GROUP BY category, year WITH ROLLUP`
  (hierarchical subtotals) and `GROUPING()` to label them.
- **Stored routine (G1):** replace `CREATE FUNCTION … LANGUAGE plpgsql` /
  `CREATE PROCEDURE … $$` with MySQL `DELIMITER $$ CREATE PROCEDURE … $$` syntax;
  `RAISE NOTICE` → `SELECT … ;` or a `SIGNAL` for errors.
- **`generate_series` (F1):** MySQL lacks it — build the calendar with a recursive
  CTE (`WITH RECURSIVE cal AS (SELECT d0 … UNION ALL SELECT day+INTERVAL 1 DAY …)`).
- **`PERCENTILE_CONT` / `MODE()` (geolocation load):** approximate with
  `AVG()`/subquery-based mode, or keep the min/any representative row per prefix.
- **Partial & covering indexes (G2):** MySQL has no partial indexes; drop the
  `WHERE` clause. `INCLUDE` columns → put them in the composite key instead.
- **`FILTER (WHERE …)` (D1):** rewrite as `SUM(CASE WHEN … THEN 1 ELSE 0 END)`.
- **`::type` casts** → `CAST(x AS type)`; `date_trunc('month', ts)` →
  `DATE_FORMAT(ts,'%Y-%m-01')`.

---

## Verification checklist

- [x] All SQL scripts included (`00`–`04`) and run without errors end-to-end.
- [x] ERD attached (PNG + SVG + Mermaid source).
- [x] Data Quality Findings report (14 issues, with counts, impact, remediation).
- [x] Data Dictionary (generated from the live catalog).
- [x] Performance Optimization report with real `EXPLAIN ANALYZE` before/after.
- [x] Execution evidence captured (`docs/execution_evidence.txt`); slots for your own screenshots in `docs/`.
- [x] Folder ready to ZIP as `SQL_Mastery_Assignment_1.zip`.
