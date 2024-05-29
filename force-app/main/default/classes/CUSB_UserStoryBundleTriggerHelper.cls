public with sharing class CUSB_UserStoryBundleTriggerHelper {
    public static void moveChildUserStoriesAcrossEnvironments(Map<Id, copado__User_Story__c> usNew, Map<Id, copado__User_Story__c> usOld) {
        List<copado__User_Story__c> changedUserStories = new List<copado__User_Story__c>();
        List<Id> changedUserStoryIds = new List<Id>();
        for (copado__User_Story__c userStoryItem : usNew.values()) {
            if (userStoryItem.Is_Bundle__c && userStoryItem.copado__Org_Credential__c != usOld.get(userStoryItem.Id).copado__Org_Credential__c) {
                changedUserStories.add(userStoryItem);
                changedUserStoryIds.add(userStoryItem.Id);
            }
        }
        if (!changedUserStoryIds.isEmpty()) {
            System.enqueueJob(new CUSB_UserStoryBundleQueueable(usNew, usOld, changedUserStories, changedUserStoryIds));
        }
    }
}