# PR Review Protocol

The contract both reviewers return, the conditions under which the session acts on its own, and the path the fixer walks. `pr-adversary`, `pr-conventions-reviewer`, `pr-rereviewer`, and `pr-review-fixer` all read this file, so the definition lives here once.

## Output contract

One line per finding, then one verdict line, then a `RAN:` list of what the reviewer executed.

```
<path>:<line>: <severity>: <problem>. <fix>.
VERDICT: merge|hold. <the single most important reason>
```

No praise, no restating the PR body, no prose between findings. A PR with nothing wrong returns a bare verdict. A finding with no file uses the PR number as the path and `0` as the line.

| Severity | Meaning | Routes to |
|---|---|---|
| `blocker` | Merging as is breaks something, fails to do what the body claims, reaches somewhere the body does not admit, or misses a rule the gate enforces | fixer |
| `warning` | Real problem, merge survivable, fix before or soon after | fixer |
| `nit` | Small and safe to defer | fixer |
| `decision` | A person has to choose | human |

## The five agreement conditions

The session acts without asking only when both reviews agree cleanly. All five have to hold:

1. **Both reviewers finished.** A timeout, a truncated report, or a report with no verdict line is not an opinion.
2. **Same verdict.** Both `merge`, or both `hold`.
3. **No `decision` finding** from either reviewer.
4. **The fixes are compatible.** Neither reviewer asks to remove what the other asks to add, and neither wants a file the other wants left alone.
5. **Neither reviewer questions the premise.** Neither says the PR should be closed, split, or rewritten to a different goal.

When all five hold, classify the findings to apply against `model-tiers`' simple definition, then spawn `pr-review-fixer` for its fix phase with the PR number, the repository, the base branch, both reports in full, and the findings to apply, and say in one line what it is doing. Take the model from its definition unless every finding is simple, in which case name `model: haiku` at this one spawn; `model-tiers` has the definition and says why a `decision` finding leaves this loop instead of being settled inside it. The fixer applies every finding that is not a `decision`, whatever the verdicts were: two `merge` verdicts with warnings still get their warnings fixed. Both `merge` with no findings, or with nothing above `nit`, means the fixer goes straight through to the ready path in one run.

When any condition fails, put the choice to the human with a recommendation, then act on the answer.

## Always escalate

Whatever the verdicts say, these go to a person:

- A finding about ownership: which team or repository owns the thing being changed.
- A naming choice that outlives the PR.
- Whether a change that reaches a shared base ships now or waits behind a staging soak.
- Splitting a PR, closing it, or reopening a question the issue already settled.
- A reviewer that could not run the check it needed, so hedged. A hedge is not agreement.

A reviewer tags each of these `decision`, which fails condition 3. The session checks the list anyway, because a reviewer can describe one of these in a `warning` by mistake.

## The fix and ready path

Once the boundary is clear, the fixer's fix phase:

1. Applies the findings in the worktree that already holds the PR branch, found with `git worktree list`, never in a shared checkout and never through `isolation: worktree`.
2. Commits signed, one commit per coherent change, message wrapped at 80 and shaped by `commit-conventions`. Never passes a flag that skips signing.
3. Rewrites the body if a reviewer said to, which sends it back through `pr-op-gate` on the way out.
4. Pushes and returns the new head SHA to the session.

## The re-review

If the fix phase changed anything tagged `blocker` or `warning`, the session fetches the new head and launches the second pass on it with the same five conditions. The second pass is `pr-rereviewer` in place of a fresh `pr-adversary`, alongside `pr-conventions-reviewer`. The re-reviewer takes the head, the head it replaced, and the applied findings from both first-pass reports, settles each finding as fixed or not against evidence at the new head, and makes one narrow pass over the fix diff for what the fix itself broke. It returns the same verdict vocabulary, so the conditions read two reports here exactly as they did on the first pass. The ready path unlocks only when that second pass returns two `merge` verdicts, or two `hold` verdicts with nothing left above `nit`.

A branch that has fallen behind its base, or that a reviewer reports colliding with another open pull request, goes to `pr-rebaser` before step 5. It works in the worktree that holds the branch, keeps both sides' intent in every conflict rather than dropping the other pull request's change, reruns the validators the touched paths map to, and pushes with `--force-with-lease`. A conflict that is a design choice rather than two additions stops it, and that goes to a person.

This is one re-review, not a loop. A second pass that still holds a `blocker` or `warning`, or that fails any of the five conditions, goes to the human with both reports and a recommendation. A fix phase that touched only `nit` findings, or had nothing to apply, needs no second pass and continues into the ready path in the same run.

Then the fixer's ready phase:

5. Waits for CI green on the head. A PR with no checks at all, in a repository with no workflows and no reporting app, counts as green, and the step 9 comment says so.
6. Runs `gh pr ready`, which is what makes GitHub request the CODEOWNERS teams.
7. Requests the configured human reviewer, if one is configured.
8. Enables auto-merge with the merge method the repository's ruleset allows. Where the repository setting Allow auto-merge is off and `gh pr merge --auto` is refused, the fixer leaves it off and the step 9 comment says the PR merges by hand once approved.
9. Posts one comment on the PR recording both verdicts and what each reviewer ran, so the human approver sees what was already checked.

## Guards the path relies on

**Auto-merge is expected in every repository, and a guarded branch keeps a human in front of it.** A ruleset that requires an approving review, a code-owner review, and approval of the last push, and dismisses stale reviews on every push, means the fixer's push always lands in front of a human, and the step 9 comment is what that human reads first. Where the base branch's ruleset has no review requirement, auto-merge can complete on CI alone, and the comment says so in one line. Where the repository has auto-merge switched off, the comment says that instead, and a person merges after approving.

**The human reviewer comes from the repository, never from a guess.** The fixer reads `prReview.humanReviewer` from the PR worktree's `.claude/settings.json`, then `.claude/settings.local.json`, first non-empty value wins, guarding for a repository that has neither file. Absent means request nobody beyond the code owners. No handle is ever invented or taken from history.

**The merge method comes from the ruleset, never from the repository flags.** The fixer reads `gh api repos/{owner}/{repo}/rules/branches/<base>` and uses the method the `pull_request` rule allows. When the endpoint returns no `pull_request` rule, the fallback is `--merge`. The repository API's `allow_squash_merge` and related flags report a setting the ruleset overrides.

**Reviewers never write.** The reviewer agents' tool lists grant Bash whole. `Bash(...)` scoping has no effect in an agent's `tools` line, so the list restricts nothing. The plugin registers a `PreToolUse` hook, `deny-gh-api-write`, that fires only for `pr-adversary`, `pr-conventions-reviewer`, and `code-reviewer` and refuses the GitHub write surface (`gh pr comment|review|edit|merge|ready|create`, `gh issue comment|create|edit|close`, `gh release`, and `gh api` with a method other than GET or HEAD or with a body), git mutations including `fetch`, cluster and deploy commands (`kubectl apply`, `flux reconcile`, `helm upgrade`, `pulumi up` and similar), network clients, and shell wrappers. It is a backstop against an accidental write, not a control. A determined agent could still evade it, so each reviewer's prompt carries the rule that it never runs a command that changes anything, and the branch ruleset's human approval is the last gate. Neither reviewer fetches, and neither posts to GitHub. The hook does not fire for `pr-rereviewer`, because that agent creates a worktree of its own to tamper-test a new test, so its prompt carries the read-only rule with nothing under it. The only GitHub writes the loop produces are the fixer's.
