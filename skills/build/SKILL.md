---
name: build
description: >-
  Implement stories from tasks/ with TDD — one inline, several at once in
  dependency-ordered parallel waves, or a whole epic. Also runs a bug-status
  story handed off by `pact fix` (bug-fix mode).
argument-hint: "[story-path] | [story-ids...] | --epic NN | --story ID | --mode step|wave|spec|flow|dry"
allowed-tools: >-
  Read Write Edit Glob Grep Agent TodoWrite
  Bash(pact *) Bash(git *)
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/no-ai-guard.sh"
---

# build — TDD story implementation

Cycle per story: plan -> RED -> GREEN -> refactor -> QA -> complete. Full
orchestration contract in
[`wave-orchestration.md`](../../references/wave-orchestration.md); fan-out rules in
[`subagent-fanout.md`](../../references/subagent-fanout.md). Next step:
`pact review` (if `steps.review`) or `pact ship`.

## Progress tracking

Open a `TodoWrite` list: one item per phase, plus one per wave once the wave plan
is known.

## Phase 0 — schema gate

`pact schema --gate`. Mismatch -> `/pact:migrate`.

## Phase 1 — scope

Parse `$ARGUMENTS`:

- a **story path** -> that one story, inline (validate its frontmatter first).
- **story ids** (`01-02 01-05`) -> one wave.
- **`--epic NN`** -> every non-`done` story of that epic, in waves.
- **`--story ID`** -> force inline even if peers exist.
- **empty** -> the current spec's non-`done` stories, in waves. If no spec is
  active, pick interactively from `FEATURE_INDEX.md`.
- **`--mode`** sets the execution mode for this run (see Phase 5). No `--mode` ->
  ask once with `[workflow].default_exec_mode` as the default.

A dispatch prompt beginning `MODE: delegated` means this run **is** a
`story-implementer` worktree agent — follow `agents/story-implementer.md` and
skip the rest of this file.

## Phase 2 — active-spec lock

One active spec at a time from here through merge. If another spec's
`spec/<id>` branch exists and is unmerged and it is not the spec in scope, **stop**:
tell the user to finish it or `pact ship --abandon <id>`. Otherwise the spec in
scope becomes the active spec.

## Phase 3 — bug-fix mode detection

If the target story's `status` is `bug`, run bug-fix mode: implement the Fix Plan
recorded in the story body, keep the diff minimal (no new scope), re-test **all**
of the story's acceptance criteria, restore `status` to `prior_status` (usually
`done`). Then Phase 8.

## Phase 4 — wave plan

`pact wave-plan <plan-dir> [--epic NN | --spec SP-id]`. Announce the waves
(count, contents, order) — the user may stop here. A single-story scope skips
worktrees and runs inline.

Cut the spec branch `spec/<SP-id>-<slug>` from the target branch if it does not
exist. This is also the rehearsal branch.

## Phase 5 — run the waves

Load the **shared context once** (`project.md`, constitution, `stack.toml`,
`accepted` DRs, team skills if `steps.team`, UI direction) — pass it verbatim into
every dispatch; agents never re-read it.

For each wave (respecting the execution mode's pause points):

1. **Isolation** — per `[env].isolation`, allocate a slice per story
   (compose project name `pact_w<N>`, or `PORT`/`DATABASE_URL` values, or
   "serialized"). Record in `.pact/wave.lock`. `serialize` -> run the wave's
   stories one at a time, no worktrees.
2. **Dispatch** — one `Agent` (`subagent_type: general-purpose`, or the registered
   `story-implementer`) per story in a single message, `model:` from the
   reasoning signal (`novel algorithm / concurrency / security / perf-critical`
   -> `[build].model_advanced`, else `model_balanced`). Each prompt carries: the
   story id + path, the frozen shared context, the isolation slice, the return
   schema, and "write only your scope + your story file; do not prompt; do not
   touch shared files or run `pact views`".
3. **Collect** typed returns. A failed/empty agent is recovered or redone inline.
4. **Drift check** — `files_touched` vs the story's concern; flag anything well
   outside it.
5. **Merge rehearsal** — merge each story branch into the spec branch in id
   order. First conflict -> the `conflict-analyzer` agent -> `auto` (apply patch),
   `serialize` (move the losing story to the next wave, re-run `wave-plan`),
   `manual` (surface hunks, pause). >1 conflict in a wave -> serialize more of
   the remaining spec.
6. **Wave test** — `pact env test`. Green -> record it against the spec-branch
   SHA. Red -> QA loop (max 3) then escalate, or roll back the wave.
7. `pact views` once, after the wave settles.

## Phase 6 — verification gate (batched)

After all waves are green, run **one** verification gate for the whole set
(method by project type — Web UI: Chrome-driven or steps; CLI: run + expected
output; Library/API: example calls; Backend: curl / smoke). `[workflow].manual_gate`
= `drive` | `steps` | `off`. Inline single-story runs did this immediately at
their phase 6.

## Phase 7 — complete

`pact views` again on exit. Report: stories done, waves run, the spec-branch SHA
and its recorded green, and the next command.

## Phase 8 — hand-off

Offer `pact review` (if `steps.review`) else `pact ship`, arguments pre-filled.
Under `--mode flow`, run it directly (respecting the hard stops).

## Execution modes

`step` pause per story · `wave` pause per wave · `spec` no pauses, hard stops
only · `flow` auto-chain `build -> review -> ship` while nothing blocks · `dry`
show the wave plan and stop.

**Hard stops override every mode:** the verification gate, QA escalation after 3
iterations, an unresolvable `manual` conflict, `review` NEEDS FIXES that is not
auto-fixable, a destructive-action confirmation, human PR approval.

## Hard gates

- RED before GREEN, every story, no exception.
- One active spec at a time.
- The fan-out decision (count vs the threshold of 3) is announced before any
  story is dispatched.
- Shared writes (spec-branch merges, `pact views`, `.pact/wave.lock`) happen only
  in this orchestrator, never in a subagent.
- Never `git push` here — that is `ship`.

## Rules

- Regenerate views once per wave and once on exit — never per story.
- A story that fails its own QA after 3 iterations leaves the wave, goes back to
  `status: todo`, and is reported; the rest of the wave continues.
- `.pact/wave.lock` is freed at wave-set end (and on a clean interrupt).
