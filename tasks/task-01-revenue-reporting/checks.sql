-- =============================================================================
-- Task 01 – Revenue Reporting: automatic checks
-- =============================================================================
--
-- Run this after you have created your model as a view or table named
-- `fct_orders`, with the column names from Hint 1 of TASK.md, in the same
-- database where you ran setup.sql.
--
--   DuckDB CLI (from the repository root):
--     .read tasks/task-01-revenue-reporting/checks.sql
--   Browser / other tools: paste this file and run it.
--
-- Every row should say PASS. A FAIL means your model has a bug: compare the
-- `expected` and `actual` columns to find out where.
-- If you get an error like "Table fct_orders does not exist" or
-- "column ... not found", check the name of your model and its columns.
-- =============================================================================

WITH
src_orders AS (
    SELECT COUNT(*) AS n, SUM(CASE WHEN order_status = 'cancelled' THEN 1 ELSE 0 END) AS n_cancelled
    FROM orders
),
src_items AS (
    SELECT SUM(quantity) AS items, SUM(line_total) AS revenue FROM order_items
),
model AS (
    SELECT
        COUNT(*)                                                       AS n,
        COUNT(DISTINCT order_id)                                       AS n_distinct,
        SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)              AS n_null_id,
        SUM(CASE WHEN gross_revenue IS NULL THEN 1 ELSE 0 END)         AS n_null_revenue,
        SUM(CASE WHEN order_status = 'cancelled' THEN 1 ELSE 0 END)    AS n_cancelled,
        SUM(total_items)                                               AS items,
        SUM(gross_revenue)                                             AS revenue
    FROM fct_orders
),
user_mismatch AS (
    SELECT COUNT(*) AS n
    FROM fct_orders f
    JOIN orders o ON o.order_id = f.order_id
    WHERE f.user_id <> o.user_id OR f.order_date <> o.order_date OR f.payment_method <> o.payment_method
)

SELECT '1. one row per order (row count = orders)' AS check_name,
       CASE WHEN m.n = s.n THEN 'PASS' ELSE 'FAIL' END AS result,
       CAST(s.n AS VARCHAR) AS expected, CAST(m.n AS VARCHAR) AS actual
FROM model m, src_orders s
UNION ALL
SELECT '2. order_id is unique',
       CASE WHEN m.n = m.n_distinct THEN 'PASS' ELSE 'FAIL' END,
       CAST(m.n AS VARCHAR), CAST(m.n_distinct AS VARCHAR)
FROM model m
UNION ALL
SELECT '3. order_id is never NULL',
       CASE WHEN m.n_null_id = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0', CAST(m.n_null_id AS VARCHAR)
FROM model m
UNION ALL
SELECT '4. cancelled orders are kept',
       CASE WHEN m.n_cancelled = s.n_cancelled THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.n_cancelled AS VARCHAR), CAST(m.n_cancelled AS VARCHAR)
FROM model m, src_orders s
UNION ALL
SELECT '5. gross_revenue is never NULL',
       CASE WHEN m.n_null_revenue = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0', CAST(m.n_null_revenue AS VARCHAR)
FROM model m
UNION ALL
SELECT '6. total gross_revenue = SUM(order_items.line_total)',
       CASE WHEN ABS(m.revenue - s.revenue) < 0.01 THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.revenue AS VARCHAR), CAST(m.revenue AS VARCHAR)
FROM model m, src_items s
UNION ALL
SELECT '7. total total_items = SUM(order_items.quantity)',
       CASE WHEN m.items = s.items THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.items AS VARCHAR), CAST(m.items AS VARCHAR)
FROM model m, src_items s
UNION ALL
SELECT '8. user_id, order_date, payment_method match the source order',
       CASE WHEN u.n = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0 mismatches', CAST(u.n AS VARCHAR) || ' mismatches'
FROM user_mismatch u;
