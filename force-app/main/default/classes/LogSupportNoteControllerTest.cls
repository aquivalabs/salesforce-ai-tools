@IsTest
private class LogSupportNoteControllerTest {
    @TestSetup
    static void makeData() {
        insert new Account(Name = 'Test Account');
    }

    @IsTest
    static void happyPath_createsCompletedTask() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        LogSupportNoteController.logNote('Support call completed', acc.Id);
        Test.stopTest();

        Task t = [SELECT Subject, Status, WhatId, ActivityDate FROM Task LIMIT 1];
        Assert.areEqual('Support call completed', t.Subject);
        Assert.areEqual('Completed', t.Status);
        Assert.areEqual(acc.Id, t.WhatId);
        Assert.areEqual(Date.today(), t.ActivityDate);
    }

    @IsTest
    static void blankNote_throwsException() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        try {
            LogSupportNoteController.logNote('', acc.Id);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().length() > 0);
        }
    }

    @IsTest
    static void nullAccountId_throwsException() {
        try {
            LogSupportNoteController.logNote('Some note', null);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().length() > 0);
        }
    }
}
