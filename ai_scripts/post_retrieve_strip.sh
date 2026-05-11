#!/bin/bash
# post_retrieve_strip.sh
#
# Run this after every 'sf project retrieve' from the source org.
# Strips org-specific artifacts that would break deployment to any other org.

set -e

FORCE_APP="force-app/main/default"

echo ">>> Stripping org-specific artifacts..."

# ── Email Service ──────────────────────────────────────────────────────────────
# Remove the emailServicesAddresses block (contains hardcoded runAsUser)
# Disable error routing (errorRoutingAddress contains source-org email)
EMAIL_SVC="$FORCE_APP/emailservices/aha_ContractorIncidentEmails.xml-meta.xml"
if [ -f "$EMAIL_SVC" ]; then
  # Remove emailServicesAddresses block
  perl -0777 -i -pe 's|\s*<emailServicesAddresses>.*?</emailServicesAddresses>||gs' "$EMAIL_SVC"
  # Clear errorRoutingAddress value
  sed -i '' 's|<errorRoutingAddress>.*</errorRoutingAddress>|<errorRoutingAddress></errorRoutingAddress>|' "$EMAIL_SVC"
  # Disable error routing
  sed -i '' 's|<isErrorRoutingEnabled>true</isErrorRoutingEnabled>|<isErrorRoutingEnabled>false</isErrorRoutingEnabled>|' "$EMAIL_SVC"
  echo "    ✓ Email Service stripped"
fi

# ── Queue ──────────────────────────────────────────────────────────────────────
# Remove hardcoded user members (keep publicGroups)
QUEUE="$FORCE_APP/queues/aha_Contractor_Incidents.queue-meta.xml"
if [ -f "$QUEUE" ]; then
  perl -0777 -i -pe 's|\s*<users>.*?</users>||gs' "$QUEUE"
  echo "    ✓ Queue stripped"
fi

# ── Custom Object ──────────────────────────────────────────────────────────────
# Remove Flexipage actionOverrides that reference aha_Contractor_Incident_Record_Page
# (Lightning App Builder activation writes these; the FlexiPage is now a
#  separate deployable component so the override is no longer needed here)
OBJECT="$FORCE_APP/objects/aha_Contractor_Incident__c/aha_Contractor_Incident__c.object-meta.xml"
if [ -f "$OBJECT" ]; then
  perl -0777 -i -pe 's|\s*<actionOverrides>\s*<actionName>View</actionName>\s*<comment>[^<]*</comment>\s*<content>aha_Contractor_Incident_Record_Page</content>\s*<formFactor>[^<]*</formFactor>\s*<skipRecordTypeSelect>[^<]*</skipRecordTypeSelect>\s*<type>Flexipage</type>\s*</actionOverrides>||gs' "$OBJECT"
  echo "    ✓ Custom Object FlexiPage action overrides stripped"
fi

# ── Custom Application ─────────────────────────────────────────────────────────
# Remove logo reference (points to a ContentAsset that won't exist in target org)
APP="$FORCE_APP/applications/Hx_aha_Contractor_Incidents.app-meta.xml"
if [ -f "$APP" ]; then
  sed -i '' 's|<logo>.*</logo>||' "$APP"
  sed -i '' 's|<logoVersion>.*</logoVersion>||' "$APP"
  echo "    ✓ App logo stripped"
fi

# ── Prompt Template ────────────────────────────────────────────────────────────
# Remove activeVersionIdentifier (org-specific hash)
# Keep only the latest templateVersions block (highest _N suffix)
# Strip versionIdentifier hashes from remaining version
PT="$FORCE_APP/genAiPromptTemplates/aha_Contractor_Incident_Email.genAiPromptTemplate-meta.xml"
if [ -f "$PT" ]; then
  # Remove activeVersionIdentifier line
  sed -i '' '/<activeVersionIdentifier>/d' "$PT"
  # Remove all templateVersions blocks except the last one
  perl -0777 -i -pe '
    my @blocks = split(/(?=\n\s*<templateVersions>)/, $_);
    my $header = shift @blocks;
    my $last = pop @blocks;
    $_ = $header . "\n" . $last;
  ' "$PT"
  # Remove versionIdentifier line from remaining block
  sed -i '' '/<versionIdentifier>/d' "$PT"
  # Ensure templateVersions starts on its own line
  sed -i '' 's|</masterLabel><templateVersions>|</masterLabel>\
    <templateVersions>|' "$PT"
  # Ensure the remaining version is Published (not Draft)
  sed -i '' 's|<status>Draft</status>|<status>Published</status>|' "$PT"
  echo "    ✓ Prompt Template stripped to latest version"
fi

# ── Flows ──────────────────────────────────────────────────────────────────────
# Set GenAI flows to Draft (Metadata API cannot deploy them as Active)
for FLOW in \
  "$FORCE_APP/flows/aha_Contractor_Incident_Populate_from_Email.flow-meta.xml" \
  "$FORCE_APP/flows/aha_Contractor_Incident_Panel.flow-meta.xml"
do
  if [ -f "$FLOW" ]; then
    sed -i '' 's|<status>Active</status>|<status>Draft</status>|' "$FLOW"
    echo "    ✓ $(basename $FLOW) set to Draft"
  fi
done

echo ""
echo ">>> Strip complete. Files are ready for deployment to a target org."
echo "    Remember: activate the two flows manually in Flow Builder after deploy."
