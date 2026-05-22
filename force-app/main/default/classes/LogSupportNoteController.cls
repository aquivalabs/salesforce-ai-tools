public with sharing class LogSupportNoteController {

    @AuraEnabled
    public static void createTask(Id accountId, String noteText) {
        if (accountId == null || String.isBlank(noteText)) {
            throw new AuraHandledException('accountId and noteText are required');
        }
        Task t = new Task(
            Subject = noteText,
            WhatId = accountId,
            Status = 'Completed',
            ActivityDate = Date.today()
        );
        insert t;
    }
}
