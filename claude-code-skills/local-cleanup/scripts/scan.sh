#!/bin/bash
# scan.sh - Read-only survey of local developer leftovers. Deletes nothing.
#
# Usage: bash scan.sh [output-dir]
#
# Writes TSV reports plus summary.md to the output dir (default: a new temp dir)
# and prints the summary. Tunables (env vars):
#   WORKTREES_DIR    worktree root            (default ~/repositories/worktrees)
#   DOWNLOADS_DIR    downloads folder         (default ~/Downloads)
#   RECENT_DAYS      skip worktrees with commits newer than this   (default 2)
#   IDLE_DAYS        node_modules-only tier: idle at least this    (default 7)
#   DOWNLOADS_DAYS   downloads older than this get archived        (default 14)

set -u

OUT="${1:-$(mktemp -d -t local-cleanup)}"
mkdir -p "$OUT"
WT="${WORKTREES_DIR:-$HOME/repositories/worktrees}"
DL="${DOWNLOADS_DIR:-$HOME/Downloads}"
RECENT_DAYS="${RECENT_DAYS:-2}"
IDLE_DAYS="${IDLE_DAYS:-7}"
DOWNLOADS_DAYS="${DOWNLOADS_DAYS:-14}"
RECENT_CUTOFF=$(date -v-"${RECENT_DAYS}"d +%Y-%m-%d)
IDLE_CUTOFF=$(date -v-"${IDLE_DAYS}"d +%Y-%m-%d)
ME=$(gh api user -q .login 2>/dev/null || echo "")

kb() { du -sk "$1" 2>/dev/null | cut -f1; }
gb() { awk -v k="${1:-0}" 'BEGIN{printf "%.1f GB", k/1048576}'; }

# --- 1. Worktrees -----------------------------------------------------------
# Columns: name size_kb nm_kb last_commit tracked_dirty untracked branch repo_dir unpushed
: > "$OUT/worktrees.tsv"; : > "$OUT/nongit.tsv"; : > "$OUT/repos.txt"
for path in "$WT"/*/; do
	d=$(basename "$path")
	if ! git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		printf '%s\t%s\n' "$d" "$(kb "$path")" >> "$OUT/nongit.tsv"
		continue
	fi
	common=$(cd "$path" && cd "$(git rev-parse --git-common-dir)" && pwd)
	repo_dir=$(dirname "$common")
	echo "$repo_dir" >> "$OUT/repos.txt"
	nm=0; [ -d "$path/node_modules" ] && nm=$(kb "$path/node_modules")
	status=$(git -C "$path" status --porcelain 2>/dev/null)
	dirty=$(printf '%s\n' "$status" | grep -v '^??' | grep -c . )
	untracked=$(printf '%s\n' "$status" | grep -c '^??')
	branch=$(git -C "$path" branch --show-current 2>/dev/null)
	unpushed=""
	[ -n "$branch" ] && unpushed=$(git -C "$path" rev-list --count '@{u}..HEAD' 2>/dev/null || echo noupstream)
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$d" "$(kb "$path")" "$nm" \
		"$(git -C "$path" log -1 --format=%cs)" "$dirty" "$untracked" "$branch" "$repo_dir" "$unpushed" \
		>> "$OUT/worktrees.tsv"
done
# Logs are disposable; other loose files (notes, playbooks) are only listed for review.
find "$WT" -maxdepth 1 -type f -name '*.log' > "$OUT/stray-files.txt"
find "$WT" -maxdepth 1 -type f ! -name '*.log' ! -name .DS_Store > "$OUT/review-loose-files.txt"

# --- 2. PR state per branch ------------------------------------------------------
# Query each repo's origin and its upstream parent. Own repos: every author.
: > "$OUT/prs.tsv"
sort -u "$OUT/repos.txt" | while read -r repo_dir; do
	slugs=$(cd "$repo_dir" && gh repo view --json nameWithOwner,parent \
		-q '[.nameWithOwner, (.parent // {} | if .owner then .owner.login + "/" + .name else empty end)] | .[]' 2>/dev/null)
	for slug in $slugs; do
		# Own repos: every author (agents open PRs there), but only branches pushed
		# to the user's own repo, so a fork PR with the same branch name never matches.
		author="--author=@me"; head=""
		[ "${slug%%/*}" = "$ME" ] && { author=""; head="select(.headRepositoryOwner.login == \"$ME\") | "; }
		gh pr list -R "$slug" $author --state all --limit 1000 \
			--json headRefName,headRepositoryOwner,state,number \
			-q ".[] | $head[\"$repo_dir\", .headRefName, .state, (.number|tostring), \"$slug\"] | @tsv" \
			>> "$OUT/prs.tsv" 2>/dev/null
	done
done

# --- 3. Running wp-env / docker mounts (never touch these worktrees) -------------
docker ps --format '{{.Names}}' 2>/dev/null | while read -r c; do
	docker inspect "$c" --format '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' 2>/dev/null
done | grep -o "$WT/[^/]*" | sed "s|$WT/||" | sort -u > "$OUT/in-use.txt"

# --- 4. Classify worktrees ------------------------------------------------------------
for f in tier-remove-worktree tier-node-modules review-merged-but-dirty keep-in-use keep; do : > "$OUT/$f.tsv"; done
awk -F'\t' -v recent="$RECENT_CUTOFF" -v idle="$IDLE_CUTOFF" -v OUT="$OUT" '
	BEGIN { rank["CLOSED"] = 1; rank["MERGED"] = 2; rank["OPEN"] = 3 }
	# A branch can have several PRs: OPEN beats MERGED beats CLOSED, whatever the order.
	FILENAME ~ /prs.tsv$/ {
		k = $1 SUBSEP $2; split(pr[k], cur, "#")
		if (!(k in pr) || rank[$3] > rank[cur[1]]) pr[k] = $3 "#" $4
		next
	}
	FILENAME ~ /in-use.txt$/ { use[$1] = 1; next }
	{
		state = ($7 == "") ? "DETACHED" : (($8 SUBSEP $7) in pr ? pr[$8 SUBSEP $7] : "NOPR")
		split(state, s, "#")
		clean = ($5 == 0 && $6 == 0 && ($9 == "0" || $9 == ""))
		row = $0 "\t" state
		if (use[$1]) { print row > (OUT "/keep-in-use.tsv"); next }
		if ((s[1] == "MERGED" || s[1] == "CLOSED") && clean && $4 < recent) { print row > (OUT "/tier-remove-worktree.tsv"); next }
		if ((s[1] == "MERGED" || s[1] == "CLOSED") && !clean) { print row > (OUT "/review-merged-but-dirty.tsv") }
		if ($3 > 0 && $4 < idle && $5 == 0) { print row > (OUT "/tier-node-modules.tsv"); next }
		print row > (OUT "/keep.tsv")
	}' "$OUT/prs.tsv" "$OUT/in-use.txt" "$OUT/worktrees.tsv"

# --- 5. wp-env environments whose source is gone or slated for removal -----------------
: > "$OUT/tier-wpenv.tsv"
if [ -d "$HOME/.wp-env" ]; then
	for env in "$HOME"/.wp-env/*/; do
		e=$(basename "$env")
		src=$(grep -ho '/Users/[^": ]*repositories[^": ]*' "$env"docker-compose.yml 2>/dev/null | head -1)
		wt=""; case "$src" in "$WT"/*) wt=${src#"$WT"/}; wt=${wt%%/*} ;; esac
		reason=""
		# No recognizable source path: unknown, so leave it alone.
		if [ -z "$src" ]; then continue
		elif [ ! -e "$src" ]; then reason=source-gone
		elif [ -n "$wt" ] && cut -f1 "$OUT/tier-remove-worktree.tsv" | grep -qx "$wt"; then reason=worktree-being-removed
		fi
		[ -n "$reason" ] && printf '%s\t%s\t%s\t%s\n' "$e" "$(kb "$env")" "$reason" "${wt:-$src}" >> "$OUT/tier-wpenv.tsv"
	done
fi

# --- 6. Docker --------------------------------------------------------------------------
docker system df > "$OUT/docker-df.txt" 2>&1
docker ps -aq --filter status=exited 2>/dev/null | wc -l | tr -d ' ' > "$OUT/docker-exited-count.txt"
# Unused volumes, minus databases of stopped wp-env envs that still exist.
: > "$OUT/docker-dangling-volumes.txt"
for v in $(docker volume ls -qf dangling=true 2>/dev/null); do
	proj=$(docker volume inspect "$v" -f '{{index .Labels "com.docker.compose.project"}}' 2>/dev/null)
	[ -n "$proj" ] && [ -d "$HOME/.wp-env/$proj" ] && continue
	echo "$v" >> "$OUT/docker-dangling-volumes.txt"
done

# --- 7. Downloads ------------------------------------------------------------------------
find "$DL" -maxdepth 1 -mindepth 1 -mtime +"$DOWNLOADS_DAYS" ! -name .localized ! -name .DS_Store \
	-exec du -sk {} + 2>/dev/null > "$OUT/downloads-old.tsv"

# --- 8. Caches -----------------------------------------------------------------------------
: > "$OUT/caches.tsv"
# Playwright is left out: it deletes browser builds no installed client needs on
# its next `playwright install`, and only it knows which builds each version needs.
for c in "$HOME/.npm/_cacache" "$HOME/Library/Caches/Cypress" \
	"$HOME/.cache/puppeteer" "$HOME/.cache/codex-runtimes" "$HOME/Library/Caches/node-gyp" \
	"$HOME/Library/Caches/composer" "$HOME/Library/Caches/Yarn"; do
	[ -e "$c" ] && printf '%s\t%s\n' "$c" "$(kb "$c")" >> "$OUT/caches.tsv"
done

# --- Summary ---------------------------------------------------------------------------------
sum() { awk -F'\t' -v c="$2" '{t+=$c} END{print t+0}' "$1"; }
cnt() { awk 'NF{n++} END{print n+0}' "$1" 2>/dev/null; }
{
	echo "# Local cleanup scan - $(date +%Y-%m-%d)"
	echo
	echo "Free disk: $(df -h "$HOME" | awk 'NR==2{print $4 " of " $2}')"
	echo
	echo "| # | Category | Count | Size |"
	echo "|---|---|---|---|"
	echo "| 1 | Worktrees to remove (PR merged/closed, clean, pushed, idle ${RECENT_DAYS}d+) | $(cnt "$OUT/tier-remove-worktree.tsv") | $(gb "$(sum "$OUT/tier-remove-worktree.tsv" 2)") |"
	echo "| 2 | node_modules in kept worktrees idle ${IDLE_DAYS}d+ | $(cnt "$OUT/tier-node-modules.tsv") | $(gb "$(sum "$OUT/tier-node-modules.tsv" 3)") |"
	echo "| 3 | wp-env environments (source gone or being removed) | $(cnt "$OUT/tier-wpenv.tsv") | $(gb "$(sum "$OUT/tier-wpenv.tsv" 2)") |"
	echo "| 4 | Docker: $(cat "$OUT/docker-exited-count.txt") stopped containers, $(cnt "$OUT/docker-dangling-volumes.txt") unused volumes, build cache | - | see docker-df.txt |"
	echo "| 5 | Downloads older than ${DOWNLOADS_DAYS}d (archive) | $(cnt "$OUT/downloads-old.tsv") | $(gb "$(sum "$OUT/downloads-old.tsv" 1)") |"
	echo "| 6 | Stray files and non-git folders in worktrees dir | $(( $(cnt "$OUT/stray-files.txt") + $(cnt "$OUT/nongit.tsv") )) | $(gb "$(sum "$OUT/nongit.tsv" 2)")+ |"
	echo "| 7 | Tool caches | $(cnt "$OUT/caches.tsv") | $(gb "$(sum "$OUT/caches.tsv" 2)") |"
	echo
	echo "Kept: $(cnt "$OUT/keep-in-use.tsv") worktrees mounted by running containers; $(cnt "$OUT/review-merged-but-dirty.tsv") merged/closed worktrees with local changes or unpushed commits (see review-merged-but-dirty.tsv)."
	echo
	echo "Reports: $OUT"
} > "$OUT/summary.md"
cat "$OUT/summary.md"
