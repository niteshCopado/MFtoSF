@IsTest
public class CUSB_TestUserStoryBundle {
    private static final String BUNDLED_USER_STORY = 'Bundled User Story';
    private static final List<String> USERSTORY1_USERSTORY2 = new List<String>{ 'User Story 1', 'User Story 2' };
    @TestSetup
    static void makeData() {
        User runAsUser = createUser();
        assignPermissionSet(runAsUser.Id);
        System.runAs(runAsUser) {
            assignLicense(runAsUser.Id);
            List<copado__Org__c> orgCreds = new List<copado__Org__c>();
            copado__Org__c devOrgCredential = new copado__Org__c(
                Name = 'Dev 1',
                copado__Org_Type__c = 'Production/Developer',
                copado__SFDC_Org_ID__c = '00D1i00000095bEEAQ_0050X000007h8hTQAQ_6'
            );
            orgCreds.add(devOrgCredential);
            copado__Org__c stagingOrgCredential = new copado__Org__c(
                Name = 'Staging',
                copado__Org_Type__c = 'Production/Developer',
                copado__SFDC_Org_ID__c = '00D1i00000095cEEAQ_0050X000007h8cTQAQ_3'
            );
            orgCreds.add(stagingOrgCredential);
            insert orgCreds;
            // This update is to create Environments from OrgCredentials.
            // copado__SFDC_Org_ID__c is populated after creation. In this case, I populated the field in the very beginning so data creation code is smoother.
            update orgCreds;

            copado__Git_Repository__c gitRepo = new copado__Git_Repository__c(Name = 'My Repo');
            insert gitRepo;

            copado__Git_Backup__c gitSnapshot = new copado__Git_Backup__c(
                copado__Git_Repository__c = gitRepo.Id,
                copado__Org__c = devOrgCredential.Id
            );
            insert gitSnapshot;

            copado__Git_Org_Commit__c gitOrgCommit1 = new copado__Git_Org_Commit__c(
                copado__Git_Backup__c = gitSnapshot.Id,
                copado__Org__c = devOrgCredential.Id,
                copado__Commit_Id__c = 'b7adccf3937495e8928d1023c5a5c644198b8974',
                copado__Commit_Date__c = Date.today(),
                copado__Commit_Message__c = 'test message',
                copado__Status__c = 'Complete'
            );
            copado__Git_Org_Commit__c gitOrgCommit2 = new copado__Git_Org_Commit__c(
                copado__Git_Backup__c = gitSnapshot.Id,
                copado__Org__c = devOrgCredential.Id,
                copado__Commit_Id__c = 'b7adccf3937495e8928d1023c5a5c644198b8975',
                copado__Commit_Date__c = Date.today(),
                copado__Commit_Message__c = 'test message 2',
                copado__Status__c = 'Complete'
            );
            insert new List<copado__Git_Org_Commit__c>{ gitOrgCommit1, gitOrgCommit2 };

            copado__User_Story__c userStory1 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 1');
            copado__User_Story__c userStory2 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 2');
            copado__User_Story__c userStory3 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 3');
            copado__User_Story__c userStory4 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 4');
            copado__User_Story__c userStory5 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 5');
            copado__User_Story__c userStory6 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 6');
            insert new List<copado__User_Story__c>{ userStory1, userStory2, userStory3, userStory4, userStory5, userStory6 };

            copado__User_Story_Commit__c userStoryCommit1 = new copado__User_Story_Commit__c(
                copado__User_Story__c = userStory1.Id,
                copado__Snapshot_Commit__c = gitOrgCommit1.Id
            );
            copado__User_Story_Commit__c userStoryCommit2 = new copado__User_Story_Commit__c(
                copado__User_Story__c = userStory2.Id,
                copado__Snapshot_Commit__c = gitOrgCommit2.Id
            );
            insert new List<copado__User_Story_Commit__c>{ userStoryCommit1, userStoryCommit2 };

            copado__Deployment_Task__c deploymentTaskManual = new copado__Deployment_Task__c(
                copado__User_Story__c = userStory1.Id,
                copado__Task_Description__c = 'Deployment Task Description',
                copado__Type__c = 'Manual Task'
            );
            copado__Deployment_Task__c deploymentTaskApex = new copado__Deployment_Task__c(
                copado__User_Story__c = userStory2.Id,
                copado__Task_Description__c = 'Deployment Task Apex',
                copado__Type__c = 'Apex'
            );
            insert new List<copado__Deployment_Task__c>{ deploymentTaskManual, deploymentTaskApex };

            // Metadata selections via the grid
            Attachment att1 = new Attachment(
                ParentId = gitOrgCommit1.Id,
                Name = 'Metadata',
                Body = Blob.valueOf('[{"t":"EmailTemplate","n":"Template1","s":true,"r":true}, {"t":"EmailTemplate","n":"Template2","s":false}]')
            );

            Attachment att2 = new Attachment(
                ParentId = gitOrgCommit2.Id,
                Name = 'Metadata',
                Body = Blob.valueOf('[{"t":"EmailTemplate","n":"Template1","s":true,"r":false}, {"t":"EmailTemplate","n":"a_Template","s":true}]')
            );
            // Test only Attachment.
            Attachment testOnlyAttachment = new Attachment(
                ParentId = userStory1.Id,
                Name = 'Test Classes',
                Body = Blob.valueOf('[{"n":"test_class","s":true,"r":false,"ns":""}]')
            );
            // Apex Deployment Task
            Attachment testApexDeploymentTask = new Attachment(
                ParentId = deploymentTaskApex.Id,
                Name = 'Apex',
                Body = Blob.valueOf('System.debug(\'debug\')')
            );

            insert new List<Attachment>{ att1, att2, testOnlyAttachment, testApexDeploymentTask };
        }
    }

    /**
     * Test: user stories with commits and metadata selection.
     */
    @IsTest
    static void testUserStoryBundleCreation() {
        System.runAs(getRunAsUser()) {
            copado__Org__c orgCred = [SELECT Id, Name FROM copado__Org__c LIMIT 1];
            Map<Id, copado__User_Story__c> selectedUserStoriesById = getSelectedUserStoriesById(USERSTORY1_USERSTORY2);
            List<copado__User_Story__c> selectedUserStories = new List<copado__User_Story__c>(selectedUserStoriesById.values());
            Set<Id> selectedUserStoriesIds = new Set<Id>(selectedUserStoriesById.keySet());

            PageReference pageRef = Page.CUSB_UserStoryBundle;
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardSetController bundleUserStoryStandardSetController = new ApexPages.StandardSetController(selectedUserStories);
            bundleUserStoryStandardSetController.setSelected(selectedUserStories);
            CUSB_UserStoryBundleController bundleController = new CUSB_UserStoryBundleController(bundleUserStoryStandardSetController);
            bundleController.getAllMetadata();
            Boolean userStoryConsistency = bundleController.getIsTheUserStorySelectionConsistant();
            System.assertEquals(true, userStoryConsistency, 'User consistency must be true');
            System.assertEquals(0, ApexPages.getMessages().size(), 'There should not be any erros at this point');
            bundleController.bundleUs.copado__User_Story_Title__c = BUNDLED_USER_STORY;
            bundleController.bundleUs.copado__Org_Credential__c = orgCred.Id;

            PageReference gitCommitPage = bundleController.assign();
            System.assertEquals(0, ApexPages.getMessages().size(), 'There should not be any erros at this point');
            Test.setCurrentPage(gitCommitPage);

            Test.stopTest();
            copado__User_Story__c resultUserStory = [
                SELECT
                    Id,
                    Is_Bundle__c,
                    copado__User_Story_Title__c,
                    copado__Org_Credential__c,
                    (
                        SELECT Id, Name, copado__Stop_Indexing_Metadata__c, copado__Exclude_From_CBM__c, Bundle_User_Story__c
                        FROM Bundle_User_Stories__r
                    )
                FROM copado__User_Story__c
                WHERE copado__User_Story_Title__c = :BUNDLED_USER_STORY
                LIMIT 1
            ];

            String assertMetadataPreselectionAttachment;
            String assertTestClassesAttachment;
            for (Attachment resultAttachment : [SELECT Id, Name FROM Attachment WHERE ParentId = :resultUserStory.Id]) {
                switch on resultAttachment.Name {
                    when 'MetadataPreselection-UsertStoryImport' {
                        assertMetadataPreselectionAttachment = resultAttachment.Id;
                    }
                    when 'Test Classes' {
                        assertTestClassesAttachment = resultAttachment.Id;
                    }
                }
            }

            Set<copado__User_Story__c> childUserStories = new Set<copado__User_Story__c>(
                [
                    SELECT Id, Name, copado__Stop_Indexing_Metadata__c, copado__Exclude_From_CBM__c, Bundle_User_Story__c
                    FROM copado__User_Story__c
                    WHERE copado__User_Story_Title__c = :USERSTORY1_USERSTORY2
                ]
            );
            Set<copado__User_Story__c> assertChildUserStories = new Set<copado__User_Story__c>(resultUserStory.Bundle_User_Stories__r);

            Map<Id, copado__Deployment_Task__c> childDeploymentTasksById = getDeploymentTasksByUserStoryId(selectedUserStoriesIds);
            List<copado__Deployment_Task__c> childDeploymentTasks = new List<copado__Deployment_Task__c>(childDeploymentTasksById.values());
            List<Attachment> chilDeploymentTasksAttachment = [
                SELECT Id, Name, ParentId, Body
                FROM Attachment
                WHERE ParentId = :childDeploymentTasksById.keySet()
            ];

            Map<Id, copado__Deployment_Task__c> assertDeploymentTasksById = getDeploymentTasksByUserStoryId(new Set<Id>{ resultUserStory.Id });
            List<copado__Deployment_Task__c> assertDeploymentTasks = new List<copado__Deployment_Task__c>(assertDeploymentTasksById.values());
            List<Attachment> assertDeploymentTasksAttachment = [
                SELECT Id, Name, ParentId, Body
                FROM Attachment
                WHERE ParentId = :assertDeploymentTasksById.keySet()
            ];

            PageReference assertCommitPage = Page.copado__GitCommitMain;
            assertCommitPage.getParameters().put('userStoryId', resultUserStory.Id);
            assertCommitPage.getParameters().put('MetadataPreselectionId', assertMetadataPreselectionAttachment);
            assertCommitPage.getParameters().put('variant', 'UserStoryCommit');
            System.assertEquals(assertCommitPage.getUrl(), gitCommitPage.getUrl(), 'Url expected is not correct');

            System.assertEquals(true, resultUserStory.Is_Bundle__c, 'Is Bundle field must be TRUE');
            System.assertEquals(BUNDLED_USER_STORY, resultUserStory.copado__User_Story_Title__c, 'Title is not correct');
            System.assertEquals(orgCred.Id, resultUserStory.copado__Org_Credential__c, 'Org Credential is not correct');

            System.assert(assertChildUserStories.equals(childUserStories), 'Child USer Stories are not correct');
            System.assertEquals(assertDeploymentTasks.size(), childDeploymentTasks.size(), 'Child DeploymentTasks are not correct');
            System.assertEquals(
                assertDeploymentTasks[0].copado__Task_Description__c,
                childDeploymentTasks[0].copado__Task_Description__c,
                'Task Descriptiion mismatches'
            );
            System.assertEquals(
                childDeploymentTasks[0].copado__Type__c == 'Apex' ? String.valueOf(childDeploymentTasks[0].Id) : null,
                assertDeploymentTasks[0].CUSB_Source_Deployment_Task__c,
                'CUSB Source Deployment Task Value is not correct'
            );
            System.assertEquals(assertDeploymentTasks[1].copado__Type__c, childDeploymentTasks[1].copado__Type__c, 'Task Type mismatches');
            System.assertEquals(
                assertDeploymentTasks[1].copado__Task_Description__c,
                childDeploymentTasks[1].copado__Task_Description__c,
                'Task Descriptiion mismatches'
            );
            System.assertEquals(
                childDeploymentTasks[1].copado__Type__c == 'Apex' ? String.valueOf(childDeploymentTasks[1].Id) : null,
                assertDeploymentTasks[1].CUSB_Source_Deployment_Task__c,
                'CUSB Source Deployment Task Value is not correct'
            );
            System.assertEquals(assertDeploymentTasks[0].copado__Type__c, childDeploymentTasks[0].copado__Type__c, 'Task Type mismatches');
            System.assertEquals(
                assertDeploymentTasksAttachment.size(),
                chilDeploymentTasksAttachment.size(),
                'DeploymentTasks attachments are not correct'
            );
            System.assertEquals(assertDeploymentTasksAttachment[0].Name, chilDeploymentTasksAttachment[0].Name, 'Attachment name is not the same');
            System.assertEquals(assertDeploymentTasksAttachment[0].Body, chilDeploymentTasksAttachment[0].Body, 'Attachment Body is not the same');
            System.assertNotEquals(null, assertTestClassesAttachment, 'Test Classes attachment is not created in Bundled user story');
        }
    }

    /**
     * Test UserStories selected has no metadata
     */
    @IsTest
    static void testNoMetadataInSelection() {
        System.runAs(getRunAsUser()) {
            copado__Org__c orgCred = [SELECT Id, Name FROM copado__Org__c LIMIT 1];
            List<copado__User_Story__c> selectedUserStories = getSelectedUserStoriesById(new List<String>{ 'User Story 3', 'User Story 4' }).values();
            PageReference pageRef = Page.CUSB_UserStoryBundle;
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardSetController bundleUserStoryStandardSetController = new ApexPages.StandardSetController(selectedUserStories);
            bundleUserStoryStandardSetController.setSelected(selectedUserStories);
            CUSB_UserStoryBundleController bundleController = new CUSB_UserStoryBundleController(bundleUserStoryStandardSetController);
            bundleController.getAllMetadata();
            Boolean userStoryConsistency = bundleController.getIsTheUserStorySelectionConsistant();
            System.assertEquals(false, userStoryConsistency, 'User consistency must be false');
            System.assertEquals(
                'There is no metadata selection in the selected user stories',
                ApexPages.getMessages()[0].getDetail(),
                'The message is not correct'
            );

            Test.stopTest();
        }
    }

    /**
     * Test No user story selection
     */
    @IsTest
    static void testNoUserStorySelection() {
        System.runAs(getRunAsUser()) {
            PageReference pageRef = Page.CUSB_UserStoryBundle;
            Test.setCurrentPage(pageRef);

            Test.startTest();
            List<copado__User_Story__c> selectedUserStories = new List<copado__User_Story__c>();
            ApexPages.StandardSetController bundleUserStoryStandardSetController = new ApexPages.StandardSetController(selectedUserStories);
            CUSB_UserStoryBundleController bundleController = new CUSB_UserStoryBundleController(bundleUserStoryStandardSetController);
            Boolean userStoryConsistency = bundleController.getIsTheUserStorySelectionConsistant();
            System.assertEquals(false, userStoryConsistency, 'User consistency must be false');
            System.assertEquals(
                'You need to select at least one user story with commits.',
                ApexPages.getMessages()[0].getDetail(),
                'The message is not correct'
            );

            Test.stopTest();
        }
    }

    /**
     * Test: user stories with inconsistency selection
     */
    @IsTest
    static void testUserStorySelectionConsistency() {
        System.runAs(getRunAsUser()) {
            copado__Org__c devOrgCredential = new copado__Org__c();
            copado__Org__c stagingOrgCredential = new copado__Org__c();
            for (copado__Org__c orgCredentialItem : [
                SELECT Id, Name, copado__Environment__c
                FROM copado__Org__c
                WHERE Name IN ('Dev 1', 'Staging')
            ]) {
                switch on orgCredentialItem.Name {
                    when 'Dev 1' {
                        devOrgCredential = orgCredentialItem;
                    }
                    when 'Staging' {
                        stagingOrgCredential = orgCredentialItem;
                    }
                }
            }
            copado__User_Story__c bundleUs = new copado__User_Story__c();
            bundleUs.copado__User_Story_Title__c = BUNDLED_USER_STORY;
            bundleUs.copado__Org_Credential__c = devOrgCredential.Id;
            bundleUs.RecordTypeId = Schema.SObjectType.copado__User_Story__c.getRecordTypeInfosByName().get('User Story').getRecordTypeId();
            bundleUs.Is_Bundle__c = true;
            bundleUs.copado__Status__c = 'Draft';
            insert bundleUs;

            Map<Id, copado__User_Story__c> selectedUserStoriesById = getSelectedUserStoriesById(USERSTORY1_USERSTORY2);
            List<copado__User_Story__c> selectedUserStories = new List<copado__User_Story__c>(selectedUserStoriesById.values());
            Set<Id> selectedUserStoriesIds = new Set<Id>(selectedUserStoriesById.keySet());

            selectedUserStories[0].copado__Org_Credential__c = devOrgCredential.Id;
            selectedUserStories[0].copado__Environment__c = devOrgCredential.copado__Environment__c;
            selectedUserStories[0].Bundle_User_Story__c = bundleUs.Id;
            selectedUserStories[1].copado__Org_Credential__c = stagingOrgCredential.Id;
            selectedUserStories[1].copado__Environment__c = stagingOrgCredential.copado__Environment__c;
            selectedUserStories[1].Bundle_User_Story__c = bundleUs.Id;
            update selectedUserStories;

            PageReference pageRef = Page.CUSB_UserStoryBundle;
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardSetController bundleUserStoryStandardSetController = new ApexPages.StandardSetController(selectedUserStories);
            bundleUserStoryStandardSetController.setSelected(selectedUserStories);
            CUSB_UserStoryBundleController bundleController = new CUSB_UserStoryBundleController(bundleUserStoryStandardSetController);
            Boolean userStoryConsistency = bundleController.getIsTheUserStorySelectionConsistant();
            bundleController.getAllMetadata();
            System.assertEquals(false, userStoryConsistency, 'User consistency must be false');
            Test.stopTest();
        }
    }

    /**
     * Test: user stories with unsupported operations
     */
    @IsTest
    static void testUserStorySelectionUnsupportedOperations() {
        System.runAs(getRunAsUser()) {
            copado__Git_Org_Commit__c gitOrgCommit1 = [
                SELECT Id
                FROM copado__Git_Org_Commit__c
                WHERE copado__Commit_Id__c = 'b7adccf3937495e8928d1023c5a5c644198b8974'
            ];
            gitOrgCommit1.copado__Git_Operation__c = 'Destructive Changes';
            update gitOrgCommit1;

            List<copado__User_Story__c> selectedUserStories = new List<copado__User_Story__c>(
                getSelectedUserStoriesById(USERSTORY1_USERSTORY2).values()
            );
            Attachment fullProfilesAttachment = new Attachment();
            fullProfilesAttachment.ParentId = selectedUserStories[1].Id;
            fullProfilesAttachment.Name = 'Full Profile Permission Set';
            fullProfilesAttachment.Body = Blob.valueOf('');
            insert fullProfilesAttachment;

            PageReference pageRef = Page.CUSB_UserStoryBundle;
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardSetController bundleUserStoryStandardSetController = new ApexPages.StandardSetController(selectedUserStories);
            bundleUserStoryStandardSetController.setSelected(selectedUserStories);
            CUSB_UserStoryBundleController bundleController = new CUSB_UserStoryBundleController(bundleUserStoryStandardSetController);
            bundleController.getAllMetadata();
            Boolean userStoryConsistency = bundleController.getIsTheUserStorySelectionConsistant();
            System.assertEquals(false, userStoryConsistency, 'User consistency must be false');
            System.assertEquals(2, Apexpages.getMessages().size());

            Test.stopTest();
        }
    }

    /**
     * Test "Cancel" button
     */
    @IsTest
    static void testCancelButton() {
        System.runAs(getRunAsUser()) {
            copado__Org__c orgCred = [SELECT Id, Name FROM copado__Org__c LIMIT 1];
            List<copado__User_Story__c> selectedUserStories = getSelectedUserStoriesById(USERSTORY1_USERSTORY2).values();
            PageReference pageRef = Page.CUSB_UserStoryBundle;
            Test.setCurrentPage(pageRef);

            Test.startTest();

            ApexPages.StandardSetController bundleUserStoryStandardSetController = new ApexPages.StandardSetController(selectedUserStories);
            bundleUserStoryStandardSetController.setSelected(selectedUserStories);
            CUSB_UserStoryBundleController bundleController = new CUSB_UserStoryBundleController(bundleUserStoryStandardSetController);
            bundleController.getAllMetadata();
            Boolean userStoryConsistency = bundleController.getIsTheUserStorySelectionConsistant();
            PageReference userStoryTabPage = bundleController.cancel();
            Test.setCurrentPage(userStoryTabPage);

            Test.stopTest();
            System.assertEquals(true, userStoryConsistency, 'User consistency must be true');
            Pagereference assertCancelButton = new PageReference('/' + Schema.SObjectType.copado__User_Story__c.getKeyPrefix() + '/o');
            System.assertEquals(assertCancelButton.getUrl(), userStoryTabPage.getUrl(), 'Url expected is not correct');
        }
    }

    /**
     * Test Cancel a User Story which already belongs to a Bundle.
     */
    @IsTest
    static void testCancellingChildUserStoryBundled() {
        System.runAs(getRunAsUser()) {
            copado__Org__c orgCred = [SELECT Id, Name FROM copado__Org__c LIMIT 1];
            List<copado__User_Story__c> selectedUserStories = getSelectedUserStoriesById(USERSTORY1_USERSTORY2).values();

            ApexPages.StandardSetController bundleUserStoryStandardSetController = new ApexPages.StandardSetController(selectedUserStories);
            bundleUserStoryStandardSetController.setSelected(selectedUserStories);
            CUSB_UserStoryBundleController bundleController = new CUSB_UserStoryBundleController(bundleUserStoryStandardSetController);
            bundleController.getAllMetadata();
            bundleController.bundleUs.copado__User_Story_Title__c = BUNDLED_USER_STORY;
            bundleController.bundleUs.copado__Org_Credential__c = orgCred.Id;
            bundleController.assign();

            Test.startTest();
            String errorMessage;
            copado__User_Story__c testUserStory = [
                SELECT Id, Bundle_User_Story__c, copado__Status__c, copado__Cancellation_Reason__c
                FROM copado__User_Story__c
                WHERE copado__User_Story_Title__c = 'User Story 1'
                LIMIT 1
            ];
            try {
                testUserStory.copado__Status__c = 'Cancelled';
                testUserStory.copado__Cancellation_Reason__c = 'Cancellation reason';
                update testUserStory;
            } catch (Exception excp) {
                errorMessage = excp.getDmlMessage(0);
            }
            System.assertEquals(
                'The user story status cannot be changed to Cancelled since it is part of a bundle and the bundle will continue moving the changes committed in this user story. You need to cancel the parent user story bundle first in order to cancel this user story.',
                errorMessage,
                'Error message is different from expected in "Cancelling_a_child_user_story_bundled" validation rule'
            );
            Test.stopTest();
        }
    }

    /**
     * Returns selected user stories by Id
     * @return Map<Id, copado__User_Story__c>
     */
    private static Map<Id, copado__User_Story__c> getSelectedUserStoriesById(List<String> selectedUserStories) {
        return new Map<Id, copado__User_Story__c>(
            [
                SELECT
                    Id,
                    Name,
                    copado__Stop_Indexing_Metadata__c,
                    copado__Exclude_From_CBM__c,
                    Bundle_User_Story__c,
                    copado__Org_Credential__c,
                    copado__Environment__c
                FROM copado__User_Story__c
                WHERE copado__User_Story_Title__c = :selectedUserStories
            ]
        );
    }

    /**
     * Returns Deployment Tasks by User Story Id
     * @return Map<Id, copado__Deployment_Task__c>
     */
    private static Map<Id, copado__Deployment_Task__c> getDeploymentTasksByUserStoryId(Set<Id> userStoryIds) {
        return new Map<Id, copado__Deployment_Task__c>(
            [
                SELECT
                    Id,
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
            ]
        );
    }

    /**
     * Run as User
     */
    public static User createUser() {
        User runAsUser = new User(
            LastName = 'UserLastName',
            Username = 'username@myemail.com',
            Email = 'username@myemail.com',
            Alias = 'MyAlias',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = UserInfo.getProfileId(),
            LanguageLocaleKey = 'en_US'
        );
        insert runAsUser;
        return runAsUser;
    }

    /**
     * Retrieve Run as User
     */
    public static User getRunAsUser() {
        List<User> runAsUsers = [SELECT Id FROM User WHERE Username = 'username@myemail.com'];
        return runAsUsers[0];
    }

    /**
     * Assign user licenses
     */
    public static void assignLicense(Id userId) {
        copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
        copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();
        userLicense.isCCMEnabled = true;
        userLicense.isCopadoEnabled = true;
        userLicense.userId = userId;
        copadoGlobalAPI.upsertCopadoLicense(userLicense);
    }

    /**
     * Assign PermissionSet
     */
    public static void assignPermissionSet(Id userId) {
        PermissionSetAssignment permSetAssignment = new PermissionSetAssignment();
        permSetAssignment.PermissionSetId = [SELECT Id, Name FROM PermissionSet WHERE Name = 'Copado_User_Story_Bundle' LIMIT 1].Id;
        permSetAssignment.AssigneeId = userId;
        insert permSetAssignment;
    }
}