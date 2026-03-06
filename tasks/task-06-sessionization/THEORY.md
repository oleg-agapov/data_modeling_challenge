# Theory – Sessionization, Window Functions, and Anti-Join Patterns

This task sits at the advanced end of analytical SQL. It combines three techniques that together cover the majority of behavioral analytics work in production data warehouses: **sessionization**, **window functions**, and **anti-joins**. Each builds on patterns you have used in earlier tasks.

---

## Sessionization: Grouping Events into Visits

Raw clickstream data is a flat sequence of timestamped events. A "session" is a human concept: a discrete visit to the platform, separated from the next visit by a period of inactivity.

The standard industry definition is a **30-minute inactivity gap**: if more than 30 minutes pass between two consecutive events from the same user, the second event starts a new session.

### Why Sessionization Matters for Modeling

Without sessions, you can only ask "did this user ever add to cart?" — a lifetime aggregate. With sessions you can ask:
- In this specific visit, did the user add to cart and then leave without buying?
- How long do converting sessions last compared to non-converting ones?
- Which sessions start with a product view and end in a purchase?

Sessions add the **visit** grain to your analytical model, sitting between the event grain (one row per click) and the user grain (one row per user lifetime).

---

## Window Functions: The Core Mechanism

Sessionization relies entirely on window functions applied in the right order. Understanding why the order matters is key.

### LAG: Looking at the Previous Row

```sql
LAG(event_timestamp) OVER (
    PARTITION BY user_id
    ORDER BY event_timestamp
) AS prev_event_timestamp
```

`LAG` returns the value from the previous row within the same partition. The result is `NULL` for the very first event per user — which is exactly how we detect the start of the first session.

The gap in minutes between the current event and the previous one:
```sql
EXTRACT(EPOCH FROM (event_timestamp - prev_event_timestamp)) / 60
```

### Detecting Session Boundaries

A session starts when:
- The gap exceeds 30 minutes, OR
- There is no previous event (first event for this user)

```sql
CASE
    WHEN prev_event_timestamp IS NULL THEN 1
    WHEN EXTRACT(EPOCH FROM (event_timestamp - prev_event_timestamp)) / 60 > 30 THEN 1
    ELSE 0
END AS is_session_start
```

### Cumulative Sum: Building the Session Counter

Once you have `is_session_start`, convert it to a monotonically increasing session number per user using a running sum:

```sql
SUM(is_session_start) OVER (
    PARTITION BY user_id
    ORDER BY event_timestamp
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS session_number
```

This running sum starts at 1 (the first event is always a session start) and increments by 1 each time a new session begins. The result is a clean integer session counter per user that you can use to group events.

### Why Two CTEs for Sessionization

The `LAG` computation and the `SUM` computation **cannot** happen in the same query step — `SUM(is_session_start)` depends on the value of `is_session_start`, which is itself computed from `LAG`. You need two CTEs:

```
CTE 1: compute is_session_start using LAG
CTE 2: compute session_number using SUM(is_session_start)
```

Trying to collapse these into one step is a common mistake that produces a SQL error or wrong results.

---

## Denormalization: Enriched Events as a Modeling Layer

Part A of this task asks you to build a flat enriched events table. This is a deliberate **denormalization** step — you are adding redundant data (user email, product name) to the event table so that downstream queries do not need to join back to `users` and `products` every time.

This is the basis of the **layered modeling** approach used in modern warehouses (sometimes called Bronze → Silver → Gold, or Raw → Staging → Mart):

| Layer | Contents | Purpose |
|---|---|---|
| Raw (Bronze) | Source data as-is | Auditability, reprocessing |
| Enriched (Silver) | Denormalized, cleaned events | Simplified joins for Gold layer |
| Mart (Gold) | Aggregated, business-grain tables | Direct consumption by BI tools |

`enriched_events` is a Silver layer artifact. `sessions` is Gold. Building Silver first is what makes Gold efficient.

---

## Anti-Joins: The Correct Way to Find Absences

**Cart abandonment** requires finding rows that exist in one table but have no matching row in another. This is an **anti-join** — the opposite of a standard join.

There are three ways to express an anti-join in SQL, and they are not equivalent:

### 1. LEFT JOIN … WHERE right_id IS NULL (Recommended)

```sql
SELECT c.user_id, c.product_id
FROM carted c
LEFT JOIN purchased p
    ON p.user_id = c.user_id AND p.product_id = c.product_id
WHERE p.user_id IS NULL
```

Works correctly when either side contains NULLs. Is well-optimized by most query engines.

### 2. NOT EXISTS (Also Recommended)

```sql
SELECT c.user_id, c.product_id
FROM carted c
WHERE NOT EXISTS (
    SELECT 1 FROM purchased p
    WHERE p.user_id = c.user_id AND p.product_id = c.product_id
)
```

Semantically clear and NULL-safe. `NOT EXISTS` short-circuits on the first match found, which can be faster than a full join when the subquery is selective.

### 3. NOT IN (Avoid)

```sql
SELECT user_id FROM carted
WHERE (user_id, product_id) NOT IN (SELECT user_id, product_id FROM purchased)
```

**This is dangerous.** If `purchased` contains a single `NULL` in either column, `NOT IN` returns zero rows — because `x NOT IN (1, 2, NULL)` evaluates to `UNKNOWN`, not `TRUE`. This is a silent bug that produces an empty result instead of an error. Always use `LEFT JOIN … IS NULL` or `NOT EXISTS` instead.

---

## Cart Abandonment Model: Design Decisions

The cart abandonment definition in this task is: *user added product to cart, but never completed a purchase for that product.*

Key design choices embedded in this definition:

1. **Scope is user × product, not session × product.** A user who carted a product in one session, browsed away, and never bought it is abandoned — regardless of how many sessions they had.

2. **Cancelled orders do not count as purchases.** If a user "bought" something but cancelled, the cart item is still considered abandoned for the purpose of retargeting.

3. **Grain of the output is (user_id, product_id).** Not (user_id, session_id, product_id) — we care about the user-level behavior, not a specific session.

These choices are not the only valid ones. A different business question might define abandonment per session, or might count cancellations differently. Documenting these decisions is part of the deliverable.

---

## Window Function Reference Summary

| Function | What it computes |
|---|---|
| `LAG(col) OVER (PARTITION BY … ORDER BY …)` | Value from the previous row in the window |
| `LEAD(col) OVER (PARTITION BY … ORDER BY …)` | Value from the next row in the window |
| `ROW_NUMBER() OVER (…)` | Sequential row number within the window |
| `RANK() OVER (…)` | Rank with gaps on ties |
| `DENSE_RANK() OVER (…)` | Rank without gaps on ties |
| `SUM(col) OVER (… ROWS UNBOUNDED PRECEDING …)` | Running total up to current row |
| `FIRST_VALUE(col) OVER (…)` | First value in the window partition |
| `LAST_VALUE(col) OVER (…)` | Last value — requires explicit `ROWS BETWEEN` clause |

Window functions never collapse rows. They add a computed column to every row while preserving the original granularity — use `GROUP BY` afterward if you need to aggregate to a coarser grain.
