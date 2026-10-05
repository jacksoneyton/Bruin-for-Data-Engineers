# Curriculum Review Notes

Review of `Course_Curriculum_Outline.md` (v1) against the current Bruin and Snowflake documentation, dated 2026-10-05. Findings are ordered by impact.

## Material problems in v1

| # | Finding | Basis | Resolution in v2 |
|---|---------|-------|------------------|
| 1 | Docker Desktop was required for "source simulation," and Gitea (typically self-hosted with runners) was required for CI. | Bruin docs list only Git as a prerequisite and run CI natively on `ubuntu-latest`. ingestr supports `sqlite://` and `csv://`. | Sources simulated with SQLite, CSV, and JSON fixtures. GitHub Actions is the CI reference. Gitea and GitLab become appendices. |
| 2 | Python 3.10+ was listed as required. | Bruin manages Python versions and dependencies through uv. | Python removed from requirements. Python experience is no longer a prerequisite for Modules 0-5. |
| 3 | Module order created forward references. `CUSTOMERS_HIST` was built in Module 3 before landing data existed (Module 4). Dependencies were taught in Module 6 but needed from Module 1. | Outline structure. | Landing precedes SQL assets. Dependencies moved to Module 4. |
| 4 | Severity levels Warning, Error, Critical were presented as a framework feature. | Bruin exposes `blocking` true or false on checks. No three-level severity system is documented. | Course-defined three-level vocabulary mapped onto blocking behavior, stated openly as a course convention. |
| 5 | Built-in checks included "Row Counts, Freshness, Schema Validation." | The documented built-ins are ten column checks. Others are written as custom SQL checks. | Corrected. Row count, freshness, and schema checks taught as custom SQL checks. |
| 6 | "Custom Python sensors" and a `validation.py` Python check framework. | Not documented. Sensors are per-platform asset types. | Removed from objectives. Flagged for hands-on verification in Phase A. |
| 7 | Snowflake as the only target, with a trial that lasts 30 days from sign-up. | Snowflake trial documentation. | DuckDB for development, Snowflake trial begins at Module 13. Same assets run on both through environments. |
| 8 | Scheduling taught as if Bruin CLI schedules runs, including "SLA compliance" monitoring. | Docs describe external orchestration (Airflow, GitHub Actions, Cloud). No CLI scheduler. | Explicit note in Modules 5, 14, 15. GitHub Actions cron as the reference. |
| 9 | Naming inconsistency: `CUSTOMER_CURRENT` versus `CUSTOMER_MASTER`; `DIM_CUSTOMER` in both SCD2 and Mart layers. | Outline text. | Single naming table in section 3. Dimensions live in the SCD2 layer. |
| 10 | Materialization list omitted `ddl` and `view`, and did not note that `datavault_*` strategies are PostgreSQL and DuckDB only. | Materialization docs. | Complete list with caveats. |
| 11 | Dependency chain used `signature-daily`, which appears to be an internal system name. | Outline text. | Replaced with generic `core-banking-daily`. Confirm no other internal details remain. |
| 12 | Source entities Campaigns and Economic Indicators were listed but never used in a lab. Landing "Expected Outputs" listed three of the seven landing tables. | Outline text. | Stretch items. Seven landing tables defined. |
| 13 | Git flow used long-lived `staging` and `production` branches. | Design judgment, not a Bruin constraint. | Trunk-based with environment promotion recommended. Branch-per-environment retained as an appendix. |
| 14 | Prerequisites (2+ years SQL, 1+ year Python, Kimball and Snowflake reading) limit who can take the course. | Accessibility goal. | Lowered. Primers embedded. Reading made optional. |
| 15 | Fast-track durations (30 h, 37 h) could not be derived from the module table. | Arithmetic. | Recomputed: about 32 h and 41 h against the new durations. |
| 16 | Total duration sums to 49 h plus capstone in v1. | Arithmetic. | v2 totals about 52 h plus capstone. |

## Added in v2

- Three paths: Local (no accounts), Local plus GitHub, Full (Snowflake).
- Source Simulator specification with fault injection and per-day manifests.
- Automated self-check for every module and an automated capstone grader.
- `starter` and `solution` tags per module.
- Accessibility and inclusion standards.
- Verification status appendix.

## Open items and uncertainty

- Ingestr assets on Windows and with no Docker: documentation does not state requirements explicitly. Treat as unverified until tested on a clean machine.
- Cross-pipeline dependency documentation could not be retrieved (404). Syntax and CLI versus Cloud support are unverified.
- Snowflake password sign-in policy for new accounts may have tightened (my recollection, not verified). Module 13 uses key-pair authentication as the primary path as a precaution.
- Platform differences between DuckDB and Snowflake in `scd2_*` and `merge` edge cases were not tested.
- All verified items come from documentation fetched during this review, summarized by a fetch tool. Spot-check load-bearing items during Phase A.
