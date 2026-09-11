---
name: config
description: >-
  Conversational editor for PACT settings — .pact/config.toml, stack.toml, the
  constitution; plus `statusline install` and `project expand`. The user never
  hand-edits a config file.
argument-hint: "[show | statusline install | project expand | <what to change>]"
allowed-tools: >-
  Read Write Edit Glob Grep
  Bash(pact *) Bash(git status*)
  AskUserQuestion
---

# config — change PACT settings

See [`workflow-map.md`](../../references/workflow-map.md). Read-only inspection
does not gate on schema; any write does (`pact schema --gate`).

## Modes

### `show`

Print the current `config.toml` and `stack.toml` values grouped by section, plus
the constitution version and which `[steps]` are on.

### `statusline install`

The main status line must live in user or project `settings.json` (a plugin
cannot set it). Ask: user-level (`~/.claude/settings.json`) or project-level
(`.claude/settings.json`). Add:

```json
"statusLine": { "type": "command", "command": "<abs path>/scripts/statusline.sh" }
```

Refuse to overwrite an existing `statusLine` unless the user passes / confirms
`--force`. Back the file up first. The script always renders model / dir /
context-window usage; it adds the PACT segment (flow mode, project, spec/story
progress) only inside a PACT project — so a user-level install is safe
everywhere and never goes blank outside PACT.

### `project expand`

Turn `.pact/project.md` into a fuller PRD under `docs/` and, optionally, create
`status: draft` spec stubs — one per capability the brief implies, with
`depends_on` where an ordering is implied. The user activates them one at a time
with `pact spec <slug>`.

### free text ("turn on review", "switch to squash merges", "notify me on failures")

1. Identify the target key(s) in `config.toml` / `stack.toml` / the constitution.
2. Show the current value, propose the new one, confirm.
3. Edit the file in place.
4. **Backfill** when turning a step on: `design_docs` -> offer `pact design`;
   `constitution` -> offer to author the charter now; `team` -> offer
   `pact team`; `issue_tracking` -> note that `pact ship --to-issues` publishes
   the plan.
5. Editing the constitution bumps its version header.
6. Changing `flow` `lite -> full` -> walk the newly-relevant toggles.
7. Sound: "notify me" / "play a sound when it needs me" -> `[notify].sound`
   (`attention` for waits + failures, `all` for everything); mention `method`
   (`auto` | `bell` | `command`) and that `PACT_NOTIFY=off` mutes it.

## Hard gates

- Never leave a `.toml` file syntactically broken — re-read after editing.
- A constitution edit always bumps the version.
- `statusline install` never overwrites an existing `statusLine` without
  explicit `--force`.

## Completion report

What changed, in which file, and any backfill offered.
