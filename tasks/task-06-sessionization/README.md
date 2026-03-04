# Task 06 – Sessionization & Cart Abandonment Analysis

**Difficulty:** Hard ⭐️⭐️⭐️
**Files used:**
- `user_events.csv`
- `products.csv`
- `orders.csv`
- `users.csv`

---

## Context

Raw clickstream events are stored one row at a time. To reason about user behaviour at the *visit* level, events must first be **sessionized** — grouped into discrete browsing sessions separated by a 30-minute inactivity gap. Once sessions exist, you can identify **cart abandonment**: users who added a product to their cart during a session but never placed an order for it.

---

## Goal

Build three layered artefacts on top of `user_events`:

1. An **enriched events table** (denormalized flat view)
2. A **session table** (one row per session)
3. A **cart abandonment report** (one row per user/product pair that was carted but not purchased)

---

## Part A – Enriched events (denormalization)

Produce a flat table `enriched_events` with one row per event, combining event data with user and product attributes.

| Column | Source | Notes |
|---|---|---|
| `event_id` | `user_events.event_id` | |
| `event_type` | `user_events.event_type` | |
| `event_timestamp` | `user_events.event_timestamp` | |
| `page_url` | `user_events.page_url` | |
| `user_id` | `user_events.user_id` | |
| `user_email` | `users.email` | Denormalized |
| `user_registered_at` | `users.created_on` | Denormalized |
| `product_id` | `user_events.product_id` | Nullable |
| `product_name` | `products.name` | Denormalized; `NULL` when no product |
| `product_category` | `products.category` | Denormalized; `NULL` when no product |
| `product_catalog_price` | `products.price` | Denormalized; `NULL` when no product |

Use `LEFT JOIN` for both `users` and `products` so that events with no associated product are preserved.

---

## Part B – Sessionization

Using a **30-minute inactivity gap** rule, assign a session identifier to every event.

A new session starts when the gap between the current event and the previous event from the **same user** exceeds 30 minutes (or when it is the user's first event).

### Steps

1. Use `LAG(event_timestamp) OVER (PARTITION BY user_id ORDER BY event_timestamp)` to get the previous event's timestamp.
2. Flag each event as a **session start** when the gap > 30 minutes (or `LAG` is `NULL`).
3. Use `SUM(is_session_start) OVER (PARTITION BY user_id ORDER BY event_timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` to produce a monotonically increasing session counter per user.
4. Concatenate `user_id` and the counter to form a globally unique `session_id`.

### `sessions` table (one row per session)

| Column | Description |
|---|---|
| `session_id` | Unique session identifier |
| `user_id` | User who owns the session |
| `session_start` | Timestamp of the first event in the session |
| `session_end` | Timestamp of the last event in the session |
| `duration_minutes` | `session_end - session_start` in minutes |
| `event_count` | Total events in the session |
| `page_view_count` | Events with `event_type = 'page_view'` |
| `add_to_cart_count` | Events with `event_type = 'add_to_cart'` |
| `distinct_products_viewed` | Distinct non-null `product_id` values seen in the session |

---

## Part C – Cart abandonment report

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

---

## Requirements

1. All three parts must be expressed as **CTEs or views** — do not use temporary tables stored outside the query.
2. The sessionization logic in Part B must not rely on hard-coded session IDs.
3. Part C must use either a `LEFT JOIN … WHERE … IS NULL` anti-join or a `NOT EXISTS` subquery — **not** `NOT IN` (due to NULL-safety concerns).

---

## Hints

- Sessionization is easier to reason about when done in two CTEs: one that computes the lag gap and session-start flag, and a second that computes the running sum.
- For Part C, you need to join `orders` to `order_items` first to get the `(user_id, product_id)` pairs that were actually purchased.
- The `add_to_cart` events have `product_id` populated; verify this with a quick count before building the anti-join.

---

## Stretch goal

Compute a **session-level conversion flag**: for each session, determine whether the user placed at least one order within 24 hours of the session ending. Add this as an `is_converted_session` boolean column to the `sessions` table.
