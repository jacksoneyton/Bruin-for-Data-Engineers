# Module 12: Capstone and breadth survey

Estimated time: 8 to 10 hours for the capstone, 2 to 3 hours for the survey. Written against Bruin v0.11.773.

## Outcome

You build a new, production-shaped pipeline from a written specification without copying lessons, you prove it against numbers computed independently from the data, you operate it the way you would operate it at the bank, and you leave with an operating plan, a list of the features you have not used yet, and a concept map from DataStage and Netezza to what you now know of Bruin.

This module is graded by you. Each requirement has an acceptance test that returns a number or a yes or no. Fill in the log honestly: a "fail" with a clear note is more useful than a quiet pass.

## 12.1 The brief

Lakota Bank's risk team wants a daily risk view of accounts built on the data the `lakota` pipeline already produces. You will build a new pipeline, `lakota_risk`, in your repository. It waits for the `lakota` marker (Module 9), reads from the warehouse, and publishes three outputs and a marker of its own.

Before you write any code, write a one-page design note in `lakota_risk/DESIGN.md` answering:

1. What is each table's grain, key and strategy, and why that strategy?
2. What happens when the same date is run twice? When a day is skipped and run late?
3. What must be true for the pipeline to start, and what does it write when it finishes?
4. What breaks if the source deletes an account (Module 2: the landing merge does not remove it)?
5. Which assets are blocking on a failed check, and which only warn?

Keep it under a page. You will compare it against what you built.

### Requirements

| # | Requirement | Notes |
|---|---|---|
| R1 | Gate | First asset waits for `lakota` to be marked `DONE` for the data date, using the pattern from Module 9. |
| R2 | Source truth for deletes | The source deletes accounts, and the landing merge never removes them. Land a complete copy of the source accounts each run (replace, not incremental) as `landing.core_accounts_full`, in your `lakota_risk` pipeline, using an ingestr asset. |
| R3 | `risk.account_band_daily` | One row per open account per snapshot date, as of the data date. Columns: `snapshot_date`, `account_id`, `customer_id`, `product_code`, `balance`, `band`. Band is `LOW` below 1000, `MID` from 1000 up to but not including 10000, `HIGH` from 10000 up. Rerunning a date replaces that date. Accounts that no longer exist in the source must not appear. |
| R4 | `risk.band_summary` | One row per snapshot date and band with the account count and total balance. Built from R3, not from the landing data. Idempotent per date. |
| R5 | `risk.large_txn_flags` | Every transaction whose absolute amount is at least a threshold held in a pipeline variable `large_txn_threshold` (default 1000), with its date, account, type, channel and amount. Incremental by transaction date. |
| R6 | History | `hist.account_band_hist`: SCD2 of each account's band and status, so you can answer "when did this account become HIGH". |
| R7 | A Python asset | At least one Python asset using the SDK and a pipeline variable. Suggested: `risk.dormant_accounts`, accounts with no transactions in the last `dormant_days` days (variable, default 2) as of the data date, materialized by Bruin. It must be rerun-safe. |
| R8 | Quality | Not null and unique on keys, accepted values on `band`, a custom check that the band counts in R4 add up to the account count in R3, and two unit tests on R3 and R5. At least one check must block downstream assets, and you must prove it by planting bad data. |
| R9 | Policy | A `policy.yml` that requires every asset in `lakota_risk` to have an owner, a description and at least one tag. `bruin validate` fails before you comply and passes after. |
| R10 | Marker | Last asset writes `lakota_risk` as `DONE` for the data date into `ctl.pipeline_status`. It runs only when everything before it succeeded. |
| R11 | Environments | The whole pipeline runs in a `dev` environment (separate database) with no code change, and a `data-diff` of dev and default for R3 is clean for the same date. |
| R12 | Operations | A scheduled-style run through `run_if_ready.sh` inside a window, a deliberate failure raising an alert through `run_and_alert.sh`, `ci_local.sh` passing, and generated docs. |

### The day loop and acceptance numbers

Reset to a clean state for each date so results are comparable:

```bash
bash "$COURSE/tools/reset.sh" warehouse
bash "$COURSE/tools/reset.sh" source 1
# run lakota for day 1, then lakota_risk for 2026-01-02 (the last date of day 1), then continue with days 2 and 3
```

The data dates are 2026-01-02 (after day 1), 2026-01-03 (after day 2) and 2026-01-04 (after day 3). Apply the source days with `reset.sh source 2` and `source 3` or the SQL scripts, run `lakota` for each date, then `lakota_risk`.

These numbers were computed directly from the CSV files with the deleted accounts removed, independent of Bruin:

| Snapshot date | Open accounts (R3) | LOW | MID | HIGH |
|---|---|---|---|---|
| 2026-01-02 | 83 | 7 | 31 | 45 |
| 2026-01-03 | 89 | 6 | 34 | 49 |
| 2026-01-04 | 92 | 5 | 36 | 51 |

If your pipeline reads the landing accounts instead of the full source copy, you get 90 on 2026-01-03 (LOW 7) and 94 on 2026-01-04 (LOW 6, HIGH 52). That difference is the two ghost accounts (1006 and 1025) and is exactly what R2 exists to prevent.

Large transactions (R5), absolute amount at least 1000, by transaction date:

| Transaction date | Rows |
|---|---|
| 2026-01-01 | 17 |
| 2026-01-02 | 15 |
| 2026-01-03 | 18 |
| 2026-01-04 | 24 |

Total after all three days: 74. With a threshold of 2000 the answer is 0 (the largest absolute amount in the data is 1496.19). Prove that your variable works by running with `--var large_txn_threshold=1400` and checking the count against a query you write yourself.

R6 has no preset number. Derive the expected row count with SQL over `risk.account_band_daily` (versions are runs of consecutive identical band and status per account) and compare it with the table.

R7 has no preset number. Write an independent SQL query for the same question and compare the account sets.

## 12.2 Build order (suggested)

Build in this order, validating and running after each step, and committing after each requirement:

1. Pipeline skeleton, connection, `pyproject.toml`, and the gate (R1). Test the gate with and without a marker.
2. R2, then R3 with the first date. Check the table against the numbers above.
3. R4, R5 and their quality checks (R8). Plant bad data to prove a blocking check stops downstream.
4. R6 and R7.
5. R10, R9, then R11.
6. R12 last, because it exercises everything.

Rules for yourself:

- Do not copy asset files from earlier modules. Open the modules for reference, then write from the docs. If you have to look at a module, write down what you looked up.
- Use `bruin render` before the first run of every SQL asset.
- Record every surprise in the log, however small.

## 12.3 The failure drills

Do all four on a real run, not on paper.

1. **Late upstream.** Start the consumer on a date for which `lakota` has not finished. Show the gate holding, then release it by running `lakota`. Time how long the consumer took to proceed after the marker appeared.
2. **Bad data.** Corrupt one source row so that a blocking check fails (for example, a balance of NULL, or a transaction with an unknown type, depending on your checks). Show that downstream assets are skipped, no marker is written, the alert fires, and the consumer's own downstream sees no marker. Then fix the source, resume with `bruin run --continue`, and show the marker appear.
3. **Rerun the same date.** Run the same date twice. Show row counts unchanged and the marker row updated, not duplicated.
4. **Skipped day.** Skip a date entirely, run the next date, then run the skipped one late. Show which tables handle this correctly and which do not. SCD2 (R6) is the one to look at: what does `_valid_from` mean for a late run?

## 12.4 Review checklist

Review your own work as if you were reviewing a colleague's pull request, then fill in the log.

| Check | Question |
|---|---|
| Idempotency | Does every asset produce the same result when its date is rerun? |
| Strategy choice | Would a different strategy be wrong or just different for each asset? |
| Deletes | Where could a source delete leave a ghost row? |
| Dates | Is any date computed from the clock instead of the run window? |
| Secrets | Is any credential in a file that will be committed? |
| Blocking | Which failures stop the marker and which do not? Is that deliberate? |
| Cost | Does any asset scan more data than its window? |
| Naming | Do names, tags and owners follow the policy you wrote? |
| Observability | If this fails at 03:00, what does the on-call person see, and what do they do? |
| Handover | Could a colleague operate it from the docs HTML and `DESIGN.md` alone? |

## 12.5 Breadth survey

These are short, deliberate tours. For each one, spend the time shown, write three lines in the log (what it is, whether you would use it at the bank, and what blocked you), and stop.

### VS Code extension (30 minutes)

Read `vscode-extension/overview.md`. Install the extension, open your repository, and use the lineage panel, the rendered query preview, snippets (`!fullsqlasset`) and the run buttons on one asset. Decide whether your team would standardise on it. Questions: does it work with Git Bash on your machine, and does it show asset metadata and quality checks as the docs describe?

### Policies (covered by R9)

Read the full `getting-started/policies.md`, including the list of built-in rules and the selectors. Which built-in rules would you turn on for the whole repository? Write the `policy.yml` for the bank's naming convention.

### Semantic layer (45 minutes)

Read `core-concepts/semantic-layer.md` and `commands/semantic.md`. Create `semantic/txn_summary.yml` at the repository root:

```yaml
schema: v1
name: txn_summary
label: Daily transaction summary
description: Transaction counts and amounts by day and type

source:
  table: mart.daily_txn_summary
  connection: lakota-pg

dimensions:
  - name: txn_date
    type: time
    granularities:
      day: date_trunc('day', txn_date)
      month: date_trunc('month', txn_date)
  - name: txn_type
    type: string

metrics:
  - name: txns
    expression: sum(txn_count)
  - name: amount
    expression: sum(total_amount)
  - name: avg_amount
    expression: "{amount} / {txns}"
```

```bash
bruin semantic validate
bruin query --pipeline lakota --connection lakota-pg --semantic-model txn_summary --dimension txn_type --metric txns --metric amount --sort txns:desc
```

With the warehouse at day 3, expected counts by type: PAYMENT 92, FEE 90, WITHDRAWAL 81, DEPOSIT 62 (325 in total). Try the month granularity (`--dimension txn_date:month`), add a segment, add a check with a known value, and run `bruin semantic check`. UNVERIFIED: the exact flags that work for your version. Decision: would the bank use a semantic layer, or is a governed mart enough? What problem does it solve that your marts do not?

### Glossary (15 minutes, beta)

Read `getting-started/glossary.md`. Write two entities with attributes that matter to the bank (Customer, Account). Decide whether this belongs in Bruin or in your data governance tool.

### AI features and governance (30 minutes)

Read `commands/ai-enhance.md`, `commands/ai-skills.md` and `getting-started/bruin-mcp.md`.

- `bruin ai enhance` calls an AI command-line tool (Claude Code, OpenCode or Codex) to add descriptions, checks and tags to assets, using the asset and database schema.
- `bruin ai skills` installs agent guidance files (`AGENTS.md` and bundled skills) into the repository.
- `bruin mcp` lets an AI agent query data, compare tables, ingest data and build pipelines through Bruin.

Do not run any of these against real bank data in this course. The governance questions are the exercise: what leaves the machine (schema, sample values, query results), who approves the tool and the model provider, what the agent can write or read under the credentials you give it, and whether a read-only connection is enough. Write the policy you would propose. The docs mention Windows users may need the full path to `bruin.exe` for the MCP configuration, which you can find with `which bruin` in Git Bash.

### Templates and `bruin init` (15 minutes)

Read `getting-started/templates.md`. List the templates your installed version offers (`bruin init --help`). Pick two that resemble your work and read their asset files for patterns worth borrowing. Do this in a scratch folder.

### Telemetry (5 minutes)

Read `getting-started/telemetry.md`. Bruin sends anonymous usage telemetry (version, OS, command and success or failure, asset type statistics) unless the environment variable `TELEMETRY_OPTOUT` is `true`. Decide whether the bank sets it, and where: the scheduled-task environment, the CI job, developer machines.

### Other platforms (10 minutes)

Skim the list in `platforms/` for anything the bank uses beside Snowflake. For each, note the asset type prefix, the sensors and the strategies it supports, using the platform support table in `assets/materialization.md`.

## 12.6 Concept map: DataStage and Netezza to Bruin

This table is the course author's mapping to help you plan the migration. It is not from the Bruin docs. Check each row against your own DataStage jobs and write what is different at the bank.

| DataStage or Netezza concept | Closest Bruin concept | What to check |
|---|---|---|
| Job | An asset (one output table) or a pipeline (a flow of assets) | Many DataStage jobs do several things; Bruin prefers one asset per output |
| Job sequence or sequencer | Pipeline with `depends` between assets | Conditional branches map to variables and `enabled`, not a graph of triggers |
| Sequence trigger and notification | Sensor, marker table, wrapper script | Module 9 and Module 11 |
| Parameter set, job parameters | Pipeline `variables`, `--var`, variants | Module 7 |
| Source stage (database, file) | ingestr asset or a source table | ingestr source support for your systems |
| Target stage (insert, upsert) | Materialization strategy | Which strategy matches each DataStage write mode |
| Transformer stage (derivations, constraints) | SQL `SELECT` or Python asset | Stage variables become CTEs |
| Lookup stage | A join | Reject links need an explicit anti-join and a quality check |
| Aggregator stage | `GROUP BY` | |
| Remove Duplicates stage | `ROW_NUMBER()` and a filter | Add a unique check |
| Change Capture, SCD stage | `scd2_by_column`, `scd2_by_time` | Module 8; check Snowflake support |
| Reject link and reject file | A quarantine table plus a blocking check | Decide what blocks and what only warns |
| Job log and monitoring | `logs/runs`, run wrapper, alert | Module 11 |
| Director schedule | External scheduler | Module 11 |
| Netezza external table or `nzload` | ingestr or a Snowflake stage | Outside the Bruin docs |
| Netezza distribution key, organize-on key | `cluster_by` or none on Snowflake | Platform specific, check the Snowflake docs |
| Netezza SQL | Snowflake SQL | Not covered by Bruin; plan a dialect review per object |

Pick your three most complex DataStage jobs. For each, write down which row of this table each stage maps to, and which stage has no row. The stages with no row are your risk list.

## 12.7 The operating plan

Take the table from 11.1 and your answers to 11.7 and write `OPERATING_PLAN.md` for the bank's first production pipeline. It must cover: which environment and credentials, how it is scheduled, what a late or missed run looks like and who sees it, how a failure is alerted and resumed, how a backfill is run, how changes get to production (pull request, checks, who approves), and what you would need from the platform team. Five to ten bullets per heading is enough.

## 12.8 What you should now be able to do

Check each box in your own words in the log. If you cannot, the module to revisit is in brackets.

- Build a pipeline from nothing and say what each file does [1].
- Land data incrementally and know exactly how the window is chosen [2].
- Pick a materialization for any table and justify it, including the first run [3].
- Run, select, resume and read the output of a pipeline [4].
- Write checks that block and ones that warn, plus unit tests [5].
- Write Python assets that read the run window and variables [6].
- Use variables, macros, hooks and variants without surprising yourself [7].
- Keep history and replay a date range [8].
- Make one pipeline wait for another without Bruin Cloud [9].
- Run the same code in several environments with credentials kept out of git [10].
- Run it in production, know when it fails and know what you do not have [11].

## Validation log

| Requirement | Pass / fail | Evidence (number, command, note) |
|---|---|---|
| Design note written before building | | |
| R1 gate holds, then releases | | |
| R2 full source copy lands, no ghost accounts | | |
| R3 counts 83 / 89 / 92 and band splits | | |
| R4 band summary matches R3, idempotent | | |
| R5 large transactions 17 / 15 / 18 / 24, variable override | | |
| R6 history rows match your independent query | | |
| R7 Python asset and independent comparison | | |
| R8 checks, unit tests, blocking proven | | |
| R9 policy fails then passes | | |
| R10 marker written only on full success | | |
| R11 dev run and clean data-diff | | |
| R12 polling run, alert, CI, docs | | |
| Drill 1 late upstream | | |
| Drill 2 bad data and resume | | |
| Drill 3 rerun same date | | |
| Drill 4 skipped day | | |
| Review checklist: worst finding | | |
| Survey: VS Code | | |
| Survey: semantic layer counts | | |
| Survey: AI governance note | | |
| Concept map: unmapped stages | | |
| Operating plan written | | |
| Time taken | | |
