# Email to Contractor — Salesforce Open Source App

Converts inbound emails into structured `Contractor_Incident__c` records, enriched by an LLM Prompt Template.

## What It Does

1. A contractor sends an incident report email to a Salesforce Email Service address
2. An Apex handler creates a `Contractor_Incident__c` record from the email (From, Subject, Body)
3. A record-triggered Flow sends the email body to an Agentforce Prompt Template
4. The LLM extracts structured data and populates all incident fields automatically

## Prerequisites

- Salesforce org with **Einstein / Agentforce** licence (required for Prompt Templates)
- - Enable Einstein / Gen AI / Agentforce (As of 11 May 26, this was Setup >  Einstein Setup > Turn On Einstein)
- - Check that **Prompt Templates** exist (App Launcher > Agentforce Studio > Prompt Templates)   
- **Salesforce CLI** (Command Line Interface) is installed.  Checkin in a terminal with "sf"  — latest version recommended (sf -update)
- -  This app was tested with `@salesforce/cli/2.131.7`. [Install guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- -  Ensure CLI is authenticated to your org and set to default: "sf org login web --alias my-org-alias --set-default"
- LLM model: tested with **Gemini 2.5 Flash** (`sfdc_ai__DefaultVertexAIGemini25Flash001`). The prompt template references this model by default. If your org uses a different model you can update it in Setup > Prompt Builder after deployment.

## Installation

### 1. Clone the repo

```bash
git clone <repo-url>
cd Email_to_Contractor
```

### 2. Deploy to your org

Deploy in three steps — order matters:

```bash
# Step 1: Lightning Type (must exist before Prompt Template)
sf project deploy start --source-dir force-app/main/default/lightningTypes --target-org <your-alias>

# Step 2: Prompt Template (must exist before Flows)
sf project deploy start --source-dir force-app/main/default/genAiPromptTemplates --target-org <your-alias>

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
  --target-org <your-alias>
```



🚧 ACTION REQUIRED 
### 3. Grant Permissions to your User

1. Grant all Object & Field permissions to the Contractor_Incident__c object




🚧 ACTION REQUIRED
### 4. Set the Prompt Template Lightning Type

Check that the the Lightning Object Type association was set during deployment, if not set manually:

1. Go to **Setup > Prompt Builder**
2. Open **hx Contractor Incident - Email**
3. Edit the template and set the following under Template Settings > Details > Response:
- Response Format = JSON
-  Response Structure = `hxContractorIncidentOBLTv4`
4. Save as new version and Activate




🚧 ACTION REQUIRED
### 5. Activate the flows manually

Two flows deploy as **Draft** due to a Salesforce platform limitation with GenAI flow actions. 
Open each in Flow Builder and click **Save & Activate**:  (Save as New Version if an error occurs)


- `hx Contractor Incident - Populate from Email`
- `hx Contractor Incident Panel`




🚧 ACTION REQUIRED
### 5. Configure the Email Service

The Email Service deploys without an address (addresses are org-specific). Set it up manually:

1. Go to **Setup > Custom Code > Email Services**
2. Open **ContractorIncidentEmails**
3. Click **New Email Address**
4. Set **Run As User** to an active user in your org
5. Save — note the generated email address; this is what contractors send reports to

**Optional — restrict which senders are accepted:**
On the Email Service record, the **Accept Email From** field can be set to a comma-separated list of email addresses or domains (e.g. `contractor.com, anothercompany.co.uk`). By default this is empty, meaning all senders are accepted. Set this if you want to restrict incoming emails to known contractor domains.

## Customising the Prompt Template

The prompt template (`hx Contractor Incident - Email`) contains example context describing a fictional organisation. You should edit it in **Setup > Prompt Builder** to reflect your own organisation's context, terminology, and field matching guidance.

## Components Installed

| Type | Name | Purpose |
|------|------|---------|
| Custom Object | `Contractor_Incident__c` | Core record |
| Apex Class | `hx_ContractorIncidentEmailParser` | Inbound email handler |
| Flow | `hx Contractor Incident - Populate from Email` | Trigger flow: queue assignment + AI enrichment |
| Flow | `hx Contractor Incident Panel` | Screen flow: manual re-enrichment from record |
| Flow | `hx_util_Get_Queue_Id` | Utility: resolves queue ID by name |
| Queue | `Contractor Incidents` | Owner for new incident records |
| Prompt Template | `hx Contractor Incident - Email` | LLM extraction prompt |
| Lightning Type | `hxContractorIncidentOBLTv4` | Structured output schema for the LLM |
| Email Service | `ContractorIncidentEmails` | Receives inbound emails |
| Lightning Page | `Contractor_Incident_Record_Page` | Record page layout for the incident object |
| Lightning Page | `Contractors_UtilityBar` | App page with utility bar |
| Custom Tab | `Contractor_Incident__c` | Tab for the incident object |
| Page Layout | `Contractor Incident Layout` | Field layout for the incident record |

## Reinstalling

This install is not designed to handle upgrades. Before reinstalling, it is recommended to manually remove the components tand hen run the installation steps from scratch.


## For Maintainers / Contributors

The `ai_scripts/post_retrieve_strip.sh` script and `DEPLOYMENT.md` are maintainer tools — **installers do not need them**. They are used after `sf project retrieve` to strip org-specific data before committing updated source to the repo.

After any retrieve from the source org, run:

```bash
bash ai_scripts/post_retrieve_strip.sh
```

See `DEPLOYMENT.md` for full details on the deploy order rationale and known issues.

## Contributing

This is an open source project. Contributions welcome — please open an issue or PR on GitHub.
