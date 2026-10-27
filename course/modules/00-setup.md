# Module 0: Setup and first run

Estimated time: 1.5 to 2 hours (measure yours and record it in the validation log at the bottom).
Written against Bruin v0.11.773. Record the version you actually run.

## Outcome

You have Bruin, uv and Postgres working on your machine, three dedicated empty databases whose names start with your own prefix (so several people can share one Postgres server), a Bruin project scaffolded with `bruin init` and wired to them with `bruin connections add`, and one successful `bruin run`.

## Ground rules for the whole course

- **Terminal:** use Git Bash on Windows, including inside VS Code (section 0.1 shows how to make it the default terminal there). The documented Bruin installer is a `sh` script and the docs say Windows users must run it in Git Bash or WSL. Every command in this course is written for Git Bash, macOS or Linux shells. If you prefer WSL, treat it as Linux. PowerShell and `cmd` are not supported by the lessons: `export`, `$VAR`, `&&` chains, heredocs and `cd ~` all differ there.
- **Two tracks, one lesson:** the course is written for engineers who work in VS Code with the Bruin extension. Where the extension offers an action, the step shows the **VS Code** way and the CLI command that does the same thing. Run the CLI commands in the VS Code terminal or in any Git Bash window. If you do not use VS Code, ignore the VS Code blocks. Extension steps are described from the extension documentation (`vscode-extension/` in the Bruin docs) where it covers them, and otherwise from what the course reviewer saw on extension version 0.84.8. The extension changes quickly, so button labels may differ in your version. The CLI command is always the reference.
- **Database:** Postgres is the reference target. Use dedicated, empty databases that you can wipe. Do not point the course at a database that holds real data, and never at an employer system. Your databases are named with your own prefix, for example `alex_bruin_course`, so several learners can work on the same server without touching each other's data (section 0.5).
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
| VS Code (recommended) | Bruin has an extension that scaffolds projects, manages connections, previews queries and shows lineage. The course gives a VS Code step next to the CLI step | `code --version` |
| pgAdmin (optional) | A GUI for Postgres. Anywhere a lesson runs a one-off SQL statement with `psql`, you can paste it into pgAdmin's Query Tool instead (details in 0.5) | none |

### Set Git Bash as the VS Code terminal

Skip this if you do not use VS Code. VS Code on Windows opens PowerShell by default, and the lessons assume Git Bash.

1. Open the Command Palette (`Ctrl+Shift+P`) and run `Terminal: Select Default Profile`.
2. Pick `Git Bash`. If it is not listed, Git for Windows is not installed or VS Code has not seen it yet. Restart VS Code after installing.
3. Open a new terminal (Terminal menu, New Terminal) and confirm the prompt shows `MINGW64` and that `echo $SHELL` prints a path ending in `bash`.

This is a standard VS Code setting (`terminal.integrated.defaultProfile.windows`), not a Bruin feature. Terminals that were already open keep their old shell. Close them.

### Install the Bruin extension (optional)

In VS Code, open the Extensions view (`Ctrl+Shift+X`), search for `Bruin` and install the extension published by Bruin. The course reviewer used version 0.84.8. The extension needs the Bruin CLI, which you install in 0.2. Its documentation lives under `vscode-extension/` in the Bruin docs ([overview](https://getbruin.com/docs/bruin/vscode-extension/overview.html)).

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

**VS Code:** the extension can install the CLI for you (Command Palette, `Bruin: Install Bruin CLI`, from `vscode-extension/getting-started.md`). Do not use that for this course, because it installs the latest release and you want v0.11.773. Use the pinned installer above, then reload VS Code so the extension finds the binary.

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

1. A native install on your machine that you administer. The EDB installer for Windows is the common route and includes `psql`. You can log in as the `postgres` superuser.
2. A shared server at work where you have a login but not the `postgres` superuser, and where several people may use the same login. This works too. Section 0.5 has a path for it. All you need is a login that can create databases, or a DBA who creates three databases for you.
3. Optional: the official Postgres container image (`https://hub.docker.com/_/postgres`) if you already run containers. The course does not require containers.

Use version 17 or newer. The materialization docs list PostgreSQL 17 or later as the requirement for `scd2_by_column` and `scd2_by_time`. Everything before Module 8 works on older versions, but you will hit a wall there. You check the server version in 0.9, after Bruin has a connection to it.

Make sure `psql` runs in Git Bash. If `psql --version` fails after a native Windows install, add the Postgres `bin` folder to your `PATH`, for example:

```bash
echo 'export PATH="/c/Program Files/PostgreSQL/16/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Adjust the version number to match your install.

## 0.5 Create your course databases

You need three empty databases: one where Bruin builds everything (the warehouse), one that plays the role of an operational source system that Bruin reads from (Module 2), and one for the environment lab in Module 10. Keeping the source separate means Module 2 behaves like a real extract from another system.

To let several people share one Postgres server, every database name starts with your own prefix. The prefix is your operating-system username, lowercased, with anything other than letters, digits and underscores replaced by `_`. For a user `Alex.Smith` the databases are:

| Role in the course | Name | Shell variable |
|---|---|---|
| warehouse | `alex_smith_bruin_course` | `$COURSE_DB` |
| source system | `alex_smith_bruin_course_src` | `$COURSE_SRC_DB` |
| dev environment (Module 10) | `alex_smith_bruin_course_dev` | `$COURSE_DEV_DB` |

The lessons always write these as variables or as `<prefix>_bruin_course`. Never type another learner's database name. The reset script (`tools/reset.sh`) refuses to run against any database whose name does not match these variables.

Constraints on the prefix: it must start with a letter and the longest database name must stay under 63 characters, the Postgres identifier limit. The block below truncates the prefix to 30 characters. If you want a different prefix (a team name, say), run `export COURSE_PREFIX=myname` before the block.

### Step 1: choose your values

Run this block on its own. It stops at a password prompt, so do not paste anything after it. Git Bash does not always define `$USER`, so the block falls back to `$USERNAME` and then `id -un`.

```bash
raw="${COURSE_PREFIX:-${USER:-${USERNAME:-$(id -un)}}}"
COURSE_PREFIX="$(printf '%s' "$raw" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_' '_' | sed 's/^[^a-z]*//' | cut -c1-30)"
echo "Prefix: $COURSE_PREFIX"
COURSE_PG_HOST="${COURSE_PG_HOST:-localhost}"
COURSE_PG_PORT="${COURSE_PG_PORT:-5432}"
COURSE_PG_USER="${COURSE_PG_USER:-${COURSE_PREFIX}_course}"
read -rsp "Password for $COURSE_PG_USER (no @ : / # characters): " COURSE_PG_PASSWORD; echo
```

Check the printed prefix. If it is empty or wrong, run `export COURSE_PREFIX=yourname` and repeat the block.

Which login and password you enter depends on your server:

- **Path A, you administer the server** (local install). Keep the default login name `<prefix>_course` or choose another. The password is a new one you invent. Step 3A creates the login with it.
- **Path B, a shared server and an existing login** (for example everyone on the team uses `da_user`). Set the login before the block: `export COURSE_PG_USER=da_user` and set `COURSE_PG_HOST` and `COURSE_PG_PORT` the same way if they are not `localhost` and `5432`. At the prompt, enter that login's real password. The login needs the `CREATEDB` attribute (Step 3B). If it does not have it, use Path C.
- **Path C, a DBA creates the databases.** Set the same values as Path B and ask the DBA to run the statements in Step 3C.

Use a password without `@`, `:`, `/`, `#`, `"` or `\` characters. It is placed inside connection strings and JSON, and those characters would need escaping.

### Step 2: save the values for every new terminal

This block writes your values to `~/.bruin_course_env` and makes `~/.bashrc` load that file. It replaces the file each time, so running it again does not create duplicates (if you run it again after 0.6, repeat the `COURSE` line from 0.6 as well). Apart from this file, the password is written only to `.bruin.yml` in 0.8.

```bash
{
  printf 'export COURSE_PREFIX=%q\n' "$COURSE_PREFIX"
  printf 'export COURSE_PG_HOST=%q\n' "$COURSE_PG_HOST"
  printf 'export COURSE_PG_PORT=%q\n' "$COURSE_PG_PORT"
  printf 'export COURSE_PG_USER=%q\n' "$COURSE_PG_USER"
  printf 'export COURSE_PG_PASSWORD=%q\n' "$COURSE_PG_PASSWORD"
  echo 'export COURSE_DB="${COURSE_PREFIX}_bruin_course"'
  echo 'export COURSE_SRC_DB="${COURSE_PREFIX}_bruin_course_src"'
  echo 'export COURSE_DEV_DB="${COURSE_PREFIX}_bruin_course_dev"'
  echo 'export PGURL="postgresql://${COURSE_PG_USER}:${COURSE_PG_PASSWORD}@${COURSE_PG_HOST}:${COURSE_PG_PORT}/${COURSE_DB}"'
  echo 'export PGURL_SRC="postgresql://${COURSE_PG_USER}:${COURSE_PG_PASSWORD}@${COURSE_PG_HOST}:${COURSE_PG_PORT}/${COURSE_SRC_DB}"'
} > ~/.bruin_course_env
chmod 600 ~/.bruin_course_env
grep -q 'bruin_course_env' ~/.bashrc 2>/dev/null || echo '[ -f ~/.bruin_course_env ] && . ~/.bruin_course_env' >> ~/.bashrc
. ~/.bruin_course_env
echo "$COURSE_DB  $COURSE_SRC_DB  $COURSE_DEV_DB"
```

Course pattern, not a Bruin feature: Bruin itself reads connections from `.bruin.yml`, never from these variables. The variables exist so that the lessons, the `psql` commands for writes and admin steps, and the helper scripts in `tools/` all use the same names, and so that you type a password once. The file holds the password in plain text in your home folder. On Path A it is a throwaway course password, so do not reuse one you use elsewhere. On Path B it is the real password of a shared login. `chmod 600` limits the file to your user on macOS and Linux, and may not do so on Windows file systems. If a plain-text shared password in your home folder is not acceptable where you work, ask for a personal login and use Path C.

Open a new terminal and check that the values arrive:

```bash
echo "$COURSE_DB"
```

UNVERIFIED: whether Git Bash loads `~/.bashrc` in every terminal you use. A Git Bash window normally starts a login shell, which reads `~/.bash_profile`, and the VS Code Git Bash profile is expected to do the same. Git for Windows normally ships a `~/.bash_profile` that sources `~/.bashrc`. If `echo` prints an empty line, run `echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> ~/.bash_profile` and open another terminal. Record what happened.

### Step 3A: you administer the server

Connect as the superuser and create the login and the databases. The variables are passed into `psql`, which quotes them safely as identifiers (`:"name"`) and strings (`:'name'`):

```bash
psql -h "$COURSE_PG_HOST" -p "$COURSE_PG_PORT" -U postgres -d postgres \
  -v u="$COURSE_PG_USER" -v pw="$COURSE_PG_PASSWORD" \
  -v db="$COURSE_DB" -v sdb="$COURSE_SRC_DB" -v ddb="$COURSE_DEV_DB" <<'SQL'
CREATE ROLE :"u" LOGIN PASSWORD :'pw';
CREATE DATABASE :"db" OWNER :"u";
CREATE DATABASE :"sdb" OWNER :"u";
CREATE DATABASE :"ddb" OWNER :"u";
SQL
```

`psql` asks for the `postgres` password. UNVERIFIED: in some Git Bash windows (the older mintty one) native Windows programs do not show a password prompt. If `psql` hangs or fails with a password error, run the same command as `winpty psql ...` or use the VS Code terminal.

### Step 3B: a shared server and a login that can create databases

You are the login in `$COURSE_PG_USER`. You do not need the `postgres` superuser. Connect to any database you can already reach (`postgres` is the usual one; use another name if the server restricts it):

```bash
PGPASSWORD="$COURSE_PG_PASSWORD" psql -h "$COURSE_PG_HOST" -p "$COURSE_PG_PORT" -U "$COURSE_PG_USER" -d postgres \
  -v db="$COURSE_DB" -v sdb="$COURSE_SRC_DB" -v ddb="$COURSE_DEV_DB" <<'SQL'
CREATE DATABASE :"db";
CREATE DATABASE :"sdb";
CREATE DATABASE :"ddb";
SQL
```

The login owns the databases it creates. If a statement fails with `permission denied to create database`, the login lacks `CREATEDB`: use Step 3C.

If a name already exists because someone else on your team chose the same prefix, `CREATE DATABASE` reports `already exists`. Do not reuse it. Choose a different prefix (`export COURSE_PREFIX=alex2`) and repeat Steps 1 to 3.

### Step 3C: a DBA creates the databases

Print the three names and send them to your DBA:

```bash
echo "$COURSE_DB $COURSE_SRC_DB $COURSE_DEV_DB"
```

Ask for three empty databases, each owned by (or fully granted to) `$COURSE_PG_USER`, including permission to create schemas in them. The course creates and drops schemas freely inside these databases and nowhere else.

### Step 4: check the login with `psql`

This is a check of the login itself, so it uses `psql` and the URLs from Step 2. Bruin does not have a connection yet.

```bash
psql "$PGURL" -c "select current_database(), current_user;"
psql "$PGURL_SRC" -c "select current_database(), current_user;"
```

Expected: one row per command. The first shows your `<prefix>_bruin_course` and the login, the second your `<prefix>_bruin_course_src` and the login. Check the dev database the same way: `psql "${PGURL%/*}/$COURSE_DEV_DB" -c "select current_database();"`.

**pgAdmin instead of `psql`:** register your server in pgAdmin with the same host, port, login and password. Expand Databases, right-click your warehouse database and open the Query Tool. Run `select current_database(), current_user;` there. Use the same pattern whenever a lesson runs a one-off SQL statement with `psql "$PGURL" -c "..."`: open the Query Tool on the right database and paste the statement. Two things need `psql` and not pgAdmin: the `-f` loader scripts in `$COURSE/data/sql` (they use `psql` meta-commands for loading CSV files) and `tools/reset.sh`.

**Read-only checks use Bruin.** From this point on, lessons check data with `bruin query --connection <name> --query "..."` wherever the statement only reads, because Bruin has the connection and you will use it in your own work. Statements that change data (`drop`, `delete`, `insert`, `truncate`) stay on `psql` or pgAdmin, since `bruin query` is documented as retrieving results and the docs do not say whether it is meant for writes (UNVERIFIED).

## 0.6 Get the course repository and make your work repository

You need two folders: the course repository (read-only reference, holds the data) and your own Bruin project (where you build).

Clone the course wherever you keep projects. The first command below moves to your home folder. To keep both folders elsewhere, replace `cd ~` with that folder, for example `cd /d/Bruin_Projects` for a `D:` drive (Git Bash writes drive `D:` as `/d`).

```bash
cd ~
git clone https://github.com/jacksoneyton/Bruin-for-Data-Engineers.git
echo "export COURSE=\"$(pwd)/Bruin-for-Data-Engineers/course\"" >> ~/.bruin_course_env
. ~/.bruin_course_env
echo "$COURSE"

mkdir lakota-bruin
cd lakota-bruin
git init
```

`$COURSE` now points at the `course` folder of the clone, wherever it is. Run the `echo "export COURSE=..."` line once, because running it twice appends a second line (the last one wins, so the result is still correct). Later lessons write `cd ~/lakota-bruin` to return to the work repository. If yours is somewhere else, substitute that path.

A Bruin project is a Git repository, and `.bruin.yml` must live at its root (`core-concepts/project.md`). That is why your work lives in its own repository.

## 0.7 Scaffold the project with `bruin init`

You do not write `.bruin.yml` or a pipeline folder from scratch. `bruin init <template> <folder>` scaffolds them (`commands/init.md`, `getting-started/introduction/quickstart.md`). Run it from the work repository:

```bash
cd ~/lakota-bruin
bruin init empty smoke
```

**VS Code:** the Bruin extension has its own project-init flow (the reviewer saw it on extension 0.84.8 while following issue #1; it is not described in the extension documentation). Open the empty `lakota-bruin` folder in VS Code (File, Open Folder), start the Bruin init flow from the extension, pick the `empty` template and name the folder `smoke`. The extension runs the same scaffold as the CLI command, so everything below applies. If you cannot find the flow in your version, run the CLI command.

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

Add the warehouse connection and the source connection. In flag mode, all four of `--env`, `--type`, `--name` and `--credentials` must be given together. The credentials are the JSON form of the connection, with the field names from `platforms/postgres.md`. The values come from the shell variables you saved in 0.5, so the same commands work for every learner on every server. The double quotes let the shell fill the variables in, and the backslashes keep the JSON quotes:

```bash
bruin connections add --env default --type postgres --name lakota-pg \
  --credentials "{\"username\": \"$COURSE_PG_USER\", \"password\": \"$COURSE_PG_PASSWORD\", \"host\": \"$COURSE_PG_HOST\", \"port\": $COURSE_PG_PORT, \"database\": \"$COURSE_DB\"}"

bruin connections add --env default --type postgres --name lakota-src \
  --credentials "{\"username\": \"$COURSE_PG_USER\", \"password\": \"$COURSE_PG_PASSWORD\", \"host\": \"$COURSE_PG_HOST\", \"port\": $COURSE_PG_PORT, \"database\": \"$COURSE_SRC_DB\"}"
```

Bruin writes the expanded values into `.bruin.yml`. That file is git-ignored, but it now contains your password in plain text. Module 10 shows how to replace it with an environment variable reference.

**VS Code:** the extension can add a connection to `.bruin.yml` through a form (seen by the reviewer on extension 0.84.8, issue #1; not in the extension documentation). Use the extension's add-connection form: choose the type Postgres, name it `lakota-pg` and fill in the fields. To read the values, run `echo "$COURSE_PG_USER $COURSE_PG_HOST $COURSE_PG_PORT $COURSE_DB"` in the terminal. Type the password yourself. Repeat for `lakota-src` with `$COURSE_SRC_DB`. The result in `.bruin.yml` is the same as the CLI commands above.

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

Look at what Bruin wrote, and confirm the file is ignored by Git. In VS Code, open `.gitignore` and `.bruin.yml` from the Explorer and read them there. In any terminal:

```bash
git check-ignore -v .bruin.yml
```

The output names the `.gitignore` line that matches. (`cat .gitignore` shows the whole file if you prefer the terminal.)

`.bruin.yml` holds credentials and must never be committed. If `check-ignore` prints nothing, add `.bruin.yml` to `.gitignore` yourself.

One detail that bites later: Bruin appends its `.gitignore` entries without a trailing newline in the file. When you append your own lines, start with a newline, for example `printf '\nlogs/\n' >> .gitignore`. A plain `echo "logs/" >> .gitignore` can glue the new line onto the last entry.

## 0.9 List and test the connections

```bash
bruin connections list
bruin connections test --name lakota-pg
bruin connections test --name lakota-src
```

Source: `commands/connections.md`. `list` prints connection type, name and the names of filled fields, never the values. `test` runs a simple validation check against the connection and, without `--env`, uses the default environment from `.bruin.yml`.

**VS Code:** the extension shows the connections in `.bruin.yml` and has a test action for each (the reviewer saw both on extension 0.84.8, issue #1; not in the extension documentation). The database browser in the Bruin activity-bar view lists connections, databases, schemas and tables (`vscode-extension/panels/activity-bar.md`), which also confirms that Bruin can reach the server. Use whichever you prefer. The CLI commands above are what the check script in 0.11 runs.

Now that Bruin has a connection, check the server version with it, instead of `psql`:

```bash
bruin query --connection lakota-pg --query "show server_version"
```

Module 8 needs 17 or newer. `bruin query` finds `.bruin.yml` on its own: it looks for the root of the Git repository you are standing in (`cmd/fetch.go`, read from the CLI source), which is why you run it from inside `lakota-bruin`. If it complains that it cannot find the repository, you are in the wrong folder.

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

Notes on what you wrote, all from the asset definition reference (`assets/definition-schema.md` in the docs folder of the Bruin repository, published at [getbruin.com/docs/bruin/assets/definition-schema](https://getbruin.com/docs/bruin/assets/definition-schema.html)). Other lessons cite docs pages the same way: a path such as `commands/run.md` maps to `https://getbruin.com/docs/bruin/commands/run.html`.

- A SQL asset keeps its definition and its query in one `.sql` file. The definition sits between `/* @bruin` and `@bruin */`.
- `name` is `schema.table`. On Postgres, Bruin accepts a `table` or `schema.table` name and rejects three segments (`a.b.c`) during validation (the table in the docs page, and `pkg/tablename/capability.go` in the CLI source). The limit comes from Bruin's validation rules, not from Postgres. A one-segment name lands in the `public` schema, and the course checks that in the break/fix below. The course always uses two segments so each module has its own schema. If you leave `name` out, Bruin infers it from the file path under `assets/`, so `assets/smoke/hello.sql` becomes `smoke.hello`.
- `type: pg.sql` selects the Postgres SQL runner. `materialization: type: table` makes Bruin create a table from the query result (default strategy is `create+replace`).
- Because `pipeline.yml` sets `default_connections`, the asset does not need its own `connection` field.

Validate, run, then query the result:

```bash
bruin validate smoke
bruin run smoke
bruin query --connection lakota-pg --query "select * from smoke.hello"
```

Sources: `commands/validate.md`, `commands/run.md`, `commands/query.md`.

Why these commands need no path to `pipeline.yml`, to `hello.sql` or to `.bruin.yml`:

- **`smoke` is the path.** `validate` and `run` take an optional path to a pipeline folder or to a single asset file (`[path to pipelines]` in `commands/validate.md`, `[optional path to the pipeline/asset]` in `commands/run.md`). You give the folder `smoke`, Bruin finds `pipeline.yml` inside it and then discovers every asset under `smoke/assets/`. With no path, both commands use the current directory. If you pass a path to an asset file, such as `smoke/assets/smoke/hello.sql`, Bruin works on just that asset: `run` prints "Running only the asset" and still loads the whole pipeline to resolve its settings. `hello.sql` therefore never needs to be named, and `--downstream` and `--only` exist for the cases where you want a slice.
- **`.bruin.yml` is found from the Git root.** The commands search upward from where you stand for the root of the Git repository and read `.bruin.yml` there (`core-concepts/project.md`). That is why every command must run inside `lakota-bruin`. `--config-file` or `BRUIN_CONFIG_FILE` overrides it.
- **`bruin query` takes a connection name, not a path.** `--connection lakota-pg` names an entry in `.bruin.yml`, and `--query` is any SQL for that database. It does not read your asset file unless you use `--asset` (`commands/query.md`). Note that the table is addressed as `smoke.hello` because that is where `name: smoke.hello` put it.

**VS Code:** open `smoke/assets/smoke/hello.sql`. The extension's side panel shows the asset's details (name, type, a SQL preview and the environment and date inputs, `vscode-extension/panels/side-panel/tabs.md`) and has buttons that run Bruin commands without the terminal (`vscode-extension/getting-started.md`, step 4). Use them to validate and run the asset, then check the Query Preview panel. It has a **Run** button (also `Ctrl+Enter`) that executes the asset's query and shows the rows below the editor (`vscode-extension/panels/query-preview.md`), and a **Preview** CodeLens above the query. Treat the preview as a look at the query's rows and the run as the build: run the asset first, then query `smoke.hello` with the CLI command above or through the database browser in the activity bar. The buttons run the same commands as the terminal, so the terminal output is the record you keep.

You should see the validation pass, a run that executes one asset, and a one-row table. Bruin creates the `smoke` schema for you: for a SQL asset with a materialization, the Postgres runner issues `CREATE SCHEMA IF NOT EXISTS` before the query (read from the CLI source, `pkg/postgres/operator.go`; confirm in your run and record it in the validation log).

Look at what Bruin did on disk and in Git. In VS Code, expand `logs/runs/smoke` in the Explorer and open `.gitignore`. In the terminal:

```bash
ls logs/runs/smoke
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

if [ -n "$COURSE_DB" ] && [ -n "$COURSE_SRC_DB" ]; then ok "course databases: $COURSE_DB, $COURSE_SRC_DB"; else no "COURSE_DB / COURSE_SRC_DB not set (section 0.5, open a new terminal)"; fi
if [ -n "$PGURL" ] && psql "$PGURL" -Atc "select 1" >/dev/null 2>&1; then ok "database reachable via PGURL"; else no "database not reachable via PGURL"; fi
if [ -f .bruin.yml ] && git check-ignore -q .bruin.yml; then ok ".bruin.yml exists and is git-ignored"; else no ".bruin.yml missing or not git-ignored"; fi
if [ -n "$PGURL_SRC" ] && psql "$PGURL_SRC" -Atc "select 1" >/dev/null 2>&1; then ok "source database reachable via PGURL_SRC"; else no "source database not reachable via PGURL_SRC"; fi
for c in lakota-pg lakota-src; do
  if bruin connections test --name "$c" >/dev/null 2>&1; then ok "bruin connection $c"; else no "bruin connection $c"; fi
done
if bruin validate smoke >/dev/null 2>&1; then ok "bruin validate smoke"; else no "bruin validate smoke"; fi
if bruin run smoke >/dev/null 2>&1; then ok "bruin run smoke (validate alone does not prove the connections work)"; else no "bruin run smoke"; fi
```

## Break/fix

Do these in order. Read the symptom, find the cause, then fix. The answers are at the end. In VS Code, edit the files in the editor. Run every command in the terminal, or with the extension's buttons where they exist.

1. In `smoke/pipeline.yml`, change `lakota-pg` to `lakota_pg`. Run `bruin validate smoke` and `bruin run smoke`. What does each report? Which one catches it?
2. In `smoke/assets/smoke/hello.sql`, change the asset name to `hello` (one segment). Run `bruin validate smoke`, `bruin run smoke`, then `bruin query --connection lakota-pg --query "select * from hello"`. What happens, and in which schema is the table? Then change the name to `a.b.c` (three segments) and validate again. What does Bruin say?
3. In `.bruin.yml`, change the port of `lakota-pg` to `5439`. Run `bruin connections test --name lakota-pg`. Compare this failure with the one in step 1.
4. Move `.bruin.yml` aside (`mv .bruin.yml .bruin.yml.bak`) and run `bruin validate smoke`. What does Bruin do about the missing file, and what does `bruin connections list` show afterwards? Then restore the file (`mv .bruin.yml.bak .bruin.yml`; if Bruin created a new one, delete that first).

Restore all four after each step. After step 2, also remove the stray table: `psql "$PGURL" -c "drop table if exists public.hello"` (or run that statement in pgAdmin's Query Tool).

<details>
<summary>Answers</summary>

1. `validate` reports no issues and `run` fails with an error that the connection `lakota_pg` is not found in the config file. This was observed by the course reviewer on v0.11.773. The reason, read from the CLI source (`pkg/lint/query.go`): without `--fast`, `validate` runs a live query check for Postgres assets, but when the asset's connection name cannot be found it skips the check without reporting anything, and no other rule checks that the pipeline's default connection exists. The lesson text before this revision said the opposite. Takeaway: `validate` checks structure and, when the connection resolves, query syntax. It does not prove that your connections exist. Run `bruin connections test` and a real run to prove those.
2. The reviewer saw `validate` and `run` both succeed with a one-segment name, and the query `select * from hello` worked. On Postgres, Bruin accepts a bare `table` name (`pkg/tablename/capability.go`: minimum 1 and maximum 2 components), and the table lands in the connection's default schema, `public`. The docs sentence that single-segment names are "rejected by most databases" (`assets/definition-schema.md`) describes name inference, and it does not hold for Postgres. A three-segment name is rejected during validation, because the docs list three segments as "Not supported" for PostgreSQL. Record the exact message. The course keeps two-segment names so that each module's tables sit in a schema of their own and `reset.sh` can drop them. Drop `public.hello` when you are done.
3. A wrong port is a runtime connectivity failure. `connections test` reports it with the host, port and a refused-connection message. `validate --fast` would not catch it, because `--fast` never opens a connection. A non-fast `validate` against a connection that does resolve runs a live check and shows "Failed to validate query" (source-derived, `pkg/lint/query.go`). Compare that with step 1, where the connection name was wrong and `validate` passed.
4. `core-concepts/project.md` says Bruin creates `.bruin.yml` automatically the first time a command needs it and adds it to `.gitignore`. The new file has a `default` environment and no connections. Whether `validate` passes or fails then follows what you learned in step 1: a missing connection is silent in `validate` and fatal in `run`. This is why you should never delete `.bruin.yml` casually: Bruin does not rebuild your connections. Re-add them with 0.8. UNVERIFIED: what `validate` prints in this case.
</details>

## Check questions

1. Where must `.bruin.yml` live, and why is it git-ignored?
2. What is the difference between `bruin validate` and `bruin run`? Name one mistake `validate` will not catch.
3. A SQL asset file has its definition in `hello.asset.yml` and its query in `hello.sql`. Why does this fail?
4. What does `bruin connections list` show, and what does it deliberately not show?
5. A pipeline run without `--start-date` and `--end-date` uses which date window?
6. Which commands create `.bruin.yml`, and what else do they change?

<details>
<summary>Answers</summary>

1. At the root of the Git repository (override with `--config-file` or `BRUIN_CONFIG_FILE`). It holds credentials.
2. `validate` checks configuration and structure without executing assets. Without `--fast` it also checks each query against the database for BigQuery, Snowflake and Postgres (`cmd/lint.go`), but only for assets whose connection it can resolve; `--fast` runs only the offline rules. `run` executes the assets. A default connection name that does not exist in `.bruin.yml` passes `validate` and fails `run` (break/fix 1).
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
| 0.5 prefix printed in Step 1 (is it what you expected?), path used (A, B or C), three databases created, `~/.bruin_course_env` loaded in a new terminal (Git Bash window and VS Code terminal) | | |
| 0.5 `winpty` or other workaround needed for the psql password prompt? pgAdmin used? | | |
| 0.7 `bruin init empty smoke`: what it printed, files it created | | |
| 0.8 connections add (flag mode) worked? Interactive wizard worked in your terminal? | | |
| 0.8 ssl_mode needed? | | |
| 0.9 connections test (both) | | |
| 0.10 schema auto-created? Which `.gitignore` entries did Bruin add? | | |
| 0.11 check script | | |
| 0.1 VS Code: Git Bash default profile set; Bruin extension version (course reviewer: 0.84.8) | | |
| 0.7 / 0.8 / 0.9 VS Code init flow, add-connection form, connection test: found and worked? Labels that differ from the lesson | | |
| 0.9 `bruin query ... "show server_version"` output | | |
| 0.10 `bruin validate smoke`, `bruin run smoke`: VS Code buttons used? | | |
| Break/fix 1 messages (validate and run) | | |
| Break/fix 2: one-segment name result, schema of the table, exact message for the three-segment name | | |
| Break/fix 4: file recreated? What does `connections list` show? | | |
| Time taken | | |
