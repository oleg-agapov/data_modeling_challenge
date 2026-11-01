# Input data

All tasks that use real data work with one dataset: an **e-commerce store** selling furniture.

| File | Rows | Description |
|---|---:|---|
| [`ecommerce/users.csv`](ecommerce/users.csv) | 12,483 | Registered customers |
| [`ecommerce/locations.csv`](ecommerce/locations.csv) | 12,483 | Customer addresses (one per user) |
| [`ecommerce/products.csv`](ecommerce/products.csv) | 21 | Product catalog |
| [`ecommerce/orders.csv`](ecommerce/orders.csv) | 1,918 | Order headers |
| [`ecommerce/order_items.csv`](ecommerce/order_items.csv) | 2,092 | Order lines |
| [`ecommerce/user_events.csv`](ecommerce/user_events.csv) | 191,157 | Website clickstream events |

Read the full documentation before starting a task: [ecommerce.md](ecommerce.md). It explains every column, the relationships between tables, and a few known quirks of the data.

To load the files into a database, follow [GETTING_STARTED.md](../GETTING_STARTED.md).

The schema is also available as an [ERD image](ecommerce/erd.png) and as [DBML](ecommerce/schema.dbml).
