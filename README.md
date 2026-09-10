# PACT

**P**ragmatic, **A**gent-**C**ontrolled, **T**erminal-based — a spec-driven
software-engineering methodology delivered as a Claude Code plugin.

This README is the user manual: what PACT is, how to install it, and every
command, flag, setting, and file. For the design rationale and the internals, see
[`docs/DESIGN.md`](docs/DESIGN.md).

> **Status: early.** All 15 commands are implemented and the deterministic engine
> (scaffolding, wave planning, view generation, health checks) is tested end to
> end. The model-driven flows have not yet had a full real-world run. Expect
> rough edges in the prompts.

---

## Table of contents

- [What PACT is](#what-pact-is)
- [Install](#install)
- [Core concepts](#core-concepts)
- [The workflow](#the-workflow)
- [Command reference](#command-reference)
- [Configuration reference](#configuration-reference)
- [Execution modes](#execution-modes)
- [Resource isolation](#resource-isolation)
- [Walkthroughs](#walkthroughs)
- [Files PACT creates](#files-pact-creates)
- [Status line](#status-line)
- [Hooks](#hooks)
- [Updating & releases](#updating--releases)
- [FAQ](#faq)
- [License](#license)

---

## What PACT is

PACT turns an idea into merged code through four moves the agent drives from the
terminal:

```
spec  ->  plan  ->  build  ->  ship
```

- **spec** — the precise *what*, written as a reviewable document. Nothing is
  coded without one.
- **plan** — the *what* becomes epics and stories with dependencies.
- **build** — stories are implemented with Test-Driven Development, in
  dependency-ordered parallel waves.
- **ship** — a conventional commit, a pull request, issue links, a merge.

Everything else — `init`, `design`, `team`, `review`, `fix`, `security`,
`status`, `check`, `config`, `adr`, `migrate` — is support around that spine.

### Principles

- **Pragmatic.** Ceremony scales to the work. A one-line chore does not get an
  epic. `lite` mode is the spine only; `full` adds governance and quality layers.
  Configuration is long and upfront so execution runs without interruption.
- **Agent-Controlled.** The agent owns the loop: routing, hand-offs, subagent
  fan-out, the TDD cycle, the QA loop, state in frontmatter. Anything countable
  or mechanical — numbering, wave planning, view rendering, resource allocation,
  health checks — runs in POSIX shell scripts, never in the model.
- **Terminal-based.** Driven entirely from Claude Code. No mandatory web step.
  Skills use browser automation, artifacts, and design tooling when the task
  benefits, and degrade cleanly when those are absent.

### What it keeps honest

- **One writable source of truth per story: its file's YAML frontmatter.** Every
  index (`STORIES_INDEX.md`, `FEATURE_INDEX.md`, the decisions index) is a
  generated, read-only view — a pure function of the frontmatter, so it cannot
  drift. There is no reconciler.
- **Two orthogonal axes.** `status` (`todo -> in-progress -> done`, plus `skip`,
  `bug`) is the work itself. `delivery` (empty `-> pr -> merged`, or `direct`) is
  how far it travelled toward the trunk. "Done" and "shipped" are different
  facts.
- **TDD is not optional.** RED before GREEN, in `lite` and `full`, no exception.
- **Decision Records are always on.** Every significant choice with real
  alternatives is recorded, and immutable once accepted.
- **One active spec at a time.** From `build` through merge, one spec holds the
  lock. New spec branches are always cut from an up-to-date target branch, so
  cross-spec merge conflicts cannot arise.

### What PACT does not do

- It is not portable — Claude Code only.
- It does not manage CI/CD or deployment. Those are project-specific; make them a
  normal `spec`. `ship` stops at commit + push + PR + merge.
- It never commits a hook that blocks a session. `pact check` warns, passively,
  if `.pact/` is present but the plugin is not enabled.

---

## Install

PACT is a Claude Code plugin. The public repository **is** its marketplace.

### Once per machine

```
/plugin marketplace add melchimaelran/pact
/plugin install pact@pact
```

Restart the session. The `/pact:*` commands are now available.

### Once per project

```
/pact:init
```

`init` runs the questionnaire, writes `.pact/`, and adds the plugin to the
project's `.claude/settings.json` `enabledPlugins`. Commit `.pact/`,
`.claude/settings.json`, `CLAUDE.md`, and `.gitignore`.

### Dormant everywhere else

An installed plugin that a project has not opted into does nothing: no commands
run, the `SessionStart` hook is silent, the status line prints nothing. The only
cost is a few hundred tokens of command descriptions in the session prompt.

### For local development of PACT itself

The marketplace accepts a local path:

```
/plugin marketplace add /absolute/path/to/pact
/plugin install pact@pact
```

Iterate on the files, `/plugin update pact@pact`, restart.

### A teammate joining a PACT project

1. `/plugin marketplace add melchimaelran/pact` then
   `/plugin install pact@pact` (once, their machine).
2. Open the project — `.claude/settings.json` already carries the
   `enabledPlugins` entry, so PACT is active.
3. If they have not installed the plugin, `SessionStart` prints the install hint.
   It never blocks.

---

## Core concepts

### The four project documents

Four documents let the agent build correctly; everything else is generated or
optional.

| Document | Answers | Mandatory? |
|---|---|---|
| `.pact/project.md` | what the app is, for whom, why; which tech does what; where things live | always |
| `.pact/stack.toml` | how to install, test, lint, build, and run it | always (config, not prose) |
| `.pact/constitution.md` | the rules the code must obey | `full`; recommended in `lite` |
| `docs/specs/<date>_<slug>/spec.md` | the precise *what* of one change | one per piece of work |

`project.md` is kept current by `ship` (it proposes a patch when a merged spec
changes the structure). The constitution is the project's standing rules — *not*
the method's own rules (TDD, SOLID, the QA loop are always on regardless).

### Spec-driven

Nothing is coded without a spec. The spec is the source of truth for the *what*,
the constitution for the *rules*, the decision records for the *why*, and story
frontmatter for the *state*. Specs are authored progressively — one at a time, as
work is decided, not dumped upfront. Day one is `/pact:init` -> `project.md`. Then
`/pact:spec` per decision to build.

### Spec types

Every spec is typed, and the type is the conventional-commit prefix it will use.
The seven types resolve to three work shapes:

| Shape | Types | Why it needs its own handling |
|---|---|---|
| Planning + TDD of new behavior | `feat`, `adjust` | needs epics / stories |
| Constrained change with a safety property | `fix` (reproduce + failing test first, never write the fix during diagnosis), `refactor` (invariants frozen, no behavior change), `perf` (measured baseline + target) | a uniform flow would let the agent skip the constraint |
| Direct small change | `chore`, `docs` | forcing `plan` on "bump a dep" is pure ceremony |

The type is a label — it does not create a separate pipeline. The flow is always
`spec -> plan -> build -> ship`, and `plan` picks depth from the spec's content.

### State model

Story state lives only in the story file's frontmatter:

```yaml
---
id: 01-02              # epic-story, unique across the whole project
title: Contact form component
epic: 01
spec: SP-003
type: feat             # inherited from the spec
status: todo           # todo -> in-progress -> done  (+ skip, bug)
delivery: ""           # "" -> pr -> merged   (or "direct")
blocked_by: []         # ["01-01", ...] story ids in the same plan
prior_status: ""       # status before it became bug
issue: ""              # GitHub issue number, when issue tracking is on
pr: ""                 # PR number after ship
---
```

`blocked_by` resolves against `status: done` only. Bug flow: `done -> bug` (set
by `fix`, previous status kept in `prior_status`) `-> done` (restored by `build`
bug-fix mode).

### Decision Records

Always on. `docs/decisions/NNNN-slug.md`, sequential. Scope is any significant
decision (architecture, product, tooling, process, naming, tradeoff). Sections:
Context, Decision, Alternatives considered, Consequences. Immutable once
`accepted` — a change is a new DR that supersedes the old one. `spec`, `plan`,
`build`, and `review` propose one when a decision has real alternatives **and**
is hard to reverse, cross-feature, or contradicts a standing document — after
checking the index so the same decision is never recorded twice. Create one by
hand with `/pact:adr`.

### lite vs full

The pipeline is identical in both modes — `spec -> plan -> build -> ship`, with
TDD, parallel waves, and Decision Records, always. `full` adds layers:

| Aspect | `lite` | `full` |
|---|---|---|
| `spec` clarification | leans harder on defaults | asks until no material ambiguity |
| `plan` | epics + stories, minimal detail; one-pass | + edge cases, test notes, task breakdown, explicit dependency graph; two-pass |
| `constitution` | off (advisory if on) | on, gated |
| `review` | off | on, and gates `ship` |
| `design` / `team` / issue tracking | off | offered at `init` |
| `preflight` (re-lint/test before commit) | off | on |
| model tiers / review effort | conservative defaults | tunable, deep review available |
| verification gate | text steps | drives the tool when available |

Switch any time with `/pact:config`. Turning `full` on offers a backfill.

---

## The workflow

```
/pact:init
   |
/pact:spec  <type> "..."          write the spec, answer clarifications
   |
[ /pact:design ]                  optional: architecture docs (steps.design_docs)
   |
[ /pact:team ]                    optional: project-tailored skills (steps.team)
   |
/pact:plan  <spec.md>             epics + stories
   |
/pact:build                       TDD waves
   |
[ /pact:review ]                  optional: feature-level audit (steps.review)
   |
/pact:ship                        commit, PR, merge
```

Anytime: `/pact:status`, `/pact:check`, `/pact:config`, `/pact:adr`,
`/pact:security`. For a bug: `/pact:fix`.

### Hand-offs

Each finished command offers the next as a one-click, with arguments already
filled in. You say yes or no. Nothing auto-chains — **except** under
`build --mode flow`, which runs `build -> review -> ship` straight through while
nothing blocks. Chain depth is capped at 3, and a command may never invoke one
already on the chain (so `fix -> build -> fix` is impossible).

### Routing checks

Every action command first asks "am I the right command?" If the real task
belongs elsewhere it stops and tells you which command to use — for example
`plan` invoked with no spec sends you to `spec`, and `build` invoked on an
un-triaged bug sends you to `fix`.

---

## Command reference

Syntax: `/pact:<name> [arguments]` inside a Claude Code session. The deterministic
parts are also runnable as `pact <subcommand>` in a terminal where the plugin's
`bin/` is on `PATH`.

### `pact init`

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

### `pact spec`

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

### `pact design` *(optional)*

```
/pact:design <spec.md>       generate feature-scoped architecture docs
/pact:design sync            scaffold docs for features that lack one
/pact:design optimize        dedup shared content into _shared.md
```

Runs only when `[steps].design_docs` is on. Produces global docs
(`overview.md`, `folder-structure.md`, `tech-stack.md`, `_shared.md`) plus one
self-contained `docs/architecture/features/<slug>/index.md` per feature
(Components, Data, Flows, API). `plan` reads these to cut better stories. With the
toggle off, `plan` works from the spec, `project.md`, and the code directly.

### `pact team` *(optional)*

```
/pact:team [--basic | --standard | --max] [--regenerate] [--check]
```

Runs only when `[steps].team` is on. Derives project-tailored skills into
`.claude/skills/` — `guide-<language>`, `guide-<framework>`, `expert-qa`, and
specialists a real signal justifies (`expert-security` when auth or secrets,
`expert-database` when a schema, `expert-api` when routes). Each carries `paths:`
globs so `build` auto-loads the relevant ones. `--regenerate` refreshes them
merge-safe, preserving any `## House rules` you added. Version-specific research
is opt-in via `[team].context7` (off by default — token cost).

### `pact plan`

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

### `pact build`

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

### `pact review` *(optional)*

```
/pact:review [--effort quick|standard|deep] [--passes N] [--model M]
/pact:review --project
```

Runs only when `[steps].review` is on. A feature-level audit of the whole spec —
every story together — that `build` already took to green per story. Checks
spec-level acceptance-criteria coverage, consistency against the plan, the
constitution, accepted DRs, and `project.md`, and a whole-diff code review
(SOLID, feature-level redundancy, edge cases, security, error handling). It does
not re-run the test suite unless the branch moved since `build`'s green or
`[review].fresh_suite` asks for it. Verdict `PASS` / `NEEDS_FIXES`; it auto-fixes
low/medium findings and hands CRITICAL/HIGH back to a targeted `build`.

`--project` audits the whole codebase against `project.md`, accepted DRs, and the
constitution, and emits `refactor` / `chore` spec stubs for the drift it finds.
It blocks nothing.

`--effort deep` fans out independent passes (correctness, security,
architecture) and merges the findings.

### `pact ship`

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

### `pact fix`

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

### `pact security`

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

### `pact status`

```
/pact:status [--write]
```

Read-only dashboard, rendered by a script — zero model tokens. Shows the spec
counts, the active spec's stories, live worktrees, and the wave lock. `--write`
also dumps a generated `tasks/ROADMAP.md` snapshot. Does not gate on schema, so
it works even when a migration is pending.

### `pact check`

```
/pact:check [--quiet]
```

Health report. Flags a schema mismatch, unparseable frontmatter, an index that
has drifted from the stories, an unresolvable `blocked_by`, an orphan spec
branch, a missing `.gitignore` block, and uncommitted `.pact/`. Each finding
names the command that fixes it. Exit status is non-zero if any error-level
finding exists. Read-only.

### `pact config`

```
/pact:config show                       print the current settings
/pact:config statusline install         install the main status line
/pact:config project expand             turn project.md into a fuller PRD (+ spec stubs)
/pact:config <what to change>           free text — e.g. "turn on review", "squash merges"
```

The conversational editor for `.pact/config.toml`, `.pact/stack.toml`, and the
constitution. You never hand-edit those files. Turning a step on offers the
matching backfill; editing the constitution bumps its version.

### `pact adr`

```
/pact:adr "<the decision>"
```

Create a Decision Record by hand. The agent drafts the four sections from the
conversation and the repo, you confirm, and the file is written with the next
sequential number and the index regenerated. It checks the index first and will
not record the same decision twice.

### `pact migrate`

```
/pact:migrate
```

Upgrades the project's `.pact/` layout to the schema this plugin build supports.
One-shot, idempotent, refuses a dirty tree, applies each migration step in order
across versions, restamps the schema, regenerates the views, and lands everything
in one revertable commit. Every write-command refuses to run on a schema
mismatch and points here; read-only commands (`status`, `check`) still work.

---

## Configuration reference

Two files under `.pact/`, both written and edited only through `/pact:init` and
`/pact:config`. `docs/DESIGN.md` has the annotated originals; the tables below are
the semantic reference.

### `config.toml`

| Key | Values | Effect |
|---|---|---|
| `schema` | integer | the `.pact/` layout version; the migration gate checks it |
| `language.technical` | `en` | fixed — all on-disk output is English |
| `language.communication` | `en` `fr` `es` `de` `pt` `it` `ja` `zh` `ko` or free text | the language the agent talks to you in |
| `mode.flow` | `lite` `full` | the spine only, or the spine plus governance/quality layers |
| `steps.constitution` | bool | the charter is active and gated (`full`) or advisory (`lite`) |
| `steps.review` | bool | `/pact:review` exists and, with `review_gate`, blocks `ship` |
| `steps.team` | bool | `/pact:team` generates project-tailored skills |
| `steps.design_docs` | bool | `/pact:design` maintains `docs/architecture/` |
| `steps.issue_tracking` | bool | GitHub Issues integration (github only) |
| `workflow.pr_per` | `spec` `story` | one PR per spec, or one per story into the spec branch |
| `workflow.merge_strategy` | `squash` `merge` `rebase` | how the spec branch lands |
| `workflow.commit_style` | `conventional` `simple` | commit message shape |
| `workflow.branch_prefix` | string | prefix for story branches |
| `workflow.preflight` | bool | re-run lint + test just before the ship commit (skipped when the branch is unchanged) |
| `workflow.review_gate` | bool | a `NEEDS_FIXES` review blocks `ship` |
| `workflow.ci_gate` | bool | wait for green CI before merging |
| `workflow.deploy_prompt` | `on-merge` `manual` `none` | the post-merge deploy reminder (PACT never deploys) |
| `workflow.confirm_story_plan` | bool | pause for approval before each story's phase-1 plan |
| `workflow.manual_gate` | `drive` `steps` `off` | drive the verification tool, print steps, or skip |
| `workflow.max_parallel` | integer | cap on concurrent worktree agents |
| `workflow.default_exec_mode` | `step` `wave` `spec` `flow` `dry` | the default execution mode for a build |
| `build.model_fast` / `model_balanced` / `model_advanced` | `haiku` `fable` `sonnet` `opus` | the three build tiers |
| `build.effort` | `high` … | reasoning depth per story |
| `review.effort` | `quick` `standard` `deep` | how thorough a review is |
| `review.model` | `auto` or a tier | the reviewer's model |
| `review.passes` | integer | independent review passes to merge |
| `review.auto_fix` | `off` `low` `low+medium` | severities the reviewer fixes itself |
| `review.fresh_suite` | bool | re-run the suite even when `build`'s green still holds |
| `spec.effort` / `plan.effort` | `high` … | reasoning depth |
| `plan.confirmation` | `two-pass` `one-pass` | validate epics then stories, or all at once |
| `team.depth` | `basic` `standard` `max` | how many expert/guide skills to generate |
| `team.context7` | bool | fetch version-specific framework docs (token cost) |
| `design.system` | `auto` `claude-design` `none` | UI design source — auto uses the official frontend-design plugin if present, else `.pact/design.md` |

### `stack.toml`

| Key | Meaning |
|---|---|
| `stack.languages` | list, e.g. `["typescript"]` |
| `stack.frameworks` | list, e.g. `["nestjs", "nextjs"]` |
| `stack.package_manager` | `pnpm` `npm` `yarn` `bun` `pip` `poetry` `uv` `cargo` `go` … |
| `stack.runtime` | e.g. `node@22`, `python@3.12` |
| `stack.monorepo` | bool — when true, add a `[stack.packages.<name>]` block per package |
| `env.containerized` | bool |
| `env.compose_file` | path to `docker-compose.yml` |
| `env.isolation` | `auto` `docker-compose` `inline-env` `serialize` — how parallel worktrees avoid port/DB collisions |
| `env.setup` | install dependencies |
| `env.test` | the full test suite |
| `env.test_one` | run one test file; `{path}` is substituted |
| `env.lint` | linter |
| `env.typecheck` | type checker; empty string = skip |
| `env.build` | compile / bundle |
| `env.dev` | run the app (for the verification gate) |
| `env.format` | formatter for the PostToolUse hook; empty string = no auto-format |
| `vcs.platform` | `github` `gitlab` `gitea` `local` |
| `vcs.default_branch` | the branch every PR targets |
| `vcs.has_gh_cli` | bool, set at `init` |
| `vcs.project_board` | bool — mirror story status to a GitHub Projects board |
| `vcs.min_approvals` | required human PR approvals before `ship` merges |

---

## Execution modes

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

## Resource isolation

When a wave runs several stories at once, each worktree needs its own ports,
database, and cache so the test runs do not collide. There is **no file to
configure** — `init` picks a per-project strategy:

| `env.isolation` | Behavior |
|---|---|
| `docker-compose` | each worktree runs under `docker compose -p pact_w<N>` |
| `inline-env` | `PORT` and `DATABASE_URL` are prefixed onto each command |
| `serialize` | the wave runs one story at a time — no parallelism, no worktrees |
| `auto` (default) | detect; fall back to `serialize` when isolation cannot be guaranteed |

---

## Walkthroughs

### A new project

```
mkdir portfolio && cd portfolio && git init
```
```
/pact:init
  detects NEW
  language + flow: lite
  project context: "personal portfolio, shows projects + a contact form"
  stack: preset next-only -> pnpm commands filled; not containerized; isolation inline-env
  vcs: github, target main, one PR per spec
  (lite -> optional toggles skipped)
  scaffolds .pact/, tasks/, docs/, CLAUDE.md, the .gitignore block

/pact:spec feat "contact section with a working form"
  the agent drafts, then asks: how is the message delivered? spam handling?

/pact:plan docs/specs/2026-.../spec.md          (one-pass, lite default)
  1 epic, 3 stories: form component / send action / wiring + validation + states

/pact:build                                     (mode: spec -> runs through)
  wave 1: form component + send action in parallel
  wave 2: wiring (blocked_by both) inline
  verification gate: fill the form, submit, see the success state

/pact:ship                                      commit, push, PR, squash merge
```

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

---

## Files PACT creates

| Path | Committed? | What |
|---|---|---|
| `.pact/config.toml` | yes | project configuration |
| `.pact/stack.toml` | yes | stack + environment + VCS |
| `.pact/project.md` | yes | the project brief |
| `.pact/constitution.md` | yes | the rules (if enabled) |
| `.pact/design.md` | yes | UI direction (unless `design.system = claude-design`) |
| `.pact/charter-overrides.log` | yes | the audit trail of accepted charter violations |
| `.pact/wave.lock` | no | transient, exists only during a build |
| `.pact/green` | no | per-branch record of the last full-suite green |
| `.pact/cache/`, `.pact/tmp/` | no | scratch |
| `pact-wt/` | no | build worktrees |
| `tasks/<date>_<slug>/` | yes | a plan: `PROJECT_OVERVIEW.md`, `epics/*/EPIC.md`, `epics/*/stories/*.md`, `ROADMAP.md` |
| `tasks/<slug>/STORIES_INDEX.md` | yes | generated view — one row per story |
| `tasks/FEATURE_INDEX.md` | yes | generated view — one row per spec |
| `docs/specs/<date>_<slug>/spec.md` | yes | a spec |
| `docs/decisions/NNNN-slug.md` | yes | a Decision Record |
| `docs/decisions/README.md` | yes | generated view — the DR table |
| `docs/architecture/**` | yes | if `design_docs` is on |

`init` writes a managed block into `.gitignore`:

```
# --- PACT (managed) ---
.pact/wave.lock
.pact/green
.pact/cache/
.pact/tmp/
pact-wt/
# --- end PACT ---
```

`pact check` flags a missing block, or a `.gitignore` line that would exclude
`.pact/` wholesale (which breaks sharing).

---

## Status line

- **Per-agent rows** during build waves ship enabled automatically.
- **The main status line** must live in your user or project `settings.json` — a
  plugin cannot set it. Install it with `/pact:config statusline install` (choose
  user-level or project-level). It renders

  ```
  PACT SP-003 contact-section 2/3 · wt: 01-03
  ```

  the active spec and slug, stories done/total, and any live worktrees. It is
  drawn by the terminal, costs no model tokens, and prints nothing outside a PACT
  project — so a user-level install is safe everywhere.

---

## Hooks

- **`SessionStart`** — silent outside a PACT project. Inside one it prints, at
  most: a schema-mismatch notice, a plugin-not-enabled hint, the condensed
  project state, a stale-index flag, and an uncommitted-`.pact/` note.
- **`PostToolUse`** on `Write` / `Edit` / `MultiEdit` — formats the file just
  written with `env.format`, if one is configured. Silent on success, never
  fails the edit.
- **`PreToolUse`** (while `ship`, `build`, `fix`, `spec` run) — blocks any
  `git` / `gh` command carrying an AI-authorship trailer or footer. It matches
  the trailer forms only.

---

## Updating & releases

Update an installed plugin:

```
/plugin update pact@pact
```

then restart the session. If the marketplace metadata changed, run
`/plugin marketplace update pact` first.

A schema bump ships a migration step, so after an update a project whose
`.pact/` is behind will be gated until `/pact:migrate` runs — a one-shot,
revertable commit.

Maintainers cut a release with the repo-local `release` skill: it bumps the
version in `plugin.json` and `marketplace.json`, rolls the changelog, tags
`vX.Y.Z`, and creates the GitHub Release. It refuses to run from a non-`main`
branch, on a dirty tree, or without a migration step when the `.pact/` layout
changed, and it asks before pushing the tag.

---

## FAQ

**Do I have to install it globally?**
Installing the plugin makes it available; it only runs where `/pact:init` opted
it in. Everywhere else it is inert.

**Does an installed-but-dormant plugin cost tokens?**
A few hundred, for the command descriptions in the session prompt. Nothing else
loads until a command runs.

**Can I run two builds at once?**
No. One spec holds the active lock from `build` through merge. Many specs can be
*drafted* and *planned* concurrently — those touch no code.

**What if I skip the spec and just start coding?**
PACT will not. Every piece of work starts with `/pact:spec`. A one-line change is
a `chore` or `docs` spec that skips `plan` and goes straight to `build`.

**Does it work without GitHub?**
Yes — `vcs.platform = local` does commits and local merges with no PR. GitHub
Issues and Projects are optional add-ons.

**Can I turn `full` features on later?**
Yes, with `/pact:config`. Turning one on offers a backfill for the existing plan.

---

## License

[MIT](LICENSE)
