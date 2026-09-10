---
name: ship
description: >-
  Deliver the active spec — commit, push, open the PR, link issues, wait for CI,
  merge. --abandon returns a spec to planned. --to-issues publishes a plan to
  GitHub Issues.
argument-hint: "[--abandon SP-id] [--to-issues [--mode feature|epics|stories]]"
allowed-tools: >-
  Read Edit Glob Grep
  Bash(pact *) Bash(git *) Bash(gh *)
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/no-ai-guard.sh"
---

# ship — commit, PR, merge

See [`workflow-map.md`](../../references/workflow-map.md). GitHub links are by the
frontmatter `issue:` number, never by matching titles.

**No AI references** in any commit, PR body, issue comment, or branch name —
enforced by the `no-ai-guard` hook while this skill runs. Absolute.

## Phase 0 — schema gate

`pact schema --gate`. Exception: a standalone commit in a repo with no `.pact/`
is not a PACT project — just commit.

## Mode

- `--abandon SP-id` -> set that spec back to `status: planned`, delete its
  `spec/<id>` branch and any worktrees, free the active-spec lock, regenerate
  views. Stop.
- `--to-issues` -> publish the active plan to GitHub Issues (`--mode` =
  `feature` | `epics` | `stories`, default `epics`); write each created number
  into story/epic frontmatter `issue:`. Re-runnable; never creates twice. Stop.
- default -> **ship the active spec** (below).

## Phase 1 — pre-check

- The active spec's stories are all `status: done`.
- If `review_gate` is on: `pact review` returned PASS for the current
  spec-branch SHA.
- Current branch is `spec/<id>-<slug>` (or check it out).

## Phase 2 — preflight

If `[workflow].preflight` is on: `sha=$(git rev-parse HEAD)`. If
`pact green check spec/<id> $sha` succeeds -> skip with
"already verified at `<sha>`". Otherwise `pact env lint` + `pact env test`;
`pact green record` on green.

## Phase 3 — commit

Per-story commits already exist (from `build`). Make a final synthesis commit only
if there are unstaged plan/bookkeeping changes. `commit_style` from config:
`conventional` -> `<type>(<slug>): <summary>` using the spec's `type`.

## Phase 4 — push & PR

- `platform = local` -> skip; go to Phase 6 (local merge).
- else: `git push -u origin spec/<id>-<slug>`.
- Open the PR `spec/<id>` -> target branch. Body from the spec: goal, acceptance
  criteria, the story list, linked DRs. Append `Closes #NN` for every linked
  issue when `issue_tracking` is on.

## Phase 5 — issues & CI

- `issue_tracking` on -> update / close the linked issues; write back numbers.
- `ci_gate` on -> poll the PR checks; do not merge on red.

## Phase 6 — merge

`merge_strategy` (`squash` / `merge` / `rebase`), after approval if
`min_approvals > 0`. `platform = local` -> merge `spec/<id>` into the target
branch locally with the same strategy.

## Phase 7 — post-merge

- Set every story `delivery: merged` (via `pact story set`), the spec
  `status: done`.
- Delete the merged branch and any worktrees; `pact views`.
- **project.md patch** — diff what this spec added (new dirs / modules / services
  / integrations, from the story diffs + `accepted` DRs) against `project.md`'s
  structure and tech->role map. On drift, propose a minimal patch; the user
  confirms.
- `deploy_prompt` (`on-merge` | `manual` | `none`) -> print the reminder. PACT
  does not deploy.
- Free the active-spec lock.

## Phase 8 — hand-off

`pact status`, or the next spec.

## Hard gates

- No AI references anywhere — the hook enforces it; do not try `--no-verify`.
- Never merge on red CI when `ci_gate` is on.
- Never merge without approval when `min_approvals > 0`.
- Confirm before the push and before the merge (outward, hard to reverse).

## Completion report

The commit(s), the PR URL (or the local merge), issues closed, `delivery` state,
any project.md patch, and the next command.
