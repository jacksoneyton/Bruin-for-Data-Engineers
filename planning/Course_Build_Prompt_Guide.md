# Course Build Prompt Guide

Purpose: a set of prompts for Claude (best run in Claude Code inside the course repository) to build the "Bruin for Data Engineers" course from `Course_Curriculum_Outline.md` (v4.0). This is Stage 1: a self-guided course that experienced engineers follow manually on their own machines, against a database they choose. The hosted platform (Stage 2) is shelved in `planning/Hosted_Platform_Build_Spec.md` and is not part of this build.

Sources of truth, in priority order: (1) `Curriculum_Planning_Prompt.md`, which holds the original requirements and intent; (2) `Course_Curriculum_Outline.md`, which holds how those requirements are met; (3) this guide. If the outline contradicts the planning prompt, follow the prompt and report the conflict.

Process documents: `Master_Execution_Guide.md` governs how every session runs (planning, research, knowledge files, decision tiers, handoffs). `Prerequisites_Checklist.md` lists what the author must provide. Where this guide and the master guide differ on process, the master guide wins. Where they differ on course content, this guide and the outline win.

Research is expected. This guide and the outline contain known gaps (outline Appendix A, items marked Verify) and will have unknown ones. Claude investigates them using the research protocol in the master guide section 4, records results in `docs/knowledge/`, and continues. Claude asks the author only for decisions in the master guide section 7 (Tier 3).

How to use: run the phases in order. Paste the Master Context Prompt at the start of every new session. Build one module per session, commit after each, and do not start a module until the previous module's self-check passes on a clean checkout. Start trials early: after Modules 0 to 3 pass Phase F, run Phase G with testers before building further (outline section 6).

---

## 1. Master Context Prompt (paste at the start of every session)

```text
You are helping build "Bruin for Data Engineers", a self-guided, project-based
course for experienced engineers who will follow it manually on their own
machines. The authoritative plan is Course_Curriculum_Outline.md in this
repository. Read Master_Execution_Guide.md in full first, and follow its
start-of-session routine (handoff, knowledge index, plan, wait for approval) and
end-of-session routine (knowledge files, build log, handoff, commit, no push).
Then read the outline sections relevant to the phase, and always read
Curriculum_Planning_Prompt.md (the original requirements). Knowledge files live in
docs/knowledge/ (VERIFIED_FACTS, ASSUMPTIONS, OPEN_QUESTIONS, DECISIONS, RISKS,
BUILD_LOG, SESSION_HANDOFF, research/).

You are expected to investigate. When a fact is unverified, a document disagrees
with reality, or you need a pattern for a requirement Bruin lacks a feature for,
research it using the source hierarchy in the master guide, record the result,
and continue. Create new files under docs/knowledge, docs/adr, docs/data,
docs/compat, docs/coverage and docs/spike as needed without asking. Ask me only
for Tier 3 decisions.

Hard constraints:
1. Stage 1 is a manual, self-guided course. Learners install tools themselves
   from setup/SETUP.md, in their own editor and terminal. There is no hosted
   environment, instructor, or required outside service. Lessons depend on the
   environment contract (outline section 1.3), never on how the environment was
   provisioned, so a hosted environment can supply the same contract later.
2. Bring your own database. Postgres is the reference target: every lab is
   written and verified on it. Learners may use any Bruin-supported platform
   except DuckDB (Snowflake, SQL Server, MySQL, others). Every module has a
   Target compatibility note built from the verified capability matrix, never
   from guesses. DuckDB is not supported as the learner's warehouse, because
   Bruin documents that DuckDB does not allow concurrency between processes,
   which breaks the sensor, parallel, and recovery labs. Never design a lab that
   needs a second process to connect to a DuckDB file.
3. Learners use a dedicated empty database. Labs create and drop objects. The
   course CLI must refuse destructive actions against a database holding
   non-course objects unless the learner confirms with an explicit flag. Never
   write a step that points at a shared or production database.
4. Docker is never required. The setup guide may link to the official Postgres
   container image as an optional convenience and say so plainly. No lab may
   need Docker, and any lab step that does not need it must work without it.
5. Cross-platform. Every command is shown for bash and PowerShell, with expected
   output. The course CLI runs through uv. Do not write steps that need make,
   WSL, or a specific shell unless labeled as an optional shortcut. Verify
   Linux by running it. Windows and macOS are verified by scripts the author or
   testers run, and results are recorded in docs/compat/ with their source.
6. After setup, labs run locally with no outside network. Anything that needs an
   outside service (the GitHub Actions lab, an optional real API) is labeled
   optional and has an offline alternative where one exists.
7. All data is synthetic and deterministic. No real personal, financial, or
   employer data and no employer table or system names appear anywhere. The
   institution is the fictional Lakota Bank.
8. Never invent Bruin features, flags, YAML keys, or asset types. Every Bruin
   claim must be traceable to the official docs (https://bruin-data.github.io/bruin/),
   to Bruin source, or to a command you ran. Record each in
   docs/knowledge/VERIFIED_FACTS.md with the source URL or command and output,
   the Bruin version, and the confidence level.
9. Pin the Bruin version in the repository. Record it in VERIFIED_FACTS.md.
10. When the docs and the curriculum disagree about what Bruin does, the docs
    win. Report the disagreement and propose a curriculum edit. Required course
    content never gets dropped because Bruin lacks a native feature. Build it as
    a pattern on documented features and label it clearly as a course pattern.
11. Custom Python sensors and custom Python quality checks are required content.
    Bruin documents native sensors per platform (for example pg.sensor.table,
    pg.sensor.query) and SQL custom checks, but no Python sensor or check type.
    Teach them as Python assets in the dependency graph: a sensor asset
    succeeds when a data condition is met and raises on timeout so downstream
    assets do not run; a quality gate records results and raises on blocking
    failures. Never present these as official Bruin asset types. Verify the real
    behavior in Phase A before writing about it.
12. The reason custom sensors exist is conditional execution: run only when
    conditions in the data are met, against generic sources (file drops, vendor
    feeds, status tables, web endpoints) with no Bruin connector. Every sensor
    lesson starts from such a scenario.
13. For every asset type, cover purpose, configuration, execution lifecycle,
    production examples, and troubleshooting.
14. The goal is expertise. Every module has an Expert track section (internals,
    failure modes, performance, edge cases). Every row of the in-scope Bruin
    feature inventory (docs/coverage/bruin-feature-inventory.md) maps to a lesson
    and a lab or exercise. A gap is a defect.
15. The audience is experienced engineers. Do not pad with beginner material.
    Short primers are allowed only where the outline asks for them.

Style rules for all course text:
- Plain language, short sentences, define each term on first use.
- Markdown only. No emojis. No em dashes. No contrast constructions of the form
  "this is not X, it is Y".
- Technical and direct. No marketing tone, no filler openers.
- Every code block has a language tag. Every command shows expected output.
- No information conveyed by color alone. Diagrams are text with a prose
  equivalent.

Working rules:
- Do the work for the phase I name and stop. Do not start the next phase.
- Run every command and lab you write on a clean checkout before declaring done.
- Report anything you could not verify instead of guessing.
- Commit with a message naming the module and phase. Do not push.

Confirm you have read the outline and list the three biggest risks you see for
the phase I am about to give you. Then wait for the phase prompt.
```

---

## 2. Repository Layout Specification

Give this to Claude in Phase B. It defines where everything lives. The repository is the existing `Bruin-for-Data-Engineers` repository.

```text
Bruin-for-Data-Engineers/
 ├── README.md                    (what the course is, who it is for, how to start)
 ├── CLAUDE.md                    (short operating instructions, under about 200 lines)
 ├── Curriculum_Planning_Prompt.md
 ├── Course_Curriculum_Outline.md
 ├── Course_Build_Prompt_Guide.md
 ├── Master_Execution_Guide.md
 ├── Prerequisites_Checklist.md
 ├── Curriculum_Review_Notes.md
 ├── planning/
 │    └── Hosted_Platform_Build_Spec.md   (shelved Stage 2 spec)
 ├── .gitignore                   (includes .bruin.yml, .env*, data/generated/)
 ├── .bruin.yml.example           (committed template; the real .bruin.yml is git-ignored)
 ├── BRUIN_VERSION                (pinned version)
 ├── setup/
 │    ├── SETUP.md                (install and verify, bash and PowerShell, per OS)
 │    ├── targets/                (one file per supported target: postgres.md, snowflake.md, sqlserver.md, mysql.md ...)
 │    ├── postgres-container.md   (optional: link to the official Postgres image and one-command start)
 │    └── TROUBLESHOOTING.md
 ├── course/                      (the course CLI, a Python package run through uv: doctor, up, down, check, hint, reset, advance, fault, clock, report, ci, scheduler)
 ├── simulator/                   (Source Simulator and mock API; portable DDL subset; adapters per target; CSV export fallback)
 ├── data/                        (generated SQLite mortgage file, CSV and JSON fixtures, manifests, immutable landing archive; generated parts git-ignored)
 ├── docs/
 │    ├── knowledge/              (INDEX, VERIFIED_FACTS, ASSUMPTIONS, OPEN_QUESTIONS, DECISIONS, RISKS, BUILD_LOG, SESSION_HANDOFF, research/)
 │    ├── adr/
 │    ├── data/                   (measurements, version regression results)
 │    ├── spike/
 │    ├── compat/                 (capability-matrix.md, one results file per OS and target)
 │    ├── coverage/               (bruin-feature-inventory.md)
 │    ├── GLOSSARY.md
 │    └── appendices/             (python-primer, gitea, gitlab, branch-per-env)
 ├── modules/
 │    └── NN-title/
 │         ├── lesson.md
 │         ├── lab.md
 │         ├── break-fix.md
 │         ├── knowledge-check.md   (questions and an answers section)
 │         ├── common-mistakes.md   (mistakes and troubleshooting guide)
 │         ├── compat.md            (Target compatibility note)
 │         ├── expert.md            (Expert track)
 │         ├── manifest.yaml        (steps, tags, simulator state, hints, check commands)
 │         ├── checks/              (one script per step, JSON-lines output, exit 0 or 1)
 │         └── facilitator-notes.md
 ├── platform/                    (the evolving Bruin project learners build in)
 │    ├── pipelines/
 │    └── lib/
 │         ├── sensors.py          (sensor contract and condition library, Module 11)
 │         ├── validation.py       (rules, severities, dq_results writer, Module 10)
 │         └── alerts.py           (webhook and table alert helper, Module 10)
 ├── assessment/
 │    ├── midcourse/               (broken platform and answer key)
 │    ├── ops-drill/
 │    └── expert/                  (Prairie Insurance fixture, Granite Utilities retake fixture, grader, rubric)
 ├── capstone/
 │    ├── brief.md
 │    ├── rubric.md
 │    └── capstone-check/
 └── trial/
      ├── tester-guide.md
      ├── feedback-form.md
      └── report-schema.md
```

Manifest and check contract (kept simple so any future environment can consume it):

```yaml
# modules/NN-title/manifest.yaml
module: 3
title: SQL Assets and Materialization
steps:
  - id: "3.1"
    title: Build the first draft of customers_hist
    est_minutes: 25
    starter_tag: module-03-s01-starter
    solution_tag: module-03-s01-solution
    sim_state: day-1
    requires: []                  # target features the step needs, for example [scd2_by_column]
    check: "uv run course check 3.1"
    hints: ["tier 1 text", "tier 2 text", "tier 3 text"]
```

Each check prints one JSON object per line, for example `{"criterion":"customers_hist row count matches manifest","status":"pass","message":""}`. Status is `pass`, `fail`, or `skip`. A skip means the learner's target does not support a required feature and carries the reason. The check exits 0 when no criterion fails and non-zero otherwise.

Git tags: `module-NN-sMM-starter` and `module-NN-sMM-solution` for every step, and `module-NN-starter` and `module-NN-solution` for every module. `course reset <step>` saves the learner's work to a branch, checks out the step's starter files, drops and recreates the course schemas, reloads sources, and sets the simulator seed and clock. Solutions are available on request through `course hint --solution`, which records that it was used in `course report`.

---

## 3. Phase Prompts

### Phase A: Research and Verification Spike

```text
Phase A: verification spike. Do not write any course content yet.

Work on the Linux development machine, with a clean state for each experiment
(use a fresh Postgres database, and a fresh working directory). Pin the Bruin
version first. Verify each item by running it and by reading the official docs
(raw page or source, not only a summarizing tool). Record results in
docs/knowledge/VERIFIED_FACTS.md with the Bruin version, the exact commands, and
the observed output. Items that need Windows or macOS cannot be run here: write a
verification script for each (bash and PowerShell), put it in docs/spike/, and
list it in OPEN_QUESTIONS.md for the author or testers to run and report back.

1. Install state: install Bruin and uv with the documented methods. Confirm
   Bruin runs with no Docker. Confirm uv-managed Python assets run with no system
   Python. Record whether Bruin installs uv itself, whether administrator rights are
   needed, and what the install touches on disk.
2. bruin init with a template, then bruin validate and bruin run against
   Postgres (pg.sql, pg.seed). Record the .bruin.yml connection shape.
3. ingestr asset with a Postgres source (incremental on updated_at) into a Postgres
   destination where source and destination are the same server and database.
   Then a SQLite source (sqlite:///...), then csv://. Record incremental behavior,
   deletes, and late-arriving rows. Determine whether Postgres CDC (wal_level
   logical, publication, slot) is practical as an Advanced topic for a learner's
   own Postgres.
4. Can an ingestr or Python asset read a daily-partitioned extract, for example by
   using the run date (BRUIN_START_DATE or Jinja variables) in a path or query?
   Determine the cleanest way to simulate "advance one business day".
5. A Python asset that returns a DataFrame or list of dicts and is materialized
   by Bruin into Postgres.
6. All materialization strategies on Postgres: create+replace, truncate+insert,
   append, delete+insert, merge, time_interval, ddl, scd2_by_column, scd2_by_time,
   and datavault_hub, datavault_link, datavault_satellite. Record required fields,
   surprises, failure modes, and the SQL each generates (find the render or debug
   option).
7. Built-in column checks and custom_checks, including blocking true and false.
   Look for any native Python check support. Determine how row count, freshness,
   and schema checks are best expressed in SQL. Then build a prototype Python
   quality-gate asset that writes to dq.dq_results and raises on a blocking failure.
   Confirm that downstream assets do not run when it raises, and what the run
   output and exit code look like.
8. Sensors: pg.sensor.table and pg.sensor.query behavior (documented default poll of
   30 seconds), poke_interval, timeout, and whether a sensor can poll Postgres while
   an upstream pipeline is still writing. Look for any native Python or generic
   (file, HTTP) sensor. Then prototype the three custom Python sensor patterns
   from Module 11 against a simulated drop-folder file:
   (a) an in-process polling gate with poke_interval and timeout;
   (b) a retry-based gate using the documented retries, rerun_cooldown, and
       timeout asset settings (determine the real semantics for Python assets,
       including attempts, cooldown, and logging);
   (c) a pre-flight gate run before bruin run, using the exit code.
   Determine whether a gate can end a run cleanly without failing it. If not,
   verify the control-table fallback: the gate records NOT_READY and a blocking
   custom check stops downstream assets. Record how each pattern appears in logs
   and exit codes.
9. Cross-pipeline dependencies: the uri field and depends with uri. What works in
   the CLI versus only in Bruin Cloud. (The docs page could not be retrieved during
   the curriculum review, so use the docs index, the Bruin repository docs folder,
   and test directly.)
10. bruin backfill and bruin run date flags against Postgres. Idempotency of each
    materialization under re-run.
11. bruin unit-test: what it supports.
12. Environments: dev, staging, and production as three Postgres databases (and as
    three schema sets) selected through Bruin environments. Confirm a local CI
    sequence (validate, unit-test, run in staging, checks, promote) works end to end.
13. Step resets: measure resetting a course database by dropping and recreating
    schemas and reloading sources. On Postgres also measure CREATE DATABASE ...
    TEMPLATE (documented to fail if any other session is connected to the
    template). Decide the default reset method and record timings.
14. Scheduler harness: build a minimal harness that triggers pipelines on their
    pipeline.yml cron schedule against the simulated clock, since the Bruin CLI has
    no scheduler. Record its limits.
15. Alerting: determine what notification support the CLI has (the docs appear to
    tie notifications to Bruin Cloud). If none, confirm the webhook and table-based
    alert helper approach works from a Python asset.
16. Raw file archive: confirm the cleanest way to write each simulated day's extract
    once to an immutable archive and load from it, so any day can be replayed.
17. Editor: confirm the Bruin VS Code extension installs in a local VS Code and what
    it adds (lineage view, rendering). Record anything that helps or hurts the labs.
18. Course CLI feasibility: confirm a Python package run through uv (uv run course
    ...) works on Linux, and write the Windows and macOS verification scripts.
19. Capability matrix: from the docs and by running what you can, build
    docs/compat/capability-matrix.md for Postgres (verified), Snowflake, SQL
    Server, MySQL, and every other platform Bruin documents (except DuckDB):
    asset types, materialization strategies, sensors, check support, ingestr
    destination and source support, schema versus database mapping, and known
    limits. Mark each cell Verified-run, Verified-source, Documented, or Unknown.
20. Simulator target adapters: confirm which portable DDL subset works on Postgres,
    and which SQLAlchemy dialects or drivers are needed for Snowflake, SQL Server,
    and MySQL. Do not build the adapters yet. Record the plan and risks.
21. Postgres container: find the official image page and the shortest correct
    one-command start for a learner (port, password, persistence). Do not
    require it anywhere.
22. Feature inventory: from the pinned version's CLI help (every command and flag),
    docs index, and asset schema, build docs/coverage/bruin-feature-inventory.md
    listing every command, flag, asset type, YAML key, materialization strategy,
    check, and integration, each with a status column (to teach, out of scope with
    reason) and a "taught in" column left blank.
23. Optional: GitHub Actions with bruin-data/setup-bruin and a Postgres service
    container, to support the Module 14 lab. Write the workflow; running it needs a
    push, which is a Tier 3 decision, so propose it and wait.
24. License facts: record the licenses of Bruin and ingestr and anything the course
    redistributes. Present the ingestr terms as a lead for the author.

Deliverables: VERIFIED_FACTS.md, the capability matrix, the feature inventory,
verification scripts for Windows and macOS, and a short list of curriculum edits
needed because reality differed from the outline. Do not edit the outline
yourself; propose the changes.
```

### Phase B: Scaffold, Setup Guide, Course CLI, and Source Simulator

```text
Phase B: scaffold the repository per the layout specification (section 2 of the
Prompt Guide), write the setup guide, build the course CLI, and build the Source
Simulator.

Setup guide (setup/SETUP.md and setup/targets/*.md):
- Per-OS installation of Git, uv, the Bruin CLI at the pinned version, and the
  course CLI, each with bash and PowerShell commands and expected output.
- Choosing a target: Postgres reference path (existing Postgres or the optional
  container from setup/postgres-container.md), and a section per other target with
  exact statements to create the dedicated database, role, and environment
  databases or schemas, plus the Bruin connection fields. Base target sections on
  the capability matrix, and mark unverified targets as best effort.
- DuckDB is explicitly listed as unsupported, with the reason.
- course doctor output reference, and a troubleshooting file built from every
  failure seen during Phase A and B.

Course CLI (course/): a Python package run through uv with these commands:
doctor, up, down, check, hint, reset, advance, fault, clock, report, ci,
scheduler. Requirements:
- Reads the Bruin connection from the learner's .bruin.yml, never stores secrets.
- Refuses destructive actions (reset, down) against a database holding non-course
  objects unless the learner passes an explicit confirmation flag.
- check prints JSON lines and exits per the contract in section 2.
- report writes a local bundle (step timings, check results, versions, hint and
  solution usage, no data contents and no credentials) for trial feedback.
- Behaves the same on Windows, macOS, and Linux.

Simulator requirements:
- Runs locally. State which runtime it uses and why.
- Deterministic from a seed. Same seed gives identical output.
- Writes to the schemas src_core_banking (customers, accounts, transactions) and
  src_crm (crm_customers, interactions) in the learner's target, with updated_at
  columns that support incremental loads. Uses a portable DDL subset and an
  adapter per target. The Postgres adapter is complete and verified. Other
  adapters are stubbed with clear errors until Phase H, and a CSV export plus a
  plain loader script is the fallback.
- Produces CSV (branches, products), JSON fixtures and a mock API for FX rates, and
  a Mortgage SQLite database (loans, payments, borrowers) for the capstone.
- Mock API: REST with pagination and authentication, started by course up, plus
  fault switches (HTTP 500, HTTP 429, slow responses, expired credential, pagination
  change, schema drift).
- Commands to advance one simulated business day and to reset to day 0. Simulator
  state can be set to a named state for a step reset.
- A manifest per day listing true row counts and checksums per table, used by checks.
- Fault injection: late-arriving rows (backdated updated_at), duplicates, corrupted
  day, partial load, schema drift, deleted source rows. Each is documented,
  reversible, and recorded in the manifest.
- A shared customer population across Core Banking and CRM with deliberate overlap
  and conflicts, so Module 8 survivorship rules have real work to do.
- A Vendor Feed generic source: a drop folder of daily files with a manifest (row
  count, checksum, business date) and a status table with a completeness flag.
  Controls to delay arrival, deliver in growing chunks, deliver an empty or
  under-threshold file, flip the completeness flag late, deliver a checksum
  mismatch, and deliver a prior day's file by mistake. All deterministic and
  recorded in the manifest. A simulated clock that sensors can read so labs run in
  seconds.
- An immutable per-day raw file archive (data/landing/<source>/<date>/).
- Realistic but fake data from clearly synthetic generators.

Also build: README.md, .gitignore (including .bruin.yml), .bruin.yml.example, the
BRUIN_VERSION file, the Module 0 manifest and checks, the platform/ skeleton, and
trial/tester-guide.md, feedback-form.md, and report-schema.md.

Verify on a clean Linux state: install from the setup guide as written, reset,
advance 5 days, confirm manifests match actual counts, confirm determinism by
running twice and diffing, confirm the destructive-action guard blocks a database
with foreign objects, and confirm reset restores files, database, and simulator
clock. Produce the Windows and macOS verification scripts for the author to run.
```

### Phase C: Module Build (repeat per module)

Use this template once per module. Fill the bracketed fields from section 4.

```text
Phase C: build Module [N]: [TITLE].

Inputs: Course_Curriculum_Outline.md (the Module [N] section),
docs/knowledge/VERIFIED_FACTS.md, docs/compat/capability-matrix.md,
docs/coverage/bruin-feature-inventory.md, and the repository state at tag
module-[N-1]-solution.

Produce in modules/[NN-title]/:
1. lesson.md: concept explanation, short primer sections where the outline says so,
   all commands (bash and PowerShell) with expected output. Target 20-30 minutes of
   reading for each hour of module time.
2. lab.md: numbered steps, each with a command, expected result, and what to do if
   the result differs. Include a "why this works" note per major step.
3. break-fix.md: the broken scenario, symptoms only (not the answer), hints in
   three tiers, and an answers section at the end.
4. knowledge-check.md: 5-8 questions with an answers section that explains each
   answer. common-mistakes.md: the mistakes learners actually made or would likely
   make, with symptom, cause, and fix.
5. compat.md: the Target compatibility note, generated from the capability matrix
   and the module's own runs. For each supported target: what works unchanged,
   what needs a change (with the change), and what is unavailable. Steps that
   depend on an unavailable feature declare it in manifest.yaml under requires so
   that checks report skip with a reason.
6. expert.md: the Expert track, covering internals, failure modes, performance, and
   edge cases named in the outline. Every item is verified or labeled as inference.
7. manifest.yaml and checks/: one check script per step, following the contract in
   section 2. Each failure message must be specific. Include starter and solution
   tags per step, hints (three tiers), and the simulator state for each step.
8. facilitator-notes.md: timing, common mistakes, extension ideas, for anyone running
   the course with a group.
9. The platform/ changes for this module's starter and solution states, committed and
   tagged module-[N]-starter and module-[N]-solution.
10. Update docs/coverage/bruin-feature-inventory.md: fill the "taught in" column for
    every feature this module teaches.

Rules:
- Every Bruin feature you mention must exist in VERIFIED_FACTS.md. If it does not,
  verify it now and add it, or remove it. Course patterns (Python sensors, Python
  quality gates, control tables, severity levels) are labeled as course patterns,
  and the Bruin features they rely on are cited.
- For any asset type introduced in this module, cover purpose, configuration,
  execution lifecycle, a production-style example, and troubleshooting.
- Run the entire lab from the starter tag on a clean state against the reference
  target (Postgres). Commands are run as written.
- For any step that has a database state, test a reset to that step.
- Run the break/fix scenario and confirm the symptoms match what you wrote.
- Confirm each check fails on its starter tag and passes on its solution tag.
- Check reading level: short sentences, no undefined jargon.
- Measure time: record how long the lab actually takes on a clean run, and compare
  with the outline's estimate. Propose a revised estimate if they differ by more
  than 25 percent.

Finish with a short report: what you built, what you verified and how, what you
could not verify, and any curriculum changes you recommend. Do not begin the next
module.
```

### Phase D: Break/Fix Fixtures, Assessments, and Drills

```text
Phase D: build the mid-course practical (after Module 9), the operations drill
(Module 15), and the expert assessment (Module 17).

Mid-course practical: a copy of the platform containing at least eight distinct
faults spanning: a misspelled connection, a merge without primary_key, a circular
dependency, an invalid schedule, a wrong materialization strategy, a failing
blocking check, an SCD2 with the wrong key, and a layer that skips history. Each
fault must be discoverable from bruin validate, run logs, or checks. Provide a
facilitator answer key, a learner-facing scoring checklist, and a self-check that
reports how many faults remain.

Operations drill: three chained incidents driven by simulator fault switches (a late
Vendor Feed file that times out a custom Python sensor, a failing blocking check, a
bad deploy requiring rollback). Include a runbook template and a post-incident
report template.

Expert assessment (assessment/expert/): the Prairie Insurance fixture (claims,
policies, adjusters, a vendor feed for repair estimates) with a provided broken
platform of at least ten faults across validation, materialization, dependencies,
checks, sensors, and recovery; a written spec for a new pipeline that includes
conditional execution against a generic source, a quality gate, and an SCD2
dimension; a pull request with seeded defects to review; and an incident to recover
(a corrupted day plus a late vendor file). Build the automated grader for the
structural and outcome parts, a published rubric for the review and post-incident
report, a time limit with a published hint penalty, and the Granite Utilities retake
fixture. Fix the pass mark and the rubric before any learner attempts it. Prove the
grader passes on your reference solution and fails on the unrepaired fixture.

Verify that every fault is detectable, that the answer key's fixes make the
self-check pass, and that no fixture contains real employer or personal data.
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
warning checks both exist; cross-pipeline dependency is data-state based; at least
one custom Python sensor exists, has a bounded timeout, records evidence to the
control table, has plain Python unit tests, and the Vendor Feed run proceeds only
after the sensor passes; a Python quality-gate rule and a SQL check of each severity
exist; a backfill over a date range and a rebuild from history both reproduce
identical results; the CI definition exists and runs validate and tests. On targets
where a feature is unavailable, report skip with the reason and point to the
checklist alternative.

Rubric items needing human judgment (architecture, documentation) get a checklist
with observable criteria, not adjectives.

Build a reference solution and prove capstone-check passes on it and fails on the
module-15 solution.
```

### Phase F: Clean-Machine QA

```text
Phase F: quality assurance. You are a new learner with no prior context, using only
the written materials on a clean machine state.

1. On a freshly restored clean Linux state (a VM snapshot or a new user account with
   no tools installed), follow setup/SETUP.md and then the course from Module 0
   through the modules built so far using only the written materials. Record every
   point of confusion, missing prerequisite, command that failed, and unexplained
   term.
2. Confirm no step requires Docker, an outside account, or an outside network after
   setup (optional labs excepted and labeled).
3. Run every module check from the starter and solution tags and confirm the
   expected pass or fail results. Run the reset reliability test.
4. Produce the Windows and macOS verification scripts and the exact commands for the
   author to run them. Do not claim Windows or macOS support until results are
   recorded in docs/compat/.
5. Run the accessibility checklist in section 6, a link check on all URLs, and a grep
   for em dashes and emojis. Grep for "Docker" and "docker": each remaining mention
   must be the optional Postgres container link or an explicit statement that Docker
   is not needed.
6. Check coverage: every in-scope row of the feature inventory built so far has a
   lesson and a lab or exercise. List gaps.

Output: a prioritized defect list with file and line references, then fix the
high-priority items and rerun.
```

### Phase G: Tester Trial and Revision

```text
Phase G: prepare and analyze a trial. The author and a few trusted engineers will
work through the course manually. Run this phase first on Modules 0 to 3 (the thin
slice), then again for each later block.

Prepare (before testers start):
1. Confirm trial/tester-guide.md tells a tester exactly what to install, how to
   choose a target database, how to record time and problems, and how to send back
   a course report bundle and the feedback form. It must say that no real data,
   employer systems, or credentials should be used or shared.
2. Confirm course report excludes credentials and data contents, and that the
   report schema is documented.
3. Dry run the tester guide yourself on a clean state.

Analyze (after testers return reports):
4. For each step, compare actual time with the estimate, failed checks, hint and
   solution usage, and the free-text feedback. Rank the steps by pain.
5. Group problems: setup, instructions unclear, check wrong, lab too hard, lab too
   easy, content wrong, target-specific. Record each as a numbered issue with
   evidence.
6. Propose revisions in priority order. Apply the ones that are Tier 1 or Tier 2.
   Anything that changes a requirement, scope, or module order is Tier 3.
7. Update time estimates in the outline by proposal. Update facilitator notes with
   the questions testers actually asked.

Entry criteria for widening the audience: the thin slice passes a clean-machine run
on Linux, Windows, and macOS; at least three testers complete Modules 0 to 3 with no
unresolved setup failures; every check-wrong or content-wrong issue is fixed; the
median time per module is within 25 percent of the estimate.
```

### Phase H: Additional Target Verification

```text
Phase H: verify one additional target. Start with Snowflake. The author supplies a
dedicated sandbox database and a role (prerequisites checklist). Never use a
production account.

1. Implement and test the simulator adapter for the target using the portable DDL
   subset, or document why the CSV export fallback is required.
2. Create setup/targets/<target>.md from real runs.
3. Run every module's checks against the target. For each step record pass, fail, or
   skip with the reason. Update each module's compat.md and the capability matrix so
   that the cells move from Documented to Verified-run.
4. Fix lab text where the change needed on this target is small and general. Keep
   target-specific variants in compat.md.
5. Report the cost incurred, if any, and the cleanup performed.

Repeat for SQL Server and MySQL only when the author asks.
```

### Phase I: Packaging

```text
Phase I: package the course. Produce the final README, a course landing page in
Markdown, a CHANGELOG, a CONTRIBUTING guide (including how learners contribute
compatibility findings), and a LICENSE recommendation (presented as a Tier 3
decision with options and trade-offs). Tag the release. List the Bruin version it was
built against and the process for upgrading it (which docs and checks to rerun when
Bruin releases a new version, and the feature inventory diff).
```

---

## 4. Per-Module Addenda (fill into the Phase C template)

Every module also produces compat.md and expert.md (see the template). The table lists extra deliverables and what to verify first.

| N | Module | Required deliverables beyond the template | Verify before writing |
|---|--------|-------------------------------------------|-----------------------|
| 0 | Setup, Orientation, First Run | Fed from Phase B: SETUP.md walk-through, doctor expected output, broken `.bruin.yml` fixture, report and reset walkthrough, DuckDB-unsupported explanation | Install methods per OS, connection shapes per target, Bruin extension in local VS Code |
| 1 | Fundamentals | Kimball vocabulary primer (one page), seed plus SQL asset lab | `bruin init` templates, `bruin query`, `bruin lineage` output |
| 2 | Landing Ingestion | Seven landing assets, load metadata columns, manifest count check | ingestr from the source schemas, sqlite://, and csv://, incremental key behavior, deletes and late rows, daily-extract mechanism |
| 3 | SQL and Materialization | Strategy lookup table exercise, three-strategy lab, target comparison lab, optional Data Vault aside | Required fields and failure modes per strategy on Postgres, generated SQL, datavault behavior, support per other target |
| 4 | Dependencies and Lineage | Circular and missing-upstream fixtures, parallelism prediction exercise | `--workers`, `--downstream`, how cycles are reported, how the graph is built |
| 5 | Pipeline Design | Four ingest pipelines, shared `lib/`, schedule fixture, `--workers` tuning exercise, scheduler harness | Valid schedule syntax, variables, default connections, environment flags |
| 6 | Python Assets | `fx_rates_fetch.py` with offline fallback, secrets injection lab, `lib/` shared code, failure-semantics lesson (exception versus exit code versus downstream blocking) | uv dependency files, DataFrame and list-of-dicts materialization, env vars, what happens downstream when a Python asset raises |
| 7 | Historical Layer | Four `_hist` assets, reconciliation checks, three reprocessing scenarios | Append versus merge patterns for history, late-arriving fault behavior |
| 8 | Integration Layer | Golden record with documented survivorship matrix | Merge strategies on Postgres and survivorship patterns |
| 9 | SCD Type 2 | `dim_customer` and `dim_account` with both scd2 strategies, late correction advanced lab, mid-course practical hook | scd2_by_column versus scd2_by_time semantics, behavior on rebuild and late data |
| 10 | Data Quality | `lib/validation.py`, `lib/alerts.py`, SQL check templates, Python quality-gate asset, `dq.dq_results` and `dq.run_log` tables, dashboard views, severity demonstration with simulator faults, `bruin unit-test` intro | Native Python check support, failure propagation downstream, retries and cooldown on Python assets, alert options in the CLI |
| 11 | Sensors and Python Sensors | Part A: native SQL sensor and control tables (`ctl.processing_dates`, `ctl.publication_log`). Part B: `lib/sensors.py` with the sensor contract and condition library, Vendor Feed labs B1 to B6, the three implementation patterns, five break/fix scenarios, plain-Python tests | Cross-pipeline syntax, pg.sensor.* semantics, timeouts, the real behavior of all three Python gate patterns, any clean-skip mechanism |
| 12 | Replay and Recovery | Five recovery scenarios with fault switches, idempotency proof, decision tree | backfill flags, resume behavior, run-twice idempotency per strategy |
| 13 | Targets, Compatibility, Porting (optional) | Dialect worksheet with answer key and checker, port plan template, read-the-config exercise, optional second-target lab, role translation table | Bruin docs for each platform's connection fields, asset types, materialization support, whether bruin validate works on an unreachable platform config |
| 14 | Git Deployment | `course ci` pipeline with staging and production databases or schema sets, review exercise pack with automated review checks, PR review checklist, release notes template, rollback lab, GitHub Actions lab with a Postgres service container | Bruin environments for staging and production, setup-bruin version pinning, scheduled trigger, rollback timing |
| 15 | Operations | Runbook and post-incident templates (including late-vendor-feed runbook), operational dashboard extensions, alert routing by severity, three-incident drill | Run-log locations and formats, how to surface failures for monitoring, sensor evidence for SLA measurement |
| 16 | Capstone | Brief, rubric, grader, reference solution | Everything above, rerun on the final pinned version |
| 17 | Expert Practice and Assessment | Parts A to C lessons and labs, the 50-times scale lab, the assessment fixtures and grader from Phase D | Render and debug options, Bruin source reading notes, governance metadata fields in the feature inventory |

---

## 5. Reusable Short Prompts

Use these between phases.

**Review a finished module with fresh eyes**

```text
Act as an experienced engineer who has never used Bruin. Follow modules/[NN-title]/
from the starter tag using only what is written. Do not use knowledge from earlier
sessions. List every ambiguity, missing step, undefined term, and failing command.
Then rate the module for clarity on a 1-5 scale with specific justification, and fix
every issue rated medium or higher.
```

**Fact-check pass**

```text
Extract every statement in modules/[NN-title]/ that describes Bruin or target-platform
behavior. For each, give the matching entry in docs/knowledge/VERIFIED_FACTS.md or the
docs URL you checked just now. List statements with no support. Fix or delete them.
```

**Simplify pass**

```text
Reduce reading level and length of modules/[NN-title]/lesson.md without removing a
learning objective. Replace jargon with a defined term or plain wording. Keep every
command and expected output. Report the before and after word counts.
```

**Custom Python sensor design review**

```text
Review lib/sensors.py and every sensor asset against the Module 11 design rules. For
each sensor, check: bounded timeout; run-date awareness; idempotent and side-effect
free except the evidence write; distinct "not ready" and "broken" messages; never
treats existence as completeness; evidence recorded; unit tests exist and run without
Bruin. Then run each Vendor Feed fault switch and show the sensor's behavior. List
defects and fix them.
```

**Bruin version upgrade**

```text
A new Bruin version [X] is out. Update BRUIN_VERSION on a branch, rerun every module
self-check from its solution tag, and report which fail. Diff the new CLI help and
docs against docs/coverage/bruin-feature-inventory.md and list new, changed, and
removed features. For each failure or change, find the changelog or docs change
responsible, update VERIFIED_FACTS.md, and fix the material. Do not merge until all
self-checks pass.
```

**Reset reliability test**

```text
For every step of module [NN]: from a clean state, jump to the step with course
reset, run its check (expect fail), apply the solution tag, run the check (expect
pass), then reset again and confirm the state matches the starter exactly, including
database contents and simulator clock. Run it twice in a row to catch leftover state.
Report any step where state differs and fix the reset logic.
```

**Target compatibility review**

```text
For module [NN], compare compat.md with docs/compat/capability-matrix.md. List every
claim in compat.md that is not backed by a matrix cell at Verified-run, Verified-source,
or Documented level, and every feature the lab uses that the matrix marks Unknown for a
supported target. Fix compat.md, adjust manifest requires fields, and add open
questions for anything the author must test on a real target.
```

**Expert coverage check**

```text
Compare docs/coverage/bruin-feature-inventory.md with the modules built so far. List
every in-scope feature with an empty "taught in" cell, every row that points to a
lesson without a lab or exercise, and every lesson that teaches something missing
from the inventory. Propose where each gap is best taught. Do not edit the outline.
```

**Tester feedback triage**

```text
Read the course report bundles and feedback forms in trial/results/. Produce a
ranked issue list with evidence per issue (step id, time versus estimate, failed
checks, quotes), group by cause, and propose the smallest fix for each. Mark
anything that changes scope or requirements as a Tier 3 decision.
```

---

## 6. Definition of Done and Accessibility Checklist

A module is done when all items hold:

- [ ] Every step: starter tag fails its check, solution tag passes it, from a clean state against the reference target, and a reset restores the exact starter state.
- [ ] Commands are shown for bash and PowerShell, run as written on Linux, and verified on Windows and macOS by recorded results (or the module states the gap).
- [ ] No step requires Docker, an outside account, or an outside network after setup (labeled optional labs excepted).
- [ ] Every Bruin claim maps to `docs/knowledge/VERIFIED_FACTS.md`.
- [ ] Every command has expected output.
- [ ] Break/fix scenario reproduces the described symptoms.
- [ ] compat.md exists, is backed by the capability matrix, and checks report skip with a reason where a target lacks a feature.
- [ ] expert.md exists and every claim in it is verified or labeled inference.
- [ ] The feature inventory rows this module owns have a "taught in" entry, and each has a lab or exercise.
- [ ] Terms defined on first use and listed in the glossary.
- [ ] No meaning carried by color alone; diagrams have text equivalents.
- [ ] No emojis or em dashes.
- [ ] Time estimates measured by an actual run-through, and by trial data once available.
- [ ] Destructive actions are guarded and the module never touches a database with foreign objects.

The course is ready for wider release when every module passes the list above, the mid-course practical, operations drill, capstone, and expert assessment graders pass on their reference solutions and fail on their unrepaired fixtures, the trial entry criteria in Phase G are met, and the feature inventory has no uncovered in-scope row.

---

## 7. Decisions

**Settled by the course author**

- Stage 1 is a manual, self-guided course for experienced engineers. The hosted platform is deferred until the course has been trialed and revised (2026-10-06).
- Bring your own database. Postgres is the reference target, with a link to an easy Postgres container as an optional convenience. Any Bruin-supported target except DuckDB is allowed, best effort, with compatibility notes (2026-10-06).
- Snowflake is not required. It is the first additional target to verify (Phase H).
- The goal of the course is to make engineers Bruin experts (2026-10-06).
- Use the existing `Bruin-for-Data-Engineers` repository as the course repository.

**Still open**

1. **Source simulation mechanism.** Phase A decides between pre-generated daily files and a Bruin-managed generator for file sources. The database sources are written directly by the simulator.
2. **Course content license and distribution.** The repository is private during the trial. Decide the license and any public parts before wider release (Phase I).
3. **CI platform for the real lab.** GitHub Actions is the reference because Bruin documents it. Gitea and GitLab remain appendices.
4. **Fictional institution.** The outline uses "Lakota Bank." Confirm no real institution's table names, source system names, or process details appear in the course. The planning prompt's dependency chain used `signature-daily`, which the outline replaces with the generic `core-banking-daily`.
5. **Skip versus fail for conditional runs.** When a data condition is not met, should the run fail (alerting, simple) or end cleanly with NOT_READY (quiet, needs a control-table check or a native skip)? Phase A reports what Bruin supports. The course will teach both, and you choose the recommended default.
6. **Scope trims.** Campaigns and Economic Indicators are stretch items. Confirm.
7. **Trial group.** Who the testers are, which operating systems and targets they will use, and how feedback is returned.
8. **Expert designation wording and pass mark.** Fix before any learner attempts the assessment.
9. **Employer and IP clearance.** Confirm before the trial starts (Prerequisites section 10).
