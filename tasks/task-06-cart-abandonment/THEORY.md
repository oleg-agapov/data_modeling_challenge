# Theory – Event Enrichment, Denormalization, and Anti-Join Patterns

Task 05 summarized events into one row per user. This task works at a different level: it keeps every event, makes it easier to use, and then looks for something that **didn't** happen. That needs two techniques used all the time in behavioral analytics: **denormalization** and **anti-joins**.

---

## Raw Events Are Hard to Use

A raw event table is built for writing, not reading. Each row stores only IDs:

| event_id | user_id | event_type | product_id |
|---|---|---|---|
| 1a2a… | bdd6… | page_view | 310c… |

To answer "which product categories get the most add-to-carts?", an analyst first has to join `products`. To filter by registration date, they also have to join `users`. Every analyst repeats the same joins in every query, and sooner or later someone gets one wrong.

---

## Denormalization: Enriched Events as a Modeling Layer

Part A asks you to build a flat `enriched_events` table. This is deliberate **denormalization**: you copy user and product attributes onto every event row, so downstream queries don't need to join back to `users` and `products`.

In operational databases, duplicating data like this is usually avoided. In analytics it is a normal, intentional choice:

| | Normalized (source) | Denormalized (enriched) |
|---|---|---|
| Storage | Each fact stored once | Attributes repeated on many rows |
| Queries | Many joins | Few or no joins |
| Who it's built for | The application writing data | Analysts and BI tools reading data |

This is the basis of the **layered modeling** approach used in modern warehouses (sometimes called Bronze → Silver → Gold, or Raw → Staging → Mart):

| Layer | Contents | Purpose |
|---|---|---|
| Raw (Bronze) | Source data as-is | Auditability, reprocessing |
| Enriched (Silver) | Cleaned, denormalized events | Simple building block for marts |
| Mart (Gold) | Business-grain tables | Direct consumption by BI tools |

`enriched_events` is a Silver artifact. `cart_abandonment` is Gold, and it can be built directly on top of `enriched_events`.

### Rules for a safe enrichment

1. **The grain must not change.** One row per event before and after. Check that the row count equals `user_events`.
2. **Use `LEFT JOIN` for lookups.** Many events have no product (sign-ups, catalog views). An `INNER JOIN` to `products` would silently delete them.
3. **Join on unique keys only.** If the lookup table had two rows for the same key, every matching event would be duplicated. `users.user_id` and `products.id` are unique, but always check before you trust it.

---

## Anti-Joins: The Correct Way to Find Absences

**Cart abandonment** means finding rows that exist in one table but have no matching row in another. This is an **anti-join** — the opposite of a standard join.

There are three ways to express an anti-join in SQL, and they are not equivalent:

### 1. LEFT JOIN … WHERE right_key IS NULL (Recommended)

```sql
SELECT c.user_id, c.product_id
FROM carted c
LEFT JOIN purchased p
    ON p.user_id = c.user_id AND p.product_id = c.product_id
WHERE p.user_id IS NULL
```

Works correctly when either side contains NULLs. Is well-optimized by most query engines. Make sure `purchased` has one row per `(user_id, product_id)` (use `SELECT DISTINCT`) so the join cannot duplicate rows.

### 2. NOT EXISTS (Also Recommended)

```sql
SELECT c.user_id, c.product_id
FROM carted c
WHERE NOT EXISTS (
    SELECT 1 FROM purchased p
    WHERE p.user_id = c.user_id AND p.product_id = c.product_id
)
```

Semantically clear and NULL-safe. Duplicates in `purchased` don't matter here, because `NOT EXISTS` only asks whether at least one match exists.

### 3. NOT IN (Avoid)

```sql
SELECT user_id FROM carted
WHERE (user_id, product_id) NOT IN (SELECT user_id, product_id FROM purchased)
```

**This is dangerous.** If `purchased` contains a single `NULL` in either column, `NOT IN` returns zero rows — because `x NOT IN (1, 2, NULL)` evaluates to `UNKNOWN`, not `TRUE`. This is a silent bug that produces an empty result instead of an error. Always use `LEFT JOIN … IS NULL` or `NOT EXISTS` instead.

---

## Cart Abandonment Model: Design Decisions

The cart abandonment definition in this task is: *the user added a product to the cart, but never completed a purchase of that product.*

Key design choices embedded in this definition:

1. **The grain is (user_id, product_id).** If a user carted the same product three times, that's one abandoned pair with `cart_count = 3`, not three rows. The marketing email is about a product, not about each click.
2. **Cancelled orders do not count as purchases.** If a user "bought" something but cancelled, the product is still considered abandoned for the purpose of retargeting.
3. **Purchases come from a different source than carts.** There is no purchase event in `user_events`, so the model compares behavioral data (events) with transactional data (orders). Matching on `user_id` + `product_id` is the only link between the two.
4. **Timing is ignored.** A product bought *before* it was carted again still counts as purchased. A stricter definition could only look at orders placed after the last cart event.

These choices are not the only valid ones. A different business question might count cancellations differently or look at a time window. Documenting these decisions is part of the deliverable.

---

## Ratios at the Right Grain (for the stretch goal)

An abandonment rate is a ratio: `users_abandoned / users_carted`. Ratios can't be added up or averaged across rows. If one product has 1 of 2 users abandoning (50%) and another has 90 of 100 (90%), the average of the rates is 70%, but the true combined rate is 91 / 102 ≈ 89%.

Store the counts (`users_carted`, `users_abandoned`) in the model, and compute the rate from the counts at the level you report.

One more trap: **distinct counts are not additive either.** Summing `users_carted` over all Living Room products counts a user twice if they carted two Living Room products. That sum is really "user × product pairs", which may be exactly what you want. If you need "distinct users per category", count them again at the category level instead of summing the product rows. Say in your solution which one you report.

---

## What About Sessions?

Clickstream data is often grouped into **sessions**: visits separated by a period of inactivity, usually 30 minutes. Sessions add a "visit" grain between the event and the user.

This dataset can't show that technique well: every user has exactly one short visit (all events within about 12 minutes of sign-up), so every user would get exactly one session. Sessionization is planned for a future version of the dataset with repeat visits.
