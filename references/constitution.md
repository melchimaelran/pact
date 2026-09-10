# Constitution (charter) — shared contract

The project's standing rules. **Not** the method's own rules.

## Built-in method rules (never in the charter, never configurable)

Always active, `lite` and `full`:

- TDD, RED before GREEN.
- The SOLID check in the refactor phase.
- The reuse-first redundancy scan.
- The QA loop, max 3 iterations, then escalate.
- No AI references in any git or GitHub artifact.
- Confirmation before a destructive or outbound action.

## What the charter covers

Project-specific decisions the method cannot know. Authored at `init` (or later),
**no question cap**: the agent walks every axis that matters, one at a time,
proposes a best-practice default per axis, and **drops** any axis that does not
apply (removed from the file, not left as "N/A").

Axes:

- **Testing** — framework(s), coverage floor (overall + critical paths), what
  requires integration tests, test-data strategy, mock policy.
- **Architecture** — style (hexagonal / clean / layered / feature-folders /
  modular monolith), dependency direction, module boundaries, front-end state,
  API style + versioning, sync/async boundaries.
- **Code style** — exports, immutability, error handling (exceptions vs Result),
  null/undefined, naming, formatter/linter authority, comment policy, file/function
  size guidance.
- **Dependencies** — justification to add a runtime dep, banned libraries +
  preferred alternatives, lockfile + pinning, vendoring.
- **Security** — authn/authz, secret handling, input-validation boundary, PII
  rules, dependency-vulnerability policy.
- **Data** — DB + migration tool, migration review, schema-change policy
  (expand-contract), seed data.
- **Delivery** — commit granularity, what blocks a merge, changelog policy.
- **Observability** — structured logging, levels, what must be logged, metrics /
  tracing, error reporting.
- **Performance** — standing budgets (bundle size, p95, query count), when perf
  work is warranted.
- **Accessibility / i18n** — WCAG target, i18n from day one.
- **Documentation** — what must be documented, where docs live.

## File

`.pact/constitution.md`, versioned with a semver header. Editing it bumps the
version. `plan` and `build` record the version they ran against
(`charter_version` in the spec frontmatter).

## Violation handling — Option B (explicit acknowledgment)

- **`full`** — a violation **stops** the command, shows it, and offers "proceed
  anyway". On confirmation, a line is appended to `.pact/charter-overrides.log`
  (date, charter version, rule, story id) and the command continues. The charter
  is not modified.
- **`lite`** — a warning plus the same acknowledgment.

A human can always override in the moment; the trace is permanent.

## Mechanical rules (deferred, nice-to-have)

At charter authoring, generate the rules that *can* be mechanized — banned-dep
lint, import-boundary rules, naming — into the project's own tooling, so the LLM
gate only judges what cannot be mechanized.
