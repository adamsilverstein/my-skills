#!/usr/bin/env bash
# Discover the PRs that make up a feature from its tracking issue(s).
#
# Usage: discover-feature.sh OWNER/REPO ISSUE [ISSUE...]
#
# Reads each issue body, collects every PR it references (#NNNN or a pull URL in the
# same repo), then adds the current user's open PRs whose base branch is the head of a
# PR already in the set, so a stack layer added after the issue was written still shows
# up. Prints one JSON object:
#
#   {
#     "repo": "WordPress/gutenberg",
#     "issues": [73411],
#     "me": "adamsilverstein",
#     "prs": [ { number, title, url, state, isDraft, author, branch, base,
#                depth, mine, from_issue, bundle_candidate }, ... ],   # sorted by depth then number
#     "not_prs": [77403, ...]                                            # referenced numbers that are issues
#   }
#
# depth is 0 for a PR based on a branch that is not another PR in the set (usually trunk),
# 1 for a PR based on a depth-0 PR, and so on. A single chain comes out bottom to top.
# The script only reads. It never writes the registry; Claude does that after Adam confirms.
set -euo pipefail

if [ $# -lt 2 ]; then
	echo "Usage: discover-feature.sh OWNER/REPO ISSUE [ISSUE...]" >&2
	exit 2
fi

repo=$1
shift
issues=("$@")
me=$(gh api user --jq .login)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 1. Numbers referenced from the issue bodies.
for issue in "${issues[@]}"; do
	gh issue view "$issue" --repo "$repo" --json body --jq .body \
		| grep -oE "(https://github\.com/${repo}/(pull|issues)/[0-9]+|(^|[^A-Za-z0-9/])#[0-9]+)" \
		| grep -oE '[0-9]+$' || true
done | sort -un > "$tmp/refs"

# Drop the issue numbers themselves.
for issue in "${issues[@]}"; do
	grep -vx "$issue" "$tmp/refs" > "$tmp/refs.next" || true
	mv "$tmp/refs.next" "$tmp/refs"
done

# 2. Look each one up as a PR. Non-PRs land in not_prs.
fetch_pr() {
	local n=$1
	if out=$(gh pr view "$n" --repo "$repo" \
		--json number,title,url,state,isDraft,author,headRefName,baseRefName 2>/dev/null); then
		echo "$out" | jq -c '{number, title, url, state, isDraft, author: .author.login,
			branch: .headRefName, base: .baseRefName, from_issue: true}'
	else
		echo "$n" >> "$tmp/not_prs"
	fi
}
export -f fetch_pr
export repo tmp
touch "$tmp/not_prs"
# Numbers go in as positional arguments, never spliced into the -c string.
xargs -P 8 -I{} bash -c 'set -euo pipefail; fetch_pr "$1"' _ '{}' < "$tmp/refs" > "$tmp/prs.jsonl" \
	|| { echo "ERROR: looking up referenced PRs failed" >&2; exit 1; }

# 3. Pull the user's open PRs once and add any whose base is a branch already in the set.
#    Repeat until nothing new appears (a layer on a layer on a layer).
gh pr list --repo "$repo" --author "@me" --state open --limit 200 \
	--json number,title,url,state,isDraft,author,headRefName,baseRefName \
	| jq -c '.[] | {number, title, url, state, isDraft, author: .author.login,
		branch: .headRefName, base: .baseRefName, from_issue: false}' > "$tmp/mine.jsonl"

while :; do
	before=$(wc -l < "$tmp/prs.jsonl")
	jq -r '.branch' "$tmp/prs.jsonl" | sort -u > "$tmp/heads"
	jq -r '.number' "$tmp/prs.jsonl" | sort -u > "$tmp/have"
	while IFS= read -r line; do
		base=$(echo "$line" | jq -r .base)
		num=$(echo "$line" | jq -r .number)
		if grep -qx "$base" "$tmp/heads" && ! grep -qx "$num" "$tmp/have"; then
			echo "$line" >> "$tmp/prs.jsonl"
		fi
	done < "$tmp/mine.jsonl"
	after=$(wc -l < "$tmp/prs.jsonl")
	[ "$after" -eq "$before" ] && break
done

# 4. Compute depth in the chain and flag likely bundle PRs.
jq -s --arg me "$me" --arg repo "$repo" \
	--argjson issues "$(printf '%s\n' "${issues[@]}" | jq -s 'map(tonumber)')" \
	--argjson not_prs "$(sort -un "$tmp/not_prs" | jq -s 'map(tonumber)')" '
	# Depth follows base branches through OPEN PRs only, so closed earlier iterations
	# of a feature do not interleave with the live stack.
	(map(select(.state == "OPEN") | {key: .branch, value: .base}) | from_entries) as $baseOf
	| def depth($b; $n): if $n > 50 or ($baseOf[$b] | not) then 0 else 1 + depth($baseOf[$b]; $n + 1) end;
	map(. + {
		depth: depth(.base; 0),
		mine: (.author == $me),
		bundle_candidate: (.title | test("bundle|combined|playground"; "i"))
	  })
	| sort_by((if .state == "OPEN" then 0 else 1 end), .depth, .number)
	| {repo: $repo, issues: $issues, me: $me, prs: ., not_prs: $not_prs}
' "$tmp/prs.jsonl"
