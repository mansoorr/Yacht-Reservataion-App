import { LightningElement, track, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import YACHT_SEARCH_CHANNEL from '@salesforce/messageChannel/YachtSearchChannel__c';
import getYachtTypes from '@salesforce/apex/YachtSearchController.getYachtTypes';

export default class YachtSearchFilterslwc extends LightningElement {

    @wire(MessageContext)
    messageContext;

    yachtTypes = [];
    yachtTypesError;

    @wire(getYachtTypes)
    wiredYachtTypes({ data, error }) {
        if (data) {
            this.yachtTypes = data;
        } else if (error) {
            console.error('Error loading yacht types', error);
        }
    }

    @track selectedTypeId  = '';
    @track selectedDate    = '';
    @track partySize       = null;
    @track validationError = '';

    get todayString() {
        const d = new Date();
        return d.toISOString().split('T')[0];
    }

    get isSearchDisabled() {
        return !this.selectedDate || !this.partySize;
    }

    handleTypeChange(event) {
        this.selectedTypeId = event.target.value;
    }

    handleDateChange(event) {
        this.selectedDate    = event.target.value;
        this.validationError = '';
    }

    handlePartySizeChange(event) {
        const val = parseInt(event.target.value, 10);
        if (isNaN(val) || val <= 0) {
            this.validationError = 'Party size must be a positive number.';
            this.partySize = null;
        } else {
            this.validationError = '';
            this.partySize = val;
        }
    }

    handleSearch() {
        if (!this.selectedDate) {
            this.validationError = 'Please select a date.';
            return;
        }
        if (!this.partySize || this.partySize <= 0) {
            this.validationError = 'Please enter a valid party size.';
            return;
        }

        const payload = {
            yachtTypeId : this.selectedTypeId || null,
            searchDate  : this.selectedDate,
            partySize   : this.partySize
        };

        publish(this.messageContext, YACHT_SEARCH_CHANNEL, payload);
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back', {
            bubbles: true,
            composed: true
        }));
    }

    handleDateClick(event) {
        try {
            event.target.showPicker();
        } catch(e) {
            // fallback for browsers that don't support showPicker
        }
    }
}