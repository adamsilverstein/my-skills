#!/usr/bin/env bash
# Bring a stack of branches up to date by merging each parent into its child, bottom up.
#
# Usage: cascade-update.sh WORKTREE BASE BRANCH [BRANCH...] [--bundle BRANCH] [--dry-run]
#   WORKTREE   checkout to work in (a clean tree; the script refuses a dirty one)
#   BASE       what the bottom branch merges from, usually trunk
#   BRANCH...  the stack, bottom to top; each merges from the one before it
#   --bundle   a branch that merges from the top of the stack last (Playground bundle)
#   --dry-run  only report how far behind each branch is; touch nothing
#
# For each branch: check it out (tracking origin), fast-forward from origin, merge
# origin/<parent> with a merge commit, push to origin. Never rebases, never force-pushes.
#
# Exit codes
#   0  every branch up to date or merged and pushed
#   2  usage or a dirty worktree
#   3  merge conflict: the merge is left in progress on that branch with the
#      conflicting files listed, so it can be resolved by hand. Re-run with the
#      remaining branches once it is resolved and pushed.
#
# Output, one line per branch:
#   UP-TO-DATE  suggest/intent
#   MERGED      suggest/data <- suggest/intent (pushed)
#   BEHIND      suggest/data is 3 behind suggest/intent      (dry run only)
#   CONFLICT    suggest/inline-ops <- suggest/inline-markers
set -uo pipefail

dry=false
bundle=""
pos=()
while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run) dry=true; shift ;;
		--bundle) bundle=$2; shift 2 ;;
		*) pos+=("$1"); shift ;;
	esac
done

if [ ${#pos[@]} -lt 3 ]; then
	echo "Usage: cascade-update.sh WORKTREE BASE BRANCH [BRANCH...] [--bundle BRANCH] [--dry-run]" >&2
	exit 2
fi

worktree=${pos[0]}
base=${pos[1]}
branches=("${pos[@]:2}")
[ -n "$bundle" ] && branches+=("$bundle")

cd "$worktree" || { echo "ERROR: cannot cd to $worktree" >&2; exit 2; }

# A dry run only reads remote refs, so a dirty tree is fine for it.
if ! $dry; then
	if [ -n "$(git status --porcelain)" ]; then
		echo "ERROR: $worktree has uncommitted changes; commit or move them first" >&2
		exit 2
	fi
	if git rev-parse -q --verify MERGE_HEAD >/dev/null; then
		echo "ERROR: a merge is already in progress in $worktree" >&2
		exit 2
	fi
fi

git fetch origin --quiet || { echo "ERROR: git fetch failed" >&2; exit 2; }

parent=$base
for branch in "${branches[@]}"; do
	if ! git rev-parse -q --verify "origin/$branch" >/dev/null; then
		echo "ERROR: origin/$branch does not exist" >&2
		exit 2
	fi

	behind=$(git rev-list --count "origin/$branch..origin/$parent")

	if $dry; then
		if [ "$behind" -eq 0 ]; then
			echo "UP-TO-DATE  $branch"
		else
			echo "BEHIND      $branch is $behind behind $parent"
		fi
		parent=$branch
		continue
	fi

	if git show-ref -q --verify "refs/heads/$branch"; then
		git checkout -q "$branch" || exit 2
		git merge -q --ff-only "origin/$branch" || {
			echo "ERROR: local $branch has diverged from origin/$branch; reconcile it first" >&2
			exit 2
		}
	else
		git checkout -q -b "$branch" --track "origin/$branch" || exit 2
	fi

	if [ "$behind" -eq 0 ]; then
		echo "UP-TO-DATE  $branch"
		parent=$branch
		continue
	fi

	if git merge --no-edit -q "origin/$parent" >/dev/null 2>&1; then
		if git push -q origin "$branch"; then
			echo "MERGED      $branch <- $parent (pushed)"
		else
			echo "ERROR: merged $branch but push failed; push it by hand and re-run from the next branch" >&2
			exit 2
		fi
	else
		echo "CONFLICT    $branch <- $parent"
		git diff --name-only --diff-filter=U | sed 's/^/            /'
		echo "Merge left in progress on $branch in $worktree. Resolve, commit, push, then re-run with the remaining branches." >&2
		exit 3
	fi
	parent=$branch
done
