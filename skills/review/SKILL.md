---
name: review
description: >-
  Feature-level audit of the active spec before shipping — spec-AC coverage,
  consistency vs plan/constitution/DRs/project.md, and a whole-diff code review.
  Runs only when steps.review is on. --project audits the whole codebase for
  architectural drift.
argument-hint: "[--effort quick|standard|deep] [--passes N] [--model M] [--project]"
allowed-tools: >-
  Read Glob Grep Agent TodoWrite
  Bash(pact *) Bash(git *)
---

# review — feature-level audit

Runs after `build` (all waves green + verification gate). Isolated subagent work
via `agents/reviewer.md`. Contract:
[`subagent-fanout.md`](../../references/subagent-fanout.md). Next step:
`pact ship`.

## Progress tracking

`TodoWrite`: one item per phase, plus one per review pass.

## Phase 0 — schema gate

`pact schema --gate`.

## Phase 1 — mode

- `--project` -> **project audit**: dispatch a `reviewer` over the whole
  codebase vs `project.md` + `accepted` DRs + the constitution. Output ->
  `type: refactor` / `type: chore` spec stubs (`status: draft`) under
  `docs/specs/`, one per material finding. Blocks nothing. Skip the rest.
- default -> **spec review** of the active spec.

## Phase 2 — suite freshness

`sha=$(git rev-parse spec/<id>)`. If `pact green check spec/<id> $sha` succeeds
and `[review].fresh_suite` is false -> reuse that green; do not re-run the suite.
Otherwise run `pact env test` once and `pact green record spec/<id> $sha` on
green.

## Phase 3 — dispatch

Effort from `--effort` or `[review].effort`:

- `quick` -> 1 pass, checks 1–2 only (AC coverage + consistency).
- `standard` -> 1 pass, the full checklist.
- `deep` -> `--passes` (or `[review].passes`, min 2) independent `reviewer`
  agents with focuses `correctness` / `security` / `architecture`, `model:` from
  `[review].model` (or `advanced`). Announce the fan-out decision.

Each `reviewer` gets: the spec, the plan, the spec-branch diff vs the target
branch, the constitution, `project.md`, `accepted` DRs, its focus, and the return
schema.

## Phase 4 — converge

Merge findings across passes, dedupe, rank by severity. Verdict is `NEEDS_FIXES`
if any pass returned it or any CRITICAL finding exists; else `PASS`.

## Phase 5 — handle

- **PASS** -> report, hand off to `pact ship`.
- **NEEDS_FIXES**:
  - Auto-fix `low` / `medium` per `[review].auto_fix`, then re-run the affected
    checks.
  - CRITICAL / HIGH -> `pact notify fail`, then back to a targeted
    `pact build <story>` (or list them for the user).
  - A charter violation -> Option B: show it, offer "proceed anyway", log to
    `.pact/charter-overrides.log` on confirmation.
- `review_gate` on + `NEEDS_FIXES` unresolved -> `ship` stays blocked.

## Decision records

A significant undocumented decision surfaced by the review -> propose a
retroactive DR (after checking the index).

## Hard gates

- Never modify source beyond the sanctioned `low`/`medium` auto-fix.
- CRITICAL always fails the verdict.
- The fan-out decision is announced before any pass runs.

## Completion report

The verdict, findings by severity, what was auto-fixed, what was handed back, and
the next command.
