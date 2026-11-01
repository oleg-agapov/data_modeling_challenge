# Task 06 – Event Enrichment & Cart Abandonment

## Context

The marketing team wants to run a "you left something in your cart" email campaign. To do that, they need to know which users added which products to their cart but never bought them.

Clickstream events are stored one row per event, with only IDs for the user and the product. Before anyone can analyze them comfortably, they need to be **enriched** with user and product details. Purchases are not tracked as events at all: they live in `orders` and `order_items`, so finding what was *not* bought means comparing two different sources.

## Goal

Build two layered models on top of `user_events`:

1. An **enriched events table** (`enriched_events`): one row per event, with user and product attributes added.
2. A **cart abandonment report** (`cart_abandonment`): one row per user × product pair that was added to the cart but never purchased.

In this exercise you should use the **following files**:

- `data/ecommerce/user_events.csv`
- `data/ecommerce/users.csv`
- `data/ecommerce/products.csv`
- `data/ecommerce/orders.csv`
- `data/ecommerce/order_items.csv`

## Deliverables

Fill in the `SOLUTION.md` file in this directory. It must cover three sections:

1. **Conceptual layer** — describe events, carts and purchases, how they relate, and the grain of each output model in plain language.
2. **Logical layer** — define the tables, columns, data types, and keys involved; explain how raw events are enriched and how carted products are matched against purchases.
3. **Physical layer** — provide the SQL for Parts A and B. A plain `SELECT` is fine; `CREATE VIEW` or `CREATE TABLE AS SELECT` are also welcome if you want to persist the model.

You are free to enrich your solution with anything that helps communicate your thinking: diagrams (e.g. [Excalidraw](https://excalidraw.com/), [DrawDB](https://www.drawdb.app)), links, screenshots, or extra explanation. There is no strict format — clarity and correctness matter most.

## Before you submit

Use this checklist to review your `SOLUTION.md` before you call the task done. These points cover the thinking a reviewer would look for.

- [ ] You state the grain of `enriched_events` and of `cart_abandonment`.
- [ ] `enriched_events` has exactly as many rows as `user_events`, and events without a product are still there.
- [ ] You write down your definition of an abandoned cart, including how cancelled orders and timing are treated.
- [ ] Each (user, product) pair appears only once in `cart_abandonment`.
- [ ] You explain which anti-join pattern you used and why `NOT IN` is risky.
- [ ] You explain which layer each model belongs to (enriched vs mart) and why `cart_abandonment` can be built on top of `enriched_events`.

## Hints

<details>
<summary>
Hint 1. Part A – Enriched events (denormalization)
</summary>

Produce a flat table `enriched_events` with one row per event, combining event data with user and product attributes.

| Column | Source | Notes |
|---|---|---|
| `event_id` | `user_events.event_id` | |
| `event_type` | `user_events.event_type` | |
| `event_timestamp` | `user_events.event_timestamp` | |
| `page_url` | `user_events.page_url` | |
| `user_id` | `user_events.user_id` | |
| `user_email` | `users.email` | Denormalized |
| `user_registered_at` | `users.created_at` | Denormalized |
| `product_id` | `user_events.product_id` | Nullable |
| `product_name` | `products.name` | Denormalized; `NULL` when no product |
| `product_category` | `products.category` | Denormalized; `NULL` when no product |
| `product_catalog_price` | `products.price` | Denormalized; `NULL` when no product |

Use `LEFT JOIN` for both `users` and `products` so that events without a product are preserved. The row count must equal the row count of `user_events`.

</details>


<details>
<summary>
Hint 2. Part B – Cart abandonment report
</summary>

Identify **user × product pairs** where the user added the product to their cart but **never placed a completed order** for it.

Definition:
- The user has at least one `add_to_cart` event for a given `product_id`.
- There is **no** non-cancelled order in `orders` that contains a matching `order_items` row for the same `user_id` + `product_id` combination.

### Output table: `cart_abandonment`

| Column | Description |
|---|---|
| `user_id` | User who abandoned the cart |
| `user_email` | From `users` |
| `product_id` | Product that was carted but not bought |
| `product_name` | From `products` |
| `product_category` | From `products` |
| `product_catalog_price` | From `products` |
| `first_carted_at` | Earliest `add_to_cart` event timestamp for this pair |
| `last_carted_at` | Most recent `add_to_cart` event timestamp |
| `cart_count` | Total number of times the product was added to the cart |

Sort by `cart_count` descending, then `last_carted_at` descending.

</details>


<details>
<summary>
Hint 3. Requirements and additional guidance
</summary>

1. Both parts must be expressed as **CTEs or views** — do not use temporary tables stored outside the query.
2. Part B must use either a `LEFT JOIN … WHERE … IS NULL` anti-join or a `NOT EXISTS` subquery — **not** `NOT IN` (due to NULL-safety concerns).

- Part B can be built on top of `enriched_events` from Part A: filter it to `add_to_cart` events and you already have the user and product attributes.
- Aggregate the cart events to the **user × product** grain *before* the anti-join, so each pair appears once.
- For the anti-join, you need the `(user_id, product_id)` pairs that were actually purchased: join `orders` to `order_items` and keep non-cancelled orders only.
- The `add_to_cart` events always have `product_id` populated; verify this with a quick count before building the anti-join.
- Don't try to link cart events to product views: in this dataset, many add-to-cart events have no earlier view of the same product (see [Known quirks](../../data/ecommerce.md#known-quirks)).

</details>


<details>
<summary>
Hint 4. Stretch goal
</summary>

Build a product-level summary `product_cart_abandonment` with one row per product:

| Column | Description |
|---|---|
| `product_id`, `product_name`, `product_category` | From `products` |
| `users_carted` | Distinct users who added the product to their cart |
| `users_abandoned` | Distinct users who carted it but never bought it |
| `abandonment_rate` | `users_abandoned / users_carted` |

Which category has the highest abandonment rate? In your solution, explain why `abandonment_rate` must be computed from the two counts rather than averaged from another table.

</details>
