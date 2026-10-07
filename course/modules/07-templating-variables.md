# Module 7: Templating, variables, variants, hooks and interval modifiers

Estimated time: 3 hours. Written against Bruin v0.11.773.

## Outcome

You parameterize assets with Jinja, macros, custom variables and pipeline variants. You use hooks for set-up and audit statements, and you know exactly when interval modifiers apply and when they silently do not.

Docs for this module: `assets/templating/templating.md`, `assets/templating/macros.md`, `assets/templating/filters.md`, `variables/overview.md`, `variables/built-in.md`, `variables/custom.md`, `pipelines/variants.md`, `assets/interval-modifiers.md`, `assets/definition-schema.md` (sections `hooks`, `interval_modifiers`, `enabled`).

## 7.1 Concepts

- SQL assets are rendered with Jinja before they run. The engine is a Go implementation of Jinja (the filters page links to gonja), so most but not all Python Jinja features behave the same. When something fails, run `bruin render` first.
- Built-in variables (`start_date`, `end_date`, `execution_date`, `run_id`, `pipeline`, `full_refresh`, `this`, `schema_prefix`, `commit_hash`, and the `_datetime`, `_timestamp`, `_nodash` variants) are always available. Custom variables are declared in `pipeline.yml`, need a `default`, and are read as `{{ var.name }}`.
- YAML assets (sensor, ingestr) can use variables only in the value of `parameters`.
- Macros live in a `macros/` folder in the pipeline folder, as `.sql` files, and are loaded automatically.
- Bruin ships helpers under the `bruin` namespace (`bruin.group_by`, `bruin.safe_divide`, `bruin.generate_surrogate_key`, `bruin.pivot`, `bruin.deduplicate`, others) that render platform-specific SQL.
- Variants let one `pipeline.yml` describe several concrete pipelines that override variables. They are also the only place where a templated `enabled` is resolved (7.6).
- Interval modifiers shift the window that an asset sees. They are off on the CLI unless you pass `--apply-interval-modifiers`, and Bruin Cloud always applies them.

## 7.2 Lab: macros

Create `lakota/macros/lakota.sql`:

```sql
{% macro date_window(column, start, end) -%}
{{ column }}::date BETWEEN '{{ start }}' AND '{{ end }}'
{%- endmacro %}
```

Use it in `mart.daily_txn_summary`, replacing the `WHERE` clause inside the `{% if not full_refresh %}` block:

```sql
{% if not full_refresh %}
WHERE {{ date_window('txn_ts', start_date, end_date) }}
{% endif %}
```

The docs pass `start_date` and `end_date` as arguments, so do the same.

```bash
cd ~/lakota-bruin
bruin render lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999"
bruin run lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999"
bruin run lakota --only checks --tag mart --start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999"
```

The render must show the expanded `BETWEEN` clause and the checks must still pass. Try calling the macro without passing the dates (use the variables directly inside the macro body). Macros are expanded in the same render context as the asset, so `start_date` and `end_date` are visible from the body (source-derived, `pkg/jinja/jinja.go`; the docs do not state it). Confirm it in the render and record what you see.

## 7.3 Lab: loops and custom variables

Add to `lakota/pipeline.yml`:

```yaml
variables:
  min_txn_amount:
    type: number
    default: 0
  report_label:
    type: string
    default: "daily"
  txn_types:
    type: array
    items:
      type: string
    default: ["DEPOSIT", "WITHDRAWAL", "PAYMENT", "FEE"]
```

Keep the two variables from Module 6 and add `txn_types`. Create `lakota/assets/mart/txn_type_pivot.sql`:

```sql
/* @bruin
name: mart.txn_type_pivot
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
@bruin */

SELECT txn_ts::date AS txn_date,
{% for t in var.txn_types %}
       sum(CASE WHEN txn_type = '{{ t }}' THEN amount ELSE 0 END) AS {{ t | lower }}_amount{% if not loop.last %},{% endif %}

{% endfor %}
FROM landing.core_transactions
{% if not full_refresh %}
WHERE {{ date_window('txn_ts', start_date, end_date) }}
{% endif %}
GROUP BY 1
```

```bash
bruin render lakota/assets/mart/txn_type_pivot.sql --start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999"
bruin render lakota/assets/mart/txn_type_pivot.sql --start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999" --var '{"txn_types": ["DEPOSIT", "FEE"]}'
bruin run lakota/assets/mart/txn_type_pivot.sql --full-refresh --start-date 2026-01-01 --end-date "2026-01-04 23:59:59.999999"
bruin query --connection lakota-pg --query "select * from mart.txn_type_pivot order by 1"
```

The first render lists four generated columns, the second lists two. Do not run the two-column override against the existing table. Changing the generated columns without a rebuild has two outcomes. If the column count changes, the insert fails. If the count stays the same but the values change (swap `["DEPOSIT","FEE"]` for two other types), the insert can succeed and put the new values under the old column names, because the Postgres `time_interval` path deletes the window and then runs a positional `INSERT INTO ... SELECT` with no column list (source-derived, `pkg/postgres/materialization.go`; UNVERIFIED at runtime). A row count check will not catch either case. Rebuild with `--full-refresh` whenever the column set can change, and check what a run with the override would do by rendering only.

Now replace the hand-written loop with the helper (`assets/templating/macros.md`):

```sql
{{ bruin.pivot('txn_type', var.txn_types, then_value='amount', suffix='_amount') }}
```

`agg` defaults to `sum` and `else_value` to `0`, so `then_value='amount'` reproduces the loop's `sum(CASE WHEN ... THEN amount ELSE 0 END)`. Render it and compare with the loop output. Alias quoting and letter case can differ (`quote_identifiers` defaults to `true`). Record every difference. Do not run the helper version against the existing table unless the aliases match.

Why `{{ t | lower }}`: Jinja filters apply before conversion to text. Try `{{ t | upper }}`, and a bad filter name, and note the error.

## 7.4 Lab: Bruin SQL helpers and date filters

Create `lakota/assets/mart/txn_type_avg.sql`:

```sql
/* @bruin
name: mart.txn_type_avg
type: pg.sql
tags:
  - mart
depends:
  - landing.core_transactions
materialization:
  type: view
@bruin */

SELECT txn_type,
       {{ bruin.safe_divide('sum(amount)', 'count(*)') }} AS avg_amount
FROM landing.core_transactions
{{ bruin.group_by(1) }}
```

```bash
bruin render lakota/assets/mart/txn_type_avg.sql
```

Record the Postgres-specific SQL the helper produced. Then try date filters with the query command, which renders Jinja in the text you pass:

```bash
bruin query --connection lakota-pg --start-date 2026-01-15 --end-date 2026-01-20 --query "select '{{ start_date }}' as s, '{{ end_date | add_days(1) }}' as e_plus_1, '{{ start_date | date_format('%Y-%m') }}' as month_label"
bruin query --connection lakota-pg --start-date 2026-01-15 --end-date 2026-01-20 --query "select '{{ start_date | truncate_month }}' as month_start"
```

`bruin query` renders the text you pass with the same Jinja context as a run, and the start and end dates default as they do for `run` (source-derived, `cmd/fetch.go`; confirm in the output). A probe of the Jinja package gave `2026-01-21` for `end_date | add_days(1)`, `2026-01` for `start_date | date_format('%Y-%m')` and `2026-01-01` for `start_date | truncate_month`. Each `bruin query` call also writes a small log under `logs/queries`, which `bruin query` adds to `.gitignore`. The filters page lists: `add_years`, `add_months`, `add_days`, `add_hours`, `add_minutes`, `add_seconds`, `add_milliseconds`, `truncate_year`, `truncate_month`, `truncate_day`, `truncate_hour`, `date_add`, `date_format`. Try three more of them and record the results.

## 7.5 Lab: hooks

Hooks run SQL before or after an asset's main statement. They are supported for SQL assets and render Jinja with the same context as the query. Add to `mart.channel_daily`:

```yaml
hooks:
  pre:
    - query: "SET statement_timeout = '60s'"
  post:
    - query: "INSERT INTO ctl.run_audit (run_id, asset_name, rows_loaded, finished_at) SELECT '{{ run_id }}:{{ this }}', '{{ this }}', count(*), now() FROM {{ this }} ON CONFLICT (run_id) DO NOTHING"
```

```bash
bruin render lakota/assets/mart/channel_daily.sql --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin run lakota/assets/mart/channel_daily.sql --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin query --connection lakota-pg --query "select * from ctl.run_audit order by finished_at desc limit 3"
```

Check whether `render` shows the hooks, and whether the `pre` hook ran in the same session as the main statement. A `SET` only helps if it does. Source reading says the Postgres path sends the pre hook, the main statement and the post hook together, so a session `SET` applies (source-derived, UNVERIFIED at runtime). Confirm it: use `SET statement_timeout = '1ms'` as the pre hook and see whether the asset fails, then restore the real value.

Hooks can also be pipeline defaults under `default.hooks`, with an optional `applicable_type` list to limit them to certain SQL asset types. Defaults inherit independently, so setting only `pre` on an asset still inherits the default `post`.

Think before you use hooks for auditing. A hook runs as part of the asset. If the audit row must exist even when the asset fails, a hook is the wrong tool.

## 7.6 Lab: variants

Variants produce several concrete pipelines from one definition. Create a small separate pipeline `state_reports`:

```bash
mkdir -p state_reports/assets/mart
```

`state_reports/pipeline.yml`:

```yaml
name: "{{ var.state_key }}_state_report"
default_connections:
  postgres: "lakota-pg"

variables:
  state:
    type: string
    default: "SD"
  state_key:
    type: string
    default: "sd"
  include_detail:
    type: boolean
    default: false

variants:
  sd:
    state: "SD"
    state_key: "sd"
  nd:
    state: "ND"
    state_key: "nd"
    include_detail: true
```

`state_reports/assets/mart/branches.sql`:

```sql
/* @bruin
name: "mart.branches_{{ var.state_key }}"
type: pg.sql
materialization:
  type: table
@bruin */

SELECT branch_id, branch_name, city, state
FROM ref.branches
WHERE state = '{{ var.state }}'
```

`state_reports/assets/mart/branch_detail.sql`:

```sql
/* @bruin
name: "mart.branch_detail_{{ var.state_key }}"
type: pg.sql
enabled: "{{ var.include_detail }}"
depends:
  - "mart.branches_{{ var.state_key }}"
materialization:
  type: table
@bruin */

SELECT b.branch_id, b.branch_name, count(c.customer_id) AS customers
FROM mart.branches_{{ var.state_key }} b
LEFT JOIN staging.customers c ON c.branch_id = b.branch_id
GROUP BY 1, 2
```

```bash
bruin internal list-variants state_reports
bruin validate state_reports
bruin run state_reports --variant sd --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin run state_reports --variant nd --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin query --connection lakota-pg --query "select table_name from information_schema.tables where table_schema='mart' and table_name like 'branch%' order by 1"
```

Expected tables: `branches_sd`, `branches_nd`, `branch_detail_nd`. The `sd` variant skips the detail asset. By the docs a templated `enabled` that renders to false marks the asset as skipped, which is not a failure. This works because `state_reports` declares `variants`. In v0.11.773 Bruin renders a templated `enabled` only while materializing a variant (`pkg/pipeline/variant.go`, and the `enabled-template-pipeline` integration test, which always passes `--variant`).

Record: does `bruin run state_reports` without `--variant` fail? The v0.11.773 source prints `pipeline "..." declares variants [...]; --variant is required` and exits 1. Does `bruin validate state_reports` need a variant? The source says validate fans out and checks every variant when none is given (UNVERIFIED at runtime), so run it both ways and record the difference.

In a pipeline without `variants`, `enabled` is a static boolean. A templated value there is never rendered, and reading it fails with `enabled contains unresolved template`. Variants are therefore the way to make a branch conditional on a value. For a one-off run, select assets with `--tag` and `--exclude-tag` instead (Module 4). Module 9 uses the tag form.

The `bruin init` template list includes a variants example (source-derived, `templates/`). Check `bruin init --help` and compare it with this lab.

## 7.7 Lab: interval modifiers

Add to `mart.daily_txn_summary`:

```yaml
interval_modifiers:
  start: -1d
```

```bash
bruin render lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin render lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999" --apply-interval-modifiers
```

The first render uses the window you passed. The second shifts the start back one day (2026-01-03). Verify in the rendered `DELETE` and `WHERE`.

The docs warn that without the flag the modifiers are ignored silently, with no error and no warning. The `valid-time-interval` lint rule checks the modifier syntax, and `default.interval_modifiers` in `pipeline.yml` sets one for every asset. This is the usual reason for "my lookback does nothing" locally. Bruin Cloud applies modifiers automatically, so a local run without the flag and a Cloud run of the same window can see different data.

Pair modifiers with the right strategy. Think about what `interval_modifiers: start: -1d` does to `staging.txn_log` (append), then confirm with a render only (do not run it). Safe strategies for lookback windows are `time_interval`, `delete+insert` and `merge`. `append` duplicates.

`--apply-interval-modifiers` is ignored with `--full-refresh`.

## Break/fix

1. Use `{{ var.not_declared }}` in an asset and render it.
2. Declare a variable without a `default`. Validate.
3. Override a variable with the wrong JSON type (for example `--var min_txn_amount='"abc"'`) and render an asset that uses it.
4. In the variants pipeline, add a variant that overrides an undeclared variable. Validate.
5. Run `bruin run state_reports` without `--variant`.
6. Put `{{ var.state }}` in a sensor or ingestr YAML asset outside `parameters` (for example in `name`). What do the docs say?

<details>
<summary>Answers</summary>

1. Rendering fails. The Jinja engine runs with strict undefined variables, so the render reports an error instead of an empty value (source-derived, `pkg/jinja/jinja.go`). Record the message.
2. The docs say Bruin enforces at parse time that every variable has a `default`. Validation fails.
3. `--var` values replace the variable's default without a type or `enum` check (`Variables.Merge` in `pkg/pipeline/variables.go` only rejects names that are not declared, with `no such variable`). The render succeeds with the wrong type. There is no `--var-file` flag in this version. Pass `--var` repeatedly, or set `BRUIN_VARS`. On the command line `execution_date` is the current time, so use `start_date` for the data window. Record what happened.
4. Variant overrides must reference declared variables. Unknown names fail validation with `references unknown variable "X"`.
5. When a pipeline declares variants you must pick one with `--variant`.
6. For YAML-style assets, variables can only be used in the value context of the `parameters` field.
</details>

## Check questions

1. How do you read a custom variable in SQL, and how in Python?
2. What is the difference between `start_date` and `start_datetime`?
3. A lookback via `interval_modifiers` seems to have no effect on a local run. Why?
4. When does a templated `enabled: false` fail the pipeline?
5. Where do macro files live and how are they loaded?
6. Which strategies are safe with a lookback window?

<details>
<summary>Answers</summary>

1. SQL: `{{ var.name }}`. Python: `json.loads(os.environ["BRUIN_VARS"])`, or `context.vars` from the SDK.
2. `start_date` is `YYYY-MM-DD`. `start_datetime` includes the time as `YYYY-MM-DDThh:mm:ss`.
3. Interval modifiers are applied on the CLI only with `--apply-interval-modifiers`.
4. Never, inside a variant pipeline. The asset is marked skipped and downstream assets can continue. Outside variants a templated `enabled` is not resolved and fails when read.
5. In `macros/` inside the pipeline folder, as `.sql` files. All macros are loaded automatically.
6. `time_interval`, `delete+insert` and `merge`. `append` duplicates rows.
</details>

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| 7.2 macro with explicit date arguments | | |
| 7.2 macro reading built-ins directly | | |
| 7.3 array loop render and `--var` override | | |
| 7.4 `bruin.safe_divide` rendered SQL | | |
| 7.4 `bruin query` with date variables and filters | | |
| 7.5 hook rendering and same-session `SET` test | | |
| 7.6 variants: tables created, skipped asset reporting | | |
| 7.6 run without `--variant`, and `validate` with and without it | | |
| 7.6 plain pipeline with `enabled: "{{ var.x }}"`, error text | | |
| 7.3 `bruin.pivot` output versus the loop; same-count override result | | |
| 7.7 render with and without `--apply-interval-modifiers` | | |
| Time taken | | |
