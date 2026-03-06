# Task 01 – Revenue Reporting

**Difficulty**: Easy ⭐️

**Data source**: data/ecommerce

**Theory**: [The Three Layers of Data Modeling](THEORY.md)

---

## Context

The finance team needs a reliable, order-grained foundation for revenue reporting. Rather than a pre-aggregated summary, they want a model where each row represents one order — enriched with revenue and item metrics — so that any downstream aggregation (daily, monthly, by status, by user, etc.) can be computed on top of it.

---

## Goal

Build an **order-level fact table** with one row per `order_id`. The model must be rich enough that the following metrics can be derived from it directly, without joining back to the source tables:

- **Order count** — total number of orders (overall or by any dimension)
- **Gross revenue** — total revenue across orders
- **Average order value (AOV)** — mean revenue per order
- **ARPU** (Average Revenue Per User) — total revenue divided by the number of distinct users
- **Status split** — distribution of orders and revenue across `pending`, `shipped`, `delivered`, and `cancelled`

In this exercise you should use the **following files**:

- `data/ecommerce/orders.csv`
- `data/ecommerce/order_items.csv`
- `data/ecommerce/users.csv`

---

## Hints

<details>
<summary>
Hint 1. Required output columns
</summary>

| Column | Description |
|---|---|
| `order_id` | Primary key — unique identifier for the order (`orders.id`) |
| `user_id` | The customer who placed the order (`orders.user_id`) |
| `date_ordered` | Timestamp of when the order was placed |
| `status` | Order status: `pending`, `shipped`, `delivered`, or `cancelled` |
| `payment_method` | Payment method used for the order |
| `total_items` | Sum of `quantity` across all line items for this order |
| `gross_revenue` | Sum of `line_total` across all line items for this order |

</details>


<details>
<summary>
Hint 2. Additional guidance
</summary>

- Aggregate `order_items` to order grain first (e.g. a CTE or subquery), then join to `orders` to avoid row fan-out.
- Join `orders` to `order_items` on `order_items.order_id = orders.id`.
- Aggregate `order_items` to order grain **before** (or within) the final join — the output must have exactly one row per `order_id`.
- Retain **all** orders regardless of status; the `status` column allows consumers to filter or pivot as needed.
- Validate revenue: compare `gross_revenue` (derived from `order_items.line_total`) against `orders.total_amount`. Flag or document any discrepancies — if they diverge, prefer the `order_items` sum as the authoritative revenue figure.

</details>
