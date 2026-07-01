#!/usr/bin/env bash
# test/check-companion-freshness.sh — is the vendored offensive/companion/ subtree BEHIND upstream?
# ──────────────────────────────────────────────────────────────────────────────
# The vendored offensive/companion/ here is a git-subtree copy of dotgibson/htpx (the
# standalone red<->blue pentest companion; provenance in companion.lock). Nothing on
# THIS side tracked whether that copy had fallen behind upstream — so a fix landing in
# htpx could sit un-pulled here indefinitely. This is the consumer-side freshness
# watcher: it asks whether the vendored commit (companion.lock's companion_sha) is now
# BEHIND upstream's tip, i.e. there are companion updates this repo hasn't pulled. A
# behind result is the NUDGE to run scripts/sync-companion.sh, not a hard error in
# normal development — so it lives in a SCHEDULED workflow.
#
# This mirrors test/check-core-freshness.sh (the watcher for the vendored core/
# subtree); the only differences are the lock file (companion.lock), its field names
# (companion_repo / companion_branch / companion_sha), and the remediation
# (scripts/sync-companion.sh, not a raw `git subtree pull`).
#
# Exit codes (matching dotfiles-core's drift-check convention — see
# core/scripts/update-plugins.sh --check, and test/check-core-freshness.sh):
#   0  current, OR a graceful skip (no git, offline/restricted, not a subtree checkout)
#   2  vendored offensive/companion/ is BEHIND upstream (drift — the nudge to sync)
#   1  a genuine hard failure (e.g. a malformed companion.lock)
# The workflow branches on these so a skip, a drift, and a real error each render the
# right step summary. Override the upstream/branch with COMPANION_UPSTREAM / COMPANION_BRANCH.
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

# Palette + glyphs from the VENDORED shared bash UX lib (core/lib/ux.sh) — ONE colour/glyph
# rule instead of hand-rolled copies that drift. If core/ is incomplete the lib won't be
# readable, so fall back to no colour and ASCII glyphs rather than fail to source it; the
# explicit companion.lock presence check below is what actually decides "not a subtree checkout".
if [[ -r "$REPO/core/lib/ux.sh" ]]; then
  # shellcheck source=/dev/null
  source "$REPO/core/lib/ux.sh"
  c_g=$UX_GRN c_y=$UX_YEL c_r=$UX_RED c_0=$UX_RST
else
  c_g='' c_y='' c_r='' c_0=''
fi
# ASCII fallbacks when ux.sh is absent; when it's present these are already the
# locale-correct glyph (✓/⚠/… on UTF-8, ok/!/… otherwise), so := leaves them be.
: "${UX_OK:=ok}" "${UX_WARN:=!}" "${UX_ERR:=x}" "${UX_INFO:=-}"

skip() {
  printf '%s%s%s %s\n' "$c_y" "$UX_INFO" "$c_0" "$*"
  exit 0
}

# A non-subtree checkout has no vendored companion/ or companion.lock to compare — skip
# cleanly rather than report a misleading "behind".
[[ -d offensive/companion ]] || skip "check-companion-freshness: no vendored offensive/companion/ (not a subtree checkout?)"
command -v git >/dev/null 2>&1 || skip "check-companion-freshness: git unavailable"

# Read the recorded vendored commit from companion.lock (the O(1) offline provenance stamp
# written by scripts/sync-companion.sh). Same field idiom that sync-companion.sh uses.
# offensive/companion/ exists (asserted above), so this IS a subtree checkout — a
# missing/unreadable companion.lock is a broken repo state, not "not a subtree", and
# skipping it would silently disable the drift signal. Fail HARD (exit 1) instead.
if [[ ! -r companion.lock ]]; then
  printf '%s%s%s check-companion-freshness: offensive/companion/ present but companion.lock missing/unreadable — broken subtree state\n' \
    "$c_r" "$UX_ERR" "$c_0" >&2
  exit 1
fi
SPLIT="$(sed -n 's/^companion_sha=//p' companion.lock | head -n1)"
# A present-but-malformed lock would make the TIP-vs-SPLIT compare below report a false
# "behind". This is a real misconfiguration, not drift, so fail HARD (exit 1) with a
# clear message rather than emit a misleading verdict.
if [[ ! "$SPLIT" =~ ^[0-9a-f]{40}$ ]]; then
  printf '%s%s%s check-companion-freshness: companion.lock has an invalid companion_sha (%s) — expected a 40-char hex SHA\n' \
    "$c_r" "$UX_ERR" "$c_0" "${SPLIT:-empty}" >&2
  exit 1
fi

# Upstream repo/branch come from the lock too (override with COMPANION_UPSTREAM / COMPANION_BRANCH).
# companion_repo is recorded as an owner/name slug (dotgibson/htpx); derive the HTTPS URL the
# same way sync-companion.sh does when no override is given.
REPO_SLUG="$(sed -n 's/^companion_repo=//p' companion.lock | head -n1)"
LOCK_BRANCH="$(sed -n 's/^companion_branch=//p' companion.lock | head -n1)"
[[ -n "$REPO_SLUG" ]]   || { printf '%s%s%s check-companion-freshness: companion_repo missing from companion.lock\n' "$c_r" "$UX_ERR" "$c_0" >&2; exit 1; }
[[ -n "$LOCK_BRANCH" ]] || { printf '%s%s%s check-companion-freshness: companion_branch missing from companion.lock\n' "$c_r" "$UX_ERR" "$c_0" >&2; exit 1; }

UPSTREAM="${COMPANION_UPSTREAM:-https://github.com/$REPO_SLUG.git}"
BRANCH="${COMPANION_BRANCH:-$LOCK_BRANCH}"

# Resolve BRANCH to an explicit refs/heads/<branch> so ls-remote can't match a same-named
# tag (a bare name is a ref PATTERN). A caller may still pass a full refs/… via COMPANION_BRANCH.
case "$BRANCH" in
refs/*) ref="$BRANCH" ;;
*) ref="refs/heads/$BRANCH" ;;
esac
# The upstream tip we'd be pulling. ls-remote needs no clone; GIT_TERMINAL_PROMPT=0 keeps it
# non-interactive (never block a scheduled run waiting on a credential prompt).
# `--` forces end-of-options: UPSTREAM is overridable (COMPANION_UPSTREAM), and
# ls-remote would treat a leading-dash value as an option (option-injection guard).
TIP="$(GIT_TERMINAL_PROMPT=0 git ls-remote -- "$UPSTREAM" "$ref" 2>/dev/null | awk 'NR==1{print $1}')"
[[ -n "$TIP" ]] || skip "check-companion-freshness: cannot reach $UPSTREAM ($BRANCH) — offline/restricted?"

if [[ "$TIP" == "$SPLIT" ]]; then
  printf '%s%s%s vendored offensive/companion/ is current with %s@%s (%s)\n' "$c_g" "$UX_OK" "$c_0" "$UPSTREAM" "$BRANCH" "${SPLIT:0:12}"
  exit 0
fi

# Behind (or diverged). Report the SHAs and how to update, then exit 2 (drift) so a
# scheduled run surfaces it as a nudge — distinct from the exit-1 hard failures above.
# The remediation is scripts/sync-companion.sh (which pulls htpx + bumps companion.lock),
# then the two manual follow-ups it can't do: eyeball the diff and drift-check the views.
{
  printf '%s%s%s vendored offensive/companion/ is behind upstream %s@%s\n' "$c_y" "$UX_WARN" "$c_0" "$UPSTREAM" "$BRANCH"
  printf '    vendored: %s\n    upstream: %s\n' "${SPLIT:0:12}" "${TIP:0:12}"
  printf '    update:\n'
  printf '      scripts/sync-companion.sh\n'
  printf '      git diff %s -- offensive/companion   # review the pulled change\n' "${SPLIT:0:12}"
  printf '      offensive/companion/gen-views.sh --check   # regenerate + commit if it reports drift\n'
} >&2
exit 2
