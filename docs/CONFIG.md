# PACT — configuration, files, hooks

Everything under `.pact/` is written and edited only through `/pact:init` and
`/pact:config` — you never hand-edit it. This is the semantic reference for every
key. [`DESIGN.md`](DESIGN.md) has the annotated originals; [`COMMANDS.md`](COMMANDS.md)
covers the commands.

---

## `config.toml`

| Key | Values | Effect |
|---|---|---|
| `schema` | integer | the `.pact/` layout version; the migration gate checks it |
| `language.technical` | `en` | fixed — all on-disk output is English |
| `language.communication` | `en` `fr` `es` `de` `pt` `it` `ja` `zh` `ko` or free text | the language the agent talks to you in |
| `mode.flow` | `lite` `full` | the spine only, or the spine plus governance/quality layers |
| `steps.constitution` | bool | the charter is active and gated (`full`) or advisory (`lite`) |
| `steps.review` | bool | `/pact:review` exists and, with `review_gate`, blocks `ship` — on by default in both modes (light settings in `lite`, no `review_gate` there) |
| `steps.team` | bool | `/pact:team` generates project-tailored skills |
| `steps.design_docs` | bool | `/pact:design` maintains `docs/architecture/` |
| `steps.issue_tracking` | bool | GitHub Issues integration (github only) |
| `workflow.pr_per` | `spec` `story` | one PR per spec, or one per story into the spec branch |
| `workflow.merge_strategy` | `squash` `merge` `rebase` | how the spec branch lands |
| `workflow.commit_style` | `conventional` `simple` | commit message shape |
| `workflow.branch_prefix` | string | prefix for story branches |
| `workflow.preflight` | bool | re-run lint + test just before the ship commit (skipped when the branch is unchanged) |
| `workflow.review_gate` | bool | a `NEEDS_FIXES` review blocks `ship` |
| `workflow.ci_gate` | bool | wait for green CI before merging |
| `workflow.deploy_prompt` | `on-merge` `manual` `none` | the post-merge deploy reminder (PACT never deploys) |
| `workflow.confirm_story_plan` | bool | pause for approval before each story's phase-1 plan |
| `workflow.manual_gate` | `drive` `steps` `off` | drive the verification tool, print steps, or skip |
| `workflow.max_parallel` | integer | cap on concurrent worktree agents |
| `workflow.default_exec_mode` | `step` `wave` `spec` `flow` `dry` | the default execution mode for a build |
| `build.model_fast` / `model_balanced` / `model_advanced` | `haiku` `fable` `sonnet` `opus` | the three build tiers |
| `build.effort` | `high` … | reasoning depth per story |
| `review.effort` | `quick` `standard` `deep` | how thorough a review is — default `deep` in both modes |
| `review.model` | `auto` `haiku` `fable` `sonnet` `opus` | the reviewer's model — default `haiku` in `lite`, `sonnet` in `full` |
| `review.passes` | integer, 2–3 | independent `deep`-review passes, one focus each (`correctness` / `security` / `architecture`) — default `2` in `lite` (drops `architecture`), `3` in `full` |
| `review.auto_fix` | `off` `low` `low+medium` | severities the reviewer fixes itself |
| `review.fresh_suite` | bool | re-run the suite even when `build`'s green still holds |
| `spec.effort` / `plan.effort` | `high` … | reasoning depth |
| `plan.confirmation` | `two-pass` `one-pass` | validate epics then stories, or all at once |
| `team.depth` | `basic` `standard` `max` | how many expert/guide skills to generate |
| `team.context7` | bool | fetch version-specific framework docs (token cost) |
| `design.system` | `auto` `claude-design` `none` | UI design source — `auto` uses the official frontend-design plugin if present, else `.pact/design.md` |
| `notify.sound` | `off` `attention` `all` | play a sound so you can step away — `off`; `attention` = only input waits and failures; `all` = also each turn end and settled build wave |
| `notify.method` | `auto` `bell` `command` | `auto` = a system sound if one is found, else the terminal bell; `bell` forces the bell; `command` runs `notify.command` |
| `notify.command` | string | for `method = command` — a shell line run per event, with `{event}` (`done` `wait` `wave` `fail`) substituted |

---

## `stack.toml`

| Key | Meaning |
|---|---|
| `stack.languages` | list, e.g. `["typescript"]` |
| `stack.frameworks` | list, e.g. `["nestjs", "nextjs"]` |
| `stack.package_manager` | `pnpm` `npm` `yarn` `bun` `pip` `poetry` `uv` `cargo` `go` … |
| `stack.runtime` | e.g. `node@22.11.0`, `python@3.12.4` — pin exact when `version_manager` is set |
| `stack.version_manager` | `fnm` `nvm` `volta` `asdf` `mise` `pyenv` `rbenv` `none` — how the pinned runtime version is enforced across machines |
| `stack.version_file` | path to the pin file (`.nvmrc`, `.node-version`, `.tool-versions`, `.python-version`); `""` if none |
| `stack.monorepo` | bool — when true, add a `[stack.packages.<name>]` block per package |
| `env.containerized` | bool |
| `env.compose_file` | path to `docker-compose.yml` |
| `env.isolation` | `auto` `docker-compose` `inline-env` `serialize` — how parallel worktrees avoid port/DB collisions |
| `env.setup` | install dependencies |
| `env.test` | the full test suite |
| `env.test_one` | run one test file; `{path}` is substituted |
| `env.lint` | linter |
| `env.typecheck` | type checker; empty string = skip |
| `env.build` | compile / bundle |
| `env.dev` | run the app (for the verification gate) |
| `env.format` | formatter for the `PostToolUse` hook; empty string = no auto-format |
| `vcs.platform` | `github` `gitlab` `gitea` `local` |
| `vcs.default_branch` | the branch every PR targets |
| `vcs.has_gh_cli` | bool, set at `init` |
| `vcs.project_board` | bool — mirror story status to a GitHub Projects board |
| `vcs.min_approvals` | required human PR approvals before `ship` merges |

---

## Resource isolation

When a wave runs several stories at once, each worktree needs its own ports,
database, and cache so the test runs do not collide. There is **no file to
configure** — `init` picks a per-project strategy:

| `env.isolation` | Behavior |
|---|---|
| `docker-compose` | each worktree runs under `docker compose -p pact_w<N>` |
| `inline-env` | `PORT` and `DATABASE_URL` are prefixed onto each command |
| `serialize` | the wave runs one story at a time — no parallelism, no worktrees |
| `auto` (default) | detect; fall back to `serialize` when isolation cannot be guaranteed |

---

## Files PACT creates

| Path | Committed? | What |
|---|---|---|
| `.pact/config.toml` | yes | project configuration |
| `.pact/stack.toml` | yes | stack + environment + VCS |
| `.pact/project.md` | yes | the project brief |
| `.pact/constitution.md` | yes | the rules (if enabled) |
| `.pact/design.md` | yes | UI direction (unless `design.system = claude-design`) |
| `.pact/charter-overrides.log` | yes | the audit trail of accepted charter violations |
| `.pact/wave.lock` | no | transient, exists only during a build |
| `.pact/green` | no | per-branch record of the last full-suite green |
| `.pact/cache/`, `.pact/tmp/` | no | scratch |
| `pact-wt/` | no | build worktrees |
| `tasks/<date>_<slug>/` | yes | a plan: `PROJECT_OVERVIEW.md`, `epics/*/EPIC.md`, `epics/*/stories/*.md`, `ROADMAP.md` |
| `tasks/<slug>/STORIES_INDEX.md` | yes | generated view — one row per story |
| `tasks/FEATURE_INDEX.md` | yes | generated view — one row per spec |
| `docs/specs/<date>_<slug>/spec.md` | yes | a spec |
| `docs/decisions/NNNN-slug.md` | yes | a Decision Record |
| `docs/decisions/README.md` | yes | generated view — the DR table |
| `docs/architecture/**` | yes | if `design_docs` is on |

`init` writes a managed block into `.gitignore`:

```
# --- PACT (managed) ---
.pact/wave.lock
.pact/green
.pact/cache/
.pact/tmp/
pact-wt/
# --- end PACT ---
```

`pact check` flags a missing block, or a `.gitignore` line that would exclude
`.pact/` wholesale (which breaks sharing).

---

## Status line

- **Per-agent rows** during build waves ship enabled automatically.
- **The main status line** must live in your user or project `settings.json` — a
  plugin cannot set it. Install it with `/pact:config statusline install` (choose
  user-level or project-level). It renders

  ```
  PACT [full] myapp · SP-003 contact-section 2/3 · wt: 01-03
  ```

  colored flow mode, project name, active spec/slug, stories done/total, and
  any live worktrees. Model, cwd, and context-window usage aren't repeated
  here — Claude Code's own footer renders those alongside a custom
  `statusLine` (it doesn't replace it), always. Prints nothing outside a PACT
  project, so a user-level install is safe everywhere. Costs no model tokens.

---

## Hooks

- **`SessionStart`** — silent outside a PACT project. Inside one it prints, at
  most: a schema-mismatch notice, a plugin-not-enabled hint, the condensed
  project state, a stale-index flag, and an uncommitted-`.pact/` note.
- **`PostToolUse`** on `Write` / `Edit` / `MultiEdit` — formats the file just
  written with `env.format`, if one is configured. Silent on success, never
  fails the edit.
- **`PreToolUse`** (while `ship`, `build`, `fix`, `spec` run) — blocks any
  `git` / `gh` command carrying an AI-authorship trailer or footer. It matches
  the trailer forms only.
- **`Stop`** and **`Notification`** — play a sound (`scripts/notify.sh`) when a
  turn finishes and when PACT is waiting on you. Off unless `notify.sound` is
  set. Backgrounded, silent, never fails a turn. `build` and `review` also call
  `pact notify` when a wave settles or an escalation needs you. See below.

---

## Sound notifications

A short sound so you can start a long parallel `build` and step away. **Off by
default** — nothing plays until you turn it on.

**Turn on** — `/pact:init` asks for it up front (Block 1, default `off`); after
that, either:

- `/pact:config` in a session: *"turn on sounds"*, *"notify me on failures"*,
  *"play a sound when it needs me"*; or
- set `notify.sound` in `.pact/config.toml` (via `/pact:config` — never
  hand-edited):
  - `attention` — only when PACT needs you: input waits and failures.
  - `all` — also each turn end and each settled build wave.

**Turn off** — set `notify.sound = "off"` (again through `/pact:config`), or
mute without editing the file by exporting `PACT_NOTIFY=off` (useful in CI or a
headless run — it overrides the config wherever it is set).

**Events:** `done` (turn end), `wait` (permission prompt or idle), `wave` (a
build wave settled), `fail` (QA loop exhausted, unresolvable conflict, review
`NEEDS_FIXES`, failed verification gate).

**How it plays** — `notify.method`:

- `auto` (default) — a system sound if one is found (freedesktop on Linux,
  `/System/Library/Sounds` on macOS), otherwise the terminal bell (1–4 beats by
  event).
- `bell` — always the terminal bell.
- `command` — run `notify.command` once per event, with `{event}` substituted
  (e.g. `notify.command = "osascript -e 'display notification \"PACT {event}\"'"`).

Zero model tokens: the hooks and the `pact notify` calls are deterministic
scripts. `notify.sh` is backgrounded and always exits 0, so it can never delay
or fail a turn.
