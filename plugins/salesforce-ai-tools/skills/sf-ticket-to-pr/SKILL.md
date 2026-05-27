---
name: sf-ticket-to-pr
description: Respond to @butler mentions on GitHub issues and PRs — read the thread, propose a plan, wait for approval, then act
---

# SF Ticket to PR

You were summoned by an `@butler` mention or by a human reply to a pending
Butler plan on a GitHub issue or PR.

You are done when **one** of these is true:
- You posted a concrete plan with `<!-- butler:plan status=pending -->` and are
  waiting for human approval,
- You determined that the latest human reply clearly approved the current plan,
  posted `<!-- butler:execute -->`, and the execute job will take over,
- A new commit lands on a branch with an open PR, **or**
- A clear stop-reason has been posted as a comment explaining why you didn't.

## Preconditions

The workflow has already checked out the correct branch (`fix/issue-<N>` off
main for new issues, or the PR's head branch for follow-ups) and
provisioned/restored a scratch org aliased `pr-<issue-number>`. DevHub auth and
SF CLI are ready. Commits are attributed to `github-actions[bot]`.

On follow-up runs the scratch org is restored from cache — do not re-provision
or redeploy everything; only redeploy files you changed.

## Project-specific addenda

This skill is portable across any sfdx repo. Project-specific rules live in the
consuming repo's `CLAUDE.md` — read it and treat its rules as overrides.

## Local metadata knowledge

Before creating or editing Salesforce metadata, read
`knowledge/salesforce-metadata/INDEX.md` and then each routed file for the
metadata type you will touch.

When you discover a new metadata quirk, update the matching knowledge file in
the same PR. Use the entry shape documented in the knowledge files: Error,
Likely Cause, Fix, Validation, Source, Trust (`AI-observed, not human-reviewed`),
Confirmed date. Also append one line to `knowledge/log.md`.

## Step 1 — Read the thread, then decide

Read the conversation before touching code:

    gh issue view <N> --repo <owner/repo> --comments     # for issues
    gh pr view  <N> --repo <owner/repo> --comments       # for PRs

The latest human signal is authoritative. An empty issue body is not a reason to
stop — the title is part of the request.

**Verify prior bot promises before believing them.** Earlier bot comments may
reference PRs or branches that no longer exist. Check with `gh pr view` and
`git ls-remote` before adopting any prior plan.

Then pick **one** move and post it as a GitHub comment. Always write the body to
a file and pass `--body-file` to avoid shell-expansion issues:

    cat > /tmp/butler-reply.md <<'EOF'
    <your comment body, including the hidden marker required by the selected move>
    EOF
    gh issue comment <N> --repo <owner/repo> --body-file /tmp/butler-reply.md

### Propose a plan

The request is clear enough to plan and small enough for one PR. Comment with a
short, concrete plan — name the classes, metadata, tests, and verification
approach. End with:

    <!-- butler:plan status=pending -->

Stop after posting. Do not include an execute marker in the same run that first
creates or materially revises a plan.

**Verification plan.** State what you will verify after approval, not how.
Apex/triggers touched → Apex tests. Agentforce metadata → Testing Center case.
User-visible change → Playwright screenshot. Interactive conversational UI →
Playwright video. Bug → reproduce first with Playwright evidence, then fix.
Pick the cheapest verification that proves the requirement.

**The plan is what YOU will verify** — not a checklist for the reviewer. The PR
must never contain "How to verify" instructions. You do all verification in
Step 3 and attach evidence.

**FlexiPage activation.** If your change creates a custom Lightning record page,
the plan must include activating it through object `actionOverrides` metadata. A
non-activated page is invisible to users.

### Human approved the current plan

The latest human reply after the most recent pending plan clearly approves it.
Post a brief acknowledgement ending with:

    <!-- butler:execute -->

Stop. Approval can be natural language.

### Human corrected the plan

Post a revised concrete plan ending with `<!-- butler:plan status=pending -->`.
Stop.

### Human response is ambiguous

Answer briefly or ask one concise clarifying question. Include
`<!-- butler:plan status=pending -->` if the existing plan should remain pending.
Do not execute.

### Sizing

A request that fits one PR usually touches 1-3 Apex classes plus tests,
optionally one LWC, optionally a handful of metadata files. If you're not sure,
propose a split.

Custom fields, objects, queues, Flows, Permission Sets — author them alongside
the Apex when the request needs them. Do not refuse for "missing prerequisites"
if the issue is asking you to create them.

### Ask for clarification

Post one or two crisp questions. Do not include the execute marker. Stop.

### Propose a split

Comment with a proposed split — each sub-story sized to ~1 class + tests +
metadata. Name what should land first and why. Stop.

### Refuse

- `config/`, `sfdx-project.json`, or `.github/workflows/` changes
- Feedback that contradicts the original issue without explanation
- Anything in the consuming repo's `CLAUDE.md` refuse-list

Comment with the reason in one sentence. Stop.

## Step 2 — Code

Touch whatever the change requires under `force-app/` or `unpackaged/`. Follow
the consuming repo's `CLAUDE.md` for Apex rules and deploy conventions.

Read each file you will change in full before editing.

For unknown Salesforce XML shape, find a recent real source shape from public
GitHub or a live-org retrieve. Do not invent XML. If two focused deploy attempts
fail on the same metadata file, stop and post the exact blocker.

For FlexiPage RecordPages, follow the `flexipages.md` recipe.

### Salesforce CLI command discipline

Run metadata commands in the foreground with a Bash timeout:

```bash
timeout 180 sf project retrieve start --metadata "Layout:Account-Account Layout" --target-org "$SCRATCH_ORG_ALIAS"
timeout 180 sf project deploy start --source-dir "force-app/main/default/layouts/Account-Account Layout.layout-meta.xml" --concise
```

Do not background SF CLI commands or poll task output files. Before repeating a
command, state what changed since the previous run.

## Step 3 — Verify

Deploy your changed files:

    timeout 180 sf project deploy start --source-dir <changed-file-path> --concise

Follow the consuming repo's `CLAUDE.md` if it describes namespace-strip or other
pre-deploy steps.

### Deploy failure protocol

On the first deploy failure, stop editing:

1. Capture the exact error.
2. Read `knowledge/salesforce-metadata/INDEX.md` and the routed knowledge file.
3. Apply one targeted fix.
4. Redeploy the smallest relevant source path.

If local knowledge doesn't resolve it, retrieve the real artifact from the org
or find a recent public GitHub source file. Do not open Salesforce Setup or App
Builder. After resolution, update the knowledge file with what you learned.

### Run tests

Run tests in the foreground with a Bash timeout matching the CLI wait:

    timeout 1800 sf apex run test --test-level RunLocalTests --wait 30 --result-format human

### Code analysis

Run `/sf-code-analyzer` on the files you changed. Fix findings on lines you
touched. Ignore findings on lines you did not touch — those are pre-existing.

### Playwright verification

If the plan included Playwright verification (screenshot or video), invoke the
`playwright-sf` skill now against the scratch org. Use CLI/scripted Playwright
first; MCP only as a fallback for selector discovery on the final user-facing
page. Never use Playwright to configure Setup or App Builder.

Attach screenshots to the PR body in Step 4. A `UI-FAIL` means the change is
wrong — iterate. `UI-INCONCLUSIVE` means the page didn't load reliably — note it
but don't block.

For video verification, the `playwright-sf` skill must extract and inspect
frames before the PR claims verification. A video of login, Access Denied, or
the wrong record is invalid.

## Step 4 — Ship

Commit and push:

    git add force-app/main/default/classes/<changed files>
    git commit -m "<one short sentence>"
    git push

### Scratch org URL — non-negotiable

Every PR body, reviewer reply, and summary comment must include the auto-login
URL:

    SCRATCH_URL=$(sf org open --url-only --target-org "$SCRATCH_ORG_ALIAS" --json | jq -r .result.url)

### Opening a new PR

If no PR exists for the branch, open one. Write the body to a file and use
`--body-file` (do not inline with `--body "$(cat <<EOF...)"` — backticks and
`$()` in the markdown collide with shell expansion):

    BRANCH=$(git branch --show-current)
    if [ -z "$(gh pr list --head "$BRANCH" --json number --jq '.[0].number')" ]; then
      cat > /tmp/pr-body.md <<'EOF'
    Closes #<issue-number>

    ## What changed
    <2-4 bullets>

    ## Verified
    <what you verified — test counts, screenshots, SOQL. Not instructions for a human.>

    Scratch org:
    EOF
      printf '%s\n' "$SCRATCH_URL" >> /tmp/pr-body.md
      gh pr create \
        --title "fix: <short description>" \
        --body-file /tmp/pr-body.md \
        --head "$BRANCH" \
        --base main \
        --label ai-involved
    fi

If the PR already exists, the push updates it. Include `$SCRATCH_URL` in any
`gh pr comment` replies too.

### Stop here

Once the push succeeds and the summary comment is posted, stop. Do not run
further verification commands.
