-- =============================================================================
-- Task 03 – Star Schema Design: automatic checks
-- =============================================================================
--
-- Run this after you have created the four models from TASK.md as views or
-- tables (`fct_order_items`, `dim_date`, `dim_customer`, `dim_product`), with
-- the column names from Hints 2 and 3, in the same database where you ran
-- setup.sql.
--
--   DuckDB CLI (from the repository root):
--     .read tasks/task-03-star-schema/checks.sql
--   Browser / other tools: paste this file and run it.
--
-- Every row should say PASS. A FAIL means your model has a bug: compare the
-- `expected` and `actual` columns to find out where.
-- The checks don't use order_status / payment_method, so they also pass if you
-- did the junk-dimension stretch goal.
-- =============================================================================

WITH
src AS (
    SELECT
        (SELECT COUNT(*) FROM order_items)                       AS n_items,
        (SELECT SUM(line_total) FROM order_items)                AS revenue,
        (SELECT COUNT(*) FROM users)                             AS n_users,
        (SELECT COUNT(*) FROM products)                          AS n_products,
        (SELECT CAST(MIN(order_date) AS DATE) FROM orders)       AS first_day,
        (SELECT CAST(MAX(order_date) AS DATE) FROM orders)       AS last_day
),
fct AS (
    SELECT
        COUNT(*)                                                 AS n,
        COUNT(DISTINCT order_item_id)                            AS n_distinct_items,
        COUNT(DISTINCT order_item_key)                           AS n_distinct_keys,
        SUM(line_total)                                          AS revenue,
        SUM(CASE WHEN date_key IS NULL OR customer_key IS NULL OR product_key IS NULL
                 THEN 1 ELSE 0 END)                              AS n_null_fk
    FROM fct_order_items
),
dims AS (
    SELECT
        (SELECT COUNT(*) FROM dim_customer)                      AS n_customer,
        (SELECT COUNT(DISTINCT customer_id) FROM dim_customer)   AS n_customer_nk,
        (SELECT COUNT(DISTINCT customer_key) FROM dim_customer)  AS n_customer_sk,
        (SELECT COUNT(*) FROM dim_product)                       AS n_product,
        (SELECT COUNT(DISTINCT product_id) FROM dim_product)     AS n_product_nk,
        (SELECT COUNT(DISTINCT product_key) FROM dim_product)    AS n_product_sk,
        (SELECT COUNT(*) FROM dim_date)                          AS n_date,
        (SELECT COUNT(DISTINCT full_date) FROM dim_date)         AS n_date_nk,
        (SELECT COUNT(DISTINCT date_key) FROM dim_date)          AS n_date_sk,
        (SELECT MIN(full_date) FROM dim_date)                    AS date_min,
        (SELECT MAX(full_date) FROM dim_date)                    AS date_max,
        (SELECT SUM(CASE WHEN city IS NULL OR state IS NULL THEN 1 ELSE 0 END) FROM dim_customer) AS n_no_address
),
orphans AS (
    SELECT
        (SELECT COUNT(*) FROM fct_order_items f LEFT JOIN dim_date d     ON d.date_key = f.date_key         WHERE d.date_key IS NULL)     AS date_orphans,
        (SELECT COUNT(*) FROM fct_order_items f LEFT JOIN dim_customer c ON c.customer_key = f.customer_key WHERE c.customer_key IS NULL) AS customer_orphans,
        (SELECT COUNT(*) FROM fct_order_items f LEFT JOIN dim_product p  ON p.product_key = f.product_key   WHERE p.product_key IS NULL)  AS product_orphans
),
wrong_links AS (
    -- follow each fact row through the dimensions and compare with the source
    SELECT
        SUM(CASE WHEN c.customer_id <> o.user_id THEN 1 ELSE 0 END)             AS wrong_customer,
        SUM(CASE WHEN p.product_id <> oi.product_id THEN 1 ELSE 0 END)          AS wrong_product,
        SUM(CASE WHEN d.full_date <> CAST(o.order_date AS DATE) THEN 1 ELSE 0 END) AS wrong_date
    FROM fct_order_items f
    JOIN order_items oi  ON oi.order_item_id = f.order_item_id
    JOIN orders o        ON o.order_id = oi.order_id
    JOIN dim_customer c  ON c.customer_key = f.customer_key
    JOIN dim_product p   ON p.product_key = f.product_key
    JOIN dim_date d      ON d.date_key = f.date_key
),
bad_date_keys AS (
    SELECT COUNT(*) AS n
    FROM dim_date
    WHERE date_key <> EXTRACT(YEAR FROM full_date) * 10000
                    + EXTRACT(MONTH FROM full_date) * 100
                    + EXTRACT(DAY FROM full_date)
)

SELECT '01. fct_order_items: one row per order line' AS check_name,
       CASE WHEN f.n = s.n_items AND f.n_distinct_items = s.n_items THEN 'PASS' ELSE 'FAIL' END AS result,
       CAST(s.n_items AS VARCHAR) AS expected, CAST(f.n AS VARCHAR) || ' rows, ' || CAST(f.n_distinct_items AS VARCHAR) || ' distinct' AS actual
FROM fct f, src s
UNION ALL
SELECT '02. fct_order_items: order_item_key is unique',
       CASE WHEN f.n_distinct_keys = f.n THEN 'PASS' ELSE 'FAIL' END,
       CAST(f.n AS VARCHAR), CAST(f.n_distinct_keys AS VARCHAR)
FROM fct f
UNION ALL
SELECT '03. fct_order_items: SUM(line_total) matches the source',
       CASE WHEN ABS(f.revenue - s.revenue) < 0.01 THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.revenue AS VARCHAR), CAST(f.revenue AS VARCHAR)
FROM fct f, src s
UNION ALL
SELECT '04. fct_order_items: no NULL foreign keys',
       CASE WHEN f.n_null_fk = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0', CAST(f.n_null_fk AS VARCHAR)
FROM fct f
UNION ALL
SELECT '05. no orphan foreign keys (date / customer / product)',
       CASE WHEN o.date_orphans + o.customer_orphans + o.product_orphans = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0 / 0 / 0',
       CAST(o.date_orphans AS VARCHAR) || ' / ' || CAST(o.customer_orphans AS VARCHAR) || ' / ' || CAST(o.product_orphans AS VARCHAR)
FROM orphans o
UNION ALL
SELECT '06. fact rows point to the right customer, product and date',
       CASE WHEN w.wrong_customer + w.wrong_product + w.wrong_date = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0 / 0 / 0',
       CAST(w.wrong_customer AS VARCHAR) || ' / ' || CAST(w.wrong_product AS VARCHAR) || ' / ' || CAST(w.wrong_date AS VARCHAR)
FROM wrong_links w
UNION ALL
SELECT '07. dim_customer: one row per user, unique keys',
       CASE WHEN d.n_customer = s.n_users AND d.n_customer_nk = s.n_users AND d.n_customer_sk = s.n_users THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.n_users AS VARCHAR),
       CAST(d.n_customer AS VARCHAR) || ' rows, ' || CAST(d.n_customer_nk AS VARCHAR) || ' ids, ' || CAST(d.n_customer_sk AS VARCHAR) || ' keys'
FROM dims d, src s
UNION ALL
SELECT '08. dim_customer: every customer has an address',
       CASE WHEN d.n_no_address = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0', CAST(d.n_no_address AS VARCHAR)
FROM dims d
UNION ALL
SELECT '09. dim_product: one row per product, unique keys',
       CASE WHEN d.n_product = s.n_products AND d.n_product_nk = s.n_products AND d.n_product_sk = s.n_products THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.n_products AS VARCHAR),
       CAST(d.n_product AS VARCHAR) || ' rows, ' || CAST(d.n_product_nk AS VARCHAR) || ' ids, ' || CAST(d.n_product_sk AS VARCHAR) || ' keys'
FROM dims d, src s
UNION ALL
SELECT '10. dim_date: covers first to last order date',
       CASE WHEN d.date_min <= s.first_day AND d.date_max >= s.last_day THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.first_day AS VARCHAR) || ' .. ' || CAST(s.last_day AS VARCHAR),
       CAST(d.date_min AS VARCHAR) || ' .. ' || CAST(d.date_max AS VARCHAR)
FROM dims d, src s
UNION ALL
SELECT '11. dim_date: one row per day, no gaps',
       CASE WHEN d.n_date = d.n_date_nk AND d.n_date = d.n_date_sk
             AND d.n_date = CAST(d.date_max - d.date_min AS INTEGER) + 1 THEN 'PASS' ELSE 'FAIL' END,
       CAST(CAST(d.date_max - d.date_min AS INTEGER) + 1 AS VARCHAR),
       CAST(d.n_date AS VARCHAR) || ' rows, ' || CAST(d.n_date_nk AS VARCHAR) || ' dates'
FROM dims d
UNION ALL
SELECT '12. dim_date: date_key is YYYYMMDD',
       CASE WHEN b.n = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0 wrong keys', CAST(b.n AS VARCHAR) || ' wrong keys'
FROM bad_date_keys b;
