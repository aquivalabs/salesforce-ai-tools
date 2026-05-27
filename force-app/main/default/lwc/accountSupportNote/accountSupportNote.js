import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createSupportNote from '@salesforce/apex/AccountSupportNoteController.createSupportNote';

export default class AccountSupportNote extends LightningElement {
    @api recordId;
    noteText = '';

    handleChange(event) {
        this.noteText = event.detail.value;
    }

    handleSave() {
        createSupportNote({ accountId: this.recordId, noteText: this.noteText })
            .then(() => {
                this.noteText = '';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Support note saved',
                        variant: 'success'
                    })
                );
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error saving note',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }
}
