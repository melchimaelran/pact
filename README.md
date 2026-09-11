# PACT

**P**ragmatic, **A**gent-**C**ontrolled, **T**erminal-based — a spec-driven
software-engineering methodology delivered as a Claude Code plugin.

---

If you have run an AI agent on a real codebase, you know the failure mode: the
agent works file by file, you think in architecture, and the two drift apart. The
spec you wrote goes stale. A feature gets reimplemented because nobody checked.
Tests get skipped under deadline pressure, and *done* quietly stops meaning
*tested*.

PACT keeps the spec, the plan, and the implementation locked together — and
refuses to ship code without a failing test first, a decision trail, and a status
you can trust.

## How it works

Four moves, driven from the terminal:

```
spec  ->  plan  ->  build  ->  ship
```

- **spec** — the precise *what*, as a reviewable document. Nothing is coded
  without one.
- **plan** — the *what* becomes epics and stories with dependencies.
- **build** — Test-Driven implementation, in dependency-ordered parallel waves.
- **ship** — a conventional commit, a pull request, issue links, a merge.

A run looks like this:

```
/pact:init                              configure once — a guided questionnaire
/pact:spec feat "contact form"          draft the spec, answer the clarifications
/pact:plan docs/specs/.../spec.md       1 epic, 3 stories
/pact:build                             wave 1: form + send action in parallel
                                        wave 2: wiring (depends on both)
                                        gate: fill the form, submit, see success
/pact:ship                              commit, PR, squash merge
```

## Quickstart

```
# once per machine
/plugin marketplace add melchimaelran/pact
/plugin install pact@pact
# restart the session

# once per project
/pact:init
```

Then `/pact:spec <type> "..."` to start work, `/pact:status` to see where things
stand, `/pact:check` to find what is broken. `/pact:help` lists every command.

## Why PACT

- **Spec-driven, and it is enforced.** Every change starts with a typed spec
  (`feat | fix | adjust | refactor | perf | chore | docs`). `plan` and `build`
  read it; `review` checks the code against it.
- **TDD is not optional.** RED before GREEN, in every mode, no exception. `build`
  runs the full suite, lint, typecheck, and build before a story is `done`.
- **State cannot drift.** Story status lives in one place — the story file's
  frontmatter. Every index is a generated, read-only view of it. There is no
  reconciler because there is nothing to reconcile.
- **Decisions are recorded.** Every significant choice with real alternatives
  becomes an immutable Decision Record, so nobody re-litigates a settled call.
- **Real parallelism, safely.** Independent stories build at once in git
  worktrees, merge through a rehearsal branch, and a conflict analyzer decides
  auto-resolve / re-serialize / hand to you — before anything touches your target
  branch.
- **Deterministic work stays out of the model.** Numbering, wave planning, view
  rendering, dashboards, health checks — all POSIX scripts, zero tokens.

### Principles

- **Pragmatic** — ceremony scales to the work. `lite` mode is the spine only;
  `full` adds governance and quality layers. Configuration is long and upfront so
  execution runs without interruption.
- **Agent-Controlled** — the agent owns the loop: routing, hand-offs, subagent
  fan-out, the TDD cycle, the QA loop.
- **Terminal-based** — driven entirely from Claude Code, no mandatory web step.

### What PACT does not do

- It is not portable — Claude Code only.
- It does not manage CI/CD or deployment. Those are project-specific; make them a
  normal `spec`. `ship` stops at commit + push + PR + merge.
- It never commits a hook that blocks a session.

## Concepts

**The four documents.** `.pact/project.md` (what the app is, for whom, which tech
does what), `.pact/stack.toml` (how to install/test/build/run), the optional
`.pact/constitution.md` (the rules the code must obey — not the method's own
rules), and one `spec.md` per piece of work. Everything else — indexes, roadmaps,
the `CLAUDE.md` section — is generated.

**Two axes.** `status` (`todo -> in-progress -> done`, plus `skip`, `bug`) is the
work. `delivery` (empty `-> pr -> merged`, or `direct`) is how far it travelled
toward the trunk. *Done* and *shipped* are different facts.

**lite vs full.** The pipeline is identical — `spec -> plan -> build -> ship`,
with TDD, waves, and Decision Records, always. `full` adds: a deeper plan, the
constitution gate, `review`, `design` and `team`, a pre-commit re-check, tunable
model tiers. Switch any time with `/pact:config`.

**One active spec at a time.** From `build` through merge, one spec holds a lock.
New spec branches are cut from an up-to-date target branch, so cross-spec merge
conflicts cannot arise. Many specs can be drafted and planned concurrently.

**Sound, if you want it.** Off by default. `/pact:config` turns it on
(*"notify me on failures"* → only waits and failures, or everything) and off
again the same way — so you can start a long parallel build and walk away.
Backgrounded, zero model tokens, never blocks a turn. `PACT_NOTIFY=off` mutes it
without touching the config.

## The workflow

```
/pact:init
   |
/pact:spec  <type> "..."
   |
[ /pact:design ] [ /pact:team ]      optional layers, full mode
   |
/pact:plan  <spec.md>
   |
/pact:build
   |
[ /pact:review ]                     optional layer, full mode
   |
/pact:ship
```

Each finished command offers the next as a one-click, arguments filled in. You
say yes or no — nothing auto-chains, except `build --mode flow`, which runs
`build -> review -> ship` straight through while nothing blocks. Anytime:
`/pact:help`, `/pact:status`, `/pact:check`, `/pact:config`, `/pact:adr`,
`/pact:security`. For a bug: `/pact:fix`.

## Documentation

- **[docs/COMMANDS.md](docs/COMMANDS.md)** — every command, its flags, and what it
  does; plus worked walkthroughs for an existing project and a project with a PRD.
- **[docs/CONFIG.md](docs/CONFIG.md)** — every `config.toml` and `stack.toml`
  key, resource isolation, the files PACT creates, the status line, the hooks.
- **[docs/DESIGN.md](docs/DESIGN.md)** — the design rationale and the internals.
- **[CHANGELOG.md](CHANGELOG.md)** — what each version changes. PACT is in `0.x`;
  the framework evolves between releases.

## Install details

Installing the plugin makes it *available*; it only *runs* where `/pact:init`
opted it in (via the project's `.claude/settings.json` `enabledPlugins`).
Everywhere else it is inert — no commands, a silent `SessionStart` hook, no status
line. The only cost is a few hundred tokens of command descriptions in the
session prompt.

Commit `.pact/`, `.claude/settings.json`, `CLAUDE.md`, and `.gitignore`. A
teammate who has installed the plugin picks it up automatically when they open the
project.

For local development of PACT itself, add the marketplace by path:
`/plugin marketplace add /absolute/path/to/pact`.

## Team workflow

State lives in git — story files, specs, decisions, config — so a teammate who
pulls `main` sees exactly where every spec stands. Only `.pact/wave.lock`,
`.pact/green`, `.pact/cache/`, `.pact/tmp/`, and `pact-wt/` are gitignored: all
transient, regenerated per run.

The active-spec lock (above) is the branch itself: `pact build` refuses a second
spec while another `spec/<id>` branch is unmerged. That only protects a teammate
once the branch is pushed, so push it as soon as `build` starts, not at the end.

Generated views (`STORIES_INDEX.md`, `FEATURE_INDEX.md`,
`docs/decisions/README.md`) are committed and can still conflict like any text
file on merge or rebase. Don't hand-resolve them — take either side and rerun
`pact views`.

Nothing stops two people from targeting the same `spec/<id>`; treat it like any
shared feature branch and agree who's driving before running `build`.

## Updating

```
/plugin update pact@pact
```

then restart the session (`/plugin marketplace update pact` first if the
marketplace metadata changed). If a release changed the on-disk `.pact/` layout,
the next write-command is gated until `/pact:migrate` runs — a one-shot,
revertable commit.

## FAQ

**Do I have to install it globally?** No — it only runs where `/pact:init` opted
it in. Everywhere else it is inert.

**Can I run two builds at once?** No. One spec holds the active lock from `build`
through merge. Many specs can be drafted and planned concurrently.

**What if I skip the spec and just start coding?** PACT will not. A one-line
change is a `chore` or `docs` spec that skips `plan` and goes straight to
`build`.

**Does it work without GitHub?** Yes — `vcs.platform = local` does commits and
local merges with no PR. GitHub Issues and Projects are optional add-ons.

## License

[MIT](LICENSE)
