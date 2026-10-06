# Bruin for Data Engineers: Building a Data Platform from Zero

Version 3.0 (revised 2026-10-05). Supersedes v2.1. See `Curriculum_Review_Notes.md` for what changed and why. The source requirements for this course are in `Curriculum_Planning_Prompt.md`; where this outline and that prompt differ, the prompt states the intent and this outline states how it is met. The hosted platform that delivers this course is specified in `Hosted_Platform_Build_Spec.md`.

A project-based, hosted course for data engineers who know SQL and are new to Bruin. Every module extends one evolving banking analytics platform for a fictional institution ("Lakota Bank"), so each lesson, lab, and break/fix exercise reinforces the same codebase, dependency graph, and business entities.

**Design goals**

1. Browser only. Learners install nothing. They open a hosted VS Code environment that already contains Bruin, uv, Git, Postgres, DuckDB, SQLite, the Source Simulator, and the course lessons. Containers exist only inside the operator's infrastructure and are never visible to learners.
2. Paid and inexpensive. The course is a low-priced paid service, so the operator provides the compute. No learner needs an outside account for any module. GitHub is optional in Module 14.
3. Fully self-contained. Every source system and every target runs inside the learner's environment: Postgres, SQLite, DuckDB, flat files, a mock API, and a Vendor Feed. Real external sources appear only as optional extras.
4. Postgres is the primary warehouse from Module 2 onward. DuckDB serves the first-run exercises (Modules 0 and 1), a Module 3 engine-comparison lab, and local file analytics. SQLite and Postgres serve as sources. Snowflake is not required anywhere. Module 13 covers cloud-warehouse porting as an optional module that needs no account.
5. Every lab verifies itself. A learner can tell whether they are correct without an instructor.
6. Conditional execution is a first-class topic. Pipelines often must run only when conditions in the data are met, and many sources are generic (files, vendor feeds, status tables, web endpoints) with no official Bruin connector. The course teaches native sensors where Bruin has them and **custom Python sensors** where it does not.
7. Accessible by design (see the standards at the end of this document).

**Target operating model:** Bruin CLI with Git, inside a hosted VS Code environment.
**Primary warehouse:** Postgres.
**Supporting engines:** DuckDB (first-run exercises, engine comparison, local file analytics), SQLite (source system).
**CI/CD:** a built-in `make ci` pipeline in the environment for every learner. GitHub Actions appears as an optional lab for learners who bring their own GitHub account.

---

# 1. Prerequisites and the Learning Environment

## 1.1 Student Prerequisites

Required:

- Comfortable SQL: joins, aggregates, CTEs, and basic window functions. Roughly 6-12 months of regular use.
- Basic Git: clone, commit, branch.
- Ability to use a terminal at a basic level.
- A modern browser and a stable internet connection.

Not required:

- Deep Python experience. Modules 0-5 use no Python. Module 6 teaches the Python asset lifecycle and assumes basic Python (functions, lists, dictionaries, exceptions). Modules 10 and 11 (Python quality gates and custom Python sensors) use Python more heavily, so a Python primer appendix covers file handling, HTTP requests, retries, and exit behavior.
- Prior Postgres, Snowflake, Kimball, or warehouse experience. Module 1 and Module 7 include short self-contained primers on the dimensional modeling and history concepts used later.
- Any software installation, any cloud account, or any credit card beyond the course purchase.

Advanced material (marked **[Advanced]**) assumes MERGE patterns and dimensional modeling and is skippable on the Core track.

## 1.2 What Is Inside the Environment

Every learner gets a private, persistent Linux workspace opened in a browser. Versions are pinned and recorded in the course repository.

| Component | Purpose | Notes |
|-----------|---------|-------|
| VS Code (web) | Editor, terminal, file explorer | Includes the Bruin extension if it can be installed in the hosted editor (verify), and the course runner panel (lessons, Check, Hint, Reset). |
| Bruin CLI | Develop and run pipelines | Version pinned. |
| uv and cached Python versions | Python assets, sensors, checks | Bruin manages Python environments through uv. Interpreters and packages are pre-cached, so labs need no internet. |
| Git | Source control | Local repository with a local `origin` for branch and review exercises. |
| Postgres | Primary warehouse and two source databases | Runs inside the workspace. Roles, schemas, and several databases are pre-created. |
| DuckDB | Local analytics and early modules | Single-writer, single-process file engine (see Module 0 knowledge check). |
| SQLite | Mortgage source system | File based. |
| Source Simulator and mock API | Deterministic sources with fault injection | Section 2. |
| Self-check scripts | Automated verification | One per module step. |

Learner-side requirements: a browser and a connection. Everything else is provided.

## 1.3 How the Environment Behaves

- **Persistence.** Files, Git history, and database state persist between sessions. Idle workspaces stop automatically and resume where the learner left off.
- **Resets.** A learner can reset any step to its known-good starter state, which restores files, the database state, and the simulator clock. Learner changes are saved to a branch first.
- **Export.** A learner can download their work (a Git bundle and database dumps) at any time, so the work is theirs.
- **Fair-use limits.** Monthly environment hours and idle timeouts are published before purchase.
- **Offline-first inside the environment.** No lab depends on an outside service. Optional labs that do are marked.

## 1.4 Engine Roles

| Engine | Role | Why |
|--------|------|-----|
| Postgres | Source databases (core banking, CRM) and the warehouse | A real server database with concurrent writers, roles, and grants. Pipelines and sensors can run at the same time without file locks. Bruin documents `pg.sql`, `pg.seed`, `pg.sensor.table`, `pg.sensor.query`, and `pg.source`, and supports `merge`, `scd2_by_column`, `scd2_by_time`, and the Data Vault strategies on Postgres. |
| DuckDB | First-run exercises (Modules 0 and 1), a Module 3 engine-comparison lab, local analytics on Parquet and CSV files | Fast to start. Bruin's docs state that DuckDB does not allow concurrency between processes, which makes it a poor fit for sensors and parallel pipelines. |
| SQLite | Mortgage source | A different source engine, read through ingestr. |

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

## Source Systems (simulated, inside the environment)

All sources are synthetic, deterministic, and contain no real personal data. They are produced by a bundled **Source Simulator** and a **mock API** that run inside the learner's environment.

| Source | Simulated as | Entities |
|--------|--------------|----------|
| Core Banking | Postgres database `src_core_banking` | Customers, Accounts, Transactions |
| CRM | Postgres database `src_crm` | CRM Customers, Interactions |
| Flat Files | CSV files in a drop folder | Branches, Products |
| External API | Mock REST API service with pagination, authentication, rate limits, and fault switches (optional real public API as a stretch) | FX Rates |
| Mortgage Platform (capstone) | SQLite database file | Loans, Payments, Borrowers |
| Vendor Feed (generic source, no Bruin connector) | Drop folder of files with a manifest or status file, plus a status table | Daily statement and settlement files, a completeness flag, a vendor run status |

The Vendor Feed exists to teach custom Python sensors. It models the common case of a generic source whose readiness depends on conditions in the data: a file has arrived, the file has stopped growing, the row count meets a threshold, the maximum business date equals the processing date, a status flag says COMPLETE, or a checksum matches the manifest.

Stretch entities (not required): Campaigns, Economic Indicators.

### Source Simulator requirements

- Deterministic from a seed value.
- Advances by one simulated business day on demand, writing inserts, updates (with `updated_at` values), and deletes to the source databases, so incremental loads, missed days, and replays are practiced against a moving source.
- Fault injection switches: late-arriving rows (backdated `updated_at`), duplicate rows, corrupted day, partial load, schema drift, deleted source rows. Each is documented, reversible, and recorded in the manifest.
- Mock API controls: return HTTP 500 or 429, slow responses, expired credentials, pagination changes, schema drift.
- Vendor Feed controls: delay a file's arrival, deliver a file in growing chunks, deliver an empty or under-threshold file, flip the completeness flag late, deliver a checksum mismatch, deliver a prior day's file by mistake.
- A simulated clock that sensors and schedulers can read, so waiting scenarios finish in seconds.
- A per-day manifest of true row counts and checksums, used by self-checks.
- Runs entirely inside the environment with no outside network.

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

| Module | Title | Duration | Required |
|--------|-------|----------|----------|
| 0 | Environment Tour and First Run | 1 h | Yes |
| 1 | Bruin Fundamentals | 2.5 h | Yes |
| 2 | Landing Layer Ingestion | 3.5 h | Yes |
| 3 | SQL Assets and Materialization | 4 h | Yes |
| 4 | Dependencies and Lineage | 2.5 h | Yes |
| 5 | Pipeline Design | 3 h | Yes |
| 6 | Python Assets | 3 h | Yes |
| 7 | Historical Layer Engineering | 4 h | Yes |
| 8 | Integration Layer | 3 h | Yes |
| 9 | SCD Type 2 Processing | 4 h | Yes |
| 10 | Data Quality Frameworks | 4.5 h | Yes |
| 11 | Sensors, Custom Python Sensors, and Data-State Dependencies | 5 h | Yes |
| 12 | Replayability, Backfills, and Recovery | 4 h | Yes |
| 13 | Cloud Warehouses and Porting | 3 h | Optional |
| 14 | Git-Based Deployment | 3 h | Yes |
| 15 | Operations and Production Support | 3 h | Yes |
| 16 | Enterprise Capstone | 8-16 h | Yes |

Core content total: about 53 hours including optional Module 13, plus 8-16 hours for the capstone.

**What moved and why**

- Landing ingestion (old 4) now precedes SQL assets (old 3), because the old order asked learners to build `CUSTOMERS_HIST` before any data had been landed.
- Dependencies (old 6) moved up to Module 4. Every module after Module 1 uses `depends`, so teaching it late forced forward references.
- Python assets stay after the SQL and pipeline modules but before history, since the FX fetch and the simulator advance step use them.
- Data quality (old 11) moved ahead of sensors and replay. Sensors, recovery drills, and the CI gate all rely on checks. Custom Python sensors and Python checks stay in the course as required content and gained time (Module 10 grew to 4.5 h, Module 11 to 5 h).
- The Snowflake module became an optional cloud-warehouse porting module (13). Postgres replaced DuckDB as the platform warehouse from Module 2 onward, which also lets sensors and parallel pipelines run together (Modules 5, 11, 12, 14).

---

# Module 0: Environment Tour and First Run (1 h)

**Objectives:** open the hosted environment, learn the layout (lesson pane, editor, terminal, Check, Hint, Reset), run the first Bruin commands, and learn what persists.

**Lab**

1. Open the environment and complete the guided tour.
2. Run `bruin --version` and `bruin validate` on the starter project.
3. Run the starter pipeline against DuckDB, then against Postgres, and compare the connection settings.
4. Use Check, then Reset a step, then export your work.
5. Turn on the accessibility options (screen-reader mode for the terminal, high contrast, font size).

**Self-check:** reports Bruin found, Git found, Postgres reachable, DuckDB connection works, starter asset materialized.

**Break/fix:** the starter project's `.bruin.yml` names a connection that does not exist. Learners read the `bruin validate` error and repair it.

**Knowledge check**

1. Which file stores connections and environments?
2. Why is `.bruin.yml` excluded from source control in a real project, and where do credentials come from in the hosted environment?
3. Why can two processes not write to the same DuckDB file at once, and which engine does the course use when two pipelines must run together?

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

- Core Banking (Postgres source database via ingestr, incremental on `updated_at`): customers, accounts, transactions
- CRM (Postgres source database via ingestr): customers, interactions
- Flat files (seed assets or CSV via ingestr): products, branches
- External API: FX rates (the Python version arrives in Module 6; here load the JSON fixture as a seed)
- Mortgage (SQLite via ingestr) appears in the capstone; a short demonstration here shows a second source engine

**Topics:** full refresh versus incremental key, immutable snapshots, load metadata columns (`_loaded_at`, `_run_id`, `_source_file`).

**Raw file archive:** the planning requirement is "raw immutable history stored in files and loaded into history tables." Each simulated day's extract is written once to an append-only `data/landing/<source>/<yyyy-mm-dd>/` archive that is never edited. Loads read from the archive, so any day can be replayed byte for byte. The exact extract-and-load mechanism is decided in the Phase A spike (see the Prompt Guide).

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

Also: `table` versus `view` materialization types. `datavault_hub`, `datavault_link`, and `datavault_satellite` are documented as PostgreSQL and DuckDB only, so they run on the course warehouse. They appear as a short optional **[Advanced]** aside (hub, link, and satellite for customers and accounts).

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

**Scheduling note:** the Bruin CLI defines a schedule in `pipeline.yml` but contains no scheduler. Something external triggers runs. The environment ships a small scheduler harness that triggers pipelines on their cron schedule against the simulated clock, standing in for an external orchestrator so labs finish in seconds. Module 14 explains real orchestrators (CI schedulers, Airflow, Bruin Cloud) without building on them.

**Environments:** define Bruin environments `default` (dev), `staging`, and `production`, each pointing at a different Postgres database in the same environment.

**Lab:** split the project into four pipelines:

```text
ingest-core-banking    ingest-crm
ingest-flatfile        ingest-external-api
```

plus a shared `lib/` of reusable SQL macros or Python helpers.

**Break/fix:** invalid schedule syntax.

---

# Module 6: Python Assets (3 h)

**Objectives:** Python asset lifecycle, isolated environments and dependency files, secrets injection, DataFrame materialization, shared libraries in `lib/`, and failure semantics (how a raised exception or non-zero exit fails the asset and blocks downstream assets). The failure semantics lesson is the foundation for Modules 10 and 11.

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

# Module 10: Data Quality Frameworks (4.5 h)

**Objectives:** built-in checks, custom checks, blocking behavior, reusable conventions.

**Built-in column checks (verified):** `not_null`, `unique`, `accepted_values`, `positive`, `negative`, `non_negative`, `pattern`, `relationships`, `min`, `max`.

**Custom SQL checks (verified):** `custom_checks` with `name`, `query`, optional `value`, optional `count`, and a `blocking` flag (default true). Row-count, freshness, and schema-drift checks are written as custom SQL checks. They are taught as the "row count, freshness, and schema validation" tier the planning prompt calls for.

**Custom Python checks (course pattern):** Bruin documents SQL custom checks but no Python check type. The course builds Python checks as a **Python quality-gate asset**: a Python asset that sits in the dependency graph between a built asset and its consumers, runs checks that SQL expresses poorly (cross-source reconciliation, file-versus-table comparison, statistical drift, calls to external references), writes every result to a `dq_results` table, and raises an exception to fail the asset when a blocking rule fails. Downstream assets that `depends` on the gate do not run. Phase A must confirm the failure and blocking behavior and look for any native Python check support before this module is written.

**Severity model:** Bruin exposes blocking versus non-blocking for checks, and failed assets block downstream. The course defines its three-level vocabulary on top of that:

| Course level | Mechanism | Effect |
|--------------|-----------|--------|
| Warning | SQL check with `blocking: false`, or a Python gate rule that logs and records without raising | Recorded and alerted, downstream continues |
| Error | SQL check with `blocking: true`, or a Python gate rule that raises | Downstream assets do not run |
| Critical | Error behavior plus a documented escalation step (for example the CI job fails, the alert pages the on-call, and the runbook applies) | Run stops and escalation is required |

**Reusable framework:** `lib/validation.py` plus a library of parameterized SQL check templates. The Python library provides: rule definitions, a severity enum, a runner that records results to `dq_results`, a standard exception that Bruin sees as a failed asset, and helpers for the reconciliation patterns used in Modules 7 to 9.

**Failure handling and alerting patterns:** retries and cooldown settings on assets, quarantine tables for rejected rows, notify-and-continue versus stop-the-line, and alert hooks. Native Bruin notification support appears tied to Bruin Cloud in the documentation; Phase A must confirm what the CLI supports. The default course pattern is CI or scheduler failure notification plus a small alert helper in `lib/` that posts to a webhook when configured and writes to the `dq_results` table either way.

**Operational dashboard:** SQL views over `dq_results` and a `run_log` table (check pass rates, failures by layer, freshness by table, open warnings). The lab builds the views and a plain-text report script. A rendered dashboard is optional and tool-agnostic.

**Lab:** apply the framework to every hist and integration asset. Add one warning and one blocking rule per layer, including at least one Python gate rule. Then break the data with simulator faults and show each severity behaves as designed.

**Unit tests:** introduce `bruin unit-test` (referenced in the CI docs) at a basic level.

---

# Module 11: Sensors, Custom Python Sensors, and Data-State Dependencies (5 h)

**Objectives:** native sensor assets, custom Python sensors for generic sources, control and publication tables, waiting on published data rather than scheduler success, cross-pipeline ordering.

## Part A: Native sensors (about 1.5 h)

**Verified:** sensors are implemented per platform. For Postgres, the docs list `pg.sensor.table` and `pg.sensor.query`, which poll every 30 seconds by default. DuckDB has `duckdb.sensor.query`. Sensors accept `poke_interval` (seconds) and `timeout` (default 24 hours), and quality checks can run on a sensor after it succeeds. Coverage differs per platform. The course uses Postgres sensors so that a sensor can poll the warehouse while the upstream pipeline is still writing to it, which a single-process DuckDB file does not allow.

**Required dependency chain** (generic names):

```text
core-banking-daily
      ↓
ctl.processing_dates
      ↓
banking-integration
      ↓
customer-mart
```

**Why data-state matters:** depend on "the data I need is published and valid," not on "the scheduler said success." Benefits: replayability, resilience, failure isolation. A replayed or backfilled date can pass the same gate, and an upstream rerun does not trigger downstream work by accident.

**Control and publication tables:** `ctl.processing_dates` (one row per business date with status and the run that published it) and `ctl.publication_log` (what was published, row counts, checksums, timestamp). A pipeline's last step publishes to these tables only after its own checks pass. Downstream pipelines wait on them.

**Lab A:** a native SQL sensor that waits until `ctl.processing_dates` contains the target date with status PUBLISHED, then releases `banking-integration`.

## Part B: Custom Python sensors (about 3 h)

**Why they exist:** pipelines often must run only when conditions in the data are met, and many sources are generic: file drops, vendor feeds, status tables in systems without a Bruin connector, web endpoints, SFTP-style locations. Native sensors cover platform tables and queries. Everything else needs a sensor the team writes.

**Status of the feature:** Bruin documents native sensors per platform and does not document a Python sensor type. The course therefore teaches custom Python sensors as a **design pattern built on documented Python assets**: a Python asset placed in the graph so that downstream assets declare `depends` on it. It succeeds when the condition is met and fails (raises) when it is not met by the timeout, so downstream assets do not run. Phase A confirms the exact failure and blocking behavior, and whether Bruin offers any native hook that improves on this pattern.

**The sensor contract** (implemented once in `lib/sensors.py`):

- `check(run_date) -> Result(ready: bool, observed: dict, reason: str)`: a side-effect-free evaluation of one condition.
- `poke_interval` and `timeout`, mirroring native sensor parameters, so learners reuse one mental model.
- Run-date awareness through `BRUIN_START_DATE` and `BRUIN_END_DATE`, so replays and backfills evaluate the right date.
- A final control-table write recording what was observed (evidence), whether the sensor passed or timed out.
- Distinct messages for "not ready yet" and "source is broken," so on-call can tell them apart.

**Condition library built in the labs** (all against the Vendor Feed and status table):

| Condition | Example |
|-----------|---------|
| Arrival | Today's settlement file exists in the drop folder |
| Stability | File size and modified time unchanged across two pokes (the file is no longer being written) |
| Completeness flag | Vendor status row reads COMPLETE for the business date |
| Row threshold | Row count is at least 95 percent of the trailing 7-day average |
| Business date | Maximum business date in the file equals the processing date |
| Integrity | File checksum equals the checksum in the manifest |
| Composite | Arrival AND stability AND integrity AND completeness |
| Optional web endpoint | A JSON status document reports ready (uses a recorded fixture offline) |

**Three implementation patterns compared:**

1. **In-process polling gate.** The asset loops, sleeping `poke_interval`, until ready or `timeout`. Simple, one log, but holds a worker while waiting.
2. **Retry-based gate.** The asset checks once and raises if not ready, relying on Bruin's documented `retries` and `rerun_cooldown` asset settings to re-attempt. No long-held worker, but noisier logs and a retry budget to size.
3. **Pre-flight gate.** The scheduler or CI job runs the sensor logic first and starts `bruin run` only when it passes. Keeps long waits outside Bruin, at the cost of logic living outside the dependency graph.

Learners build pattern 1, then convert to pattern 2, and then discuss pattern 3 trade-offs. Phase A verifies the behavior of `retries`, `rerun_cooldown`, and `timeout` on Python assets.

**Conditional execution without failing the run:** a gate that fails creates a failed run and an alert, which is correct for "the vendor is late" but noisy for "nothing to do today." The course teaches the options: fail on timeout (stop the line), succeed with a recorded NOT_READY status that a blocking SQL check on the control table turns into a clean stop for downstream assets, or skip through a documented Bruin mechanism if Phase A finds one. The course states clearly which option each scenario should use.

**Design rules taught:** bounded timeouts always, idempotent checks, never mutate the source, never treat "file exists" as "file complete," record evidence, keep secrets in connections or secret injection, test sensor logic as plain Python without running Bruin (the logic lives in `lib/`), and log enough to explain a decision after the fact.

**Labs**

- **Lab B1:** file-arrival sensor with a stability check. Run it while the simulator delays the file, and while it delivers the file in growing chunks.
- **Lab B2:** data-condition sensor using row threshold plus business date plus checksum.
- **Lab B3:** wire the Vendor Feed sensor into a pipeline so downstream assets run only after the sensor passes, then prove it: advance the simulator with the file late, observe the wait, release the file, observe the run proceed.
- **Lab B4:** convert the polling gate to the retry-based gate and compare logs and runtime.
- **Lab B5:** plain-Python unit tests for every condition in the library.

**Break/fix scenarios**

1. The sensor passes on yesterday's file left in the drop folder (missing business date condition).
2. The sensor releases on a half-written file (missing stability and integrity conditions).
3. The sensor has no timeout and blocks a worker indefinitely.
4. The sensor fails with a stack trace instead of a clear "not ready" message, and on-call cannot tell a late vendor from a bug.
5. The control table was updated before checks passed, so a downstream pipeline consumed unvalidated data.

**Open verification item:** cross-pipeline dependency syntax (the `uri` field and `depends` with `uri`) and which behaviors exist in the CLI versus Bruin Cloud. The documentation page could not be retrieved during review. Resolve in Phase A before this module is written. If the CLI cannot make a pipeline wait on another pipeline directly, the control-table sensor pattern above is the primary mechanism, which is also the planning prompt's intent.

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

# Module 13: Cloud Warehouses and Porting (3 h, optional)

No outside account is required to complete this module or the course. It teaches what changes when the platform moves from Postgres to a cloud warehouse, using Snowflake as the worked example because Bruin documents it well and many employers use it.

**Objectives:** understand the differences that matter when porting, and be able to read and adapt a Bruin project for a cloud target.

**Topics**

- Connection configuration shape for a cloud warehouse (account, user, database, warehouse, role, region) and key-pair authentication concepts.
- Environments mapped to databases or schemas, and how `default`, `staging`, and `production` translate.
- Asset types per platform (`sf.sql`, `sf.seed`, `sf.source`, `sf.sensor.table`, `sf.sensor.query`) and the materialization support Bruin documents for Snowflake (including `merge`, `scd2_by_column`, and `scd2_by_time`).
- Compute and cost: virtual warehouses, auto-suspend, credit budgeting, and why a retry loop in a sensor can be expensive.
- RBAC translation: Postgres roles and grants compared with Snowflake roles, grants, and role hierarchy **[Advanced]**.
- Dialect differences: identifier case, date functions, `QUALIFY`, semi-structured types, sequences, and procedural code.

**Labs (no account needed)**

- **Dialect worksheet:** translate ten of the course's SQL assets to Snowflake dialect. A checker compares against the answer key and flags unsupported constructs.
- **Port plan:** write a one-page port plan for the Lakota Bank platform covering connections, environments, roles, materialization changes, cost controls, and a cutover and rollback approach.
- **Read the config:** given a sample cloud-warehouse `.bruin.yml` and a project, identify the five mistakes that would fail `bruin validate` or a run.

**Optional bring-your-own-account lab (later release):** a learner with their own warehouse account runs a pipeline against it from the environment. This requires outbound network access to that provider and careful handling of private keys, so it is off by default and tracked as a post-launch feature in the platform spec.

**Break/fix:** a project ported with Postgres-only syntax in a Snowflake-targeted asset.

---

# Module 14: Git-Based Deployment (3 h)

**Objectives:** branching, pull requests and code review, environment promotion, release management, rollback, CI gates, scheduled runs.

**Reference flow**

```text
feature/*  →  review  →  main  →  staging  →  production
```

The course recommends trunk-based flow with environment promotion rather than long-lived `staging` and `production` branches, because separate branches for each environment drift. A branch-per-environment variant appears in an appendix.

**Built-in CI in the environment:** `make ci` runs the same sequence a hosted CI system would:

```text
bruin validate  →  bruin unit-test  →  run in staging database  →  run checks  →  promote to production database
```

Promotion targets are separate Postgres databases (`wh_staging`, `wh_prod`) selected through Bruin environments. Credentials stay in the environment's `.bruin.yml`, which is never committed.

**Pull request review without a forge:** the environment includes a local `origin` and a review exercise pack. Learners review provided diffs against a checklist, then submit their own change for an automated review (the self-check applies the checklist rules).

**Code review checklist for data platforms:** `bruin validate` and `bruin unit-test` pass, lineage change reviewed, materialization and key changes called out, new checks and severity levels justified, backfill impact stated, sensors have bounded timeouts, no secrets in the diff.

**Release management:** version tags, a changelog, and a release note that states which tables change shape and whether a backfill is required.

**Rollback strategies:** Git revert and redeploy; rebuild affected layers from `_hist` (Module 12); restore a database from a snapshot or template clone taken before the release; restore a table from history using a pinned run date. Each strategy states what it can and cannot undo, and a lab practices a bad deploy followed by rollback.

**Real orchestration (reading and optional lab):** Bruin's docs describe a GitHub Actions setup action (`bruin-data/setup-bruin`) and external schedulers such as Airflow. The optional lab uses the learner's own GitHub account and requires outbound access to GitHub from the environment (off by default, allowlisted when enabled). The lab converts the `make ci` flow into a workflow with a `schedule` trigger.

**Appendices:** Gitea Actions and GitLab CI equivalents.

---

# Module 15: Operations and Production Support (3 h)

**Objectives:** monitoring, triage, root cause analysis, incident response.

**Activities**

- Monitoring: pipeline health, data freshness (custom check), SLA compliance (measured from run logs, sensor evidence, and freshness checks, since the CLI has no built-in scheduler or SLA dashboard).
- Operational dashboard: extend the Module 10 views (`dq_results`, `run_log`) with sensor wait times, publication latency per business date, and open warnings. Delivered as SQL views plus a text report.
- Alerting: route Warning, Error, and Critical to different channels using the alert helper from Module 10, with a rule that every alert names the asset, the business date, the evidence, and the runbook step.
- Incident response loop: triage, diagnose (lineage and run logs), fix, deploy, backfill, document, and root cause analysis.
- Runbook and post-incident write-up templates, including a "late vendor feed" runbook that uses sensor evidence.

**Lab:** complete incident simulation using the simulator's fault switches (a late Vendor Feed that times out a sensor, a failing blocking check, a bad deploy). Output: a fixed platform, a completed backfill, a rollback demonstration, and a short post-incident report.

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

**Target:** Postgres. The optional Module 13 port plan can be extended to the capstone for extra credit.

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

**Fast-Track A: Engineer Productivity** (about 34 h)
Modules 0, 1, 2, 3, 4, 6, 9, 10, 11, 12.

**Fast-Track B: Architect / Lead** (about 42.5 h)
Modules 0, 1, 4, 5, 7, 8 (overview), 9, 10, 11, 12, 13, 14, 15. Emphasis on dependency design, data-state contracts, governance, recovery, deployment, and operations.

Hours recomputed from the module table above; recheck when module durations change.

---

# Accessibility and Inclusion Standards

- Text-first lessons in Markdown. No video required for any lab.
- One environment for everyone: the same commands, the same results, no operating-system differences to manage.
- Plain language, defined terms on first use, and a glossary.
- No meaning conveyed by color alone in diagrams; diagrams have text equivalents.
- Time estimates per section and clear stopping points. Work persists between sessions and can be exported.
- Every lab runs inside the environment with no outside service.
- No real personal or financial data anywhere.
- Pricing, monthly hour limits, and idle timeouts stated before purchase. No hidden costs inside the course.

---

# Asset Type Coverage Matrix

The planning prompt requires, for each asset type: purpose, configuration, execution lifecycle, production examples, and troubleshooting. Every lesson on an asset type includes all five. This matrix says where each is taught.

| Asset type | Status in Bruin | Taught in | Course example |
|------------|-----------------|-----------|----------------|
| Seed (`*.seed`) | Native | Modules 1, 2 | Branches, products, FX fixture |
| ingestr | Native | Module 2 | SQLite and CSV sources into landing |
| SQL (`*.sql`) | Native | Modules 3, 7, 8, 9 | Hist, integration, SCD2, marts |
| Python | Native | Module 6 | FX rates fetch |
| Source (`*.source`) | Native, documents existing tables | Module 3 | Documenting simulator tables |
| Native sensor (`*.sensor.*`) | Native, per platform | Module 11 Part A | Processing-date sensor |
| Custom Python sensor | Course pattern on Python assets | Module 11 Part B | Vendor Feed gate |
| Python quality gate | Course pattern on Python assets | Module 10 | Reconciliation and drift checks |
| Column and custom SQL checks | Native | Module 10 | Every layer |
| DDL strategy (`ddl`) | Native materialization | Module 3 | Control tables |

Additional asset types relevant to enterprise work (for example other platform-specific asset types) are surveyed in Module 5 from the docs index, with at most one short example each.

---

# Other Deliverables From the Planning Prompt

Each module ships these alongside the lesson, lab, and break/fix files (see the Prompt Guide for the file layout): learning objectives, estimated duration, instructor notes, hands-on labs with expected outputs and validation steps, knowledge checks and quizzes, a common mistakes and troubleshooting guide, and a reading list. The course repository also ships a suggested repository structure and a suggested Bruin project structure, both in the Prompt Guide, and a fast-track option (above).

---

# Recommended References

**Bruin:** official Bruin documentation (CLI, assets, materialization, sensors, quality checks, backfill).
**Postgres:** PostgreSQL documentation (roles, privileges, template databases). **Cloud warehouses (optional):** Snowflake documentation for Module 13. **Official free Bruin content:** Bruin Academy, as complementary reading.
**Git:** Pro Git (free online).
**Data engineering:** The Data Warehouse Toolkit (optional, the course is self-contained), DataTalksClub Data Engineering Zoomcamp.

---

# Final Learning Outcomes

Learners will be able to:

1. Design Bruin project structures.
2. Build multi-pipeline solutions.
3. Implement asset and cross-pipeline dependencies.
4. Build SQL, Python, seed, ingestr, and native sensor assets.
5. Build custom Python sensors for generic sources with no Bruin connector, so pipelines run only when conditions in the data are met.
6. Build data quality controls and a reusable check library.
7. Debug failures from logs and checks.
8. Execute backfills and reconstruct history.
9. Implement SCD2 processing.
10. Analyze lineage.
11. Deploy through Git workflows with CI gates.
12. Describe and plan the port of a Bruin project to a cloud warehouse.
13. Operate and support a Bruin platform in production.

---

# Appendix A: Platform Facts and Verification Status

Verified means read in the official Bruin, PostgreSQL, or vendor documentation on 2026-10-05 (through a summarizing fetch tool, so spot-check load-bearing items against the raw page or by running them). Items marked Verify must be confirmed hands-on before the related module is written.

Claude is expected to close these items itself. Each Verify row becomes an entry in `docs/knowledge/VERIFIED_FACTS.md` (with evidence, method, version, and date), `ASSUMPTIONS.md`, or `OPEN_QUESTIONS.md` if it cannot be resolved, following `Master_Execution_Guide.md` sections 4 and 5. If the research changes the course design, record an ADR and propose the outline edit to the author. This table is a starting list. Research may uncover items that belong here, and Claude adds them in a proposed patch.

| Claim | Status |
|-------|--------|
| Python assets run in uv-managed isolated environments | Verified |
| Materialization strategies listed in Module 3; `merge`, `scd2_by_column`, `scd2_by_time` and Data Vault strategies documented for Postgres and DuckDB | Verified |
| Postgres connection fields and asset types `pg.sql`, `pg.seed`, `pg.sensor.table`, `pg.sensor.query`, `pg.source` | Verified |
| Postgres sensors poll every 30 seconds by default | Verified |
| Postgres CDC through ingestr needs `wal_level: logical`, a publication, and a replication slot | Verified (optional **[Advanced]** topic, requires Postgres configuration in the environment) |
| DuckDB does not allow concurrency between processes | Verified |
| Ten built-in column checks; custom SQL checks with `blocking` flag | Verified |
| Sensors are per platform; docs show no Python, file, or HTTP sensor | Verified |
| `bruin backfill` is CLI-local and resumable | Verified |
| No built-in scheduler in the CLI | Verified (docs describe external orchestration) |
| GitHub Actions setup action `bruin-data/setup-bruin`; `bruin validate`, `bruin unit-test` | Verified |
| ingestr supports `sqlite://` and `csv://` sources | Verified |
| `CREATE DATABASE ... TEMPLATE` clones a database but fails if any other session is connected to the template; database-level grants are not copied | Verified (PostgreSQL docs) |
| The Bruin VS Code extension is installed from the VS Code Marketplace | Verified (Bruin Academy install guide) |
| The Bruin extension is installable in a hosted open-source VS Code server (Open VSX or `.vsix`) | Verify |
| Ingestr Postgres-to-Postgres incremental loads on `updated_at` inside one environment | Verify |
| Cross-pipeline dependency syntax and CLI versus Cloud behavior | Verify |
| Custom Python sensors as Python assets that fail on timeout and block downstream | Verify (not documented as a feature; pattern relies on documented Python asset and dependency behavior) |
| Python quality-gate asset blocks downstream when it raises | Verify |
| `retries`, `rerun_cooldown`, and `timeout` behavior on Python assets | Verify (fields documented, Python-asset behavior not) |
| A documented way for a gate to skip downstream cleanly without failing the run | Verify |
| Native alerting available in the CLI (versus Bruin Cloud notifications) | Verify |
| Raw file archive plus load mechanism for daily extracts | Verify |
| `bruin validate` on a project configured for a platform the environment cannot reach (for Module 13 labs) | Verify |
| Optional real FX endpoint availability and terms | Verify |
