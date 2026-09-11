#!/usr/bin/env bash
# New feedback on a feature's issues and PRs since a timestamp.
#
# Usage: feature-feedback.sh OWNER/REPO SINCE TARGET [TARGET...] [--exclude LOGIN]
#   SINCE    ISO 8601 UTC timestamp, e.g. 2026-09-10T00:00:00Z. Use 1970-01-01T00:00:00Z for everything.
#   TARGET   issue or PR number; the script works out which
#   --exclude LOGIN   skip this author (default: the gh user, so Adam's own comments drop out)
#
# Prints one JSON object per line, oldest first:
#
#   { "target": 80427, "target_kind": "pr" | "issue",
#     "kind": "comment" | "review" | "review-comment",
#     "author", "created_at", "url",
#     "state":    for reviews: APPROVED | CHANGES_REQUESTED | COMMENTED | DISMISSED
#     "resolved": for review-comments: true | false
#     "path":     for review-comments: the file the thread is on
#     "is_bot":   true for [bot] accounts and the usual review bots (CodeRabbit, Copilot, ...)
#     "body":     first 600 characters }
#
# Read-only. The digest and any replies are Claude's job, through post-review-gate.
set -euo pipefail

exclude=""
args=()
while [ $# -gt 0 ]; do
	case "$1" in
		--exclude) exclude=$2; shift 2 ;;
		*) args+=("$1"); shift ;;
	esac
done

if [ ${#args[@]} -lt 3 ]; then
	echo "Usage: feature-feedback.sh OWNER/REPO SINCE TARGET [TARGET...] [--exclude LOGIN]" >&2
	exit 2
fi

repo=${args[0]}
since=${args[1]}
targets=("${args[@]:2}")
owner=${repo%%/*}
name=${repo##*/}
[ -z "$exclude" ] && exclude=$(gh api user --jq .login)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

one_target() {
	local n=$1 out="$tmp/$1.jsonl"
	local kind="issue"
	gh api "repos/$repo/pulls/$n" --jq .number >/dev/null 2>&1 && kind="pr"

	# Conversation comments: same endpoint for issues and PRs.
	gh api "repos/$repo/issues/$n/comments?since=$since&per_page=100" --paginate \
		| jq -c --argjson n "$n" --arg kind "$kind" --arg since "$since" --arg ex "$exclude" '
			.[] | select(.created_at > $since and .user.login != $ex)
			| {target: $n, target_kind: $kind, kind: "comment", author: .user.login,
			   created_at: .created_at, url: .html_url, body: .body[0:600]}' >> "$out"

	[ "$kind" = "pr" ] || return 0

	# Reviews with a body or a decision.
	gh api "repos/$repo/pulls/$n/reviews?per_page=100" --paginate \
		| jq -c --argjson n "$n" --arg since "$since" --arg ex "$exclude" '
			.[] | select(.submitted_at > $since and .user.login != $ex
			             and ((.body | length) > 0 or .state != "COMMENTED"))
			| {target: $n, target_kind: "pr", kind: "review", author: .user.login,
			   created_at: .submitted_at, url: .html_url, state: .state, body: .body[0:600]}' >> "$out"

	# Review threads via GraphQL, which is the only place resolved state lives.
	gh api graphql -F owner="$owner" -F name="$name" -F number="$n" -f query='
		query($owner:String!, $name:String!, $number:Int!) {
		  repository(owner:$owner, name:$name) { pullRequest(number:$number) {
		    reviewThreads(first:100) { nodes {
		      isResolved path
		      comments(first:50) { nodes { author { login } createdAt url body } }
		    } }
		  } } }' \
		| jq -c --argjson n "$n" --arg since "$since" --arg ex "$exclude" '
			.data.repository.pullRequest.reviewThreads.nodes[] as $t
			| $t.comments.nodes[]
			| select(.createdAt > $since and .author.login != $ex)
			| {target: $n, target_kind: "pr", kind: "review-comment", author: .author.login,
			   created_at: .createdAt, url, resolved: $t.isResolved, path: $t.path,
			   body: .body[0:600]}' >> "$out"
}
export -f one_target
export repo owner name since exclude tmp

printf '%s\n' "${targets[@]}" | xargs -P 6 -I{} bash -c 'one_target {}'

# Bots do not carry the [bot] suffix everywhere (GraphQL drops it), so name the usual ones.
cat "$tmp"/*.jsonl 2>/dev/null | jq -s -c '
	sort_by(.created_at)
	| .[]
	| .is_bot = ((.author | test("\\[bot\\]$"))
		or (.author | IN("coderabbitai", "copilot-pull-request-reviewer", "copilot", "github-actions", "dependabot")))'
