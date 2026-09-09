# Claude Code Plugin Marketplace

A marketplace for Claude Code plugins providing platform engineering tools and automation. This repository hosts multiple plugins that can be installed individually or as a collection.

## Available Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [datum-platform](./plugins/datum-platform/) | Kubernetes platform engineering automation with aggregated API servers, controller patterns, and GitOps deployment | 1.14.0 |
| [datum-gtm](./plugins/datum-gtm/) | Go-to-market automation with commercial strategy, product discovery, and customer support | 1.1.1 |
| [milo-activity](./plugins/milo-activity/) | Query audit logs, investigate incidents, and author ActivityPolicies using the Milo Activity service | 1.0.0 |

## Installation

### Adding the Marketplace

Add this marketplace to Claude Code:

```bash
# In Claude Code:
/plugin marketplace add datum-cloud/claude-code-plugins
```

Or configure it in your project's `.claude/settings.json` to prompt team members to install the marketplace when they trust the project folder:

```json
{
  "extraKnownMarketplaces": {
    "datum-claude-code-plugins": {
      "source": {
        "source": "github",
        "repo": "datum-cloud/claude-code-plugins"
      }
    }
  }
}
```

You can also pre-enable specific plugins:

```json
{
  "extraKnownMarketplaces": {
    "datum-claude-code-plugins": {
      "source": {
        "source": "github",
        "repo": "datum-cloud/claude-code-plugins"
      }
    }
  },
  "enabledPlugins": {
    "datum-platform@datum-claude-code-plugins": true,
    "datum-gtm@datum-claude-code-plugins": true
  }
}
```

### Installing a Plugin

Once the marketplace is added, install plugins by name:

```bash
/plugin install datum-platform@datum-claude-code-plugins
/plugin install datum-gtm@datum-claude-code-plugins
/plugin install milo-activity@datum-claude-code-plugins
```

> [!IMPORTANT]
> Install at **user** scope. A project-scoped install binds the plugin to the
> directory you installed it from, and that record then suppresses the
> auto-install in every other repo — the plugin stays enabled in settings and
> listed by `claude plugin list`, but its skills never load. The failure is
> silent.

```bash
claude plugin install datum-platform@datum-claude-code-plugins --scope user
```

The CLI defaults to user scope; the interactive `/plugin` flow asks, so choose
user there.

### Already broken?

If a repo's `CLAUDE.md` references a plugin skill that isn't available to you,
re-pin at user scope:

```bash
claude plugin install datum-platform@datum-claude-code-plugins --scope user
```

That is sufficient on its own — leave any existing project-scoped entry alone.
Removing it with `claude plugin uninstall --scope project` also strips the
plugin from that repo's tracked `.claude/settings.json`, which breaks the
declaration for everyone else.

Confirm with `claude plugin list` (expect `Scope: user`).

### Local Development

For local development, add the marketplace from your local directory:

```bash
# In Claude Code:
/plugin marketplace add ./path/to/claude-code-plugins
/plugin install datum-platform@datum-claude-code-plugins
```

### Validation

Validate the marketplace before distribution:

```bash
# From the command line:
claude plugin validate .

# Or from within Claude Code:
/plugin validate .
```

## Marketplace Structure

```
claude-code-plugins/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog
├── plugins/
│   ├── datum-platform/         # Platform engineering plugin
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json     # Plugin manifest
│   │   ├── agents/             # Specialized agents
│   │   ├── skills/             # Knowledge modules
│   │   ├── commands/           # Slash commands
│   │   ├── hooks/              # Automation hooks
│   │   └── scripts/            # Utility scripts
│   ├── datum-gtm/              # Go-to-market plugin
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json     # Plugin manifest
│   │   ├── agents/             # Specialized agents
│   │   ├── skills/             # Knowledge modules
│   │   └── commands/           # Slash commands
│   └── milo-activity/          # Activity service plugin
│       ├── .claude-plugin/
│       │   └── plugin.json     # Plugin manifest
│       ├── agents/             # Investigation & authoring agents
│       └── skills/             # Activity workflows & CEL reference
└── README.md
```

## Plugins

### datum-platform

Kubernetes platform engineering automation with aggregated API servers, controller patterns, and GitOps deployment for the Datum Cloud platform.

**Features:**
- 11 specialized agents (plan, api-dev, frontend-dev, sre, test-engineer, code-reviewer, tech-writer, operational-reviewer, pr-adversary, pr-conventions-reviewer, pr-review-fixer)
- 34 skill modules covering Kubernetes patterns, Go conventions, clear writing, deployment workflows, and more
- Pipeline orchestration for structured feature development
- Automatic learning engine for pattern extraction
- A model tier per agent, matched to the design risk of its work rather than to its importance, with an escalation path when a cheaper agent meets a decision above its tier
- A PR/issue body gate that blocks a `gh` post when it misses the writing bar
- A two-reviewer loop (`/pr-review`) that runs an adversarial and a conventions review on every PR a session opens, then fixes, pushes, re-reviews, and sets auto-merge when the two agree. Skill-driven, no automatic trigger yet. A guard hook refuses GitHub writes, git mutations, cluster changes, and shell wrappers for the reviewer agents as a backstop against an accidental write, not a control. Name a human reviewer under `prReview.humanReviewer` in the repository's `.claude/settings.json`; absent means code owners only

**Category:** Platform Engineering
**Tags:** kubernetes, go, infrastructure, multi-tenant, devops

### datum-gtm

Go-to-market automation with commercial strategy, product discovery, and customer support tools.

**Features:**
- 4 specialized agents (product-discovery, commercial-strategist, gtm-comms, support-triage)
- 4 skill modules for GTM workflows
- Commercial strategy and pricing analysis
- Customer support triage automation

**Category:** Business
**Tags:** gtm, marketing, product, support, commercial

### milo-activity

Query audit logs, investigate incidents, and author ActivityPolicies using the Milo Activity service. Wraps the Activity MCP server with higher-level skills and agents that teach Claude how to use Activity for incident investigation, change auditing, and policy authoring.

**Features:**
- 2 specialized agents (incident-investigator for read-only investigation, policy-author for interactive policy creation)
- 7 skills covering incident investigation, user auditing, policy authoring, policy preview, activity summaries, and slash commands
- CEL expression reference for ActivityPolicy rules
- Token-efficient design with forked agents for investigation and inline skills for interactive authoring

**Prerequisites:** The `activity` binary must be on your PATH and configured as an MCP server separately.

**Category:** Observability
**Tags:** kubernetes, audit, activity, incident, observability, milo, cel

## Contributing

### Adding a New Plugin

1. Create a directory under `plugins/`:
   ```bash
   mkdir -p plugins/your-plugin-name/.claude-plugin
   ```

2. Create the plugin manifest at `plugins/your-plugin-name/.claude-plugin/plugin.json`:
   ```json
   {
     "name": "your-plugin-name",
     "description": "Description of your plugin",
     "version": "1.0.0",
     "author": {
       "name": "Your Name",
       "url": "https://github.com/your-org"
     },
     "repository": "https://github.com/datum-cloud/claude-code-plugins",
     "license": "MIT",
     "keywords": ["your", "keywords"]
   }
   ```

3. Add your plugin components:
   - `agents/` - Agent definitions (markdown files)
   - `skills/` - Knowledge modules
   - `commands/` - Slash commands
   - `hooks/` - Automation hooks

4. Register your plugin in `.claude-plugin/marketplace.json`:
   ```json
   {
     "name": "your-plugin-name",
     "source": "./plugins/your-plugin-name",
     "description": "Description of your plugin",
     "version": "1.0.0",
     "category": "your-category",
     "tags": ["tag1", "tag2"]
   }
   ```

5. Submit a pull request.

### Plugin Guidelines

- Each plugin should be self-contained within its directory
- Use `${CLAUDE_PLUGIN_ROOT}` for path references in hooks and scripts
- Include a README in your plugin directory with usage documentation
- Follow semantic versioning for plugin versions
- Test your plugin locally before submitting

For detailed guidance on plugin development, see the [official Claude Code documentation](https://code.claude.com/docs/en/plugins).

## Documentation

- [Create plugins](https://code.claude.com/docs/en/plugins) - Guide to creating plugins with commands, agents, hooks, MCP servers, and more
- [Discover and install plugins](https://code.claude.com/docs/en/discover-plugins) - Installing plugins from marketplaces
- [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) - Creating and distributing plugin marketplaces
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference) - Complete technical specifications and schemas
- [Plugin settings](https://code.claude.com/docs/en/settings#plugin-settings) - Configuration options

## License

MIT
