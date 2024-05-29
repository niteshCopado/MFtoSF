public with sharing class CUSB_EmailError {
    /**
     * Send a generic error email
     */
    public static void sendErrorEmail(String subject, String errorMessage, String errorTitle, String emailTo) {
        String htmlBody = getHtmlBody(errorMessage, errorTitle);

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setSenderDisplayName('Copado Application');
        message.setUseSignature(false);
        message.setBccSender(false);
        message.setSaveAsActivity(false);
        message.setSubject(subject);
        message.setHtmlBody(htmlBody);
        message.setTargetObjectId(emailTo);

        Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage>{ message };
        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
    }

    /**
     * Replaces keywords with title and messages
     */
    private static String getHtmlBody(String errorMessage, String errorTitle) {
        EmailTemplate emailTemplate = [SELECT Id, HtmlValue FROM EmailTemplate WHERE DeveloperName = 'CUSB_UserStoryBundleEmailError'];
        String htmlBody = emailTemplate.HtmlValue != null ? emailTemplate.HtmlValue : '';
        htmlBody = htmlBody.replace('errorMessage', errorMessage);
        htmlBody = htmlBody.replace('"errorTitle"', errorTitle);
        return htmlBody;
    }
}