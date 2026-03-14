# Task 03 – Star Schema Design

![Image](image.png)

**Difficulty**: Medium ⭐️⭐️

**Data source**: data/ecommerce

**Theory**: [Dimensional Modeling: Facts, Dimensions, and the Star Schema](THEORY.md)

## Context

The BI team is migrating the e-commerce data into an analytics warehouse. The raw operational tables need to be restructured into a **star schema** so that downstream reporting tools can query it efficiently without re-joining every table from scratch.

## Goal

Design and populate a **star schema** centred on order line items (the most granular transactional grain), with four dimension tables.


## Deliverables

Fill in the `SOLUTION.MD` file in this directory. It must cover three sections:

1. **Conceptual layer** — describe the star schema structure: identify the central fact, the dimensions, and the grain of the fact table in plain language.
2. **Logical layer** — define all dimension and fact tables with columns, data types, and keys; explain how source tables are mapped to each model.
3. **Physical layer** — provide the SQL for all dimensional and fact models, plus any validation queries. A plain `SELECT` is fine; `CREATE VIEW` or `CREATE TABLE AS SELECT` are also welcome if you want to persist the model.

You are free to enrich your solution with anything that helps communicate your thinking: diagrams (e.g. [Excalidraw](https://excalidraw.com/), [DrawDB](https://www.drawdb.app)), links, screenshots, or extra explanation. There is no strict format — clarity and correctness matter most.

## Hints

<details>
<summary>
Hint 1. Target schema
</summary>

```
                   ┌─────────────┐
                   │  dim_date   │
                   └──────┬──────┘
                          │
┌──────────────┐   ┌──────▼──────────┐   ┌────────────────┐
│ dim_customer │◄──┤ fact_order_items ├──►│  dim_product   │
└──────────────┘   └──────┬──────────┘   └────────────────┘
                          │
                   ┌──────▼──────┐
                   │ dim_location│
                   └─────────────┘
```


</details>


<details>
<summary>
Hint 2. Dimension table specifications
</summary>

### `dim_date`
One row per calendar date covering the full range of `orders.date_ordered`.

| Column | Type | Notes |
|---|---|---|
| `date_key` | integer | Surrogate key in `YYYYMMDD` format |
| `full_date` | date | The calendar date |
| `year` | integer | |
| `quarter` | integer | 1–4 |
| `month` | integer | 1–12 |
| `month_name` | string | |
| `week_of_year` | integer | |
| `day_of_week` | integer | 1 = Monday … 7 = Sunday |
| `day_name` | string | |
| `is_weekend` | boolean | |

### `dim_customer`
One row per user; treat as a **Type 1 SCD** (overwrite on change, no history).

| Column | Notes |
|---|---|
| `customer_key` | Integer surrogate key (auto-increment / row_number) |
| `customer_id` | Natural key from `users.id` |
| `first_name` | |
| `last_name` | |
| `email` | |
| `registered_at` | `users.created_on` |
| `registration_month` | `DATE_TRUNC('month', created_on)` |

### `dim_product`

| Column | Notes |
|---|---|
| `product_key` | Integer surrogate key |
| `product_id` | Natural key from `products.id` |
| `name` | |
| `category` | |
| `material` | |
| `current_catalog_price` | `products.price` as of load time |

### `dim_location`

| Column | Notes |
|---|---|
| `location_key` | Integer surrogate key |
| `location_id` | Natural key from `locations.id` |
| `city` | |
| `state` | `stateRegion` |
| `zip_code` | |
| `country_code` | `code` |


</details>


<details>
<summary>
Hint 3. Fact table specification
</summary>

### `fact_order_items`

Grain: one row per order line item.

| Column | Type | Notes |
|---|---|---|
| `order_item_key` | integer | Surrogate PK |
| `order_item_id` | UUID | Natural key from `order_items.id` |
| `order_id` | UUID | Degenerate dimension (kept for drill-through) |
| `order_status` | string | Denormalized from `orders.status` |
| `payment_method` | string | Denormalized from `orders.payment_method` |
| `date_key` | integer | FK → `dim_date.date_key` (from `orders.date_ordered`) |
| `customer_key` | integer | FK → `dim_customer.customer_key` |
| `product_key` | integer | FK → `dim_product.product_key` |
| `location_key` | integer | FK → `dim_location.location_key` |
| `quantity` | integer | |
| `unit_price` | numeric(12,2) | Transaction price snapshot |
| `discount` | numeric(12,2) | |
| `line_total` | numeric(12,2) | |


</details>


<details>
<summary>
Hint 4. Requirements and validation
</summary>

1. Generate integer surrogate keys using `ROW_NUMBER() OVER ()` or equivalent — do **not** reuse the source UUIDs as dimension PKs.
2. All dimension lookups in the fact table must use surrogate keys, not natural keys.
3. Every foreign key in `fact_order_items` must resolve — no orphan keys (validate with anti-join checks).
4. Monetary columns must be typed as `NUMERIC(12,2)`.

After building the schema, write queries to verify:

1. Row count of `fact_order_items` equals row count of `order_items.csv`.
2. `SUM(fact_order_items.line_total)` matches `SUM(order_items.line_total)` from the source.
3. No `NULL` foreign keys exist in any FK column of `fact_order_items`.


</details>


<details>
<summary>
Hint 5. Stretch goal
</summary>

Promote `dim_customer` to a **Type 2 SCD**: add `valid_from`, `valid_to`, and `is_current` columns, and simulate a single fictitious change to five users' email addresses to demonstrate the versioning logic.

</details>
