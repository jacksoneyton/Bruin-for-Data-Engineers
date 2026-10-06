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
- Variants let one `pipeline.yml` describe several concrete pipelines that override variables.
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
bruin render lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-03 --end-date 2026-01-03
bruin run lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-03 --end-date 2026-01-03
bruin run lakota --only checks --tag mart --start-date 2026-01-03 --end-date 2026-01-03
```

The render must show the expanded `BETWEEN` clause and the checks must still pass. Try calling the macro without passing the dates (use the variables directly inside the macro body). UNVERIFIED whether the macro can see the built-in variables from its own body. Record what you see.

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
bruin render lakota/assets/mart/txn_type_pivot.sql --start-date 2026-01-03 --end-date 2026-01-03
bruin render lakota/assets/mart/txn_type_pivot.sql --start-date 2026-01-03 --end-date 2026-01-03 --var '{"txn_types": ["DEPOSIT", "FEE"]}'
bruin run lakota/assets/mart/txn_type_pivot.sql --full-refresh --start-date 2026-01-01 --end-date 2026-01-04
bruin query --connection lakota-pg --query "select * from mart.txn_type_pivot order by 1"
```

The first render lists four generated columns, the second lists two. Do not run the two-column override against the existing table. Changing the column set of an incremental table without a rebuild breaks it, and this is the practical risk of data-driven SQL. Check what a run with the override would do by rendering only.

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

UNVERIFIED: whether `bruin query` accepts these built-in variables for ad-hoc text and the output format of each filter. The filters page lists: `add_years`, `add_months`, `add_days`, `add_hours`, `add_minutes`, `add_seconds`, `add_milliseconds`, `truncate_year`, `truncate_month`, `truncate_day`, `truncate_hour`, `date_add`, `date_format`. Try three more of them and record the results.

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
bruin render lakota/assets/mart/channel_daily.sql --start-date 2026-01-04 --end-date 2026-01-04
bruin run lakota/assets/mart/channel_daily.sql --start-date 2026-01-04 --end-date 2026-01-04
bruin query --connection lakota-pg --query "select * from ctl.run_audit order by finished_at desc limit 3"
```

Check whether `render` shows the hooks, and whether the `pre` hook ran in the same session as the main statement. A `SET` only helps if it does. UNVERIFIED. One way to test it: use `SET statement_timeout = '1ms'` as the pre hook and see whether the asset fails.

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
bruin run state_reports --variant sd --start-date 2026-01-04 --end-date 2026-01-04
bruin run state_reports --variant nd --start-date 2026-01-04 --end-date 2026-01-04
bruin query --connection lakota-pg --query "select table_name from information_schema.tables where table_schema='mart' and table_name like 'branch%' order by 1"
```

Expected tables: `branches_sd`, `branches_nd`, `branch_detail_nd`. The `sd` variant skips the detail asset. By the docs a templated `enabled` that renders to false marks the asset as skipped, which is not a failure.

Record: does `bruin run state_reports` without `--variant` fail (the docs say you must pick one)? Does `validate` need a variant?

This `enabled: "{{ var.something }}"` mechanism is the documented clean way to make a whole branch of a pipeline conditional. Module 9 uses it.

## 7.7 Lab: interval modifiers

Add to `mart.daily_txn_summary`:

```yaml
interval_modifiers:
  start: -1d
```

```bash
bruin render lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-04 --end-date 2026-01-04
bruin render lakota/assets/mart/daily_txn_summary.sql --start-date 2026-01-04 --end-date 2026-01-04 --apply-interval-modifiers
```

The first render uses the window you passed. The second shifts the start back one day (2026-01-03). Verify in the rendered `DELETE` and `WHERE`.

The docs warn that without the flag the modifiers are ignored silently, with no error and no warning. This is the usual reason for "my lookback does nothing" locally. Bruin Cloud applies modifiers automatically, so a local run without the flag and a Cloud run of the same window can see different data.

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

1. Rendering fails or produces an empty value. UNVERIFIED which. Record it.
2. The docs say Bruin enforces at parse time that every variable has a `default`. Validation fails.
3. Full JSON Schema validation is not yet enforced per the docs, so the render may succeed with a nonsense value. Record what happened.
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
4. Never. The asset is marked skipped and downstream assets can continue.
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
| 7.6 run without `--variant` | | |
| 7.7 render with and without `--apply-interval-modifiers` | | |
| Time taken | | |
