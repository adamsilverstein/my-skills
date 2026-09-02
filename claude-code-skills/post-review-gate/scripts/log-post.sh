#!/usr/bin/env bash
# Append one entry to the central record of everything Claude has posted on Adam's behalf.
#
# Usage: log-post.sh <kind> <target> <url> <review> [draft-path]
#   kind    comment | review-reply | issue | pr | trac-ticket | trac-comment
#   target  where it went, e.g. "WordPress/gutenberg#81397", "wordpress-develop PR 9012", "Trac #62345"
#   url     link to the posted comment, issue, PR, or ticket
#   review  edited | approved | unreviewed | short
#           edited      Adam changed the draft file before it went out
#           approved    Adam said to post it in chat, file unchanged
#           unreviewed  the five minute window passed with no word from Adam
#           short       a one-liner that skipped the review gate
set -u

LOG="${CLAUDE_POSTS_LOG:-$HOME/.claude/posts-log.md}"

if [ $# -lt 4 ]; then
	echo "Usage: log-post.sh <kind> <target> <url> <review> [draft-path]" >&2
	exit 2
fi

kind=$1
target=$2
url=$3
review=$4
draft=${5:-}

case "$review" in
	edited|approved|unreviewed|short) ;;
	*) echo "ERROR: review must be edited, approved, unreviewed, or short (got '$review')" >&2; exit 2 ;;
esac

today=$(date +%Y-%m-%d)
now=$(date "+%H:%M %Z")

if [ ! -f "$LOG" ]; then
	printf "# Posts made on Adam's behalf\n\nOne line per post, grouped by day. Written by the post-review-gate skill.\n" > "$LOG"
fi

if ! grep -q "^## $today\$" "$LOG"; then
	printf '\n## %s\n\n' "$today" >> "$LOG"
fi

line="- $now | $kind | $target | $url | review: $review"
if [ -n "$draft" ]; then
	line="$line | draft: ${draft/#$HOME/~}"
fi

echo "$line" >> "$LOG"
echo "Logged to $LOG:"
echo "$line"
