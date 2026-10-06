# Prerequisites Checklist

Purpose: everything the course author must have in place for Claude Code to build the "Bruin for Data Engineers" course and its hosted platform. Items are numbered P1 to P18 and tied to the phases they block. Claude runs the preflight in section 12 at the start of each phase and reports any missing item and the phase it blocks.

Companion documents: `Master_Execution_Guide.md` (how Claude works), `Course_Build_Prompt_Guide.md` (course phases A to G), `Hosted_Platform_Build_Spec.md` (platform phases 0 to 2 and the open decisions in its section 21).

## 1. Summary: what blocks what

Required means the phase cannot finish without it. Start-early means it has a long lead time, so request it now even though the phase that needs it comes later.

| ID | Item | Required for | Lead time |
|----|------|--------------|-----------|
| P1 | Claude Code access and a budget | Everything | Minutes |
| P2 | Dedicated Linux development VM | Everything | Hours |
| P3 | Outbound web access for research | Course Phase A, Platform Phase 0, all research | Hours |
| P4 | Git hosting and two private repositories | Everything | Minutes |
| P5 | Toolchain on the development VM | Course Phase A onward, Platform Phase 1 | Hours (Claude can install most of it) |
| P6 | Secret handling and Claude Code permission setup | Everything | An hour |
| P7 | Rented bare-metal test host (KVM, root SSH) | Platform Phase 0 | Days (provider approval can take time) |
| P8 | Domain and DNS control | Platform Phase 1 | Days |
| P9 | S3-compatible object storage | Platform Phase 1 (backups) | Hours |
| P10 | Transactional email provider | Platform Phase 1 | Days (domain verification) |
| P11 | Payment provider or merchant of record, test mode | Platform Phase 1 (billing) | Days to weeks (account review) |
| P12 | GitHub OAuth application | Platform Phase 1 (if GitHub sign-in is chosen) | Minutes |
| P13 | Uptime monitoring and alert destination | Platform Phase 1 end | Hours |
| P14 | Contact with Bruin Data Limited about ingestr use | Before public launch, ideally before Phase 1 | Weeks (start early) |
| P15 | Legal and tax advice | Before taking any payment | Weeks (start early) |
| P16 | Accessibility testing devices and people | Course Phase F, Platform Phase 1 end | Weeks |
| P17 | Beta testers | Beta | Weeks |
| P18 | Author time and decisions | Everything | Ongoing |

Minimum to begin building course content only (Course Phases A to C, no platform): P1 to P6 and P18. Everything else can wait until the platform work starts.

## 2. P1: Claude Code access and budget

1. A Claude Code account that can run long, tool-heavy sessions. Documented sign-in options include Claude subscription plans (Pro, Max, Team, Enterprise), the Claude Console with API billing, and supported cloud providers. Use `/status` inside Claude Code to confirm which one is active. Check current plan limits and terms on the Anthropic site before choosing, because they change.
2. A spending decision, written down. Anthropic's Claude Code cost documentation states an average of about $13 per developer per active day, with 90 percent of users under $30 per active day. Those figures describe typical use. This project (17 modules, a simulator, a multi-service platform, many verification runs) is heavier than typical. At the documented average, 60 active days is roughly $780. Treat that as an order-of-magnitude floor and not a forecast. Set a budget cap you can live with, and tell Claude the cap. Claude states the expected size of each session in its plan and stops at twice the estimate.
3. Know which model each task uses. Planning, security review, and research synthesis justify the strongest model available to you. Mechanical edits do not. Claude Code lets you switch with `/model`.
4. Agent teams and many parallel subagents consume substantially more tokens than a single session (documentation cites roughly seven times). Do not enable them unless you decide to.
5. Install Claude Code on the development VM (P2) with the native installer: `curl -fsSL https://claude.ai/install.sh | bash`. Confirm with `claude --version` and `claude doctor`. Check the install page for the current command before running it.

Done when: `claude` starts on the development VM, `/status` shows your account, and you have a written budget cap.

## 3. P2: Dedicated Linux development VM

Claude runs commands, installs packages, starts databases, and writes files. Give it a machine where that is safe.

Requirements:

- A Linux VM (Ubuntu 24.04 LTS or Debian 12 or later recommended). Your Proxmox cluster is a reasonable place for it.
- 4 or more vCPU, 16 GB RAM, 100 GB disk. Postgres, the Source Simulator, Bruin runs, and a code editor server run together during testing, so smaller than this will be slow. These are planning values. Adjust after Phase A.
- A non-root user with sudo. Claude uses sudo for package installs only after you approve the plan.
- Snapshots enabled. Take a snapshot before the first session and before every phase. A snapshot is how you undo a bad install or an accidental deletion.
- Outbound internet access (see P3).
- No credentials for anything unrelated to this project. Do not reuse a VM that holds bank, work, or personal credentials. Do not mount work file shares. See the employer note in section 10.
- Inbound access only from you (SSH from your network, or a private overlay such as WireGuard or Tailscale). The VM does not need a public address.

Limitation to plan around: running Incus VMs for the platform spike needs hardware virtualization. A Proxmox guest cannot test that unless nested virtualization is enabled, and nested results do not predict bare-metal performance. This is why P7 exists. Use the development VM for course work and platform code, and the rented host (P7) for isolation, density, and reset measurements.

Done when: you can SSH in, `sudo -v` works, a snapshot exists, and `curl -sI https://example.com` returns a response.

## 4. P3: Outbound web access for research

Claude researches by fetching documentation and source. Network policies on your VM, firewall, or Claude Code settings can block that. Allow these domains at minimum (HTTPS, port 443), and let Claude record any others it needs in `docs/knowledge/OPEN_QUESTIONS.md` for your approval:

| Purpose | Domains |
|---------|---------|
| Bruin | `bruin-data.github.io`, `getbruin.com`, `github.com`, `raw.githubusercontent.com`, `api.github.com`, `objects.githubusercontent.com` |
| Packages | `pypi.org`, `files.pythonhosted.org`, `registry.npmjs.org`, `proxy.golang.org`, `sum.golang.org`, `deb.debian.org` or the Ubuntu mirror, `astral.sh` (uv) |
| Postgres | `www.postgresql.org`, `apt.postgresql.org` |
| Platform components | `linuxcontainers.org`, `github.com/lxc`, `coder.com` and `github.com/coder/code-server`, `open-vsx.org`, `marketplace.visualstudio.com`, `traefik.io` |
| Claude and Anthropic docs | `code.claude.com`, `docs.claude.com`, `docs.anthropic.com`, `support.claude.com` |
| Course references | `docs.snowflake.com`, `duckdb.org`, `sqlite.org`, `kimballgroup.com` (optional reading) |
| Providers you choose | Your hosting, billing, email, and DNS providers' documentation domains |

Note: the Bruin extension may be installable only from the Microsoft marketplace, which has terms restricting use in non-Microsoft products. Claude records the real finding in Phase 0 and asks you to decide. Do not assume it is allowed.

Done when: `curl -sI` against three of the above domains from the development VM succeeds and Claude can run a web fetch of the Bruin docs home page.

## 5. P4: Git hosting and repositories

- A Git host account (GitHub, GitLab, or self-hosted such as Gitea). The optional CI lab and Bruin's documented CI examples use GitHub, so a GitHub account is convenient.
- Two private repositories (or one monorepo, which Claude records as an ADR): `bruin-course` and `bruin-platform`. Names are placeholders.
- A way for the development VM to push and pull: a deploy key or fine-grained personal access token scoped to those two repositories only. Never a token with access to your other repositories.
- Branch protection on `main` is optional while you are the only contributor. Claude commits locally and does not push unless you instruct it.
- Put these five documents in the course repository root, and copies of the platform-relevant ones in the platform repository: `Curriculum_Planning_Prompt.md`, `Course_Curriculum_Outline.md`, `Course_Build_Prompt_Guide.md`, `Master_Execution_Guide.md`, `Prerequisites_Checklist.md`, and in the platform repository `Hosted_Platform_Build_Spec.md`.

Done when: both repositories exist, the development VM can clone them, and the planning documents are committed.

## 6. P5: Toolchain on the development VM

Claude installs most of this itself with your approval. Listing it lets you confirm the VM can support it. Versions are pinned by Claude in the first session and recorded in `docs/knowledge/VERIFIED_FACTS.md`.

- Git, make, curl, jq, build-essential
- Python 3.12 or later and `uv`
- Node.js LTS and npm (for the Starlight site and the control plane if TypeScript is chosen)
- Go (for the host agent, workspace agent, and the Bruin binary if built from source)
- PostgreSQL server and client, current stable release, installed locally for development and tests
- DuckDB CLI and SQLite
- The Bruin CLI at a pinned version
- A secret scanner (gitleaks or similar)
- For platform work, optionally a local container runtime to run Traefik and the control plane database during development. This is a developer convenience on your machine and never appears in the course. If you prefer to avoid it, Claude runs those services as native packages.

Done when: Claude's preflight (section 12) reports each tool and version.

## 7. P6: Secret handling and Claude Code permission setup

1. Decide where secrets live: a password manager, a file outside the repository with permissions 600, or environment variables loaded from a protected file. Claude never sees values. It receives variable names.
2. Create separate development, test, and production credentials for every provider. Use test-mode keys for payments and email until launch readiness.
3. Add `.env*`, `.bruin.yml` with real credentials, `*.pem`, `*.key`, and `secrets/` to `.gitignore` in the first commit.
4. Configure Claude Code permissions before the first working session:
   - Allow: read and edit within the repository, the build and test commands, `git status`, `git diff`, `git add`, `git commit`.
   - Ask: package installs, `sudo`, network downloads, `ssh` to any host.
   - Deny: reading secret files and `git push`, `git push --force`, `rm -rf` outside the repository.
   - Check the current rule syntax in the Claude Code settings documentation, and verify the active rules with `/permissions`. Rules in `CLAUDE.md` are instructions Claude may or may not follow in a given turn. Use permission rules or a PreToolUse hook when you need enforcement.
5. Keep your own account passwords and MFA devices out of the VM.

Done when: a test session shows Claude is denied reading a dummy `.env` file and denied pushing.

## 8. P7: Rented bare-metal test host (Platform Phase 0)

Needed for isolation, density, startup, reset, and egress measurements. This is the highest-value item for deciding whether the platform design works.

Requirements:

- A dedicated server or bare-metal instance with hardware virtualization exposed (Intel VT-x or AMD-V; check `egrep -c '(vmx|svm)' /proc/cpuinfo` returns a number above zero).
- Root SSH access with key authentication and the ability to reinstall the operating system.
- Planning values: 8 or more cores, 64 GB RAM or more, NVMe storage of 1 TB or more with the option to give Incus a dedicated disk or partition for ZFS, a public IPv4 address, and bandwidth terms that cover the test. Per-workspace limits in the spec are 2 vCPU and 4 GiB RAM, so the RAM figure decides the density you can measure. A host smaller than this still gives usable data if you accept fewer concurrent workspaces.
- Hourly or monthly billing with no long commitment. Reported 2026 price increases at a major provider make a current quote necessary. Claude records quotes in `docs/data/pricing-<date>.csv` as leads. You decide and pay.
- A dedicated SSH key for this host, created for this project and revocable.
- A written budget approval for the test host: monthly price, maximum duration, and who cancels it.
- Out-of-band console access (provider rescue mode or KVM-over-IP). Firewall mistakes during egress tests will lock out SSH otherwise.

Claude does the server configuration, but you hold the provider account. Claude does not sign up, pay, or reinstall a host on your behalf. Production hosts come later, after the Phase 0 ADRs.

Done when: `ssh` from the development VM works with the dedicated key, `lscpu` shows virtualization, and the budget is written down.

## 9. P8 to P13: Platform services

Needed from Platform Phase 1. Gather them during Phase 0 to avoid waiting.

**P8 Domain and DNS.** Choose a brand name that does not imply affiliation with Bruin (spec section 21, item 2), buy the domain, and make sure you can create DNS records. For automated TLS certificates, create a DNS provider API token scoped to this zone only, with permission to edit TXT records. Keep the registrar login out of the VM. The control plane, the gateway, and per-workspace subdomains share the zone.

**P9 Object storage.** An S3-compatible bucket with a separate access key limited to that bucket, for encrypted backups of the control database and course content. A second bucket or provider for off-site copies is preferred. Lifecycle rules and versioning enabled.

**P10 Transactional email.** An account with a provider that supports API sending. Verify your sending domain with SPF, DKIM, and DMARC records (these require P8). Sending quota enough for sign-up, receipts, password resets, and alerts. Create a separate test API key.

**P11 Payments.** Open an account with a payment provider, in test mode, with a hosted checkout and webhooks. Decide whether to use a merchant of record, which handles sales tax and VAT collection and remittance for you in exchange for higher fees (spec section 21, item 5). Account review and identity verification (KYC) take days to weeks and require your personal or business documents, which only you can supply. Claude builds against the test-mode keys only. Live keys are a launch-readiness step you perform.

**P12 GitHub OAuth app.** If GitHub sign-in is part of your decision (spec section 21, item 6): create an OAuth application, record the client ID, store the secret per P6. Callback URLs are set after P8.

**P13 Monitoring.** An external uptime monitor (hosted service or a second small server in another network), an alert destination (email, SMS, or push to your phone), and a status page option. Required before beta, since a platform that cannot tell you it is down is a production risk.

## 10. P14 and P15: Legal, licensing, and business

Claude cannot give legal or tax advice, contact third parties on your behalf (Tier 3 in the master guide), or accept terms for you. These items belong to you.

1. **Employer and intellectual property.** The planning prompt and the outline describe workflows and a dependency chain drawn from your work at a bank. Before building a commercial product, confirm with your employment agreement, your employer's outside-activity or conflict-of-interest policy, and if needed a lawyer, that you may create and sell this course, and that nothing in it derives from confidential or proprietary material. The outline already uses a fictional institution and synthetic data. Do not paste real table names, vendor names, or process documents into the repository or into Claude sessions. This is a material risk to the whole project and cheap to check now. I have not seen your agreement, so I cannot say what it permits. Raise the question now.
2. **ingestr license.** The ingestr license (FSL-1.1-ALv2 per the research done so far) permits education but prohibits competing commercial ingestion services. A paid course that runs ingestr inside a hosted workspace needs written confirmation from Bruin Data Limited that this use is allowed. Draft the request yourself or with counsel. Claude can prepare a factual summary of the license text and the planned use as a starting point, and you send it.
3. **Trademarks and branding.** Use of the Bruin name and logo in a product name or marketing. Ask the same contact. Your brand avoids implying affiliation.
4. **Third-party licenses.** Claude produces a license inventory for every bundled component in Phase 0. You or counsel review it. The VS Code Marketplace terms for non-Microsoft editors are a known question.
5. **Business entity, tax, and sales tax or VAT.** Whether to operate through an entity, registration requirements in the jurisdictions of your customers, and whether a merchant of record covers them. Consult a tax professional before charging.
6. **Terms of service, privacy policy, acceptable use policy, refund policy.** Claude drafts structure and checklists from the spec's compliance section. A lawyer reviews final text. Learners run arbitrary code, so the acceptable use policy and the abuse-handling process matter.
7. **Data residency and privacy law** for your target customers (spec section 21, item 14).
8. **Cyber insurance and liability limits** if you want them.

## 11. P16 and P17: People and devices for testing

- Screen reader testing: NVDA with Firefox or Chrome on Windows, VoiceOver with Safari on macOS, and a keyboard-only pass. Claude can run automated accessibility checks (axe) and review markup, but it cannot hear a screen reader. A person must listen.
- Browsers for the embedded editor and cookie behavior: current Chrome, Firefox, and Safari, including one Safari on macOS or iOS. Safari has the strictest cookie and iframe rules.
- A few people who match the audience (working data engineers or analysts) to do the first modules without help, and report where they got stuck. Five to ten for beta is a reasonable target. You recruit them.
- Willingness to review work in short, frequent passes (see P18).

## 12. Preflight checks Claude runs

Run at the start of each phase, adapted to the repository. Claude reports a table of item, result, and blocking phase.

```bash
# P1, P2
claude --version
uname -a; nproc; free -g | head -2; df -h . | tail -1
# P3
for u in https://bruin-data.github.io https://github.com https://pypi.org \
         https://www.postgresql.org https://code.claude.com; do
  curl -sS -o /dev/null -w "%{http_code} $u\n" "$u"; done
# P4
git remote -v; git status -sb
# P5
git --version; make --version | head -1; python3 --version; uv --version
node --version; go version; psql --version; duckdb --version; sqlite3 --version
bruin --version
# P6
test -f .gitignore && grep -E '^\.env|\.bruin\.yml|secrets/' .gitignore
command -v gitleaks
# P7 (platform Phase 0 only; host name from CLAUDE.md, no credentials in output)
ssh -o BatchMode=yes <test-host> 'egrep -c "(vmx|svm)" /proc/cpuinfo; nproc; free -g | head -2; lsblk -d -o NAME,SIZE,ROTA'
```

A missing optional tool is installed by Claude after plan approval. A missing blocking item (P1, P2, P4, P6, and P7 for Phase 0) stops the session after Claude reports it.

## 13. What Claude cannot do for you

| Task | Why |
|------|-----|
| Sign up, pay for, or verify accounts (hosting, domain, payments, email) | Requires your identity, payment method, MFA, and KYC |
| Enter or retrieve MFA codes | Security |
| Obtain current provider quotes with certainty | Prices change and pages may be unreachable. Claude records leads, you confirm |
| Give legal, tax, or compliance advice | Not a lawyer or tax advisor |
| Negotiate with or email Bruin Data Limited or providers | Third-party communication on your behalf is a Tier 3 action |
| Listen to a screen reader and judge usability | Needs a person with the real tools |
| Recruit and observe beta testers | Needs humans |
| Decide price, brand, and positioning | Author decisions (spec section 21) |
| Operate production on a schedule while you are away | No scheduler runs in a session. Production operations need your monitoring and on-call plan |

## 14. P18: Author time and decisions

- Review plans before each session starts. Plan mode waits for you, so an unattended session stalls. Budget about 15 to 30 minutes per plan review and per handoff review.
- Be reachable for Tier 3 decisions. Claude lists them in `docs/knowledge/OPEN_QUESTIONS.md` with blocking phases.
- Decisions to make before Platform Phase 1 (spec section 21): price and model, brand and domain, hosting provider and region, isolation (after Phase 0), billing provider and merchant of record, sign-in methods, free preview scope, retention policy, support and on-call plan, ingestr confirmation timing, optional egress labs, certificates and cohorts, data residency.
- Decisions to make before Course Phase B (prompt guide section 7): source simulation mechanism, public versus private distribution of content, CI platform for the optional lab, fictional institution naming, skip versus fail for conditional runs, scope trims.
- Expect the first module to take several sessions, because it also exercises the process. Later modules go faster.

## 15. Final readiness checklist

Copy this into `docs/knowledge/OPEN_QUESTIONS.md` and tick items as they are met.

```markdown
Course Phase A and B ready
- [ ] P1 Claude Code works on the dev VM, budget cap written down
- [ ] P2 Dev VM with snapshots, sudo, 4 vCPU, 16 GB, 100 GB
- [ ] P3 Web access verified for Bruin, packages, Postgres, Claude docs
- [ ] P4 Repositories created, planning documents committed
- [ ] P5 Toolchain installed or approved for install
- [ ] P6 Secret rules and permissions configured, deny rules tested
- [ ] P18 Time reserved for plan reviews

Platform Phase 0 ready (adds)
- [ ] P7 Test host rented, SSH key works, virtualization confirmed, budget approved
- [ ] Employer and IP question answered (section 10, item 1)

Platform Phase 1 ready (adds)
- [ ] Phase 0 ADRs accepted and decisions in section 21 made
- [ ] P8 Domain bought, DNS token created
- [ ] P9 Object storage and scoped key
- [ ] P10 Email provider verified for the domain, test key
- [ ] P11 Payment account in test mode, merchant of record decision made
- [ ] P12 GitHub OAuth app, if used
- [ ] P13 Monitoring and alert destination

Before public launch (adds)
- [ ] P14 ingestr and branding confirmation in writing
- [ ] P15 Legal and tax advice obtained, policies reviewed
- [ ] P16 Accessibility testing done with real assistive technology
- [ ] P17 Beta completed, issues triaged
- [ ] Production hosts, live keys, backups restored in a drill, runbooks written
```
