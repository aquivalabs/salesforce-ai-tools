# FlexiPages

## Recipe: LWC on a Lightning Record Page

Use this when a story asks for an LWC on an Account, Contact, Case, Opportunity,
or other Lightning record page.

1. Build and deploy dependencies first.
   - Create Apex/classes first when the LWC calls Apex.
   - Create the LWC second.
   - The LWC metadata must expose `lightning__RecordPage`.
   - Deploy Apex/classes and the LWC before touching the FlexiPage.
   - A FlexiPage deploy cannot validate a custom component that is not in the
     org yet.

2. Get a real FlexiPage XML shape before editing. Never guess structure from memory.
   - Default to a recent public GitHub RecordPage of the same object/template
     family and copy its region/component shape. A fresh scratch org has no
     retrievable standard RecordPage — `FlexiPage` retrieve there returns only
     Utility Bars or "cannot be found", so org-retrieve is not the starting move.
   - Only retrieve from the org when the target page already exists as a
     customized page:
     `timeout 180 sf project retrieve start --metadata "FlexiPage:<Page_Api_Name>" --target-org "$SCRATCH_ORG_ALIAS"`
   - Use only RecordPage examples. Never use Utility Bar FlexiPages.
   - Stop once you have a RecordPage with enough region/component shape to place
     the LWC. Public examples are structure only; the org deploy is truth.

3. Author the smallest valid FlexiPage.
   - Set `<type>RecordPage</type>`.
   - Set the correct `<sobjectType>...</sobjectType>`.
   - Use the template from a retrieved page or a public example that deploys in
     the current org.
   - For a standard desktop record page with header and right sidebar, the known
     template is `flexipage:recordHomeTemplateDesktop`.
   - Add only the region/component XML needed for the story. Do not copy a whole
     public page full of unrelated standard components.
   - Do not add standard Salesforce components from memory. If a standard
     component is required, copy its name/properties from real source.

4. Deploy in dependency order.
   - Deploy Apex/classes first.
   - Deploy the LWC second.
   - Deploy the FlexiPage last.
   - Deploy the smallest source path that can validate the change.

5. If FlexiPage deploy fails, fix the exact XML shape error once.
   - Do not switch metadata types.
   - Do not invent a new template name.
   - Make one targeted XML change, then redeploy the same FlexiPage file.
   - Trust the current org deploy error over copied examples.
   - After a successful deploy, retrieve the FlexiPage back from the org and keep
     the org-normalized XML.
   - If the second focused deploy fails, stop and post the exact blocker.

6. Activate the page with object metadata. The FlexiPage XML defines the page;
   an `actionOverrides` entry on the object activates it as the org-default record
   page. No App Builder, no Setup, no Tooling API.
   - Add the override to `force-app/main/default/objects/<Object>/<Object>.object-meta.xml`
     (set `<content>` to the FlexiPage API name, `<Object>` to the target object):

     ```xml
     <CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
         <actionOverrides>
             <actionName>View</actionName>
             <content>Account_Record_Page</content>
             <formFactor>Large</formFactor>
             <skipRecordTypeSelect>false</skipRecordTypeSelect>
             <type>Flexipage</type>
         </actionOverrides>
     </CustomObject>
     ```

   - Deploy the FlexiPage, then the object metadata:

     ```bash
     sf project deploy start --source-dir force-app/main/default/flexipages/<Page>.flexipage-meta.xml
     sf project deploy start --source-dir force-app/main/default/objects/<Object>/<Object>.object-meta.xml
     ```

   - If the story requires app-level or app/profile-specific assignment instead
     of org default, activate through `CustomApplication` metadata in
     `force-app/main/default/applications/<App>.app-meta.xml` using
     `actionOverrides` or `profileActionOverrides`. Do not use this path unless
     the story asks for app/profile scoping.

   - A deployed but inactive record page is not shipped. Activation is required so
     the Step 7 Playwright verification can open the record and prove the page works.

7. Verify the visible user flow.
   - Open a real record in Lightning.
   - Confirm the LWC renders in the intended region.
   - Exercise the UI action.
   - Confirm the backend effect with UI or SOQL.
   - For interactive input flows, record a Playwright video.
   - Evidence from Setup or App Builder is not enough.

## Hard Rules

- Never hand-author FlexiPage XML from memory.
- Never use a template name that has not been retrieved, found in a real source
  file, or deploy-validated in the current org.
- `FlexiPageTemplate` is not a listable Metadata API type and is not queryable as
  a Tooling API sObject.
- Never use UtilityBar FlexiPages as RecordPage examples.
- Never use Salesforce Setup or App Builder for FlexiPage creation, inspection,
  or activation in this pipeline.
- Do not rely on a deploy alone. FlexiPage work is done only after activation and
  UI verification.

## Common RecordPage Tokens

- `RecordPage` page type: `<type>RecordPage</type>`
- Object binding: `<sobjectType>Account</sobjectType>`
- Standard desktop header/right-sidebar template:
  `flexipage:recordHomeTemplateDesktop`
- Metadata source path:
  `force-app/main/default/flexipages/<Page_Api_Name>.flexipage-meta.xml`

## Common Deploy Failures

### `Property 'componentInstances' not valid in version 65.0`

The copied example uses an older or incompatible region shape. Search for current
examples using `itemInstances` and `componentInstance`, then deploy again.

### `Template c:<name> doesn't exist`

The template name is missing the correct namespace or is not a valid template.
Use a retrieved or deploy-validated template name. For the default desktop
record page layout, use `flexipage:recordHomeTemplateDesktop`.

### `The '<region>' region ... specifies mode 'APPEND' but a parent region enabling that mode doesn't exist`

The region mode does not match the page/template relationship. Search examples
for the same template and region. For a fresh minimal custom page, omit copied
`<mode>` values unless the matching source shape proves they are needed.

### `<mode>Replace</mode>` on a region but no `<parentFlexiPage>` declared

### Error
FlexiPage deploy fails when `<flexiPageRegions>` elements include `<mode>Replace</mode>` but the page declares no `<parentFlexiPage>`.

### Likely Cause
`Replace` mode on a region is only valid when the page overrides a parent. A standalone page has no parent to replace against, so Salesforce rejects the mode tag.

### Fix
Remove all `<mode>` elements from `<flexiPageRegions>` when there is no `<parentFlexiPage>`. A standalone record page region requires no mode declaration.

### Validation
In run 26503751040, `sf project deploy start --source-dir force-app/main/default/flexipages/Account_Record_Page.flexipage-meta.xml` succeeded after removing all `<mode>` tags from a standalone FlexiPage with no `<parentFlexiPage>`. Reconfirmed in run 26512323943 (issue #20, fresh scratch org `pr-20`): the same mode-free standalone `Account_Record_Page` FlexiPage — reused for the `quickSupportNote` LWC — deployed clean on the first try with no `<mode>` tags and no `<parentFlexiPage>`.

### Source
GitHub Actions runs 26503751040 (issue #17) and 26512323943 (issue #20).

### Trust
AI-observed, not human-reviewed

### Confirmed
2026-05-27

## Org Normalization

### LWC component name namespace prefix stripped by no-namespace org

### Error
(Not a deploy error — a normalization difference.) After deploying a FlexiPage that references a custom LWC as `c:componentName`, the org-retrieved XML shows `componentName` (no `c:` prefix).

### Likely Cause
When a scratch org has no namespace (`"namespace": ""` in `sfdx-project.json`), the Metadata API normalizes custom LWC component names to unprefixed form.

### Fix
After every successful FlexiPage deploy, retrieve the FlexiPage back from the org and keep the returned XML. Do not hand-author the `c:` prefix back in — the retrieved form is authoritative.

### Validation
In run 26503751040, deployed with `<componentName>c:accountSupportNote</componentName>`, then retrieved; org returned `<componentName>accountSupportNote</componentName>`. No deploy error in either direction. Reconfirmed in run 26512323943 (issue #20, fresh scratch org `pr-20`): deployed the FlexiPage referencing the LWC in the already-normalized unprefixed form `<componentName>quickSupportNote</componentName>`; the org retrieve returned `quickSupportNote` unchanged — the org-normalized form round-trips with no deploy error.

### Source
GitHub Actions runs 26503751040 (issue #17) and 26512323943 (issue #20); live-org retrieve.

### Trust
AI-observed, not human-reviewed

### Confirmed
2026-05-27
