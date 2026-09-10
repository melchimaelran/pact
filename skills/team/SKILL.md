---
name: team
description: >-
  Optional. Derive project-tailored expert and language-guide skills from the
  stack, the constitution, and the code, into .claude/skills/. Only when
  steps.team is on. --regenerate refreshes them merge-safe.
argument-hint: "[--basic|--standard|--max] [--regenerate] [--check]"
allowed-tools: >-
  Read Write Glob Grep
  Bash(pact *) Bash(git status*) Bash(ls *) Bash(mkdir *)
---

# team — project-tailored skills (optional)

Runs only when `[steps].team` is on. Auto-loaded by `build` when a story's touched
paths match a generated skill's `paths:`. With `[steps].team` off, `build` reads
`stack.toml` + the constitution + `CLAUDE.md` only.

## Phase 0 — schema gate

`pact schema --gate`. Check `[steps].team` is `true`; if not, point the user at
`/pact:config`.

## Phase 1 — detection

From `stack.toml` + (if `[steps].design_docs`) `docs/architecture/`, else the
codebase, list the units that a real signal justifies:

- `guide-<language>` per detected language.
- `guide-<framework>` per major framework.
- `expert-qa` always. `expert-security` when auth / secrets are present.
  `expert-database` when there is a schema. `expert-api` when there are routes.

Breadth gate: `--basic` (languages + qa) / `--standard` (default — + frameworks +
core-idiom libraries) / `--max` (the finest justified split).

## Phase 2 — research (opt-in)

Only if `[team].context7` is `true`: fetch current, version-specific framework
docs. Off by default (token cost) — otherwise rely on the code + model knowledge.

## Phase 3 — generate

One `SKILL.md` per unit at `.claude/skills/<name>/SKILL.md`:

- frontmatter: `name`, `description`, `paths:` (globs that auto-load it),
  `keywords:`.
- body: this project's folder layout, naming conventions, test patterns, and
  framework idioms — **derived from the code**, not invented. A hand-editable
  `## House rules` section.

## Phase 4 — merge-safe write

For an existing generated skill, refresh the derived sections but **preserve** any
`## House rules` edits. `--check` reports which units are missing / present for
the resolved tier and stops. `--regenerate` refreshes all of them.

## Reuse-first

Generate only what a real signal demands. Research only what is current,
version-specific, or project-specific — never well-known fundamentals.

## Hard gates

- Never generate when `[steps].team` is off.
- Never clobber a `## House rules` section on regenerate.
- One skill, one top-level `.claude/skills/<name>/` folder — never nested.

## Completion report

The skills generated / refreshed, the tier used, and the next command
(`pact plan`).
