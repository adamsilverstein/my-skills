#!/usr/bin/env bash
# Status of every PR in a feature, in the order given (bottom of the stack first).
#
# Usage: feature-status.sh OWNER/REPO PR [PR...] [--snapshot SLUG]
#
# Prints one JSON object:
#
#   {
#     "prs": [
#       { number, title, url, state, isDraft, branch, base, author,
#         mergeable,          MERGEABLE | CONFLICTING | UNKNOWN
#         mergeState,         CLEAN | BLOCKED | BEHIND | DIRTY | UNSTABLE | UNKNOWN | ...
#         reviewDecision,     APPROVED | CHANGES_REQUESTED | REVIEW_REQUIRED | ""
#         ci,                 passing | failing | running | none
#         failing_checks,     [names]
#         unresolved,         count of unresolved review threads
#         behind_by,          commits on the base branch missing from this PR
#         ahead_by,
#         last_activity: { at, by, kind }   newest comment or review, whoever wrote it
#       }, ...
#     ],
#     "changes": null | [ { number, field, from, to }, ... ],
#     "checked_at": "2026-09-11T22:00:00Z"
#   }
#
# --snapshot SLUG compares against ~/.claude/features/.snapshots/SLUG.json, fills
# "changes" with every watched field that differs since the previous run, and saves
# the new result as the snapshot. Watch mode uses it to speak only when something moved.
# Watched fields: state, mergeable, mergeState, reviewDecision, ci, unresolved,
# behind_by, last_activity.at.
set -euo pipefail

snapshot=""
repo=""
prs=()
while [ $# -gt 0 ]; do
	case "$1" in
		--snapshot) snapshot=$2; shift 2 ;;
		*)
			if [ -z "$repo" ]; then repo=$1; else prs+=("$1"); fi
			shift ;;
	esac
done

if [ -z "$repo" ] || [ ${#prs[@]} -eq 0 ]; then
	echo "Usage: feature-status.sh OWNER/REPO PR [PR...] [--snapshot SLUG]" >&2
	exit 2
fi

owner=${repo%%/*}
name=${repo##*/}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

one_pr() {
	local n=$1 idx=$2
	local view checks threads compare base head ci failing
	local fields=number,title,url,state,isDraft,author,headRefName,baseRefName,mergeable,mergeStateStatus,reviewDecision
	view=$(gh pr view "$n" --repo "$repo" --json "$fields")
	# GitHub computes mergeability lazily; the first read after a push often says UNKNOWN.
	if [ "$(echo "$view" | jq -r .mergeable)" = "UNKNOWN" ]; then
		sleep 3
		view=$(gh pr view "$n" --repo "$repo" --json "$fields")
	fi
	base=$(echo "$view" | jq -r .baseRefName)
	head=$(echo "$view" | jq -r .headRefName)

	# gh pr checks exits non-zero when a check fails or is pending, with complete JSON on
	# stdout, and also when no checks exist at all. Anything else is a real failure.
	checks=$(gh pr checks "$n" --repo "$repo" --json name,bucket 2>"$tmp/$idx.checks.err" || true)
	if ! echo "$checks" | jq -e 'type == "array"' >/dev/null 2>&1; then
		if grep -q "no checks reported" "$tmp/$idx.checks.err"; then
			checks='[]'
		else
			echo "ERROR: gh pr checks $n failed: $(cat "$tmp/$idx.checks.err")" >&2
			return 1
		fi
	fi
	ci=$(echo "$checks" | jq -r '
		if length == 0 then "none"
		elif any(.[]; .bucket == "fail") then "failing"
		elif any(.[]; .bucket == "pending") then "running"
		else "passing" end')
	failing=$(echo "$checks" | jq -c '[.[] | select(.bucket == "fail") | .name]')

	threads=$(gh api graphql -F owner="$owner" -F name="$name" -F number="$n" -f query='
		query($owner:String!, $name:String!, $number:Int!) {
		  repository(owner:$owner, name:$name) { pullRequest(number:$number) {
		    reviewThreads(first:100) { nodes { isResolved } }
		    comments(last:1) { nodes { author { login } createdAt } }
		    reviews(last:1) { nodes { author { login } submittedAt } }
		  } } }' --jq '.data.repository.pullRequest | {
			unresolved: ([.reviewThreads.nodes[] | select(.isResolved == false)] | length),
			comment: .comments.nodes[0],
			review: .reviews.nodes[0]
		}')

	compare=$(gh api "repos/$repo/compare/$base...$head" --jq '{ahead_by, behind_by}' 2>/dev/null \
		|| echo '{"ahead_by":null,"behind_by":null}')

	jq -n --argjson view "$view" --argjson threads "$threads" --argjson compare "$compare" \
		--arg ci "$ci" --argjson failing "$failing" '
		($threads.comment // {}) as $c | ($threads.review // {}) as $r
		| (if ($c.createdAt // "") >= ($r.submittedAt // "")
		   then {at: $c.createdAt, by: $c.author.login, kind: "comment"}
		   else {at: $r.submittedAt, by: $r.author.login, kind: "review"} end) as $last
		| {
			number: $view.number, title: $view.title, url: $view.url, state: $view.state,
			isDraft: $view.isDraft, branch: $view.headRefName, base: $view.baseRefName,
			author: $view.author.login,
			mergeable: $view.mergeable, mergeState: $view.mergeStateStatus,
			reviewDecision: ($view.reviewDecision // ""),
			ci: $ci, failing_checks: $failing,
			unresolved: $threads.unresolved,
			behind_by: $compare.behind_by, ahead_by: $compare.ahead_by,
			last_activity: (if $last.at then $last else null end)
		  }' > "$tmp/$idx.json"
}
export -f one_pr
export repo owner name tmp

i=0
for n in "${prs[@]}"; do
	printf '%s %04d\n' "$n" "$i"
	i=$((i + 1))
done | xargs -P 6 -L 1 bash -c 'one_pr "$0" "$1"'

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
result=$(cat "$tmp"/*.json | jq -s --arg now "$now" '{prs: ., changes: null, checked_at: $now}')

if [ -n "$snapshot" ]; then
	dir="${CLAUDE_FEATURES_DIR:-$HOME/.claude/features}/.snapshots"
	mkdir -p "$dir"
	file="$dir/$snapshot.json"
	if [ -f "$file" ]; then
		result=$(jq -n --argjson new "$result" --argjson old "$(cat "$file")" '
			($old.prs | map({key: (.number|tostring), value: .}) | from_entries) as $prev
			| ["state","mergeable","mergeState","reviewDecision","ci","unresolved","behind_by"] as $fields
			| $new | .changes = [
				.prs[] as $p
				| ($prev[$p.number|tostring]) as $o
				| if $o == null then {number: $p.number, field: "new", from: null, to: "tracked"}
				  else
				    ($fields[] | select($p[.] != $o[.]) | {number: $p.number, field: ., from: $o[.], to: $p[.]}),
				    (select(($p.last_activity.at // "") != ($o.last_activity.at // ""))
				      | {number: $p.number, field: "last_activity", from: $o.last_activity, to: $p.last_activity})
				  end
			  ]')
	else
		result=$(echo "$result" | jq '.changes = []')
	fi
	echo "$result" > "$file"
fi

echo "$result"
