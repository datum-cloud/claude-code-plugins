---
name: lighthouse
description: >
  Start the recurring watched-author PR reviewer. Filters your review queue
  to an explicit allowlist of authors and gives each PR a real first-pass
  review. Drives the lighthouse skill.
tools: Read, Grep, Glob, Bash, Agent
model: sonnet
disable-model-invocation: true
argument-hint: "[options]"
---

# Lighthouse Command

Start the recurring watched-author PR reviewer.

## Usage

```
/lighthouse [options]
```

## Arguments

Options: $ARGUMENTS

## Workflow

1. **Read the `lighthouse` skill** in full before doing anything else. It
   owns the watched-author list, the review contract, the triage rule, and
   the schedule; this command does not restate any of it.
2. **Run Setup** as the skill describes: resolve your own login, resolve the
   org, read the watched-author list, and confirm which posture (comment-only
   or approve) is active for this run.
3. **Run each tick** as the skill's **Each tick** section describes, then
   schedule the recurring jobs from **Loop**.

## Options

See the skill's **Invocation** section for the full list and defaults:
`--org`, `--repos`/`--exclude-repos`, `--interval`, `--approve`,
`--max-parallel`, `--max-diff`, `--inline-max`.

## Error handling

**Watched-author list is empty:**
```
Watched authors list is empty. Lighthouse will not run until a login is
added to that block by hand.
```
