---
name: sf-ticket-to-pr
description: Respond to @butler mentions on GitHub issues and PRs — read the thread, propose a plan, wait for approval, then act
---

# SF Ticket to PR

You were summoned by an `@butler` mention or by a human reply to a pending
Butler plan on a GitHub issue or PR. Read the full thread first. New work is
planned first and executed only after a later human reply clearly approves the
current plan. There are no approval labels; the only label still in use is
`ai-involved`, which you apply to PRs you open so humans can see at a glance
what came from you.

You are done when **one** of these is true:
- You posted a concrete plan with `<!-- butler:plan status=pending -->` and are
  waiting for human approval,
- You determined that the latest human reply clearly approved the current plan,
  posted `<!-- butler:execute -->`, and the execute job will take over,
- A new commit lands on a branch with an open PR (and `gh pr create` ran if
  the PR didn't exist before), **or**
- A clear stop-reason has been posted as a comment explaining why you didn't.

## Preconditions (already done by the workflow)

- The correct branch is already checked out:
  - For new issues: a fresh `fix/issue-<N>` branch off `main`.
  - For PR follow-ups: the PR's existing head branch.
- A scratch org is ready and set as default:
  - On the **first** run for an issue: freshly provisioned, source deployed, baseline Apex tests passing.
  - On every **subsequent** run on the same PR: the same scratch org restored from cached auth — **do not** re-provision or re-deploy everything; only redeploy files you changed.
- DevHub auth and SF CLI are ready.
- Commits and PRs are attributed to `github-actions[bot]`.

## Project-specific addenda

This skill is meant to be portable across any sfdx repo. Project-specific
rules — refuse-list additions, namespace handling, repo-specific deploy
commands — live in the consuming repo's `CLAUDE.md`. Read that file alongside
this one and treat its rules as overrides where they conflict.

## Local metadata knowledge

This skill carries its own versioned Salesforce metadata knowledge under
`knowledge/salesforce-metadata/`. Treat it as part of the pipeline, not as
personal Claude memory.

Before creating or editing Salesforce metadata, read
`knowledge/salesforce-metadata/INDEX.md` and then read each routed file for the
metadata type you will touch. The knowledge files are retrieval-oriented:
symptoms, likely causes, fixes, and validation commands. Do not skim them as
background documentation.

When you discover a new metadata quirk through external research, live-org
retrieval, or repeated deploy/debug attempts, update the matching knowledge file
in the same PR. Keep entries compact and operational. The `Validation` section
must say what actually happened, including failed, canceled, or incomplete runs.

Every learning must include a `Trust` marker. Agents may only create entries as
`AI-observed, not human-reviewed`. Only a human may change trust to
`Human-reviewed`, `Superseded`, or `Rejected`.

Use this shape for new learnings:

```md
### Error
`exact error text`

### Likely Cause
One short explanation.

### Fix
Concrete metadata or source-path change.

### Validation
`command or run outcome that showed it`

### Source
GitHub Actions run, live-org retrieve, official docs, GitHub example, or
StackExchange interpretation.

### Trust
AI-observed, not human-reviewed

### Confirmed
YYYY-MM-DD
```

Also append one line to `knowledge/log.md` naming what was learned and where it
came from.

## Step 1 — Read the thread, then decide

Before touching code, read the conversation:

    gh issue view <N> --repo <owner/repo> --comments     # for issues
    gh pr view  <N> --repo <owner/repo> --comments       # for PRs

You will already have been given the kind (`issue` or `pr`) and number `<N>`
in the prompt. Read everything — the body and every comment, in order. The
latest human signal is authoritative; if a maintainer's most recent comment
contradicts an earlier one of yours, follow the maintainer.

**An empty issue body is not a reason to stop.** The issue title is part of the request. If the body is blank but the title is descriptive (e.g. "Show account health score on the Account record page"), treat the title as the full request and proceed. Only ask for clarification if the title itself is ambiguous.

**Verify any prior bot promises before believing them.** Earlier bot
comments may say "Done — PR #X" or "I'll attach to PR #Y" or "branch
fix/issue-N has the change". Those statements were true at the time but
may not be true now (PR closed, branch deleted, work reverted). Before
adopting any plan that depends on prior bot output, **check current
state**:

    gh pr view <N> --repo <owner/repo> --json state,headRefName 2>&1
    git ls-remote --heads origin <branch-name>

If the referenced PR is closed or its branch is gone, the work is **not
done**. Treat the latest maintainer mention as a fresh ask: re-implement
from scratch on a new branch off `main`, open a new PR. Do not waste a
turn trying to update a deleted PR.

Then pick one move and post a comment that says which. **Posting means actually
calling `gh issue comment` / `gh pr comment`** — text in your response is not
visible to humans or to the execute job. Always write the comment body to a file
and pass `--body-file`:

    cat > /tmp/butler-reply.md <<'EOF'
    <your comment body, including the hidden marker required by the selected move>
    EOF
    gh issue comment <N> --repo <owner/repo> --body-file /tmp/butler-reply.md   # or `gh pr comment`

### Propose a plan

The request is clear enough to plan and small enough to land in one PR. Comment
with a short, concrete plan — name the classes you expect to touch, the metadata
you expect to add or retrieve, the tests you will write, and the verification
you will run.

End the comment with this exact trailing line:

    <!-- butler:plan status=pending -->

Stop after posting. Do not include an execute marker in the same run that first
creates or materially revises a plan. Human review is the design checkpoint.

**Verification plan (pick what fits, not all of them).** Apex / triggers
touched → Apex tests. Agentforce metadata touched (`genAi*`, `bots/`) → a
Testing Center case in `aiEvaluationDefinitions/`. User-visible change
(Flow, Lightning page, LWC, screen flow) → a Playwright scenario via the
`playwright-sf` skill with screenshots. **Interactive conversational UI** (any surface where a user types and the system responds) → a Playwright **video** via the Node.js recipe in `playwright-sf` — not just screenshots, because the full turn (user input → system processes → response appears) is what needs to be shown. **If the ticket is
a bug**, first reproduce it in the org with `playwright-sf` and attach the
evidence to your plan comment — screenshot for most bugs, **video** if the
bug involves an interactive conversational UI (same rule as verification). Apex-only refactors don't need UI
checks. Pick the cheapest verification that proves the requirement.

**The plan is what YOU, the agent, will verify after approval — not a checklist
for the human.** The PR must never contain "How to verify" instructions telling
the reviewer to log in, activate pages, create records, click around. You do
all of that yourself in Step 3 and attach the evidence (screenshots, SOQL
output, test results). The reviewer's only verification is glancing at the
evidence and optionally clicking the scratch-org URL.

**If your change creates a custom Lightning record page (FlexiPage), you
also activate it through metadata** — object `actionOverrides` for org-default
record pages, or app `actionOverrides` / `profileActionOverrides` for
app/profile-specific assignments. Do not use App Builder, Setup, or Tooling API
activation guesses. A non-activated page is invisible to users, so shipping one
is the same as shipping nothing. Verification without activation is impossible
because the new page is never rendered.

### Human approved the current plan

If the latest human reply after the most recent pending Butler plan clearly
approves that plan, post a brief acknowledgement and end it with this exact
trailing line:

    <!-- butler:execute -->

Stop after posting. The workflow will start the execute job with the latest
pending plan as context. Approval can be natural language; do not require humans
to use keywords.

### Human corrected the plan

If the latest human reply changes the implementation approach, scope, or
verification expectations, post a revised concrete plan and end it with:

    <!-- butler:plan status=pending -->

Stop. The revised plan needs human approval before execution.

### Human response is ambiguous

If the latest human reply asks a question, discusses tradeoffs, or does not
clearly approve the current plan, answer briefly or ask one concise clarifying
question. If the current plan should remain pending, include:

    <!-- butler:plan status=pending -->

Do not execute.

**Sizing.** Use judgment, not a checklist. A request that fits one PR usually
touches 1–3 Apex classes plus their tests, optionally one LWC, optionally a
handful of metadata files (custom fields, queues, perm sets, a Flow). It does
**not** cross several subsystems at once (a new action **and** a new prompt
template **and** a memory write) and does **not** require architectural
decisions that aren't already settled in the codebase. If you're not sure,
propose a split.

**Schema is in scope.** Custom fields, custom objects, queues, Flows,
Permission Sets, Custom Metadata, record types — author them alongside the
Apex when the request needs them. Do **not** refuse for "missing
prerequisites" if the prerequisite is something the issue is asking you to
create. The whole point of the pipeline is to go from words to a working PR;
demanding that a human pre-create the field defeats it.

### Ask for clarification

The request is unclear, ambiguous, or contradicts something already in the
codebase or thread. Post a comment naming exactly what you need to decide
before you can plan — one or two crisp questions, not a list of ten. **Do not**
include the execute marker. Stop.

### Propose a split

The work is implementable but bigger than one PR. Comment with a proposed
split — each sub-story sized to ~1 class + tests + the metadata it needs.
Name what should land first and why. **Do not** include the execute marker.
Stop. A human will open the sub-issues and mention you on them.

### Refuse

A small number of changes genuinely shouldn't go through the pipeline:

- `config/`, `sfdx-project.json`, or `.github/workflows/` changes — these belong in a separate human PR for safety.
- Feedback that contradicts the original issue without explanation — ask for clarification instead of guessing.
- Anything listed in the consuming repo's `CLAUDE.md` refuse-list addendum.

Comment with the reason in one sentence. **Do not** include the execute
marker. Stop.

## Step 2 — Code

Touch whatever the change actually requires — classes, LWC, agent metadata
(`genAiFunctions/`, `genAiPlugins/`, `genAiPromptTemplates/`), permission sets,
queues, custom fields, Flows, Testing Center XML, anything else under
`force-app/` or `unpackaged/`. The triage in Step 1 is what protects against
scope creep, not a folder allowlist.

Apex / coding rules live in the consuming repo's `CLAUDE.md` and any
`rules/` files it references — follow them. Repo-specific deploy gotchas
(namespace stripping, Agentforce-specific fixups, etc.) also belong in
`CLAUDE.md` — read it alongside this skill.

Read each file you will change in full before editing. Then write the change
and update or add the test class.

For unknown Salesforce XML shape, do not invent it and do not use Setup UI.
Find a recent real source shape from public GitHub or a live-org retrieve, adapt
only the needed values, keep the shipped metadata minimal, and validate by
deploy. If two focused deploy attempts fail on the same metadata file, stop and
post the exact blocker instead of switching to API archaeology or browser setup
work.

For FlexiPage RecordPages, follow the `flexipages.md` recipe.

### Salesforce CLI command discipline

Run Salesforce CLI metadata commands in the foreground with a Bash timeout. Do
not background `sf project retrieve start`, `sf project deploy start`, or
metadata inspection commands. Do not poll `/tmp/claude-*/tasks/*.output` files
as a normal workflow.

Use this shape:

```bash
timeout 180 sf project retrieve start --metadata "Layout:Account-Account Layout" --target-org "$SCRATCH_ORG_ALIAS"
timeout 180 sf project deploy start --source-dir "force-app/main/default/layouts/Account-Account Layout.layout-meta.xml" --concise
```

If a command was forced into the background by the tool harness, wait for that
command's result once. Do not start a second equivalent retrieve/deploy while
the first one is still running.

Before repeating the same metadata list, retrieve, or deploy command, state what
changed since the previous run. If nothing changed, use the previous output and
continue with the smallest next step.

## Step 3 — Verify

Redeploy the changed file (the script already deployed everything else):

    timeout 180 sf project deploy start --source-dir <changed-file-path> --concise

If the consuming repo's `CLAUDE.md` describes a namespace strip-deploy-restore
dance or other pre-deploy massaging, follow that instead.

### Salesforce metadata deploy failure protocol

On the first Salesforce metadata deploy failure, stop editing. Do not make a
second guess.

1. Capture the exact deploy error.
2. Classify the failing metadata type from the source path and error text.
3. Read `knowledge/salesforce-metadata/INDEX.md`.
4. Read the routed knowledge file(s).
5. Apply one targeted fix.
6. Redeploy the smallest relevant source path.

If local knowledge does not resolve the failure, use a retrieved org artifact or
a recent public GitHub source file for structure. Official docs help interpret
fields, but real source shape plus current-org deploy is the validation. Do not
open Salesforce Setup or App Builder to create, inspect, or activate metadata.

After a fix, failure, cancellation, or repeated metadata loop that required
research or retrieval, update the matching knowledge file with the exact symptom,
likely cause or observed hypothesis, fix or attempted fix, validation outcome,
source, trust marker, and date.

Run tests **in the foreground** with a Bash timeout long enough to cover the full Apex run (the CLI `--wait 30` is 30 minutes — the Bash timeout must match):

    sf apex run test --test-level RunLocalTests --wait 30 --result-format human

Do **not** background this call and poll `TaskOutput` — the 5-minute `TaskOutput` cap is shorter than a real test run, the agent will read "still running" and stall the PR. Use Bash `timeout: 1800000` (30 min) and let the CLI print results directly when finished.

Run the `/sf-code-analyzer` skill on the files you changed. Use the
selectors the consuming repo's setup configures (typically via
`code-analyzer.yaml` at the repo root). Fix every new finding the agent
caused, on the lines you touched.

**Scope discipline:** the analyzer reports findings on the whole file, but you
own only the lines you touched. Findings on lines you did not change are
pre-existing — ignore them. Do not investigate or fix them.

Repeat until tests pass and the analyzer reports no new findings on lines
you touched.

If your plan included a Playwright scenario (bug repro or UI verification),
invoke the `playwright-sf` skill to run it now against the scratch org.
Use CLI/scripted Playwright first; use MCP only as a fallback discovery tool
when selectors cannot be determined on the final user-facing page. Never use
Playwright or MCP to configure Salesforce Setup/App Builder. Classic
`npx playwright test` is for
committed regression specs, not the default one-off PR evidence path. Attach
the resulting screenshots to the PR body in Step 4. A `UI-FAIL` result means
the change is wrong — iterate. A `UI-INCONCLUSIVE` result means the assertion
couldn't load reliably — note it in the PR but don't block on it.

If the plan required a video, do not treat a committed `.mp4` as proof by
itself. The `playwright-sf` skill must extract frames from the final committed
video and inspect them before the PR claims video verification. A video showing
login, Access Denied, Setup, a blank page, or the wrong record is invalid even
if the script logs passed assertions or SOQL confirms backend data.

## Step 4 — Ship

Commit and push:

    git add force-app/main/default/classes/<changed files>
    git commit -m "<one short sentence describing the change>"
    git push

### Always include the scratch org URL — non-negotiable

Every "I implemented this" surface — the PR body, every reply to a reviewer,
the post-execution summary comment — **must** include a clickable auto-login
URL to the per-PR scratch org. Reviewers should be able to click through and
poke at the change themselves without re-deploying anything. The scratch org
is throwaway, so the URL is safe to post in a public repo.

    SCRATCH_URL=$(sf org open --url-only --target-org "$SCRATCH_ORG_ALIAS" --json | jq -r .result.url)

(`SCRATCH_ORG_ALIAS` is set by the workflow to `pr-<issue-number>`.)

If you also produced Playwright screenshots, embed them inline in the same
markdown body — `playwright-sf` writes them under a path you can commit to
the branch; use absolute raw GitHub URLs so GitHub renders them in PR bodies
and comments. The pair "here's a
screenshot of it working / here's the org if you want to see for yourself"
is what makes the PR self-evidencing.

### Opening a new PR

If a PR for the current branch does **not** yet exist, open one. The body must be
specific enough that a reviewer can act without re-reading the issue — but no wall
of text. Aim for ~5–10 lines: what changed, what you verified, the scratch org URL,
the issue link.

**Always write the body to a file and pass `--body-file`.** Don't try to inline it
via `--body "$(cat <<EOF...EOF)"` — backticks and `$()` inside the markdown body
collide with shell expansion and the call fails in ways that take several turns
to recover from. Use this exact pattern:

    BRANCH=$(git branch --show-current)
    if [ -z "$(gh pr list --head "$BRANCH" --json number --jq '.[0].number')" ]; then
      cat > /tmp/pr-body.md <<'EOF'
    Closes #<issue-number>

    ## What changed
    <2–4 bullets — what classes/methods were modified and why>

    ## Verified
    <what you, the agent, verified — Apex test counts, Playwright screenshots
    embedded inline by raw GitHub URL, SOQL excerpts. Do NOT write instructions
    for a human to follow; the only human verification is clicking the scratch
    URL below if curious.>

    Scratch org:
    EOF
      # Append volatile URLs outside the quoted heredoc. Do not use sed: Salesforce
      # frontdoor URLs contain `&` and other characters that corrupt replacements.
      printf '%s\n' "$SCRATCH_URL" >> /tmp/pr-body.md
      gh pr create \
        --title "fix: <short description>" \
        --body-file /tmp/pr-body.md \
        --head "$BRANCH" \
        --base main \
        --label ai-involved
    fi

The single-quoted `<<'EOF'` heredoc disables shell expansion inside the body, so
backticks for code spans and `$variables` in narrative both stay literal. Append
volatile URLs with `printf` after the heredoc; do not use `sed`.

If the PR already exists, the push above updates it — no new PR. When you reply
to feedback with `gh pr comment`, include `$SCRATCH_URL` in the comment body too.

### Stop here

Once the push has succeeded **and** the summary comment has been posted, **stop**.
Do not run further `gh pr view`, `git status`, `git log`, or other verification
commands to "double-check" — the work is done, and additional turns burn the budget
without changing the outcome.

## Anti-patterns

- Skipping Step 1 — touching code before reading the thread and posting a comment that names what you're about to do.
- Acknowledging a request without naming concrete classes / metadata in the plan ("I'll add the action" is not a plan).
- Including the `<!-- butler:execute -->` marker before a human has clearly approved the current pending plan.
- Refusing because a custom field, queue, or Flow doesn't exist yet, when the issue is asking you to create it.
- Opening a second PR when one already exists for the branch.
- Investigating PMD findings on lines you did not touch.
- Calling `create-scratch-org.sh` — the workflow already restored or provisioned the org.
- Re-deploying everything via `--source-dir force-app` on a follow-up run — only deploy the files you changed.
- Backgrounding Salesforce CLI metadata commands or polling `/tmp/claude-*/tasks/*.output` instead of using foreground commands with `timeout`.
- Repeating the same metadata list/retrieve/deploy command without a changed input or an inconclusive prior result.
- Posting a PR description or reviewer reply without the scratch org auto-login URL.
- Stopping after a green test run without `git push`.
- Continuing to run verification commands after the push and summary comment — that's the post-completion loop, exit instead.
