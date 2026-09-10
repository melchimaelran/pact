# Reuse-First & Simplest-Viable — shared constraint

One ethos, linked by every authoring command (`spec`, `plan`, `design`, `team`)
and by `build` (the redundancy scan in the refactor phase).

## The rule

- **Read context before acting.** Before designing or generating anything, read
  the existing `project.md`, the spec, the constitution, `accepted` DRs, and any
  directly-related source. Never re-derive what a doc or the code already states.
- **Reuse before you build.** Prefer an existing component, pattern, utility, doc
  section, or reference file over authoring a new one. Point to the source
  instead of duplicating it.
- **Simplest viable approach.** The smallest design or implementation that meets
  the requirement. No layers, options, or abstractions the requirement does not
  ask for.
- **Don't re-analyze what's already clear.** Skip questions the docs/spec answer;
  skip research on well-known basics. Spend effort only on genuine gaps.
- **Effort scales depth, not busywork.** A higher effort level means more depth on
  real ambiguities — never more ceremony or more re-derivation of settled facts.

## Redundancy scan (build, refactor phase)

Run against the story's diff only — never the whole repo. Five checks, in order:

1. **Reimplementation** — the diff writes logic that already exists elsewhere.
   Before accepting a new function as new, grep the repo for its verb + noun and a
   distinctive line of its body. A hit -> call the existing one, or extend it.
2. **Copy-paste inside the diff** — the same block appears twice in the changed
   files. Two occurrences differing only by a value are a parameter; three are a
   helper.
3. **Dead code** — anything added this run with no caller: an export nothing
   imports, a parameter no body reads, an import no line uses, a branch no test
   reaches.
4. **Needless indirection** — a wrapper, adapter, or interface with exactly one
   caller and no behavior of its own. Inline it unless the architecture names it
   as a seam.
5. **Unasked-for surface** — an option, flag, config key, or generality no
   acceptance criterion requires. Delete it; the story is the scope.

**Not a finding:** duplication the architecture makes deliberate, test setup
repeated for readability, or two similar-looking blocks that change for different
reasons.

## Boundary

Reuse-first **tightens, never loosens** a command's own guarantees. Where a step
is mandated for safety or correctness (the version gate, a destructive-write
confirmation, `fix`'s reproduce-first rule, RED before GREEN), that step still
runs. This rule removes redundant analysis, not required checks.
