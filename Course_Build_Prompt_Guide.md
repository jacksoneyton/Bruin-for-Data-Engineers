# Course Build Prompt Guide

Purpose: a set of prompts for Claude (best run in Claude Code inside the course repository) to build the actual "Bruin for Data Engineers" course from `Course_Curriculum_Outline.md` (v3.0). The hosted platform that delivers the course is built separately from `Hosted_Platform_Build_Spec.md`. The two projects meet at the content contract in section 6 of that spec (module manifests, check output format, environment recipe).

Sources of truth, in priority order: (1) `Curriculum_Planning_Prompt.md`, which holds the original requirements and intent; (2) `Course_Curriculum_Outline.md`, which holds how those requirements are met; (3) this guide. If the outline contradicts the planning prompt, follow the prompt and report the conflict.

Process documents: `Master_Execution_Guide.md` governs how every session runs (planning, research, knowledge files, decision tiers, handoffs). `Prerequisites_Checklist.md` lists what the author must provide. Where this guide and the master guide differ on process, the master guide wins. Where they differ on course content, this guide and the outline win.

Research is expected. This guide and the outline contain known gaps (outline Appendix A, items marked Verify) and will have unknown ones. Claude investigates them using the research protocol in the master guide section 4, records results in `docs/knowledge/`, and continues. Claude asks the author only for decisions in the master guide section 7 (Tier 3).

How to use: run the phases in order. Paste the Master Context Prompt at the start of every new session. Build one module per session, commit after each, and do not start a module until the previous module's self-check passes on a clean checkout.

---

## 1. Master Context Prompt (paste at the start of every session)

```text
You are helping build "Bruin for Data Engineers", a project-based course. The
authoritative plan is Course_Curriculum_Outline.md in this repository. Read
Master_Execution_Guide.md in full first, and follow its start-of-session routine
(handoff, knowledge index, plan, wait for approval) and end-of-session routine
(knowledge files, build log, handoff, commit, no push). Then read the outline
sections relevant to the phase. Knowledge files live in docs/knowledge/
(VERIFIED_FACTS, ASSUMPTIONS, OPEN_QUESTIONS, DECISIONS, RISKS, BUILD_LOG,
SESSION_HANDOFF, research/). Wherever this prompt says docs/VERIFIED_FACTS.md,
use docs/knowledge/VERIFIED_FACTS.md.

You are expected to investigate. When a fact is unverified, a document disagrees
with reality, or you need a pattern for a requirement Bruin lacks a feature for,
research it using the source hierarchy in the master guide, record the result,
and continue. Create new files under docs/knowledge, docs/adr, docs/data and
docs/spike as needed without asking. Ask me only for Tier 3 decisions.

Read Curriculum_Planning_Prompt.md as well. It is the original requirements
document. The outline is how those requirements are met.

Hard constraints:
1. The course is delivered only in a hosted browser environment (see
   Hosted_Platform_Build_Spec.md). Learners install nothing, need no outside
   account, and never see Docker or containers. Do not write any step that asks a
   learner to install software, use their own terminal, or sign up for a service.
   If a step seems to need one, stop and propose an alternative.
2. Postgres is the platform warehouse from Module 2 onward. DuckDB is used for the
   first-run exercises, an engine-comparison lab in Module 3, and local file
   analytics. SQLite is the mortgage source. Core banking and CRM are Postgres
   source databases. Snowflake is not required anywhere. Module 13 is optional
   reading and worksheets about cloud warehouses and needs no account.
3. Bruin documents that DuckDB does not allow concurrency between processes.
   Never design a lab where a sensor, a second pipeline, or a check connects to a
   DuckDB file while Bruin is writing to it. Use Postgres for those.
4. Python is not installed by the learner. Bruin manages Python through uv. The
   environment ships pre-cached interpreters and packages, so labs need no
   internet. Do not write instructions that assume a system Python.
5. Every lab must be completable inside the environment with no outside network.
   Anything that needs an outside service (the optional GitHub CI lab, an optional
   real API) is labeled optional and must have an in-environment alternative.
6. All data is synthetic and deterministic. No real personal or financial data.
7. Never invent Bruin features, flags, YAML keys, or asset types. Every Bruin
   claim must be traceable to the official docs (https://bruin-data.github.io/bruin/)
   or to a command you actually ran. Record each in docs/VERIFIED_FACTS.md with
   the source URL or the command and its output, and the Bruin version.
8. Pin the Bruin version in the repository and CI. Record it in
   docs/VERIFIED_FACTS.md.
9. When the docs and the curriculum disagree about what Bruin does, the docs
   win. Report the disagreement and propose a curriculum edit. Do not silently
   paper over it. Required course content never gets dropped because Bruin lacks
   a native feature. Instead, build it as a pattern on documented features and
   label it clearly as a course pattern.
10. Custom Python sensors and custom Python quality checks are required content.
    Bruin documents native sensors per platform (for example pg.sensor.table,
    pg.sensor.query, duckdb.sensor.query) and SQL custom checks, but no Python sensor
    or Python check type. Teach them as Python assets placed in the dependency
    graph: a sensor asset succeeds when a data condition is met and raises on
    timeout so downstream assets do not run; a quality gate asset records results
    and raises on blocking failures. Never present these patterns as official Bruin
    asset types. Verify the real behavior in Phase A before writing about it.
11. The reason custom sensors exist is conditional execution: run only when
    conditions in the data are met, against generic sources (file drops, vendor
    feeds, status tables, web endpoints) that have no Bruin connector. Every
    sensor lesson must start from such a scenario.
12. For every asset type, cover purpose, configuration, execution lifecycle,
    production examples, and troubleshooting.

Style rules for all course text:
- Plain language, short sentences, define each term on first use.
- Markdown only. No emojis. No em dashes.
- Technical and direct. No marketing tone, no filler openers.
- Every code block has a language tag. Every command shows expected output.
- No information conveyed by color alone. Diagrams are text with a prose
  equivalent.

Working rules:
- Do the work for the phase I name and stop. Do not start the next phase.
- Run every command and lab you write on a clean checkout before declaring done.
- Report anything you could not verify instead of guessing.
- Commit with a message naming the module and phase.

Confirm you have read the outline and list the three biggest risks you see for
the phase I am about to give you. Then wait for the phase prompt.
```

---

## 2. Repository Layout Specification

Give this to Claude in Phase B. It defines where everything lives.

```text
bruin-course/
 ├── README.md                    (what the course repository is and how the platform consumes it)
 ├── .bruin.yml.example           (committed template; the real .bruin.yml is created per workspace and git-ignored)
 ├── .gitignore
 ├── BRUIN_VERSION                (pinned version)
 ├── environment/                 (workspace recipe: version pins, simulator and mock API services, scheduler harness, database seeds and template builders; consumed by the platform image build)
 ├── Curriculum_Planning_Prompt.md  (original requirements, kept for reference)
 ├── docs/
 │    ├── VERIFIED_FACTS.md       (every Bruin claim with source)
 │    ├── BUILD_LOG.md            (what was built, open issues)
 │    ├── GLOSSARY.md
 │    └── appendices/             (python-primer, gitea, gitlab, branch-per-env)
 ├── simulator/                   (Source Simulator and mock API, offline, deterministic, writes to the Postgres source databases)
 ├── data/                        (generated SQLite mortgage file, CSV, JSON fixtures, manifests, immutable landing archive)
 ├── modules/
 │    └── NN-title/
 │         ├── lesson.md
 │         ├── lab.md
 │         ├── break-fix.md
 │         ├── knowledge-check.md   (questions and an answers section)
 │         ├── common-mistakes.md   (mistakes and troubleshooting guide)
 │         ├── manifest.yaml        (steps, tags, resets, check commands, hints; schema in Hosted_Platform_Build_Spec.md section 6)
 │         ├── checks/              (one script per step, JSON-lines output, exit 0 or 1)
 │         └── instructor-notes.md
 ├── platform/                    (the evolving Bruin project learners build in)
 │    ├── pipelines/
 │    └── lib/
 │         ├── sensors.py          (sensor contract and condition library, Module 11)
 │         ├── validation.py       (rules, severities, dq_results writer, Module 10)
 │         └── alerts.py           (webhook and table alert helper, Module 10)
 └── capstone/
      ├── brief.md
      ├── rubric.md
      └── capstone-check/
```

Git tags: `module-NN-sMM-starter` and `module-NN-sMM-solution` for every step (and `module-NN-starter` and `module-NN-solution` for every module). The platform resets a learner to a step by checking out its starter tag and restoring the matching database template and simulator state. The course repository must contain a database template builder for each step that needs one. Solutions are not shipped to learners until they request them through the platform.

---

## 3. Phase Prompts

### Phase A: Research and Verification Spike

```text
Phase A: verification spike. Do not write any course content yet.

On the platform's prototype workspace, or any equivalent clean Linux machine until the platform exists (a clean Linux environment with the pinned
Bruin, uv, Postgres, DuckDB, SQLite, and Git, and no outside network apart from the
documentation sites for reading), verify each item below by running it and by
reading the official docs. Write results to docs/VERIFIED_FACTS.md with the Bruin
version, the exact commands, and the observed output.

1. Install state: confirm Bruin runs with no Docker and that uv-managed Python
   assets run with no system Python and no internet once the uv cache is warm.
   Record exactly what must be pre-cached in the image.
2. bruin init with a template, then bruin validate and bruin run against DuckDB,
   then against Postgres (pg.sql, pg.seed). Record the .bruin.yml connection
   shape for each.
3. An ingestr asset with a Postgres source (incremental on updated_at) into the
   Postgres warehouse. Then a SQLite source (sqlite:///...), then csv://. Record
   incremental behavior, deletes, and late-arriving rows. Confirm no Docker.
   Determine whether Postgres CDC (wal_level logical, publication, slot) is
   practical to offer as an Advanced topic inside a workspace.
4. Can an ingestr or Python asset read a daily-partitioned extract, for example
   by using the run date (BRUIN_START_DATE or Jinja variables) in a path or
   query? Determine the cleanest way to simulate "advance one business day".
5. A Python asset that returns a DataFrame or list of dicts and is materialized
   by Bruin into Postgres. Confirm no system Python is required.
6. All materialization strategies on Postgres and on DuckDB: create+replace,
   truncate+insert, append, delete+insert, merge, time_interval, ddl,
   scd2_by_column, scd2_by_time, and the datavault_hub, datavault_link, and
   datavault_satellite strategies. Record required fields, surprises, and any
   strategy that fails on either engine.
7. Built-in column checks and custom_checks, including blocking true and false.
   Look for any native Python check support. Determine how row count, freshness,
   and schema checks are best expressed in SQL. Then build a prototype Python
   quality-gate asset that writes to a dq_results table and raises on a blocking
   failure. Confirm that downstream assets do not run when it raises, and what
   the run output and exit code look like.
8. Sensors: pg.sensor.table and pg.sensor.query behavior (documented default poll
   of 30 seconds), poke_interval, timeout, and whether a sensor can poll Postgres
   while an upstream pipeline is still writing to it. Whether a sensor can gate a
   different pipeline. Look for any native Python or generic (file, HTTP) sensor.
   Then prototype the three custom Python sensor patterns from Module 11 against
   a simulated drop-folder file:
   (a) an in-process polling gate with poke_interval and timeout;
   (b) a retry-based gate using the documented retries, rerun_cooldown, and
       timeout asset settings (determine the real semantics for Python assets,
       including how attempts and cooldown behave and what is logged);
   (c) a pre-flight gate run before bruin run, using the exit code.
   Determine whether a gate can end a run cleanly without failing it (a skip
   or no-op mechanism), and if not, verify the control-table fallback: the gate
   records NOT_READY and a blocking custom check stops downstream assets.
   Record how each pattern appears in logs and exit codes, since Module 11
   break/fix scenarios depend on it.
9. Cross-pipeline dependencies: the uri field and depends with uri. What works
   in the CLI versus only in Bruin Cloud. (The docs page for this could not be
   retrieved during the curriculum review, so use the docs index and test directly.)
10. bruin backfill and bruin run date flags against Postgres. Idempotency of each
    materialization under re-run.
11. bruin unit-test: what it supports.
12. Environments: dev, staging, and production as three Postgres databases selected
    through Bruin environments. Confirm make ci style promotion works end to end.
13. Step resets: confirm that a Postgres database can be reset to a known state per
    step using CREATE DATABASE ... TEMPLATE (documented to fail if any other session is
    connected to the template) and measure the time. Compare with restoring a
    snapshot of the data volume.
14. Scheduler harness: build a minimal harness that triggers pipelines on their
    pipeline.yml cron schedule against the simulated clock, since the Bruin CLI has
    no scheduler. Record its limits.
15. Alerting: determine what notification support the CLI has (the docs
    appear to tie notifications to Bruin Cloud). If none, confirm the webhook
    and table-based alert helper approach works from a Python asset.
16. Raw file archive: confirm the cleanest way to write each simulated day's
    extract once to an immutable archive and load from it, so any day can be
    replayed.
17. Editor environment: confirm the Bruin VS Code extension installs in the
    hosted editor (registry or packaged file), and that Bruin's lineage and
    rendering features work in it. The Bruin install guide lists the VS Code
    Marketplace, which open-source hosted editors may not use.
18. Optional: GitHub Actions with bruin-data/setup-bruin, to support the optional
    Module 14 lab. Record the egress it needs.

Deliverables: docs/VERIFIED_FACTS.md and a short list of curriculum edits needed
because reality differed from the outline. Do not edit the outline yourself;
propose the changes.
```

### Phase B: Scaffold and Source Simulator

```text
Phase B: scaffold the repository per the layout specification (section 2 of the
Prompt Guide) and build the Source Simulator.

Simulator requirements:
- Runs inside the workspace with no outside network. Standard library plus
  Postgres and SQLite drivers that are already in the image, or run as a
  Bruin-managed Python asset if Phase A showed that is cleaner. State which and why.
- Deterministic from a seed. Same seed gives identical output.
- Writes to the Postgres source databases src_core_banking (customers, accounts,
  transactions) and src_crm (crm_customers, interactions), with updated_at columns
  that support incremental loads. Produces CSV (branches, products), JSON fixtures
  and a mock API for FX rates, and a Mortgage SQLite database (loans, payments,
  borrowers) for the capstone.
- Mock API service: REST with pagination and authentication, plus fault switches
  (HTTP 500, HTTP 429, slow responses, expired credential, pagination change,
  schema drift).
- Command to advance one simulated business day, and to reset to day 0. The
  simulator state is part of a step reset and can be set to a named state.
- A manifest file per day listing true row counts and checksums per table, used
  by checks.
- Fault injection switches: late-arriving rows (backdated updated_at), duplicates,
  corrupted day, partial load, schema drift, deleted source rows. Each is
  documented, reversible, and recorded in the manifest.
- A shared customer population across Core Banking and CRM with deliberate
  overlap and conflicts, so Module 8 survivorship rules have real work to do.
- A Vendor Feed generic source: a drop folder of daily files with a manifest
  (row count, checksum, business date) and a status table with a completeness
  flag. Controls to delay arrival, deliver in growing chunks, deliver an empty or
  under-threshold file, flip the completeness flag late, deliver a checksum
  mismatch, and deliver a prior day's file by mistake. All controls are
  deterministic and recorded in the manifest. Simulated time must not require real
  waiting: the simulator exposes a clock the sensors can read so labs run in seconds.
- An immutable per-day raw file archive (data/landing/<source>/<date>/).
- Realistic but fake: names, emails, and addresses from clearly synthetic generators.
- Database template builders so each step can be reset instantly.

Also build: README.md, .gitignore (including .bruin.yml), .bruin.yml.example, the
BRUIN_VERSION file, the environment/ recipe, the Module 0 manifest and checks, and
the platform/ skeleton.

Verify in a fresh workspace: reset, advance 5 days, confirm manifests match actual
counts, confirm determinism by running twice and diffing, and confirm a step reset
restores files, database, and simulator clock.
```

### Phase C: Module Build (repeat per module)

Use this template once per module. Fill the bracketed fields from section 4.

```text
Phase C: build Module [N]: [TITLE].

Inputs: Course_Curriculum_Outline.md (the Module [N] section), docs/VERIFIED_FACTS.md,
and the repository state at tag module-[N-1]-solution.

Produce in modules/[NN-title]/:
1. lesson.md: concept explanation, short primer sections where the outline says so,
   all commands with expected output, and "Cloud warehouse notes" callouts only in
   Module 13. Target 20-30 minutes of reading for each hour of module time.
2. lab.md: numbered steps, each with a command, expected result, and what to do if
   the result differs. Include a "why this works" note per major step.
3. break-fix.md: the broken scenario, symptoms only (not the answer), hints in
   three tiers, and an answers section at the end.
4. knowledge-check.md: 5-8 questions with an answers section that explains each answer.
   common-mistakes.md: the mistakes learners actually made or would likely make,
   with symptom, cause, and fix.
5. manifest.yaml and checks/: one check script per step. Each prints one JSON
   object per line (criterion, status, message) and exits 0 on pass and non-zero on
   fail, following the contract in Hosted_Platform_Build_Spec.md section 6. Each
   failure message must be specific. Include starter and solution tags per step,
   database template builders, hints (three tiers), and the simulator state for
   each step.
6. instructor-notes.md: common mistakes, timing, extension ideas.
7. The platform/ changes for this module's starter and solution states, committed
   and tagged module-[N]-starter and module-[N]-solution.

Rules:
- Every Bruin feature you mention must exist in docs/VERIFIED_FACTS.md. If it does
  not, verify it now and add it, or remove it. Course patterns (Python sensors,
  Python quality gates, control tables, severity levels) are labeled as course
  patterns, and the Bruin features they rely on are cited.
- For any asset type introduced in this module, cover purpose, configuration,
  execution lifecycle, a production-style example, and troubleshooting.
- Run the entire lab from the starter tag in a fresh workspace, using the engine
  the outline names for that module (Postgres from Module 2 onward).
- For any step that has a database state, test a reset to that step.
- Run the break/fix scenario and confirm the symptoms match what you wrote.
- Confirm each check fails on its starter tag and passes on its solution tag.
- Check reading level: short sentences, no undefined jargon.

Finish with a short report: what you built, what you verified and how, what you
could not verify, and any curriculum changes you recommend. Do not begin the next module.
```

### Phase D: Break/Fix Fixtures and Mid-Course Practical

```text
Phase D: build the mid-course practical (after Module 9) and the operations drill
(Module 15).

Mid-course practical: a copy of the platform containing at least eight distinct
faults spanning: a misspelled connection, a merge without primary_key, a circular
dependency, an invalid schedule, a wrong materialization strategy, a failing
blocking check, an SCD2 with the wrong key, and a layer that skips history.
Each fault must be discoverable from bruin validate, run logs, or checks. Provide
a facilitator answer key, a learner-facing scoring checklist, and a self-check
that reports how many faults remain.

Operations drill: three chained incidents driven by simulator fault switches
(a late Vendor Feed file that times out a custom Python sensor, a failing blocking
check, a bad deploy requiring rollback). Include a runbook template and a
post-incident report template.

Verify that every fault is detectable and that the answer key's fixes make the
self-check pass.
```

### Phase E: Capstone and Automated Grader

```text
Phase E: build the capstone.

Create capstone/brief.md, rubric.md, and capstone-check/.

The brief: onboard the Mortgage Servicing source into the platform following the
requirements in the outline. Include a reference architecture diagram (text and
prose), acceptance criteria, and the two reporting facts to build.

capstone-check must automatically verify: required schemas and tables exist;
dim_customer, dim_account, dim_mortgage have exactly one current row per key and
contiguous valid ranges; fact grain is stated and enforced by a check; blocking and
warning checks both exist; cross-pipeline dependency is data-state based; at least one custom Python sensor
exists, has a bounded timeout, records evidence to the control table, has plain
Python unit tests, and the Vendor Feed run proceeds only after the sensor passes;
a Python quality-gate rule and a SQL check of each severity exist; a backfill
over a date range and a rebuild from history both reproduce identical results;
the CI workflow file exists and runs validate and tests.

Rubric items needing human judgment (architecture, documentation) get a checklist
with observable criteria, not adjectives.

Build a reference solution and prove capstone-check passes on it and fails on the
module-15 solution.
```

### Phase F: Fresh-Workspace QA

```text
Phase F: quality assurance. You are a new learner with no prior context, using
only a browser and the written materials in a freshly created workspace.

1. Follow the course from Module 0 through Module 3 using only the written
   materials. Record every point of confusion, missing prerequisite, command
   that failed, and unexplained term.
2. Confirm no step requires the learner to install anything, use Docker, use an
   outside account, or reach an outside network (optional labs excepted and
   labeled).
3. Run platform-validate-content (Hosted_Platform_Build_Spec.md section 6.4) for
   every module.
4. Run the accessibility checklist in section 6 of the Prompt Guide, including a
   keyboard-only pass and a screen reader pass.
5. Run a link check on all URLs and a grep for em dashes and emojis. Grep for
   "Docker" and "docker": each remaining mention must be an explicit statement
   that it is not needed.

Output: a prioritized defect list with file and line references, then fix the
high-priority items and rerun.
```

### Phase G: Packaging

```text
Phase G: package the course. Produce the final README, a course landing page in
Markdown, a CHANGELOG, a CONTRIBUTING guide, and a LICENSE recommendation. Tag the
release. List the Bruin version it was built against and the process for upgrading
it (which docs and checks to rerun, and the platform image rebuild, when Bruin releases a new version).
```

---

## 4. Per-Module Addenda (fill into the Phase C template)

| N | Module | Required deliverables beyond the template | Verify before writing |
|---|--------|-------------------------------------------|-----------------------|
| 0 | Environment Tour and First Run | Guided tour steps, first-run checks, broken `.bruin.yml` fixture, accessibility settings step, reset and export walkthrough | Layout of the hosted editor, Bruin extension availability, DuckDB and Postgres connection shapes |
| 1 | Fundamentals | Kimball vocabulary primer (one page), seed plus SQL asset lab | `bruin init` templates, `bruin query`, `bruin lineage` output |
| 2 | Landing Ingestion | Seven landing assets, load metadata columns, manifest count check | ingestr from Postgres, sqlite://, and csv:// into Postgres, incremental key behavior, deletes and late rows, daily-extract mechanism |
| 3 | SQL and Materialization | Strategy lookup table exercise, three-strategy lab, DuckDB versus Postgres engine-comparison lab, optional Data Vault aside | Required fields and failure modes per strategy on Postgres and DuckDB, datavault strategy behavior |
| 4 | Dependencies and Lineage | Circular and missing-upstream fixtures, parallelism prediction exercise | `--workers`, `--downstream`, how cycles are reported |
| 5 | Pipeline Design | Four ingest pipelines, shared `lib/`, schedule fixture | Valid schedule syntax, variables, default connections, environment flags |
| 6 | Python Assets | `fx_rates_fetch.py` with offline fallback, secrets injection lab, `lib/` shared code, failure-semantics lesson (exception versus exit code versus downstream blocking) | uv dependency files, DataFrame and list-of-dicts materialization, env vars, what happens downstream when a Python asset raises |
| 7 | Historical Layer | Four `_hist` assets, reconciliation checks, three reprocessing scenarios | Append versus merge patterns for history, late-arriving fault behavior |
| 8 | Integration Layer | Golden record with documented survivorship matrix | Merge strategies on Postgres and survivorship patterns |
| 9 | SCD Type 2 | `dim_customer` and `dim_account` with both scd2 strategies, late correction advanced lab | scd2_by_column versus scd2_by_time semantics, behavior on rebuild and late data |
| 10 | Data Quality | `lib/validation.py`, `lib/alerts.py`, SQL check templates, Python quality-gate asset, `dq_results` and `run_log` tables, dashboard views, severity demonstration with simulator faults, `bruin unit-test` intro | Native Python check support, failure propagation downstream, retries and cooldown on Python assets, alert options in the CLI |
| 11 | Sensors and Python Sensors | Part A: native SQL sensor and control tables (`ctl.processing_dates`, `ctl.publication_log`). Part B: `lib/sensors.py` with the sensor contract and condition library, Vendor Feed labs B1 to B5, the three implementation patterns, five break/fix scenarios, plain-Python tests | Cross-pipeline syntax, pg.sensor.* semantics, timeouts, the real behavior of all three Python gate patterns, any clean-skip mechanism |
| 12 | Replay and Recovery | Five recovery scenarios with fault switches, idempotency proof | backfill flags, resume behavior, run-twice idempotency per strategy |
| 13 | Cloud Warehouses and Porting (optional) | Dialect worksheet with answer key and checker, port plan template, read-the-config exercise, Postgres-to-Snowflake role translation table | Bruin Snowflake docs (connection fields, sf.* asset types, materialization support), whether bruin validate works on an unreachable platform config |
| 14 | Git Deployment | `make ci` pipeline with staging and production Postgres databases, review exercise pack with automated review checks, PR review checklist, release notes template, rollback lab, optional GitHub Actions lab | Bruin environments for staging and production, setup-bruin version pinning, scheduled trigger, snapshot and template-clone rollback timing |
| 15 | Operations | Runbook and post-incident templates (including late-vendor-feed runbook), operational dashboard extensions, alert routing by severity, three-incident drill | Run-log locations and formats, how to surface failures for monitoring, sensor evidence for SLA measurement |
| 16 | Capstone | Brief, rubric, grader, reference solution | Everything above, rerun on the final pinned version |

---

## 5. Reusable Short Prompts

Use these between phases.

**Review a finished module with fresh eyes**

```text
Act as a learner who has never used Bruin. Follow modules/[NN-title]/ from the
starter tag using only what is written. Do not use knowledge from earlier sessions.
List every ambiguity, missing step, undefined term, and failing command. Then rate
the module for clarity on a 1-5 scale with specific justification, and fix every
issue rated medium or higher.
```

**Fact-check pass**

```text
Extract every statement in modules/[NN-title]/ that describes Bruin or Snowflake
behavior. For each, give the matching entry in docs/VERIFIED_FACTS.md or the docs URL
you checked just now. List statements with no support. Fix or delete them.
```

**Simplify pass**

```text
Reduce reading level and length of modules/[NN-title]/lesson.md without removing
a learning objective. Replace jargon with a defined term or plain wording. Keep
every command and expected output. Report the before and after word counts.
```

**Custom Python sensor design review**

```text
Review lib/sensors.py and every sensor asset against the Module 11 design rules.
For each sensor, check: bounded timeout; run-date awareness; idempotent and
side-effect free except the evidence write; distinct "not ready" and "broken"
messages; never treats existence as completeness; evidence recorded; unit tests
exist and run without Bruin. Then run each Vendor Feed fault switch and show the
sensor's behavior. List defects and fix them.
```

**Bruin version upgrade**

```text
A new Bruin version [X] is out. Update BRUIN_VERSION on a branch, rerun every
module self-check from its solution tag, and report which fail. For each failure,
find the changelog or docs change responsible, update VERIFIED_FACTS.md, and fix
the material. Do not merge until all self-checks pass.
```

**Reset reliability test**

```text
For every step of module [NN]: create a fresh workspace, jump to the step with a
reset, run its check (expect fail), apply the solution tag, run the check (expect
pass), then reset again and confirm the state matches the starter exactly, including
database contents and simulator clock. Report any step where state differs and
fix the template builder.
```

---

## 6. Definition of Done and Accessibility Checklist

A module is done when all items hold:

- [ ] Every step: starter tag fails its check, solution tag passes it, in a fresh workspace, and a reset restores the exact starter state.
- [ ] No step requires the learner to install software, use Docker, use an outside account, or reach an outside network (labeled optional labs excepted).
- [ ] Every Bruin claim maps to `docs/VERIFIED_FACTS.md`.
- [ ] Every command has expected output.
- [ ] Break/fix scenario reproduces the described symptoms.
- [ ] Commands run in the workspace shell exactly as written, and the accessible alternative for each terminal action exists.
- [ ] Terms defined on first use and listed in the glossary.
- [ ] No meaning carried by color alone; diagrams have text equivalents.
- [ ] No emojis or em dashes.
- [ ] Time estimates measured by an actual run-through, not guessed.
- [ ] Lab runs on the engine the outline names for the module, and engine-specific behavior is stated.

---

## 7. Decisions

**Settled by the course author (2026-10-05)**

- Hosted only, paid, inexpensive. No local path.
- Postgres is the platform warehouse. Snowflake is not required. Module 13 is an optional cloud-warehouse module.
- Platform delivery details are in `Hosted_Platform_Build_Spec.md`.

**Still open**

1. **Source simulation mechanism.** Phase A decides between pre-generated daily files and a Bruin-managed generator for file sources. The Postgres sources are written directly by the simulator.
2. **Distribution of content.** The course repository is private and consumed by the platform. Confirm whether any part (for example the Module 0 and 1 preview and a syllabus) is public marketing.
3. **CI platform for the optional lab.** GitHub Actions is the reference because Bruin documents it. Gitea and GitLab remain appendices.
4. **Fictional institution.** The outline uses "Lakota Bank." Confirm no real institution's table names, source system names, or process details appear in the course. The planning prompt's dependency chain used `signature-daily`, which the outline replaces with the generic `core-banking-daily`. Keep the generic name for a paid public course.
5. **Skip versus fail for conditional runs.** When a data condition is not met, should the run fail (alerting, simple) or end cleanly with NOT_READY (quiet, needs a control-table check or a native skip)? Phase A reports what Bruin supports. The course will teach both, and you choose the recommended default.
6. **Scope trims.** Campaigns and Economic Indicators were listed as source entities but never used in labs. They are now stretch items. Confirm.
