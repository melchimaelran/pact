# PACT

**P**ragmatic, **A**gent-**C**ontrolled, **T**erminal-based — a spec-driven
software-engineering methodology delivered as a Claude Code plugin.

> **Status: early.** All commands are implemented; the deterministic engine
> (scaffold, wave planning, view generation, health checks) is tested. The
> model-driven flows have not yet had a real end-to-end run. Expect rough edges.
> The full design is [`docs/DESIGN.md`](docs/DESIGN.md).

## The idea

PACT turns an idea into merged code through four moves the agent drives from the
terminal:

```
spec  ->  plan  ->  build  ->  ship
```

- **spec** — the precise *what*, written as a reviewable document. Nothing is
  coded without one. Typed: `feat | fix | adjust | refactor | perf | chore |
  docs`.
- **plan** — the *what* becomes epics (vertical, demo-first) and stories with
  dependencies.
- **build** — stories are implemented with Test-Driven Development, in
  dependency-ordered parallel waves (git worktrees, a rehearsal merge, conflict
  analysis).
- **ship** — a conventional commit, a pull request, issue links, a merge.

Around the spine: `init`, `review`, `fix`, `security`, `status`, `check`,
`config`, `adr`, `migrate`, plus optional `design` and `team`.

### Principles

- **Pragmatic** — ceremony scales to the work. `lite` mode is the spine only;
  `full` adds governance and quality layers. Configuration is long and upfront so
  execution runs without interruption.
- **Agent-Controlled** — the agent owns the loop. Deterministic work — numbering,
  wave planning, view rendering, resource allocation, health checks — runs in
  POSIX scripts, never in the model.
- **Terminal-based** — driven entirely from Claude Code, no mandatory web step.

### What it keeps honest

- **One writable source of truth per story: its frontmatter.** Every index is a
  generated, read-only view — it cannot drift.
- **Two axes:** `status` (the work) and `delivery` (how far toward the trunk).
- **TDD is not optional** — RED before GREEN, in `lite` and `full`.
- **Decision Records are always on** — every significant choice, immutable once
  accepted.

## Install

```
/plugin marketplace add melchimaelran/pact
/plugin install pact@pact
```

Then, per project:

```
/pact:init
```

`init` runs the questionnaire, writes `.pact/`, and opts the plugin in for that
project. Everywhere else the plugin stays dormant (a few hundred tokens of
command descriptions, nothing more).

## First run

```
/pact:init                         # configure + scaffold
/pact:spec feat "..."              # write the spec, answer the clarifications
/pact:plan docs/specs/.../spec.md  # epics + stories
/pact:build                        # TDD waves
/pact:ship                         # commit, PR, merge
```

`/pact:status` shows where things stand; `/pact:check` reports what is broken and
how to fix it.

## Documentation

[`docs/DESIGN.md`](docs/DESIGN.md) — every command, the configuration schema, the
state model, wave orchestration, decision records, `lite` vs `full`, and worked
walkthroughs (new project, existing project, project with a PRD).

## License

[MIT](LICENSE)
