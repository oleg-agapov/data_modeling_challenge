# Task 04 – Hotel Booking Data Marts (Conceptual & Logical Design)

![Image](image.png)

**Difficulty**: Medium ⭐️⭐️

**Theory**: [Slowly Changing Dimensions, Data Marts, and Design-First Thinking](THEORY.md)


## Context

A hotel booking platform wants to build an analytics layer on top of its operational data. The data engineering team has been asked to design data marts that will power executive dashboards and enable deeper segment analysis.

The deliverable is a **design document**, not code. You should produce:
1. A **conceptual model** — key business entities and their relationships.
1. A **logical model** — fact and dimension tables with column-level definitions, grain statements, and notes on how the model answers each business question.


## Goal

Design a **conceptual + logical data mart model** for a hotel booking analytics layer so that all required business questions are answerable from the final design.


## Deliverables

Fill in the `SOLUTION.MD` file in this directory. It must cover three sections:

1. **Conceptual layer** — describe the business entities, their relationships, and the grain of the output model in plain language.
2. **Logical layer** — define the fact and dimension tables with columns, data types, and keys; explain how each source table maps to the proposed model.
3. **Business question mapping** — for each business question in the Goal section, identify which facts, dimensions, and measures answer it.

You are free to enrich your solution with anything that helps communicate your thinking: diagrams (e.g. [Excalidraw](https://excalidraw.com/), [DrawDB](https://www.drawdb.app)), links, screenshots, or extra explanation. There is no strict format — clarity and correctness matter most.

## Hints

<details>
<summary>
Hint 1. Business questions to answer
</summary>

The following questions must all be answerable from the final model:

1. **General business health** — What does the overall booking volume, revenue, average daily rate (ADR), and cancellation rate look like over time? Are key metrics improving or declining month-over-month?
1. **Local vs. international demand** — What share of bookings (and revenue) comes from guests whose country of origin differs from the property's country? How does this split vary by property, region, or season — and what does it imply for marketing budget allocation?
1. **Occupancy and capacity utilization** — How fully booked are properties over time, broken down by room type and season? Where is there persistent under- or over-demand?
1. **Guest retention and loyalty** — What proportion of bookings come from returning guests vs. first-timers? How does lifetime booking value differ between the two segments, and which channels tend to produce more loyal guests?

</details>


<details>
<summary>
Hint 2. Conceptual model requirements
</summary>

Identify the core business **entities** involved in the hotel booking domain and describe the relationships between them. At minimum, your model should cover:

| Entity | Notes |
|---|---|
| **Guest** | The person making the booking; carries origin country |
| **Property** | The hotel or accommodation unit; carries country and city |
| **Room Type** | Category of room (e.g. single, double, suite); belongs to a property |
| **Booking** | The reservation event; central transactional entity |
| **Stay** | Actual check-in / check-out (may differ from booking if date changes occur) |
| **Booking Channel** | How the booking was made (e.g. direct web, mobile app, OTA, corporate) |
| **Payment** | Financial transaction tied to a booking; may include deposits and final charges |

For each relationship, state the **cardinality** (one-to-many, many-to-many, etc.) and whether it is mandatory or optional.

Example entry: `A Guest can make many Bookings; each Booking belongs to exactly one Guest (mandatory).`

</details>


<details>
<summary>
Hint 3. Logical model requirements
</summary>

Design a **star schema** (or justified snowflake variant) with at least one fact table and supporting dimension tables. For each table, define the grain, all columns with types and descriptions, and note whether any surrogate keys are needed.

### Suggested fact table: `fact_bookings`

**Grain:** one row per booking.

Define columns for the following categories:

- **Foreign keys** to all relevant dimensions (date of booking, check-in date, check-out date, guest, property, room type, channel)
- **Degenerate dimensions** that live on the fact but do not warrant their own dimension (e.g. booking reference number)
- **Additive measures**: booking value, number of nights, number of guests
- **Semi-additive or derived measures**: lead time in days (booking date -> check-in date), `is_cancelled` flag, `is_international` flag (guest country != property country)

### Required dimension tables

Design at minimum the following dimensions and specify their columns:

| Dimension | Key attributes to include |
|---|---|
| `dim_date` | Full date spine; year, quarter, month, week, day of week, `is_weekend`, `is_holiday` |
| `dim_guest` | Guest ID, origin country, region (continent or custom grouping), first booking date |
| `dim_property` | Property ID, name, country, city, star rating, property type (hotel / apartment / hostel) |
| `dim_room_type` | Room type ID, name (single/double/suite/...), max capacity, bed configuration |
| `dim_channel` | Channel ID, channel name, channel group (direct / OTA / corporate / other) |

For each dimension, state whether you would implement **Slowly Changing Dimension (SCD) Type 1 or Type 2**, and justify the choice.

</details>


<details>
<summary>
Hint 4. Question-to-model mapping and quality criteria
</summary>

For each of the four business questions, write a short paragraph (3-5 sentences) explaining:
- Which fact table(s) and dimension(s) are involved.
- Which measures or flags make the question answerable.
- Any assumptions or limitations in the model that affect the answer.

A strong submission will:
- Clearly separate conceptual entities from logical table structures.
- Justify all grain decisions - explain what is lost or gained by choosing a coarser or finer grain.
- Identify at least one modeling trade-off (e.g. SCD strategy, snowflaking a dimension, handling cancellations in the fact table).
- Ensure the `is_international` flag is defined unambiguously and consistently across the model.
- Note any data quality assumptions (e.g. what happens if guest country is unknown).

</details>


<details>
<summary>
Hint 5. Stretch goal
</summary>

Propose a second fact table - `fact_availability` - at the grain of **one row per room type per night**, carrying an `available_rooms` measure. Describe how it would be joined to `fact_bookings` to compute **occupancy rate**, and discuss any fan-out or double-counting risks in such a join.

</details>
