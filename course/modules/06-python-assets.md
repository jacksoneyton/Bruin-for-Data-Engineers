# Module 6: Python assets and the Python SDK

Estimated time: 3 hours. Written against Bruin v0.11.773.

## Outcome

You write Python assets that run in isolated, uv-managed environments, return data for Bruin to materialize, read the run window and pipeline variables, query the warehouse through the SDK, receive connection credentials, and declare locked dependencies.

Docs for this module: `assets/python.md`, `assets/python-sdk.md`, `variables/built-in.md`, `variables/custom.md`, `commands/clean.md`.

## 6.1 Concepts

- A Python asset is a `.py` file. The definition sits in a docstring block between `"""@bruin` and `@bruin"""` at the top of the file.
- Bruin runs it with uv in an isolated environment. The Python version is 3.11 unless the asset sets `image: python:X.Y`. When both `image` and `requires-python` are present, `image` wins (v0.11.773 source, `pkg/python/uv.go`; `assets/python.md`). You do not need a system Python. Bruin downloads uv into `~/.bruin` on the first Python run when it is missing.
- Dependencies come from the closest `requirements.txt` or `pyproject.toml` found by walking up from the asset's folder to the repository root. If both exist in the search path, `requirements.txt` wins. `pyproject.toml` with a committed `uv.lock` is the recommended form. When Bruin runs an asset in `pyproject.toml` mode it runs `uv lock` first, so the lockfile appears on a normal run (v0.11.773 source).
- **Plain scripts** run and exit. A non-zero exit fails the asset.
- **Materialized assets** define `materialization` (table only, strategies `create+replace`, `append`, `merge`, `delete+insert`) and a `connection`, and implement `materialize()` that returns a dataframe, a PyArrow table, a list of dicts, or a generator yielding dicts or tables. Bruin writes the result to the destination through ingestr. `time_interval` is not supported for Python assets. If `materialize()` returns `None`, Bruin skips materialization with a warning.
- Built-in values arrive as `BRUIN_*` environment variables (`BRUIN_START_DATE`, `BRUIN_END_DATE`, `BRUIN_RUN_ID`, `BRUIN_FULL_REFRESH`, `BRUIN_VARS`, and others).
- Connections reach the script through `secrets` or the asset's `connection`, as JSON in an environment variable. The asset's own `connection` is injected as a secret automatically, under the connection name (v0.11.773 source).
- The **Python SDK** (`bruin-sdk`) wraps all of that: `context` for typed run values, `query()` for SQL, `get_connection()` for typed clients.

## 6.2 Lab: a plain script and the environment

Create `lakota/assets/ops/env_probe.py`:

```python
""" @bruin
name: ops.env_probe
type: python
@bruin """

import os

for key in sorted(k for k in os.environ if k.startswith("BRUIN_")):
    if key in ("BRUIN_VARS_SCHEMA",):
        continue
    print(key, "=", os.environ[key])
```

Run it twice, once with a window and once with a full refresh:

```bash
cd ~/lakota-bruin
bruin run lakota/assets/ops/env_probe.py --start-date 2026-01-03 --end-date "2026-01-04 23:59:59.999999"
bruin run lakota/assets/ops/env_probe.py --full-refresh --start-date 2026-01-03 --end-date "2026-01-04 23:59:59.999999"
```

Record:

- how long the first run took (uv sets up the environment) and the second,
- the values of `BRUIN_START_DATE`, `BRUIN_END_DATE`, `BRUIN_FULL_REFRESH`, `BRUIN_PIPELINE`, `BRUIN_RUN_ID`,
- anything printed about Python version or downloads.

On Windows, watch for uv or Python download prompts. Bruin installs uv itself on the first Python run, so you do not install it by hand. `run` also accepts `--exp-use-winget-for-uv`, but in v0.11.773 the flag is set and never read, so it changes nothing. Do not use it. The first `run` that touches Python also appends `__pycache__/` and `*.py[cod]` to `.gitignore` for you.

## 6.3 Lab: dependencies with `pyproject.toml`

Create `lakota/pyproject.toml`:

```toml
[project]
name = "lakota"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "bruin-sdk[postgres]",
    "psycopg2-binary",
]
```

Run the probe. Bruin runs `uv lock` before the asset, so a normal run creates `lakota/uv.lock`:

```bash
bruin run lakota/assets/ops/env_probe.py --start-date 2026-01-03 --end-date "2026-01-03 23:59:59.999999"
git status --short
```

Commit `pyproject.toml` and `uv.lock`. Rerun the probe and compare the run time. If `git status` shows a `.venv` folder under `lakota/`, add `lakota/.venv/` to `.gitignore`. UNVERIFIED: whether v0.11.773 creates one in this mode. Record what you see.

`bruin internal lock-asset-dependencies lakota/assets/ops/env_probe.py` locks dependencies without running the asset. It is an internal command, and you need it only when you want the lockfile before the first run (for example in CI).

Where does the cache live? Cached virtualenvs sit under `~/.bruin`. `bruin clean` removes that folder and the `logs/*.log` files (`commands/clean.md`, `cmd/clean.go`). It does not touch `uv.lock`, because the lockfile lives in your repository.

## 6.4 Lab: SDK basics and a plain script that writes

Create `lakota/assets/ops/window_report.py`:

```python
""" @bruin
name: ops.window_report
type: python
connection: lakota-pg
depends:
  - mart.daily_txn_summary
@bruin """

from bruin import query, context

print("window:", context.start_date, "to", context.end_date)
print("full refresh:", context.is_full_refresh)

df = query(
    f"""
    SELECT txn_date, sum(txn_count) AS txns
    FROM mart.daily_txn_summary
    WHERE txn_date BETWEEN '{context.start_date}' AND '{context.end_date}'
    GROUP BY txn_date
    ORDER BY txn_date
    """
)
print(df.to_string(index=False))
```

```bash
bruin run lakota/assets/ops/window_report.py --start-date 2026-01-03 --end-date "2026-01-04 23:59:59.999999"
```

Expected: two rows, 2026-01-03 with 90 and 2026-01-04 with 85, if the warehouse is at day 3.

Notes from the docs:

- `query()` returns a pandas DataFrame for `SELECT`-like statements and `None` for DDL and DML.
- When `connection` is set on the asset, Bruin injects the credentials automatically. Extra connections go under `secrets`.
- Every SDK query carries a `@bruin.config` comment, which helps you find it in `pg_stat_activity` or the Postgres log.
- Interpolating `context` values into SQL is safe here because they come from Bruin, not from users. Never interpolate untrusted text this way.

Now a script that writes. Create `lakota/assets/ctl/write_run_audit.py`:

```python
""" @bruin
name: ctl.write_run_audit
type: python
connection: lakota-pg
depends:
  - ctl.run_audit
  - mart.daily_txn_summary
  - mart.channel_daily
@bruin """

from bruin import query, context

query(
    f"""
    INSERT INTO ctl.run_audit (run_id, asset_name, rows_loaded, finished_at)
    SELECT '{context.run_id}', 'mart.daily_txn_summary', count(*), now()
    FROM mart.daily_txn_summary
    ON CONFLICT (run_id) DO NOTHING
    """
)
print("audit row written for run", context.run_id)
```

Run the full pipeline for day 3 and check:

```bash
bruin run lakota --exclude-tag landing --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin query --connection lakota-pg --query "select * from ctl.run_audit order by finished_at desc limit 3"
```

The table `ctl.run_audit` was created by the `ddl` asset in Module 3. A Python script wrote to it. This is the general pattern for control tables.

## 6.5 Lab: a materialized Python asset

Create `lakota/assets/ref/calendar.py`:

```python
""" @bruin
name: ref.calendar
type: python
connection: lakota-pg
materialization:
  type: table
  strategy: create+replace
columns:
  - name: cal_date
    type: date
    primary_key: true
    checks:
      - name: not_null
      - name: unique
  - name: is_weekend
    type: boolean
@bruin """

from datetime import date, timedelta


def materialize():
    start = date(2025, 1, 1)
    rows = []
    for i in range(730):
        d = start + timedelta(days=i)
        rows.append({"cal_date": d, "is_weekend": d.weekday() >= 5})
    return rows
```

```bash
bruin validate lakota
bruin run lakota/assets/ref/calendar.py --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin query --connection lakota-pg --query "select count(*), min(cal_date), max(cal_date), sum(is_weekend::int) from ref.calendar"
```

Expected: 730 rows from 2025-01-01 to 2026-12-31. The docs describe the flow: uv installs dependencies, `materialize()` runs, the result goes to an Arrow file, and ingestr loads it. The table carries the column types ingestr infers unless you set `parameters: enforce_schema: true` with typed `columns`. Check the actual column types:

```bash
bruin query --connection lakota-pg --query "select column_name, data_type from information_schema.columns where table_schema='ref' and table_name='calendar'"
```

Now change the strategy to `append`, run it twice, and count. It doubles. Change it to `merge` (the `cal_date` column is already the primary key) and run twice. It stays at 730. Revert to `create+replace`.

Return a generator instead of a list (`yield` each dict) and confirm the output is identical. This is the pattern for paginated sources.

## 6.6 Lab: variables from `pipeline.yml`

Add to `lakota/pipeline.yml`:

```yaml
variables:
  min_txn_amount:
    type: number
    default: 0
  report_label:
    type: string
    default: "daily"
```

Create `lakota/assets/ops/vars_probe.py`:

```python
""" @bruin
name: ops.vars_probe
type: python
@bruin """

from bruin import context

print("min_txn_amount:", context.vars["min_txn_amount"], type(context.vars["min_txn_amount"]).__name__)
print("report_label:", context.vars["report_label"])
```

```bash
bruin run lakota/assets/ops/vars_probe.py --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin run lakota/assets/ops/vars_probe.py --var min_txn_amount=100 --var report_label='"weekly"' --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

The docs show string overrides in JSON quoting (`'"prod"'`). Bruin parses each `--var` value as JSON (`key=value`, or a whole JSON object), so integers stay integers and an unquoted string such as `report_label=weekly` fails to parse (v0.11.773 source, `parseVariable` in `cmd/run.go`). Run the unquoted form and record the error text, and confirm that the type of `min_txn_amount` prints as `int`. The docs say the same variables are available in SQL through `{{ var.report_label }}` (Module 7).

## 6.7 Lab: connection credentials as secrets

```python
""" @bruin
name: ops.conn_probe
type: python
secrets:
  - key: lakota-pg
@bruin """

import json
import os

conn = json.loads(os.environ["lakota-pg"])
print("connection keys:", sorted(conn.keys()))
```

This prints only key names. Never print the values. Run it and compare the printed keys with the fields in `.bruin.yml`. The docs say the injected secret is a JSON representation of the connection model. You can also rename the variable with `inject_as`. Add `inject_as: DB` and read `os.environ["DB"]`.

Using the SDK instead:

```python
from bruin import get_connection
c = get_connection("lakota-pg")
print(c.type, sorted(c.raw.keys()))
```

Delete the probe assets (`ops.conn_probe`, `ops.env_probe`, `ops.vars_probe`) when you are done, or keep them under the `lab` tag.

## 6.8 R assets, briefly

The docs describe `type: r` assets (`assets/r.md`). R is not bundled. Skim the page and note the same shape: definition in a comment block, code below, same environment variables. This course does not run them.

## Break/fix

1. Remove `connection` from `ref.calendar` and validate.
2. Rename `materialize` to `materialise` and run the asset.
3. Change the strategy of `ref.calendar` to `time_interval`.
4. Add `"not-a-real-package"` to `pyproject.toml`, run `ops.window_report`, then remove it.
5. Raise an exception in a plain script. Observe retries if you set `retries: 1`.
6. Put a `requirements.txt` containing only `requests` next to `pyproject.toml` (in `lakota/`), then run `ops.window_report`. What happens, according to the docs, and why?
7. Add `print(os.environ["lakota-pg"])` to a probe, run it with `--mask-credentials` at its default, and read the log. Do not leave this in place.

<details>
<summary>Answers</summary>

1. A Python asset with `materialization.type: table` needs a `connection`. Validation should report it.
2. When `materialization.type` is set, Bruin imports the module and calls `module.materialize()`. With the function renamed, the call raises an AttributeError and the asset fails. Without a `materialization` block the script runs as a plain script and `materialize()` is never called. Record the error text.
3. Python assets do not support `time_interval`. `bruin validate` reports "Materialization strategy 'time_interval' is not supported for Python assets" and lists the supported strategies (`pkg/lint/rules.go`).
4. uv fails to resolve the package and the asset fails before your code runs.
5. A non-zero exit is an asset failure. Local `bruin run` does not retry in v0.11.773: `retries` is parsed from the definition but nothing in the local runner consumes it. Expect one attempt. Record whether you see a second one (UNVERIFIED at runtime).
6. `requirements.txt` takes priority over `pyproject.toml`. The environment would not contain `bruin-sdk`, so `from bruin import query` fails with an import error.
7. `--mask-credentials` defaults to `true` and redacts connection credential values from run logs (`commands/run.md`). Verify what you see. Masking is not a license to print secrets.
</details>

## Check questions

1. What decides which Python version and which dependencies an asset uses?
2. What must a Python asset have to materialize its result into a table?
3. Which materialization strategies do Python assets support?
4. Which `context` property tells you a run is a full refresh?
5. What does `query()` return for an `INSERT`?
6. How do you give a Python asset access to a second connection?

<details>
<summary>Answers</summary>

1. `image: python:X.Y` selects the version (default 3.11, `requires-python` is the fallback). Dependencies come from the closest `requirements.txt` or `pyproject.toml` (with `uv.lock`) found by walking up from the asset, with `requirements.txt` winning when both are present.
2. A `connection`, a `materialization` block with `type: table`, and a `materialize()` function that returns data.
3. `create+replace`, `append`, `merge`, `delete+insert`.
4. `context.is_full_refresh` (environment variable `BRUIN_FULL_REFRESH` equals `1`).
5. `None`.
6. List it under `secrets` (the default `connection` is injected automatically).
</details>

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| 6.2 first run time (uv setup) and second run time | | |
| 6.2 Windows uv behavior, any prompts | | |
| 6.3 lockfile created by a normal run; `.venv` appears or not | | |
| 6.7 unquoted `--var` string error text | | |
| 6.4 SDK query output matches (90 and 85) | | |
| 6.4 audit row written | | |
| 6.5 calendar: 730 rows, column types | | |
| 6.5 append doubles, merge stable | | |
| 6.6 variable override typing | | |
| 6.7 secret keys printed | | |
| Break/fix 2 and 6 outcomes | | |
| Time taken | | |
