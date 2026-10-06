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

Clone the default environment, then edit the copy:

```bash
cd ~/lakota-bruin
bruin environments list
bruin environments clone --source default --target dev
```

In `.bruin.yml`, under `environments.dev`, change the `database` of `lakota-pg` to `bruin_course_dev`. Leave `lakota-src` alone: both environments read the same source system.

```bash
bruin connections list --environment dev
bruin connections test --name lakota-pg --env dev
```

Check that the dev connection points where you intend (a quick way: `bruin query --connection lakota-pg --environment dev --query "select current_database()"`, UNVERIFIED that `query` accepts `--environment` together with `--connection`; if not, use `--env`).

Build the pipeline in dev with a small window, leaving the default environment untouched:

```bash
bruin run lakota --environment dev --tag landing --start-date 2000-01-01 --end-date 2026-01-02
bruin run lakota --environment dev --exclude-tag landing --full-refresh --start-date 2026-01-01 --end-date 2026-01-02
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
bruin environments create --name dev_jane --schema-prefix jane_
```

Edit `.bruin.yml` and add under `environments.dev_jane.connections.postgres` the two connections `lakota-pg` (database `bruin_course`) and `lakota-src`, copied from `default`. UNVERIFIED: whether `environments create` adds any connections. Check with `bruin connections list --environment dev_jane`.

Run only the downstream layers first, with landing left alone:

```bash
bruin run lakota --environment dev_jane --exclude-tag landing --full-refresh --start-date 2026-01-01 --end-date 2026-01-04
psql "$PGURL" -c "select table_schema, table_name from information_schema.tables where table_schema like 'jane%' order by 1, 2"
```

The docs say an asset named `mart.customers` becomes `jane_mart.customers`. Record:

- Which schemas appeared, and which tables landed in each?
- `jane_landing` does not exist. Where did `staging.customers` read its data from? Compare the rendered SQL: `bruin render lakota/assets/staging/customers.sql --environment dev_jane`. The docs say Bruin rewrites a table reference to the prefixed schema only if the prefixed table exists.
- Now load landing in this environment (`--tag landing`) and render the same asset again. What changed? This is the property that makes schema prefixes both useful (read production-like data, write privately) and risky (a partially prefixed set of tables can mix sources).
- Did seeds, ingestr assets and the Python assets put their output in prefixed schemas? UNVERIFIED for each type.
- Did the marker row from Module 9 land in `jane_ctl.pipeline_status`?

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

Environment variables are expanded at runtime, not when the file is parsed.

```bash
export LAKOTA_PW='choose-a-simple-password'
```

In `.bruin.yml`, change the password of `lakota-pg` and `lakota-src` in `default` to `${LAKOTA_PW}`, then:

```bash
bruin connections test --name lakota-pg
unset LAKOTA_PW
bruin connections test --name lakota-pg
```

Record the exact failure when the variable is missing (an empty password, a clear message, or a confusing database error). Put the variable back afterwards. On Windows, note where you set it so that scheduled tasks can see it: a variable exported in an interactive Git Bash session is not visible to Task Scheduler. Record what you decided (a user environment variable in Windows settings, or a file the wrapper sources).

### Config supplied through the environment

CI systems usually do not have a `.bruin.yml`. The docs say `BRUIN_CONFIG_FILE_CONTENT` takes precedence over the file:

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

The docs say `--mask-credentials` is on by default and redacts credential values in run logs. Confirm that no log contains the password. Also check `git status` and `git log -p -S "choose-a-simple-password"` in your repository to make sure the password never entered a commit.

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
| Variables Bruin needs | | | | UNVERIFIED, no page in this docs snapshot |
| Where each connection's secret lives | | | | |
| Secret value format | | | | |
| How Bruin authenticates | | | | |

Then write, for `lakota-pg`, the exact secret you would store in each backend (JSON with `type` and `details`). Check your answer against the Postgres example in the docs. Which connection fields would you leave out of the secret, and why?

Your platform is Azure. The docs list `azure` as a value of `--secrets-backend` but this snapshot of the docs has no page for it, so the variable names and secret layout are unknown. Before relying on it, check the current docs and test with a throwaway vault and a non-production connection.

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

`bruin run --force` is documented as "do not ask for confirmation in a production environment". The docs do not say how an environment is recognised as production. Find out by testing:

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

Answer `no` to any confirmation. Record which names produce a prompt. Then test `--force` on the one that prompts. For a scheduled job, which flag do you pass? Is it acceptable to pass `--force` from a scheduler, and what compensating controls do you want (separate credentials, `full_refresh_restricted`, code review)?

Result from the course author's reviewer (Bruin v0.11.773, Postgres): an environment named `prod` is treated as production. Running against it asks for confirmation, and `--force` suppresses the prompt. VERIFIED for `prod` only. `production` and `prd` have not been reported, so the rule behind the name check (exact names, a substring such as "prod", or something else) is still UNVERIFIED. Test the names your own environments use before relying on the prompt as a safety control, and record the result.

### Environment-wide full refresh protection

In `.bruin.yml`, add to the `production` environment:

```yaml
    config:
      full_refresh_restricted: true
```

Run a full refresh against that environment on an asset that would lose history (use the SCD2 asset from Module 8, with the table existing in the dev database that the `production` clone points to):

```bash
bruin run lakota/assets/hist/accounts_hist.sql --environment production --full-refresh --force --start-date 2026-01-04 --end-date 2026-01-04
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
7. A clear error about a missing variable, or an authentication failure. Record which.
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
4. `--force` skips the confirmation. `full_refresh_restricted: true` at asset or environment level protects tables from `--full-refresh`.
5. `--workers` is the total number of assets running at once. `max_concurrent_assets` caps assets using one named connection. The lower limit wins.
6. In `.bruin.yml` under `environments.<name>.config.full_refresh_restricted`.
7. The `.bruin.yml` file (with `${VAR}` expansion), `BRUIN_CONFIG_FILE_CONTENT`, and an external backend selected with `--secrets-backend` or `BRUIN_SECRETS_BACKEND`.
</details>

## Answers to 10.1

1. The pipeline code and connection names stay identical. The connection details, `schema_prefix` and `config` change per environment.
2. Assets are named `<schema>.<table>`, so the same asset in a different environment would collide unless the environment is a different database. `schema_prefix` rewrites schema names and query references to a prefixed copy.
3. It analyzes the query for referenced tables, lists the schemas and tables in the database, and rewrites a reference only if the prefixed table exists.
4. At runtime, not when the file is parsed.
5. `vault`, `doppler`, `aws`, `azure`. Secrets are JSON with `type` and `details` objects, named by connection name (Vault via a path convention).
6. `--workers` limits total concurrent assets (default 16). `max_concurrent_assets` limits assets using one named connection. The docs say the lower effective limit wins.
7. At asset level it keeps the asset on its normal strategy during `--full-refresh` and prints a warning. At environment level (`config.full_refresh_restricted`) it applies to every asset.

## Validation log

| Step | Pass / fail | What actually happened |
|---|---|---|
| 10.2 clone and edit `dev`, run in separate database | | |
| 10.2 `query` with `--environment` | | |
| 10.3 schema prefix: schemas and tables created | | |
| 10.3 prefixed read rewrite before and after landing | | |
| 10.3 seeds, ingestr, Python under a prefix | | |
| 10.4 `${VAR}` works; missing variable failure | | |
| 10.4 `BRUIN_CONFIG_FILE_CONTENT` without the file | | |
| 10.4 no credentials in logs or git history | | |
| 10.5 `secrets:` and `inject_as`; SQL cannot see secrets | | |
| 10.6 backend table and secrets drafted | | |
| 10.7 timings: 4 workers / 1 worker / limit 2 / limit 1 | | |
| 10.8 which environment names prompt for confirmation (`prod` prompts, verified by the author's reviewer; test `production`, `prd` and your own names) | | |
| 10.8 `--force` suppresses the prompt (verified for `prod`) and environment-level restriction | | |
| Time taken | | |
