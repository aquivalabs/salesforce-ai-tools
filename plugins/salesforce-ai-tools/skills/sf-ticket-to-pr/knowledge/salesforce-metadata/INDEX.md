# Salesforce Metadata Knowledge Index

Read this before creating or editing Salesforce metadata.

If touching `quickActions/`, read `quick-actions.md`.
If adding an LWC record action, read `quick-actions.md`.
If touching `layouts/`, read `layouts.md`.
If a deploy error mentions `SummaryLayout`, `platformActionList`,
`quickActionList`, or layout assignment, read `layouts.md`.
If touching `flexipages/`, read `flexipages.md`.
If a deploy error mentions `FlexiPage`, `template`, or `doesn't exist` on a
flexipage deploy, read `flexipages.md`.
If adding or fixing Lightning record page activation through `actionOverrides`,
`profileActionOverrides`, `objects/`, or `applications/`, read `flexipages.md`.

If no route matches, use the deploy failure protocol in `SKILL.md`. After a
validated fix, add a compact entry or create a new metadata file.

## External Search Patterns

Use exact file suffixes, paths, XML elements, and error text.

```text
site:github.com "Account.LogSupportNote.quickAction-meta.xml"
site:github.com "LightningWebComponent" "quickAction-meta.xml"
site:github.com "platformActionList" "actionName" "QuickAction"
site:github.com "Account-Account Layout.layout-meta.xml"
site:github.com "SummaryLayout" "layout-meta.xml"
```

Public GitHub examples are shape discovery. Validate by deploy or live-org
retrieve before writing a rule.
