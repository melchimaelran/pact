# Workflow Map — the PACT lifecycle

The single source of truth for the order of work and which hand-offs exist. Every
`SKILL.md` links here instead of restating the graph.

## The spine

```
pact init  ->  pact spec  ->  pact plan  ->  pact build  ->  pact review  ->  pact ship
                                              (optional)
```

- `init` — once per project. Config + scaffold.
- `spec` — the mandatory front door for every piece of work. Typed
  (`feat | fix | adjust | refactor | perf | chore | docs`).
- `plan` — spec -> epics/stories. Skipped when the spec is a trivial `chore` /
  `docs`.
- `build` — implement stories with TDD, in dependency-ordered parallel waves.
- `review` — feature-level audit. Runs only when `steps.review` is on.
- `ship` — commit, PR, issue links, merge.

## Optional layer commands

Run only when their `[steps]` toggle is on. Off -> `plan` and `build` work from
the spec + `project.md` + the code directly.

| Command | When | Role |
|---|---|---|
| `pact design` | `steps.design_docs` | spec -> feature-scoped architecture docs, between `spec` and `plan`. |
| `pact team` | `steps.team` | derive project-tailored expert / guide skills into `.claude/skills/`. |
| `pact review` | `steps.review` | feature-level audit between `build` and `ship`. |

## Support commands

| Command | Role |
|---|---|
| `pact fix` | Bug flow: diagnose -> failing test -> Fix Plan -> `build` (bug-fix mode). |
| `pact security` | On-demand security audit -> security-fix spec stubs. Never auto-runs. |
| `pact status` | Read-only dashboard. Script-rendered, zero model tokens. |
| `pact check` | Project health report; names the fix for each finding. |
| `pact config` | Conversational editor: config, stack, charter, `statusline install`, `project expand`. |
| `pact adr` | Create a Decision Record by hand. |
| `pact migrate` | Upgrade the `.pact/` schema. |

## Hand-offs

Each finished command offers the next as a one-click, arguments pre-filled. The
user says yes or no; nothing auto-chains **except under `build --mode flow`**.

| After | Offers |
|---|---|
| `init` | `pact spec` |
| `spec` (ready) | `pact plan` |
| `plan` (planned) | `pact build` |
| `build` (all stories done) | `pact review` if `steps.review`, else `pact ship` |
| `review` (PASS) | `pact ship` |
| `ship` (merged) | `pact status`, or the next spec |
| `fix` (easy) | auto-runs `build` (bug-fix mode) |
| `fix` (complex) | `pact build <fix-spec>` |
| `security` | `pact spec <picked stub>` |

Chain rules: max depth 3; a command may not invoke one already on the chain
(so `fix -> build -> fix` is structurally impossible).

## Misuse redirects — "am I the right command?"

Every action `SKILL.md` runs this check first. If the real task matches a row,
stop and recommend the command in the last column.

| Invoked | …but the task is actually | Use instead |
|---|---|---|
| `spec` | a plan already exists; you want to implement | `build` |
| `plan` | no spec yet | `spec` (first) |
| `plan` | a one-line chore / docs edit | still `spec` (type `chore`/`docs`) — it skips `plan` on its own |
| `build` | no plan for the work | `plan` (or `spec` if none) |
| `build` | an un-triaged bug in shipped code | `fix` (first) |
| `review` | the code is not implemented yet | `build` |
| `ship` | stories are not all `done` | `build` |
| `fix` | new behavior, not a bug | `spec` (type `feat`/`adjust`) |
| `security` | you already know the fix and want to apply it | `spec` (type `fix`) |
| any write command | `.pact/` schema is behind | `migrate` (first — the Phase 0 gate forces this) |

## State conventions

- Story `status` lives only in the story-file frontmatter
  (`todo -> in-progress -> done`, plus `skip`, `bug`). Every index is a generated
  view of it.
- Story `delivery` is the orthogonal axis (empty `-> pr -> merged`, or `direct`).
  `blocked_by` resolves against `status: done` only.
- One **active spec** at a time from `build` through merge. `spec` and `plan` may
  run for many specs concurrently.

See [`state-model.md`](state-model.md) for the full data model.
