#!/usr/bin/env bash
set -euo pipefail

# Installs the salesforce-ai-tools Claude plugin.
#
# This script intentionally keeps the old filename used by downstream repos,
# but it no longer symlinks skills into ~/.claude. Claude Code owns plugin
# installation, versioning, and cache layout.

SCOPE="${SCOPE:-user}"
SOURCE="${SOURCE:-aquivalabs/salesforce-ai-tools}"
MARKETPLACE="aquiva-labs"
PLUGIN="salesforce-ai-tools"

usage() {
  cat <<'EOF'
Usage: scripts/install-sf-ai-tools.sh [--scope user|project|local] [--source <repo-or-path>]

Examples:
  scripts/install-sf-ai-tools.sh
  scripts/install-sf-ai-tools.sh --scope project
  scripts/install-sf-ai-tools.sh --scope local --source ./.sf-ai-tools
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --scope)
      SCOPE="${2:-}"
      shift 2
      ;;
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$SCOPE" in
  user|project|local) ;;
  *)
    echo "Invalid scope: $SCOPE. Expected user, project, or local." >&2
    exit 2
    ;;
esac

if ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code CLI is required. Install it first, then rerun this script." >&2
  exit 1
fi

claude plugin marketplace add "$SOURCE" --scope "$SCOPE"
claude plugin install "$PLUGIN@$MARKETPLACE" --scope "$SCOPE"

echo "Installed $PLUGIN@$MARKETPLACE using Claude plugin scope '$SCOPE'."
