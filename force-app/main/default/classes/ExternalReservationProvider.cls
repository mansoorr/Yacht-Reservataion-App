/**
 * Author          : Mansoor Ahmad
 * Description     : Real implementation of IReservationProvider.
 *                   Makes HTTP callout to external Salesforce org via
 *                   Named Credential: Yacht_Reservation_API.
 *                   Only active when Use_Mock_Provider__c = false in CMT.
 */
public class ExternalReservationProvider implements IReservationProvider {

    private static final String NAMED_CREDENTIAL = 'callout:Yacht_Reservation_API';
    private static final String RESERVATION_ENDPOINT = '/services/apexrest/reservations';

    /**
     * @description Submits reservation to external org and returns result.
     */
    public YachtReservationService.ReservationResult submitReservation(YachtReservationService.ReservationRequest request) {
        
        Yacht_Integration_Settings__mdt settings = Yacht_Integration_Settings__mdt.getInstance('Default');
        
        Integer timeout = settings != null ? (Integer)settings.API_Timeout_ms__c : 10000;

        Map<String, Object> requestBody = new Map<String, Object>{
            'yachtId'         => request.yachtId,
            'reservationDate' => String.valueOf(request.reservationDate),
            'partySize'       => request.partySize,
            'guestName'       => request.guestName,
            'guestEmail'      => request.guestEmail,
            'totalPrice'      => request.totalPrice
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + RESERVATION_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(requestBody));
        req.setTimeout(timeout);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
            return parseReservationResponse(res.getBody());
        }

        throw new YachtException(
            'Reservation API returned status ' + res.getStatusCode()
        );
    }

    /**
     * @description Parses JSON response into ReservationResult
     * Expected format: { confirmationNumber, externalReferenceId }
     */
    private YachtReservationService.ReservationResult parseReservationResponse(String responseBody) {
        
        Map<String, Object> record = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        return new YachtReservationService.ReservationResult(
            true,
            (String) record.get('confirmationNumber'),
            (String) record.get('externalReferenceId')
        );
    }
}