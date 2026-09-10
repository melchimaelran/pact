---
name: adr
description: >-
  Create a Decision Record by hand. The agent drafts Context / Decision /
  Alternatives / Consequences from the conversation and the repo; the user
  confirms; the file is written and the index regenerated.
argument-hint: "\"<the decision>\""
allowed-tools: >-
  Read Write Glob Grep
  Bash(pact *) Bash(git status*) Bash(date *)
---

# adr — a Decision Record by hand

Contract: [`decision-records.md`](../../references/decision-records.md).

## Phase 0 — schema gate

`pact schema --gate`.

## Phase 1 — dedup

Read `docs/decisions/README.md`. If a `proposed` or `accepted` DR already covers
this decision area, say so and stop (offer to supersede it instead if the user
wants a change).

## Phase 2 — draft

- `id` from `pact adr-id`. `date` from `date +%F`.
- `kind` — one of `arch | product | tooling | process | naming | tradeoff`;
  infer, confirm.
- Draft the four sections from the conversation, `project.md`, and the code:
  - **Context** — the problem, the forces, the constraints. Factual.
  - **Decision** — one or two sentences, active voice.
  - **Alternatives considered** — each rejected option + one line why.
  - **Consequences** — `+` gains and `-` costs/risks.
- If this decision changes a constitution rule, note that in `## Consequences`
  and bump the constitution version.

## Phase 3 — confirm & write

Show the draft. On confirmation, write
`docs/decisions/NNNN-<slug>.md` with `status: accepted` (or `proposed` if the
user wants to sit on it), then `pact views`.

## Hard gates

- Never edit an existing `accepted` DR — a change is a new DR with `supersedes:`.
- Always regenerate the index after writing.

## Completion report

The DR path, its id and kind, and whether it superseded another.
