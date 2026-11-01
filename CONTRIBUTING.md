# Contributing

Thanks for helping make this challenge better! It's in beta, so even small reports help a lot.

## Give feedback on a task

The most valuable contribution right now is telling us what didn't work for you.

- **Something unclear, wrong, too hard or too easy?** Open an issue with the [task feedback form](https://github.com/oleg-agapov/data_modeling_challenge/issues/new?template=task-feedback.yml). It takes two minutes.
- **A question about a concept or a task?** Ask in [Discussions → Q&A](https://github.com/oleg-agapov/data_modeling_challenge/discussions/categories/q-a).
- **`checks.sql` fails on what you think is a correct answer?** Please open an issue and paste the check output. Either the check is too strict, or the task description needs to be clearer. Both are worth fixing.

## Share your solution

Please **don't open pull requests with your solutions** to this repository: the `SOLUTION.md` files here are blank templates for everyone.

Instead:

1. Fork the repository and solve the tasks in your fork.
2. Commit your `SOLUTION.md` files, SQL and diagrams to your fork.
3. Post a link in [Discussions → Show your solution](https://github.com/oleg-agapov/data_modeling_challenge/discussions/categories/show-your-solution). Mention which tasks you solved and any decision you're unsure about.

Reviewing someone else's solution is a great way to learn too. When you comment, focus on the modeling decisions (grain, keys, trade-offs) rather than SQL style.

## Fix a typo or a mistake

Small fixes (typos, broken links, a wrong column name) are welcome as pull requests. For anything bigger, such as changing a task, adding a hint or a new task, please open an issue first so we can discuss it.

If your change touches SQL (theory examples, `checks.sql`, `setup.sql`, reference solutions):

- Run it in DuckDB against the tables created by [`setup.sql`](setup.sql).
- For `checks.sql` changes, make sure the matching reference solution in [`reference-solutions/`](reference-solutions/) still passes every check.
- Keep checks comparing the model with the source tables, rather than with hard-coded numbers.

## Conventions

Each task lives in `tasks/task-NN-short-name/` and contains:

| File | Purpose |
|---|---|
| `README.md` | Summary, difficulty, links |
| `TASK.md` | Context, Goal, Deliverables, Check your solution, Before you submit, Hints |
| `THEORY.md` | The concepts needed for the task |
| `SOLUTION.md` | Blank template with Conceptual, Logical and Physical sections |
| `checks.sql` | Automatic checks (where the task has data) |
| `assets/` | Images |

Column names always match the CSV headers documented in [`data/ecommerce.md`](data/ecommerce.md).
