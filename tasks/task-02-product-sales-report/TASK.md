# Task 02 – Product Sales Report

## Context

The merchandising team needs to understand how each product is selling. They want to see sales volume and revenue per product, understand how much money is given away through discounts, and compare current stock levels with how fast each product sells — all in a single product-level view.

## Goal

Build a **product-level sales report** named `rpt_product_sales`, with one row per product. All sales metrics should reflect only non-cancelled orders.

In this exercise you should use the **following files**:

- `data/ecommerce/products.csv`
- `data/ecommerce/order_items.csv`
- `data/ecommerce/orders.csv`

## Deliverables

Fill in the `SOLUTION.md` file in this directory. It must cover three sections:

1. **Conceptual layer** — describe the business entities, their relationships, and the grain of the output model in plain language.
2. **Logical layer** — define the tables, columns, data types, and keys involved; explain how the source tables relate to each other and how the output model is derived.
3. **Physical layer** — provide the SQL that builds the model. A plain `SELECT` is fine; `CREATE VIEW` or `CREATE TABLE AS SELECT` are also welcome if you want to persist the model.

You are free to enrich your solution with anything that helps communicate your thinking: diagrams (e.g. [Excalidraw](https://excalidraw.com/), [DrawDB](https://www.drawdb.app)), links, screenshots, or extra explanation. There is no strict format — clarity and correctness matter most.

## Check your solution

When your model is built, run the automatic checks from the repository root, in the same database:

```sql
.read tasks/task-02-product-sales-report/checks.sql
```

(In the browser or another SQL tool, open [`checks.sql`](checks.sql), copy it, and run it.) The checks look for a model named `rpt_product_sales` with the column names from the hints. Every row should say `PASS`; a `FAIL` row shows the expected and actual values, so you can find the bug.

When everything passes, compare your reasoning with the [reference solution](../../reference-solutions/task-02-product-sales-report/SOLUTION.md). Try the task on your own first!

## Before you submit

Use this checklist to review your `SOLUTION.md` before you call the task done. The automatic checks test your SQL; these points cover the thinking that SQL can't show.

- [ ] You state the grain of the report and name the table that acts as the spine.
- [ ] You explain why the join from `products` is a `LEFT JOIN`, and what an unsold product would look like in your output.
- [ ] You show where the filter on cancelled orders is applied, and why it must happen before the aggregation (or in the join), not after.
- [ ] You explain that `discount` is a rate and how you turned it into money.
- [ ] You say which columns can be summed across products and which can't (`distinct_buyers`, `avg_revenue_per_order`).
- [ ] You mention the limits of the data you rely on, for example that `stock` is a single snapshot.
- [ ] `checks.sql` passes.

## Hints

<details>
<summary>
Hint 1. Required output columns
</summary>

| Column | Description |
|---|---|
| `product_id` | Product UUID |
| `product_name` | Product display name (`products.name`) |
| `category` | Product category (`Living Room`, `Bedroom`, or `Kitchen`) |
| `catalog_price` | Current list price from `products.price` |
| `stock` | Current inventory quantity from `products.stock` |
| `times_ordered` | Number of distinct orders containing this product (non-cancelled only) |
| `units_sold` | Total `quantity` sold across non-cancelled line items |
| `distinct_buyers` | Number of distinct users who purchased this product |
| `total_revenue` | Sum of `line_total` across non-cancelled line items |
| `discount_amount` | Money given away as discounts: sum of `quantity * unit_price * discount` across non-cancelled line items (`discount` is a rate, e.g. `0.15` = 15%) |
| `avg_revenue_per_order` | `total_revenue / times_ordered`; `NULL` when the product has no orders |

</details>


<details>
<summary>
Hint 2. Additional guidance
</summary>

- Aggregate `order_items` (filtered to non-cancelled orders) into a product-level CTE first, then `LEFT JOIN` that to `products` — this avoids accidentally dropping unsold products when filtering.
- `distinct_buyers` requires `COUNT(DISTINCT orders.user_id)` since `user_id` lives on `orders`, not `order_items`.
- In the current dataset `quantity` is always `1`, so `units_sold` and `times_ordered` will likely be equal — but model against the column definition, not the observed shortcut.
- `discount` is a rate, not an amount. Summing it directly gives a meaningless number; convert it to money first (`quantity * unit_price * discount`), and round the result to 2 decimals.
- Compute `avg_revenue_per_order` with `NULLIF(times_ordered, 0)` in the denominator to avoid division by zero.
- Join `order_items` to `products` on `order_items.product_id = products.id`.
- Join `order_items` to `orders` on `order_items.order_id = orders.order_id` to access order status and `user_id`.
- **Exclude cancelled orders** (`orders.order_status = 'cancelled'`) from all sales metrics.
- Include **all products** in the output, even those with zero sales — use a `LEFT JOIN` from `products` into the sales aggregation. In the current dataset every product has at least one sale, so an `INNER JOIN` would happen to return the same rows. Build the model so it stays correct when a new, unsold product is added to the catalog.
- For products with no sales, count and sum columns should be `0` (use `COALESCE`); `avg_revenue_per_order` should be `NULL`.
- Don't compare `unit_price` with the catalog price: some order lines carry another product's price (see [Known quirks](../../data/ecommerce.md#known-quirks)).

</details>


<details>
<summary>
Hint 3. Stretch goal
</summary>

- Add a `sell_through_rate` column defined as `units_sold / NULLIF(products.stock + units_sold, 0)`.
- Discuss assumptions required for this estimate (for example, static stock snapshot vs. historical inventory movement).

</details>
