#!/usr/bin/env bash
# Alert Adam that a draft is ready, then wait for him to edit it, delete it,
# or run out the clock. Run this in the background (run_in_background: true).
#
# Usage: wait-for-review.sh <draft.md> [timeout-seconds] [settle-seconds]
#
# Prints exactly one final line:
#   EDITED <path>   Adam saved changes and stopped editing for <settle> seconds. Post the file as it is on disk.
#   DELETED <path>  Adam removed the file. Do not post.
#   TIMEOUT <path>  No edits within <timeout> seconds. Post as drafted.
set -u

draft="${1:-}"
timeout="${2:-300}"
settle="${3:-20}"

if [ -z "$draft" ] || [ ! -f "$draft" ]; then
	echo "ERROR: draft file not found: '$draft'"
	exit 2
fi

name=$(basename "$draft")
minutes=$(( (timeout + 59) / 60 ))

mtime() {
	stat -f %m "$1" 2>/dev/null || echo missing
}

# Alert: the terminal bell only. Claude Code captures this script's stdout, so
# ring the bell on the controlling terminal when there is one. The dependable
# bell is Claude Code's own: with preferredNotifChannel set to terminal_bell in
# ~/.claude/settings.json it rings when the turn ends and waits for input.
printf '\a' > /dev/tty 2>/dev/null || true
echo "Waiting up to $minutes min for edits to $name"

start=$(mtime "$draft")
last=$start
changed_at=0
missing_polls=0
deadline=$(( SECONDS + timeout ))

while :; do
	now=$(mtime "$draft")

	# Some editors briefly remove the file while saving; require two consecutive misses.
	if [ "$now" = missing ]; then
		missing_polls=$(( missing_polls + 1 ))
		if [ "$missing_polls" -ge 2 ]; then
			echo "DELETED $draft"
			exit 0
		fi
		sleep 2
		continue
	fi
	missing_polls=0

	if [ "$now" != "$last" ]; then
		last=$now
		changed_at=$SECONDS
	fi

	if [ "$last" != "$start" ] && [ $(( SECONDS - changed_at )) -ge "$settle" ]; then
		echo "EDITED $draft"
		exit 0
	fi

	if [ "$last" = "$start" ] && [ "$SECONDS" -ge "$deadline" ]; then
		echo "TIMEOUT $draft"
		exit 0
	fi

	sleep 2
done
