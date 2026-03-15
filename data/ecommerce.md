# E-commerce datasets documentation

This document describes the datasets in `data/ecommerce/` and explains each field based on observed data patterns.

## Dataset overview

| Dataset | Description | Approx. rows | Primary key |
|---|---|---:|---|
| `users.csv` | Registered users/customers | 12,483 | `id` |
| `products.csv` | Product catalog | 21 | `id` |
| `locations.csv` | Shipping/order destination locations | 1,988 | `id` |
| `orders.csv` | Order header records | 1,988 | `id` |
| `order_items.csv` | Line items per order | 2,161 | `id` |
| `user_events.csv` | User behavioral events (web tracking) | 190,370 | `event_id` |

## Entity relationships

- `orders.user_id` → `users.id`
- `users.loc_id` → `locations.id`
- `order_items.order_id` → `orders.id`
- `order_items.product_id` → `products.id`
- `user_events.user_id` → `users.id`
- `user_events.product_id` → `products.id` (nullable; only populated for product-related events)

## `users.csv`

**Grain:** one row per user account.

| Field | Type (inferred) | Description |
|---|---|---|
| `id` | UUID | Unique user identifier. |
| `firstName` | string | User first name. |
| `lastName` | string | User last name. |
| `email` | string | User email address (appears mostly unique; may include duplicates). |
| `created_on` | datetime | Account creation timestamp. |
| `loc_id` | UUID | User's default shipping/destination location. Foreign key to `locations.id`. |

## `products.csv`

**Grain:** one row per product SKU/item.

| Field | Type (inferred) | Description |
|---|---|---|
| `id` | UUID | Unique product identifier. |
| `name` | string | Product name shown in catalog. |
| `category` | string | Product category (observed values: `Living Room`, `Bedroom`, `Kitchen`). |
| `description` | string | Human-readable product description. |
| `price` | decimal | Catalog/base product price. |
| `dimensions` | string | Product dimensions stored as free-text (for example `180 x 90 x 75`). |
| `material` | string | Main materials used for the product. |
| `stock` | integer | Available inventory quantity at time of extraction. |

## `locations.csv`

**Grain:** one row per address/location used by orders.

| Field | Type (inferred) | Description |
|---|---|---|
| `id` | UUID | Unique location identifier. |
| `code` | string | Country code (observed: `US`). |
| `fullName` | string | Country name (observed: `United States`). |
| `city` | string | City name for the address. |
| `address` | string | Street address line. |
| `zip_code` | string | Postal/ZIP code. Stored as string (can include leading zeros). |
| `stateRegion` | string | State or region name. |

## `orders.csv`

**Grain:** one row per order (header-level information).

| Field | Type (inferred) | Description |
|---|---|---|
| `id` | UUID | Unique order identifier. |
| `user_id` | UUID | User who placed the order. Foreign key to `users.id`. |
| `date_ordered` | datetime | Order creation/placement timestamp. |
| `status` | string | Current order status. Observed values: `pending`, `shipped`, `delivered`, `cancelled`. |
| `payment_method` | string | Payment channel used. Observed values: `credit card`, `bank transfer`, `paypal`. |
| `total_amount` | decimal | Final order total amount. Typically equals sum of associated `order_items.line_total`. |
| `updated` | datetime | Last update timestamp for the order record (often same as `date_ordered` in current data). |

## `order_items.csv`

**Grain:** one row per product line inside an order.

| Field | Type (inferred) | Description |
|---|---|---|
| `id` | UUID | Unique order line identifier. |
| `order_id` | UUID | Parent order identifier. Foreign key to `orders.id`. |
| `product_id` | UUID | Product purchased in this line. Foreign key to `products.id`. |
| `quantity` | integer | Quantity purchased for this line item (observed as `1` in current data). |
| `unit_price` | decimal | Per-unit selling price captured at purchase time. |
| `discount` | decimal/integer | Discount amount applied at line level (observed as `0` in current data). |
| `line_total` | decimal | Extended line amount (typically `quantity * unit_price - discount`). |

## `user_events.csv`

**Grain:** one row per tracked user event (clickstream / behavioral log).

| Field | Type (inferred) | Description |
|---|---|---|
| `event_id` | UUID | Unique event identifier. |
| `user_id` | UUID | User performing the event. Foreign key to `users.id`. |
| `event_type` | string | Event category. Observed values: `user_sign_up`, `page_view`, `add_to_cart`. |
| `event_timestamp` | datetime | Event occurrence timestamp. |
| `page_url` | string | URL/path where event occurred (for example `/signup`, `/catalog`, `/product`, `/checkout`). |
| `product_id` | UUID (nullable) | Product involved in the event, when applicable (mostly for product page views and add-to-cart actions). |
| `additional_details` | string (nullable) | Extra event metadata. Currently empty in all observed records. |

## Notes and modeling tips

- Monetary fields are stored as decimals in CSV text; define a fixed precision numeric type in your warehouse (for example `NUMERIC(12,2)`).
- Use `orders` + `order_items` for transactional sales facts; `user_events` is a high-volume behavioral fact table.
- Treat `products.price` as catalog price and `order_items.unit_price` as transaction price snapshot.
- Consider normalizing event URLs and mapping `event_type` to a controlled dimension table for analytics consistency.
