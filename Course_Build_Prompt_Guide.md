# Course Build Prompt Guide

Purpose: a set of prompts for Claude (best run in Claude Code inside the course repository) to build the actual "Bruin for Data Engineers" course from `Course_Curriculum_Outline.md` (v2).

How to use: run the phases in order. Paste the Master Context Prompt at the start of every new session. Build one module per session, commit after each, and do not start a module until the previous module's self-check passes on a clean checkout.

---

## 1. Master Context Prompt (paste at the start of every session)

```text
You are helping build "Bruin for Data Engineers", a project-based course. The
authoritative plan is Course_Curriculum_Outline.md in this repository. Read it
fully before doing anything. Also read docs/BUILD_LOG.md and docs/VERIFIED_FACTS.md
if they exist.

Hard constraints:
1. No Docker, containers, VMs, or locally hosted services anywhere in the
   course. If a step seems to need one, stop and propose an alternative.
2. Learners need no paid account for Modules 0-12, 14 (local portion), 15, 16.
   Snowflake is required only in Module 13 and the optional Snowflake path of
   the capstone.
3. Default local target is DuckDB through Bruin. Production target is Snowflake.
   Every lab must run on both targets by changing only the Bruin environment,
   unless a lesson explicitly teaches a dialect difference.
4. Python is not installed by the learner. Bruin manages Python through uv.
   Do not write instructions that assume a system Python.
5. Platform parity: every command must work in Git Bash, macOS, and Linux
   shells. Call out Windows differences inline.
6. All data is synthetic and deterministic. No real personal or financial data.
7. Never invent Bruin features, flags, YAML keys, or asset types. Every Bruin
   claim must be traceable to the official docs (https://bruin-data.github.io/bruin/)
   or to a command you actually ran. Record each in docs/VERIFIED_FACTS.md with
   the source URL or the command and its output, and the Bruin version.
8. Pin the Bruin version in the repository and CI. Record it in
   docs/VERIFIED_FACTS.md.
9. When the docs and the curriculum disagree, the docs win. Report the
   disagreement and propose a curriculum edit. Do not silently paper over it.

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
 ├── README.md                    (what the course is, three paths, start here)
 ├── .bruin.yml.example           (committed template; real .bruin.yml is git-ignored)
 ├── .gitignore
 ├── BRUIN_VERSION                (pinned version)
 ├── check                        (Git Bash script that runs the self-check for the current module)
 ├── docs/
 │    ├── VERIFIED_FACTS.md       (every Bruin claim with source)
 │    ├── BUILD_LOG.md            (what was built, open issues)
 │    ├── GLOSSARY.md
 │    └── appendices/             (python-primer, gitea, gitlab, branch-per-env)
 ├── simulator/                   (Source Simulator, offline, deterministic)
 ├── data/                        (generated SQLite files, CSV, JSON fixtures, manifests)
 ├── modules/
 │    └── NN-title/
 │         ├── lesson.md
 │         ├── lab.md
 │         ├── break-fix.md
 │         ├── knowledge-check.md   (questions and an answers section)
 │         ├── self-check           (script, pass/fail output)
 │         └── instructor-notes.md
 ├── platform/                    (the evolving Bruin project learners build in)
 │    ├── pipelines/
 │    └── lib/
 └── capstone/
      ├── brief.md
      ├── rubric.md
      └── capstone-check/
```

Git tags: `module-NN-starter` and `module-NN-solution` for every module. A learner can check out a starter tag to begin or recover.

---

## 3. Phase Prompts

### Phase A: Research and Verification Spike

```text
Phase A: verification spike. Do not write any course content yet.

On a clean machine or clean directory with no prior Bruin state, using only the
documented install command, verify each item below by running it and by reading
the official docs. Write results to docs/VERIFIED_FACTS.md with the Bruin version,
the exact commands, and the observed output.

1. Install Bruin. Record any prerequisite beyond Git. Confirm no Docker is needed.
2. bruin init with a template, then bruin validate and bruin run against DuckDB.
3. An ingestr asset with a SQLite source (sqlite:///...) into DuckDB. Confirm it
   works with no Docker. Then try csv:// as a source.
4. Can an ingestr or Python asset read a daily-partitioned extract, for example
   by using the run date (BRUIN_START_DATE or Jinja variables) in a path or
   query? Determine the cleanest way to simulate "advance one business day".
5. A Python asset that returns a DataFrame or list of dicts and is materialized
   by Bruin into DuckDB. Confirm no system Python is required.
6. All materialization strategies on DuckDB: create+replace, truncate+insert,
   append, delete+insert, merge, time_interval, ddl, scd2_by_column, scd2_by_time.
   Record required fields, surprises, and any strategy that fails.
7. Built-in column checks and custom_checks, including blocking true and false.
   Determine whether Python-based checks exist. Determine how row count,
   freshness, and schema checks are best expressed.
8. Sensors: duckdb.sensor.query behavior, poke_interval, timeout. Whether a
   sensor can gate a different pipeline. Whether custom Python sensors exist.
9. Cross-pipeline dependencies: the uri field and depends with uri. What works
   in the CLI versus only in Bruin Cloud. (The docs page for this could not be
   retrieved during the curriculum review, so use the docs index and test directly.)
10. bruin backfill and bruin run date flags against DuckDB. Idempotency of each
    materialization under re-run.
11. bruin unit-test: what it supports.
12. GitHub Actions with bruin-data/setup-bruin: a minimal workflow that
    validates and runs against DuckDB with no containers.
13. Windows: install and run the same steps in Git Bash. If a Windows machine is
    not available, mark Windows items as unverified and list them.
14. Snowflake (only if I provide trial credentials): connection, key-pair auth,
    sf.sql, sf.seed, sf.sensor.table, merge, scd2_by_column on a trial account.
    Record the current sign-in requirements for new trial accounts.
15. Free FX data source: identify one with a stable free tier and clear terms,
    plus the offline fixture fallback.

Deliverables: docs/VERIFIED_FACTS.md and a short list of curriculum edits needed
because reality differed from the outline. Do not edit the outline yourself;
propose the changes.
```

### Phase B: Scaffold and Source Simulator

```text
Phase B: scaffold the repository per the layout specification (section 2 of the
Prompt Guide) and build the Source Simulator.

Simulator requirements:
- Standard library only where possible so it runs with no installs, or run as a
  Bruin-managed Python asset if Phase A showed that is cleaner. State which and why.
- Deterministic from a seed. Same seed gives byte-identical output.
- Produces: Core Banking SQLite (customers, accounts, transactions), CRM SQLite
  (crm_customers, interactions), CSV (branches, products), JSON fixtures for FX
  rates, and Mortgage SQLite (loans, payments, borrowers) for the capstone.
- Command to advance one simulated business day, and to reset to day 0.
- A manifest file per day listing true row counts per table, used by self-checks.
- Fault injection switches: late-arriving rows, duplicates, corrupted day,
  partial load, schema drift, deleted source rows. Each is documented, reversible,
  and recorded in the manifest.
- A shared customer population across Core Banking and CRM with deliberate
  overlap and conflicts, so Module 8 survivorship rules have real work to do.
- Realistic but fake: names, emails, and addresses from clearly synthetic generators.

Also build: README.md, .gitignore (including .bruin.yml), .bruin.yml.example, the
BRUIN_VERSION file, the Module 0 self-check, and the platform/ skeleton.

Verify on a clean checkout: reset, advance 5 days, confirm manifests match actual
counts, confirm determinism by running twice and diffing.
```

### Phase C: Module Build (repeat per module)

Use this template once per module. Fill the bracketed fields from section 4.

```text
Phase C: build Module [N]: [TITLE].

Inputs: Course_Curriculum_Outline.md (the Module [N] section), docs/VERIFIED_FACTS.md,
and the repository state at tag module-[N-1]-solution.

Produce in modules/[NN-title]/:
1. lesson.md: concept explanation, short primer sections where the outline says so,
   all commands with expected output, and "Snowflake notes" callouts where target
   behavior differs. Target 20-30 minutes of reading for each hour of module time.
2. lab.md: numbered steps, each with a command, expected result, and what to do if
   the result differs. Include a "why this works" note per major step.
3. break-fix.md: the broken scenario, symptoms only (not the answer), hints in
   three tiers, and an answers section at the end.
4. knowledge-check.md: 5-8 questions with an answers section that explains each answer.
5. self-check: a script that prints PASS or FAIL per criterion using Bruin
   commands and validation queries against the manifest. It must give a specific
   message on failure.
6. instructor-notes.md: common mistakes, timing, extension ideas.
7. The platform/ changes for this module's starter and solution states, committed
   and tagged module-[N]-starter and module-[N]-solution.

Rules:
- Every Bruin feature you mention must exist in docs/VERIFIED_FACTS.md. If it does
  not, verify it now and add it, or remove it.
- Run the entire lab from the starter tag on a clean checkout, on DuckDB. If the
  module has Snowflake content, run it on Snowflake too if I provide credentials,
  otherwise mark it unverified in BUILD_LOG.md.
- Run the break/fix scenario and confirm the symptoms match what you wrote.
- Confirm the self-check fails on the starter and passes on the solution.
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
(late source, failing blocking check, bad deploy). Include a runbook template and a
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
warning checks both exist; cross-pipeline dependency is data-state based; a backfill
over a date range and a rebuild from history both reproduce identical results;
the CI workflow file exists and runs validate and tests.

Rubric items needing human judgment (architecture, documentation) get a checklist
with observable criteria, not adjectives.

Build a reference solution and prove capstone-check passes on it and fails on the
module-15 solution.
```

### Phase F: Clean-Machine QA

```text
Phase F: quality assurance. You are a new learner with no prior context.

1. On a clean environment, follow README.md and Modules 0-3 using only the
   written materials. Record every point of confusion, missing prerequisite,
   command that failed, and unexplained term.
2. Repeat Module 0 in Git Bash on Windows, in WSL if available, on macOS and
   Linux if available. List which were actually tested.
3. Confirm no step requires Docker, a system Python install, admin rights beyond
   the documented Bruin installer, or a paid account.
4. Run the accessibility checklist in section 6 of the Prompt Guide.
5. Run a link check on all URLs and a grep for em dashes, emojis, and the words
   "Docker" and "docker" (each remaining mention must be an explicit
   statement that it is not needed).

Output: a prioritized defect list with file and line references, then fix the
high-priority items and rerun.
```

### Phase G: Packaging

```text
Phase G: package the course. Produce the final README, a course landing page in
Markdown, a CHANGELOG, a CONTRIBUTING guide, and a LICENSE recommendation. Tag the
release. List the Bruin version it was built against and the process for upgrading
it (which docs and self-checks to rerun when Bruin releases a new version).
```

---

## 4. Per-Module Addenda (fill into the Phase C template)

| N | Module | Required deliverables beyond the template | Verify before writing |
|---|--------|-------------------------------------------|-----------------------|
| 0 | Environment Setup | `check` script, Git Bash and WSL notes, broken `.bruin.yml` fixture | Installer behavior on Windows, uv bootstrap, DuckDB path handling |
| 1 | Fundamentals | Kimball vocabulary primer (one page), seed plus SQL asset lab | `bruin init` templates, `bruin query`, `bruin lineage` output |
| 2 | Landing Ingestion | Seven landing assets, load metadata columns, manifest count check | ingestr from sqlite:// and csv:// into DuckDB, incremental key behavior, daily-extract mechanism |
| 3 | SQL and Materialization | Strategy lookup table exercise, three-strategy lab | Required fields and failure modes per strategy on DuckDB and Snowflake |
| 4 | Dependencies and Lineage | Circular and missing-upstream fixtures, parallelism prediction exercise | `--workers`, `--downstream`, how cycles are reported |
| 5 | Pipeline Design | Four ingest pipelines, shared `lib/`, schedule fixture | Valid schedule syntax, variables, default connections, environment flags |
| 6 | Python Assets | `fx_rates_fetch.py` with offline fallback, secrets injection lab | uv dependency files, DataFrame and list-of-dicts materialization, env vars |
| 7 | Historical Layer | Four `_hist` assets, reconciliation checks, three reprocessing scenarios | Append versus merge patterns for history, late-arriving fault behavior |
| 8 | Integration Layer | Golden record with documented survivorship matrix | Merge strategies and any Snowflake-specific behavior |
| 9 | SCD Type 2 | `dim_customer` and `dim_account` with both scd2 strategies, late correction advanced lab | scd2_by_column versus scd2_by_time semantics, behavior on rebuild and late data |
| 10 | Data Quality | Check template library, warning and blocking layering, `bruin unit-test` intro | Whether Python checks exist, how failures propagate downstream, row count and freshness patterns |
| 11 | Sensors | Processing-date sensor, generic dependency chain | Cross-pipeline syntax, sensor semantics on DuckDB and Snowflake, timeouts |
| 12 | Replay and Recovery | Five recovery scenarios with fault switches, idempotency proof | backfill flags, resume behavior, run-twice idempotency per strategy |
| 13 | Snowflake Target | Key-pair walkthrough, environments, role model, dialect diff table | Trial sign-in rules, region field, warehouse auto-suspend, sf.* assets |
| 14 | Git Deployment | Working GitHub Actions workflows, local-only `./promote`, secret handling | setup-bruin version pinning, generating `.bruin.yml` in CI, scheduled trigger |
| 15 | Operations | Runbook and post-incident templates, three-incident drill | Run-log locations and formats, how to surface failures for monitoring |
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

**Bruin version upgrade**

```text
A new Bruin version [X] is out. Update BRUIN_VERSION on a branch, rerun every
module self-check from its solution tag, and report which fail. For each failure,
find the changelog or docs change responsible, update VERIFIED_FACTS.md, and fix
the material. Do not merge until all self-checks pass.
```

**Cross-target parity test**

```text
Run module [NN] solution on DuckDB and on Snowflake. Diff row counts and key
aggregates per table. List every dialect or behavior difference and decide whether
it needs a Snowflake notes callout or a code change.
```

---

## 6. Definition of Done and Accessibility Checklist

A module is done when all items hold:

- [ ] Starter tag fails the self-check, solution tag passes it, on a clean checkout.
- [ ] No step requires Docker, a system Python, or a paid account (Module 13 excepted).
- [ ] Every Bruin claim maps to `docs/VERIFIED_FACTS.md`.
- [ ] Every command has expected output.
- [ ] Break/fix scenario reproduces the described symptoms.
- [ ] Commands work in Git Bash, macOS, and Linux shells; Windows differences are stated.
- [ ] Terms defined on first use and listed in the glossary.
- [ ] No meaning carried by color alone; diagrams have text equivalents.
- [ ] No emojis or em dashes.
- [ ] Time estimates measured by an actual run-through, not guessed.
- [ ] Lab runs on both DuckDB and Snowflake (or Snowflake marked unverified in `BUILD_LOG.md`).

---

## 7. Decisions to Make Before Phase B

1. **Snowflake timing.** The outline starts the Snowflake trial at Module 13 because a 30-day trial would expire during a 52-hour course. If Snowflake must be present from the first lab, accept either a shorter course calendar or paid-account instructions.
2. **Source simulation mechanism.** Phase A decides between pre-generated daily files and a Bruin-managed generator. Either meets the no-Docker requirement.
3. **CI platform.** The outline uses GitHub Actions because Bruin documents it and it needs no self-hosting. Gitea Actions is demoted to an appendix. Confirm that is acceptable for your audience.
4. **Distribution.** Public Git repository with Markdown lessons (recommended), or a platform with a login. Public Markdown is the most accessible and the cheapest to maintain.
5. **Fictional institution.** The outline uses "Lakota Bank." Confirm no real institution's table names, source system names, or process details appear in the course. The original dependency chain contained an internal-looking name (`signature-daily`) and has been replaced with a generic one.
6. **Scope trims.** Campaigns and Economic Indicators were listed as source entities but never used in labs. They are now stretch items. Confirm.
