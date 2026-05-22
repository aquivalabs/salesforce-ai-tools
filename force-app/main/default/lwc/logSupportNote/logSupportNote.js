import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import logNote from '@salesforce/apex/LogSupportNoteController.logNote';

export default class LogSupportNote extends LightningElement {
    @api recordId;
    note = '';

    handleNoteChange(event) {
        this.note = event.target.value;
    }

    async handleSave() {
        if (!this.note || !this.note.trim()) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'Note cannot be blank.',
                variant: 'error'
            }));
            return;
        }
        try {
            await logNote({ note: this.note.trim(), accountId: this.recordId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Support note logged.',
                variant: 'success'
            }));
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error?.body?.message ?? 'An unexpected error occurred.',
                variant: 'error'
            }));
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
