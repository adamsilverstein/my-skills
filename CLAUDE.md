# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of custom skills for Claude Code. Skills are reusable prompts and workflows that extend Claude Code's capabilities, each defined in a `SKILL.md` file within its own directory.

## Directory Structure

- `claude-skills/` - Skills for Claude (claude.ai)
- `claude-code-skills/` - Skills for Claude Code (planned)

## Skill File Format

Skills are defined using a `SKILL.md` file with YAML frontmatter:

```markdown
---
name: skill-name
description: "Description of when to use this skill and trigger phrases"
---

# Skill content and instructions
```

## Adding New Skills

1. Create a new directory under `claude-skills/` or `claude-code-skills/`
2. Add a `SKILL.md` file with frontmatter (name, description) and skill content
3. Update README.md to include the new skill in the Available Skills table
