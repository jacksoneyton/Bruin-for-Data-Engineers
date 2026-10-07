# Docs and source audit, 2026-10-06

Trigger: Module 0 told the learner to write `.bruin.yml` by hand. The documented workflow is `bruin init` plus `bruin connections add`. This audit looked for other places where a lesson used a manual or invented step where Bruin has a canonical command, and for places where a lesson disagreed with the v0.11.773 docs or source.

Method: four read-only audit passes (Modules 0 to 3, 4 to 6, 7 to 9, 10 to 12 with tools), each reading the lessons against the docs and the Go source at tag v0.11.773. Load-bearing claims were re-checked in the source before they were written into a lesson. Where a pass was wrong, the lesson follows the source (see "Audit claims that were corrected").

The Bruin binary was not run. "Source-derived" means read from the code, not observed.

## Changes by module

| Module | Change |
|---|---|
| 0 | Pin and upgrade instructions added. `.bruin.yml` is no longer hand-written: `bruin init empty` creates the project, `bruin connections add --env --type --name --credentials` creates the connections, `connections list` and `test` verify them. Template table added. `.gitignore` entries are added by Bruin, not by the learner. |
| 1 | New 1.2 template tour in a scratch folder. Project creation uses `bruin init empty lakota`. Date convention explained. |
| 2 | Step 0 drafts assets with `bruin import database` into an `init empty` pipeline. Engine version selection (`parameters.version`) documented. |
| 3 | Postgres facts from `pkg/postgres/materialization.go`: `merge` renders `MERGE INTO` (Postgres 15+), `merge` without `update_on_merge` only inserts, `create+replace` drops and recreates, `ddl` is untouched by full refresh, exact restricted-full-refresh warning text, `*_datetime` has no fractional seconds. |
| 4 | Local `bruin run` does not retry. `--continue <pipeline>`, compatibility hash and run-state keys documented. Selector examples run from the repository root. |
| 5 | `blocking` defaults to true. `--single-check` takes the check's sha256 id, with exit 1 for a check failure and 2 otherwise. Retries are not acted on locally. Unit-test window. |
| 6 | Python version rule (3.11 default, `image` overrides `requires-python`), uv installed by Bruin, `--exp-use-winget-for-uv` does nothing, `uv lock` runs automatically, `--var` parsed as JSON, `materialize()` missing raises an error, `time_interval` rejected by validate. |
| 7 | Templated `enabled` resolves only in variant pipelines. `bruin.pivot` comparison added. `--var` is not type checked and there is no `--var-file`. Positional insert hazard for `time_interval` with changed columns. Several UNVERIFIED items settled. |
| 8 | `scd2_by_column` with `incremental_key` sets `_valid_from` from the key. Restricted SCD2 on a missing table should fail (bare `MERGE INTO`). Backfill passes `--sensor-mode`, `--apply-interval-modifiers`, `--var` to children. Hourly partitions on a date asset give no warning. Answer 6 contradicted answer 5, now consistent. |
| 9 | Sensor pass rule: one integer cell above 0. Query errors fail at once. Invalid `timeout` silently becomes 24h. `uri` dependencies are read for lineage and validate but not waited on. Templated `enabled` exercise replaced by `--exclude-tag`. `pct_of_day` sums to 100.01. Default window is yesterday of the local calendar date, labeled UTC. |
| 10 | Dev environment built with `connections delete` and `add`. `clone` copies connections and prefix, not `config`. Production detection rule (lowercased name contains `prod`, only with explicit `--environment`, `--force` or `--only checks` skips it, backfill requires `--force`). `${VAR}` write-back hazard. Azure Key Vault variables. Masking does not cover the `cmdline` field. |
| 11 | `--continue lakota`. Non-fast `validate` runs live Postgres query validation. `import database` needs an existing pipeline. `connections add` for the second connection. `BRUIN_CONFIG_FILE_CONTENT` in the CI example. No local retries, one exit code for any failure. |
| 12 | `policy.yml` at repository root. `--continue lakota_risk`. Templates guidance (`default` is DuckDB). `ai enhance` data flow marked UNVERIFIED. |
| README | Postgres 15 for `merge`, verification paragraph, conventions section. |
| tools | All `--end-date` values end-of-day. `reset.sh` drops `risk` and `jane_*` schemas. Header notes in `run_if_ready.sh`, `run_and_alert.sh`, `ci_local.sh`. |

Across all modules, every `--end-date` that is a window end was rewritten to `"YYYY-MM-DD 23:59:59.999999"`. Reason: in v0.11.773 a date-only `--end-date` parses as midnight at the start of that day, so a one-day window was empty. `bruin backfill` is the exception and treats a date-only end as inclusive.

## Audit claims that were corrected

| Audit claim | What the source and docs say |
|---|---|
| `scd2_by_column` with `incremental_key` restricts rows to the run window | It sets `_valid_from` and `_valid_until` from the key (`assets/materialization.md`, `buildSCD2ByColumnQuery`). |
| A restricted SCD2 asset on a missing table probably creates the table | The incremental statement is `MERGE INTO` the target. Only the full-refresh path creates the table, so the run should fail. |
| `bruin environments update` can set `full_refresh_restricted` | `update` takes only a new name and a schema prefix. The `config` block is a hand edit. |
| Disabled assets are removed from the run and absent from the summary | `SkipDisabledAssets` marks them skipped. Summary listing stays UNVERIFIED. |
| Invalid `poke_interval` produces a tight loop | Unparseable values fall back to 30 seconds. Only an explicit `0` or negative number sleeps for no time. |
| `git diff .bruin.yml` detects write-back | Bruin adds `.bruin.yml` to `.gitignore`, so use `grep -c` for the reference text. |

## Still UNVERIFIED (confirm on a machine, then record in the module log)

- Local `bruin run` does not retry (source shows no consumer of `retries`).
- `${VAR}` write-back into `.bruin.yml` after `environments` or `connections` commands.
- Prompt behavior of a prod-named environment under a scheduler with no TTY.
- Whether `.venv` appears next to `pyproject.toml` after a Python run.
- Restricted SCD2 on a missing table: exact error text.
- Hourly partitions on a date asset: no warning, 96 children for 4 days.
- `bruin validate` on a variants pipeline fans out to every variant.
- `bruin format .` skipping unparseable files.
- Whether sensor `table_name` and marker `INSERT` text are rewritten under a schema prefix.
- `bruin.pivot` output compared with the hand-written loop.
- What `bruin ai enhance` sends to the provider.
- Azure secret-name character rules (Azure's, not Bruin's).
- Windows Task Scheduler behavior in Module 9.

## Open items for the course owner

1. Module 10 creates a third database, `bruin_course_dev`, which conflicts with the repository rule that labs run only in `bruin_course` and `bruin_course_src`. It predates this audit and was left in place. Options: keep it and amend the rule, or rework 10.2 to use a schema-prefix environment only.
2. Netezza is not a Bruin connection type in this version, so the migration lessons rely on exports.
3. Re-run the audit when the pinned version changes.
