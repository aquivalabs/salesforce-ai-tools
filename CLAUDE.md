# Salesforce AI Tools - Claude Instructions

## Plugin Versioning

Bump the `version` field in
[plugins/salesforce-ai-tools/.claude-plugin/plugin.json](plugins/salesforce-ai-tools/.claude-plugin/plugin.json)
whenever a change alters what installing the plugin gives a user — a new or
changed skill, a fix to a shipped script (`bin/`, `run.mjs`), a hook, a command,
anything that changes runtime behavior downstream.

The trigger is **semantic**: does this warrant a new version because users would
receive something different? It is *not* about which file type changed. A
one-line fix to `bin/` that unbreaks the runner ships only if the version moves;
a large refactor that changes nothing observable does not need a bump.
Repo-internal-only edits (this file, READMEs, comments) don't warrant one on their own.

Claude Code clients pin plugins at install time and use the version string to detect updates.
Without a bump, clients will not pull the change even after it is pushed to GitHub.

Use **CalVer** (`YYYY.M.patch`), where `M` is the current calendar month (no leading zero).
The year and month must match the current date; never use a future month.

- **Patch** (`2026.5.0` -> `2026.5.1`) - any behavior-affecting change shipped within the same month
- **New month** (`2026.5.3` -> `2026.6.0`) - first release of a new calendar month resets patch to 0

Commit the version bump together with the change that warranted it.

After pushing, always:

1. Create a matching GitHub release (`vYYYY.M.patch`) so the plugin version and repository release tag stay in sync.
2. Update the version badge in the first line of [README.md](README.md) to match.
