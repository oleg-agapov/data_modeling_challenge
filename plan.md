# Improvement Plan

Working plan for getting this repository ready to share with the analytics community.
It contains all the context needed to execute the plan without re-doing the research.

---

## 1. Goal of the repository

A free, self-paced practice repository for **junior data people** who want to upskill in
data modeling, starting with **dimensional modeling**. Learners get a realistic dataset,
a business problem per task, short theory, and a solution template that asks for
conceptual → logical → physical models plus documented trade-offs.

## 2. Decisions (agreed with the author)

| Topic | Decision |
|---|---|
| Audience | Junior data people starting with dimensional modeling |
| Scope | Mainly dimensional modeling + a few small, practical event/behavioral modeling tasks. OBT, Data Vault etc. are out of scope |
| Tooling | Tool-agnostic, DuckDB as the default. Repo must be self-sufficient (own setup instructions). An in-browser DuckDB playground may be hosted later |
| Dataset | **Stays static for now.** A generator script exists (not in repo). Messiness / history is deferred to a later version |
| Domains | Tasks may leave the e-commerce domain (e.g. the hotel task) |
| Technique rule | **If the dataset cannot genuinely showcase a technique, skip the technique** (no "simulate it" tasks) |
| Distribution | Soft launch on social media, collect first-student feedback, then iterate |
| Effort | Phase 1 is a weekend project; restructuring the curriculum is a later concern |
| Docs | Cleaning up READMEs and making all docs coherent is a priority |

## 3. Current state (as of this plan)

```
README.md                 main readme (cover, task table, workflow, deliverables)
materials/README.md       curated books / videos / guides
data/README.md            pointer to data docs
data/ecommerce.md         dataset docs  ← OUT OF DATE
data/ecommerce/*.csv      6 CSV files
data/ecommerce/schema.dbml, erd.png   ← OUT OF DATE
tasks/README.md           one-liner
tasks/task-0N-*/          README.md, TASK.md, THEORY.md, SOLUTION.md|SOLUTION.MD, image(s)
```

Tasks:

| # | Task | Notes |
|---|---|---|
| 01 | Revenue Reporting (order-level fact) | Only task with an example solution (`SOLUTION-example.md`) |
| 02 | Product Sales Report | Product grain aggregation |
| 03 | Star Schema Design | Fact on order line items + 4 dims |
| 04 | Hotel Booking Data Marts | Design-only, different domain, no data |
| 05 | User Conversion Funnel | Behavioral |
| 06 | Sessionization & Cart Abandonment | Behavioral |

## 4. Verified facts about the dataset

Profiled with DuckDB (`read_csv_auto`) against the CSVs in `data/ecommerce/`.

### 4.1 Real column names vs. what the docs say

The CSVs were regenerated (commits `337000e`, `ef27b51`) but the docs, DBML, ERD, tasks,
theory and example solution still use the **old** names.

| Table | Old name (in docs) | Real CSV column |
|---|---|---|
| users | `id` | `user_id` |
| users | `firstName` / `lastName` | `first_name` / `last_name` |
| users | `created_on` | `created_at` |
| users | `loc_id` | `location_id` |
| orders | `id` | `order_id` |
| orders | `date_ordered` | `order_date` |
| orders | `status` | `order_status` |
| orders | `updated` | `updated_at` |
| order_items | `id` | `order_item_id` |
| locations | `id` | `location_id` |
| locations | `code` | `country_code` |
| locations | `fullName` | `country_full_name` |
| locations | `stateRegion` | `state` |
| products | `id` | `id` (unchanged; it is the **last** column in the CSV) |
| user_events | — | unchanged (`event_id`, `user_id`, `event_type`, `event_timestamp`, `page_url`, `product_id`, `additional_details`) |

### 4.2 Row counts (docs are wrong)

| Table | Docs say | Actual |
|---|---:|---:|
| users | 12,483 | 12,483 |
| products | 21 | 21 |
| locations | 1,988 | **12,483** |
| orders | 1,988 | **1,918** |
| order_items | 2,161 | **2,092** |
| user_events | 190,370 | **191,157** |

### 4.3 Semantics and observations

- **Keys / integrity:** no duplicate PKs, no orphan FKs anywhere, no NULLs in users. Every order has ≥1 item (1,760 orders × 1 item, 142 × 2, 16 × 3).
- **`discount` is a rate**, not an amount: values `0` (1,696), `0.1` (136), `0.15` (120), `0.2` (140).
  `line_total = quantity * unit_price * (1 - discount)` holds for 100% of rows. Docs say `quantity * unit_price - discount` (wrong).
- **`quantity`** is always `1`.
- **`unit_price` quirk:** 166 of 2,092 line items have a `unit_price` that is a *different product's* price
  (e.g. Luna Side Table, catalog 139.50, sold at 899.00). Looks like a generator bug. Makes "selling price vs catalog price" metrics meaningless.
- **`locations` is 1:1 with users** (12,483 rows, no location shared) and **100% `US`**. It is the user's address, not "order destinations".
- **`updated_at` always equals `order_date`** → no change history in the data (no SCD2, snapshots, late-arriving data possible).
- **Order statuses:** pending 483, shipped 502, delivered 470, cancelled 463. **Payment methods:** paypal 678, bank transfer 632, credit card 608.
- **Date ranges:** users/events 2024-03-15 → 2026-03-15; orders 2024-03-15 → 2026-03-14. No order happens before the user's sign-up.
- **Every product has sales** (0 unsold products) → LEFT JOIN vs INNER JOIN gives the same result in Task 02.
- **Emails:** 317 duplicates.
- **Events** (`event_type`, `page_url`, has product):

  | event_type | page_url | product_id | rows |
  |---|---|---|---:|
  | user_sign_up | /signup | null | 12,483 |
  | page_view | /catalog | null | 63,423 |
  | page_view | /product | set | 103,037 |
  | page_view | /checkout | null | 2,405 |
  | page_view | /about_us | null | 1,613 |
  | add_to_cart | /product/add_to_cart | set | 8,196 |

- Every user has exactly one `user_sign_up` event and its timestamp **equals `users.created_at`**.
- There is **no purchase event**; purchases only exist in `orders`. `additional_details` is always empty.
- 1,767 users have orders. **Every buyer has an add_to_cart event**, every purchased (user, product) pair was carted, and every order happens within 1 hour after an add_to_cart event.
- **Timestamp ties:** 12,488 (user, timestamp) pairs have more than one event. At sign-up, the `user_sign_up` event and up to 9 `/catalog` views share the exact same timestamp. An `event_id` tie-breaker makes ordering deterministic but not meaningful (random UUIDs, so sign-up may sort after catalog views).
- **One short visit per user (found in Step 1):** all of a user's events fall within ≤ ~12 minutes of sign-up (median span ~2 min); consecutive events are never more than **60 seconds** apart. Orders are placed 1.5–9 minutes after sign-up. Consequences:
  - A 30-minute sessionization rule yields **exactly one session per user** (12,483 sessions). Sessionization cannot be meaningfully showcased (Task 06 Part B, and its "converted within 24h" stretch).
  - `days_to_first_purchase` (Task 05) is always 0; the cohort-maturity caveat is moot.
- **Add-to-cart not linked to views:** 2,217 add-to-cart events are for a product the user never viewed; 3,336 more come before the first view of that product.
- **Funnel coverage:** signed up 12,483 → viewed product 12,330 → added to cart 5,559 → viewed `/checkout` 2,171 → ordered 1,767.
- **File sizes:** `user_events.csv` 27 MB, everything else < 2 MB → loading from `raw.githubusercontent.com` in the browser DuckDB shell is feasible.
- **Types:** auto-detection gives `DOUBLE` for money; setup should cast to `DECIMAL(12,2)`.
- **Dialect:** theory snippets like `EXTRACT(EPOCH FROM (ts1 - ts2)) / 60` and `DATE_TRUNC` work in DuckDB.

### 4.4 What the static dataset can / cannot showcase

| Can showcase | Cannot showcase (skip for now) |
|---|---|
| Grain, fan-out, pre-aggregation | SCD Type 2 with real changes |
| Star schema, surrogate keys, `dim_date` | Accumulating snapshots (no status history) |
| Degenerate dims, junk dimension (`order_status × payment_method`, 12 combos) | Role-playing dates (only one real order date) |
| Conformed dims across order and event facts (bus matrix) | Late-arriving data |
| Factless fact (product views) | Data-quality exercises (data is clean) |
| Funnels, cohorts (registration month), anti-joins, event enrichment | International / multi-country analysis |
| | **Sessionization** (one visit per user, max gap 60 s) |
| | Time-to-convert in days (everything happens within minutes) |

## 5. Problems found in the repository

### Blockers
1. Docs, DBML, ERD, task hints, theory and example SQL use old column names → SQL does not run (see 4.1).
2. Wrong row counts and wrong field semantics in `data/ecommerce.md` (see 4.2, 4.3).
3. Task 02: `total_discount = SUM(discount)` sums rates → meaningless; `price_diff` / `avg_selling_price` vs catalog are noise due to the `unit_price` quirk.
4. Task 03: `dim_location` adds nothing (1:1 with users, US-only); the SCD2 stretch goal requires simulating history (violates the technique rule).
5. No setup instructions (how to load CSVs, which dialect).
6. No way for learners to verify their work; only Task 01 has an example solution.

### Smaller issues
- Task 01 `TASK.md` links to `SOLUTION.MD`, but the file is `SOLUTION.md` (broken on case-sensitive systems/GitHub). Tasks 02–06 use `SOLUTION.MD`.
- Main README says each task folder has "three files" — there are four (README, TASK, THEORY, SOLUTION).
- `tasks/README.md` is a single sentence.
- Task 01 theory references `users.payment_method` (it lives on `orders`).
- Task 05 theory has an unfinished snippet ("Instead: divide by a fixed subquery reference or use the first row's value").
- Task 06 sessionization examples don't break timestamp ties.
- Task 03 theory recommends `ROW_NUMBER() OVER ()` for surrogate keys (non-deterministic across rebuilds) and says fact tables are "wide" (they are narrow and long).
- Tasks 05–06 are labelled "Window Functions" rather than as modeling topics.
- Hints are effectively full answer specs (exact column lists), which removes most modeling decisions for the learner.
- Typo in `materials/README.md`: "programm".
- Task images live in the task root except Task 01 (`assets/`).

## 6. Feedback mechanism (recommended)

1. **`checks.sql` per task** — standard SQL assertions run against the learner's output tables, returning `check_name | PASS/FAIL` (grain uniqueness, row counts, revenue reconciliation, no NULL/orphan keys, expected totals). Requires fixed output table names per task.
2. **Self-review rubric** at the end of each `TASK.md` for conceptual/logical work.
3. **Reference solutions** for all tasks in a top-level `reference-solutions/` folder with a spoiler warning. Writing them also validates each task and produces the numbers for `checks.sql`.
4. **GitHub Discussions** ("Show your solution", "Q&A") + a "task feedback" issue template. Learner flow: fork → fill `SOLUTION.md` → post link in Discussions.

---

## 7. Phase 1 — v0.1 "shareable" (weekend)

Each step = one commit. Owner is Claude unless marked **(author)**.

- [x] **Step 1 — Fix dataset docs** (done) (`data/ecommerce.md`, `data/README.md`)
  - Real column names (4.1), real row counts (4.2), correct semantics (4.3): discount is a rate + correct `line_total` formula; locations = user address, 1:1, US-only; `updated_at = order_date`; no purchase event, `/checkout` is a page view; sign-up event = `created_at`.
  - Add a "Known quirks" section: 166 `unit_price` ≠ catalog price; 317 duplicate emails.
  - Done when: every statement matches a query against the CSVs.

- [x] **Step 2 — Fix schema & ERD** (done; ERD rendered from the DBML with headless Chromium, no dbdiagram export needed) (`data/ecommerce/schema.dbml`, `data/ecommerce/erd.png`)
  - Update DBML to real names. **(author)** re-export `erd.png` from dbdiagram.io.
  - Done when: DBML imports cleanly and matches CSV headers.

- [x] **Step 3 — File naming & links** (done; also moved all task images to `assets/` and turned the task README link lines into lists)
  - Rename `SOLUTION.MD` → `SOLUTION.md` in tasks 02–06; fix links in each `README.md` / `TASK.md`.
  - Optional: move task images into `assets/` everywhere for consistency.
  - Done when: a link checker finds no broken relative links.

- [x] **Step 4 — Column names in tasks, theory, example solution** (done; Task 01 output columns renamed to `order_date` / `order_status`; example solution verified in DuckDB: 1,918 rows, gross revenue 838,870.67)
  - Apply the mapping from 4.1 to every `TASK.md`, `THEORY.md`, `task-01/SOLUTION-example.md`.
  - Fix Task 01 theory: `users.payment_method` → `orders.payment_method`.
  - Done when: grep finds no old names (`date_ordered`, `created_on`, `loc_id`, `stateRegion`, `fullName`, `orders.id`, `users.id`, `order_items.id`, `locations.id`, bare `status` for orders).

- [x] **Step 5 — Getting started** (done; verified locally with DuckDB 2.0 Python and CLI v1.4.1, and the remote GitHub variant with DuckDB-WASM v1.1.1 in headless Chromium) (new `GETTING_STARTED.md`, new `setup.sql`)
  - Three paths: (a) zero-install shell.duckdb.org reading CSVs from `raw.githubusercontent.com`; (b) DuckDB CLI / `duckdb -ui`; (c) Python `pip install duckdb`.
  - `setup.sql` creates all six tables with explicit types (`DECIMAL(12,2)` money, `TIMESTAMP` dates).
  - Dialect note ("examples are DuckDB SQL; minor changes needed elsewhere") + a "verify setup" row-count query.
  - Done when: `duckdb < setup.sql` works from repo root and the browser variant works.

- [x] **Step 6 — Task 02 fixes** (done; `avg_selling_price` replaced by `avg_revenue_per_order` to keep the NULLIF lesson; added "rates are not amounts" theory. Verified: 21 rows, non-cancelled revenue 630,677.32, discount_amount 19,490.77 vs meaningless SUM(discount) 44.65) (`task-02/TASK.md`, `THEORY.md`)
  - Replace `total_discount` with `discount_amount = SUM(quantity * unit_price * discount)`.
  - Drop `avg_selling_price` and `price_diff`; keep `catalog_price`.
  - Note that all products have sales in this dataset; LEFT JOIN is still the correct, future-proof pattern.
  - Done when: every spec column is computable and meaningful.

- [x] **Step 7 — Task 03 fixes** (done; fact renamed to `fct_order_items`; added theory on "not every source table becomes a dimension", stable vs hash keys, address as Type 1, junk dimensions; fixed "degenerate dims never grouped". Verified reference build: fct 2,092 rows, revenue 838,870.67, dim_date 730, dim_customer 12,483, dim_product 21, dim_order_profile 12, no NULL/orphan FKs. Draft SQL kept for Step 10. **(author)** cover image `assets/image.png` shows dim_users/dim_orders×2 and doesn't match the spec — redraw or replace) (`task-03/TASK.md`, `THEORY.md`, optionally `image.png`)
  - Remove `dim_location`; fold `city`, `state`, `zip_code` into `dim_customer`. Add a theory paragraph on why a 1:1 table becomes attributes, not a dimension.
  - Stable surrogate keys: `ROW_NUMBER() OVER (ORDER BY <natural_key>)` (or a hash) + a line on why `OVER ()` is risky.
  - Replace the SCD2 stretch with a junk dimension `dim_order_profile` (`order_status × payment_method`, 12 rows).
  - Fix "fact tables tend to be wide" → narrow and long.
  - Done when: diagram, hints and theory consistently show 3 dims (+ optional junk dim).

- [x] **Step 8 — Tasks 04 / 05 / 06 fixes** (done. 04: business questions moved from a hint into the Goal, no-dataset note, "semi-additive" wording fixed. 05: `minutes_to_first_purchase`, working `pct_of_registered` snippet, LEFT JOIN + WHERE pitfall, nested-funnel and cohort-maturity notes; verified funnel 12,483 → 12,330 → 5,559 → 1,363. 06: renamed to `task-06-cart-abandonment` "Event Enrichment & Cart Abandonment" ⭐⭐, Parts A/B only, new stretch = product abandonment rate; theory on denormalization rules, anti-joins, ratio and distinct-count additivity, short note on sessions; verified enriched_events 191,157 rows, cart_abandonment 6,455 pairs. **(author)** Task 06 cover image shows sessions — regenerate)
  - 04: make sure cross-references about where SCD2 is introduced are consistent with Task 03.
  - 05: replace the unfinished snippet with a working pattern (total in a CTE, or `MAX(users_reached) OVER ()`); mention that every buyer added to cart in this dataset.
  - 05: `days_to_first_purchase` is always 0 → switch to minutes or drop it; drop the cohort-maturity caveat or mark it as general theory.
  - 06: add tie-breaker `ORDER BY event_timestamp, event_id` to `LAG` / running-sum examples, and explain why ties exist.
  - 06: **DECIDED (a):** sessionization yields one session per user, so drop Part B (sessionization) and the 24h-conversion stretch. Keep Part A (enriched events) and Part C (cart abandonment). Rename the task (e.g. "Event Enrichment & Cart Abandonment"), update its README/TASK/THEORY/image references and the main README task table; move sessionization theory to Phase 3. The `event_id` tie-breaker note is then only needed where event order matters.
  - Done when: theory snippets for 05/06 run against the `setup.sql` tables.

- [x] **Step 9 — Coherent READMEs** (done; main README rewritten: audience, beta note, prerequisites, topic column, task-folder file table, solution layers, "Checking your work", "Feedback" via GitHub issues, structure table, license. `tasks/README.md` now has a learning path with concepts per task, dependencies and a how-to. Typo fixed) (`README.md`, `tasks/README.md`, `materials/README.md`)
  - Main README: "Status: beta — feedback welcome", link to `GETTING_STARTED.md`, fix "three files" → four, relabel tasks 05/06 as "Behavioral modeling", explain how to check your work.
  - `tasks/README.md`: learning path, what each task teaches, prerequisites, how to submit.
  - Fix "programm" typo.
  - Done when: a newcomer can get from README to first query without guessing.

- [x] **Step 10 — Reference solutions + checks for Tasks 01–03** (done; `reference-solutions/` with README + Tasks 01–03 incl. stretch goals; Task 01 example moved there with a redrawn `logical.png`; `checks.sql` for Tasks 01 (8 checks), 02 (10), 03 (12) reconcile against source tables, not hard-coded numbers. Verified: reference solutions pass all checks in fresh DBs (Python + CLI v1.4.1); 11 deliberately broken models (fan-out, dropped cancellations, SUM(discount), date gaps, re-numbered keys, YYYYDDMM keys, dropped rows, missing address…) all FAIL the right checks; junk-dim stretch variant still passes. Output model names now stated in each Goal; "Check your solution" section added to TASK.md 01–03; README "Checking your work" updated)
  - New `reference-solutions/task-01…03/` (all three layers); move `task-01/SOLUTION-example.md` there; add a spoiler warning README.
  - Fix output table names in each `TASK.md`: `fct_orders`, `rpt_product_sales`, `fct_order_items`, `dim_customer`, `dim_product`, `dim_date` (+ optional `dim_order_profile`).
  - New `tasks/task-0N-*/checks.sql` returning `check_name | PASS/FAIL` (grain, row counts, revenue reconciliation, NULL/orphan FKs, expected totals from the reference solution).
  - Done when: reference solutions pass all checks; an empty or wrong table fails them.
  - Update the main README "Checking your work" section to point to `checks.sql` and `reference-solutions/`.
  - Note: Task 01 example validation queries 2–3 rebuild the model inline instead of querying `fct_orders`; simplify when moving it.

- [x] **Step 11 — Self-review rubric** in every `TASK.md` (done; task-specific "Before you submit" checklists, 6–8 items each, placed before the hints; Task 03 reference solution now states SCD type for every dimension to match its checklist)
  - "Before you submit" checklist (5–7 items): grain stated in one sentence, assumptions listed, trade-offs explained, validation performed, etc.

- [ ] **Step 12 — Community setup**
  - New `.github/ISSUE_TEMPLATE/task-feedback.yml` (which task, what was unclear, time spent) and a short `CONTRIBUTING.md`.
  - **(author)** Enable GitHub Discussions with "Show your solution" and "Q&A" categories.
  - Document the fork → fill `SOLUTION.md` → post link flow in the README (extend the existing "Feedback" section, which currently points to GitHub issues).

- [ ] **Step 13 — Final pass**
  - Fresh clone → `setup.sql` → reference solutions → `checks.sql` all pass; click every link.
  - **(author)** Ideally have one person do Task 01 cold before posting.

Estimated effort: ~6–9 hours. Steps 1–9 are mostly mechanical; Step 10 is the largest.

## 8. Phase 2 — v0.2 "after first feedback"

- [ ] **Step 14 — Triage feedback**: collect feedback issues and Discussions; tag as unclear / too hard / too easy / broken; fix top items before adding anything new.
- [ ] **Step 15 — Hint ladder** (all `TASK.md`): reorder hints to guiding questions ("What is one row? What's the spine?") → approach → full column spec last.
- [ ] **Step 16 — Reference solutions + checks for Tasks 04–06**: Task 04 gets a reference design doc + rubric (design-only, no `checks.sql`); Tasks 05/06 get solutions and checks (funnel stage counts, enriched event row count, cart abandonment rows).
- [ ] **Step 17 — New task: Conformed dimensions & bus matrix** (after Task 03): build `fct_product_events` (product views + add-to-carts) reusing `dim_customer`, `dim_product`, `dim_date`; draw a bus matrix; answer a cross-fact question (e.g. view-to-purchase rate by product).
- [ ] **Step 18 — Optional small task** (pick at most one, driven by feedback): factless fact for product views, or a daily product sales aggregate as a step toward periodic snapshots.
- [ ] **Step 19 — Materials refresh**: add Adamson, *Star Schema: The Complete Reference*; Joe Reis, *Practical Data Modeling*; tag each resource with the task(s) it supports.
- [ ] **Step 20 — Retro + `ROADMAP.md`**: write down Phase 3.

## 9. Phase 3 — later (requires changing the dataset)

Only once the generator is updated: sessionization (multi-visit users with gaps > 30 min), SCD2 with real attribute changes, accumulating snapshots (order status history), role-playing dates (shipped/delivered dates), late-arriving data, data-quality exercises (orphans, NULLs, duplicates), international addresses, anonymous (pre-sign-up) traffic. Also consider fixing the `unit_price` generator bug and adding the generator script to the repo.
