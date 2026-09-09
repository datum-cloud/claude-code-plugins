---
name: pr-conventions
description: Covers GitHub conventions for pull requests, issues, and comments including linking, language style, formatting, and callout syntax. Use when creating PRs, writing issues, or posting comments on Datum Cloud repositories.
---

# GitHub Conventions

Rules for PR, issue, and comment bodies in every `datum-cloud`, `milo-os`, and
`datum-labs` repository. The `pr-op-gate` hook enforces the countable ones on
`gh pr|issue create|edit`. A new post has to meet the bar outright. An edit has
to leave the post no further from the bar than it found it.

## The bar

Countable, so it can be checked rather than believed:

| Limit | Applies to |
|---|---|
| Summary: **4 sentences or fewer**, spread across paragraphs rather than massed in one | PR and issue bodies, before the next heading |
| Test plan: **4 checkboxes or fewer** | PRs; behavioral outcomes only, build/lint/test collapse to one row |
| **No** file paths, identifiers, per-file breakdowns, or local tool invocations | PR and issue bodies |
| **No** hard-wrapped prose | everywhere on GitHub |
| **No** em dashes, and none of the banned phrases below | everywhere |
| **No** wordy phrase, Latin tag, or jargon from the `clear-writing` table | everywhere |
| Callouts only for a caveat that changes what a reader would do | everywhere |

Target: a reader with no context grasps the why in 30 seconds. Depth goes in a
comment or the commit message, where length costs nothing.

## Writing rules

The `clear-writing` skill is the prose basis: the seven questions a body has
to answer, verbs over nouns, concrete over abstract, and the phrase table the
gate reads. This section carries only what is specific to GitHub.

Orwell, applied:

1. Cut every word that carries no fact. Compress, never omit.
2. Short word over long. Active over passive.
3. No stale metaphor, no jargon with an everyday equivalent.
4. Break any rule sooner than write something barbarous.

[Google's technical writing rules](https://developers.google.com/tech-writing),
applied:

1. One idea per paragraph. Short sentences.
2. Name the audience before writing. Most readers do not work on this codebase.
3. Define a term the first time you use it, or drop the term.
4. Lists for sequences, tables for comparison, prose for reasoning.
5. Delete "simply", "just", "easily", "obviously". They only tell a stuck
   reader they are stupid.

**Say it once.** Never describe the same behaviour in prose and again in a
checklist. Never restate the summary in the test plan. Anything already in the
linked issue gets linked, not restated.

**Don't hard-wrap.** GitHub reflows Markdown. Fixed-column wrapping produces
ragged lines that are awkward to edit. Wrap only where syntax needs it: lists,
tables, code fences. Hard-wrapping belongs in commit messages alone.

**Cadence.** Break prose into short, single-idea paragraphs, and vary their
length. Anything from one to three sentences is fine, and a longer paragraph
followed by a single-sentence one is the shape to aim for.

The rule is the variation, not a number. A run of same-length paragraphs is the
thing to avoid, whether they all run long or all run short.

Long individual sentences are fine. Length is a problem in paragraphs.

No counter can tell a pleasing alternation from a monotonous one, so this one
rests on the writer rather than on the gate. What the gate counts is sentences
in the summary, and nothing else about shape.

The summary's four-sentence budget is spread across paragraphs, not massed into
one block. A four-sentence block passes the count and still reads as a wall.

A dense block that packs setup, mechanism, and consequence together gets split
so each beat stands alone and a reader can skim. The shape that works runs from
the problem, to how it fails, to what should have prevented it, to the gap, to
what this change does, and finally to what it changes for a reader. Use a
bulleted list for any enumerable beat rather than packing the items into a
comma-run, and let prose carry the narrative.

## Banned words and punctuation

| Banned | Write instead |
|---|---|
| Em dash (`—`) | A period, a comma, or nothing. Reserve it for the rare case where neither works. |
| "load-bearing" | Name the dependency. "That silence is load-bearing" becomes "those alerts evaluate against series nothing produces, so they cannot fire." |
| "gotchas" | Caveats, watch-outs, constraints, limitations. Applies to headings too. |
| Arrows (`→`, `->`) for a sequence | An ordered list. Arrows for a simple mapping or rename are fine; prefer a preposition when one reads well. |
| "structural" | Name the structure and what it forces. "The docs make it structural" becomes "the docs tell contributors to set the version in two files and nothing keeps the two in step." |
| "why it matters:" | Nothing. Drop the label and let the sentence under it stand on its own. A `## Why it matters` heading is the same tic wearing a bigger hat. |
| "kept it honest" (or kept them, or us) | Say what the check verifies and what it would have caught. "The test kept it honest" becomes "the test fails when the generated file drifts from its source." |
| "that's a valid answer" | "ok", or nothing at all. Ratifying somebody's choice back to them carries no fact. |

Stacked em dashes read as a verbal tic and blur where one thought ends and the
next begins. A period forces the sentence to finish. "Load-bearing" gestures at
importance without saying what depends on the thing or what breaks without it.

"Structural" is the same gesture. It claims a thing is deep rather than
incidental and then declines to say which structure produces it, which is the
one fact a reader needs. The ban is the bare word in prose, not the idea: a
genuine term of art stays available in code formatting, where `structural
merge` reads as the name of a thing rather than as a verdict.

A "why it matters" label announces that the point is coming instead of making
it, and the sentence underneath survives the label's removal untouched. "Kept
it honest" claims a check did its job without saying what it compared, so
nobody can tell whether it would catch the next drift.

**Colons and semicolons.** Don't use a colon where a period would work. Don't
use a semicolon where a comma or a period would work.

The tic is a punctuation mark standing in for a sentence break. "Docs-only; no
behavior change" is two sentences wearing one, and so is "the cause is narrow:
the poller never restarts". Write each as two and the prose picks up speed.

Both marks have honest work to do. A colon introduces a genuine list, and
either mark turns up inside code, a URL, a table row, `Related to`, a
conventional-commit prefix, or a clock time. Across a hundred recently merged
bodies a colon appears in prose in about half of them and a semicolon in a
fifth, and a gate rule would have to refuse all of those to catch the tic in
some of them. So this pair is guidance, and the gate stays out of it.

## Naming a cause

State a cause in an issue, a PR, or a comment only when the evidence
discriminates: it has to explain why the broken cases broke *and* why the
working cases worked. "Consistent with the facts" is not the same as explaining
the difference between the case that failed and the case that didn't.

When two groups behave differently, diff their API objects field by field
before theorizing. `gh api repos/<owner>/<repo>/pulls/<n>` carries fields the UI
and `gh pr view` never show.

Say plainly what remains unknown rather than smoothing the gap over.

## Structure

PR body:

```markdown
## Summary

<The problem, in one sentence.>

<How it fails, and what it costs.>

<What this change does.>

<The caveat or the limit, if there is one.>

## Test plan

- [ ] <Observable outcome>

Fixes #<issue>
```

Issue body: what needs to happen, why it needs to happen, what success looks
like.
Outcome-focused acceptance criteria: "a user can do X", not "the handler calls
Y". Keep the solution out of the description; it belongs in comments.

Add `## Breaking changes` when something downstream must migrate. Add
`## Screenshots` for UI work. Omit empty sections.

## Titles

Conventional prefix (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`),
imperative mood, capitalized after the colon, no trailing period, under 72
characters. Describe the outcome, not the mechanism.

**Good:** `feat: Show activity timeline on the resource dashboard`
**Avoid:** `feat: Add ActivityFeed component with websocket polling`

Issue titles state the symptom in plain language: `Users can't see who last
modified a resource`, not `NullPointerException in ResourceController`.

## Linking

Every PR links the issue it addresses. Required.

| Keyword | Use when |
|---|---|
| `Fixes #n` / `Resolves #n` | merging should close the issue |
| `Related to #n` | connected, but does not fully address it |

Never `Closes`, because closing is deliberate. Cross-repo references need
`org/repo#n` or a full URL; a bare `#n` resolves in the current repo only. A
bare issue or PR URL renders as a titled, state-aware chip, so prefer it over
`[here](url)`.

`Related to` does **not** auto-close on merge. After a batch of PRs lands, close
each shipped issue by hand (`gh issue close --reason completed --comment ...`)
and reconcile any tracker. Verify against issue state, not PR state.

## Lifecycle

Open every PR as a draft (`gh pr create --draft`) unless the requester asks for
it ready. Review and CI should settle before a PR is marked ready.

**Superseding a stale PR.** When a PR sits many commits behind trunk, often with
most of its content already landed through siblings, branch fresh from
`origin/main`, port only what is genuinely unique to it, and open a new PR. Then
comment `Superseded by #NNN` on the old one and close it. Never force-push over
the original author's branch.

**Fanning out PR-opening agents.** Give each writer its own worktree
(`isolation: "worktree"`). Concurrent writers sharing one working tree race on
branch checkout, commit, and push, and one agent's commit lands on another's
branch. Pin the base SHA once up front and hand every agent the literal SHA so
the batch shares a known base. Give each one a stop-and-report escape for when
the premise does not hold. Read-only agents need none of this.

## Comments

Comments carry the depth the description sheds: tradeoffs, alternatives,
questions. Plain prose. No headers; a header means the content belonged in the
description. No tables except a genuine side-by-side comparison of options.

Only @-mention handles grounded in the repo (CODEOWNERS, the commit history,
existing reviewers) or ones the requester names. Never invent a handle. When
unsure, omit the mention entirely.

**Evaluations are the exception to the no-headers rule.** A survey, review, or
multi-part evaluation is a deliverable in its own right, and readers need to
skim to the section they care about. Post it as one comment with `##` headers,
never split across several comments. When a later turn adds a dimension, fold it
into the existing comment rather than appending a new one:

```
gh api --method PATCH repos/<owner>/<repo>/issues/comments/<id> -F body=@file.md
```

**Corrections are one line.** When a claim you posted turns out to be wrong,
state the correction and the evidence that settles it in a single sentence. A
reader arriving at the thread needs the current answer, not the archaeology of
how you got it wrong. Hide the superseded comment as `outdated` instead of
deleting it, which collapses the wrong turn while leaving it auditable:

```
cid=$(gh api repos/<owner>/<repo>/issues/comments/<id> --jq .node_id)
gh api graphql -f query='mutation($id:ID!){minimizeComment(input:{subjectId:$id,classifier:OUTDATED}){minimizedComment{isMinimized}}}' -f id="$cid"
```

Rewrite the issue title and opening post to the corrected framing too. A stale
title outlives every comment.

## Replying in a dispute

A review that contradicts a fact in your pull request, and your reply to it,
follow different rules from the evidence comment on your own work. Depth
belongs in that evidence comment. A dispute reply carries one thing: why the
two of you disagree.

Pull request datum-cloud/infra#4968 shows the failure. Five posts, three
reviews and two replies, and seventeen hours settled one fact, that the
reviewer's checkout predated the merge which added the route under dispute.
The decisive sentence came last in a reply that cited line numbers, a commit
SHA, a render, and a live object. The gate does not measure comments, so these
rules rest on the writer.

The reply is addressed to a person, so an agent drafts it for the requester to
send, and posts it only when the requester asks.

**Pin your state before contradicting a fact.** Say what you read and when:
`main at a0e658d`, `live production at 2026-09-09 17:45Z`, `staging overlay
rendered at 2026-09-08 09:00Z`. Two readers who each confirmed opposite facts
read different states. Naming yours lets the other side find the difference in
one line instead of proving the fact again.

**Answer a contradiction with its cause, not with more evidence.** When a
reviewer asserts something you know to be false, the reader needs the reason
the two of you differ. "The route merged in #4920 at 2026-09-08 18:34Z, and a
checkout older than that does not have it" ends the thread. A second proof of
the same fact does not. You cannot read the other side's checkout, so state the
cause as a condition rather than as a fact about them.

**One claim, one proof.** Cite the most authoritative source and stop. A live
object beats Git at a SHA, and Git at a SHA beats a local render. If the reader
should reproduce it, give the command in a code block. Three proofs of one fact
tell the reader the writer did not trust the first.

**State the fact, not how you learned it.** "Confirmed via kustomize build",
"checked all VMAlertmanagerConfig objects, base and both overlays", and
"verified against current main" describe the writer's afternoon. Delete them.
The fact stands or falls on its citation. A pinned state is a citation, not a
method: keep `main at a0e658d`, cut "confirmed via kustomize build".

**Cut what the reader verifies faster than reads.** The author of the
repository does not need telling that `us-central-1-lab` is a lab cluster, or
where the production cluster label is set. Explain only what the reader
plausibly lacks.

**No parentheses.** Every parenthesis in a dispute is a proof of a proof.
Promote it to a sentence or delete it.

**Don't restate the pull request, and don't repeat your last comment.** The
reader is on the page. If your previous reply did not land, name the sentence
the other side missed rather than saying it all again with more.

**Fixed shapes.** A review that requests changes is a verdict, a reason, and an
ask. A withdrawal is a correction, so the one-sentence rule above applies: the
withdrawal, its cause, and the new verdict.

| Posted | Rewrite |
|---|---|
| "the only route to the blackhole receiver matches cluster=us-central-1-lab, which is an edge lab cluster, not prod (prod's cluster label is prod-infrastructure-control-plane, set in production/kustomization.yaml). There is no route matching severity=info anywhere." | The only blackhole route matches `cluster=us-central-1-lab`. Nothing routes on `severity=info`. Read at main, 2026-09-08 09:00Z. |
| A reply citing line numbers, a SHA, a render, and a live object | The info route merged in #4920 at 2026-09-08 18:34Z, and a checkout older than that does not have it. Read at main a0e658d. |
| An approval restating the whole routing argument | Withdrawn and approving, since my checkout predated #4920. |

## Callouts

`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`.
Never an emoji header (`## ⚠️ ...`). If everything is highlighted, nothing is.

## Editing a post you did not write

On an edit, `pr-op-gate` reads the body already posted and scores it on the same
rules as the body you are about to post. It refuses only where your version
scores worse. Ticking a checkbox on a post written before the convention passes.
Adding an em dash to that same post does not.

So the misses that predate your change are not yours to fix, and the answer to a
colleague's unformatted issue is never to rewrite their words.

An edit that touches only labels, a title, or a milestone is never measured
against body rules at all.

When the gate cannot read the posted body, from a failed fetch or a target it
cannot resolve, it allows the edit and says so, listing what the body it is
about to post misses. Fix whatever your edit introduced and leave the rest.

There is no route around the gate, and no need for one. A body you are authoring
gets fixed, not bypassed.

## Example

```markdown
## Summary

Users had no way to see recent activity on a resource, so understanding what changed meant reading audit logs.

The resource detail page now shows the last 20 actions, newest first, drawn from the existing Activity API.

## Test plan

- [ ] Timeline paginates and renders empty and error states
- [ ] Resources predating activity tracking degrade without crashing

Fixes #234
```
