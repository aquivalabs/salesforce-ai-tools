public with sharing class AccountSupportNoteController {
    @AuraEnabled
    public static void createSupportNote(Id accountId, String noteText) {
        insert new Task(
            Status = 'Completed',
            Subject = noteText,
            WhatId = accountId
        );
    }
}
