# Data Modeling Tasks

Six exercises that progress from your first fact table to designing a full dimensional model, with two smaller tasks on behavioral (event) data.

Before you start, load the data ([GETTING_STARTED.md](../GETTING_STARTED.md)) and read the [dataset documentation](../data/ecommerce.md).


## Learning path

| # | Task | You will build | Concepts you will learn |
|---|---|---|---|
| 01 | [Revenue Reporting](task-01-revenue-reporting/) | `fct_orders`: one row per order with revenue metrics | Conceptual, logical and physical models · grain · fan-out · aggregating before joining |
| 02 | [Product Sales Report](task-02-product-sales-report/) | A product-level sales report | Choosing the spine of a query · `LEFT JOIN` vs `INNER JOIN` · `COALESCE` / `NULLIF` · additive vs non-additive metrics · rates vs amounts |
| 03 | [Star Schema Design](task-03-star-schema/) | `fct_order_items` with `dim_date`, `dim_customer`, `dim_product` | Facts and dimensions · star vs snowflake · surrogate keys · date dimension · degenerate dimensions · SCD Type 1 · junk dimensions (stretch) |
| 04 | [Hotel Booking Data Marts](task-04-hotel-booking-marts/) | A design document (no SQL, no data) | Design-first modeling · cardinality · data marts · SCD Type 1 vs Type 2 · modeling cancellations · choosing a grain |
| 05 | [User Conversion Funnel](task-05-conversion-funnel/) | A per-user funnel table and a funnel summary | Modeling event data · milestone flags with `MAX(CASE …)` · funnel denominators · cohorts |
| 06 | [Event Enrichment & Cart Abandonment](task-06-cart-abandonment/) | `enriched_events` and a cart abandonment report | Denormalization · layered modeling (raw → enriched → mart) · anti-joins · ratio and distinct-count pitfalls |

Tasks 01–03 build on each other: the grain and join rules from Tasks 01–02 are what make the star schema in Task 03 correct. Task 04 assumes you know the star schema vocabulary from Task 03. Tasks 05–06 can be done after Task 02.


## How to work on a task

1. Open the task folder and read `README.md`, then `TASK.md`.
2. If a concept is new to you, read `THEORY.md` first.
3. Think about the model **before** writing SQL: what is the grain, which tables are the spine, which are lookups?
4. Write your SQL and run it. Save each model as a view or table so you can query it by name.
5. Run the validation checks from the task's hints.
6. Fill in `SOLUTION.md`: your conceptual, logical and physical model, plus assumptions and trade-offs.

The hints in `TASK.md` are collapsed. Try the task on your own first, and open a hint only when you're stuck. The later hints get very specific, down to the exact output columns.

If you fork this repository, commit your filled-in `SOLUTION.md` files and SQL to your fork. That way you have a portfolio of modeling work you can show others.
