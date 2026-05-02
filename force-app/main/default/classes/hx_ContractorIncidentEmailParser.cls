global class hx_ContractorIncidentEmailParser implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        try {
            // 1. Get the email content
            String emailBody;
            if (email.plainTextBody != null) {
                emailBody = email.plainTextBody;
            } else if (email.htmlBody != null) {
                emailBody = email.htmlBody.stripHtmlTags();
            } else {
                emailBody = '';
            }

            // 2. Create the Contractor Incident record
            Contractor_Incident__c incident = new Contractor_Incident__c(
                hx_Email_From__c = email.fromAddress,
                hx_Email_Subject__c = email.subject,
                hx_Email_Body__c = emailBody,
                hx_Sourced_from_Email__c = true,
                hx_AI_Enrichment_Status__c = 'Pending'
            );
            insert incident;

            result.success = true;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'hx_ContractorIncidentEmailParser failed: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            result.success = false;
        }
        return result;
    }
}