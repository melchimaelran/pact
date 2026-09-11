# Changelog

All notable changes to PACT are documented here. The format follows the
Keep a Changelog convention, and PACT versions follow Semantic Versioning.

PACT is in `0.x`: the framework — prompts, flows, skill wording — changes freely
between releases, and every `0.x` release is a pre-release. The on-disk `.pact/`
**schema** is a separate track — it only bumps when the layout of files a project
keeps changes, and each such bump ships a migration step. A breaking change to
that on-disk layout only happens on a major version.

## [Unreleased]

### Changed
- **Statusline, colored.** `scripts/statusline.sh` now always renders a
  colored base segment — model, folder, full path, context-window usage
  (green/yellow/red by threshold), total tokens — plus, inside a PACT
  project, a colored PACT segment (flow mode, project, spec/story/worktree
  progress). The base segment renders everywhere, not just PACT projects, so
  a user-level install is a sane statusline baseline on its own.

## [0.3.0] — 2026-09-11

### Added
- **Stack runtime versioning** — `stack.toml` gains `version_manager`
  (`fnm`/`nvm`/`volta`/`asdf`/`mise`/`pyenv`/`rbenv`/`none`) and `version_file`
  (`.nvmrc`, `.tool-versions`, …); `runtime` now recommends an exact pinned
  version instead of a bare major. `/pact:init`'s stack block asks for it
  (skipped where version-insensitive, e.g. Go/Rust) and detects it from an
  existing pin file in ADOPT. Optional keys — no schema bump.
- **Full statusline** — `scripts/statusline.sh` now renders model, current
  dir, and context-window usage from the JSON Claude Code already pipes to a
  `statusLine` command, always, not just inside a PACT project. Inside one, it
  layers flow mode (`[lite]` / `[full]`), project name, and the spec/story/
  worktree progress on top.
- **`review` on by default in `lite`** — previously off (`build`'s per-story
  QA was the only check). Both modes now default `review.effort` to `deep`,
  with `passes` clamped to 2–3 — one per focus (correctness/security/
  architecture), no 4th to hand out. `lite`: 2 passes, `haiku`, advisory (no
  `review_gate`). `full`: 3 passes, `sonnet` (was `auto`), `review_gate` stays
  on.
- `/pact:init`'s existing-docs scan (ADOPT) also looks for PRD/requirements/
  architecture docs, and asks where a missing expected doc lives instead of
  inferring project intent.
- `/pact:init` Block 1 now asks for sound notifications (`off` default /
  `attention` / `all`) up front — previously only reachable after the fact via
  `/pact:config`.

## [0.2.0] — 2026-09-10

### Added
- **`/pact:help`** — the command map. `/pact:help` lists every command grouped
  by pipeline / optional layer / anytime, each with its syntax and description,
  plus the `spec -> plan -> build -> ship` spine; `/pact:help <command>` prints
  one command's syntax and full description. Script-rendered (`scripts/help.sh`),
  zero model tokens, works before `/pact:init`. The command count is now 16.
- **Sound notifications** — a short sound when a turn finishes, when PACT is
  waiting on you, when a build wave settles, and on an escalation (QA loop
  exhausted, unresolvable conflict, review `NEEDS_FIXES`, failed verification
  gate). New `Stop` / `Notification` hooks plus `pact notify` calls from `build`
  and `review`, all via `scripts/notify.sh` — backgrounded, zero model tokens,
  can never delay or fail a turn. Off by default; turn it on and off any time
  through `/pact:config` — `[notify].sound` (`attention` = waits + failures,
  `all` = everything), `[notify].method` (`auto` system sound / terminal `bell`
  / your own `command`). `PACT_NOTIFY=off` mutes it everywhere without editing
  the config. The `[notify]` block is optional — no schema bump.

### Changed
- README restructured as a pitch-first entry point (~190 lines). The exhaustive
  command reference moved to `docs/COMMANDS.md`, the configuration reference to
  `docs/CONFIG.md`.

## [0.1.0] — 2026-09-10

First working release. The full spine and its support commands are implemented;
the deterministic engine is tested end to end.

### Added
- **Commands (15):** `init`, `spec`, `design`, `team`, `plan`, `build`, `review`,
  `ship`, `fix`, `security`, `status`, `check`, `config`, `adr`, `migrate` —
  each as a `skills/<name>/SKILL.md`.
- **Subagents (5):** `story-implementer`, `qa-validator`, `conflict-analyzer`,
  `reviewer`, `security-auditor`, each with a typed return schema.
- **Deterministic engine:** `bin/pact` dispatcher plus `scripts/` — `schema`,
  `gitignore`, `scaffold`, `spec-id`, `views`, `wave-plan`, `env`, `story`,
  `green`, `status`, `check`, `adr-id`, `migrate`, and `adr-id`; the
  `session-start`, `format`, `no-ai-guard`, `statusline`, and
  `subagent-statusline` hook scripts.
- **Shared contracts (`references/`):** workflow map, state model, subagent
  fan-out, wave orchestration, decision records, constitution, reuse-first,
  skill anatomy.
- **State model:** story-file frontmatter as the single source of truth;
  generated read-only index views; `status` × `delivery` axes.
- **Flow:** `spec` (typed) → `plan` (demo-first vertical epics, one-format
  stories) → `build` (TDD waves, git worktrees, rehearsal merge, conflict
  analysis, execution modes `step`/`wave`/`spec`/`flow`/`dry`) → `ship` (commit,
  PR, issues, merge). `lite` / `full` modes.
- **Always on:** TDD RED-before-GREEN, the reuse-first redundancy scan, the QA
  loop, Decision Records, the no-AI-references commit guard.
- **Config:** `.pact/config.toml` + `.pact/stack.toml`, `schema = 1`, edited only
  through `init` / `config`.
- **Hooks:** `SessionStart` state line, `PostToolUse` formatter, `PreToolUse`
  AI-reference guard while `ship` / `build` / `fix` / `spec` run.
- **Docs:** `README.md` (the user manual), `docs/DESIGN.md` (design reference).
