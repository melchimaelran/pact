---
name: security
description: >-
  On-demand defensive security audit of this repository and its local dev
  instance. Turns findings into type:fix spec stubs. Never auto-runs, never
  auto-fixes, never touches third-party systems.
argument-hint: "[--deps] [--scope PATH] [--deep]"
allowed-tools: >-
  Read Write Glob Grep Agent TodoWrite
  Bash(pact *) Bash(git status*) Bash(date *)
  Bash(npm audit*) Bash(pnpm audit*) Bash(yarn audit*) Bash(pip-audit*)
  Bash(cargo audit*) Bash(osv-scanner*) Bash(curl *)
---

# security — audit, then generate fix specs

The normal flow already carries a security baseline (the constitution's Security
axis, `review`'s security dimension, `build` phase-5 QA). This is the deep,
opt-in pass. It **generates work**, it does not change code.

## Progress tracking

`TodoWrite`: one item per phase, plus one per audit pass in `--deep`.

## Phase 0 — schema gate

`pact schema --gate`.

## Phase 1 — scope

- `--deps` -> dependency vulnerabilities only.
- `--scope PATH` -> limit the SAST review to that path.
- `--deep` -> fan out: independent `security-auditor` passes with focuses
  `injection` / `auth` / `crypto` / `config`. Announce the decision.
- default -> one full `security-auditor` pass.

## Phase 2 — audit (isolated, defensive only)

Dispatch `agents/security-auditor.md`. It covers, in scope:

- SAST — injection (SQLi, XSS, command, path traversal), authn/authz gaps, secret
  leakage, insecure deserialization, SSRF, CSRF, weak crypto, unsafe defaults.
- Dependencies — the stack's audit tool.
- Config — exposed env, permissive CORS, missing security headers, debug mode.
- Compliance — the constitution's Security axis; authz logic vs `project.md` and
  `accepted` DRs.
- Light DAST — only if `[env].dev` runs the app locally; probe the **local**
  instance, no aggressive testing.

It returns typed findings with `severity`, `category`, `file:line`, `evidence`,
`recommendation`, `cwe`. **No fixes.**

## Phase 3 — report

Print the findings table, grouped by severity. This is the only output that is
always produced.

## Phase 4 — generate spec stubs

For each actionable finding (or a group sharing a root cause), create a
`type: fix` spec stub under `docs/specs/<date>_<slug>/`:

- frontmatter `type: fix`, `security: true`, `status: draft`.
- `## Context` — the finding, its `cwe`, its `file:line`.
- `## Fix Requirements` — the recommendation, scoped tight.
- `## Acceptance Criteria` — a test that would have caught it, plus no
  regression.

List the stubs, ordered by severity. The user picks which to act on; each runs
the normal `pact spec` (to refine) -> `pact plan` -> `pact build` -> `pact ship`
flow.

## Phase 5 — accepted risk

A finding the user decides not to fix -> record a DR
(`kind: tradeoff`, "accepted security risk: X because Y"), after checking the
index.

## Hard gates

- Defensive only — never scan or probe a system that is not this repo or its
  local dev instance.
- Never write a fix. The output is findings + draft spec stubs.
- Never auto-run (this skill is only invoked explicitly).

## Completion report

The findings count by severity, the spec stubs created, and how to act on them.
