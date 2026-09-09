---
name: pr-review-loop
description: >
  Runs two read-only reviewers with different angles on a pull request,
  compares their verdicts, and either spawns the fixer to carry the PR to
  auto-merge or puts the choice to a human. Trigger on "review this PR",
  "double review", "two reviewers", "run the review agents", "I just opened a
  PR", "check this before it merges", and on the session opening any pull
  request itself, including one opened by a subagent. Handles a PR the
  session opened or a PR named by number or URL; a diff with no PR is
  code-reviewer's job, not this skill's.
---

# PR Review Loop

A session that writes a change is the worst judge of it. This skill runs two reviewers that do not know about each other on every pull request the session opens, then acts on what they agree on and asks a person about the rest.

The reviewers are agents, so their model pin and read-only posture hold every time they run. Both reviewers run on sonnet, because each works from an explicit brief against a diff that already exists, and a finding a person has to decide leaves the loop rather than being settled inside it. The fixer also pins sonnet, but the session classifies the agreed findings against `model-tiers`' simple definition before spawning it and passes `model: haiku` at that one spawn when every finding qualifies; do not override a pin anywhere else in this loop. Their tool lists do not restrict Bash. The plugin hook refuses the GitHub write surface, git mutations, and shell wrappers for the reviewer agents as a backstop against an accidental write; a determined agent could still evade it, so the reviewers' prompts carry the rule and the branch ruleset's human approval is the last gate. This skill is the protocol around them, and it holds only when the session follows it. Follow it.

## When to run

Run the loop on every pull request this session opens, including one a subagent opened on the session's behalf. Run it when the user asks with any of the trigger phrases above, or types `/pr-review`. A subagent that opens a PR can run the loop itself, since a subagent can spawn subagents, and does not need to come back to the main session first.

The unit of review is one PR against one base SHA. A push after the review ran means a new review.

This skill takes a pull request: one the session opened, or one the user names by number or URL. A diff, a branch, or a working tree with no PR behind it goes to the `code-reviewer` agent instead.

## Cost caps

Each reviewer costs roughly 100k to 160k tokens and the pair plus the fixer adds ten to fifteen minutes of wall time per PR. Both reviewers run at once, so the wall time is one review, not two. That is cheap next to one broken reconcile and expensive on a typo, so:

- **Nothing deployable changed.** A diff confined to Markdown, a changelog, or comments gets `pr-conventions-reviewer` alone.
- **Trivial diff.** Under about twenty changed lines in a single file gets one reviewer: `pr-adversary` when the file deploys, `pr-conventions-reviewer` when it does not.
- **Never skip on reach.** Any diff that touches a shared base, a production overlay, a cluster overlay that tracks trunk, or an alert rule gets both reviewers regardless of size. Blast radius decides, not diff size.
- **Run in the background.** Keep working while the reviews run and pick them up when they land. Both reviewer agents carry `background: true`.

When one reviewer is skipped, the agreement conditions in `${CLAUDE_PLUGIN_ROOT}/skills/pr-review-loop/protocol.md` cannot all hold, because they need two finished reports. A single-reviewer run is advisory: report its findings and verdict to the user and do not spawn the fixer without their say.

## Launch

Read the PR first:

```
gh pr view <n> --json number,baseRefOid,headRefOid,headRefName,baseRefName,url
```

Then fetch the head once, in the worktree that holds the PR branch (find it with `git worktree list --porcelain`; any worktree of the repository will do, since they share the object store), and take the head SHA from what landed:

```
cd <worktree> && git fetch origin refs/pull/<n>/head && git rev-parse FETCH_HEAD
```

That is the only fetch the loop makes. The reviewers never fetch; they read the diff with `git diff <base>...<head>` and files with `git show <head>:<path>`, which is why both SHAs go in the prompt. If the fetched SHA differs from `headRefOid`, the branch moved since `gh` answered, so use the fetched one.

Launch both reviewers in the same message so they run at once, each with `subagent_type` set to the plugin-scoped agent name. Both carry `background: true`, so they run in the background without being asked. Give each the same prompt:

```
Review PR #<n> in <owner>/<repo>. Base SHA <base>, head SHA <head>, branch
<headRefName> against <baseRefName>. The head is already fetched; do not
fetch. Return findings and a verdict in the shape your definition gives.
Post nothing to GitHub.
```

Do not tell either reviewer what the other is doing, and do not pass either one's report to the other.

While they run, keep working. When both notifications arrive, read both reports in full.

## Compare and act

Apply `${CLAUDE_PLUGIN_ROOT}/skills/pr-review-loop/protocol.md`. In short: check the five agreement conditions and the always-escalate list, then either classify the agreed findings against `model-tiers` and spawn `pr-review-fixer` for its fix phase (with `model: haiku` when every finding is simple) with both reports and say in one line what it is doing, or put the choice to the user with a recommendation and act on the answer.

When the fixer pushes a fix for any `blocker` or `warning`, fetch the new head the same way and launch the second pass on it: `pr-rereviewer` in place of a fresh `pr-adversary`, alongside `pr-conventions-reviewer`. Hand the re-reviewer the head it is checking, the head that one replaced, and the findings from both first-pass reports that the fixer applied. It settles each of those against evidence at the new head and makes one narrow pass over the fix diff, rather than reviewing the whole pull request again, which the first pass already did. The five conditions apply to the two reports unchanged, so only two `merge` verdicts, or two `hold` with nothing left above `nit`, unlock the fixer's ready phase. That is one re-review, not a loop: a second `hold` with a `blocker` or `warning` still standing goes to the user with both reports and a recommendation.

A pull request that has fallen behind its base, or that a reviewer reports colliding with another open pull request, goes to `pr-rebaser` before the ready phase. It rebases in the worktree that holds the branch, keeps both sides' intent in every conflict, reruns the validators the touched paths map to, and pushes with lease. A conflict that needs a design decision comes back to the user rather than being guessed.

Never post a reviewer's report to GitHub yourself. The fixer posts one comment at the end of its ready phase, and that is the only comment the loop produces.

## Configuration

`prReview.humanReviewer` names the one person to request on top of the code owners once the PR is ready. It lives in the repository's own `.claude/settings.json`:

```json
{ "prReview": { "humanReviewer": "<github-login>" } }
```

The fixer reads it from the PR worktree, `settings.json` first and then `settings.local.json`, first non-empty value wins. Absent means request nobody beyond the code owners. The fixer never guesses a login, and never takes one from commit history or a reviewer report. Auto-merge is expected in every repository; where the base branch's ruleset has no review requirement, the fixer's comment says so in one line, and where the repository has auto-merge switched off, the comment says the PR merges by hand once approved. A PR with no checks at all counts as CI green, and the comment says that too.

## Output contract

Both reviewers return the same shape, defined once in `${CLAUDE_PLUGIN_ROOT}/skills/pr-review-loop/protocol.md`: one line per finding as `<path>:<line>: <severity>: <problem>. <fix>.`, then `VERDICT: merge|hold. <reason>`. Severity is `blocker`, `warning`, `nit`, or `decision`, and `decision` is what routes a review to a person rather than to the fixer.

## Files

- `protocol.md`: the output contract, the severity table, the five agreement conditions, the always-escalate list, the re-review step, and the fix and ready path.
- `agents/pr-adversary.md`, `agents/pr-conventions-reviewer.md`, `agents/pr-review-fixer.md`: the three agents the first pass and the fix path use.
- `agents/pr-rereviewer.md`: the second pass over a fixed head. `agents/pr-rebaser.md`: the rebase when the branch falls behind or collides.
- `commands/pr-review.md`: the `/pr-review` entry point.
