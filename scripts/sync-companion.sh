#!/usr/bin/env bash
# scripts/sync-companion.sh — pull the latest companion from upstream htpx and
# refresh companion.lock. The consumer-side half of the vendoring contract.
# ──────────────────────────────────────────────────────────────────────────────
# offensive/companion/ is a vendored `git subtree` of Gerrrt/htpx (provenance in
# companion.lock). Upstream is the source of truth; this is the one command that
# re-pulls htpx `main` into the prefix AND records the new git-subtree-split sha in
# companion.lock, so the lock can never drift from what's actually vendored. It is
# the convenience wrapper the lock's own header points at — nothing it does is
# magic, just the documented `git subtree pull --squash` + the sha bump in one step.
#
#   scripts/sync-companion.sh                  # pull from the URL derived from companion.lock
#   scripts/sync-companion.sh <remote-or-url>  # pull from a specific remote / URL / local clone
#   scripts/sync-companion.sh --check          # report whether upstream is ahead; touch nothing
#
# A bare run leaves you with TWO things to do before it's a finished change:
#   1. eyeball the diff under offensive/companion/, and
#   2. run offensive/companion/gen-views.sh --check — an upstream content change can
#      shift the generated blocks in hacktheplanet / PURPLE-TEAM.md, which this
#      script does NOT touch (that's gen-views.sh's job). Fix + commit both together.
#
# Pre-reqs the script enforces: a clean working tree (git subtree pull refuses to
# run otherwise) and a companion.lock it can read the repo/branch/prefix from.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PREFIX="offensive/companion"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
LOCK="$REPO_ROOT/companion.lock"
cd -- "$REPO_ROOT"

die() { echo "sync-companion: $*" >&2; exit 1; }

CHECK=0
REMOTE_ARG=""
for a in "$@"; do
  case "$a" in
    --check) CHECK=1 ;;
    -*) die "unknown option: $a" ;;
    *) [[ -z "$REMOTE_ARG" ]] || die "only one remote/URL may be given"; REMOTE_ARG="$a" ;;
  esac
done

[[ -f "$LOCK" ]] || die "$LOCK not found — is the companion subtree vendored?"

# Pull the provenance out of the lock (the same fields gen-views/CI rely on).
lock_field() { sed -n -E "s/^$1=//p" "$LOCK" | head -n1; }
repo="$(lock_field companion_repo)"
branch="$(lock_field companion_branch)"
old_sha="$(lock_field companion_sha)"
[[ -n "$repo" ]]   || die "companion_repo missing from $LOCK"
[[ -n "$branch" ]] || die "companion_branch missing from $LOCK"

# Remote precedence: explicit arg → a git remote literally named in the lock →
# the GitHub HTTPS URL derived from companion_repo. The arg lets you sync from a
# fork, an ssh remote, or a local htpx clone without editing the lock.
if [[ -n "$REMOTE_ARG" ]]; then
  remote="$REMOTE_ARG"
elif git remote get-url "$repo" >/dev/null 2>&1; then
  remote="$repo"
else
  remote="https://github.com/$repo.git"
fi

echo "sync-companion: prefix=$PREFIX  remote=$remote  branch=$branch"
echo "sync-companion: locked at  ${old_sha:-<none>}"

# --check: peek at upstream without mutating the tree or the lock. Fetch the tip
# and compare; report ahead / up-to-date. Exit 0 either way (informational) unless
# the fetch itself fails.
if [[ "$CHECK" == 1 ]]; then
  upstream_sha="$(git ls-remote "$remote" "$branch" 2>/dev/null | awk 'NR==1{print $1}')"
  [[ -n "$upstream_sha" ]] || die "could not read $branch from $remote"
  echo "sync-companion: upstream ${branch} tip is $upstream_sha"
  if [[ "$upstream_sha" == "$old_sha" ]]; then
    echo "sync-companion: up to date — nothing to pull."
  else
    echo "sync-companion: upstream is AHEAD of the lock — run without --check to pull."
  fi
  exit 0
fi

# A subtree pull rewrites tracked files and makes a merge commit, so the tree must
# be clean first — fail early with a clear message rather than letting git do it.
git diff --quiet && git diff --cached --quiet \
  || die "working tree not clean — commit or stash first (git subtree pull needs a clean tree)."

before="$(git rev-parse HEAD)"

echo "sync-companion: git subtree pull --prefix=$PREFIX $remote $branch --squash"
git subtree pull --prefix="$PREFIX" "$remote" "$branch" --squash

after="$(git rev-parse HEAD)"
if [[ "$before" == "$after" ]]; then
  echo "sync-companion: already up to date — no new commits, lock unchanged."
  exit 0
fi

# Pull the new split sha from the squash commit's `git-subtree-split:` trailer —
# the SAME value the lock records, read straight back out of the commit git just
# wrote (don't recompute it; `git subtree split` would synthesize a different sha).
new_sha="$(git log --format='%b' "$before..$after" \
            | sed -n -E 's/^[[:space:]]*git-subtree-split:[[:space:]]*([0-9a-f]+).*/\1/p' \
            | head -n1)"
[[ -n "$new_sha" ]] || die "pulled new commits but found no git-subtree-split trailer — bump companion_sha in $LOCK by hand."

# Rewrite only the companion_sha line; leave the header + repo/branch untouched.
tmp="$(mktemp)"
awk -v sha="$new_sha" '/^companion_sha=/{print "companion_sha=" sha; next} {print}' "$LOCK" >"$tmp"
mv -- "$tmp" "$LOCK"

echo "sync-companion: companion.lock  ${old_sha:-<none>} -> $new_sha"
cat <<EOF

sync-companion: pulled. Next:
  1. review the diff:   git diff $before -- $PREFIX
  2. drift-check views: offensive/companion/gen-views.sh --check
     (regenerate + commit if it reports drift: offensive/companion/gen-views.sh)
  3. commit companion.lock together with the subtree pull.
EOF
