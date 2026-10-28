# Module 4: Dependencies, selection and running pipelines

Estimated time: 2.5 hours. Written against Bruin v0.11.773.

## Outcome

You control exactly which assets run and in what order: dependencies, the selector syntax, tags, `--downstream`, `--only`, `--continue`, workers and per-connection concurrency, `enabled`, retries and timeouts. You can read a run log and a lineage graph.

Docs for this module: `commands/run.md` (read it fully), `getting-started/concurrency.md`, `assets/definition-schema.md` (sections `depends`, `enabled`, `retries`, `timeout`, `rerun_cooldown`, `tags`), `commands/lineage.md`, `pipelines/definition.md`.

## 4.1 Concepts

- **Dependencies** are declared in `depends`. They are the only thing that orders assets. An asset runs when every dependency has succeeded (including its blocking quality checks).
- Assets that do not depend on each other run in parallel, up to `--workers` (default 16).
- A dependency can be `mode: symbolic`: it shows in lineage but the downstream does not wait on it.
- `enabled: false` marks an asset as skipped, which is not a failure. Downstream assets continue.
- Quality checks belong to the asset. A failed blocking check fails the asset and stops everything downstream (Module 5).
- Local runs take their window from `--start-date` and `--end-date`, which default to yesterday (start of yesterday to its last microsecond). A date-only `--end-date` is midnight at the start of that day, which is why the labs pass the end of the day explicitly (Module 1). The pipeline-level `schedule`, `catchup`, `concurrency` and `max_active_steps` fields exist, but the docs describe them as Bruin Cloud features. `bruin run` does not read them for scheduling.
- `retries` and `rerun_cooldown` are parsed, inherited from pipeline to asset to check, and passed on to Cloud and Airflow. Reading the CLI source, nothing in the local executor or scheduler consumes them, so a local `bruin run` does not retry a failed asset. You test this in 4.5. UNVERIFIED at runtime.

Selection tools, from the `run` docs:

| Tool | Example | Selects |
|---|---|---|
| path | `bruin run lakota/assets/mart/channel_daily.sql` | one asset |
| `--downstream` | `bruin run <asset> --downstream` | the asset and everything downstream |
| `--tag` / `--exclude-tag` | `bruin run lakota --tag mart` | assets with (or without) a tag |
| `--selector` | `bruin run --selector "+mart.channel_daily"` | dbt-style graph expressions |
| `--only` | `--only checks` or `--only main` | which steps of each selected asset run |

Selector syntax: `tag:x`, `path:x`, `file:x`, `fqn:x`; `+asset` (with upstream), `asset+` (with downstream), `2+asset+1` (limited depth), `@asset` (descendants and the ancestors they need); a space between terms is a union (OR) and a comma is an intersection (AND). `--selector` cannot be combined with `--tag`, `--downstream`, `--single-check`, `--modified`, or a path that points at one asset file. A pipeline folder as the positional argument is allowed, and it is how you say which pipeline the selector applies to when you are not inside it (CLI source, `cmd/run.go`).

## 4.2 Lab: read the graph

Make sure the pipeline is loaded to day 3 from Module 3. If not, reset and replay as in Module 3 (days 1 to 3).

```bash
cd ~/lakota-bruin
bruin lineage lakota/assets/mart/daily_txn_summary.sql
bruin lineage --full lakota/assets/mart/daily_txn_summary.sql
bruin lineage --full -o json lakota/assets/staging/customers.sql
```

On paper, draw the DAG for the whole `lakota` pipeline (14 assets). Mark which assets can run in parallel in the first wave of a full run. Then check your drawing against the log lines of a real run in 4.4.

## 4.3 Lab: selecting assets

Run these from the repository root. The pipeline folder is the positional argument, and the selector decides which of its assets run. The date flags go in a bash array so the quoted end time survives:

```bash
cd ~/lakota-bruin
D=(--start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999")

bruin run lakota --selector "tag:mart" "${D[@]}"
bruin run lakota --selector "+mart.daily_txn_summary" "${D[@]}"
bruin run lakota --selector "staging.customers+" "${D[@]}"
bruin run lakota --selector "@staging.customers" "${D[@]}"
bruin run lakota --selector "tag:mart,path:assets/mart/channel_daily.sql" "${D[@]}"
bruin run lakota --selector "path:assets/mart tag:ctl" "${D[@]}"
```

For each command, note which assets ran. Predict first, then check. The surprising ones to think through:

- `+mart.daily_txn_summary` runs the asset and its upstream (`landing.core_transactions`), not the other `mart` assets.
- `@staging.customers` runs the asset's descendants and, in addition, the ancestors those descendants need (for example `ref.branches`, which `staging.branch_customer_counts` depends on). Check the result against your graph from 4.2.
- The comma form is an intersection: only `mart.channel_daily` matches both terms.

`path:` is matched against the asset's path relative to the pipeline folder. A plain path matches that file or everything below that folder, and a pattern with `*` is matched as a glob (CLI source, `pkg/pipeline/selector.go`). That is why `assets/mart` works with no repository-root prefix. UNVERIFIED at runtime: record which assets `path:assets/mart` selected.

Then the flag forms:

```bash
bruin run lakota --tag mart --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin run lakota --exclude-tag landing --only checks --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin run lakota/assets/staging/customers.sql --downstream --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin run lakota --only main --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

`--only checks` runs the quality checks without refreshing data. `--only main` refreshes data and skips the checks. Neither skips the other's validation of configuration. `--exclude-tag` can be repeated, and `--tag` has the short form `-t`.

## 4.4 Lab: parallelism and connection limits

Run the whole pipeline and read the output top to bottom:

```bash
bruin run lakota --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
bruin run lakota --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999" --workers 1
bruin run lakota --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999" -i
```

Questions to answer from the output:

1. Which assets started together in the first wave? Does it match your drawing from 4.2?
2. How does the total run time change with `--workers 1`?
3. What does `-i` (interactive TUI) show that the plain log does not?

Now add a per-connection limit. In `.bruin.yml`, add `max_concurrent_assets: 1` to the `lakota-pg` connection (`getting-started/concurrency.md`). This is a small hand edit, which is normal: there is no command that edits one field of a connection, and `bruin connections add` rejects a name that already exists. Run again with the default workers. The docs say ingestr assets count against both their source and destination connections. Predict what happens to the three landing assets, then watch it. Then predict whether the quality checks on `lakota-pg` assets also queue behind the limit. The docs speak of assets, and the CLI source appears to count every task instance on the connection. UNVERIFIED: record what you see. Remove the setting afterward unless you want it on.

The Postgres connection also has its own pool size, `pool_max_conns` (default 10, `platforms/postgres.md`). That is a separate limit from `--workers` and `max_concurrent_assets`.

## 4.5 Lab: failure, retries and `--continue`

Create a deliberately broken pair of assets.

`lakota/assets/staging/broken.sql`:

```sql
/* @bruin
name: staging.broken
type: pg.sql
tags:
  - lab
retries: 1
materialization:
  type: view
@bruin */

SELECT * FROM landing.table_that_does_not_exist
```

`lakota/assets/staging/after_broken.sql`:

```sql
/* @bruin
name: staging.after_broken
type: pg.sql
tags:
  - lab
depends:
  - staging.broken
materialization:
  type: view
@bruin */

SELECT 1 AS ok
```

Run them:

```bash
bruin run lakota --tag lab --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

Observe: `staging.broken` fails, and `staging.after_broken` does not run. The asset sets `retries: 1`, so count how many times the failing statement appears. Run it once more with `--verbose` and count the attempts. The docs describe `retries` as retrying failed assets, but reading the CLI source, local `bruin run` has no retry loop: expect one failure and no second attempt. UNVERIFIED at runtime. Record the count. This matters for Module 11: if you want retries on a VM, your wrapper must provide them. Read the end-of-run summary. Look at the state file:

```bash
ls logs/runs/lakota | tail -3
```

Fix the broken query (change the table to `landing.core_customers`) and continue from the failure. `--continue` finds the state file through the pipeline, so give it the pipeline:

```bash
bruin run --continue lakota
```

From the docs: `--continue` runs from the last failed asset and reuses the flags of the last run. From the CLI source: it reads the newest file in `logs/runs/lakota`, sets assets that failed, were blocked by a failure, or were still running back to pending, and marks assets that succeeded or were skipped as not needing a run. It refuses to start if the pipeline structure changed, with the message "the pipeline has changed since the last run; please rerun the pipeline". The structure is a hash of the pipeline name, each asset name, each asset's `enabled: false` marker and each asset's upstream list. Changing a query does not change it. Adding a dependency, adding or removing an asset, or disabling an asset does. Note whether it re-ran anything that had already succeeded.

Now test `enabled`. Add `enabled: false` to `staging.broken` and run the `lab` tag again. The asset is marked as skipped (CLI source, `SkipDisabledAssets`), and `after_broken` should run. UNVERIFIED: whether the summary lists the disabled asset or omits it. Record it. Disabling an asset also changes the structure hash above, so a `--continue` after this change would be refused. Remove both lab assets at the end (`git rm` or just delete the files, they were never committed).

## 4.6 Lab: timeouts

Add `timeout: 3s` to a SQL asset that sleeps:

```sql
/* @bruin
name: staging.slow
type: pg.sql
tags:
  - lab
timeout: 3s
@bruin */

SELECT pg_sleep(10)
```

Run it. The docs say the step is cancelled and the asset fails with a timeout error. Compare with the run-wide `bruin run --timeout 2 lakota --tag lab ...` (seconds, default 604800). Delete the asset afterward. `timeout` is a Go duration (`1h30m` allowed); sensor timeouts use a different syntax (Module 9).

## 4.7 Read a run log

```bash
ls logs/runs/lakota
python3 -m json.tool "logs/runs/lakota/$(ls -t logs/runs/lakota | head -1)" | head -60
```

The state file is the data `--continue` reads, not an audit log. From the CLI source (`pkg/scheduler/scheduler.go`), the top-level keys are `cmdline`, `parameters` (the flags of the run: dates, workers, environment, force, full refresh, selector, tags, `only`, sensor mode), `metadata`, `state` (a list of `{name, status}`, one entry per asset), `version`, `timestamp`, `run_id`, `compatibility_hash`, and `backfill_id` and `backfill_total` for backfill children. It holds no timings, row counts or error text. For Module 11, alert on the process exit code and the captured output, and use this file to see which assets ended in which status. Confirm the key names on your machine. Note that `cmdline` records the command as typed, so never pass a secret as a flag.

## 4.8 Related commands

- `bruin run --verbose` prints the SQL it executes. Use it alongside `render`.
- `bruin run --no-validation` skips the pre-run validation. Use only to debug the validator itself.
- `bruin run --query-annotations default` adds a comment with asset, pipeline and step to every statement. This is how you trace queries in `pg_stat_activity` or the database log. Try it and look at the statements in `pg_stat_activity` while a run executes (or in the Postgres log).
- `bruin clean` deletes `logs/*.log` in the project and wipes the whole `~/.bruin` folder, which holds the uv install, the ingestr install and Bruin's local state (CLI source, `cmd/clean.go`). The next Python or ingestr run downloads them again. It does not delete `logs/runs`. `--uv-cache` also cleans uv's package cache after a confirmation prompt.

## Break/fix

1. Add a dependency cycle: make `staging.customers` depend on `mart.daily_txn_summary`. Run `bruin validate lakota`.
2. Add a `depends` entry that names an asset that does not exist. Validate, then run with `--tag mart`. The docs say selected assets must still declare dependencies that exist, even if the upstream does not execute.
3. Run `bruin run lakota/assets/mart/channel_daily.sql --selector "tag:mart"`.
4. Run `bruin run lakota --selector "+mart.channel_daily" --downstream`.
5. Mark `landing.core_customers` as `depends` of `staging.customers` with `mode: symbolic`, then run `staging.customers` on a fresh warehouse where landing is empty. What does lineage show, and what does the run do?

<details>
<summary>Answers</summary>

1. Validation rejects a cyclic graph. UNVERIFIED wording. Record it.
2. Validation fails on the missing dependency, and so does a run restricted by a tag.
3. Rejected: "Cannot use --selector when running a single asset file directly." A pipeline folder as the positional argument is fine, as the 4.3 commands show.
4. Rejected: "Cannot use --selector together with --downstream. Use +, n+, or @ in the selector instead."
5. Lineage shows the dependency. The run does not wait for the upstream and does not order itself by it, so with an empty landing the query runs against whatever exists. Symbolic is for documentation, not ordering.
</details>

## Check questions

1. What orders assets in a run, and what runs in parallel?
2. What is the difference between `--tag mart` and `--selector "tag:mart"`?
3. `--continue` after you changed a dependency. What happens, and what exactly counts as "changed"?
4. What does `max_concurrent_assets` do for an ingestr asset?
5. Which pipeline settings are Cloud features, so that a local `bruin run` does not honor them?
6. What does a failed blocking check do to downstream assets?

<details>
<summary>Answers</summary>

1. `depends`. Assets without a dependency between them run in parallel, capped by `--workers`.
2. Both pick assets by tag. The selector supports expressions (AND, OR, graph expansion) and cannot be combined with other selection flags. The flag is a single tag.
3. It only works if the pipeline structure is unchanged: "the pipeline has changed since the last run; please rerun the pipeline". Structure means the asset names, `enabled: false` markers and upstream lists. Editing a query or a column list does not count. After a structural change you must run from the beginning.
4. It caps concurrent assets per connection. For ingestr the cap applies to both the source and the destination connection.
5. `schedule`, `catchup`, `concurrency` and `max_active_steps` (and `instance` and the `notifications` block). Local runs use flags for the window and workers. `retries` and `rerun_cooldown` are also not acted on by a local run, per the CLI source (UNVERIFIED at runtime).
6. The asset is marked failed and downstream assets do not run.
</details>

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| 4.3 each selector: assets that ran | | |
| 4.3 which assets `path:assets/mart` selected (path is relative to the pipeline folder?) | | |
| 4.4 first-wave assets match drawing | | |
| 4.4 `--workers 1` run time vs default | | |
| 4.4 `max_concurrent_assets: 1` effect, and do quality checks queue behind it? | | |
| 4.5 how many times the failing statement ran with `retries: 1` (does local run retry?) | | |
| 4.5 `--continue lakota`: re-ran what, and the message after a structure change | | |
| 4.5 `enabled: false`: listed as skipped in the summary, or absent? | | |
| 4.6 timeout message | | |
| 4.7 run log keys | | |
| Time taken | | |
