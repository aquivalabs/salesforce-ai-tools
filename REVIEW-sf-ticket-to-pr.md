# Review: sf-ticket-to-pr

A review of the skill and workflow through the lens of: minimal agent instructions, deterministic tools for deterministic processes, and simplicity.

## The good

- **Gate job is clean.** Deterministic permission check, bot-exclusion, pending-plan detection. No LLM needed, none used.
- **PR cleanup workflow is exemplary.** One job, no LLM, does exactly one thing. This is the standard the main workflow should aspire to.
- **Plan/approve/execute protocol is well-designed.** The two-phase triage/execute split with HTML-comment markers is elegant. Humans stay in the loop without ceremony.
- **Knowledge files are well-structured.** The symptom/cause/fix/validation shape is operational and retrieval-oriented. Good format.
- **Concurrency group keyed to scratch org alias** prevents races. Correct and simple.

## Problems

### 1. The SKILL.md is 449 lines -- 5x longer than any other skill

Compare: sf-code-analyzer is 68 lines, agentforce deploy is 112 lines, playwright-sf is 253 lines (and that one includes a full Node.js video-recording template).

The skill tries to be a complete runbook for an agent personality. Much of it is shell recipes the agent must parse and reproduce, not judgment calls the agent must make. The result is that the agent has to hold an enormous instruction set in context while making a simple decision (triage) or following a fixed procedure (ship).

### 2. Workflow prompts duplicate the skill

The triage prompt is ~80 lines and restates the plan/approve/execute decision tree that SKILL.md already fully specifies. Since the skill is loaded via the plugin, the triage prompt could be ~10 lines:

> You were summoned on {kind} #{number}. Follow sf-ticket-to-pr. Read the thread, decide, post your comment. Don't code.

Instead it re-explains all five decision branches, the comment-posting pattern, and the tone rules. The execute prompt does the same: re-explains "don't use Setup" and "don't use App Builder", which are already in the skill and in playwright-sf.

This duplication means two places to update when the protocol changes, and extra tokens in every run.

### 3. Shell recipes belong in scripts, not in agent instructions

Three patterns are repeated as prose instructions but are purely mechanical:

- **PR creation** (Step 4): ~30 lines of heredoc/printf/gh-pr-create shell. This is a script, not a judgment call. Extract to `scripts/butler-create-pr.sh`.
- **Comment posting**: "write to /tmp/butler-reply.md, use --body-file" appears 3+ times. A one-liner helper or just saying "use --body-file to avoid shell expansion issues" once would suffice.
- **Scratch URL generation**: The `sf org open --url-only` pattern appears in the skill and in playwright-sf. It's a fixed command, not a decision.

The principle: if the agent can't meaningfully vary the output, it shouldn't be generating it from prose instructions. A script is deterministic, testable, and doesn't consume agent turns or tokens.

### 4. Learning extraction is expensive premature infrastructure

Every execute run fires a third Claude invocation (Opus, up to 40 turns) to scan transcripts and update knowledge files. The knowledge entries created so far come from just two runs. The "Prepare metadata learning context" step does a broad grep (`salesforce|metadata|deploy|...`) that matches nearly everything, then asks Opus to find the needle.

For the current volume, a simpler approach works: if the deploy failed, the execute agent captures the error in its summary comment. A human (or a cheaper periodic batch) reviews those and updates knowledge files. The auto-extraction pipeline should be justified by data before it earns Opus pricing on every run.

### 5. Model selection is inverted

- **Triage uses Opus.** But triage is structured: read thread, classify into one of 5 buckets, post a comment. Sonnet handles this fine.
- **Execute uses Sonnet.** But execute is the creative/complex phase: read code, write Apex, debug deploys, run Playwright. This is where the stronger model pays off.
- **Learning extraction uses Opus.** For what's essentially pattern matching on transcript lines.

The current setup (bbc298e) documents this as intentional ("Use Opus for triage and learning extraction, keep Sonnet for execute"), but the reasoning inverts the complexity gradient. Triage is a classification task; execution is an open-ended coding task.

### 6. Anti-patterns section is reactive, not structural

20+ anti-patterns, many of which are "don't do X" where X was only tempting because the instructions were ambiguous. Examples:

- "Skipping Step 1" -- a well-structured workflow already prevents this (triage runs before execute).
- "Opening a second PR when one already exists" -- the PR-creation script should check this, not the agent.
- "Backgrounding SF CLI commands" -- mentioned three times across the skill.

A shorter, better-structured skill would make most of these unnecessary. The ones that survive should be at the point of use, not in a separate section the agent may or may not re-read.

### 7. Verification details leak into the planning phase

Step 1 (triage/planning) contains detailed Playwright instructions: when to use video vs screenshots, how interactive UIs differ, frame extraction. The triage agent doesn't execute any of this -- it just needs to write "Verification: Playwright screenshot of the record page" in the plan. The execution details belong in Step 3 where they're acted on.

### 8. Minor issues

- `DEV_HUB_URL: set` in the execute job's env block looks like a placeholder.
- `timeout-minutes: 15` on the execute job conflicts with `--wait 30` (30 minutes) for Apex test runs in the skill.
- The Preconditions section is 10 lines of "things the workflow already did." Could be 2 lines.

## Recommended changes

### Done (on this branch)

1. **Trimmed the triage and execute prompts** to ~5-10 lines each. The skill has the instructions; the prompt just provides context (kind, number, plan).
2. **Collapsed the Preconditions section** from 10+ lines to 6.
3. **Moved verification execution details from Step 1 to Step 3.** Step 1 now says *what* to plan for ("Playwright screenshot", "Playwright video") without explaining *how* to run Playwright.
4. **Deleted the anti-patterns section entirely.** Genuine footguns are now inline at point of use (e.g., "do not background SF CLI commands" in the CLI discipline section).
5. **Fixed `timeout-minutes`** on execute from 15 to 45 (the skill tells the agent to use `--wait 30` for Apex tests — a 15-minute job timeout would kill it).
6. **Removed `DEV_HUB_URL: set`** placeholder env var.
7. **Downgraded learning extraction** from Opus/40-turns to Sonnet/15-turns. It's pattern matching on transcript lines, not creative work.

Net result: SKILL.md 449→261 lines, workflow ~100 lines shorter, ~390 lines removed total.

### Do later (separate PR, needs discussion)

8. **Extract PR-creation and comment-posting to scripts.** These are pure shell; making them scripts removes token overhead and lets them be tested.
9. **Swap model assignments**: Sonnet for triage, Opus for execute. Or at least Sonnet for triage. The current setup uses Opus for the simpler job and Sonnet for the harder one.
10. **Evaluate whether to keep learning extraction at all.** The knowledge entries so far come from just two runs. A cheaper approach: the execute agent captures deploy errors in its summary comment; a human periodically reviews those and updates knowledge files.
11. **Evaluate the knowledge pipeline ROI.** Count how often a knowledge entry actually prevented a repeat failure vs. the cost of running extraction on every run.
