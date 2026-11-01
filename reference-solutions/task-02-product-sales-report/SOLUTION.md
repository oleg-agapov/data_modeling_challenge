# Reference solution 02 – Product Sales Report

## Conceptual Layer

The merchandising team thinks in **products**. Each question they ask ("how much did the sofa sell?", "how much discount did we give on dining tables?") is about one product at a time, so the output has one row per product.

Business entities involved:

- **Product** — an item in the catalog. It has a name, a category, a current price and a current stock level.
- **Order** — one purchase by a customer. It has a status; cancelled orders are not real sales.
- **Order line** — one product inside an order, with the price that was charged and the discount applied.
- **Customer** — the person who placed the order. I only need it to count distinct buyers.

Relationships:

```
Customer ──places──► Order ──contains──► Order line ◄──is sold as── Product
   (1:N)                       (1:N)                        (N:1)
```

**Grain of the output:** one row per product in the catalog, whether it has sold or not.

Decisions at this level:

- **Only non-cancelled orders count as sales.** Pending, shipped and delivered orders all count.
- **Products with no sales still appear**, with zero sales. An unsold product is important information for merchandising.


## Logical Layer

### Source tables

| Table | Grain | Columns I use |
|---|---|---|
| `products` | one row per product | `id`, `name`, `category`, `price`, `stock` |
| `order_items` | one row per order line | `order_id`, `product_id`, `quantity`, `unit_price`, `discount`, `line_total` |
| `orders` | one row per order | `order_id`, `user_id`, `order_status` |

### Output: `rpt_product_sales`

Grain: one row per product. Primary key: `product_id`.

| Column | Type | Derivation | Metric type |
|---|---|---|---|
| `product_id` | text | `products.id` | key |
| `product_name` | text | `products.name` | attribute |
| `category` | text | `products.category` | attribute |
| `catalog_price` | decimal(12,2) | `products.price` | attribute (current snapshot) |
| `stock` | integer | `products.stock` | attribute (current snapshot) |
| `times_ordered` | integer | `COUNT(DISTINCT order_id)` | count |
| `units_sold` | integer | `SUM(quantity)` | sum |
| `distinct_buyers` | integer | `COUNT(DISTINCT orders.user_id)` | distinct count |
| `total_revenue` | decimal(12,2) | `SUM(line_total)` | sum |
| `discount_amount` | decimal(12,2) | `SUM(quantity * unit_price * discount)`, rounded | sum |
| `avg_revenue_per_order` | decimal(12,2) | `total_revenue / times_ordered`, `NULL` if never ordered | ratio |

All metrics use non-cancelled order lines only.

### How the model is derived

1. **Filter and aggregate first.** Join `order_items` to `orders` (to get `order_status` and `user_id`), keep non-cancelled lines, and group by `product_id`. The result has one row per product *that sold*.
2. **Join to the spine.** `products` is the spine: it decides which rows appear. I `LEFT JOIN` the aggregated sales onto it, so unsold products are kept.
3. **Fill the gaps.** Counts and sums become `0` with `COALESCE` for unsold products. `avg_revenue_per_order` stays `NULL`, because an average over zero orders cannot be calculated.

### Decisions and trade-offs

- **`discount` is a rate, not money.** `SUM(discount)` would add up percentages from different lines, so I convert to an amount per line before summing.
- **I don't compare `unit_price` with `catalog_price`.** The dataset docs warn that some lines carry another product's price, so that comparison would be misleading.
- **The stock is a snapshot.** `stock` is the value at export time, not at the time of each sale. That's fine for "what do we have now" but limits any inventory analysis over time (see the stretch goal).
- **Every product has sales in this dataset**, so an `INNER JOIN` would happen to give the same 21 rows. I still use the `LEFT JOIN` from the spine, so the model stays correct when a new product is added.
- `distinct_buyers` is a distinct count. It can't be summed across products to get "total buyers", because a customer who bought two products would be counted twice.


## Physical Layer

### `rpt_product_sales`

```sql
CREATE OR REPLACE VIEW rpt_product_sales AS

-- 1. Non-cancelled order lines aggregated to product grain
WITH product_sales AS (
    SELECT
        oi.product_id,
        COUNT(DISTINCT oi.order_id)                           AS times_ordered,
        SUM(oi.quantity)                                      AS units_sold,
        COUNT(DISTINCT o.user_id)                             AS distinct_buyers,
        SUM(oi.line_total)                                    AS total_revenue,
        ROUND(SUM(oi.quantity * oi.unit_price * oi.discount), 2) AS discount_amount
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status <> 'cancelled'
    GROUP BY oi.product_id
)

-- 2. Products are the spine: every product appears, sold or not
SELECT
    p.id                                    AS product_id,
    p.name                                  AS product_name,
    p.category,
    p.price                                 AS catalog_price,
    p.stock,
    COALESCE(ps.times_ordered, 0)           AS times_ordered,
    COALESCE(ps.units_sold, 0)              AS units_sold,
    COALESCE(ps.distinct_buyers, 0)         AS distinct_buyers,
    COALESCE(ps.total_revenue, 0)           AS total_revenue,
    COALESCE(ps.discount_amount, 0)         AS discount_amount,
    ROUND(ps.total_revenue / NULLIF(ps.times_ordered, 0), 2) AS avg_revenue_per_order
FROM products p
LEFT JOIN product_sales ps ON ps.product_id = p.id;
```

### Validation queries

```sql
-- 1. One row per product
SELECT COUNT(*) AS model_rows, COUNT(DISTINCT product_id) AS distinct_products,
       (SELECT COUNT(*) FROM products) AS source_products
FROM rpt_product_sales;

-- 2. Revenue reconciles with non-cancelled order lines
SELECT
    (SELECT SUM(total_revenue) FROM rpt_product_sales) AS model_revenue,
    (SELECT SUM(oi.line_total)
     FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
     WHERE o.order_status <> 'cancelled')              AS source_revenue;

-- 3. NULL audit: metrics are never NULL, the average only for unsold products
SELECT
    SUM(CASE WHEN total_revenue IS NULL OR units_sold IS NULL THEN 1 ELSE 0 END)          AS null_metrics,
    SUM(CASE WHEN avg_revenue_per_order IS NULL AND times_ordered > 0 THEN 1 ELSE 0 END)  AS bad_null_avg
FROM rpt_product_sales;

-- 4. The report itself
SELECT product_name, category, times_ordered, total_revenue, discount_amount, avg_revenue_per_order
FROM rpt_product_sales
ORDER BY total_revenue DESC;
```

Results I got:

- 21 rows, 21 distinct products, 21 in the source.
- Revenue 630,677.32 in both the model and the source.
- No NULL metrics. `avg_revenue_per_order` is never NULL, because every product has at least one sale.
- Total `discount_amount` is 19,490.77. For comparison, `SUM(discount)` would have returned 44.65, a number with no business meaning.

All checks in [`checks.sql`](../../tasks/task-02-product-sales-report/checks.sql) pass.


## Stretch goal: sell-through rate

```sql
SELECT
    product_name,
    stock,
    units_sold,
    ROUND(units_sold / NULLIF(stock + units_sold, 0), 3) AS sell_through_rate
FROM rpt_product_sales
ORDER BY sell_through_rate DESC;
```

This estimate assumes that `stock + units_sold` was the amount available at the start of the period, which only holds if:

- the stock was never replenished during the two years,
- cancelled orders were returned to stock (or never left it),
- `stock` was exported at the end of the period covered by the orders.

None of this can be verified from a single stock snapshot. With a daily inventory snapshot table, sell-through could be calculated per period instead.
