#!/usr/bin/env bash
# offensive/companion/gen-views.sh — render entry-backed blocks into the flat views.
# ──────────────────────────────────────────────────────────────────────────────
# The source-of-truth bridge. The structured `entries/` are CANONICAL for the
# paired red<->blue attack/detection slice; the flat field references
# (`PURPLE-TEAM.md`, later `hacktheplanet`) stay canonical for everything else —
# the tradecraft prose, dorks, sequencing, warnings that don't fit the entry
# schema. Where the two OVERLAP, this script makes the entry win: it regenerates
# the marked blocks in the flat file FROM the entry, so the overlap can't drift.
#
# A flat file opts a block in with a marker pair naming the entry id:
#
#     <!-- companion:gen kerberoasting-4769 -->
#     …everything here is generated from entries/**/kerberoasting-4769.md…
#     <!-- companion:end kerberoasting-4769 -->
#
# Anything OUTSIDE the markers is hand-authored and never touched.
#
#   gen-views.sh            # rewrite every marked block in place from its entry
#   gen-views.sh --check    # exit 1 (with a diff) if any block is out of date
#
# --check is the drift gate (CI runs it); the bare form is what you run after
# editing an entry. Markdown markers only for now (PURPLE-TEAM.md); the red-side
# hacktheplanet retrofit needs a {{slot}} -> <angle-bracket> reverse map and is a
# deliberate follow-up.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
ENTRIES="$HERE/entries"
REPO="$(cd -- "$HERE/../.." && pwd)"

# The flat files that carry generated blocks (paths relative to the repo root).
TARGETS=("PURPLE-TEAM.md")

CHECK=0
[[ "${1:-}" == "--check" ]] && CHECK=1

# entry_for_id <id> — print the path of the ONE entry whose frontmatter id == <id>.
# Fails (non-zero, with a clear message naming the paths) on zero or multiple
# matches, so a typo or a duplicate id can never silently regenerate the wrong
# block. Callers must invoke it in a conditional (`if ! ef=$(entry_for_id …)`) so
# the failure is visible under `set -e` (a bare `ef=$(…)` assignment swallows it).
entry_for_id() {
  local id="$1" matches n
  matches="$(grep -rl "^id:[[:space:]]*$id\$" "$ENTRIES" 2>/dev/null || true)"
  n="$(printf '%s' "$matches" | grep -c . || true)"
  if [[ "$n" -eq 0 ]]; then
    echo "gen-views: no entry with id '$id'" >&2; return 1
  elif [[ "$n" -gt 1 ]]; then
    echo "gen-views: duplicate id '$id' across multiple entries:" >&2
    printf '%s\n' "$matches" | sed 's/^/  /' >&2; return 1
  fi
  printf '%s\n' "$matches"
}

# render_block <entry-file> — the markdown block a flat file should show for it:
# the bold title, the body prose, the fenced detection, then any trailing note
# (e.g. a "Tighter:" follow-up after the query). One awk pass; reads only the first
# frontmatter block for the title and treats the FIRST fenced block as the query,
# so a stray ``` or key: in the body can't confuse it. Content before the fence is
# prose, content after it is the tail.
render_block() {
  awk '
    /^---[[:space:]]*$/ { fm++; if (fm == 2) stage = 1; next }
    fm == 1 { if (index($0, "title:") == 1) { t = $0; sub(/^title:[[:space:]]*/, "", t) } next }
    stage == 1 && /^```/ { stage = 2; next }
    stage == 2 && /^```/ { stage = 3; next }
    stage == 1 { prose = prose $0 "\n" }
    stage == 2 { spl = spl $0 "\n" }
    stage == 3 { tail = tail $0 "\n" }
    END {
      gsub(/^\n+/, "", prose); gsub(/\n+$/, "", prose)
      gsub(/\n+$/, "", spl)
      gsub(/^\n+/, "", tail); gsub(/\n+$/, "", tail)
      if (tail != "")
        printf "**%s**\n\n%s\n\n```spl\n%s\n```\n\n%s\n", t, prose, spl, tail
      else
        printf "**%s**\n\n%s\n\n```spl\n%s\n```\n", t, prose, spl
    }
  ' "$1"
}

# build_file <flat-file> — emit the file with every marked block regenerated.
build_file() {
  local file="$1" line id ef
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\<!--\ companion:gen\ ([a-z0-9-]+)\ --\>$ ]]; then
      id="${BASH_REMATCH[1]}"
      printf '%s\n' "$line"                       # keep the opening marker
      # Conditional call so entry_for_id's failure surfaces under `set -e`; it has
      # already printed the specific reason (missing / duplicate id).
      if ! ef="$(entry_for_id "$id")"; then
        echo "gen-views: ^ referenced by a companion:gen marker in $file" >&2; return 2
      fi
      render_block "$ef"
      # consume the old block up to and including its end marker
      local found=0 l2
      while IFS= read -r l2; do
        if [[ "$l2" =~ ^\<!--\ companion:end\ ([a-z0-9-]+)\ --\>$ ]]; then
          [[ "${BASH_REMATCH[1]}" == "$id" ]] || { echo "gen-views: marker mismatch: gen '$id' closed by end '${BASH_REMATCH[1]}' in $file" >&2; return 2; }
          printf '%s\n' "$l2"; found=1; break
        fi
      done
      [[ "$found" == 1 ]] || { echo "gen-views: unterminated 'companion:gen $id' region in $file" >&2; return 2; }
    else
      printf '%s\n' "$line"
    fi
  done < "$file"
}

rc=0
for t in "${TARGETS[@]}"; do
  file="$REPO/$t"
  [[ -f "$file" ]] || { echo "gen-views: target not found: $t" >&2; rc=1; continue; }
  if ! grep -q '<!-- companion:gen ' "$file"; then
    echo "gen-views: $t has no companion:gen markers — skipping" >&2
    continue
  fi
  generated="$(build_file "$file")" || { rc=$?; continue; }
  if [[ "$CHECK" == 1 ]]; then
    if ! diff -u "$file" <(printf '%s\n' "$generated") >/dev/null; then
      echo "gen-views: DRIFT in $t — a generated block is out of date with its entry:" >&2
      diff -u "$file" <(printf '%s\n' "$generated") | sed 's/^/  /' >&2 || true
      echo "  fix: run offensive/companion/gen-views.sh and commit the result." >&2
      rc=1
    else
      echo "gen-views: $t up to date"
    fi
  else
    printf '%s\n' "$generated" > "$file"
    echo "gen-views: regenerated $t"
  fi
done
exit "$rc"
