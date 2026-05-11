# DEPLOYMENT.md

This file is intended for AI instances (Claude Code) working on retrieval and deployment tasks in this repository. It documents hard-won lessons from iterative deploy attempts. Read this before touching `sf project retrieve` or `sf project deploy`.

## Skills

Use the **`sf-deploy`** skill for deployment work in this project. Invoke it with `/sf-deploy` at the start of a deployment session — it provides structured validation and catches ordering issues early.

## Post-Deploy Verification

Before testing the app, confirm these are in place in the target org:

1. **Object** — `aha_Contractor_Incident__c` exists with all fields
2. **Apex** — `aha_ContractorIncidentEmailParser` is deployed and active
3. **Prompt Template** — `aha Contractor Incident - Email` exists and has `ahaContractorIncidentOBLTv4` set as Lightning Object Type
4. **Flows** — `aha Contractor Incident - Populate from Email` and `aha Contractor Incident Panel` are activated in Flow Builder
5. **Queue** — `Contractor Incidents` exists
6. **Email Service** — `aha_ContractorIncidentEmails` has an address configured with a valid Run As User

## Deploy Order

Salesforce validates flow references at deploy time. Always deploy in this sequence:

1. `LightningTypeBundle` — must exist before Prompt Templates or Flows reference it
2. `GenAiPromptTemplate` — must exist before Flows that call it as an action
3. Everything else (object, fields, apex, queue, email service, flows)

```bash
# Step 1: Lightning Type (must exist before Prompt Template)
sf project deploy start --source-dir force-app/main/default/lightningTypes --target-org <alias>

# Step 2: Prompt Template (must exist before Flows)
sf project deploy start --source-dir force-app/main/default/genAiPromptTemplates --target-org <alias>

# Step 3: Everything else
sf project deploy start \
  --source-dir force-app/main/default/objects \
  --source-dir force-app/main/default/classes \
  --source-dir force-app/main/default/flows \
  --source-dir force-app/main/default/queues \
  --source-dir force-app/main/default/emailservices \
  --source-dir force-app/main/default/flexipages \
  --source-dir force-app/main/default/layouts \
  --source-dir force-app/main/default/tabs \
  --target-org <alias>
```

## Step 4: Post-Deployment Configuration (Manual)

These steps must be completed in the target org after all three deploy steps succeed. Do them in this order.

### 4.1 Grant Object Permissions

The `aha_Contractor_Incident__c` object has no permission set in this project. Users will not see the object or its tab until permissions are granted.

1. Go to **Setup > Permission Sets** (or **Profiles** if you are using profiles)
2. Open the relevant permission set / profile for your users
3. Under **Object Settings > Contractor Incident**, set:
   - Object: Read, Create, Edit (add Delete if needed)
   - Fields: enable Read/Edit on all `aha_` fields as required
4. Save, then assign the permission set to the target users if using a permission set

### 4.2 Validate and Activate Prompt Template

The template deploys with settings intact, but must be saved as a new version and activated before it can be invoked by the Flow.

1. Go to **Setup > Prompt Builder**
2. Open **aha Contractor Incident - Email**
3. Click **Edit** and review all settings — verify the prompt text, the grounding object, and that the **Response Format / Lightning Object Type** is set to `ahaContractorIncidentOBLTv4`
4. Click **Save as New Version** (not just Save — this is required to create an activatable version)
5. Once saved, click **Activate** on the new version

### 4.3 Activate Flows

Flows deploy as Draft. They must be saved as a new version before activating — activating the deployed version directly can cause errors.

1. Go to **Setup > Flows**
2. Open **aha Contractor Incident - Populate from Email**
   - Click **Edit**
   - Click **Save as New Version**
   - Click **Activate**
3. Open **aha Contractor Incident Panel**
   - Click **Edit**
   - Click **Save as New Version**
   - Click **Activate**

### 4.4 Activate the Lightning Record Page

The Lightning page for `aha_Contractor_Incident__c` deploys but is not set as the org default.

1. Navigate to the **Contractor Incident** tab and open (or create) any record — this opens the record page
2. Click the **Setup (gear) icon** in the top-right > **Edit Page** to open the page in Lightning App Builder
3. Click **Save**, then click **Activation**
4. Select **Org Default** and click **Assign as Org Default**
5. Save and close

### 4.5 Configure Email Service Address

The Email Service deploys without an address because the `runAsUser` is org-specific.

1. Go to **Setup > Custom Code > Email Services**
2. Open **aha_ContractorIncidentEmails**
3. Click **New Email Address**
4. Set **Run As User** to a valid active user in the target org
5. Save and note the generated email address for testing

## Known Issues Requiring Manual Post-Deploy Steps

### Flows with GenAI Structured Output — Must Be Activated Manually

`aha_Contractor_Incident_Populate_from_Email` and `aha_Contractor_Incident_Panel` are stored in source as `<status>Draft</status>`. Salesforce's Metadata API cannot deploy flows as Active when they reference `LLM.structuredResponse.*` fields from a `generatePromptResponse` action — it fails validation even when the Lightning Type and Prompt Template are already deployed.

**After deploy:** open each flow in Flow Builder in the target org and click Save & Activate.

### Prompt Template — Lightning Object Type Must Be Set Manually

The `ahaContractorIncidentOBLTv4` Lightning Type association is not preserved when deploying `aha_Contractor_Incident_Email` via the Metadata API. The template deploys without it, which means the LLM won't return structured output.

**After deploy:** go to Setup > Prompt Builder > open `aha Contractor Incident - Email` > edit the template > set the Response Format / Lightning Object Type to `ahaContractorIncidentOBLTv4` > save and publish.

### Email Service — No Auto-Configured Address

The `emailServicesAddresses` block is stripped from `aha_ContractorIncidentEmails.xml-meta.xml` because it contains a hardcoded `runAsUser` from the source org. The Email Service deploys without an address.

**After deploy:** go to Setup > Custom Code > Email Services > aha_ContractorIncidentEmails > New Email Address, create an address, set Run As User to a valid user in the target org, note the generated address for testing.

## Artifacts Stripped on Retrieval

After every `sf project retrieve`, run the strip script from the project root before deploying:

```bash
bash ai_scripts/post_retrieve_strip.sh
```

This handles all of the below automatically. The table is kept for reference — it explains *why* each item is stripped.

When re-retrieving from source, these items will reappear in the metadata and must be removed before deploying to a different org:

| File | Element to Remove | Reason |
|------|-------------------|--------|
| `emailservices/aha_ContractorIncidentEmails.xml-meta.xml` | `<emailServicesAddresses>` block | Contains source-org-specific `runAsUser` |
| `emailservices/aha_ContractorIncidentEmails.xml-meta.xml` | `<errorRoutingAddress>` value | Source-org email address |
| `emailservices/aha_ContractorIncidentEmails.xml-meta.xml` | `<isErrorRoutingEnabled>true</isErrorRoutingEnabled>` | Set to `false` |
| `queues/aha_Contractor_Incidents.queue-meta.xml` | `<users><user>...</user></users>` block | Source-org-specific user |
| `objects/aha_Contractor_Incident__c/aha_Contractor_Incident__c.object-meta.xml` | `actionOverrides` blocks with `<type>Flexipage</type>` referencing `aha_Contractor_Incident_Record_Page` | References a Lightning page that won't exist in target org |
| `genAiPromptTemplates/aha_Contractor_Incident_Email.genAiPromptTemplate-meta.xml` | `<activeVersionIdentifier>` element | Org-specific hash |
| `genAiPromptTemplates/aha_Contractor_Incident_Email.genAiPromptTemplate-meta.xml` | All `<templateVersions>` blocks except the latest | Only keep the current version with `<status>Published</status>`; strip `<versionIdentifier>` hash |
| `flows/aha_Contractor_Incident_Populate_from_Email.flow-meta.xml` and `aha_Contractor_Incident_Panel.flow-meta.xml` | `<status>Active</status>` | Set to `<status>Draft</status>` — cannot deploy as Active via Metadata API |
