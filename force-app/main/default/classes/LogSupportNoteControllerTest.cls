@IsTest
private class LogSupportNoteControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
    }

    @IsTest
    static void createTask_insertsTaskLinkedToAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        LogSupportNoteController.createTask(acc.Id, 'Follow-up call needed');
        Test.stopTest();

        List<Task> tasks = [SELECT Subject, WhatId, Status, ActivityDate FROM Task WHERE WhatId = :acc.Id];
        Assert.areEqual(1, tasks.size(), 'Expected one Task');
        Assert.areEqual('Follow-up call needed', tasks[0].Subject);
        Assert.areEqual('Completed', tasks[0].Status);
        Assert.areEqual(Date.today(), tasks[0].ActivityDate);
    }

    @IsTest
    static void createTask_throwsOnBlankNote() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        try {
            LogSupportNoteController.createTask(acc.Id, '');
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            // AuraHandledException.getMessage() returns 'Script-thrown exception' in test context
            Assert.isNotNull(e, 'Expected AuraHandledException to be thrown');
        }
    }

    @IsTest
    static void createTask_throwsOnNullAccountId() {
        try {
            LogSupportNoteController.createTask(null, 'Note');
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Expected AuraHandledException to be thrown');
        }
    }
}
