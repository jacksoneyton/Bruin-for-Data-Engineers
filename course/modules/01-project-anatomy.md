# Module 1: Project anatomy

Estimated time: 2 hours. Written against Bruin v0.11.773.

## Outcome

You can describe and build the pieces of a Bruin project (project, pipeline, asset, connection, environment), create seed and SQL assets by hand, and use `validate`, `run`, `query`, `lineage` and `render` to inspect your work.

Docs for this module: `getting-started/concepts.md`, `core-concepts/project.md`, `assets/definition-schema.md`, `assets/seed.md`, `assets/sql.md`, `assets/columns.md`, `commands/lineage.md`, `commands/render.md`, `commands/query.md`.

## 1.1 The five nouns

| Term | What it is | Where it lives |
|---|---|---|
| Project | A Git repository. One `.bruin.yml` at its root. | repository root |
| Pipeline | A group of assets that run together in dependency order. | a folder containing `pipeline.yml` and an `assets/` folder |
| Asset | Anything derived from data: a table, a view, a Python script, a sensor. | one file under `assets/` |
| Connection | A named set of credentials for a platform or source. | `.bruin.yml` |
| Environment | A named group of connections (default, staging, production). | `.bruin.yml` |

Rules that cause most beginner mistakes:

- A pipeline folder needs `pipeline.yml` and an `assets/` folder next to it. Bruin finds assets only under `assets/`.
- The same repository can hold many pipelines. They share one `.bruin.yml`.
- A SQL asset (`.sql`) and a Python asset (`.py`) hold their definition inside the file, in a comment block. Asset types without code (seed, ingestr, sensor) are standalone YAML files that must end in `.asset.yml` or `.asset.yaml`. Plain `.yml` files are ignored.
- Asset names are unique within a pipeline. On Postgres the name is `schema.table`.
- If you leave `name` out, Bruin infers it from the path under `assets/`: `assets/mart/orders.sql` becomes `mart.orders`. A file placed directly in `assets/` would infer a one-segment name, which Postgres rejects. This course always sets `name` explicitly.

## 1.2 Look at what `bruin init` generates (optional, 10 minutes)

Do this in a scratch folder outside your work repository. Do not run the generated pipeline: the default template targets DuckDB and an external API.

```bash
mkdir ~/scratch && cd ~/scratch
bruin init default demo
find . -not -path './.git/*' -type f | head -30
```

`bruin init` in an empty folder creates a `bruin/` wrapper, initializes Git, puts `.bruin.yml` at the project root and the pipeline in a named folder (`commands/init.md`). Run inside an existing repository it uses that repository's root instead. Compare the layout with the one below, then delete `~/scratch`.

## 1.3 Lab: build the `lakota` pipeline

Work in `lakota-bruin` from Module 0.

### Step 1: folders and pipeline file

```bash
cd ~/lakota-bruin
mkdir -p lakota/assets/ref lakota/assets/mart
cp "$COURSE/data/ref/branches.csv" "$COURSE/data/ref/products.csv" lakota/assets/ref/
```

`lakota/pipeline.yml`:

```yaml
name: lakota
default_connections:
  postgres: "lakota-pg"
```

### Step 2: two seed assets

A seed loads a file into the database. The `path` is relative to the asset file (`assets/seed.md`).

`lakota/assets/ref/branches.asset.yml`:

```yaml
name: ref.branches
type: pg.seed
parameters:
  path: branches.csv
columns:
  - name: branch_id
    type: integer
    primary_key: true
    checks:
      - name: not_null
      - name: unique
  - name: branch_name
    type: string
  - name: city
    type: string
  - name: state
    type: string
  - name: opened_date
    type: date
```

`lakota/assets/ref/products.asset.yml`:

```yaml
name: ref.products
type: pg.seed
parameters:
  path: products.csv
columns:
  - name: product_code
    type: string
    primary_key: true
    checks:
      - name: not_null
      - name: unique
  - name: product_name
    type: string
  - name: product_type
    type: string
    checks:
      - name: accepted_values
        value: ["CHECKING", "SAVINGS", "LOAN"]
  - name: interest_rate
    type: float
```

By default seeds enforce the column types you list (`enforce_schema: true`). If a type name is rejected on your run (for example `date`), change it to `string` and record it in the validation log.

### Step 3: two SQL assets

`lakota/assets/mart/branches_by_state.sql`:

```sql
/* @bruin
name: mart.branches_by_state
type: pg.sql
depends:
  - ref.branches
materialization:
  type: table
columns:
  - name: state
    type: string
    checks:
      - name: not_null
  - name: branch_count
    type: integer
    checks:
      - name: positive
@bruin */

SELECT state, count(*) AS branch_count
FROM ref.branches
GROUP BY state
```

`lakota/assets/mart/product_catalog.sql`:

```sql
/* @bruin
name: mart.product_catalog
type: pg.sql
depends:
  - ref.products
materialization:
  type: view
@bruin */

SELECT product_code,
       product_name,
       product_type,
       round(interest_rate * 100, 2) AS rate_pct
FROM ref.products
```

`type: view` makes Bruin run `CREATE OR REPLACE VIEW` (`assets/materialization.md`). Views cannot have a `strategy`.

### Step 4: validate, run, query

```bash
bruin validate lakota
bruin run lakota --start-date 2026-01-01 --end-date 2026-01-01
```

The dates do not matter for these assets, but passing them is a habit worth forming. Without them Bruin uses yesterday.

Watch the output. The two seed assets can run in parallel. Each SQL asset runs after the seed it depends on. Quality checks run after each asset, and a failed blocking check stops downstream assets.

```bash
bruin query --connection lakota-pg --query "select * from mart.branches_by_state order by state"
bruin query --connection lakota-pg --query "select product_type, count(*) from mart.product_catalog group by 1 order by 1"
```

Expected:

| state | branch_count |
|---|---|
| ND | 3 |
| SD | 5 |

and three product types with two products each (CHECKING 2, LOAN 2, SAVINGS 2).

Check where Bruin put the seed tables:

```bash
bruin query --connection lakota-pg --query "select table_schema, table_name, table_type from information_schema.tables where table_schema in ('ref','mart') order by 1,2"
```

You should see `ref.branches` and `ref.products` as base tables, `mart.branches_by_state` as a table, `mart.product_catalog` as a view. The seed docs contain an example that mentions a different table name than the asset name. UNVERIFIED which one Postgres uses. Your query settles it.

### Step 5: run pieces

```bash
bruin run lakota/assets/mart/branches_by_state.sql --start-date 2026-01-01 --end-date 2026-01-01
bruin run lakota/assets/ref/branches.asset.yml --downstream --start-date 2026-01-01 --end-date 2026-01-01
bruin run lakota --only checks --start-date 2026-01-01 --end-date 2026-01-01
```

- A path to one asset runs only that asset.
- `--downstream` adds everything that depends on it.
- `--only checks` runs quality checks without refreshing data (`commands/run.md`).

### Step 6: inspect

```bash
bruin lineage lakota/assets/mart/branches_by_state.sql
bruin lineage --full lakota/assets/mart/branches_by_state.sql
bruin lineage -o json lakota/assets/mart/branches_by_state.sql
bruin render lakota/assets/mart/branches_by_state.sql
bruin render --raw-query lakota/assets/mart/branches_by_state.sql
bruin render --full-refresh lakota/assets/mart/branches_by_state.sql
```

- `lineage` shows direct upstream and downstream assets. `--full` adds indirect ones. `-o json` is for scripts.
- `render` prints the exact SQL Bruin will send to the database. Read this output for every materialization you meet in Module 3.

### Step 7: commit your work

```bash
cat .gitignore
git add .gitignore lakota
git commit -m "Module 1: lakota pipeline with seeds and two SQL assets"
```

`.bruin.yml` and `logs/` must not appear in `git status`.

## Break/fix

Restore each change before the next.

1. In `branches.asset.yml`, change `path: branches.csv` to `path: branch.csv`. Run `bruin validate lakota` and then `bruin run lakota`. Which one fails, and what does it say?
2. Remove the `depends` block from `branches_by_state.sql`. Run `bruin lineage lakota/assets/mart/branches_by_state.sql`. What changed? Then drop both schemas (`psql "$PGURL" -c "drop schema ref cascade; drop schema mart cascade"`) and run the pipeline with `--workers 1`. What happens, and why?
3. Copy `product_catalog.sql` to `product_catalog_copy.sql` without changing the `name`. Run `bruin validate lakota`. Delete the copy.
4. In `product_catalog.sql`, add `strategy: merge` under `materialization` while keeping `type: view`. Validate.

<details>
<summary>Answers</summary>

1. The CSV path points at a file that does not exist. Local CSV seeds are validated against their columns, so `validate` should catch it. UNVERIFIED which command fails first and the exact message. Record it.
2. The lineage shows no upstream, because lineage follows `depends`. Without a dependency, Bruin has no reason to run the seed first, and the SQL asset can fail with a "relation does not exist" error. Bruin orders assets only by `depends` (`getting-started/concepts.md`). UNVERIFIED whether `validate` warns about tables referenced in the query but absent from `depends`. Record it.
3. Asset names must be unique inside a pipeline. Validation reports the duplicate.
4. A view cannot have a `strategy`. The docs say setting `strategy`, `incremental_key`, `incremental_predicate`, `partition_by` or `cluster_by` on a view is a validation error.
</details>

## Check questions

1. Which file extension must a standalone YAML asset use, and what happens to a plain `.yml` file?
2. What decides the order in which assets run?
3. What does `bruin render` print that `bruin query` does not?
4. What does `--only checks` skip?
5. Why does the course set `name` explicitly instead of relying on inference?

<details>
<summary>Answers</summary>

1. `.asset.yml` or `.asset.yaml`. A plain `.yml` file is ignored.
2. The `depends` lists. Assets with no dependency between them can run in parallel.
3. The SQL that Bruin generates for the asset, including the `CREATE`, `INSERT`, `MERGE` or `DELETE` statements for the materialization strategy.
4. The main step (the asset's own query). Only the quality checks run.
5. A file placed directly under `assets/` infers a one-segment name, which Postgres rejects. Explicit names also survive file moves.
</details>

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| Seed table names (ref.branches?) | | |
| Seed `date` and `float` types accepted? | | |
| Validate output (any warnings?) | | |
| Run output shows parallel seeds? | | |
| Expected query results match? | | |
| Break/fix 1: which command failed first, message | | |
| Break/fix 2: result without depends | | |
| Time taken | | |
