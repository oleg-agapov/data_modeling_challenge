# Task 04 – User Conversion Funnel

**Difficulty:** Hard ⭐️⭐️⭐️
**Files used:**
- `user_events.csv`
- `orders.csv`
- `users.csv`

---

## Context

The product analytics team wants to measure how effectively the platform converts visitors into buyers. They track three key behavioral milestones before a purchase: signing up, viewing a product page, and adding an item to the cart. Mapping the drop-off between each stage reveals where to focus optimisation effort.

---

## Goal

Build a **per-user funnel table** and then aggregate it into **funnel stage counts**.

---

## Part A – Per-user milestone flags

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

---

## Part B – Funnel stage summary

Aggregate the Part A result into a single summary table with one row per funnel stage:

| stage | users_reached | pct_of_registered |
|---|---|---|
| `registered` | — | 100 % |
| `viewed_product` | — | — |
| `added_to_cart` | — | — |
| `purchased` | — | — |

`pct_of_registered` is the share of the total registered user base that reached each stage.

---

## Hints

- Pre-aggregate `user_events` in a CTE (`GROUP BY user_id, event_type`) before joining to `users`, to keep the join cardinality manageable.
- `MAX(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END)` is a clean pattern for boolean flags from aggregation.
- For the funnel summary, a `UNION ALL` of four `SELECT` statements is often the simplest approach.

---

## Stretch goal

Break down the funnel by user **cohort month** (`DATE_TRUNC('month', registered_at)`) to show whether conversion rates have improved over time.
