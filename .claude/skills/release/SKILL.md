---
name: release
description: >-
  Cut a PACT plugin release from this repository — bump the version in
  plugin.json and marketplace.json, roll the CHANGELOG, commit, tag, push, and
  create the GitHub Release. Use when the maintainer asks to "release", "cut a
  release", "publish a new version", or "tag vX.Y.Z". Repo-local maintainer tool,
  not a /pact:* command.
argument-hint: "patch | minor | major | X.Y.Z"
allowed-tools: >-
  Read Edit
  Bash(git status*) Bash(git branch*) Bash(git symbolic-ref*) Bash(git rev-parse*)
  Bash(git remote get-url*) Bash(git describe*)
  Bash(git fetch*) Bash(git log*) Bash(git diff*) Bash(git add*) Bash(git commit*)
  Bash(git tag*) Bash(git push*)
  Bash(gh auth status*) Bash(gh repo view*) Bash(gh release create*) Bash(gh release view*)
---

# release — cut a PACT plugin release

Releases PACT from this repository. The public repo **is** the marketplace:
`.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` carry the
version; a git tag + GitHub Release is what users pull with
`/plugin update pact@pact`.

## Routing check (do first)

This skill publishes a **new version of the PACT plugin**. If the request is
something else, stop and say so:

- Editing PACT's behavior or docs → just edit the files; this skill only releases.
- Migrating a user project's `.pact/` layout → that is the `pact migrate` command
  in the plugin, not this skill.

## Progress tracking

Open a `TodoWrite` list with one item per phase below and update it as you go.

## Phase 0 — preconditions (hard gate)

All must hold, or stop and report which failed:

1. **This is the PACT repository.** `git remote get-url origin` ends with
   `melchimaelran/pact` (`.git` optional). If not, refuse — this skill only ever
   releases the PACT plugin itself, never a project that happens to have a copy
   of it.
2. `gh auth status` succeeds.
3. Current branch is `main` (`git symbolic-ref --short HEAD`).
4. Working tree is clean (`git status --porcelain` empty).
5. `git fetch origin` then `main` is not behind `origin/main`.
6. `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` exist and
   parse.

## Phase 1 — resolve the new version

- Read the current version from `.claude-plugin/plugin.json`.
- From `$ARGUMENTS`:
  - `patch` / `minor` / `major` → bump that part of the current version.
  - an explicit `X.Y.Z` → use it verbatim (must be greater than current).
  - empty → ask the maintainer: patch, minor, or major, and show what each
    resolves to. Offer the three plus a free-text `X.Y.Z`.
- **Schema check.** Resolve the last tag with `git describe --tags --abbrev=0`
  (none yet on a first release — skip this check then). If anything under the
  `.pact/` layout or the config schema changed since that tag
  (`git diff <last-tag> -- docs/DESIGN.md scripts/migrations/` and the config
  templates), require:
  - a migration step present under `scripts/migrations/`, and
  - a `major` bump if the change is breaking to an existing `.pact/` project.
  If that is not satisfied, stop and explain what is missing.

## Phase 2 — apply the version

- Edit `version` in `.claude-plugin/plugin.json`.
- Edit `version` in `.claude-plugin/marketplace.json` (the entry under `plugins`).
- In `CHANGELOG.md`: move everything under `## [Unreleased]` into a new
  `## [X.Y.Z] — YYYY-MM-DD` section (today's date), leave `## [Unreleased]` empty,
  and update the link-reference lines at the bottom
  (`[Unreleased]` compare link + a new `[X.Y.Z]` tag link).
- If `## [Unreleased]` was empty, ask the maintainer for a one-line summary of
  what this release contains and put it under `### Changed` before proceeding.

## Phase 3 — commit, tag, push

- `git add .claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md`
  plus any other staged release edits the maintainer confirmed.
- Commit: `chore(release): vX.Y.Z`.
- Tag: `git tag vX.Y.Z`.
- **Confirm with the maintainer before the next step** (it is outward-facing):
  push branch + tag.
- `git push origin main && git push origin vX.Y.Z`.

## Phase 4 — GitHub Release

- Build the release notes from the new `## [X.Y.Z]` CHANGELOG section (strip the
  heading, keep the body).
- `gh release create vX.Y.Z --title "vX.Y.Z" --notes "<notes>"`.
- If this is the first-ever release, add `--latest`.

## Hard gates

- Never release from a branch other than `main`.
- Never release with a dirty tree.
- Never skip the CHANGELOG roll.
- Never push the tag or create the Release without explicit maintainer
  confirmation in this run.
- A `.pact/` layout change without a migration step blocks the release.

## Completion report

Report: the new version, the tag, the Release URL, and the reminder that users
update with `/plugin marketplace update pact` then `/plugin update pact@pact`
(and restart their session).
