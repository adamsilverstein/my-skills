#!/usr/bin/env bash
# Show what Claude has posted on Adam's behalf.
#
# Usage: show-posts.sh [today | YYYY-MM-DD | all]   (default: today)
set -u

LOG="${CLAUDE_POSTS_LOG:-$HOME/.claude/posts-log.md}"
day=${1:-today}

if [ ! -f "$LOG" ]; then
	echo "No posts recorded yet ($LOG does not exist)."
	exit 0
fi

if [ "$day" = all ]; then
	cat "$LOG"
	exit 0
fi

if [ "$day" = today ]; then
	day=$(date +%Y-%m-%d)
fi

entries=$(awk -v h="## $day" '$0 == h { p = 1; next } /^## / { p = 0 } p' "$LOG" | grep '^- ')

if [ -z "$entries" ]; then
	echo "Nothing posted on $day."
else
	echo "## $day"
	echo "$entries"
fi
