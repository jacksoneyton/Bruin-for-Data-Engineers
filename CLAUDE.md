# Bruin for Data Engineers

A self-guided course that experienced engineers follow manually against a database they choose. Goal: make them Bruin experts. Stage 1 only. The hosted platform is shelved in `planning/`.

Start here: `Master_Execution_Guide.md`. It defines how every session runs: plan first and wait for approval, research gaps and record findings in `docs/knowledge/`, decision tiers (stop and ask for money, legal, real databases, sharing, third-party contact, destructive actions, requirement changes), end-of-session handoff, and commit without pushing.

Read order:
1. `Curriculum_Planning_Prompt.md` (original requirements, highest authority)
2. `Master_Execution_Guide.md`
3. `Prerequisites_Checklist.md` (run its preflight, report missing items)
4. `Course_Curriculum_Outline.md` (v4.0), only the sections the phase needs
5. `Course_Build_Prompt_Guide.md` for phases A to I
6. `Curriculum_Review_Notes.md` for revision history
7. `planning/Hosted_Platform_Build_Spec.md` only if Stage 2 is reopened

Hard constraints: manual self-guided course; bring your own database with Postgres as the reference; DuckDB is not a supported target; Docker is never required; labs run only against the dedicated test database named below; every Bruin claim is verified and recorded; custom Python sensors and checks are labeled course patterns; synthetic data and the fictional Lakota Bank only.

Dedicated test database: [name only, no credentials; fill in during setup]
Bruin version: [pin in BRUIN_VERSION]

Style: no emojis, no em dashes, no filler openers, plain and direct. Markdown for documents. Commands in bash and PowerShell.
Never read or write secrets. Never push without explicit instruction. Keep this file under about 200 lines.
