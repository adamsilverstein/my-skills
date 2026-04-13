---
name: wp-cli
description: "Run WP-CLI commands to manage WordPress installations. Use when the user wants to manage WordPress via the command line, run wp commands, manage plugins, themes, users, databases, options, cron, rewrite rules, or perform any WordPress administration task using WP-CLI. Triggers include requests like 'run wp-cli', 'manage WordPress', 'install a plugin', 'update WordPress', 'create a user', 'search-replace in the database', 'export the database', or any WP-CLI task."
---

# WP-CLI Skill

Manage WordPress installations using WP-CLI: core, plugins, themes, users, database, options, cron, and more.

## Prerequisites

- `wp` installed and on PATH; run from the WordPress root or pass `--path=<path>`
- `wp doctor` requires WP-CLI v2.12+ and the separate `wp-cli/doctor-command` package:
  `wp package install wp-cli/doctor-command:@stable`
- `wp maintenance-mode` is bundled with WP-CLI (no extra package needed)

## Core

```bash
wp --version
wp core version
wp core is-installed
wp core check-update
wp core update && wp core update-db
wp core verify-checksums

# Install fresh (prompts avoid leaking secrets to shell history)
wp core download
wp config create --dbname=wordpress --dbuser=root --dbhost=localhost --prompt=dbpass
wp core install --url=example.com --title="Site" --admin_user=admin --admin_email=admin@example.com --prompt=admin_password
```

## Plugins & Themes

```bash
wp plugin list [--status=active] [--update=available]
wp plugin install <slug> --activate
wp plugin activate|deactivate <name>
wp plugin update --all
wp plugin verify-checksums --all

wp theme list
wp theme install <slug> --activate
wp theme update --all
```

## Users

```bash
wp user list [--role=administrator]
wp user create <username> <email> --role=<role> --user_pass=<password>
wp user update <id> --role=editor --display_name="Name"
wp user update <id> --user_pass=<new-password>
wp user delete <id> --reassign=<other-id>
```

## Database

```bash
wp db export backup.sql
wp db import backup.sql
wp db query "SELECT option_value FROM wp_options WHERE option_name='siteurl';"
wp db optimize
wp db repair

# Always --dry-run first
wp search-replace 'old' 'new' --dry-run
wp search-replace 'old' 'new' --precise --recurse-objects --all-tables
```

## Options, Cache, Rewrites

```bash
wp option get|update|delete <name> [value]
wp option list --search="*cache*"
wp cache flush
wp transient delete --all
wp rewrite flush
wp rewrite structure '/%postname%/'
```

## Cron

```bash
wp cron event list
wp cron event run --due-now
wp cron event run <hook-name>
wp cron test
```

## Posts & Media

```bash
wp post list --post_type=post --post_status=publish
wp post create --post_title='Title' --post_content='Body' --post_status=publish
wp post delete <id> --force
wp post generate --count=10

wp media regenerate --yes
wp media import <url-or-path>
```

## Maintenance & Troubleshooting

```bash
wp maintenance-mode activate|deactivate|status
wp doctor check --all            # requires wp-cli/doctor-command package
wp shell
wp eval 'echo PHP_VERSION;'
wp config get|list
```

## Multisite

```bash
wp site list
wp site create --slug=<slug> --title="Title"
wp site list --field=url | xargs -I {} wp option get blogname --url={}
```

## Rules

- Always `--dry-run` `search-replace` first, and `wp db export` before destructive changes
- Use `--prompt=<arg>` for passwords and secrets — never inline them on the command line
- Confirm destructive actions (`--yes`, `delete --force`, `plugin deactivate --all`) with the user first
- `--format=json` for machine output, `--fields=<cols>` to trim columns

## Common Workflows

```bash
# Domain migration
wp db export pre-migration.sql
wp search-replace 'https://old.com' 'https://new.com' --dry-run
wp search-replace 'https://old.com' 'https://new.com' --precise --recurse-objects --all-tables
wp cache flush && wp rewrite flush

# Update everything
wp core update && wp core update-db
wp plugin update --all
wp theme update --all
wp cache flush

# Bisect a broken site
wp core verify-checksums
wp plugin deactivate --all
# Re-activate one by one to find the culprit
wp plugin activate <name>
```
