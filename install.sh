#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p ~/.claude/skills

# Symlink each skill individually so multiple repos can contribute to ~/.claude/skills/.
for skill_dir in "$SCRIPT_DIR"/.claude/skills/*/; do
    skill_name=$(basename "$skill_dir")
    target=~/.claude/skills/"$skill_name"

    # ln -sfn can replace a symlink but not a real directory.
    if [ -d "$target" ] && [ ! -L "$target" ]; then
        rm -rf "$target"
    fi

    ln -sfn "$skill_dir" "$target"
done

echo "Done. Skills symlinked into ~/.claude/skills/"
echo ""
for skill_dir in "$SCRIPT_DIR"/.claude/skills/*/; do
    skill_name=$(basename "$skill_dir")
    echo "  ~/.claude/skills/$skill_name/ -> .claude/skills/$skill_name/"
done
echo ""
echo "Start a new Claude Code session to pick up the skills."
