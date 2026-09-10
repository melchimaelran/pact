---
name: spec
description: >-
  Write or revise the spec for one piece of work — the mandatory front door.
  Typed (feat | fix | adjust | refactor | perf | chore | docs). The agent drafts;
  the user steers the real decisions. Produces docs/specs/<date>_<slug>/spec.md.
argument-hint: "<type> \"<description>\" | <existing-slug-or-SP-id> | <notes-file>"
allowed-tools: >-
  Read Write Edit Glob Grep
  Bash(pact *) Bash(git status*) Bash(date *)
  AskUserQuestion
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/no-ai-guard.sh"
---

# spec — the typed front door

Every piece of work starts here. See
[`workflow-map.md`](../../references/workflow-map.md). Next step: `pact plan`
(the flow picks depth from the spec's content — trivial `chore` / `docs` skip
`plan`).

**Reuse-first** ([`reuse-first.md`](../../references/reuse-first.md)): read
`project.md`, the constitution, existing specs, and directly-related source
first. Do not re-ask what they already answer.

## Routing check (do first)

- A plan already exists and you want to implement -> `pact build`.
- New behavior that is really a bug -> keep `type: fix`, but a bug in **shipped**
  code with no story yet -> `pact fix` (it reproduces + writes the failing test).
- You already know the fix and want to apply it -> still a `spec` (`type: fix`),
  then `plan`/`build`.

## Phase 0 — schema gate

`pact schema --gate`. Mismatch -> stop, tell the user to run `/pact:migrate`.
No `.pact/` -> stop, tell the user to run `/pact:init`.

## Phase 1 — resolve CREATE vs ADJUST

Parse `$ARGUMENTS`:

- Starts with a **type** + a quoted description -> CREATE.
- An existing **slug** or **`SP-NNN`** (glob `docs/specs/*/spec.md` for a match)
  -> ADJUST that spec.
- A **notes file** path -> CREATE, using the file as raw input; infer the type.
- Ambiguous / empty -> if any `docs/specs/*/spec.md` exist, list them and ask
  CREATE vs ADJUST with `AskUserQuestion`; else CREATE and ask for the type.

Valid types: `feat`, `fix`, `adjust`, `refactor`, `perf`, `chore`, `docs`.

## Phase 2 — CREATE

1. Short name: a 2–4 word kebab slug from the description
   (`add-user-auth`, `fix-payment-timeout`).
2. `id` from `pact spec-id`. `created` from `date +%F`.
   `charter_version` from `.pact/constitution.md` header (or `0.0.0` if the
   charter is a draft skeleton / absent).
3. Folder: `docs/specs/<date>_<slug>/`. Copy
   `skills/spec/templates/spec.md`, substitute the frontmatter placeholders.
4. Draft the body from the description + `project.md` + the constitution +
   related source. Fill the sections that apply for this type (see the template's
   per-type note); **remove** the sections that do not — never leave "N/A".
   Make informed guesses; record assumptions inline.
5. **Clarification loop — no cap, one question at a time.** For each material
   ambiguity (a choice that changes scope, behavior, or acceptance and has no
   reasonable default): ask exactly one question, with a recommended answer and
   2–4 options plus a free-text path. On the answer, append
   `- Q: <question> -> A: <answer>` under
   `## Clarifications` -> `### Session <date>`, then apply it to the right
   section. Stop when no material ambiguity remains, or the user says "stop" /
   "go". Save the file after each integration.
6. Set `status: ready`. Report the path and the next step (`pact plan <path>`).

## Phase 3 — ADJUST

1. Read the existing spec. Keep its `id`, `slug`, `created`.
2. Apply the requested change to the relevant sections. For a scope or behavior
   change, update `Acceptance Criteria` and add an `Impact` note if the spec is
   `type: adjust`.
3. Run the same clarification loop for anything newly ambiguous.
4. If the spec was already `planned` or `done`, warn that downstream `tasks/`
   may need `plan --quick` or a new spec, and record that under
   `## Open Questions`.
5. Keep `status` unless the change reopens it (a `done` spec being materially
   changed goes back to `ready` only after the user confirms).

## Decision records

If a Constraint or Requirement locks a technical direction that has real
alternatives and is hard to reverse or cross-feature, propose a DR
([`decision-records.md`](../../references/decision-records.md)) — after checking
the index for an existing one. A declined proposal is a one-line note, not a file.

## Hard gates

- Never write source or tests — `spec` produces a document only.
- Never exceed one question at a time in the clarification loop.
- Never leave a placeholder or an inapplicable "N/A" section in the final file.

## Completion report

Path to the spec, its `id` and `type`, the number of clarifications resolved,
sections filled/removed, and the next command (`pact plan <path>`).
