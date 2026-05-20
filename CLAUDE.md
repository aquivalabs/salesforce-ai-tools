# salesforce-ai-tools

Reusable GitHub Actions workflows and Claude Code skills for AI-assisted Salesforce development.

## What's here

**Skills** (`.claude/skills/`) — Claude Code reads these at runtime. Consumer repos reference them by checking out this repo in their CI workflow.

- `sf-ticket-to-pr` — turns GitHub issues into pull requests via an @butler mention
- `playwright-sf` — headless Salesforce UI automation for change verification
- `sf-code-analyzer` — runs Salesforce Code Analyzer on changed files

**Workflows** (`.github/workflows/`) — reusable via `uses: aquivalabs/salesforce-ai-tools/.github/workflows/<name>.yml@main`

- `sf-ticket-to-pr.yml` — triage + execute pipeline triggered by @butler mentions
- `sf-pr-cleanup.yml` — deletes the per-PR scratch org when a PR closes

**Scripts** (`scripts/`) — shared shell utilities used by the workflows

- `report-ai-cost.sh` — posts a sticky cost rollup comment on the issue
- `create-scratch-org.sh` — provisions or restores a scratch org from cache
- `config.sh` — project-specific values (override in consumer repos)

## Using in your repo

Add to your `.github/workflows/sf-ticket-to-pr.yml`:

```yaml
jobs:
  pipeline:
    uses: aquivalabs/salesforce-ai-tools/.github/workflows/sf-ticket-to-pr.yml@main
    secrets: inherit
```

The workflow checks out this repo to make the skills available to Claude at runtime.

## Local testing

Clone this repo, point `config.sh` at your DevHub, and run `./scripts/create-scratch-org.sh` against your own Salesforce project. The `sfdx-project.json` and `config/project-scratch-def.json` here are minimal placeholders — replace them with your project's files.
