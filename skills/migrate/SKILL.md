---
name: migrate
description: >-
  Upgrade the project's .pact/ layout to the schema this plugin build supports.
  One-shot, idempotent, refuses a dirty tree, lands one revertable commit.
argument-hint: ""
allowed-tools: >-
  Read Glob Grep
  Bash(pact *) Bash(git status*) Bash(git diff*) Bash(git add*) Bash(git commit*)
---

# migrate — upgrade the .pact schema

Runs when a write-command's Phase 0 gate reports a schema mismatch, or on
request. Contract: `pact migrate` in `scripts/migrate.sh`.

## Steps

1. Read the project's current schema (`pact schema`) and the supported one
   (`pact schema --supported`).
   - Equal -> nothing to do; say so and stop.
   - Project newer -> tell the user to update the plugin.
2. Confirm the working tree is clean. If not, stop and ask the user to commit or
   stash.
3. Run `pact migrate`. It applies each `scripts/migrations/NNNN-*.sh` step in
   order for every version between current and supported, restamps `schema`,
   regenerates the views, and commits
   `chore(pact): migrate .pact schema N -> M`.
4. Report what changed (the commit is revertable).

## Hard gates

- Never run on a dirty tree.
- Never skip a migration step — a missing step is an error, not a silent jump.
- The whole migration is one commit.

## Completion report

The from/to schema, the migration steps applied, the commit sha, and that any
blocked write-command can now run.
