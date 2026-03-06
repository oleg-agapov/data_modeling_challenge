# Data Modeling Tasks

Six exercises progressing from foundational entity modeling to advanced dimensional design and behavioral analytics.

| # | Task | Difficulty | Type | Files used |
|---|---|---|---|---|
| 01 | [Revenue Reporting](task-01-revenue-reporting/) | ⭐️ | Entity / Fact table | `orders`, `order_items`, `users` |
| 02 | [Product Sales Report](task-02-product-sales-report/) | ⭐️ | Join + Aggregation | `products`, `order_items`, `orders` |
| 03 | [Star Schema Design](task-03-star-schema/) | ⭐️⭐️ | Dimensional Modeling | `orders`, `order_items`, `products`, `users`, `locations` |
| 04 | [Hotel Booking Data Marts](task-04-hotel-booking-marts/) | ⭐️⭐️ | Theoretical / Design-only | none |
| 05 | [User Conversion Funnel](task-05-conversion-funnel/) | ⭐️⭐️⭐️ | Window Functions + Funnel | `user_events`, `orders`, `users` |
| 06 | [Sessionization & Cart Abandonment](task-06-sessionization/) | ⭐️⭐️⭐️ | Advanced Window Functions | `user_events`, `products`, `orders`, `users` |

## Progression

Each task folder contains a `README.md` with:
- **Context** – the business problem and stakeholder need
- **Goal** – what to build
- **Required output columns** – the expected schema (code tasks) or deliverables (design tasks)
- **Requirements** – constraints and rules to follow
- **Hints** – syntax nudges and common pitfalls
- **Stretch goal** – an optional extension for extra depth
