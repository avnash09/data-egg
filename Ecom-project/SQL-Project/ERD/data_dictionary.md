# ShopHub — Data Dictionary

_Analytics (3NF) layer. Auto-generated from the live PostgreSQL catalog (`pg_attribute` + `COMMENT ON` metadata) after running `01_schema.sql`._

Database: **shophub** · Schema: **analytics** · 9 core tables


---


## `product_categories`

Reference/dimension of product categories with PT->EN translation.


| # | Column | Type | Nullability | Business meaning |
|---|--------|------|-------------|------------------|
| 1 | `category_id` | integer | NOT NULL | Surrogate PK for the category. |
| 2 | `category_name` | text | NOT NULL | Original Portuguese category name (natural key from Olist). |
| 3 | `category_name_english` | text | NULL allowed | English translation from product_category_name_translation.csv. |

**Constraints**

- **PK** — `PRIMARY KEY (category_id)`
- **UNIQUE** — `UNIQUE (category_name)`


## `geolocation`

Zip-prefix dimension: one representative lat/lng/city/state per prefix.


| # | Column | Type | Nullability | Business meaning |
|---|--------|------|-------------|------------------|
| 1 | `zip_code_prefix` | integer | NOT NULL | Brazilian zip code prefix (first 5 digits). PK. |
| 2 | `latitude` | numeric(10,6) | NULL allowed | Representative (median) latitude for the prefix. |
| 3 | `longitude` | numeric(10,6) | NULL allowed | Representative (median) longitude for the prefix. |
| 4 | `city` | text | NULL allowed | Most frequent city name for the prefix (normalized). |
| 5 | `state` | character(2) | NULL allowed | Two-letter Brazilian state code (UF). |

**Constraints**

- **CHECK** — `CHECK (((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric)))`
- **CHECK** — `CHECK (((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric)))`
- **PK** — `PRIMARY KEY (zip_code_prefix)`


## `customers`

Customer records. customer_id is per-order; customer_unique_id = the person.


| # | Column | Type | Nullability | Business meaning |
|---|--------|------|-------------|------------------|
| 1 | `customer_id` | character(32) | NOT NULL | Per-order customer key (PK). One physical person may own many. |
| 2 | `customer_unique_id` | character(32) | NOT NULL | Stable identifier for the physical customer across orders. |
| 3 | `zip_code_prefix` | integer | NULL allowed | FK -> geolocation. Customer location prefix. |
| 4 | `city` | text | NULL allowed | Customer city (as supplied). |
| 5 | `state` | character(2) | NULL allowed | Customer state (UF). |

**Constraints**

- **FK** — `FOREIGN KEY (zip_code_prefix) REFERENCES analytics.geolocation(zip_code_prefix)`
- **PK** — `PRIMARY KEY (customer_id)`


## `sellers`

Marketplace sellers and their location.


| # | Column | Type | Nullability | Business meaning |
|---|--------|------|-------------|------------------|
| 1 | `seller_id` | character(32) | NOT NULL | Seller PK. |
| 2 | `zip_code_prefix` | integer | NULL allowed | FK -> geolocation. Seller location prefix. |
| 3 | `city` | text | NULL allowed |  |
| 4 | `state` | character(2) | NULL allowed |  |

**Constraints**

- **FK** — `FOREIGN KEY (zip_code_prefix) REFERENCES analytics.geolocation(zip_code_prefix)`
- **PK** — `PRIMARY KEY (seller_id)`


## `products`

Product catalogue with physical attributes and category FK.


| # | Column | Type | Nullability | Business meaning |
|---|--------|------|-------------|------------------|
| 1 | `product_id` | character(32) | NOT NULL | Product PK. |
| 2 | `category_id` | integer | NULL allowed | FK -> product_categories. |
| 3 | `weight_g` | integer | NULL allowed | Product weight in grams. |
| 4 | `length_cm` | integer | NULL allowed |  |
| 5 | `height_cm` | integer | NULL allowed |  |
| 6 | `width_cm` | integer | NULL allowed |  |
| 7 | `photos_qty` | integer | NULL allowed |  |
| 8 | `name_length` | integer | NULL allowed | Character length of the product name (renamed from misspelled lenght). |
| 9 | `description_length` | integer | NULL allowed | Character length of the product description. |

**Constraints**

- **CHECK** — `CHECK ((description_length >= 0))`
- **CHECK** — `CHECK ((height_cm >= 0))`
- **CHECK** — `CHECK ((length_cm >= 0))`
- **CHECK** — `CHECK ((name_length >= 0))`
- **CHECK** — `CHECK ((photos_qty >= 0))`
- **CHECK** — `CHECK ((weight_g >= 0))`
- **CHECK** — `CHECK ((width_cm >= 0))`
- **FK** — `FOREIGN KEY (category_id) REFERENCES analytics.product_categories(category_id)`
- **PK** — `PRIMARY KEY (product_id)`


## `orders`

Order header. One row per order_id; grain = order.


| # | Column | Type | Nullability | Business meaning |
|---|--------|------|-------------|------------------|
| 1 | `order_id` | character(32) | NOT NULL | Order PK. |
| 2 | `customer_id` | character(32) | NOT NULL | FK -> customers (per-order key). |
| 3 | `order_status` | text | NOT NULL | Lifecycle status (delivered, shipped, canceled, ...). |
| 4 | `purchase_ts` | timestamp without time zone | NULL allowed | Timestamp the order was placed. |
| 5 | `approved_ts` | timestamp without time zone | NULL allowed | Timestamp payment was approved. |
| 6 | `delivered_carrier_ts` | timestamp without time zone | NULL allowed | Timestamp handed to logistics carrier. |
| 7 | `delivered_customer_ts` | timestamp without time zone | NULL allowed | Timestamp delivered to the customer. |
| 8 | `estimated_delivery_ts` | timestamp without time zone | NULL allowed | Promised/estimated delivery timestamp. |

**Constraints**

- **CHECK** — `CHECK (((delivered_customer_ts IS NULL) OR (purchase_ts IS NULL) OR (delivered_customer_ts >= purchase_ts)))`
- **CHECK** — `CHECK ((order_status = ANY (ARRAY['delivered'::text, 'shipped'::text, 'canceled'::text, 'unavailable'::text, 'invoiced'::text, 'processing'::text, 'created'::text, 'approved'::text])))`
- **FK** — `FOREIGN KEY (customer_id) REFERENCES analytics.customers(customer_id)`
- **PK** — `PRIMARY KEY (order_id)`


## `order_items`

Order line items. Grain = one line (order_id, order_item_id).


| # | Column | Type | Nullability | Business meaning |
|---|--------|------|-------------|------------------|
| 1 | `order_id` | character(32) | NOT NULL |  |
| 2 | `order_item_id` | smallint | NOT NULL | Sequential line number within the order (1..N). |
| 3 | `product_id` | character(32) | NOT NULL |  |
| 4 | `seller_id` | character(32) | NOT NULL |  |
| 5 | `shipping_limit_ts` | timestamp without time zone | NULL allowed |  |
| 6 | `price` | numeric(10,2) | NOT NULL | Item price in BRL (revenue driver). |
| 7 | `freight_value` | numeric(10,2) | NOT NULL | Freight/shipping charge for the line in BRL. |

**Constraints**

- **CHECK** — `CHECK ((freight_value >= (0)::numeric))`
- **CHECK** — `CHECK ((price >= (0)::numeric))`
- **FK** — `FOREIGN KEY (order_id) REFERENCES analytics.orders(order_id)`
- **FK** — `FOREIGN KEY (product_id) REFERENCES analytics.products(product_id)`
- **FK** — `FOREIGN KEY (seller_id) REFERENCES analytics.sellers(seller_id)`
- **PK** — `PRIMARY KEY (order_id, order_item_id)`


## `order_payments`

Payment transactions. An order may split across several rows.


| # | Column | Type | Nullability | Business meaning |
|---|--------|------|-------------|------------------|
| 1 | `order_id` | character(32) | NOT NULL |  |
| 2 | `payment_sequential` | smallint | NOT NULL | Sequence number of the payment within the order. |
| 3 | `payment_type` | text | NOT NULL | credit_card / boleto / voucher / debit_card / not_defined. |
| 4 | `payment_installments` | smallint | NULL allowed | Number of installments chosen by the customer. |
| 5 | `payment_value` | numeric(10,2) | NOT NULL | Amount paid on this payment row in BRL. |

**Constraints**

- **CHECK** — `CHECK ((payment_installments >= 0))`
- **CHECK** — `CHECK ((payment_type = ANY (ARRAY['credit_card'::text, 'boleto'::text, 'voucher'::text, 'debit_card'::text, 'not_defined'::text])))`
- **CHECK** — `CHECK ((payment_value >= (0)::numeric))`
- **FK** — `FOREIGN KEY (order_id) REFERENCES analytics.orders(order_id)`
- **PK** — `PRIMARY KEY (order_id, payment_sequential)`


## `order_reviews`

Customer reviews tied to orders (1..5 stars + free text).


| # | Column | Type | Nullability | Business meaning |
|---|--------|------|-------------|------------------|
| 1 | `review_sk` | bigint | NOT NULL | Surrogate PK (review_id is not unique). |
| 2 | `review_id` | character(32) | NOT NULL |  |
| 3 | `order_id` | character(32) | NOT NULL |  |
| 4 | `review_score` | smallint | NULL allowed | Star rating 1..5. |
| 5 | `comment_title` | text | NULL allowed |  |
| 6 | `comment_message` | text | NULL allowed |  |
| 7 | `creation_date` | timestamp without time zone | NULL allowed |  |
| 8 | `answer_ts` | timestamp without time zone | NULL allowed |  |

**Constraints**

- **CHECK** — `CHECK (((review_score >= 1) AND (review_score <= 5)))`
- **FK** — `FOREIGN KEY (order_id) REFERENCES analytics.orders(order_id)`
- **PK** — `PRIMARY KEY (review_sk)`
- **UNIQUE** — `UNIQUE (review_id, order_id)`
