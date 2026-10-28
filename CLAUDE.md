# Bruin for Data Engineers

A self-guided course (13 modules) that makes experienced data engineers Bruin experts. Learners work manually against their own Postgres, using synthetic data from a fictional bank (Lakota Bank).

Read order:
1. `Curriculum_Planning_Prompt.md` (original requirements, highest authority)
2. `course/README.md` (the course index and conventions)
3. The module being changed in `course/modules/`
4. `planning/` only for history. Those documents are shelved and do not govern the course.

Rules for editing lessons:
- Every Bruin claim comes from the official docs for the pinned version (v0.11.773). Cite the docs page. If the docs do not settle something, mark it UNVERIFIED and add a row to the module's validation log.
- Course patterns that are not Bruin features (marker tables, polling wrapper, custom Python sensors, alert wrapper) are labeled as such.
- Keep expected numbers consistent with the data in `course/data`. If you change the generator in `course/tools/make_data.py`, recompute every number in the modules.
- Labs run only in the learner's own prefixed course databases: `<prefix>_bruin_course`, `<prefix>_bruin_course_src` and `<prefix>_bruin_course_dev` (variables `$COURSE_DB`, `$COURSE_SRC_DB`, `$COURSE_DEV_DB`, set in Module 0, 0.5, where the prefix comes from the OS username). Never hard-code a database name, user or password in a lesson, and never add steps that touch other databases.
- Read-only lab steps use `bruin query`. Writes and admin steps use `psql`, with a pgAdmin alternative noted. VS Code steps are labeled with the extension version they were observed on (0.84.8) and always sit next to the CLI command.
- No DuckDB as a target. No Docker as a requirement.

Style: no emojis, no em dashes, no filler openers, plain and direct. Markdown for documents. Commands for bash (Git Bash on Windows).
Never read or write secrets. Never push without being asked.
