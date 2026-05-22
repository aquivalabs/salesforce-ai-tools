---
name: markdown-web
description: Fetch JS-rendered webpages via headless Chromium, returning clean markdown. Handles shadow DOM, cookie consent overlays, and other JS-heavy patterns that defeat simpler fetchers.
trigger: Use when WebFetch returns empty or JS-gated content, or when the URL is on a known JS-heavy Salesforce site (developer.salesforce.com, help.salesforce.com). Other domains fall back to a generic extractor that may or may not work — try WebFetch first.
allowed-tools:
  - Bash(node ${CLAUDE_SKILL_DIR}/fetch.mjs *)
---

## Usage

Call the script directly — no pipes, redirects, or `cd`:

```bash
node ${CLAUDE_SKILL_DIR}/fetch.mjs --limit 400 "<url>"
```

The `--limit N` flag truncates output to N lines. Browser stderr is suppressed automatically. Do NOT add `2>/dev/null`, `| head`, or other shell plumbing.

## Setup (first time only)

```bash
cd ${CLAUDE_SKILL_DIR} && npm install && npx playwright install chromium
```

Heads up: `playwright install chromium` downloads ~300 MB on first run.

## Site configuration

Per-domain config lives in `${CLAUDE_SKILL_DIR}/sites.json`. Sites can specify cookies, shadow DOM traversal paths, content selectors, elements to remove, and a waitFor selector. Specialized configs exist for `help.salesforce.com` and `developer.salesforce.com`. Unknown domains fall back to sensible defaults (`main, article, body`).
