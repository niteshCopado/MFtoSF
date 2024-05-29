@IsTest
private class CUSB_TestUserStoryBundleTriggerHelper {
    @TestSetup
    static void makeData() {
        User runAsUser = CUSB_TestUserStoryBundle.createUser();
        CUSB_TestUserStoryBundle.assignPermissionSet(runAsUser.Id);
        System.runAs(runAsUser) {
            CUSB_TestUserStoryBundle.assignLicense(runAsUser.Id);

            copado__Org__c devOrgCredential = new copado__Org__c(Name = 'Dev 1', copado__SFDC_Org_ID__c = '00D1i00000095cEEAQ_0050X000007h8hTQAQ_6');
            copado__Org__c stagingOrgCredential = new copado__Org__c(
                Name = 'Staging',
                copado__SFDC_Org_ID__c = '00D1i00000095cEEAQ_0050X000007h8hTQAQ_3'
            );
            insert new List<copado__Org__c>{ devOrgCredential, stagingOrgCredential };

            copado__Deployment_Flow__c pipeline = new copado__Deployment_Flow__c();
            pipeline.Name = 'Test Pipeline';
            pipeline.copado__Active__c = true;
            insert pipeline;

            copado__Deployment_Flow_Step__c pipelineConnectionDev = new copado__Deployment_Flow_Step__c();
            pipelineConnectionDev.copado__Deployment_Flow__c = pipeline.Id;
            pipelineConnectionDev.copado__Source_Environment__c = devOrgCredential.copado__Environment__c;
            pipelineConnectionDev.copado__Destination_Environment__c = stagingOrgCredential.copado__Environment__c;
            insert pipelineConnectionDev;

            copado__Project__c project = new copado__Project__c();
            project.copado__Deployment_Flow__c = pipeline.Id;
            insert project;

            copado__User_Story__c bundleUs = new copado__User_Story__c();
            bundleUs.copado__User_Story_Title__c = 'Bundled User Story';
            bundleUs.copado__Org_Credential__c = devOrgCredential.Id;
            bundleUs.copado__Project__c = project.Id;
            bundleUs.RecordTypeId = Schema.SObjectType.copado__User_Story__c.getRecordTypeInfosByName().get('User Story').getRecordTypeId();
            bundleUs.Is_Bundle__c = true;
            bundleUs.copado__Status__c = 'Draft';
            insert bundleUs;

            copado__User_Story__c userStory1 = new copado__User_Story__c();
            userStory1.copado__User_Story_Title__c = 'User Story 1';
            userStory1.copado__Project__c = project.Id;
            userStory1.Bundle_User_Story__c = bundleUs.Id;
            userStory1.copado__Stop_Indexing_Metadata__c = true;
            userStory1.copado__Exclude_From_CBM__c = true;

            copado__User_Story__c userStory2 = new copado__User_Story__c();
            userStory2.copado__User_Story_Title__c = 'User Story 2';
            userStory2.copado__Project__c = project.Id;
            userStory2.Bundle_User_Story__c = bundleUs.Id;
            userStory2.copado__Stop_Indexing_Metadata__c = true;
            userStory2.copado__Exclude_From_CBM__c = true;

            insert new List<copado__User_Story__c>{ userStory1, userStory2 };
        }
    }

    /**
     * Test changes in bundle us org credential to be replicated across child user stories.
     */
    @IsTest
    static void testChangeChildUserStoriesOrgCredential() {
        System.runAs(CUSB_TestUserStoryBundle.getRunAsUser()) {
            copado__Org__c devOrgCredential = new copado__Org__c();
            copado__Org__c stagingOrgCredential = new copado__Org__c();
            for (copado__Org__c orgCredentialItem : [SELECT Id, Name FROM copado__Org__c WHERE Name IN ('Dev 1', 'Staging')]) {
                switch on orgCredentialItem.Name {
                    when 'Dev 1' {
                        devOrgCredential = orgCredentialItem;
                    }
                    when 'Staging' {
                        stagingOrgCredential = orgCredentialItem;
                    }
                }
            }

            copado__User_Story__c bundleUs = [SELECT Id FROM copado__User_Story__c WHERE copado__User_Story_Title__c = 'Bundled User Story' LIMIT 1];

            Test.startTest();
            bundleUs.copado__Org_Credential__c = stagingOrgCredential.Id;
            bundleUs.copado__Environment__c = null;
            update bundleUs;
            Test.stopTest();

            for (copado__Promoted_User_Story__c assertPromotedUserStoryItem : [
                SELECT
                    Id,
                    Name,
                    copado__Promotion__c,
                    copado__Promotion__r.copado__Source_Org_Credential__c,
                    copado__Promotion__r.copado__Destination_Org_Credential__c,
                    copado__User_Story__c
                FROM copado__Promoted_User_Story__c
                WHERE copado__User_Story__c = :bundleUs.Id
            ]) {
                System.assertNotEquals(null, assertPromotedUserStoryItem.copado__Promotion__c, 'Promotion should be populated');
                System.assertEquals(bundleUs.Id, assertPromotedUserStoryItem.copado__User_Story__c, 'Bundle User Story is not correct');
                System.assertEquals(
                    devOrgCredential.Id,
                    assertPromotedUserStoryItem.copado__Promotion__r.copado__Source_Org_Credential__c,
                    'Source Credential is not correct'
                );
                System.assertEquals(
                    stagingOrgCredential.Id,
                    assertPromotedUserStoryItem.copado__Promotion__r.copado__Destination_Org_Credential__c,
                    'Destination Credential is not correct'
                );
            }

            for (copado__User_Story__c childUSerStoryItem : [
                SELECT Id, Bundle_User_Story__c, copado__Stop_Indexing_Metadata__c, copado__Exclude_From_CBM__c, copado__Org_Credential__c
                FROM copado__User_Story__c
                WHERE copado__User_Story_Title__c IN ('User Story 1', 'User Story 2')
            ]) {
                System.assertEquals(bundleUs.Id, childUSerStoryItem.Bundle_User_Story__c, 'Bundle User Story is not correct');
                System.assertEquals(stagingOrgCredential.Id, childUSerStoryItem.copado__Org_Credential__c, 'Bundle User Story is not correct');
            }
        }
    }

    /**
     * Test changing bundle user story org credential to previous environment. Does not create promotion or promoted user stories
     */
    @IsTest
    static void testChangeChildUserStoriesOrgCredentialToPreviousEnv() {
        System.runAs(CUSB_TestUserStoryBundle.getRunAsUser()) {
            copado__Org__c devOrgCredential = new copado__Org__c();
            copado__Org__c stagingOrgCredential = new copado__Org__c();
            for (copado__Org__c orgCredentialItem : [SELECT Id, Name FROM copado__Org__c WHERE Name IN ('Dev 1', 'Staging')]) {
                switch on orgCredentialItem.Name {
                    when 'Dev 1' {
                        devOrgCredential = orgCredentialItem;
                    }
                    when 'Staging' {
                        stagingOrgCredential = orgCredentialItem;
                    }
                }
            }

            copado__User_Story__c bundleUs = [SELECT Id FROM copado__User_Story__c WHERE copado__User_Story_Title__c = 'Bundled User Story' LIMIT 1];
            bundleUs.copado__Org_Credential__c = stagingOrgCredential.Id;
            bundleUs.copado__Environment__c = null;
            update bundleUs;

            List<copado__Promoted_User_Story__c> promotedUserStories = [
                SELECT Id
                FROM copado__Promoted_User_Story__c
                WHERE copado__User_Story__c = :bundleUs.Id
            ];

            Test.startTest();
            bundleUs.copado__Org_Credential__c = devOrgCredential.Id;
            bundleUs.copado__Environment__c = null;
            update bundleUs;
            Test.stopTest();

            List<copado__Promoted_User_Story__c> assertPromotedUserStories = [
                SELECT Id
                FROM copado__Promoted_User_Story__c
                WHERE copado__User_Story__c = :bundleUs.Id
            ];
            System.assertEquals(promotedUserStories.size(), assertPromotedUserStories.size(), 'Promoted user stories number is not the same');

            for (copado__User_Story__c assertChildUSerStories : [
                SELECT Id, Bundle_User_Story__c, copado__Stop_Indexing_Metadata__c, copado__Exclude_From_CBM__c, copado__Org_Credential__c
                FROM copado__User_Story__c
                WHERE copado__User_Story_Title__c IN ('User Story 1', 'User Story 2')
            ]) {
                System.assertEquals(
                    bundleUs.copado__Org_Credential__c,
                    assertChildUSerStories.copado__Org_Credential__c,
                    'Org Credential is not correct'
                );
            }
        }
    }

    /**
     * Test changes in bundle us Status and Rady to Promote to be replicated across child user stories.
     */
    @IsTest
    static void testChangeChildUserStoriesStatusAndReadyToPromote() {
        System.runAs(CUSB_TestUserStoryBundle.getRunAsUser()) {
            copado__User_Story__c bundleUs = [SELECT Id FROM copado__User_Story__c WHERE copado__User_Story_Title__c = 'Bundled User Story' LIMIT 1];

            Test.startTest();
            bundleUs.copado__Status__c = 'Completed';
            bundleUs.copado__Promote_Change__c = true;
            update bundleUs;
            Test.stopTest();

            for (copado__User_Story__c childUSerStoryItem : [
                SELECT Id, Bundle_User_Story__c, copado__Status__c, copado__Promote_Change__c
                FROM copado__User_Story__c
                WHERE Bundle_User_Story__c = :bundleUs.Id
            ]) {
                System.assertEquals(bundleUs.Id, childUSerStoryItem.Bundle_User_Story__c, 'Bundle User Story is not correct');
                System.assertEquals(true, childUSerStoryItem.copado__Promote_Change__c, 'Ready to Promote must be true');
                System.assertEquals('Completed', childUSerStoryItem.copado__Status__c, 'Status is not correct');
            }
        }
    }

    /**
     * Test changes in bundle us Status , Ready to Promote , org credentials are not replicated across child user stories.
     */
    @IsTest
    static void testNoChangesChildUserStoriesStatusReadyToPromoteOrgCredentials() {
        System.runAs(CUSB_TestUserStoryBundle.getRunAsUser()) {
            copado__User_Story__c bundleUs = [
                SELECT Id, copado__Status__c, copado__Promote_Change__c
                FROM copado__User_Story__c
                WHERE copado__User_Story_Title__c = 'Bundled User Story'
                LIMIT 1
            ];
            copado__User_Story__c assertNoChangesBundleUs = bundleUs;

            Test.startTest();
            update bundleUs;
            Test.stopTest();

            List<copado__Promoted_User_Story__c> assertPromotedUserStoryItem = [
                SELECT Id
                FROM copado__Promoted_User_Story__c
                WHERE copado__User_Story__c = :bundleUs.Id
            ];
            System.assertEquals(true, assertPromotedUserStoryItem.isEmpty(), 'List must be empty');

            for (copado__User_Story__c childUSerStoryItem : [
                SELECT Id, Bundle_User_Story__c, copado__Org_Credential__c, copado__Status__c, copado__Promote_Change__c
                FROM copado__User_Story__c
                WHERE Bundle_User_Story__c = :bundleUs.Id
            ]) {
                System.assertEquals(bundleUs.Id, childUSerStoryItem.Bundle_User_Story__c, 'Bundle User Story is not correct');
                System.assertEquals(null, childUSerStoryItem.copado__Org_Credential__c, 'Source Org is not correct');
                System.assertEquals(
                    assertNoChangesBundleUs.copado__Promote_Change__c,
                    childUSerStoryItem.copado__Promote_Change__c,
                    'Ready to promote field is not matching'
                );
                System.assertEquals(assertNoChangesBundleUs.copado__Status__c, childUSerStoryItem.copado__Status__c, 'Status field is not matching');
            }
        }
    }
}