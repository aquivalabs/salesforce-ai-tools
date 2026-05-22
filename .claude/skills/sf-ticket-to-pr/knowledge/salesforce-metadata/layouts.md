# Layouts

## Known Rules

- Do not invent an object layout from memory.
- Retrieve the actual layout from the org before editing it.
- Layout filenames preserve the layout full name. `Account-Account_Layout` is a
  different layout from `Account-Account Layout`.
- If a quick action deploys but is not visible, check whether the changed layout
  is the one assigned/used by the record page.

## Symptoms

### Error
`Error parsing file: Element {http://soap.sforce.com/2006/04/metadata}style invalid at this location in type SummaryLayout`

### Likely Cause
Invented layout XML placed elements in a shape Salesforce parsed as
`SummaryLayout`. In run `26237825260`, this happened with
`force-app/main/default/layouts/Account-Account_Layout.layout-meta.xml`.

### Fix
Retrieve the real layout and edit the returned XML:

`sf project retrieve start --metadata "Layout:Account-Account Layout" --target-org pr-3`

Then deploy that exact file:

`force-app/main/default/layouts/Account-Account Layout.layout-meta.xml`

### Validation
Live-org retrieve returned `Account-Account Layout.layout-meta.xml`.

### Source
GitHub Actions run `26237825260`.

### Trust
AI-observed, not human-reviewed

### Confirmed
2026-05-21

### Error
Quick action deploys, but the action does not appear on the Account record page.

### Likely Cause
The agent deployed a new duplicate layout instead of editing the layout used by
the org. In run `26237825260`, org metadata listed both:

`Account-Account Layout`

`Account-Account_Layout`

The second was newly created and not the active Account layout.

### Fix
List or retrieve org layouts before deciding which layout file to edit:

`sf org list metadata --metadata-type Layout --target-org pr-3 --json`

Retrieve the real layout full name, then apply the quick action change there.

### Validation
Playwright showed the quick action missing; org metadata showed the duplicate
layout; retrieving `Layout:Account-Account Layout` returned the active layout
candidate.

### Source
GitHub Actions run `26237825260`.

### Trust
AI-observed, not human-reviewed

### Confirmed
2026-05-21
