# Curriculum Review Notes

Review of `Course_Curriculum_Outline.md` (v1) against the current Bruin and Snowflake documentation, dated 2026-10-05. Findings are ordered by impact.

Revision 3 (same day) changes the delivery model. See "Revision 3: hosted, paid, Postgres-first" below.

Revision 2 (same day): after reading `Curriculum_Planning_Prompt.md`, the original requirements document, findings 6 and 11 were corrected and the section "Corrections after reading the planning prompt" was added.

## Material problems in v1

| # | Finding | Basis | Resolution in v2 |
|---|---------|-------|------------------|
| 1 | Docker Desktop was required for "source simulation," and Gitea (typically self-hosted with runners) was required for CI. | Bruin docs list only Git as a prerequisite and run CI natively on `ubuntu-latest`. ingestr supports `sqlite://` and `csv://`. | Sources simulated with SQLite, CSV, and JSON fixtures. GitHub Actions is the CI reference. Gitea and GitLab become appendices. |
| 2 | Python 3.10+ was listed as required. | Bruin manages Python versions and dependencies through uv. | Python removed from requirements. Python experience is no longer a prerequisite for Modules 0-5. |
| 3 | Module order created forward references. `CUSTOMERS_HIST` was built in Module 3 before landing data existed (Module 4). Dependencies were taught in Module 6 but needed from Module 1. | Outline structure. | Landing precedes SQL assets. Dependencies moved to Module 4. |
| 4 | Severity levels Warning, Error, Critical were presented as a framework feature. | Bruin exposes `blocking` true or false on checks. No three-level severity system is documented. | Course-defined three-level vocabulary mapped onto blocking behavior, stated openly as a course convention. |
| 5 | Built-in checks included "Row Counts, Freshness, Schema Validation." | The documented built-ins are ten column checks. Others are written as custom SQL checks. | Corrected. Row count, freshness, and schema checks taught as custom SQL checks. |
| 6 | "Custom Python sensors" and a `validation.py` Python check framework. | Not documented as Bruin features. Sensors are per-platform asset types. | **Corrected in revision 2:** these are required course content. Built as documented patterns on Python assets (sensor gate, quality gate). See below. |
| 7 | Snowflake as the only target, with a trial that lasts 30 days from sign-up. | Snowflake trial documentation. | DuckDB for development, Snowflake trial begins at Module 13. Same assets run on both through environments. |
| 8 | Scheduling taught as if Bruin CLI schedules runs, including "SLA compliance" monitoring. | Docs describe external orchestration (Airflow, GitHub Actions, Cloud). No CLI scheduler. | Explicit note in Modules 5, 14, 15. GitHub Actions cron as the reference. |
| 9 | Naming inconsistency: `CUSTOMER_CURRENT` versus `CUSTOMER_MASTER`; `DIM_CUSTOMER` in both SCD2 and Mart layers. | Outline text. | Single naming table in section 3. Dimensions live in the SCD2 layer. |
| 10 | Materialization list omitted `ddl` and `view`, and did not note that `datavault_*` strategies are PostgreSQL and DuckDB only. | Materialization docs. | Complete list with caveats. |
| 11 | Dependency chain used `signature-daily`. | It came from the planning prompt, so it was your choice, not a leak. | Replaced with generic `core-banking-daily` for a shareable course. Easy to swap back. |
| 12 | Source entities Campaigns and Economic Indicators were listed but never used in a lab. Landing "Expected Outputs" listed three of the seven landing tables. | Outline text. | Stretch items. Seven landing tables defined. |
| 13 | Git flow used long-lived `staging` and `production` branches. | Design judgment, not a Bruin constraint. | Trunk-based with environment promotion recommended. Branch-per-environment retained as an appendix. |
| 14 | Prerequisites (2+ years SQL, 1+ year Python, Kimball and Snowflake reading) limit who can take the course. | Accessibility goal. | Lowered. Primers embedded. Reading made optional. |
| 15 | Fast-track durations (30 h, 37 h) could not be derived from the module table. | Arithmetic. | Recomputed: about 34 h and 43 h against the revised durations. |
| 16 | Total duration sums to 49 h plus capstone in v1. | Arithmetic. | v2.1 totals about 53.5 h plus capstone. |

## Corrections after reading the planning prompt

The planning prompt shows the audience is experienced engineers, and that several items I had trimmed were deliberate requirements.

- **Custom Python sensors restored as required content.** Module 11 grew from 3.5 h to 5 h and is split into native sensors (Part A) and custom Python sensors for generic sources (Part B). The motivating case is conditional execution: run only when conditions in the data are met, against sources with no Bruin connector. A new Vendor Feed source in the simulator supports it.
- **Honest labeling.** Bruin documents native sensors per platform and no Python sensor type. The course teaches custom Python sensors as a pattern on documented Python assets: the sensor succeeds when the condition holds and raises on timeout, so downstream assets do not run. Three implementation patterns are compared (in-process polling, retry-based using the documented `retries` and `rerun_cooldown` settings, and a pre-flight gate). Whether the failure and blocking behavior works exactly this way is the first thing Phase A tests.
- **Custom Python checks and `validation.py` restored.** Module 10 grew from 4 h to 4.5 h. Python checks are a quality-gate asset that writes to `dq_results` and raises on blocking failures. Severity levels map onto this plus the native `blocking` flag.
- **Planning-prompt items I had dropped, now restored:** control tables and publication patterns, alerting patterns, operational dashboards, code review, release management, rollback strategies, an asset-type coverage matrix (purpose, configuration, lifecycle, examples, troubleshooting), the raw immutable file archive for landing, and per-module common-mistakes guides.
- **Unchanged from my first pass:** no Docker, no required local Python install, DuckDB-first with a Snowflake module, GitHub Actions as the CI reference, reordered modules, corrected check and materialization facts.
- **Tension to be aware of:** the planning prompt targets experienced engineers, while the request to make the course available to anyone pushed prerequisites lower. The outline keeps lower prerequisites and adds a Python primer, since Modules 10 and 11 use Python heavily. If you prefer the original audience, raise the Python prerequisite and drop the primer.


## Revision 3: hosted, paid, Postgres-first

Decisions made by the course author after the first two revisions:

- The course is delivered only as a hosted, paid, inexpensive browser service (VS Code in the browser). No local option.
- Self-hosted on rented bare-metal servers. The platform is specified in `Hosted_Platform_Build_Spec.md`.
- Snowflake is no longer required anywhere. Module 13 became "Cloud Warehouses and Porting", optional, with no account needed.
- Postgres is the platform warehouse from Module 2. Core banking and CRM are Postgres source databases. DuckDB is used for first-run exercises and an engine-comparison lab. SQLite is the mortgage source.

Why Postgres: Bruin's DuckDB docs state that DuckDB does not allow concurrency between processes. The v2.1 design had sensors and cross-pipeline waits polling a DuckDB file while pipelines wrote to it, which that limitation makes unreliable. Postgres supports concurrent sessions, and Bruin documents `pg.sql`, `pg.seed`, `pg.sensor.table`, `pg.sensor.query`, and `pg.source`, plus `merge`, both `scd2` strategies, and the Data Vault strategies on Postgres.

Changes to the course:

- Module 0 became an environment tour. All install, Windows, macOS, and "three paths" content was removed.
- Module 5 gained Bruin environments for dev, staging, and production, each a separate Postgres database, and a scheduler harness that triggers pipelines against the simulated clock.
- Module 11 uses Postgres sensors.
- Module 14 uses a built-in `make ci` flow and a review exercise pack. GitHub Actions is an optional lab that needs outbound access.
- The Source Simulator now writes to Postgres sources and includes a mock API with fault switches.
- Every step gets a manifest entry, starter and solution tags, a JSON-lines check, and a database template for instant reset.
- Total course time is about 53 hours (including optional Module 13) plus the capstone. Fast-Track A is about 34 hours and Fast-Track B about 42.5 hours.

Things I found while researching this revision that you should weigh:

- **Free competing content.** Bruin Academy lists dozens of free guides and courses, including a data engineer track. The paid course needs to compete on depth, the ready environment, verification, custom sensors, and recovery drills.
- **ingestr license.** FSL-1.1-ALv2 permits education but prohibits competing commercial ingestion services. A paid course should obtain written confirmation from Bruin Data Limited.
- **Bruin VS Code extension.** The install guide lists the VS Code Marketplace. Whether it can be installed in an open-source hosted editor is unverified.
- **Hosting prices.** Reports say a major bare-metal provider raised prices in April and June 2026. No hosting figure in the docs should be trusted without a current quote.
- **Postgres resets.** `CREATE DATABASE ... TEMPLATE` fails if any other session is connected to the template, so the reset flow must terminate sessions first.
- **Module 14.** It cannot be fully self-contained if learners want real CI. The built-in `make ci` covers the concepts, and the real CI lab stays optional.

## Revision 4: execution process and prerequisites

Added `Master_Execution_Guide.md` and `Prerequisites_Checklist.md`, and patched the master prompts in `Course_Build_Prompt_Guide.md` and `Hosted_Platform_Build_Spec.md`, plus the outline's Appendix A intro.

- Claude is now told to investigate gaps, research, and write its own knowledge and data files (`docs/knowledge/`, `docs/adr/`, `docs/data/`, `docs/spike/`) without asking, and to ask only for Tier 3 decisions.
- Durable memory lives in version-controlled files, not in chat or auto memory, so you can review and correct it. Each session starts from `SESSION_HANDOFF.md` and ends by overwriting it.
- Every session plans first and waits for approval (plan mode), and ends with verification.
- Source hierarchy for research: running it, source code, official docs, release notes, third-party leads, then prior knowledge. Summarizing fetch tools are not enough for load-bearing claims.
- Prerequisites P1 to P18 are tied to phases. Items with long lead times (test host, payment account review, ingestr confirmation, legal and tax advice, accessibility testers) are marked start-early.
- New risk to weigh: the planning prompt appears to derive from your work at a bank. Confirm your employment and IP terms allow creating and selling this course before investing build time. See the prerequisites checklist section 10.
- Unverified in this revision: Claude Code plan limits and pricing change over time, and the cost figures cited are the documented averages for typical use. This project is heavier than typical, so set a budget cap.

## Added in v2

- Three paths: Local (no accounts), Local plus GitHub, Full (Snowflake).
- Source Simulator specification with fault injection and per-day manifests.
- Automated self-check for every module and an automated capstone grader.
- `starter` and `solution` tags per module.
- Accessibility and inclusion standards.
- Verification status appendix.

## Open items and uncertainty

- Ingestr assets on Windows and with no Docker: documentation does not state requirements explicitly. Treat as unverified until tested on a clean machine.
- Custom Python sensor and Python quality-gate behavior (blocking downstream on failure, retry and cooldown semantics, any clean-skip mechanism) is inferred from documented Python asset and blocking behavior, not documented for this use. Phase A tests it.
- Native notifications appear to be a Bruin Cloud feature. CLI alerting is unverified, so the course uses a webhook and table-based alert helper.
- Cross-pipeline dependency documentation could not be retrieved (404). Syntax and CLI versus Cloud support are unverified.
- Snowflake password sign-in policy for new accounts may have tightened (my recollection, not verified). Module 13 uses key-pair authentication as the primary path as a precaution.
- Platform differences between DuckDB and Snowflake in `scd2_*` and `merge` edge cases were not tested.
- All verified items come from documentation fetched during this review, summarized by a fetch tool. Spot-check load-bearing items during Phase A.
