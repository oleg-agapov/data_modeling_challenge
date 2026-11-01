# Reference solution 03 – Star Schema Design

## Conceptual Layer

The central business event is **a product being sold as part of an order**. That's the most detailed thing that happens in the sales process, so it becomes the fact.

Around that event, people want to ask *when* (date), *who* (customer) and *what* (product). Those are the dimensions.

```
                    Date
                     ▲
                     │ when
Customer ◄── who ── Order line sold ── what ──► Product
```

**Grain of the fact:** one row per order line (one product in one order).

I chose the finest grain available on purpose. Order-level or daily totals can always be calculated from order lines, but not the other way around.

Entities and how I treated them:

| Entity | Becomes | Why |
|---|---|---|
| Order line | the fact (`fct_order_items`) | The measurable event: quantity, price, discount, amount |
| Order | degenerate dimension on the fact | It has no descriptive attributes of its own besides status, payment method and date, which I put on the fact or in `dim_date` |
| Customer | `dim_customer` | Who bought |
| Address | attributes of `dim_customer` | Exactly one address per customer, not shared, so it describes the customer |
| Product | `dim_product` | What was bought |
| Calendar day | `dim_date` | When it was bought, with calendar attributes pre-computed |


## Logical Layer

### Source-to-model mapping

| Model | Built from | Grain |
|---|---|---|
| `dim_date` | generated from the `orders.order_date` range | one row per calendar day |
| `dim_customer` | `users` + `locations` | one row per user |
| `dim_product` | `products` | one row per product |
| `fct_order_items` | `order_items` + `orders`, keys looked up in the dimensions | one row per order line |

### `dim_date`

| Column | Type | Notes |
|---|---|---|
| `date_key` | integer | PK, `YYYYMMDD` |
| `full_date` | date | natural key |
| `year`, `quarter`, `month`, `week_of_year`, `day_of_week` | integer | `day_of_week`: 1 = Monday |
| `month_name`, `day_name` | text | |
| `is_weekend` | boolean | Saturday or Sunday |

### `dim_customer` (SCD Type 1)

| Column | Type | Notes |
|---|---|---|
| `customer_key` | integer | PK, surrogate |
| `customer_id` | text | natural key, `users.user_id` |
| `first_name`, `last_name`, `email` | text | |
| `registered_at` | timestamp | `users.created_at` |
| `registration_month` | date | first day of the registration month |
| `city`, `state`, `zip_code`, `country_code` | text | from `locations` |

### `dim_product`

| Column | Type | Notes |
|---|---|---|
| `product_key` | integer | PK, surrogate |
| `product_id` | text | natural key, `products.id` |
| `name`, `category`, `material` | text | |
| `current_catalog_price` | decimal(12,2) | price at load time, not at sale time |

### `fct_order_items`

| Column | Type | Notes |
|---|---|---|
| `order_item_key` | integer | PK, surrogate |
| `order_item_id` | text | natural key |
| `order_id` | text | degenerate dimension |
| `order_status`, `payment_method` | text | degenerate dimensions |
| `date_key` | integer | FK → `dim_date` |
| `customer_key` | integer | FK → `dim_customer` |
| `product_key` | integer | FK → `dim_product` |
| `quantity` | integer | additive |
| `unit_price` | decimal(12,2) | non-additive (a price) |
| `discount` | decimal(4,2) | non-additive (a rate) |
| `line_total` | decimal(12,2) | additive |

### Decisions and trade-offs

- **No `dim_location`.** Users and locations are one-to-one, so a separate dimension would only add a join. If addresses were shared, or analyzed on their own, I would reconsider.
- **Address is Type 1.** Past orders show the customer's *current* address. The data has no address history, so "revenue by state at the time of order" is not possible; I would mention this to anyone using the state for analysis.
- **Order status and payment method stay on the fact** as degenerate dimensions. They are simple and analysts filter by them a lot. The stretch goal shows the junk-dimension alternative.
- **Surrogate keys** come from `ROW_NUMBER()` ordered by the natural key, so a rebuild of the same data gives the same keys. All tables are rebuilt together, so the fact always matches its dimensions.
- **`dim_date` covers every day** between the first and last order, including days without sales, so date-based reports don't silently skip empty days.
- **Cancelled orders are kept**, like in Task 01. Consumers filter on `order_status`.


## Physical Layer

The SQL is written for DuckDB. `monthname`, `dayname`, `isodow` and `weekofyear` have equivalents in other databases.

### `dim_date`

```sql
CREATE OR REPLACE TABLE dim_date AS
WITH bounds AS (
    SELECT CAST(MIN(order_date) AS DATE) AS first_day,
           CAST(MAX(order_date) AS DATE) AS last_day
    FROM orders
),
spine AS (
    SELECT CAST(d AS DATE) AS full_date
    FROM bounds, generate_series(first_day, last_day, INTERVAL 1 DAY) AS t(d)
)
SELECT
    year(full_date) * 10000 + month(full_date) * 100 + day(full_date) AS date_key,
    full_date,
    year(full_date)           AS year,
    quarter(full_date)        AS quarter,
    month(full_date)          AS month,
    monthname(full_date)      AS month_name,
    weekofyear(full_date)     AS week_of_year,
    isodow(full_date)         AS day_of_week,
    dayname(full_date)        AS day_name,
    isodow(full_date) IN (6, 7) AS is_weekend
FROM spine;
```

### `dim_customer`

```sql
CREATE OR REPLACE TABLE dim_customer AS
SELECT
    ROW_NUMBER() OVER (ORDER BY u.user_id)   AS customer_key,
    u.user_id                                AS customer_id,
    u.first_name,
    u.last_name,
    u.email,
    u.created_at                             AS registered_at,
    CAST(DATE_TRUNC('month', u.created_at) AS DATE) AS registration_month,
    l.city,
    l.state,
    l.zip_code,
    l.country_code
FROM users u
LEFT JOIN locations l ON l.location_id = u.location_id;
```

### `dim_product`

```sql
CREATE OR REPLACE TABLE dim_product AS
SELECT
    ROW_NUMBER() OVER (ORDER BY id) AS product_key,
    id                              AS product_id,
    name,
    category,
    material,
    price                           AS current_catalog_price
FROM products;
```

### `fct_order_items`

```sql
CREATE OR REPLACE TABLE fct_order_items AS
SELECT
    ROW_NUMBER() OVER (ORDER BY oi.order_item_id) AS order_item_key,
    oi.order_item_id,
    oi.order_id,
    o.order_status,
    o.payment_method,
    d.date_key,
    c.customer_key,
    p.product_key,
    oi.quantity,
    oi.unit_price,
    oi.discount,
    oi.line_total
FROM order_items oi
JOIN orders o            ON o.order_id = oi.order_id
LEFT JOIN dim_date d     ON d.full_date = CAST(o.order_date AS DATE)
LEFT JOIN dim_customer c ON c.customer_id = o.user_id
LEFT JOIN dim_product p  ON p.product_id = oi.product_id;
```

I use `LEFT JOIN` for the dimension lookups on purpose: if a lookup fails, the fact row is kept with a `NULL` key and my validation catches it. An `INNER JOIN` would silently drop the row and the revenue with it.

### Validation queries

```sql
-- 1. Fact grain and totals match the source
SELECT
    (SELECT COUNT(*) FROM fct_order_items)        AS fact_rows,
    (SELECT COUNT(*) FROM order_items)            AS source_rows,
    (SELECT SUM(line_total) FROM fct_order_items) AS fact_revenue,
    (SELECT SUM(line_total) FROM order_items)     AS source_revenue;

-- 2. No NULL foreign keys
SELECT COUNT(*) AS rows_with_null_fk
FROM fct_order_items
WHERE date_key IS NULL OR customer_key IS NULL OR product_key IS NULL;

-- 3. No orphans (repeat for dim_customer and dim_date)
SELECT COUNT(*) AS orphan_products
FROM fct_order_items f
LEFT JOIN dim_product p ON p.product_key = f.product_key
WHERE p.product_key IS NULL;

-- 4. One row per natural key in each dimension
SELECT
    (SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM dim_customer) AS dup_customers,
    (SELECT COUNT(*) - COUNT(DISTINCT product_id)  FROM dim_product)  AS dup_products,
    (SELECT COUNT(*) - COUNT(DISTINCT full_date)   FROM dim_date)     AS dup_dates;

-- 5. The star schema in action: revenue by category and quarter, non-cancelled orders
SELECT d.year, d.quarter, p.category, SUM(f.line_total) AS revenue
FROM fct_order_items f
JOIN dim_date d    ON d.date_key = f.date_key
JOIN dim_product p ON p.product_key = f.product_key
WHERE f.order_status <> 'cancelled'
GROUP BY d.year, d.quarter, p.category
ORDER BY d.year, d.quarter, p.category;
```

Results I got:

- `fct_order_items`: 2,092 rows and 838,870.67 revenue, the same as the source.
- No NULL foreign keys, no orphans, no duplicate natural keys.
- `dim_date` has 730 days (2024-03-15 to 2026-03-14), `dim_customer` 12,483 rows, `dim_product` 21 rows.

All checks in [`checks.sql`](../../tasks/task-03-star-schema/checks.sql) pass.


## Stretch goal: junk dimension

```sql
CREATE OR REPLACE TABLE dim_order_profile AS
SELECT
    ROW_NUMBER() OVER (ORDER BY order_status, payment_method) AS order_profile_key,
    order_status,
    payment_method
FROM (SELECT DISTINCT order_status, payment_method FROM orders) AS combos;
```

This gives 12 rows (4 statuses × 3 payment methods; all combinations occur in the data). In `fct_order_items`, `o.order_status` and `o.payment_method` are replaced by:

```sql
    op.order_profile_key,
-- ...
LEFT JOIN dim_order_profile op
       ON op.order_status = o.order_status
      AND op.payment_method = o.payment_method
```

Trade-off: the fact table loses two text columns, and the list of valid status/payment combinations lives in one place. But every query that filters by status (which is most revenue queries, to exclude cancelled orders) now needs an extra join. For a fact table this small, I would keep the degenerate dimensions. A junk dimension pays off when there are many such flags and a very large fact table.
