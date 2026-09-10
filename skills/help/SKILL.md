---
name: help
description: >-
  The PACT command map — what every /pact:* command does, grouped by where it
  sits in the spec -> plan -> build -> ship flow. Script-rendered, zero model
  tokens. Pass a command name for that command's syntax and full description.
argument-hint: "[<command>]"
allowed-tools: Bash(pact help*)
---

# help — the command map

Run `pact help` (or `pact help <command>` for one command) and relay the output
verbatim. Read-only; does not gate on schema — it works before `/pact:init` and
while a `pact migrate` is pending.

If the user is new or asks how to start, point them at `/pact:init` (once per
project), then `/pact:spec <type> "..."` for the first piece of work.
