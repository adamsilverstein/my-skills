#!/usr/bin/env bash
# Show what Claude has posted on Adam's behalf.
#
# Usage: show-posts.sh [today | YYYY-MM-DD | all]   (default: today)
#
# Understands two entry shapes under a day heading:
#   - HH:MM TZ | kind | target | url | review: ...        (written by log-post.sh)
#   ## YYYY-MM-DD - <title> followed by a URL line          (free-form entries from sessions without the skill)
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

entries=$(awk -v d="$day" '
	/^## / {
		prefix = "## " d
		insec = (index($0, prefix) == 1)
		pending = ""
		if (insec && length($0) > length(prefix)) {
			pending = substr($0, length(prefix) + 1)
			sub(/^[ -]+/, "", pending)
		}
		next
	}
	!insec { next }
	/^- / { print; next }
	/^https?:\/\// {
		if (pending != "") { print "- " pending " | " $0; pending = "" }
		else { print "- " $0 }
		next
	}
' "$LOG")

if [ -z "$entries" ]; then
	echo "Nothing posted on $day."
else
	echo "## $day"
	echo "$entries"
fi
