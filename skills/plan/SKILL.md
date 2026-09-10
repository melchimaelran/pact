---
name: plan
description: >-
  Turn a ready spec into epics and stories under tasks/. Epics are vertical
  slices of user-visible capability in demo-first order; stories are one vertical
  behavior each. two-pass (validate epics, then stories) or one-pass.
argument-hint: "<path-to-spec.md> [--one-pass]"
allowed-tools: >-
  Read Write Edit Glob Grep
  Bash(pact *) Bash(git status*) Bash(date *) Bash(mkdir *)
  AskUserQuestion
---

# plan — spec to epics and stories

See [`workflow-map.md`](../../references/workflow-map.md) and
[`state-model.md`](../../references/state-model.md). Next step: `pact build`.

**Reuse-first** ([`reuse-first.md`](../../references/reuse-first.md)): plan from
the spec, `project.md`, and any existing `tasks/`. Do not re-derive settled
architecture. Pick the simplest epic/story structure that covers the spec.

## Progress tracking

Open a `TodoWrite` list, one item per phase.

## Phase 0 — schema gate

`pact schema --gate`. Mismatch -> `/pact:migrate`. No `.pact/` -> `/pact:init`.

## Phase 1 — input

- `$ARGUMENTS` is the path to a `spec.md` at `status: ready`. If it is `draft`,
  stop and send the user to `pact spec` to finish it. If `planned` / `done`,
  ask whether this is a re-plan.
- Read the spec, `project.md`, the constitution, `accepted` DRs.
- Confirmation mode: `[plan].confirmation` (`two-pass` default in `full`,
  `one-pass` in `lite`); `--one-pass` overrides.

## Phase 2 — trivial-work shortcut

If the spec is `type: chore` or `type: docs` **and** the work is a single small
change with no code structure, do **not** create epics. Create one story directly
under a minimal plan folder (`tasks/<date>_<slug>/epics/01_<slug>/stories/01_*.md`)
with the acceptance criteria straight from the spec, set the spec to
`status: planned`, regenerate views, and hand off to `pact build`. Skip the rest.

## Phase 3 — epic breakdown

An epic is a **vertical slice of user-visible capability**, never a horizontal
layer. Ordered **demo-first**:

- Epic 01 = the thinnest walking skeleton that renders + one real capability.
- Each later epic adds a capability **and** replaces earlier fixture seams with
  real code.
- A mandatory final **Integration & E2E** epic wires everything and removes
  remaining fixtures.
- ~3–8 stories per epic. A capability that overflows is split; fewer than two
  stories merges into a neighbor. A small spec is often one epic.

**two-pass:** present the epic list (number, title, demo statement, rough story
count, order rationale). Get the user's approval or edits before Phase 4.
**one-pass:** continue straight to Phase 4 and present everything together.

## Phase 4 — stories

For each epic, cut stories. A story is **one vertical behavior, testable on its
own, that one agent finishes in one pass**. Cut heuristic:

1. Testable independently? no -> merge or re-cut.
2. At most ~6 acceptance criteria? no -> split.
3. One concern? two unrelated concerns -> split.
4. Depends on code from another story? -> `blocked_by`, not inline.

Distribute the **spec's** acceptance criteria across the stories: every spec AC is
covered by at least one story. Write finer story-level AC where useful. The final
Integration epic re-verifies all spec AC end-to-end.

Set `blocked_by` only for a hard code dependency (story B needs story A's code).
Horizontal splitting (schema / API / UI) is fine **inside** an epic as separate
stories.

## Phase 5 — confirm

Present the full structure: epics, stories (id, title, AC count, `blocked_by`),
and the dependency graph. In two-pass this is the second checkpoint; in one-pass
the only one. Apply edits until the user approves.

Run `pact wave-plan <plan-dir> --spec <SP-id>` and show the resulting waves so
the user sees how it will parallelize.

## Phase 6 — generate

1. `mkdir -p tasks/<date>_<slug>/epics/<NN>_<epic-slug>/stories/`.
2. From `skills/plan/templates/`:
   - `PROJECT_OVERVIEW.md` per plan (summary, epic list, dep graph, AC coverage).
   - `EPIC.md` per epic (frontmatter + goal + demo note).
   - `story.md` per story (frontmatter + Goal + Acceptance Criteria +
     Implementation Tasks). Story files are `<NN>_<story-slug>.md`; ids are
     `<epic>-<NN>`, unique project-wide (allocate from the project-wide max epic
     number, do not restart at 01 for a later plan).
   - `ROADMAP.md` — the ordered epic list with the dependency graph.
3. Set the spec `status: planned`. If `steps.design_docs` is on and a feature doc
   exists, flip its `design:` flag `pending -> planned`.
4. `pact views` — regenerate STORIES_INDEX / FEATURE_INDEX / decisions index.

## Decision records

Propose a DR ([`decision-records.md`](../../references/decision-records.md)) for
an epic/story structure choice with real tradeoffs (introduce a queue, a new
module boundary, a separate service) — after checking the index.

## Hard gates

- The fan-out / confirmation decision is announced before units are produced
  (two-pass: epics approved before stories are detailed).
- Never widen a story past ~6 acceptance criteria to "save effort" — add task
  depth instead.
- Every spec acceptance criterion maps to at least one story.
- Regenerate views exactly once, at the end.

## Completion report

The plan folder, the epic and story counts, the wave plan, and the next command
(`pact build`).
