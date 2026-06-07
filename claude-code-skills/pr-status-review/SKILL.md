---
name: pr-status-review
description: "Review your open pull requests and summarize their status in a table covering CI status, mergeability, and outstanding feedback, then suggest which PR to work on next. Use when the user asks to 'review my open PRs', 'check my PR status', 'what should I work on next', 'summarize my pull requests', 'which PR needs attention', or any request to triage open PRs across repos."
---

# PR Status Review Skill

Review all open pull requests authored by the current user across every repo, present a status table, and recommend the next PR to push forward.

## Workflow

1. **Find your PRs** - List all open PRs you authored across all repos.
2. **Gather status** - For each PR, collect CI status, mergeability, and review/feedback state.
3. **Build the table** - Present one row per PR (see format below).
4. **Recommend next** - Pick the PR with the highest leverage and explain why in one or two lines.

## Step 1: Find your open PRs

```bash
gh search prs --author @me --state open \
  --json repository,number,title,url,updatedAt \
  --sort updated --limit 50
```

This returns every open PR you authored, most recently updated first. If the user
asks to limit scope to the current repo, swap in
`gh pr list --author @me --state open --json number,title,url,updatedAt` instead.

## Step 2: Gather status per PR

For each PR, query the three signals. Use `OWNER/REPO` and `NUMBER` from step 1.

```bash
# CI status (returns one row per check)
gh pr checks NUMBER --repo OWNER/REPO --json name,state,bucket 2>/dev/null

# Mergeability + review decision in one call
gh pr view NUMBER --repo OWNER/REPO \
  --json mergeable,mergeStateStatus,reviewDecision,isDraft,comments,reviews
```

Interpret the fields:

| Field | Meaning |
|-------|---------|
| `mergeable: "MERGEABLE"` | No merge conflicts |
| `mergeable: "CONFLICTING"` | Has conflicts, needs rebase |
| `mergeStateStatus: "CLEAN"` | Ready to merge |
| `mergeStateStatus: "BLOCKED"` | Blocked (failing checks, missing approval, etc.) |
| `mergeStateStatus: "BEHIND"` | Branch is behind base, needs update |
| `reviewDecision: "APPROVED"` | Approved |
| `reviewDecision: "CHANGES_REQUESTED"` | Outstanding feedback to address |
| `reviewDecision: "REVIEW_REQUIRED"` | Awaiting review |
| `reviewDecision: ""` / null | No review required/requested yet |

**CI summary:** roll up `gh pr checks` rows into one label:
- All checks `pass`/`skipping` -> Passing
- Any `fail` -> Failing
- Any `pending` and none failing -> Running
- No checks -> None

**Outstanding feedback:** treat as Yes when `reviewDecision == "CHANGES_REQUESTED"`,
or when there are unresolved review threads / recent reviewer comments you have not
replied to. Otherwise No.

## Step 3: Build the status table

Present results sorted by recommended priority (most actionable first):

| PR | Title | CI | Mergeable | Feedback | Next action |
|----|-------|----|-----------|----------|-------------|
| [owner/repo#123](url) | Short title | Passing | Clean | None | Ready to merge |
| [owner/repo#456](url) | Short title | Failing | Blocked | Yes | Fix CI + address review |
| [owner/repo#789](url) | Short title | Running | Behind | No | Rebase on base branch |

Always link the PR using its URL (per the user's convention of linking issues/PRs).
Mark drafts explicitly (e.g. append "(draft)" to the title).

## Step 4: Recommend the next PR to work on

Pick ONE PR to suggest next, favoring high leverage. Suggested priority order:

1. **Mergeable + approved + CI passing** -> merge it now (fastest win, frees the queue).
2. **Changes requested** -> address feedback (unblocks a reviewer who is waiting).
3. **CI failing** -> fix CI (your action is the only blocker).
4. **Behind / conflicting** -> rebase/update the branch.
5. **Awaiting review** -> nothing to do but nudge reviewers; lowest priority for your time.

State the recommendation in one or two lines with the reason, e.g.:

> **Next:** [owner/repo#456](url) - CI is green and it's approved; merging it unblocks the
> stacked PR #460.

## Tips

- Batch the per-PR queries; with many PRs, run them in parallel where possible.
- If `gh` is not authenticated, prompt the user to run `gh auth login`.
- Keep titles short in the table (truncate to ~50 chars) so it stays readable.
- Don't take action (merge, push, comment) unless the user asks - this skill reports and recommends.
