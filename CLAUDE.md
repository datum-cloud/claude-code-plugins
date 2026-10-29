# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the public Claude Code plugin marketplace for people using Datum Cloud.
Each plugin helps Claude work with one Datum Cloud product.

Plugins for people building and running Datum Cloud (platform engineering,
go-to-market) do not belong here. They live in the internal marketplace in
datum-cloud/infra.

- **milo-activity** (from milo-os/activity): query audit logs, investigate incidents, and author ActivityPolicies
- **milo-observe** (from milo-os/telemetry): query logs, export metrics, and read resource status metrics

## Validation Commands

```bash
# Validate marketplace and plugin structure
claude plugin validate .
```

`validate` only reads files in this repository. A plugin listed with a remote
source (`github`, `git-subdir`) is only fetched at install, so install it once
to check a new entry.

## Repository Structure

```
.claude-plugin/
  marketplace.json          # Marketplace catalog listing plugins
                            # (milo-activity is listed from milo-os/activity,
                            # milo-observe from milo-os/telemetry)

claude-desktop/             # datumctl sign-in helper for Claude Desktop
```

## Adding a Plugin

A product plugin can live in this repository under `plugins/`, or in the
product's own repository in a top-level `claude-plugin/` folder, listed here
with a `git-subdir` source:

```json
{
  "name": "datum-dns",
  "source": {
    "source": "git-subdir",
    "url": "https://github.com/datum-cloud/dns-operator.git",
    "path": "claude-plugin"
  }
}
```

- Keep the entry `name` equal to the `name` in the plugin's `plugin.json`, or installs fail.
- Use `${CLAUDE_PLUGIN_ROOT}` for paths in hooks and scripts.
- Never change a published plugin's `name`. To retire one, remove its entry and map its name to `null` in `renames`; never edit an existing `renames` entry.

## Versioning and Releases

Set `version` in the plugin's `plugin.json` only, not in its marketplace entry.
Users get an update only when that version changes.

- **Patch** (1.0.x): Bug fixes, typo corrections, minor documentation fixes
- **Minor** (1.x.0): New features, new skills, new agents, significant documentation additions
- **Major** (x.0.0): Breaking changes, major restructuring

### Changelog

Maintain `CHANGELOG.md` at the repo root. For each release:
- Use format `## [X.Y.Z] - YYYY-MM-DD`
- Keep entries concise and user-focused (what value does this provide?)
- Avoid implementation details - focus on capabilities added

### Release Checklist

1. Bump version in the plugin's `plugin.json`
2. Add entry to `CHANGELOG.md` with date
3. Update the version in the `README.md` table
4. Commit with conventional commit message: `feat(plugin-name): description`
5. Merge to main (plugins update from the main branch)
