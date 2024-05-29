trigger CUSB_UserStoryBundleTrigger on copado__User_Story__c (after update) {
    new CUSB_UserStoryBundleTriggerHandler().run();
}