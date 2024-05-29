@isTest
private class AccountUtilsTest {
    
    static testMethod void testUpdateAccountStatus() {
        List<Account> testAccounts = new List<Account>();
        testAccounts.add(new Account(Name='Test Account 1'));
        testAccounts.add(new Account(Name='Test Account 2'));
        testAccounts.add(new Account(Name='Test Account 3'));
        insert testAccounts;
        
        String status = 'Inactive';
        AccountUtils.updateAccountStatus(testAccounts, status);
        
        List<Account> updatedAccounts = [SELECT Id, Name, Status__c FROM Account WHERE Id IN :testAccounts];
        for(Account acc : updatedAccounts) {
            System.assertEquals(status, acc.Status__c);
        }
    }
    
    static testMethod void testGetActiveAccounts() {
        List<Account> testAccounts = new List<Account>();
        testAccounts.add(new Account(Name='Test Account 1', Status__c='Active'));
        testAccounts.add(new Account(Name='Test Account 2', Status__c='Inactive'));
        testAccounts.add(new Account(Name='Test Account 3', Status__c='Active'));
        insert testAccounts;
        
        List<Account> activeAccounts = AccountUtils.getActiveAccounts();
        System.assertEquals(2, activeAccounts.size());
        for(Account acc : activeAccounts) {
            System.assertEquals('Active', acc.Status__c);
        }
    }
    
}