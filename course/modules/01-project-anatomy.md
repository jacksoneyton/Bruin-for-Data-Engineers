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

## 1.2 Tour the starter templates (optional, 15 minutes)

You used `bruin init empty` in Module 0. Look at two other templates in a scratch folder that is not inside any Git repository, so their config cannot touch your work repository. A template that ships a `.bruin.yml` merges its connections into the `.bruin.yml` at the Git root of wherever you run it (`cmd/init.go`, read from source), which is why you never run this tour inside `lakota-bruin`.

```bash
mkdir ~/bruin-tour && cd ~/bruin-tour
bruin init default demo
find . -not -path './.git/*' -type f | head -30
cat bruin/.bruin.yml
```

Outside a repository, `bruin init` creates a `bruin/` wrapper, runs `git init` in it, puts `.bruin.yml` at that root and the pipeline in the named folder (`commands/init.md`). Add `--in-place` to initialize the current folder instead of creating the wrapper.

Then the Postgres starter:

```bash
cd ~/bruin-tour
rm -rf bruin demo
bruin init bronze-silver-postgres fx
cat bruin/.bruin.yml
cat bruin/fx/pipeline.yml
find bruin/fx -type f
```

You should see an ingestr asset (`bronze_raw_data.asset.yml`) that loads a public FX-rate API into Postgres, a SQL asset (`silver_aggregated.sql`) that builds a summary on top, and a `postgres-default` connection with placeholder credentials (`localhost`, database `bruin`, user `postgres`). The template's README, upstream at `templates/bronze-silver-postgres/README.md`, says to update that connection for your instance. Do not run it: it calls an external API, and it would write to whatever database `postgres-default` points at. Compare its layout with the one you build next, then delete the scratch folder:

```bash
cd ~ && rm -rf ~/bruin-tour
```

Two more `init` options you will meet later: `bruin init --merge <template> <existing pipeline>` copies a template's assets into a pipeline you already have without overwriting files, and `bruin init` with no arguments opens a template picker.

## 1.3 Lab: build the `lakota` pipeline

Work in `lakota-bruin` from Module 0.

### Step 1: scaffold the pipeline

```bash
cd ~/lakota-bruin
bruin init empty lakota
rm lakota/assets/placeholder
mkdir -p lakota/assets/ref lakota/assets/mart
cp "$COURSE/data/ref/branches.csv" "$COURSE/data/ref/products.csv" lakota/assets/ref/
```

`init` creates `lakota/pipeline.yml` and `lakota/assets/`. The `ref` and `mart` subfolders are this course's layout, not something Bruin requires. Replace the content of `lakota/pipeline.yml` with:

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

By default seeds enforce the column types you list (`enforce_schema: true`), and Bruin passes them to ingestr as type hints (`assets/seed.md`). The type names above (`integer`, `string`, `date`, `float`) are all in Bruin's type mapping (CLI source, `pkg/python/columns.go`). If your run rejects one, change it to `string` and record it in the validation log.

Seeds run through ingestr, which Bruin installs and runs through uv. The first `bruin run` in this module is therefore slower than later ones, and it is the first place a firewall or proxy on your machine can interfere with package downloads. Record how long the first run took and whether anything was downloaded. Bruin installs uv itself under `~/.bruin` if it is missing (Module 6 covers this).

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
bruin run lakota --start-date 2026-01-01 --end-date "2026-01-01 23:59:59.999999"
```

The dates do not matter for these assets, but passing them is a habit worth forming. Without them Bruin uses yesterday.

This is the date convention for the whole course. A date-only `--end-date` means midnight at the start of that day (`assets/materialization.md`, time_interval section: "A date-only `--end-date` means midnight at the start of that day"). `--start-date 2026-01-03 --end-date 2026-01-03` is therefore a window of zero length, and anything filtered on a timestamp after midnight falls outside it. To cover a whole day, give the end as the last microsecond of the day: `--end-date "2026-01-03 23:59:59.999999"`. That is exactly what the default window (yesterday) uses. Every lab command uses this form. `bruin backfill` is different: it treats a date-only end as inclusive (`commands/backfill.md`, Module 8).

Watch the output. The two seed assets can run in parallel. Each SQL asset runs after the seed it depends on. Quality checks run after each asset, and a failed blocking check stops downstream assets.

```bash
bruin query --connection lakota-pg --query "select * from mart.branches_by_state order by state"
bruin query --connection lakota-pg --query "select product_type, count(*) from mart.product_catalog group by 1 order by 1"
```

`bruin query` can also take an asset instead of a connection name, and it then uses that asset's connection: `bruin query --asset lakota/assets/mart/branches_by_state.sql --query "select count(*) from mart.branches_by_state"` (`commands/query.md`). Each `bruin query` call writes a small log under `logs/queries`, which Bruin adds to `.gitignore`.

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

You should see `ref.branches` and `ref.products` as base tables, `mart.branches_by_state` as a table, `mart.product_catalog` as a view. The seed docs contain an example that mentions a different table name than the asset name. The CLI source resolves the destination to the asset name (`ref.branches`). The `seed.raw` string in the docs is only the source label that Bruin hands to ingestr (`pkg/ingestr/operator.go`). Your query confirms it. Seeds also carry ingestr's own load columns, so expect extra columns in `ref.branches` beyond the five in the CSV (`\d ref.branches` in `psql`). Record the extra column names and types.

### Step 5: run pieces

```bash
bruin run lakota/assets/mart/branches_by_state.sql --start-date 2026-01-01 --end-date "2026-01-01 23:59:59.999999"
bruin run lakota/assets/ref/branches.asset.yml --downstream --start-date 2026-01-01 --end-date "2026-01-01 23:59:59.999999"
bruin run lakota --only checks --start-date 2026-01-01 --end-date "2026-01-01 23:59:59.999999"
```

- A path to one asset runs only that asset.
- `--downstream` adds everything that depends on it.
- `--only checks` runs quality checks without refreshing data (`commands/run.md`).
- `bruin run` lints the pipeline before it executes anything. `--no-validation` skips that step. The `bruin validate` you ran earlier is not optional hygiene before a run, because the run repeats the offline part of it.

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
5. Rename `branches.asset.yml` to `branches.yml`. Validate, then run `bruin lineage` on `branches_by_state.sql`. What does validate say, and what does the pipeline look like now? Rename it back.

<details>
<summary>Answers</summary>

1. The CSV path points at a file that does not exist. `validate` fails first. The seed rule reports "Seed file does not exist or cannot be found" (CLI source, `pkg/lint/rules.go`), and the same rule checks that every column you list exists in the CSV header. `bruin run` lints before it executes, so it fails the same way. Record the exact messages. As an extension, rename one column in the YAML and validate again to see the header message.
2. The lineage shows no upstream, because lineage follows `depends`. Without a dependency, Bruin has no reason to run the seed first, and the SQL asset can fail with a "relation does not exist" error. Bruin orders assets only by `depends` (`getting-started/concepts.md`). The `used-tables` rule in `validate` warns about this: "There are some tables that are referenced in the query but not included in the 'depends' list" (CLI source). The canonical repair is a command, not a hand edit: `bruin patch fill-asset-dependencies lakota` adds the missing `depends` entries (`commands/patch.md`). Try it, then diff the file. UNVERIFIED at runtime: record the warning text and what the patch wrote.
3. Asset names must be unique inside a pipeline. Validation reports the duplicate.
4. A view cannot have a `strategy`. The docs say setting `strategy`, `incremental_key`, `incremental_predicate`, `partition_by` or `cluster_by` on a view is a validation error.
5. `validate` warns that regular YAML files are not treated as assets. The seed is no longer an asset, so `branches_by_state` has a dependency on a name that does not exist in the pipeline. Record what `validate` and `lineage` report.
</details>

## Check questions

1. Which file extension must a standalone YAML asset use, and what happens to a plain `.yml` file?
2. What decides the order in which assets run?
3. What does `bruin render` print that `bruin query` does not?
4. What does `--only checks` skip?
5. Why does the course set `name` explicitly instead of relying on inference?

<details>
<summary>Answers</summary>

1. `.asset.yml` or `.asset.yaml`. A plain `.yml` file is not treated as an asset. `validate` warns about it ("Regular YAML files are not treated as assets, please rename them to `.asset.yml` if you intended to create assets", rule `plain-yaml-files`, CLI source).
2. The `depends` lists. Assets with no dependency between them can run in parallel.
3. The SQL that Bruin generates for the asset, including the `CREATE`, `INSERT`, `MERGE` or `DELETE` statements for the materialization strategy.
4. The main step (the asset's own query). Only the quality checks run.
5. A file placed directly under `assets/` infers a one-segment name, which Postgres rejects. Explicit names also survive file moves.
</details>

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| First `bruin run`: how long, anything downloaded (ingestr, uv)? | | |
| Seed table names (ref.branches?) and the extra ingestr columns | | |
| Seed `date` and `float` types accepted? | | |
| Validate output (any warnings?) | | |
| Run output shows parallel seeds? | | |
| Expected query results match? | | |
| Break/fix 1: which command failed first, message | | |
| Break/fix 2: validate warning text, run result, and what `patch fill-asset-dependencies` wrote | | |
| Break/fix 5: validate message for the renamed seed | | |
| `init --merge` or template tour: anything unexpected in `.bruin.yml`? | | |
| Time taken | | |
