---
name: wp-cli
description: "Run WP-CLI commands to manage WordPress installations. Use when the user wants to manage WordPress via the command line, run wp commands, manage plugins, themes, users, databases, options, cron, rewrite rules, or perform any WordPress administration task using WP-CLI. Triggers include requests like 'run wp-cli', 'manage WordPress', 'install a plugin', 'update WordPress', 'create a user', 'search-replace in the database', 'export the database', or any WP-CLI task."
---

# WP-CLI Skill

Manage WordPress installations using WP-CLI: core, plugins, themes, users, database, options, cron, and more.

## Prerequisites

- `wp` installed and on PATH; run from the WordPress root or pass `--path=<path>`
- `wp doctor` needs the separate `wp-cli/doctor-command` package:
  `wp package install wp-cli/doctor-command:@stable`
  Composer resolves `@stable` against the installed WP-CLI. If it reports a version
  conflict, check `wp --version` and pin an exact release that supports it instead
- `wp maintenance-mode` is bundled with WP-CLI (no extra package needed)

## Core

```bash
wp --version
wp core version
wp core is-installed
wp core check-update
wp core update && wp core update-db      # add --network to update-db on multisite
wp core verify-checksums

# Install fresh. --prompt keeps secrets out of shell history, but it reads from stdin
# and blocks forever without a terminal
wp core download
wp config create --dbname=wordpress --dbuser=root --dbhost=localhost --prompt=dbpass
wp core install --url=example.com --title="Site" --admin_user=admin --admin_email=admin@example.com --prompt=admin_password

# Non-interactive equivalent (scripts, agents, CI): read the secret from the
# environment so the value itself never reaches the command line or history
wp config create --dbname=wordpress --dbuser=root --dbhost=localhost --dbpass="$WP_DB_PASS"
wp core install --url=example.com --title="Site" --admin_user=admin --admin_email=admin@example.com --admin_password="$WP_ADMIN_PASS"
```

## Plugins & Themes

```bash
wp plugin list [--status=active] [--update=available]
wp plugin install <slug> --activate
wp plugin activate <name>
wp plugin deactivate <name>
wp plugin update --all
wp plugin verify-checksums --all

wp theme list
wp theme install <slug> --activate
wp theme update --all
```

## Users

```bash
wp user list [--role=administrator]
wp user create <username> <email> --role=<role> --prompt=user_pass
wp user update <id> --role=editor --display_name="Name"
wp user update <id> --prompt=user_pass
wp user delete <id> --reassign=<other-id>
```

## Database

```bash
wp db export backup.sql
wp db import backup.sql
wp option get siteurl                    # prefix-agnostic; prefer over raw SQL
wp db query "SELECT option_value FROM $(wp config get table_prefix)options WHERE option_name='siteurl';"
wp db optimize
wp db repair

# Always --dry-run first, with the exact flags the real run will use
wp search-replace 'old' 'new' --precise --recurse-objects --all-tables-with-prefix --dry-run
wp search-replace 'old' 'new' --precise --recurse-objects --all-tables-with-prefix
```

## Options, Cache, Rewrites

```bash
wp option get <name>
wp option update <name> <value>
wp option delete <name>
wp option list --search="*cache*"
wp cache flush
wp transient delete --all        # database transients only; with an external object
                                 # cache you need `wp cache flush` too, and --network
                                 # for network transients on multisite
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

wp media regenerate            # add --yes only after confirming; it rewrites every thumbnail
wp media import <url-or-path>
```

## Maintenance & Troubleshooting

```bash
wp maintenance-mode activate
wp maintenance-mode deactivate
wp maintenance-mode status
wp doctor check --all            # requires wp-cli/doctor-command package
wp shell
wp eval 'echo PHP_VERSION;'
wp config get <name>
wp config list
```

## Multisite

```bash
wp site list
wp site create --slug=<slug> --title="Title"
wp site list --field=url | xargs -I {} wp option get blogname --url={}

# Network-wide operations need --network; without it they only touch the main site
wp core update-db --network
wp transient delete --all --network
wp plugin list --status=active,active-network
```

## Rules

- Always `--dry-run` `search-replace` first, and `wp db export` before destructive changes
- The dry run must carry the *same* flags as the real run — a preview with a different table
  scope does not describe what the real run will modify
- Prefer `--all-tables-with-prefix` over `--all-tables`: the latter rewrites every table in the
  database, including tables owned by other apps sharing it. Use it only deliberately
- Keep passwords and secrets off the command line: `--prompt=<arg>` when a terminal is
  attached, or an environment variable (`--dbpass="$WP_DB_PASS"`) when running
  non-interactively - `--prompt` blocks on stdin and will hang a script or agent
- Confirm destructive actions (`--yes`, `delete --force`, `plugin deactivate --all`) with the user first
- `--format=json` for machine output, `--fields=<cols>` to trim columns

## Common Workflows

```bash
# Domain migration
wp db export pre-migration.sql
wp search-replace 'https://old.com' 'https://new.com' --precise --recurse-objects --all-tables-with-prefix --dry-run
wp search-replace 'https://old.com' 'https://new.com' --precise --recurse-objects --all-tables-with-prefix
# search-replace only rewrites the database. WP_HOME/WP_SITEURL in wp-config.php override
# the rewritten options, so the old domain keeps serving - check `wp config list` first
wp config set WP_HOME 'https://new.com'
wp config set WP_SITEURL 'https://new.com'
wp cache flush && wp rewrite flush

# Update everything
wp core update && wp core update-db      # --network on multisite, or subsites keep the old schema
wp plugin update --all
wp theme update --all
wp cache flush

# Bisect a broken site
wp core verify-checksums
wp plugin list --status=active --field=name > active-plugins.txt   # capture first, so state is restorable
wp plugin deactivate --all
# Re-activate one by one from active-plugins.txt to find the culprit
wp plugin activate <name>
# Restore the original set: xargs wp plugin activate < active-plugins.txt
```
