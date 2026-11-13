#!/usr/bin/env bash
#
# Open the decision cards UI in a terminal the user can type into, wait
# for them to finish, and print the result JSON.
#
# Usage: launch.sh <decisions.json> [timeout-seconds]
#
# Exit codes:
#   0  finished, result JSON printed (status is "go" or "cancelled")
#   2  the decisions file is invalid (the reason is on stderr)
#   3  no terminal could be opened here: fall back to cards in the chat
#   4  timed out waiting; the window may still be open
#
# DECISION_CARDS_TERMINAL=tmux|iterm|terminal|linux|none forces a choice.

set -u

if [ $# -lt 1 ]; then
	echo "usage: launch.sh <decisions.json> [timeout-seconds]" >&2
	exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"
input="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
timeout="${2:-3600}"
result="${input%.json}.result.json"

python="$(command -v python3 || true)"
if [ -z "$python" ]; then
	echo "decision-cards: python3 not found" >&2
	exit 3
fi

"$python" "$here/decide.py" --check "$input" >/dev/null || exit 2
rm -f "$result"

# The new terminal runs this file, so quoting only has to be right once.
runner="$(mktemp "${TMPDIR:-/tmp}/decision-cards.XXXXXX")"
mv "$runner" "$runner.command"
runner="$runner.command"
{
	echo '#!/bin/sh'
	printf '%q %q %q %q\n' "$python" "$here/decide.py" "$input" "$result"
	printf '[ -f %q ] || echo %q > %q\n' "$result" '{"status": "cancelled", "answers": []}' "$result"
} >"$runner"
chmod +x "$runner"
trap 'rm -f "$runner"' EXIT

choice="${DECISION_CARDS_TERMINAL:-}"
if [ -z "$choice" ]; then
	if [ -n "${TMUX:-}" ]; then
		choice=tmux
	elif [ "$(uname)" = "Darwin" ] && [ -z "${SSH_CONNECTION:-}" ]; then
		case "${TERM_PROGRAM:-}" in
			iTerm.app) choice=iterm ;;
			*) choice=terminal ;;
		esac
	elif [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v x-terminal-emulator >/dev/null; then
		choice=linux
	else
		choice=none
	fi
fi

case "$choice" in
	tmux)
		# A popup blocks until the UI exits. Older tmux has no popups.
		tmux display-popup -E -w 78 -h 32 "$runner" 2>/dev/null ||
			tmux split-window -v "$runner" || exit 3
		;;
	iterm)
		osascript - "$runner" >/dev/null <<'APPLESCRIPT' || exit 3
on run argv
	tell application "iTerm"
		activate
		set cardWindow to (create window with default profile command (item 1 of argv))
		tell current session of cardWindow
			set columns to 78
			set rows to 32
		end tell
	end tell
end run
APPLESCRIPT
		;;
	terminal)
		# Whatever handles .command files, which is Terminal.app by default.
		open "$runner" || exit 3
		;;
	linux)
		x-terminal-emulator -e "$runner" >/dev/null 2>&1 &
		;;
	*)
		echo "decision-cards: no terminal available here" >&2
		exit 3
		;;
esac

waited=0
while [ ! -f "$result" ]; do
	if [ "$waited" -ge "$timeout" ]; then
		echo "decision-cards: no answer after ${timeout}s" >&2
		exit 4
	fi
	sleep 1
	waited=$((waited + 1))
done

cat "$result"
