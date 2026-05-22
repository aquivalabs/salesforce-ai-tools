# Salesforce AI Tools - Claude Instructions

## Plugin Versioning

After any skill change (add, modify, rename, remove), bump the `version` field in
[plugins/salesforce-ai-tools/.claude-plugin/plugin.json](plugins/salesforce-ai-tools/.claude-plugin/plugin.json).

Claude Code clients pin plugins at install time and use the version string to detect updates.
Without a bump, clients will not pull new skills even after the changes are pushed to GitHub.

Use **CalVer** (`YYYY.M.patch`), where `M` is the current calendar month (no leading zero).
The year and month must match the current date; never use a future month.

- **Patch** (`2026.5.0` -> `2026.5.1`) - edits within an existing skill, or new skills added in the same month
- **New month** (`2026.5.3` -> `2026.6.0`) - first release of a new calendar month resets patch to 0

Commit the version bump together with the skill changes.

After pushing, always:

1. Create a matching GitHub release (`vYYYY.M.patch`) so the plugin version and repository release tag stay in sync.
2. Update the version badge in the first line of [README.md](README.md) to match.
