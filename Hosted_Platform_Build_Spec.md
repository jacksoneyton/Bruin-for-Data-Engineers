# Hosted Platform Build Spec

Specification for building the paid, browser-based learning platform that delivers "Bruin for Data Engineers" (`Course_Curriculum_Outline.md` v3.0). Written for Claude Code. Version 1.0, 2026-10-05.

This document is a build specification. It does not describe the course content. Course content, lessons, labs, and self-checks are built from `Course_Build_Prompt_Guide.md`. This spec describes the platform that runs them.

Glossary used throughout:

- **MVP (minimum viable product):** the smallest first release that still delivers the core experience to real paying learners.
- **Workspace:** one learner's private, persistent Linux environment, opened in a browser.
- **Host:** a rented bare-metal server that runs many workspaces.
- **Control plane:** the web service that handles accounts, payments, progress, and workspace lifecycle.
- **Agent:** a small program inside each workspace that runs checks, resets steps, and reports state.
- **Check:** the automated verification of a learner's step, run by a course-provided script.

---

## 1. Product Definition

### 1.1 What is being built

A low-priced paid course delivered entirely in a browser. A learner signs in, pays, and opens a hosted VS Code workspace beside a lesson pane. The workspace contains everything the course needs: Bruin, uv, Git, Postgres, DuckDB, SQLite, a deterministic Source Simulator, a mock API, and the self-check scripts. Progress is recorded server-side. There is no local install option.

### 1.2 Decisions already made by the course author

| Decision | Value |
|----------|-------|
| Delivery | Hosted only. No local or self-install path. |
| Business model | Paid, inexpensive. Exact price and model are open (section 21). |
| Hosting | Self-hosted on rented bare-metal servers (the "middle option"), not on a managed sandbox vendor and not on a home network. |
| Editor | VS Code in the browser. |
| Primary warehouse | Postgres. DuckDB for first-run exercises. SQLite as a source. |
| Snowflake | Not required anywhere. Module 13 is an optional cloud-warehouse porting module that needs no account. |
| Learner-visible containers | None. Learners never see or need Docker. Server-side isolation technology is the operator's choice. |
| First layout | Side-by-side lesson site and editor for the MVP. A VS Code course-runner extension is the v1 target. |

### 1.3 Non-goals for the MVP

Cohort mode, certificates, bring-your-own cloud account labs, multi-language UI, mobile editing, team or enterprise accounts, instructor dashboards, and any marketplace of third-party courses.

### 1.4 Competitive context

Bruin Data Limited publishes Bruin Academy, which currently lists dozens of free guides and courses, including a data-engineer track (https://getbruin.com/learn/, retrieved 2026-10-05). The paid course therefore competes with free official material. Its differentiators are depth (a 53-hour enterprise project), a ready-to-use environment with no setup, automated verification, custom Python sensors, recovery and replay drills, and support. The marketing site must state these differences honestly and must not imply affiliation with Bruin.

---

## 2. Findings That Shape the Design

Verified items cite a source retrieved 2026-10-05. Everything else is inference or estimate and is labeled.

| Topic | Finding | Source or status |
|-------|---------|------------------|
| Bruin license | Apache-2.0. Hosting it for training and bundling it in an image are permitted with the license text retained. | https://github.com/bruin-data/bruin/blob/main/LICENSE.md |
| ingestr license | FSL-1.1-ALv2. Permitted uses include education and professional services. It prohibits use to offer a competing commercial ingestion or managed pipeline service. A paid course should obtain written confirmation from Bruin Data Limited. | https://github.com/bruin-data/ingestr |
| Bruin Python execution | Python assets run in isolated uv-managed environments. | https://bruin-data.github.io/bruin/assets/python.html |
| Bruin on Postgres | Connection fields, `pg.sql`, `pg.seed`, `pg.sensor.table`, `pg.sensor.query`, `pg.source`. Sensors poll every 30 seconds by default. | https://bruin-data.github.io/bruin/platforms/postgres.html |
| DuckDB concurrency | Bruin's docs state DuckDB does not allow concurrency between processes. This is why Postgres is the platform warehouse. | https://bruin-data.github.io/bruin/platforms/duckdb.html |
| Bruin VS Code extension | Installed from the VS Code Marketplace per Bruin's install guide. Availability in an open-source hosted editor's registry is unverified. | https://getbruin.com/learn/install-bruin/install-extension |
| code-server | MIT-licensed browser VS Code. Marketplace, telemetry, reverse-proxy, and iframe behavior need verification in the spike. | https://github.com/coder/code-server |
| Incus | Manages system containers and VMs, has a REST API, ZFS and other storage drivers, snapshots, resource limits through profiles, projects, and network ACLs. The docs warn that local socket access grants full control, so access must be tightly restricted. | https://linuxcontainers.org/incus/docs/main/ |
| Postgres template cloning | `CREATE DATABASE ... TEMPLATE` copies a database but fails if any other session is connected to the template. Database-level grants are not copied. | https://www.postgresql.org/docs/current/manage-ag-templatedbs.html |
| Bruin release cadence | Very frequent (about 80 releases in two months, per third-party trackers). Pin versions and upgrade on a schedule. | https://pkg.go.dev/github.com/bruin-data/bruin ; third-party tracker, medium confidence |
| Hosting prices | One provider's reported price increases in April and June 2026 mean any price memorized from before then is stale. Re-check at purchase time. | Reports retrieved 2026-10-05, not primary sources |
| Terminal accessibility | xterm.js builds its accessible DOM only in screen-reader mode, which is off by default. VS Code's own terminal exposes a screen-reader setting that must be tested. | https://github.com/xtermjs/xterm.js/issues/6185 |
| Microsoft-branded VS Code server | Likely has licensing terms that restrict hosting it as a service. Use an open-source server (code-server or OpenVSCode Server). | Prior knowledge, not verified. Confirm before launch. |

---

## 3. Architecture

```text
                      Internet
                         |
                 Traefik (TLS, WebSockets)
        +----------------+-------------------+
        |                |                   |
  Static site       Control plane API    Workspace gateway
  (Starlight)       (accounts, billing,  (auth check, routes
  lessons, docs     progress, lifecycle)  to workspace by ID)
                         |                   |
                  Control DB (Postgres)       |
                         |                   |
                         +------ Host agent -+  (one per host)
                                    |
                                Incus API (local only)
                                    |
              +---------------------+---------------------+
              |                     |                     |
        Workspace A           Workspace B            Workspace N
        (VM or container)     ...                    ...
        - code-server
        - learner Postgres
        - DuckDB, SQLite
        - simulator, mock API, scheduler harness
        - workspace agent
        - Bruin, uv, Git
```

### 3.1 Components

| Component | Responsibility | Recommended technology |
|-----------|----------------|------------------------|
| Marketing and lesson site | Public pages, pricing, rendered lessons, free preview | Starlight (Astro), static, hosted on a CDN or the same host |
| Control plane API | Auth, entitlements, billing webhooks, progress, workspace lifecycle, admin | TypeScript (Node.js) with a typed HTTP framework and Postgres migrations. Go is an acceptable alternative. |
| Control database | Platform data. Separate from any learner Postgres. | Postgres, with automated backups |
| Gateway | Terminates TLS, authenticates the browser session, routes `ws-<id>` requests to the right workspace, supports WebSockets | Traefik with ForwardAuth to the control plane |
| Host agent | Runs on each host, talks to the local Incus API, creates, starts, stops, snapshots, resets, and deletes workspaces | Go, static binary |
| Workspace image | Everything inside a workspace | Debian or Ubuntu LTS image built by script, versioned, with pinned tool versions |
| Workspace agent | Inside each workspace. Runs checks, resets, snapshots the learner database, reports health and idle state | Go, static binary |
| Course runner (v1) | VS Code extension for lessons, Check, Hint, Reset, Next inside the editor | TypeScript VS Code extension |
| Object storage | Backups, workspace snapshots, exports | Any S3-compatible storage |
| Observability | Metrics, logs, uptime, alerts | Prometheus, Grafana, Loki, plus an external uptime monitor |

Rationale for the split: the control plane never runs learner code. The only components that touch learner code are the workspace and its agent, which sit behind the isolation boundary in section 5.

### 3.2 Isolation decision (resolve in the spike)

Learners can run arbitrary commands, so the isolation boundary is the most important security decision.

| Option | Strength | Cost | Notes |
|--------|----------|------|-------|
| Incus VM (QEMU and KVM) per workspace | Strongest. Separate kernel. | Higher RAM overhead per workspace, slower start | Requires KVM on the host, which bare metal provides |
| Incus system container, unprivileged, with default confinement | Light, fast start, high density | Shares the host kernel, so a kernel or runtime escape reaches the host | Acceptable only if density requires it and the host holds nothing else of value |
| Container plus a user-space kernel sandbox | Stronger than plain containers | Operational complexity, compatibility gaps | Not built into Incus. Only evaluate if VMs prove too heavy |

Default recommendation: Incus VMs. The spike measures idle memory, start and resume time, and density on the chosen host. If VMs meet the targets in section 17, use VMs. If they do not, document the density gain and the escape risk, and decide explicitly.

Targets to meet or document as missed: resume of a stopped workspace in 30 seconds or less, first-ever start from a warm pool in 20 seconds or less, idle memory per workspace documented, at least 20 simultaneous workspaces per 128 GB host at the recommended size (an estimate to confirm).

### 3.3 Workspace sizing (initial planning values, to be load-tested)

Per active workspace: 2 vCPU, 4 GiB RAM limit, 10 to 20 GiB disk quota. Memory overcommit and auto-stop on idle are expected. Idle workspaces are stopped, so resident memory tracks active sessions.

---

## 4. Workspace Image

### 4.1 Contents (all pinned in `image/versions.lock`)

- Base OS (LTS), systemd.
- Non-root `learner` user with no sudo. A documented, tightly scoped escape hatch exists only inside lab steps that need it.
- Bruin CLI at the pinned version, uv, and a pre-populated uv cache with the Python versions and wheels the course uses, so labs need no internet.
- Git, Make, jq, curl, a DuckDB CLI, the SQLite CLI, `psql`.
- Postgres at a pinned major version, running as a service inside the workspace, bound to localhost. Databases and roles created at provisioning: `src_core_banking`, `src_crm`, `wh_dev`, `wh_staging`, `wh_prod`, plus layer roles.
- Source Simulator, mock API service, and scheduler harness from the course repository, as services or commands.
- code-server (or OpenVSCode Server), with telemetry disabled, bound to localhost only, authentication handled by the gateway, and extensions preinstalled from a vetted list.
- The Bruin VS Code extension, if it can be installed (spike item).
- The workspace agent.
- The course repository checked out at the starter tag for module 0, with a local bare `origin`.

### 4.2 Build and release

- Image recipe lives in `image/` and builds reproducibly in CI.
- Every image build runs the course's full verification suite (section 9.4) against every module's solution tag before the image can be promoted.
- Image versions are immutable and tagged. A workspace records the image version it was created from. Upgrades happen at module boundaries or on explicit learner request, never mid-lab.
- Bruin and uv versions upgrade on a schedule (monthly or quarterly), not on each upstream release.

---

## 5. Networking and Security

### 5.1 Threat model

Assume any learner may try to: escape the workspace; reach other workspaces, the host, or the control plane; use the workspace for crypto-mining, scanning, spam, or attacks; exhaust CPU, memory, disk, or processes; steal other learners' data; abuse billing (sharing accounts, scraping course content).

### 5.2 Controls (all required for launch)

| Area | Control |
|------|---------|
| Isolation | Section 3.2 decision. Non-root user inside the workspace. |
| Host | Dedicated hosts. Nothing else of value runs on them. Management interfaces on a private network. SSH key only. Automatic security updates. |
| Incus access | The Incus API is reachable only by the host agent on that host. The control plane talks to the host agent, never directly to Incus. |
| Workspace network | Each workspace on an isolated bridge with no route to other workspaces, the host, or management networks. |
| Egress | Default deny. Allow only through an allowlisting proxy or Incus network ACLs. Initial allowlist: the package mirror (if any), the course control plane, and nothing else. Optional labs add specific hosts per learner entitlement (for example `github.com` for the optional CI lab). No outbound SMTP. |
| Ingress | Workspaces accept traffic only from the gateway. Code-server and agent ports are not exposed publicly. |
| Authentication to a workspace | The gateway validates the learner's session and workspace ownership on every request and WebSocket upgrade. Workspace URLs are unguessable and also gated by that check. |
| Agent authentication | The workspace agent and host agent authenticate to the control plane with short-lived signed tokens or mutual TLS. Learners cannot call privileged agent endpoints. |
| Resource limits | CPU, memory, disk quota, process count, and open file limits per workspace. Fork bomb, disk fill, and sustained CPU burn tests must not affect other workspaces. |
| Abuse detection | Sustained 100 percent CPU beyond a threshold flags the workspace. Outbound connection attempts to blocked destinations are logged and counted. Automatic stop and manual review above thresholds. |
| Session limits | One running workspace per learner. Idle timeout (default 15 minutes). Hard session maximum (default 4 hours). Monthly hour cap (default decided in section 21). |
| Secrets | Control plane secrets in a secrets manager or encrypted environment, never in the image or repository. No learner secrets are stored by the platform. |
| Content protection | Solution files are not present in the workspace until the learner requests them through the platform. |
| Transport and headers | TLS everywhere, HSTS, strict cookie flags, CSP. `frame-ancestors` configured for the MVP side-by-side layout. |
| Logging | Platform logs, lifecycle events, and check results. Never log terminal or editor content. |
| Backups | Encrypted, tested restores (section 14). |
| Patching | Host and image patch cadence documented, with a security-update path that bypasses the normal image schedule. |

### 5.3 Required security tests (automated where possible)

1. From workspace A, scan every address on the workspace network and the host: nothing reachable except the gateway.
2. From a workspace, request a blocked external host and a blocked port: refused, and the attempt is logged.
3. Fork bomb, disk fill, memory exhaustion, and a CPU burn inside one workspace: other workspaces remain responsive, and the abusive workspace is limited or stopped.
4. Attempt to read another learner's workspace URL with a different valid session: denied.
5. Attempt to call agent endpoints from inside a workspace: denied.
6. Replay an expired token: denied.

---

## 6. Course Content Contract

The platform consumes the course repository. The course repository must not change shape without updating this contract.

### 6.1 Module manifest (`modules/NN-title/manifest.yaml`)

```yaml
module: 11
title: "Sensors, Custom Python Sensors, and Data-State Dependencies"
estimated_minutes: 300
free_preview: false
requires_egress: []            # extra hosts allowed for this module, if any
steps:
  - id: m11-s03
    title: "Build a file-arrival sensor"
    lesson: "lesson.md#file-arrival-sensor"
    estimated_minutes: 25
    starter_ref: "module-11-s03-starter"      # git tag
    solution_ref: "module-11-s03-solution"
    reset:
      git_ref: "module-11-s03-starter"
      database_template: "wh_dev_m11_s03"     # template database for instant reset
      simulator_state: "day-12-vendor-feed-late"
    check:
      command: "./modules/11-sensors/checks/s03.sh"
      timeout_seconds: 120
    hints:
      - "Check which condition your sensor evaluates first."
      - "A file that exists can still be half written."
      - "Look at lib/sensors.py for the stability condition."
```

### 6.2 Check output

Every check exits 0 on pass and non-zero on failure, and prints one JSON object per line:

```json
{"criterion":"sensor_has_timeout","status":"pass","message":"timeout is 600 seconds"}
{"criterion":"sensor_checks_business_date","status":"fail","message":"The sensor passed on yesterday's file. Add a business date condition."}
{"summary":"1 of 2 criteria passed","exit":1}
```

The platform stores the lines, shows them as text, and never trusts a browser-reported result.

### 6.3 Image recipe contract

The course repository provides `environment/` with the lists and scripts that define the workspace's course-specific parts (simulator, mock API, scheduler harness, database seed, template database builder, version pins). The platform's image build pulls a course repository tag and builds from it.

### 6.4 Validation

A command `platform-validate-content` loads every manifest, checks that referenced tags, files, and scripts exist, runs each module's solution check against its solution tag, and runs each starter check against its starter tag expecting failure. CI runs this on every course change.

---

## 7. Workspace Lifecycle

```text
none -> provisioning -> stopped <-> starting -> running -> stopping -> stopped
                                         \-> resetting -> running
running -> snapshotting -> running
stopped -> deleted
```

| Event | Behavior |
|-------|----------|
| Create | Clone from the golden image (copy-on-write), run first-boot provisioning (databases, roles, repository, simulator seed), record the image version. A warm pool of pre-cloned stopped workspaces reduces first-start time. |
| Start or resume | Check entitlement and monthly hours, check host capacity, start the workspace, wait for agent health, return the workspace URL. If no capacity, queue the learner and show position and expected wait. |
| Idle stop | The agent reports no editor or terminal activity and low CPU for the idle period. The control plane stops the workspace and snapshots its storage. |
| Hard stop | Session maximum or monthly cap reached. A warning is sent five minutes before. |
| Reset step | Save the learner's current work to a branch named `learner/<step>-<timestamp>`. Check out the step's starter tag. Restore the learner database from the step's template, which requires terminating other sessions on the database first (the Postgres docs say template cloning fails with other sessions connected). Set the simulator clock and state. Restart services. |
| Snapshot | Storage snapshot before any destructive operation and daily for active learners. Keep a short rolling window. |
| Export | Produce a Git bundle plus database dumps, store them temporarily in object storage, and give the learner a time-limited download link. |
| Delete | After an inactivity period (default 90 days, published), warn by email, then delete the workspace and its snapshots. Learners can export first. Account deletion deletes immediately on request. |
| Failure | If a workspace fails health checks, restart once, then restore from the last snapshot, then alert an operator. |

Learner-visible state must always be one of: Starting, Running, Stopping, Stopped, Resetting, Needs attention, with a plain-text explanation.

---

## 8. Frontend

### 8.1 MVP layout: side by side

- Left pane: the lesson, rendered from the course repository's Markdown for the current step, with step navigation.
- Right pane: the workspace's code-server in an iframe on a subdomain controlled by the platform, behind the gateway.
- Top bar: current module and step, Check, Hint, Show solution, Reset step, Next, Save and exit, workspace status, hours remaining.
- Check runs the step's check through the control plane, which calls the workspace agent. Results appear in an accessible results panel in the left pane as text, with `role="status"` updates.
- The platform's own pages must work with a keyboard only and with a screen reader.

Known risk: iframe embedding of code-server requires the server and gateway headers to allow framing from the platform's origin, and browsers restrict third-party cookies in iframes. Use a same-site subdomain arrangement (for example `app.example.com` and `ws-<id>.example.com`) and verify in the spike. If it fails in any major browser, fall back to a top-level code-server page with the lesson in a second window or a VS Code webview (section 8.2).

### 8.2 v1 target: course runner extension

A VS Code extension, installed in every workspace, providing:

- A lesson view (webview) for the current step with Markdown rendering and code copy buttons.
- Commands: Check, Hint, Show solution, Reset step, Next step, Open lesson, Show progress. All keyboard accessible, all in the command palette.
- A status bar item with the step and last check result.
- A Problems-panel-style list of failed criteria linked to files where possible.
- Communication with the workspace agent over a local socket. The agent talks to the control plane.

Because the extension runs inside VS Code, the same experience works regardless of whether the lesson pane is separate or embedded. The side-by-side layout can then become optional.

### 8.3 Accounts and dashboard pages

Sign in, account, billing portal link, my progress, my workspace (status, start, stop, reset, export, delete), help, accessibility settings (terminal screen-reader mode, font size, contrast, reduced motion).

### 8.4 Accessibility requirements (WCAG 2.2 AA target)

- Every control keyboard operable with visible focus, skip links, logical focus order, and no keyboard traps. Document how to leave the terminal and editor by keyboard.
- Terminal: a user setting turns on VS Code's screen-reader-optimized and terminal accessibility options by default for users who choose them. Provide a non-terminal alternative for every action (a Run button that executes a documented command and writes output to a text log region).
- Check results, errors, and status changes are text with ARIA live regions. Never color alone.
- Contrast, text resizing to 200 percent, reduced motion, dark and light themes.
- Lesson diagrams have text equivalents.
- Test with NVDA, JAWS, and VoiceOver before launch, and publish an accessibility statement with a contact channel.

---

## 9. Accounts, Billing, Progress

### 9.1 Accounts

- Sign in by email magic link. GitHub sign-in is optional. Google is optional.
- Store the minimum: email, display name, identity provider ID, consent records.
- Learners can export and delete their data.

### 9.2 Billing (decisions in section 21)

- Use a hosted checkout and a customer portal. Never handle card data.
- Consider a merchant of record to handle sales tax and VAT, especially for a solo operator. This is a business decision outside this spec, and tax rules should be confirmed with a qualified advisor.
- Entitlements table drives access: an entitlement has a product, start, end, and monthly hour allowance. Webhooks create, extend, and revoke entitlements. Webhooks are verified, idempotent, and replay-safe.
- Free preview: modules 0 and 1 are available without payment, with a smaller hour allowance and a shorter workspace lifetime. This funnels learners and lets them verify the environment works before buying.
- Refund policy stated clearly on the pricing page.

### 9.3 Progress

- Step events are recorded server-side only: started, check run (with result lines), hint used, solution viewed, reset, completed.
- A step is complete when a server-run check passes.
- Show module and course completion, estimated time remaining, and the next step.

### 9.4 Content validation in CI

Before any image or content release, CI runs `platform-validate-content` and a scripted end-to-end run in a fresh workspace: create a workspace, complete every step of a sample module by applying the solution tags, and assert progress is recorded.

---

## 10. Control Plane Data Model (outline)

| Table | Key fields |
|-------|------------|
| `users` | id, email, display_name, created_at, deleted_at |
| `identities` | user_id, provider, provider_user_id |
| `products` | id, name, price reference, hours_per_month, preview flag |
| `entitlements` | id, user_id, product_id, starts_at, ends_at, source (order id) |
| `orders` | id, user_id, provider_order_id, status, amount, currency |
| `workspaces` | id, user_id, host_id, state, image_version, created_at, last_active_at |
| `workspace_events` | workspace_id, type, at, detail |
| `usage_hours` | user_id, month, seconds_used |
| `step_progress` | user_id, step_id, status, first_started_at, completed_at |
| `check_runs` | id, user_id, step_id, at, exit_code, result_lines (jsonb), bruin_version, image_version |
| `hints_used`, `solutions_viewed` | user_id, step_id, at |
| `hosts` | id, address, capacity_ram_gb, capacity_slots, state |
| `audit_log` | at, actor, action, target |
| `consents` | user_id, document, version, at |
| (v1) `certificates`, `cohorts` | defined in the v1 plan |

All timestamps in UTC. Migrations are versioned and tested. Personal data is minimized and listed in the privacy notice.

---

## 11. APIs (outline)

### 11.1 Public (browser to control plane)

Auth (magic link, OAuth callback, session), `GET /me`, `GET /course` (manifest summary), `POST /workspaces/start`, `POST /workspaces/stop`, `POST /workspaces/reset`, `POST /workspaces/export`, `GET /workspaces/status`, `POST /steps/:id/check`, `POST /steps/:id/hint`, `POST /steps/:id/solution`, `GET /progress`, billing portal redirect, account delete.

### 11.2 Internal (control plane to host agent, host agent to Incus)

Create, start, stop, snapshot, restore, reset, delete, list, capacity, health.

### 11.3 Workspace agent (called only by the control plane through the host)

`/health`, `/idle`, `/check`, `/reset`, `/snapshot-db`, `/export`, `/clock`.

All internal calls use mutual TLS or signed short-lived tokens and are rate limited.

---

## 12. Repository Layout (platform monorepo)

```text
platform/
 ├── apps/
 │    ├── site/              (Starlight site, lessons rendered from the course repo)
 │    ├── dashboard/         (account, progress, workspace controls)
 │    └── api/               (control plane)
 ├── agents/
 │    ├── host-agent/        (Go, talks to Incus)
 │    └── workspace-agent/   (Go, runs inside workspaces)
 ├── extension/              (course runner VS Code extension, v1)
 ├── image/                  (workspace image recipe, versions.lock)
 ├── infra/                  (host provisioning: Incus preseed, networking, firewall, proxy, backups)
 ├── tests/
 │    ├── e2e/               (Playwright)
 │    ├── security/          (section 5.3 tests)
 │    └── load/              (synthetic learner driver)
 ├── docs/                   (runbooks, ADRs, accessibility statement, privacy notes)
 └── Makefile
```

Architecture decisions are recorded as short ADRs in `docs/adr/`.

---

## 13. Testing Strategy

| Level | What | Notes |
|-------|------|-------|
| Unit | Control plane logic, entitlement rules, agents | Standard test runners |
| Integration | Control plane to host agent to a real Incus on a test host | Needs a host with KVM. Use a dedicated small test host. |
| End to end | Browser flows: sign up, pay (test mode), start workspace, run a step, Check, Reset, Export | Playwright against staging |
| Content | `platform-validate-content` against every module | Runs on every course change |
| Security | Section 5.3 | Runs before every release and nightly on staging |
| Accessibility | Automated checks plus manual screen reader passes | Before launch and before each major UI change |
| Load | A synthetic driver creates N workspaces, runs scripted check loads, and measures start time, memory, and failures | Determines real per-workspace sizing and host capacity |
| Chaos and recovery | Kill a host agent, kill a workspace, fill a disk, restore a backup | Quarterly and before launch |

---

## 14. Operations

### 14.1 Monitoring and alerts

Host: CPU, memory, disk, ZFS or storage pool health, temperature and SMART data where available, network. Platform: request rate, error rate, latency, webhook failures, queue depth, workspace start time, failures by stage, active workspaces and capacity, idle stop rate, check pass rates per step (a high failure rate points at a broken lab), abuse flags. Alert on: host unreachable, storage nearly full, backup failure, start-time regression, webhook failures, a step with a sudden pass-rate drop.

### 14.2 Backups

Control database: automated daily backups plus point-in-time recovery if available, encrypted, stored off the host. Workspace storage: snapshots as described in section 7, replicated off the host for paid learners. Restore tests monthly and documented.

### 14.3 Runbooks (written before launch)

Host down, storage full, workspace will not start, billing webhook failure, suspected abuse, security incident, restore from backup, image rollback, Bruin upgrade, database migration, emergency stop of all workspaces.

### 14.4 Admin tools

Search a learner, view workspace state and recent events, stop or reset a workspace, grant or revoke hours or entitlement, force an export, view check history for support, flag and review abuse, drain a host for maintenance.

### 14.5 Support

A published support address, a response-time target, a status page, and a template for incident communication.

### 14.6 Capacity

Capacity planning formula: `hosts = ceil(peak_concurrent_workspaces / slots_per_host)` where `slots_per_host` comes from load testing. Peak concurrency is estimated as a multiple of average concurrency, where average concurrency is `monthly_active_learners × hours_per_learner_per_month / 720`. Use measured values after launch.

---

## 15. Legal and Compliance Checklist

This is a checklist for the operator to resolve with qualified advisors, not legal advice.

- Include Apache-2.0 notices for Bruin and other components in the image and on a licenses page.
- Obtain written confirmation from Bruin Data Limited that a paid course running ingestr in learner workspaces is acceptable under FSL-1.1-ALv2. If it is not confirmed, evaluate whether the course can avoid ingestr or use an alternative load path.
- Use "teaches Bruin" or "for Bruin" phrasing. Do not use Bruin's logo. State non-affiliation. I found no published trademark policy for third-party courses, so ask Bruin directly.
- Confirm hosting licenses for the editor server and every preinstalled extension. Do not redistribute extensions from marketplaces whose terms forbid it.
- Terms of service, privacy policy, refund policy, acceptable use policy, cookie notice if needed, and a data processing agreement with the hosting and email providers.
- Data residency decision and retention periods published.
- Sales tax and VAT handling through the billing choice in section 9.2.
- Accessibility statement.
- Copyright and license notice for the course content itself, including what learners may do with their exported work.

---

## 16. Cost Model (formulas, not figures)

Inputs the operator must provide: price per learner, expected share of purchasers who become active in a month, host monthly cost, storage and backup cost, payment fees, merchant-of-record fees if used, email provider cost, domain, monitoring cost.

Variables measured in the load test: RAM per active workspace, idle resident cost, disk per workspace, workspaces per host.

Break-even sketch: `monthly_cost = hosts × host_price + storage + backups + tools + fees`. `required_paying_learners = monthly_cost / (price_per_learner_per_month_equivalent × (1 - fee_rate))`. I did not verify current bare-metal prices because reported price changes in 2026 make older figures unreliable. Collect quotes from at least two providers during Phase 0.

---

## 17. Build Plan

Effort figures are estimates for one developer working with Claude Code and should be revised after Phase 0. They are not commitments.

### Phase 0: Decisions and spikes (1 to 2 weeks)

Deliverables: `docs/adr/` records and a short spike report.

1. Rent one test host with KVM and enough RAM. Install Incus with ZFS storage. Record the exact host spec, price, and provider.
2. Build a minimal workspace image by hand: Debian or Ubuntu, code-server, Postgres, Bruin, uv.
3. Verify the Bruin VS Code extension installs in the chosen editor server, by registry or by a packaged file, and note the licensing.
4. Verify code-server embedded in an iframe on a same-site subdomain behind Traefik with WebSockets, in Chrome, Firefox, and Safari, including cookies.
5. Measure for both VMs and containers: idle RAM, start time from a stopped state, start time from a warm clone, density at 4 GiB limits, disk use of a clone.
6. Prototype the Postgres step reset using a template database, and the alternative of a storage snapshot, and measure each.
7. Prototype egress default deny with an allowlist and run the section 5.3 tests that apply.
8. Pick isolation (section 3.2) and record the ADR.
9. Confirm the course's verification spike results (Prompt Guide Phase A) with the platform's image.

Acceptance: ADRs exist for isolation, editor server, layout, and reset method; all measurements recorded; go or no-go for the MVP.

### Phase 1: MVP (about 6 to 10 weeks)

Scope: one host, free preview plus one paid product, side-by-side layout, manual operations where cheaper than automation.

Deliverables:

- Accounts (magic link), entitlements, checkout and webhook handling, preview versus paid gating.
- Workspace lifecycle: create, start, idle stop, resume, reset step, export, delete, with the state machine in section 7.
- Workspace image with everything in section 4, built in CI.
- Gateway and host agent; workspace agent with check, reset, idle reporting.
- Lesson site from the course repository with the step navigation and the results panel.
- Server-side progress and a basic learner dashboard.
- Security controls in section 5.2 and the tests in section 5.3 passing.
- Backups with a tested restore. Monitoring and alerts for host and platform basics. Runbooks for the highest-risk events.
- Basic admin tools (find user, view workspace, stop or reset, adjust hours).
- Accessibility pass for the platform pages and the workspace layout.

Acceptance criteria:

1. A new learner can sign up, complete the free preview modules, buy, and resume in a new session with their work intact.
2. A scripted run completes every step of two sample modules in fresh workspaces using solution tags, with all checks passing and progress recorded.
3. Reset returns a step to the exact starter state, including database and simulator clock, in under 60 seconds.
4. Security tests 1 to 6 pass. A fork bomb in one workspace does not degrade another.
5. Load test with 2 times the planned launch concurrency shows start times within targets and no failed provisioning.
6. A restore from backup is performed and documented.
7. A screen reader user can sign in, open a workspace, run a check, and read the results.

### Phase 2: v1 (about 3 to 5 months solo, less for a team)

Course runner extension, hints and solution diffs refined, certificates with server-verified completion, cohort mode and scheduled deadlines, second host and host draining, automated capacity alerts, richer admin tools, learner export polish, accessibility audit by an external tester, optional GitHub CI lab with allowlisted egress, per-learner egress allowlists as entitlements, status page, cost dashboards.

### Phase 3: later

Bring-your-own cloud account lab with secure key handling, additional course tracks, translations, institutional accounts, referral or affiliate features.

---

## 18. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Container or VM escape | Prefer VMs, dedicated hosts, isolated networks, patch cadence, no shared secrets in workspaces |
| Abuse (mining, scanning) | Egress default deny, CPU flags, session caps, verified paid accounts, preview limits |
| Single host failure | Off-host backups, documented rebuild, second host in v1, honest availability statement |
| Bruin releases break labs | Pin versions, CI verifies all solution tags before image promotion, scheduled upgrades |
| Editor server licensing or extension availability | Spike item 3, packaged extension fallback, ADR |
| iframe or cookie issues | Same-site subdomains, spike item 4, extension-based layout in v1 |
| ingestr license objection | Written confirmation before charging, fallback load path |
| Free official Bruin content reduces demand | Position on depth, environment, verification, and support. Verify demand before heavy build. |
| Solo-operator burnout and on-call | Automate restarts, published support hours, status page, simple stack |
| Price or capacity assumptions wrong | Load test, adjustable limits, waitlist when at capacity |
| Payment or tax mistakes | Merchant of record or advisor review, idempotent webhooks, test mode checks |
| Accessibility gaps in terminal or editor | Early screen reader testing, non-terminal alternatives, extension-based results |

---

## 19. Prompts for Claude Code

Paste the master prompt at the start of every session. Run one phase prompt at a time.

### 19.1 Master prompt

```text
You are building the hosted learning platform specified in
Hosted_Platform_Build_Spec.md. Read Master_Execution_Guide.md in full first and
follow its start-of-session routine (handoff, knowledge index, plan, wait for
approval) and end-of-session routine (knowledge files, build log, handoff,
commit, no push). Then read this spec fully, plus the relevant parts of
Course_Curriculum_Outline.md (v3.0) and Course_Build_Prompt_Guide.md.
Prerequisites_Checklist.md lists what I must provide. Run its preflight and tell
me which missing item blocks the phase.

You are expected to investigate. Where the spec says verify, measure, or spike,
or where a third-party fact is unverified, research it using the source hierarchy
in the master guide, record results in docs/knowledge/ (facts, assumptions, open
questions, research notes, data files), and continue. Create new files under
docs/knowledge, docs/adr, docs/data and docs/spike as needed without asking. Ask
me only for Tier 3 decisions (money, legal, security-relevant changes, third-party
contact, destructive actions, contract changes).

Constraints:
1. Learners use only a browser. They never install anything or see containers.
2. The platform runs on rented bare-metal hosts that I operate. Do not design for
   a managed sandbox vendor.
3. Isolation and security controls in section 5 are mandatory. Do not skip or
   weaken a control to make something work. If a control blocks progress, stop and
   report.
4. Use the technologies in section 3.1 unless the Phase 0 spike produced an ADR
   that changes them.
5. Never invent facts about third-party services. Verify against official
   documentation or by running it, and record the evidence in
   docs/knowledge/VERIFIED_FACTS.md, docs/adr, or docs/spike.
6. Do not store or log learner terminal or editor content.
7. Plain, direct documentation. No emojis, no em dashes.
8. Every feature ships with tests at the level listed in section 13, and with an
   updated runbook if it adds an operational duty.
9. Work on the phase I name and stop at its acceptance criteria. Report what you
   verified, what you could not verify, and any decision you need from me.

Confirm you have read the spec and list the three highest risks for the phase I
am about to give you. Then wait.
```

### 19.2 Phase 0 prompt

```text
Phase 0: decisions and spikes (spec section 17). I will give you SSH access to a
test host. Do items 1 to 9 in order. For each, record the commands run, the
measurements, and the result in docs/spike/. Produce ADRs for isolation, editor
server, layout, and reset method. Do not write platform application code yet.
Finish with a go or no-go recommendation for Phase 1 and a list of decisions you
need from me (spec section 21).
```

### 19.3 Phase 1 prompts (run in this order)

```text
Phase 1a: infrastructure. Using the Phase 0 ADRs, build infra/ and image/:
host provisioning for Incus, storage, isolated networking with default-deny
egress, the workspace image recipe with pinned versions, the CI job that builds
the image and runs platform-validate-content, and the host agent. Acceptance:
spec section 5.3 tests 1 to 3 pass against a workspace created by the host agent,
and a workspace can be created, stopped, resumed, snapshotted, and deleted
through the host agent API.
```

```text
Phase 1b: workspace agent and content contract. Build the workspace agent
(health, idle, check, reset, snapshot-db, export, clock) and
platform-validate-content, following spec section 6. Use a sample module from the
course repository, or write a minimal sample module if the course is not ready.
Acceptance: check output is stored as JSON lines, reset returns a step to its exact
starter state including database and simulator clock in under 60 seconds, and
platform-validate-content passes on the sample.
```

```text
Phase 1c: control plane. Build apps/api: accounts (magic link), entitlements,
billing webhooks in test mode, preview versus paid gating, workspace lifecycle
state machine, hour accounting, progress, admin endpoints, and the data model in
section 10. Acceptance: all section 9 behaviors work in tests, webhooks are
idempotent, a learner cannot start a second workspace, and an unpaid user cannot
open paid modules.
```

```text
Phase 1d: gateway and frontend. Build the Traefik configuration with ForwardAuth,
apps/site and apps/dashboard with the side-by-side layout in section 8.1, the
accessible results panel, workspace status UI, and account pages. Acceptance:
end-to-end test passes (sign up, preview, buy in test mode, start workspace, run a
check, reset, export), and the keyboard-only and screen reader checks in 8.4 pass.
```

```text
Phase 1e: operations and launch readiness. Build monitoring and alerts, backups
with a tested restore, admin tools, runbooks (14.3), the load test, and the
security test suite as a CI and nightly job. Acceptance: all Phase 1 acceptance
criteria in spec section 17 are met and documented in docs/launch-readiness.md.
```

### 19.4 Phase 2 prompt (when ready)

```text
Phase 2: v1 (spec section 17). Build the course runner extension (8.2), hints and
solution viewing, certificates, cohorts, a second host with draining, capacity
alerts, and the optional egress-allowlisted GitHub lab. Do each as a separate
pull request with tests, and report accessibility and security test results for
each.
```

### 19.5 Reusable prompts

**Security review**

```text
Review the platform against spec section 5 as an attacker. Try to reach other
workspaces, the host, and the control plane from a workspace. Report every control
that can be bypassed, with reproduction steps, then fix and add a regression test.
```

**Learner-journey audit**

```text
Act as a new paying learner using only a browser and a keyboard. Complete the free
preview, buy, run three modules' steps using solution tags, reset, export, stop,
and resume. Report every point of confusion, delay over 30 seconds, and failure.
```

**Capacity check**

```text
Run the load driver at 1x, 2x, and 4x planned concurrency. Report start time
percentiles, memory and CPU per workspace, failures, and the host capacity formula
inputs. Update section 16 inputs and the capacity runbook.
```

---

## 20. Definition of Done for the MVP

All Phase 1 acceptance criteria met. All runbooks written and exercised once. Backups restored once. Security tests passing in CI. Accessibility pass completed and the statement published. Legal checklist items in section 15 resolved or consciously deferred in writing. Written confirmation from Bruin Data Limited on ingestr obtained, or the fallback chosen. Pricing, refund, and hour-limit policies published.

---

## 21. Open Decisions for the Course Author

1. Price, model (one-time with access period, subscription, or both), and the monthly hour allowance.
2. Brand name and domain. Avoid implying affiliation with Bruin.
3. Hosting provider, region, and host specification, chosen after quotes and the Phase 0 measurements.
4. Isolation choice (VM or container), decided from the Phase 0 spike.
5. Billing provider and whether to use a merchant of record.
6. Sign-in methods beyond email, and whether a GitHub account will be encouraged.
7. Free preview scope (modules 0 and 1 is the default).
8. Retention policy for inactive workspaces (default 90 days with warning).
9. Support channel, response-time target, and support hours.
10. Who is on call and what the published availability statement says.
11. Whether to approach Bruin Data Limited about ingestr confirmation and a possible partnership before or after the MVP.
12. Whether the optional CI lab and Module 13's optional bring-your-own-account lab are worth the egress risk at launch.
13. Certificates and cohorts: needed at launch or v1.
14. Data residency requirements for your target customers.
