/**
 * Author          : Mansoor Ahmad
 * Description     : wrapper or DTO representing a paginated page of yacht search results.
 *                   Returned from YachtSearchService to LWC via controller.
 *
 */
public with sharing class YachtSearchResultWrapper {
    @AuraEnabled public List<YachtItemWrapper> yachts { get; set; }
    @AuraEnabled public Boolean hasMore { get; set; }
    @AuraEnabled public Integer totalCount { get; set; }

    public YachtSearchResultWrapper() {
        this.yachts = new List<YachtItemWrapper>();
        this.hasMore = false;
        this.totalCount = 0;
    }
}