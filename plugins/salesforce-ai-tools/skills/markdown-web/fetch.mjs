#!/usr/bin/env node

import { chromium } from "playwright";
import TurndownService from "turndown";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

export function loadConfig() {
  return JSON.parse(readFileSync(join(__dirname, "sites.json"), "utf-8"));
}

export function matchSite(config, url) {
  const { hostname, pathname } = new URL(url);
  const matches = config.sites.filter(
    (s) => hostname === s.domain || hostname.endsWith(`.${s.domain}`)
  );
  // Prefer entries with a pathPattern that matches, fall back to entry without one
  const pathMatch = matches.find(
    (s) => s.pathPattern && new RegExp(s.pathPattern).test(pathname)
  );
  if (pathMatch) return pathMatch;
  const domainOnly = matches.find((s) => !s.pathPattern);
  if (domainOnly) return domainOnly;
  return { domain: hostname, ...config.defaults };
}

export function cleanMarkdown(md) {
  return (
    md
      .replace(/\n{3,}/g, "\n\n")
      .replace(/\[([^\]]*)\]\(\s*\)/g, "$1")
      .trim() + "\n"
  );
}

async function fetchPage(url) {
  const config = loadConfig();
  const site = matchSite(config, url);
  const content = site.content;

  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext();
    if (site.cookies?.length) {
      await context.addCookies(site.cookies);
    }

    const page = await context.newPage();

    // LWC synthetic shadow intercepts DOM APIs (innerHTML, querySelector, etc.)
    // Save native methods before the page loads so we can bypass the interception.
    if (site.syntheticShadow) {
      await page.addInitScript(() => {
        window.__nativeInnerHTML = Object.getOwnPropertyDescriptor(
          Element.prototype,
          "innerHTML"
        );
        window.__nativeQS = Element.prototype.querySelector;
        window.__nativeQSA = Element.prototype.querySelectorAll;
      });
    }

    const waitUntil = site.syntheticShadow ? "networkidle" : "load";
    await page.goto(url, { waitUntil, timeout: 30000 });

    if (site.syntheticShadow) {
      // Dismiss Aura error overlays that block rendering
      await page.evaluate(() => {
        document.querySelector("#auraErrorMask")?.remove();
        document.querySelector(".auraForcedErrorBox")?.remove();
      });
    }

    // Wait for content to render
    await page.waitForFunction(
      ({ shadowPath = [], waitFor, _synthetic }) => {
        if (_synthetic) {
          const qs = window.__nativeQS;
          return qs ? !!qs.call(document.body, waitFor) : false;
        }
        let root = document;
        for (const tag of shadowPath) {
          const el = root.querySelector(tag);
          if (!el?.shadowRoot) return false;
          root = el.shadowRoot;
        }
        return !!root.querySelector(waitFor);
      },
      { ...content, _synthetic: !!site.syntheticShadow },
      { timeout: 15000 }
    );

    if (!site.syntheticShadow) {
      // Wait for code blocks to render (they load lazily after shadow DOM)
      await page.waitForFunction(
        ({ shadowPath = [] }) => {
          let root = document;
          for (const tag of shadowPath) {
            const el = root.querySelector(tag);
            if (!el?.shadowRoot) return false;
            root = el.shadowRoot;
          }
          const cbs = root.querySelectorAll("dx-code-block");
          if (cbs.length === 0) return true;
          const first = cbs[0].shadowRoot?.querySelector(
            ".code-block-content pre"
          );
          return !!first;
        },
        content,
        { timeout: 10000 }
      ).catch(() => {}); // non-fatal — page may have no code blocks
    }

    // Extract HTML
    const html = site.syntheticShadow
      ? await page.evaluate(
          ({ selector, removeSelectors = [] }) => {
            const qs = window.__nativeQS;
            const qsa = window.__nativeQSA;
            const getHTML = window.__nativeInnerHTML.get;

            const container = qs.call(document.body, selector);
            if (!container)
              throw new Error(`Selector "${selector}" not found`);

            for (const sel of removeSelectors) {
              for (const el of qsa.call(container, sel)) el.remove();
            }

            return getHTML.call(container);
          },
          content
        )
      : await page.evaluate(
          ({ shadowPath = [], selector, removeSelectors = [] }) => {
            let root = document;
            for (const tag of shadowPath) {
              const el = root.querySelector(tag);
              if (!el?.shadowRoot)
                throw new Error(`shadowPath step '${tag}' not found or has no shadowRoot`);
              root = el.shadowRoot;
            }

            const container = root.querySelector(selector);
            if (!container)
              throw new Error(`Selector "${selector}" not found`);

            for (const sel of removeSelectors) {
              for (const el of container.querySelectorAll(sel)) el.remove();
            }

            // Inline dx-code-block shadow content before serializing
            for (const cb of container.querySelectorAll("dx-code-block")) {
              const cbc = cb.shadowRoot?.querySelector(
                ".code-block-content pre code"
              );
              if (cbc) {
                const lines = cbc.querySelectorAll(".line");
                const text = lines.length
                  ? Array.from(lines)
                      .map((l) => l.textContent)
                      .join("\n")
                  : cbc.textContent;
                const pre = document.createElement("pre");
                const codeEl = document.createElement("code");
                codeEl.textContent = text;
                pre.appendChild(codeEl);
                cb.replaceWith(pre);
              }
            }

            return container.innerHTML;
          },
          content
        );

    const turndown = new TurndownService({
      headingStyle: "atx",
      codeBlockStyle: "fenced",
    });

    return cleanMarkdown(turndown.turndown(html));
  } finally {
    await browser.close();
  }
}

// CLI entry point — skip when imported as a module
const isCLI =
  process.argv[1] &&
  fileURLToPath(import.meta.url) === process.argv[1];

if (isCLI) {
  const args = process.argv.slice(2);
  let limit = Infinity;
  const limitIdx = args.indexOf("--limit");
  if (limitIdx !== -1) {
    const raw = args[limitIdx + 1];
    const parsed = Number(raw);
    if (!Number.isInteger(parsed) || parsed <= 0) {
      process.stderr.write(`Invalid --limit value: ${raw}\n`);
      process.exit(1);
    }
    limit = parsed;
    args.splice(limitIdx, 2);
  }

  const url = args[0];
  if (!url) {
    process.stderr.write("Usage: node fetch.mjs [--limit N] <url>\n");
    process.exit(1);
  }

  // Suppress noisy browser stderr (protocol errors, font warnings, etc.)
  // but keep a reference so real failures can still surface.
  const writeStderr = process.stderr.write.bind(process.stderr);
  process.stderr.write = () => true;

  try {
    let md = await fetchPage(url);
    if (limit !== Infinity) {
      const lines = md.split("\n");
      if (lines.length > limit) md = lines.slice(0, limit).join("\n") + "\n";
    }
    process.stdout.write(md);
  } catch (err) {
    writeStderr(`markdown-web: ${err.stack || err.message || err}\n`);
    process.exit(1);
  }
}
