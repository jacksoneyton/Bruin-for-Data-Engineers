# Module 0: Setup and first run

Estimated time: 1.5 to 2 hours (measure yours and record it in the validation log at the bottom).
Written against Bruin v0.11.773. Record the version you actually run.

## Outcome

You have Bruin, uv and Postgres working on your machine, two dedicated empty databases, a Bruin project scaffolded with `bruin init` and wired to them with `bruin connections add`, and one successful `bruin run`.

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

Source: `getting-started/introduction/installation.md`. The install script puts the binary in `~/.local/bin` by default.

This course is written against v0.11.773. The installer above installs the latest release, which may behave differently. To pin the version, pass it to the installer script (the docs show this form with a version in `cicd/azure-pipelines.md`):

```bash
curl -LsSf https://getbruin.com/install/cli | sh -s v0.11.773
```

If Bruin is already installed, `bruin upgrade v0.11.773` switches the installed binary to a specific release in place (`commands/upgrade.md`). It also moves you to a newer or older version later, and it does nothing if you already have the target. Do not run a bare `bruin upgrade` during the course: it installs the latest release. UNVERIFIED: whether `bruin upgrade` can downgrade. If it refuses, rerun the pinned installer. Record the output of `bruin version`. If you get `Permission denied`, make sure your user can write to that folder and run the installer again without `sudo` (the docs warn that `sudo` installs into root's home).

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

## 0.7 Scaffold the project with `bruin init`

You do not write `.bruin.yml` or a pipeline folder from scratch. `bruin init <template> <folder>` scaffolds them (`commands/init.md`, `getting-started/introduction/quickstart.md`). Run it from the work repository:

```bash
cd ~/lakota-bruin
bruin init empty smoke
```

What this does, from `commands/init.md` and, where marked, from reading the CLI source at the v0.11.773 tag (`cmd/init.go`):

- It creates the folder `smoke/` with `pipeline.yml` and `assets/placeholder`.
- It looks for a Git repository. You are inside one, so the pipeline folder is created in the current directory and `.bruin.yml` belongs at the Git root. Outside a repository, `init` creates a `bruin/` wrapper folder and runs `git init` there. `--in-place` skips the wrapper and initializes the current folder instead.
- If the template ships its own `.bruin.yml`, `init` merges its connections into the project `.bruin.yml` (creating the file when it is missing). The `empty` template ships none, so no file is created yet and `init` prints "Create a .bruin.yml with your connection credentials" as a next step (source).
- `bruin init` with no template name opens a template picker. `bruin init --merge <template> <existing pipeline folder>` copies a template's assets into a pipeline you already have, without overwriting anything.

Which template to use:

| Template | What you get | Use it here? |
|---|---|---|
| `default` | A pipeline built on DuckDB and a public chess API. It writes a DuckDB connection and a `chess` connection into `.bruin.yml`. | No. DuckDB is not a course target, and the extra connections would clutter your config. You look at it in a scratch folder in Module 1. |
| `empty` | `pipeline.yml` with a name and every other option commented out, plus a placeholder asset. | Yes. |
| `bronze-silver-postgres` | An ingestr asset that loads a public FX-rate API into Postgres, a SQL asset on top of it, and a `.bruin.yml` with a `postgres-default` connection and placeholder credentials. | Look at it in Module 1. It is the closest official starter to this course. |

Source: `getting-started/templates.md` lists the bundled templates.

Now make the scaffold yours. Delete the placeholder and replace `smoke/pipeline.yml` with:

```bash
rm smoke/assets/placeholder
```

```yaml
name: smoke
default_connections:
  postgres: "lakota-pg"
```

The template names the pipeline `my-pipeline`. Bruin uses the pipeline name for its run-state folder (`logs/runs/<name>`) and in lineage and Cloud, so give it a real one. `default_connections` tells assets in this pipeline which connection to use for each platform when they do not name one (`pipelines/definition.md`).

## 0.8 Add the connections with `bruin connections add`

Connections live in `.bruin.yml`. You add them with `bruin connections add` (`commands/connections.md`). If `.bruin.yml` does not exist, the command creates it with an environment called `default`, and it adds `.bruin.yml` to `.gitignore` (creating that file if needed). Both behaviors are described in `core-concepts/project.md` and match the CLI source.

Add the warehouse connection and the source connection. In flag mode, all four of `--env`, `--type`, `--name` and `--credentials` must be given together. The credentials are the JSON form of the connection, with the field names from `platforms/postgres.md`:

```bash
bruin connections add --env default --type postgres --name lakota-pg \
  --credentials '{"username": "bruin_course", "password": "choose-a-simple-password", "host": "localhost", "port": 5432, "database": "bruin_course"}'

bruin connections add --env default --type postgres --name lakota-src \
  --credentials '{"username": "bruin_course", "password": "choose-a-simple-password", "host": "localhost", "port": 5432, "database": "bruin_course_src"}'
```

`lakota-pg` is the warehouse Bruin builds in. `lakota-src` is the source system. Both use the connection type `postgres`. Optional Postgres fields from the same docs page that matter later are `ssl_mode` and `schema`.

Flag mode is the form you use in scripts and CI. Try the interactive form once on a throwaway connection so you know it exists:

```bash
bruin connections add
```

Run in a terminal without flags, it walks through four steps: pick the environment (skipped when there is only one), enter a name, pick the type (type to filter the list, choose `postgres`), then fill in the fields. Secret fields are masked as you type. Name it `scratch-pg`, fill in anything, then remove it again:

```bash
bruin connections delete --env default --name scratch-pg
```

UNVERIFIED: whether the interactive wizard starts in Git Bash on Windows. Some Windows terminals do not give Go programs a real console, and the command then prints "No flags provided and not running in a terminal". If you see that, try `winpty bruin connections add`, or skip the wizard. Record what happened.

There is no `bruin connections update`. To change a connection, edit `.bruin.yml` directly (small edits are normal) or delete and re-add it.

If a later step fails with a message about SSL not being supported by the server, delete and re-add the connection with `"ssl_mode": "disable"` added to the credentials JSON. The Postgres docs say `ssl_mode` accepts the libpq modes. UNVERIFIED: whether your local server needs it. The CLI source gives `ssl_mode` a default of `allow`, which usually works against a server without SSL.

Look at what Bruin wrote, and confirm the file is ignored by Git:

```bash
cat .gitignore
git check-ignore -v .bruin.yml
```

`.bruin.yml` holds credentials and must never be committed. If `check-ignore` prints nothing, add `.bruin.yml` to `.gitignore` yourself.

One detail that bites later: Bruin appends its `.gitignore` entries without a trailing newline in the file. When you append your own lines, start with a newline, for example `printf '\nlogs/\n' >> .gitignore`. A plain `echo "logs/" >> .gitignore` can glue the new line onto the last entry.

## 0.9 List and test the connections

```bash
bruin connections list
bruin connections test --name lakota-pg
bruin connections test --name lakota-src
```

Source: `commands/connections.md`. `list` prints connection type, name and the names of filled fields, never the values. `test` runs a simple validation check against the connection and, without `--env`, uses the default environment from `.bruin.yml`.

## 0.10 First pipeline and first run

You already have `smoke/pipeline.yml` from 0.7. Add one asset, `smoke/assets/smoke/hello.sql`:

```sql
/* @bruin
name: smoke.hello
type: pg.sql
materialization:
  type: table
@bruin */

SELECT 1 AS one, now() AS built_at
```

The project now looks like this:

```text
lakota-bruin/
  .bruin.yml            (git-ignored, written by bruin connections add)
  .gitignore
  smoke/
    pipeline.yml
    assets/
      smoke/
        hello.sql
```

Notes on what you wrote, all from `assets/definition-schema.md`:

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

You should see the validation pass, a run that executes one asset, and a one-row table. Bruin creates the `smoke` schema for you: for a SQL asset with a materialization, the Postgres runner issues `CREATE SCHEMA IF NOT EXISTS` before the query (read from the CLI source, `pkg/postgres/operator.go`; confirm in your run and record it in the validation log).

Look at what Bruin did on disk and in Git:

```bash
ls logs/runs/smoke
cat .gitignore
```

Each run writes a JSON state file at `logs/runs/<pipeline>/<run-id>.json` (`commands/run.md`). Module 4 explains what it is for. `bruin run` adds `logs/runs` and `logs/*.log` to `.gitignore` itself (CLI source, `cmd/run.go`), so you do not need to. Confirm both entries appear. `bruin query` adds `logs/queries` the same way.

## 0.11 Setup check script

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
4. Move `.bruin.yml` aside (`mv .bruin.yml .bruin.yml.bak`) and run `bruin validate smoke`. What does Bruin do about the missing file, and what does `bruin connections list` show afterwards? Then restore the file (`mv .bruin.yml.bak .bruin.yml`; if Bruin created a new one, delete that first).

Restore all four after each step.

<details>
<summary>Answers</summary>

1. The default connection name no longer exists in `.bruin.yml`. Without `--fast`, `validate` also runs a live query check for Postgres assets, which needs the connection (`cmd/lint.go`, read from the CLI source), so it should fail before the run does. UNVERIFIED: which command reports it first and the exact wording. Record both messages.
2. Postgres needs `schema.table`. A single-segment name is rejected by validation, and the docs state names without a schema are rejected by most databases. Fix by using two segments, or put the file under a folder inside `assets/` and rely on name inference.
3. A wrong port is a runtime connectivity failure. `connections test` reports it. `validate --fast` would not catch it, because `--fast` never opens a connection. A non-fast `validate` may, because it runs queries against the database.
4. `core-concepts/project.md` says Bruin creates `.bruin.yml` automatically the first time a command needs it and adds it to `.gitignore`. The new file has a `default` environment and no connections, so `validate` then fails on the unknown connection `lakota-pg`. This is why you should never delete `.bruin.yml` casually: Bruin does not rebuild your connections. Re-add them with 0.8. UNVERIFIED: the exact message.
</details>

## Check questions

1. Where must `.bruin.yml` live, and why is it git-ignored?
2. What is the difference between `bruin validate` and `bruin run`?
3. A SQL asset file has its definition in `hello.asset.yml` and its query in `hello.sql`. Why does this fail?
4. What does `bruin connections list` show, and what does it deliberately not show?
5. A pipeline run without `--start-date` and `--end-date` uses which date window?
6. Which commands create `.bruin.yml`, and what else do they change?

<details>
<summary>Answers</summary>

1. At the root of the Git repository (override with `--config-file` or `BRUIN_CONFIG_FILE`). It holds credentials.
2. `validate` checks configuration and structure without executing assets. Without `--fast` it also checks each query against the database for BigQuery, Snowflake and Postgres (`cmd/lint.go`); `--fast` runs only the offline rules. `run` executes the assets.
3. SQL assets keep definition and query in the same file. A `.asset.yml` file is treated as a separate standalone asset.
4. Type, name and the names of filled fields. It never shows values.
5. Yesterday (start of yesterday to end of yesterday) (`commands/run.md`). A date-only `--end-date` means midnight at the start of that day, so Module 1 teaches the end-of-day form you will use in every lab.
6. `bruin connections add` creates it (with a `default` environment) when it is missing. `bruin init <template>` creates or merges it when the template ships a `.bruin.yml`. Both add `.bruin.yml` to `.gitignore`. Most other commands also create an empty one on first use.
</details>

## Validation log

Copy this table into your notes and fill it in. It is what tells the author what to fix.

| Step | Pass / fail | What actually happened (errors, differences from the lesson) |
|---|---|---|
| 0.2 Bruin install (admin needed?) | | |
| 0.3 uv install | | |
| 0.4 Postgres and psql on PATH | | |
| 0.5 role and both databases | | |
| 0.7 `bruin init empty smoke`: what it printed, files it created | | |
| 0.8 connections add (flag mode) worked? Interactive wizard worked in your terminal? | | |
| 0.8 ssl_mode needed? | | |
| 0.9 connections test (both) | | |
| 0.10 schema auto-created? Which `.gitignore` entries did Bruin add? | | |
| 0.11 check script | | |
| Break/fix 1 messages (validate and run) | | |
| Break/fix 4: file recreated? What does `connections list` show? | | |
| Time taken | | |
