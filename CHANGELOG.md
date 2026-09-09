# Changelog

Notable changes to the Datum Cloud Claude Code plugins.

## [1.14.0] - 2026-09-07

### Added

- **PR re-reviewer** (`pr-rereviewer`, datum-platform). The second pass over a fixed head now has its own agent instead of a fresh adversary reviewing the whole pull request again. It settles each finding the fixer applied as fixed or not against evidence at the new head, tamper-tests any test the fix added, then makes one narrow pass over the fix diff for what the fix itself broke. It returns the same verdict vocabulary, so the loop's agreement conditions read it unchanged.

- **PR rebaser** (`pr-rebaser`, datum-platform). Brings a pull request that fell behind its base back up to date in the worktree that holds it. Every conflict keeps both sides' intent, because dropping the other pull request's change to make a conflict go away is the failure worth preventing. It reruns the validators the touched paths map to, pushes with lease, and stops on a conflict that is a design choice rather than two additions.

- **Gap verifier** (`gap-verifier`, datum-platform). Runs before anyone writes code for an issue and answers whether the gap is still there. It reproduces the claim at trunk and at the tag production tracks, checks the open pull requests touching the same files, checks the component repository when the claim is a single-service contract, and reads live state when the claim is about a cluster. It returns confirmed, already fixed, premise wrong, or in flight, with the evidence.

- **Rollout verifier** (`rollout-verifier`, datum-platform). Takes a list of effects a release or a merge was expected to have and reports each one as confirmed, not yet, or contradicted, with the current value and the object's last transition time. It carries the readings that turn a check into a wrong answer: a configuration change does not roll pods, an empty result is not absence, and a restart count is cumulative. It never forces a reconcile, never mutates, and never decides what a not-yet means.

- **Bookkeeper** (`bookkeeper`, datum-platform). Does the small GitHub edits that follow a merge: ticking a checkbox on an opening post, closing an issue with a supplied body, commenting, filing an issue, and parenting a sub-issue. Every body comes from the brief, it addresses nobody, and a checkbox tick is diffed to prove it changed one character before it goes through. It runs on haiku when every body is supplied verbatim.

- **Model tiers** (`model-tiers`, datum-platform). One place that says which model an agent gets and why. Authoring work that carries design risk gets opus, because a wrong approach costs a review round or a bad release. Bounded work against an explicit brief gets sonnet, and read-only lookup gets haiku. An agent that meets a decision above its tier stops and reports rather than deciding, and the orchestrator escalates. The model is a cost choice and never an acceptance bar, so the same brief and the same gates hold at every tier.

### Changed

- **Agent model pins now follow the tiers.** The two PR reviewers, the review fixer, and the code-reviewer move to sonnet: each works from a brief against a diff that already exists, and anything needing a person's choice already leaves the loop as a `decision`. The planner and the three implementation agents move to opus, because they author the change rather than judge one. Reviews carry the same weight they did, and nothing about the acceptance bar moves with the model.
- **Spawn instructions name the tier, not the model.** The pipeline, review, release, and PR review loop skills now take the model from the agent definition rather than naming one at the spawn, and point at `model-tiers` for the reason.
- **The review fixer drops to haiku on simple findings.** When every finding the two reviewers agreed on is mechanical, a wording change, a rename, a single-value change, a comment strip, a content-free file move, or a link, the orchestrator classifies them and spawns the fixer on haiku instead of sonnet. Anything that touches logic, an expression, a query, a template, a test, or a workflow, or needs a validation run, keeps the fixer on sonnet, and a haiku fixer that meets one of those stops and reports rather than attempting it.

## [1.13.0] - 2026-09-05

### Added

- **PR review loop.** Two read-only opus reviewers with different angles review a pull request at once. When both agree, a fixer applies their findings, pushes, waits for a second pass, then marks the PR ready and enables auto-merge. Run `/pr-review [number]`, or let the `pr-review-loop` skill trigger on a PR the session opens. Skill-driven, no automatic trigger yet. A guard hook, firing only for the reviewer agents, refuses GitHub writes, git mutations, cluster changes, and shell wrappers. It is a backstop against an accidental write, not a control: the reviewers' prompts carry the rule, and the branch ruleset's human approval is the last gate.

### Fixed

- **Marketplace catalogue versions.** The catalogue entries for `datum-platform` and `datum-gtm` now match their plugin manifests. They had sat at 1.0.0 while the manifests moved, and the validator warned on every run.
- **Inert agent permission fields.** `code-reviewer` drops `permissionMode` and the `Bash(...)` scoping in its `tools` line, neither of which the agent loader honours, and its body now says what it may run. The datum-gtm agents get the same fix in 1.1.1.

## [1.1.1] - 2026-09-05

### Fixed

- **Inert agent permission fields** (datum-gtm). The four agents drop `permissionMode` and the `Bash(...)` scoping in their `tools` lines, neither of which the agent loader honours, and each body now says what it may run.

## [1.12.0] - 2026-09-04

### Added

- **Clear writing skill** (`clear-writing`, datum-platform) — The prose basis for every Datum repository, adapted from the European Economic and Social Committee's *Clear Writing* guide. Carries only what the Orwell and Google rules in `pr-conventions` do not: the seven questions a piece of writing has to answer, verbs over nominalized nouns, sentence order and modifier placement, restrictive commas, concrete over abstract, word pairs and false friends, and a technical section on READMEs, error messages, code comments, and reference docs. Includes a phrase table of wordy constructions, Latin tags, and jargon with plain replacements.

### Changed

- **PR/issue body gate** (`pr-op-gate`, datum-platform) — Now refuses any phrase in the clear-writing table, naming each one and its replacement. The gate reads the table from the skill at run time, so the doc and the enforcement cannot drift, and an unreadable table is a refusal rather than a pass. Edits stay judged on what they add, so a phrase already in a colleague's post is not yours to fix.
- **GitHub conventions skill** (`pr-conventions`), **commit conventions** (`commit-conventions`), and the **tech-writer agent** now point at `clear-writing` instead of restating it.

## [1.9.0] - 2026-08-04

### Added

- **PR/issue body gate** (`pr-op-gate`, datum-platform) — A `PreToolUse` hook that measures the body of a `gh pr|issue create|edit` call and blocks the post when it misses the countable rules: summary over four sentences, test plan over four checkboxes, file paths or identifiers in the opening post, a `Closes` keyword, an emoji heading, or hard-wrapped prose. Each denial names the rule and the count that broke it, so the draft gets revised before it goes up rather than after. Replaces per-repository copies of the same checklist that only ever advised.

### Changed

- **GitHub conventions skill** (`pr-conventions`, datum-platform) — Rewritten around a countable bar rather than qualitative advice, and cut by more than half so the skill reads the way it asks writers to write. Adds Orwell's writing rules and Google's technical writing rules as the style basis, states which limits the gate enforces, and drops the prose-about-prose tables and long worked examples that taught the verbosity the skill was meant to prevent.

## [1.8.2] - 2026-07-29

### Changed

- **GitHub conventions skill** (`pr-conventions`, datum-platform) — Sharpened "be concise" into two enforceable rules: say it once (no restating the summary as test-plan checkboxes, no describing the same behaviour in prose and again in a checklist) and cut every word carrying no fact, with a compress-don't-omit clause so brevity never costs facts. Added the two matching rows to the PR "What to Avoid" table.

## [1.8.1] - 2026-07-09

### Changed

- **GitHub conventions skill** (`pr-conventions`, datum-platform) — Added a rule forbidding hard-wrapped prose in PR descriptions, issues, and comments. GitHub reflows Markdown, so manual fixed-column wrapping (e.g. 80 characters) produces ragged, hard-to-edit text; hard-wrapping belongs only in commit messages. Added as a Core Principle and a row in the PR "What to Avoid" table.

## [1.1.0] - 2026-07-08

### Added

- **Changelog entry skill** (`changelog-entry`, datum-gtm) — Guides the gtm-comms agent through turning raw engineering notes, PR/issue links, or a feature description into a hand-off-ready draft for Datum's GitHub Discussions Changelog. Covers benefit-led titling, a fixed post structure (lead → hero feature → New/Improved/Fixed, plus a breaking-changes heads-up and security wording → docs links → single CTA), a voice pass that strips Kubernetes jargon and internal implementation detail, an anti-fabrication rule with a `[VERIFY]` convention, a public-vs-private community credit gate, a scope gate with a stakeholder-override path, and a required pre-publish handoff block. Ships a fill-in `template.md`, a worked `example.md`, and a self-review checklist that mirrors every rule. Complements the Keep-a-Changelog release-file template in `gtm-templates`.

## [1.8.0] - 2026-05-04

### Added

- **Release skill** (`release`) — Generates GitHub releases for any datum-cloud service repository. Gates releases on a green CI status for the release commit and refreshes the third-party `NOTICE` file (license compliance) before tagging. Auto-detects project type (CRD-based operator or aggregated API server), collects merged PRs since the last release, diffs schema/type files to determine compatibility, drafts release notes in the established style, and publishes via `gh release create`. Supports `--patch`, `--minor`, `--major`, and `--draft` flags.

## [1.7.0] - 2026-04-30

### Changed

- **GitHub conventions skill** (`pr-conventions`) — Expanded from PR-only guidance to cover issues and comments. PRs must now link to an issue. Avoid using `Closes`/`Closed` — use `Fixes` or `Resolves` only when intentionally closing. Issue descriptions focus on goals and desired outcomes; technical discussion belongs in comments. Adds GitHub callout syntax guidance and a rule to always use descriptive link text.

## [1.6.0] - 2026-04-12

### Added

- **Operational review skill** (`operational-review`) — Guides the SRE agent through producing weekly traffic and latency ops review reports for the global Envoy edge ingress. Covers VictoriaMetrics queries for RPS and latency (P50/P90/P95) globally and per-POP, anomaly detection thresholds, and publishing structured reports as pull requests to `datum-cloud/engineering`.

## [1.5.0] - 2026-02-20

### Added

- **PR conventions skill** (`pr-conventions`) — Standardized pull request description guidelines covering structure, required sections, and content guidance. Defines Summary, Test plan, and Breaking changes sections. Agents prompt for context when PR purpose is unclear.

## [1.4.0] - 2026-02-20

### Added

- **Commit conventions skill** (`commit-conventions`) — Standardized commit message guidelines based on the seven rules from cbea.ms/git-commit. Provides format, structure, and content guidance for consistent commit history across repositories. Agents prompt for clarification when commit purpose is unclear.

## [1.3.0] - 2026-02-20

### Added

- **Feature gates pattern** (`k8s-apiserver-patterns`) — Guidance for safely introducing experimental features with Alpha/Beta/GA lifecycle stages. Helps API developers ship new capabilities incrementally while giving operators runtime control via `--feature-gates` flags.
