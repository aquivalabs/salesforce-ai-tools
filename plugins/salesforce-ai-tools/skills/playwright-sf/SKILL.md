---
name: playwright-sf
description: Verify Salesforce Lightning UI flows with Playwright CLI/scripts first, using Playwright MCP only for fallback selector discovery. Captures screenshot/video evidence for sf-ticket-to-pr or standalone use.
---

# Playwright in a Salesforce Org

Default to Playwright CLI or small scripted Playwright runs for Salesforce UI verification. CLI/scripted runs keep browser state, traces, snapshots, and videos outside the model context, so they are cheaper and repeatable in GitHub Actions. Use Playwright MCP only as a fallback discovery tool when you cannot determine selectors from the scripted run output.

Playwright verifies user-facing Salesforce pages only. Do not use Playwright,
MCP, Setup, or App Builder to configure Salesforce metadata, activate pages, or
perform admin setup. If configuration is required, do it through source,
Salesforce CLI, or API-backed metadata. If that path is unclear, report the
blocker instead of clicking through Setup.

Classic `npx playwright test` is for committed deterministic regression specs. Do not use it as the default one-off evidence path for a ticket unless you are adding or running a real regression spec.

## Tools you have

Use Bash first for Playwright CLI or Node.js scripts. When `@playwright/cli` is available, prefer it for one-off inspection because page state and snapshots stay on disk instead of streaming into the model context. The MCP server is available only for fallback selector discovery on final user-facing pages and exposes:

- `browser_navigate(url)` — open a URL
- `browser_snapshot()` — return the accessibility tree of the current page, with `ref` handles for every element
- `browser_click({ element, ref })` — click by `ref` from the snapshot
- `browser_type({ element, ref, text })` / `browser_fill_form` — type into a field by `ref`
- `browser_wait_for({ text | textGone | time })` — wait for content to appear/disappear or a fixed delay
- `browser_take_screenshot({ filename, fullPage })` — save a PNG
- `browser_press_key(key)` — keyboard input
- `browser_close()` — close the browser

## Log in via the frontdoor URL

Don't script the login form. Ask the CLI for a one-time auto-login URL and navigate to that:

    SCRATCH_URL=$(sf org open --url-only --target-org "$SCRATCH_ORG_ALIAS" --json | jq -r .result.url)

Navigate to that URL in MCP fallback discovery, or pass it as `SCRATCH_URL` for scripted runs. You land already logged in. The URL is single-use; if you need a second session, request another. Do not write it into a JS file.

**Land directly on the target page — don't navigate after login.** A bare
frontdoor URL drops you on the org home, and a second `page.goto()` to the
record can race the session cookie and bounce you to login. Pass the
destination with `--path` so the frontdoor redirects there *after* auth, in one
hop. A bare record id is enough — Salesforce resolves `/<id>` to that record's
correct page for any object, so you never need an object-specific URL:

    SCRATCH_URL=$(sf org open --url-only --path "/$RECORD_ID" --target-org "$SCRATCH_ORG_ALIAS" --json | jq -r .result.url)

Get the id first with a quick SOQL (`sf data query`) or create the record you
need. One `page.goto(SCRATCH_URL)` then lands logged-in on the record itself —
no follow-up navigation, no post-login bounce to debug.

## Find Things By Role, Not CSS

In scripts, prefer Playwright locators such as `getByRole`, `getByLabel`, and `getByText` with stable business text. Lightning selectors against Shadow DOM internals are brittle.

If the scripted run cannot determine selectors, use MCP briefly: `browser_snapshot` dumps the a11y tree with `ref` handles. Read the snapshot, identify the element by its accessible name + role ("button Save", "textbox Subject"), then encode that role/name in the script:

    page.getByRole('button', { name: 'Save' }).click()
    page.getByRole('textbox', { name: 'Subject' }).fill('value')

Lightning composes shadow roots into the a11y tree, so this works across LWC, Aura, and Visualforce without per-component selectors.

## Wait before you assert

Lightning pages spinner. Before every assertion, wait for a stable anchor you expect: the record name, a section header, the Save button, or the exact response text. In scripts, use `expect(locator).toBeVisible()` or `page.waitForFunction(...)`; in MCP fallback, use `browser_wait_for({ text: "<known anchor>" })`. If the anchor never shows up after two reasonable waits, report `UI-INCONCLUSIVE` rather than `UI-FAIL` — flaky load ≠ broken feature.

If backend state, a success toast, or earlier screenshots prove the requested
behavior but a dynamic Lightning panel does not refresh into the final frame,
do not keep re-recording. Make one focused retry with a changed wait/refresh
strategy, then report `UI-INCONCLUSIVE` and preserve the best artifacts.

## Screenshot Evidence

Every assertion writes a screenshot. Use Playwright CLI/scripted screenshots by default; use MCP screenshots only for fallback exploration. Write to a path **inside the branch** so the screenshots ride along with the commit and GitHub renders them inline in the PR body by raw URL:

    mkdir -p ".verification/pr-$ISSUE_NUMBER"
    # then either:
    page.screenshot({ path: ".verification/pr-$ISSUE_NUMBER/<scenarioId>.png", fullPage: true })
    # or, from MCP fallback discovery:
    browser_take_screenshot({ filename: ".verification/pr-$ISSUE_NUMBER/<scenarioId>.png", fullPage: true })
    git add -f ".verification/pr-$ISSUE_NUMBER/<scenarioId>.png"

`-f` because `.verification/` is gitignored on `main`; we force-add it on the PR branch and it disappears when the branch is deleted on merge.

Embed each screenshot with an **absolute raw GitHub URL** — GitHub Markdown
in PR bodies and comments does **not** render relative image paths. Use:

    https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>

Concretely:

    ## Verified
    ![Home page with accountGreeter LWC rendering](https://raw.githubusercontent.com/aquivalabs/my-org-butler/fix/issue-103/.verification/pr-103/account-after.png)

Substitute `<owner>/<repo>` from `$GITHUB_REPOSITORY`, `<branch>` from
`git branch --show-current`. Relative paths look right in `git diff` but
render as broken-image placeholders in the actual PR body — never use them
for embedded screenshots.

For bug repros, post the **before** and **after** as a pair.

Always pair screenshots with the scratch-org auto-login URL (see `sf-ticket-to-pr` Step 4) — "here's the screenshot" + "here's the org" is the self-evidencing pattern.

## When the caller is `sf-ticket-to-pr`

Two shapes:

**Bug reproduction.** The ticket describes broken behaviour. Before writing any fix, navigate to the broken state and capture screenshot evidence. Attach the repro evidence. After the fix deploys, re-run the same scenario and confirm it now passes.

**Feature verification.** After the change is deployed, walk through the acceptance criteria, screenshot the passing state. Cap at five screenshots per PR.

## Video Evidence

The MCP server cannot record video. When the full interaction sequence — user input → system processes → response appears — is the thing being proven, write a short Node.js script and run it via Bash. Playwright's `recordVideo` context option captures the session and flushes the file to disk when the context is closed.

MCP is only for discovering the UI shape before writing the script on the final
user-facing page. The script is the verification artifact. It must fail if
Salesforce shows login, Access Denied, Setup instead of the target page, a blank
page, the wrong record, or if the expected UI text never appears. Backend SOQL
plus a video file is not enough; the recorded pixels must prove the UI flow.

**Step 1 — locate the Chromium binary and the playwright module.** The workflow already installed Chromium via `npx playwright install --with-deps chromium`. Find it before writing the script:

    CHROME=$(find ~/.cache/ms-playwright /root/.cache/ms-playwright \
      ~/Library/Caches/ms-playwright \
      -type f \( -name 'chrome' -o -name 'chromium' \) 2>/dev/null | head -1)
    echo "Chromium: $CHROME"

Letting Playwright auto-resolve the executable path fails when the version in the npx cache doesn't match what was installed. Always pass the found path as `executablePath`.

For the `import`, install playwright temporarily so the module resolves cleanly:

    npm install --no-save playwright

**Step 2 — write the script.** Pass volatile values through environment variables. Do not embed or rewrite frontdoor URLs with `sed`; Salesforce URLs contain `&` and other characters that corrupt shell substitutions.

Do not delete the last good evidence before a replacement succeeds. For a
re-record, write into a fresh directory such as `.verification/pr-<N>/retry-1`
or copy the previous screenshots/video aside first. A failed re-record must not
erase the only useful artifacts from the run.

```js
import { chromium } from 'playwright';
import { mkdir, rm } from 'fs/promises';

const CHROME     = process.env.CHROME;
const FRONTDOOR  = process.env.SCRATCH_URL;
const VIDEO_DIR  = process.env.VIDEO_DIR || '.verification/pr-<N>';
const EXPECTED   = process.env.EXPECTED_TEXT;
const TARGET_TEXT = process.env.TARGET_TEXT;

if (!CHROME || !FRONTDOOR || !EXPECTED) {
  throw new Error('CHROME, SCRATCH_URL, and EXPECTED_TEXT are required');
}

await rm(VIDEO_DIR, { recursive: true, force: true });
await mkdir(VIDEO_DIR, { recursive: true });
const browser = await chromium.launch({ headless: true, executablePath: CHROME });
const context = await browser.newContext({
  viewport: { width: 1280, height: 720 },
  recordVideo: { dir: VIDEO_DIR, size: { width: 1280, height: 720 } },
});
const page = await context.newPage();

await page.goto(FRONTDOOR, { waitUntil: 'domcontentloaded' });
await page.waitForTimeout(3000); // give frontdoor time to set the session cookie

async function rejectBadShell(label) {
  const text = await page.locator('body').innerText({ timeout: 10000 }).catch(() => '');
  const url = page.url();
  if (!text.trim()) {
    throw new Error(`${label}: Salesforce page body is blank`);
  }
  if (/Access Denied|Salesforce login|Log In to Sandbox|You've been logged out/i.test(text) || /\/setup\/|\/SetupOneHome/i.test(url)) {
    throw new Error(`${label}: not authenticated or blocked by Salesforce shell`);
  }
}

async function assertTargetPage(label) {
  if (!TARGET_TEXT) return;
  const text = await page.locator('body').innerText({ timeout: 10000 }).catch(() => '');
  if (TARGET_TEXT && !text.includes(TARGET_TEXT)) {
    throw new Error(`${label}: expected target text not found: ${TARGET_TEXT}`);
  }
}

await rejectBadShell('after frontdoor login');

// Navigate and interact.
// Use stable business text and role selectors, not CSS selectors.
// If selectors are unclear, use one MCP browser_snapshot() to discover roles/names,
// then encode those getByRole/getByText locators here.

// Stop the moment the expected phrase is visible — no fixed sleep, no networkidle
await page.waitForFunction(
  expected => document.body.innerText.includes(expected),
  EXPECTED,
  { timeout: 90000, polling: 1000 }
);
await rejectBadShell('before closing video');
await assertTargetPage('before closing video');
await page.waitForTimeout(3000); // let the response settle visually

const video = page.video();
if (!video) {
  throw new Error('Playwright did not create a video for this page');
}
await context.close(); // flushes the video file to disk
await browser.close();

console.log(`webm: ${await video.path()}`);
```

Run it like this:

```bash
CHROME="$CHROME" \
SCRATCH_URL="$(sf org open --url-only --target-org "$SCRATCH_ORG_ALIAS" --json | jq -r .result.url)" \
VIDEO_DIR=".verification/pr-<N>" \
EXPECTED_TEXT="<text that proves the final UI state>" \
TARGET_TEXT="<record name or page anchor that proves the right page>" \
node .verification/pr-<N>/record-video.mjs
```

**Step 3 — convert the current video only.** `ffmpeg` is already installed by the
workflow — don't check for it or `apt-get install` it. Use the `webm:` path
printed by the script. Do not scan the directory or pick the first `.webm`.

    ffmpeg -i "<webm path printed by script>" -c:v libx264 -preset fast -crf 22 -movflags +faststart \
      .verification/pr-<N>/session.mp4 -y

**Step 4 — inspect frames before committing or linking.** Extract frames from the final `.verification/pr-<N>/session.mp4`. A video file existing is not evidence; the content is evidence.

    plugins/salesforce-ai-tools/skills/playwright-sf/scripts/extract-video-frames.sh \
      .verification/pr-<N>/session.mp4 /tmp/pr-<N>-frames

Open at least the first, middle, and last frame with an image viewer or image-capable tool. If any frame shows login, Access Denied, Setup, a blank page, or the wrong record, the video is invalid. Re-record it. Do not link or commit it, and do not claim video verification in the PR.

If frames show the right page and interaction but miss a late-refreshing
Lightning subpanel, run at most one focused re-record. After that, keep the
best evidence, report `UI-INCONCLUSIVE`, and let `sf-ticket-to-pr` ship with the
available screenshots, SOQL, and test evidence.

After frame inspection passes:

    git add -f .verification/pr-<N>/session.mp4

**Step 5 — link from the PR body.** GitHub Markdown does not auto-embed video from `raw.githubusercontent.com`, but the browser plays it natively when the reviewer clicks through — one click, new tab, plays immediately:

    [Watch recording](https://raw.githubusercontent.com/<owner>/<repo>/<branch>/.verification/pr-<N>/session.mp4)

**Finding elements for the script.** Start with Playwright role/text locators. If they fail or the names are unclear, take one `browser_snapshot()` via the MCP tools to see the current a11y tree. Read the accessible names and roles of the elements you need, then use `getByRole` / `getByText` in the script. Do not keep looping through MCP snapshots once the selectors are known.

## Anti-patterns

- Logging in by filling the username/password form. Use the frontdoor URL.
- Rewriting frontdoor URLs into scripts with `sed`. Pass them as environment variables.
- Picking elements by CSS selectors. Use a11y `ref` handles from `browser_snapshot`.
- Marking a flaky load as `UI-FAIL`. Use `UI-INCONCLUSIVE`.
- More than ~5 screenshots per PR. CI budget isn't infinite; pick the ones that prove the change.
- Verifying without ever opening the page in the org. If the change is user-visible and you didn't `browser_navigate` to it, the verify step didn't happen.
- Using `waitForLoadState('networkidle')` on Lightning pages — it never settles. Wait for a specific element instead.
- Recording video with the MCP tools — they cannot. Use the Node.js script above.
- Using a fixed sleep or timeout to decide when to stop recording. Wait for the expected response text, then close immediately.
- Selecting a video file with `readdir(...).find(f => f.endsWith('.webm'))`. Clean the video directory before recording and use `await page.video().path()` for the current page. Otherwise an old failed recording can be converted and committed.
- Claiming video verification without inspecting frames from the committed `session.mp4`.
- Treating backend SOQL assertions as proof that the recorded UI is correct.
- Looping through MCP snapshots after a CLI/scripted approach has enough selectors.
- Deleting previous screenshots/video before a replacement recording has passed frame inspection.
- Re-recording more than once for a flaky Lightning refresh when the implementation is already deployed and backend-verified.
