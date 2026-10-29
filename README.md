# Datum Cloud plugins for Claude Code

Claude Code plugins for working with Datum Cloud products. Add this marketplace
once, then turn on the plugins for the products you use. Each plugin gives
Claude the agents and skills to work with that product.

## Available plugins

| Plugin | What it does | Version |
|--------|--------------|---------|
| [datum-networking](https://github.com/datum-cloud/network-services-operator/tree/main/claude-plugin) | Create and troubleshoot Datum Cloud load balancers, hostnames, domains and networks | 0.1.0 |
| [milo-activity](./plugins/milo-activity/) | Query audit logs, investigate incidents, and author ActivityPolicies using the Milo Activity service | 1.0.0 |

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

### datum-networking

Create and troubleshoot Datum Cloud Application Load Balancers, the hostnames
and domains in front of them, and the networks and network services behind
them. It uses the same diagnosis and procedures as Datum's own assistant, and
ships from the network-services-operator repository.

- `site-triage` agent for "why isn't my site up?", read-only
- 17 procedures for creating load balancers and networks, and for hostnames,
  domain verification, DNS, certificates, origins, the WAF and access logs
- 5 datumctl how-tos: load balancers, HTTPRoutes, client traffic policies,
  domains and networks

**Prerequisites:** install datum-mcp (`brew install datum-cloud/tap/datum-mcp`).
The plugin starts it for you.

### milo-activity

Query audit logs, investigate incidents, and author ActivityPolicies using the
Milo Activity service. Wraps the Activity MCP server with skills and agents
that teach Claude how to use Activity for incident investigation, change
auditing, and policy authoring.

- 2 agents: incident-investigator for read-only investigation, policy-author
  for interactive policy creation
- 7 skills covering incident investigation, user auditing, policy authoring,
  policy preview, activity summaries, and slash commands
- CEL expression reference for ActivityPolicy rules

**Prerequisites:** the `activity` binary must be on your PATH and configured
as an MCP server separately.

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
