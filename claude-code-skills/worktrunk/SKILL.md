---
name: worktrunk
description: "Manages git worktrees using Worktrunk (wt CLI). Covers core commands (switch, list, merge, remove, step), configuration (user config at ~/.config/worktrunk/config.toml and project hooks at .config/wt.toml), hooks, LLM commit messages, parallel agents, and troubleshooting. Use for 'wt switch', 'wt list', 'wt merge', 'wt remove', 'worktree management', 'parallel agents', 'configuring hooks'."
---

# Worktrunk — Git Worktree Management

Worktrunk (`wt`) addresses worktrees by branch name and computes paths from a configurable template.

## Core Commands

### `wt switch` — Create or Switch Worktrees

```bash
wt switch feat                        # Switch to existing worktree
wt switch --create feat               # Create new branch + worktree
wt switch -c -x claude feat           # Create and run Claude in it
wt switch -c feat -- 'Fix GH #322'   # Create + Claude with prompt (args after --)
wt switch -                            # Previous worktree
wt switch pr:123                       # Check out a PR's branch
wt switch --create part2 --base=@     # Branch from current HEAD (stacked branches)
```

**Shortcuts:** `^` (default branch), `@` (current worktree), `-` (previous), `pr:N`/`mr:N`

No arguments opens an interactive picker with live diff/log previews.

### `wt list` — View All Worktrees

```bash
wt list                               # Compact status
wt list --full                        # CI status, LLM summaries
wt list --full --branches             # Include branches without worktrees
wt list --format=json                 # JSON output for scripts
```

**Symbols:** `@` current, `^` main, `+` staged, `*` unstaged, `upN`/`downN` ahead/behind

### `wt merge` — Merge and Clean Up

8-step pipeline: commit → squash → rebase → pre-merge hooks → fast-forward merge → pre-remove hooks → cleanup → post hooks.

```bash
wt merge main
```

### `wt remove` — Clean Up

```bash
wt remove                             # Current worktree (with 5 safety checks)
wt remove feat                        # Specific worktree
wt remove --force                     # Skip safety checks
```

### `wt step` — Individual Operations

```bash
wt step commit                        # Commit (with LLM message if configured)
wt step squash                        # Squash branch commits
wt step rebase                        # Rebase onto default branch
wt step push                          # Push current branch
wt step copy-ignored                  # Copy gitignored files from default worktree
wt step diff                          # Diff vs default branch
wt step eval '{{ branch }}'           # Evaluate template expression
wt step for-each 'npm test'           # Run command in every worktree
```

## Configuration

### User Config: `~/.config/worktrunk/config.toml`

```toml
# Worktree path template
worktree-path = "{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}"

# LLM commit messages
[commit.generation]
command = "claude -p"

# Branch summaries in wt list --full
[list]
summary = true

# Aliases
[aliases]
wsc = "switch --create --execute=claude"
```

### Project Config: `.config/wt.toml`

Committed to the repo for team-shared hooks and settings.

```toml
[post-start]
deps = "npm install"
copy = "wt step copy-ignored"

[pre-merge]
lint = "npm run lint"
test = "npm test"

[pre-remove]
cleanup = "docker stop myapp 2>/dev/null || true"
```

### Hook Lifecycle

| Hook | When | Use For |
|------|------|---------|
| `pre-start` | Before worktree setup | Copy caches needed by later hooks |
| `post-start` | After creation | Install deps, start servers, copy .env |
| `pre-commit` | Before committing | Lint, format |
| `post-commit` | After committing | Push, notify |
| `pre-merge` | Before merge | Local CI gate (failures abort merge) |
| `post-merge` | After merge | Notify, deploy |
| `pre-remove` | Before removal | Stop servers, clean containers |
| `post-remove` | After removal | Clean caches |

### Template Variables and Filters

**Variables:** `{{ branch }}`, `{{ repo }}`, `{{ repo_path }}`, `{{ worktree_path }}`, `{{ vars.* }}`

**Filters:**
- `sanitize` — safe for filenames/containers
- `sanitize_db` — safe for database names
- `hash_port` — deterministic port 10000–19999 from string (e.g., `{{ branch | hash_port }}`)

## Common Patterns

### Parallel Agents

```bash
wt switch -x claude -c feature-a -- 'Add user authentication'
wt switch -x claude -c feature-b -- 'Fix the pagination bug'
wt switch -x claude -c feature-c -- 'Write tests for the API'
```

### Eliminate Cold Starts

```toml
[post-start]
copy = "wt step copy-ignored"
```

Copies gitignored files (node_modules, .env, caches). Use `pre-start` if later hooks need them. Limit with `.worktreeinclude`.

### Dev Server Per Worktree

```toml
[post-start]
server = "npm run dev -- --port {{ branch | hash_port }}"

[list]
url = "http://localhost:{{ branch | hash_port }}"

[pre-remove]
server = "lsof -ti :{{ branch | hash_port }} -sTCP:LISTEN | xargs kill 2>/dev/null || true"
```

### Database Per Worktree

```toml
post-start = [
  "wt config state vars set container='{{ repo }}-{{ branch | sanitize }}-postgres' port='{{ ('db-' ~ branch) | hash_port }}' db_url='postgres://postgres:dev@localhost:{{ ('db-' ~ branch) | hash_port }}/{{ branch | sanitize_db }}'",
  { db = "docker run -d --rm --name {{ vars.container }} -p {{ vars.port }}:5432 -e POSTGRES_DB={{ branch | sanitize_db }} -e POSTGRES_PASSWORD=dev postgres:16" },
]

[pre-remove]
db-stop = "docker stop {{ vars.container }} 2>/dev/null || true"
```

Access: `DATABASE_URL=$(wt config state vars get db_url) npm start`

### Agent Handoffs

```bash
# tmux (detached)
tmux new-session -d -s fix-auth "wt switch --create fix-auth -x claude -- 'Fix the bug'"

# Zellij
zellij run -- wt switch --create fix-auth -x claude -- 'Fix the bug'
```

### Agent Status Markers

```bash
wt config state marker set "WIP"
wt config state marker set "done" --branch feat
```

### State Utilities

```bash
wt config state default-branch                           # Detected default branch
wt config state logs get --hook=user:post-start:server   # Hook log path
```

## Troubleshooting

- **`wt switch` doesn't change directory:** Run `wt config shell install` and reload shell (`exec $SHELL`)
- **Check path template:** `wt step eval '{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}'`
- **Debug hooks:** `tail -f "$(wt config state logs get --hook=user:post-start:server)"`

## Resources

- Docs: https://worktrunk.dev/worktrunk/
- Tips: https://worktrunk.dev/tips-patterns/
- GitHub: https://github.com/max-sixty/worktrunk
- Claude Code integration: https://worktrunk.dev/claude-code/
