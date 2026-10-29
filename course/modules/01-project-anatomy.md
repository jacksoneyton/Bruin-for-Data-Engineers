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
- Asset names are unique within a pipeline. On Postgres the name is `schema.table`, or just `table`. Bruin rejects three segments on Postgres (`assets/definition-schema.md`).
- If you leave `name` out, Bruin infers it from the path under `assets/`: `assets/mart/orders.sql` becomes `mart.orders`. A file placed directly in `assets/` infers a one-segment name such as `orders`. The docs say most databases reject that, but on Postgres Bruin accepts it and the table lands in `public` (Module 0 break/fix 2, observed by the course reviewer on v0.11.773). This course always sets `name` explicitly with a schema, so each module's tables live in a schema you can drop.

How to read the docs paths in this course: `assets/definition-schema.md` is published at `https://getbruin.com/docs/bruin/assets/definition-schema.html`. The same mapping applies to every path cited here.

## 1.2 Tour the starter templates (optional, 15 minutes)

You used `bruin init empty` in Module 0. Look at two other templates in a scratch folder that is not inside any Git repository, so their config cannot touch your work repository. A template that ships a `.bruin.yml` merges its connections into the `.bruin.yml` at the Git root of wherever you run it (`cmd/init.go`, read from source), which is why you never run this tour inside `lakota-bruin`.

```bash
mkdir ~/bruin-tour && cd ~/bruin-tour
bruin init default demo
find . -not -path './.git/*' -type f | head -30
cat bruin/.bruin.yml
```

In VS Code, `code ~/bruin-tour` opens the scratch folder in a separate window, which is easier than `cat` for reading these files.

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

Work in `lakota-bruin` from Module 0. Open that folder in VS Code (File, Open Folder) if you use it, and keep the terminal in Git Bash (Module 0, section 0.1). Each step gives the CLI commands and, where the Bruin extension offers the same action, a **VS Code** note. Extension notes are labeled with where they come from, as in Module 0.

### Step 1: scaffold the pipeline

```bash
cd ~/lakota-bruin
bruin init empty lakota
rm lakota/assets/placeholder
mkdir -p lakota/assets/ref lakota/assets/mart
cp "$COURSE/data/ref/branches.csv" "$COURSE/data/ref/products.csv" lakota/assets/ref/
```

**VS Code:** use the extension's init flow with the `empty` template and the name `lakota`, as in Module 0 (0.7). Copy the two CSV files with the terminal command above, or drag them into `lakota/assets/ref/` in the Explorer.

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

By default seeds enforce the column types you list (`enforce_schema: true`), and Bruin passes them to ingestr as type hints (`assets/seed.md`). The type names above (`integer`, `string`, `date`, `float`) are all in Bruin's type mapping (CLI source, `pkg/python/columns.go`). If your run rejects one, change it to `string` and record it in the validation log to improve this course.

**VS Code:** when you open an `.asset.yml` or a `.sql` file with a Bruin block, the extension highlights the block as YAML, offers autocomplete for the asset properties and validates it as you type (`vscode-extension/panels/side-panel/editor-experience.md`). For a new SQL or Python asset you can type `!fullsqlasset` or `!fullpythonasset` to insert a full template (`vscode-extension/getting-started.md`). The side panel's Columns tab edits the same `columns:` list you are typing by hand (`panels/side-panel/tabs.md`).

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
       round((interest_rate * 100)::numeric, 2) as rate_pct
FROM ref.products
```

`type: view` makes Bruin run `CREATE OR REPLACE VIEW` (`assets/materialization.md`). Views cannot have a `strategy`.

### Step 4: validate, run, query

```bash
bruin validate lakota
bruin run lakota --start-date 2026-01-01 --end-date "2026-01-01 23:59:59.999999"
```

The dates do not matter for these assets, but passing them is a habit worth forming. Without them Bruin uses yesterday.

**VS Code:** the side panel's General tab has an environment dropdown and start and end date inputs, in UTC, plus buttons that run Bruin commands for the open asset (`vscode-extension/panels/side-panel/tabs.md`, `getting-started.md`). Set the dates there to match the command. The terminal output of the run is still the record to read. UNVERIFIED: whether the extension's date inputs accept a time of `23:59:59.999999`. If not, run from the terminal for the end-of-day form.

This is the date convention for the whole course. A date-only `--end-date` means midnight at the start of that day (`assets/materialization.md`, time_interval section: "A date-only `--end-date` means midnight at the start of that day"). `--start-date 2026-01-03 --end-date 2026-01-03` is therefore a window of zero length, and anything filtered on a timestamp after midnight falls outside it. To cover a whole day, give the end as the last microsecond of the day: `--end-date "2026-01-03 23:59:59.999999"`. That is exactly what the default window (yesterday) uses. Every lab command uses this form. `bruin backfill` is different: it treats a date-only end as inclusive (`commands/backfill.md`, Module 8).

Watch the output. The two seed assets can run in parallel. Each SQL asset runs after the seed it depends on. Quality checks run after each asset, and a failed blocking check stops downstream assets.

```bash
bruin query --connection lakota-pg --query "select * from mart.branches_by_state order by state"
bruin query --connection lakota-pg --query "select product_type, count(*) from mart.product_catalog group by 1 order by 1"
```

`bruin query` finds `.bruin.yml` and the connection by name, so it needs no path to the pipeline or asset (Module 0, 0.10 explains why).

**VS Code:** the same SELECTs run from the Query Preview panel (**Run** or `Ctrl+Enter`, `vscode-extension/panels/query-preview.md`). You can also browse the new schemas and tables in the Bruin activity-bar view (`panels/activity-bar.md`).

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

You should see `ref.branches` and `ref.products` as base tables, `mart.branches_by_state` as a table, `mart.product_catalog` as a view. The seed docs contain an example that mentions a different table name than the asset name. The CLI source resolves the destination to the asset name (`ref.branches`). The `seed.raw` string in the docs is only the source label that Bruin hands to ingestr (`pkg/ingestr/operator.go`). Your query confirms it. Seeds also carry ingestr's own load columns, so expect extra columns in `ref.branches` beyond the five in the CSV. See them with `bruin query --connection lakota-pg --query "select column_name, data_type from information_schema.columns where table_schema = 'ref' and table_name = 'branches' order by ordinal_position"`. Record the extra column names and types.

### Step 5: run pieces

```bash
bruin run lakota/assets/mart/branches_by_state.sql --start-date 2026-01-01 --end-date "2026-01-01 23:59:59.999999"
bruin run lakota/assets/ref/branches.asset.yml --downstream --start-date 2026-01-01 --end-date "2026-01-01 23:59:59.999999"
bruin run lakota --only checks --start-date 2026-01-01 --end-date "2026-01-01 23:59:59.999999"
```

- A path to one asset runs only that asset.
- `--downstream` adds everything that depends on it.
- `--only checks` runs quality checks without refreshing data (`commands/run.md`).

**VS Code:** Run-with-downstream is an option in the extension's asset actions. It runs the open asset plus everything that depends on it, the same as `--downstream`. There is no equivalent for `--only checks`, so run that one in the terminal.
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

**VS Code:** the lineage panel sits at the bottom of VS Code next to the terminal and shows the open asset's upstream and downstream nodes. Its options menu switches between `All (downstream, upstream)`, one direction, or `Direct Only`, and a plus button on a node expands further dependencies (`vscode-extension/panels/lineage-panel.md`). That matches `lineage` and `lineage --full`. The extension's **Render** button shows the rendered, materialized query for the open asset, including Jinja (`vscode-extension/overview.md`, "Rendered Jinja queries"), which matches `bruin render`.

### Step 7: commit your work

Open `.gitignore` in VS Code (or run `cat .gitignore`) and confirm it lists `.bruin.yml` and `logs/` entries. Then:

```bash
git add .gitignore lakota
git commit -m "Module 1: lakota pipeline with seeds and two SQL assets"
git status
```

What these do: `git add` copies the current content of the named paths into Git's staging area, which is the list of changes the next commit will contain. `.gitignore` is one file. `lakota` is a folder, so Git stages everything inside it, at any depth (the pipeline file, the CSV files and the asset files). Naming the paths instead of using `git add .` keeps `.bruin.yml`, `logs/` and `check_setup.sh` out by construction, even if an ignore rule is wrong. `git commit -m` records the staged content as one commit with that message. `git status` should then report nothing staged, and `.bruin.yml` and `logs/` must not appear in it.

**VS Code:** the Source Control view (third icon in the left bar) shows the same changes. The `+` next to a file or folder stages it, and the message box with the Commit button does the commit.

## Break/fix

Restore each change before the next.

1. In `branches.asset.yml`, change `path: branches.csv` to `path: branch.csv`. Run `bruin validate lakota` and then `bruin run lakota`. Which one fails, and what does it say?
2. Remove the `depends` block from `branches_by_state.sql`. Run `bruin lineage lakota/assets/mart/branches_by_state.sql`. What changed? Then drop both schemas (`psql "$PGURL" -c "drop schema ref cascade; drop schema mart cascade"`, or the same statement in pgAdmin's Query Tool) and run the pipeline with `--workers 1`. What happens, and why?
3. Copy `product_catalog.sql` to `product_catalog_copy.sql` without changing the `name`. Run `bruin validate lakota`. Delete the copy.
4. In `product_catalog.sql`, add `strategy: merge` under `materialization` while keeping `type: view`. Validate.
5. Rename `branches.asset.yml` to `branches.yml`. Validate, then run `bruin lineage` on `branches_by_state.sql`. What does validate say, and what does the pipeline look like now? Rename it back.

<details>
<summary>Answers</summary>

1. The CSV path points at a file that does not exist. `validate` fails first, with a message that the seed file does not exist (the reviewer confirmed this on v0.11.773, issue #2). The rule is "Seed file does not exist or cannot be found" in the CLI source (`pkg/lint/rules.go`), and the same rule checks that every column you list exists in the CSV header. `bruin run` lints before it executes, so it fails with the same error. Record the exact messages. As an extension, rename one column in the YAML and validate again to see the header message.
2. The lineage shows no dependencies in either direction, because lineage follows `depends`. Without a dependency, Bruin has no reason to run the seed first. The reviewer's `--workers 1` run started `mart.branches_by_state` first and it failed with `relation "ref.branches" does not exist (SQLSTATE 42P01)`, while the seeds loaded afterwards and the quality checks passed. Bruin orders assets only by `depends` (`getting-started/concepts.md`). The `used-tables` rule is meant to warn about this: "There are some tables that are referenced in the query but not included in the 'depends' list" (CLI source, a warning-severity rule). In the reviewer's run the lint that `bruin run` prints before executing said "No issues found", so do not count on seeing the warning there. Run `bruin validate lakota` on its own and record whether it appears (UNVERIFIED). The canonical repair is a command, not a hand edit: `bruin patch fill-asset-dependencies lakota` adds the missing `depends` entries (`commands/patch.md`). Try it, then diff the file. UNVERIFIED at runtime: record the warning text and what the patch wrote.
3. Asset names must be unique inside a pipeline. Validation reports the duplicate. The reviewer saw: `Asset name 'mart.product_catalog' is not unique, Please make sure all the task names are unique.`
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
5. A file placed directly under `assets/` infers a one-segment name, and the table then lands in `public` instead of a schema of its own. Explicit names also survive file moves.
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
| VS Code (extension version?): init flow, run-with-downstream, lineage panel, Render, Query Preview. Which worked, which labels differ? Is there any way to run `--only checks`? | | |
| Break/fix 2: does `bruin validate lakota` print the `used-tables` warning? | | |
| Time taken | | |
