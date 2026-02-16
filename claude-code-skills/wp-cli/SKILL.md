---
name: wp-cli
description: "Run WP-CLI commands to manage WordPress installations. Use when the user wants to manage WordPress via the command line, run wp commands, manage plugins, themes, users, databases, options, cron, rewrite rules, or perform any WordPress administration task using WP-CLI. Triggers include requests like 'run wp-cli', 'manage WordPress', 'install a plugin', 'update WordPress', 'create a user', 'search-replace in the database', 'export the database', or any WP-CLI task."
---

# WP-CLI Skill

Manage WordPress installations using WP-CLI commands. Covers core management, plugins, themes, users, database operations, options, cron, and more.

## Prerequisites

- WP-CLI must be installed and available as `wp` in PATH
- Commands must be run from the WordPress root directory (where `wp-config.php` lives) or use `--path=<path>`
- For remote servers, ensure SSH access is configured

## Quick Reference

```bash
# Verify WP-CLI is available and check WordPress status
wp --version
wp core version
wp core is-installed
```

## Core Management

```bash
# Check for updates
wp core check-update

# Update WordPress core
wp core update
wp core update-db

# Download and install WordPress
wp core download
wp config create --dbname=wordpress --dbuser=root --prompt=dbpass --dbhost=localhost
wp core install --url=example.com --title="Site Title" --admin_user=admin --admin_email=admin@example.com --prompt=admin_password
```

## Plugin Management

```bash
# List plugins
wp plugin list
wp plugin list --status=active
wp plugin list --update=available

# Install and activate
wp plugin install <plugin-slug> --activate
wp plugin activate <plugin-name>
wp plugin deactivate <plugin-name>

# Update plugins
wp plugin update --all
wp plugin update <plugin-name>

# Search for plugins
wp plugin search <term> --fields=name,slug,rating
```

## Theme Management

```bash
# List themes
wp theme list
wp theme list --status=active

# Install and activate
wp theme install <theme-slug> --activate
wp theme activate <theme-name>

# Update themes
wp theme update --all
wp theme update <theme-name>
```

## User Management

```bash
# List users
wp user list
wp user list --role=administrator

# Create a user
wp user create <username> <email> --role=<role> --user_pass=<password>

# Update a user
wp user update <user-id> --display_name="New Name"
wp user update <user-id> --role=editor

# Delete a user (reassign content)
wp user delete <user-id> --reassign=<other-user-id>

# Reset password
wp user update <user-id> --user_pass=<new-password>
```

## Database Operations

```bash
# Export / Import
wp db export backup.sql
wp db import backup.sql

# Search and replace (always use --dry-run first)
wp search-replace 'old-string' 'new-string' --dry-run
wp search-replace 'old-string' 'new-string' --precise --recurse-objects --all-tables

# Run a query
wp db query "SELECT * FROM wp_options WHERE option_name = 'siteurl';"

# Optimize and repair
wp db optimize
wp db repair
```

## Options

```bash
# Get / Set options
wp option get siteurl
wp option get blogname
wp option update siteurl 'https://example.com'
wp option update blogname 'My Site'

# List options matching a pattern
wp option list --search="*cache*"

# Delete an option
wp option delete <option-name>
```

## Cache and Transients

```bash
# Flush caches
wp cache flush
wp transient delete --all

# Flush rewrite rules
wp rewrite flush
wp rewrite structure '/%postname%/'
```

## Cron

```bash
# List scheduled events
wp cron event list

# Run all due cron events
wp cron event run --due-now

# Run a specific cron event
wp cron event run <hook-name>

# Test WP-Cron
wp cron test
```

## Post and Content Management

```bash
# List posts
wp post list --post_type=post --post_status=publish

# Create a post
wp post create --post_title='Title' --post_content='Content' --post_status=publish

# Delete a post
wp post delete <post-id> --force

# Generate test posts
wp post generate --count=10
```

## Media

```bash
# Regenerate thumbnails
wp media regenerate --yes

# Import media from a URL
wp media import <url>
```

## Maintenance and Troubleshooting

```bash
# Enable/disable maintenance mode
wp maintenance-mode activate
wp maintenance-mode deactivate

# Check site health
wp doctor check --all

# Verify core file integrity
wp core verify-checksums

# Verify plugin file integrity
wp plugin verify-checksums --all

# Debug and information
wp shell
wp eval 'echo PHP_VERSION;'
wp config get
wp config list
```

## Multisite

```bash
# List sites in a network
wp site list

# Create a new site
wp site create --slug=<site-slug> --title="Site Title"

# Run a command across all sites
wp site list --field=url | xargs -I {} wp option get blogname --url={}
```

## Important Rules

- **Always use `--dry-run`** for `search-replace` before running the real command
- **Always export the database** before destructive operations (`wp db export`)
- **Use `--yes`** flag cautiously; confirm destructive actions with the user first
- **Check `wp core is-installed`** before running commands to verify WordPress is accessible
- **Quote values** that contain spaces or special characters
- **Use `--fields`** to limit output columns for readability
- **Use `--format=json`** when you need to parse output programmatically

## Workflow for Common Tasks

### Migrating a domain

```bash
wp db export pre-migration.sql
wp search-replace 'https://old-domain.com' 'https://new-domain.com' --dry-run
wp search-replace 'https://old-domain.com' 'https://new-domain.com' --precise --recurse-objects --all-tables
wp cache flush
wp rewrite flush
```

### Updating everything

```bash
wp core update
wp core update-db
wp plugin update --all
wp theme update --all
wp cache flush
```

### Debugging a broken site

```bash
wp core is-installed
wp core verify-checksums
wp plugin list --status=active
wp plugin deactivate --all
# Re-activate plugins one by one to identify the culprit
wp plugin activate <plugin-name>
```
