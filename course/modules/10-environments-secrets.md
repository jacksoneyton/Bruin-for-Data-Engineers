# Module 10: Environments, secrets and resource limits

Estimated time: 3 to 3.5 hours. Written against Bruin v0.11.773.

## Outcome

You can run the same pipeline code against development, staging and production targets, choose between separate databases and schema prefixes, keep credentials out of `.bruin.yml` and out of git, feed configuration to a CI job, explain how external secret backends are wired, cap concurrency per connection, and protect production tables.

Docs for this module: `core-concepts/project.md`, `getting-started/devenv.md`, `secrets/bruinyml.md`, `secrets/overview.md`, `secrets/vault.md`, `secrets/doppler.md`, `secrets/aws-secrets-manager.md`, `core-concepts/secrets.md`, `commands/environments.md`, `commands/connections.md`, `getting-started/concurrency.md`, `assets/materialization.md` (section on `full_refresh_restricted`), `commands/run.md`.

## 10.1 Concepts to read first

Answers are at the end.

1. Which part of the setup stays identical across environments and which part changes?
2. What is the limitation that makes a separate database necessary for a plain environment, and what does `schema_prefix` do about it?
3. How does Bruin decide whether to rewrite a table reference to a prefixed schema?
4. When are `${VAR}` references in `.bruin.yml` expanded?
5. Which secret backends does `--secrets-backend` accept, and what is the shape of a secret stored in them?
6. What do `--workers` and `max_concurrent_assets` each limit?
7. What does `full_refresh_restricted` do at asset level and at environment level?

## 10.2 Lab: a second environment in a separate database

Your pipelines refer to connections by name (`lakota-pg` in `pipeline.yml`). An environment is a set of connections with the same names pointing somewhere else. The pipeline code does not change.

Create a development database. Use the same administrator session you used in Module 0:

```sql
CREATE DATABASE bruin_course_dev OWNER bruin_course;
```

Clone the default environment, then point the copy at the dev database:

```bash
cd ~/lakota-bruin
bruin environments list
bruin environments clone --source default --target dev
```

`clone` copies every connection and the schema prefix of the source. It does not copy the environment's `config` block (for example `full_refresh_restricted`, see 10.8). There is no `bruin connections update` command, so changing a connection means deleting it and adding it again. Leave `lakota-src` alone: both environments read the same source system.

```bash
bruin connections delete --env dev --name lakota-pg
bruin connections add --env dev --type postgres --name lakota-pg --credentials '{"username": "bruin_course", "password": "choose-a-simple-password", "host": "localhost", "port": 5432, "database": "bruin_course_dev"}'
```

The password is now in your shell history. That is acceptable for a throwaway lab password, and not for a real one. Open `.bruin.yml` afterwards and read the `dev` block to see what the commands wrote. The documented connection fields for Postgres (`platforms/postgres.md`) are `username`, `password`, `host`, `port`, `database`, `schema`, `pool_max_conns`, `ssl_mode` and `read_only`.

```bash
bruin connections list --environment dev
bruin connections test --name lakota-pg --env dev
```

Check that the dev connection points where you intend: `bruin query --connection lakota-pg --env dev --query "select current_database()"`. `query` accepts `--environment` (alias `--env`) together with `--connection` (`commands/query.md`). Each query writes a small log under `logs/queries`.

Build the pipeline in dev with a small window, leaving the default environment untouched:

```bash
bruin run lakota --environment dev --tag landing --start-date 2000-01-01 --end-date "2026-01-02 23:59:59.999999"
bruin run lakota --environment dev --exclude-tag landing --full-refresh --start-date 2026-01-01 --end-date "2026-01-02 23:59:59.999999"
```

Compare the two databases:

```bash
psql "$PGURL" -Atc "select current_database(), count(*) from staging.customers"
psql "postgresql://bruin_course:choose-a-simple-password@localhost:5432/bruin_course_dev" -Atc "select current_database(), count(*) from staging.customers"
```

The source system may be at a different day than the dev run's window, which makes the counts differ. Explain any difference you see. Record whether `ctl.pipeline_status` in dev got a marker row and which pipeline reads it. If a consumer pipeline from Module 9 ran in dev, would it read dev's marker or the default environment's? Why?

## 10.3 Lab: a schema-prefix environment

Add an environment that shares the warehouse database but prefixes schemas:

```bash
bruin environments clone --source default --target dev_jane --schema-prefix jane
bruin connections list --environment dev_jane
```

`clone` copies the two connections from `default` and sets the prefix in one step. `bruin environments create --name X --schema-prefix Y` makes an empty environment with no connections (source-derived, `cmd/environments.go`; confirm with `connections list`). Bruin appends an underscore to the prefix when it builds schema names, so `jane` and `jane_` are equivalent (`pkg/config/manager.go`).

Run only the downstream layers first, with landing left alone:

```bash
bruin run lakota --environment dev_jane --exclude-tag landing --full-refresh --start-date 2026-01-01 --end-date "2026-01-04 23:59:59.999999"
psql "$PGURL" -c "select table_schema, table_name from information_schema.tables where table_schema like 'jane%' order by 1, 2"
```

The docs say an asset named `mart.customers` becomes `jane_mart.customers`. Record:

- Which schemas appeared, and which tables landed in each?
- `jane_landing` does not exist. Where did `staging.customers` read its data from? Compare the rendered SQL: `bruin render lakota/assets/staging/customers.sql --environment dev_jane`. The docs say Bruin rewrites a table reference to the prefixed schema only if the prefixed table exists.
- Now load landing in this environment (`--tag landing`) and render the same asset again. What changed? This is the property that makes schema prefixes both useful (read production-like data, write privately) and risky (a partially prefixed set of tables can mix sources).
- Did seeds, ingestr assets and the Python assets put their output in prefixed schemas? Source reading says SQL assets, seeds and ingestr destinations are all renamed with the prefix. A Python asset is not rewritten: Bruin sets `BRUIN_SCHEMA_PREFIX` and the code has to apply it (Module 6). Jinja templates get a `schema_prefix` variable. UNVERIFIED at runtime for each type, so confirm them.
- Did the marker row from Module 9 land in `jane_ctl.pipeline_status`? The marker writer is a SQL asset whose `INSERT` names `ctl.pipeline_status` in its text. Whether that reference is rewritten depends on whether the prefixed table exists at that point (UNVERIFIED). Also check whether a sensor's `table_name` parameter is rewritten (UNVERIFIED).

Clean up what you created. List the schemas first, then drop each one that starts with `jane_`:

```bash
psql "$PGURL" -Atc "select nspname from pg_namespace where nspname like 'jane\\_%'"
psql "$PGURL" -c "drop schema if exists jane_mart cascade"   # repeat for each schema listed
```

### Which style should the bank use?

Fill in the table in your notes. The first rows come from `getting-started/devenv.md`. For Snowflake the course cannot verify behavior, so write down what you would test.

| Question | Separate database per environment | Schema prefix in one database |
|---|---|---|
| Isolation | | |
| Cost and data volume to replicate | | |
| Can read production-like data without copying | | |
| Risk of mixing prefixed and unprefixed sources | | |
| What would you test on Snowflake before choosing? | | |

## 10.4 Lab: keep credentials out of `.bruin.yml`

`${VAR}` references in `.bruin.yml` are expanded when Bruin loads the file (`secrets/bruinyml.md`).

**Warning: write-back.** The commands that change the file (`bruin environments create`, `update`, `clone`, `delete` and `bruin connections add`, `delete`) load the config, change it in memory and write the whole file back. The loader has already replaced `${LAKOTA_PW}` with its value when the variable is set in your shell, so the written file can contain the plain password where you had the reference (`LoadFromFileOrEnv` and `Persist` in `pkg/config/manager.go`; UNVERIFIED on a real machine). Two rules follow:

1. Run every `environments` and `connections` command in a shell where the variable is not set (`unset LAKOTA_PW`).
2. After any such command, run `grep -c '\${LAKOTA_PW}' .bruin.yml` and confirm the count did not drop. `git diff` will not help, because Bruin adds `.bruin.yml` to `.gitignore`.

Test the hazard once on a copy: `export LAKOTA_PW=...`, run `bruin environments clone --source default --target hazard_test`, then look for the plain password in the file. Delete the clone and restore the references.

```bash
export LAKOTA_PW='choose-a-simple-password'
```

In `.bruin.yml`, change the password of `lakota-pg` and `lakota-src` in `default` to `${LAKOTA_PW}`. This is one of the few edits you make by hand, because the CLI has no way to store a reference. Then:

```bash
bruin connections test --name lakota-pg
unset LAKOTA_PW
bruin connections test --name lakota-pg
```

Record the exact failure when the variable is missing. An unset variable is not replaced: Bruin keeps the literal text `${LAKOTA_PW}` and passes it as the password, so expect a Postgres authentication error rather than an empty-password or missing-variable message (source-derived). Put the variable back afterwards. On Windows, note where you set it so that scheduled tasks can see it: a variable exported in an interactive Git Bash session is not visible to Task Scheduler. Record what you decided (a user environment variable in Windows settings, or a file the wrapper sources).

### Config supplied through the environment

CI systems usually do not have a `.bruin.yml`. The docs say `BRUIN_CONFIG_FILE_CONTENT` takes precedence over the file, and `${VAR}` references inside it are expanded as well:

```bash
export BRUIN_CONFIG_FILE_CONTENT="$(cat .bruin.yml)"
mv .bruin.yml .bruin.yml.bak
bruin connections list
bruin connections test --name lakota-pg
mv .bruin.yml.bak .bruin.yml
unset BRUIN_CONFIG_FILE_CONTENT
```

Record whether it worked without the file, and whether Bruin created a new empty `.bruin.yml` while the real one was moved away. In CI you would store the whole file (with `${VAR}` references) as one protected variable and inject the real secrets separately.

### Are credentials in your logs?

```bash
grep -rl "choose-a-simple-password" logs/ 2>/dev/null | head
```

The docs say `--mask-credentials` is on by default and redacts credential values in run logs. Confirm that no log contains the password. Masking covers terminal and log output. The run-state JSON under `logs/runs` stores the command line as you typed it (`cmdline`, `pkg/scheduler/scheduler.go`), so do not pass secrets as flags (`--var`, `connections add --credentials`) on shared machines. That also keeps them out of shell history. Also check `git status` and `git log -p -S "choose-a-simple-password"` in your repository to make sure the password never entered a commit.

## 10.5 Secrets in assets

You used `secrets:` and `connection:` injection in Module 6. Two extra checks:

1. Add a generic connection to the default environment:

```yaml
      generic:
        - name: LAKOTA_API_KEY
          value: "not-a-real-key"
```

2. Write a Python asset that lists which environment variables starting with `LAKOTA_` exist, once without `secrets:` and once with `secrets: [- key: LAKOTA_API_KEY]`. Never print the value. Confirm that SQL assets cannot see the secret (the docs say secret mappings are not available in the SQL or Jinja context).

Use `inject_as` to rename the variable, and record the exact YAML you used.

## 10.6 External secret backends

You will not stand up Vault, Doppler or AWS here. The goal is to be able to specify what the platform team must build. Read the three pages and the `--secrets-backend` row in `commands/run.md`, then complete this table.

| | Vault | Doppler | AWS Secrets Manager | Azure Key Vault |
|---|---|---|---|---|
| Enable with | | | | `--secrets-backend azure` |
| Variables Bruin needs | | | | `BRUIN_AZURE_KEYVAULT_URL`; `BRUIN_AZURE_AUTH_METHOD` (`default`, `cli`, `managed_identity`, `client_credentials`); for `client_credentials` also `BRUIN_AZURE_TENANT_ID`, `BRUIN_AZURE_CLIENT_ID`, `BRUIN_AZURE_CLIENT_SECRET` (source-derived, no docs page) |
| Where each connection's secret lives | | | | |
| Secret value format | | | | |
| How Bruin authenticates | | | | |

Then write, for `lakota-pg`, the exact secret you would store in each backend (JSON with `type` and `details`). Check your answer against the Postgres example in the docs. Which connection fields would you leave out of the secret, and why?

Your platform is Azure. The flag help lists `azure` (`vault`, `doppler`, `aws` and `azure` are the accepted values) but this snapshot of the docs has no page for it. The v0.11.773 source (`pkg/secrets/azure_keyvault.go`) reads the variables in the table above and expects a secret named after the connection (`lakota-pg`) whose value is JSON with a non-empty `type` and a `details` object, the same shape the other backends use. It reports `must contain both 'type' ... and 'details'` otherwise. Azure's own rules for secret names (hyphens allowed, underscores not) come from Azure, not from Bruin: UNVERIFIED against Bruin. Test with a throwaway vault and a non-production connection before relying on it. Check `bruin run --help` and the help of the other commands you use to see which of them accept `--secrets-backend`.

Decision exercise: pick one approach for each of these and justify it in two lines.

- A developer laptop running `bruin run --environment dev`.
- A scheduled job on a Windows server.
- A CI job that runs `bruin validate` on a pull request (does it need real credentials at all? see Module 11).

## 10.7 Lab: concurrency limits you can see

Build four independent assets that each sleep five seconds:

```bash
mkdir -p concurrency_lab/assets
cat > concurrency_lab/pipeline.yml <<'EOF'
name: concurrency_lab
default_connections:
  postgres: "lakota-pg"
EOF
for i in 1 2 3 4; do
cat > concurrency_lab/assets/sleep_$i.sql <<EOF
/* @bruin
name: ops.sleep_$i
type: pg.sql
@bruin */

select pg_sleep(5)
EOF
done
bruin validate concurrency_lab
```

Time the runs (the `time` keyword works in Git Bash):

```bash
time bruin run concurrency_lab --workers 4
time bruin run concurrency_lab --workers 1
```

Expected: about 5 seconds with four workers, about 20 with one. Plus overhead for process start. Now add `max_concurrent_assets: 2` to the `lakota-pg` connection in `.bruin.yml` and run with `--workers 4` again. Expected: about 10 seconds. Try `max_concurrent_assets: 1`. The docs say the lower of the two limits wins.

Record the timings. Then think about what this means for your real work: a Snowflake warehouse or a Netezza host with a small workload-management queue, and a source database that cannot take more than a couple of readers. Which connection would you cap, and how does the ingestr rule (an ingestr asset counts against both its source and destination connections) change the numbers?

Remove the limit and delete the lab pipeline when finished.

## 10.8 Lab: protecting production

### Production prompt

`bruin run --force` is documented as "do not ask for confirmation in a production environment". The docs do not say how an environment is recognised as production. The v0.11.773 source does (`isProductionEnvironment` in `cmd/helpers.go`): an environment is production when its lowercased name contains the text `prod`. `prod`, `production`, `eu-prod` and `PROD2` match. `prd`, `live` and `main` do not. The check applies only when you pass `--environment` on the command line. A `default_environment` in `.bruin.yml` bypasses it, so never make your production environment the default. `--force` and `--only checks` skip the prompt. Confirm each of these:

```bash
bruin environments clone --source default --target production
bruin environments clone --source default --target prod
bruin environments clone --source default --target prd
```

Point each clone's `lakota-pg` at `bruin_course_dev` first so that a mistaken run can only touch the dev database. Then run a harmless asset in each (the `ddl` asset is a no-op after the first run):

```bash
bruin run lakota/assets/ctl/run_audit.sql --environment production
bruin run lakota/assets/ctl/run_audit.sql --environment prod
bruin run lakota/assets/ctl/run_audit.sql --environment prd
```

Answer `no` to any confirmation. Record which names produce a prompt (expect `production` and `prod`, not `prd`). Then test `--force` on the one that prompts. A scheduled job has no terminal to answer the prompt, so a job that targets a `prod`-named environment needs `--force`, and `bruin backfill` in such an environment refuses to start without it (`cmd/backfill.go`). What a prompt does under a scheduler with no TTY is UNVERIFIED, so do not rely on it. Is it acceptable to pass `--force` from a scheduler, and what compensating controls do you want (separate credentials, `full_refresh_restricted`, code review)? If the bank names its production environment `prd`, no prompt exists at all, so name it to contain `prod` or enforce the control in your wrapper.

Run-time confirmation (Bruin v0.11.773, Postgres): an environment named `prod` prompts and `--force` suppresses the prompt (verified by the course author's reviewer). The substring rule for other names is source-derived and not yet confirmed at run time. Test the names your own environments use before relying on the prompt as a safety control, and record the result.

### Environment-wide full refresh protection

`clone` did not copy the `config` block, and `bruin environments update` has no flag for it (it takes only a new name and a schema prefix), so this is a hand edit documented in `assets/materialization.md`. In `.bruin.yml`, add to the `production` environment:

```yaml
    config:
      full_refresh_restricted: true
```

Run a full refresh against that environment on an asset that would lose history (use the SCD2 asset from Module 8, with the table existing in the dev database that the `production` clone points to):

```bash
bruin run lakota/assets/hist/accounts_hist.sql --environment production --full-refresh --force --start-date 2026-01-04 --end-date "2026-01-04 23:59:59.999999"
```

Expected: the table is not dropped and a warning is printed. Compare with the same command against `dev`. The docs say the restriction takes precedence over `--full-refresh` and `parameters.full_refresh`.

Delete the three clones you do not need before moving on.

## 10.9 What stays out of the environment

Environments change connections, schema prefixes and the restriction above. They do not change pipeline variables. To vary behavior per environment, use `--var`, variants (Module 7), or `BRUIN_VARS` set by the scheduler. Decide which of these you will use to pass "this is a dev run" to an asset, and write the YAML or command you would use.

## Break/fix

1. Reference an environment that does not exist: `bruin run lakota --environment nope`.
2. Name a connection differently in `dev` than in `default` (for example `lakota-pg-dev`) and run in `dev`.
3. Put a literal `$` or `${` in a password.
4. Set `max_concurrent_assets: 0`.
5. Give two environments the same `schema_prefix` and run the same pipeline in both.
6. Run a prefixed environment with `--tag landing` first and then `--exclude-tag landing`, and compare to the opposite order.
7. Leave a secrets backend variable out (for example `BRUIN_DOPPLER_TOKEN`) and run with `--secrets-backend doppler`.

<details>
<summary>Answers</summary>

1. An error that names the missing environment. Record the wording.
2. The pipeline asks for `lakota-pg`, which does not exist in `dev`. The run fails with a missing connection error. Connection names must match across environments.
3. Record what happens with `${` in a password (the expansion syntax can collide). Use a variable for the whole password instead.
4. The docs say the value must be a positive integer. Expect a validation or startup error.
5. They write into the same schemas, so two people's runs collide. Prefixes must be unique per developer.
6. In the first order the later layers read the prefixed landing tables. In the second they read the shared, unprefixed ones, and landing then fills the prefixed schema. The result tables differ.
7. The unset reference stays as literal text and is passed as the password, so expect an authentication failure naming the user, not a missing-variable message (source-derived). Record the message.
</details>

## Check questions

1. Why must connection names be the same in every environment?
2. When would you choose `schema_prefix` over a separate database, and what is the main risk?
3. How do you give a CI job its Bruin configuration without a `.bruin.yml` in the repository?
4. A production run is started by a scheduler. What stops it from asking for confirmation, and what protects tables that must never be rebuilt?
5. What is the difference between `--workers 4` and `max_concurrent_assets: 2`?
6. Where do you set `full_refresh_restricted` to cover every asset in an environment?
7. What are the three ways Bruin can obtain connection credentials in this module?

<details>
<summary>Answers</summary>

1. Assets and `pipeline.yml` refer to connections by name. An environment swaps what that name points at.
2. When a replica database is impractical (too much data, cross-database queries not possible). The risk is mixing prefixed and unprefixed sources, and collisions between developers sharing a prefix.
3. Put the file's contents in `BRUIN_CONFIG_FILE_CONTENT`, which takes precedence over the file. Keep real secrets in `${VAR}` references or an external backend.
4. `--force` (or `--only checks`) skips the confirmation, which exists only when the environment name contains `prod` and was passed with `--environment`. `bruin backfill` in such an environment requires `--force`. `full_refresh_restricted: true` at asset or environment level protects tables from `--full-refresh`.
5. `--workers` is the total number of assets running at once. `max_concurrent_assets` caps assets using one named connection. The lower limit wins.
6. In `.bruin.yml` under `environments.<name>.config.full_refresh_restricted`.
7. The `.bruin.yml` file (with `${VAR}` expansion), `BRUIN_CONFIG_FILE_CONTENT`, and an external backend selected with `--secrets-backend` or `BRUIN_SECRETS_BACKEND` (`vault`, `doppler`, `aws`, `azure`).
</details>

## Answers to 10.1

1. The pipeline code and connection names stay identical. The connection details, `schema_prefix` and `config` change per environment.
2. Assets are named `<schema>.<table>`, so the same asset in a different environment would collide unless the environment is a different database. `schema_prefix` rewrites schema names and query references to a prefixed copy.
3. It analyzes the query for referenced tables, lists the schemas and tables in the database, and rewrites a reference only if the prefixed table exists.
4. When Bruin loads the file, on every command. An unset variable stays as literal text. Because commands that edit the file write the expanded values back, run them with the variable unset and check the file afterwards.
5. `vault`, `doppler`, `aws`, `azure`. Secrets are JSON with `type` and `details` objects, named by connection name (Vault via a path convention).
6. `--workers` limits total concurrent assets (default 16). `max_concurrent_assets` limits assets using one named connection. The docs say the lower effective limit wins.
7. At asset level it keeps the asset on its normal strategy during `--full-refresh` and prints a warning. At environment level (`config.full_refresh_restricted`) it applies to every asset.

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| 10.2 clone and edit `dev`, run in separate database | | |
| 10.2 `connections delete` and `add` for the dev copy, and what `.bruin.yml` looks like | | |
| 10.2 `query` with `--env` and `--connection` | | |
| 10.3 schema prefix: schemas and tables created | | |
| 10.3 prefixed read rewrite before and after landing | | |
| 10.3 seeds, ingestr, Python under a prefix | | |
| 10.4 `${VAR}` works; missing variable failure (literal text as password?) | | |
| 10.4 write-back hazard: plain password in `.bruin.yml` after `environments clone` with the variable set | | |
| 10.4 `BRUIN_CONFIG_FILE_CONTENT` without the file | | |
| 10.4 no credentials in logs or git history | | |
| 10.5 `secrets:` and `inject_as`; SQL cannot see secrets | | |
| 10.6 backend table and secrets drafted | | |
| 10.7 timings: 4 workers / 1 worker / limit 2 / limit 1 | | |
| 10.8 which environment names prompt for confirmation (`prod` verified by the author's reviewer; confirm `production` prompts and `prd` does not) | | |
| 10.8 `--force` suppresses the prompt (verified for `prod`) and environment-level restriction | | |
| Time taken | | |
