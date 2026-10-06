# Module 3: SQL assets and materialization strategies

Estimated time: 4 to 4.5 hours. Written against Bruin v0.11.773.

## Outcome

You can pick a materialization strategy for a SQL asset and justify it, you know what each one requires, what it does to existing rows and to source deletes, whether it is safe to re-run, and how the first run differs from later runs. You read the rendered SQL for each strategy.

Docs for this module: `assets/materialization.md` (read all of it, it is the center of this module), `assets/sql.md`, `assets/templating/templating.md`, `variables/built-in.md`, `commands/render.md`, `commands/run.md`.

## 3.1 The strategies

Fill in this table from `assets/materialization.md` before you build anything. Answers are at the end of the module.

| Strategy | Required keys | What a run does to existing rows | Source deletes propagate? | Safe to re-run the same window? | First run needs `--full-refresh`? |
|---|---|---|---|---|---|
| `create+replace` | | | | | |
| `truncate+insert` | | | | | |
| `ddl` | | | | | |
| `append` | | | | | |
| `delete+insert` | | | | | |
| `merge` | | | | | |
| `time_interval` | | | | | |
| `scd2_by_column` | | | | | |
| `scd2_by_time` | | | | | |
| `datavault_hub / link / satellite` | | | | | |

Two rules from the docs shape every lab below:

1. **Incremental strategies write into an existing table.** For a new SQL asset, do the first run with `--full-refresh` so Bruin creates the table with `create+replace`. Later runs use the real strategy.
2. **Bruin does not filter your query.** For `append`, `delete+insert`, `merge` and `time_interval`, you write the date filter in the query with the built-in variables. Bruin only manages how the result lands in the table. The docs show the pattern for full refreshes: wrap the filter in `{% if not full_refresh %} ... {% endif %}` so a full refresh loads everything.

Postgres notes from the docs: `partition_by` and `cluster_by` are ignored on PostgreSQL. `merge`, `time_interval`, `scd2_*` and Data Vault are all supported. `time_interval` runs delete and insert in one transaction. `incremental_key` cannot be combined with `merge` in a SQL asset.

## 3.2 Build the assets

Starting point: Module 2 finished, landing tables loaded (any day). The lab begins with a reset so you can watch the strategies day by day.

Create folders and files in `lakota-bruin`:

```bash
mkdir -p lakota/assets/staging lakota/assets/mart lakota/assets/ctl
```

The landing assets already carry the tag `landing`. The new assets carry `staging`, `mart` or `ctl`.

### `lakota/assets/staging/customers.sql` (create+replace)

```sql
/* @bruin
name: staging.customers
type: pg.sql
tags:
  - staging
depends:
  - landing.core_customers
materialization:
  type: table
  strategy: create+replace
columns:
  - name: customer_id
    type: integer
    primary_key: true
    checks:
      - name: not_null
      - name: unique
@bruin */

SELECT customer_id,
       first_name || ' ' || last_name AS full_name,
       lower(email)                   AS email,
       branch_id,
       status,
       created_at,
       updated_at
FROM landing.core_customers
```

### `lakota/assets/staging/branch_customer_counts.sql` (truncate+insert)

```sql
/* @bruin
name: staging.branch_customer_counts
type: pg.sql
tags:
  - staging
depends:
  - ref.branches
  - staging.customers
materialization:
  type: table
  strategy: truncate+insert
@bruin */

SELECT b.branch_id,
       b.branch_name,
       count(c.customer_id) AS customers
FROM ref.branches b
LEFT JOIN staging.customers c ON c.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name
```

### `lakota/assets/staging/accounts_current.sql` (merge)

```sql
/* @bruin
name: staging.accounts_current
type: pg.sql
tags:
  - staging
depends:
  - landing.core_accounts
materialization:
  type: table
  strategy: merge
columns:
  - name: account_id
    type: integer
    primary_key: true
  - name: customer_id
    type: integer
  - name: product_code
    type: string
  - name: status
    type: string
    update_on_merge: true
  - name: balance
    type: numeric
    update_on_merge: true
  - name: updated_at
    type: timestamp
    update_on_merge: true
@bruin */

SELECT account_id, customer_id, product_code, status, balance, updated_at
FROM landing.core_accounts
{% if not full_refresh %}
WHERE updated_at >= '{{ start_datetime }}'
  AND updated_at <= '{{ end_datetime }}'
{% endif %}
```

### `lakota/assets/staging/txn_log.sql` (append)

```sql
/* @bruin
name: staging.txn_log
type: pg.sql
tags:
  - staging
depends:
  - landing.core_transactions
materialization:
  type: table
  strategy: append
@bruin */

SELECT txn_id, account_id, txn_ts, amount, txn_type, channel
FROM landing.core_transactions
{% if not full_refresh %}
WHERE txn_ts >= '{{ start_datetime }}'
  AND txn_ts <= '{{ end_datetime }}'
{% endif %}
```

### `lakota/assets/mart/daily_txn_summary.sql` (time_interval)

```sql
/* @bruin
name: mart.daily_txn_summary
type: pg.sql
tags:
  - mart
depends:
  - landing.core_transactions
materialization:
  type: table
  strategy: time_interval
  incremental_key: txn_date
  time_granularity: date
columns:
  - name: txn_date
    type: date
  - name: txn_type
    type: string
  - name: txn_count
    type: integer
  - name: total_amount
    type: numeric
@bruin */

SELECT txn_ts::date AS txn_date,
       txn_type,
       count(*)     AS txn_count,
       sum(amount)  AS total_amount
FROM landing.core_transactions
{% if not full_refresh %}
WHERE txn_ts::date BETWEEN '{{ start_date }}' AND '{{ end_date }}'
{% endif %}
GROUP BY 1, 2
```

### `lakota/assets/mart/channel_daily.sql` (delete+insert)

```sql
/* @bruin
name: mart.channel_daily
type: pg.sql
tags:
  - mart
depends:
  - landing.core_transactions
materialization:
  type: table
  strategy: delete+insert
  incremental_key: txn_date
columns:
  - name: txn_date
    type: date
  - name: channel
    type: string
  - name: txn_count
    type: integer
@bruin */

SELECT txn_ts::date AS txn_date,
       channel,
       count(*)     AS txn_count
FROM landing.core_transactions
{% if not full_refresh %}
WHERE txn_ts::date BETWEEN '{{ start_date }}' AND '{{ end_date }}'
{% endif %}
GROUP BY 1, 2
```

### `lakota/assets/ctl/run_audit.sql` (ddl)

A `ddl` asset has no query. It creates an empty table from `columns`, once, and never drops it.

```sql
/* @bruin
name: ctl.run_audit
type: pg.sql
tags:
  - ctl
materialization:
  type: table
  strategy: ddl
columns:
  - name: run_id
    type: VARCHAR
    primary_key: true
  - name: asset_name
    type: VARCHAR
  - name: rows_loaded
    type: INTEGER
  - name: finished_at
    type: TIMESTAMP
@bruin */
```

Validate:

```bash
bruin validate lakota
```

## 3.3 Read the SQL before you run it

```bash
bruin render lakota/assets/staging/accounts_current.sql --start-date 2026-01-03 --end-date 2026-01-03
bruin render lakota/assets/staging/accounts_current.sql --start-date 2026-01-03 --end-date 2026-01-03 --full-refresh
bruin render lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-03 --end-date 2026-01-03
bruin render lakota/assets/mart/channel_daily.sql --start-date 2026-01-03 --end-date 2026-01-03
bruin render lakota/assets/staging/txn_log.sql --start-date 2026-01-03 --end-date 2026-01-03
bruin render lakota/assets/ctl/run_audit.sql
```

For each one, write down in your notes:

- the statements Bruin generates (staging table, delete, insert, merge),
- where your own filter went,
- what changes with `--full-refresh`.

This is the habit that makes you fast later: you can read what Bruin will do before it does it.

## 3.4 Lab: three days, strategy by strategy

### Day 1: reset and first load

```bash
cd ~/lakota-bruin
bash "$COURSE/tools/reset.sh" warehouse
bash "$COURSE/tools/reset.sh" source 1

bruin run lakota --tag landing --start-date 2000-01-01 --end-date 2026-01-02
bruin run lakota --exclude-tag landing --full-refresh --start-date 2026-01-01 --end-date 2026-01-02
```

The first command loads landing (wide window, as in Module 2). The second builds everything else with `--full-refresh`, which creates each table with `create+replace`.

Expected state:

| Table | Rows |
|---|---|
| staging.customers | 60 |
| staging.branch_customer_counts | 8 (customers column sums to 60) |
| staging.accounts_current | 83 |
| staging.txn_log | 150 |
| mart.daily_txn_summary | 8 (4 transaction types for each of 2 days) |
| mart.channel_daily | 10 (5 channels for each of 2 days) |
| ctl.run_audit | 0 |

Check with:

```bash
bruin query --connection lakota-pg --query "select 'customers' t, count(*) from staging.customers union all select 'branch_counts', count(*) from staging.branch_customer_counts union all select 'accounts_current', count(*) from staging.accounts_current union all select 'txn_log', count(*) from staging.txn_log union all select 'daily_txn_summary', count(*) from mart.daily_txn_summary union all select 'channel_daily', count(*) from mart.channel_daily union all select 'run_audit', count(*) from ctl.run_audit"
```

### Day 2: incremental run

```bash
cd "$COURSE/data" && psql "$PGURL_SRC" -f sql/02_source_day2.sql && cd ~/lakota-bruin
bruin run lakota --start-date 2026-01-03 --end-date 2026-01-03
```

Expected:

| Table | Rows |
|---|---|
| staging.customers | 68 |
| staging.branch_customer_counts | 8 (sums to 68) |
| staging.accounts_current | 93 (one more than the source, the hard-deleted account stays) |
| staging.txn_log | 240 |
| mart.daily_txn_summary | 12 |
| mart.channel_daily | 15 |

Look at what happened to a merged row. Pick a closed account:

```bash
bruin query --connection lakota-pg --query "select account_id, status, updated_at from staging.accounts_current where status = 'CLOSED' order by updated_at limit 5"
```

### Re-run the same window

```bash
bruin run lakota --start-date 2026-01-03 --end-date 2026-01-03
```

Compare row counts with the table above. Only one asset should have changed: `staging.txn_log` (append) now has 330 rows. Every other asset is stable. That is the practical meaning of "safe to re-run".

Repair the duplicate:

```bash
bruin run lakota/assets/staging/txn_log.sql --full-refresh --start-date 2026-01-03 --end-date 2026-01-03
```

`txn_log` returns to 240. Compare the loaded rows with the source: `landing.core_transactions` has 240.

### Day 3

```bash
cd "$COURSE/data" && psql "$PGURL_SRC" -f sql/03_source_day3.sql && cd ~/lakota-bruin
bruin run lakota --start-date 2026-01-04 --end-date 2026-01-04
```

Expected: customers 73, accounts_current 99, txn_log 325, daily_txn_summary 16, channel_daily 20. Branch counts: 14, 15, 6, 6, 7, 7, 7, 11 for branches 1 to 8.

Commit: `git add lakota && git commit -m "Module 3: materialization strategies"`.

## 3.5 Experiment: `time_interval` versus `delete+insert`

Both replace a slice. They differ when the new result has no rows for part of the slice.

```bash
psql "$PGURL" -c "delete from landing.core_transactions where txn_ts::date = '2026-01-03'"
bruin run lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-03 --end-date 2026-01-03
bruin run lakota/assets/mart/channel_daily.sql    --start-date 2026-01-03 --end-date 2026-01-03
bruin query --connection lakota-pg --query "select txn_date, count(*) from mart.daily_txn_summary group by 1 order by 1" 
bruin query --connection lakota-pg --query "select txn_date, count(*) from mart.channel_daily group by 1 order by 1"
```

By the docs, `time_interval` deletes the whole window and inserts whatever the query returns, so the 2026-01-03 rows in `daily_txn_summary` disappear. `delete+insert` only deletes the key values present in the new result. With no rows returned, nothing is deleted and the stale 2026-01-03 rows in `channel_daily` remain. Confirm that on your machine, then restore the day with a landing reload:

```bash
bruin run lakota --tag landing --start-date 2026-01-03 --end-date 2026-01-03
```

## 3.6 `full_refresh_restricted`

Add `full_refresh_restricted: true` to `staging.accounts_current` (a top-level key in the definition block, next to `materialization`). Run:

```bash
bruin run lakota/assets/staging/accounts_current.sql --full-refresh --start-date 2026-01-04 --end-date 2026-01-04
```

The docs say the table is not dropped, the normal strategy runs, and Bruin prints a warning. Confirm. This is the protection you will put on history tables in Module 8. Keep the flag on this asset.

## 3.7 The strategies you read but did not run yet

- `scd2_by_column`, `scd2_by_time`: Module 8.
- `datavault_hub`, `datavault_link`, `datavault_satellite`: supported on PostgreSQL and DuckDB only. Read the docs section "Data Vault". They are covered by an optional exercise in Module 8.
- `incremental_predicate` on `merge`: documented for PostgreSQL. It limits which destination rows a merge considers. Read the warning about late-arriving rows and duplicates.

## Break/fix

Restore after each.

1. Remove the `primary_key: true` line from `staging.accounts_current`. Run `bruin validate lakota`, then the asset.
2. Add `incremental_key: updated_at` to the `merge` asset's `materialization`. Validate.
3. Remove `time_granularity` from `mart.daily_txn_summary`. Validate.
4. Remove the `{% if not full_refresh %}` wrapper from `mart.daily_txn_summary` (keep the plain `WHERE` filter). Run `bruin run lakota/assets/mart/daily_txn_summary.sql --full-refresh --start-date 2026-01-04 --end-date 2026-01-04`, then query the table. What is in it?
5. Run the Day 2 incremental command on a fresh warehouse without ever doing the `--full-refresh` build (drop the `staging` and `mart` schemas, then run `bruin run lakota --start-date 2026-01-03 --end-date 2026-01-03`).
6. In `mart.channel_daily`, change `incremental_key` to `channel`. Run it for the same window twice. What do you see?

<details>
<summary>Answers</summary>

1. The docs state `merge` requires a `primary_key` column. Validation reports the missing key (UNVERIFIED wording). `bruin validate` checks that the configuration is complete.
2. The docs say `incremental_key` cannot be combined with `merge`. Setting it with any other explicit strategy is a validation error.
3. `time_interval` requires `time_granularity` (`date` or `timestamp`).
4. After a full refresh the table holds only the 2026-01-04 rows, because the filter still applies to the full-refresh run. Full refresh recreates the table from "the full query result", and your query was not full. This is the mistake the `full_refresh` variable pattern prevents.
5. The incremental strategies fail because the target tables do not exist (the docs: incremental strategies write into an existing table and most platforms do not create it). UNVERIFIED: the exact PostgreSQL error text. Record it.
6. `delete+insert` deletes rows whose key value appears in the new result and the key is now a channel name. The window is no longer a date, so each run deletes every row of each channel present and inserts only the day's rows, which wipes history for those channels. The key must match the slice you intend to replace.
</details>

## Table answers (3.1)

| Strategy | Required keys | Existing rows | Source deletes propagate? | Safe to re-run? | First run needs `--full-refresh`? |
|---|---|---|---|---|---|
| `create+replace` | none | table rebuilt | yes (full rebuild) | yes | no |
| `truncate+insert` | none | emptied, then reinserted | yes (full rebuild) | yes | yes, table must exist |
| `ddl` | `columns` | untouched, table never recreated | n/a | yes | no (creates if missing) |
| `append` | none | never touched | no | no, duplicates | yes |
| `delete+insert` | `incremental_key` | rows with matching key values replaced | only for key values present in the result | yes | yes |
| `merge` | `primary_key` columns | matched rows updated per `update_on_merge`/`merge_sql` | no | yes | yes |
| `time_interval` | `incremental_key`, `time_granularity` | rows in the window replaced | yes, within the window | yes | yes |
| `scd2_by_column` | `primary_key` | closes old version, adds new version | closes versions that left the source | yes for the same snapshot | yes |
| `scd2_by_time` | `primary_key`, `incremental_key` (date or timestamp) | same, driven by the key moving forward | closes versions that left the source | yes | yes |
| Data Vault | column roles | inserts new keys / changed rows | no | yes | n/a (creates target) |

## Check questions

1. Why does the first run of an incremental SQL asset use `--full-refresh`?
2. A query for a `time_interval` asset has no date filter. What happens on a daily run?
3. Which strategies remove a row from the target when the source row disappears?
4. What is the difference between `create+replace` and `truncate+insert` when other users hold grants on the table?
5. What does `full_refresh_restricted: true` do, and which tables need it?
6. What does `incremental_predicate` change, and what is the risk?

<details>
<summary>Answers</summary>

1. The target table must exist before an incremental strategy can write to it, and most platforms do not create it. A full refresh uses `create+replace`.
2. Bruin deletes the window and inserts the whole query result, which includes rows outside the window. Rows outside the window are duplicated next to the existing ones.
3. `create+replace`, `truncate+insert` (full rebuilds), `time_interval` within the window, `delete+insert` only when other rows with the same key value are present in the new result, and SCD2 (which closes the version instead of deleting it). `merge` and `append` never delete.
4. `create+replace` recreates the table and can reset grants. `truncate+insert` keeps the table object, its permissions and indexes.
5. It keeps the table from being dropped during a full refresh. It runs the normal strategy and prints a warning. History tables (SCD2) and tables that are slow to rebuild need it.
6. It adds a condition to the match step of a merge so fewer target rows are scanned. If a row that should match falls outside the predicate window, the key is inserted again as a duplicate.
</details>

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| validate (any warnings on `ddl` asset with no query) | | |
| Day 1 counts match | | |
| Day 2 counts match | | |
| Re-run: only `txn_log` changed? | | |
| `--exclude-tag landing --full-refresh` ran seeds and SQL assets in the right order? | | |
| Day 3 counts match | | |
| 3.5 time_interval vs delete+insert result | | |
| 3.6 restricted warning text | | |
| Break/fix 1 and 5 error messages | | |
| `render` output understandable? | | |
| Time taken | | |
