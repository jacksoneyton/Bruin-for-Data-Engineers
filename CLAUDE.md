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
- Labs run only in the databases `bruin_course` and `bruin_course_src`. Never add steps that touch other databases.
- No DuckDB as a target. No Docker as a requirement.

Style: no emojis, no em dashes, no filler openers, plain and direct. Markdown for documents. Commands for bash (Git Bash on Windows).
Never read or write secrets. Never push without being asked.
