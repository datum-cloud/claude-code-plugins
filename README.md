# Claude Code Plugin Marketplace

A marketplace for Claude Code plugins providing platform engineering tools and automation. This repository hosts multiple plugins that can be installed individually or as a collection.

## Available Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [datum-cloud](./plugins/datum-cloud/) | Kubernetes-based cloud infrastructure development automation | 1.0.0 |

## Installation

### Adding the Marketplace

Add this marketplace to your Claude Code configuration:

```bash
# In Claude Code:
/plugin marketplace add https://github.com/datum-cloud/claude-code-marketplace
```

Or add to your `.claude/settings.json`:

```json
{
  "marketplaces": [
    {
      "name": "datum-cloud-marketplace",
      "url": "https://github.com/datum-cloud/claude-code-marketplace"
    }
  ]
}
```

### Installing a Plugin

Once the marketplace is added, install plugins by name:

```bash
/plugin install datum-cloud@claude-code-plugins
```

### Local Development

For local development, run Claude Code with the plugin directory:

```bash
claude --plugin-dir /path/to/claude-code-marketplace/plugins/datum-cloud
```

## Marketplace Structure

```
claude-code-plugins/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog
├── plugins/
│   └── datum-cloud/            # Individual plugin
│       ├── .claude-plugin/
│       │   └── plugin.json     # Plugin manifest
│       ├── .mcp.json           # MCP server configuration
│       ├── agents/             # Specialized agents
│       ├── skills/             # Knowledge modules
│       ├── commands/           # Slash commands
│       ├── hooks/              # Automation hooks
│       └── scripts/            # Utility scripts
└── README.md
```

## Plugins

### datum-cloud

Kubernetes-based cloud infrastructure development automation with specialized agents, skills, and pipeline orchestration for the Datum Cloud platform.

**Features:**
- 10 specialized agents (api-dev, frontend-dev, sre, test-engineer, code-reviewer, tech-writer, product-discovery, commercial-strategist, gtm-comms, support-triage)
- 17+ skill modules covering Kubernetes patterns, Go conventions, deployment workflows
- Pipeline orchestration for structured feature development
- Automatic learning engine for pattern extraction
- MCP integration for kubectl and GitHub CLI

**Category:** Platform Engineering
**Tags:** kubernetes, go, infrastructure, multi-tenant

[View full documentation](./plugins/datum-cloud/)

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
     "repository": "https://github.com/datum-cloud/claude-code-marketplace",
     "license": "MIT",
     "keywords": ["your", "keywords"]
   }
   ```

3. Add your plugin components:
   - `agents/` - Agent definitions (markdown files)
   - `skills/` - Knowledge modules
   - `commands/` - Slash commands
   - `hooks/` - Automation hooks
   - `.mcp.json` - MCP server configuration (optional)

4. Register your plugin in `.claude-plugin/marketplace.json`:
   ```json
   {
     "name": "your-plugin-name",
     "source": "./your-plugin-name",
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

## License

MIT
