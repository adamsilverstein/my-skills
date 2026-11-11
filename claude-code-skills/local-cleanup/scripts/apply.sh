#!/bin/bash
# apply.sh - Carry out one approved cleanup category from a scan.sh output dir.
#
# Usage: bash apply.sh <scan-dir> <category> [archive-dir]
#   worktrees     git worktree remove each tier-remove-worktree.tsv entry (re-checks it is clean)
#   node-modules  delete node_modules in each tier-node-modules.tsv entry
#   wpenv         remove containers, volumes, networks and ~/.wp-env dir for tier-wpenv.tsv
#   docker        stopped containers, volumes that were unused AT SCAN TIME, build cache
#   downloads     move old Downloads items to <archive-dir> (never overwrites)
#   strays        move stray files and non-git folders in the worktrees dir to the Trash
#   caches        npm, Cypress, Puppeteer, codex caches; old Playwright browser builds only
#
# Long categories (worktrees, node-modules) should run in the background.

set -u
OUT="$1"; CAT="$2"; ARCHIVE="${3:-}"
WT="${WORKTREES_DIR:-$HOME/repositories/worktrees}"
DL="${DOWNLOADS_DIR:-$HOME/Downloads}"

case "$CAT" in
worktrees)
	ok=0; skipped=0
	while IFS=$'\t' read -r d _; do
		p="$WT/$d"; [ -d "$p" ] || continue
		if [ -n "$(git -C "$p" status --porcelain 2>/dev/null)" ]; then
			echo "SKIP $d: changed since scan"; skipped=$((skipped+1)); continue
		fi
		# No --force: git refuses if anything uncommitted appeared.
		if git -C "$p" worktree remove "$p"; then ok=$((ok+1)); else skipped=$((skipped+1)); fi
	done < "$OUT/tier-remove-worktree.tsv"
	cut -f8 "$OUT/worktrees.tsv" | sort -u | while read -r r; do git -C "$r" worktree prune; done
	echo "worktrees: removed=$ok skipped=$skipped"
	;;
node-modules)
	n=0
	while IFS=$'\t' read -r d _; do
		[ -d "$WT/$d/node_modules" ] || continue
		# Nested workspace node_modules too (Gutenberg packages/*/node_modules).
		find "$WT/$d" -name node_modules -type d -prune -exec rm -rf {} + 2>/dev/null
		n=$((n+1))
	done < "$OUT/tier-node-modules.tsv"
	echo "node-modules: cleared in $n worktrees"
	;;
wpenv)
	while IFS=$'\t' read -r e _; do
		ids=$(docker ps -aq --filter "label=com.docker.compose.project=$e")
		[ -n "$ids" ] && docker rm -f $ids >/dev/null 2>&1
		ids=$(docker volume ls -q --filter "label=com.docker.compose.project=$e")
		[ -n "$ids" ] && docker volume rm $ids >/dev/null 2>&1
		ids=$(docker network ls -q --filter "label=com.docker.compose.project=$e")
		[ -n "$ids" ] && docker network rm $ids >/dev/null 2>&1
		rm -rf "$HOME/.wp-env/$e"
	done < "$OUT/tier-wpenv.tsv"
	echo "wpenv: $(ls "$HOME/.wp-env" | wc -l | tr -d ' ') environments remain"
	;;
docker)
	docker container prune -f | tail -1
	# Not `volume prune -a`: after the container prune it would also delete the
	# databases of stopped environments the user is keeping.
	while read -r v; do docker volume rm "$v" >/dev/null 2>&1; done < "$OUT/docker-dangling-volumes.txt"
	docker builder prune -af | tail -1
	docker system df
	;;
downloads)
	[ -d "$ARCHIVE" ] || { echo "archive dir missing or drive not mounted: $ARCHIVE"; exit 1; }
	n=0; f=0
	while IFS=$'\t' read -r _ p; do
		[ -e "$p" ] || continue
		b=$(basename "$p"); t="$ARCHIVE/$b"
		[ -e "$t" ] && t="$ARCHIVE/${b%.*}-moved-$(date +%Y-%m-%d).${b##*.}"
		if mv -n "$p" "$t"; then n=$((n+1)); else f=$((f+1)); fi
	done < "$OUT/downloads-old.tsv"
	echo "downloads: moved=$n failed=$f"
	;;
strays)
	# Arrays, not unquoted strings: zsh does not word-split, and file names may have spaces.
	items=()
	while read -r f; do [ -e "$f" ] && items+=("$f"); done < "$OUT/stray-files.txt"
	while IFS=$'\t' read -r d _; do [ -e "$WT/$d" ] && items+=("$WT/$d"); done < "$OUT/nongit.tsv"
	[ ${#items[@]} -gt 0 ] && trash "${items[@]}"
	echo "strays: trashed ${#items[@]}"
	;;
caches)
	rm -rf "$HOME/.npm/_cacache" "$HOME/Library/Caches/Cypress" "$HOME/.cache/puppeteer" "$HOME/.cache/codex-runtimes"
	pw="$HOME/Library/Caches/ms-playwright"
	if [ -d "$pw" ]; then
		# Keep the newest build of each browser so tests run without a download.
		for b in $(ls "$pw" | sed -E 's/-[0-9]+$//' | sort -u); do
			ls "$pw" | grep -E "^$b-[0-9]+$" | sort -t- -k2 -n -r | tail -n +2 | while read -r old; do rm -rf "${pw:?}/$old"; done
		done
	fi
	echo "caches: cleared; playwright now $(du -sh "$pw" 2>/dev/null | cut -f1)"
	;;
*) echo "unknown category: $CAT"; exit 1 ;;
esac
