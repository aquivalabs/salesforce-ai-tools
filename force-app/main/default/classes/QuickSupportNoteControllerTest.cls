@isTest
private class QuickSupportNoteControllerTest {
    @isTest
    static void logsCompletedTaskOnAccount() {
        Account acct = new Account(Name = 'Acme Test');
        insert acct;

        Test.startTest();
        QuickSupportNoteController.logSupportNote(acct.Id, 'Customer called about a billing question.');
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject, Status, WhatId, Type, ActivityDate
            FROM Task
            WHERE WhatId = :acct.Id
        ];
        System.assertEquals(1, tasks.size(), 'Expected exactly one task logged on the account');
        System.assertEquals('Customer called about a billing question.', tasks[0].Subject);
        System.assertEquals('Completed', tasks[0].Status, 'Task should be marked completed');
        System.assertEquals('Other', tasks[0].Type);
        System.assertEquals(Date.today(), tasks[0].ActivityDate);
    }

    @isTest
    static void truncatesLongNoteTo255Chars() {
        Account acct = new Account(Name = 'Acme Test');
        insert acct;

        Test.startTest();
        QuickSupportNoteController.logSupportNote(acct.Id, 'x'.repeat(300));
        Test.stopTest();

        Task t = [SELECT Subject FROM Task WHERE WhatId = :acct.Id LIMIT 1];
        System.assertEquals(255, t.Subject.length(), 'Subject should be truncated to 255 chars');
    }

    @isTest
    static void rejectsBlankNote() {
        Account acct = new Account(Name = 'Acme Test');
        insert acct;

        Boolean threw = false;
        Test.startTest();
        try {
            QuickSupportNoteController.logSupportNote(acct.Id, '   ');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected an AuraHandledException for a blank note');
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :acct.Id], 'No task should be created for a blank note');
    }
}
