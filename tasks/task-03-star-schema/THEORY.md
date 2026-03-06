# Theory – Dimensional Modeling: Facts, Dimensions, and the Star Schema

Tasks 01 and 02 produced analytical tables optimized for a single business question. This task introduces **dimensional modeling** — a design paradigm built for warehouses that must answer *many* different questions efficiently without restructuring the underlying data each time.

---

## Facts and Dimensions

Dimensional modeling divides the world into two kinds of tables:

### Fact Tables

A fact table records **what happened** — a business event or measurement. Each row is one occurrence of that event, and almost every column is either a foreign key or a numeric measure.

Characteristics of a fact table:
- **One declared grain** — e.g., "one row per order line item"
- **Foreign keys** to dimensions — these are the axes you can slice by
- **Measures** — the numbers you sum, count, or average (`quantity`, `line_total`, `discount`)
- **Degenerate dimensions** — attributes that describe the event but don't warrant their own dimension table (e.g., `order_id`, `order_status`)

Fact tables tend to be wide (many columns) and very long (millions of rows). They are append-only in most designs — once an event is recorded, that row does not change.

### Dimension Tables

A dimension table records **who, what, where, and when** — the context around the event. Dimensions are looked up during query time to filter and group facts.

Characteristics of a dimension table:
- One row per entity (one product, one customer, one date)
- **Surrogate key** — a system-generated integer that is the join key used in the fact table
- **Natural key** — the business identifier from the source system (UUID, etc.)
- **Attributes** — descriptive text and categorical fields used for filtering and grouping

Dimensions tend to be wide and short relative to facts.

---

## The Star Schema

A star schema is the standard layout for a dimensional warehouse: one central fact table surrounded by denormalized dimension tables, connected by surrogate keys.

```
         dim_date
            │
dim_customer ──► fact_order_items ◄── dim_product
                        │
                   dim_location
```

It is called a "star" because the diagram looks like one. The layout has two important properties:

1. **Query simplicity** — any analysis is at most one join away from the fact table. BI tools, analysts, and dashboards can all read the same star schema without custom SQL for each use case.
2. **Performance** — dimension tables are small enough to fit in memory; the warehouse only needs to scan the (large) fact table once per query.

### Star vs. Snowflake

A **snowflake schema** normalizes some dimensions into sub-dimensions. For example, `dim_location` might be split into `dim_city → dim_state → dim_country`. This saves storage (city names are not repeated per location row) but adds joins and complexity.

**Rule of thumb:** prefer star schema (denormalized dimensions) for analytics. The storage savings of snowflaking are negligible in modern warehouses; the join simplicity of a star schema is invaluable.

---

## Surrogate Keys vs. Natural Keys

| | Surrogate Key | Natural Key |
|---|---|---|
| What it is | System-generated integer (`1, 2, 3, …`) | Business identifier (UUID, code) |
| Used for | Joining fact to dimension | Matching source records, debugging |
| Changes when source data changes? | Never | May change (e.g., product code reassigned) |
| Storage cost | 4 bytes (INT) | 16 bytes+ (UUID) |

**Always use surrogate keys as join keys in a star schema.** Keep the natural key in the dimension for traceability, but never use it as the FK in the fact table. This insulates the warehouse from upstream identifier changes and cuts join cost.

To generate surrogate keys in SQL:
```sql
ROW_NUMBER() OVER () AS surrogate_key
```

---

## The Date Dimension

`dim_date` deserves special attention. Rather than storing a raw timestamp in the fact table, you store a **date key** (integer in `YYYYMMDD` format, e.g., `20240315`) and build a fully pre-computed calendar dimension. This lets analysts filter with simple expressions:

```sql
WHERE d.year = 2024 AND d.is_weekend = TRUE
-- instead of: WHERE EXTRACT(isodow FROM event_ts) IN (6, 7)
```

Every possible calendar attribute — year, quarter, month name, week of year, day of week, `is_weekend` — lives in `dim_date` and is computed once at load time, not on every query.

---

## Degenerate Dimensions

Some attributes describe an event but have only one value per fact row and don't need their own dimension table. The order number is the classic example: every line item already implies a specific order, and there is nothing more to know about the order concept that isn't already on the fact or in another dimension.

These are stored directly in the fact table and called **degenerate dimensions**. They are useful for drill-through queries (finding all line items for a specific order) but are never used for aggregation grouping.

---

## Slowly Changing Dimensions (SCD) — Type 1 Introduction

Dimensional data changes over time. A customer updates their email. A product is renamed. How do you handle that?

**Type 1 SCD — Overwrite:** Simply replace the old value with the new one. No history is preserved. Simple and sufficient when you don't need to know what the value was at the time of the transaction.

```
Before:  customer_key=42, email='old@example.com'
After:   customer_key=42, email='new@example.com'
```

Historical fact rows now appear to belong to a customer with the new email — even those placed before the change. This is acceptable for most attributes where historical accuracy is not required.

Type 2 SCD (preserving history) is introduced in Task 04.

---

## Validation is Not Optional

A dimensional model is only trustworthy if you verify it. After building a star schema, always confirm:

1. **Fact row count** matches the source grain (no row duplication or loss).
2. **Total measure sum** matches the source (no silent aggregation errors).
3. **No orphan foreign keys** — every FK in the fact table resolves to a row in its dimension. An orphan means a fact row with no associated dimension context, which will silently disappear from any filtered query.

```sql
-- Anti-join check: find fact rows with no matching dim_product row
SELECT f.order_item_id
FROM fact_order_items f
LEFT JOIN dim_product dp ON dp.product_key = f.product_key
WHERE dp.product_key IS NULL
-- Should return zero rows
```
