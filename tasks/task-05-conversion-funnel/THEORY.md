# Theory – Event-Driven Modeling, Funnels, and Cohort Analysis

Previous tasks modeled **transactions** — discrete events with a clear dollar value (orders, bookings). This task models **behavior** — a stream of raw user actions that must be shaped into something analytically useful. This is a different kind of modeling challenge.

---

## From Transactions to Events

An order has a natural grain: one row per order. Events are messier. A single user might generate hundreds of `page_view` events in one session. Raw event tables are:

- **Wide** in time (events arrive continuously)
- **Narrow** in meaning (each row knows only what happened at that moment)
- **Sparse** (most columns are NULL for most event types)

To make events analytically useful you must transform them into **aggregated behavioral summaries** — tables where one row represents a user, a session, or a cohort, and columns represent things that happened (flags, counts, timestamps).

---

## The Funnel Model

A conversion funnel is the most common behavioral analytic pattern. It maps the journey from first contact to purchase, with each step representing a behavioral milestone:

```
Registered → Viewed a product → Added to cart → Purchased
```

Every step is a strict subset of the previous one — you cannot purchase without having registered. The model you build must capture:

1. **Whether** a user reached each milestone (a boolean flag per stage)
2. **When** they first reached it (a timestamp)
3. **The drop-off** at each transition

### Modeling pattern: per-user milestone flags

The building block is a single flat row per user with one boolean per milestone:

```sql
SELECT
    u.user_id,
    MAX(CASE WHEN ue.event_type = 'page_view' AND ue.product_id IS NOT NULL
             THEN 1 ELSE 0 END)  AS did_view_product,
    MAX(CASE WHEN ue.event_type = 'add_to_cart'
             THEN 1 ELSE 0 END)  AS did_add_to_cart
FROM users u
LEFT JOIN user_events ue ON ue.user_id = u.user_id
GROUP BY u.user_id
```

The `MAX(CASE WHEN …)` pattern is the idiomatic way to pivot event types into boolean columns within a single aggregation.

**Why `LEFT JOIN` from `users`?** Because the funnel denominator is "all registered users", including those who never generated any events. An `INNER JOIN` would undercount the total and inflate all conversion percentages.

### Pre-aggregating events before joining

Joining unaggregated `user_events` directly to `users` creates a fan-out: a user with 500 events would appear as 500 rows. Always aggregate events into a per-user CTE first:

```sql
-- Step 1: aggregate events to user grain
WITH user_event_flags AS (
    SELECT
        user_id,
        MAX(CASE WHEN event_type = 'page_view' AND product_id IS NOT NULL
                 THEN 1 ELSE 0 END) AS did_view_product,
        MAX(CASE WHEN event_type = 'add_to_cart'
                 THEN 1 ELSE 0 END) AS did_add_to_cart
    FROM user_events
    GROUP BY user_id
)
-- Step 2: join the aggregated CTE to the user spine
SELECT u.id, uef.did_view_product, uef.did_add_to_cart
FROM users u
LEFT JOIN user_event_flags uef ON uef.user_id = u.id
```

---

## Funnel Stage Summary: UNION ALL Pattern

The per-user table answers "what did this user do?" The stage summary answers "how many users reached each stage?" These are two different grains and should be two different models.

A `UNION ALL` of four `SELECT` statements is the clearest way to build the summary:

```sql
SELECT 'registered'     AS stage, COUNT(*)  AS users_reached FROM funnel_users
UNION ALL
SELECT 'viewed_product' AS stage, SUM(did_view_product)  FROM funnel_users
UNION ALL
SELECT 'added_to_cart'  AS stage, SUM(did_add_to_cart)   FROM funnel_users
UNION ALL
SELECT 'purchased'      AS stage, SUM(did_purchase)      FROM funnel_users
```

`pct_of_registered` is then computed by dividing each count by the first count. Use a subquery or window function to avoid a second full scan:

```sql
-- Using a window function to carry the total across rows
SUM(users_reached) OVER ()  -- This gives the total in all rows, not what we want
-- Instead: divide by a fixed subquery reference or use the first row's value
```

---

## Cohort Analysis

A **cohort** is a group of users who share a common characteristic at a common point in time. The most common analytical cohort is **registration month**: "all users who signed up in January 2024."

Cohort analysis answers the question: *are newer users behaving differently from older ones?* This is crucial for product teams — if the conversion rate of the March 2024 cohort is higher than the January 2024 cohort, something changed for the better.

### Implementation

```sql
DATE_TRUNC('month', registered_at) AS cohort_month
```

Group the per-user funnel table by this column, then compute conversion rates per cohort. The result is a matrix:

| cohort_month | registered | viewed_product | purchased | conversion_rate |
|---|---|---|---|---|
| 2024-01 | 1,200 | 840 | 156 | 13.0% |
| 2024-02 | 1,450 | 1,088 | 232 | 16.0% |
| 2024-03 | 980 | 784 | 176 | 18.0% |

### Cohort maturity bias

Older cohorts have had more time to convert. A January cohort measured in December is more "mature" than a November cohort measured in December. When comparing conversion rates across cohorts, you may want to normalize by **days since registration** rather than comparing raw rates — otherwise older cohorts will always look better.

---

## Days-to-Purchase: A Behavioral Metric

`days_to_first_purchase = first_purchase_at - registered_at` is a simple but powerful metric. It answers:

- How quickly does the product convert new users?
- Do high-value customers buy faster or slower?
- Is the funnel getting faster for recent cohorts?

Design notes:
- Users who never purchased should have `NULL`, not `0` — zero would imply they purchased on the day they registered.
- Be careful with timestamp vs. date arithmetic: if `registered_at` is a timestamp and `first_purchase_at` is a timestamp, the difference in SQL may return fractional days. Cast to `DATE` first if you want whole-day counts.

---

## Key Modeling Principles for This Task

| Principle | Application |
|---|---|
| Always start from the spine | Start from `users` so every user appears, even with no events |
| Aggregate before joining | Pre-aggregate `user_events` by user before the final join |
| Preserve NULLs meaningfully | `NULL` in `first_purchase_at` means "never purchased", not missing data |
| Two grains = two tables | Per-user detail table + aggregated funnel summary are separate deliverables |
| Document your denominator | "Conversion rate" is meaningless without knowing the denominator — always be explicit |
