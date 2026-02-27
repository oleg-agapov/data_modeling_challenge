# Data Modeling Challenge

Practice end-to-end data modeling using realistic datasets.

This repository is a self-contained challenge: it includes source data, task prompts, and a place to document your approach and final solution.

## What this challenge covers

- Translating raw operational data into an analytics-friendly model
- Defining entities, relationships, keys, and grain
- Building fact/dimension thinking for transactional and event data
- Documenting assumptions, trade-offs, and modeling decisions

## Repository structure

- [data/](data/) — source datasets and dataset documentation
- [docs/](docs/) — instructions on how to approach data modeling
- [tasks/](tasks/) — challenge tasks and requirements

## Quick start

1. Review the source data in [data/ecommerce/](data/ecommerce/).
2. Read the dataset dictionary in [data/ecommerce.md](data/ecommerce.md).
3. Open the assignments in [tasks/README.md](tasks/README.md).
4. Design your model and record your work in [docs/](docs/).

## Suggested workflow

1. **Understand the source model**  
	Inspect each table, identify entity boundaries, and note data quality constraints.
2. **Define target model**  
	Decide on analytical grain, fact tables, dimension tables, and key relationships.
3. **Document assumptions**  
	Capture unclear business rules and how you resolved them.
4. **Validate consistency**  
	Reconcile totals, record counts, and foreign-key relationships where possible.
5. **Present final artifacts**  
	Provide diagrams, table definitions, and concise rationale.

## Expected deliverables

- A conceptual data model defined on a whiteboard
- A logical data model presented as ERD schema
- And a physical model defined as one or multiple SQL files
- Documentation that will explain your key assumptions and design trade-offs
- Additionally, you can provide table/column documentation and notes on validation checks you performed

## Notes

- Keep your solution practical and explainable.
- Prefer clarity over unnecessary complexity.
- Make assumptions explicit when requirements are ambiguous.

