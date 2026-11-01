# Task 05 – User Conversion Funnel

## Context

The product analytics team wants to measure how effectively the platform converts newly registered users into buyers. They track three key behavioral milestones before a purchase: signing up, viewing a product page, and adding an item to the cart. Mapping the drop-off between each stage reveals where to focus optimisation effort.


## Goal

Build a **per-user funnel table** and then aggregate it into **funnel stage counts**.

In this exercise you should use the **following files**:

- `data/ecommerce/users.csv`
- `data/ecommerce/user_events.csv`
- `data/ecommerce/orders.csv`

## Deliverables

Fill in the `SOLUTION.md` file in this directory. It must cover three sections:

1. **Conceptual layer** — describe the business entities, the funnel milestones, and the grain of each output model in plain language.
2. **Logical layer** — define the tables, columns, data types, and keys involved; explain how the source tables are transformed into the output models.
3. **Physical layer** — provide the SQL for Part A and Part B. A plain `SELECT` is fine; `CREATE VIEW` or `CREATE TABLE AS SELECT` are also welcome if you want to persist the model.

You are free to enrich your solution with anything that helps communicate your thinking: diagrams (e.g. [Excalidraw](https://excalidraw.com/), [DrawDB](https://www.drawdb.app)), links, screenshots, or extra explanation. There is no strict format — clarity and correctness matter most.

## Before you submit

Use this checklist to review your `SOLUTION.md` before you call the task done. These points cover the thinking a reviewer would look for.

- [ ] You state the grain of both outputs: the per-user table and the stage summary.
- [ ] Your per-user table has exactly one row per registered user (compare its row count with `users`).
- [ ] You say what the denominator of every percentage is.
- [ ] You explain how cancelled orders are handled when deciding whether a user purchased.
- [ ] You explain what `NULL` means in `first_purchase_at` and `minutes_to_first_purchase`, and why it isn't `0`.
- [ ] You check that each funnel stage is no larger than the previous one, and say what you'd do if it were.
- [ ] Your SQL aggregates events per user before joining them to `users`.

## Hints

<details>
<summary>
Hint 1. Part A - Per-user milestone flags
</summary>

Produce one row per user with the following columns:

| Column | Type | Description |
|---|---|---|
| `user_id` | UUID | User identifier |
| `registered_at` | datetime | `users.created_at` |
| `did_view_product` | boolean/int | User has at least one `page_view` event with a non-null `product_id` |
| `did_add_to_cart` | boolean/int | User has at least one `add_to_cart` event |
| `did_purchase` | boolean/int | User has at least one non-cancelled order in `orders` |
| `first_purchase_at` | datetime | Timestamp of the user's earliest non-cancelled order, or `NULL` |
| `minutes_to_first_purchase` | integer | Whole minutes between `registered_at` and `first_purchase_at`, or `NULL` |

Requirements:
- Start from `users` so that every registered user appears, even those with no events and no orders.
- Join `user_events` with `LEFT JOIN`; aggregate events before joining to avoid row explosion.
- Join `orders` with `LEFT JOIN` filtered to non-cancelled orders. Put the filter in a pre-aggregated CTE (or in the `ON` clause), not in the final `WHERE`: a `WHERE` on the right-hand table silently turns the `LEFT JOIN` into an `INNER JOIN` and drops users who never ordered.
- In this dataset every user has a single short visit, and buyers order within about 10 minutes of signing up. That's why the time metric is in minutes, not days (see the [dataset docs](../../data/ecommerce.md#user_eventscsv)).

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
