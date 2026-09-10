# Decision Records — shared contract

Always on. Not a toggle. Lightweight. Scope: **any** significant decision
(architecture, product, tooling, process, naming, tradeoff).

## File

`docs/decisions/NNNN-slug.md` — sequential number, zero-padded to 4.

```yaml
---
id: 0007
title: Server actions over a separate API for form submissions
kind: arch              # arch | product | tooling | process | naming | tradeoff
status: accepted        # proposed | accepted | superseded
date: YYYY-MM-DD
spec: SP-003             # the triggering spec, or ""
supersedes: ""           # id of the DR this replaces, or ""
superseded_by: ""        # filled when a later DR replaces this one
---

## Context
The problem, the forces in play, the constraints. Factual.

## Decision
What was chosen. One or two sentences, active voice.

## Alternatives considered
- <option> — <one line on why it was rejected>

## Consequences
- + <a gain>
- - <a cost or risk>
```

## Lifecycle

- **`proposed`** — drafted, awaiting the user's acceptance. Still editable.
- **`accepted`** — the user confirmed. **Immutable from here.**
- **`superseded`** — a later DR replaced it. It stays on disk (history); its
  `superseded_by` points to the replacement.

A change to an `accepted` DR is a **new** DR that sets `supersedes:`; the old one
flips to `superseded` + `superseded_by:`. Never edit an accepted DR in place.

A DR that changes a rule in the constitution also bumps the constitution version,
cited in its `## Consequences`.

## Auto-propose

`spec` / `plan` / `build` / `review` propose a DR when a decision has **real
alternatives** *and* is one of:

- hard to reverse (data model, public API, an infra dependency, a
  framework-level pattern),
- cross-feature (affects more than the spec in hand),
- contradicts or extends `project.md` or the constitution.

Below that threshold — a local, easily changed choice — write nothing
(reuse-first: no ceremony).

## Dedup

Before proposing, the phase reads the generated index
(`docs/decisions/README.md`). If a `proposed` or `accepted` DR already covers the
decision area, it is **not** re-proposed. One decision, one DR, regardless of how
many phases touch it.

A proposal the user **declines** leaves a one-line trace in the story's
`## Notes` — not a DR file.

## Index

`docs/decisions/README.md` is a generated view (`scripts/views.sh`): a table of
`id | title | kind | status | date`, newest first, `superseded` rows greyed.
Never hand-edited.

## Manual creation

`pact adr "<decision>"` — the agent drafts the four sections from the
conversation and the repo, the user confirms, the file is written and the index
regenerated.
