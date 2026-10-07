# Module 5: Data quality and unit tests

Estimated time: 3.5 to 4 hours. Written against Bruin v0.11.773.

## Outcome

You attach built-in and custom quality checks to assets, control whether a failure blocks downstream work, run checks on their own, reconcile counts between layers, and pin SQL logic with unit tests that run against mock rows.

Docs for this module: `quality/overview.md`, `quality/available_checks.md`, `quality/custom.md`, `quality/unit-tests.md`, `commands/unit-test.md`, `assets/columns.md`.

## 5.1 Concepts

- Checks run after the asset's main step. They are part of the asset definition.
- A check has `blocking`, default `true`. A failed blocking check marks the asset failed and stops downstream assets. With `blocking: false` downstream assets continue, but the failure is still a failure of the run: reading the CLI source (`cmd/run.go`), any task result with an error, blocking or not, makes `bruin run` exit with code 1. A scheduler or CI job wrapped around the run will see a failed run. UNVERIFIED at runtime: confirm the exit code in 5.3 with `echo $?`.
- Run checks alone with `bruin run --only checks <path>`. Run one check with `--single-check <id>`, where `<id>` is the check's identifier hash, not the label printed in the run output (see 5.2).
- Retries resolve through the chain check, then asset, then pipeline (`quality/overview.md`). A local `bruin run` does not appear to act on retries (Module 4, 4.5), so treat them as settings for Cloud or Airflow until you have seen otherwise.
- Quality checks validate real data after it is produced. Unit tests validate SQL logic before it runs, against rows you supply, and write nothing to the database. Use both.

Built-in checks (`quality/available_checks.md`): `accepted_values`, `negative`, `non_negative`, `not_null`, `pattern`, `positive`, `relationships`, `unique`, `min`, `max`.

Custom checks (`custom_checks:`): a SQL query plus an expectation. `value` is the expected integer result (default 0 when omitted), or use `count` for the number of rows the query must return. Fields: `name`, `description`, `query`, `value`, `count`, `blocking`, `retries`.

Two things to know before you start:

- `relationships` needs `foreign_key` metadata on the column and does not create a dependency. Add the referenced asset to `depends` yourself.
- `pattern` uses POSIX regular expressions on most platforms, which includes Postgres.

## 5.2 Lab: add built-in checks

Start from the Module 3 state at day 3. Edit the assets as shown. Only the changed parts are listed.

### `staging.customers`

Add `ref.branches` to `depends`, and replace `columns` with:

```yaml
depends:
  - landing.core_customers
  - ref.branches
columns:
  - name: customer_id
    type: integer
    primary_key: true
    checks:
      - name: not_null
      - name: unique
  - name: email
    type: string
    checks:
      - name: not_null
      - name: pattern
        value: '^[a-z0-9._-]+@example\.test$'
  - name: status
    type: string
    checks:
      - name: accepted_values
        value: ["ACTIVE"]
  - name: branch_id
    type: integer
    foreign_key:
      table: ref.branches
      column: branch_id
    checks:
      - name: not_null
      - name: relationships
```

### `staging.accounts_current`

Add `ref.products` and `staging.customers` to `depends`, and extend the column definitions (keep `primary_key` and `update_on_merge` as they are):

```yaml
depends:
  - landing.core_accounts
  - ref.products
  - staging.customers
columns:
  - name: account_id
    type: integer
    primary_key: true
    checks:
      - name: not_null
      - name: unique
  - name: customer_id
    type: integer
    foreign_key:
      table: staging.customers
      column: customer_id
    checks:
      - name: not_null
      - name: relationships
  - name: product_code
    type: string
    foreign_key:
      table: ref.products
      column: product_code
    checks:
      - name: relationships
  - name: status
    type: string
    update_on_merge: true
    checks:
      - name: accepted_values
        value: ["OPEN", "CLOSED"]
  - name: balance
    type: numeric
    update_on_merge: true
    checks:
      - name: min
        value: 0
  - name: updated_at
    type: timestamp
    update_on_merge: true
```

### `staging.txn_log`

Add `staging.accounts_current` to `depends` and add:

```yaml
columns:
  - name: txn_id
    type: integer
    checks:
      - name: not_null
      - name: unique
  - name: account_id
    type: integer
    foreign_key:
      table: staging.accounts_current
      column: account_id
    checks:
      - name: relationships
  - name: txn_type
    type: string
    checks:
      - name: accepted_values
        value: ["DEPOSIT", "WITHDRAWAL", "PAYMENT", "FEE"]
  - name: channel
    type: string
    checks:
      - name: accepted_values
        value: ["BRANCH", "ATM", "ONLINE", "MOBILE", "ACH"]
```

Run only the checks. The tables already hold day 3 data.

```bash
cd ~/lakota-bruin
bruin validate lakota
bruin run lakota --only checks --exclude-tag landing --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

All checks should pass. Read the output: checks are labelled in the run log as `asset:column:check` (for example `staging.customers:customer_id:unique`). That label is for reading. `--single-check` does not accept it.

`--single-check` takes the check's `id`, a 64-character SHA-256 hex string. In the CLI source (`pkg/pipeline/yaml.go`), a custom check's id is the hash of `<asset name>-<check name>`, and column checks carry a hash id as well. Bruin matches `--single-check` against that id, within one asset, and the run must name exactly one asset. You can read the ids from the parsed asset:

```bash
bruin internal parse-asset lakota/assets/staging/customers.sql
```

Look for the `id` fields under the column checks (and custom checks) in the JSON. `bruin internal` commands are not covered by the public docs beyond a mention in the Airflow page, so treat the output shape as UNVERIFIED and record it. Then run one check and read its output:

```bash
bruin run lakota/assets/staging/customers.sql --single-check <id from the JSON> --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

A passing check prints the check and the query that ran. A failing check prints the error, the result against the expectation, and the query, and exits with code 1 (code 2 if the failure is not a check failure). This is the fastest way to read the SQL behind any built-in check. UNVERIFIED at runtime.

## 5.3 Lab: custom checks and reconciliation

Add to `staging.accounts_current`:

```yaml
custom_checks:
  - name: every landing account is present in the staging table
    description: Compares landing and staging after a load. A mismatch means a window was missed.
    query: |
      SELECT count(*)
      FROM landing.core_accounts l
      WHERE NOT EXISTS (SELECT 1 FROM staging.accounts_current s WHERE s.account_id = l.account_id)
    value: 0
```

Add to `mart.daily_txn_summary`:

```yaml
custom_checks:
  - name: summary transaction count equals landing transaction count
    query: |
      SELECT (SELECT coalesce(sum(txn_count), 0) FROM mart.daily_txn_summary)
           - (SELECT count(*) FROM landing.core_transactions)
    value: 0
  - name: at least one summary row exists
    query: SELECT count(*) FROM mart.daily_txn_summary
    count: 1
    blocking: false
```

The first custom check is a reconciliation. It fails when a daily window was missed or loaded twice, which is exactly the failure that a daily incremental design can hide.

The second one uses `count`. By the docs, Bruin wraps the query as `SELECT count(*) FROM (<query>)` and compares it to the given count. Here the query returns one row, so the expectation is 1. Check what happens if you change `count` to 2.

Run:

```bash
bruin run lakota --only checks --exclude-tag landing --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

### Make a check fail on purpose

```bash
psql "$PGURL" -c "update staging.txn_log set account_id = 999999 where txn_id = 1"
bruin run lakota/assets/staging/txn_log.sql --only checks --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

The `relationships` check should fail (one child row with a missing parent). Because `blocking` defaults to `true`, a full run would stop everything downstream of `staging.txn_log`. Prove it:

```bash
bruin run lakota --exclude-tag landing --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

Check which assets ran. Then set `blocking: false` on the `relationships` check (under the check entry, as a sibling of `name`) and run again. The asset should report the failure but downstream assets should now run. Check the exit code with `echo $?` right after the run: the CLI source says it is 1 even though nothing downstream was held back. Record it. Repair the data afterward:

```bash
bruin run lakota/assets/staging/txn_log.sql --full-refresh --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

Decide when each is right. Blocking suits checks whose failure makes downstream data wrong (keys, reconciliations). Non-blocking suits slow or advisory checks.

### Retries

Set `retries: 2` on one custom check that fails (use the temporary `txn_log` corruption above) and count how many times its query runs, using `--verbose` if the normal output does not show attempts. The docs describe `retries` as retrying a failed check. Reading the CLI source, a local run does not retry, so expect one execution. UNVERIFIED at runtime. Retries suit checks against eventually consistent inputs in an orchestrator that implements them. They do not suit deterministic failures.

## 5.4 Lab: unit tests

Unit tests live in the asset definition under `unit_tests`. Each test lists mock rows for the tables the query reads and the expected output. Nothing is written to the database. The docs list PostgreSQL among verified platforms.

Add to `staging.customers`:

```yaml
unit_tests:
  - name: builds_full_name_and_lowercases_email
    inputs:
      - asset: landing.core_customers
        rows:
          - {customer_id: 1, first_name: Ada, last_name: Lovelace, email: ADA@EXAMPLE.TEST, branch_id: 1, status: ACTIVE}
    expected:
      rows:
        - {customer_id: 1, full_name: Ada Lovelace, email: ada@example.test}
```

List every column the query reads, using `null` where a value does not matter (rows are sparse: omitted columns become NULL, and only columns set by some row exist in the mock). The query reads `created_at` and `updated_at` too, so add them:

```yaml
          - {customer_id: 1, first_name: Ada, last_name: Lovelace, email: ADA@EXAMPLE.TEST, branch_id: 1, status: ACTIVE, created_at: null, updated_at: null}
```

Run:

```bash
bruin unit-test lakota/assets/staging/customers.sql
```

Add a second test to `mart.daily_txn_summary`:

```yaml
unit_tests:
  - name: groups_by_day_and_type
    inputs:
      - asset: landing.core_transactions
        rows:
          - {txn_id: 1, txn_ts: "2026-01-03 09:00:00", amount: 100, txn_type: DEPOSIT}
          - {txn_id: 2, txn_ts: "2026-01-03 10:00:00", amount: 50, txn_type: DEPOSIT}
          - {txn_id: 3, txn_ts: "2026-01-03 11:00:00", amount: -20, txn_type: FEE}
          - {txn_id: 4, txn_ts: "2026-01-04 09:00:00", amount: 999, txn_type: DEPOSIT}
    expected:
      match: exact
      rows:
        - {txn_date: "2026-01-03", txn_type: DEPOSIT, txn_count: 2, total_amount: 150}
        - {txn_date: "2026-01-03", txn_type: FEE, txn_count: 1, total_amount: -20}
```

```bash
bruin unit-test lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999"
```

Notice that the date window is part of the test. The query filters on `{{ start_date }}` and `{{ end_date }}`, so the 2026-01-04 row is excluded and the test proves it. Without `--start-date` and `--end-date` the window defaults to yesterday (`bruin unit-test` uses the same date flags as `bruin run`), and the test would not match your mock dates. `bruin unit-test` also accepts `--var` and `--environment`. The test runs one read-only query on the asset's own connection, so the database must be reachable.

Break the logic on purpose: change `count(*)` to `count(distinct txn_ts::date)` in the query and rerun the unit test. It fails before any data moves, which is the point. Revert.

Run all unit tests in the repository:

```bash
bruin unit-test
```

Also read the docs sections on shared `fixtures` in `pipeline.yml`, `expected.ctes` for asserting intermediate CTEs, `execution_time` for freezing `now()`, and per-test `variables`. Try freezing time: write a throwaway asset that selects `now()::date AS d` and a test with `execution_time`.

UNVERIFIED on your setup: number and numeric comparison and date string handling in `expected`. The docs say comparisons are forgiving about representation. Record anything that was not.

## 5.5 Where checks belong

| Question | Use |
|---|---|
| Is this column unique, non-null, in a set? | built-in check |
| Does this table match the layer above it? | custom check (reconciliation) |
| Is my SQL logic right for edge cases? | unit test |
| Is the upstream data ready? | sensor (Module 9) |
| Should the pipeline stop for this? | `blocking: true` |

## Break/fix

1. Add a `relationships` check without a `foreign_key` on the column. Validate.
2. Point `foreign_key.table` at an asset that does not exist. Validate.
3. In `accounts_current`, add the `relationships` check to `customer_id` but remove `staging.customers` from `depends`. Run the whole pipeline on a fresh warehouse with `--full-refresh`. What can go wrong, and what do the docs say about this?
4. Write a custom check query that returns two columns. Run the check.
5. Edit a unit test's expected value so it is wrong. Run `bruin unit-test` and read the failure output.
6. In a unit test, forget one column that the query reads in a mocked input. What happens?

<details>
<summary>Answers</summary>

1. The check has no foreign key to resolve. The CLI source has lint rules around `relationships` and the column metadata, but I did not confirm whether the result is an error or a warning, so record the exact message. The doc: the `relationships` check uses the column's `foreign_key` metadata.
2. The docs: validation checks that the referenced asset exists in the pipeline and that the referenced column exists on it.
3. `foreign_key` metadata and the check do not create a scheduler dependency. Without `depends`, the child can be checked before the parent table exists or is refreshed, so the check can fail on a fresh build or pass on stale data.
4. A custom check compares one integer result (or a row count with `count`). The result is read through an integer cast that accepts a query returning a single value (`CastResultToInteger`, CLI source), so a two-column result should make the check error rather than compare. Record the message.
5. The failure output shows the expected and actual rows. Record how readable it is.
6. The doc says a column that no row sets does not exist in the mock, so the query fails on a missing column, or if you set it to `null` explicitly it works. Expect an error result (the database reports an undefined column) and not an ordinary test failure. UNVERIFIED which wording you get. Record whether the output says FAIL or ERROR.
</details>

## Check questions

1. What does `blocking: false` change?
2. Does `foreign_key` on a column cause the referenced table to be built first?
3. What is a reconciliation check, and why is it a better guard than row counts alone?
4. What does `--only checks` run?
5. A unit test and a quality check cover different failure modes. Name one failure each catches that the other cannot.
6. How do you test an asset whose query depends on the run window?

<details>
<summary>Answers</summary>

1. Downstream assets are no longer held back by that check. The failure is still reported, and the run still exits with code 1 (CLI source, UNVERIFIED at runtime).
2. No. Only `depends` orders execution.
3. It compares two layers (for example landing and mart) in a query that must return a fixed value. It catches missing or double-loaded windows, which row counts for one table cannot reveal.
4. Only the quality checks of the selected assets, without re-running their main query.
5. Unit test: a wrong `CASE` branch on rows that do not exist in production yet. Quality check: a null key that arrived from the source today.
6. Pass `--start-date` and `--end-date` to `bruin unit-test` (the dates feed the Jinja render, and the default is yesterday) or set per-test `variables`/`execution_time` as documented.
</details>

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| 5.2 all built-in checks pass on day 3 data | | |
| The `id` of one column check and one custom check (from `bruin internal parse-asset`), and the output of `--single-check` | | |
| Exit code of a run with a failed non-blocking check | | |
| Does `retries: 2` on a failing check run the query once or three times? | | |
| `pattern` regex accepted by Postgres | | |
| 5.3 failing relationships check blocks downstream | | |
| 5.3 `blocking: false` lets downstream run | | |
| `count:` custom check behaves as described | | |
| 5.4 unit test (customers) passes | | |
| 5.4 unit test (daily_txn_summary) passes with dates | | |
| Unit test comparison of numbers and dates | | |
| Break/fix 1, 4, 5, 6 messages (FAIL or ERROR for 5 and 6?) | | |
| Time taken | | |
