-- =============================================================================
-- Task 02 – Product Sales Report: automatic checks
-- =============================================================================
--
-- Run this after you have created your model as a view or table named
-- `rpt_product_sales`, with the column names from Hint 1 of TASK.md, in the
-- same database where you ran setup.sql.
--
--   DuckDB CLI (from the repository root):
--     .read tasks/task-02-product-sales-report/checks.sql
--   Browser / other tools: paste this file and run it.
--
-- Every row should say PASS. A FAIL means your model has a bug: compare the
-- `expected` and `actual` columns to find out where.
-- =============================================================================

WITH
sales AS (
    -- non-cancelled order lines, the population all sales metrics are based on
    SELECT oi.order_id, oi.product_id, oi.quantity, oi.unit_price, oi.discount, oi.line_total, o.user_id
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status <> 'cancelled'
),
src AS (
    SELECT
        (SELECT COUNT(*) FROM products)                                         AS n_products,
        SUM(line_total)                                                         AS revenue,
        SUM(quantity)                                                           AS units,
        SUM(quantity * unit_price * discount)                                   AS discount_amount,
        COUNT(DISTINCT order_id || '|' || product_id)                           AS order_product_pairs,
        COUNT(DISTINCT user_id || '|' || product_id)                            AS buyer_product_pairs
    FROM sales
),
model AS (
    SELECT
        COUNT(*)                                                                AS n,
        COUNT(DISTINCT product_id)                                              AS n_distinct,
        SUM(total_revenue)                                                      AS revenue,
        SUM(units_sold)                                                         AS units,
        SUM(discount_amount)                                                    AS discount_amount,
        SUM(times_ordered)                                                      AS times_ordered,
        SUM(distinct_buyers)                                                    AS distinct_buyers,
        SUM(CASE WHEN times_ordered IS NULL OR units_sold IS NULL OR distinct_buyers IS NULL
                   OR total_revenue IS NULL OR discount_amount IS NULL THEN 1 ELSE 0 END) AS n_null_metrics,
        SUM(CASE WHEN times_ordered > 0
                  AND ABS(avg_revenue_per_order - total_revenue / times_ordered) >= 0.01 THEN 1
                 WHEN times_ordered = 0 AND avg_revenue_per_order IS NOT NULL THEN 1
                 ELSE 0 END)                                                    AS n_bad_avg
    FROM rpt_product_sales
),
attr_mismatch AS (
    SELECT COUNT(*) AS n
    FROM rpt_product_sales r
    JOIN products p ON p.id = r.product_id
    WHERE r.product_name <> p.name OR r.category <> p.category
       OR r.catalog_price <> p.price OR r.stock <> p.stock
)

SELECT '1. one row per product (row count = products)' AS check_name,
       CASE WHEN m.n = s.n_products THEN 'PASS' ELSE 'FAIL' END AS result,
       CAST(s.n_products AS VARCHAR) AS expected, CAST(m.n AS VARCHAR) AS actual
FROM model m, src s
UNION ALL
SELECT '2. product_id is unique',
       CASE WHEN m.n = m.n_distinct THEN 'PASS' ELSE 'FAIL' END,
       CAST(m.n AS VARCHAR), CAST(m.n_distinct AS VARCHAR)
FROM model m
UNION ALL
SELECT '3. product attributes match the catalog',
       CASE WHEN a.n = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0 mismatches', CAST(a.n AS VARCHAR) || ' mismatches'
FROM attr_mismatch a
UNION ALL
SELECT '4. count and sum metrics are never NULL (use COALESCE)',
       CASE WHEN m.n_null_metrics = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0', CAST(m.n_null_metrics AS VARCHAR)
FROM model m
UNION ALL
SELECT '5. total_revenue reconciles with non-cancelled line_total',
       CASE WHEN ABS(m.revenue - s.revenue) < 0.01 THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.revenue AS VARCHAR), CAST(m.revenue AS VARCHAR)
FROM model m, src s
UNION ALL
SELECT '6. units_sold reconciles with non-cancelled quantity',
       CASE WHEN m.units = s.units THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.units AS VARCHAR), CAST(m.units AS VARCHAR)
FROM model m, src s
UNION ALL
SELECT '7. times_ordered counts distinct orders per product',
       CASE WHEN m.times_ordered = s.order_product_pairs THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.order_product_pairs AS VARCHAR), CAST(m.times_ordered AS VARCHAR)
FROM model m, src s
UNION ALL
SELECT '8. distinct_buyers counts distinct users per product',
       CASE WHEN m.distinct_buyers = s.buyer_product_pairs THEN 'PASS' ELSE 'FAIL' END,
       CAST(s.buyer_product_pairs AS VARCHAR), CAST(m.distinct_buyers AS VARCHAR)
FROM model m, src s
UNION ALL
SELECT '9. discount_amount is money (quantity * unit_price * discount)',
       CASE WHEN ABS(m.discount_amount - s.discount_amount) < 0.25 THEN 'PASS' ELSE 'FAIL' END,
       CAST(ROUND(s.discount_amount, 2) AS VARCHAR), CAST(m.discount_amount AS VARCHAR)
FROM model m, src s
UNION ALL
SELECT '10. avg_revenue_per_order = total_revenue / times_ordered (NULL if no orders)',
       CASE WHEN m.n_bad_avg = 0 THEN 'PASS' ELSE 'FAIL' END,
       '0 wrong rows', CAST(m.n_bad_avg AS VARCHAR) || ' wrong rows'
FROM model m;
