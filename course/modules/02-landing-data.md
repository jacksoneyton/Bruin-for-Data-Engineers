# Module 2: Landing data with ingestr

Estimated time: 3 to 3.5 hours. Written against Bruin v0.11.773.

## Outcome

You load tables from a source system into a landing schema with ingestr assets, choose a write strategy per table, drive incremental loads with the run's date window, and can explain what ingestr does and does not do with deleted rows.

Docs for this module: `assets/ingestr.md`, `ingestion/overview.md`, `ingestion/csv.md`, `platforms/postgres.md`, `assets/interval-modifiers.md`, and the ingestr docs `getting-started/incremental-loading` and `commands/ingest` (repository `bruin-data/ingestr`, folder `docs/`).

## 2.1 What an ingestr asset is

An ingestr asset is a standalone YAML file (`*.asset.yml`) with `type: ingestr`. Bruin turns it into a call to the open-source ingestr tool, which reads a source table and writes a destination table. You write no code.

```yaml
name: landing.core_customers
type: ingestr
tags:
  - landing
parameters:
  source_connection: lakota-src
  source_table: src_core.customers
  destination: postgres
```

- `name` is the destination table.
- `source_connection` is a connection name from `.bruin.yml`.
- `source_table` is the table (or, for SQL sources, `query:` plus a SQL statement).
- `destination` is a destination type. Bruin picks the destination connection from `default_connections` in `pipeline.yml`. You can override with `connection` or `destination_connection`.

### How incremental loading works here

This is the most important idea in the module, and it differs from many ETL tools.

- ingestr does not look at the destination table to find a high-water mark. The window comes from the run: Bruin passes `--interval-start` and `--interval-end` to ingestr, taken from `--start-date` and `--end-date` (`assets/ingestr.md`, "Run configuration").
- With `append` or `merge` and an `incremental_key`, ingestr reads only source rows whose key falls in the window, then appends or merges them.
- With `delete+insert`, ingestr deletes destination rows whose `incremental_key` is inside the window and inserts what it staged.
- Both bounds are inclusive in ingestr (`commands/ingest`).
- Running the same window twice with `append` duplicates rows. With `merge` and `delete+insert` it does not.

The consequence: you, or a scheduler, own the window. A load is only as correct as the dates you pass.

### Strategies available to ingestr assets

`create+replace`, `append`, `merge`, `delete+insert`, `truncate+insert`, set under `materialization.strategy`. ingestr's own `scd2` strategy is not supported through Bruin ingestr assets. `merge` needs primary keys, which you mark with `primary_key: true` on columns. Source: `assets/ingestr.md`.

UNVERIFIED: `truncate+insert`. The Bruin page lists it as accepted for Postgres. The ingestr page for the `ingest` command (`commands/ingest`) says the former `truncate+insert` strategy "has been removed" and points to `replace`. The two pages disagree about the ingestr version Bruin installs. This course does not use `truncate+insert`. If you want to settle it, run a probe asset with it and record the result.

### Which ingestr Bruin runs

Bruin installs ingestr itself, and an asset can choose the engine with `parameters.version`: `v0`, `v1`, or a full pin such as `v1.0.71` (`assets/ingestr.md`, parameter table). Without it, Bruin uses its built-in default for the CLI version you installed (v1 in v0.11.773; the CLI source pins ingestr 1.1.63 for `v1`). That is one more reason this course pins the Bruin version in Module 0.

## 2.2 Prepare the source system

The source system is the `src_core` schema in `bruin_course_src`. A SQL script creates it and loads day 1.

```bash
cd "$COURSE/data"
psql "$PGURL_SRC" -f sql/01_source_init.sql
```

Expected final output, a three-row table:

| tbl | count |
|---|---|
| customers | 60 |
| accounts | 83 |
| transactions | 150 |

The script drops and recreates only the `src_core` schema, so you can re-run it any time to reset the source to day 1. It never touches your warehouse database.

Facts about the source that you will rely on (they come from the generator in `course/tools/make_data.py`):

- `customers` and `accounts` carry `updated_at`. Changed rows get a new `updated_at` on the day they change.
- `transactions` is append-only. `txn_ts` falls on 2026-01-01 and 2026-01-02 for day 1.
- Day 2 applies on 2026-01-03, day 3 on 2026-01-04.
- The source hard-deletes one account per day. Nothing in the source marks the delete.

## 2.3 Lab: landing tables

Work in `lakota-bruin`.

### Step 0: let Bruin draft the assets

You would never write twenty ingestr assets by hand for a real source schema. `bruin import database` reads the source's tables and writes one asset per table (`commands/import.md`). It needs an existing pipeline folder to write into: the command finds the pipeline by walking up from the path you give it (CLI source), so it does not create one, even though the docs wording suggests it does. Use a throwaway pipeline:

```bash
cd ~/lakota-bruin
bruin init empty scratch_import
cat > scratch_import/pipeline.yml <<'EOF'
name: scratch_import
default_connections:
  postgres: "lakota-pg"
EOF
rm scratch_import/assets/placeholder
```

The source schema has to exist before you can import from it. Apply the day 1 script from 2.2 first if you have not, then:

```bash
bruin import database --connection lakota-src --schema src_core --ingestr --destination postgres scratch_import
find scratch_import -type f
cat scratch_import/assets/src_core/customers.asset.yml
```

`--ingestr --destination postgres` makes runnable ingestr assets that copy each table into the pipeline's default Postgres connection. Without `--ingestr` you get metadata-only `pg.source` placeholder assets that run nothing. Leaving off `--connection` opens an interactive picker instead. Add `--no-columns` to skip filling column metadata from the database.

Compare the output with what you need. The draft keeps the source schema and table as the asset name (`src_core.customers`), so a run would copy into a `src_core` schema in the warehouse. It sets no `materialization`, no `incremental_key` and no primary key, which is the real design work: strategy, key and window are decisions Bruin cannot read from the source. UNVERIFIED: which column metadata and description the draft carries. Record what you see. Then delete the throwaway pipeline and write the three assets below by hand, which is the same shape with your decisions added:

```bash
rm -rf scratch_import
```

Similarly, `bruin patch fill-columns-from-db --connection lakota-src <asset>` can fill the `columns` block of an existing asset from a table's structure (`commands/patch.md`). You will use it in Module 11.

### Step 1: the three assets

Add to `lakota/assets/`:

```text
lakota/assets/landing/
  core_customers.asset.yml
  core_accounts.asset.yml
  core_transactions.asset.yml
```

`core_customers.asset.yml`:

```yaml
name: landing.core_customers
type: ingestr
tags:
  - landing
parameters:
  source_connection: lakota-src
  source_table: src_core.customers
  destination: postgres
materialization:
  type: table
  strategy: merge
  incremental_key: updated_at
columns:
  - name: customer_id
    type: integer
    primary_key: true
    checks:
      - name: not_null
      - name: unique
  - name: updated_at
    type: timestamp
```

`core_accounts.asset.yml`:

```yaml
name: landing.core_accounts
type: ingestr
tags:
  - landing
parameters:
  source_connection: lakota-src
  source_table: src_core.accounts
  destination: postgres
materialization:
  type: table
  strategy: merge
  incremental_key: updated_at
columns:
  - name: account_id
    type: integer
    primary_key: true
    checks:
      - name: not_null
      - name: unique
  - name: updated_at
    type: timestamp
```

`core_transactions.asset.yml`:

```yaml
name: landing.core_transactions
type: ingestr
tags:
  - landing
parameters:
  source_connection: lakota-src
  source_table: src_core.transactions
  destination: postgres
materialization:
  type: table
  strategy: delete+insert
  incremental_key: txn_ts
columns:
  - name: txn_id
    type: integer
    primary_key: true
    checks:
      - name: not_null
      - name: unique
  - name: txn_ts
    type: timestamp
```

Why these strategies:

| Table | Strategy | Reason |
|---|---|---|
| customers, accounts | `merge` on the primary key, window on `updated_at` | rows change in place, source tells us when |
| transactions | `delete+insert` on `txn_ts` | rows never change, and re-running a day must not duplicate |

Validate, then do the initial load. The customer and account rows have old `updated_at` values, so the first window must reach far back. Transactions cover 2026-01-01 and 2026-01-02.

```bash
cd ~/lakota-bruin
bruin validate lakota
bruin run lakota --tag landing --start-date 2000-01-01 --end-date "2026-01-02 23:59:59.999999"
```

`--tag landing` runs only the assets that carry the tag `landing` (`commands/run.md`). The assets below carry it. Tags are the course's way of running one layer at a time.

Seeds already ran through ingestr in Module 1, so uv and ingestr are installed. This is the first run that reads from one database and writes to another through ingestr. Record anything unusual: antivirus prompts, Python version messages, time per asset.

Check the landing tables:

```bash
bruin query --connection lakota-pg --query "select 'customers' t, count(*) from landing.core_customers union all select 'accounts', count(*) from landing.core_accounts union all select 'transactions', count(*) from landing.core_transactions"
```

Expected: customers 60, accounts 83, transactions 150.

Look at the destination columns:

```bash
bruin query --connection lakota-pg --query "select column_name, data_type from information_schema.columns where table_schema='landing' and table_name='core_customers' order by ordinal_position"
```

Compare with the source columns. ingestr adds its own load-tracking columns to the destination. The ingestr docs mention a column named `_ingestr_loaded_at`, and other `_ingestr_*` columns may exist. Your seed tables from Module 1 carry the same kind of columns. UNVERIFIED: the full list and their Postgres types. Record them. Everything downstream in this course selects columns by name, because `SELECT *` would carry these along.

### Apply day 2 and load incrementally

```bash
cd "$COURSE/data"
psql "$PGURL_SRC" -f sql/02_source_day2.sql
cd ~/lakota-bruin
bruin run lakota --tag landing --start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999"
```

Expected counts in landing after the run:

| table | landing | source |
|---|---|---|
| customers | 68 | 68 |
| accounts | 93 | 92 |
| transactions | 240 | 240 |

Landing has one more account than the source. The source hard-deleted account 1006. A merge only inserts and updates, and ingestr does not detect rows missing from a bounded window. The deleted account stays in landing forever, still marked as it was last seen.

Check that update propagation worked: some day 2 account rows changed status to CLOSED.

```bash
bruin query --connection lakota-pg --query "select status, count(*) from landing.core_accounts group by 1 order by 1"
```

Day 2 closed three accounts. Compare with the source:

```bash
psql "$PGURL_SRC" -c "select status, count(*) from src_core.accounts group by 1 order by 1"
```

### Re-run the same window

```bash
bruin run lakota --tag landing --start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999"
```

Counts must not change (merge and delete+insert are safe to repeat). If they change, record the numbers.

### Apply day 3

```bash
cd "$COURSE/data" && psql "$PGURL_SRC" -f sql/03_source_day3.sql && cd ~/lakota-bruin
bruin run lakota --tag landing --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

Expected landing counts: customers 73, accounts 99 (source 97), transactions 325.

Commit: `git add lakota && git commit -m "Module 2: landing assets"`.

## 2.4 Experiments (30 minutes, recommended)

These make the model stick. Record outcomes in the validation log.

1. **Append duplicates.** Copy `core_transactions.asset.yml` to a probe asset named `landing.probe_txn_append`, change the strategy to `append`, run it twice for 2026-01-01 to 2026-01-02. Count rows. Then run the real `core_transactions` asset again and confirm it stays at its expected count. Delete the probe asset and its table afterward.
2. **Window too narrow.** Reset the source with `01_source_init.sql`. Load customers with `--start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999"`. Expected: nothing loads, because no customer has `updated_at` on that date. This is why a first load needs a wide window.
3. **Full refresh.** Run `bruin run lakota/assets/landing/core_customers.asset.yml --full-refresh` and observe what is rebuilt. Read `parameters.full_refresh` and `start_date` in `assets/definition-schema.md` first. The Bruin side is settled from the CLI source: `--full-refresh` adds `--full-refresh` to the ingestr call; the interval start becomes the asset's top-level `start_date` (`YYYY-MM-DD`) when it has one and the run's `--start-date` otherwise; the interval end is always the run's end date. UNVERIFIED: how ingestr applies that window during a full refresh. Run it once without an asset `start_date` and with the default dates, then once with `--start-date 2000-01-01`, and compare row counts.
4. **Same database as source and destination.** Add a connection `lakota-self` pointing to `bruin_course` (the warehouse) and create a table `public.selftest` in it. Write an ingestr asset that reads `public.selftest` through `lakota-self` and writes `landing.selftest_copy`. UNVERIFIED whether ingestr handles same-server source and destination without problems. Record the result.
5. **Custom query source.** Replace `source_table` on a probe asset with `query:select customer_id, email, updated_at from src_core.customers where branch_id = 1`. Note the doc requirement that the incremental key must appear in the query's result.

## 2.5 Other sources (read, do not run)

ingestr and Bruin connect to many sources. Read these pages and note what a connection and an asset look like for each:

- CSV file (`ingestion/csv.md`): a `csv` connection with a `path`, and `source_table: sample`.
- HTTP (`ingestion/http.md`), SFTP (`ingestion/sftp.md`), S3 (`ingestion/s3.md`), SQLite (`ingestion/sqlite.md`), MySQL (`ingestion/mysql.md`), Google Sheets (`ingestion/google_sheets.md`).
- Postgres change data capture (`platforms/postgres.md`, section "CDC"): needs `wal_level=logical`, a publication and a replication slot, and the strategy must be `merge`. This course does not run it.

## 2.6 Seed or ingestr?

| Use a seed when | Use ingestr when |
|---|---|
| a small file lives in the repository and changes through pull requests | data lives in another system |
| it is reference data such as branches and products | it is large, changes often, or needs incremental loads |

## Break/fix

Restore after each.

1. In `core_customers.asset.yml`, change `source_connection` to `lakota_src`. Run `bruin validate lakota`, then `bruin run` on that asset.
2. Change `source_table` to `src_core.customer` (singular). Run the asset.
3. Remove the `primary_key: true` line from `core_customers`. Validate and run it with the `merge` strategy.
4. Change `incremental_key` in `core_accounts` to `opened_date`. Reset the source with `01_source_init.sql`, reload day 1 with a wide window, apply day 2, and run the day 2 window. Compare the account counts and statuses with the correct configuration.
5. Run `bruin run lakota --tag landing --start-date 2026-01-05 --end-date 2026-01-04`. What happens?

<details>
<summary>Answers</summary>

1. Unknown connection name. Reading the CLI source, no lint rule checks that an ingestr asset's `source_connection` exists, so `validate` should pass and `run` should fail when the asset starts with a connection-not-found error. UNVERIFIED at runtime. Compare with Module 0 break/fix 1, where a missing default connection on a `pg.sql` asset can be caught earlier by the live query check in non-fast `validate`.
2. ingestr cannot read the table, so the asset fails at run time with an error from the source. `validate` cannot know what tables exist in the source.
3. The docs say `merge` requires primary keys, either from the source metadata or from columns marked `primary_key: true`. The CLI source has a validation rule that fails with "Materialization strategy 'merge' requires the 'primary_key' field to be set on at least one column". UNVERIFIED at runtime: record whether `validate` or `run` fails, and the message.
4. `opened_date` does not change when an account is closed, so the window filter misses status changes. Landing keeps old statuses and the closed accounts do not show as CLOSED. The incremental key must be a column that moves whenever the row changes.
5. The start is after the end. Bruin rejects it before anything runs, with "Start date cannot be after end date. Given start date: ..., end date: ..." (CLI source, `cmd/run.go`). Start equal to end is accepted by Bruin. Whether ingestr accepts a zero-length window is UNVERIFIED, and it matters: a date-only `--end-date` equal to the start date is exactly that case (Module 1).
</details>

## Check questions

1. Where does the date window for an ingestr incremental load come from?
2. Why is `delete+insert` a better fit than `append` for `core_transactions`?
3. A source row is hard-deleted. What happens to the landing table with `merge`? How would you detect it?
4. What must be true of a column used as `incremental_key` for `merge`?
5. Which strategy does ingestr call `replace`, and what Bruin name maps to it?

<details>
<summary>Answers</summary>

1. From the run: `--start-date` and `--end-date` (or interval modifiers when enabled), passed to ingestr as interval bounds. ingestr does not read a watermark from the destination.
2. Re-running a window replaces the rows in it instead of duplicating them. Transactions are immutable, so replacing a day is safe.
3. The row stays. Detect it by comparing keys or counts between source and landing (a reconciliation check, Module 5), or by loading a full key list and anti-joining.
4. It must change whenever the row changes (a reliable `updated_at`), and the source must be able to filter on it.
5. `replace`, configured as `materialization.strategy: create+replace`.
</details>

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| `bruin import database` draft: files created, asset names, columns and metadata present | | |
| ingestr first-run setup (time, downloads, Windows issues) | | |
| Initial load counts (60 / 83 / 150) | | |
| Extra columns ingestr adds (names, types) | | |
| Break/fix 1: does validate catch the bad connection name? | | |
| Day 2 counts (68 / 93 / 240) | | |
| Re-run of the same window stable? | | |
| Day 3 counts (73 / 99 / 325) | | |
| `--tag landing` selected the 3 assets? | | |
| Experiment 3: full refresh result | | |
| Experiment 4: same database | | |
| Break/fix 3 outcome | | |
| Time taken | | |
