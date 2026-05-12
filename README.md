# Email to Contractor — Salesforce Open Source App

Converts inbound emails into structured `aha_Contractor_Incident__c` records, enriched by an LLM Prompt Template.

## What It Does

1. A contractor sends an incident report email to a Salesforce Email Service address
2. An Apex handler creates a `aha_Contractor_Incident__c` record from the email (From, Subject, Body)
3. A record-triggered Flow sends the email body to an Agentforce Prompt Template
4. The LLM extracts structured data and populates all incident fields automatically


***

## Prerequisites

### Enable Agentforce
This solution uses Prompt Templates. Check that your Salesforce org / sandbox has **Einstein / Agentforce** licences (required for Prompt Templates)
- Enable Einstein / Gen AI

>Setup > Einstein Setup > Turn On Einstein

- Check that **Prompt Templates** exist
>App Launcher > Agentforce Studio > Prompt Templates

- Check that the **Salesforce CLI** (Command Line Interface) is installed. [Install guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)

```bash
sf --version
sf --update
# Ensure CLI is authenticated to your org and set to default:
sf org login web --alias my-org-alias --set-default
```

***

## Installation

### 1. Clone the repo

```bash
git clone <repo-url>
cd Email_to_Contractor
```

### 2. Deploy to your org

Deploy in three steps — order matters due to Salesforce metadata dependencies.

#### Step 1 — Lightning Type

Must exist before the Prompt Template or Flows reference it.

```bash
sf project deploy start --source-dir force-app/main/default/lightningTypes --target-org <your-alias>
```

#### Step 2 — Prompt Template

Must exist before Flows that call it as an action.

```bash
sf project deploy start --source-dir force-app/main/default/genAiPromptTemplates --target-org <your-alias>
```

#### Step 3 — Everything else

```bash
sf project deploy start \
  --source-dir force-app/main/default/objects \
  --source-dir force-app/main/default/classes \
  --source-dir force-app/main/default/flows \
  --source-dir force-app/main/default/queues \
  --source-dir force-app/main/default/emailservices \
  --source-dir force-app/main/default/flexipages \
  --source-dir force-app/main/default/layouts \
  --source-dir force-app/main/default/tabs \
  --target-org <your-alias>
```

---

# ⚙️ Post-Deployment Configuration

> Complete all steps below **in the target org** after the three deploy commands above succeed. Do them in order.

### 1. Grant Permissions

The `aha_Contractor_Incident__c` object has no permission set included in this project. Users will not see the object or its tab until permissions are granted.

1. Go to **Setup > Permission Sets** (or **Profiles** if you are using profiles)
2. Open the relevant permission set / profile for your users
3. Under **Object Settings > Contractor Incident**, set:
   - Object: Read, Create, Edit (add Delete if needed)
   - Fields: enable Read/Edit on all `aha_` fields as required
4. Save, then assign the permission set to the target users if using a permission set

### 2. Validate and Activate Prompt Template

The template deploys with settings intact, but must be saved as a new version and activated before it can be invoked by the Flow.

1. Go to **Setup > Prompt Builder**
2. Open **aha Contractor Incident - Email**
3. Click **Edit** and review all settings — verify the prompt text, the grounding object, and that **Response Format / Lightning Object Type** is set to `ahaContractorIncidentOBLTv4`
4. Click **Save as New Version**
5. Click **Activate** on the new version

### 3. Activate Flows

Flows deploy as Draft and must be saved as a new version before activating.

1. Go to **Setup > Flows**
2. Open **aha Contractor Incident - Populate from Email**
   - Click **Edit**
   - Click **Save as New Version**
   - Click **Activate**
3. Open **aha Contractor Incident Panel**
   - Click **Edit**
   - Click **Save as New Version**
   - Click **Activate**

### 4. Activate the Lightning Record Page

The Lightning page for `aha_Contractor_Incident__c` deploys but is not set as the org default.

1. Navigate to the **Contractor Incident** tab and open (or create) any record
2. Click the **Setup (gear) icon** in the top-right > **Edit Page**
3. Click **Save**, then click **Activation**
4. Select **Org Default** and click **Assign as Org Default**
5. Save and close

### 5. Configure Email Service

The Email Service deploys without an address because the `runAsUser` is org-specific.

1. Go to **Setup > Custom Code > Email Services**
2. Open **aha_ContractorIncidentEmails**
3. Click **New Email Address**
4. Set **Run As User** to a valid active user in the target org
5. Save and note the generated email address — this is what contractors send reports to

**Optional — restrict which senders are accepted:**
On the Email Service record, the **Accept Email From** field can be set to a comma-separated list of email addresses or domains (e.g. `contractor.com, anothercompany.co.uk`). By default this is empty, meaning all senders are accepted.

---

## Customising the Prompt Template

The prompt template (`aha Contractor Incident - Email`) contains example context describing a fictional organisation. You should edit it in **Setup > Prompt Builder** to reflect your own organisation's context, terminology, and field matching guidance.

## Components Installed

| Type | Name | Purpose |
|------|------|---------|
| Custom Object | `aha_Contractor_Incident__c` | Core record |
| Apex Class | `aha_ContractorIncidentEmailParser` | Inbound email handler |
| Flow | `aha Contractor Incident - Populate from Email` | Trigger flow: queue assignment + AI enrichment |
| Flow | `aha Contractor Incident Panel` | Screen flow: manual re-enrichment from record |
| Flow | `aha_util_Get_Queue_Id` | Utility: resolves queue ID by name |
| Queue | `aha_Contractor_Incidents` | Owner for new incident records |
| Prompt Template | `aha Contractor Incident - Email` | LLM extraction prompt |
| Lightning Type | `ahaContractorIncidentOBLTv4` | Structured output schema for the LLM |
| Email Service | `aha_ContractorIncidentEmails` | Receives inbound emails |
| Lightning Page | `aha_Contractor_Incident_Record_Page` | Record page layout for the incident object |
| Custom Tab | `aha_Contractor_Incident__c` | Tab for the incident object |
| Page Layout | `aha_Contractor_Incident__c-Contractor Incident Layout` | Field layout for the incident record |

## Reinstalling

This install is not designed to handle upgrades. Before reinstalling, it is recommended to manually remove the components and then run the installation steps from scratch.

## For Maintainers / Contributors

The `ai_scripts/post_retrieve_strip.sh` script and `DEPLOYMENT.md` are maintainer tools — **installers do not need them**. They are used after `sf project retrieve` to strip org-specific data before committing updated source to the repo.

After any retrieve from the source org, run:

```bash
bash ai_scripts/post_retrieve_strip.sh
```

See `DEPLOYMENT.md` for full details on the deploy order rationale and known issues.

## Contributing

This is an open source project. Contributions welcome. Ways to contribute
- Join the Saleforce Open Source Commons
- If you work at a Housing Association? - Volunteer via Housing Foundation
- Contact edeklerk at salesforce
- Open an issue or PR on GitHub.


### Potential Additions
- Add a permisssion set 'aha_Email_to_Record' with relevant permissions
- Process attachments
  - Text documents
  - Images / Scans
  - Process ideally via D360° as the document handling is more rugged than generic LLM
- Prompt to handle schema drift
- Documentation
  - Example email content
  - Installation video
  - Installation doc with images