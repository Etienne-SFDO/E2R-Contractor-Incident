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

This is a Salesforce project that routes inbound emails to `aha_Contractor_Incident__c` records and enriches them via an LLM Prompt Template.

## Architecture

### End-to-End Flow

1. **Email arrives** at a custom Salesforce Email Service address (Setup > Custom Code > Email Services)
2. **Apex handler** `aha_ContractorIncidentEmailParser` (`Messaging.InboundEmailHandler`) creates a `aha_Contractor_Incident__c` record, populating email From/Subject/Body and setting `aha_AI_Enrichment_Status__c = 'Pending'`
3. **Record-triggered Flow** `aha Contractor Incident - Populate from Email` fires on CREATE:
   - Calls utility Flow `aha_util_Get_Queue_Id` to resolve the `aha_Contractor_Incidents` queue ID
   - Assigns queue as record owner
   - Invokes Prompt Template action `generatePromptResponse-aha_Contractor_Incident_Email`
   - Writes structured LLM response back to record fields

### Key Components

| Type | Name | Purpose |
|------|------|---------|
| Apex | `aha_ContractorIncidentEmailParser` | InboundEmailHandler — creates incident record |
| Object | `aha_Contractor_Incident__c` | Core data record |
| Flow | `aha Contractor Incident - Populate from Email` | Orchestrates queue assignment + AI enrichment |
| Flow | `aha_util_Get_Queue_Id` | Utility: returns Queue ID by name |
| Flow | `aha Contractor Incident Panel` | (Panel/screen flow) |
| Queue | `aha_Contractor_Incidents` | Owns newly created incident records |
| Prompt Template | `aha Contractor Incident - Email` | Extracts structured data from email body via LLM |
| Lightning Type | `ahaContractorIncidentOBLTv4` | JSON schema that shapes the LLM's structured output |

### Prompt Template Behaviour

The template (`aha Contractor Incident - Email`) instructs the LLM to:
- Locate the "Incident Report" section in the email thread
- Extract structured fields into the `ahaContractorIncidentOBLTv4` JSON schema
- Copy the Activity section verbatim to the `Activity` field
- Return ISO 8601 dates, booleans as `true`/`false`
- Return raw JSON only — no markdown wrapping

## Naming Conventions

- Apex classes / custom fields: `aha_` prefix (e.g. `aha_ContractorIncidentEmailParser`, `aha_Email_From__c`)
- Flows and Prompt Templates: `aha ` prefix with spaces (e.g. `aha Contractor Incident - Populate from Email`)
- Lightning Types: camelCase with version suffix (e.g. `ahaContractorIncidentOBLTv4`)
- Queues: PascalCase with underscores (e.g. `aha_Contractor_Incidents`)

## Salesforce Setup Reference

- Email Service config: **Setup > Custom Code > Email Services**
- Prompt Template invoked via Flow action: `generatePromptResponse-aha_Contractor_Incident_Email`
- Lightning Type documentation: https://developer.salesforce.com/docs/platform/lightning-types/guide/lightning-types-object.html
- Apex Email Service documentation: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_email_inbound_what_is.htm
