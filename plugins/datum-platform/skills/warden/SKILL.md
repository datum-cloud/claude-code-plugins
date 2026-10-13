---
name: warden
description: >-
  Recurring production infrastructure health patrol, run as the robot half of
  an on-call shift. Checks firing alerts, active silences, Flux reconciliation,
  and pod and workload health on the production control plane, keeps one shift
  comment on the current week's on-call log, files untracked alerts, proposes
  narrow silences for a person to approve, and continues on a self-paced loop.
  Trigger when the user says "warden", "walk the beat", asks for an infra
  patrol, a health check or a production status sweep, or wants the patrol
  looped.
---

# Warden

The warden walks the beat: a recurring health patrol of Datum **production**
infrastructure. It reports only anomalies. A green pass is a one-line
all-clear.

The patrol is the robot half of an on-call shift, so it works the way the shift
does. It reads what the last engineer left, keeps one running note on the
current week's on-call log, and files what the rotation is expected to file.
The process it follows is
[`docs/oncall.md`](https://github.com/datum-cloud/engineering/blob/main/docs/oncall.md)
and
[`docs/incidents.md`](https://github.com/datum-cloud/engineering/blob/main/docs/incidents.md)
in `datum-cloud/engineering`. Where this skill and those docs disagree, the
docs win.

The patrol runs from any Datum repository. Paths below that start with
`docs/` or `bin/` are in `datum-cloud/infra`; read them from a checkout of that
repository, or with `gh api repos/datum-cloud/infra/contents/<path>`.

## Scope: production only

- Use the `datum-infra-prod` MCP server. **Never** query `datum-infra-staging`.
- Production is `prod-infrastructure-control-plane`, the cluster that server
  surfaces.

## What the patrol never does

Each of these needs a person, and the patrol stops and says so instead:

- **Declare an incident.** It drafts one and waits. See
  [Suspected incidents](#suspected-incidents).
- **Write a silence without approval.** It proposes one and waits. See
  [Silences](#silences).
- **Close an issue it did not open.** See
  [Issue hygiene](#issue-hygiene-close-what-the-patrol-filed).
- **Address a person.** No replies on someone's thread, no `@` mentions, no
  pages, no Slack. Agents it spawns inherit this rule.
- **Mark a pull request ready, merge, tag, or force a Flux reconcile.**

## Modes

The patrol runs in one of two modes, picked by cost. Triage is the cheap idle
pass. Investigate is the deep drill-down.

- **triage** asks what is new or changed since the last pass, including
  anything that fired and resolved *between* ticks. Load the `alerts` and
  `query_range` tools. Take the current firing snapshot, then run an
  `ALERTS{alertstate="firing"}` lookback over the window since the previous
  pass to catch alerts that paged and resolved before the snapshot (see
  [Checks](#checks-in-order)). Diff against the previous pass's firing set. If
  nothing is new, changed, or flapped, emit a one-line all-clear and move any
  resolved alert to **Cleared** in the shift comment. Escalate to investigate
  for each new, changed, or flapped alert. Triage is the default on the loop.
- **investigate** is the deep pass for one alert, or for the whole surface when
  invoked directly: Flux resource state, pod and workload health, logs,
  metrics, per-namespace drill-down, runbooks. Escalated from triage, it covers
  only the new or changed alerts, not the whole cluster. An investigation that
  ends on a new, untracked production fault continues into
  [Escalation](#escalation-diagnose-then-fix).

Mode selection:

- `warden triage` forces a triage-only pass.
- `warden investigate` forces a full deep pass across the surface.
- Bare `warden` runs a **full pass**: a triage sweep plus investigate on every
  firing alert. The first pass of a session uses it to set the baseline firing
  set. Loop ticks after that run triage and escalate on deltas.

## Preflight

MCP tools are deferred, so load their schemas before calling them. Triage needs
the alerts tool plus `query_range` for the lookback:

```
ToolSearch "select:mcp__datum-infra-prod__victoria-metrics-mcp-server__alerts,mcp__datum-infra-prod__victoria-metrics-mcp-server__query_range"
```

Investigate, or a full pass, also needs Flux, logs, and metrics:

```
ToolSearch "select:mcp__datum-infra-prod__flux-mcp-server__get_kubernetes_resources,mcp__datum-infra-prod__flux-mcp-server__get_kubernetes_logs,mcp__datum-infra-prod__flux-mcp-server__get_kubernetes_metrics"
```

## Shift context: read before the first pass

A patrol that starts cold re-reports what the last engineer already handled,
and mistakes a deliberate quiet for a healthy one. Read all three before the
first pass of a session, and re-read the silences on every pass.

1. **The on-call log.** The issues in `datum-cloud/engineering` labelled
   `:team/oncall` and titled `on-call: week of YYYY-MM-DD`, dated the Tuesday
   the rotation starts and running through the following Monday. Read the
   comments on this week's issue and on last week's: they carry the active
   issues the previous shift handed over. If no issue exists for this week, say
   so and report to the session instead of creating one. The rotation cuts it,
   not the patrol.

   ```sh
   gh issue list -R datum-cloud/engineering --label ':team/oncall' --state all -L 2
   gh issue view <number> -R datum-cloud/engineering --comments
   ```

2. **Open incident issues.** `datum-cloud/engineering`, label
   `:incident/issue`. An alert that belongs to a live incident is already
   owned. It is never a new fault and never escalates.
3. **The active silence list.** See [Silences](#silences).

## Silences

An alert that is firing and silenced is not the same as an alert that is
firing, and a report that does not separate them describes a cleaner production
than the real one. A silence is also the only record that someone already
decided a fire was expected.

Both paths use the script beside this skill, which needs `kubectl`, `curl` and
`jq`, and a production kubectl context in `CONTEXT`:

```sh
SILENCES="${CLAUDE_PLUGIN_ROOT}/skills/warden/scripts/alertmanager-silences"
```

### Read them, every pass

Silences live in Alertmanager, not in vmalert, so the `alerts` feed cannot see
them.

```sh
CONTEXT=<prod-context> "$SILENCES" list
```

The output is one silence per line, tab-separated: id, matchers, end time,
author, comment. A failed port-forward or an unreadable response exits non-zero
with the reason. Treat that as "silences unknown", never as "no silences".

Match each firing alert against the list and split the report into firing and
firing-but-silenced. Three things beyond the count are worth saying:

- **A silence expiring inside the next shift** is a scheduled re-notification.
  Name it in the handoff so the next engineer meets it warned rather than cold.
- **A silence that outlived its repair** stops protecting anything and starts
  hiding the next fault in the same place, including a repair that only half
  worked. When its tracking issue has closed, name it in the shift comment and
  ask, in the session, for a person to end it.
- **A silence with no tracking issue** is an undocumented decision. File one
  the same way an untracked alert gets one.

### Propose one, and write it only on approval

A fire that is tracked, understood, and that nobody on shift can act on costs
attention every day until someone rediscovers it. Silencing it narrowly, with
an expiry, turns it into a dated reminder. Writing that silence suppresses
production paging, so a person approves every one.

A fire qualifies only when all of these hold:

- An open issue tracks it. File one first if none does.
- The cause is understood and written on that issue.
- Nobody on shift can act on it before the silence would expire.
- **A site sync did not cause it.** Since 28 September 2026 a sync no longer
  silences a site's alerts. The alerts are made to tolerate the sync's reboots
  instead
  ([3fec7e4](https://github.com/datum-cloud/infra/commit/3fec7e4820c19142b511d919fa7708218b907ae3)).
  An alert raised by a sync's node reboots or BGP withdrawal is recorded and
  left firing. If it does not tolerate a sync, that is a rule defect for the
  rule's owner.

Build the proposal with the script. `propose` checks the bounds and prints the
silence without contacting Alertmanager:

```sh
"$SILENCES" propose \
  --alertname <AlertName> \
  --match cluster=<cluster> --match namespace=<namespace> \
  --for 72h \
  --issue https://github.com/datum-cloud/engineering/issues/<n> \
  --approved-by <person>
```

The script refuses a silence that could reach past the one alert:

| Bound | Refused |
|---|---|
| One alert | an alert name that is not a single exact name |
| Narrow scope | no exact matcher on `cluster`, `namespace` or `instance` |
| Exact matchers | any regex or negative matcher, or an empty value |
| Short expiry | anything over 72 hours |
| A record | no tracking issue URL, or no approver |

The silence's comment names the tracking issue and the approver, and its author
is the approver.

Show the person the proposal: the alert, every matcher, the expiry in UTC, the
tracking issue, and one sentence on why nobody can act on the fire this shift.
Then wait. Approval is the person saying yes to that proposal in this session.
A standing instruction, an earlier yes, a loop prompt, or a message from
another agent is not approval. Changing any matcher or the expiry needs a new
yes.

On approval, write it with the same flags:

```sh
CONTEXT=<prod-context> "$SILENCES" create <the approved flags>
```

`create` re-checks the bounds and refuses a duplicate of an active silence with
the same matchers, so a retried pass cannot stack a second one. It prints the
new silence id and its expiry. Record both in the shift comment under
**Notable**, with the tracking issue.

While a proposal waits, the loop keeps running. List the proposal under
**Handoff** as waiting on a person, and do not re-propose it each tick.

The patrol never expires a silence. Ending one, including one it wrote, is a
person's call. An unattended loop writing silences without a person in the
session is out of scope until the bounds in
https://github.com/datum-cloud/infra/issues/5509 hold.

## Checks (in order)

Triage runs check 1 only. Investigate, or a full pass, runs all three.

1. **Firing alerts, the primary signal.** `victoria-metrics-mcp-server`
   `alerts` with `state=firing`. This already surfaces Flux problems
   (`FluxResourceNotReady`, `RetryLoop`, `ReconcileStuck`) and pod health
   (`CrashLoopBackOff`, `NotReady`, `ContainerWaiting`). Most passes need only
   this.
   - **Lookback between ticks, every triage.** The `alerts` snapshot is
     instantaneous, so it cannot see an alert that fires, pages, and resolves
     between ticks. Also run `query_range` on `ALERTS{alertstate="firing"}`
     from the previous pass's time to now, step 5m. An alert name firing in
     that window but absent from the current snapshot flapped and resolved.
     Note it under **Notable** and send the flappiness to the rule owner.
     Escalate to investigate if it is on the production control plane or it
     paged. `KarmadaBindingSyncSlow` once spiked p99 to about 2s and paged
     Slack, and every snapshot caught it already resolved.
2. **Flux health.** `flux-mcp-server` `get_kubernetes_resources`. Listing all
   Kustomizations returns more than a million characters and exceeds the token
   limit, so filter by name or namespace, or rely on the alert feed.
3. **Pod and workload health.** Through the alert feed, or a targeted
   `get_kubernetes_resources` by namespace.

To investigate a specific alert, read its `runbook_url`, or the runbooks under
`docs/runbooks/` in `datum-cloud/infra`, such as
`docs/runbooks/flux/resource-retry-loop.md`,
`docs/runbooks/flux/helmrelease-upgrade-stuck.md` and
`docs/runbooks/node-scaleup-quota-blocked.md`.

## Diagnostic shortcuts

Each of these has saved a whole investigation branch. Apply them before
reaching for heavier tools.

- **A large MCP payload goes to a file. Read it with `jq`.** `alerts` and
  `get_kubernetes_resources` routinely exceed the token limit and spill to a
  file. Group firing alerts by `alertname` and filter on
  `cluster=="prod-infrastructure-control-plane"`.
- **The autoscaler will not add a node: read the pod's events, not the quota
  API.** `kubectl describe pod` shows `NotTriggerScaleUp` or `FailedScaleUp`
  with the cause verbatim, for example "max node group size reached" or "GCE
  quota exceeded". The compute quota API is IAM-blocked for the impersonated
  service account. See `docs/runbooks/node-scaleup-quota-blocked.md`.
- **A fix may be committed and not applied.** When a live symptom looks like
  missing config, diff Git against the live object before writing a pull
  request. A stalled HelmRelease can strand a committed value. See
  `docs/runbooks/flux/helmrelease-upgrade-stuck.md`.
- **A quiet `helm --wait` is not a hang.** helm-controller logs nothing per
  resource during `--wait`. Judge progress by whether workloads roll: a new
  ReplicaSet, replica counts moving. Suspect the v1.4.5 hang only when
  workloads are static and the last release log line is ten minutes old or
  more.
- **Production `kubectl` works from the session. `gcloud compute` may not.**
  After a person runs `gcloud auth login`, production `kubectl` reads work from
  the patrol shell. Quota and compute reads that force service-account
  impersonation need a person.
- **A fleet-wide alert storm is often one cause.** Correlated route-loss or
  reconcile alerts across many objects usually trace to one event, such as one
  HTTPRoute deletion or one dependency flap. Look for the common trigger before
  treating each alert as separate.

## Rule hygiene

A firing alert is also a datapoint about the quality of its rule. The `alerts`
output carries the rule's labels and annotations, so these checks cost nothing.
Run them on every triage pass for each new or changed alert.

**Metadata.** A well-formed rule carries the labels `severity`, `team` and
`service`, and the annotations `summary` and `runbook_url`. Flag a firing alert
missing any of them, using the reasons the alert-quality dashboard uses:
`missing_severity`, `missing_service`, `missing_team`, `missing_summary`,
`missing_runbook`. A **critical** alert with no runbook strands the next
responder mid-incident, so surface it first.

**Noise.** These are tuning candidates, not live incidents:

- **Longest-firing.** An alert firing for hours or days is almost never a real
  incident. It is a bad threshold or a missing SLO. Note it and do not
  re-investigate it each pass. Intended heartbeats such as a Watchdog are the
  exception.
- **Flappiest.** Repeated firing and resolving erodes trust. It is a candidate
  for a longer `for` or a better threshold.
- **Noisiest.** The highest firing volume over the window is a candidate for an
  SLO instead of a raw threshold.

The patrol does not tune rules. Hygiene findings go to the rule owner's
repository as an issue, after a duplicate check there, and stay out of the
shift comment. The one exception is a **critical** alert with no runbook, which
earns one line in the handoff.

The full standard is `docs/telemetry/alerting-standards.md` in
`datum-cloud/infra`.

## Untracked alerts

The rotation's rule is that an alert nobody tracks gets an issue, so the next
engineer on shift meets a known thing rather than a fresh mystery.

**Check for a duplicate first.** Search the open issues labelled
`:infra/monitoring`, and list the recent ones too, because a symptom-word
search misses more than it finds:

```sh
gh issue list -R datum-cloud/engineering --label ':infra/monitoring' --search '<alert or cause>'
gh issue list -R datum-cloud/engineering --label ':infra/monitoring' -L 30
```

**Then file one** in `datum-cloud/engineering` with the `:infra/monitoring`
label, following the `datum-platform:pr-conventions` bar. File one issue per
failure class, never one per alert name: six alert names from one cause share
an issue. End the body with the line `Filed by the warden patrol.` so a later
pass can tell the patrol's issues from a person's. Link the issue from the
shift comment.

## Escalation: diagnose, then fix

A patrol that only writes things down leaves every fault for a person. When it
finds a fault that is **new to this shift**, it spawns a diagnostic agent, and
when that agent returns a bounded cause, it spawns a fixer that opens a pull
request. The record comes first. The agents are what happens after it, not
instead of it.

### What qualifies

Spawn a diagnostic only for a fault that is all of these:

- **New this patrol.** Not already in the shift comment, and not a recurrence
  of something in the known-flappy set.
- **On `prod-infrastructure-control-plane`.**
- **Not silenced.** A live silence is somebody's decision that the fire is
  expected. Read the silence and its tracking issue instead.
- **Not part of an incident.** An alert belonging to an open `:incident/issue`
  is owned by whoever is running that incident.
- **Untracked.** No open issue covers it. Search before spawning.
- **A fault.** A rule-quality note goes to the rule owner and stops there.

An alert whose ratio or window is still draining after a known event, such as a
release rollout or a node roll, is not new. Wait for it to clear before
treating it as a fault.

### Diagnostic agent

One agent per fault: read-only, opus. It writes no code, changes nothing, and
posts nothing to GitHub. Brief it to return:

1. The cause, stated so it explains why the broken cases broke **and** why the
   working cases worked. "Consistent with the facts" is not a cause.
2. The evidence, each claim pinned to the state it was read at: a live object,
   a revision, a render.
3. Which repository owns the fix, against the ownership boundary in
   `datum-cloud/infra`'s `CLAUDE.md`. A component's own behavior is fixed in
   the component's repository, never in infra.
4. Whether an open pull request already touches the files a fix would change.
5. A verdict: **simple**, **complex**, or **not ours**.

### The simple bar

A fault is simple only when every one of these holds. Any miss makes it
complex.

- The cause is named and confirmed, not inferred.
- The fix is configuration or a manifest, in two files or fewer.
- `datum-cloud/infra` owns it.
- It lands in a staging overlay, or in environment-scoped config that never
  reaches a shared base. Anything that needs a base promotion is complex,
  because promotion wants a staging soak first.
- No open pull request touches those files.
- It needs no secret, no cluster change, no Pulumi, and no Flux reconcile.
- Reverting it is a revert, not a rebuild.

### What happens next

**Simple.** File the issue, then spawn one fixer (sonnet,
`isolation: "worktree"`, in a `datum-cloud/infra` checkout) to open a **draft**
pull request: signed commits, the `datum-platform:pr-conventions` bar on the
body, the validators the touched paths map to, and `Fixes #<issue>`. Hand the
pull request to the `datum-platform:pr-review-loop` skill. Do not mark it
ready, do not merge it, and do not request a human reviewer from inside the
patrol.

**Complex or not ours.** File the issue with the diagnosis on the owning
repository, and stop. Say in the patrol report that it needs a person.

### Limits

- At most two diagnostics and one fixer in flight per tick. A fault that misses
  the cut waits for the next tick.
- Never spawn a second agent for a fault already being diagnosed. Carry the
  in-flight set in the loop context with the firing set.
- A fixer that finds the premise wrong stops and reports. It does not widen
  scope to whatever it found instead.

Record the outcome in the shift comment: the verdict, and the issue and pull
request numbers.

## Suspected incidents

The patrol never declares an incident. Declaring one calls people away from
their work, and that decision belongs to a person.

When a fault looks like customer impact, or a fault is spreading rather than
holding, prepare the draft and stop:

- Draft the body from the
  [Incident Response template](https://github.com/datum-cloud/engineering/blob/main/.github/ISSUE_TEMPLATE/incident-response.yml)
  in `datum-cloud/engineering`: a title of the form `[INCIDENT] <summary>`,
  the incident checklist unticked, the description, a plain-text copy of the
  alert, the timeline, and what still needs a decision.
- Write the timeline in **UTC**, one line per event in the template's form,
  `* 2026/10/10 14:05 UTC - <event>`, each pinned to the state it was read at:
  the first alert firing, the first symptom seen, any release or reconcile in
  the window, and every check the patrol ran.
- State plainly what is known and what is not. An unverified cause in an
  incident draft costs the responder the time it takes to disprove it.
- Hand the draft to the session and say it is waiting. Declaring means filing
  it with the `:incident/issue` label and taking ownership, so the patrol does
  not file it.

Then stop. Do not page, open a Slack channel, or address anyone.

## Issue hygiene: close what the patrol filed

A tracker that outlives its fault costs the next reader real time: they open
it, re-read a symptom that no longer exists, and check the cluster to find out.

On every pass, for each alert that moved to **Cleared**, check its tracking
issue.

### Which issues the patrol may close

Only an issue the patrol filed. Both must hold:

- Its author is the account the session runs as (`gh api user -q .login`).
- Its body ends with `Filed by the warden patrol.`

Any other issue is a person's to close, including one the same account filed by
hand. Surface it in the session with the evidence and leave it open.

### Before closing

- **The alert is gone, not between evaluations.** Confirm absence over a window
  longer than the rule's own `for`: an hour of quiet or two consecutive passes,
  whichever is longer. One empty snapshot is not absence.
- **The fix is where the fault was.** A merge to `main` in `datum-cloud/infra`
  moves staging only. Production tracks a semver tag, so a production fault
  stays open until a release carrying the fix exists and production runs it.
- **The hole is closed too.** When the symptom cleared but whatever let it
  happen is still open, link the follow-up before closing, or leave the issue
  open and say why.

### Closing

Close as completed, with a comment carrying the evidence: what fixed it, which
release, when the alert stopped, and how long it has been quiet. Say so plainly
when the fix took a different shape than the issue proposed.

### Leave open

- **An issue broader than the alert that cleared.** One cleared symptom out of
  several gets a comment, not a closure.
- **An issue whose fault is suppressed rather than fixed**, by a silence, a
  paused rule, or a scaled-down workload.

### Stale citations

A handoff pointing at a closed tracker is worse than one pointing at nothing,
because it reads as covered. When a pass cites a tracker, confirm it is still
open. When it closed under the fault, say so in the shift comment and find or
file the live one. The same goes for a silence whose tracker closed: until a
person ends it, it hides the next fault in that place.

Record every closure in the shift comment under **Issues and PRs touched**.

## Report: the weekly on-call log

The patrol keeps **one comment** on the current week's on-call log, **edited in
place** for the whole session. The next engineer reads the log before their
shift, and a running transcript buries the handoff they came for.

Write it the way the rotation writes it, a few bullets short enough to skim:

- **Notable**: what fired, what was acknowledged, what escalated, and what was
  silenced, by whom and until when. Keep firing and firing-but-silenced apart.
  They read alike and mean different things.
- **Issues and PRs touched**: opened, closed, or moved, each by link. The
  diagnostic and fixer outcomes land here.
- **Handoff**: what the next engineer inherits. Faults still open, diagnostics
  in flight, silences expiring inside their shift, silences whose tracker has
  closed, and anything waiting on a person, including silence proposals and
  incident drafts.

Post the first version once the session's first pass finds something worth
saying, then edit that comment as the loop learns more:

```sh
gh issue comment <log> -R datum-cloud/engineering --body-file shift.md
gh api --method PATCH repos/datum-cloud/engineering/issues/comments/<id> -F body=@shift.md
```

A session that stays green throughout posts nothing. An empty shift comment is
noise in the one place that has to stay skimmable.

At week turnover the rotation cuts the new log issue. The patrol starts a fresh
comment there and leaves the old one alone.

## Loop

- "Walk the beat" always means run on a loop. Use `ScheduleWakeup`.
- The idle cadence is about 25 minutes. Tighten it when something is found,
  and relax it when green. Slow to about 30 minutes when blocked on an
  external dependency, such as a quota grant or a person's action.
- **After a release.** When a new revision reconciles onto production, drop to
  about 5 minutes for the next 30 minutes, then relax. Releases surface
  transient regressions, such as webhook blips, flapping reconciles and
  recording-rule breakage, that a 25-minute tick would miss.
- **The first pass of a session** is a full pass, to set the baseline firing
  set. **Every tick after that is triage**, escalating to investigate only for
  new, changed, or flapped alerts. Most ticks load only the alerts and
  `query_range` tools and emit one line.
- Carry the previous pass's firing set, the active silence set, the pending
  silence proposals, the in-flight agents, and the shift comment's id in the
  loop context. Keep no persistent copy.
- Each wake: re-read the silences, run triage, edit the shift comment on any
  change, escalate any new fault, close what the patrol filed and is fixed,
  report only anomalies, then schedule the next wake.

## Known-flappy set

Confirm these are still benign. Do not deep-dive them each pass:

- `KarmadaBindingSyncSlow`
- `EnvoyService5xxErrors`
- `EnvoyGatewayNoRoute`, from edge deletion noise
- Sentry `ContainerMemoryNearLimit`

A name joins or leaves this set through a pull request on
`datum-cloud/claude-code-plugins`. A pattern that spans weeks and is not a
flappy alert belongs in an issue on the owning repository, not in this skill.
