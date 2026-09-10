---
id: {{ID}}
type: {{TYPE}}
slug: {{SLUG}}
status: draft
created: {{DATE}}
charter_version: {{CHARTER_VERSION}}
depends_on: []
target: ""
security: false
---

# {{TITLE}}

<!--
One spec format for every type. Fill the sections that apply, remove the rest
(do not leave "N/A"). Technical and precise — not stakeholder prose. Define the
WHAT; the "how exactly" is plan's job.

Per-type emphasis:
  feat     Goal + Scope + Requirements + Acceptance Criteria.
  fix      Context = where/when it breaks. Requirements hold the Reproduction and
           Expected-vs-Actual. Acceptance Criteria: repro test goes green + all
           prior AC of the touched story still pass + no regression.
  adjust   Target names the spec/feature changed. Change = before -> after.
           Impact lists what could break (drives regression checks).
  refactor Constraints list the Invariants (behavior that must NOT change).
           Acceptance Criteria: existing tests stay green, no behavior change.
  perf     Constraints carry the measured Baseline and the Target budget.
           Acceptance Criteria: target met under the stated measurement, suite
           green, no functional change.
  chore    Scope tiny. Acceptance Criteria: change applied, test+lint+build green,
           no behavior change.
  docs     Affected docs listed. Acceptance Criteria: content correct, examples
           run, links valid, doc build passes.
-->

## Context

{{CONTEXT}}

## Goal

1. {{GOAL}}

## Scope

### In

- {{SCOPE_IN}}

### Out

- {{SCOPE_OUT}}

## Requirements

- R1: {{REQUIREMENT}}

## Acceptance Criteria

- [ ] AC1: {{ACCEPTANCE_CRITERION}}

## Constraints

- {{CONSTRAINT}}

## Clarifications

## Open Questions
