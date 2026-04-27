/**
 * Author          : Mansoor Ahmad
 * Description     : Mock implementation of IAvailabilityProvider.
 *                   Returns controlled availability data without HTTP callouts.
 *                   Used when Yacht_Integration_Settings__mdt.Use_Mock_Provider__c
 *                   is true or when injected directly in test classes.
 *                   Simulates realistic availability — odd-indexed yachts
 *                   are marked unavailable to demonstrate UI disabled states.
 */

public class MockAvailabilityProvider implements IAvailabilityProvider {

    // Configurable for tests — inject specific availability scenarios
    @TestVisible
    private Map<Id, Boolean> mapAvailabilityOverrides = new Map<Id, Boolean>();

    @TestVisible
    private Map<Id, Decimal> mapPriceOverrides = new Map<Id, Decimal>();

    /**
     * @description Returns mock availability for each yacht ID.
     * Alternates available/unavailable to simulate realistic results.
     */
    public Map<Id, YachtAvailabilityService.AvailabilityResult> getAvailability(List<Id> yachtIds, Date searchDate) {
        
        Map<Id, YachtAvailabilityService.AvailabilityResult> results = new Map<Id, YachtAvailabilityService.AvailabilityResult>();

        Integer index = 0;
        for (Id yachtId : yachtIds) {

            Boolean isAvailable = mapAvailabilityOverrides.containsKey(yachtId)
                ? mapAvailabilityOverrides.get(yachtId)
                : Math.mod(index, 3) != 0; // Every 3rd yacht unavailable

            Decimal price = mapPriceOverrides.containsKey(yachtId)
                ? mapPriceOverrides.get(yachtId)
                : 500 + (index * 150); // Varied pricing for realism

            String extId = 'MOCK-AVAIL-' + yachtId + '-' 
                + String.valueOf(searchDate).replace('-', '');

            results.put(
                yachtId,
                new YachtAvailabilityService.AvailabilityResult(
                    yachtId,
                    isAvailable,
                    price,
                    extId
                )
            );
            index++;
        }
        return results;
    }
}