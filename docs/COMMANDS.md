# PACT — command reference

Every command, its syntax, and what it does. Syntax is `/pact:<name> [arguments]`
inside a Claude Code session. The deterministic parts are also runnable as
`pact <subcommand>` in a terminal where the plugin's `bin/` is on `PATH`.

For settings, files, hooks, and the status line, see [`CONFIG.md`](CONFIG.md). For
the design rationale, see [`DESIGN.md`](DESIGN.md).

---

## `pact help`

```
/pact:help [<command>]
```

The command map. With no argument it prints every command grouped by where it
sits in the flow — the pipeline (`init`, `spec`, `plan`, `build`, `ship`), the
optional layers (`design`, `team`, `review`), and the anytime commands — each
with its invocation and description, plus the `spec -> plan -> build -> ship`
spine and pointers to this file, `CONFIG.md`, and the README.

Given a command name it prints just that command's syntax and full description,
e.g. `/pact:help build`.

Script-rendered, zero model tokens, read-only. Does not gate on schema — it works
before `/pact:init` and while a `pact migrate` is pending. Also runs as
`pact help` (or bare `pact`) in a terminal; `pact help --list` prints the command
names, one per line.

---

## `pact init`

```
/pact:init [--new | --adopt | --reconfig]
```

Configure PACT for the current project. Detects the mode automatically:

- **NEW** — empty directory (or just `.git`). Full scaffold, long questionnaire.
- **ADOPT** — code exists, no `.pact/`. Scans the stack, short questionnaire,
  touches no source files.
- **RECONFIG** — `.pact/` already present. Does not re-scaffold; points you at
  `/pact:config`. `--reconfig` forces a guided re-run.

The questionnaire, in order: communication language and flow mode; a scan of
existing docs (`CLAUDE.md`, `README`, `docs/**`, …) offered as source; the
project brief; the stack and environment commands; VCS and git workflow; the
optional toggles (`full` only); the constitution (if enabled); models and effort
(`full` only). Every question offers three paths — accept the proposed default,
pick a preset, or answer in free text.

Writes `.pact/{config.toml, stack.toml, project.md, constitution.md, design.md,
charter-overrides.log}`, `tasks/`, `docs/specs/`, `docs/decisions/`, a fenced
PACT section in `CLAUDE.md`, the `enabledPlugins` entry, and the managed
`.gitignore` block.

---

## `pact spec`

```
/pact:spec <type> "<description>"          create
/pact:spec <existing-slug-or-SP-id>        adjust an existing spec
/pact:spec <notes-file>                    create from a notes file
```

`<type>` is one of `feat | fix | adjust | refactor | perf | chore | docs`.

The agent drafts about 90% of the spec from the description, `project.md`, the
constitution, and related source, then runs a **clarification loop with no cap**:
one question at a time, each recorded under `## Clarifications` as it is answered,
until no material ambiguity remains or you say stop. Sections that do not apply to
the type are removed, not left as "N/A".

Output: `docs/specs/<date>_<slug>/spec.md` at `status: ready`.

---

## `pact design` *(optional — `steps.design_docs`)*

```
/pact:design <spec.md>       generate feature-scoped architecture docs
/pact:design sync            scaffold docs for features that lack one
/pact:design optimize        dedup shared content into _shared.md
```

Produces global docs (`overview.md`, `folder-structure.md`, `tech-stack.md`,
`_shared.md`) plus one self-contained
`docs/architecture/features/<slug>/index.md` per feature (Components, Data,
Flows, API). `plan` reads these to cut better stories. With the toggle off,
`plan` works from the spec, `project.md`, and the code directly.

---

## `pact team` *(optional — `steps.team`)*

```
/pact:team [--basic | --standard | --max] [--regenerate] [--check]
```

Derives project-tailored skills into `.claude/skills/` — `guide-<language>`,
`guide-<framework>`, `expert-qa`, and specialists a real signal justifies
(`expert-security` when auth or secrets, `expert-database` when a schema,
`expert-api` when routes). Each carries `paths:` globs so `build` auto-loads the
relevant ones. `--regenerate` refreshes them merge-safe, preserving any
`## House rules` you added. Version-specific research is opt-in via
`[team].context7` (off by default — token cost).

---

## `pact plan`

```
/pact:plan <spec.md> [--one-pass]
```

Turns a `ready` spec into epics and stories under `tasks/<date>_<slug>/`.

- **Epics** are vertical slices of user-visible capability, ordered **demo-first**
  — epic 01 is the thinnest walking skeleton plus one real capability; later
  epics add capabilities and replace earlier fixture seams; a mandatory final
  **Integration & E2E** epic wires everything. Roughly 3–8 stories per epic.
- **Stories** are one vertical behavior each, testable on its own, that one agent
  finishes in one pass (cap ~6 acceptance criteria). No size buckets.
- Every acceptance criterion in the spec maps to at least one story.
- **two-pass** (default in `full`) validates the epic breakdown, then the
  stories. **one-pass** (default in `lite`, or `--one-pass`) presents everything
  at once.

A trivial `chore` / `docs` spec skips epics entirely — one story straight to
`build`.

Regenerates the index views once at the end. Shows the wave plan.

---

## `pact build`

```
/pact:build                              the current spec, in waves
/pact:build <story-path>                  one story, inline
/pact:build 01-02 01-05                   those stories, one wave
/pact:build --epic 01                     the whole epic, in waves
/pact:build --story 01-02                 force inline
/pact:build --mode step|wave|spec|flow|dry
```

Implements stories with the cycle **plan -> RED -> GREEN -> refactor -> QA ->
complete**. RED before GREEN, always. QA runs the full test, lint, typecheck, and
build, checks architecture compliance and edge cases, and loops at most 3 times
before escalating.

**Waves.** `pact wave-plan` computes the topological layers of the `blocked_by`
DAG; each layer runs in parallel, one git worktree and one `story-implementer`
subagent per story. Story branches merge into the spec branch in id order; the
first conflict goes to the `conflict-analyzer`, which returns `auto` (apply a
patch), `serialize` (push the losing story to the next wave), or `manual`
(surface the hunks). The full suite runs on the spec branch after each wave.

**One active spec at a time.** `build` refuses to start on spec B while spec A's
branch is unmerged — finish it, or `/pact:ship --abandon <A>`.

**Bug-fix mode.** A story at `status: bug` implements the recorded Fix Plan with
the smallest possible diff, re-tests all of the story's acceptance criteria, and
restores its previous status.

After all waves are green, one **batched verification gate** for the whole set
(method by project type — a browser click-through for a web UI, running the
command for a CLI, a curl or smoke script for a service).

### Execution modes

Chosen when a spec's build starts (default `workflow.default_exec_mode`),
changeable mid-run with `/pact:build --mode <x>` (it resumes where it left off):

| Mode | Pauses after… |
|---|---|
| `step` | every story |
| `wave` | every wave |
| `spec` | nothing — builds the whole spec to `done` |
| `flow` | nothing — auto-chains `build -> review -> ship` while nothing blocks |
| `dry` | does nothing — shows the wave plan and stops |

**Hard stops override every mode**: the batched verification gate, QA escalation
after 3 iterations, an unresolvable `manual` merge conflict, a `review`
`NEEDS_FIXES` that cannot be auto-fixed, a destructive-action confirmation, and a
required human PR approval.

---

## `pact review` *(optional — `steps.review`)*

```
/pact:review [--effort quick|standard|deep] [--passes N] [--model M]
/pact:review --project
```

A feature-level audit of the whole spec — every story together — that `build`
already took to green per story. Checks spec-level acceptance-criteria coverage,
consistency against the plan, the constitution, accepted DRs, and `project.md`,
and a whole-diff code review (SOLID, feature-level redundancy, edge cases,
security, error handling). It does not re-run the test suite unless the branch
moved since `build`'s green or `[review].fresh_suite` asks for it. Verdict `PASS`
/ `NEEDS_FIXES`; it auto-fixes low/medium findings and hands CRITICAL/HIGH back
to a targeted `build`.

`--project` audits the whole codebase against `project.md`, accepted DRs, and the
constitution, and emits `refactor` / `chore` spec stubs for the drift it finds.
It blocks nothing.

`--effort deep` fans out independent passes (correctness, security, architecture)
and merges the findings.

---

## `pact ship`

```
/pact:ship                                       ship the active spec
/pact:ship --abandon SP-id                        return a spec to planned
/pact:ship --to-issues [--mode feature|epics|stories]   publish the plan to GitHub Issues
```

Delivers the active spec: pre-check (all stories `done`, review green if gated),
preflight (re-lint/test only if the branch moved since the recorded green),
commit, push, PR (`spec/<id>` -> the target branch, body from the spec, `Closes
#NN` when issue tracking is on), issue updates, CI wait if gated, merge with the
configured strategy, then post-merge: mark every story `delivery: merged` and the
spec `done`, delete the branch and worktrees, propose a `project.md` patch if the
structure changed, print the deploy reminder (PACT does not deploy).

`--abandon` deletes the spec branch and worktrees and frees the active-spec lock.
`--to-issues` mirrors the plan into GitHub Issues and writes the numbers back
into frontmatter; it is re-runnable and never creates anything twice.

No AI references in any commit, PR body, issue comment, or branch name — enforced
by a guard hook while `ship`, `build`, and `fix` run.

---

## `pact fix`

```
/pact:fix "<bug description>"          diagnose + spec in one run
/pact:fix <spec-slug-or-SP-id>         continue an existing fix spec's diagnosis
```

Diagnoses a bug in an isolated context: reproduces it (browser, curl, or a direct
call by project type), writes a **failing reproduction test** (RED, committed),
and locates the root cause. It writes the Context, Reproduction, Expected vs
Actual, Root Cause Hypothesis, and Fix Plan into a `type: fix` spec — **never the
source fix itself**. Links the affected story (`status: bug`, previous status
kept). An easy fix auto-runs `build` in bug-fix mode; a complex one hands off.

---

## `pact security`

```
/pact:security [--deps] [--scope PATH] [--deep]
```

An on-demand, defensive security audit of **this repository and its local dev
instance only** — never third-party systems. Covers SAST (injection, authz gaps,
secret leakage, SSRF, CSRF, weak crypto, unsafe defaults), dependency
vulnerabilities, config (exposed env, permissive CORS, missing headers), and
compliance with the constitution's Security axis. Findings become `type: fix`
spec stubs (`security: true`, `status: draft`), one per finding or grouped by
root cause, ordered by severity. You pick which to act on; each runs the normal
`spec -> plan -> build -> ship` flow. A risk you accept is recorded as a
`tradeoff` DR. It never auto-runs and never writes a fix.

`--deep` fans out passes focused on injection, auth, crypto, and config.

---

## `pact status`

```
/pact:status [--write]
```

Read-only dashboard, rendered by a script — zero model tokens. Shows the spec
counts, the active spec's stories, live worktrees, and the wave lock. `--write`
also dumps a generated `tasks/ROADMAP.md` snapshot. Does not gate on schema, so
it works even when a migration is pending.

---

## `pact check`

```
/pact:check [--quiet]
```

Health report. Flags a schema mismatch, unparseable frontmatter, an index that
has drifted from the stories, an unresolvable `blocked_by`, an orphan spec
branch, a missing `.gitignore` block, and uncommitted `.pact/`. Each finding
names the command that fixes it. Exit status is non-zero if any error-level
finding exists. Read-only.

---

## `pact config`

```
/pact:config show                       print the current settings
/pact:config statusline install         install the main status line
/pact:config project expand             turn project.md into a fuller PRD (+ spec stubs)
/pact:config <what to change>           free text — e.g. "turn on review", "squash merges"
```

The conversational editor for `.pact/config.toml`, `.pact/stack.toml`, and the
constitution. You never hand-edit those files. Turning a step on offers the
matching backfill; editing the constitution bumps its version.

---

## `pact adr`

```
/pact:adr "<the decision>"
```

Create a Decision Record by hand. The agent drafts the four sections from the
conversation and the repo, you confirm, and the file is written with the next
sequential number and the index regenerated. It checks the index first and will
not record the same decision twice.

---

## `pact migrate`

```
/pact:migrate
```

Upgrades the project's `.pact/` layout to the schema this plugin build supports.
One-shot, idempotent, refuses a dirty tree, applies each migration step in order
across versions, restamps the schema, regenerates the views, and lands everything
in one revertable commit. Every write-command refuses to run on a schema
mismatch and points here; read-only commands (`status`, `check`) still work.

---

## Walkthroughs

### An existing project

```
cd my-existing-app          # code, package.json, tests, docker-compose.yml, a README
```
```
/pact:init
  detects ADOPT; scans pnpm + NestJS + Next + docker-compose + workflows
  finds README, CONTRIBUTING -> offered as source
  language + flow: full
  project context: pre-filled from the README + code; you confirm the tech->role map
  stack: detected commands confirmed; isolation docker-compose
  vcs: github detected, gh authenticated, target main, one PR per spec
  toggles: constitution on, review on, team off, design_docs off, issue_tracking on
  charter: drafted from the observed conventions (test framework, coverage floor,
           folder style, banned deps); you tweak it
  writes .pact/, appends the CLAUDE.md section, never touches source

/pact:spec feat "rate-limit the public API"
  clarifications: per-IP or per-key? limit + window? 429 body shape?

/pact:plan docs/specs/.../spec.md               (two-pass)
  epic "Rate limiting": 01-01 middleware + config, 01-02 Redis store, 01-03 429 responses
  you approve the breakdown, then the stories

/pact:build
  wave 1: 01-01 + 01-02 in parallel worktrees (docker compose -p pact_w1 / w2)
  wave 2: 01-03 inline
  verification gate: curl the endpoint, observe 429 after N requests

/pact:review     -> PASS
/pact:ship
  preflight, push, PR with "Closes #42", CI green, squash merge,
  proposes a project.md patch ("Redis = rate-limit counters") -> you confirm
```

### A project with a PRD and other docs

```
cd saas-app        # docs/PRD.md, docs/ROADMAP.md, CLAUDE.md, ARCHITECTURE.md
```
```
/pact:init
  detects ADOPT
  the existing-docs scan finds PRD.md, ROADMAP.md, CLAUDE.md, ARCHITECTURE.md
  -> "Use these as source? [Y]"
  project.md is drafted from the PRD (capabilities, users, domain) + ARCHITECTURE.md
     (tech->role, structure), citing "Source: docs/PRD.md" — never copied wholesale
  constitution.md is drafted from the CLAUDE.md rules + code conventions
  CLAUDE.md gets an appended PACT section, existing content untouched
  ROADMAP.md is left as-is — a planning source, not transformed

/pact:config project expand
  reads the PRD, proposes one status:draft spec stub per feature, with depends_on
  where the PRD implies an order (auth before billing, ...)
  you pick the first: SP-001 "signup + login"

/pact:spec SP-001            refine the stub into a full spec
/pact:plan  ...             demo-first epics: 01 = login screen against a fixture auth
                            (runs immediately), 02 = the real auth service, 03 = Integration & E2E
/pact:build --mode flow     auto-chains build -> review -> ship; SP-001 delivered as one PR

/pact:status                shows the queue: SP-002 billing, SP-003 dashboard
/pact:spec SP-002 ...       next spec, one at a time
```
