# Theory – Grain Choices, Aggregation Patterns, and Join Safety

Task 01 introduced the three modeling layers and the concept of grain. This task applies those ideas to a different grain — the **product level** — and introduces the practical mechanics that make or break analytical queries: aggregation order, join type selection, and NULL handling.

---

## Revisiting Grain: From Order to Product

In Task 01, the grain was *one row per order*. Here the grain is *one row per product*. That shift changes everything:

- The "spine" of the query is now the `products` table, not `orders`.
- Revenue and sales metrics must be collapsed from `order_items` (many rows per product) into a single summary row per product.
- Products with zero sales must still appear — a business cares about unsold inventory, not just what moved.

Grain is a **design decision**, not something you discover after writing SQL. Making it explicit upfront prevents you from writing queries that produce the wrong number of rows.

---

## Join Type Selection: LEFT JOIN vs INNER JOIN

This is one of the most consequential decisions in analytical modeling.

### INNER JOIN — use when both sides must exist

An `INNER JOIN` silently drops rows from either side that have no match. In an operational context this is often fine. In an analytical model it creates **silent data loss** that is very hard to detect.

```sql
-- BAD: drops products with no sales
SELECT p.id, SUM(oi.line_total)
FROM order_items oi
JOIN products p ON p.id = oi.product_id
GROUP BY p.id
```

### LEFT JOIN — use when the left side must be complete

When you need every row from one side regardless of whether a match exists on the other:

```sql
-- GOOD: keeps all products, even those with zero sales
SELECT p.id, COALESCE(SUM(oi.line_total), 0) AS total_revenue
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.id
GROUP BY p.id
```

**Rule of thumb:** In a product/customer/date-spined report, always `LEFT JOIN` from the spine into event or transaction tables. The spine defines what appears in the output; the transaction side defines the measures.

---

## Aggregation Order: Pre-aggregate Before Joining

A recurring trap: joining first, filtering second. When `order_items` is joined to `orders` to get `status`, you must apply the status filter **before** aggregating — or you will aggregate over all rows and then silently filter away some of the result.

The safe pattern is CTEs with explicit grain:

```sql
-- Step 1: filter and aggregate order_items to product grain
WITH product_sales AS (
    SELECT
        oi.product_id,
        COUNT(DISTINCT oi.order_id)  AS times_ordered,
        SUM(oi.quantity)             AS units_sold,
        SUM(oi.line_total)           AS total_revenue
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id
    WHERE o.status != 'cancelled'      -- filter BEFORE aggregation
    GROUP BY oi.product_id
)
-- Step 2: join the pre-aggregated CTE back to the spine
SELECT p.id, p.name, COALESCE(ps.total_revenue, 0)
FROM products p
LEFT JOIN product_sales ps ON ps.product_id = p.id
```

Each CTE has a declared grain. The final `SELECT` just combines them.

---

## NULL Handling: COALESCE and NULLIF

Two SQL functions that every analytical engineer uses constantly:

### COALESCE — replace NULL with a default

When a `LEFT JOIN` finds no match, all columns from the right side are `NULL`. For numeric metrics, this `NULL` should usually be `0`:

```sql
COALESCE(ps.units_sold, 0)   -- 0 for products with no sales
```

For metrics that are genuinely undefined (e.g., average selling price for an unsold product), leave them as `NULL`. A `NULL` communicates "this is unknown" — overwriting it with `0` would claim the product sold at zero price, which is wrong.

### NULLIF — prevent division by zero

Division by zero causes a runtime error. `NULLIF(denominator, 0)` returns `NULL` when the denominator is zero, which propagates cleanly through arithmetic:

```sql
total_revenue / NULLIF(times_ordered, 0)  -- NULL instead of error
```

---

## Metrics Taxonomy: What Makes a "Good" Metric

When designing a product-level model, it helps to classify every metric you compute:

| Type | Definition | Example |
|---|---|---|
| **Count** | Raw volume of events | `times_ordered`, `units_sold` |
| **Sum** | Additive total | `total_revenue`, `total_discount` |
| **Average** | Sum ÷ count | `avg_selling_price` |
| **Derived / Ratio** | Computed from other metrics | `price_diff`, `sell_through_rate` |

Counts and sums are the most reliable — they can be `SUM`'d further up the reporting chain. Averages and ratios are **not** re-aggregatable: if you average product-level `avg_selling_price` across products you get a simple mean that ignores volume. Store the components (sum, count) in the model and let consumers compute averages themselves when needed.

---

## Validating Your Model

Once you have built the product-level report, always run sanity checks:

1. **Row count** — equals the number of distinct products in `products.csv`.
2. **Revenue reconciliation** — `SUM(total_revenue)` in your output should equal `SUM(oi.line_total)` from `order_items` filtered to non-cancelled orders.
3. **NULL audit** — confirm that `product_id` and `product_name` are never `NULL`; confirm that `avg_selling_price` is `NULL` only for products with zero sales.

These three checks catch the majority of fan-out bugs, silent filter errors, and join direction mistakes.
