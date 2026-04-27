/**
 * Author          : Mansoor Ahmad
 * Description     : Service class for fetching and caching yacht availability.
 *                   Calls external org via Named Credential or mock provider
 *                   based on Yacht_Integration_Settings__mdt configuration.
 *                   Upserts Yacht_Availability__c records as a local cache.
 */
public with sharing class YachtAvailabilityService {

    // ─── Inner Classes 

    public class AvailabilityResult {
        @AuraEnabled public Id yachtId { get; set; }
        @AuraEnabled public Boolean isAvailable { get; set; }
        @AuraEnabled public Decimal price { get; set; }
        @AuraEnabled public String externalAvailabilityId { get; set; }
        @AuraEnabled public String errorMessage { get; set; }

        public AvailabilityResult(Id yachtId, Boolean isAvailable, Decimal price, String extId) {
            this.yachtId              = yachtId;
            this.isAvailable          = isAvailable;
            this.price                = price;
            this.externalAvailabilityId = extId;
        }
    }

    // ─── Constants 

    private static final String SETTINGS_RECORD = 'Default';

    // ─── Provider Injection 

    @TestVisible
    private static IAvailabilityProvider providerOverride;

    private static IAvailabilityProvider getProvider() {
        
        if (providerOverride != null) {
            return providerOverride;
        }
        
        Yacht_Integration_Settings__mdt settings = Yacht_Integration_Settings__mdt.getInstance(SETTINGS_RECORD);
        
        if (settings != null && settings.Use_Mock_Provider__c) {
            return new MockAvailabilityProvider();
        }
        return new ExternalAvailabilityProvider();
    }

    // ─── Public Methods 

    /**
     * @description Fetch availability for given yachts on given date.
     *              Updates cached Yacht_Availability__c records as side effect.
     * @param yachtIds   List of yacht IDs to check
     * @param searchDate Date to check
     * @return           Map of Yacht ID to AvailabilityResult
     */
    public static Map<Id, AvailabilityResult> fetchAvailability(List<Id> yachtIds, Date searchDate) {
        
        if (yachtIds == null || yachtIds.isEmpty()) {
            return new Map<Id, AvailabilityResult>();
        }
        
        if (searchDate == null || searchDate < Date.today()) {
            throw new YachtException('Search date must be today or in the future.');
        }

        Map<Id, AvailabilityResult> mapAvailbilityResults = new Map<Id, AvailabilityResult>();

        try {
            IAvailabilityProvider provider = getProvider();
            mapAvailbilityResults = provider.getAvailability(yachtIds, searchDate);
            updateAvailabilityCache(mapAvailbilityResults, searchDate);

        } catch (YachtException ex) {
            throw ex;
        
        } catch (Exception ex) {
            Logger.error('Availability fetch failed: ' + ex.getMessage());
            Logger.saveLog();
            throw new YachtException('Unable to retrieve availability. Please try again.');
        }

        return mapAvailbilityResults;
    }

    // ─── Private Methods 

    /**
     * @description Upsert Yacht_Availability__c records from API results.
     *              Uses External_Availability_ID__c as the upsert key.
     */
    private static void updateAvailabilityCache(Map<Id, AvailabilityResult> mapAvailabilityResults, Date searchDate) {
        List<Yacht_Availability__c> lstAvailibilitytoUpsert = new List<Yacht_Availability__c>();

        for (Id yachtId : mapAvailabilityResults.keySet()) {
            AvailabilityResult result = mapAvailabilityResults.get(yachtId);
            
            lstAvailibilitytoUpsert.add(new Yacht_Availability__c(
                Yacht__c                    = yachtId,
                Available_Date__c           = searchDate,
                Is_Available__c             = result.isAvailable,
                Price__c                    = result.price,
                Last_Synced__c              = DateTime.now(),
                External_Availability_ID__c = result.externalAvailabilityId
            ));
        }

        if (!lstAvailibilitytoUpsert.isEmpty()) {
            Database.upsert( lstAvailibilitytoUpsert, Yacht_Availability__c.External_Availability_ID__c, false);
        }
    }
}