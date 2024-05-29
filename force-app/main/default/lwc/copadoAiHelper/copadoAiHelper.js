import { LightningElement, api, wire } from 'lwc';
import PreviewModal from 'c/previewModal';
import useAI from '@salesforce/label/c.USE_AI';
import privacyPolicy from '@salesforce/label/c.PRIVACY_POLICY';
import labelError from '@salesforce/label/c.ERROR';
import headerLabel from '@salesforce/label/c.HEADER_LABEL';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const FIELDS = [
    'copado__User_Story__c.copado__Acceptance_Criteria__c',
    'copado__User_Story__c.copado__Functional_Specifications__c',
    'copado__User_Story__c.copado__Technical_Specifications__c',
    'copado__User_Story__c.copado__User_Story_Title__c',
    'copado__User_Story__c.copado__userStory_Role__c',
    'copado__User_Story__c.copado__userStory_need__c',
    'copado__User_Story__c.copado__userStory_reason__c',
];

export default class CopadoAiHelper extends LightningElement {
    @api recordId;
    @api max_tokens;
    @api temperature;
    @api engine;
    userStory;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ err, data }) {
        if (err) {
            let message = 'Unknown error';
            if (Array.isArray(err.body)) {
                message = err.body.map(e => e.message).join(', ');
            } else if (typeof err.body.message === 'string') {
                message = err.body.message;
            }

            this.dispatchEvent(new ShowToastEvent({
                title: labelError,
                message: message,
                variant: 'error',
            }));
        } else if (data) {
            this.userStory = data;
        }
    }

    label = {
        useAI,
        headerLabel,
        privacyPolicy,
    };

    async handlePreview() {
        await PreviewModal.open({
            size: 'large',
            description: 'Preview the current OpenAI information',
            payload: {
                max_tokens: this.max_tokens,
                userStory: this.userStory,
                temperature: this.temperature,
                engine: this.engine,
            },
        });
    }
}