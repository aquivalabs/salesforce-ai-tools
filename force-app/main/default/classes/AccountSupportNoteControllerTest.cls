@IsTest
private class AccountSupportNoteControllerTest {
    @IsTest
    static void createSupportNoteInsertsTask() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Test.startTest();
        AccountSupportNoteController.createSupportNote(acc.Id, 'Test Note');
        Test.stopTest();

        List<Task> tasks = [
            SELECT Status, Subject, WhatId
            FROM Task
            WHERE WhatId = :acc.Id
        ];
        System.assertEquals(1, tasks.size(), 'Expected one Task');
        System.assertEquals('Completed', tasks[0].Status);
        System.assertEquals('Test Note', tasks[0].Subject);
        System.assertEquals(acc.Id, tasks[0].WhatId);
    }
}
