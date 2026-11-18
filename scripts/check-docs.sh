#!/usr/bin/env bash
# Checks that README.md, docs/, scripts/ and templates/ agree, and regenerates the README set tables.
#
# Usage: check-docs.sh [--fix]
#   --fix  Rewrite the README set tables (between the sets:start and sets:end markers) from
#          templates/sets.json instead of failing when they are stale.
# Needs jq. Exits 1 if any check fails.
set -euo pipefail

cd "$(dirname "$0")/.."
fix=false
[[ "${1:-}" == "--fix" ]] && fix=true
meta=templates/sets.json
problems=0
fail() { echo "FAIL: $*" >&2; problems=$((problems + 1)); }

# Prints the README set tables, one per category, from sets.json.
render_tables() {
  jq -r '
    to_entries[] |
    "### `\(.key)`\n\n| Set | What it adds |\n| --- | --- |\n" +
    (.value | to_entries | map(
      "| `\(.key)` | \(.value.summary)" +
      (if (.value.needs // []) | length > 0
       then "; needs " + (.value.needs | map("`\(.)`") | join(", "))
       else "" end) + " |"
    ) | join("\n")) + "\n"' "$meta"
}

# Prints README.md with the region between the markers replaced by the rendered tables.
readme_with_tables() {
  local tables
  tables="$(render_tables)"
  awk -v tables="$tables" '
    /<!-- sets:start -->/ { print; print ""; print tables; print ""; skip = 1; next }
    /<!-- sets:end -->/   { skip = 0 }
    !skip'  README.md
}

# 1. sets.json and templates/ list the same sets in the same categories.
declared="$(jq -r 'to_entries[] | .key as $c | .value | keys[] | "\($c)/\(.)"' "$meta" | sort)"
on_disk="$(find templates -mindepth 2 -maxdepth 2 -type d -printf '%P\n' | sort)"
if [[ "$declared" != "$on_disk" ]]; then
  fail "templates/sets.json and templates/ differ:"
  diff <(echo "$declared") <(echo "$on_disk") >&2 || true
fi

# 2. Every `needs` entry names a real set.
all_sets="$(jq -r '.[] | keys[]' "$meta")"
while read -r set need; do
  grep -qx "$need" <<<"$all_sets" || fail "$set needs unknown set '$need'"
done < <(jq -r '.[] | to_entries[] | .key as $s | (.value.needs // [])[] | "\($s) \(.)"' "$meta")

# 3. The README set tables match sets.json.
if ! grep -q '<!-- sets:start -->' README.md; then
  fail "README.md has no <!-- sets:start --> marker"
elif "$fix"; then
  readme_with_tables >README.md.new && mv README.md.new README.md
elif ! diff -q <(readme_with_tables) README.md >/dev/null; then
  fail "README set tables are stale; run scripts/check-docs.sh --fix"
fi

# 4. Every script is in the README and starts with a header comment.
for script in scripts/*.sh; do
  [[ "$script" == scripts/common.sh ]] && continue
  grep -qF "$script" README.md || fail "$script is not in the README Scripts table"
  [[ "$(sed -n '2p' "$script")" == '#'* ]] || fail "$script has no header comment describing it"
done

# 5. Relative links in README.md and docs/ resolve.
for doc in README.md docs/*.md; do
  while read -r link; do
    [[ -e "$(dirname "$doc")/$link" ]] || fail "$doc links to missing $link"
  done < <(grep -oE '\]\([^)#:]+\)' "$doc" | sed -E 's/^\]\(//; s/\)$//')
done

# 6. Scripts named in README.md and docs/ exist.
while read -r path; do
  [[ -e "$path" ]] || fail "docs mention missing $path"
done < <(grep -ohE 'scripts/[A-Za-z0-9_.-]+\.sh' README.md docs/*.md | sort -u)

if ((problems > 0)); then
  echo "$problems problem(s) found." >&2
  exit 1
fi
echo "Docs are consistent."
