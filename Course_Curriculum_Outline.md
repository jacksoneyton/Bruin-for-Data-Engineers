# Bruin for Data Engineers: Building a Data Platform from Zero

Version 4.0 (revised 2026-10-06). Supersedes v3.0. See `Curriculum_Review_Notes.md` for what changed and why. The source requirements for this course are in `Curriculum_Planning_Prompt.md`; where this outline and that prompt differ, the prompt states the intent and this outline states how it is met.

This is Stage 1: a self-guided course that experienced engineers follow manually on their own machines, against a database they choose. A hosted, browser-delivered version (Stage 2) is deferred until Stage 1 has been trialed and revised. The hosted platform spec in `planning/Hosted_Platform_Build_Spec.md` is shelved. The course content is written against an environment contract (section 1.3) so that Stage 2 can supply the same environment without rewriting lessons.

A project-based course for data engineers who know SQL and are new to Bruin. Every module extends one evolving banking analytics platform for a fictional institution ("Lakota Bank"), so each lesson, lab, and break/fix exercise reinforces the same codebase, dependency graph, and business entities. The goal is expertise: a learner who completes the course can design, build, debug, recover, tune, and operate a production Bruin platform, and can show it in a timed assessment on an unfamiliar domain.

**Design goals**

1. Self-guided and manual. Engineers follow written lessons, run commands themselves, and verify their own work with automated checks. No instructor, no hosted service. Text and files only.
2. Bring your own database. The course is written and verified against one reference target (Postgres). Learners may use any Bruin-supported warehouse or database except DuckDB, for example Postgres, Snowflake, Microsoft SQL Server, or MySQL. A per-module compatibility note says what works unchanged, what needs adjustment, and what is not available on each target. The setup guide links to an easy-to-deploy Postgres container as an optional convenience.
3. DuckDB is not supported as the learner's warehouse. Bruin's documentation states that DuckDB does not allow concurrency between processes, which breaks the sensor, parallel pipeline, and recovery labs.
4. Self-contained after setup. Sources are simulated locally (written into the learner's target by the Source Simulator, plus local files, a SQLite file, and a mock API). After setup, no lab needs an outside service. Labs that do are marked optional.
5. Every lab verifies itself. A learner can tell whether they are correct without an instructor, using the course CLI.
6. Conditional execution is a first-class topic. Pipelines often must run only when conditions in the data are met, and many sources are generic (files, vendor feeds, status tables, web endpoints) with no official Bruin connector. The course teaches native sensors where Bruin has them and **custom Python sensors** where it does not.
7. Expert coverage is measurable. A feature inventory of the pinned Bruin version (every CLI command, flag, asset type, and YAML key) is mapped to lessons and labs. Anything in scope but untaught is a defect (section 9).
8. Cross-platform. Every command is shown for bash and PowerShell. The course CLI runs through `uv` so it behaves the same on Windows, macOS, and Linux.
9. Safe by default. Labs create and drop objects. The course CLI refuses to run against a database that holds anything other than course objects unless the learner confirms explicitly, and the setup guide requires a dedicated empty database.
10. Accessible by design (see the standards at the end of this document).

**Target operating model:** Bruin CLI with Git, in the learner's own editor and terminal. VS Code with the Bruin extension is the recommended editor.
**Reference warehouse:** Postgres.
**Other supported targets:** any Bruin-supported platform except DuckDB, best effort, with compatibility notes. Snowflake is the first additional target to be verified (Phase H).
**Local file and source engines:** SQLite (mortgage source), CSV and JSON files, mock API.
**CI/CD:** a local `course ci` pipeline that mirrors a real CI sequence. GitHub Actions is a real lab for learners with a GitHub account.

---

# 1. Prerequisites and the Learning Environment

## 1.1 Learner Prerequisites

Required:

- Working SQL: joins, aggregates, CTEs, window functions. The course assumes professional use of SQL.
- Basic Git: clone, commit, branch, merge.
- Comfort in a terminal (bash, zsh, or PowerShell).
- A computer (Windows 10 or later, macOS, or Linux) where the learner may install command-line tools, or an approved sandbox machine or virtual machine.
- A database to use as the target, with permission to create and drop schemas and tables in a dedicated empty database (section 1.2). A Postgres container (see the setup guide) satisfies this.
- Network access during setup, to download Bruin, `uv`, and Python packages.

Helpful, not required:

- Python (functions, dictionaries, exceptions, file and HTTP handling). Modules 6, 10, 11, and 17 use Python. An appendix primer covers what the labs need.
- Prior warehouse or Kimball experience. Modules 1 and 7 include short primers.

Advanced material (marked **[Advanced]**) assumes MERGE patterns and dimensional modeling and can be skipped on the Core track.

## 1.2 Choosing and Preparing the Target Database

The learner supplies the database. The setup guide (`setup/SETUP.md`) walks through these choices.

| Choice | Guidance |
|--------|----------|
| Postgres (reference) | All labs are written and verified here. If the learner has no Postgres, the setup guide links to the official Postgres container image and gives one command to start it. Docker is optional and is the only convenience that uses it. Any Postgres 14 or later works (the exact tested versions are pinned in the repository). |
| Snowflake, SQL Server, MySQL, other Bruin-supported platforms | Allowed. Use the per-module compatibility notes. Some labs need different syntax, a different asset type, or are unavailable. Verified status per target is in the compatibility matrix (`docs/compat/`). |
| DuckDB | Not supported as the target. See the design goals. |
| A shared or production database | Do not use. Labs drop and recreate objects. Use a dedicated empty database or a sandbox account. |

Requirements on whichever database is chosen:

- A dedicated, empty database (or the platform's closest equivalent) used only for this course.
- A role that can create and drop schemas, tables, and views, and can read and write across them.
- Separate databases or schemas for Bruin environments `default` (development), `staging`, and `production` (Module 5). The setup guide gives exact statements per platform.
- Reachability from the learner's machine, with credentials stored only in the git-ignored `.bruin.yml` and in environment variables.

On platforms where "schema" and "database" mean different things (for example MySQL), the compatibility notes give the mapping. The logical layers in section 3 stay the same.

## 1.3 The Environment Contract

Lessons and labs depend on this contract, not on how the environment was provisioned. Stage 1 meets it with the setup guide. A future hosted environment would meet it with a prebuilt image.

| Item | Contract |
|------|----------|
| Bruin CLI | One pinned version, recorded in the repository and checked by `course doctor`. |
| `uv` | Available on the path. Bruin manages Python versions and dependencies through `uv`. Whether Bruin installs `uv` itself is checked in Phase A. |
| Git | Installed and configured. |
| Course CLI (`course`) | Installed with `uv` from the repository. Commands: `doctor`, `up`, `down`, `check <step>`, `hint <step>`, `reset <step>`, `advance`, `fault`, `clock`, `report`, `ci`. |
| Target database | Reachable through a connection named in `.bruin.yml`. The course CLI reads the same connection. |
| Source Simulator | Writes synthetic sources into the target (schemas `src_core_banking` and `src_crm`) and writes the file, SQLite, and Vendor Feed sources into a local `data/` folder. |
| Mock API | A small local process started by `course up`, listening on a configurable local port. |
| Simulated clock | Readable by sensors and the scheduler harness. |
| Per-step manifest and checks | Each step has a manifest and a check that prints machine-readable results (JSON lines). |

## 1.4 How the Environment Behaves

- **State.** The learner's work is files in a Git repository plus database objects in the dedicated database. Nothing is stored outside those two places.
- **Resets.** `course reset <step>` restores files from the step's starter tag (after saving the learner's work on a branch), drops and recreates the course schemas, reloads sources, and sets the simulator seed and clock. On Postgres, a template database clone can speed this up (optional).
- **Safety.** `course reset` and `course down` refuse to touch a database containing non-course objects unless the learner passes an explicit confirmation flag.
- **Offline after setup.** No lab depends on an outside service. Optional labs that do are marked.
- **Feedback.** `course report` writes a local bundle (step timings, check results, environment versions, no data contents) that testers can send to the course author.

## 1.5 Source and Target Roles

| Engine | Role | Why |
|--------|------|-----|
| Learner's target database (Postgres reference) | Warehouse, and host of the simulated core banking and CRM source schemas | A real server database with concurrent sessions, so sensors, parallel pipelines, and checks can run together. Bruin documents `pg.sql`, `pg.seed`, `pg.sensor.table`, `pg.sensor.query`, and `pg.source`, and `merge`, `scd2_by_column`, `scd2_by_time`, and the Data Vault strategies on Postgres. |
| SQLite | Mortgage source | A different source engine, read through ingestr. |
| Files (CSV, JSON, and the Vendor Feed drop folder) | Reference data and the generic source for custom sensors | No connector, which is the point. |

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

## Source Systems (simulated, local)

All sources are synthetic, deterministic, and contain no real personal data. They are produced by a bundled **Source Simulator** and a **mock API**.

| Source | Simulated as | Entities |
|--------|--------------|----------|
| Core Banking | Schema `src_core_banking` in the target database (written by the simulator) | Customers, Accounts, Transactions |
| CRM | Schema `src_crm` in the target database | CRM Customers, Interactions |
| Flat Files | CSV files in a drop folder | Branches, Products |
| External API | Mock REST API with pagination, authentication, rate limits, and fault switches (optional real public API as a stretch) | FX Rates |
| Mortgage Platform (capstone) | SQLite database file | Loans, Payments, Borrowers |
| Vendor Feed (generic source, no Bruin connector) | Drop folder of files with a manifest or status file, plus a status table | Daily statement and settlement files, a completeness flag, a vendor run status |

The Vendor Feed exists to teach custom Python sensors. It models the common case of a generic source whose readiness depends on conditions in the data: a file has arrived, the file has stopped growing, the row count meets a threshold, the maximum business date equals the processing date, a status flag says COMPLETE, or a checksum matches the manifest.

Stretch entities (not required): Campaigns, Economic Indicators.

### Source Simulator requirements

- Deterministic from a seed value.
- Advances by one simulated business day on demand, writing inserts, updates (with `updated_at` values), and deletes to the source schemas, so incremental loads, missed days, and replays are practiced against a moving source.
- Fault injection switches: late-arriving rows (backdated `updated_at`), duplicate rows, corrupted day, partial load, schema drift, deleted source rows. Each is documented, reversible, and recorded in the manifest.
- Mock API controls: return HTTP 500 or 429, slow responses, expired credentials, pagination changes, schema drift.
- Vendor Feed controls: delay a file's arrival, deliver a file in growing chunks, deliver an empty or under-threshold file, flip the completeness flag late, deliver a checksum mismatch, deliver a prior day's file by mistake.
- A simulated clock that sensors and schedulers can read, so waiting scenarios finish in seconds.
- A per-day manifest of true row counts and checksums, used by self-checks.
- Target adapters through a portable DDL subset. The Postgres adapter is the reference and is verified. Other adapters (Snowflake first, then SQL Server and MySQL) are best effort. When an adapter fails on a target, `course` can export the sources as CSV files plus a plain loader script so the learner can load them by hand.
- Runs entirely locally after setup.

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
| Control | `ctl` | descriptive | `processing_dates`, `publication_log` |
| Data quality | `dq` | descriptive | `dq_results`, `run_log` |

Dimensions belong to the SCD2 layer. The mart layer holds facts and presentation views that join to those dimensions.

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
| 0 | Setup, Orientation, and First Run | 2 h | Yes |
| 1 | Bruin Fundamentals | 2.5 h | Yes |
| 2 | Landing Layer Ingestion | 3.5 h | Yes |
| 3 | SQL Assets and Materialization | 4.5 h | Yes |
| 4 | Dependencies and Lineage | 2.5 h | Yes |
| 5 | Pipeline Design | 3.5 h | Yes |
| 6 | Python Assets | 3 h | Yes |
| 7 | Historical Layer Engineering | 4 h | Yes |
| 8 | Integration Layer | 3 h | Yes |
| 9 | SCD Type 2 Processing | 4 h | Yes |
| 10 | Data Quality Frameworks | 4.5 h | Yes |
| 11 | Sensors, Custom Python Sensors, and Data-State Dependencies | 5 h | Yes |
| 12 | Replayability, Backfills, and Recovery | 4 h | Yes |
| 13 | Targets, Compatibility, and Porting | 3 h | Optional, recommended off Postgres |
| 14 | Git-Based Deployment | 3 h | Yes |
| 15 | Operations and Production Support | 3 h | Yes |
| 16 | Enterprise Capstone | 8-16 h | Yes |
| 17 | Expert Practice and Assessment | 8 h | Yes for the Expert designation |

Core content total: about 63 hours including optional Module 13, plus 8-16 hours for the capstone. Module 17 follows the capstone.

**Expert designation.** Completing Modules 0 to 16 earns "Practitioner". Completing Module 17, including a passing timed assessment on an unfamiliar domain, earns "Expert". These are course-defined labels for the author's cohort, with no connection to any vendor certification.

**Structure carried over from earlier versions**

- Landing ingestion precedes SQL assets, because history builds on landed data.
- Dependencies come early (Module 4) because every module after Module 1 uses `depends`.
- Data quality precedes sensors and replay, because sensors, recovery drills, and the CI gate rely on checks.
- Custom Python sensors and Python checks stay as required content with enough time.
- The Snowflake module became Module 13, a target-independent compatibility and porting module.

Every module ships these parts: lesson text, hands-on lab with expected output, automated self-check, break/fix exercise, knowledge check, common-mistakes guide, a **Target compatibility** note, an **Expert track** section (internals, failure modes, and edge cases for learners going for Expert), reading list, and facilitator notes for anyone running the course with a group.

---

# Module 0: Setup, Orientation, and First Run (2 h)

**Objectives:** install and verify the tools, prepare a dedicated database, learn the repository layout and the course CLI, and run the first Bruin commands.

**Lab**

1. Follow `setup/SETUP.md` for your operating system: install Git, `uv`, the Bruin CLI (at the pinned version), and the course CLI.
2. Choose the target database (section 1.2). If using Postgres in a container, start it with the command from the setup guide.
3. Create the dedicated database and roles, the environment databases or schemas, and the connection in `.bruin.yml`.
4. Run `course doctor` until every line passes.
5. Run `bruin --version` and `bruin validate` on the starter project, then run the starter pipeline against your target.
6. Install the Bruin extension in VS Code (optional but recommended). Use `course check`, `course hint`, and `course reset` once each, and generate a `course report`.

**Self-check:** reports Bruin found at the pinned version, Git found, `uv` found, target reachable and permissions sufficient, database contains only course objects, starter asset materialized.

**Break/fix:** the starter project's `.bruin.yml` names a connection that does not exist. Learners read the `bruin validate` error and repair it.

**Knowledge check**

1. Which file stores connections and environments, and why is it excluded from source control?
2. Why does the course refuse to run against a database with non-course objects?
3. Why is DuckDB not supported as the course warehouse?

**Target compatibility:** the setup guide has a section per supported target with exact statements for creating the database, role, and environment databases or schemas, plus the Bruin connection fields. Known gaps are listed per target.

**Expert track:** how Bruin finds the project root, how `.bruin.yml` environments resolve, where Bruin caches Python environments and logs, and how to run two Bruin versions side by side safely.

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

**Target compatibility:** seed and SQL asset type names per platform (for example `pg.seed`, `pg.sql`, and the equivalents for other targets), connection field names, and any limits on identifier length or case.

**Expert track:** the anatomy of an asset definition (every YAML key), how Bruin parses asset files, what `validate` checks and what it does not, and how to read `run` output line by line.

---

# Module 2: Landing Layer Ingestion (3.5 h)

**Objectives:** seed assets, ingestr assets, the landing architecture, and the Source Simulator.

**Lab:** build landing assets for every source:

- Core Banking (the `src_core_banking` schema via ingestr, incremental on `updated_at`): customers, accounts, transactions
- CRM (the `src_crm` schema via ingestr): customers, interactions
- Flat files (seed assets or CSV via ingestr): products, branches
- External API: FX rates (the Python version arrives in Module 6; here load the JSON fixture as a seed)
- Mortgage (SQLite via ingestr) appears in the capstone; a short demonstration here shows a second source engine

**Topics:** full refresh versus incremental key, immutable snapshots, load metadata columns (`_loaded_at`, `_run_id`, `_source_file`).

**Raw file archive:** the planning requirement is "raw immutable history stored in files and loaded into history tables." Each simulated day's extract is written once to an append-only `data/landing/<source>/<yyyy-mm-dd>/` archive that is never edited. Loads read from the archive, so any day can be replayed byte for byte. The exact extract-and-load mechanism is decided in the Phase A spike (see the Prompt Guide).

**Expected outputs:** `landing.core_customers`, `landing.core_accounts`, `landing.core_transactions`, `landing.crm_customers`, `landing.crm_interactions`, `landing.ref_products`, `landing.ref_branches`.

**Self-check:** row counts match the simulator's manifest for day 1.

**Break/fix:** source connection name misspelled.

**Target compatibility:** ingestr source and destination URIs per platform, supported incremental strategies per destination, and type mapping differences.

**Expert track:** how ingestr runs under Bruin, incremental key semantics and their failure modes (clock skew, late rows, ties), full-refresh versus incremental trade-offs, and ingestr's license terms for commercial use (relevant if the learner's employer builds a product on it).

---

# Module 3: SQL Assets and Materialization (4.5 h)

**Objectives:** SQL asset anatomy, materialization strategies, incremental processing, and how the same logic behaves on different targets.

**Strategies covered** (verified against the Bruin docs, October 2026):

```text
create+replace     truncate+insert    append
delete+insert      merge              time_interval
ddl                scd2_by_column     scd2_by_time
```

Also: `table` versus `view` materialization types. `datavault_hub`, `datavault_link`, and `datavault_satellite` are documented as PostgreSQL and DuckDB only, so they run on the reference target. They appear as a short optional **[Advanced]** aside (hub, link, and satellite for customers and accounts). Learners on other targets read the aside and skip the lab.

Required fields per strategy (for example `primary_key` for merge, `incremental_key` plus `time_granularity` for `time_interval`) are taught as a lookup table learners fill in themselves.

**Lab:** build `hist.customers_hist` and `hist.accounts_hist` as first drafts using SQL assets over the landing tables, using at least three different strategies.

**Target comparison lab:** fill in the strategy support table for your target from the documentation and from `bruin validate` and `bruin run` results. Learners with a second target repeat the lab and record differences.

**Break/fix:** `merge` without `primary_key`.

**Target compatibility:** the strategy support table per platform, SQL dialect differences for the lab queries (date arithmetic, string functions, upsert syntax), and what each strategy compiles to on the target.

**Expert track:** inspect the SQL Bruin generates for each strategy (using whatever render or debug command Phase A finds), transaction and locking behavior of each strategy, cost and row-locking implications at volume, and when `time_interval` beats `merge`.

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

**Target compatibility:** none beyond Module 3, except any platform limits on concurrent sessions or queries that change the parallelism results.

**Expert track:** how Bruin builds and schedules the graph, what limits parallelism (workers, connection limits, locks), how lineage is derived (declared dependencies versus parsed SQL), and how to debug a graph that runs in the wrong order.

---

# Module 5: Pipeline Design (3.5 h)

**Objectives:** pipeline structure, schedule syntax, default connections, variables, environments, reuse, and run-time tuning.

**Scheduling note:** the Bruin CLI defines a schedule in `pipeline.yml` but contains no scheduler. Something external triggers runs. The course CLI includes a small scheduler harness (`course scheduler`) that triggers pipelines on their cron schedule against the simulated clock, standing in for an external orchestrator so labs finish in seconds. Module 14 explains real orchestrators (CI schedulers, Airflow, Bruin Cloud) without building on them.

**Environments:** define Bruin environments `default` (dev), `staging`, and `production`, each pointing at a separate database or schema set on the target.

**Lab:** split the project into four pipelines:

```text
ingest-core-banking    ingest-crm
ingest-flatfile        ingest-external-api
```

plus a shared `lib/` of reusable SQL macros or Python helpers. Then tune: measure the effect of `--workers` on total run time and database load.

**Break/fix:** invalid schedule syntax.

**Target compatibility:** how environments map to databases or schemas per platform, and variable and macro behavior differences, if any.

**Expert track:** pipeline-level versus asset-level settings and precedence, variable scoping, project layout patterns for 100-plus assets, and naming and ownership conventions that scale.

---

# Module 6: Python Assets (3 h)

**Objectives:** Python asset lifecycle, isolated environments and dependency files, secrets injection, DataFrame materialization, shared libraries in `lib/`, and failure semantics (how a raised exception or non-zero exit fails the asset and blocks downstream assets). The failure semantics lesson is the foundation for Modules 10 and 11.

**Facts taught** (verified in docs): Bruin runs Python assets in managed isolated environments using uv, so no hand-managed virtual environment is needed. Dependencies come from `pyproject.toml` with `uv.lock` (preferred) or `requirements.txt`. Returned data (DataFrames, Arrow tables, lists of dicts, generators) is materialized by the asset's `materialization` block. Run dates arrive as environment variables (`BRUIN_START_DATE`, `BRUIN_END_DATE`).

**Lab:** build `fx_rates_fetch.py`:

1. Read FX rates from the mock API (and optionally a real public endpoint), falling back to the offline fixture when the network or API is unavailable.
2. Return a DataFrame or list of dicts.
3. Let Bruin materialize it into `landing.ref_fx_rates`.

**Break/fix:** wrong endpoint, then a missing secret. Learners diagnose HTTP failure versus authentication failure from the logs.

**Target compatibility:** materialization of returned data per platform, and any type mapping differences for Python-produced columns.

**Expert track:** Python environment caching and lock behavior, memory profile of materializing large frames versus generators, secrets injection paths and their leak risks, and when to put logic in `lib/` versus in the asset.

---

# Module 7: Historical Layer Engineering (4 h)

**Objectives:** historical persistence, auditability, reconciliation, reprocessing.

**Primer:** why append-oriented history differs from current state, with one worked example.

**Build:** `hist.customers_hist`, `hist.accounts_hist`, `hist.transactions_hist`, `hist.crm_customers_hist` (final versions, with count reconciliation checks against the simulator manifest).

**Reprocessing scenarios:** missed day, corrupted day, partial load.

**Lab:** turn on the simulator's late-arriving-data fault, observe the gap, reprocess successfully, show reconciliation passes.

**Target compatibility:** append and dedup patterns per platform, and window function differences used in change detection.

**Expert track:** designing history for 1 billion rows (partitioning, clustering, retention), delete handling in history (soft versus hard), and proving completeness to an auditor.

---

# Module 8: Integration Layer (3 h)

**Objectives:** current-state entities, business key standardization, conformed entities, golden records.

**Build:** `integration.customer_current`, `integration.account_current`, `integration.product_current`.

**Lab:** merge CRM and Core Banking customer records into one golden record with documented survivorship rules (which source wins per attribute).

**Target compatibility:** merge and upsert syntax and string normalization functions per platform.

**Expert track:** survivorship rules as data (a rules table) versus code, match and merge for fuzzy keys, and handling a source that changes its keys.

---

# Module 9: SCD Type 2 Processing (4 h)

**Objectives:** historical dimension design, versioning, late-arriving corrections, rebuilds.

**Build:** `dim.dim_customer`, `dim.dim_account` using `scd2_by_column` and compare against `scd2_by_time`. Bruin adds `_valid_from`, `_valid_until`, and `_is_current` automatically (verified in docs).

**Scenarios**

1. Initial load: Customer A has version 1.
2. Change: Customer A's email changes, version 2 is created and version 1 is closed.
3. Late-arriving correction: a change dated in the past arrives after later changes **[Advanced]**.

**Lab:** drop the dimension and rebuild it from scratch from history. Verify the version count and that exactly one current row exists per key.

**Mid-course practical (after this module):** repair a provided broken platform (see Assessment Strategy).

**Target compatibility:** SCD2 strategy support per platform and any differences in how `_valid_until` and open-ended rows are represented.

**Expert track:** compare Bruin's SCD2 strategies to hand-written SCD2 SQL, handle deletes and reappearing keys, and fact-to-dimension joins that respect validity ranges.

---

# Module 10: Data Quality Frameworks (4.5 h)

**Objectives:** built-in checks, custom checks, blocking behavior, reusable conventions.

**Built-in column checks (verified):** `not_null`, `unique`, `accepted_values`, `positive`, `negative`, `non_negative`, `pattern`, `relationships`, `min`, `max`.

**Custom SQL checks (verified):** `custom_checks` with `name`, `query`, optional `value`, optional `count`, and a `blocking` flag (default true). Row-count, freshness, and schema-drift checks are written as custom SQL checks. They are taught as the "row count, freshness, and schema validation" tier the planning prompt calls for.

**Custom Python checks (course pattern):** Bruin documents SQL custom checks but no Python check type. The course builds Python checks as a **Python quality-gate asset**: a Python asset that sits in the dependency graph between a built asset and its consumers, runs checks that SQL expresses poorly (cross-source reconciliation, file-versus-table comparison, statistical drift, calls to external references), writes every result to a `dq.dq_results` table, and raises an exception to fail the asset when a blocking rule fails. Downstream assets that `depends` on the gate do not run. Phase A must confirm the failure and blocking behavior and look for any native Python check support before this module is written.

**Severity model:** Bruin exposes blocking versus non-blocking for checks, and failed assets block downstream. The course defines its three-level vocabulary on top of that:

| Course level | Mechanism | Effect |
|--------------|-----------|--------|
| Warning | SQL check with `blocking: false`, or a Python gate rule that logs and records without raising | Recorded and alerted, downstream continues |
| Error | SQL check with `blocking: true`, or a Python gate rule that raises | Downstream assets do not run |
| Critical | Error behavior plus a documented escalation step (for example the CI job fails, the alert pages the on-call, and the runbook applies) | Run stops and escalation is required |

**Reusable framework:** `lib/validation.py` plus a library of parameterized SQL check templates. The Python library provides: rule definitions, a severity enum, a runner that records results to `dq.dq_results`, a standard exception that Bruin sees as a failed asset, and helpers for the reconciliation patterns used in Modules 7 to 9.

**Failure handling and alerting patterns:** retries and cooldown settings on assets, quarantine tables for rejected rows, notify-and-continue versus stop-the-line, and alert hooks. Native Bruin notification support appears tied to Bruin Cloud in the documentation; Phase A must confirm what the CLI supports. The default course pattern is CI or scheduler failure notification plus a small alert helper in `lib/` that posts to a webhook when configured and writes to `dq.dq_results` either way.

**Operational dashboard:** SQL views over `dq.dq_results` and a `dq.run_log` table (check pass rates, failures by layer, freshness by table, open warnings). The lab builds the views and a plain-text report script. A rendered dashboard is optional and tool-agnostic.

**Lab:** apply the framework to every hist and integration asset. Add one warning and one blocking rule per layer, including at least one Python gate rule. Then break the data with simulator faults and show each severity behaves as designed.

**Unit tests:** introduce `bruin unit-test` (referenced in the CI docs) at a basic level.

**Target compatibility:** whether each built-in check is supported on the target (checks compile to SQL, so differences in regex and type behavior matter for `pattern`), custom check query dialect, and where `dq.dq_results` stores JSON or arrays if used.

**Expert track:** check cost at scale (full-table checks versus sampled or partition-scoped), check ordering and fail-fast behavior, designing rules that do not flap, and how checks interact with materialization (before or after write, per Phase A).

---

# Module 11: Sensors, Custom Python Sensors, and Data-State Dependencies (5 h)

**Objectives:** native sensor assets, custom Python sensors for generic sources, control and publication tables, waiting on published data rather than scheduler success, cross-pipeline ordering.

## Part A: Native sensors (about 1.5 h)

**Verified:** sensors are implemented per platform. For Postgres, the docs list `pg.sensor.table` and `pg.sensor.query`, which poll every 30 seconds by default. Sensors accept `poke_interval` (seconds) and `timeout` (default 24 hours), and quality checks can run on a sensor after it succeeds. Coverage differs per platform. The course uses Postgres sensors so that a sensor can poll the warehouse while the upstream pipeline is still writing to it. Learners on a target without a native table or query sensor build Part A's lab with the Part B Python pattern, which is itself a lesson in the trade-off.

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
| Optional web endpoint | A JSON status document reports ready (uses the mock API offline) |

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
- **Lab B6 (generic source of your choice):** write a sensor for a source that has no connector in your own environment (a status table in another system, an SFTP listing, a web endpoint), or use the mock API's alternate endpoint.

**Break/fix scenarios**

1. The sensor passes on yesterday's file left in the drop folder (missing business date condition).
2. The sensor releases on a half-written file (missing stability and integrity conditions).
3. The sensor has no timeout and blocks a worker indefinitely.
4. The sensor fails with a stack trace instead of a clear "not ready" message, and on-call cannot tell a late vendor from a bug.
5. The control table was updated before checks passed, so a downstream pipeline consumed unvalidated data.

**Open verification item:** cross-pipeline dependency syntax (the `uri` field and `depends` with `uri`) and which behaviors exist in the CLI versus Bruin Cloud. The documentation page could not be retrieved during review. Resolve in Phase A before this module is written. If the CLI cannot make a pipeline wait on another pipeline directly, the control-table sensor pattern above is the primary mechanism, which is also the planning prompt's intent.

**Target compatibility:** native sensor asset names and behavior per platform (for example `sf.sensor.table` and `sf.sensor.query` for Snowflake), polling cost on pay-per-query platforms (a 30-second poll on a cloud warehouse can keep a warehouse awake), and the Python pattern as the portable fallback.

**Expert track:** worker starvation from long-held sensors, sensor storms (many sensors polling one table), tuning `poke_interval` against cost, evidence retention, exactly-once publication under retries, and race conditions between a sensor and a late upstream write.

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

**Target compatibility:** backfill performance and cost on the target, transaction behavior when a backfill fails midway, and any platform-specific restore options (snapshots, time travel, point-in-time restore) that complement history-based rebuilds.

**Expert track:** backfill planning for large ranges (partition size, parallelism, throttling the source), resuming after partial failure, proving a backfill changed only what it should, and a decision tree for choosing among rerun, backfill, rebuild, and restore.

---

# Module 13: Targets, Compatibility, and Porting (3 h, optional)

Recommended for every learner who is not on Postgres, and for any learner whose employer runs a different warehouse. No account on any other platform is required to complete the module.

**Objectives:** understand the differences that matter when running or porting a Bruin project across targets, and be able to read and adapt a Bruin project for another target.

**Topics**

- Connection configuration shape per platform (for Snowflake: account, user, database, warehouse, role, region, key-pair authentication concepts; for SQL Server and MySQL: host, port, database, driver and TLS options).
- Environments mapped to databases or schemas, and how `default`, `staging`, and `production` translate.
- Asset types per platform (for example `sf.sql`, `sf.seed`, `sf.source`, `sf.sensor.table`, `sf.sensor.query`) and the materialization support Bruin documents for each platform.
- Compute and cost: virtual warehouses, auto-suspend, credit budgeting, and why a retry loop or a short sensor poll can be expensive.
- RBAC translation: Postgres roles and grants compared with Snowflake roles and SQL Server logins and users **[Advanced]**.
- Dialect differences: identifier case, date functions, `QUALIFY`, semi-structured types, sequences, and procedural code.

**Labs**

- **Dialect worksheet:** translate ten of the course's SQL assets to the dialect of a second target. A checker compares against the answer key and flags unsupported constructs.
- **Port plan:** write a one-page port plan for the Lakota Bank platform covering connections, environments, roles, materialization changes, cost controls, and a cutover and rollback approach.
- **Read the config:** given a sample `.bruin.yml` for another platform and a project, identify the five mistakes that would fail `bruin validate` or a run.
- **Run it on a second target (optional, needs a second database):** use the simulator adapter and the compatibility notes to run Modules 1 to 4 on a second target, and add your findings to the compatibility matrix. A contribution that passes review becomes part of the course.

**Break/fix:** a project ported with Postgres-only syntax in an asset targeted at another platform.

**Target compatibility:** this module is the compatibility reference. It links to the matrix in `docs/compat/`.

**Expert track:** designing a project that is portable by construction (thin platform-specific layer, shared logic), and testing portability in CI against two targets.

---

# Module 14: Git-Based Deployment (3 h)

**Objectives:** branching, pull requests and code review, environment promotion, release management, rollback, CI gates, scheduled runs.

**Reference flow**

```text
feature/*  →  review  →  main  →  staging  →  production
```

The course recommends trunk-based flow with environment promotion rather than long-lived `staging` and `production` branches, because separate branches for each environment drift. A branch-per-environment variant appears in an appendix.

**Local CI:** `course ci` runs the same sequence a hosted CI system would:

```text
bruin validate  →  bruin unit-test  →  run in staging  →  run checks  →  promote to production
```

Promotion targets are the separate staging and production databases or schema sets selected through Bruin environments. Credentials stay in `.bruin.yml`, which is never committed.

**Pull request review:** the repository includes a review exercise pack. Learners review provided diffs against a checklist, then submit their own change for an automated review (the self-check applies the checklist rules). Learners with a GitHub or other forge account can also use real pull requests.

**Code review checklist for data platforms:** `bruin validate` and `bruin unit-test` pass, lineage change reviewed, materialization and key changes called out, new checks and severity levels justified, backfill impact stated, sensors have bounded timeouts, no secrets in the diff.

**Release management:** version tags, a changelog, and a release note that states which tables change shape and whether a backfill is required.

**Rollback strategies:** Git revert and redeploy; rebuild affected layers from `_hist` (Module 12); restore a database from a snapshot or template clone taken before the release; restore a table from history using a pinned run date. Each strategy states what it can and cannot undo, and a lab practices a bad deploy followed by rollback.

**Real orchestration lab (needs a GitHub account):** Bruin's docs describe a GitHub Actions setup action (`bruin-data/setup-bruin`) and external schedulers such as Airflow. The lab converts the `course ci` flow into a workflow with a `schedule` trigger. The CI runner needs a database it can reach, so the lab uses a Postgres service container in the workflow, which keeps the lab self-contained and independent of the learner's target.

**Appendices:** Gitea Actions and GitLab CI equivalents.

**Target compatibility:** how the CI database differs from the learner's target and which assets need a platform-specific variant in CI.

**Expert track:** secrets in CI, caching Bruin and Python environments, deploy locks, running CI for only the changed assets, and handling migrations of existing tables.

---

# Module 15: Operations and Production Support (3 h)

**Objectives:** monitoring, triage, root cause analysis, incident response.

**Activities**

- Monitoring: pipeline health, data freshness (custom check), SLA compliance (measured from run logs, sensor evidence, and freshness checks, since the CLI has no built-in scheduler or SLA dashboard).
- Operational dashboard: extend the Module 10 views (`dq.dq_results`, `dq.run_log`) with sensor wait times, publication latency per business date, and open warnings. Delivered as SQL views plus a text report.
- Alerting: route Warning, Error, and Critical to different channels using the alert helper from Module 10, with a rule that every alert names the asset, the business date, the evidence, and the runbook step.
- Incident response loop: triage, diagnose (lineage and run logs), fix, deploy, backfill, document, and root cause analysis.
- Runbook and post-incident write-up templates, including a "late vendor feed" runbook that uses sensor evidence.

**Lab:** complete incident simulation using the simulator's fault switches (a late Vendor Feed that times out a sensor, a failing blocking check, a bad deploy). Output: a fixed platform, a completed backfill, a rollback demonstration, and a short post-incident report.

**Target compatibility:** platform-native monitoring (query history, warehouse usage views, logs) that complements Bruin run logs.

**Expert track:** error budgets and SLOs for data, alert fatigue and how to measure it, on-call handoff documents, and capacity planning for the control and run-log tables.

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

**Target:** the learner's chosen target. Learners on Postgres get full automated grading. Learners on other targets get automated grading for the checks that apply, and a published checklist for the rest, because a few strategies (for example the Data Vault aside) are Postgres only.

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

# Module 17: Expert Practice and Assessment (8 h)

Follows the capstone. Required for the Expert designation.

## Part A: Bruin internals and troubleshooting (about 2 h)

- How a run executes: project discovery, graph construction, worker pool, per-asset steps (render, execute, check), connection handling, and where each stage logs.
- A catalog of failure modes with symptoms, causes, and fixes, built from every break/fix exercise in the course plus new ones: connection errors, rendering errors, dependency errors, materialization errors, check failures, Python environment errors, and sensor timeouts.
- Debugging method: reproduce on one asset with `--only`, render the SQL, run it by hand, compare, bisect the graph, read the run log. Whatever render, debug, and verbose options the pinned version offers (from the feature inventory) are used here.
- Reading the Bruin source (Go, Apache-2.0) to answer a behavior question when the docs are silent, and writing a minimal reproduction for an upstream issue.

## Part B: Performance, cost, and scale (about 1.5 h)

- Tuning workers, partitioning with `time_interval`, incremental design, avoiding full scans in checks, and choosing materializations for volume.
- Measuring: run time per asset, database load, rows per second, and cost on pay-per-use targets.
- Sensor and retry load on the target, and how to bound it.
- A scale lab: grow the simulator volume by 50 times and bring the pipeline back inside a time budget, reporting what changed and why.

## Part C: Extending, governing, and contributing (about 1 h)

- Project templates and conventions for a team: repository layout, naming, review rules, and onboarding a new engineer.
- Governance patterns: ownership metadata, tags, data contracts as checks, and change control for shared assets (whatever metadata fields the feature inventory documents).
- Where Bruin ends: what to build as a course pattern (custom sensors, quality gates, alerting) versus what to ask for upstream, and how to file a high-quality feature request or contribution.

## Part D: Expert assessment (3.5 h, timed)

An unseen domain ("Prairie Insurance": claims, policies, adjusters, a vendor feed for repair estimates) with a provided platform and the course CLI. Learners work alone with the Bruin documentation open and no course notes. Tasks:

1. Repair a broken platform: at least ten injected faults across validation, materialization, dependencies, checks, sensors, and recovery.
2. Build one new pipeline from a written spec that includes conditional execution against a generic source, a quality gate, and an SCD2 dimension.
3. Review a provided pull request and write findings that identify the defects, with severity.
4. Recover from a simulated incident (a corrupted day plus a late vendor file) and write a short post-incident report.

Grading: an automated suite grades tasks 1, 2, and 4 structurally and by outcome; a published rubric grades tasks 3 and the report. A learner who needs hints can use them at a published time penalty. The pass mark and the rubric are fixed before the first learner attempts it, and a second unseen domain variant (the "Granite Utilities" fixture) is provided for retakes.

**Target compatibility:** the assessment is delivered for the reference target. Learners on other targets use the automated suite for the portable parts and the rubric for the rest, or run the assessment on a Postgres container.

---

# 5. Assessment Strategy

Every module has four parts: a knowledge check, a hands-on lab, an automated self-check, and a break/fix exercise.

- **Mid-course practical (after Module 9):** repair a provided broken platform. The fixture contains at least eight faults that `bruin validate`, run logs, or checks reveal.
- **Operations drill (Module 15):** diagnose, repair, and replay.
- **Capstone:** weighted rubric above.
- **Expert assessment (Module 17):** timed practical on an unseen domain.

Each module ships `starter` and `solution` Git tags so a learner who falls behind can restart from a known good state.

# 6. Trial Program

Before the course is declared ready for wider use, the author and a small group of trusted engineers work through it manually. The trial follows the process in the Prompt Guide (Phase G): testers record time per step, every failed check, and every point where they got stuck, and send a `course report` bundle plus a short feedback form. Each cycle ends with a revision pass. Entry criteria for wider release are in the Prompt Guide.

# 7. Fast-Track Options

**Fast-Track A: Engineer Productivity** (about 35.5 h)
Modules 0, 1, 2, 3, 4, 6, 9, 10, 11, 12.

**Fast-Track B: Architect / Lead** (about 44 h)
Modules 0, 1, 4, 5, 7, 8 (overview), 9, 10, 11, 12, 13, 14, 15. Emphasis on dependency design, data-state contracts, governance, recovery, deployment, and operations.

Hours are computed from the module table; recheck them when module durations change.

---

# 8. Accessibility and Inclusion Standards

- Text-first lessons in Markdown. No video required for any lab.
- Every command is shown for bash and PowerShell, with expected output.
- Plain language, defined terms on first use, and a glossary.
- No meaning conveyed by color alone in diagrams; diagrams have text equivalents.
- Time estimates per section and clear stopping points. Work lives in Git and the database, so it survives interruptions.
- Every lab runs locally with no outside service after setup.
- No real personal or financial data anywhere, and none required from the learner.

---

# 9. Expert Coverage Standard

"Expert" is measured against the product, not against a feeling. Phase A produces `coverage/bruin-feature-inventory.md` for the pinned Bruin version: every CLI command and flag, every asset type, every top-level and asset-level YAML key, every materialization strategy, every check, and every documented integration. Each row states one of:

- the lesson and lab that teach it, or
- out of scope with a one-line reason (for example, Cloud-only, or a platform the course does not use).

The Definition of Done requires every in-scope row to have a lesson and a lab or exercise. A new Bruin release triggers a diff against the inventory and a revision pass.

---

# 10. Asset Type Coverage Matrix

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

Additional asset types relevant to enterprise work (for example other platform-specific asset types) are surveyed in Module 5 from the docs index, with at most one short example each, and are tracked in the feature inventory.

---

# 11. Other Deliverables From the Planning Prompt

Each module ships these alongside the lesson, lab, and break/fix files (see the Prompt Guide for the file layout): learning objectives, estimated duration, facilitator notes, hands-on labs with expected outputs and validation steps, knowledge checks and quizzes, a common mistakes and troubleshooting guide, a target compatibility note, an expert track, and a reading list. The course repository also ships a suggested repository structure and a suggested Bruin project structure, both in the Prompt Guide, and the fast-track options above.

---

# 12. Recommended References

**Bruin:** official Bruin documentation (CLI, assets, materialization, sensors, quality checks, backfill).
**Postgres:** PostgreSQL documentation (roles, privileges, template databases). **Other targets (optional):** the platform documentation for your chosen target. **Official free Bruin content:** Bruin Academy, as complementary reading.
**Git:** Pro Git (free online).
**Data engineering:** The Data Warehouse Toolkit (optional, the course is self-contained), DataTalksClub Data Engineering Zoomcamp.

---

# 13. Final Learning Outcomes

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
12. Run and port a Bruin project across target platforms.
13. Operate and support a Bruin platform in production.
14. Explain how Bruin executes a run, and use that knowledge to diagnose failures that the documentation does not cover.
15. Tune a Bruin platform for performance and cost.
16. Show all of the above on an unfamiliar domain under time pressure (Expert designation).

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
| Postgres CDC through ingestr needs `wal_level: logical`, a publication, and a replication slot | Verified (optional **[Advanced]** topic, requires Postgres configuration) |
| DuckDB does not allow concurrency between processes | Verified (reason DuckDB is excluded as a target) |
| Ten built-in column checks; custom SQL checks with `blocking` flag | Verified |
| Sensors are per platform; docs show no Python, file, or HTTP sensor | Verified |
| `bruin backfill` is CLI-local and resumable | Verified |
| No built-in scheduler in the CLI | Verified (docs describe external orchestration) |
| GitHub Actions setup action `bruin-data/setup-bruin`; `bruin validate`, `bruin unit-test` | Verified |
| ingestr supports `sqlite://` and `csv://` sources | Verified |
| `CREATE DATABASE ... TEMPLATE` clones a database but fails if any other session is connected to the template; database-level grants are not copied | Verified (PostgreSQL docs); used only as an optional fast reset on Postgres |
| The Bruin VS Code extension is installed from the VS Code Marketplace | Verified (Bruin Academy install guide) |
| Bruin CLI installs and runs on Windows, macOS, and Linux without administrator rights, and with or without Docker | Verify |
| Whether Bruin installs `uv` itself or requires it on the path | Verify |
| ingestr behavior on Windows with no Docker (documentation does not state requirements) | Verify |
| Official Postgres container image page and a one-command start for the setup guide | Verify |
| Per-platform capability matrix (asset types, materialization strategies, sensors, checks, ingestr destinations) for Snowflake, SQL Server, MySQL, and other documented platforms | Verify (Phase A deliverable) |
| Schema versus database mapping for each platform, especially MySQL | Verify |
| Ingestr Postgres-to-Postgres incremental loads on `updated_at` where source and destination are the same server | Verify |
| Ingestr source and destination in the same database on other platforms | Verify |
| Cross-pipeline dependency syntax and CLI versus Cloud behavior | Verify |
| Custom Python sensors as Python assets that fail on timeout and block downstream | Verify (not documented as a feature; pattern relies on documented Python asset and dependency behavior) |
| Python quality-gate asset blocks downstream when it raises | Verify |
| `retries`, `rerun_cooldown`, and `timeout` behavior on Python assets | Verify (fields documented, Python-asset behavior not) |
| A documented way for a gate to skip downstream cleanly without failing the run | Verify |
| Native alerting available in the CLI (versus Bruin Cloud notifications) | Verify |
| Raw file archive plus load mechanism for daily extracts | Verify |
| Commands to render generated SQL, enable verbose or debug logging, and list run history in the pinned version | Verify (feeds Module 17 and the feature inventory) |
| Complete feature inventory of the pinned Bruin version (commands, flags, asset types, YAML keys) | Verify (Phase A deliverable) |
| `bruin validate` on a project configured for a platform the learner cannot reach | Verify |
| Optional real FX endpoint availability and terms | Verify |
