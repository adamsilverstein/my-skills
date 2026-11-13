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
# DECISION_CARDS_TERMINAL=tmux|iterm|iterm-window|terminal|linux|none forces
# a choice.

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

# A launcher that stays in the foreground of this script runs here, so the
# timeout below still applies and a failed start can be told from a slow user.
launcher_pid=""
background() {
	"$@" >/dev/null 2>&1 &
	launcher_pid=$!
}

# True when the background launcher has exited with an error.
launcher_failed() {
	[ -n "$launcher_pid" ] || return 1
	kill -0 "$launcher_pid" 2>/dev/null && return 1
	wait "$launcher_pid"
	local status=$?
	launcher_pid=""
	[ "$status" -ne 0 ]
}

tmux_split_tried=""

case "$choice" in
	tmux)
		# A popup blocks until the UI exits. Older tmux has no popups; the
		# wait loop falls back to a split pane when the popup fails.
		background tmux display-popup -E -w 78 -h 32 "$runner"
		;;
	iterm | iterm-window)
		# Split the pane this session runs in, so the cards open right under
		# the conversation and the pane closes when they are done. A new
		# window is the fallback when that pane cannot be found.
		session="${ITERM_SESSION_ID:-}"
		session="${session#*:}"
		[ "$choice" = iterm-window ] && session=""
		osascript - "$runner" "$session" >/dev/null <<'APPLESCRIPT' || exit 3
on run argv
	set cardCommand to item 1 of argv
	set sessionId to item 2 of argv
	tell application "iTerm"
		if sessionId is not "" then
			repeat with aWindow in windows
				repeat with aTab in tabs of aWindow
					repeat with aSession in sessions of aTab
						if (id of aSession) is sessionId then
							tell aSession
								set cardSession to (split horizontally with default profile command cardCommand)
							end tell
							tell cardSession to select
							return
						end if
					end repeat
				end repeat
			end repeat
		end if
		activate
		set cardWindow to (create window with default profile command cardCommand)
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
		background x-terminal-emulator -e "$runner"
		;;
	*)
		echo "decision-cards: no terminal available here" >&2
		exit 3
		;;
esac

waited=0
while [ ! -f "$result" ]; do
	if launcher_failed && [ ! -f "$result" ]; then
		if [ "$choice" = tmux ] && [ -z "$tmux_split_tried" ]; then
			tmux_split_tried=1
			tmux split-window -v "$runner" 2>/dev/null && continue
		fi
		echo "decision-cards: the terminal did not start" >&2
		exit 3
	fi
	if [ "$waited" -ge "$timeout" ]; then
		if [ -n "$launcher_pid" ]; then
			kill "$launcher_pid" 2>/dev/null
			[ "$choice" = tmux ] && tmux display-popup -C 2>/dev/null
		fi
		echo "decision-cards: no answer after ${timeout}s" >&2
		exit 4
	fi
	sleep 1
	waited=$((waited + 1))
done

cat "$result"
