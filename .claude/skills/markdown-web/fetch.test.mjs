import { describe, it, before } from "node:test";
import assert from "node:assert/strict";
import { matchSite, cleanMarkdown } from "./fetch.mjs";

describe("matchSite", () => {
  const config = {
    sites: [
      { domain: "developer.salesforce.com", pathPattern: "/references/", content: { selector: "div.ref" } },
      { domain: "developer.salesforce.com", pathPattern: "^/docs/ai/", content: { selector: "div.ai" } },
      { domain: "developer.salesforce.com", content: { selector: "div.sf" } },
      { domain: "example.com", content: { selector: "main" } },
    ],
    defaults: { cookies: [], content: { selector: "body" } },
  };

  it("matches exact domain", () => {
    const site = matchSite(config, "https://developer.salesforce.com/docs/foo");
    assert.equal(site.content.selector, "div.sf");
  });

  it("prefers first matching pathPattern", () => {
    const site = matchSite(config, "https://developer.salesforce.com/docs/ai/agentforce/references/agent-api");
    assert.equal(site.content.selector, "div.ref");
  });

  it("matches second pathPattern when first does not match", () => {
    const site = matchSite(config, "https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api.html");
    assert.equal(site.content.selector, "div.ai");
  });

  it("falls back to domain-only when no path matches", () => {
    const site = matchSite(config, "https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/foo.htm");
    assert.equal(site.content.selector, "div.sf");
  });

  it("matches subdomain", () => {
    const site = matchSite(config, "https://sub.example.com/page");
    assert.equal(site.domain, "example.com");
  });

  it("falls back to defaults for unknown domain", () => {
    const site = matchSite(config, "https://unknown.org/page");
    assert.equal(site.content.selector, "body");
    assert.equal(site.domain, "unknown.org");
  });
});

describe("cleanMarkdown", () => {
  it("collapses excessive blank lines", () => {
    const result = cleanMarkdown("# Title\n\n\n\n\nParagraph");
    assert.equal(result, "# Title\n\nParagraph\n");
  });

  it("strips empty links but keeps text", () => {
    const result = cleanMarkdown("See [Type Class]() for details");
    assert.equal(result, "See Type Class for details\n");
  });

  it("leaves valid links intact", () => {
    const result = cleanMarkdown("See [docs](https://example.com)");
    assert.equal(result, "See [docs](https://example.com)\n");
  });

  it("trims whitespace", () => {
    const result = cleanMarkdown("  hello  \n\n  ");
    assert.equal(result, "hello\n");
  });
});

describe("integration", { skip: process.env.CI ? "skipped in CI" : false }, () => {
  let exec, script;

  before(async () => {
    const { execFile } = await import("node:child_process");
    const { promisify } = await import("node:util");
    exec = promisify(execFile);
    const { fileURLToPath } = await import("node:url");
    const { dirname, join } = await import("node:path");
    script = join(dirname(fileURLToPath(import.meta.url)), "fetch.mjs");
  });

  it("fetches developer.salesforce.com (native shadow DOM)", async () => {
    const url = "https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm";
    const { stdout } = await exec("node", [script, url], { timeout: 45000 });

    assert.ok(stdout.includes("# Type Class"), "should have page title");
    assert.ok(stdout.includes("## Namespace"), "should have namespace heading");
    assert.ok(stdout.includes("forName"), "should mention forName method");
    assert.ok(!stdout.includes("ullinks"), "should not contain TOC list class");
    assert.ok(stdout.includes("```"), "should have fenced code blocks");
  });

  it("fetches developer.salesforce.com API reference (deep shadow DOM)", async () => {
    const url = "https://developer.salesforce.com/docs/ai/agentforce/references/agent-api?meta=Summary";
    const { stdout } = await exec("node", [script, url], { timeout: 45000 });

    assert.ok(stdout.includes("Agent API"), "should have API title");
    assert.ok(stdout.includes("Endpoints"), "should have endpoints section");
  });

  it("fetches developer.salesforce.com AI docs (no shadow DOM)", async () => {
    const url = "https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api.html";
    const { stdout } = await exec("node", [script, url], { timeout: 45000 });

    assert.ok(stdout.includes("# Agent API Developer Guide"), "should have page title");
    assert.ok(stdout.includes("Agent API"), "should have content");
  });

  it("fetches help.salesforce.com (LWC synthetic shadow)", async () => {
    const url = "https://help.salesforce.com/s/articleView?id=sf.data_sandbox_create.htm&type=5";
    const { stdout } = await exec("node", [script, url], { timeout: 60000 });

    assert.ok(stdout.includes("# Create a Sandbox"), "should have article title");
    assert.ok(stdout.includes("Sandbox"), "should have article content");
    assert.ok(!stdout.includes("You are here"), "should not contain breadcrumbs");
    assert.ok(!stdout.includes("Did this article solve"), "should not contain feedback widget");
  });
});
