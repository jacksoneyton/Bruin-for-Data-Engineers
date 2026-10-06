# Module 0: Setup and first run

Estimated time: 1.5 to 2 hours (measure yours and record it in the validation log at the bottom).
Written against Bruin v0.11.773. Record the version you actually run.

## Outcome

You have Bruin, uv and Postgres working on your machine, a dedicated empty database, a Bruin project with one working connection, and one successful `bruin run`.

## Ground rules for the whole course

- **Terminal:** use Git Bash on Windows. The documented Bruin installer is a `sh` script and the docs say Windows users must run it in Git Bash or WSL. Every command in this course is written for Git Bash, macOS or Linux shells. If you prefer WSL, treat it as Linux.
- **Database:** Postgres is the reference target. Use a dedicated, empty database that you can wipe. Do not point the course at a database that holds real data, and never at an employer system.
- **Data:** all data is synthetic and belongs to the fictional Lakota Bank.
- **Sources:** each lesson cites the page in the official Bruin docs (`docs/` folder of `github.com/bruin-data/bruin`, also published on getbruin.com). Where the docs do not settle a question, the lesson says UNVERIFIED. Your run settles it. Write the result in the validation log.
- **DuckDB** is not used. Other databases are possible later (Module 11 lists what changes), but all labs are written and checked for Postgres.

## 0.1 Prerequisites

| Tool | Why | Check |
|---|---|---|
| Git for Windows (includes Git Bash) | Bruin projects are Git repositories, and the installer runs in Git Bash | `git --version` |
| Bruin CLI | the subject of the course | `bruin version` |
| uv | Bruin runs Python assets through uv | `uv --version` |
| Postgres 17 or newer, with `psql` | the target database. The SCD2 strategies (Module 8) need Postgres 17 or later according to the materialization docs | `psql --version` |
| VS Code (optional) | Bruin has an extension for editing and lineage | none |

## 0.2 Install Bruin

In Git Bash:

```bash
curl -LsSf https://getbruin.com/install/cli | sh
```

Source: `getting-started/introduction/installation.md`. The install script puts the binary in `~/.local/bin` by default. If you get `Permission denied`, make sure your user can write to that folder and run the installer again without `sudo` (the docs warn that `sudo` installs into root's home).

Open a new Git Bash window so your `PATH` refreshes, then:

```bash
bruin version
```

If `bruin` is not found, add `~/.local/bin` to your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

UNVERIFIED: whether the installer needs administrator rights on a locked-down Windows machine. The docs describe a per-user install. Record what happened.

## 0.3 Install uv

Bruin runs Python assets with uv and manages Python versions itself, so you do not need a system Python for the course (`assets/python.md`). Install uv with its own installer. From uv's documentation, in Git Bash on Windows you can call PowerShell:

```bash
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

On macOS or Linux:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Open a new terminal and check:

```bash
uv --version
```

`bruin run` has an experimental flag, `--exp-use-winget-for-uv`, described as "use PowerShell to manage and install uv on Windows" (`commands/run.md`). UNVERIFIED: whether Bruin installs uv for you on Windows without that flag. You do not need to find out now. You will see the behavior in Module 6.

## 0.4 Postgres

Use one of these.

1. An existing Postgres server you control. Ask for a new empty database and role.
2. A native install on your machine. The EDB installer for Windows is the common route and includes `psql`.
3. Optional: the official Postgres container image (`https://hub.docker.com/_/postgres`) if you already run containers. The course does not require containers.

Use version 17 or newer. The materialization docs list PostgreSQL 17 or later as the requirement for `scd2_by_column` and `scd2_by_time`. Everything before Module 8 works on older versions, but you will hit a wall there. After setup, check the server version with `psql "$PGURL" -Atc "show server_version"` (see 0.5).

Make sure `psql` runs in Git Bash. If `psql --version` fails after a native Windows install, add the Postgres `bin` folder to your `PATH`, for example:

```bash
echo 'export PATH="/c/Program Files/PostgreSQL/16/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Adjust the version number to match your install.

## 0.5 Create the course databases

You need two empty databases. `bruin_course` is where Bruin builds everything. `bruin_course_src` plays the role of an operational source system that Bruin reads from (Module 2). Keeping them separate means Module 2 behaves like a real extract from another system.

Connect as an administrator (adjust host and user to your server):

```bash
psql -h localhost -U postgres
```

Then run:

```sql
CREATE ROLE bruin_course LOGIN PASSWORD 'choose-a-simple-password';
CREATE DATABASE bruin_course OWNER bruin_course;
CREATE DATABASE bruin_course_src OWNER bruin_course;
\q
```

Use a simple password without `@`, `:`, `/` or `#` characters. It keeps connection strings simple.

Set connection strings for `psql` in your shell. Add them to `~/.bashrc` so they persist:

```bash
export PGURL="postgresql://bruin_course:choose-a-simple-password@localhost:5432/bruin_course"
export PGURL_SRC="postgresql://bruin_course:choose-a-simple-password@localhost:5432/bruin_course_src"
psql "$PGURL" -c "select current_database(), current_user;"
psql "$PGURL_SRC" -c "select current_database(), current_user;"
```

Expected: one row per command, showing `bruin_course` or `bruin_course_src` and the user `bruin_course`.

## 0.6 Get the course repository and make your work repository

You need two folders: the course repository (read-only reference, holds the data) and your own Bruin project (where you build).

```bash
cd ~
git clone https://github.com/jacksoneyton/Bruin-for-Data-Engineers.git
export COURSE="$HOME/Bruin-for-Data-Engineers/course"

mkdir lakota-bruin
cd lakota-bruin
git init
```

Add `export COURSE=...` to `~/.bashrc` as well.

A Bruin project is a Git repository, and `.bruin.yml` must live at its root (`core-concepts/project.md`). That is why your work lives in its own repository.

## 0.7 Create `.bruin.yml`

Inside `lakota-bruin`, create `.bruin.yml`:

```yaml
default_environment: default
environments:
  default:
    connections:
      postgres:
        - name: "lakota-pg"
          username: "bruin_course"
          password: "choose-a-simple-password"
          host: "localhost"
          port: 5432
          database: "bruin_course"
        - name: "lakota-src"
          username: "bruin_course"
          password: "choose-a-simple-password"
          host: "localhost"
          port: 5432
          database: "bruin_course_src"
```

`lakota-pg` is the warehouse Bruin builds in. `lakota-src` is the source system. Both are the same connection type (`postgres`). The field names come from `platforms/postgres.md`. Two optional fields from the same page matter later: `ssl_mode` and `schema`.

If a later step fails with a message about SSL not being supported by the server, add this line under the connection and retry:

```yaml
          ssl_mode: "disable"
```

`ssl_mode` accepts the libpq modes listed in the Postgres docs. UNVERIFIED: whether your local server needs it.

Bruin creates `.bruin.yml` automatically if it is missing and adds it to `.gitignore` (`core-concepts/project.md`). Confirm it is ignored:

```bash
git check-ignore -v .bruin.yml
```

If nothing prints, add `.bruin.yml` to `.gitignore` yourself. The file holds credentials and must never be committed.

## 0.8 List and test the connection

```bash
bruin connections list
bruin connections test --name lakota-pg
bruin connections test --name lakota-src
```

Source: `commands/connections.md`. `list` prints connection type, name and the names of filled fields, never the values. `test` runs a simple validation check against the connection.

## 0.9 First pipeline and first run

Create this structure inside `lakota-bruin`:

```text
lakota-bruin/
  .bruin.yml            (git-ignored)
  .gitignore
  smoke/
    pipeline.yml
    assets/
      smoke/
        hello.sql
```

`smoke/pipeline.yml`:

```yaml
name: smoke
default_connections:
  postgres: "lakota-pg"
```

`smoke/assets/smoke/hello.sql`:

```sql
/* @bruin
name: smoke.hello
type: pg.sql
materialization:
  type: table
@bruin */

SELECT 1 AS one, now() AS built_at
```

Notes on what you just wrote, all from `assets/definition-schema.md`:

- A SQL asset keeps its definition and its query in one `.sql` file. The definition sits between `/* @bruin` and `@bruin */`.
- `name` follows `schema.table`. Postgres accepts two segments only.
- `type: pg.sql` selects the Postgres SQL runner. `materialization: type: table` makes Bruin create a table from the query result (default strategy is `create+replace`).
- Because `pipeline.yml` sets `default_connections`, the asset does not need its own `connection` field.

Validate, run, then query the result:

```bash
bruin validate smoke
bruin run smoke
bruin query --connection lakota-pg --query "select * from smoke.hello"
```

Sources: `commands/validate.md`, `commands/run.md`, `commands/query.md`.

You should see the validation pass, a run that executes one asset, and a one-row table. Bruin should also have created the `smoke` schema for you. The docs say the schema segment is auto-created where the platform supports it (`assets/definition-schema.md`). UNVERIFIED for Postgres specifically. If the run fails with "schema does not exist", create it with `psql "$PGURL" -c "create schema smoke"` and record that in the validation log.

Look at what Bruin wrote to disk:

```bash
ls logs/runs/smoke
```

Each run writes a JSON log at `logs/runs/<pipeline>/<run-id>.json` (`commands/run.md`). You will use these in Module 11. Add `logs/` to `.gitignore` for now.

## 0.10 Setup check script

Save this as `check_setup.sh` in `lakota-bruin` and run it with `bash check_setup.sh`. It prints PASS or FAIL per item.

```bash
#!/usr/bin/env bash
ok() { echo "PASS  $1"; }
no() { echo "FAIL  $1"; }
chk() { if command -v "$1" >/dev/null 2>&1; then ok "$1: $("$1" "${2:---version}" 2>&1 | head -1)"; else no "$1 not found on PATH"; fi; }

chk git
chk uv
chk bruin version
chk psql

if [ -n "$PGURL" ] && psql "$PGURL" -Atc "select 1" >/dev/null 2>&1; then ok "database reachable via PGURL"; else no "database not reachable via PGURL"; fi
if [ -f .bruin.yml ] && git check-ignore -q .bruin.yml; then ok ".bruin.yml exists and is git-ignored"; else no ".bruin.yml missing or not git-ignored"; fi
if [ -n "$PGURL_SRC" ] && psql "$PGURL_SRC" -Atc "select 1" >/dev/null 2>&1; then ok "source database reachable via PGURL_SRC"; else no "source database not reachable via PGURL_SRC"; fi
for c in lakota-pg lakota-src; do
  if bruin connections test --name "$c" >/dev/null 2>&1; then ok "bruin connection $c"; else no "bruin connection $c"; fi
done
if bruin validate smoke >/dev/null 2>&1; then ok "bruin validate smoke"; else no "bruin validate smoke"; fi
```

## Break/fix

Do these in order. Read the symptom, find the cause, then fix. The answers are at the end.

1. In `smoke/pipeline.yml`, change `lakota-pg` to `lakota_pg`. Run `bruin validate smoke` and `bruin run smoke`. What does each report? Which one catches it earlier?
2. In `smoke/assets/smoke/hello.sql`, change the asset name to `hello` (one segment). Validate. What does Bruin say, and what rule from `assets/definition-schema.md` explains it?
3. In `.bruin.yml`, change the port to `5439`. Run `bruin connections test --name lakota-pg`. Compare this failure with the one in step 1.

Restore all three after each step.

<details>
<summary>Answers</summary>

1. The default connection name no longer exists in `.bruin.yml`. Validation checks configuration without running anything, so it should catch it before the run does. UNVERIFIED: the exact wording. Record both messages.
2. Postgres needs `schema.table`. A single-segment name is rejected by validation, and the docs state names without a schema are rejected by most databases. Fix by using two segments, or put the file under a folder inside `assets/` and rely on name inference.
3. A wrong port is a runtime connectivity failure, not a configuration mismatch. `connections test` reports it, and `validate` alone would not necessarily catch it.
</details>

## Check questions

1. Where must `.bruin.yml` live, and why is it git-ignored?
2. What is the difference between `bruin validate` and `bruin run`?
3. A SQL asset file has its definition in `hello.asset.yml` and its query in `hello.sql`. Why does this fail?
4. What does `bruin connections list` show, and what does it deliberately not show?
5. A pipeline run without `--start-date` and `--end-date` uses which date window?

<details>
<summary>Answers</summary>

1. At the root of the Git repository (override with `--config-file` or `BRUIN_CONFIG_FILE`). It holds credentials.
2. `validate` checks configuration and structure (and for some platforms dry-runs queries) without executing assets. `run` executes them.
3. SQL assets keep definition and query in the same file. A `.asset.yml` file is treated as a separate standalone asset.
4. Type, name and the names of filled fields. It never shows values.
5. Yesterday (start of yesterday to end of yesterday) (`commands/run.md`).
</details>

## Validation log

Copy this table into your notes and fill it in. It is what tells the author what to fix.

| Step | Pass / fail | What actually happened (errors, differences from the lesson) |
|---|---|---|
| 0.2 Bruin install (admin needed?) | | |
| 0.3 uv install | | |
| 0.4 Postgres and psql on PATH | | |
| 0.5 role and both databases | | |
| 0.7 ssl_mode needed? | | |
| 0.8 connections test (both) | | |
| 0.9 schema auto-created? | | |
| 0.10 check script | | |
| Break/fix 1 messages | | |
| Time taken | | |
