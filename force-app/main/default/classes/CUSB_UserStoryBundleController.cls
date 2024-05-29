public with sharing class CUSB_UserStoryBundleController {
    private final String TEST_CLASSES = 'Test Classes';
    private final String METADATA_PRESELECTION_USIMPORT = 'MetadataPreselection-UsertStoryImport';
    private Set<Id> userStoryIds;
    private Set<String> allMetadataNames;
    private List<MetaDataItem> allMetadataItems;
    private List<Attachment> cusbAttachments = new List<Attachment>();
    private Map<Id, copado__User_Story__c> userStoriesById;
    public List<copado__User_Story__c> userStories { get; set; }
    public copado__User_Story__c bundleUs { get; set; }

    public CUSB_UserStoryBundleController(ApexPages.StandardSetController std) {
        if (!Test.isRunningTest()) {
            std.addFields(new List<String>{ 'Name', 'Is_Bundle__c', 'Bundle_User_Story__c', 'copado__Environment__c' });
        }
        createBundleUserStory();
        userStoriesById = new Map<Id, copado__User_Story__c>((List<copado__User_Story__c>) std.getSelected());
        userStoryIds = new Set<Id>(userStoriesById.keySet());
        userStories = new List<copado__User_Story__c>(userStoriesById.values());
    }

    /**
     * Initialize Bundle user story
     */
    private void createBundleUserStory() {
        bundleUs = new copado__User_Story__c();
        bundleUs.RecordTypeId = Schema.SObjectType.copado__User_Story__c.getRecordTypeInfosByDeveloperName().get('User_Story').getRecordTypeId();
        bundleUs.Is_Bundle__c = true;
        bundleUs.copado__Status__c = 'Draft';
    }

    /**
     * Checks User Story Bundle consistency. Selection can't be user stories already in a bundle, Bundled user stories or from different environments.
     */
    public Boolean getIsTheUserStorySelectionConsistant() {
        Set<String> environments = new Set<String>();
        if (userStories.isEmpty()) {
            genericWarningMessage(ApexPages.Severity.WARNING, 'You need to select at least one user story with commits.');
            return false;
        }
        for (copado__User_Story__c userStoryItem : userStories) {
            if (userStoryItem.Bundle_User_Story__c != null) {
                genericWarningMessage(ApexPages.Severity.WARNING, userStoryItem.Name + ' is already bundled.');
            }
            environments.add(userStoryItem.copado__Environment__c);
        }
        if (environments.size() > 1) {
            genericWarningMessage(
                ApexPages.Severity.WARNING,
                'The selected user stories are located in different environments. Make sure all user stories are in the same environment to avoid git and Salesforce to become out of sync.'
            );
        }
        checkUnsupportedOperations();
        return !Apexpages.hasMessages();
    }

    /**
     * Checks User Stories Selected have unsupported operations (Destructive Changes)
     */
    private void checkUnsupportedOperations() {
        try {
            // Desctructive Changes
            for (copado__User_Story_Commit__c destructiveChangesOperation : [
                SELECT Id, copado__User_Story__r.Name
                FROM copado__User_Story_Commit__c
                WHERE
                    copado__User_Story__r.Id IN :userStoryIds
                    AND copado__Snapshot_Commit__r.copado__Git_Operation__c = 'Destructive Changes'
                    AND copado__Snapshot_Commit__r.copado__Status__c = 'Complete'
                WITH SECURITY_ENFORCED
            ]) {
                genericWarningMessage(
                    ApexPages.Severity.WARNING,
                    destructiveChangesOperation.copado__User_Story__r.Name + ' Contains Unsupported Operations (Destructive Changes)'
                );
            }

            // Full Profiles and Permission Sets
            for (Attachment userStoryAttachamentItem : [
                SELECT Id, Name, ParentId
                FROM Attachment
                WHERE ParentId = :userStoryIds AND Name = 'Full Profile Permission Set'
            ]) {
                genericWarningMessage(
                    ApexPages.Severity.WARNING,
                    userStoriesById.get(userStoryAttachamentItem.ParentId).Name +
                    ' Contains Unsupported Operations (Full Profiles and Permission Sets)'
                );
            }
        } catch (NoAccessException ex) {
            genericWarningMessage(ApexPages.Severity.WARNING, ex.getMessage());
        } catch (System.QueryException exceptions) {
            genericWarningMessage(
                ApexPages.Severity.WARNING,
                Label.CUSB_INSUFFICIENT_ACCESS_RIGHTS + Schema.SObjectType.copado__User_Story_Commit__c.getLabel()
            );
        }
    }

    /**
     * Assign metadata from user stories selected to Bundle User Story
     */
    public PageReference assign() {
        Id gitCommitAttachmentId;
        Savepoint sp = Database.setSavepoint();
        try {
            // Strip fields that are not insertable
            SObjectAccessDecision bundleUsDecision = Security.stripInaccessible(AccessType.CREATABLE, new List<copado__User_Story__c>{ bundleUs });
            bundleUs = (copado__User_Story__c) bundleUsDecision.getRecords()[0];
            insert bundleUs;
            assignChildUsToBundle();
            assignDeploymentTasksToBundleUs();
            addCusbAttachment(METADATA_PRESELECTION_USIMPORT, allMetadataItems);
            createTestOnlyAttachment();
            gitCommitAttachmentId = createCusbAttachments(); // what if returns null?
        } catch (NoAccessException ex) {
            Database.rollback(sp);
            genericWarningMessage(ApexPages.Severity.WARNING, ex.getMessage());
            return null;
        } catch (Exception ex) {
            Database.rollback(sp);
            genericWarningMessage(ApexPages.Severity.ERROR, ex.getMessage());
            return null;
        }

        Boolean isScratchOrg =
            String.isNotBlank(bundleUs.copado__Environment_Type__c) && bundleUs.copado__Environment_Type__c.containsIgnoreCase('Scratch Org');

        PageReference pReference = Page.copado__GitCommitMain;
        pReference.setRedirect(true);
        pReference.getParameters().put('userStoryId', bundleUs.Id);
        pReference.getParameters().put('MetadataPreselectionId', gitCommitAttachmentId);
        pReference.getParameters().put('variant', isScratchOrg ? 'DxCommit' : 'UserStoryCommit');
        return pReference;
    }

    /**
     * Assign selected user stories to Bunlde User Story
     * Exclude from CBM and Stop Indexing Metadata so only Bundle User Story will appear for Back Promotion
     */
    private void assignChildUsToBundle() {
        for (copado__User_Story__c userStoryItem : userStories) {
            userStoryItem.copado__Stop_Indexing_Metadata__c = true;
            userStoryItem.copado__Exclude_From_CBM__c = true;
            userStoryItem.Bundle_User_Story__c = bundleUs.Id;
        }
        try {
            // Strip fields that are not insertable
            SObjectAccessDecision userStoriesDecision = Security.stripInaccessible(AccessType.UPDATABLE, userStories);
            update userStoriesDecision.getRecords();
        } catch (NoAccessException ex) {
            genericWarningMessage(ApexPages.Severity.WARNING, ex.getMessage());
        }
    }

    /**
     * If selected user stories have Deployment tasks, those are copied and assigned to Bundle User Story
     */
    private void assignDeploymentTasksToBundleUs() {
        Set<String> deploymentTasksTypesWithAttachments = new Set<String>{ 'Custom Settings', 'Delete metadata', 'Apex' };
        Map<String, String> deploymentTaskByOldId = new Map<String, String>();
        List<copado__Deployment_Task__c> bundleDeploymentTasks = new List<copado__Deployment_Task__c>();
        try {
            Map<Id, copado__Deployment_Task__c> childDeploymentTasksById = new Map<Id, copado__Deployment_Task__c>(
                [
                    SELECT
                        Id,
                        Name,
                        copado__Notify_Task_Owner__c,
                        copado__Order__c,
                        copado__Perform_Manual_Task__c,
                        copado__Perform_in_Destination_Orgs__c,
                        copado__Perform_in_Source_Org__c,
                        copado__Status__c,
                        copado__Task_Description__c,
                        copado__Type__c,
                        copado__dataJSON__c,
                        CUSB_Source_Deployment_Task__c
                    FROM copado__Deployment_Task__c
                    WHERE copado__User_Story__c = :userStoryIds
                    WITH SECURITY_ENFORCED
                ]
            );
            if (!childDeploymentTasksById.isEmpty()) {
                for (copado__Deployment_Task__c depTaskItem : childDeploymentTasksById.values()) {
                    copado__Deployment_Task__c deploymentTaskCopy = depTaskItem.clone();
                    deploymentTaskCopy.copado__User_Story__c = bundleUs.Id;
                    // CUSB_Source_Deployment_Task__c will be populated with Origin Deployment Task Id.
                    if (deploymentTasksTypesWithAttachments.contains(deploymentTaskCopy.copado__Type__c)) {
                        deploymentTaskCopy.CUSB_Source_Deployment_Task__c = depTaskItem.Id;
                    }
                    bundleDeploymentTasks.add(deploymentTaskCopy);
                }
                // Strip fields that are not insertable
                SObjectAccessDecision bundleDeploymentTasksDecision = Security.stripInaccessible(AccessType.CREATABLE, bundleDeploymentTasks);
                bundleDeploymentTasks = new List<copado__Deployment_Task__c>(
                    (List<copado__Deployment_Task__c>) bundleDeploymentTasksDecision.getRecords()
                );
                insert bundleDeploymentTasks;

                // If there are Deployment tasks with attachments. This block clone and assign the attachments to its respective Deployment Tasks in the CUSB.
                List<Attachment> deploymenTasksAttachments = [
                    SELECT Id, Name, ParentId, Body
                    FROM Attachment
                    WHERE ParentId = :childDeploymentTasksById.keySet()
                ];
                if (!deploymenTasksAttachments.isEmpty()) {
                    for (copado__Deployment_Task__c deploymentTaskItem : bundleDeploymentTasks) {
                        if (deploymentTasksTypesWithAttachments.contains(deploymentTaskItem.copado__Type__c)) {
                            deploymentTaskByOldId.put(deploymentTaskItem.CUSB_Source_Deployment_Task__c, deploymentTaskItem.Id);
                        }
                    }
                    for (Attachment attachmentItem : deploymenTasksAttachments) {
                        if (deploymentTaskByOldId.containsKey(attachmentItem.ParentId)) {
                            Attachment bundleDeploymenTaskAttachment = attachmentItem.clone();
                            bundleDeploymenTaskAttachment.ParentId = deploymentTaskByOldId.get(attachmentItem.ParentId);
                            cusbAttachments.add(bundleDeploymenTaskAttachment);
                        }
                    }
                }
            }
        } catch (NoAccessException ex) {
            genericWarningMessage(ApexPages.Severity.WARNING, ex.getMessage());
        } catch (System.QueryException exceptions) {
            genericWarningMessage(
                ApexPages.Severity.WARNING,
                Label.CUSB_INSUFFICIENT_ACCESS_RIGHTS + Schema.SObjectType.copado__Deployment_Task__c.getLabel()
            );
        }
    }

    /**
     * This method creates the attachments needed for User Story Bundle.
     */
    private void addCusbAttachment(String attachmentName, List<MetaDataItem> metadataItems) {
        Attachment usbAttachment = new Attachment(ParentId = bundleUs.Id, Name = attachmentName, Body = Blob.valueOf(JSON.serialize(metadataItems)));
        cusbAttachments.add(usbAttachment);
    }
    /**
     * Inserts User Story Bundle needed attachments.
     * @return Only Metadata preselection attachment Id, which is needed for the commit.
     */
    private Id createCusbAttachments() {
        Id gitCommitAttachment;
        insert cusbAttachments;
        for (Attachment insertAttachment : cusbAttachments) {
            if (insertAttachment.Name == METADATA_PRESELECTION_USIMPORT) {
                gitCommitAttachment = insertAttachment.Id;
                break;
            }
        }
        return gitCommitAttachment;
    }

    /**
     * Creates the "Test Only" Attachment
     * @see addCusbAttachment
     */
    private void createTestOnlyAttachment() {
        Map<String, MetaDataItem> testOnlyItemsByKey = new Map<String, MetaDataItem>();
        for (Attachment testOnlyAtt : [SELECT Id, Body FROM Attachment WHERE Name = :TEST_CLASSES AND ParentId = :userStoryIds]) {
            List<MetaDataItem> metaDataItems = new List<MetaDataItem>();
            try {
                metaDataItems = (List<MetaDataItem>) JSON.deserialize(testOnlyAtt.Body.toString(), List<MetaDataItem>.class);
            } catch (Exception excp) {
                genericWarningMessage(ApexPages.Severity.ERROR, Label.CUSB_NOT_PARSED_METADATA + excp.getMessage());
            }
            // Merge the metadata to the testOnlyItemsByKey set.
            // Also checks if any class checked as Test only is commited, then that class will be removed from 'Test Classes' Attachment
            for (MetaDataItem metadata : metaDataItems) {
                if (!testOnlyItemsByKey.containsKey(metadata.n) && !allMetadataNames.contains(metadata.n)) {
                    testOnlyItemsByKey.put(metadata.n, metadata);
                }
            }
        }
        // If there are Test Only metadata creates the "Test Only" Attachment
        if (!testOnlyItemsByKey.isEmpty()) {
            addCusbAttachment(TEST_CLASSES, testOnlyItemsByKey.values());
        }
    }

    /**
     * Get selected user stories metadata.
     * Fetch each MetaData attachment from each commit associated with each user story
     * @return All metadatsa selected to be recommitted.
     */
    public List<MetaDataItem> getAllMetadata() {
        allMetadataNames = new Set<String>();
        Map<String, MetaDataItem> allMetadataItemsByKey = new Map<String, MetaDataItem>();
        List<Attachment> metadataAttachments = new List<Attachment>();
        try {
            metadataAttachments = [
                SELECT Id, Body
                FROM Attachment
                WHERE
                    Name = 'Metadata'
                    AND ParentId IN (
                        SELECT copado__Snapshot_Commit__c
                        FROM copado__User_Story_Commit__c
                        WHERE copado__User_Story__r.Id IN :userStoryIds AND copado__Snapshot_Commit__r.copado__Status__c = 'Complete'
                    )
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
        } catch (System.QueryException exceptions) {
            genericWarningMessage(
                ApexPages.Severity.WARNING,
                LAbel.CUSB_INSUFFICIENT_ACCESS_RIGHTS + Schema.SObjectType.copado__User_Story_Commit__c.getLabel()
            );
        }

        for (Attachment att : metadataAttachments) {
            List<MetaDataItem> metaDataItems = new List<MetaDataItem>();
            try {
                metaDataItems = (List<MetaDataItem>) JSON.deserialize(att.Body.toString(), List<MetaDataItem>.class);
            } catch (Exception excp) {
                genericWarningMessage(ApexPages.Severity.ERROR, Label.CUSB_NOT_PARSED_METADATA + excp.getMessage());
            }
            // Merge the commit metadata to the allMetadataItemsByKey set.
            for (MetaDataItem metadata : metaDataItems) {
                String key = metadata.t + '.' + metadata.n;
                if (!allMetadataItemsByKey.containsKey(key)) {
                    metadata.s = true;
                    allMetadataItemsByKey.put(key, metadata);
                    // This Set is used in createTestOnlyAttachment() method
                    allMetadataNames.add(metadata.n);
                } else {
                    // If it exists, check if it has metadata.r = false, and ensure it's also false in allMetadataItemsByKey
                    // This is to ensure if it is not retrieve-only at least once, it must be not retrieve only.
                    if (metadata.r == null || !metadata.r) {
                        allMetadataItemsByKey.get(key).r = false;
                    }
                }
            }
        }
        allMetadataItems = allMetadataItemsByKey.values();
        if (allMetadataItems == null || allMetadataItems.isEmpty()) {
            genericWarningMessage(ApexPages.Severity.ERROR, 'There is no metadata selection in the selected user stories');
        }
        return allMetadataItems;
    }

    /**
     * Returns the user to User Story listview page
     */
    public PageReference cancel() {
        return new PageReference('/' + Schema.SObjectType.copado__User_Story__c.getKeyPrefix() + '/o');
    }

    /**
     * Generic method to show meesages in the page
     */
    private void genericWarningMessage(ApexPages.Severity severityLevel, Object messageToShow) {
        ApexPages.addMessage(new ApexPages.Message(severityLevel, messageToShow.toString()));
    }

    /**
     * Wrapper class to serialize/deserialze and process Salesforce Metadata.
     */
    public class MetaDataItem {
        public String t { get; set; } // Metadata Type
        public String n { get; set; } // Metadata Name
        public Boolean r; // Retrieve Only
        public Boolean s; // Metadata Is Selected
        public String cb; // Created By
        public String cd; // Created Date
    }
}