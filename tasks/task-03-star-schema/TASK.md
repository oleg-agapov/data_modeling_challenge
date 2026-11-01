# Task 03 – Star Schema Design

## Context

The BI team is migrating the e-commerce data into an analytics warehouse. The raw operational tables need to be restructured into a **star schema** so that downstream reporting tools can query it efficiently without re-joining every table from scratch.

## Goal

Design and populate a **star schema** centred on order line items (the most granular transactional grain), with three dimension tables: date, customer and product. Name the models `fct_order_items`, `dim_date`, `dim_customer` and `dim_product`.

In this exercise you should use the **following files**:

- `data/ecommerce/orders.csv`
- `data/ecommerce/order_items.csv`
- `data/ecommerce/users.csv`
- `data/ecommerce/locations.csv`
- `data/ecommerce/products.csv`

## Deliverables

Fill in the `SOLUTION.md` file in this directory. It must cover three sections:

1. **Conceptual layer** — describe the star schema structure: identify the central fact, the dimensions, and the grain of the fact table in plain language.
2. **Logical layer** — define all dimension and fact tables with columns, data types, and keys; explain how source tables are mapped to each model.
3. **Physical layer** — provide the SQL for all dimensional and fact models, plus any validation queries. A plain `SELECT` is fine; `CREATE VIEW` or `CREATE TABLE AS SELECT` are also welcome if you want to persist the model.

You are free to enrich your solution with anything that helps communicate your thinking: diagrams (e.g. [Excalidraw](https://excalidraw.com/), [DrawDB](https://www.drawdb.app)), links, screenshots, or extra explanation. There is no strict format — clarity and correctness matter most.

## Check your solution

When your model is built, run the automatic checks from the repository root, in the same database:

```sql
.read tasks/task-03-star-schema/checks.sql
```

(In the browser or another SQL tool, open [`checks.sql`](checks.sql), copy it, and run it.) The checks look for the four models `fct_order_items`, `dim_date`, `dim_customer` and `dim_product` with the column names from the hints. Every row should say `PASS`; a `FAIL` row shows the expected and actual values, so you can find the bug.

When everything passes, compare your reasoning with the [reference solution](../../reference-solutions/task-03-star-schema/SOLUTION.md). Try the task on your own first!

## Hints

<details>
<summary>
Hint 1. Target schema
</summary>

```
                 ┌─────────────┐
                 │  dim_date   │
                 └──────▲──────┘
                        │
┌──────────────┐  ┌─────┴───────────┐  ┌─────────────┐
│ dim_customer │◄─┤ fct_order_items ├─►│ dim_product │
└──────────────┘  └─────────────────┘  └─────────────┘
```

There are five source tables but only three dimensions. `locations` has exactly one row per user, so the address is an **attribute of the customer**, not a separate dimension. The theory file explains why.

</details>


<details>
<summary>
Hint 2. Dimension table specifications
</summary>

### `dim_date`
One row per calendar date, covering every day from the first to the last `orders.order_date`, including days without orders.

| Column | Type | Notes |
|---|---|---|
| `date_key` | integer | Surrogate key in `YYYYMMDD` format, e.g. `20240315` |
| `full_date` | date | The calendar date |
| `year` | integer | |
| `quarter` | integer | 1–4 |
| `month` | integer | 1–12 |
| `month_name` | string | |
| `week_of_year` | integer | ISO week |
| `day_of_week` | integer | 1 = Monday … 7 = Sunday |
| `day_name` | string | |
| `is_weekend` | boolean | |

### `dim_customer`
One row per user, including the user's address. Treat it as a **Type 1 SCD** (overwrite on change, no history).

| Column | Notes |
|---|---|
| `customer_key` | Integer surrogate key |
| `customer_id` | Natural key from `users.user_id` |
| `first_name` | |
| `last_name` | |
| `email` | |
| `registered_at` | `users.created_at` |
| `registration_month` | `DATE_TRUNC('month', created_at)` |
| `city` | From `locations`, joined on `users.location_id` |
| `state` | From `locations` |
| `zip_code` | From `locations` |
| `country_code` | From `locations` (always `US` in this dataset) |

### `dim_product`

| Column | Notes |
|---|---|
| `product_key` | Integer surrogate key |
| `product_id` | Natural key from `products.id` |
| `name` | |
| `category` | |
| `material` | |
| `current_catalog_price` | `products.price` as of load time |

</details>


<details>
<summary>
Hint 3. Fact table specification
</summary>

### `fct_order_items`

Grain: one row per order line item.

| Column | Type | Notes |
|---|---|---|
| `order_item_key` | integer | Surrogate PK |
| `order_item_id` | UUID | Natural key from `order_items.order_item_id` |
| `order_id` | UUID | Degenerate dimension (kept for drill-through) |
| `order_status` | string | Degenerate dimension, from `orders.order_status` |
| `payment_method` | string | Degenerate dimension, from `orders.payment_method` |
| `date_key` | integer | FK → `dim_date.date_key` (from `orders.order_date`) |
| `customer_key` | integer | FK → `dim_customer.customer_key` (via `orders.user_id`) |
| `product_key` | integer | FK → `dim_product.product_key` |
| `quantity` | integer | |
| `unit_price` | numeric(12,2) | Price charged per unit |
| `discount` | numeric(4,2) | Discount **rate** (e.g. `0.15`), not an amount |
| `line_total` | numeric(12,2) | Amount charged for the line |

</details>


<details>
<summary>
Hint 4. Requirements and validation
</summary>

1. Generate integer surrogate keys with a **deterministic** order, for example `ROW_NUMBER() OVER (ORDER BY customer_id)`. Do **not** use `ROW_NUMBER() OVER ()` without an `ORDER BY` (the numbering can change every time you rebuild), and do **not** reuse the source UUIDs as dimension keys.
2. All dimension lookups in the fact table must use surrogate keys, not natural keys.
3. Every foreign key in `fct_order_items` must resolve — no orphan keys (validate with anti-join checks).
4. Monetary columns must be typed as `NUMERIC(12,2)`.
5. To build the date spine for `dim_date`, generate one row per day between the first and last order date. In DuckDB: `SELECT * FROM generate_series(DATE '2024-01-01', DATE '2024-12-31', INTERVAL 1 DAY)` (replace the dates with the real range). It returns timestamps, so cast each value with `::DATE`.

After building the schema, write queries to verify:

1. Row count of `fct_order_items` equals row count of `order_items`.
2. `SUM(fct_order_items.line_total)` matches `SUM(order_items.line_total)` from the source.
3. No `NULL` foreign keys exist in any FK column of `fct_order_items`.
4. Each dimension has exactly one row per natural key (`dim_customer` per `customer_id`, `dim_product` per `product_id`, `dim_date` per `full_date`).

</details>


<details>
<summary>
Hint 5. Stretch goal
</summary>

`order_status` and `payment_method` are two low-cardinality text flags that sit on every fact row. Replace them with a **junk dimension**:

- Build `dim_order_profile` with one row per combination of `order_status` × `payment_method` (4 × 3 = 12 rows) and an integer `order_profile_key`.
- Replace the two text columns in `fct_order_items` with `order_profile_key`.
- In your solution, discuss the trade-off: what do you gain, and what becomes less convenient for someone querying the fact table?

</details>
