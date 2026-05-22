public with sharing class LogSupportNoteController {
    @AuraEnabled
    public static void logNote(String note, Id accountId) {
        if (String.isBlank(note)) {
            throw new AuraHandledException('Note cannot be blank.');
        }
        if (accountId == null) {
            throw new AuraHandledException('Account ID is required.');
        }
        Task t = new Task(
            Subject = note,
            Status = 'Completed',
            WhatId = accountId,
            ActivityDate = Date.today()
        );
        insert t;
    }
}
