#!/bin/bash
# apply.sh - Carry out one approved cleanup category from a scan.sh output dir.
#
# Usage: bash apply.sh <scan-dir> <category> [archive-dir]
#   worktrees     git worktree remove each tier-remove-worktree.tsv entry (re-checks it is
#                 clean, unmounted and idle)
#   node-modules  delete node_modules in each tier-node-modules.tsv entry
#   wpenv         remove containers, volumes, networks and ~/.wp-env dir for tier-wpenv.tsv
#                 (run after worktrees: envs of skipped worktrees are kept)
#   docker        stopped containers, volumes that were unused AT SCAN TIME, build cache
#   downloads     move old Downloads items to <archive-dir> (never overwrites)
#   strays        move stray files and non-git folders in the worktrees dir to the Trash
#   caches        every path in caches.tsv (npm, Cypress, Puppeteer, codex, node-gyp, Composer, Yarn)
#
# Long categories (worktrees, node-modules) should run in the background.

set -u
OUT="$1"; CAT="$2"; ARCHIVE="${3:-}"
WT="${WORKTREES_DIR:-$HOME/repositories/worktrees}"
DL="${DOWNLOADS_DIR:-$HOME/Downloads}"

case "$CAT" in
worktrees)
	ok=0; skipped=0
	recent=$(date -v-"${RECENT_DAYS:-2}"d +%Y-%m-%d)
	# Containers started since the scan count too.
	in_use=$(docker ps -q 2>/dev/null | xargs -n1 docker inspect --format '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' 2>/dev/null)
	while IFS=$'\t' read -r d _; do
		p="$WT/$d"; [ -d "$p" ] || continue
		if [ -n "$(git -C "$p" status --porcelain 2>/dev/null)" ]; then
			echo "SKIP $d: changed since scan"; skipped=$((skipped+1)); continue
		fi
		if printf '%s\n' "$in_use" | awk -v p="$p" '$0 == p || index($0, p "/") == 1 {f=1} END{exit !f}'; then
			echo "SKIP $d: mounted by a running container"; skipped=$((skipped+1)); continue
		fi
		if [[ ! "$(git -C "$p" log -1 --format=%cs)" < "$recent" ]]; then
			echo "SKIP $d: new commit since scan"; skipped=$((skipped+1)); continue
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
	docker info >/dev/null 2>&1 || { echo "wpenv: Docker is not running, nothing removed"; exit 1; }
	failed=0
	while IFS=$'\t' read -r e _ reason wt; do
		# Keep the env of a worktree that the worktrees step skipped.
		if [ "$reason" = worktree-being-removed ] && [ -d "$WT/$wt" ]; then
			echo "SKIP $e: worktree $wt still exists"; continue
		fi
		ok=1
		for kind in container volume network; do
			if [ $kind = container ]; then ids=$(docker ps -aq --filter "label=com.docker.compose.project=$e")
			else ids=$(docker $kind ls -q --filter "label=com.docker.compose.project=$e"); fi
			[ -n "$ids" ] && { docker $kind rm -f $ids >/dev/null 2>&1 || ok=0; }
		done
		# Keep the compose dir until its Docker resources are gone, so a rescan finds it.
		if [ $ok = 1 ]; then rm -rf "$HOME/.wp-env/$e"; else echo "FAIL $e: Docker resources remain, dir kept"; failed=$((failed+1)); fi
	done < "$OUT/tier-wpenv.tsv"
	echo "wpenv: $(ls "$HOME/.wp-env" | wc -l | tr -d ' ') environments remain, $failed failed"
	[ $failed = 0 ]
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
	# Exactly the paths scan.sh lists in caches.tsv.
	while IFS=$'\t' read -r c _; do rm -rf "${c:?}"; done < "$OUT/caches.tsv"
	echo "caches: cleared $(awk 'NF{n++} END{print n+0}' "$OUT/caches.tsv")"
	;;
*) echo "unknown category: $CAT"; exit 1 ;;
esac
