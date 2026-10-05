# Bruin for Data Engineers: Building a Data Platform from Zero

Version 2 (revised 2026-10-05). Supersedes the original outline. See `Curriculum_Review_Notes.md` for what changed and why.

A project-based course for data engineers who know SQL and are new to Bruin. Every module extends one evolving banking analytics platform for a fictional institution ("Lakota Bank"), so each lesson, lab, and break/fix exercise reinforces the same codebase, dependency graph, and business entities.

**Design goals**

1. No Docker, no containers, no local services. Every lab runs from the Bruin CLI and a Git repository.
2. No paid account is needed to start. Modules 0-12, 14, 15 and the capstone run on a free local DuckDB database.
3. Snowflake remains the production target. Module 13 and the Snowflake path through the capstone use it.
4. Every lab verifies itself. A learner can tell whether they are correct without an instructor.
5. Works on Windows, macOS, and Linux with identical instructions wherever Bruin allows it.

**Target operating model:** Bruin CLI with Git.
**Local target:** DuckDB (free, file based, no account).
**Production target:** Snowflake.
**CI/CD reference implementation:** GitHub Actions (free for public repositories). Gitea Actions and GitLab CI appear as optional appendices.

---

# 1. Prerequisites and Required Software

## 1.1 Student Prerequisites

Required:

- Comfortable SQL: joins, aggregates, CTEs, and basic window functions. Roughly 6-12 months of regular use.
- Basic Git: clone, commit, branch, push.
- Ability to use a terminal.

Not required:

- Python experience. Modules 0-5 use no Python. Module 6 teaches the Python asset lifecycle and assumes only basic Python (functions, lists, dictionaries). A Python primer appendix covers the rest.
- Prior Snowflake, Kimball, or warehouse experience. Module 1 and Module 7 include short self-contained primers on the dimensional modeling and history concepts used later.

Advanced material (marked **[Advanced]**) assumes MERGE patterns and dimensional modeling and is skippable on the Core track.

## 1.2 Required Software

| Component | Required? | Purpose | Notes |
|-----------|-----------|---------|-------|
| Bruin CLI | Yes | Develop and run pipelines | Single install command. On Windows, run in Git Bash or WSL. |
| Git | Yes | Source control | Bruin itself requires Git. |
| Text editor | Yes | Editing assets | Any editor works. |
| VS Code + Bruin extension | Optional | Lineage view, rendered queries, autocomplete | Never required. Every lab gives CLI equivalents. |
| DuckDB | Bundled | Local warehouse | Used through Bruin connections. A standalone DuckDB CLI is optional for ad hoc queries (`bruin query` also works). |
| Python | Not required | Python assets | Bruin installs and manages Python versions and dependencies itself through uv. |
| Docker | Not required | n/a | Removed. Sources are simulated with files and SQLite. |
| Snowflake account | Module 13 only | Production target | 30-day trial with no credit card. Start it at Module 13, not earlier (see 1.4). |
| GitHub account | Module 14 only | CI/CD | Free. Local-only path provided. |

## 1.3 Ways to Take the Course

| Path | Accounts needed | Covers |
|------|-----------------|--------|
| Local (default) | None | Modules 0-12, 14 (local portion), 15, 16 on DuckDB |
| Local + GitHub | GitHub | Adds the live CI/CD labs in Module 14 |
| Full (Snowflake) | GitHub, Snowflake trial | Everything, including Module 13 and the Snowflake capstone variant |

Optional hosted-editor path (browser only, nothing installed locally): publish the repository with a dev-container or cloud-workspace configuration. Treat as optional and verify it works with Bruin before advertising it.

## 1.4 Snowflake Trial Timing

The Snowflake trial lasts 30 days from sign-up or until the free credit balance is used, and the account is suspended afterward. A 52-hour course taken at 5 hours per week would outlast a trial started on day one. Learners therefore build and test everything on DuckDB first and create the trial account at Module 13. Because the same assets run on both targets through Bruin environments, nothing is rewritten when the target changes.

Snowflake sign-in requirements change over time (multi-factor and key-pair authentication in particular). Module 13 includes a key-pair authentication walkthrough as the primary path so the course does not depend on password sign-in remaining available.

---

# 2. Enterprise Project Overview

## Business Scenario

Lakota Bank wants a modern analytics platform covering:

- Customer analytics
- Product analytics
- Profitability reporting
- Regulatory auditability
- Historical reconstruction
- Replayability

## Source Systems (simulated, no Docker)

All sources are synthetic, deterministic, and contain no real personal data. They are produced by a bundled **Source Simulator** that runs offline.

| Source | Simulated as | Entities |
|--------|--------------|----------|
| Core Banking | SQLite database file | Customers, Accounts, Transactions |
| CRM | SQLite database file | CRM Customers, Interactions |
| Flat Files | CSV files | Branches, Products |
| External API | JSON fixtures (offline default) with an optional live FX endpoint | FX Rates |
| Mortgage Platform (capstone) | SQLite database file | Loans, Payments, Borrowers |

Stretch entities (not required): Campaigns, Economic Indicators.

### Source Simulator requirements

- Deterministic from a seed value.
- Advances by one simulated business day on demand, so incremental loads, missed days, and replays are practiced against a moving source.
- Fault injection switches: late-arriving rows, duplicate rows, corrupted day, partial load, schema drift, deleted source rows.
- Runs with no network and no container.

---

# 3. Target Architecture

```text
Sources
    ↓
Landing
    ↓
Historical (_HIST)
    ↓
Integration (current state)
    ↓
SCD2 Dimensions (DIM_*)
    ↓
Reporting Marts (FACT_* and presentation views)
```

Naming rules used everywhere in the course:

| Layer | Schema | Naming | Examples |
|-------|--------|--------|----------|
| Landing | `landing` | `<source>_<entity>` | `core_customers`, `crm_interactions` |
| Historical | `hist` | `<entity>_hist` | `customers_hist`, `accounts_hist` |
| Integration | `integration` | `<entity>_current` | `customer_current`, `account_current`, `product_current` |
| SCD2 | `dim` | `dim_<entity>` | `dim_customer`, `dim_account` |
| Marts | `mart` | `fact_<subject>` | `fact_transactions`, `fact_customer_profitability` |

This resolves the original outline's inconsistency where `CUSTOMER_CURRENT` and `CUSTOMER_MASTER` named the same thing and `DIM_CUSTOMER` appeared in both the SCD2 and Mart layers. Dimensions belong to the SCD2 layer. The mart layer holds facts and presentation views that join to those dimensions.

## Layer Purposes

**Landing:** raw persistence of each extract. Topics: initial loads, incremental loads, late-arriving data, replay.

**Historical:** complete, append-oriented history for audit and reconstruction. Topics: full and incremental reloads, source count reconciliation, regulatory traceability.

**Integration:** current-state business entities. Topics: business keys, conformed entities, source standardization, golden records.

**SCD2:** versioned dimensions. Topics: initial load, new members, attribute change, late-arriving corrections, historical rebuild.

**Marts:** reporting structures. Topics: star schema, fact grain, dimension dependencies.

---

# 4. Complete Course Outline

| Module | Title | Duration | Needs Snowflake |
|--------|-------|----------|-----------------|
| 0 | Environment Setup | 1 h | No |
| 1 | Bruin Fundamentals | 2.5 h | No |
| 2 | Landing Layer Ingestion | 3.5 h | No |
| 3 | SQL Assets and Materialization | 4 h | No |
| 4 | Dependencies and Lineage | 2.5 h | No |
| 5 | Pipeline Design | 3 h | No |
| 6 | Python Assets | 3 h | No |
| 7 | Historical Layer Engineering | 4 h | No |
| 8 | Integration Layer | 3 h | No |
| 9 | SCD Type 2 Processing | 4 h | No |
| 10 | Data Quality Frameworks | 4 h | No |
| 11 | Sensors and Data-State Dependencies | 3.5 h | No |
| 12 | Replayability, Backfills, and Recovery | 4 h | No |
| 13 | The Snowflake Target | 3.5 h | Yes |
| 14 | Git-Based Deployment | 3 h | Optional |
| 15 | Operations and Production Support | 3 h | No |
| 16 | Enterprise Capstone | 8-16 h | Optional |

Core content total: about 52 hours, plus 8-16 hours for the capstone.

**What moved and why**

- Landing ingestion (old 4) now precedes SQL assets (old 3), because the old order asked learners to build `CUSTOMERS_HIST` before any data had been landed.
- Dependencies (old 6) moved up to Module 4. Every module after Module 1 uses `depends`, so teaching it late forced forward references.
- Python assets stay after the SQL and pipeline modules but before history, since the FX fetch and the simulator advance step use them.
- Data quality (old 11) moved ahead of sensors and replay. Sensors, recovery drills, and the CI gate all rely on checks.
- Snowflake becomes an explicit module (13) covering what is unique to the target.

---

# Module 0: Environment Setup (1 h)

**Objectives:** install Bruin and Git, clone the course repository, run the first command, choose a path from section 1.3.

**Lab**

1. Install Bruin with the documented one-line installer (Git Bash or WSL on Windows).
2. Clone the course repository.
3. Run `bruin --version` and `bruin validate` on the starter project.
4. Run the starter pipeline against the local DuckDB connection.

**Self-check:** `./check` (or the documented equivalent) prints a pass/fail list: Bruin found, Git found, DuckDB connection works, starter asset materialized.

**Break/fix:** the repository ships with `.bruin.yml` pointing at a missing path. Learners read the `bruin validate` error and repair it.

**Knowledge check**

1. Which file stores connections and environments?
2. Why is `.bruin.yml` excluded from source control, and how will CI get credentials later?
3. Why can two processes not write to the same DuckDB file at once?

---

# Module 1: Bruin Fundamentals (2.5 h)

**Objectives:** projects, pipelines, assets, environments, the CLI loop (`init`, `validate`, `run`, `lineage`, `query`).

**Project structure**

```text
project-root/
 ├── .bruin.yml          (credentials, git-ignored)
 └── <pipeline-name>/
      ├── pipeline.yml   (name, schedule, default connections, variables)
      └── assets/
```

**Primer:** the Kimball vocabulary used later (grain, fact, dimension, surrogate key, slowly changing dimension) in one page, with no outside book required.

**Lab:** create pipeline `scratch` with a seed asset (`hello_world` from a CSV) and one SQL asset that selects from it. Validate, run, query the result, view lineage.

**Break/fix:** a seed asset with a wrong `path`.

---

# Module 2: Landing Layer Ingestion (3.5 h)

**Objectives:** seed assets, ingestr assets, the landing architecture, and the Source Simulator.

**Lab:** build landing assets for every source:

- Core Banking (SQLite via ingestr): customers, accounts, transactions
- CRM (SQLite via ingestr): customers, interactions
- Flat files (seed assets or CSV via ingestr): products, branches
- External API: FX rates (the Python version arrives in Module 6; here use the JSON fixture as a seed)

**Topics:** full refresh versus incremental key, immutable snapshots, load metadata columns (`_loaded_at`, `_run_id`, `_source_file`).

**Expected outputs:** `landing.core_customers`, `landing.core_accounts`, `landing.core_transactions`, `landing.crm_customers`, `landing.crm_interactions`, `landing.ref_products`, `landing.ref_branches`.

**Self-check:** row counts match the simulator's manifest for day 1.

**Break/fix:** source connection name misspelled.

---

# Module 3: SQL Assets and Materialization (4 h)

**Objectives:** SQL asset anatomy, materialization strategies, incremental processing.

**Strategies covered** (verified against the Bruin docs, October 2026):

```text
create+replace     truncate+insert    append
delete+insert      merge              time_interval
ddl                scd2_by_column     scd2_by_time
```

Also: `table` versus `view` materialization types. `datavault_hub`, `datavault_link`, and `datavault_satellite` are documented as PostgreSQL and DuckDB only, so they appear as a short optional aside and are excluded from the Snowflake path.

Required fields per strategy (for example `primary_key` for merge, `incremental_key` plus `time_granularity` for `time_interval`) are taught as a lookup table learners fill in themselves.

**Lab:** build `hist.customers_hist` and `hist.accounts_hist` as first drafts using SQL assets over the landing tables, using at least three different strategies.

**Break/fix:** `merge` without `primary_key`.

---

# Module 4: Dependencies and Lineage (2.5 h)

**Objectives:** `depends`, asset graphs, parallel execution, `bruin lineage`, `--downstream` and `--workers`.

**Within-pipeline flow**

```text
extract → hist → validate → publish
```

**Parallelism**

```text
A ─┐
   ├─► C
B ─┘
```

**Lab:** declare the full dependency chain for the ingestion and history assets, view lineage, predict which assets run in parallel, confirm by running.

**Break/fix:** a circular dependency and a missing upstream.

---

# Module 5: Pipeline Design (3 h)

**Objectives:** pipeline structure, schedule syntax, default connections, variables, environments, reuse.

**Scheduling note:** the Bruin CLI defines a schedule in `pipeline.yml` but contains no scheduler. Something external triggers runs. The course uses a GitHub Actions cron trigger as the reference (Module 14) and names alternatives (Airflow, Bruin Cloud) without building on them.

**Lab:** split the project into four pipelines:

```text
ingest-core-banking    ingest-crm
ingest-flatfile        ingest-external-api
```

plus a shared `lib/` of reusable SQL macros or Python helpers.

**Break/fix:** invalid schedule syntax.

---

# Module 6: Python Assets (3 h)

**Objectives:** Python asset lifecycle, isolated environments and dependency files, secrets injection, DataFrame materialization.

**Facts taught** (verified in docs): Bruin runs Python assets in managed isolated environments using uv, so no local Python install or virtual environment management is needed. Dependencies come from `pyproject.toml` with `uv.lock` (preferred) or `requirements.txt`. Returned data (DataFrames, Arrow tables, lists of dicts, generators) is materialized by the asset's `materialization` block. Run dates arrive as environment variables (`BRUIN_START_DATE`, `BRUIN_END_DATE`).

**Lab:** build `fx_rates_fetch.py`:

1. Read FX rates from the live endpoint, falling back to the offline fixture when the network is unavailable.
2. Return a DataFrame or list of dicts.
3. Let Bruin materialize it into `landing.ref_fx_rates`.

**Break/fix:** wrong endpoint, then a missing secret. Learners diagnose HTTP failure versus authentication failure from the logs.

---

# Module 7: Historical Layer Engineering (4 h)

**Objectives:** historical persistence, auditability, reconciliation, reprocessing.

**Primer:** why append-oriented history differs from current state, with one worked example.

**Build:** `hist.customers_hist`, `hist.accounts_hist`, `hist.transactions_hist`, `hist.crm_customers_hist` (final versions, with count reconciliation checks against the simulator manifest).

**Reprocessing scenarios:** missed day, corrupted day, partial load.

**Lab:** turn on the simulator's late-arriving-data fault, observe the gap, reprocess successfully, show reconciliation passes.

---

# Module 8: Integration Layer (3 h)

**Objectives:** current-state entities, business key standardization, conformed entities, golden records.

**Build:** `integration.customer_current`, `integration.account_current`, `integration.product_current`.

**Lab:** merge CRM and Core Banking customer records into one golden record with documented survivorship rules (which source wins per attribute).

---

# Module 9: SCD Type 2 Processing (4 h)

**Objectives:** historical dimension design, versioning, late-arriving corrections, rebuilds.

**Build:** `dim.dim_customer`, `dim.dim_account` using `scd2_by_column` and compare against `scd2_by_time`. Bruin adds `_valid_from`, `_valid_until`, and `_is_current` automatically (verified in docs).

**Scenarios**

1. Initial load: Customer A has version 1.
2. Change: Customer A's email changes, version 2 is created and version 1 is closed.
3. Late-arriving correction: a change dated in the past arrives after later changes **[Advanced]**.

**Lab:** drop the dimension and rebuild it from scratch from history. Verify the version count and that exactly one current row exists per key.

---

# Module 10: Data Quality Frameworks (4 h)

**Objectives:** built-in checks, custom checks, blocking behavior, reusable conventions.

**Built-in column checks (verified):** `not_null`, `unique`, `accepted_values`, `positive`, `negative`, `non_negative`, `pattern`, `relationships`, `min`, `max`.

**Custom checks (verified):** SQL-based `custom_checks` with `name`, `query`, optional `value`, optional `count`, and a `blocking` flag (default true). Row-count, freshness, and schema-drift checks are written as custom SQL checks, not as separate built-in types.

**Severity model:** Bruin exposes blocking versus non-blocking. The course defines its three-level vocabulary on top of that:

| Course level | Bruin mechanism | Effect |
|--------------|-----------------|--------|
| Warning | `blocking: false` | Reported, downstream continues |
| Error | `blocking: true` | Downstream assets wait and do not run on failure |
| Critical | `blocking: true` plus a documented escalation step (for example CI fails and the on-call runbook applies) | Run stops and escalation is required |

**Reusable framework:** a library of parameterized check templates (SQL snippets generated from Jinja or a small Python generator) that learners reuse across assets. A `validation.py` that executes Python checks is **not** assumed to exist in Bruin. Whether Python-based checks are supported must be verified at build time (see the Prompt Guide). If unsupported, the framework uses SQL templates only.

**Lab:** apply the framework to every hist and integration asset. Add one warning check and one blocking check per layer.

**Unit tests:** introduce `bruin unit-test` (referenced in the CI docs) at a basic level.

---

# Module 11: Sensors and Data-State Dependencies (3.5 h)

**Objectives:** sensor assets, waiting on published data rather than scheduler success, cross-pipeline ordering.

**Sensors available** (verified): table and query sensors per platform, for example `duckdb.sensor.query`, `sf.sensor.table`, `sf.sensor.query`. Sensors accept `poke_interval` and `timeout` (default 24 hours). Sensor coverage differs per platform. Custom Python sensors are **not** documented, so the original outline's custom-sensor objective is removed pending verification.

**Required dependency chain** (generic names):

```text
core-banking-daily
      ↓
integration.processing_dates
      ↓
banking-integration
      ↓
customer-mart
```

**Why data-state matters**

Avoid depending on "the scheduler said success." Depend on "the data I need is published and valid." Benefits: replayability, resilience, failure isolation.

**Lab:** build a processing-date sensor that waits until `processing_dates` contains the target date, then releases the downstream pipeline.

**Open verification item:** cross-pipeline dependency syntax (the `uri` field and `depends` with `uri`) and which behaviors exist in the CLI versus Bruin Cloud. The documentation page for cross-pipeline dependencies could not be retrieved during review. Resolve before writing this module.

---

# Module 12: Replayability, Backfills, and Recovery (4 h)

**Objectives:** `bruin backfill` and `bruin run` date flags, historical reconstruction, incident recovery.

**Facts taught** (verified): `bruin backfill` is CLI-local, splits a range into partitions (`daily`, `weekly`, `monthly`, and others), is resumable, and supports `--max-parallel`, `--on-failure`, `--dry-run`, and `--continue`. `bruin run` supports `--start-date`, `--end-date`, `--full-refresh`, `--downstream`, `--only`, and `--continue`. Backfills require incremental-capable materializations (`append`, `merge`, `time_interval`) and idempotent logic.

**Scenarios** (each uses a simulator fault switch and a self-check):

1. Current table lost, rebuild from `_hist`.
2. SCD2 dimension dropped, rebuild from history.
3. Missing date (for example 2026-09-15), replay safely.
4. Corrupted mart, rebuild from lineage using `--downstream`.
5. Accidental delete in a source table, restore from history.

**Idempotency lab:** run each recovery twice and prove the second run changes nothing.

---

# Module 13: The Snowflake Target (3.5 h)

Requires a Snowflake trial account. Learners who skip this module continue on DuckDB.

**Objectives:** configure a Snowflake connection, promote the existing project to Snowflake through environments, understand target-specific behavior.

**Topics**

- Trial account setup and the 30-day clock.
- Connection fields (`account`, `username`, `database`, `warehouse`, `role`, and `region`, which the docs mark required) and key-pair authentication (generate key, register public key with `ALTER USER ... SET RSA_PUBLIC_KEY`, reference the key path).
- Environments: `default` on DuckDB, `snowflake-dev` and `snowflake-prod` as separate databases or schemas in one account, so a single trial supports dev and prod.
- Asset types: `sf.sql`, `sf.seed`, `sf.source`, `sf.sensor.table`, `sf.sensor.query`.
- Warehouse sizing, auto-suspend, and cost control for a trial.
- A minimal role model (loader, transformer, reader) as an introduction to RBAC **[Advanced]**.
- Dialect differences that bite when moving from DuckDB (identifier case, date functions, `QUALIFY`, semi-structured types).

**Lab:** run the full pipeline on Snowflake by changing only the environment flag. Fix the dialect differences found. Compare row counts between targets.

**Break/fix:** wrong role lacking privileges, then an expired or mismatched key.

---

# Module 14: Git-Based Deployment (3 h)

**Objectives:** branching, pull requests, environment promotion, CI gates, scheduled runs.

**Reference flow**

```text
feature/*  →  pull request  →  main  →  (tag or promotion)  →  production
```

The course recommends trunk-based flow with environment promotion rather than long-lived `staging` and `production` branches, because separate branches for each environment drift. A branch-per-environment variant appears in an appendix for teams that require it.

**CI with GitHub Actions** (documented setup action: `bruin-data/setup-bruin`):

```text
validate  →  unit-test  →  run in staging  →  run in production (manual approval)
```

**Credentials in CI:** `.bruin.yml` is generated at job time from repository secrets, never committed.

**Scheduled runs:** a GitHub Actions `schedule` trigger runs the pipeline on a cron, demonstrating how a Bruin schedule is realized without a built-in scheduler.

**Local-only path:** learners without GitHub simulate promotion with local branches and a `./promote` script that runs the same validate, test, and run steps.

**Appendices:** Gitea Actions and GitLab CI equivalents. These may require self-hosting and runners and are therefore optional.

---

# Module 15: Operations and Production Support (3 h)

**Objectives:** monitoring, triage, root cause analysis, incident response.

**Activities**

- Monitoring: pipeline health, data freshness (custom check), SLA compliance (measured from run logs and freshness checks, since the CLI has no built-in scheduler or SLA dashboard).
- Incident response loop: triage, diagnose, fix, deploy, backfill, document.
- Runbook and post-incident write-up templates.

**Lab:** complete incident simulation using the simulator's fault switches (a late source, a failing blocking check, a bad deploy). Output: a fixed platform, a completed backfill, and a short post-incident report.

---

# Module 16: Enterprise Capstone (8-16 h)

**Objective:** onboard a Mortgage Servicing system into the Lakota Bank platform.

**Requirements**

- Sources: Core Banking, CRM, Flat Files, External API, Mortgage Platform (simulated SQLite).
- Multiple pipelines with cross-pipeline data-state dependencies.
- Data quality: reusable framework, blocking checks, warning checks.
- SCD2: `dim_customer`, `dim_account`, `dim_mortgage`.
- Reporting: `fact_customer_profitability`, `fact_mortgage_profitability`.
- Backfill and historical rebuild demonstrated.
- Git deployment with a CI gate.
- Operations: a short runbook and one incident drill.

**Targets:** DuckDB (default) or Snowflake (full path).

**Automated acceptance:** a `capstone-check` suite (Bruin checks plus validation queries) verifies structure, row counts, SCD2 integrity, and recoverability, so learners can self-grade. Rubric items that need judgment (architecture, documentation) use a published checklist.

| Area | Weight |
|------|--------|
| Architecture | 10% |
| Assets | 15% |
| Dependencies | 15% |
| SCD2 | 15% |
| Data Quality | 15% |
| Replayability | 15% |
| Git Workflow | 10% |
| Documentation | 5% |

---

# Assessment Strategy

Every module has four parts: a knowledge check, a hands-on lab, an automated self-check, and a break/fix exercise.

- **Mid-course practical (after Module 9):** repair a provided broken platform. The fixture contains at least eight faults that `bruin validate`, run logs, or checks reveal.
- **Operations drill (Module 15):** diagnose, repair, and replay.
- **Capstone:** weighted rubric above.

Each module ships `starter` and `solution` Git tags so a learner who falls behind can restart from a known good state.

---

# Fast-Track Options

**Fast-Track A: Engineer Productivity** (about 32 h)
Modules 0, 1, 2, 3, 4, 6, 9, 10, 11, 12.

**Fast-Track B: Architect / Lead** (about 41 h)
Modules 0, 1, 4, 5, 7, 8 (overview), 9, 10, 11, 12, 13, 14, 15. Emphasis on dependency design, data-state contracts, governance, recovery, deployment, and operations.

Hours recomputed from the module table above; recheck when module durations change.

---

# Accessibility and Inclusion Standards

- Text-first lessons in Markdown. No video required for any lab.
- Every command shown for Git Bash/Linux/macOS. Windows differences called out inline.
- Plain language, defined terms on first use, and a glossary.
- No meaning conveyed by color alone in diagrams; diagrams have text equivalents.
- Time estimates per section and clear stopping points.
- Offline-capable after installation (simulator, fixtures, DuckDB).
- No real personal or financial data anywhere.
- Free by default. Costs and trial limits stated before they apply.

---

# Recommended References

**Bruin:** official Bruin documentation (CLI, assets, materialization, sensors, quality checks, backfill).
**Snowflake:** Snowflake documentation, trial account guide, key-pair authentication guide.
**Git:** Pro Git (free online).
**Data engineering:** The Data Warehouse Toolkit (optional, the course is self-contained), DataTalksClub Data Engineering Zoomcamp.

---

# Final Learning Outcomes

Learners will be able to:

1. Design Bruin project structures.
2. Build multi-pipeline solutions.
3. Implement asset and cross-pipeline dependencies.
4. Build SQL, Python, seed, ingestr, and sensor assets.
5. Build data quality controls and a reusable check library.
6. Debug failures from logs and checks.
7. Execute backfills and reconstruct history.
8. Implement SCD2 processing.
9. Analyze lineage.
10. Deploy through Git workflows with CI gates.
11. Promote a project from a local target to Snowflake.
12. Operate and support a Bruin platform in production.

---

# Appendix A: Platform Facts and Verification Status

Verified means read in the official Bruin or Snowflake documentation on 2026-10-05. Items marked Verify must be confirmed hands-on before the related module is written.

| Claim | Status |
|-------|--------|
| Bruin installs with one command on macOS, Linux, Windows (Git Bash or WSL); Git required; Docker not required | Verified |
| Python assets run in uv-managed isolated environments, no local Python needed | Verified |
| Materialization strategies listed in Module 3, with scd2 support on Snowflake and DuckDB | Verified |
| Ten built-in column checks; custom SQL checks with `blocking` flag | Verified |
| Sensors exist for Snowflake and DuckDB (`sf.sensor.*`, `duckdb.sensor.query`) | Verified |
| `bruin backfill` is CLI-local and resumable | Verified |
| No built-in scheduler in the CLI | Verified (docs describe external orchestration) |
| GitHub Actions setup action `bruin-data/setup-bruin`; `bruin validate`, `bruin unit-test` | Verified |
| ingestr supports `sqlite://` and `csv://` sources | Verified |
| Snowflake trial: 30 days or until credits are used, no credit card, suspended at expiry | Verified |
| Ingestr assets run without Docker on a clean Windows, macOS, and Linux machine | Verify |
| Cross-pipeline dependency syntax and CLI versus Cloud behavior | Verify |
| Python-based custom checks or custom Python sensors | Verify (not documented; assume absent) |
| Daily-partitioned file or SQLite extracts through ingestr with run-date templating | Verify |
| Snowflake sign-in rules for new trial accounts (MFA, key-pair, tokens) | Verify |
| Free live FX endpoint availability and terms | Verify |
| Hosted browser workspace compatibility | Verify |
