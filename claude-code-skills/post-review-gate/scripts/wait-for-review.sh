#!/usr/bin/env bash
# Wait for Adam to edit a draft, delete it, or run out the clock.
# Run this in the background (run_in_background: true).
#
# Usage: wait-for-review.sh <draft.md> [timeout-seconds] [settle-seconds] [grace-seconds]
#
# Prints exactly one final line:
#   EDITED <path>   The file changed and then sat still for <settle> seconds, or an edit was
#                   still in progress <grace> seconds past the deadline. Post the file as it is on disk.
#   DELETED <path>  Adam removed the file. Do not post.
#   TIMEOUT <path>  No change within <timeout> seconds. Post as drafted.
#
# The script never runs longer than timeout + grace seconds.
set -u

draft="${1:-}"
timeout="${2:-300}"
settle="${3:-20}"
grace="${4:-120}"

if [ -z "$draft" ] || [ ! -f "$draft" ]; then
	echo "ERROR: draft file not found: '$draft'"
	exit 2
fi

name=$(basename "$draft")
minutes=$(( (timeout + 59) / 60 ))

# Content fingerprint rather than mtime: stat has one-second resolution and some
# editors preserve mtime. Prints "missing" when the file is gone.
fingerprint() {
	if [ -f "$1" ]; then
		shasum -a 256 "$1" 2>/dev/null | cut -d ' ' -f 1
	else
		echo missing
	fi
}

# Alert: the terminal bell only. Claude Code captures this script's stdout, so
# ring the bell on the controlling terminal when there is one. The dependable
# bell is Claude Code's own: with preferredNotifChannel set to terminal_bell in
# ~/.claude/settings.json it rings when the turn ends and waits for input.
{ printf '\a' > /dev/tty; } 2>/dev/null || true
echo "Waiting up to $minutes min for edits to $name"

start=$(fingerprint "$draft")
last=$start
changed_at=0
missing_polls=0
deadline=$(( SECONDS + timeout ))
hard_stop=$(( deadline + grace ))

while :; do
	now=$(fingerprint "$draft")

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

	edited=0
	[ "$last" != "$start" ] && edited=1

	if [ "$edited" = 1 ] && [ $(( SECONDS - changed_at )) -ge "$settle" ]; then
		echo "EDITED $draft"
		exit 0
	fi

	if [ "$edited" = 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
		echo "TIMEOUT $draft"
		exit 0
	fi

	# An edit still in progress past the deadline gets a grace period, then posts as is.
	if [ "$edited" = 1 ] && [ "$SECONDS" -ge "$hard_stop" ]; then
		echo "EDITED $draft"
		exit 0
	fi

	sleep 2
done
