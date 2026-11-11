---
name: local-cleanup
description: "Use when the user asks to clean up, free disk space, or tidy local developer leftovers: old git worktrees, node_modules folders, wp-env or Docker containers and volumes, temporary test or work files, build logs, tool caches (npm, Playwright, Cypress), or old files in ~/Downloads. Triggers include 'clean up my machine', 'disk is full', 'free up space', 'remove old worktrees', 'local cleanup'."
---

# Local Cleanup

Find developer leftovers (mostly from agent work), report what each category costs, get the user's approval per category, then remove only what was approved. **Nothing is deleted before the user picks categories.**

## Workflow

1. **Scan (read-only).** `bash scripts/scan.sh <out-dir>` with an out dir in the scratchpad. It takes a few minutes on hundreds of worktrees, so run it in the background. Tunables are documented in the script header (worktrees root, recency and idle thresholds, Downloads age).
2. **Report.** Show `summary.md` as a numbered table: category, count, size, risk. Also write a full per-item list to `~/Downloads/local-cleanup-plan-YYYY-MM-DD.md` so the user can strike items. Say what is deliberately kept (in-use, recent, merged-but-dirty) and why.
3. **Ask** which numbered categories to run, and where old Downloads should go (an archive folder, often on an external drive; check it is mounted). Stop here until the user answers.
4. **Apply** each approved category: `bash scripts/apply.sh <out-dir> <category> [archive-dir]`. Run `worktrees` and `node-modules` in the background (removal of 100+ worktrees takes many minutes) and do the quick categories meanwhile. Send a short progress update while they run.
5. **Final report.** Free space before and after (`df -h ~`), per-category result, anything skipped and why.

## Categories

| # | Category | Rule | Removal |
|---|---|---|---|
| 1 | Worktrees | Branch's PR is MERGED or CLOSED, no tracked or untracked changes, nothing unpushed, no commit in the last 2 days, not mounted by a running container | `git worktree remove` (no `--force`), then `worktree prune` |
| 2 | node_modules | Kept worktree idle 7+ days, no tracked changes | `rm -rf`, including nested workspace copies |
| 3 | wp-env envs | `~/.wp-env/<hash>` whose source folder is gone or is in category 1 | Compose-labelled containers, volumes, networks, then the dir |
| 4 | Docker | Stopped containers, unused volumes not owned by a remaining `~/.wp-env` env, build cache | prune, but volumes by the scan's list only |
| 5 | Downloads | Older than 14 days | `mv -n` to the archive dir; rename on collision |
| 6 | Strays | Files and non-git folders at the worktrees root (build logs, screencast frames) | `trash` (recoverable) |
| 7 | Caches | npm, Cypress, Puppeteer, codex runtimes; Playwright old builds | `rm -rf`; keep newest Playwright build per browser |

## Safety rules

- PR state comes from `gh pr list` on each repo's origin **and** its upstream parent; for repos the user owns, include every author (agents open PRs there too).
- A merged PR does not mean the worktree is done: branches get reused. Keep anything with a recent commit.
- Never touch worktrees mounted by running containers (`docker inspect` mounts); the scan puts them in `keep-in-use.tsv`.
- List `review-merged-but-dirty.tsv` for the user (unpushed commits, uncommitted work) instead of removing those.
- `apply.sh` re-checks each worktree is clean right before removing it, since the user keeps working while this runs.
- Leave Claude transcripts (`~/.claude/projects`) and main repo checkouts alone unless the user asks.

## Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| `docker volume prune -a` after pruning containers | Deletes the databases of every stopped env the user keeps | Remove only the volumes recorded as dangling during the scan |
| Inline `docker volume rm $ids` or `trash $LIST` in the zsh Bash tool | zsh does not word-split: the list arrives as one bogus name (`404 page not found`) and nothing is removed | Run the bundled scripts with `bash`, or loop one item at a time |
| `git worktree remove --force` | Silently discards new work | Let git refuse and report the skip |
| Wiping all Playwright browsers | Next e2e run stalls on a download | Keep the newest build per browser |
| `gh pr list --author @me` on the user's own repos | Misses agent-opened PRs, worktrees look PR-less and get kept | Drop the author filter when the owner is the user |
| Matching Downloads only by age without checking the drive | `mv` fails or fills the wrong disk | Confirm the archive dir exists first |
