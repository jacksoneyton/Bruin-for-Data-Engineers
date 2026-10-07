# Bruin for Data Engineers: the course

A self-guided course for experienced data engineers. You work through 13 modules on your own machine against a Postgres database, using a fictional bank (Lakota Bank) and synthetic data. By the end you can build, run, test and operate Bruin pipelines, including without Bruin Cloud, and you have a plan for using Bruin in your own work.

Written against Bruin CLI v0.11.773 and the official docs at that version.

## What you need

- Git and a shell (Git Bash on Windows, bash on Linux or macOS).
- Bruin CLI (Module 0 covers installing and pinning it).
- A Postgres server you can create two databases on (Module 10 adds a third, `bruin_course_dev`). Use version 17 or newer if you want the history labs in Module 8. The `merge` strategy renders `MERGE INTO`, which needs version 15 or newer. No Docker is required. If you want an easy local server, the official Postgres container image is one option, but any server works.
- Python 3 on the path for a few helper steps. Bruin manages its own Python environments for Python assets.
- About 50 to 55 hours in total, spread however you like.

## The modules

| # | Module | Time | What you can do afterwards |
|---|---|---|---|
| 0 | [Setup and first run](modules/00-setup.md) | 1.5 to 2 h | Run a first Bruin pipeline against your database |
| 1 | [Project anatomy](modules/01-project-anatomy.md) | 2 h | Read and write the files that make up a project |
| 2 | [Landing data with ingestr](modules/02-landing-data.md) | 3 to 3.5 h | Load source tables incrementally and know how the window works |
| 3 | [SQL assets and materialization](modules/03-sql-materialization.md) | 4 to 4.5 h | Choose and justify a strategy for any table |
| 4 | [Running pipelines](modules/04-running-pipelines.md) | 2.5 h | Select, run, resume and inspect runs |
| 5 | [Data quality and unit tests](modules/05-data-quality.md) | 3.5 to 4 h | Write blocking checks, custom checks and unit tests |
| 6 | [Python assets and the SDK](modules/06-python-assets.md) | 3 h | Write Python assets that use the run window, variables and connections |
| 7 | [Templating, variables, variants, hooks](modules/07-templating-variables.md) | 3 h | Parameterize pipelines safely |
| 8 | [History and backfill](modules/08-history-and-backfill.md) | 3.5 to 4 h | Keep history with SCD2 and replay date ranges |
| 9 | [Sensors and cross-pipeline dependencies](modules/09-sensors-cross-pipeline.md) | 4 to 5 h | Make one pipeline wait for another without Bruin Cloud |
| 10 | [Environments and secrets](modules/10-environments-secrets.md) | 3 to 3.5 h | Run the same code in dev and production with credentials kept safe |
| 11 | [Operating Bruin](modules/11-operating-it.md) | 5 h | Alert, compare, scaffold, run CI and choose where to deploy |
| 12 | [Capstone and survey](modules/12-capstone-and-survey.md) | 10 to 13 h | Build a pipeline from a spec and plan its operation |

Do them in order. Each module assumes the earlier ones.

## How each module works

- **Outcome** at the top says what you will be able to do.
- **Docs to read** are file paths in the official Bruin docs repository (`docs/...`). Read them before the lab. The lessons are written from those pages and tell you which page each claim comes from.
- **Labs** use exact commands. Expected row counts are given for the three business days of synthetic data, so you can check yourself.
- **UNVERIFIED** marks anything the docs do not settle and the author could not test. Treat each one as a question to answer on your machine and record in the log.
- **Break/fix** exercises make you cause common errors on purpose. Answers are in collapsed sections.
- **Check questions** end each module. Answers are collapsed.
- **Validation log** at the end of each module is a table you fill in as you work: pass or fail and what actually happened. Commit your filled-in logs. They are the record of what is true on your machine and version.

## Where the labs run

Everything runs in two databases that Module 0 creates (`bruin_course` as the warehouse and `bruin_course_src` as the fictional source system). The reset script refuses to run against any other database name. Do not point the labs at a database that holds real data.

## Repository layout

```text
course/
  README.md            this file
  modules/             the 13 lessons
  data/                synthetic CSVs for days 1 to 3, reference tables, and the SQL that loads the source system
  tools/
    make_data.py       regenerates the CSVs (deterministic)
    reset.sh           resets the warehouse or the source to a known day
    run_if_ready.sh    windowed polling wrapper for cross-pipeline runs (Module 9)
    run_and_alert.sh   failure alert wrapper (Module 11)
    ci_local.sh        local pull-request checks (Module 11)
```

Your own work goes in a separate repository (Module 0 creates `lakota-bruin`), because a Bruin project is a Git repository with `.bruin.yml` at its root.

## What was and was not verified

The author wrote these lessons from the official docs and tested what could be tested without Bruin itself: the data generator, the source-system SQL, the reset script, the polling wrapper, the alert wrapper and the course's Postgres SQL on Postgres 16. The Bruin commands, YAML and asset behavior were not run by the author. Where the docs were silent or disagreed with each other, the lessons were checked against the Bruin v0.11.773 source code, and those statements say "source-derived". Reading the source is stronger than guessing and weaker than a run, so source-derived claims stay in your validation log until you have seen them. The audit that produced these checks is in `audit/2026-10-06-docs-audit.md`. Your validation logs close the remaining gap. When a command or an expected result in a lesson is wrong for your version, fix the lesson in this repository, and note it in the log.

## Conventions

- **Dates.** `bruin run` treats a date-only `--end-date` as midnight at the start of that day, which gives an empty or one-instant window. Every command in the course passes `--end-date "YYYY-MM-DD 23:59:59.999999"` to cover the whole day. `bruin backfill` treats a date-only end as inclusive.
- **Project setup.** You create the project with `bruin init` and `bruin connections add`, not by writing `.bruin.yml` by hand. The two exceptions are `${VAR}` references and `config.full_refresh_restricted`, which the CLI cannot store (Module 10).
- **Production names.** Bruin asks for confirmation only when an environment name contains `prod`, and only when `--environment` is passed explicitly (Module 10, 10.8).

## Recording findings

Anything you learn that contradicts a lesson, or answers an UNVERIFIED, goes in the module's validation log first. When a fact is settled, update the lesson text so the next reader benefits.
