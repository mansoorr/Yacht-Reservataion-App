/**
 * Author          : Mansoor Ahmad
 * Description     : Service class for submitting and recording yacht reservations.
 *                   Handles validation, idempotency, external callout via provider
 *                   interface, and local Salesforce record creation.
 *
 *                   Runs WITHOUT SHARING intentionally — guest users cannot own
 *                   records in Salesforce. 
 *                   Input validation and field-level checks are enforced
 *                   manually via WITH SECURITY_ENFORCED on all SOQL queries.
 */
public without sharing class YachtReservationService {

    // ─── Inner Classes 

    public class ReservationRequest {
        @AuraEnabled public Id      yachtId         { get; set; }
        @AuraEnabled public Date    reservationDate  { get; set; }
        @AuraEnabled public Integer partySize        { get; set; }
        @AuraEnabled public String  guestName        { get; set; }
        @AuraEnabled public String  guestEmail       { get; set; }
        @AuraEnabled public Decimal totalPrice       { get; set; }
    }

    public class ReservationResult {
        @AuraEnabled public Boolean success             { get; set; }
        @AuraEnabled public String  confirmationNumber  { get; set; }
        @AuraEnabled public String  externalReferenceId { get; set; }
        @AuraEnabled public String  errorMessage        { get; set; }

        public ReservationResult(Boolean success, String confirmationNumber, String extRefId) {
            this.success            = success;
            this.confirmationNumber = confirmationNumber;
            this.externalReferenceId = extRefId;
        }

        public ReservationResult(String errorMessage) {
            this.success      = false;
            this.errorMessage = errorMessage;
        }
    }

    // ─── Constants 

    private static final String SETTINGS_RECORD = 'Default';

    // ─── Provider Injection 

    @TestVisible
    private static IReservationProvider providerOverride;

    private static IReservationProvider getProvider() {
        if (providerOverride != null) {
            return providerOverride;
        }

        Yacht_Integration_Settings__mdt settings = Yacht_Integration_Settings__mdt.getInstance(SETTINGS_RECORD);
        
        if (settings != null && settings.Use_Mock_Provider__c) {
            return new MockReservationProvider();
        }
        return new ExternalReservationProvider();
    }

    // ─── Public Methods 

    /**
     * @description Main reservation entry point.
     *              Validates input, checks idempotency, calls provider, saves record.
     * @param request Populated ReservationRequest from LWC controller
     * @return        ReservationResult with success flag and confirmation details
     */
    public static ReservationResult reserve(ReservationRequest request) {
        try {
            validateRequest(request);
            checkIdempotency(request);

            IReservationProvider provider = getProvider();
            ReservationResult result = provider.submitReservation(request);

            if (result.success) {
                saveReservationRecord(request, result);
                markAvailabilityUnavailable(request.yachtId, request.reservationDate);
            } else {
                saveFailedAttempt(request, result.errorMessage);
            }

            return result;

        } catch (IdempotencyException ex) {
            return new ReservationResult(ex.getMessage());
        
        } catch (YachtException ex) {
            Logger.warn('Reservation validation failed: ' + ex.getMessage());
            Logger.saveLog();
            return new ReservationResult(ex.getMessage());
        
        } catch (Exception ex) {
            Logger.error('Reservation failed unexpectedly: ' + ex.getMessage());
            Logger.saveLog();
            return new ReservationResult(
                'Your reservation could not be completed. Please try again.'
            );
        }
    }

    // ─── Private Methods

    private static void validateRequest(ReservationRequest request) {
        if (request == null) {
            throw new YachtException('Invalid reservation request.');
        }

        if (request.yachtId == null) {
            throw new YachtException('Yacht is required.');
        }

        if (request.reservationDate == null || request.reservationDate < Date.today()) {
            throw new YachtException(
                'Reservation date must be today or in the future.'
            );
        }

        if (request.partySize == null || request.partySize <= 0) {
            throw new YachtException('Party size must be a positive number.');
        }

        Yacht_Integration_Settings__mdt settings = Yacht_Integration_Settings__mdt.getInstance(SETTINGS_RECORD);
        
        Integer maxPartySize = settings != null ? (Integer) settings.Max_Party_Size__c : 20;

        if (request.partySize > maxPartySize) {
            throw new YachtException(
                'Party size cannot exceed ' + maxPartySize + ' guests.'
            );
        }

        List<Yacht__c> yachts = [
            SELECT Id, Capacity__c, Minimum_Party_Size__c
            FROM Yacht__c
            WHERE Id = :request.yachtId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (yachts.isEmpty()) {
            throw new YachtException('Yacht not found.');
        }

        Yacht__c yacht = yachts[0];

        if (request.partySize > yacht.Capacity__c) {
            throw new YachtException(
                'Party size exceeds yacht capacity of ' + (Integer) yacht.Capacity__c + '.'
            );
        }

        if (yacht.Minimum_Party_Size__c != null && request.partySize < yacht.Minimum_Party_Size__c) {
            throw new YachtException(
                'Minimum party size for this yacht is ' + (Integer) yacht.Minimum_Party_Size__c + '.'
            );
        }
    }

    private static void checkIdempotency(ReservationRequest request) {
        String key = buildIdempotencyKey(request);
        
        List<Yacht_Reservation__c> existing = [
            SELECT Id, Status__c
            FROM Yacht_Reservation__c
            WHERE Idempotency_Key__c = :key
            LIMIT 1
        ];
        
        if (!existing.isEmpty()) {
            throw new IdempotencyException(
                'A reservation for this yacht on this date already exists.'
            );
        }
    }

    private static void saveReservationRecord( ReservationRequest request, ReservationResult result) {
        
        Yacht__c yacht = [
            SELECT Name FROM Yacht__c
            WHERE Id = :request.yachtId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        insert new Yacht_Reservation__c(
            Yacht__c                 = request.yachtId,
            Reservation_Date__c      = request.reservationDate,
            Party_Size__c            = request.partySize,
            Guest_Name__c            = request.guestName,
            Guest_Email__c           = request.guestEmail,
            Status__c                = 'Confirmed',
            Total_Price__c           = request.totalPrice,
            Confirmation_Number__c   = result.confirmationNumber,
            External_Reference_ID__c = result.externalReferenceId,
            Idempotency_Key__c       = buildIdempotencyKey(request)
        );

        // Send confirmation email — failure does not affect reservation
        YachtConfirmationEmailService.sendConfirmation(
            request.guestEmail,
            request.guestName,
            yacht.Name,
            request.reservationDate,
            request.partySize,
            result.confirmationNumber,
            request.totalPrice
        );
    }

    private static void saveFailedAttempt(ReservationRequest request, String errorMessage) {
        insert new Yacht_Reservation__c(
            Yacht__c            = request.yachtId,
            Reservation_Date__c = request.reservationDate,
            Party_Size__c       = request.partySize,
            Guest_Name__c       = request.guestName,
            Guest_Email__c      = request.guestEmail,
            Status__c           = 'Failed',
            Idempotency_Key__c  = buildIdempotencyKey(request)
        );
    }

    private static void markAvailabilityUnavailable( Id yachtId, Date reservationDate) {
        
        List<Yacht_Availability__c> availability = [
            SELECT Id, Is_Available__c 
            FROM Yacht_Availability__c
            WHERE Yacht__c = :yachtId
            AND Available_Date__c = :reservationDate
            LIMIT 1
        ];

        if (!availability.isEmpty()) {
            availability[0].Is_Available__c = false;
            update availability[0];
        }
    }

    private static String buildIdempotencyKey(ReservationRequest request) {
        return request.yachtId + '_' + String.valueOf(request.reservationDate) + '_' + request.guestEmail?.toLowerCase();
    }

    // ─── Custom Exceptions

    public class IdempotencyException extends Exception {}
}