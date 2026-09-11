---
name: lighthouse
description: >-
  Recurring watcher that finds open PRs across a GitHub org requesting review
  from you, filters to ones opened by an author on the watched list, and has a
  subagent give each a real review — approving only with explicit opt-in,
  otherwise commenting with findings for a human to act on. Trigger when the
  user says "lighthouse", "watch so-and-so's PRs", "auto-review PRs for me", or
  wants a recurring reviewer bot for those accounts.
---

# Lighthouse

A recurring PR reviewer. It watches your review queue, picks out the PRs
opened by a watched author, and gives each a real first-pass review — not a
rubber stamp. Default posture is **advisory**: it always leaves a comment with
findings, and only submits a formal approval if you've explicitly opted in.

## Watched authors

Only the GitHub logins listed here are in scope. A PR from anyone else is left
alone, even when it sits in your review queue.

```
(empty)
```

**The list ships empty, and an empty list means the watcher does not run.** If
you invoke it with nothing in this block, say so and stop. Do not fall back to
reviewing everything, do not ask whether to widen it, and do not treat the
operator's own login as an implied entry.

Adding someone is an edit to this block, reviewed like any other change. There
is no flag for it and no "review everything" mode, because a reviewer bot that
posts on anyone's work the moment it is installed is a far larger trust step
than one that starts with a handful of names you chose.

Keep the list short and grow it deliberately. Every login here is a person
whose PRs a machine will comment on, under your account, without asking you
first.

## Why comment-only is the default

Auto-approving on a teammate's behalf is a bigger trust step than leaving
feedback. A dev picking this up for the first time should get useful signal
immediately without having to trust a stranger's agent to gate their merges.
Auto-approve is opt-in per invocation (`--approve`), not a one-time setting,
so it's a deliberate choice every time someone starts the watcher, not a
default that silently persists across sessions.

## Invocation

```
/lighthouse [options]
```

- `--org <org>` — GitHub org to search. Defaults to the org of the current
  repo's `origin` remote.
- `--repos <a,b,c>` / `--exclude-repos <a,b>` — restrict or exclude repos
  within the org. Default: all repos in the org.
- `--interval <Nm|Nh>` — recurring cadence. Default is split by time of day:
  `10m` during business hours (weekdays 09:00-17:59 local), `20m` otherwise.
  See **Loop** for the two cron expressions. Passing `--interval` overrides
  both with a single flat cadence.
- `--approve` — allow the subagent to submit a formal approval for low-risk
  PRs. Without it, every PR gets a `--comment` review (findings, no gate),
  even ones with nothing wrong.
- `--max-parallel <N>` — how many PRs to review concurrently per tick.
  Default `4`.
- `--max-diff <N>` — skip auto-review (comment "too large for auto-review,
  flagging for human eyes") on PRs whose diff exceeds N changed lines.
  Default `800`.
- `--inline-max <N>` — review diffs at or under N changed lines inline, in the
  tick itself, with no subagent. Default `150`. Set `0` to always delegate.

There is no author argument and no "review everything" mode. Widening the
watcher is an edit to the **Watched authors** list above, not a flag.

Examples:

```
/lighthouse --approve
/lighthouse --org datum-cloud --repos infra --interval 10m
```

## Setup (once per invocation)

1. Resolve your own login: `gh api user --jq .login`. This is who
   `--review-requested=@me` and the already-reviewed check key off of — don't
   hardcode a login, including yours; a copy of this skill run by someone else
   must resolve theirs.
2. Resolve the org from `--org`, or from `git remote get-url origin` in the
   current repo if omitted.
3. Read the **Watched authors** list. If it is empty, say so and stop without
   searching anything.
4. Confirm auto-approve mode out loud once at the start ("running in
   comment-only / auto-approve mode") so it's never ambiguous which posture
   is active for this run.

## What a review checks

This list is the standing review contract. Apply it whether the review runs
inline or in a subagent, and do not restate it when delegating — point the
subagent at this section instead.

- The target repo's own conventions. Read its `CLAUDE.md` and
  `CONTRIBUTING.md` if present; never assume another repo's rules apply.
- Correctness: faulty logic, off-by-one and boundary errors, error paths that
  swallow failures, integer truncation at a type boundary.
- Security: overly broad permission or RBAC grants, secrets exposure, and
  script or command injection, such as unsanitized PR-controlled input
  interpolated into a shell `run:` step.
- Config and workflow syntax that parses but means something other than what
  the author intended.
- Blast radius: does the change touch a shared base rather than an overlay or
  staging path, in a repo that has that split? Does a rename change an
  external surface (binary name, flag, env var, metric name, CRD field)
  without a compatibility path?
- Silent defaults: a missing or renamed value that reads as "not configured"
  rather than failing loudly. These are worth naming explicitly, because they
  fail with no error and no symptom at the failure site.
- Tests: does a test exist for the changed path, and would it actually fail if
  the change were wrong? A test asserting only that a call returned no error
  is close to worthless.

Give concise feedback. Do not nitpick trivial style.

## Each tick

1. **Find candidates:**
   ```
   gh search prs --owner <org> --review-requested=@<your-login> --state open \
     --json number,title,author,repository,isDraft \
     --jq '.[] | select(.isDraft==false)
                | select(.author.login | IN(<watched authors, quoted>))'
   ```
   Keep the `IN(...)` set identical to the **Watched authors** list, and edit
   the two together. An empty list stops the tick here. Filter client-side rather
   than with repeated `--author` qualifiers: GitHub search does not reliably OR
   them, and a silently-empty result looks the same as a quiet queue. Then
   apply `--repos`/`--exclude-repos`.

   **On a rate-limit error, do not retry in a loop.** Note it and let the next
   scheduled tick pick it back up — spinning on `gh` calls just burns the same
   shared budget that's already exhausted. Sanity-check with
   `gh api rate_limit --jq .resources` if the same error repeats for several
   consecutive ticks — the block is sometimes a harness-shared limit unrelated
   to the token's actual remaining quota, worth surfacing to the user if it
   persists rather than silently retrying forever.

   If there are no candidates, stop here and report one line. Do not run any
   of the steps below.

2. **Filter to unreviewed:** for each candidate,
   ```
   gh pr view <n> --repo <org>/<repo> --json reviews \
     --jq '.reviews[] | select(.author.login=="<your-login>")'
   ```
   Any output (approved, commented, or dismissed) means you've already put
   eyes on this PR at some point — skip it. This is a deliberate choice: a
   dismissed review usually means the PR changed after review, but re-review
   on every new commit would make the bot noisy and redundant with human
   re-review; it only reviews a PR once per watcher lifetime.

3. **Also skip** any PR with an unresolved `REQUEST_CHANGES` review from
   another human — don't let the bot's judgment override a colleague's
   standing objection. Note it in the tick summary instead.

4. **Triage before reading any diff.** One call per surviving candidate gets
   everything the routing decision needs:
   ```
   gh pr view <n> --repo <org>/<repo> \
     --json additions,deletions,files,statusCheckRollup \
     --jq '{lines:(.additions+.deletions), files:(.files|length),
            checks:([.statusCheckRollup[] | .conclusion // .state]
                    | group_by(.) | map({(.[0]):length}) | add)}'
   ```
   Route on the result, cheapest outcome first:

   - **CI red or still pending** — that is a hold under this skill's own rule
     regardless of `--approve`, and the decision does not depend on the diff.
     Post the hold now; do not read the diff and do not spawn anything.
   - **Diff exceeds `--max-diff`** — post the threshold comment now. Same
     reasoning: the decision is already made.
   - **Diff at or under `--inline-max`** — review it inline, in this tick. Run
     `gh pr diff <n> --repo <org>/<repo>`, apply **What a review checks**, and
     post the verdict yourself. A small diff costs a few hundred tokens to
     read; a subagent costs tens of thousands before it reads anything, so
     delegating a 25-line change spends roughly 100x what the review is worth.
   - **Everything else** — delegate, up to `--max-parallel` at a time, one
     subagent per PR.

   Triage is the whole point of this step: the expensive paths are entered
   only by PRs that actually need them.

5. **Delegating (only for diffs above `--inline-max`).** Spawn a
   general-purpose subagent per PR. It has no local clone unless one exists on
   this machine, so it works through `gh pr view` and
   `gh pr diff --repo <org>/<repo> <n>`.

   Keep the brief short. It needs only:
   - The PR number, repo, diff size, and whether `--approve` mode is active.
   - "Apply the review contract in this skill's **What a review checks**
     section, and read that file first." Do not paste the list into the brief.
   - Anything genuinely specific to this PR that the contract cannot know —
     a sibling PR it interacts with, a subsystem whose failure mode is worth
     naming, a claim in the description worth testing.
   - The decision rule below, and the posting rules.

   A brief that restates the standing contract costs the same tokens on every
   spawn and tells the subagent nothing the file does not.

   For a very large or high-risk change, splitting one PR across several
   subagents by area (datapath, control plane, tests and docs) buys real
   depth, but it multiplies the fixed per-agent cost — do it deliberately,
   not by default.

6. **The decision rule** (inline and delegated alike):
   - Real hold (correctness bug, security issue, blast-radius problem,
     failing or pending CI): `gh pr review <n> --repo <org>/<repo> --comment
     --body "<concise hold explanation>"`.
   - Diff exceeds `--max-diff`: `--comment --body "Diff exceeds auto-review
     threshold (<N> lines) — flagging for human review."`.
   - Otherwise sound: if `--approve` mode, `gh pr review <n> --repo
     <org>/<repo> --approve --body "<2-4 sentence summary of what it does and
     why it's fine>"`; if not, `--comment --body "<same summary, prefixed
     'Looks good —'>"` — same judgment, but never crosses into a formal
     approval without opt-in.

   Never address the author directly beyond the review body text — no
   chit-chat, no @ mentions, no back-and-forth.

7. **Report only deltas.** A quiet tick (nothing new, still rate-limited,
   nothing to review) gets a one-line note, not a full recap. Only expand
   when something was actually approved or held.

## Loop

Schedule two `CronCreate` jobs so the cadence follows the working day:

```
3-59/10 9-17 * * 1-5     business hours, every 10 minutes
7-59/20 0-8,18-23 * * 1-5   weekday nights, every 20 minutes
7-59/20 * * * 0,6        weekends, every 20 minutes
```

The ranges do not overlap, so exactly one job is live at any moment. Minutes
are deliberately off `:00` and `:30`. If `--interval` was passed, use a single
job at that flat cadence instead.

Both are session-only — they die when the session closes, and auto-expire
after 7 days. Tell the user both facts when scheduling.

The tick prompt carries its own copy of the watched-author list, so editing
**Watched authors** means deleting and recreating the jobs. If the user asks
to pause, `CronDelete` every job; resuming re-creates them with the same
parameters rather than assuming state carried over.
