import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import logSupportNote from '@salesforce/apex/QuickSupportNoteController.logSupportNote';

export default class QuickSupportNote extends LightningElement {
    @api recordId;
    noteBody = '';
    isSaving = false;

    handleNoteChange(event) {
        this.noteBody = event.target.value;
    }

    async handleSave() {
        if (!this.noteBody || !this.noteBody.trim()) {
            this.showToast('Nothing to save', 'Please enter a support note before saving.', 'warning');
            return;
        }
        this.isSaving = true;
        try {
            await logSupportNote({ accountId: this.recordId, noteBody: this.noteBody });
            this.showToast('Note saved', 'Your support note was logged as a completed activity.', 'success');
            this.noteBody = '';
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (error) {
            const message =
                error && error.body && error.body.message
                    ? error.body.message
                    : 'Something went wrong saving your note.';
            this.showToast('Error', message, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
