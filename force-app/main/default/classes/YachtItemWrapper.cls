/**
 * Author          : Mansoor Ahmad
 * Description     : wrapper or DTO representing a single yacht card in search results.
 *                   Carries yacht data plus availability and pricing for
 *                   the searched date. Passed from service layer to LWC.
 *
 */
public with sharing class YachtItemWrapper {
    @AuraEnabled public Id id { get; set; }
    @AuraEnabled public String name { get; set; }
    @AuraEnabled public String yachtTypeName { get; set; }
    @AuraEnabled public Id yachtTypeId { get; set; }
    @AuraEnabled public Integer capacity { get; set; }
    @AuraEnabled public Integer minPartySize { get; set; }
    @AuraEnabled public String headline { get; set; }
    @AuraEnabled public String description { get; set; }
    @AuraEnabled public String imageUrl { get; set; }
    @AuraEnabled public Boolean isAvailable { get; set; }
    @AuraEnabled public Decimal price { get; set; }
}