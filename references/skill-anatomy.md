# SKILL.md Anatomy — how every PACT command is written

Every `skills/<cmd>/SKILL.md` follows this shape. Bulky templates and examples go
in `skills/<cmd>/references/*.md` (loaded on demand, read once per run). Shared
contracts live in repo-root `references/*.md` — link, never restate. Target 6–8
dense reference files total.

## Frontmatter

```yaml
---
name: <cmd>
description: >-
  When to use this command — one tight sentence. Drives Claude's auto-selection.
argument-hint: "<shape of $ARGUMENTS>"
allowed-tools: >-
  <the exact Bash(...) globs and tools this command needs, plus Skill>
hooks:              # only where relevant (ship, build, fix, spec)
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/no-ai-guard.sh"
---
```

Keep `description` to one sentence — it is in context in every session while the
plugin is installed.

## Body

1. **Title + purpose** — one paragraph: what the command does and its place in the
   flow. Link [`workflow-map.md`](workflow-map.md).
2. **Routing check (do first)** — "am I the right command?" If the real task
   matches a misuse-redirect row, stop and recommend the right command.
3. **Reuse-first note** — link [`reuse-first.md`](reuse-first.md): read existing
   context, reuse before rebuilding, simplest viable.
4. **Progress tracking** — a `TodoWrite` list, one todo per phase, updated as you
   go — **only for the long multi-phase commands** (`plan`, `build`, `review`,
   `security`, `migrate`). `spec`, `ship`, `status`, `check`, `config`, `adr` skip
   it.
5. **Phase 0 — schema gate** — read `.pact/config.toml` `schema`. A mismatch
   **blocks** and points to `pact migrate`. Read-only commands (`status`, `check`)
   run anyway. Not a PACT project (no `.pact/`) — say so and stop, unless the
   command explicitly handles that case (`init`).
6. **Phases 1..N** — the work, numbered, each with a goal, concrete steps, and an
   exit gate.
7. **Hard gates** — cross-phase invariants listed explicitly, so a skip is a
   visible failure. Examples: RED before GREEN; `fix` never writes the source fix
   during diagnosis; confirm before push / merge / destructive writes; one active
   spec at a time.
8. **Completion report** — what to tell the user: paths touched, resulting state,
   the next command.
9. **Hand-off** — offer the next step as a one-click with arguments pre-filled.
   Max chain depth 3; never invoke a command already on the chain. Auto-run only
   under `build --mode flow`.
10. **Rules** — terse dos and don'ts specific to this command.

## Determinism

Anything countable, renderable, or mechanical — numbering, wave planning, view
regeneration, dashboards, status, resource allocation, health checks — runs in
`scripts/*.sh` and is invoked via `bin/pact <subcommand>`, never reasoned out by
the model.

The plugin's `bin/` directory is on `PATH` for a skill's Bash calls, so a bare
`pact <subcommand>` resolves to `bin/pact`. A skill's `allowed-tools` lists
`Bash(pact *)` so those calls are pre-approved for the turn. If a host does not
put `bin/` on `PATH`, fall back to `"${CLAUDE_PLUGIN_ROOT}/bin/pact" <subcommand>`.
