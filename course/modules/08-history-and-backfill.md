# Module 8: History tracking and backfill

Estimated time: 3.5 to 4 hours. Written against Bruin v0.11.773. Requires Postgres 17 or later for the SCD2 labs (see Module 0).

## Outcome

You can keep every version of a changing record with SCD2, you know which SCD2 strategy fits which source, you know how SCD2 behaves when records disappear and when someone runs `--full-refresh`, and you can reload a historical range with `bruin backfill`, including interrupting it, failing a partition on purpose, and resuming. Optional: you can load a small Raw Data Vault (hub and satellite) on Postgres.

Docs for this module: `assets/materialization.md` (sections "History tracking (SCD2)", "Data Vault", "Full refresh and full_refresh_restricted"), `commands/backfill.md`, `commands/run.md`, `variables/built-in.md`.

## 8.1 Concepts to read first

Answer these in your notes from the docs before building. Answers are at the end.

1. What three columns does every SCD2 table get, and what is `_valid_until` for a current row?
2. What decides "a change happened" in `scd2_by_column`? In `scd2_by_time`?
3. Which columns must you declare in `columns`, and why?
4. What happens to a record that disappears from the query result?
5. What does `--full-refresh` do to an SCD2 table?
6. Which timestamp types does Postgres accept for the `incremental_key` of `scd2_by_time`?
7. What are the null-handling caveat and the first-run rule?

## 8.2 Build the history assets

Start from a clean state with day 1 loaded and the Module 3 assets built:

```bash
cd ~/lakota-bruin
bash "$COURSE/tools/reset.sh" warehouse
bash "$COURSE/tools/reset.sh" source 1
bruin run lakota --tag landing --start-date 2000-01-01 --end-date "2026-01-02 23:59:59.999999"
bruin run lakota --exclude-tag landing --full-refresh --start-date 2026-01-01 --end-date "2026-01-02 23:59:59.999999"
```

Create the folder:

```bash
mkdir -p lakota/assets/hist
```

### `lakota/assets/hist/customers_hist.sql` (scd2_by_time)

The source system stamps `updated_at` on every change, so `scd2_by_time` is the right fit. Versions get `_valid_from` from `updated_at`.

```sql
/* @bruin
name: hist.customers_hist
type: pg.sql
tags:
  - hist
depends:
  - staging.customers
materialization:
  type: table
  strategy: scd2_by_time
  incremental_key: updated_at
columns:
  - name: customer_id
    type: integer
    primary_key: true
  - name: first_name
    type: varchar
  - name: last_name
    type: varchar
  - name: email
    type: varchar
  - name: branch_id
    type: integer
  - name: status
    type: varchar
  - name: created_at
    type: timestamp
  - name: updated_at
    type: timestamp
@bruin */

SELECT customer_id,
       first_name,
       last_name,
       email,
       branch_id,
       status,
       created_at::timestamp AS created_at,
       updated_at::timestamp AS updated_at
FROM staging.customers
```

The casts matter: the docs say Postgres rejects `TIMESTAMPTZ` for the `incremental_key`, so the query casts it to `timestamp`. The landing column type is whatever ingestr created. If it is already `timestamp`, the cast is harmless. Record the type with (use `bruin query --connection lakota-pg --query "select column_name, data_type from information_schema.columns where table_schema='landing' and table_name='core_customers'"`).

### `lakota/assets/hist/accounts_hist.sql` (scd2_by_column)

Pretend the account source has no trustworthy change timestamp. `scd2_by_column` compares every declared column and stamps `_valid_from` with the processing time. If the source does record when a row changed, `scd2_by_column` also accepts an `incremental_key`: new versions then take `_valid_from` from that column, and a version closed by a change takes `_valid_until` from the new version's key. A version closed because the record left the source still uses `CURRENT_TIMESTAMP` (`assets/materialization.md`, "Use business timestamps instead of processing time"). This lab does not set it.

```sql
/* @bruin
name: hist.accounts_hist
type: pg.sql
tags:
  - hist
depends:
  - landing.core_accounts
materialization:
  type: table
  strategy: scd2_by_column
columns:
  - name: account_id
    type: integer
    primary_key: true
  - name: customer_id
    type: integer
  - name: product_code
    type: varchar
  - name: opened_date
    type: date
  - name: status
    type: varchar
  - name: balance
    type: numeric
  - name: updated_at
    type: timestamp
@bruin */

SELECT account_id,
       customer_id,
       product_code,
       opened_date::date AS opened_date,
       status,
       balance,
       updated_at::timestamp AS updated_at
FROM landing.core_accounts
```

### `lakota/assets/hist/accounts_open_hist.sql` (scd2_by_column, rows disappear)

Same table, but the query returns only open accounts. When an account closes it vanishes from the result, which is how you see the "close records that disappeared" rule.

```sql
/* @bruin
name: hist.accounts_open_hist
type: pg.sql
tags:
  - hist
depends:
  - landing.core_accounts
materialization:
  type: table
  strategy: scd2_by_column
columns:
  - name: account_id
    type: integer
    primary_key: true
  - name: customer_id
    type: integer
  - name: product_code
    type: varchar
  - name: opened_date
    type: date
  - name: status
    type: varchar
  - name: balance
    type: numeric
  - name: updated_at
    type: timestamp
@bruin */

SELECT account_id,
       customer_id,
       product_code,
       opened_date::date AS opened_date,
       status,
       balance,
       updated_at::timestamp AS updated_at
FROM landing.core_accounts
WHERE status = 'OPEN'
```

Validate and render:

```bash
bruin validate lakota
bruin render lakota/assets/hist/customers_hist.sql --start-date 2026-01-01 --end-date "2026-01-02 23:59:59.999999"
bruin render lakota/assets/hist/customers_hist.sql --start-date 2026-01-01 --end-date "2026-01-02 23:59:59.999999" --full-refresh
```

Read both renders. Note the statements for the first run versus an incremental run and how `_valid_from`, `_valid_until` and `_is_current` are computed.

## 8.3 Lab: three days of history

### Day 1: create the tables

The setup commands above already ran `--full-refresh` over everything outside landing, which created the three hist tables. If you added the files after that run, create them now:

```bash
bruin run lakota --tag hist --full-refresh --start-date 2026-01-01 --end-date "2026-01-02 23:59:59.999999"
```

Expected after day 1:

| Table | Rows | Current rows |
|---|---|---|
| hist.customers_hist | 60 | 60 |
| hist.accounts_hist | 83 | 83 |
| hist.accounts_open_hist | 83 | 83 |

Look at the columns:

```bash
bruin query --connection lakota-pg --query "select customer_id, email, updated_at, _valid_from, _valid_until, _is_current from hist.customers_hist order by customer_id limit 5"
```

For `customers_hist`, `_valid_from` should equal `updated_at`. For `accounts_hist`, `_valid_from` should be the time you ran the command.

### Day 2

```bash
cd "$COURSE/data" && psql "$PGURL_SRC" -f sql/02_source_day2.sql && cd ~/lakota-bruin
bruin run lakota --start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999"
```

Expected:

| Table | Rows | Current rows |
|---|---|---|
| hist.customers_hist | 73 | 68 |
| hist.accounts_hist | 96 | 93 |
| hist.accounts_open_hist | 93 | 90 |

Customers 11, 17, 18, 43 and 47 changed their email, so each has two versions. The 8 new customers each have one. Accounts 1005, 1022 and 1034 changed status to CLOSED.

Look at the history of one customer and one closed account:

```bash
bruin query --connection lakota-pg --query "select customer_id, email, updated_at, _valid_from, _valid_until, _is_current from hist.customers_hist where customer_id = 11 order by _valid_from"
bruin query --connection lakota-pg --query "select account_id, status, balance, _valid_from, _valid_until, _is_current from hist.accounts_hist where account_id = 1005 order by _valid_from"
bruin query --connection lakota-pg --query "select account_id, status, _valid_from, _valid_until, _is_current from hist.accounts_open_hist where account_id = 1005"
```

In `accounts_open_hist`, account 1005 has one row, closed because it disappeared. Its `_valid_until` is the run time (`CURRENT_TIMESTAMP`), not a business date. In `accounts_hist` it has two rows, because the CLOSED status is a change, not a disappearance.

Account 1006 was hard-deleted in the source on day 2 (Module 2: the landing merge does not propagate deletes). Query it in `hist.accounts_hist`. Is it still current? Why? Write down the lesson: SCD2 can only close what disappears from the query result, and the landing layer never removes it.

### Day 3

```bash
cd "$COURSE/data" && psql "$PGURL_SRC" -f sql/03_source_day3.sql && cd ~/lakota-bruin
bruin run lakota --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

Expected:

| Table | Rows | Current rows |
|---|---|---|
| hist.customers_hist | 82 | 73 |
| hist.accounts_hist | 104 | 99 |
| hist.accounts_open_hist | 99 | 94 |

### Idempotency check

Run day 3 again with the same window:

```bash
bruin run lakota --tag hist --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

The counts must not change. If `accounts_hist` grows, record it as a finding.

## 8.4 The full-refresh trap

An SCD2 table rebuilt with `--full-refresh` loses its history. Prove it on a copy of the data first, not on a table you care about:

```bash
bruin run lakota/assets/hist/accounts_hist.sql --full-refresh --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin query --connection lakota-pg --query "select count(*), count(*) filter (where _is_current) from hist.accounts_hist"
```

Expected: the table is back to one row per account (99 rows from landing), with the history of 5 changed accounts gone.

Now protect it. Rebuild the history first so you have something to protect (re-run day 1 to day 3 or accept the current state), then add this line to the asset header of `hist.customers_hist` and `hist.accounts_hist` (not to `accounts_open_hist`):

```yaml
full_refresh_restricted: true
```

Two tests:

1. With the table present and the flag set, run `bruin run lakota/assets/hist/customers_hist.sql --full-refresh --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"`. The docs say the table is not dropped, the asset runs with its normal strategy, and a warning is printed. Confirm that history (82 rows) is intact.
2. Drop the table (`psql "$PGURL" -c "drop table hist.accounts_hist"`) and run the same command for `hist.accounts_hist`. A restricted asset keeps its normal strategy. On Postgres the normal SCD2 statement is a `MERGE INTO` the target, and only the full-refresh path creates the table (`pkg/postgres/materialization.go`), so with the table missing the run should fail with a relation-does-not-exist error. UNVERIFIED at runtime: record the exact text. The fix is to create the table once with the restriction removed (or on an environment without it), then restore the flag. This is also why a restricted asset in a new environment needs a one-time bootstrap run.

Production habit: set `full_refresh_restricted: true` for the whole environment in `.bruin.yml` (`environments.<name>.config.full_refresh_restricted: true`) so nobody has to remember the flag per asset. Module 10 covers environments.

## 8.5 Backfill

`bruin backfill` splits a date range into partitions, runs each as an ordinary `bruin run`, and saves state so interrupted or failed work can resume.

Use `mart.daily_txn_summary` (time_interval, date granularity) as the target. It accumulates history and each partition replaces only its own dates, which is the profile the docs recommend.

### Prepare

The transactions in the dataset fall between 2026-01-01 and 2026-01-04. Make sure all three source days are loaded and landing is current, then empty the target while keeping its structure:

```bash
bruin run lakota --tag landing --start-date 2000-01-01 --end-date "2026-01-04 23:59:59.999999"
psql "$PGURL" -c "truncate mart.daily_txn_summary"
```

The docs say to initialize incremental destination tables before backfilling, which the truncate approach satisfies because the table already exists. Full refresh and streaming are not supported by `bruin backfill`.

### Plan, then run

```bash
bruin backfill lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-01 --end-date 2026-01-04 --partition daily --dry-run --output json
bruin backfill lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-01 --end-date 2026-01-04 --partition monthly --dry-run
```

Questions to answer from the output:

- How many partitions does the daily plan have? (`bruin backfill` treats a date-only end value as inclusive, unlike `bruin run`, where a date-only end is midnight at the start of that day. Record the `--dry-run --output json` result and state the rule it shows.)
- What `--start-date` and `--end-date` does each child run receive? (Each end is the next boundary minus one microsecond.)
- How does the monthly plan treat a partial month?
- What parallelism is effective and why?

Then execute:

```bash
bruin backfill lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-01 --end-date 2026-01-04 --partition daily --max-parallel 1
```

`bruin backfill` runs one `bruin run` per partition and passes `--sensor-mode`, `--apply-interval-modifiers` and `--var` through to each child (source-derived, `cmd/backfill.go`). A sensor in the pipeline therefore runs once per partition. Bruin does not check that the partition size fits the asset's granularity: `--partition hourly` on a date-granularity asset should produce 24 children per day that each replace the same date (UNVERIFIED at runtime). Note the backfill ID and the resume command it prints at the start. Check the result:

```bash
bruin query --connection lakota-pg --query "select count(*), sum(txn_count) from mart.daily_txn_summary"
ls logs/backfills/
```

Expected: 16 rows (4 days times 4 transaction types) and 325 transactions in total, matching a `--full-refresh` build of the same asset. Look inside `logs/backfills/<id>/`: `manifest.json`, `partitions/`, `children/`. Check that `git status` does not list the backfill folder (Bruin adds it to `.gitignore`).

### Fail a partition on purpose, then resume

Temporarily wrap the query of `mart.daily_txn_summary` so one partition fails:

```sql
{% if start_date == '2026-01-03' %}
SELECT 1/0 AS txn_date, 'x' AS txn_type, 1 AS txn_count, 1.0 AS total_amount
{% else %}
SELECT txn_ts::date AS txn_date,
       txn_type,
       count(*)     AS txn_count,
       sum(amount)  AS total_amount
FROM landing.core_transactions
WHERE txn_ts::date BETWEEN '{{ start_date }}' AND '{{ end_date }}'
GROUP BY 1, 2
{% endif %}
```

(Keep the asset header unchanged. Drop the `{% if not full_refresh %}` wrapper for this exercise since backfill never full-refreshes.)

```bash
psql "$PGURL" -c "truncate mart.daily_txn_summary"
bruin backfill lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-01 --end-date 2026-01-04 --partition daily --max-parallel 1
echo "exit code: $?"
```

Expected with the default `--on-failure stop`: partitions for Jan 1 and Jan 2 succeed, Jan 3 fails, Jan 4 never starts, and the exit code is nonzero. Inspect `logs/backfills/<id>/children/` for the error. Check the table: only Jan 1 and Jan 2 are loaded.

Fix the asset (remove the `{% if %}` wrapper), then resume:

```bash
bruin backfill --continue <backfill-id> --dry-run --output json
bruin backfill --continue <backfill-id>
```

Expected: successful partitions are skipped by default, Jan 3 and Jan 4 run, and the table matches the earlier result (16 rows, 325 transactions). Pipeline files are read again on resume, which is why fixing the asset works.

Repeat once more with `--on-failure continue` and `--rerun failed` to see the other policies. Then try `--max-parallel 2` on a 4-partition plan and read the printed effective parallelism. The flag help says connection limits may reduce it, and the pipeline's `max_concurrent_assets` setting and connection-level `max_concurrent_assets` (Module 10) are the ones to look at (source-derived, UNVERIFIED which applies).

### What backfill is not for

Think through the SCD2 assets in this module:

- A backfill over `hist.accounts_hist` would stamp each partition with the current time, because without an `incremental_key` `scd2_by_column` uses `CURRENT_TIMESTAMP` and compares the current snapshot rather than a date window. History cannot be reconstructed from a snapshot source this way. With an `incremental_key` that holds a real business timestamp the versions carry the source's own times, but the query still has to return the historical rows.
- `scd2_by_time` can only replay history when your query returns the historical versions with their own timestamps.

Write one paragraph in your notes: for which of your real tables at the bank would you use a backfill, and for which would you need a different approach (reloading from raw change records)?

## 8.6 Optional: Raw Data Vault on Postgres

The Data Vault strategies exist only for Postgres and DuckDB. Bruin does not calculate hashes, so the query returns them. All three strategies create their own table and run in one transaction, so no `--full-refresh` is needed for the first run.

### `lakota/assets/hist/hub_customer.sql`

```sql
/* @bruin
name: hist.hub_customer
type: pg.sql
tags:
  - vault
depends:
  - staging.customers
materialization:
  type: table
  strategy: datavault_hub
columns:
  - name: customer_hk
    type: varchar
    meta:
      datavault_role: hash_key
  - name: customer_bk
    type: varchar
    meta:
      datavault_role: business_key
  - name: load_dts
    type: timestamp
    meta:
      datavault_role: load_datetime
  - name: record_source
    type: varchar
    meta:
      datavault_role: record_source
@bruin */

SELECT md5(upper(trim(customer_id::text)))  AS customer_hk,
       customer_id::text                    AS customer_bk,
       created_at::timestamp                AS load_dts,
       'lakota.core'                        AS record_source
FROM staging.customers
```

### `lakota/assets/hist/sat_customer_details.sql`

```sql
/* @bruin
name: hist.sat_customer_details
type: pg.sql
tags:
  - vault
depends:
  - staging.customers
materialization:
  type: table
  strategy: datavault_satellite
columns:
  - name: customer_hk
    type: varchar
    meta:
      datavault_role: parent_hash_key
  - name: hashdiff
    type: varchar
    meta:
      datavault_role: hashdiff
  - name: load_dts
    type: timestamp
    meta:
      datavault_role: load_datetime
  - name: record_source
    type: varchar
    meta:
      datavault_role: record_source
  - name: full_name
    type: varchar
  - name: email
    type: varchar
  - name: branch_id
    type: integer
  - name: status
    type: varchar
@bruin */

SELECT md5(upper(trim(customer_id::text))) AS customer_hk,
       md5(concat_ws('||', full_name, email, branch_id::text, status)) AS hashdiff,
       updated_at::timestamp                AS load_dts,
       'lakota.core'                        AS record_source,
       full_name,
       email,
       branch_id,
       status
FROM staging.customers
```

Run on each day and compare with the SCD2 tables:

| After day | hub_customer | sat_customer_details |
|---|---|---|
| 1 | 60 | 60 |
| 2 | 68 | 73 |
| 3 | 73 | 82 |

Questions:

1. The docs say a satellite is keyed on parent hash key plus load datetime by default. What happens if two versions of a customer share the same `load_dts`? Try it by temporarily using `created_at` as `load_dts` in the satellite and rerunning day 2 or day 3. Record what you see.
2. Which column names did the suffix fallback pick up as roles in the hub? Why did the docs warn about descriptive columns ending in `_bk` or `_hk`?
3. Build `hub_account` and `link_customer_account` yourself (link hash key from the two business keys). Expected link rows after day 3: 99.

## Break/fix

1. Remove the `primary_key: true` from `hist.customers_hist` and validate.
2. Remove the `incremental_key` from `scd2_by_time` and validate.
3. Declare a column named `_is_current` in an SCD2 asset and validate.
4. Leave a column out of `columns` that your query selects. Change that column in the source and rerun. Is the change detected?
5. Run `bruin backfill ... --rerun failed` without `--continue`.
6. Run a dry-run backfill with `--partition hourly` against `mart.daily_txn_summary` (date granularity). Read the docs on which granularity hourly partitions need, and record whether Bruin warns. The source builds partitions from the flag only, so expect no warning and 96 children for 4 days.
7. Change a date range while resuming a backfill with `--continue`.
8. Start a backfill and press Ctrl+C mid-run. What state do the partitions have? Resume it.

<details>
<summary>Answers</summary>

1. `scd2_by_time` and `scd2_by_column` both require a `primary_key`. Validation fails.
2. `scd2_by_time` requires an `incremental_key`. Validation fails.
3. `_valid_from`, `_valid_until` and `_is_current` are reserved. Using them in `columns` is a validation error.
4. Per the docs only declared columns are compared and carried. The undeclared column's change is not detected. Record what you saw.
5. The docs say `--rerun` is accepted only together with `--continue`. Expect an error.
6. The docs say hourly partitions need timestamp granularity, since date granularity replaces a whole date. Source reading says Bruin does not warn (UNVERIFIED at runtime). Record what the dry run prints.
7. Resume reuses the saved range and inputs. Create a new backfill to change them. Only execution controls can change on resume.
8. Queued and interrupted partitions stay resumable. Cancellation propagates to active children.
</details>

## Check questions

1. When do you choose `scd2_by_time` over `scd2_by_column`?
2. A customer is deleted in the source and your SCD2 query selects from a landing table loaded by merge. What happens to the history row? What would fix it?
3. What do you use to stop a colleague from wiping SCD2 history with `--full-refresh`, and where can you set it for a whole environment?
4. What is the default `_valid_until` for a current row on Postgres?
5. A backfill partition succeeds, but the process crashes before Bruin records it. What happens on resume, and what does that require of your assets?
6. Which materializations suit backfills and which do not?
7. How many partitions does `--start-date 2026-01-01 --end-date 2026-01-04 --partition daily` create, and how would the answer change with timestamp end values?

<details>
<summary>Answers</summary>

1. When the source records when each row changed (an `updated_at`). Use `scd2_by_column` when it does not.
2. The history row stays current, because the key never disappears from the query. The query must stop returning it: filter on a deletion flag, or compare against the list of keys that exist in the source.
3. `full_refresh_restricted: true` on the asset, or `environments.<name>.config.full_refresh_restricted: true` in `.bruin.yml`.
4. `9999-12-31` at midnight on PostgreSQL.
5. The partition may run again. Use idempotent materializations (`time_interval`, `delete+insert`, `merge`), not `append`.
6. `time_interval`, `delete+insert` and `merge` are suitable because a partition can run again without duplicating rows. `append` duplicates on a rerun. `create+replace` replaces the whole table on every partition, so only the last partition survives.
7. Four partitions. Timestamp end values are exclusive, so `--end-date 2026-01-04T00:00:00Z` would create 3.
</details>

## Concept answers (8.1)

1. `_valid_from`, `_valid_until`, `_is_current`. A current row has `_valid_until` of `9999-12-31`.
2. By column: any declared non-key column differs from the current version. By time: the `incremental_key` is newer than the current version.
3. Every column of the query, because only declared columns are compared and carried into new versions.
4. Its current version is closed, using `CURRENT_TIMESTAMP`.
5. It rebuilds the table from the current snapshot and discards history.
6. `DATE` or `TIMESTAMP`. `TIMESTAMPTZ` is rejected on Postgres and Redshift.
7. A change from or to `NULL` is not detected on Postgres. The first run needs `--full-refresh` to create the table.

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| 8.2 landing column types for updated_at | | |
| 8.3 day 1 counts (60/83/83) | | |
| 8.3 day 2 counts (73,68 / 96,93 / 93,90) | | |
| 8.3 day 3 counts (82,73 / 104,99 / 99,94) | | |
| 8.3 account 1006 still current in accounts_hist | | |
| 8.3 idempotent rerun of day 3 | | |
| 8.4 full refresh drops history | | |
| 8.4 restricted asset: first run with no table (exact error text) | | |
| 8.5 hourly partitions on a date asset: warning or not, child count | | |
| 8.5 effective parallelism with `--max-parallel 2` | | |
| 8.4 restricted asset: warning and history kept | | |
| 8.5 backfill dry run partitions and child dates | | |
| 8.5 backfill result 16 rows / 325 txns | | |
| 8.5 failed partition and exit code | | |
| 8.5 resume skips successes | | |
| 8.5 Ctrl+C behavior (Git Bash on Windows) | | |
| 8.6 hub/satellite counts | | |
| 8.6 satellite with colliding load_dts | | |
| Time taken | | |
