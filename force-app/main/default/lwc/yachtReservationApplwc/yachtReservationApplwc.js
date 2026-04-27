import { LightningElement, track, wire } from 'lwc';
import { subscribe, MessageContext } from 'lightning/messageService';
import YACHT_SEARCH_CHANNEL from '@salesforce/messageChannel/YachtSearchChannel__c';
import HERO_IMAGE from '@salesforce/resourceUrl/YachtHeroBg';

export default class YachtReservationApplwc extends LightningElement {

    @wire(MessageContext)
    messageContext;

    @track showSearch        = false;
    @track selectedYacht     = null;
    @track currentSearchDate = '';
    @track currentPartySize  = null;

    heroImageUrl = HERO_IMAGE;

    subscription = null;

    connectedCallback() {
        this.subscription = subscribe(
            this.messageContext,
            YACHT_SEARCH_CHANNEL,
            (payload) => {
                this.currentSearchDate = payload.searchDate;
                this.currentPartySize  = payload.partySize;
                this.selectedYacht     = null;
            }
        );
    }

    handleShowSearch() {
        this.showSearch = true;
    }

    handleHeroBack() {
        this.showSearch    = false;
        this.selectedYacht = null;
    }

    handleYachtSelect(event) {
        this.selectedYacht = event.detail.yacht;
    }

    handlePanelClose() {
        this.selectedYacht = null;
    }

    handleReservationSuccess() {
        setTimeout(() => {
            this.selectedYacht = null;
        }, 3000);
    }

    get gridClass() {
        return this.selectedYacht
            ? 'grid-column grid-column--narrow'
            : 'grid-column grid-column--full';
    }

    get heroStyle() {
        return `background-image: url('${this.heroImageUrl}');`;
    }
}