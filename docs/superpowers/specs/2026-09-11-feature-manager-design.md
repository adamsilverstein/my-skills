# Feature manager skill design

Date: 2026-09-11
Status: approved in chat, implementing

## Purpose

Adam drives features on GitHub that span a tracking issue and a stack of PRs, such as
suggestion mode in Gutenberg (issue #73411, nine chained PRs, a bundle PR for Playground
testing, and side fixes). Checking on such a feature by hand means opening a dozen tabs.
This skill keeps a registry of features and gives Claude one vocabulary for the recurring
chores: status, bringing the stack up to date with trunk, CI, feedback triage, tracking
issue upkeep, and a watch loop.

## Decisions from the interview

| Question | Decision |
|---|---|
| Where the registry lives | One YAML file per feature under `~/.claude/features/`, hand-editable, outside any repo |
| How a feature is registered | Point at a tracking issue; the skill discovers the PR chain and asks for confirmation |
| Stack update strategy | Merge trunk into the bottom PR, cascade merges upward. No rebases, no force pushes |
| Feedback handling | Triage and propose. Code changes and replies only on Adam's say-so, via post-review-gate |
| Bundle PR | Tracked in the registry, rebuilt after a cascade by merging the top of the stack into it |
| Extras in v1 | Tracking issue status block, watch mode, worktree management |
| Seed data | None. Adam registers features as he goes |
| Output | Chat table plus a short "needs you" list, same field meanings as pr-status-review |

## Registry file

`~/.claude/features/<slug>.yaml`

```yaml
name: suggestion-mode
aliases: [suggest mode, suggestion mode]
repo: WordPress/gutenberg
tracking_issues: [73411]
worktree: ~/repositories/worktrees/73411-suggest-mode
stack:                      # bottom to top
  - { pr: 80427, branch: suggest/intent, base: trunk }
  - { pr: 80428, branch: suggest/data,   base: suggest/intent }
side_prs: [81997]
bundle: { pr: 78994, branch: try/suggest-mode-combined }
last_checked: 2026-09-11T22:00:00Z
notes: |
  Freeform.
```

Claude reads and edits these files directly. Scripts never parse YAML; they take repo,
branch, and PR arguments on the command line. Watch-mode snapshots live in
`~/.claude/features/.snapshots/<slug>.json` so the registry stays clean for hand edits.

## Scripts

All bash, depending on `gh` and `jq` only.

| Script | Input | Output |
|---|---|---|
| `discover-feature.sh OWNER/REPO ISSUE...` | Tracking issue numbers | JSON: every PR referenced in the issue bodies plus Adam's open PRs whose base is a branch in the set, each with branch, base, state, author, and a depth in the chain |
| `feature-status.sh OWNER/REPO PR... [--snapshot SLUG]` | PR numbers in stack order | JSON: per PR state, draft, mergeable, merge state, CI rollup, review decision, unresolved threads, commits behind base, last activity. With `--snapshot`, also the list of fields that changed since the previous run |
| `feature-feedback.sh OWNER/REPO SINCE TARGET... [--exclude LOGIN]` | ISO timestamp and issue or PR numbers | JSON lines: issue comments, reviews, and review comments newer than SINCE by anyone but the excluded login, with resolved state for review threads |
| `cascade-update.sh WORKTREE BASE BRANCH... [--bundle BRANCH] [--dry-run]` | Worktree path, base branch, branches bottom to top | Merges each parent into its child and pushes. Stops at the first conflict, leaving the merge in progress and listing the files |

## Workflows

- **register**: discover, show the proposed registry file, save on confirmation.
- **status**: run feature-status, print the table in stack order and a "needs you" list.
- **update**: dry-run first to show what is behind, then cascade, then bundle. Conflicts stop the run.
- **ci**: from status, hand each red PR to the ci-fixer skill in the feature worktree.
- **feedback**: run feature-feedback since `last_checked`, group by PR, classify each item as code change, reply, or nothing, propose a response. Advance `last_checked` only after Adam has seen the digest.
- **work on**: open the worktree (create it under `~/repositories/worktrees` if missing), check out the named branch or the top of the stack, `nvm use`.
- **sync issue**: regenerate a status block between `<!-- feature-manager:status -->` markers in the tracking issue body; post through post-review-gate.
- **watch**: `/loop` every thirty minutes running status with `--snapshot` and feedback; report only changes.
- **list**, **forget**.

## Boundaries

Never merge a PR, never force-push, never resolve a conflict unasked, never post
without post-review-gate. CI fixing is ci-fixer's job. Cross-repo status is
pr-status-review's job.

## Later

Merge progression (retarget and renumber after a layer merges), Trac-backed features for
wordpress-develop, register from a branch prefix, auto-fix trivial feedback, a dashboard
artifact, reviewer nudges, dev note drafts. Paginate review threads past 100 per PR in
feature-status and feature-feedback (raised in review of PR #31).
