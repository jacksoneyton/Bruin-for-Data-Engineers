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
- Local runs take their window from `--start-date` and `--end-date`, which default to yesterday. The pipeline-level `schedule`, `catchup`, `concurrency` and `max_active_steps` fields exist, but the docs describe them as Bruin Cloud features. `bruin run` does not read them.

Selection tools, from the `run` docs:

| Tool | Example | Selects |
|---|---|---|
| path | `bruin run lakota/assets/mart/channel_daily.sql` | one asset |
| `--downstream` | `bruin run <asset> --downstream` | the asset and everything downstream |
| `--tag` / `--exclude-tag` | `bruin run lakota --tag mart` | assets with (or without) a tag |
| `--selector` | `bruin run --selector "+mart.channel_daily"` | dbt-style graph expressions |
| `--only` | `--only checks` or `--only main` | which steps of each selected asset run |

Selector syntax: `tag:x`, `path:x`, `file:x`, `fqn:x`; `+asset` (with upstream), `asset+` (with downstream), `2+asset+1` (limited depth), `@asset` (descendants and the ancestors they need); a space between terms is a union (OR) and a comma is an intersection (AND). `--selector` cannot be combined with `--tag`, `--downstream`, a positional asset argument or a single-asset run.

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

Run these from the pipeline folder so selectors resolve against the pipeline (the docs run `--selector` without a path):

```bash
cd ~/lakota-bruin/lakota
D="--start-date 2026-01-04 --end-date 2026-01-04"

bruin run --selector "tag:mart" $D
bruin run --selector "+mart.daily_txn_summary" $D
bruin run --selector "staging.customers+" $D
bruin run --selector "@staging.customers" $D
bruin run --selector "tag:staging,tag:staging" $D
bruin run --selector "path:assets/mart tag:ctl" $D
```

For each command, note which assets ran. Predict first, then check. The two surprising ones to think through:

- `+mart.daily_txn_summary` runs the asset and its upstream (`landing.core_transactions`), not the other `mart` assets.
- `@staging.customers` runs the asset's descendants and, in addition, the ancestors those descendants need (for example `ref.branches`, which `staging.branch_customer_counts` depends on).

`path:` resolution is UNVERIFIED (relative to the pipeline folder in the docs' example). If `path:assets/mart` selects nothing, try a path relative to the repository root and record which form works.

Then the flag forms:

```bash
cd ~/lakota-bruin
bruin run lakota --tag mart --start-date 2026-01-04 --end-date 2026-01-04
bruin run lakota --exclude-tag landing --only checks --start-date 2026-01-04 --end-date 2026-01-04
bruin run lakota/assets/staging/customers.sql --downstream --start-date 2026-01-04 --end-date 2026-01-04
bruin run lakota --only main --start-date 2026-01-04 --end-date 2026-01-04
```

`--only checks` runs the quality checks without refreshing data. `--only main` refreshes data and skips the checks. Neither skips the other's validation of configuration.

## 4.4 Lab: parallelism and connection limits

Run the whole pipeline and read the output top to bottom:

```bash
bruin run lakota --start-date 2026-01-04 --end-date 2026-01-04
bruin run lakota --start-date 2026-01-04 --end-date 2026-01-04 --workers 1
bruin run lakota --start-date 2026-01-04 --end-date 2026-01-04 -i
```

Questions to answer from the output:

1. Which assets started together in the first wave? Does it match your drawing from 4.2?
2. How does the total run time change with `--workers 1`?
3. What does `-i` (interactive TUI) show that the plain log does not?

Now add a per-connection limit. In `.bruin.yml`, add `max_concurrent_assets: 1` to the `lakota-pg` connection (`getting-started/concurrency.md`) and run again with the default workers. The docs say ingestr assets count against both their source and destination connections. Predict what happens to the three landing assets, then watch it. Remove the setting afterward unless you want it on.

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
rerun_cooldown: 5
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
bruin run lakota --tag lab --start-date 2026-01-04 --end-date 2026-01-04
```

Observe: the first asset fails after its retry, the second does not run. Read the end-of-run summary. Look at the log file:

```bash
ls logs/runs/lakota | tail -3
```

Fix the broken query (change the table to `landing.core_customers`) and continue from the failure:

```bash
bruin run --continue
```

From the docs: `--continue` runs from the last failed asset and reuses the flags of the last run, and it only works if the pipeline structure has not changed. Note whether it re-ran anything that had already succeeded.

Now test `enabled`. Add `enabled: false` to `staging.broken` and run the `lab` tag again. The asset should be reported as skipped, and `after_broken` should run. Remove both lab assets at the end (`git rm` or just delete the files, they were never committed).

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

Log files hold the run id, parameters, and per-asset results. Note the keys you would use to build an alerting or audit step in Module 11. UNVERIFIED: the exact schema, since the docs show only a few top-level fields (`run_id`, `backfill_id`, `backfill_total`, `parameters`).

## 4.8 Related commands

- `bruin run --verbose` prints the SQL it executes. Use it alongside `render`.
- `bruin run --no-validation` skips the pre-run validation. Use only to debug the validator itself.
- `bruin run --query-annotations default` adds a comment with asset, pipeline and step to every statement. This is how you trace queries in `pg_stat_activity` or the database log. Try it and look at the statements in `pg_stat_activity` while a run executes (or in the Postgres log).
- `bruin clean` removes the `logs` folder and cached virtualenvs under `~/.bruin`.

## Break/fix

1. Add a dependency cycle: make `staging.customers` depend on `mart.daily_txn_summary`. Run `bruin validate lakota`.
2. Add a `depends` entry that names an asset that does not exist. Validate, then run with `--tag mart`. The docs say selected assets must still declare dependencies that exist, even if the upstream does not execute.
3. Run `bruin run lakota --selector "tag:mart"`.
4. Run `bruin run --selector "+mart.channel_daily" --downstream`.
5. Mark `landing.core_customers` as `depends` of `staging.customers` with `mode: symbolic`, then run `staging.customers` on a fresh warehouse where landing is empty. What does lineage show, and what does the run do?

<details>
<summary>Answers</summary>

1. Validation rejects a cyclic graph. UNVERIFIED wording.
2. Validation fails on the missing dependency, and so does a run restricted by a tag.
3. `--selector` cannot be combined with a positional path or other selection flags, so the command is rejected. (Here the path `lakota` is a positional argument.)
4. Same rule: `--selector` cannot be combined with `--downstream`.
5. Lineage shows the dependency. The run does not wait for the upstream and does not order itself by it, so with an empty landing the query runs against whatever exists. Symbolic is for documentation, not ordering.
</details>

## Check questions

1. What orders assets in a run, and what runs in parallel?
2. What is the difference between `--tag mart` and `--selector "tag:mart"`?
3. `--continue` after you changed a dependency. What does the docs' note say?
4. What does `max_concurrent_assets` do for an ingestr asset?
5. Which pipeline settings are Cloud features, so that a local `bruin run` does not honor them?
6. What does a failed blocking check do to downstream assets?

<details>
<summary>Answers</summary>

1. `depends`. Assets without a dependency between them run in parallel, capped by `--workers`.
2. Both pick assets by tag. The selector supports expressions (AND, OR, graph expansion) and cannot be combined with other selection flags. The flag is a single tag.
3. It only works if the pipeline structure is unchanged. After a structural change you must run from the beginning.
4. It caps concurrent assets per connection. For ingestr the cap applies to both the source and the destination connection.
5. `schedule`, `catchup`, `concurrency` and `max_active_steps` (and `instance` and the `notifications` block). Local runs use flags for the window and workers.
6. The asset is marked failed and downstream assets do not run.
</details>

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| 4.3 each selector: assets that ran | | |
| 4.3 `path:` form that worked | | |
| 4.4 first-wave assets match drawing | | |
| 4.4 `--workers 1` run time vs default | | |
| 4.4 `max_concurrent_assets: 1` effect | | |
| 4.5 retry output; `--continue` re-ran what | | |
| 4.5 `enabled: false` reported as | | |
| 4.6 timeout message | | |
| 4.7 run log keys | | |
| Time taken | | |
