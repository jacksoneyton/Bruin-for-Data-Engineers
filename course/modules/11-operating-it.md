# Module 11: Operating Bruin without Bruin Cloud

Estimated time: 5 hours. Written against Bruin v0.11.773.

## Outcome

You can run Bruin pipelines in production using only the CLI and tools the bank already has. You know what a failed run leaves behind and how to resume it, you can raise an alert on failure, compare tables across environments, scaffold assets from existing tables, run pull-request checks in CI, choose a deployment option, and list what changes when the target is Snowflake. You also know exactly what you give up compared with Bruin Cloud.

Docs for this module: `commands/run.md` (continue, logs, query annotations), `commands/data-diff.md`, `commands/import.md` (the `database` section), `commands/patch.md`, `commands/format.md`, `commands/validate.md`, `commands/unit-test.md`, `commands/lineage.md`, `commands/docs.md`, `deployment/overview.md`, `deployment/vm-deployment.md`, `deployment/github-actions.md`, `deployment/airflow.md`, `cicd/azure-pipelines.md`, `cicd/github-action.md`, `platforms/snowflake.md`, `pipelines/definition.md` (schedule, catchup, notifications).

## 11.1 What Bruin Cloud does that the CLI does not

Read the Cloud pages `cloud/overview.md`, `cloud/pipelines.md` and `cloud/notifications.md` once, then fill in the table. This is your operating checklist: every "you build it" cell is something this module or Module 9 covers.

| Capability | Bruin Cloud | CLI only: what you do instead |
|---|---|---|
| Scheduling | `schedule` in `pipeline.yml` | |
| Missed runs (catch-up) | `catchup` | |
| Run history and logs | UI | |
| Failure notifications | notification system | |
| Cross-pipeline dependencies | `uri` in `depends` | |
| Backfills | UI and API | |
| Concurrency of runs | `concurrency`, `max_active_steps` | |
| Secrets | encrypted connections | |
| Lineage across pipelines | catalog | |

Keep this table. The last exercise in Module 12 asks you to turn it into an operating plan for the bank.

## 11.2 Run logs and resuming a failed run

Every run writes a JSON log under `logs/runs/<pipeline>/<run-id>.json`. You looked at it in Module 4. Now use it.

Break a run on purpose and look at what is left behind. Add a `custom_check` or a not-null check that you know fails, or temporarily change a column name in an asset's query, then:

```bash
bruin run lakota --exclude-tag landing --start-date 2026-01-04 --end-date 2026-01-04
echo "exit code: $?"
```

Record which assets succeeded, which failed, and which were skipped. Fix the problem and resume:

```bash
bruin run --continue
```

The docs say this reruns from the last failed asset and reuses the flags of the last run, and only works if the pipeline structure has not changed. Test both claims: first resume after fixing the asset, then add a new dependency to some asset and try `--continue` again. Record what Bruin says.

Compare the two resume mechanisms you now know:

| | `bruin run --continue` | `bruin backfill --continue <id>` |
|---|---|---|
| Unit of resume | the last failed asset in one run | a partition of a date range |
| State lives in | the last run log | `logs/backfills/<id>/` |
| Reuses | the previous flags | the saved manifest |
| Fails if | the pipeline structure changed | you change saved inputs |

Check `logs/runs/lakota/` for the JSON of the failed run. List the keys in it with `python3 -m json.tool` and write down which fields you would use to build a run history table (run id, parameters, per-asset status, timestamps). UNVERIFIED: the exact schema, since the docs describe only a few top-level fields.

## 11.3 Lab: alert when a run fails

Bruin notifications live in Bruin Cloud. In the CLI, an asset cannot run "on failure", because everything downstream of a failed asset is skipped. The place that always sees the failure is the process that started the run, so the alert goes in the wrapper.

Read `tools/run_and_alert.sh`. It:

- runs any Bruin command and tees the output to `logs/alerts/<job>_<timestamp>.log`,
- on failure appends to `logs/alerts/alerts.log` and `history.log`,
- posts `{"text": "..."}` to `ALERT_WEBHOOK_URL` when it is set (Teams, Slack and many other tools accept an incoming webhook, but their payload formats differ, UNVERIFIED for your tool),
- always exits with Bruin's own exit code, so the scheduler also sees the failure.

Test it with a run that works, then one that fails:

```bash
bash "$COURSE/tools/run_and_alert.sh" nightly_ok -- run lakota --exclude-tag landing --start-date 2026-01-04 --end-date 2026-01-04
# break something, then:
bash "$COURSE/tools/run_and_alert.sh" nightly_fail -- run lakota --exclude-tag landing --start-date 2026-01-04 --end-date 2026-01-04
echo "exit code: $?"
cat logs/alerts/history.log
```

To test the webhook without an external service, run a throwaway listener in another terminal and point `ALERT_WEBHOOK_URL` at it:

```bash
python3 - <<'EOF' &
import http.server
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers["Content-Length"]); print(self.rfile.read(n).decode()); self.send_response(200); self.end_headers()
http.server.HTTPServer(("127.0.0.1", 8765), H).serve_forever()
EOF
export ALERT_WEBHOOK_URL=http://127.0.0.1:8765/
```

Stop the listener when finished (`kill %1`). Then decide:

1. Which exit codes from `run_if_ready.sh` (Module 9) should alert? Combine the two scripts: how would you make the scheduled command raise an alert on exit code 2 or 3 but stay quiet on exit code 0?
2. What alert should fire when the scheduler itself did not run (a server rebooted)? A failure wrapper cannot see that. Describe a "dead man's switch": the pipeline's last asset writes a heartbeat row, and a separate check alerts when the newest row is older than expected. Build the check as a query and decide who runs it.
3. Where do you keep a history of runs (`ctl.run_audit` from Modules 3, 6 and 7)? Is it enough to answer "did last night's load run, and for which date"?

## 11.4 Lab: compare tables with data-diff

`bruin data-diff` compares two tables, including across connections. Typical uses: dev against production, migration checks, and drift monitoring. By default it exits 0 even when differences exist; `--fail-if-diff` changes that.

Set up two comparable databases. If you did Module 10 you already have `bruin_course_dev`. Add a second connection in the default environment pointing at it (this is a regular connection, not an environment switch, so both tables can be addressed in one command):

```yaml
        - name: "lakota-pg-dev"
          username: "bruin_course"
          password: "${LAKOTA_PW}"
          host: "localhost"
          port: 5432
          database: "bruin_course_dev"
```

Make sure both databases have `staging.customers`. They should differ, for example because dev was built on day 1 data only. Then:

```bash
bruin data-diff lakota-pg:staging.customers lakota-pg-dev:staging.customers
bruin data-diff lakota-pg:staging.customers lakota-pg-dev:staging.customers --full
bruin data-diff lakota-pg:staging.customers lakota-pg-dev:staging.customers --fail-if-diff; echo "exit code: $?"
bruin data-diff lakota-pg:staging.customers lakota-pg-dev:staging.customers --full --output json | python3 -m json.tool | head -60
```

Answer from the output:

- What does the default (schema-only) comparison tell you, and what does `--full` add?
- Row counts and column statistics: which columns differ and by how much? Use `--tolerance` to decide when a numeric difference is noise.
- Create a schema difference on purpose (`alter table ... add column x int` in dev) and look at the generated `ALTER TABLE` suggestion. Which direction does it transform, and what does `--reverse` do?
- Compare two tables that are identical (the same table through both connections after you copy it). What does a clean result look like in plain and JSON output?

### Where it fits in a migration

For the DataStage and Netezza to Snowflake project, a data-diff is the shape of the check that proves a rebuilt table matches the old one. Two cautions. First, the docs list supported connections for each command and this snapshot does not list Netezza for data-diff, so you cannot assume you can diff a Netezza table against a Snowflake table directly. Verify with a Snowflake connection and a table you export. Second, a table-level statistic diff does not prove row-level equality; plan a row-level reconciliation (key counts, checksums over key columns) for critical tables.

## 11.5 Lab: scaffold assets from existing tables

Two commands help you bring existing objects under Bruin.

### `bruin import database`

```bash
cd ~/lakota-bruin
bruin import database --connection lakota-src --schema src_core ./scratch_import
```

Look at what it created: `scratch_import/pipeline.yml` and an asset per table. Open one. Record:

- the asset type and name it chose, and what the generated definition contains (columns, descriptions, owner),
- whether the assets are placeholders for external tables ("source" assets that run nothing) or runnable.

Now the ingestr form, which creates runnable assets that copy the source table:

```bash
bruin import database --connection lakota-src --schema src_core --ingestr --destination postgres ./scratch_import2
```

Compare with the assets you wrote by hand in Module 2. What did the import not know (an incremental key, a primary key, a merge strategy)? This tells you how much of a hand-written asset is business knowledge that no tool can scaffold.

Supported database types in this snapshot of the docs are Snowflake, BigQuery, PostgreSQL, Redshift, Athena, Databricks, DuckDB, ClickHouse, Synapse, MS SQL Server and MongoDB. Netezza and DataStage are not on the list. The other importers cover Oracle Data Integrator, SSIS and SQL Server Agent, Tableau, QuickSight and BigQuery scheduled queries. Nothing in this snapshot imports DataStage jobs, so a DataStage migration is a manual rewrite guided by your own job inventory (Module 12 sets this up).

### `bruin patch`

Two fixers keep asset files complete:

```bash
bruin patch fill-asset-dependencies lakota --output json
bruin patch fill-columns-from-db lakota/assets/staging/customers.sql
```

Test each:

1. Remove the `depends` line from `staging.branch_customer_counts` and run `fill-asset-dependencies` on that file. Did it find `ref.branches` and `staging.customers`? Did it rewrite the file, and how? Run `git diff` to see.
2. Delete the `columns:` block of an asset and run `fill-columns-from-db`. The docs say it adds only columns that do not exist yet. What types and descriptions does it write? Does it set `primary_key`?

Neither command replaces review. Treat their output as a draft that you read in a diff.

Delete `scratch_import` and `scratch_import2` when you finish.

## 11.6 Lab: format, validate and unit-test in CI

Pull-request checks are the cheapest quality control available. Three commands:

| Command | What it checks | Needs a database? |
|---|---|---|
| `bruin format <path> --fail-if-changed` | Asset files are in Bruin's canonical format | No |
| `bruin validate <path> --fast` | Structure, dependencies, checks, templating. `--fast` skips query validation | UNVERIFIED for connection fields |
| `bruin unit-test <path>` | Mocked-input SQL unit tests: one read-only `SELECT` per test | Yes, on the asset's connection |

Without `--fast`, `validate` runs a dry-run of each query on BigQuery and Snowflake, and not on Postgres. It also errors if a table the query reads does not exist yet.

Run the same checks locally with the course script:

```bash
bash "$COURSE/tools/ci_local.sh" lakota lakota_reports
```

Record what passed, what failed, and what `bruin format` changed. If `format` rewrote files, commit the result and run again. Then test the failure modes:

1. Misindent the header of an asset and rerun. Does `--fail-if-changed` catch it?
2. Add a dependency on a non-existent asset. Which step catches it?
3. Break a unit test's expected output. Which step catches it, and what does the failure look like?
4. Run `bruin format --sqlfluff` on one asset, if `sqlfluff` is installed (`pip install sqlfluff`). What does it change in SQL? Decide whether you want that enforced for the team.

### GitHub Actions

If your course repository is on GitHub, add this workflow (the docs' CI example, extended):

`.github/workflows/bruin-ci.yml`:

```yaml
name: bruin-ci
on:
  pull_request:
  push:
    branches: [ main ]
jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: bruin-data/setup-bruin@main
      - name: Format
        run: bruin format . --fail-if-changed
      - name: Validate
        run: bruin validate . --fast
      # Unit tests need a database connection. Provide .bruin.yml through a repository secret.
      # - name: Create Bruin config
      #   run: echo '${{ secrets.BRUIN_CONFIG }}' > .bruin.yml
      # - name: Unit tests
      #   run: bruin unit-test .
```

Pin the Bruin version for repeatable builds: the docs show `version` as an optional parameter of the setup action, and the Azure Pipelines page shows installing a specific tag. Open a pull request with a deliberate formatting error and confirm the check fails. Record how long the job takes.

The bank's platform is Azure, so also read `cicd/azure-pipelines.md`. It installs Bruin with `curl -LsSf https://getbruin.com/install/cli | sh`, then runs `bruin validate` and `bruin unit-test`. The docs show a Windows agent variant that installs through `bash install.sh`. Write the `azure-pipelines.yml` you would use. UNVERIFIED: whether your agents may download from `getbruin.com`; if not, you need an internal mirror of the binary, and that is an infrastructure question to raise early.

## 11.7 Choosing where scheduled production runs live

Read `deployment/overview.md` and the pages for the options that could apply to you. Fill in the table.

| Option | What schedules it | Where secrets live | Runs where | Good for the bank when |
|---|---|---|---|---|
| Windows Task Scheduler on a server | | | | |
| Ubuntu VM with cron (`deployment/vm-deployment.md`) | | | | |
| GitHub Actions on a schedule | | | | |
| Azure Pipelines scheduled trigger | | | | |
| Apache Airflow with `BashOperator` | | | | |
| Bruin Cloud | | | | |

Notes to write down from the docs:

- The VM guide uses absolute paths for the Bruin executable and the project folder, redirects output to a log file, and has a troubleshooting section for "Bruin command not found in cron" and "pipeline fails in cron but works manually". Both come up in Task Scheduler too.
- Its monitoring section covers email on failure and log rotation. Compare that with `run_and_alert.sh`.
- Airflow can run Bruin with a `BashOperator` on workers or a `KubernetesOperator` with official images. If the bank already runs Airflow, Bruin becomes one task type among many, and the Airflow scheduler provides the cross-pipeline dependencies. That changes Module 9 from a necessity to a fallback.
- `schedule` and `catchup` in `pipeline.yml` are read by an orchestrator. The CLI never reads them to schedule anything.

Pick one option for the bank's first production pipeline, and write down in five lines what must be true (server, account, secret handling, alerting, who is on call) before you would schedule it.

### Missed runs

Cloud has `catchup`. You do not. Design catch-up for the CLI:

1. On each start the scheduler wrapper computes the dates that should have run since the last `DONE` marker (`ctl.pipeline_status`).
2. For each missing date it calls `bruin run` with explicit dates, in order.
3. For a long gap it calls `bruin backfill` for the range.

Decide which pipelines tolerate this (idempotent strategies: `time_interval`, `delete+insert`, `merge`) and which do not (`append` without protection). Which of your `lakota` assets would you not catch up automatically?

## 11.8 Lineage and docs

```bash
bruin lineage lakota/assets/mart/daily_txn_summary.sql
bruin lineage --full --output json lakota/assets/mart/daily_txn_summary.sql | python3 -m json.tool | head -40
bruin docs . --title "Lakota Bank pipelines" --output lakota-docs.html --open
```

The docs command writes a single self-contained HTML file with every pipeline and asset: descriptions, owners, tags, columns, checks, materialization, lineage and source. Answer:

- Does the lineage include the sensors and the cross-pipeline dependency from Module 9? (The docs say cross-pipeline lineage is a Bruin Cloud feature. Verify.)
- Which fields in the output come from your `description`, `owner` and `tags` metadata? Add descriptions to two assets and regenerate.
- Use `--exclude-code` and compare. When would you publish the HTML internally with and without source code?
- A single HTML file is easy to attach to a ticket or put on a share. Where would the bank host it, and who regenerates it (a CI step on `main`)?

## 11.9 Query annotations: tracing a query back to an asset

`bruin run --query-annotations default` adds the asset, pipeline and step to SQL queries. On Snowflake the docs say the annotation becomes the `QUERY_TAG`, and custom `meta` and `tags` from the asset are merged into it, which lets you attribute warehouse cost and slow queries to an asset. Try it on Postgres:

```bash
bruin run lakota/assets/mart/daily_txn_summary.sql --query-annotations default --start-date 2026-01-04 --end-date 2026-01-04 --verbose
```

Find the annotation in the verbose output. UNVERIFIED: how it appears in `pg_stat_statements` or the Postgres log. In Module 6 you saw that SDK queries carry a `@bruin.config` comment; compare.

## 11.10 What changes on Snowflake

You cannot run Snowflake in this course. Read `platforms/snowflake.md` and `assets/materialization.md` (platform support table), then write the porting checklist for one of your own pipelines. Use this table as the skeleton.

| Topic | What the docs say | What you will do |
|---|---|---|
| Connection | `snowflake` connection, password or key-pair authentication (`private_key_path` or `private_key`, passphrase in `password`) | |
| Read-only connection | `read_only: true` allows only read statements; use a restricted role as well | |
| Asset types | `sf.sql`, `sf.seed`, `sf.sensor.table`, `sf.sensor.query`, `sf.source` | |
| Asset names | `table`, `schema.table` or `database.schema.table`; a three-part name auto-creates the database and schema and needs `CREATE DATABASE` | |
| `default_connections` key | `snowflake:` instead of `postgres:` | |
| Warehouse | per-asset `warehouse` parameter, templatable, with `--var` override and a fallback to the connection's default | |
| Query tags | set when `--query-annotations` is enabled; custom `meta` merges into the tag | |
| Strategies | merge, time_interval and both SCD2 strategies are supported; Data Vault is not (Postgres and DuckDB only) | |
| Sensors | Snowflake is one of the platforms where the CLI sensor implementation exists, per the sensor docs warning | |
| SCD2 timestamps | `_valid_until` default `23:59:59` instead of midnight on Snowflake; `TIMESTAMP_TZ` columns | |
| Dry-run validation | `bruin validate` runs a dry run on Snowflake by default | |

Also note:

- The docs' Snowflake sensor examples use double quotes around the date. In Snowflake, double quotes also delimit identifiers, so use single quotes in your own sensors (the same trap as in Module 9).
- Snowflake clones are a natural way to build a dev environment as a separate database, which `devenv` describes in general terms. UNVERIFIED how `bruin run` behaves when the clone already contains the tables.
- The cross-pipeline pattern from Module 9 works the same way: put `ctl.pipeline_status` in Snowflake and use `sf.sensor.query`.

Translate one pipeline end to end on paper: for Module 3's `staging.accounts_current`, list every line you would change to run it on Snowflake. If you have a Snowflake trial or a dev schema you may use, do the translation and run it, then record what failed.

## Break/fix

1. Run `bruin run --continue` in a folder where no run has failed.
2. Run `bruin data-diff` with a missing connection prefix and no `--connection`.
3. Run `bruin import database` against a connection type that is not supported.
4. Run `bruin format` on a file with a syntax error in the header.
5. Run `run_and_alert.sh` with a bad webhook URL. Does the exit code still reflect Bruin's failure?
6. Run `ci_local.sh` from the wrong folder.
7. Run `bruin docs` without write permission to the output folder.

<details>
<summary>Answers</summary>

1. Record the message. The docs say it continues from the last failed asset, so with none it should refuse or do nothing.
2. The docs say a table name without a connection prefix requires `--connection`. Expect an error.
3. An error naming the unsupported type. Record the wording.
4. Format should report the file as unparseable instead of rewriting it. Record the exact behavior.
5. The script records "webhook delivery failed" in `alerts.log` and still exits with Bruin's exit code.
6. The script finds no `pipeline.yml` and exits 64.
7. An error about writing the file. Record it.
</details>

## Check questions

1. Why can an asset not alert on failure of the pipeline it belongs to?
2. How do `bruin run --continue` and `bruin backfill --continue` differ?
3. What does `data-diff` exit with when tables differ, and how do you change that?
4. Which checks can run in CI without any database connection?
5. Why does a CLI-only setup need explicit dates passed by the scheduler?
6. Which of Cloud's features have no CLI equivalent at all, rather than needing a script?
7. For your bank's first production pipeline, what are the five things that must be in place before it is scheduled?

<details>
<summary>Answers</summary>

1. Everything downstream of a failed asset is skipped, so an asset placed "last" does not run when something earlier failed. The failure is visible only to the process that started the run.
2. `run --continue` reruns from the last failed asset using the last run's flags and breaks if the structure changed. `backfill --continue` resumes partitions of a saved plan.
3. Exit 0. Use `--fail-if-diff` for a nonzero exit.
4. `format --fail-if-changed`, and `validate --fast` (UNVERIFIED for connection fields). `unit-test` needs the asset's connection.
5. The CLI does not schedule; the defaults (yesterday) are computed on the machine that starts the run. Explicit dates prevent a mismatch between pipelines or after a delay.
6. A managed UI with logs and lineage across pipelines is the main one. Scheduling, catch-up, alerting and cross-pipeline waits can be built with scripts, as in Modules 9 and 11.
7. Your answer. Typical: a server and service account, credentials handled through environment variables or a secret backend, alerting on failure and on missing runs, a run history, and a named owner.
</details>

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| 11.2 failed run leaves expected state | | |
| 11.2 `bruin run --continue` and structure-change behavior | | |
| 11.3 `run_and_alert.sh` ok and fail cases | | |
| 11.3 webhook delivery to local listener | | |
| 11.4 `data-diff` plain, full, json | | |
| 11.4 `--fail-if-diff` exit code | | |
| 11.4 ALTER suggestion and `--reverse` | | |
| 11.5 `import database` output and runnable form | | |
| 11.5 `patch fill-asset-dependencies` result | | |
| 11.5 `patch fill-columns-from-db` result | | |
| 11.6 `ci_local.sh` (format, validate, unit-test) | | |
| 11.6 GitHub Actions workflow on a pull request | | |
| 11.8 lineage across pipelines | | |
| 11.8 docs HTML generated and reviewed | | |
| 11.9 query annotation visible | | |
| 11.10 Snowflake porting checklist written | | |
| Time taken | | |
