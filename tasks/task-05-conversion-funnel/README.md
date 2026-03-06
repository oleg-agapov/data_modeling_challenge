# Task 05 – User Conversion Funnel

**Difficulty**: Hard ⭐️⭐️⭐️

**Data source**: data/ecommerce

**Theory**: [Event-Driven Modeling, Funnels, and Cohort Analysis](THEORY.md)


## Context

The product analytics team wants to measure how effectively the platform converts visitors into buyers. They track three key behavioral milestones before a purchase: signing up, viewing a product page, and adding an item to the cart. Mapping the drop-off between each stage reveals where to focus optimisation effort.


## Goal

Build a **per-user funnel table** and then aggregate it into **funnel stage counts**.


## Deliverables

1. `1-conceptual-layer.png`: a conceptual layer diagram of entities and milestones. Use [excalidraw](https://excalidraw.com/) or a similar app.
1. `2-logical-layer.png`: draw the logical layer in [DrawDB](https://www.drawdb.app).
1. `3-physical-layer.sql`: a script with SQL models for Part A and Part B (SELECT-only). Use [PondPilot](pondpilot.io) to upload source data and create SQL.

## Hints

<details>
<summary>
Hint 1. Part A - Per-user milestone flags
</summary>

Produce one row per user with the following columns:

| Column | Type | Description |
|---|---|---|
| `user_id` | UUID | User identifier |
| `registered_at` | datetime | `users.created_on` |
| `did_view_product` | boolean/int | User has at least one `page_view` event with a non-null `product_id` |
| `did_add_to_cart` | boolean/int | User has at least one `add_to_cart` event |
| `did_purchase` | boolean/int | User has at least one non-cancelled order in `orders` |
| `first_purchase_at` | datetime | Timestamp of the user's earliest non-cancelled order, or `NULL` |
| `days_to_first_purchase` | integer | Days between `registered_at` and `first_purchase_at`, or `NULL` |

Requirements:
- Start from `users` so that every registered user appears, even those with no events and no orders.
- Join `user_events` with `LEFT JOIN`; aggregate events before joining to avoid row explosion.
- Join `orders` with `LEFT JOIN` filtered to non-cancelled orders.

</details>


<details>
<summary>
Hint 2. Part B - Funnel stage summary
</summary>

Aggregate the Part A result into a single summary table with one row per funnel stage:

| stage | users_reached | pct_of_registered |
|---|---|---|
| `registered` | - | 100 % |
| `viewed_product` | - | - |
| `added_to_cart` | - | - |
| `purchased` | - | - |

`pct_of_registered` is the share of the total registered user base that reached each stage.

</details>


<details>
<summary>
Hint 3. Additional guidance
</summary>

- Pre-aggregate `user_events` in a CTE (`GROUP BY user_id, event_type`) before joining to `users`, to keep the join cardinality manageable.
- `MAX(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END)` is a clean pattern for boolean flags from aggregation.
- For the funnel summary, a `UNION ALL` of four `SELECT` statements is often the simplest approach.

</details>


<details>
<summary>
Hint 4. Stretch goal
</summary>

Break down the funnel by user **cohort month** (`DATE_TRUNC('month', registered_at)`) to show whether conversion rates have improved over time.

</details>
