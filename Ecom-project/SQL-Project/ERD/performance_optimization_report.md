# ShopHub — Performance Optimization Report

**Engine:** PostgreSQL 16.14
**Technique:** `EXPLAIN (ANALYZE, BUFFERS)` to read the real executed plan (not just estimates), then add targeted indexes and re-measure.
**Scripts:** `sql/04_optimization.sql` (Part G Q2).

---

## 1. Why indexes are needed here

PostgreSQL does **not** automatically index foreign-key columns. Every join in `03_queries.sql`
(`order_items.order_id`, `order_items.product_id`, `orders.customer_id`, …) would otherwise drive a
sequential scan of the child table. On the ~100K-order Olist data — and any production analytics
workload — that is the dominant cost. The production indexes created in `04_optimization.sql`:

```
idx_orders_customer        orders(customer_id)            -- customer 360, joins
idx_items_order            order_items(order_id)          -- order-total rollups
idx_items_product          order_items(product_id)        -- top-product-per-category
idx_items_seller           order_items(seller_id)         -- seller revenue ranking
idx_payments_order         order_payments(order_id)       -- payment reconciliation
idx_reviews_order          order_reviews(order_id)        -- review joins
idx_products_category      products(category_id)          -- category rollups
idx_customers_unique       customers(customer_unique_id)  -- person-grain aggregation
idx_orders_purchase_ts     orders(purchase_ts)            -- monthly / moving-average
idx_orders_delivered_late  orders(delivered_customer_ts, estimated_delivery_ts)
                           WHERE order_status='delivered' -- PARTIAL: shipping-delay query
idx_items_seller_price     order_items(seller_id) INCLUDE(price) -- COVERING: index-only scan
```

Two techniques worth calling out:
- **Partial index** (`idx_orders_delivered_late`) indexes only `delivered` rows, so the shipping-delay
  query in Part D Q5 scans a much smaller structure.
- **Covering index** (`idx_items_seller_price` with `INCLUDE (price)`) lets the seller-revenue rollup
  be answered from the index alone (index-only scan), never touching the heap.

---

## 2. Measured before/after (EXPLAIN ANALYZE)

Tiny tables always seq-scan because it is genuinely cheaper, so the benefit was measured on a
**200,000-row** table (`analytics.items_big`) with a selective filter — the same shape as a real
`WHERE product_id = ?` lookup.

### Query
```sql
SELECT product_id, SUM(price)
FROM analytics.items_big
WHERE product_id = 42
GROUP BY product_id;
```

### BEFORE — no index (sequential scan)
```
                                                    QUERY PLAN                                                     
-------------------------------------------------------------------------------------------------------------------
 GroupAggregate  (cost=0.00..3788.81 rows=1 width=36) (actual time=9.580..9.581 rows=1 loops=1)
   Buffers: shared hit=1280
   ->  Seq Scan on items_big  (cost=0.00..3780.00 rows=3520 width=10) (actual time=0.008..9.179 rows=3272 loops=1)
         Filter: (product_id = 42)
         Rows Removed by Filter: 196728
         Buffers: shared hit=1280
 Planning:
   Buffers: shared hit=35
 Planning Time: 0.171 ms
 Execution Time: 9.618 ms
(10 rows)
```

### AFTER — with `idx_items_big_product` (bitmap index scan)
```
                                                                QUERY PLAN                                                                 
-------------------------------------------------------------------------------------------------------------------------------------------
 GroupAggregate  (cost=38.13..1368.13 rows=1 width=36) (actual time=1.933..1.934 rows=1 loops=1)
   Buffers: shared hit=1192 read=4
   ->  Bitmap Heap Scan on items_big  (cost=38.13..1359.79 rows=3333 width=10) (actual time=0.324..1.599 rows=3272 loops=1)
         Recheck Cond: (product_id = 42)
         Heap Blocks: exact=1192
         Buffers: shared hit=1192 read=4
         ->  Bitmap Index Scan on idx_items_big_product  (cost=0.00..37.29 rows=3333 width=0) (actual time=0.143..0.144 rows=3272 loops=1)
               Index Cond: (product_id = 42)
               Buffers: shared read=4
 Planning:
   Buffers: shared hit=35 read=1
 Planning Time: 0.205 ms
 Execution Time: 1.969 ms
(13 rows)
```

### Result

| Metric | Before (Seq Scan) | After (Index Scan) | Improvement |
|--------|------------------:|-------------------:|------------:|
| Execution time | ~9.6 ms | ~2.0 ms | **~4.9× faster** |
| Rows examined | 200,000 (196,728 discarded by filter) | 3,272 matched via index | ~60× less work |
| Access method | `Seq Scan` | `Bitmap Index Scan` → `Bitmap Heap Scan` | — |

The planner switched from reading the whole table and throwing away 98%+ of rows, to walking the
index straight to the matching rows. On the full Olist volume and on multi-way joins the gap widens
substantially.

---

## 3. How to read these plans (interview-ready notes)

- **`Seq Scan` + high `Rows Removed by Filter`** → a missing/unused index on the filter column.
- **`actual time=start..end`** is real wall-clock per node; compare it to the estimated `cost` to spot
  bad row estimates (fix with `ANALYZE` / extended statistics).
- **`Buffers: shared hit/read`** shows cache vs disk pages; `read` climbing means the working set does
  not fit in cache.
- **`Bitmap Index Scan`** is chosen for medium-selectivity filters (many but not most rows); a plain
  `Index Scan` appears for highly selective ones; an **`Index Only Scan`** appears when a covering
  index supplies every needed column.
- Always `ANALYZE` after bulk loads/index creation so the planner has fresh statistics.

---

## 4. Additional tuning levers (beyond indexes)

1. **Pre-aggregated materialized views** for the monthly-revenue and category-seasonality queries
   (refresh nightly) — turns repeated GROUP BYs into cheap scans.
2. **Partitioning `orders`/`order_items` by month** (range partition on `purchase_ts`) so time-bounded
   analytics prune to a single partition.
3. **`VACUUM (ANALYZE)`** scheduling to keep visibility maps current, enabling index-only scans.
4. Widen statistics targets on skewed columns (`order_status`, `state`) to improve join-order choices.
