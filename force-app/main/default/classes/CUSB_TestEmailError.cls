@IsTest
private class CUSB_TestEmailError {
    @IsTest
    static void testSendErrorEmail() {
        Test.startTest();
        //This is not a real use case test.
        //TODO: Cover potential error email scenarios 
        CUSB_EmailError.sendErrorEmail('User Story Bundle Error', 'Message', 'Error in Copado', UserInfo.getUserId());
        Test.stopTest();
    }
}