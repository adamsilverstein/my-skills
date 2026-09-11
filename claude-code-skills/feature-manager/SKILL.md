---
name: feature-manager
description: "Track and tend the multi-PR features Adam drives on GitHub. Use when Adam names a feature he is working on ('work on suggestion mode', 'check on the notes followers feature', 'how is X doing'), asks to register a feature from a tracking issue, or asks for any feature-wide chore: status of the whole stack, bring the PRs up to date with trunk, get CI green everywhere, find new feedback or comments that need addressing, refresh the tracking issue, or watch the feature for changes."
---

# Feature manager

A feature is a tracking issue plus the PRs that implement it, often a stack of branches
based on one another. Adam registers a feature once; after that, "work on suggestion mode"
means the same thing to Claude every time. This skill keeps the registry and runs the
recurring chores over the whole feature at once.

Scripts live in this skill's `scripts/` directory (`~/.claude/skills/feature-manager/scripts/`
once installed). They depend on `gh` and `jq` only and never touch the registry; Claude
reads and edits registry files directly.

## The registry

One YAML file per feature at `~/.claude/features/<slug>.yaml`. Hand-editable; Adam may
change it without saying so, so read it fresh at the start of every task.

```yaml
name: suggestion-mode
aliases: [suggest mode, suggestion mode, suggestions]
repo: WordPress/gutenberg
tracking_issues: [73411]
worktree: ~/repositories/worktrees/73411-suggest-mode
stack:                      # bottom to top; each base is the branch before it
  - { pr: 80427, branch: suggest/intent, base: trunk }
  - { pr: 80428, branch: suggest/data,   base: suggest/intent }
side_prs: [81997]           # related PRs outside the chain
bundle: { pr: 78994, branch: try/suggest-mode-combined }   # optional Playground bundle
last_checked: 2026-09-11T22:00:00Z
notes: |
  Waiting on design feedback for the sidebar summary wording.
```

**Resolving a name.** Match what Adam said against `name` and `aliases` across every file
in the directory, case-insensitively and ignoring the word "feature". One match: use it.
None: offer to register, or list what exists. Several: ask which.

**The PR list** for any chore is the stack in order, then side PRs, then the bundle.
Merged or closed PRs stay in the file until Adam removes them; skip them for git work.

## Chores

| Adam says | Do |
|---|---|
| "register X from #NNN" / "add this feature" | **Register** |
| "status of X", "check on X", "how is X doing" | **Status** |
| "update X", "bring X up to date", "rebase X on trunk" | **Update** (merge, never rebase; say so if he said rebase) |
| "fix CI on X", "get X green" | **CI** |
| "any feedback on X", "anything new on X", "what needs a reply" | **Feedback** |
| "work on X", "open X", "switch to X" | **Work on** |
| "update the tracking issue", "sync the issue" | **Sync issue** |
| "watch X", "keep an eye on X" | **Watch** |
| "what features am I working on", "forget X" | **List** / **Forget** |

### Register

```
bash ~/.claude/skills/feature-manager/scripts/discover-feature.sh WordPress/gutenberg 73411
```

The output lists every PR the issue body references plus Adam's open PRs whose base is
a branch already in the set, each with `depth` (0 = based on trunk) and a `bundle_candidate`
flag. Build the proposed file from it: open PRs sorted by depth form `stack`; open PRs at
depth 0 that are not the chain bottom, or that sit beside another PR at the same depth,
go to `side_prs`; a bundle candidate goes to `bundle`. Leave merged and closed PRs out.
Pick a slug and two or three aliases from the issue title. Set `last_checked` to now.

Show Adam the whole proposed file and ask before writing it. Discovery is a guess about
structure; he knows which branch is the bundle and which PR is a side quest.

### Status

```
bash ~/.claude/skills/feature-manager/scripts/feature-status.sh WordPress/gutenberg 80427 80428 ... 78994
```

Print one table, stack order, then side PRs, then the bundle:

| PR | Title | CI | Merge | Behind | Threads | Last activity |
|---|---|---|---|---|---|---|
| [#80427](url) | 1/9 editor intent | Passing | Conflicting | 38 | 1 | ciampo, review, 2h ago |

`Merge` is `mergeable` unless it is MERGEABLE, then show `mergeState` (Clean, Blocked,
Behind). `Behind` is commits on the PR's own base it lacks, so for a stack it says who
needs the cascade. Mark drafts. Link every PR.

Then **Needs you**, at most five lines, in this order: conflicts, failing CI, changes
requested, unresolved threads with someone else's last word, PRs behind their base. If
nothing qualifies, say "all green" and stop. Do not recommend merging; Adam decides.

### Update

Always dry-run first and show the result:

```
bash ~/.claude/skills/feature-manager/scripts/cascade-update.sh <worktree> trunk suggest/intent suggest/data ... suggest/e2e --bundle try/suggest-mode-combined --dry-run
```

`UP-TO-DATE` in a dry run is relative to the parent as it is now; once trunk lands in the
bottom layer every layer above will need its turn, which is what the real run does. If the
worktree is dirty the script refuses; report that rather than committing or stashing for him.

Then run without `--dry-run`. Each layer merges its parent with a merge commit and pushes
to origin. The bundle merges the top of the stack last, so bundle-only commits survive.
On `CONFLICT` (exit 3) the merge is left in progress: report the branch and files, then
stop. Resolving is Adam's call. When he says to resolve, do it in that worktree, commit,
push, and re-run the script starting from the next branch with the resolved branch as
the base. Never `git rebase`, never `--force`, never `reset --hard` a shared branch.

Afterwards run **Status** so the table reflects the pushes (CI will show Running).

### CI

Run **Status**, take the PRs with `ci: failing`, and for each one use the ci-fixer skill
in the feature worktree, bottom of the stack first. A fix low in the stack often clears the
layers above once the cascade carries it up, so after fixing one layer run **Update** before
touching the next. Report which PRs were red, what changed, and which are still running.

### Feedback

```
bash ~/.claude/skills/feature-manager/scripts/feature-feedback.sh WordPress/gutenberg <last_checked> 73411 80427 80428 ... --exclude adamsilverstein
```

Group by target, people first, bots (`is_bot: true`) in a separate short section with
unresolved items only. For each item say who, where (linked), a one-line gist, and a
classification: **code change**, **reply**, or **nothing** (already resolved, a thanks, a
bot summary). For code changes and replies, propose the response in one or two lines.

Nothing gets changed or posted from this chore. When Adam picks items, code changes happen
in the worktree with atomic commits, and replies go through post-review-gate in adams-voice
with claude-attribution. Advance `last_checked` in the registry only after the digest is in
front of Adam, never before, so a crashed run does not swallow comments.

### Work on

Read the registry, `cd` to `worktree`. If it does not exist, create it from the repo's
main checkout: `git worktree add ~/repositories/worktrees/<issue>-<slug> <branch>` (the
worktrunk skill applies when `wt` is set up for that repo). Check out the branch Adam
named, or the top of the stack by default, fast-forward it from origin, and run `nvm use`
when the repo has an `.nvmrc`. Say which branch is checked out and which PR it belongs to,
then wait for the actual task.

### Sync issue

Build a status block from the **Status** table and place it in the tracking issue body
between `<!-- feature-manager:status -->` and `<!-- /feature-manager:status -->`, adding
the markers at the end of the body if absent. Text outside the markers is never touched.
The block opens with a claude-attribution header. This is a post under Adam's name: draft
the full new body to a file, run it through post-review-gate, then
`gh issue edit NNN --repo OWNER/REPO --body-file <file>`, and log it as kind `issue`.

### Watch

Use `/loop` with a thirty minute interval. Each tick: run **Status** with
`--snapshot <slug>` and **Feedback** since `last_checked`. If `changes` is empty and there
is no new feedback from a person, say nothing beyond a one-line "no change". Otherwise
report only what moved (CI turned red, a conflict appeared, a review landed) and, for
feedback, the digest. Never take git action or post from a watch tick.

### List / Forget

List: one line per registry file with name, repo, open PR count, and `last_checked`.
Forget: confirm, then delete the file and its snapshot under `~/.claude/features/.snapshots/`.

## Guardrails

- **Read the registry fresh, every task.** Adam edits it by hand.
- **Never merge a PR, never force-push, never rebase, never resolve a conflict unasked.**
- **Nothing posts without post-review-gate.** Replies, issue body edits, all of it.
- **Discovery proposes, Adam confirms.** Do not write a registry file he has not seen.
- **Scope is one feature.** Cross-repo "what should I work on next" is pr-status-review's job;
  fixing a red check is ci-fixer's job. Delegate rather than reimplement.
- **One question at a time when a name or a branch is ambiguous.** Guessing wrong pushes to
  the wrong branch.

## Rationalizations that mean stop

| Thought | Reality |
|---|---|
| "The conflict is trivial, I'll just resolve it." | Adam asked for an update, not a resolution. Report and stop. |
| "Rebase would give cleaner history." | He chose merges so review threads stay anchored. Merge. |
| "The bot's suggestion is right, I'll apply it." | Feedback proposes; Adam picks. Put it in the digest. |
| "Discovery looks obviously right, I'll save it." | He knows which PR is the bundle and which is a side quest. Show it first. |
| "I'll bump last_checked now so I don't forget." | Bump it after the digest is in chat, or a crash loses comments. |
