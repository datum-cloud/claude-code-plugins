# Datum Cloud plugins for Claude Code

Claude Code plugins for working with Datum Cloud products. Add this marketplace
once, then turn on the plugins for the products you use. Each plugin gives
Claude the agents and skills to work with that product.

## Available plugins

| Plugin | What it does | Version |
|--------|--------------|---------|
| [milo-activity](https://github.com/milo-os/activity/tree/main/claude-plugin) | Query audit logs, investigate incidents, and author ActivityPolicies using the Milo Activity service | 1.1.1 |
| [milo-observe](https://github.com/milo-os/telemetry/tree/main/claude-plugin) | Query project logs, export metrics to Grafana Cloud, and read the status metrics Datum publishes for your resources | 0.1.0 |

## Install

Add the marketplace, then install the plugins you want:

```bash
claude plugin marketplace add datum-cloud/claude-code-plugins
claude plugin install milo-activity@datum-claude-code-plugins
```

Inside a session, `/plugin marketplace add datum-cloud/claude-code-plugins`
does the same, and `/plugin` lets you browse and install.

Install at **user** scope, which the CLI does by default. A project-scoped
install binds the plugin to the directory you installed it from, and that
record then stops it loading in other repositories without any error.

### Stay up to date

Auto-update is off for third-party marketplaces until you turn it on. Open
`/plugin`, go to **Marketplaces**, select `datum-claude-code-plugins`, and
choose **Enable auto-update**. Without it, run
`claude plugin marketplace update datum-claude-code-plugins` to pick up new
versions.

## Plugins

### milo-activity

Query audit logs, investigate incidents, and author ActivityPolicies using the
Milo Activity service. Wraps the Activity MCP server with skills and agents
that teach Claude how to use Activity for incident investigation, change
auditing, and policy authoring. The plugin lives in
[milo-os/activity](https://github.com/milo-os/activity/tree/main/claude-plugin),
next to the Activity service it describes.

- 2 agents: incident-investigator for read-only investigation, policy-author
  for interactive policy creation
- 7 skills covering incident investigation, user auditing, policy authoring,
  policy preview, activity summaries, and slash commands
- CEL expression reference for ActivityPolicy rules

**Prerequisites:** the `activity` binary must be on your PATH and configured
as an MCP server separately.

### milo-observe

Query your project's logs, send its metrics to Grafana Cloud or any Prometheus
remote-write endpoint, and read the status metrics Datum publishes for every
resource. The plugin lives in
[milo-os/telemetry](https://github.com/milo-os/telemetry/tree/main/claude-plugin),
next to the telemetry service it describes.

- `query-logs`: search, tail and filter logs, including load balancer access
  logs, with `datumctl telemetry`
- `export-metrics`: set up and check an ExportPolicy
- `status-metrics`: find resources that aren't ready and write alerts from the
  `_info` and `_status_condition` series, with a catalog of every family

**Prerequisites:** `datumctl`, signed in, and the telemetry plugin
(`datumctl plugin install telemetry`) for logs.

## Claude Desktop

[claude-desktop/](./claude-desktop/) holds a helper that signs Claude Desktop
in with your `datumctl` login.

## Moved: datum-platform and datum-gtm

The platform engineering and go-to-market plugins were for people building
Datum Cloud, so they moved to an internal marketplace. If you had them
installed from here, Claude Code drops them from your settings and shows
"Removed from the marketplace" once. Datum employees can find the setup steps
in the internal plugins README.

## Contributing

See [CLAUDE.md](./CLAUDE.md) for how plugins in this repository are
structured, versioned and released. Validate before opening a pull request:

```bash
claude plugin validate .
```

For plugin development in general, see the
[Claude Code plugin documentation](https://code.claude.com/docs/en/plugins).

## License

MIT
