# Quick Actions

## Known Rules

- Object quick action source files use dot naming:
  `force-app/main/default/quickActions/Account.LogSupportNote.quickAction-meta.xml`
- Do not use hyphen naming like `Account-Log_Support_Note.quickAction-meta.xml`.
- If creating an LWC quick action, retrieve the deployed action after the first
  successful deploy and keep the org-returned shape.

## Symptoms

### Error
`Name: The Action API Name can only contain underscores and alphanumeric characters. It must be unique, begin with a letter, not include spaces, not end with an underscore, and not contain two consecutive underscores.`

### Likely Cause
Wrong object quick action source-path naming. In run `26237825260`, the agent
created `Account-Log_Support_Note.quickAction-meta.xml` and Salesforce rejected
the action API name.

### Fix
Use `Object.ActionApiName` source-path naming. For the failed run, the correct
file was:

`force-app/main/default/quickActions/Account.LogSupportNote.quickAction-meta.xml`

### Validation
`sf project retrieve start --metadata "QuickAction:Account.LogSupportNote" --target-org pr-3`

### Source
GitHub Actions run `26237825260`; live-org retrieve returned
`Account.LogSupportNote.quickAction-meta.xml`.

### Trust
AI-observed, not human-reviewed

### Confirmed
2026-05-21
