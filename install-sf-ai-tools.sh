#!/bin/bash
# Installs salesforce-ai-tools skills and rules into ~/.claude/
# Run once locally; re-run to update.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/rules/salesforce"

for skill_dir in "$SCRIPT_DIR/.claude/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  ln -sfn "$skill_dir" "$CLAUDE_DIR/skills/$skill_name"
  echo "Linked skill: $skill_name"
done

for rules_file in "$SCRIPT_DIR/.claude/rules/salesforce/"*.md; do
  ln -sfn "$rules_file" "$CLAUDE_DIR/rules/salesforce/$(basename "$rules_file")"
  echo "Linked rules: $(basename "$rules_file")"
done

ln -sfn "$SCRIPT_DIR/.claude/settings.json" "$CLAUDE_DIR/settings.json"
echo "Linked settings.json"

echo "Done — skills, rules, and settings available globally in Claude Code."
