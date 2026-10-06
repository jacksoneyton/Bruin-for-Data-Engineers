# Lean Build Prompt (fastest path to learning)

Use this to get Modules 0 to 3 written and runnable quickly, so the author can start following the course. It deliberately overrides the heavy process in `Master_Execution_Guide.md` (no approval gate, no knowledge-file set, no feature inventory, no compatibility notes). Accuracy rules stay. Run it in Claude Code on the Linux development machine that has Postgres and a dedicated empty test database, from the repository root.

How to run:

1. `cd` into the repository, start `claude`, and paste the prompt below.
2. Set the test database connection in environment variables before starting (never paste credentials into the chat). Name the variable `COURSE_TEST_DB_URL`.
3. Start learning from `setup/SETUP.md` as soon as Claude reports it is ready. Claude keeps building the next modules while you work.

```text
You are building a self-guided Bruin course for one experienced engineer who will
follow it manually TODAY, mostly on Windows with PowerShell, against Postgres. Speed
to a usable first module matters more than polish. Correctness still matters: a
lesson that does not run is worse than no lesson.

Read these first, quickly: Curriculum_Planning_Prompt.md (original requirements) and
Course_Curriculum_Outline.md sections 1 to 3 and Modules 0 to 3 only. Ignore the
other process documents. This prompt overrides Master_Execution_Guide.md and the
phase structure of Course_Build_Prompt_Guide.md. Do not ask me for approval of a
plan. State your plan in five lines and start.

Scope: setup guide, a minimal Source Simulator, and Modules 0, 1, 2, 3. Nothing else.
Skip: compatibility notes, expert tracks, manifests, facilitator notes, the full
course CLI, trial tooling, assessments. Do not build Module 4 or later.

Rules (these are not optional):
1. Every statement about Bruin must come from the raw official docs
   (https://bruin-data.github.io/bruin/ or the docs folder of the Bruin GitHub repo)
   or from a command you ran. Do not invent commands, flags, or YAML keys. If you
   cannot verify something, write "UNVERIFIED" next to it in the lesson and list it
   in NOTES.md. Pin the Bruin version you used in BRUIN_VERSION.
2. Run every lab end to end on this Linux machine against the test database named in
   COURSE_TEST_DB_URL before you call a module done. Paste real output as the
   expected output. Use only that database. Never touch any other database.
3. Show every command twice: bash and PowerShell. You cannot run PowerShell, so label
   the PowerShell versions "not run on Windows" until I confirm them. Prefer commands
   that are identical on both (uv run ..., bruin ..., git ..., psql ...).
4. No Docker anywhere. The setup guide may mention the official Postgres container
   image as an optional convenience in one sentence. DuckDB is not a target; do not
   use it. Postgres is the target. Labs run offline after setup.
5. All data is synthetic and deterministic (seeded). The institution is the fictional
   Lakota Bank. No real employer, vendor, or person names.
6. Style: plain, direct, short sentences, define terms on first use. No emojis. No
   em dashes. No filler openers. Every code block has a language tag.
7. Keep one notes file, NOTES.md, with three headings: Verified facts (fact, source
   or command, Bruin version), Unverified or surprising, Questions for me. Update it
   as you go. That replaces the knowledge-file set.
8. Do not push. Commit after each deliverable with a clear message. Do not read or
   write secrets.

Deliverables, in this order. After each one, commit and print one line saying the
path and "ready", then continue to the next without waiting.

1. setup/SETUP.md and modules/00-setup/: Windows-first install of Git, uv, the Bruin
   CLI (use the documented install method and check whether it needs administrator
   rights), and Postgres (an existing server, or a native install, with the optional
   container mentioned once). Create a dedicated empty database and role, the
   .bruin.yml connection, three environments (default, staging, production) as three
   databases or schema sets, and a verification step. Include .bruin.yml.example and
   .gitignore (ignore .bruin.yml and .env*). Module 0 lab: run the starter project
   (bruin validate, bruin run), one break/fix (a misspelled connection name),
   knowledge check with answers. Include a script `uv run python tools/doctor.py` that
   prints pass or fail for: git, uv, bruin version, database reachable, database
   contains only course objects.
2. simulator/: a small deterministic Python simulator, run through uv, that writes
   schemas src_core_banking (customers, accounts, transactions) and src_crm
   (crm_customers, interactions) into the test database with updated_at columns,
   plus CSV files for branches and products and a fixture for FX rates. Commands:
   init (day 0), advance (one business day of inserts, updates, deletes), reset, and
   a manifest of true row counts per day. Same seed gives identical data. Add a guard:
   refuse to drop or reset if the database contains objects the simulator did not
   create, unless --force is passed. Keep it simple. No mock API, no fault injection,
   no Vendor Feed yet.
3. modules/01-fundamentals/: Bruin project structure, bruin init or a hand-built
   project, a seed asset and a SQL asset, bruin validate, run, query, lineage.
   Lesson, lab with expected output, break/fix (wrong seed path), knowledge check
   with answers, and a check script that prints pass or fail per criterion.
4. modules/02-landing/: landing layer for every source using ingestr assets and seeds
   as the docs allow: landing.core_customers, core_accounts, core_transactions,
   crm_customers, crm_interactions, ref_products, ref_branches. Incremental load on
   updated_at. Day 1 row counts must match the simulator manifest. Break/fix
   (misspelled source connection). Verify how ingestr behaves when source and
   destination are the same Postgres server and record it in NOTES.md.
5. modules/03-sql-materialization/: the materialization strategies the docs list
   (create+replace, truncate+insert, append, delete+insert, merge, time_interval,
   ddl, scd2_by_column, scd2_by_time), the required fields for each (as a table the
   learner fills in), and a lab building hist.customers_hist and hist.accounts_hist
   with at least three strategies. Verify each strategy by running it. Break/fix
   (merge without primary_key). Skip the Data Vault strategies unless they run
   cleanly in under ten minutes of your effort.

Each module folder contains: lesson.md (concepts, then lab steps with commands and
real expected output), break-fix.md (symptoms first, answers at the end),
knowledge-check.md (questions, then answers), and a check script. Put everything the
learner needs in as few files as possible. Time each lab on a clean run and state the
measured minutes at the top of the lesson.

When all five deliverables are done, print a short report: what you built, what you
ran, what is UNVERIFIED, and anything you changed from the outline and why. Then
stop. Do not start Module 4.
```

Notes for the author:

- Windows is untested until you run it. Report any PowerShell command that fails and Claude fixes it. Windows install behavior of Bruin and ingestr is the biggest unknown, so expect some friction in Module 0 and Module 2.
- This lean prompt skips the safety net of the full process. The two protections kept are the rule to verify every Bruin claim and the guard against dropping a database that holds foreign objects.
- When the first four modules have survived your run-through, switch back to the full process in `Master_Execution_Guide.md` for the remaining modules and for compatibility and expert content.
