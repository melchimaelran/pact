---
name: design
description: >-
  Optional. Turn a spec into feature-scoped architecture docs under
  docs/architecture/ (global docs + one self-contained doc per feature). Only
  when steps.design_docs is on. Also `sync` and `optimize` maintenance modes.
argument-hint: "[<path-to-spec.md> | sync | optimize]"
allowed-tools: >-
  Read Write Edit Glob Grep
  Bash(pact *) Bash(git status*) Bash(mkdir *)
---

# design — architecture documentation (optional)

Runs only when `[steps].design_docs` is on. Sits between `spec` and `plan`: `plan`
reads these docs to cut better stories. If the toggle is off, `plan` works from
the spec + `project.md` + the code directly and this skill is not needed.

## Phase 0 — schema gate

`pact schema --gate`. Also check `[steps].design_docs` is `true`; if not, tell the
user to enable it with `/pact:config` or skip straight to `pact plan`.

## Modes

### spec path (default)

Produce, under `docs/architecture/`:

- **Global docs** (create or keep consistent): `overview.md`,
  `folder-structure.md`, `tech-stack.md`, `_shared.md`.
- **One feature doc** per feature: `features/<slug>/index.md` with frontmatter
  `slug: <slug>` and `design: pending`, and sections **Components · Data ·
  Flows · API**. Self-contained — a later `build` story reads only this doc.

No journal or ledger docs — git is the design history. `plan` flips
`design: pending -> planned`.

### `sync`

Scaffold a `features/<slug>/index.md` for any feature that has a spec but no
architecture doc.

### `optimize`

Measure per-doc size, move content repeated across feature docs into
`_shared.md`, leave a reference in its place.

## Reuse-first

Read the existing docs, the spec, and related source first. Reuse a settled
section rather than rewriting it. Design the simplest structure that lets a story
be implemented from one feature doc.

## Decision records

An architecture choice with real alternatives and cross-feature impact -> propose
a DR (after checking the index).

## Hard gates

- Never generate architecture docs when `[steps].design_docs` is off.
- A feature doc is self-contained — a story must not need to read a second one.

## Completion report

The docs written or updated, and the next command (`pact team` if `[steps].team`,
else `pact plan`).
