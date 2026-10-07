# Module 9: Sensors and cross-pipeline dependencies without Bruin Cloud

Estimated time: 4 to 5 hours. Written against Bruin v0.11.773.

## Outcome

You can make one pipeline wait for another using only the open-source CLI, a control table, a sensor, and an external scheduler. You can run the waiting pipeline in two ways: one long-running `wait` job, or a poller that fires every 10 to 15 minutes inside a time window and runs the pipeline once the upstream is ready. You can write a custom Python sensor for conditions Bruin has no sensor for, and you know what each approach cannot do compared with Bruin Cloud.

Docs for this module: `assets/sensor.md`, `platforms/postgres.md` (section "Sensors"), `commands/run.md` (`--sensor-mode`), `pipelines/definition.md` (schedule and catchup), `cloud/cross-pipeline.md` (read it to see what you are replacing), `assets/definition-schema.md` (`enabled`), `assets/python-sdk.md`.

## 9.1 What the docs say

Read the docs above, then answer. Answers are at the end.

1. What does a sensor do, and what file format defines one?
2. What do the three `--sensor-mode` values do? Which is the default?
3. What do `poke_interval` and `timeout` mean, what are their defaults, and what syntax does `timeout` use?
4. What does the docs warning say about sensor support in the CLI?
5. Which Postgres sensor types exist?
6. Does the CLI schedule pipelines? What does the `schedule` key in `pipeline.yml` do?
7. How does Bruin Cloud express a cross-pipeline dependency, and which parts of that does this module replace?

One trap in the Postgres docs: the example `pg.sensor.query` queries wrap the date in double quotes (`"{{ end_date }}"`). In PostgreSQL, double quotes delimit an identifier, so that query looks for a column named after the date. Use single quotes in your own sensor queries. If the docs example fails for you, this is why. Record it in the log.

## 9.2 The pattern

A cross-pipeline dependency needs three things:

| Part | Role in this course |
|---|---|
| A completion marker | The upstream pipeline's last asset writes a row to `ctl.pipeline_status`: pipeline name, data date, status `DONE`, run id, time. The row is written only if every asset before it succeeded. |
| A readiness check | The downstream pipeline's first asset is a sensor that queries the marker for the data date. |
| A trigger | Either a person, a long-running `--sensor-mode wait` job, or an external scheduler that starts the downstream pipeline every 10 to 15 minutes inside a window. |

The marker is a contract between teams: pipeline name plus data date plus status. Everything else in the other pipeline can change.

Bruin Cloud does this with `uri` entries in `depends` and a managed scheduler (`cloud/cross-pipeline.md`; its wait is 12 hours, which is unrelated to the 24 hour default of a CLI sensor). The CLI reads `uri` entries for lineage and `bruin validate`, but it does not wait on them and has no scheduler (source-derived, UNVERIFIED at runtime). To show an upstream table in lineage, declare it in the downstream pipeline as a symbolic `pg.source` asset. The waiting is what the sensor and the wrapper provide. The pattern above gives you the same behavior for the cases that matter: the downstream does not run on incomplete data, and it runs soon after the upstream finishes.

What it does not give you: automatic lineage across pipelines, a UI showing the waits, catch-up of missed intervals, and notifications. You supply those yourself (Module 11).

## 9.3 Lab: sensors in isolation

Goal: find out whether the CLI runs Postgres sensors at all and how each mode behaves, before you build on them. Start at any warehouse state.

Create a scratch pipeline so nothing else is touched:

```bash
cd ~/lakota-bruin
mkdir -p sensor_lab/assets
```

`sensor_lab/pipeline.yml`:

```yaml
name: sensor_lab
default_connections:
  postgres: "lakota-pg"
```

`sensor_lab/assets/wait_table.asset.yml`:

```yaml
name: ops.wait_table
type: pg.sensor.table
parameters:
  table: ops.late_arrival
  poke_interval: 5
  timeout: 2m
```

`sensor_lab/assets/wait_rows.asset.yml`:

```yaml
name: ops.wait_rows
type: pg.sensor.query
depends:
  - ops.wait_table
parameters:
  query: "select 1 from ops.late_arrival where batch_date = '{{ end_date }}'"
  poke_interval: 5
  timeout: 2m
```

Make sure the table does not exist, then work through the modes:

```bash
psql "$PGURL" -c "drop table if exists ops.late_arrival"
bruin validate sensor_lab
bruin run sensor_lab --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
echo "exit code: $?"
```

Record in the log:

- Did Bruin recognise `pg.sensor.table`, or did it report an unsupported type? If it fails with an error about the type, the CLI does not run Postgres sensors in this version. Write down the exact message, then skip to 9.6 and use the Python sensor pattern for everything in 9.4 and 9.5. Everything else in this module still applies.
- With the default mode (`once`): did the run fail, and with what exit code? Which asset failed, and what happened to `ops.wait_rows`?

Now `skip` and `wait`. For `wait`, use a second terminal to create the table and then the row while the first terminal polls:

```bash
# terminal 1
bruin run sensor_lab --sensor-mode skip --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin run sensor_lab --sensor-mode wait --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

```bash
# terminal 2, after you see the first sensor polling
psql "$PGURL" -c "create schema if not exists ops; create table ops.late_arrival (batch_date date)"
sleep 20
psql "$PGURL" -c "insert into ops.late_arrival values ('2026-01-04')"
```

Expected: `skip` succeeds immediately even though nothing exists (note what that means for safety, you will use it as a danger example later). `wait` keeps polling about every 5 seconds, passes the table sensor once the table exists, keeps polling the query sensor until the row exists, then both succeed.

Then test the timeout: drop the table, shorten `timeout` to `20s`, run with `--sensor-mode wait`, and record how long it took to fail and what the message says. Finally test a sensor whose table never exists while using `wait` against `pg.sensor.query` only (remove the `depends` and the table sensor): does a query against a missing table keep polling or fail at once? The source says it fails at once, even under `wait`, because only an unmet condition keeps polling and a query error returns immediately (`pkg/ansisql/operator.go`; UNVERIFIED at runtime, record the message). That is why the table sensor goes in front of the query sensor. `pg.sensor.table` looks the table up in `pg_catalog.pg_tables`, so it matches real tables only and a view never satisfies it.

Then settle what "returns any results" means. The BigQuery docs use `select count(*) > 0`, and the Postgres docs use `select exists(...)`. Both always return exactly one row, true or false, so the sensor cannot be testing only for the presence of a row. Source reading says a `pg.sensor.query` passes when the result is exactly one cell that casts to an integer above 0 (`true` casts to 1). Zero rows and `NULL` count as 0, so the sensor keeps waiting. More than one row or column is an error, not a pass. Predict each row of the table below from that rule before you run it. Test it directly with a throwaway sensor (change the `query` of `ops.wait_rows` and run with `--sensor-mode once`):

| Query | Rows returned | Does the sensor pass? |
|---|---|---|
| `select true` | 1 row, true | |
| `select false` | 1 row, false | |
| `select 1 where false` | no rows | |
| `select 0` | 1 row, 0 | |
| `select 5` | 1 row, 5 | |

Record the table. Predicted from source: `select true` passes, `select false` does not, no rows does not, `select 0` does not, `select 5` passes. Add a sixth test, `select 1 union all select 1`, and expect an error about multiple results. A zero-row query such as `select 1 ... where <ready condition>` passes only when the condition is true because an empty result is not ready.

Drop the scratch pipeline when finished: `rm -r sensor_lab` and `psql "$PGURL" -c "drop table if exists ops.late_arrival"`.

## 9.4 Lab: the marker and the consumer pipeline

### Producer side: changes in `lakota`

Create the marker table and the marker writer. The table is created once by a `ddl` asset.

`lakota/assets/ctl/pipeline_status.sql`:

```sql
/* @bruin
name: ctl.pipeline_status
type: pg.sql
tags:
  - ctl
materialization:
  type: table
  strategy: ddl
columns:
  - name: pipeline_name
    type: varchar
    primary_key: true
  - name: data_date
    type: date
    primary_key: true
  - name: status
    type: varchar
  - name: run_id
    type: varchar
  - name: completed_at
    type: timestamp
@bruin */
```

`lakota/assets/ctl/mark_lakota_done.sql` (no materialization: Bruin just runs the statement):

```sql
/* @bruin
name: ctl.mark_lakota_done
type: pg.sql
tags:
  - ctl
depends:
  - ctl.pipeline_status
  - staging.branch_customer_counts
  - staging.accounts_current
  - staging.txn_log
  - mart.daily_txn_summary
  - mart.channel_daily
  - hist.customers_hist
  - hist.accounts_hist
  - hist.accounts_open_hist
  - ctl.write_run_audit
@bruin */

INSERT INTO ctl.pipeline_status (pipeline_name, data_date, status, run_id, completed_at)
VALUES ('lakota', '{{ end_date }}'::date, 'DONE', '{{ run_id }}', now())
ON CONFLICT (pipeline_name, data_date)
DO UPDATE SET status = 'DONE', run_id = EXCLUDED.run_id, completed_at = EXCLUDED.completed_at
```

Three rules make a marker trustworthy:

1. It depends on every leaf of the pipeline, so it runs last. List every asset that no other asset depends on. If you removed or added assets in earlier modules, adjust this list. (`bruin lineage` shows the graph, UNVERIFIED output format.)
2. It runs only when everything before it succeeded, including quality checks that block. A failed or skipped upstream asset means the marker asset is skipped.
3. It is an upsert keyed on pipeline and data date, so a rerun is safe.

A partial run (for example `--tag mart`) does not include the marker, so it never claims completion. Keep it that way.

### Consumer side: the `lakota_reports` pipeline

```bash
mkdir -p lakota_reports/assets/gate lakota_reports/assets/reports lakota_reports/assets/ctl
cp lakota/pyproject.toml lakota_reports/pyproject.toml
```

The `pyproject.toml` copy matters for Python assets later: Bruin looks for the closest dependency file walking up from the asset folder to the repository root. One file at the repository root would serve both pipelines. This course keeps one per pipeline folder.

`lakota_reports/pipeline.yml`:

```yaml
name: lakota_reports
default_connections:
  postgres: "lakota-pg"

variables:
  drop_dir:
    type: string
    default: "~/lakota-drop"
  drop_wait_seconds:
    type: number
    default: 60
  drop_poke_seconds:
    type: number
    default: 5
```

`lakota_reports/assets/gate/wait_lakota.asset.yml` (the first step of this pipeline):

```yaml
name: ctl.wait_lakota
type: pg.sensor.query
parameters:
  query: "select 1 from ctl.pipeline_status where pipeline_name = 'lakota' and data_date = '{{ end_date }}' and status = 'DONE'"
  poke_interval: 10
  timeout: 20m
```

`lakota_reports/assets/reports/txn_mix.sql`:

```sql
/* @bruin
name: lakota_reports.txn_mix
type: pg.sql
tags:
  - reports
depends:
  - ctl.wait_lakota
materialization:
  type: table
  strategy: create+replace
@bruin */

SELECT txn_date,
       txn_type,
       txn_count,
       total_amount,
       round(100.0 * txn_count / sum(txn_count) OVER (PARTITION BY txn_date), 2) AS pct_of_day
FROM mart.daily_txn_summary
WHERE txn_date = '{{ end_date }}'::date
```

This report is a snapshot of the data date, replaced on every run, so a rerun cannot duplicate anything.

`lakota_reports/assets/ctl/mark_reports_done.sql`:

```sql
/* @bruin
name: ctl.mark_reports_done
type: pg.sql
tags:
  - ctl
depends:
  - lakota_reports.txn_mix
@bruin */

INSERT INTO ctl.pipeline_status (pipeline_name, data_date, status, run_id, completed_at)
VALUES ('lakota_reports', '{{ end_date }}'::date, 'DONE', '{{ run_id }}', now())
ON CONFLICT (pipeline_name, data_date)
DO UPDATE SET status = 'DONE', run_id = EXCLUDED.run_id, completed_at = EXCLUDED.completed_at
```

The consumer writes its own marker so that the next pipeline in a chain can wait on it, and so the polling script in 9.5 knows not to run again.

Validate both pipelines:

```bash
bruin validate lakota
bruin validate lakota_reports
```

### Get the warehouse to day 3

```bash
bash "$COURSE/tools/reset.sh" warehouse
bash "$COURSE/tools/reset.sh" source 3
bruin run lakota --tag landing --start-date 2000-01-01 --end-date "2026-01-04 23:59:59.999999"
bruin run lakota --exclude-tag landing --full-refresh --start-date 2026-01-01 --end-date "2026-01-04 23:59:59.999999"
```

The second command ends by writing the producer marker for 2026-01-04. Check it, then remove it so you can watch the consumer wait:

```bash
bruin query --connection lakota-pg --query "select * from ctl.pipeline_status"
psql "$PGURL" -c "delete from ctl.pipeline_status"
```

### Experiment 1: the consumer refuses to run early

```bash
bruin run lakota_reports --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
echo "exit code: $?"
bruin query --connection lakota-pg --query "select to_regclass('lakota_reports.txn_mix')"
```

Expected: the sensor fails in `once` mode, `lakota_reports.txn_mix` and `ctl.mark_reports_done` are skipped or not run, the exit code is nonzero, and the report table does not exist. Record exactly how Bruin reports the skipped downstream assets.

Now see why `skip` is dangerous:

```bash
bruin run lakota_reports --sensor-mode skip --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
psql "$PGURL" -c "delete from ctl.pipeline_status where pipeline_name = 'lakota_reports'"
```

The report ran with no marker present. `skip` is for local development only. Never put it in a scheduled command.

### Experiment 2: wait mode with two terminals

```bash
# terminal 1: starts first and waits (polls every 10 seconds)
bruin run lakota_reports --sensor-mode wait --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

```bash
# terminal 2: after at least two polls, run the mart layer and everything downstream of it for the same date
bruin run lakota --tag mart --downstream --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

The mart assets are idempotent, so a repeat run is safe. If the marker asset did not run because some of its dependencies were not selected, run it directly:

```bash
bruin run lakota/assets/ctl/mark_lakota_done.sql --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

Expected: within about 10 seconds of the marker appearing, terminal 1 passes the sensor, builds `lakota_reports.txn_mix` and writes the consumer marker. Check:

```bash
bruin query --connection lakota-pg --query "select txn_date, txn_type, txn_count, pct_of_day from lakota_reports.txn_mix order by txn_type"
bruin query --connection lakota-pg --query "select pipeline_name, data_date, status, completed_at from ctl.pipeline_status order by completed_at"
```

Expected: 4 rows, `txn_count` summing to 85, `pct_of_day` summing to about 100 (each value is rounded to 2 decimals, so the exact sum is 100.01), and two marker rows for 2026-01-04.

A single long `wait` job is the simplest trigger. Its weaknesses: it holds a process (and a database connection poll) for as long as it waits, the default timeout is 24 hours, and if the machine reboots or the job is killed, nothing restarts it. That is why the polling approach in 9.5 is usually better for production.

### Experiment 3: the wrong data date

Run the consumer for a date with no marker (`--start-date 2026-01-05 --end-date "2026-01-05 23:59:59.999999" --sensor-mode once`). It must fail. This is the property that matters most: a consumer must never read yesterday's marker for today's data. Now think about the default dates: with no `--start-date`, Bruin uses "beginning of yesterday" to "end of yesterday" (UTC or local?). The source builds the default window from the machine's local calendar date for yesterday and labels the times UTC (`cmd/run.go`), so near midnight the scheduler's host clock decides which day that is. If your scheduler and the producer disagree on what "yesterday" means near midnight, the consumer waits on a date that the producer never marks. Write down how you will pin the date in production (always pass explicit dates from the scheduler).

## 9.5 Lab: scheduled polling inside a window

Instead of holding a `wait` job open, start the consumer every 10 to 15 minutes between, say, 05:00 and 09:00. Each start does a cheap readiness check, exits quietly if the upstream is not ready, runs the pipeline once when it is, and does nothing once the consumer's own marker exists.

The wrapper is `tools/run_if_ready.sh`. Read it completely before running it. It:

- exits quietly outside the polling window (`WINDOW_START_HOUR` to `WINDOW_END_HOUR`),
- takes a lock folder so a slow run is never overlapped by the next poll,
- reads both markers with `bruin query --output csv`,
- exits 0 and does nothing if the downstream is already `DONE`,
- exits 0 quietly if the upstream is not yet `DONE`, except on the last poll of the window, where it exits 2 as a "late" alert,
- otherwise runs the downstream pipeline with `--sensor-mode once` for explicit dates.

The pipeline's own sensor still runs. The wrapper's check keeps scheduled runs from showing up as failures every 15 minutes, and the sensor stays in the pipeline as the safety net and as lineage documentation.

### Test it by hand

The wrapper normally runs inside the window. For testing, widen the window with environment variables and pass an explicit date. First run it once and read the check, since `bruin query --output csv` formatting is UNVERIFIED:

```bash
bruin query --connection lakota-pg --output csv --query "select count(*) from ctl.pipeline_status where pipeline_name = 'lakota' and data_date = '2026-01-04' and status = 'DONE'" | od -c | head
```

The script reads the last line of the output and expects an integer. If the output has a different shape, adjust the `tail -n 1` line in `done_count`.

Now the full sequence:

```bash
export WINDOW_START_HOUR=0 WINDOW_END_HOUR=24
psql "$PGURL" -c "delete from ctl.pipeline_status"

bash "$COURSE/tools/run_if_ready.sh" lakota lakota_reports 2026-01-04    # 1: not ready, exits 0
bruin run lakota/assets/ctl/mark_lakota_done.sql --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bash "$COURSE/tools/run_if_ready.sh" lakota lakota_reports 2026-01-04    # 2: runs the consumer
bash "$COURSE/tools/run_if_ready.sh" lakota lakota_reports 2026-01-04    # 3: already done, exits 0
```

Expected log lines: "upstream not ready yet", then "upstream DONE, running lakota_reports" followed by a Bruin run and exit code 0, then "downstream already DONE". After step 3 nothing runs, which is the guard against duplicate runs.

The late alert:

```bash
psql "$PGURL" -c "delete from ctl.pipeline_status"
export WINDOW_START_HOUR=0 WINDOW_END_HOUR=$(( 10#$(date +%H) + 1 )) POLL_MINUTES=120
bash "$COURSE/tools/run_if_ready.sh" lakota lakota_reports 2026-01-04
echo "exit code: $?"
```

Expected exit code 2 and an "ALERT" line. A scheduler that records nonzero exits (Task Scheduler's "Last Run Result", cron mail, your CI) now tells you that the upstream missed its window.

Also try the lock: create the lock folder by hand (`mkdir /tmp/run_if_ready_lakota_reports.lock`) and run the script, then remove it. The script must exit 0 without running anything.

### Put it on a schedule

Do this on the machine that will own the job. Two options:

**Windows Task Scheduler.** Run these from PowerShell or `cmd`, not from Git Bash (Git Bash rewrites arguments that start with `/`). Adjust paths to your install and project folder:

```text
schtasks /Create /TN "lakota_reports_poll" /SC MINUTE /MO 15 /ST 05:00 /TR "\"C:\Program Files\Git\bin\bash.exe\" -lc \"cd ~/lakota-bruin && bash course/tools/run_if_ready.sh lakota lakota_reports\""
schtasks /Query /TN "lakota_reports_poll" /V /FO LIST
schtasks /Delete /TN "lakota_reports_poll" /F
```

Task Scheduler repeats every 15 minutes all day. The window logic lives in the script (default 05:00 to 09:00), so the extra firings outside the window exit at once. UNVERIFIED on your machine: whether `bruin` and `uv` are on the PATH that a non-interactive Git Bash login shell sees, and whether the task runs when you are logged out. Check the output by redirecting it to a file (append `>> ~/run_if_ready.log 2>&1` inside the `-lc` string) and read the log after two firings. Do not create this task on a shared server until you have tested it on your own machine.

**cron (Linux, WSL, macOS):**

```text
*/15 5-8 * * *  cd /home/you/lakota-bruin && bash course/tools/run_if_ready.sh lakota lakota_reports >> /home/you/run_if_ready.log 2>&1
```

Without a `$3` date argument, the script uses yesterday (`date -d yesterday`, GNU `date`; on macOS install coreutils and use `gdate`) as the data date. Each `bruin query` call in the script also writes a small log under `logs/queries`. Prune old ones with `find logs -mtime +7 -delete` if the poller runs for weeks, and pass `--environment` when the connection is defined per environment. Decide for your own pipelines whether that matches how the upstream defines its date, and pass the date explicitly if it does not.

### Choosing between the triggers

| | One long `wait` job | Windowed poller |
|---|---|---|
| Moving parts | One scheduled start, one process | Scheduler plus the wrapper script |
| Resource use while waiting | A process and a database poll for hours | A few seconds every 15 minutes |
| Survives a reboot or killed job | No | Yes, the next poll starts again |
| Late or missed upstream | Fails at `timeout` (default 24h) | Explicit late alert at the end of the window |
| Duplicate runs | Possible if started twice | Guarded by the consumer marker and a lock |
| Where the logic lives | Bruin | The wrapper (outside Bruin) |

## 9.6 Lab: a custom Python sensor

Bruin has sensors for specific platforms. For anything else (a file from a vendor, an HTTP endpoint, a business-day calendar, a row count in a different database) you write the sensor as a Python asset that polls and exits nonzero on timeout. The contract: exit 0 means proceed; a nonzero exit fails the asset, and downstream assets do not run.

Create `lakota_reports/assets/gate/wait_for_drop_file.py`. It waits for a file that an external process drops, a common pattern for core processor or vendor files:

```python
""" @bruin
name: ctl.wait_drop_file
type: python
tags:
  - dropgate
@bruin """

import os
import sys
import time
from pathlib import Path

from bruin import context

drop_dir = Path(os.path.expanduser(context.vars["drop_dir"]))
wait_seconds = float(context.vars["drop_wait_seconds"])
poke_seconds = float(context.vars["drop_poke_seconds"])
data_date = str(context.end_date)[:10]

target = drop_dir / f"settlement_{data_date}.csv"
deadline = time.monotonic() + wait_seconds
print(f"waiting up to {wait_seconds:.0f}s for {target}", flush=True)

while True:
    if target.is_file() and target.stat().st_size > 0:
        size_before = target.stat().st_size
        time.sleep(2)  # guard against a file that is still being written
        if target.stat().st_size == size_before:
            print(f"found {target} ({size_before} bytes)", flush=True)
            sys.exit(0)
    if time.monotonic() >= deadline:
        print(f"timed out waiting for {target}", file=sys.stderr, flush=True)
        sys.exit(1)
    time.sleep(poke_seconds)
```

Run it three ways:

```bash
bruin run lakota_reports/assets/gate/wait_for_drop_file.py --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
echo "exit code: $?"
```

1. With no file: it should time out after about a minute with a nonzero exit.
2. Start it again, and in a second terminal create the file after 15 seconds:

```bash
mkdir -p ~/lakota-drop
sleep 15
printf 'txn_id,amount\n1,10.00\n' > ~/lakota-drop/settlement_2026-01-04.csv
```

3. Override a variable on the command line to shorten the wait: `--var drop_wait_seconds=10`.

Record which Python version and environment Bruin set up, how long the first uv startup took, and whether the printed lines appear live or only at the end (matters when you watch a long wait). The command runner streams the script's output to the console as it arrives (source-derived), so expect live lines.

Now make the report depend on both gates. Edit `lakota_reports/assets/reports/txn_mix.sql` so that `depends` lists `ctl.wait_lakota` and `ctl.wait_drop_file`. Run the consumer with and without the file present.

### When a Python sensor beats a platform sensor

- The CLI does not support a sensor for your platform (see 9.3).
- You need a condition that is more than "a row exists": a business calendar, a row-count threshold, a file size, an API status.
- You want the same sensor logic across Postgres and Snowflake.

The cost is that you own the timeout, the polling and the error messages, and the asset occupies a worker while waiting. Keep poll intervals long and timeouts explicit.

## 9.7 Conditional execution and skipping

Sensors answer "is it ready?" Sometimes the answer is "this should not run today". Two tools from Module 7 belong here:

- `enabled: false` on an asset skips it, and downstream assets can continue. A templated `enabled` is rendered only in a pipeline that declares `variants` (Module 7, 7.6). In a plain pipeline such as `lakota_reports`, `enabled: "{{ var.x }}"` is not resolved, so do not use it there.
- `--exclude-tag` and `--tag` choose assets at run time.
- A scheduler wrapper decides before Bruin starts. A weekend or bank holiday check belongs in the wrapper (`date +%u` for weekday), because a gate inside the pipeline either fails the run or skips it with no record.

Exercise: run `bruin run lakota_reports --exclude-tag reports --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999" --sensor-mode skip`. `lakota_reports.txn_mix` carries the `reports` tag and `ctl.mark_reports_done` does not. Record whether the marker runs although `lakota_reports.txn_mix` did not. If it does, the marker claims completion for a report that was never built. Decide whether that is what you want a consumer marker to mean, and if not, what the marker should depend on or which tag it should carry. Then put `enabled: "{{ var.run_reports }}"` on `txn_mix` in this plain pipeline and run `bruin validate lakota_reports`. Record what Bruin says (the source says reading an unresolved template fails with `enabled contains unresolved template`, UNVERIFIED at runtime).

## 9.8 Hardening exercises

Each of these is a real production failure. For each, write down the failure, the fix, and test the fix.

1. **Stale marker on rerun.** The producer reruns day 3 after a data fix. Between the rerun starting and finishing, the old `DONE` marker is still visible, so a consumer could read half-fixed data. Add a first asset to `lakota`, `ctl.mark_lakota_running`, that upserts the marker with status `RUNNING`, and make the landing assets depend on it. Verify with a timeline that the marker is `RUNNING` during the load and `DONE` at the end. What happens to the consumer's marker when the producer reopens?
2. **Marker without data.** A pipeline finishes but loaded zero rows. Should the marker say `DONE`? Add a quality check or a custom check that fails the pipeline in that case, so the marker never claims completion.
3. **Two upstreams.** The consumer needs both `lakota` and another pipeline. Add a second sensor asset for a second marker name and make the report depend on both.
4. **Backfill meets sensors.** `bruin backfill lakota_reports --start-date 2026-01-01 --end-date 2026-01-04 --partition daily --max-parallel 1` runs the sensor once per day. Which days have markers? Which partitions fail? Resume with `--continue` after writing the missing markers by hand. (This is also how you replay a consumer for historical days.)
5. **Sensor on a missing table.** If you did not settle this in 9.3, drop `ctl.pipeline_status` and run the consumer with `--sensor-mode wait`. Does the sensor keep polling or fail at once?
6. **Clock skew.** The producer finishes at 23:58 and the consumer's scheduler starts at 00:05. Which date does each use by default? Make both use an explicit date from the scheduler, then show the consumer finding the producer's marker.

## Break/fix

1. Put `{{ var.x }}` in a sensor's `name` instead of `parameters`. Validate.
2. Set `timeout: 1h30m`. Validate and run.
3. Set `poke_interval: 0` or a negative value.
4. Write a sensor query `select count(*) = 0 from ctl.pipeline_status where pipeline_name = 'lakota'` that is true when the sensor should still wait. Run it in `once` mode and compare with your table from 9.3. Rewrite it so that it passes only when the marker exists.
5. Remove the `depends` from the report. Run with `--sensor-mode once`. What stops the report from running before the sensor?
6. Run the sensor with a typo in the table name. Does it fail or poll until timeout?
7. Kill the wrapper script mid-run (Ctrl+C during the Bruin run) and check for a stale lock folder. Does the next poll start?

<details>
<summary>Answers</summary>

1. Variables in YAML-style assets are only supported inside the value of `parameters`. Validation or rendering fails.
2. Combinators are not supported. Use `90m`. There is no error. An unparseable `timeout` falls back to 24 hours without a warning (`GetSensorTimeout` in `pkg/helpers/helpers.go`, matching the docs), so `1h30m` makes the sensor wait a day. Prefer `90m`. Record how you could tell. The asset-level `timeout` in `definition-schema.md` is a different setting and uses a different duration syntax.
3. An unparseable `poke_interval` falls back to 30 seconds. `0` is parsed as given (source-derived), so under `wait` the loop re-queries without pausing. Record what you see. Under `once` and `skip` the value does not matter.
4. Which result passes depends on what you found in 9.3. A returned `false` or `0` is not ready, and `true` or any value above 0 passes. `select count(*) = 0` returns `true` when the marker is missing, so it passes immediately when the data is not there. Write the condition so that the value is above 0 only when the data is ready, for example `select count(*) from ctl.pipeline_status where ...` or `select exists(...)`.
5. Without `depends`, Bruin may run the report in parallel with the sensor. The dependency is what orders them. Always list the sensor in `depends`.
6. For a `pg.sensor.query` it fails at once, because a query error is not an unmet condition (source-derived, UNVERIFIED at runtime). A `pg.sensor.table` with a typo is different: the table check is a count that returns 0, so it keeps polling until `timeout`. Record both.
7. The `trap ... EXIT` removes the lock on normal exit and on Ctrl+C. A hard kill leaves it behind, and the next poll will exit 0 forever. Decide how you will detect stale locks (age check, or use a `flock`-style approach on Linux).
</details>

## Check questions

1. Why does the marker asset depend on every leaf rather than just the last mart asset?
2. What is the difference between `once`, `wait` and `skip`, and which would you put in a scheduled command?
3. Why does the wrapper check the marker before calling `bruin run` when the pipeline has its own sensor?
4. What stops a consumer from running twice for the same date?
5. A vendor file arrives sometimes by 06:00 and sometimes after 08:00. Which trigger do you use?
6. What does Bruin Cloud give you in this area that this pattern does not?
7. What are the failure modes of the marker pattern itself?

<details>
<summary>Answers</summary>

1. So the marker only appears when the whole pipeline finished. A marker that depends on a subset can claim completion while other assets are still running or failed.
2. `once` (default) checks one time and fails if unmet. `wait` rechecks every `poke_interval` until `timeout`. `skip` bypasses the sensor. Scheduled commands use `once` (poller) or `wait` (long job). Never `skip`.
3. To avoid a failed run every 15 minutes while the upstream is simply not finished, and to separate "not ready" (exit 0) from real failures (nonzero).
4. The consumer's own marker (checked by the wrapper), the lock folder, and the idempotent `create+replace` report, so a repeat run produces the same table.
5. The windowed poller, with a late alert at the end of the window.
6. Cross-pipeline lineage, managed scheduling and catch-up, a UI for waits, notifications. The pattern covers the dependency itself.
7. Stale `DONE` markers during reruns, a marker written when data is empty, a date mismatch between the two sides, a stale lock after a hard kill, and a missing alert when nobody reads the scheduler's exit codes.
</details>

## Answers to 9.1

1. A sensor waits for an external signal before downstream assets run. It is a YAML file named `<name>.asset.yml` with `type` and `parameters`.
2. `once` (default): check once, fail if unmet. `wait`: keep polling until true or timeout. `skip`: bypass sensors. The Fabric and S3 docs state this clearly; the sensor docs say the CLI "runs sensors once by default".
3. `poke_interval` is the delay between checks in seconds (the Postgres docs say the default is 30). `timeout` bounds the wait, uses single-unit durations (`90m`, not `1h30m`), and defaults to `24h`. Per the Fabric docs, `poke_interval` only matters under `wait`.
4. The CLI has working sensor implementations for some platforms, not all. Bruin Cloud supports all of them.
5. `pg.sensor.table` (a table exists) and `pg.sensor.query` (a query returns any result).
6. No. `schedule` documents the intended frequency and is read by an orchestrator such as Bruin Cloud or an external scheduler. `catchup`, `concurrency`, `max_active_steps` and notifications are also orchestrator-side.
7. Cloud uses `uri` on the upstream asset and `depends: - uri: ...` on the downstream, with the Cloud scheduler waiting for the upstream interval. This module replaces the dependency declaration (marker plus sensor) and the trigger (wait job or windowed poller). It does not replace Cloud lineage across pipelines or notifications.

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| 9.3 `pg.sensor.table` recognised by the CLI | | |
| 9.3 `once` mode failure and exit code | | |
| 9.3 `skip` mode | | |
| 9.3 `wait` mode with two terminals | | |
| 9.3 timeout behavior and message | | |
| 9.3 `pg.sensor.query` against a missing table | | |
| 9.3 what passes: true, false, no rows, 0, 5, and the multi-row error text | | |
| 9.3 double-quote trap in the docs example | | |
| 9.4 consumer refuses to run early | | |
| 9.4 `skip` runs without a marker | | |
| 9.4 wait mode passes after the producer marker | | |
| 9.4 row counts (4 rows, 85 txns, pct_of_day sums to 100.01) | | |
| 9.4 explicit date versus default date | | |
| 9.5 wrapper: not ready, ready, already done | | |
| 9.5 wrapper: late alert exit code 2 | | |
| 9.5 wrapper: lock behavior | | |
| 9.5 `bruin query --output csv` shape | | |
| 9.5 scheduled task fires and finds bruin on PATH | | |
| 9.6 Python gate timeout, found file | | |
| 9.7 `--exclude-tag reports`: does the consumer marker still run | | |
| 9.7 plain pipeline with templated `enabled`: validate result | | |
| 9.8 `timeout: 1h30m`: no error, 24h wait | | |
| 9.8 exercises completed | | |
| Time taken | | |
