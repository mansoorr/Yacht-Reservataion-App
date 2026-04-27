import { LightningElement, track, wire } from 'lwc';
import { subscribe, MessageContext } from 'lightning/messageService';
import YACHT_SEARCH_CHANNEL from '@salesforce/messageChannel/YachtSearchChannel__c';
import searchYachts from '@salesforce/apex/YachtSearchController.searchYachts';

const PAGE_SIZE = 9;

export default class YachtResultsGridlwc extends LightningElement {

    @wire(MessageContext)
    messageContext;

    @track yachts        = [];
    @track isLoading     = false;
    @track isLoadingMore = false;
    @track hasMore       = false;
    @track totalCount    = 0;
    @track errorMessage  = '';
    @track hasError      = false;

    searchParams  = null;
    currentOffset = 0;
    subscription  = null;
    observer      = null;

    connectedCallback() {
        this.subscription = subscribe(
            this.messageContext,
            YACHT_SEARCH_CHANNEL,
            (payload) => this.handleSearchMessage(payload)
        );
    }

    disconnectedCallback() {
        this.disconnectObserver();
    }

    renderedCallback() {
        if (this.hasMore && !this.isLoadingMore) {
            this.connectObserver();
        }
    }

    handleSearchMessage(payload) {
        this.searchParams  = payload;
        this.currentOffset = 0;
        this.yachts        = [];
        this.hasMore       = false;
        this.hasError      = false;
        this.errorMessage  = '';
        this.loadYachts(true);
    }

    async loadYachts(isNewSearch = false) {
        if (!this.searchParams) return;

        if (isNewSearch) {
            this.isLoading = true;
        } else {
            this.isLoadingMore = true;
        }

        try {
            const result = await searchYachts({
                yachtTypeId : this.searchParams.yachtTypeId,
                searchDate  : this.searchParams.searchDate,
                partySize   : this.searchParams.partySize,
                offset      : this.currentOffset
            });

            if (isNewSearch) {
                this.yachts = result.yachts || [];
            } else {
                this.yachts = [...this.yachts, ...(result.yachts || [])];
            }

            this.hasMore       = result.hasMore;
            this.totalCount    = result.totalCount;
            this.currentOffset += PAGE_SIZE;

        } catch (error) {
            this.hasError     = true;
            this.errorMessage = error?.body?.message
                || 'Unable to load yachts. Please try again.';
        } finally {
            this.isLoading     = false;
            this.isLoadingMore = false;
        }
    }

    connectObserver() {
        if (this.observer) return;
        const sentinel = this.template.querySelector('.scroll-sentinel');
        if (!sentinel) return;

        this.observer = new IntersectionObserver(
            (entries) => {
                if (
                    entries[0].isIntersecting &&
                    this.hasMore &&
                    !this.isLoadingMore
                ) {
                    this.loadYachts(false);
                }
            },
            { threshold: 0.1 }
        );
        this.observer.observe(sentinel);
    }

    disconnectObserver() {
        if (this.observer) {
            this.observer.disconnect();
            this.observer = null;
        }
    }

    handleYachtSelect(event) {
        this.dispatchEvent(
            new CustomEvent('yachtselect', {
                detail   : event.detail,
                bubbles  : true,
                composed : true
            })
        );
    }

    handleRetry() {
        this.hasError = false;
        this.loadYachts(true);
    }

    get hasResults() {
        return !this.isLoading && !this.hasError && this.yachts.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasError
            && this.yachts.length === 0 && this.searchParams !== null;
    }
}