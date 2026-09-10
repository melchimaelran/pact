# Wave Orchestration — how `pact build` runs stories in parallel

## One active spec at a time

Cross-spec work is strictly serial. One spec is the **active spec** from `build`
through merge to the target branch. `spec` drafting and `plan` may run for many
specs at once (no code touched). `pact build <B>` is **refused** while another
spec's `spec/<id>` branch is unmerged — finish it or
`pact ship --abandon <id>` (returns the spec to `planned`, deletes the branch,
releases the lock). Each new spec branch is cut from an up-to-date target branch,
so cross-spec merge conflicts cannot arise.

## Wave planning (`scripts/wave-plan.sh`, zero model tokens)

1. Read the plan: every non-`done` story of the spec, plus `blocked_by`.
2. Build the dependency DAG. Its topological layers are the waves; each layer runs
   fully in parallel.
3. Emit the ordered wave list. A wave holding one story runs inline (no worktree).

There is no `files:` field and no conflict-graph pre-partitioning. File collisions
are **handled at the merge**, not predicted.

## Execution

1. Cut the spec branch `spec/<SP-id>-<slug>` from the target branch. This is also
   the rehearsal branch — safe, because spec-level serialization means a bad wave
   rolls back without affecting anything else and the branch is not merged.
2. **Load shared context once** (see
   [`subagent-fanout.md`](subagent-fanout.md)).
3. For each wave:
   - One git worktree + one `story-implementer` per story (or inline if the wave
     holds one). Worktrees: `pact-wt/<wave>/<story-id>` in a sibling directory;
     `setup` runs once per worktree; `[workflow].max_parallel` (default 4) caps
     concurrency.
   - Each agent runs the per-story loop (below) and returns its typed schema.
   - **Drift check** — compare `files_touched` against the story's stated intent;
     a file well outside the story's concern is flagged for the orchestrator.
   - **Merge rehearsal** — merge each story branch into the spec branch in id
     order. The first conflict goes to `conflict-analyzer`:
     - `auto` — apply the returned patch, continue.
     - `serialize` — move the losing story to the next wave, recompute
       `wave-plan.sh`.
     - `manual` — surface the hunks, pause the wave.
     More than one conflict in a wave -> the planner serializes more of the
     remaining spec.
   - Run the full `test` suite on the spec branch after the wave merges. Green ->
     record the result against the spec-branch SHA, wave done. Red -> QA loop
     (max 3) or roll back the wave.
   - Regenerate the index views once, after the wave settles.
4. All waves green -> the batched verification gate (one, not per story) -> ready
   for `review` / `ship`. Views regenerate again on `build` exit.

Worktrees are removed and `git worktree prune` runs on wave success; kept with a
pointer on failure. Orphan worktrees from an interrupted run are cleaned or
resumed at the next `build`.

## Per-story loop (phases 0–7)

| Phase | Work |
|---|---|
| 0 · Context | the story + code it touches. Shared context (`project.md`, charter, `stack.toml`, DRs, team skills, UI direction) arrives in the dispatch prompt — do not re-read it. |
| 1 · Plan | restate the goal, map each acceptance criterion to a test, list implementation tasks, sketch the SOLID design. No user prompt unless `[workflow].confirm_story_plan`. |
| 2 · RED | one failing test per acceptance criterion; run `test_one`; each must fail for the right reason. |
| 3 · GREEN | the minimal code to pass; `test_one` until green. |
| 4 · REFACTOR | clean up, apply SOLID, run the reuse-first redundancy scan; tests stay green. |
| 5 · QA | full `test` + `lint` + `typecheck` + `build`; architecture compliance vs `project.md`; edge cases; design fidelity if UI. Verdict PASS / NEEDS FIXES. Loop max 3, then escalate. |
| 6 · Verification gate | batched at wave-set end, not here (inline single-story runs it immediately). Method by project type — Web UI: Chrome-driven or steps; CLI: run + expected output; Library/API: example calls; Backend: curl / smoke script. `[workflow].manual_gate` = `drive` \| `steps` \| `off`. |
| 7 · Complete | implementation summary in the story body; `status: done`; the orchestrator regenerates views (once per wave). |

**QA escalation** (after iteration 3): other worktree agents finish their current
phase and hold; the orchestrator collects partial results; nothing merges until
the user resolves — A) apply user-specified fixes, B) accept as-is with documented
known issues, C) abort and set the story back to `todo`.

## Resource isolation

The orchestrator pre-allocates disjoint runtime resources per worktree. **No
`.env.pact` file.** `[env].isolation`:

| Value | Behavior in a wave |
|---|---|
| `docker-compose` | `docker compose -p pact_w<N> …` per worktree |
| `inline-env` | vars injected inline: `PORT=31NN DATABASE_URL=…pact_wN <cmd>` |
| `serialize` | the wave runs serialized, parallel off, and says why |
| `auto` (default) | detect; fall back to `serialize` when uncertain |

The orchestrator is the message bus — subagents never talk to each other. An agent
that needs an unplanned resource reports it in its return; the orchestrator
re-allocates and re-dispatches.

`.pact/wave.lock` (orchestrator-owned, gitignored, transient) records the
allocations; `pact status` shows them; it is freed at wave-set end.

## Execution modes

Chosen when a spec's build starts (default `[workflow].default_exec_mode`),
changeable with `pact build --mode <x>` (resumes where it left off):

| Mode | Pauses after… |
|---|---|
| `step` | every story |
| `wave` | every wave |
| `spec` | nothing — the whole spec to `done`, hard stops only |
| `flow` | nothing — auto-chains `build -> review -> ship` while nothing blocks |
| `dry` | does nothing — shows the wave plan |

**Hard stops** override the mode, always: the verification gate, QA escalation
after 3 iterations, an unresolvable `manual` conflict, `review` NEEDS FIXES that
is not auto-fixable, a destructive-action confirmation, human PR approval
(`min_approvals > 0`).

## Failure modes

| Failure | Behavior |
|---|---|
| Wave agent crash / timeout | mark the story failed, keep its worktree, continue the wave, report; re-run per story |
| Test hang | `[env]` commands run with a timeout (default 10 min) -> treated as failure -> QA loop / escalate |
| `build` interrupted | state is in frontmatter + git; `pact status` shows the partial state; re-run resumes from the first non-`done` story |
| `conflict-analyzer` cannot resolve | `manual` — hunks surfaced, wave paused |
| Schema gate fails | hard block -> `pact migrate` |
| Disk full / worktree create fails | abort the wave cleanly, report |
