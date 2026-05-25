# FlexiPages

## Known Rules

- Never invent a FlexiPage template name from memory. The name must be confirmed
  via live-org retrieval or App Builder UI before deployment.
- `FlexiPageTemplate` is not a listable Metadata API type and is not queryable as
  a Tooling API sObject — both will return `INVALID_TYPE`.
- The correct way to discover a template name is: create the page in App Builder,
  save it, then read `Metadata.template.name` via the Tooling API.
- Standard template name for an Account Record Page (any `RecordPage` sObject
  using the default "Header and Right Sidebar" layout): `flexipage:recordHomeTemplateDesktop`.
- Metadata API source format uses colon-separated namespace, e.g.
  `flexipage:recordHomeTemplateDesktop`, not underscore or wrong-namespace variants.

## Template Discovery Sequence

When authoring a FlexiPage and the correct template name is unknown:

1. Open App Builder in the scratch org and create a minimal page of the same type
   and sObject.
2. Save it (a name is required).
3. Note the `id` from the URL (`0M0...`).
4. Read back the template name:

```bash
export SCRATCH_ORG_ALIAS="pr-<N>"
INSTANCE_URL=$(sf org display --target-org "$SCRATCH_ORG_ALIAS" --json | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['instanceUrl'])")
ACCESS_TOKEN=$(sf org display --target-org "$SCRATCH_ORG_ALIAS" --json | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['accessToken'])")
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$INSTANCE_URL/services/data/v65.0/tooling/sobjects/FlexiPage/<ID>" \
  | python3 -c "import json,sys; meta=json.load(sys.stdin).get('Metadata',{}); print(meta.get('template',{}).get('name','?'))"
```

5. Use the returned name in your FlexiPage XML.

## Symptoms

### Error
`Template c:force_RecordLayout2Col doesn't exist.`

### Likely Cause
The `<name>` element inside `<template>` in the FlexiPage XML used
`force_RecordLayout2Col` (underscore, no namespace). Salesforce prepends the
default `c:` namespace to unrecognised names, producing `c:force_RecordLayout2Col`
at deploy time, which then fails. The correct template name for a RecordPage with
the "Header and Right Sidebar" layout is `flexipage:recordHomeTemplateDesktop`.

### Fix
Replace the `<template><name>` value with the confirmed template name:

```xml
<template>
    <name>flexipage:recordHomeTemplateDesktop</name>
</template>
```

Confirmed in run `26417341847` by creating a page in App Builder, saving it,
then reading `Metadata.template.name` from the Tooling API, which returned
`flexipage:recordHomeTemplateDesktop`.

### Validation
Run `26417341847` confirmed the template name via Tooling API retrieval
(`curl .../tooling/sobjects/FlexiPage/<id>`). The deploy with the corrected
template was not attempted before the run hit `error_max_turns` — template name
confirmed by retrieval only, not by a passing deployment.

### Source
GitHub Actions run `26417341847`; live-org App Builder creation + Tooling API
`Metadata.template.name` retrieval.

### Trust
AI-observed, not human-reviewed

### Confirmed
2026-05-25
