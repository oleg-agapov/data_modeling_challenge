# Theory – Slowly Changing Dimensions, Data Marts, and Design-First Thinking

The previous tasks were code-first: given data, build a model. This task flips the workflow. You start with **business questions** and reason backwards to the design. This is how real warehouse projects begin — and it introduces two foundational topics: **Slowly Changing Dimensions** and **data marts**.

---

## Design-First Modeling

When someone asks "can we see booking revenue by country and season?", the instinct is to write SQL. Resist it. The right first step is to sketch:

1. **What is the grain of the fact table?** (One row per booking? Per night stayed? Per room-night?)
2. **What dimensions do I need to slice by?** (Date, Guest, Property, Channel…)
3. **What measures make the question answerable?** (Booking value, nights, `is_cancelled` flag…)

Only after those three questions are answered does SQL become meaningful. Skipping this step produces code that works for today's question but cannot answer tomorrow's.

---

## Conceptual vs. Logical Modeling (Again, but Deeper)

Task 01 introduced these layers. This task requires you to *produce* them as deliverables.

### Conceptual Model

Express relationships using plain language and cardinality notation:

```
Guest (1) ──── (N) Booking ──── (1) Property
                    │
                   (1)
                    │
               Room Type
```

Cardinality labels:
- `1:1` — one guest per booking, one booking per guest (unusual in this domain)
- `1:N` — one guest, many bookings (most common)
- `M:N` — many guests, many properties (only valid at the portfolio level; requires a bridge table in the logical model)

Also state whether relationships are **mandatory** (must always exist) or **optional** (may be NULL). A booking *must* have a guest; a guest *may* have zero bookings.

### Logical Model

Translate entities into tables. For each table you must answer:
- What is the **grain**?
- What is the **primary key** (surrogate or natural)?
- Which attributes belong here vs. elsewhere?
- Is this a **Type 1 or Type 2 SCD**?

---

## Slowly Changing Dimensions (SCD) — Full Treatment

Dimensions change. How you handle change defines the kind of analysis you can do later:

### Type 1 — Overwrite (No History)

Replace the old value with the new one. The dimension row is updated in place. Historical facts now point to the new attribute value — as if the change always existed.

**Use when:** Historical accuracy of the attribute is not needed. Example: correcting a typo in a hotel name.

```
Before:  property_key=7, name='Grand Hotl'
After:   property_key=7, name='Grand Hotel'
```

### Type 2 — Versioned Rows (Full History)

Each change creates a **new row** in the dimension, with a new surrogate key and validity dates. Old surrogate keys remain in the fact table, pointing to the historical version. New facts get the new surrogate key.

**Use when:** You need to answer "what was the guest's country at the time of booking?" — not just "what is their country now?"

```sql
-- Type 2 structure
guest_key | guest_id | country | valid_from | valid_to   | is_current
──────────┼──────────┼─────────┼────────────┼────────────┼───────────
1001      | g-42     | DE      | 2022-01-01 | 2023-06-30 | FALSE
1002      | g-42     | FR      | 2023-07-01 | NULL       | TRUE
```

A fact row recorded in 2022 still joins to `guest_key=1001` (Germany). A fact row from 2024 joins to `guest_key=1002` (France). The analysis is historically accurate.

**Type 2 costs:** More rows per entity, more complex ETL, and queries must filter on `is_current` or join via date range to avoid counting an entity multiple times.

### Type 3 — Previous-Value Column (Rare)

Add a `previous_value` column alongside `current_value`. Can only track one level of history. Rarely used in practice.

---

## What is a Data Mart?

A **data warehouse** is a central repository of integrated data for the whole organization. A **data mart** is a subset of the warehouse scoped to a specific business domain or team.

Think of the warehouse as the full library and a data mart as a curated reading list for one department.

Benefits of data marts:
- **Performance** — smaller, pre-filtered datasets query faster.
- **Discoverability** — analysts find what they need without understanding the whole schema.
- **Governance** — sensitive data can be excluded from a mart serving external users.

A hotel booking platform might have:
- A **revenue mart** (finance team) — focused on booking value, ADR, RevPAR
- An **operations mart** (property managers) — occupancy rates, room utilization
- A **marketing mart** (growth team) — channel attribution, guest retention, LTV

These marts often share `dim_date` and `dim_property` but join to different fact tables.

---

## Modeling Cancellations

Cancellations are a design decision, not just a filter. There are two main approaches:

### Option A — Filter Cancellations Out

Only include active bookings in the fact table. Simple, but loses the ability to analyze cancellation patterns.

### Option B — Include with a Flag

Keep every booking, add an `is_cancelled` boolean measure. This lets you:
- Compute gross booking volume vs. net
- Calculate cancellation rates by property, channel, season
- Measure lead time between booking and cancellation

**Recommended:** include cancellations as a flag. The cost is one extra column; the analytical benefit is large. Downstream consumers can always `WHERE is_cancelled = FALSE` when they want clean revenue figures.

---

## Grain Trade-offs in Fact Table Design

The `fact_bookings` grain of "one row per booking" is natural here. But consider the alternatives:

| Grain | Pros | Cons |
|---|---|---|
| One row per booking | Simple, matches the business unit of work | Cannot answer "how many room-nights were sold per night?" |
| One row per night per room type | Enables occupancy analysis | More complex to compute; fact table is much larger |
| One row per payment transaction | Precise revenue tracking | Harder to join to booking-level behavior |

The right grain is the one that answers the most important question efficiently. When two questions require conflicting grains, build two fact tables — this is exactly what the stretch goal (`fact_availability`) proposes.

---

## The `is_international` Flag — Unambiguous Definition

This task introduces a derived flag: is the booking international (guest country ≠ property country)? Simple in concept, but it requires a precise definition to be consistent:

- What if `guest.country` is NULL? Mark as `NULL` (unknown) or `FALSE`? Document the choice.
- Is "country" the guest's nationality, country of residence, or billing address?
- Does the flag live on the fact table or on a dimension?

Because `is_international` is computed from two other dimensions (guest and property) and logically belongs to a specific booking, it belongs on the **fact table** as a derived boolean — computed at ETL time and stored for efficient filtering.

```sql
is_international = (dim_guest.country_code != dim_property.country_code)
```
