---
name: status
description: >-
  Read-only project dashboard — specs, the active spec's stories, live
  worktrees. Rendered by a script, zero model tokens. --write dumps a
  tasks/ROADMAP.md snapshot.
argument-hint: "[--write]"
allowed-tools: Bash(pact status*)
---

# status — the dashboard

Run `pact status` (add `--write` to also snapshot `tasks/ROADMAP.md`) and relay
the output. This command is read-only: it never edits state. It does not gate on
schema — it works even when a `pact migrate` is pending.

If the user asks "what's next", point them at the first `todo` story with no
unmet `blocked_by` in the active spec, or at `pact spec` when there is no active
spec.
