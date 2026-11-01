# Getting started

To solve the tasks you need a place to run SQL against the dataset. Any analytical database works. This guide uses **[DuckDB](https://duckdb.org)**: it is free, runs on your laptop or in the browser, needs no server, and reads CSV files directly.

Pick **one** of the options below. Each takes about five minutes.

| Option | Install needed | Best for |
|---|---|---|
| [A. In the browser](#option-a-in-the-browser-no-install) | None | Trying the challenge right now |
| [B. DuckDB CLI and local UI](#option-b-duckdb-on-your-computer-recommended) | One small program | Working through all tasks (recommended) |
| [C. Python](#option-c-python) | `pip install duckdb` | People who already work in Python or Jupyter |

All options use the same script, [`setup.sql`](setup.sql). It creates six tables with proper column types and finishes with a row count check.


## Option A: in the browser (no install)

1. Open **[shell.duckdb.org](https://shell.duckdb.org)**.
2. Open [`setup.sql`](setup.sql) on GitHub and click **Raw**. Copy everything.
3. In the copied text, change the two `SET VARIABLE` lines so the **second** one is active (it loads the CSV files from GitHub):

   ```sql
   -- SET VARIABLE data_path = 'data/ecommerce/';
   SET VARIABLE data_path = 'https://raw.githubusercontent.com/oleg-agapov/data_modeling_challenge/main/data/ecommerce/';
   ```

4. Paste it into the shell and press Enter. Loading takes a few seconds (about 30 MB is downloaded).
5. Check that the row counts match the [expected numbers](#check-your-setup).

Keep in mind:
- The tables live in your browser tab only. **If you reload the page, run the setup again.**
- Keep your queries in a text file on your computer, not only in the shell.


## Option B: DuckDB on your computer (recommended)

**1. Install the DuckDB CLI** ([official instructions](https://duckdb.org/docs/installation/)):

```bash
# macOS
brew install duckdb
```

```bash
# Linux or macOS without Homebrew
curl https://install.duckdb.org | sh
```

```bash
# Windows
winget install DuckDB.cli
```

**2. Get the repository.** Fork it on GitHub (so you can push your solutions later) and clone your fork. Or download it as a ZIP from the green **Code** button.

```bash
git clone https://github.com/<your-username>/data_modeling_challenge.git
cd data_modeling_challenge
```

**3. Load the data.** From the repository root, run:

```bash
duckdb challenge.duckdb -c ".read setup.sql"
```

This creates a database file `challenge.duckdb` in the repository root and prints the row counts. The file is ignored by git. Run the command again any time you want a fresh copy of the source tables.

**4. Start querying.** You have two ways to work:

- **Notebook UI in your browser** (DuckDB 1.2.1 or newer):

  ```bash
  duckdb -ui challenge.duckdb
  ```

- **Terminal:**

  ```bash
  duckdb challenge.duckdb
  ```

  Then type SQL at the `D` prompt. To run a whole file, use `.read path/to/file.sql`. Type `.quit` to exit.

Any SQL editor that supports DuckDB also works, for example [DBeaver](https://dbeaver.io), [VS Code](https://code.visualstudio.com) with a DuckDB extension, or [DataGrip](https://www.jetbrains.com/datagrip/). Point it at `challenge.duckdb`.


## Option C: Python

```bash
pip install duckdb
```

Run this from the repository root, in a script or a Jupyter notebook:

```python
import duckdb

con = duckdb.connect("challenge.duckdb")
con.sql(open("setup.sql").read()).show()  # loads the data and prints the row counts

con.sql("SELECT order_status, COUNT(*) AS orders FROM orders GROUP BY 1").show()
```

`con.sql(...)` returns a result you can `.show()`, or turn into a pandas DataFrame with `.df()`. Close other programs that have `challenge.duckdb` open (for example the CLI), because only one process can write to the file at a time.


## Check your setup

The last statement of `setup.sql` prints the number of rows in each table. You should see exactly:

| table_name | row_count |
|---|---:|
| users | 12,483 |
| locations | 12,483 |
| products | 21 |
| orders | 1,918 |
| order_items | 2,092 |
| user_events | 191,157 |

If a number is different, check that you ran the script from the repository root (Options B and C), or that the browser version uses the GitHub URL (Option A).

Then try a first query:

```sql
SELECT category, COUNT(*) AS products, MIN(price) AS cheapest, MAX(price) AS most_expensive
FROM products
GROUP BY category
ORDER BY category;
```

Before you start a task, read the [dataset documentation](data/ecommerce.md). It explains every column and lists a few quirks of the data.


## How to save your work

- Write each model as a `CREATE OR REPLACE VIEW` (or `CREATE OR REPLACE TABLE ... AS SELECT`) so you can query it by name, for example `SELECT * FROM fct_orders`.
- Keep your SQL in files inside the task folder, for example `tasks/task-01-revenue-reporting/fct_orders.sql`, and run them with `.read` (CLI) or by pasting them (browser).
- Copy the final SQL into the task's `SOLUTION.md` together with your explanations.


## Using a different database

The tasks are not tied to DuckDB. If you prefer PostgreSQL, Snowflake, BigQuery or anything else, load the six CSV files from [`data/ecommerce/`](data/ecommerce/) with your tool's import feature. Use the column types from [`setup.sql`](setup.sql) as a guide: money as `DECIMAL(12,2)`, dates as `TIMESTAMP`, and IDs and `zip_code` as text.

**About the SQL in this repository:** examples and hints are written in DuckDB SQL, which is very close to PostgreSQL. Things that may need small changes in other databases:

| DuckDB example | What it does | Other databases may use |
|---|---|---|
| `DATE_TRUNC('month', ts)` | First day of the month | Same in PostgreSQL and Snowflake. BigQuery: `DATE_TRUNC(ts, MONTH)` |
| `EXTRACT(EPOCH FROM (ts2 - ts1))` | Seconds between two timestamps | `DATEDIFF(second, ts1, ts2)` in Snowflake, `TIMESTAMP_DIFF(ts2, ts1, SECOND)` in BigQuery |
| `ts::DATE` | Cast to date | `CAST(ts AS DATE)` works everywhere |
