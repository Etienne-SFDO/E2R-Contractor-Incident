# DEPLOYMENT.md

This file is intended for AI instances (Claude Code) working on retrieval and deployment tasks in this repository. It documents hard-won lessons from iterative deploy attempts. Read this before touching `sf project retrieve` or `sf project deploy`.

## Skills

Use the **`sf-deploy`** skill for deployment work in this project. Invoke it with `/sf-deploy` at the start of a deployment session — it provides structured validation and catches ordering issues early.

## Post-Deploy Verification

Before testing the app, confirm these are in place in the target org:

1. **Object** — `Contractor_Incident__c` exists with all fields
2. **Apex** — `hx_ContractorIncidentEmailParser` is deployed and active
3. **Prompt Template** — `hx Contractor Incident - Email` exists and has `hxContractorIncidentOBLTv4` set as Lightning Object Type
4. **Flows** — `hx Contractor Incident - Populate from Email` and `hx Contractor Incident Panel` are activated in Flow Builder
5. **Queue** — `Contractor Incidents` exists
6. **Email Service** — `ContractorIncidentEmails` has an address configured with a valid Run As User

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

## Known Issues Requiring Manual Post-Deploy Steps

### Flows with GenAI Structured Output — Must Be Activated Manually

`hx_Contractor_Incident_Populate_from_Email` and `hx_Contractor_Incident_Panel` are stored in source as `<status>Draft</status>`. Salesforce's Metadata API cannot deploy flows as Active when they reference `LLM.structuredResponse.*` fields from a `generatePromptResponse` action — it fails validation even when the Lightning Type and Prompt Template are already deployed.

**After deploy:** open each flow in Flow Builder in the target org and click Save & Activate.

### Prompt Template — Lightning Object Type Must Be Set Manually

The `hxContractorIncidentOBLTv4` Lightning Type association is not preserved when deploying `hx_Contractor_Incident_Email` via the Metadata API. The template deploys without it, which means the LLM won't return structured output.

**After deploy:** go to Setup > Prompt Builder > open `hx Contractor Incident - Email` > edit the template > set the Response Format / Lightning Object Type to `hxContractorIncidentOBLTv4` > save and publish.

### Email Service — No Auto-Configured Address

The `emailServicesAddresses` block is stripped from `ContractorIncidentEmails.xml-meta.xml` because it contains a hardcoded `runAsUser` from the source org. The Email Service deploys without an address.

**After deploy:** go to Setup > Custom Code > Email Services > ContractorIncidentEmails > New Email Address, create an address, set Run As User to a valid user in the target org, note the generated address for testing.

## Artifacts Stripped on Retrieval

After every `sf project retrieve`, run the strip script from the project root before deploying:

```bash
bash ai_scripts/post_retrieve_strip.sh
```

This handles all of the below automatically. The table is kept for reference — it explains *why* each item is stripped.

When re-retrieving from source, these items will reappear in the metadata and must be removed before deploying to a different org:

| File | Element to Remove | Reason |
|------|-------------------|--------|
| `emailservices/ContractorIncidentEmails.xml-meta.xml` | `<emailServicesAddresses>` block | Contains source-org-specific `runAsUser` |
| `emailservices/ContractorIncidentEmails.xml-meta.xml` | `<errorRoutingAddress>` value | Source-org email address |
| `emailservices/ContractorIncidentEmails.xml-meta.xml` | `<isErrorRoutingEnabled>true</isErrorRoutingEnabled>` | Set to `false` |
| `queues/Contractor_Incidents.queue-meta.xml` | `<users><user>...</user></users>` block | Source-org-specific user |
| `objects/Contractor_Incident__c/Contractor_Incident__c.object-meta.xml` | `actionOverrides` blocks with `<type>Flexipage</type>` referencing `Contractor_Incident_Record_Page` | References a Lightning page that won't exist in target org |
| `genAiPromptTemplates/hx_Contractor_Incident_Email.genAiPromptTemplate-meta.xml` | `<activeVersionIdentifier>` element | Org-specific hash |
| `genAiPromptTemplates/hx_Contractor_Incident_Email.genAiPromptTemplate-meta.xml` | All `<templateVersions>` blocks except the latest | Only keep the current version with `<status>Published</status>`; strip `<versionIdentifier>` hash |
| `flows/hx_Contractor_Incident_Populate_from_Email.flow-meta.xml` and `hx_Contractor_Incident_Panel.flow-meta.xml` | `<status>Active</status>` | Set to `<status>Draft</status>` — cannot deploy as Active via Metadata API |

## Known Issues in the Source Org (To Fix)

- **`hx_Contractor_Incident_Panel`** — was referencing test artifact `hx_Contractor_Incident_Text_test1` as its prompt template. Fixed in this repo to point at `hx_Contractor_Incident_Email`, but the input parameter name also changed from `Input:Incident_Text` to `Input:InputEmail`. The Panel flow's logic and screen fields may need review against the current prompt template's input schema.
- **Naming conventions** — several components have inconsistent naming (mixed `hx_`, `HX_`, missing prefix). A cleanup pass is planned.
