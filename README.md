# My Skills

A collection of custom skills for Claude Code.

## What are Skills?

Skills are reusable prompts and workflows that extend Claude Code's capabilities. Each skill is defined in a `SKILL.md` file within its own directory.

## Directory Structure

- `claude-skills/` - Skills for Claude (claude.ai)
- `claude-code-skills/` - Skills for Claude Code

## Available Skills

### Claude Skills

| Skill | Description |
|-------|-------------|
| [travel-assistant](./claude-skills/travel-assistant/SKILL.md) | Travel assistant for searching flights and hotels |

### Claude Code Skills

| Skill | Description |
|-------|-------------|
| [ci-fixer](./claude-code-skills/ci-fixer/SKILL.md) | Fix failing CI tests on PRs and monitor until all checks pass |
| [commit](./claude-code-skills/commit/SKILL.md) | Create atomic commits with clear, descriptive messages following WordPress core style |
| [wp-cli](./claude-code-skills/wp-cli/SKILL.md) | Manage WordPress installations using WP-CLI commands |

## Installation

Use the included installer script to add skills to Claude Code or Claude Desktop.

### Quick Start

```bash
# List available skills
./install-skill.sh --list

# Install a skill to Claude Code (creates symlink)
./install-skill.sh travel-assistant

# Install to Claude Desktop (creates ZIP in ~/Downloads)
./install-skill.sh travel-assistant --target desktop

# Install to both
./install-skill.sh travel-assistant --target both
```

### Options

```bash
# Installation methods for Claude Code
./install-skill.sh travel-assistant --method symlink  # Default - links to repo
./install-skill.sh travel-assistant --method copy     # Copies files

# Install multiple skills with wildcard
./install-skill.sh "travel-*"

# Install all skills
./install-skill.sh --all

# Uninstall a skill
./install-skill.sh travel-assistant --uninstall

# Force overwrite without prompting
./install-skill.sh travel-assistant --force
```

### Claude Code Installation

Skills are installed to `~/.claude/skills/<skill-name>/`. The default symlink method keeps skills linked to the repository, so updates are automatic. Use `--method copy` if you prefer a standalone copy.

### Claude Desktop Installation

The script creates a ZIP file in `~/Downloads/` which you can upload via:
1. Open Claude Desktop
2. Go to Settings > Capabilities > Skills
3. Click "Upload skill"
4. Select the generated ZIP file

## Usage

Skills in this repository can be installed and used with Claude Code to provide specialized assistance for various tasks.

## Contributing

To add a new skill:
1. Create a new directory with the skill name
2. Add a `SKILL.md` file with the skill definition
3. Open a PR with your new skill
