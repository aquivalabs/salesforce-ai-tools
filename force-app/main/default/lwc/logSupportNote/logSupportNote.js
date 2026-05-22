import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import createTask from '@salesforce/apex/LogSupportNoteController.createTask';

export default class LogSupportNote extends LightningElement {
    @api recordId;
    noteText = '';
    isSaving = false;

    handleChange(event) {
        this.noteText = event.detail.value;
    }

    async handleSave() {
        if (!this.noteText.trim()) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation',
                message: 'Note cannot be blank.',
                variant: 'warning'
            }));
            return;
        }
        this.isSaving = true;
        try {
            await createTask({ accountId: this.recordId, noteText: this.noteText });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Support note logged as a Task.',
                variant: 'success'
            }));
            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error?.body?.message ?? 'An error occurred.',
                variant: 'error'
            }));
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
