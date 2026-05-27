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

2. Get a real FlexiPage XML shape before editing.
   - First try to retrieve the target page from the org:
     `timeout 180 sf project retrieve start --metadata "FlexiPage:<Page_Api_Name>" --target-org "$SCRATCH_ORG_ALIAS"`
   - If the exact page does not exist, use a recent public GitHub RecordPage or
     another retrieved RecordPage as the structural example.
   - Do not use unrelated FlexiPage types such as Utility Bars.
   - Do not guess structure from memory.
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

6. Activate the page.
   - If the story creates a new custom record page, activate it as org default or
     the requested app/profile assignment.
   - Activation is metadata work. Use retrieved metadata or recent source examples
     for the assignment shape.
   - Do not open App Builder or Setup to activate the page.
   - Do not query invented activation metadata types.
   - If the assignment metadata cannot be found or validated quickly, stop with
     that blocker instead of using browser clicks.
   - A deployed but inactive record page is not shipped.

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
