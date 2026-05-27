public with sharing class QuickSupportNoteController {
    @AuraEnabled(cacheable=false)
    public static void logSupportNote(Id accountId, String noteBody) {
        if (accountId == null) {
            throw new AuraHandledException('An Account is required to log a support note.');
        }
        if (String.isBlank(noteBody)) {
            throw new AuraHandledException('Please enter a support note before saving.');
        }
        String subject = noteBody.length() > 255 ? noteBody.substring(0, 255) : noteBody;
        insert new Task(
            WhatId = accountId,
            Subject = subject,
            Status = 'Completed',
            ActivityDate = Date.today(),
            Type = 'Other'
        );
    }
}
