/**
 * Author          : Mansoor Ahmad
 * Description     : Service class for searching and filtering yachts.
 *                   Queries Yacht__c records, applies party size filter,
 *                   fetches availability via YachtAvailabilityService,
 *                   and returns ordered results.
 * 
 *                   Implements offset-based pagination (Page_Size__c from CMT).
 *                   
 */

public with sharing class YachtSearchService {

    private static final String  SETTINGS_RECORD  = 'Default';
    private static final Integer DEFAULT_PAGE_SIZE = 9;

    /**
     * @description Search yachts by type, date, and party size.
     *              Returns paginated results with availability overlaid.
     *              Available yachts sorted first.
     * @param yachtTypeId Filter by type — null means all types
     * @param searchDate  Date to check availability
     * @param partySize   Minimum capacity required
     * @param offset      Pagination offset
     * @return            YachtSearchResultWrapper
     */
    public static YachtSearchResultWrapper searchYachts(Id yachtTypeId, Date searchDate, Integer partySize, Integer offset ) {
        
        validateSearchInputs(partySize, searchDate);

        // Fetch Custom Metadata
        Yacht_Integration_Settings__mdt settings = Yacht_Integration_Settings__mdt.getInstance(SETTINGS_RECORD);
        
        Integer pageSize = settings != null ? (Integer) settings.Page_Size__c : DEFAULT_PAGE_SIZE;

        List<Yacht__c> yachts = queryYachts(yachtTypeId, partySize, pageSize, offset);

        Integer totalCount = countYachts(yachtTypeId, partySize);

        if (yachts.isEmpty()) {
            YachtSearchResultWrapper empty = new YachtSearchResultWrapper();
            empty.totalCount = totalCount;
            return empty;
        }

        List<Id> yachtIds = new List<Id>();
        for (Yacht__c y : yachts) {
            yachtIds.add(y.Id);
        }

        Map<Id, YachtAvailabilityService.AvailabilityResult> mapAvailabilityResults = new Map<Id, YachtAvailabilityService.AvailabilityResult>();

        if (searchDate != null) {
            mapAvailabilityResults = YachtAvailabilityService.fetchAvailability(yachtIds, searchDate);
        }

        List<Yacht__c> strippedYachts = (List<Yacht__c>)
            Security.stripInaccessible(AccessType.READABLE, yachts).getRecords();

        List<YachtItemWrapper> wrappers = buildWrappers(strippedYachts, mapAvailabilityResults);

        wrappers.sort(new AvailabilityComparator());

        YachtSearchResultWrapper result = new YachtSearchResultWrapper();
        result.yachts     = wrappers;
        result.hasMore    = (offset + pageSize) < totalCount;
        result.totalCount = totalCount;

        return result;
    }

    // ─── Private Methods 

    private static void validateSearchInputs(Integer partySize, Date searchDate) {
        if (partySize != null && partySize <= 0) {
            throw new YachtException('Party size must be a positive number.');
        }

        if (searchDate != null && searchDate < Date.today()) {
            throw new YachtException(
                'Search date must be today or in the future.'
            );
        }
    }

    private static List<Yacht__c> queryYachts(Id yachtTypeId, Integer partySize, Integer pageSize, Integer offsetVal) {
        
        // Build dynamic query
        String query =
            'SELECT Id, Name, Headline__c, Description__c, Image_URL__c, ' +
            'Capacity__c, Minimum_Party_Size__c, Is_Active__c, ' +
            'Yacht_Type__c, Yacht_Type__r.Name ' +
            'FROM Yacht__c ' +
            'WHERE Is_Active__c = true ';

        if (yachtTypeId != null) {
            query += 'AND Yacht_Type__c = :yachtTypeId ';
        }

        if (partySize != null) {
            query += 'AND Capacity__c >= :partySize ';
        }
        
        query += 'ORDER BY Name ASC ';
        query += 'LIMIT :pageSize OFFSET :offsetVal';

        return Database.query(query);
    }

    private static Integer countYachts(Id yachtTypeId, Integer partySize) {
        String query = 'SELECT COUNT() FROM Yacht__c WHERE Is_Active__c = true ';
        
        if (yachtTypeId != null) {
            query += 'AND Yacht_Type__c = :yachtTypeId ';
        }
        
        if (partySize != null) {
            query += 'AND Capacity__c >= :partySize ';
        }
        
        return Database.countQuery(query);
    }

    private static List<YachtItemWrapper> buildWrappers(List<Yacht__c> yachts, Map<Id, YachtAvailabilityService.AvailabilityResult> mapAvailabilities) {
        List<YachtItemWrapper> wrappers = new List<YachtItemWrapper>();

        for (Yacht__c y : yachts) {
            YachtItemWrapper w  = new YachtItemWrapper();
            w.id                = y.Id;
            w.name              = y.Name;
            w.yachtTypeId       = y.Yacht_Type__c;
            w.yachtTypeName     = y.Yacht_Type__r?.Name;
            w.capacity          = (Integer) y.Capacity__c;
            w.minPartySize      = y.Minimum_Party_Size__c != null
                                    ? (Integer) y.Minimum_Party_Size__c : 1;
            w.headline          = y.Headline__c;
            w.description       = y.Description__c;
            w.imageUrl          = y.Image_URL__c;

            YachtAvailabilityService.AvailabilityResult avail = mapAvailabilities.get(y.Id);
            w.isAvailable       = avail != null ? avail.isAvailable : false;
            w.price             = avail != null ? avail.price       : null;
            wrappers.add(w);
        }
        return wrappers;
    }

    // ─── Comparator 

    private class AvailabilityComparator
        implements Comparator<YachtItemWrapper> {
        public Integer compare(YachtItemWrapper a, YachtItemWrapper b) {
            if (a.isAvailable == b.isAvailable) return 0;
            return a.isAvailable ? -1 : 1;
        }
    }
}