# Prerequisites Checklist

Purpose: everything the course author must have in place for Claude Code to build the Stage 1 "Bruin for Data Engineers" course (a manual, self-guided course for experienced engineers, run against a database they choose). Items are numbered P1 to P14 and tied to the phases they block. Claude runs the preflight in section 11 at the start of each phase and reports any missing item and the phase it blocks.

Companion documents: `Master_Execution_Guide.md` (how Claude works), `Course_Build_Prompt_Guide.md` (phases A to I), `Course_Curriculum_Outline.md` (v4.0).

The hosted-platform items from the earlier version of this checklist (rented test host, domain, payments, email, monitoring, accessibility testers) are shelved with Stage 2. They are listed in section 13 so nothing is lost.

## 1. Summary: what blocks what

Required means the phase cannot finish without it. Start-early means it has a long lead time, so request it now even though the phase that needs it comes later.

| ID | Item | Required for | Lead time |
|----|------|--------------|-----------|
| P1 | Claude Code access and a budget | Everything | Minutes |
| P2 | Dedicated Linux development VM | Everything | Hours |
| P3 | Outbound web access for research | Phase A onward | Hours |
| P4 | The Git repository and a way to commit | Everything | Minutes |
| P5 | Toolchain on the development VM, including a Postgres server | Phase A onward | Hours (Claude installs most of it) |
| P6 | Secret handling and Claude Code permission setup | Everything | An hour |
| P7 | A dedicated test database that is safe to drop and recreate | Phase A onward | Minutes once P5 is done |
| P8 | A Windows machine, and ideally a macOS machine, for verification scripts | Phase F, before any Windows or macOS support claim | Days (start early) |
| P9 | Trial testers, a feedback channel, and agreement on what they may use | Phase G | Weeks (start early) |
| P10 | Employer and IP clearance | Before the trial and before sharing anything | Days to weeks (start early) |
| P11 | A sandbox account on a second target (Snowflake first) | Phase H | Days |
| P12 | Contact with Bruin Data Limited about ingestr and branding | Before any paid or public release | Weeks (start early) |
| P13 | Course content license and distribution decision | Phase I | Weeks |
| P14 | Author time and decisions | Everything | Ongoing |

Minimum to begin (Phase A): P1 to P7, P10, and P14. Everything else can wait until its phase.

## 2. P1: Claude Code access and budget

1. A Claude Code account that can run long, tool-heavy sessions. Documented sign-in options include Claude subscription plans (Pro, Max, Team, Enterprise), the Claude Console with API billing, and supported cloud providers. Use `/status` inside Claude Code to confirm which one is active. Check current plan limits and terms on the Anthropic site before choosing, because they change.
2. A spending decision, written down. Anthropic's Claude Code cost documentation states an average of about $13 per developer per active day, with 90 percent of users under $30 per active day. Those figures describe typical use. This project (18 modules, a simulator, a course CLI, assessments, many verification runs) is heavier than typical, though it is much smaller than the earlier hosted-platform plan. At the documented average, 40 active days is roughly $520. Treat that as an order-of-magnitude floor and not a forecast. Set a budget cap, and tell Claude the cap. Claude states the expected size of each session in its plan and stops at twice the estimate.
3. Know which model each task uses. Planning, research synthesis, and grader design justify the strongest model available. Mechanical edits do not. Claude Code lets you switch with `/model`.
4. Agent teams and many parallel subagents consume substantially more tokens than a single session (documentation cites roughly seven times). Do not enable them unless you decide to.
5. Install Claude Code on the development VM (P2) with the native installer: `curl -fsSL https://claude.ai/install.sh | bash`. Confirm with `claude --version` and `claude doctor`. Check the install page for the current command before running it.

Done when: `claude` starts on the development VM, `/status` shows your account, and you have a written budget cap.

## 3. P2: Dedicated Linux development VM

Claude runs commands, installs packages, starts databases, and writes files. Give it a machine where that is safe.

Requirements:

- A Linux VM (Ubuntu 24.04 LTS or Debian 12 or later recommended). Your Proxmox cluster is a reasonable place for it.
- 4 vCPU, 16 GB RAM, 100 GB disk is comfortable for Postgres, the simulator, Bruin runs, and the mock API together. Smaller works but slows the long runs. These are planning values. Adjust after Phase A.
- A non-root user with sudo. Claude uses sudo for package installs only after you approve the plan.
- Snapshots enabled. Take a snapshot before the first session and before every phase. Phase F also needs a clean restorable state to prove the setup guide works, so keep a snapshot of the VM with only Claude Code and Git installed.
- Outbound internet access (see P3).
- No credentials for anything unrelated to this project. Do not reuse a VM that holds bank, work, or personal credentials. Do not mount work file shares. See P10.
- Inbound access only from you (SSH from your network, or a private overlay such as WireGuard or Tailscale). The VM does not need a public address.

No nested virtualization or special hardware is needed in Stage 1.

Done when: you can SSH in, `sudo -v` works, snapshots exist, and `curl -sI https://example.com` returns a response.

## 4. P3: Outbound web access for research

Claude researches by fetching documentation and source. Network policies on your VM, firewall, or Claude Code settings can block that. Allow these domains at minimum (HTTPS, port 443), and let Claude record any others it needs in `docs/knowledge/OPEN_QUESTIONS.md` for your approval:

| Purpose | Domains |
|---------|---------|
| Bruin | `bruin-data.github.io`, `getbruin.com`, `github.com`, `raw.githubusercontent.com`, `api.github.com`, `objects.githubusercontent.com` |
| Packages | `pypi.org`, `files.pythonhosted.org`, `astral.sh` (uv), `deb.debian.org` or the Ubuntu mirror |
| Postgres | `www.postgresql.org`, `apt.postgresql.org`, and Docker Hub documentation pages (`hub.docker.com`) for the optional container link |
| Other targets (read-only research) | `docs.snowflake.com`, `learn.microsoft.com`, `dev.mysql.com`, plus the documentation domain of any other platform you want listed |
| Editor | `marketplace.visualstudio.com` |
| Claude and Anthropic docs | `code.claude.com`, `docs.claude.com`, `docs.anthropic.com`, `support.claude.com` |
| Course references | `git-scm.com`, `duckdb.org` and `sqlite.org` (for the unsupported-target explanation and the SQLite source) |

Done when: `curl -sI` against three of the above domains from the development VM succeeds and Claude can fetch the Bruin docs home page.

## 5. P4: The repository

- The existing `Bruin-for-Data-Engineers` repository is the course repository. Keep it private during the trial.
- The development VM needs a clone and a way to commit. Claude commits locally and does not push unless you instruct it. If you want it to push, use a deploy key or fine-grained token scoped to this one repository.
- The planning documents are in the repository root: `Curriculum_Planning_Prompt.md`, `Course_Curriculum_Outline.md`, `Course_Build_Prompt_Guide.md`, `Master_Execution_Guide.md`, `Prerequisites_Checklist.md`, `Curriculum_Review_Notes.md`, and `CLAUDE.md`. The shelved platform spec moves to `planning/Hosted_Platform_Build_Spec.md`.

Done when: the repository is cloned on the development VM and `git log` shows the planning documents.

## 6. P5: Toolchain on the development VM

Claude installs most of this itself with your approval. Listing it lets you confirm the VM can support it. Versions are pinned by Claude in the first session and recorded in `docs/knowledge/VERIFIED_FACTS.md`.

- Git, curl, jq, build tools
- Python 3.12 or later and `uv`
- PostgreSQL server and client, current stable release, installed natively on the VM as the reference target
- SQLite
- The Bruin CLI at a pinned version
- A secret scanner (gitleaks or similar)
- VS Code with the Bruin extension on a desktop machine of yours, for the extension checks (optional, but Phase A item 17 uses it)

Docker is not required. The setup guide will mention the official Postgres container image as an optional convenience for learners. Phase A verifies that link.

Done when: Claude's preflight (section 11) reports each tool and version.

## 7. P6: Secret handling and Claude Code permission setup

1. Decide where secrets live: a password manager, a file outside the repository with permissions 600, or environment variables loaded from a protected file. Claude never sees values. It receives variable names.
2. Add `.env*`, `.bruin.yml`, `*.pem`, `*.key`, `secrets/`, and `data/generated/` to `.gitignore` in the first commit.
3. Configure Claude Code permissions before the first working session:
   - Allow: read and edit within the repository, the build and test commands, `git status`, `git diff`, `git add`, `git commit`, and `uv run course ...`.
   - Ask: package installs, `sudo`, network downloads outside the allowlist.
   - Deny: reading secret files, `git push`, `git push --force`, and `rm -rf` outside the repository.
   - Check the current rule syntax in the Claude Code settings documentation, and verify the active rules with `/permissions`. Rules in `CLAUDE.md` are instructions Claude may or may not follow in a given turn. Use permission rules or a PreToolUse hook when you need enforcement.
4. Keep your own account passwords and MFA devices out of the VM.

Done when: a test session shows Claude is denied reading a dummy `.env` file and denied pushing.

## 8. P7: A dedicated test database

Labs create and drop objects, and the course CLI will run destructive resets. Claude needs a database that is safe to wreck.

- A dedicated empty Postgres database on the development VM (Claude can create it once Postgres is installed), plus a role that owns it. Name it clearly (for example `bruin_course_test`).
- Separate databases or schema sets for the Bruin `default`, `staging`, and `production` environments.
- The connection details live in the git-ignored `.bruin.yml` and in environment variables. The database name (never the password) goes in `CLAUDE.md`.
- It must never be a shared, production, or employer database. Claude treats any attempt to point a course command elsewhere as a Tier 3 decision.

Done when: `psql` connects with the course role, the database is empty, and the name is in `CLAUDE.md`.

## 9. P8 to P9: Machines and testers

**P8 Windows and macOS.** Claude runs on Linux and cannot verify Windows or macOS. The course claims support for a platform only after the verification scripts have run there and the results are recorded.

- At least one Windows 10 or 11 machine where you may install command-line tools. A personal machine or a virtual machine is better than a managed work laptop, because managed machines often block installs. A Windows evaluation VM on your Proxmox is one option (check the license terms of whatever image you use).
- If possible, one macOS machine.
- Time to run the scripts and paste the output back. Expect a few runs per phase.

**P9 Trial testers.** Needed from Phase G.

- Three to five engineers who match the audience (SQL strong, new to Bruin), ideally using more than one operating system and more than one target database.
- A feedback channel (email, a shared folder, an issue tracker) and agreement on what they send: the `course report` bundle and the feedback form. No real data, employer systems, or credentials.
- Agreement on confidentiality while the content is private.
- If testers are colleagues, resolve P10 first.

## 10. P10: Employer and IP clearance

Claude cannot give legal advice and does not contact third parties for you. This item belongs to you, and it comes first because it affects whether you should share the material at all.

The planning prompt appears to derive from your work at a bank. Before sharing the material with testers or planning a commercial release, confirm through your employment agreement, your employer's outside-activity or conflict-of-interest policy, and if needed a lawyer, that you may create and share this course, and that nothing in it derives from confidential or proprietary material. The outline already uses a fictional institution and synthetic data. Do not paste real table names, vendor names, or process documents into the repository or into Claude sessions. I have not seen your agreement, so I cannot say what it permits. Raise the question now.

Related items:

- If colleagues will be testers, decide whether the trial happens on personal machines and personal time, or with your employer's knowledge.
- The `signature-daily` name in the planning prompt appears to come from your own planning notes. Confirm it is not an employer system name before the planning prompt is shared with anyone.

Done when: you have written confirmation, or a documented decision, that the project may proceed and be shared in the way you intend.

## 11. Preflight checks Claude runs

Run at the start of each phase. Claude reports a table of item, result, and blocking phase.

```bash
# P1, P2
claude --version
uname -a; nproc; free -g | head -2; df -h . | tail -1
# P3
for u in https://bruin-data.github.io https://github.com https://pypi.org \
         https://www.postgresql.org https://code.claude.com; do
  curl -sS -o /dev/null -w "%{http_code} $u\n" "$u"; done
# P4
git remote -v; git status -sb; git log --oneline | head -3
# P5
git --version; python3 --version; uv --version
psql --version; sqlite3 --version; bruin --version
# P6
test -f .gitignore && grep -E '^\.env|\.bruin\.yml|secrets/' .gitignore
command -v gitleaks
# P7 (connection variables named in CLAUDE.md; never print values)
psql "$COURSE_TEST_DB_URL" -Atc "select current_database(), count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema')"
```

A missing optional tool is installed by Claude after plan approval. A missing blocking item (P1, P2, P4, P6, P7) stops the session after Claude reports it.

## 12. What Claude cannot do for you

| Task | Why |
|------|-----|
| Run anything on Windows or macOS | Claude runs on Linux. It writes verification scripts for you to run |
| Create accounts on other platforms (Snowflake, cloud providers) or pay for them | Requires your identity and payment method |
| Enter or retrieve MFA codes | Security |
| Give legal, tax, or compliance advice, or confirm what your employment agreement allows | Not a lawyer |
| Negotiate with or email Bruin Data Limited | Third-party communication on your behalf is a Tier 3 action |
| Recruit and observe testers, or judge how a lab feels to a newcomer | Needs humans |
| Decide the course license, audience, or release scope | Author decisions |
| Run the course for you and report real learner experience | Only testers can supply that |

## 13. Shelved: Stage 2 prerequisites (hosted version)

Kept for when Stage 2 is reopened (`Master_Execution_Guide.md` section 14). Not needed now.

- Rented bare-metal test host with virtualization, root SSH, and console access; budget approval.
- Domain, DNS API token, and TLS automation.
- S3-compatible object storage for backups.
- Transactional email provider with domain verification.
- Payment provider or merchant of record in test mode; account review and KYC.
- GitHub OAuth app, if GitHub sign-in is used.
- Uptime monitoring and alerting.
- Legal and tax advice before taking any payment; terms of service, privacy, and refund policies.
- Accessibility testing with real screen readers (NVDA, VoiceOver) and Safari.
- A decision on price, brand, hosting, and support (spec section 21).

## 14. P11 to P14: Later items

**P11 Second target sandbox (Phase H).** A dedicated sandbox database on Snowflake first (and SQL Server or MySQL later if you ask). Use a dedicated role with permissions limited to that database. Never use a production account or shared warehouse. Set a spending cap or resource monitor so a runaway sensor or retry loop cannot burn credits. Credentials stay in your secret store. Claude tells you the cost incurred after each run.

**P12 Bruin Data Limited.** Before any paid or public use, get written confirmation from the vendor that using ingestr in your course is acceptable under its license (FSL-1.1-ALv2 per the research so far, which permits education but prohibits competing commercial ingestion services), and ask about use of the Bruin name. Claude can prepare a factual summary of the license text and the planned use as a starting point, and you send it. Free trial use among colleagues is lower risk, though still worth asking about.

**P13 License and distribution.** Choose a license for the course content and code (Claude presents options and trade-offs in Phase I), decide what is public (for example a syllabus and Modules 0 and 1), and decide whether to charge. Ask a lawyer if you plan to sell it.

**P14 Author time.**

- Review plans before each session starts. Plan mode waits for you, so an unattended session stalls. Budget about 15 to 30 minutes per plan review and per handoff review.
- Be reachable for Tier 3 decisions. Claude lists them in `docs/knowledge/OPEN_QUESTIONS.md` with blocking phases.
- Run the Windows and macOS scripts and relay the results.
- Decisions to make before Phase B: source simulation mechanism, any scope changes proposed from Phase A (prompt guide section 7).
- Decisions to make before Phase G: tester list, which targets and operating systems they use, how feedback returns.
- Expect the first module to take several sessions, because it also exercises the process. Later modules go faster.

## 15. Final readiness checklist

Copy this into `docs/knowledge/OPEN_QUESTIONS.md` and tick items as they are met.

```markdown
Phase A ready
- [ ] P1 Claude Code works on the dev VM, budget cap written down
- [ ] P2 Dev VM with snapshots, sudo, 4 vCPU, 16 GB, 100 GB
- [ ] P3 Web access verified for Bruin, packages, Postgres, Claude docs
- [ ] P4 Repository cloned on the dev VM, planning documents committed
- [ ] P5 Toolchain installed or approved for install, including Postgres
- [ ] P6 Secret rules and permissions configured, deny rules tested
- [ ] P7 Dedicated empty test database created, name in CLAUDE.md
- [ ] P10 Employer and IP question answered
- [ ] P14 Time reserved for plan reviews

Phase F ready (adds)
- [ ] P8 Windows machine available, macOS if possible, scripts run and results returned
- [ ] Clean-state VM snapshot taken

Phase G ready (adds)
- [ ] P9 Testers recruited, feedback channel set, confidentiality agreed
- [ ] P10 clearance covers sharing with testers

Phase H ready (adds)
- [ ] P11 Sandbox database on the second target, spending cap set

Before any paid or public release (adds)
- [ ] P12 Written confirmation about ingestr and branding
- [ ] P13 License and distribution decided; legal advice if selling
```
