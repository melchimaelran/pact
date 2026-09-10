# Subagent Fan-Out — shared dispatch contract

How a PACT command dispatches parallel subagents and converges the results.
Commands link here instead of restating the pattern.

## When to fan out

All of these must hold:

- **Independent** — units do not read each other's in-progress output; order does
  not matter.
- **Numerous** — at or above the threshold. Default threshold is **3 units**;
  below it, stay inline.
- **Non-interactive** — the unit needs no user prompt (subagents cannot ask the
  user).

Do **not** fan out: sequential chains (TDD red -> green -> refactor), ordered
writes (git, issue links, numbered ids), cheap reads, or anything that prompts.

## Decision-first rule (non-negotiable)

The dispatch decision is made **before** the first unit is produced, never after.
A step that produces N independent units opens by counting them and branching —
dispatch or inline — and only then does any work. Write it as
**count -> branch -> produce**, never **produce -> (also, you could have
parallelized)**.

Announce it, always, one line, before any unit is produced:

```
Fan-out: 6 units >= 3 -> dispatching 6 agents.
Fan-out: 2 units < 3 -> inline.
```

## Shared context is passed once

The orchestrator reads `project.md`, `constitution.md`, `stack.toml`, and the
relevant `accepted` DRs **one time** and passes them **verbatim** in each dispatch
prompt as read-only context. A subagent never re-reads those files — it reads only
files specific to its unit and the code it touches. A wave of 5 stories reads the
shared context once, not five times.

## Typed returns, not prose

Every subagent returns a **typed schema** the orchestrator reads by field — never
a text brief parsed with regex. Define the shape in the dispatch prompt and
collect fields. A missing or malformed field is caught at collection, not
silently mis-parsed.

Registered agents and their returns:

- `story-implementer` -> `{ status, branch, files_touched, ports_used, criteria_met, remaining, notes }`
- `qa-validator` -> `{ verdict: PASS | NEEDS_FIXES, criteria: [...], regressions: [...], issues: [...] }`
- `conflict-analyzer` -> `{ outcome: auto | serialize | manual, order: [...], patch?, hunks? }`
- `reviewer` -> `{ verdict: PASS | NEEDS_FIXES, findings: [{severity, category, file, line, summary}] }`
- `security-auditor` -> `{ findings: [{id, severity, category, file, line, description, evidence, recommendation, cwe}] }`

## Model tier per unit

Match the model to the *reasoning* the unit needs, never its size. Pass `model:`
on every dispatch — omitting it makes the subagent inherit the orchestrator's
(expensive) tier.

- `haiku` — mechanical: grep/trace/count, path extraction, classifying output
  against fixed criteria.
- `fable` — the same shape when `haiku` starts dropping steps or formatting.
- `sonnet` — filling a frozen template from already-resolved context; the
  `story-implementer` default (`[build].model_balanced`).
- `opus` — the unit itself must *decide* something the orchestrator could not
  pre-resolve: a novel algorithm, a security trade-off, an ambiguous requirement.
  `[build].model_advanced`; state why in the dispatch prompt.

## The orchestrator owns shared state

Never a subagent:

- **User interaction** — every prompt runs to completion before dispatch and
  after collection. Subagents get already-resolved context.
- **Shared writes** — the spec branch merges, index regeneration (`views.sh` runs
  once in the orchestrator after convergence), `project.md` patches, the schema
  stamp.
- **The version gate** — runs once, in the orchestrator.
- **Convergence** — merging returns, resolving contradictions to one decision, the
  final summary.

A subagent writes only files unique to its unit (its story frontmatter, its own
artifact path) and never runs the generator.

## Dispatch shape

1. **Gate** — count units, compare to the threshold, announce the branch.
2. **Freeze shared state** — finish prompts, load shared context once.
3. **Dispatch** — one `Agent` call per unit in a single message, `model:` set,
   each given: its unit id, the frozen context, its return schema, and an explicit
   "write only `<your path>`; do not prompt; do not touch shared files".
4. **Collect** — gather typed returns by field; a failed/empty agent is recovered
   or redone inline by the orchestrator, never left missing.
5. **Converge** — merge, resolve, verify each unit landed, regenerate views once,
   summarize.
