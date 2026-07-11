#!/usr/bin/env bash
# .github/workflows/file-routine-issue.sh
# ──────────────────────────────────────────────────────────────────────────────
# File a Claude routine's report as a DEDUPLICATED GitHub issue: if an open issue
# with the given title already exists, append the report as a comment; otherwise
# open a new one. Keeps a weekly bot from stacking duplicate issues. Invoked by
# .github/workflows/claude-routines.yml via `bash …` (so it needs no exec bit).
# (Mirrors dotfiles-core/dotfiles-Defense's helper of the same name — the offensive
# role layer carries its own copy; core/ is vendored read-only and its scripts/ is
# not on PATH here.)
#
# Usage: file-routine-issue.sh <issue-title> <report-file>
# Requires: gh (preinstalled on GitHub runners) + GH_TOKEN in the environment.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

title="${1:?usage: file-routine-issue.sh <title> <report-file>}"
report="${2:?usage: file-routine-issue.sh <title> <report-file>}"

if [ ! -s "$report" ]; then
  echo "::warning::routine produced an empty report ($report) — nothing to file"
  exit 0
fi

# Compose the issue body: a dated heading, the report, and a report-first footer.
body="${RUNNER_TEMP:-/tmp}/routine-issue-body.md"
{
  printf '## %s — %s\n\n' "$title" "$(date -u +%Y-%m-%d)"
  cat "$report"
  printf '\n_Filed by the claude-routines workflow. Report-first: review and act — nothing was changed._\n'
} >"$body"

# The account-level cybersecurity safety filter can block a routine's request outright —
# a REQUEST-level API error, not findings. Filing that verbatim once masqueraded as a real
# report (an "audit" whose only content was the error). Detect the signature and file a
# clearly-labeled advisory under a DISTINCT title instead (so it never dedups into a
# findings issue), then warn — but stay green, matching the preflight no-op posture.
if grep -qiE 'flagged this message for a cybersecurity topic|safety measures.*flagged.*cyber' "$report"; then
  slug="${title%%:*}" # e.g. "methodology-review" — capture before we suffix the title
  echo "::warning::${title}: blocked by the cybersecurity safety filter — filing an advisory, not a report. Apply for the cyber-use-case exemption to re-enable."
  title="$title — BLOCKED (cyber-safety filter)"
  # shellcheck disable=SC2016  # literal backticks/flags in the markdown advisory must NOT expand
  {
    printf '## %s — %s\n\n' "$title" "$(date -u +%Y-%m-%d)"
    printf 'This scheduled routine could **not** run: the model API blocked its request at the\n'
    printf 'cybersecurity safety filter (a request-level block, **not** an audit finding). Raw signal:\n\n'
    printf '```\n'
    cat "$report"
    printf '\n```\n\n'
    printf '### Fix (account-level, one-time)\n\n'
    printf -- '- Apply for the cyber-use-case exemption: <https://claude.com/form/cyber-use-case>\n'
    printf -- '- Or switch this routine to a model the filter does not block (the `--model` flag in\n'
    printf '  `.github/workflows/claude-routines.yml`).\n\n'
    printf 'Until then the routine re-files this advisory each run. Run the audit by hand if needed:\n'
    printf '`claude -p "/%s"` locally, or the matching skill.\n' "$slug"
    printf '\n_Filed by the claude-routines workflow. Run-status advisory, not findings._\n'
  } >"$body"
fi

# gh search is fuzzy, so re-check the title exactly before deciding to dedup.
existing="$(gh issue list --state open --limit 200 --search "$title in:title" --json number,title \
  --jq '.[] | [.number, .title] | @tsv' | awk -F'\t' -v t="$title" '$2 == t {print $1; exit}')"

if [ -n "$existing" ]; then
  gh issue comment "$existing" --body-file "$body"
  echo "appended report to existing issue #$existing"
else
  gh issue create --title "$title" --body-file "$body"
fi
