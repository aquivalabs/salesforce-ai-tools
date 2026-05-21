#!/usr/bin/env bash
# Append a cost footer to the last bot comment on the issue/PR.
#
# Required env:
#   GH_TOKEN, GITHUB_REPOSITORY
#   EXECUTION_FILE   path emitted by anthropics/claude-code-action
#   ISSUE_NUMBER     issue or PR number

set -euo pipefail

: "${GH_TOKEN:?}"; : "${GITHUB_REPOSITORY:?}"
: "${EXECUTION_FILE:?}"; : "${ISSUE_NUMBER:?}"

if [ ! -s "$EXECUTION_FILE" ]; then
  echo "::warning::EXECUTION_FILE missing or empty — skipping cost report."
  exit 0
fi

read -r COST INPUT OUTPUT CACHE_R CACHE_W <<< "$(jq -r '
  [.[] | select(.type == "result")] | last as $r |
  [
    ($r.total_cost_usd // 0),
    ($r.usage.input_tokens // 0),
    ($r.usage.output_tokens // 0),
    ($r.usage.cache_read_input_tokens // 0),
    ($r.usage.cache_creation_input_tokens // 0)
  ] | @tsv' "$EXECUTION_FILE" | tr '\t' ' ')"

TOTAL=$(( INPUT + OUTPUT + CACHE_R + CACHE_W ))

human_tokens() {
  local n=$1
  if (( n >= 1000000 )); then printf "%.1fM" "$(echo "$n/1000000" | bc -l)"
  elif (( n >= 1000 )); then printf "%dk" "$(( n / 1000 ))"
  else printf "%d" "$n"; fi
}

COST_FMT=$(printf "%.2f" "$COST")
TOKENS_H=$(human_tokens "$TOTAL")

COMMENT=$(gh api "repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/comments" --paginate \
  --jq 'map(select(.user.type == "Bot")) | last | {id: .id, body: .body}')

COMMENT_ID=$(echo "$COMMENT" | jq -r '.id')
COMMENT_BODY=$(echo "$COMMENT" | jq -r '.body')

if [ -z "$COMMENT_ID" ] || [ "$COMMENT_ID" = "null" ]; then
  echo "::warning::No bot comment found on issue #$ISSUE_NUMBER — skipping cost footer."
  exit 0
fi

NEW_BODY=$(printf '%s\n\n---\n🤖 $%s · %s tokens' "$COMMENT_BODY" "$COST_FMT" "$TOKENS_H")

gh api -X PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$COMMENT_ID" -f body="$NEW_BODY" >/dev/null
echo "Appended cost footer to comment $COMMENT_ID on issue #$ISSUE_NUMBER"
