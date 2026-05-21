# salesforce-ai-tools

Reusable GitHub Actions workflows and Claude Code skills for AI-assisted Salesforce development. Drop these into any Salesforce repo to get an AI agent that triages issues, opens pull requests, verifies UI changes, and more — all triggered by a simple `@butler` mention.

## What's here

**Skills** ([.claude/skills/](.claude/skills/)) — Specialized behaviors Claude Code loads at runtime. Consumer repos get them by having the workflow check out this repo.

| Skill | What it does |
|---|---|
| [sf-ticket-to-pr](.claude/skills/sf-ticket-to-pr/SKILL.md) | Reads a GitHub issue or PR thread and acts on it — writes code, opens a PR, asks for clarification, or refuses |
| [agentforce](.claude/skills/agentforce/SKILL.md) | Tests and deploys Agentforce agents and prompt templates |
| [agentforce-deploy](.claude/skills/agentforce-deploy/SKILL.md) | Handles the manual fixups Salesforce CLI doesn't cover when deploying Agentforce metadata |
| [playwright-sf](.claude/skills/playwright-sf/SKILL.md) | Drives a Salesforce Lightning org headlessly to reproduce bugs and verify UI changes |
| [sf-code-analyzer](.claude/skills/sf-code-analyzer/SKILL.md) | Runs Salesforce Code Analyzer on changed Apex, Flow, or metadata files |

**Workflows** ([.github/workflows/](.github/workflows/)) — Reusable via the `uses:` keyword in any repo's workflow file.

| Workflow | What it does |
|---|---|
| [sf-ticket-to-pr.yml](.github/workflows/sf-ticket-to-pr.yml) | Mention-driven pipeline: fires on `@butler` mentions, triages, then executes |
| [sf-pr-cleanup.yml](.github/workflows/sf-pr-cleanup.yml) | Deletes the per-PR scratch org when a PR closes |

**Scripts** ([scripts/](scripts/)) — Shell utilities used by the workflows.

| Script | What it does |
|---|---|
| [create-scratch-org.sh](scripts/create-scratch-org.sh) | Provisions or restores a scratch org from cache |
| [config.sh](scripts/config.sh) | Project-specific values — override this in your consumer repo |

## Using in your repo

### Step 1 — Reference the reusable workflow

Create `.github/workflows/sf-ticket-to-pr.yml` in your repo:

```yaml
name: SF Ticket to PR

on:
  issues:
    types: [opened, edited]
  issue_comment:
    types: [created]
  pull_request_review:
    types: [submitted]
  pull_request_review_comment:
    types: [created]

jobs:
  pipeline:
    uses: aquivalabs/salesforce-ai-tools/.github/workflows/sf-ticket-to-pr.yml@main
    secrets: inherit
```

The workflow checks out this repo at runtime, making all skills available to Claude.

### Step 2 — Add the PR cleanup workflow

Create `.github/workflows/sf-pr-cleanup.yml`:

```yaml
name: SF PR Cleanup

on:
  pull_request:
    types: [closed]

jobs:
  cleanup:
    uses: aquivalabs/salesforce-ai-tools/.github/workflows/sf-pr-cleanup.yml@main
    secrets: inherit
```

### Step 3 — Configure required secrets

Add these secrets to your repo (Settings → Secrets and variables → Actions):

| Secret | Description |
|---|---|
| `ANTHROPIC_API_KEY` | Claude API key — or use `CLAUDE_CODE_OAUTH_TOKEN` instead (see below) |
| `CLAUDE_CODE_OAUTH_TOKEN` | Alternative to `ANTHROPIC_API_KEY` for Claude Max/Team/Enterprise subscribers. Generate with `claude setup-token` in your terminal. |
| `SFDX_AUTH_URL` | Salesforce DevHub SFDX auth URL. Get it with `sf org display --target-org <DevHubAlias> --verbose --json \| jq -r .result.sfdxAuthUrl` |

### Step 4 — Trigger it

Mention `@butler` in any issue or pull request comment. The agent reads the full thread and decides what to do — implement the request, ask for clarification, propose a different approach, or decline.

```
@butler please add a validation rule to Account that requires Phone when BillingCountry is "US"
```

## Using the Claude Code skills locally

The skills also work in your local Claude Code session if you copy them into your project's [.claude/skills/](.claude/skills/) directory:

```bash
# From your Salesforce project root
git clone https://github.com/aquivalabs/salesforce-ai-tools /tmp/sf-ai-tools
cp -r /tmp/sf-ai-tools/.claude/skills/* .claude/skills/
```

Then invoke them with a slash command in Claude Code:

```
/sf-code-analyzer
/agentforce-deploy
```

## Local development

Clone this repo and point [config.sh](scripts/config.sh) at your DevHub, then run the scripts against your own Salesforce project:

```bash
git clone https://github.com/aquivalabs/salesforce-ai-tools
cd salesforce-ai-tools
# Edit scripts/config.sh with your DevHub alias and run:
./scripts/create-scratch-org.sh
```

The [sfdx-project.json](sfdx-project.json) and [config/project-scratch-def.json](config/project-scratch-def.json) here are minimal placeholders — the consumer repo's versions take precedence when the workflow runs.
