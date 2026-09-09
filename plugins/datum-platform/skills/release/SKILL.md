---
name: release
description: >
  Create a new GitHub release. Verifies CI is green on the release commit and
  refreshes the third-party NOTICE file before tagging, determines the next
  version from the latest tag, summarizes merged PRs since the last release,
  drafts release notes in the established style, and publishes via gh release
  create. Works for any datum-cloud service repository.
tools: Read, Bash
model: sonnet
context: fork
agent: general-purpose
argument-hint: "[vX.Y.Z] [--draft] [--patch|--minor|--major]"
---

# Release Command

Generate and publish a new GitHub release for this repository.

Cutting a release follows the recipe below, so it runs on sonnet. Where the recipe does not fit, such as a version that needs a judgment call or a preflight that fails for a reason not listed here, stop and report rather than improvising. The `model-tiers` skill has the tiers and the escalation rule.

## Usage

```
/release                      Auto-determine next minor version and publish
/release v0.7.0               Publish a specific version tag
/release --patch              Bump patch (v0.6.0 → v0.6.1)
/release --minor              Bump minor (v0.6.0 → v0.7.0) — default
/release --major              Bump major (v0.6.0 → v1.0.0)
/release --draft              Create a draft release for review before publishing
```

## Arguments

Version or flags: $ARGUMENTS

---

## Workflow

### Step 1 — Pre-flight: verify the release is safe to cut

**Never cut a release from a commit that is not passing CI.** A tagged release is
immutable and consumers will pull it, so the release commit must be green first.

```bash
# Resolve the default branch and the commit that will be tagged
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
git rev-parse HEAD

# Check the combined commit status (legacy status contexts)
gh api "repos/{owner}/{repo}/commits/$(git rev-parse HEAD)/status" --jq '.state'

# Check GitHub Actions / check-run results for the same commit
gh api "repos/{owner}/{repo}/commits/$(git rev-parse HEAD)/check-runs" \
  --jq '.check_runs[] | {name: .name, status: .status, conclusion: .conclusion}'
```

Treat the release commit as **not releasable** unless:
- The combined status is `success` (or `null`/empty when no legacy statuses exist), and
- Every check run has `status: completed` with a `conclusion` of `success`, `skipped`, or `neutral`.

If any check is still `in_progress`/`queued`, or any concluded as `failure`,
`cancelled`, `timed_out`, or `action_required`, **stop** and report the failing
checks (see Error Handling). Do not offer to bypass unless the user explicitly
insists and understands the risk.

Also confirm the working tree is clean and you are on the default branch (see
Error Handling for the exact warnings).

### Step 2 — Determine the next version

```bash
# Get the latest tag
git tag --sort=-version:refname | head -1

# List recent releases for context
gh release list --limit 5
```

Parse the latest tag (e.g., `v0.6.0`) and bump the appropriate component:
- `--patch`: `v0.6.0` → `v0.6.1`
- `--minor` (default): `v0.6.0` → `v0.7.0`
- `--major`: `v0.6.0` → `v1.0.0`
- An explicit version argument overrides all flags.

### Step 3 — Collect merged PRs since the last release

```bash
# Get the publish date of the last release
gh release view <last-tag> --json publishedAt --jq '.publishedAt'

# List merged PRs since that date
gh pr list --state merged \
  --json number,title,author,mergedAt,labels,body \
  --search "merged:>YYYY-MM-DDTHH:MM:SSZ" | jq '.'
```

Filter out:
- Automated dependency bumps from `renovate[bot]` (unless they represent a significant upgrade worth calling out)
- PRs merged before the previous release date

Group remaining PRs into categories based on title prefix or labels:
- **Breaking changes** (`feat!`, `fix!`, or label `breaking-change`)
- **Features** (`feat:`)
- **Fixes** (`fix:`)
- **Infrastructure / chores** (`chore:`, `ci:`, `build:`)

### Step 4 — Detect project type and schema changes

Auto-detect what kind of project this is so the release note includes the right compatibility statement. Run these checks in order; a project may match more than one.

**Check 1 — CRD-based operator:**
```bash
# Look for generated CRD YAML files
find . -name '*.yaml' \( -path '*/crd/bases/*' -o -path '*/crds/*' \) | grep -v vendor | head -10
```

If CRD files are found, extract the kinds they define:
```bash
grep '^  name:' <crd-files> | awk '{print $2}' | sort -u
# or
grep -h 'kind:' <crd-files> | grep -v '#' | sort -u
```

Diff those files against the previous tag:
```bash
git diff <last-tag>...HEAD -- <crd-paths>
```

- Changed: note the affected resources and whether existing objects require migration.
- Unchanged: include `> No schema changes. Existing resources keep working without any conversion.`

**Check 2 — Aggregated API server:**
```bash
# Look for APIService registration manifests
find . -name '*.yaml' | xargs grep -l 'kind: APIService' 2>/dev/null | grep -v vendor | head -5

# Look for the aggregated apiserver binary entry point
find . -type d -name 'apiserver' | grep -E 'cmd/|server/' | grep -v vendor | head -5

# Look for the pkg/apis layout used by aggregated API servers
find . -type d -name 'registry' | grep -v vendor | head -5
```

If an aggregated API server is detected, find the API type files:
```bash
# Types live in Go files, not YAML — look for *_types.go under api/ or pkg/apis/
find . -name '*_types.go' | grep -v vendor | head -20
```

Diff those type files against the previous tag to detect schema changes:
```bash
git diff <last-tag>...HEAD -- $(find . -name '*_types.go' | grep -v vendor | tr '\n' ' ')
```

- Changed structs or fields: note that consumers using the Go client or REST API may be affected.
- Unchanged: include `> No API type changes. Existing clients and resources keep working without any update.`

**Check 3 — Go module name** (for import path callouts in breaking releases):
```bash
head -1 go.mod
```

**Check 4 — Container image** (for image ref callouts in breaking releases):
```bash
grep -r 'ghcr.io' .github/ Makefile config/ --include='*.yaml' --include='*.yml' -l 2>/dev/null | head -3
```

If neither CRDs nor an aggregated API server are found, omit the schema / compatibility section entirely.

### Step 5 — Refresh the NOTICE file (license compliance)

Datum-cloud repositories ship a `NOTICE` file that aggregates the licenses and
attributions of third-party dependencies. It **must** be regenerated and reflect
the exact dependency set of the release commit before tagging, or the release
falls out of license compliance.

**Find the existing NOTICE and its generation mechanism:**
```bash
# Existing notice/attribution file
ls NOTICE NOTICE.md NOTICE.txt THIRD_PARTY_NOTICES* 2>/dev/null

# Preferred: a repo-provided target (use this if it exists)
grep -nE '^(notice|licenses?|third-party|attributions?)[a-z-]*:' Makefile 2>/dev/null
ls hack/*notice* hack/*license* scripts/*notice* scripts/*license* 2>/dev/null
```

**Regenerate it.** Prefer the repo's own mechanism; fall back to `go-licenses`
for Go modules:
```bash
# 1. Preferred — a Makefile target or hack/ script the repo already defines
make notice          # or: make licenses / make generate-notice / hack/update-notice.sh

# 2. Fallback for Go modules with no dedicated target
go install github.com/google/go-licenses@latest
go-licenses report ./... --template hack/notice.tpl > NOTICE   # if a template exists
# otherwise capture the license inventory:
go-licenses report ./... > NOTICE
```

**Check whether the regenerated file drifted from what is committed:**
```bash
git status --porcelain -- NOTICE NOTICE.md NOTICE.txt THIRD_PARTY_NOTICES*
git diff -- NOTICE NOTICE.md NOTICE.txt THIRD_PARTY_NOTICES*
```

- **No drift:** the committed NOTICE is current — proceed.
- **Drift detected:** the release commit is **not** in compliance. The NOTICE
  change must land on the default branch *before* tagging (releases are cut from
  a clean default branch). **Stop**, show the diff, and instruct the user to open
  a PR updating NOTICE and re-run `/release` once it merges. Do not tag over a
  dirty tree just to include the NOTICE change.
- **No NOTICE file and no generation mechanism found:** warn that the repository
  has no third-party attribution file and recommend adding one, but let the user
  decide whether to proceed.

### Step 6 — Draft release notes

Examine the last 2–3 releases with `gh release view <tag>` to match the established style and tone of this repository before writing new notes.

**Structure:**

```markdown
{One-sentence summary of the release theme.}

{Optional: > [!IMPORTANT] block for breaking changes — list exactly what
consumers must update: imports, image refs, install paths, CRD migrations, etc.}

## What's new

- **{Feature title}** — {one-sentence description}. ({PR link(s)})
- **{Fix title}** — {one-sentence description}. ({PR link(s)})

{Optional: > [!NOTE] block for schema/compatibility or upgrade notes}
```

**Style rules:**
- Each bullet leads with a **bold short title** followed by an em-dash (`—`), then a single sentence.
- Link every bullet to the PR(s) that delivered it: `([#N](url))`.
- Breaking changes go in a `> [!IMPORTANT]` callout above `## What's new`.
- Upgrade / compatibility notes go in a `> [!NOTE]` callout after `## What's new`.
- For CRD-based projects with no schema changes, add: `> No schema changes. Existing resources keep working without any conversion.`
- Omit routine dependency bumps unless the upgrade is significant (e.g., a major version of a core dependency).
- Release title format: `vX.Y.Z — {Short theme}` (em-dash, not a hyphen; omit if there is no clear theme).

### Step 7 — Confirm before publishing

Show the user:
- CI status of the release commit (all checks green)
- NOTICE status (current / regenerated with no drift)
- The proposed tag (`vX.Y.Z`)
- The release title
- The full release notes body

Ask for confirmation before running `gh release create`.

### Step 8 — Create the release

```bash
gh release create <tag> \
  --title "<tag> — <Short theme>" \
  --notes "$(cat <<'EOF'
<release notes body>
EOF
)" \
  [--draft]
```

If `--draft` was requested, skip publishing and return the draft URL for review.

---

## Output

```
CI status: all checks passing (release commit abc1234)
NOTICE: up to date  |  regenerated, no drift
Next version: v0.7.0 (minor bump from v0.6.0)
PRs since v0.6.0: 4 merged
Project type: CRD-based operator  |  aggregated API server  |  plain service
Schema changes: none  |  <list of changed resources>

Proposed release title: v0.7.0 — Webhook high availability

Release notes:
---
...
---

Publish this release? (yes/no)
```

After confirmation:

```
Release published: https://github.com/<org>/<repo>/releases/tag/v0.7.0
```

---

## Error Handling

**CI not passing on the release commit:**
```
Blocked: the release commit <sha> is not passing CI. Failing/incomplete checks:
  - <check name>: <conclusion or status>
Releases must be cut from a green commit. Fix CI (or wait for in-progress checks
to finish) and re-run /release.
```

**NOTICE file drifted:**
```
Blocked: NOTICE is out of date for this commit. Third-party dependencies changed
without regenerating attributions. Open a PR to update NOTICE, merge it to the
default branch, then re-run /release. (Diff shown above.)
```

**Uncommitted changes:**
```
Warning: you have uncommitted changes. Releases should be cut from a clean
main branch. Stash or commit changes before releasing.
```

**Not on main (or default branch):**
```
Warning: current branch is not main. Releases are typically cut from the
default branch. Confirm you want to release from: <branch-name>
```

**Tag already exists:**
```
Tag v0.7.0 already exists. Choose a different version or delete the existing
tag first: git tag -d v0.7.0 && git push origin :v0.7.0
```

**No previous release found:**
```
No previous release found. Collecting all merged PRs and generating
initial release notes.
```
