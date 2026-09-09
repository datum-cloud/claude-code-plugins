---
name: model-tiers
description: >
  Which model a subagent gets, and why. Use when spawning any agent, writing
  or editing an agent definition, or choosing the model for a skill or command
  that forks. Covers the three tiers, the signal that picks each one, what a
  cheaper agent does when it meets a design decision, and why the model never
  moves the acceptance bar.
---

# Model Tiers

Match the model to the task's design risk, not to its importance.

A review that gates production is important and still bounded: it works from an explicit brief against a diff that already exists. Writing the change under review is not bounded, because a wrong approach there is not caught by rerunning.

Three tiers. Every agent definition pins one in its `model:` frontmatter, and a spawn takes the pin rather than overriding it.

## opus

Work that authors a change carrying design risk:

- writing a pull request from an issue
- designing an alert rule, a metric join, or a query
- Pulumi programs, controllers, API types, anything that ships behavior
- planning briefs that other agents then execute

The signal: getting it wrong means someone reworks the approach rather than fixes a line. That costs a review round or a bad release, which is more than the model saved.

## sonnet

Bounded work against an explicit brief:

- the adversarial and conventions reviewers, and the re-review of a fixed head
- the fixer that applies findings the reviewers already agreed on
- a rebase whose conflict shape is known
- mechanical renames
- cutting a release from a recipe
- rewriting a body, ticking a checkbox, posting a bookkeeping comment
- drift checks and gate runs

The signal: the brief already says what finished looks like, and the work is to reach it. Judgment goes into meeting the criteria, not into deciding what they should be.

## The supplied-work haiku exception

The review fixer drops from sonnet to haiku when every finding it is about to apply is simple. Simple means mechanical: wording in a PR body, an issue body, or a comment; a commit message rewrite; a rename; a single-value change such as a number, a label, or a version; a comment strip; a file move with no content change; adding a link. A finding that changes logic, an expression, a query, a template, a test, or a workflow, or that needs a validation run to prove it, is not simple. A mixed list, where even one finding fails that bar, runs on sonnet.

The orchestrator classifies the converged findings before spawning the fixer and passes the model at the spawn, `model: haiku` on the `Agent` call, rather than relying on the fixer's own pin. A haiku fixer that meets a finding outside the simple definition stops and reports instead of attempting it, the same escalation rule as the rest of this skill. The agent's frontmatter keeps `model: sonnet` as its default pin, so a spawn that skips classification, or hands the fixer a mix it did not fully triage, still runs at the safe tier.

`bookkeeper` takes the same exception on the same terms. It drops to haiku when every body it is about to post is supplied verbatim in the brief, so no judgement is left in the work, and it keeps `model: sonnet` as its pin for every other run. An action that would need it to write or reword anything is outside the tier, and it stops and reports rather than drafting.

## haiku

Read-only lookup and enumeration, where the answer is a list or a table of `path:line`:

- every caller of a symbol, every file matching a pattern, every version pinned
- monitors and polling loops
- documentation lookups, simple greps, and summaries of what came back

The signal: the answer already exists in the repository or the docs, and the work is to fetch and shape it.

## Escalation

A sonnet agent that reaches a design decision stops and reports rather than deciding. It says what it found, what the options are, and what it did not do. The orchestrator reads that report and spawns opus with it as the brief.

That escape is what makes the cheaper tier safe. The risk in a downgrade is not a worse decision, it is a decision taken at the wrong level, so the cheaper agent is told never to take one.

The review loop already has this shape. A `decision` finding routes to a person instead of to the fixer, and a split verdict does the same. See `pr-review-loop/protocol.md`.

## The model is cost, never the bar

Choosing a model changes what a run costs and nothing else. The same brief, the same gates, and the same acceptance criteria apply at every tier.

A sonnet reviewer's `hold` carries exactly the weight an opus one would. A finding is not discounted because a cheaper model raised it, and "it was only sonnet" is not a reason to merge.

Where a tier cannot meet the bar for some task, move that task up a tier. Never lower the bar to fit the tier.

## What each agent gets today

| Agent or command | Tier | Signal |
|---|---|---|
| `plan` | opus | writes the design brief other agents execute |
| `api-dev` | opus | authors API types, storage, and controllers |
| `frontend-dev` | opus | authors the interface a user meets |
| `sre` | opus | authors manifests, CI, and deployment config whose blast radius is a cluster |
| `/evolve` | opus | promotes findings into runbooks that steer every later agent |
| `code-reviewer` | sonnet | reviews a diff that exists against conventions that exist |
| `pr-adversary` | sonnet | the same, from the correctness angle, against a brief in its definition |
| `pr-conventions-reviewer` | sonnet | the same, from the reach and conventions angle |
| `pr-review-fixer` | sonnet, haiku when every finding is simple | applies findings both reviewers already agreed on |
| `pr-rereviewer` | sonnet | settles named prior findings at a new head against evidence, then one narrow pass |
| `pr-rebaser` | sonnet | resolves conflicts whose two intents both sides already state |
| `tech-writer` | sonnet | writes to a brief and verifies each claim against the code |
| `test-engineer` | sonnet | tests an implementation that already exists |
| `operational-reviewer` | sonnet | runs the queries `operational-review/queries.md` gives verbatim into the format `report-format.md` gives |
| `/release` | sonnet | cuts a release from a recipe |
| `gap-verifier` | sonnet | tests one issue's claim against trunk, the released tag, and live state |
| `rollout-verifier` | haiku | reads a list of expected effects back off the live system |
| `bookkeeper` | sonnet, haiku when every body is supplied | posts bodies someone else already wrote |

One agent pins haiku. `rollout-verifier` writes nothing anywhere: it takes a list of expected effects, reads each one back off the live system, and reports what it saw. `bookkeeper` runs on haiku too when every body it posts is supplied verbatim, and on sonnet otherwise. Spawn haiku ad hoc for the rest of the lookups: a search agent that returns file and line and nothing else, or a monitor that watches a run.
