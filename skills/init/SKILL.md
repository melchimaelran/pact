---
name: init
description: >-
  Set up PACT in a project — a conversational questionnaire, then the .pact/
  scaffold. Detects a new vs existing project automatically; force with --new,
  --adopt, or --reconfig.
argument-hint: "[--new | --adopt | --reconfig]"
allowed-tools: >-
  Read Write Edit Glob Grep
  Bash(pact *) Bash(git status*) Bash(git rev-parse*) Bash(git init*)
  Bash(ls*) Bash(cat *) Bash(test *) Bash(gh auth status*) Bash(which *)
  AskUserQuestion
---

# init — configure PACT for this project

Runs a one-time questionnaire and scaffolds `.pact/`. Everything is asked in the
session; the user never hand-edits a config file. See
[`workflow-map.md`](../../references/workflow-map.md). Next step after this:
`pact spec`.

**Reuse-first** ([`reuse-first.md`](../../references/reuse-first.md)): in ADOPT
mode, read what the project already has (stack files, docs) and turn each
question into "confirm / correct", not "type from scratch".

## Progress tracking

Open a `TodoWrite` list: one item per block this run will execute.

## Phase 0 — mode detection

Not gated on schema (this command creates the schema). Detect:

- `.pact/config.toml` exists -> **RECONFIG**: stop here and tell the user to use
  `/pact:config` for changes; `init` does not re-scaffold. (Unless `--reconfig`
  was passed, then continue as a guided re-run that overwrites answers.)
- else the working tree has source files (any of `package.json`, `pyproject.toml`,
  `Cargo.toml`, `go.mod`, `pom.xml`, a `src/` with code) and no `.pact/` ->
  **ADOPT**.
- else -> **NEW**.

`--new` / `--adopt` force the mode. If not in a git repo, run `git init` first
(ask before doing so).

## Phase 1 — existing-docs scan (ADOPT, and NEW if notes were given)

Glob for `CLAUDE.md`, `AGENTS.md`, `README*`, `docs/**/*.md` (including any
`PRD*`, `*requirements*`, `*design*`, `*architecture*`), `.cursorrules`,
`CONTRIBUTING*`, root `*.md`. List what was found. Ask: "Use these as source for
the project brief and the constitution? [Y/n]". If yes, read them and use them to
pre-fill Blocks 3 and 6 (citing `Source: <path>` in `project.md`, never copying
wholesale, never editing the originals).

If a PRD / requirements doc, an architecture doc, or a contributing/style guide
is expected but absent (ADOPT with no `docs/` at all, or gaps like an
architecture doc but no PRD), don't fill the gap by inference — name what's
missing and ask: point to it if it lives elsewhere (a wiki, Notion, a Drive
doc), paste it, or answer Block 3 from scratch. Never invent project intent to
paper over a missing doc.

## Phase 2 — the questionnaire

Every question offers three paths: accept the proposed default, pick a preset, or
answer in free text. Ask block by block; within a block, one question at a time
when the answers depend on each other.

### Block 1 — base

- **Communication language** — `en` (default) / `fr` / `es` / `de` / `pt` / `it` /
  `ja` / `zh` / `ko` / free text.
- **Flow mode** — `lite` (spine only) / `full` (adds governance + quality layers).
- **Sound notifications** — `off` (default) / `attention` (waits + failures) /
  `all` (+ turn end, each settled build wave). `method` stays `auto` (system
  sound, else terminal bell); tune it later with `/pact:config` if needed.

### Block 3 — project context  (-> `project.md`)

- What the app does (1–3 sentences).
- Domain and users.
- Main capabilities (a list).
- Tech -> role map.
- Structure (folder layout + module boundaries).
- External systems / integrations.
- Hard constraints (optional).

ADOPT: pre-fill every field from the scan + a quick read of the code; the user
confirms or corrects.

### Block 2 — stack & environment  (-> `stack.toml`)

- Languages, frameworks, package manager, runtime, monorepo?
- **Runtime version** — exact/pinned when possible (`node@22.11.0`, not just
  `node@22`).
- **Version manager** — `fnm` / `nvm` / `volta` / `asdf` / `mise` / `pyenv` /
  `rbenv` / `none`. ADOPT: detect from a version-pin file (`.nvmrc`,
  `.node-version`, `.tool-versions`, `.python-version`) or config
  (`package.json` `engines`, `.fnmrc`) and propose it; confirm. NEW: ask only if
  the runtime has version-sensitive behavior (Node, Python, Ruby, …) — skip for
  Go/Rust where it's rarely needed. If set, ask for the pin file path
  (`version_file`); offer to create it from the chosen runtime version.
- Containerized (Docker)? If yes, the compose file path.
- The `[env]` commands: `setup`, `test`, `test_one` (with `{path}`), `lint`,
  `typecheck` (empty = skip), `build`, `dev`, `format` (empty = no auto-format).
- **Isolation strategy** — probe how the project runs and pick:
  `docker-compose` (a compose file exists), `inline-env` (the app honors `PORT` /
  `DATABASE_URL` overrides), `serialize` (can't isolate cheaply), `auto`
  (default — detect, fall back to `serialize`).

ADOPT: read `package.json` scripts, lockfiles, `Makefile`, `Dockerfile`,
`pyproject.toml`, `Cargo.toml`, `nest-cli.json`, `next.config.*`. Pre-fill and
confirm. NEW: offer a stack preset that fills the commands, or free-form.

### Block 4 — VCS & git workflow  (-> `stack.toml [vcs]` + `config.toml [workflow]`)

- Platform — `github` / `gitlab` / `gitea` / `local`.
- If a remote platform: run `gh auth status` (or the equivalent). Not installed /
  not authed -> offer `local` as a fallback, or wait while the user authenticates.
- Target branch (default `main`).
- `pr_per` — `spec` (default) / `story`.
- Merge strategy — `squash` (default) / `merge` / `rebase`.
- Commit style — `conventional` (default) / `simple`.
- `preflight` — on in `full`, off in `lite`.
- **full + github only:** issue tracking on/off; if on, GitHub Projects board
  on/off; human approvals required (`min_approvals`, default 0).

### Block 5 — optional toggles  (`full` only; `lite` -> all off except `review`, skip this block)

Ask each; none is auto-on:

- `constitution` · `review` · `team` (if on -> also ask `[team].context7`, default
  false) · `design_docs` · `design.system` (`auto` recommended / `claude-design` /
  `none`) · `issue_tracking`.

`lite` skips this block entirely, but `review` is still on — a standing default,
not a question — with the light settings from Block 7.

### Block 6 — charter  (only if `constitution = on`)

Ask: write it now, or a draft skeleton for later.

If **now**, walk every axis in
[`constitution.md`](../../references/constitution.md) — Testing, Architecture,
Code style, Dependencies, Security, Data, Delivery, Observability, Performance,
Accessibility/i18n, Documentation — **one at a time, no cap**, proposing a
best-practice default per axis. Drop any axis that does not apply (remove its
section — do not leave "N/A"). ADOPT: draft each axis from the observed
conventions, the user tweaks.

### Block 7 — models & effort  (`full` only; `lite` -> defaults, skip)

- `build` model tiers (defaults `haiku` / `sonnet` / `opus`).
- `review` effort (default `deep`), `passes` (default `3`), `model` (default
  `sonnet`), `fresh_suite` (default true in full). `deep` runs one independent
  `reviewer` per pass, each with one focus from `correctness` / `security` /
  `architecture` in that priority order — `passes` is clamped to 2–3 (2 drops
  `architecture`).
- `plan` confirmation (`two-pass` default in `full`, `one-pass` in `lite`).
- `default_exec_mode` (`wave` default in `full`, `spec` in `lite`).

`lite` review default (not asked, applied at scaffold): `steps.review = true`,
`effort = deep`, `passes = 2` (correctness + security only), `model = haiku` —
cheap and light, never `review_gate`-blocking (that stays off in `lite`).

## Phase 3 — scaffold

1. `pact scaffold` — creates `.pact/`, `tasks/`, `docs/specs/`,
   `docs/decisions/`, the `charter-overrides.log`, the `.claude/settings.json`
   `enabledPlugins` entry, the `CLAUDE.md` PACT section, and the `.gitignore`
   managed block.
2. Read each template in `skills/init/templates/`, substitute the gathered
   answers for every `{{PLACEHOLDER}}`, and `Write` the result:
   - `.pact/config.toml`
   - `.pact/stack.toml`
   - `.pact/project.md`
   - `.pact/constitution.md` (only if `constitution = on`)
   - `.pact/design.md` (only if `design.system != "claude-design"`)
3. If `full` and the user wants it: offer the statusline install
   (`/pact:config statusline install` writes it into user or project
   `settings.json`).

## Phase 4 — verify & report

- `pact schema` prints `1`.
- `pact gitignore --check` prints `ok`.
- Report: the files written, the mode used, and that the next step is
  `pact spec <type> "..."`.
- Remind the user to commit `.pact/`, `.claude/settings.json`, `CLAUDE.md`, and
  `.gitignore`.

## Hard gates

- Never overwrite `.pact/config.toml` unless mode is RECONFIG (`--reconfig`).
- Never edit the user's existing docs (README, CLAUDE.md content outside the
  PACT-marked section) — only append the marked section.
- Never touch source files in ADOPT mode.
- `git init` only after asking.

## Rules

- One question at a time when answers are dependent; a whole block at once when
  they are independent.
- Skip Blocks 5–7 entirely in `lite`; use documented defaults.
- Free-text answers are integrated verbatim.
