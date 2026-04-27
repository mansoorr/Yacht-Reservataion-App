/**
 * Author          : Mansoor Ahmad
 * Description     : Real implementation of IAvailabilityProvider.
 *                   Makes HTTP callout to external Salesforce org via
 *                   Named Credential: Yacht_Reservation_API.
 *                   Deserializes JSON response into AvailabilityResult wrappers.
 *                   Only active when Use_Mock_Provider__c = false in CMT.
 */
public class ExternalAvailabilityProvider implements IAvailabilityProvider {

    private static final String NAMED_CREDENTIAL = 'callout:Yacht_Reservation_API';
    private static final String AVAILABILITY_ENDPOINT = '/services/apexrest/availability';

    /**
     * @description Calls external org availability endpoint.
     * Sends yacht IDs and date, receives availability and pricing per yacht.
     */
    public Map<Id, YachtAvailabilityService.AvailabilityResult> getAvailability( List<Id> yachtIds, Date searchDate) {
        
        Yacht_Integration_Settings__mdt settings = Yacht_Integration_Settings__mdt.getInstance('Default');
        Integer timeout = settings != null ? (Integer)settings.API_Timeout_ms__c : 10000;

        Map<String, Object> requestBody = new Map<String, Object>{
            'yachtIds' => yachtIds,
            'date'     => String.valueOf(searchDate)
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + AVAILABILITY_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(requestBody));
        req.setTimeout(timeout);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new YachtException(
                'Availability API returned status ' + res.getStatusCode()
            );
        }

        return parseAvailabilityResponse(res.getBody());
    }

    /**
     * @description Parses JSON response from external org into result map
     * Expected format: [{ yachtId, isAvailable, price, externalAvailabilityId }]
     */
    private Map<Id, YachtAvailabilityService.AvailabilityResult> parseAvailabilityResponse(String responseBody) {
        
        Map<Id, YachtAvailabilityService.AvailabilityResult> mapAvailabilityResults = new Map<Id, YachtAvailabilityService.AvailabilityResult>();

        List<Object> rawList = (List<Object>) JSON.deserializeUntyped(responseBody);

        for (Object item : rawList) {
            Map<String, Object> mapRecord = (Map<String, Object>) item;     // Typecast to basic object map structure
            Id yachtId       = (Id) mapRecord.get('yachtId');
            Boolean isAvail  = (Boolean) mapRecord.get('isAvailable');
            Decimal price    = (Decimal) mapRecord.get('price');
            String extId     = (String) mapRecord.get('externalAvailabilityId');

            mapAvailabilityResults.put(
                yachtId,
                new YachtAvailabilityService.AvailabilityResult(
                    yachtId, isAvail, price, extId
                )
            );
        }
        return mapAvailabilityResults;
    }
}