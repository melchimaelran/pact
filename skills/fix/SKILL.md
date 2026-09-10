---
name: fix
description: >-
  Bug flow. Diagnose a bug in an isolated context, write a failing reproduction
  test and a Fix Plan into a spec — never the source fix itself — then route to
  build (auto for an easy fix, hand-off for a complex one).
argument-hint: "\"<bug description>\" | <spec-slug-or-SP-id>"
allowed-tools: >-
  Read Write Edit Glob Grep Agent
  Bash(pact *) Bash(git status*) Bash(date *)
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/no-ai-guard.sh"
---

# fix — bug triage

Turns a bug into a reproducible, planned unit of work. See
[`workflow-map.md`](../../references/workflow-map.md). Next: `pact build`
(bug-fix mode).

## Routing check

- New behavior, not a defect -> `pact spec` (`type: feat` / `adjust`).
- The bug is already triaged (a story at `status: bug` with a Fix Plan) ->
  `pact build <story>` directly.

## Phase 0 — schema gate

`pact schema --gate`.

## Phase 1 — resolve target

- A quoted description -> CREATE a `type: fix` spec (shortcut: spec + diagnose in
  one run). `id` from `pact spec-id`, folder
  `docs/specs/<date>_<slug>/`, template from
  `skills/spec/templates/spec.md` with `type: fix`.
- A slug / `SP-id` of an existing `type: fix` spec -> continue its diagnosis.

## Phase 2 — diagnose (isolated)

Dispatch the `qa-validator` agent (or do it inline if not registered):

1. **Reproduce** the bug using the project-type method (`[env].dev` + Chrome or
   curl for a service, run the command for a CLI, a targeted call for a library).
2. **Write a failing test** that reproduces it. Run `pact env test_one --path
   <file>`; confirm it fails for the bug's reason. Commit the test (RED).
3. **Locate the root cause.** Record a hypothesis.

The agent returns `{ verdict, criteria, issues }` plus the failing-test path and
the root-cause hypothesis. **It does not write the source fix.**

## Phase 3 — write the spec

Into the `type: fix` spec:

- `## Context` — where and when it breaks, severity, who is affected.
- `## Reproduction` — exact steps + environment.
- `## Expected vs Actual`.
- `## Root Cause Hypothesis`.
- `## Fix Requirements` — the smallest change that resolves it; the files
  involved.
- `## Acceptance Criteria` — the reproduction test goes green · all acceptance
  criteria of the affected story still pass · no new regression.
- `## Constraints` — smallest diff; the constitution.

## Phase 4 — link

If an existing story owns the broken code: set that story `prior_status` to its
current status and `status: bug` (via `pact story set`), and note the fix spec in
its `## Notes`. Otherwise the fix spec stands alone; `pact plan` will give it one
small story.

## Phase 5 — route

- **Easy** (one file, obvious, low risk) -> auto-run `pact build <story>` in
  bug-fix mode. Chain depth counts; `fix -> build` only, never `fix -> build ->
  fix`.
- **Complex** -> stop and hand off `pact build <story>` (or `pact plan` first if
  the fix spec has no story), arguments pre-filled.

## Hard gates

- The diagnosis phase **never** writes the source fix — only the failing test and
  the plan.
- A failing reproduction test must exist and be committed before routing.
- Re-checking **all** of the affected story's acceptance criteria is mandatory in
  bug-fix mode (the fix may have side effects).

## Completion report

The fix spec path, the failing-test path, the linked story (if any) and its new
`status: bug`, and the routing decision (auto-build or hand-off).
