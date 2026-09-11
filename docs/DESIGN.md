# PACT — Design

**PACT** — **P**ragmatic, **A**gent-**C**ontrolled, **T**erminal-based.

A spec-driven software-engineering methodology delivered as a Claude Code plugin.

This document is the **design reference** — the rationale, the internals, and the
contract each part must honor. It does not repeat the usage docs:

- [`../README.md`](../README.md) — the pitch, the quickstart, the concepts.
- [`COMMANDS.md`](COMMANDS.md) — every command's syntax and behavior, plus
  worked walkthroughs.
- [`CONFIG.md`](CONFIG.md) — every configuration key, the files PACT creates, the
  hooks, the status line.

> **Language rule.** This repository, and everything PACT writes to disk in a
> project (specs, plans, the constitution, decision records, commit messages, PR
> bodies, branch names, phase summaries), is **English only**. Only the live chat
> between the agent and the user follows the project's `language.communication`
> setting.

---

## 1. What PACT is

PACT turns an idea into merged code through four moves the agent drives from the
terminal:

```
spec  →  plan  →  build  →  ship
```

- **spec** — the precise *what*, written as a reviewable document. Nothing is coded
  without one.
- **plan** — the *what* becomes epics and stories with dependencies.
- **build** — stories are implemented with Test-Driven Development, in
  dependency-ordered parallel waves.
- **ship** — a conventional commit, a pull request, issue links, a merge.

Everything else PACT provides — `init`, `design`, `team`, `review`, `fix`,
`security`, `status`, `check`, `config`, `adr`, `migrate` — is support around
that spine.

### Philosophy

- **Pragmatic.** Ceremony scales to the work. A one-line chore does not get an
  epic. `lite` mode is the spine only; `full` adds governance and quality layers.
  Configuration is long and upfront so execution runs without interruption.
- **Agent-Controlled.** The agent owns the loop: routing, hand-offs, subagent
  fan-out, the TDD cycle, the QA loop, state in frontmatter. Deterministic work
  (numbering, wave planning, view rendering, resource allocation) runs in scripts,
  never in the model.
- **Terminal-based.** Driven entirely from Claude Code — no mandatory web step.
  "Terminal-based" does not mean text-only: skills use Claude-in-Chrome, Artifacts,
  and the official `frontend-design` plugin when the task benefits, gated by
  availability and config, degrading cleanly when absent.

### Non-goals

- Not portable. PACT targets Claude Code only. (Skill *logic* lives in
  `references/*.md` contracts and `bin/pact` scripts, which are agent-agnostic; the
  `SKILL.md` files are thin Claude Code adapters. This keeps a future port cheap
  without paying for portability now.)
- Does not manage CI/CD or deployment. Those are project-specific and can be a
  normal `spec`. `ship` stops at commit + push + PR + merge.
- No invasive guard. PACT never commits a hook that blocks a session. `pact check`
  warns, passively, if `.pact/` is present but the plugin is not enabled.

---

## 2. Distribution & rationale

**Plugin only.** No npm CLI. The public repository *is* the marketplace. The
install and update commands, and the dormant-when-not-opted-in behavior, are in
the [README](../README.md#quickstart) and [CONFIG.md](CONFIG.md). This section covers the reasoning behind that
shape.

### Why plugin-only

A CLI would need its own install path, its own update story, and a second surface
to keep in sync with the skills. The plugin mechanism already gives per-project
opt-in (`enabledPlugins`), atomic updates, and one place for skills, agents,
hooks, and scripts. The cost — no portability — is one PACT already accepts
(§1 non-goals).

### Stability commitment

- `.pact/config.toml` carries `schema = N`.
- Every write-command version-gates on it. A mismatch blocks and offers
  `pact migrate`.
- `pact migrate` is one-shot, idempotent, refuses a dirty tree, lands all changes
  in one revertable commit, and chains across schema versions.
- The plugin is semver'd. Breaking `.pact/` changes only on a major version.

### Publishing & releases

There is no central store — the public repo *is* the marketplace (`.claude-plugin/`
holds `plugin.json` and a `marketplace.json` with one entry, `source: "./"`). The
release procedure is automated by the repo-local `release` skill and summarized
for users in the [README](../README.md#updating). The design constraint:
a release bumps the `schema` template value **only** when the `.pact/` layout
changes, and only a major version when that change is breaking to an existing
project — so `pact migrate` always has a defined, tested path from any older
schema.

### Idle token cost

An installed-but-dormant plugin still puts each skill's `name` + `description` in
the session (roughly 1–3k tokens, in every session, PACT project or not). Skill
bodies, agent bodies, and hook output cost nothing until used, and
`session-start.sh` prints nothing outside a PACT project. Mitigations to target in
implementation: keep every `description` to one tight sentence; register PACT
skills as **deferred** (loaded on demand) so the idle cost approaches zero; gate
skill exposure on `.pact/` presence if the platform allows it.

### Per-run token economy

The design keeps a working run lean by construction:

- **Shared context is read once.** The orchestrator loads `project.md`,
  `constitution.md`, `stack.toml`, and relevant DRs a single time and passes them
  into each wave agent's prompt; agents never re-read them (§9).
- **A green test run is recorded against a SHA and reused.** `build` runs the
  suite to green; `review` and `ship` do not re-run an identical suite — only when
  the branch moved, or when `[review].fresh_suite` asks for it (§10, §11).
- **Deterministic work is scripts, not the model.** Wave planning, index
  regeneration, dashboards, status, resource allocation — zero model tokens.
- **Index views regenerate once per wave**, plus on `build` exit — not per story.
- **One decision, one DR.** A phase checks the DR index before proposing; no
  duplicate proposals across `spec` / `plan` / `build` / `review` (§12).
- **Progress tracking only where it earns its cost** — long multi-phase commands,
  not short linear ones (§21).
- **Optional layers are off by default.** `design_docs`, `team`, `review` are
  opt-in; `lite` is the four-command spine with none of them. No mandatory
  architecture-doc or expert-skill generation.
- **Reference files are few and dense** (6–8), each read at most once per run.

---

## 3. Core concepts

### The four project documents

To build correctly on a project, the agent must be able to answer five questions.
Four documents cover them; everything else is generated or optional.

| Question | Document | Mandatory? |
|---|---|---|
| What is it, for whom, why + which tech for what + where things live | `.pact/project.md` | always |
| How to install / test / build / run it | `.pact/stack.toml` (`[env]`, `[vcs]`) | always (config, not prose) |
| What rules must the code obey | `.pact/constitution.md` | `full`; recommended in `lite` |
| What is this specific change | `docs/specs/<work>/spec.md` | one per piece of work |

Roadmaps, index views, the `CLAUDE.md` PACT section, and `docs/architecture/` are
**generated** or **optional** — never documents the user writes.

- **`project.md`** — the brief. What the app does, its domain and users, its main
  capabilities, a tech→role map, external systems, hard constraints. In ADOPT mode
  it is drafted from the existing README / PRD / code and cites its sources
  (`Source: docs/PRD.md`); it never copies wholesale and never overwrites
  originals. It is kept current by `ship` (see §15), not by hand.
- **`constitution.md`** — the project's standing rules: test strategy, architecture
  style, code conventions, dependency policy, security baseline, and more (§14).
  These are *not* the method's own rules.

### Spec-driven

Nothing is coded without a spec. The spec is the source of truth for the *what*,
the constitution for the *rules*, the decision records for the *why*, and story
frontmatter for the *state*. Specs are authored by the user progressively — one at
a time, as work is decided — not dumped upfront. Day one is `pact init` →
`project.md`. Then `pact spec …` per decision to build.

### State model

- **One writable source of truth per story: the story file's YAML frontmatter.**
- `STORIES_INDEX.md` and `FEATURE_INDEX.md` are **generated, read-only views**,
  regenerated by script from frontmatter. A view is a pure function of the
  frontmatter, so it cannot drift. There is no reconciler.
- **Two orthogonal axes:**
  - `status` — `todo → in-progress → done` (plus `skip`, `bug`). The work itself.
  - `delivery` — empty `→ pr → merged`, or `direct`. How far it has travelled
    toward the trunk. "Done" and "shipped" are different facts.
- `blocked_by` resolves against `status: done` only, never against `delivery`.

---

## 4. Command set (16 — 11 core + 5 optional/utility)

| Command | Role |
|---|---|
| `pact help` | The command map. Script-rendered, zero model tokens; works before `init` and while a migrate is pending. |
| `pact init` | Initial configuration + scaffold (NEW / ADOPT / RECONFIG). |
| `pact spec` | Typed spec — the entry point for all work. |
| `pact design` | *Optional* (`steps.design_docs`). Spec → feature-scoped architecture docs. |
| `pact team` | *Optional* (`steps.team`). Derive project-tailored expert / guide skills. |
| `pact plan` | Spec → epics / stories (skipped for trivial `chore` / `docs`). |
| `pact build` | Implement — inline, parallel waves, or a whole epic. |
| `pact review` | *Optional* (`steps.review`). Feature-level audit before shipping. |
| `pact ship` | Commit + PR + issue links + merge. |
| `pact fix` | Bug flow (diagnose → failing test → fix plan → build). |
| `pact security` | On-demand security audit → security-fix spec stubs (never auto-runs, never auto-fixes). |
| `pact status` | Read-only dashboard (rendered by script, zero model tokens). |
| `pact check` | Project health report; names the fix for each finding. |
| `pact config` | Conversational editor for config, stack, charter; `statusline install`; `project expand`. |
| `pact adr` | Create a Decision Record by hand. |
| `pact migrate` | Upgrade the `.pact/` schema. |

Every question any command asks offers three paths: **accept** the proposed
best-practice default, pick a **preset** option, or **answer in free text**. Never
forced choice.

---

## 5. `pact init`

### Context detection

`init` classifies the directory automatically; each can be forced with a flag.

| Case | Condition | Behavior |
|---|---|---|
| **NEW** (`--new`) | empty dir (or just `.git`) | full scaffold, long questionnaire |
| **ADOPT** (`--adopt`) | code exists, no `.pact/` | scan the stack, short questionnaire, zero source files touched |
| **RECONFIG** (`--reconfig`) | `.pact/` already present | no re-scaffold, drops to `pact config` |

### Existing-docs scan

Before the project-context block, `init` scans for `CLAUDE.md`, `AGENTS.md`,
`README.md`, `docs/**` (PRD, ROADMAP, ARCHITECTURE, ADRs), `.cursorrules`,
`CONTRIBUTING.md`, root `*.md`. It lists what it found and, on consent, uses them
to pre-fill `project.md` and `constitution.md` (citing sources, never copying
wholesale). `CLAUDE.md` gets an appended, fenced PACT section only. `pact check`
later flags when a cited source has drifted from the digest.

### Questionnaire

Fully conversational. The user never edits a config file by hand. Blocks, in order:

1. **Base** — communication language (`en` / `fr` / `es` / `de` / `pt` / `it` /
   `ja` / `zh` / `ko` / free text; default `en`) · flow mode (`lite` / `full`) ·
   new-or-adopt confirmation if ambiguous.
2. *(existing-docs scan runs here)*
3. **Project context** → `project.md` — what the app does (1–3 sentences) · domain
   and users · main capabilities · tech→role map · external systems · hard
   constraints (optional). ADOPT pre-fills from the scan; the block becomes
   "confirm / correct".
4. **Stack & environment** → `stack.toml` — languages · frameworks · package
   manager · runtime (pinned exact version) · version manager (`fnm` / `nvm` /
   `volta` / `asdf` / `mise` / `pyenv` / `rbenv` / `none`, asked only where the
   runtime is version-sensitive) and its pin file (`.nvmrc`, `.tool-versions`,
   …) · containerized? (compose file path) · env commands (`setup`, `test`,
   `test_one`, `lint`, `typecheck`, `build`, `dev`) · isolation strategy. ADOPT
   pre-fills everything from `package.json` scripts, lockfiles, `Dockerfile`,
   `nest-cli.json`, `pyproject.toml`, a version-pin file, etc. NEW offers a
   stack preset or free-form entry.
5. **VCS & git workflow** → `stack.toml [vcs]` + `config.toml [workflow]` —
   platform (`github` / `gitlab` / `gitea` / `local`); if a remote platform, check
   the CLI is installed and authenticated, else offer `local` · target branch
   (default `main`) · `pr_per` (`spec` default / `story`) · merge strategy
   (`squash` / `merge` / `rebase`) · commit style (`conventional` / `simple`) ·
   `preflight` (on in `full`, off in `lite`) · issue tracking (github + `full`) ·
   GitHub Projects board (if issue tracking).
6. **Optional toggles** → `config.toml [steps]` — in `full` each is *asked* (none
   auto-on); in `lite` all off, block skipped:
   - `constitution` · `review` · `team` · `design_docs` · `design.system`
     (`auto` / `claude-design` / `none`) · `issue_tracking`
7. **Charter** (only if `constitution = on`) — write now (guided, no question cap,
   §14) or later (skeleton, `status: draft`).
8. **Models & effort** → `config.toml` — `build` model tiers
   (`fast`/`balanced`/`advanced` → `haiku`/`sonnet`/`opus` by default) · `review`
   (`effort`, `model`, `passes`, `auto_fix`) · `spec` / `plan` effort (default
   `high`) · `plan` confirmation (`two-pass` default in `full`, `one-pass` default
   in `lite`).

### Scaffold (NEW)

```
.pact/
├── config.toml
├── stack.toml
├── project.md
├── constitution.md        # if steps.constitution — filled or draft skeleton
├── design.md              # if design.system != claude-design — UI direction (tokens, spacing, conventions)
└── charter-overrides.log  # append-only
tasks/                     # empty; filled by pact plan
docs/
├── specs/                 # empty
└── decisions/             # empty
CLAUDE.md                  # created or appended: fenced PACT section
.claude/settings.json      # enabledPlugins entry; optional statusLine
```

`wave.lock` is a transient, gitignored file that exists only during a `build` run.

ADOPT produces the same layout; `stack.toml` and `constitution.md` are pre-filled
from the scan and `CLAUDE.md` is appended, not overwritten.

### `.gitignore`

`init` writes a managed block into `.gitignore` (the rest of the file untouched):

```
# --- PACT (managed) ---
.pact/wave.lock
.pact/green
.pact/cache/
.pact/tmp/
pact-wt/
# --- end PACT ---
```

**Committed** (shared project state): `.pact/config.toml`, `stack.toml`,
`project.md`, `constitution.md`, `design.md`, `charter-overrides.log`; `tasks/**`;
`docs/specs/**`, `docs/decisions/**`, `docs/architecture/**`; `CLAUDE.md`;
`.claude/settings.json` (the `enabledPlugins` entry).

**Ignored** (transient / per-machine): `.pact/wave.lock`, `.pact/green`,
`.pact/cache/**`, `.pact/tmp/**`, `pact-wt/**`.

`pact check` flags a missing managed block, or a `.gitignore` line that excludes
`.pact/` wholesale (which would break sharing).

---

## 6. Configuration reference

### `.pact/config.toml`

```toml
schema = 1

[language]
technical     = "en"          # fixed, non-editable
communication = "fr"          # en|fr|es|de|pt|it|ja|zh|ko|<free text>

[mode]
flow = "lite"                 # lite | full

[steps]
constitution   = false
review         = false
team           = false
design_docs    = false
issue_tracking = false        # github only

[workflow]
pr_per             = "spec"          # spec | story
merge_strategy     = "squash"        # squash | merge | rebase
commit_style       = "conventional"  # conventional | simple
branch_prefix      = "story/"
preflight          = false           # re-run lint + test right before commit
review_gate        = false           # NEEDS FIXES blocks ship (independent of steps.review)
ci_gate            = false           # wait for green CI before merge
deploy_prompt      = "on-merge"      # on-merge | manual | none — a reminder only
confirm_story_plan = false           # ask before each story's phase-1 plan
manual_gate        = "steps"         # drive | steps | off
max_parallel       = 4
default_exec_mode  = "wave"          # step | wave | spec | flow | dry — default when a spec build starts

[build]
model_fast = "haiku"; model_balanced = "sonnet"; model_advanced = "opus"
effort = "high"

[review]
effort       = "standard"   # quick | standard | deep
model        = "auto"       # auto | haiku | fable | sonnet | opus
passes       = 1
auto_fix     = "low"        # off | low | low+medium
fresh_suite  = false        # re-run the full test suite even when build's green still holds (default true in full)

[spec]
effort = "high"

[plan]
effort       = "high"
confirmation = "two-pass"   # two-pass | one-pass

[team]
depth    = "standard"    # basic | standard | max
context7 = false         # explicit choice; on = version-specific docs (token cost)

[design]
system = "auto"          # auto | claude-design | none
```

### `.pact/stack.toml`

```toml
[stack]
languages       = ["typescript"]
frameworks      = ["nestjs", "nextjs"]
package_manager = "pnpm"
runtime         = "node@22.11.0"
version_manager = "fnm"           # fnm | nvm | volta | asdf | mise | pyenv | rbenv | none
version_file    = ".nvmrc"        # "" if none
monorepo        = false

[env]
containerized = false
compose_file  = ""
isolation     = "auto"            # auto | docker-compose | inline-env | serialize
setup     = "pnpm install"
test      = "pnpm test"
test_one  = "pnpm test {path}"    # {path} = the targeted file
lint      = "pnpm lint"
typecheck = "pnpm tsc --noEmit"   # "" = skip this step
build     = "pnpm build"
dev       = "pnpm dev"

# monorepo only — one block per independently-built package
# [stack.packages.api]
# path = "apps/api"
# test = "pnpm --filter api test"

[vcs]
platform       = "github"   # github | gitlab | gitea | local
default_branch = "main"
has_gh_cli     = true
project_board  = false
min_approvals  = 0          # human PR approvals required
```

---

## 7. `pact spec`

The mandatory front door. A spec is a technical document that respects norms — not
stakeholder prose. The agent drafts ~90%; the user steers the real decisions and
edits freely.

### Types

Seven types, aligned 1:1 with conventional-commit prefixes. They resolve to three
work shapes:

| Shape | Types | Why it needs its own handling |
|---|---|---|
| Planning + TDD of new behavior | `feat`, `adjust` | needs epics / stories |
| Constrained change with a safety property | `fix` (reproduce + failing test first, never write the fix during diagnosis), `refactor` (invariants frozen, no behavior change), `perf` (measured baseline + target, else "faster" is unfalsifiable) | a uniform flow would let the agent skip the constraint |
| Direct small change | `chore`, `docs` | forcing `plan` on "bump a dep" is pure ceremony |

The type is a label: it becomes the commit prefix, the PR label, the changelog
section. It does **not** create a separate pipeline — the flow is always
`spec → plan → build → ship`, and `plan` picks depth from the spec's content.

### Template

One common frontmatter + one section set; sections that do not apply are removed,
not left as "N/A".

```yaml
---
id: SP-NNN
type: feat            # feat | fix | adjust | refactor | perf | chore | docs
slug: <kebab>
status: draft          # draft → ready → planned → done
created: YYYY-MM-DD
charter_version: X.Y.Z
depends_on: []         # other spec ids that must be merged first
target: ""             # for adjust / refactor / perf: the spec id or feature slug being changed
---

## Context            — why, current state, trigger. For a bug: where and when it breaks.
## Goal               — numbered, precise outcomes.
## Scope / In
## Scope / Out        — explicit non-goals.
## Requirements       — R1, R2… each testable. For a bug: reproduction + expected vs actual.
## Acceptance Criteria — [ ] AC1… verifiable, observable.
## Constraints        — technical limits, charter rules that bite here, invariants that must
                         not change, perf baseline/target, "smallest diff" — whatever applies.
## Clarifications     — ### Session <date> + Q/A bullets.
## Open Questions     — unresolved, non-blocking.
```

The safety properties live in the spec content, enforced by the universal TDD loop
in `build`:

- **bug** — Acceptance Criteria include "the reproduction test goes green" and "no
  regression"; the RED phase *is* the reproduction, so a fix is never written
  before a failing test exists.
- **refactor** — Constraints list the invariants; Acceptance Criteria say
  "existing tests stay green, no behavior change".
- **perf** — Constraints carry the baseline and target numbers; Acceptance
  Criteria say "target met, measured the same way".
- **chore / docs** — Scope is tiny; Acceptance Criteria are the check (build / lint
  green; links valid; examples compile/run; code-derived reference docs
  regenerated from source).

### Clarification

No question cap. The agent asks as many as needed, **one at a time**, each recorded
in `## Clarifications` as it is answered. It stops when no material ambiguity
remains, or when the user says stop. The user can cut it off at any point.

### Routing

`spec` resolves `$ARGUMENTS` against on-disk state: a slug or path to an existing
spec → ADJUST that spec; free text or unknown path → CREATE. `depends_on` is set
when the work needs another spec's code.

---

## 8. `pact plan`

Input: a `spec.md` at `status: ready`. Output depends on content, not on the type:

| Spec content | `plan` produces |
|---|---|
| substantial new behavior | epics + stories + roadmap |
| one small change | a single story |
| trivial, no code structure | a single task, straight to `build` |

### Confirmation mode

`[plan].confirmation`:

- **two-pass** (default in `full`) — (1) propose the epic breakdown (names, order,
  demo-first rationale, rough story count per epic) → user validates / adjusts;
  (2) detail the stories → user validates / adjusts → generate files.
- **one-pass** (default in `lite`) — everything at once, one validation.

Override per run with `--one-pass`.

### Epic boundaries

An epic is a **vertical slice of user-visible capability**, never a horizontal
layer. Because epics are ordered **demo-first**, each one must ship a demoable
end-to-end increment (UI + logic + data for that slice), using fixture seams where
a later epic will provide the real backend.

- Epic 01 = the thinnest walking skeleton that renders + one real capability.
- Later epics add capabilities *and* replace earlier fixture seams with real code.
- A mandatory final **Integration & E2E** epic wires everything, runs full
  end-to-end tests, removes any remaining fixtures.
- Horizontal splitting (schema / API / UI) appears only as stories *inside* an
  epic.
- An epic is roughly 3–8 stories. A capability that overflows is split; fewer than
  two stories merges into a neighbor. A small spec is often a single epic.

### Stories

A story is **one vertical behavior, testable on its own, that one agent finishes in
one pass**. No size buckets. The agent's cut heuristic:

1. Testable independently? If not → merge or re-cut.
2. At most ~6 acceptance criteria? If not → split.
3. One concern? If it spans two unrelated concerns → split.
4. Depends on unbuilt code? → `blocked_by`, do not inline.

### Story file

```yaml
---
id: 01-02              # epic-story, unique across the whole project
title: Contact form component
epic: 01
spec: SP-003
type: feat             # inherited from the spec
status: todo            # todo → in-progress → done  (+ skip, bug)
delivery: ""            # "" → pr → merged  (or direct)
blocked_by: []          # ["01-01", …]  story ids in the same plan
prior_status: ""        # set when status becomes bug
issue: ""               # GitHub issue number if issue_tracking is on
pr: ""                  # PR number after ship
---

## Goal
## Acceptance Criteria   — [ ] checkboxes, a subset of / derived from the spec's AC
## Implementation Tasks  — short ordered checklist; non-binding, build may revise
## Notes
```

### Acceptance-criteria mapping

`plan` distributes the spec's feature-level acceptance criteria across stories.
Every spec AC must be covered by at least one story. The final Integration epic
re-verifies all of them end-to-end. `review` checks the mapping is complete.

### Cross-spec dependencies

`blocked_by` is story↔story within one plan. Spec↔spec is `depends_on` in the spec
frontmatter. Because specs are serial (§9), `depends_on` mostly orders the
activation queue; `pact build SP-B` refuses while a `depends_on` spec is not
`done`. `pact status` shows the dependency-ordered queue.

### Output

`tasks/YYYY-MM-DD_<slug>/` — a project overview, `epics/` with an `EPIC.md` each,
`stories/` with frontmatter files, a `ROADMAP.md`. The feature doc's `design:`
flag (if `design_docs` is on) flips `pending → planned`. Index views are
regenerated.

---

## 9. `pact build`

Implements stories from `tasks/` with Test-Driven Development, SOLID, a
reuse-first scan, and a bounded QA loop.

### Invocation

| Command | Effect |
|---|---|
| `pact build` | the **current spec** in full — every non-`done` story, in dependency-ordered waves |
| `pact build 01-02` | one story, inline |
| `pact build 01-02 01-03` | those stories, one wave |
| `pact build --epic 01` | the whole epic, in waves |
| `pact build --story 01-02` | force inline even if peers are available |

### Execution modes

Chosen when a spec's build starts (a prompt at the transition into `build`),
defaulting to `[workflow].default_exec_mode`. Changeable mid-run with
`pact build --mode <x>`, which resumes where the build left off.

| Mode | Pauses after… |
|---|---|
| `step` | every story — the user reviews, then continues |
| `wave` | every wave (default in `full`) |
| `spec` | nothing — builds the whole spec to `done`, pausing only at hard stops (default in `lite`) |
| `flow` | nothing, not even `build` — auto-chains `build → review → ship` while nothing blocks; runs through to a merged PR when the path is clean |
| `dry` | does nothing — shows the wave plan and what would happen |

**Hard stops** override the mode, always: the verification gate, QA escalation
after 3 failed iterations, an unresolvable `manual` conflict, `review` NEEDS FIXES
that is not auto-fixable, a destructive-action confirmation, human PR approval
(`min_approvals > 0`).

### One active spec at a time

Cross-spec work is **strictly serial**. One spec is the *active spec* from `build`
through merge to `main`. Drafting (`spec`) and planning (`plan`) may run for many
specs concurrently — they touch no code. But `pact build <B>` is **refused** while
another spec's `spec/<id>` branch is unmerged: finish or abandon it first
(`pact ship --abandon <id>` returns the spec to `planned`, deletes the branch,
releases the lock). Each new spec branch is cut from an up-to-date `main`, so the
entire class of cross-spec merge conflicts cannot arise.

### Per-story TDD loop (phases 0–7)

| Phase | Work |
|---|---|
| 0 · Context | load the story, spec, `constitution.md`, `project.md`, `stack.toml`, relevant DRs, team skills (if on), UI direction (if applicable) |
| 1 · Plan | restate the goal, map each acceptance criterion to a test, list implementation tasks, sketch the SOLID design. No user prompt unless `confirm_story_plan` is on. |
| 2 · RED | write a failing test per acceptance criterion; run `test_one`; confirm each fails **for the right reason** |
| 3 · GREEN | the minimal code to pass; `test_one` until green |
| 4 · REFACTOR | clean up, apply SOLID, run the reuse-first redundancy scan; tests stay green |
| 5 · QA | full `test` + `lint` + `typecheck` + `build`; architecture compliance vs `project.md`; edge cases; design fidelity if UI. Verdict PASS / NEEDS FIXES. Loop **max 3**, then escalate. |
| 6 · Verification gate | method by project type (below) |
| 7 · Complete | implementation summary in the story body; `status: done`; regenerate views |

**Reuse-first scan** (phase 4, against the story's diff only): reimplementation of
existing logic · copy-paste inside the diff · dead code · needless single-caller
indirection · unasked-for surface. Findings are ordinary QA items, not a new gate.

**Verification gate** (phase 6) adapts to the project:

| Project type | Verification |
|---|---|
| Web UI | Chrome-driven (if the plugin is available) or manual steps |
| CLI | run the command, show the expected output |
| Library / API | example calls or a quickstart script |
| Backend service | curl the endpoint / a smoke script |

`[workflow].manual_gate` = `drive` (pilots the tool) / `steps` (text instructions
only) / `off` (headless / CI). In wave mode the gate is **batched once** after all
waves merge; inline (one story) it runs immediately.

**QA escalation** (phase 5, after iteration 3): the other worktree agents finish
their current phase and hold; the orchestrator collects partial results; nothing
merges until the user resolves — **A)** apply fixes the user specifies, **B)**
accept as-is with documented known issues, **C)** abort and set the story back to
`todo`.

### Wave orchestration

Computed by `pact wave-plan` — a script, zero model tokens:

1. Read the plan: every non-`done` story of the spec + `blocked_by`.
2. Build the dependency DAG; its topological layers are the waves. Each layer runs
   fully in parallel.
3. Cut the spec branch `spec/<SP-id>-<slug>` from `main` (this is also the
   rehearsal branch — safe, because spec-level serialization means a bad wave
   rolls back without affecting anything else, and the branch is not merged).
4. **Load shared context once.** The orchestrator reads `project.md`,
   `constitution.md`, `stack.toml`, and the relevant `accepted` DRs a single time
   and passes them **verbatim** in each dispatch prompt as read-only context. A
   `story-implementer` never re-reads those files — it reads only story-specific
   files and the code it touches. (A wave of 5 stories reads the shared context
   once, not five times.)
5. For each wave:
   - One git worktree + one `story-implementer` subagent per story (or inline if
     the wave holds one). Worktrees are named `pact-wt/<wave>/<story-id>` in a
     sibling directory; `setup` runs once per worktree; `[workflow].max_parallel`
     (default 4) caps concurrency.
   - Each agent runs phases 0–7 and returns a typed schema:
     `{ status, branch, files_touched, ports_used, criteria_met, remaining, notes }`.
   - Merge each story branch into the spec branch in id order. The first conflict
     goes to the `conflict-analyzer` agent, which returns one of: **auto** (apply
     the patch, continue), **serialize** (move the losing story to the next wave,
     recompute `wave-plan`), **manual** (surface the hunks, pause the wave). If a
     wave produces more than one conflict the planner tightens and serializes more
     of the remaining spec.
   - Run the full `test` suite on the spec branch after the wave merges. Green →
     wave done. Red → QA loop (max 3) or roll back the wave.
   - Regenerate the index views **once, after the wave settles** — not per story.
6. All waves green → the batched verification gate → ready for `review` / `ship`.
   The views are also regenerated on every `build` exit (success or clean
   interrupt), so they never lag by more than an in-flight wave.

The full `test` run that ends a green wave is recorded against the spec-branch
SHA. `review` and `ship` reuse that record instead of re-running an identical
suite (see §10, §11).

Worktrees are removed and `git worktree prune` runs on wave success; kept with a
pointer on failure. Orphan worktrees from an interrupted run are cleaned or
resumed at the start of the next `build`.

### Resource isolation

The orchestrator pre-allocates disjoint runtime resources per worktree. **There is
no `.env.pact` file** — never a file the user configures. `[env].isolation` is a
per-project strategy chosen at `init`:

| Value | When | Orchestrator behavior in a wave |
|---|---|---|
| `docker-compose` | project has a `docker-compose.yml` | `docker compose -p pact_w<N> …` per worktree |
| `inline-env` | the app honors `PORT` / `DATABASE_URL` overrides | vars injected inline: `PORT=3102 DATABASE_URL=…pact_w2 pnpm test` |
| `serialize` | isolation is not reliable (hardcoded ports, fixed test DB) | the wave runs serialized, parallel off, and says why |
| `auto` (default) | — | detect; fall back to `serialize` when uncertain |

The orchestrator is the message bus. Subagents never talk to each other; anything
cross-agent (the port map, merge order, conflicts, drift) is resolved by the
orchestrator. An agent that needs an unplanned resource reports it in its typed
return; the orchestrator re-allocates and re-dispatches.

### `pact fix` — the bug flow

`pact fix "login button dead on Safari"` (or `pact spec fix …` then `pact fix`):

1. **Diagnose** in an isolated context — reproduce the bug (verification method by
   project type), locate the root cause, write a **failing test** that reproduces
   it (RED, committed) and a **Fix Plan** into the spec (smallest diff, files).
   The diagnosis phase **never writes the source fix**.
2. Link the affected story if one exists: `prior_status` saved, `status: bug`.
   Otherwise the fix spec stands alone with its own small plan.
3. **Route** — an easy fix (one file, obvious, low risk) auto-runs `build` in
   bug-fix mode; a complex one hands off to `pact build <fix-spec>` when ready.
4. **Bug-fix mode** — zero new scope, a minimalism check (the diff must be the
   smallest that resolves the bug), re-test **all** acceptance criteria of the
   touched story (the fix may have side effects), then `ship`.

### Failure modes

| Failure | Behavior |
|---|---|
| Wave agent crash / timeout | mark the story failed, keep its worktree, continue the wave, report; re-run per story |
| `gh` fails mid-`ship` | `ship` is idempotent / resumable — records progress (pushed? PR opened? issues linked?); re-running resumes; nothing is created twice |
| Test hang | `[env]` commands run with a timeout (default 10 min, configurable) → treated as failure → QA loop / escalate |
| `build` interrupted (Ctrl-C, crash) | state is in frontmatter + git; `pact status` shows the partial state; re-running `pact build` resumes from the first non-`done` story |
| `conflict-analyzer` cannot resolve | `manual` — hunks surfaced, wave paused |
| Schema gate fails | hard block → `pact migrate` |
| Disk full / worktree creation fails | abort the wave cleanly, report |

---

## 10. `pact review`

A feature-level audit of the whole spec — every story together — before `ship`.
Runs after `build` (all waves green + verification gate) when `steps.review` is on.
Runs in an isolated subagent context.

`review` does **not** re-run the test suite by default: `build` already ran it to
green against the current spec-branch SHA, and re-running an identical suite is
wasted tokens. It re-runs only if the branch SHA moved since that record, or if
`[review].fresh_suite` is set (default `false` in `lite`, `true` in `full`).
`review` focuses on what a per-story `build` pass structurally cannot see —
cross-story integration and spec-level coverage.

Checks:

1. Every spec acceptance criterion is test-covered **and** fulfilled — PASS / FAIL
   each.
2. Consistency: code vs plan (all stories `done`, no orphan tasks) · code vs
   `constitution.md` + `accepted` DRs · code vs `project.md` structure.
3. Whole-spec-diff code review: SOLID, feature-level redundancy, edge cases,
   security, error handling.
4. Design fidelity, if UI and a design system is present.
5. Suite status from the recorded green (or a fresh run per the rule above) · no
   `skip` / `only` tests · coverage vs the charter floor.

Output: a report, findings by severity (CRITICAL / HIGH / MEDIUM / LOW), verdict
**PASS / NEEDS FIXES**.

Gate: `review_gate` on + NEEDS FIXES → `ship` is blocked. CRITICAL always blocks. A
charter violation is handled as Option B (§14). On NEEDS FIXES the reviewer
auto-fixes LOW / MEDIUM itself and re-runs; CRITICAL / HIGH go back to a targeted
`build`.

`review` is agent-only — an agent reviewing agent-written code has correlated blind
spots. `deep` effort mitigates this with independent fan-out passes.

### Effort

`[review]`: `effort` = `quick` (1 pass, consistency + criteria only) / `standard`
(1 pass, full checklist) / `deep` (2–3 independent fan-out passes — correctness,
security, architecture — each a subagent returning typed findings, merged and
deduped by the orchestrator). `model` = `auto` or an explicit tier. `passes` = N.
`auto_fix` = `off` / `low` / `low+medium`. Per-run override:
`pact review --effort deep --passes 3 --model opus`.

### `pact review --project`

A periodic architectural-convergence pass: the whole codebase vs `project.md` vs
`accepted` DRs vs the constitution. Run on demand, and auto-suggested by the
`SessionStart` hook / `pact check` every N merged specs (default 10) or on a
structural-drift signal. Output → `refactor` / `chore` spec stubs (`status: draft`)
the user can pick up. It blocks nothing.

---

## 10a. `pact security`

A dedicated, **on-demand** security audit. Never runs automatically, never
auto-fixes. It is a generator of security work.

The normal flow already carries a security baseline: the constitution's Security
axis, `review`'s code-review security dimension, `build` phase-5 QA edge cases.
`pact security` is the deep, opt-in pass.

```
pact security                    full audit → security-fix spec stubs
pact security --deps             dependency vulnerabilities only
pact security --scope src/auth   scoped to a path
pact security --deep             multi-pass fan-out (injection / auth / crypto / config)
```

### What it does

1. The **`security-auditor`** agent runs in an isolated context, **defensive only**
   — against this repository and its local dev instance, never third-party
   systems:
   - SAST-style review: injection (SQLi, XSS, command, path traversal),
     authn/authz gaps, secret leakage, insecure deserialization, SSRF, CSRF, weak
     crypto, unsafe defaults.
   - Dependency vulnerabilities via the stack's tool (`npm audit`, `pip-audit`,
     `cargo audit`, `osv-scanner`, …).
   - Config: exposed env, permissive CORS, missing security headers, debug mode
     on.
   - Compliance with the constitution's Security axis; authz logic vs
     `project.md` + `accepted` DRs.
   - Optional light DAST when the app runs (`dev` + curl/Chrome probes against the
     **local** instance only).
   - Returns typed findings
     `{ id, severity, category, file:line, description, evidence, recommendation, cwe }`
     — **no fixes**.
2. **Findings → specs.** Generates `type: fix` spec stubs marked `security: true`
   (`status: draft`), one per finding or grouped by area, prioritized by severity.
3. **The user picks** which to act on; each goes through the normal
   `spec → plan → build → ship` flow, so every fix is TDD'd, reviewed, shipped.
4. **Accepted risk** (no code change) is recorded as a DR (`kind: tradeoff`,
   "accepted security risk: X because Y").

Output: a report + draft spec stubs under `docs/specs/`. Nothing is changed in the
codebase by this command.

---

## 11. `pact ship`

1. **Pre-check** — spec at `status: ready`, all stories `done`, `review` green if
   `review_gate`.
2. **Preflight** — if `preflight` is on, re-run `lint` + `test` on the spec branch
   **only when its HEAD moved** since the green recorded by `build` / `review`.
   When HEAD is unchanged, skip with "already verified at `<sha>`".
3. **Commit** — conventional style; per-story commits already exist from `build`;
   a final synthesis commit if needed.
4. **Push** the `spec/<SP-id>-<slug>` branch.
5. **PR** `spec/<SP-id>` → `main`. Body generated from the spec (goal, acceptance
   criteria, stories, linked DRs) + a `Closes #NN` footer if issue tracking is on.
6. **Issues** — link / update / close GitHub issues; write issue numbers into
   frontmatter.
7. **Wait for CI** if `ci_gate` — read the status, do not merge on red.
8. **Merge** — `squash` / `merge` / `rebase`, after approval if `min_approvals > 0`.
9. **Post-merge** — `delivery: merged`; delete the branch and worktrees; regenerate
   views; propose a `project.md` patch if the merged spec changed the structure or
   tech→role map (§15); `deploy_prompt` prints its reminder (PACT does not
   deploy).
10. **Hand-off** — `pact status`, or the next spec.

`platform = "local"` skips push / PR / CI and does a local merge with
`merge_strategy`.

**No AI references** in any commit, PR, issue comment, or branch name — enforced by
a skill-scoped `PreToolUse` guard active only while `ship` / `build` / `fix` run.

---

## 12. Decision Records

Always on — not a toggle. Lightweight. Scope is **any** significant decision
(architecture, product, tooling, process, naming, tradeoff).

`docs/decisions/NNNN-slug.md`:

```yaml
---
id: 0007
title: Server actions over a separate API for form submissions
kind: arch            # arch | product | tooling | process | naming | tradeoff
status: accepted      # proposed | accepted | superseded
date: 2026-09-10
spec: SP-003           # triggering spec, or ""
supersedes: ""         # id of the DR this replaces, or ""
superseded_by: ""      # filled when a later DR replaces this one
---

## Context               — the problem, the forces in play, the constraints. Factual.
## Decision              — what was chosen. One or two sentences, active voice.
## Alternatives considered — each rejected option + one line on why.
## Consequences          — what it costs later. + gains and − costs/risks, as bullets.
```

Rules:

- Immutable once `accepted`. A change is a **new** DR that sets `supersedes:`; the
  old one flips to `superseded` + `superseded_by:`. A `proposed` DR is still
  editable.
- `docs/decisions/README.md` is a generated index (id · title · kind · status ·
  date, newest first, superseded ones greyed).
- A DR that changes a charter rule also bumps the charter version, cited in its
  `## Consequences`.

Auto-proposed by `spec` / `plan` / `build` / `review` when a decision has real
alternatives **and** is hard to reverse, or cross-feature, or contradicts /
extends `project.md` or the constitution. Below that threshold — a local, easily
changed choice — nothing is written (reuse-first: no ceremony). Before proposing,
a phase checks the DR index (`docs/decisions/README.md`): if a `proposed` or
`accepted` DR already covers the decision area, it is **not** re-proposed — one
decision, one DR, regardless of how many phases touch it. A declined proposal
leaves a one-line trace in the story's `## Notes`. Manual creation:
`pact adr "…"`.

---

## 13. Constitution (charter)

The project's standing rules — *not* the method's own rules.

**Built-in method rules** (non-configurable, always active): TDD RED-before-GREEN
(mandatory in `lite` and `full`), the SOLID check, the reuse-first scan, the QA
loop (max 3), no-AI-references in git artifacts, confirmation before destructive or
outbound actions.

**The charter** covers what PACT cannot know. Authored at `init` (or later),
guided, with **no question cap**: the agent walks every axis that matters, one at a
time, proposes a best-practice default per axis, and skips axes that do not apply
(they are removed from the file, not left as "N/A"):

Testing · Architecture · Code style · Dependencies · Security · Data · Delivery ·
Observability · Performance · Accessibility / i18n · Documentation.

`constitution.md` is versioned (semver in the header). Editing it bumps the
version; `plan` and `build` record which version they ran against.

**Violation handling — Option B (explicit acknowledgment).** In `full` mode a
violation stops the command, shows it, and offers "proceed anyway"; on
confirmation it appends a line to `.pact/charter-overrides.log` (date, charter
version, rule, story id) and continues. The charter is not modified. In `lite` mode
it is a warning + the same acknowledgment. A human can always override in the
moment; the trace is permanent.

*(Improvement, deferred: at charter authoring, generate the mechanical rules that
CAN be mechanized — banned-dependency lint, import-boundary rules, naming — into
the project's own tooling, so the LLM gate only covers what cannot be mechanized.)*

---

## 14. `project.md` upkeep

`project.md` is mandatory context and drifts as the project grows. It is
maintained by `ship`, not by hand: post-merge, the agent diffs what the spec added
(modules, directories, services, external integrations — from story diffs and DRs)
against `project.md`'s structure map and tech→role map. On drift it proposes a
minimal patch; the user confirms. `pact review --project` also re-syncs it.

---

## 15. `lite` vs `full`

The **pipeline is identical** — `spec → plan → build → ship`, with TDD
RED-before-GREEN, parallel waves, and Decision Records, always, in both modes.
`full` adds the quality and governance layers and raises effort.

| Aspect | `lite` | `full` |
|---|---|---|
| `spec` clarification | leans harder on defaults | asks until no material ambiguity |
| `plan` | epics + stories + `blocked_by`, minimal detail; one-pass | + edge cases per story, test notes, `## Implementation Tasks`, explicit dependency graph; two-pass |
| `constitution` | off (advisory if on) | on, gated (Option B) |
| `review` | off — `build`'s per-story QA is the only check | on, `review_gate` |
| `team` / `design_docs` / `issue_tracking` | off | proposed |
| `preflight` | off | on |
| model / review effort | conservative defaults | tunable, `deep` review available |
| verification gate | `steps` | `drive` when tools are available |

Switch any time with `pact config`. Turning `full` on offers a backfill (generate
architecture docs, author the charter, …).

---

## 16. `pact team` (optional)

When `steps.team` is on, `pact team` derives project-tailored skills from
`stack.toml` + the constitution + (if `design_docs` is on) `docs/architecture/`,
otherwise the codebase itself.

1. **Detection** — from stack + code, the roles / techs that warrant a skill:
   `guide-<language>`, `guide-<framework>`, `expert-qa` (always), `expert-security`
   (if auth / secrets), `expert-database` (if a schema), `expert-api` (if routes).
   Breadth is gated by `--basic` / `--standard` / `--max`.
2. **Research** — only if `[team].context7` is on; version-specific framework docs.
   Off by default (token cost).
3. **Generate** — one `SKILL.md` per unit in `.claude/skills/<name>/`, with
   `paths:` globs that auto-load it and a body of this project's folder layout,
   naming conventions, test patterns, and framework idioms — derived from the
   code, not invented.
4. **Wire** — `build` matches a story's touched paths against each skill's `paths:`
   and auto-loads the relevant ones.

Regeneration is merge-safe: hand edits in a `## House rules` section are preserved.
With `steps.team` off, `build` reads `stack.toml` + `constitution.md` +
`CLAUDE.md` only.

---

## 17. `docs/architecture/` (optional)

`steps.design_docs`, off in `lite`, proposed in `full`. When on, `pact design`
produces global docs (`overview.md`, `folder-structure.md`, `tech-stack.md`,
`_shared.md`) plus one self-contained `docs/architecture/features/<slug>/index.md`
per feature (**Components · Data · Flows · API**), frontmatter `design: pending` →
`planned` (flipped by `plan`). There are no journal / ledger docs — git is the
history. When off, `plan` and `build` work from the spec + `project.md` + the code
directly. This is the "medium+ project" upgrade for when `project.md` + spec no
longer frame `plan` / `build` without drift.

---

## 18. Generated views

Read-only, regenerated by script, never hand-edited:

- `tasks/<slug>/STORIES_INDEX.md` — one row per story: id, title, epic, status,
  delivery, `blocked_by`.
- `tasks/FEATURE_INDEX.md` — one row per spec across all plans: spec id, slug,
  type, epics done/total, stories done/total, delivery.
- `docs/decisions/README.md` — the DR table.
- `tasks/ROADMAP.md` — only on `pact status --write`; a generated snapshot.

There is no hand-written roadmap. `pact status` renders the same picture live.

---

## 19. Statusline

- **Subagent status line** (per-agent rows during waves) ships **auto-enabled** — a
  plugin may set `subagentStatusLine`.
- **Main status line** requires writing user/project `settings.json`, which a
  plugin cannot do. `init` offers it (`[y/N]`); otherwise
  `pact config statusline install`. The script prints nothing outside a PACT
  project (it checks for `.pact/`), so a global install is safe. It refuses to
  overwrite an existing `statusLine` without `--force`.

Shape:

```
PACT  SP-003 contact-section  2/3 stories  ▪ 01-02 Contact form 4/6 AC  → spec/SP-003  ⚙ 01-03
```

Current spec + slug · stories done/total · current story + its acceptance criteria
· target branch · active worktrees. Rendered by the terminal — zero model tokens.

---

## 20. Hooks

- **`SessionStart`** (`scripts/session-start.sh`, zero tokens, ~5 lines max):
  silent if not a PACT project; a schema-gate notice on mismatch; a
  plugin-not-enabled hint (the passive replacement for an invasive guard); the
  condensed project state (same data as `pact status`); light drift flags pointing
  to `pact check`; a gentle note if `.pact/` is uncommitted.
- **`PostToolUse`** on `Write | Edit | MultiEdit` (`scripts/format.sh`): formats
  the touched file with the stack's formatter, config-gated, silent on success.
- **`Stop` / `Notification`** (`scripts/notify.sh`, zero tokens): a short sound
  on turn end and when PACT is waiting on the user. Off by default
  (`[notify].sound = off`); `attention` restricts it to input waits and
  failures, `all` adds turn end and settled build waves. Toggled on and off
  through `/pact:config` like any other setting. `build` and `review`
  also invoke `pact notify wave|fail` at those checkpoints. Plays a system sound
  if one is found, else the terminal bell; `method = command` hands off to a
  user shell line. Backgrounded, always exits 0 — it can never delay or fail a
  turn. `PACT_NOTIFY=off` mutes it regardless of config. Adding the optional
  `[notify]` block needs no schema bump — absent keys read as `off`.

---

## 20a. `pact migrate`

Bridges a released plugin version that changes the `.pact/` layout and a project
still on an older `schema`.

1. A release that changes `.pact/` bumps the `schema` template value (major only if
   breaking) and ships a migration step in `scripts/migrations/NNNN-*.sh` (tested).
2. After `/plugin update`, the user opens a project whose `config.toml` `schema` is
   behind. `SessionStart` prints the mismatch notice.
3. Every write-command's Phase 0 gate **refuses** on a mismatch and points to
   `pact migrate`. Read-only commands (`status`, `check`) still run.
4. `pact migrate`:
   - refuses a dirty git tree (commit or stash first);
   - reads the current `schema` and applies each step in order, chained
     (1→2, then 2→3, …);
   - each step renames keys, moves files, rewrites frontmatter, restructures dirs
     as that version requires;
   - restamps `schema`, regenerates the views;
   - lands everything in one revertable commit
     (`chore(pact): migrate .pact schema N → M`);
   - prints a summary.
5. Idempotent — a run on an already-current project does nothing and says so. Safe
   to re-run. On a directory with no `.pact/` it reports "not a PACT project" and
   exits.

---

## 21. SKILL.md anatomy

Every command's `SKILL.md` follows this shape.

**Frontmatter:** `name` · `description` (when to use it — drives Claude's
auto-selection) · `argument-hint` · `allowed-tools` (e.g.
`Bash(pact *) Bash(git status*) … Skill`) · a `PreToolUse` `no-ai-guard` hook where
relevant.

**Body:**

1. Title + one-paragraph purpose and place in the flow.
2. **Routing check (do first)** — "am I the right skill?" If the task is actually
   X, stop and recommend the right command.
3. **Reuse-first note** — read existing context, reuse before rebuilding, simplest
   viable approach.
4. **Progress tracking** — a `TodoWrite` list, one todo per phase, updated as you
   go — **only for the long multi-phase commands** (`plan`, `build`, `review`,
   `security`, `migrate`). The short linear commands (`spec`, `ship`, `status`,
   `check`, `config`, `adr`) skip it; it costs tool calls without adding a "where
   am I" the user needs.
5. **Phase 0: schema gate** — read `.pact/config.toml` `schema`; a mismatch blocks
   and offers `pact migrate`.
6. **Phases 1..N** — the work, numbered, each with a goal, steps, and an exit gate.
7. **Hard gates** — cross-phase invariants (RED before GREEN, no source fix during
   diagnosis, confirm destructive) listed explicitly, so a skip is a visible
   failure.
8. **Completion report** — what to tell the user (paths, status, next command).
9. **Hand-off** — the one-click next step with pre-filled arguments; max chain
   depth 3; a skill may not invoke one already on the chain.
10. **Rules** — terse dos and don'ts specific to this skill.

Bulky templates and examples live in `skills/<name>/references/*.md`, loaded on
demand, read at most once per run. Shared contracts live in repo-root
`references/*.md` (state model, wave orchestration, subagent fan-out, DR, charter,
reuse-first, skill invocation, workflow map) — skills link to them, never restate.
Target **6–8 dense reference files**, not one per topic — every file a skill may
load is a recurring read, so consolidation is a direct token saving.

---

## 22. Repository layout

```
pact/                       github.com/<owner>/pact — MIT
├── .claude-plugin/
│   ├── marketplace.json    # declares the marketplace
│   └── plugin.json         # name, version, description, author
├── skills/<cmd>/SKILL.md   # help, init, spec, design, team, plan, build, review, ship, fix, security, status, check, config, adr, migrate
│   └── <cmd>/references/*.md
├── agents/
│   ├── story-implementer.md
│   ├── qa-validator.md
│   ├── conflict-analyzer.md
│   ├── reviewer.md
│   └── security-auditor.md
├── hooks/hooks.json        # SessionStart (status + schema-gate notice); PostToolUse Write|Edit (format)
├── settings.json           # subagentStatusLine
├── bin/pact                # single dispatcher
├── scripts/*.sh            # wave-plan, index regen, status render, resource alloc, worktree mgmt — POSIX, no heavy runtime
├── references/*.md         # shared contracts
└── README.md
```

Install: `/plugin marketplace add <owner>/pact` → `/plugin install pact@pact`.
Per-project opt-in via `.claude/settings.json` `enabledPlugins`, written by
`pact init`.

---

## 23. Walkthroughs

Worked end-to-end examples — a new project, an existing project, and a project
with a PRD — are in [COMMANDS.md](COMMANDS.md#walkthroughs). They are usage, not
design, so they live there.

## 24. Open items

Settle during implementation:

- Exact column layouts of the generated views.
- Charter-axis → mechanical-rule mapping (deferred; nice-to-have).
- `pact review --project` cadence beyond "every N merged specs, default 10".
- Whether `pact fix` stays a real command or becomes a thin `pact spec` alias
  (kept as a real command for now).
