---
name: check
description: >-
  Project health report — schema, frontmatter, index drift, unresolvable
  blocked_by, orphan spec branches, the managed .gitignore block, uncommitted
  .pact. Names the fix for each finding. Read-only.
argument-hint: "[--quiet]"
allowed-tools: Bash(pact check*) Bash(pact views*)
---

# check — health report

Run `pact check` and relay the output. Read-only; does not gate on schema.

Each finding names the command that fixes it. Common ones:

- `schema … != plugin …` -> `/pact:migrate`
- `.gitignore managed block missing` -> `pact gitignore`
- `index older than a story file` -> `pact views`
- `blocked_by '…' resolves to no story` -> correct the frontmatter or
  `pact plan --quick`
- `branch spec/… has no matching spec` -> delete the branch or restore the spec

If the user asks you to fix everything, apply the safe mechanical fixes
(`pact views`, `pact gitignore`) and report the rest for them to decide.
