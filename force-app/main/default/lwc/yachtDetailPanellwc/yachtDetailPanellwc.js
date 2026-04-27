import { LightningElement, api, track } from 'lwc';
import reserveYacht from '@salesforce/apex/YachtSearchController.reserveYacht';

const FALLBACK_IMAGE = 'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?w=800&q=80';

export default class YachtDetailPanellwc extends LightningElement {

    @api searchDate;
    @api partySize;

    @track _yacht             = null;
    @track isReserving        = false;
    @track showConfirmation   = false;
    @track confirmationNumber = '';
    @track reservationError   = '';
    @track isReserved         = false;
    @track guestName          = '';
    @track guestEmail         = '';
    @track formError          = '';

    @api
    get yacht() { return this._yacht; }
    set yacht(val) {
        this._yacht           = val;
        this.showConfirmation = false;
        this.reservationError = '';
        this.formError        = '';
        this.isReserved       = false;
        this.guestName        = '';
        this.guestEmail       = '';
    }

    // ── Getters ───────────────────────────────────────────────────────────────

    get isVisible() { return this._yacht !== null; }

    get isUnavailable() {
        return !this._yacht?.isAvailable || this.isReserved;
    }

    get isReserveDisabled() {
        return this.isUnavailable || this.isReserving || this.showConfirmation;
    }

    get reserveBtnLabel() {
        if (this.isReserved || this.showConfirmation) return 'Reserved';
        if (!this._yacht?.isAvailable) return 'Unavailable';
        return 'Reserve Now';
    }

    get availabilityLabel() {
        if (this.isReserved) return 'Reserved';
        return this._yacht?.isAvailable ? 'Available' : 'Unavailable';
    }

    get pillClass() {
        return this.isUnavailable
            ? 'availability-pill availability-pill--unavailable'
            : 'availability-pill availability-pill--available';
    }

    get formattedPrice() {
        if (!this._yacht?.price) return '';
        return new Intl.NumberFormat('en-AE', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(this._yacht.price);
    }

    // ── Handlers ─────────────────────────────────────────────────────────────

    handleNameChange(event) {
        this.guestName = event.target.value;
        this.formError = '';
    }

    handleEmailChange(event) {
        this.guestEmail = event.target.value;
        this.formError  = '';
    }

    validateForm() {
        if (!this.guestName || this.guestName.trim() === '') {
            this.formError = 'Please enter your full name.';
            return false;
        }
        if (!this.guestEmail || this.guestEmail.trim() === '') {
            this.formError = 'Please enter your email address.';
            return false;
        }
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(this.guestEmail)) {
            this.formError = 'Please enter a valid email address.';
            return false;
        }
        return true;
    }

    async handleReserve() {
        if (this.isReserveDisabled) return;
        if (!this.validateForm()) return;

        this.isReserving      = true;
        this.reservationError = '';

        const request = {
            yachtId         : this._yacht.id,
            reservationDate : this.searchDate,
            partySize       : this.partySize,
            guestName       : this.guestName.trim(),
            guestEmail      : this.guestEmail.trim().toLowerCase(),
            totalPrice      : this._yacht.price || 0
        };

        try {
            const result = await reserveYacht({
                requestJson: JSON.stringify(request)
            });

            if (result.success) {
                this.showConfirmation  = true;
                this.confirmationNumber = result.confirmationNumber;
                this.isReserved        = true;
                this.dispatchEvent(
                    new CustomEvent('reservationsuccess', {
                        detail: {
                            yachtId           : this._yacht.id,
                            confirmationNumber : result.confirmationNumber
                        },
                        bubbles  : true,
                        composed : true
                    })
                );
            } else {
                this.reservationError = result.errorMessage
                    || 'Reservation could not be completed. Please try again.';
            }
        } catch (error) {
            this.reservationError = error?.body?.message
                || 'Reservation could not be completed. Please try again.';
        } finally {
            this.isReserving = false;
        }
    }

    handleClose() {
        this._yacht = null;
        this.dispatchEvent(new CustomEvent('panelclose'));
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleImageError(event) {
        event.target.src = FALLBACK_IMAGE;
    }
}