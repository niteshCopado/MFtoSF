public with sharing class CUSB_UserStoryBundleQueueable implements Queueable {
    private Map<Id, copado__User_Story__c> usNew;
    private Map<Id, copado__User_Story__c> usOld;
    private List<copado__User_Story__c> changedUserStories;
    private List<Id> changedUserStoryIds;

    public CUSB_UserStoryBundleQueueable(
        Map<Id, copado__User_Story__c> newRecords,
        Map<Id, copado__User_Story__c> oldRecords,
        List<copado__User_Story__c> chUserStories,
        List<Id> chUsIds
    ) {
        this.usNew = newRecords;
        this.usOld = oldRecords;
        this.changedUserStories = chUserStories;
        this.changedUserStoryIds = chUsIds;
    }
    public void execute(QueueableContext context) {
        Map<String, String> promotionByUserStory = new Map<String, String>();

        List<copado__Promoted_User_Story__c> bundlePromotedUserStories = new List<copado__Promoted_User_Story__c>();
        Set<String> existingPromotionsKey = new Set<String>();

        Savepoint sp = Database.setSavepoint();
        try {
            Map<Id, copado__User_Story__c> childUserStoriesById = new Map<Id, copado__User_Story__c>(
                [
                    SELECT Id, Name, Bundle_User_Story__c, copado__Org_Credential__c, copado__Environment__c
                    FROM copado__User_Story__c
                    WHERE Bundle_User_Story__c = :changedUserStoryIds
                    WITH SECURITY_ENFORCED
                ]
            );
            // ExistingPromotionsKey adds keys forward and reverse to prevent promotion creation when a Bundle User Story is changed manually to previous environment.
            existingPromotionsKey = existingPromotedUserStories(childUserStoriesById.keySet());

            // Promotion creation and match changed user story with its bundle promotion to make correct assignation in Promoted User Story Creation
            promotionByUserStory = getPromotionByUserStory(changedUserStories, existingPromotionsKey, usOld);

            for (copado__User_Story__c childItem : childUserStoriesById.values()) {
                childItem.copado__Org_Credential__c = usNew.get(childItem.Bundle_User_Story__c).copado__Org_Credential__c;
                childItem.copado__Environment__c = usNew.get(childItem.Bundle_User_Story__c).copado__Environment__c;

                if (promotionByUserStory.containsKey(childItem.Bundle_User_Story__c)) {
                    copado__Promoted_User_Story__c promotedUserStory = new copado__Promoted_User_Story__c();
                    promotedUserStory.Name = 'Promoted User Story: ' + childItem.Name;
                    promotedUserStory.copado__User_Story__c = childItem.Id;
                    promotedUserStory.copado__Promotion__c = promotionByUserStory.get(childItem.Bundle_User_Story__c);

                    bundlePromotedUserStories.add(promotedUserStory);
                }
            }

            // Strip fields that are not insertable / updatable
            SObjectAccessDecision bundlePromotedUserStoriesDecision = Security.stripInaccessible(AccessType.CREATABLE, bundlePromotedUserStories);
            SObjectAccessDecision childUserStoriesDecision = Security.stripInaccessible(AccessType.UPDATABLE, childUserStoriesById.values());

            insert bundlePromotedUserStoriesDecision.getRecords();
            update childUserStoriesDecision.getRecords();
        } catch (Exception ex) {
            Database.rollback(sp);
            CUSB_EmailError.sendErrorEmail('User Story Bundle Error', ex.getMessage(), 'Error in User Story Bundle Process', UserInfo.getUserId());
        }
    }

    /**
     * When Org Credential is changed, Promotion with OLD Value as Source Org Credential and NEW Value as Destination Org is created.
     * We have to be sure duplicated Promotions are not created for child user stories.
     * So, if Bundle User Story already have a promotion for next or previous environment, child will have it for sure.
     */
    private Set<String> existingPromotedUserStories(Set<Id> childUserStoryIds) {
        Set<String> existingPromotionsKey = new Set<String>();
        for (copado__Promoted_User_Story__c promotedUserStoriesItem : [
            SELECT Id, copado__Promotion__r.copado__Source_Org_Credential__c, copado__Promotion__r.copado__Destination_Org_Credential__c
            FROM copado__Promoted_User_Story__c
            WHERE copado__Promotion__r.copado__Back_Promotion__c = false AND copado__User_Story__c = :childUserStoryIds
            WITH SECURITY_ENFORCED
        ]) {
            existingPromotionsKey.add(
                promotedUserStoriesItem.copado__Promotion__r.copado__Source_Org_Credential__c +
                '-' +
                promotedUserStoriesItem.copado__Promotion__r.copado__Destination_Org_Credential__c
            );
            existingPromotionsKey.add(
                promotedUserStoriesItem.copado__Promotion__r.copado__Destination_Org_Credential__c +
                '-' +
                promotedUserStoriesItem.copado__Promotion__r.copado__Source_Org_Credential__c
            );
        }
        return existingPromotionsKey;
    }

    /**
     * Promotion creation for each User Story that have changed and User Story assignation with its bundle promotion
     */
    private Map<String, String> getPromotionByUserStory(
        List<copado__User_Story__c> changedUserStories,
        Set<String> existingPromotionsKey,
        Map<Id, copado__User_Story__c> usOld
    ) {
        Map<String, String> promotionByUserStory = new Map<String, String>();
        List<Id> changedUserStoryIds = new List<Id>();
        List<copado__Promotion__c> bundlePromotions = new List<copado__Promotion__c>();
        for (copado__User_Story__c userStoryChangedItem : changedUserStories) {
            String promotionKey = usOld.get(userStoryChangedItem.Id).copado__Org_Credential__c + '-' + userStoryChangedItem.copado__Org_Credential__c;

            if (!existingPromotionsKey.contains(promotionKey)) {
                copado__Promotion__c childUserStoryPromotion = new copado__Promotion__c();
                childUserStoryPromotion.copado__Status__c = 'Completed';
                childUserStoryPromotion.copado__Project__c = userStoryChangedItem.copado__Project__c;
                childUserStoryPromotion.copado__Release__c = userStoryChangedItem.copado__Release__c;
                childUserStoryPromotion.copado__Source_Org_Credential__c = usOld.get(userStoryChangedItem.Id).copado__Org_Credential__c;
                childUserStoryPromotion.copado__Source_Environment__c = usOld.get(userStoryChangedItem.Id).copado__Environment__c;
                childUserStoryPromotion.copado__Destination_Org_Credential__c = userStoryChangedItem.copado__Org_Credential__c;
                childUserStoryPromotion.copado__Destination_Environment__c = userStoryChangedItem.copado__Environment__c;

                bundlePromotions.add(childUserStoryPromotion);
                changedUserStoryIds.add(userStoryChangedItem.Id);
            }
        }
        // Strip fields that are not insertable / updatable
        SObjectAccessDecision bundlePromotionsDecision = Security.stripInaccessible(AccessType.CREATABLE, bundlePromotions);
        bundlePromotions = bundlePromotionsDecision.getRecords();
        insert bundlePromotions;
        // Match changed user story with its bundle promotion to make correct assignation in Promoted User Story Creation
        for (Integer i = 0, j = bundlePromotions.size(); i < j; i++) {
            promotionByUserStory.put(changedUserStoryIds[i], bundlePromotions[i].Id);
        }
        return promotionByUserStory;
    }
}