import { LightningElement, api } from 'lwc';

const FALLBACK_IMAGE = 'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?w=600&q=80';

export default class YachtCardlwc extends LightningElement {

    @api yacht;

    get isUnavailable() {
        return !this.yacht?.isAvailable;
    }

    get cardClass() {
        return this.isUnavailable
            ? 'yacht-card yacht-card--unavailable'
            : 'yacht-card yacht-card--available';
    }

    get availabilityPillClass() {
        return this.isUnavailable
            ? 'availability-pill availability-pill--unavailable'
            : 'availability-pill availability-pill--available';
    }

    get availabilityLabel() {
        return this.isUnavailable ? 'Unavailable' : 'Available';
    }

    get formattedPrice() {
        if (!this.yacht?.price) return '';
        return new Intl.NumberFormat('en-AE', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(this.yacht.price);
    }

    get ariaLabel() {
        return `${this.yacht?.name} — ${this.availabilityLabel}`;
    }

    handleCardClick() {
        if (this.isUnavailable) return;
        this.dispatchEvent(
            new CustomEvent('yachtselect', {
                detail: { yacht: this.yacht },
                bubbles: true,
                composed: true
            })
        );
    }

    handleKeyPress(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            this.handleCardClick();
        }
    }

    handleImageError(event) {
        debugger;
        event.target.src = FALLBACK_IMAGE;
    }
}