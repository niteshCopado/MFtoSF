public with sharing class CUSB_UserStoryBundleTriggerHandler extends CUSB_TriggerHandler {
    private Map<Id, copado__User_Story__c> userStoryNew;
    private Map<Id, copado__User_Story__c> userStoryOld;

    public CUSB_UserStoryBundleTriggerHandler() {
        this.userStoryNew = (Map<Id, copado__User_Story__c>) Trigger.newMap;
        this.userStoryOld = (Map<Id, copado__User_Story__c>) Trigger.oldMap;
    }

    public override void afterUpdate() {
        CUSB_UserStoryBundleTriggerHelper.moveChildUserStoriesAcrossEnvironments(userStoryNew, userStoryOld);
    }
}