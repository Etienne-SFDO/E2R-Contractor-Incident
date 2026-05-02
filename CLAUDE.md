# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⛔ STOP. READ THIS BEFORE DOING ANYTHING. ⛔

**DO ONE THING. THEN STOP. WAIT FOR EXPLICIT INSTRUCTION BEFORE DOING THE NEXT THING.**

You are not permitted to chain actions. Ever. Not even if the next step seems obvious.

- **NEVER stage, commit, or push files without first listing exactly what you intend to include and getting explicit approval.**
- **NEVER assume scope.** If asked to "deploy to git", that means: show the plan, wait for yes, then do step 1 only, then stop.
- **NEVER add, include, or commit files that were not explicitly requested.** Ask if unsure.
- **Think before acting.** For any non-trivial action, state what you are about to do and why, and wait for confirmation.
- **Read DEPLOYMENT.md** before doing any retrieval or deployment work.

## Project Overview

This is a Salesforce project that routes inbound emails to `Contractor_Incident__c` records and enriches them via an LLM Prompt Template.

## Architecture

### End-to-End Flow

1. **Email arrives** at a custom Salesforce Email Service address (Setup > Custom Code > Email Services)
2. **Apex handler** `hx_ContractorIncidentEmailParser` (`Messaging.InboundEmailHandler`) creates a `Contractor_Incident__c` record, populating email From/Subject/Body and setting `hx_AI_Enrichment_Status__c = 'Pending'`
3. **Record-triggered Flow** `hx Contractor Incident - Populate from Email` fires on CREATE:
   - Calls utility Flow `hx_util_Get_Queue_Id` to resolve the `Contractor_Incidents` queue ID
   - Assigns queue as record owner
   - Invokes Prompt Template action `generatePromptResponse-hx_Contractor_Incident_Email`
   - Writes structured LLM response back to record fields

### Key Components

| Type | Name | Purpose |
|------|------|---------|
| Apex | `hx_ContractorIncidentEmailParser` | InboundEmailHandler — creates incident record |
| Object | `Contractor_Incident__c` | Core data record |
| Flow | `hx Contractor Incident - Populate from Email` | Orchestrates queue assignment + AI enrichment |
| Flow | `hx_util_Get_Queue_Id` | Utility: returns Queue ID by name |
| Flow | `hx Contractor Incident Panel` | (Panel/screen flow) |
| Queue | `Contractor_Incidents` | Owns newly created incident records |
| Prompt Template | `hx Contractor Incident - Email` | Extracts structured data from email body via LLM |
| Lightning Type | `hxContractorIncidentOBLTv4` | JSON schema that shapes the LLM's structured output |

### Prompt Template Behaviour

The template (`hx Contractor Incident - Email`) instructs the LLM to:
- Locate the "Incident Report" section in the email thread
- Extract structured fields into the `hxContractorIncidentOBLTv4` JSON schema
- Copy the Activity section verbatim to the `Activity` field
- Return ISO 8601 dates, booleans as `true`/`false`
- Return raw JSON only — no markdown wrapping

## Naming Conventions

- Apex classes / custom fields: `hx_` prefix (e.g. `hx_ContractorIncidentEmailParser`, `hx_Email_From__c`)
- Flows and Prompt Templates: `hx ` prefix with spaces (e.g. `hx Contractor Incident - Populate from Email`)
- Lightning Types: camelCase with version suffix (e.g. `hxContractorIncidentOBLTv4`)
- Queues: PascalCase with underscores (e.g. `Contractor_Incidents`)

## Salesforce Setup Reference

- Email Service config: **Setup > Custom Code > Email Services**
- Prompt Template invoked via Flow action: `generatePromptResponse-hx_Contractor_Incident_Email`
- Lightning Type documentation: https://developer.salesforce.com/docs/platform/lightning-types/guide/lightning-types-object.html
- Apex Email Service documentation: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_email_inbound_what_is.htm
