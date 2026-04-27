/**
 * Author          : Mansoor Ahmad
 * Description     : AuraEnabled controller exposing yacht search and reservation
 *                   to LWC components on the Experience Cloud site.
 *                   Thin controller — delegates all logic to service classes.
 *                   Runs with sharing — respects guest user record visibility.
 *
 */
public with sharing class YachtSearchController {

    /**
     * @description Search yachts by type, date, and party size.
     *              cacheable=false — availability must always be fresh.
     * @param yachtTypeId Filter by yacht type ID — null returns all types
     * @param searchDate  ISO date string e.g. 2026-06-15
     * @param partySize   Minimum required capacity
     * @param offset      Pagination offset for infinite scroll
     * @return            YachtSearchResultWrapper
     */
    @AuraEnabled(cacheable=false)
    public static YachtSearchResultWrapper searchYachts(String yachtTypeId, String searchDate, Integer partySize, Integer offset) {
        try {
            Id typeId = String.isNotBlank(yachtTypeId) ? (Id) yachtTypeId : null;
            Date parsedDate = String.isNotBlank(searchDate) ? Date.valueOf(searchDate) : null;
            Integer safeOffset = offset != null ? offset : 0;

            return YachtSearchService.searchYachts(
                typeId, parsedDate, partySize, safeOffset
            );
        
        } catch (YachtException ex) {
            throw new AuraHandledException(ex.getMessage());
        
        } catch (Exception ex) {
            Logger.error('searchYachts error: ' + ex.getMessage());
            Logger.saveLog();
            throw new AuraHandledException(
                'Unable to load yachts. Please try again.'
            );
        }
    }

    /**
     * @description Fetch all active yacht types for the filter dropdown.
     *              cacheable=true — types change infrequently.
     * @return List of Yacht_Type__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Yacht_Type__c> getYachtTypes() {
        try {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.READABLE,
                [
                    SELECT Id, Name, Description__c, Display_Order__c
                    FROM Yacht_Type__c
                    WHERE Is_Active__c = true
                    WITH SECURITY_ENFORCED
                    ORDER BY Display_Order__c ASC
                ]
            );
            return (List<Yacht_Type__c>) decision.getRecords();

            // List<Yacht_Type__c> lstYachts = [SELECT Id, Name, Description__c, Display_Order__c 
            //                                 FROM Yacht_Type__c 
            //                                 WHERE Is_Active__c = true 
            //                                 ORDER BY Display_Order__c ASC
            // ];
            
            // return lstYachts;
            
        } catch (Exception ex) {
            Logger.error('getYachtTypes error: ' + ex.getMessage());
            Logger.saveLog();
            throw new AuraHandledException(
                'Unable to load yacht types. Please try again.'
            );
        }
    }

    /**
     * @description Submit a reservation for a selected yacht.
     * @param requestJson JSON-serialized ReservationRequest
     * @return            YachtReservationService.ReservationResult
     */
    @AuraEnabled
    public static YachtReservationService.ReservationResult reserveYacht(String requestJson) {
        try {
            YachtReservationService.ReservationRequest request = (YachtReservationService.ReservationRequest)
                JSON.deserialize(
                    requestJson,
                    YachtReservationService.ReservationRequest.class
                );
            
            return YachtReservationService.reserve(request);
        
        } catch (YachtException ex) {
            throw new AuraHandledException(ex.getMessage());
        
        } catch (Exception ex) {
            Logger.error('reserveYacht error: ' + ex.getMessage());
            Logger.saveLog();
            throw new AuraHandledException(
                'Reservation could not be completed. Please try again.'
            );
        }
    }
}