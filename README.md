# PACT

**P**ragmatic, **A**gent-**C**ontrolled, **T**erminal-based — a spec-driven
software-engineering methodology delivered as a Claude Code plugin.

> **Status: pre-release.** The design is complete and lives in
> [`docs/DESIGN.md`](docs/DESIGN.md). Implementation is in progress; no commands
> work yet.

## The idea

PACT turns an idea into merged code through four moves the agent drives from the
terminal:

```
spec  ->  plan  ->  build  ->  ship
```

- **spec** — the precise *what*, written as a reviewable document. Nothing is coded
  without one.
- **plan** — the *what* becomes epics and stories with dependencies.
- **build** — stories are implemented with Test-Driven Development, in
  dependency-ordered parallel waves.
- **ship** — a conventional commit, a pull request, issue links, a merge.

Around that spine: `init`, `review`, `fix`, `security`, `status`, `check`,
`config`, `adr`, `migrate`.

### Principles

- **Pragmatic** — ceremony scales to the work. `lite` mode is the spine only;
  `full` adds governance and quality layers. Configuration is long and upfront so
  execution runs without interruption.
- **Agent-Controlled** — the agent owns the loop. Deterministic work (numbering,
  wave planning, view rendering, resource allocation) runs in scripts, never in
  the model.
- **Terminal-based** — driven entirely from Claude Code, no mandatory web step.

## Install

```
/plugin marketplace add melchimaelran/pact
/plugin install pact@pact
```

Then, per project:

```
/pact:init
```

`init` writes `.pact/` and opts the plugin in for that project. Elsewhere the
plugin stays dormant.

## Documentation

- [`docs/DESIGN.md`](docs/DESIGN.md) — the complete design: every command, the
  configuration schema, the state model, wave orchestration, decision records,
  `lite` vs `full`, and worked walkthroughs.

## License

[MIT](LICENSE)
