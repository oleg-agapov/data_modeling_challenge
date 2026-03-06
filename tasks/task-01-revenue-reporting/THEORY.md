# Theory – The Three Layers of Data Modeling

Data modeling is the process of defining how data is structured, stored, and related. Every good model passes through three distinct layers before it reaches the database. Understanding where you are in this progression prevents a very common mistake: jumping straight to implementation before the business meaning is clear.


## The Three Layers


### 1. Conceptual Model

The conceptual model answers the question: **what does the business care about?**

At this level you identify the core **entities** — the "things" the business tracks — and the **relationships** between them. There is no SQL, no column names, and no data types. The audience is a business stakeholder, not a developer.

For this task, a quick conceptual sketch might look like:

```
User ──places──► Order ──contains──► Product
```

Key artifacts of a conceptual model:
- Entity names (nouns: User, Order, Product)
- Relationship verbs (places, contains, belongs to)
- Cardinality notation (one User places many Orders; each Order belongs to one User)


### 2. Logical Model

The logical model answers: **what information do we need to capture about each entity?**

Now you move into attributes — the columns — but still without worrying about a specific database technology. You define:
- **Primary keys** (what uniquely identifies each entity)
- **Foreign keys** (what links one entity to another)
- **Attributes** (descriptive fields like `status`, `date_ordered`, `payment_method`)
- **Grain** — the single most important decision in any analytical model (see below)

A logical model for this task would show the `orders` table with its columns, `order_items` with its columns, and a line between them on `order_id`.


### 3. Physical Model

The physical model answers: **how is this actually stored in the database?**

This translates the logical design into real DDL: exact data types (`NUMERIC(12,2)` vs `FLOAT`), indexes, partitioning keys, `NOT NULL` constraints, and storage engines. The choices here affect query performance and storage cost, not just correctness.


## The Most Important Concept: Grain

> **Grain** = what exactly does one row represent?

Every analytical table must have a declared grain. This task's output has the grain: *one row per order*. That single statement drives every decision:

- Can you join directly to `order_items` without collapsing it first? No — `order_items` is at a finer grain (one row per line item), so a direct join would multiply rows and inflate every aggregate.
- Should cancelled orders appear? Yes — the grain is "one row per order regardless of status."

**Fan-out** is what happens when you violate grain accidentally. If you join `orders` (1,000 rows) to `order_items` (3,000 rows) without pre-aggregating, your result will have 3,000 rows — three times too many. Every `SUM` you run will be tripled. The fix is always the same: **aggregate to the target grain before joining**.


## Moving from Source to Analytical Model

Operational (OLTP) systems are optimized for writing data quickly and consistently. Analytical (OLAP) models are optimized for reading and aggregating. The transform step between the two is where you:

1. Resolve the grain — pick the level of detail that answers the question.
2. Pre-aggregate finer-grained sources (e.g. `order_items` → order-level totals).
3. Enrich the result by joining in descriptive attributes (e.g. `users.payment_method`).
4. Keep the model additive — make every metric computable by simple `SUM`, `COUNT`, or `AVG` without re-joins.

This task walks you through exactly that pattern: aggregate `order_items` to order grain → join to `orders` → produce a clean, self-contained fact table.


## Summary

| Layer | Question answered | Audience |
|---|---|---|
| Conceptual | What does the business care about? | Business stakeholders |
| Logical | What data do we capture and how is it related? | Data architects, analysts |
| Physical | How is it stored in the actual database? | Engineers, DBAs |

Before writing a single line of SQL, ask yourself: *what is the grain of my output?* If you cannot answer this in one sentence, stop and think — the answer will determine every join and every aggregation you write.
