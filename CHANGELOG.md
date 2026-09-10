# Changelog

All notable changes to PACT are documented here. The format follows the
Keep a Changelog convention, and PACT versions follow Semantic Versioning. A
breaking change to the on-disk `.pact/` layout only happens on a major version
and ships a migration step.

## [Unreleased]

### Added
- All 15 command skills: `init`, `spec`, `design`, `team`, `plan`, `build`,
  `review`, `ship`, `fix`, `security`, `status`, `check`, `config`, `adr`,
  `migrate`.
- Five subagents: `story-implementer`, `qa-validator`, `conflict-analyzer`,
  `reviewer`, `security-auditor`.
- Deterministic engine (`bin/pact` + `scripts/`): `schema`, `gitignore`,
  `scaffold`, `spec-id`, `views`, `wave-plan`, `env`, `story`, `green`,
  `status`, `check`, `adr-id`, `migrate`, plus the `session-start`, `format`,
  `no-ai-guard`, and status-line hooks.
- Eight shared contracts under `references/`.
- `config.toml` / `stack.toml` schema at `schema = 1`.

## [0.1.0] — 2026-09-10

### Added
- `docs/DESIGN.md` — the full design and implementation reference.
- Plugin packaging scaffold: `.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`.
- `release` project skill — cuts a PACT release (version bump, changelog, tag,
  GitHub Release).

