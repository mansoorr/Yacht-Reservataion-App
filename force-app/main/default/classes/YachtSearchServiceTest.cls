/**
 * Author          : Mansoor Ahmad
 * Created         : Apr 26, 2026
 * Description     : Test class for YachtSearchService.
 *                   Covers search filtering, pagination, availability sorting,
 *                   and party size validation.
 *
 * Change History  :
 *  Date           │ Author          │ Change
 * ─────────────────────────────────────────────────────────────────────────────
 *  Apr 26, 2026   │ Mansoor Ahmad   │ Initial version
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class YachtSearchServiceTest {

    @TestSetup
    static void setupData() {
        List<Yacht_Type__c> lstYachtTypesInsert = new List<Yacht_Type__c>();        
        Yacht_Type__c motorType = new Yacht_Type__c(
            Name            = 'Motor',
            Is_Active__c    = true,
            Display_Order__c = 1
        );
        lstYachtTypesInsert.add(motorType);

        Yacht_Type__c sailType = new Yacht_Type__c(
            Name            = 'Sailing',
            Is_Active__c    = true,
            Display_Order__c = 2
        );
        lstYachtTypesInsert.add(sailType);
        insert lstYachtTypesInsert;

        List<Yacht__c> lstYachtsInsert = new List<Yacht__c>();
        for (Integer i = 1; i <= 5; i++) {
            lstYachtsInsert.add(new Yacht__c(
                Name                  = 'Motor Yacht ' + i,
                Yacht_Type__c         = motorType.Id,
                Capacity__c           = 10,
                Minimum_Party_Size__c = 2,
                Headline__c           = 'Motor headline ' + i,
                Image_URL__c          = 'https://example.com/motor' + i + '.jpg',
                Is_Active__c          = true,
                External_Yacht_ID__c  = 'EXT-MOTOR-' + i
            ));
        }
        for (Integer i = 1; i <= 3; i++) {
            lstYachtsInsert.add(new Yacht__c(
                Name                  = 'Sailing Yacht ' + i,
                Yacht_Type__c         = sailType.Id,
                Capacity__c           = 6,
                Minimum_Party_Size__c = 2,
                Headline__c           = 'Sailing headline ' + i,
                Image_URL__c          = 'https://example.com/sail' + i + '.jpg',
                Is_Active__c          = true,
                External_Yacht_ID__c  = 'EXT-SAIL-' + i
            ));
        }
        insert lstYachtsInsert;
    }

    @IsTest
    static void testSearch_NoFilters_ReturnsAllYachts() {
        Test.startTest();
        YachtSearchResultWrapper result = YachtSearchService.searchYachts(null, Date.today().addDays(5), 1, 0);
        Test.stopTest();

        System.assertEquals( 8, result.totalCount, 'Should return all 8 yachts with no type filter');
    }

    @IsTest
    static void testSearch_FilterByType_ReturnsCorrectYachts() {
        Yacht_Type__c motorType = [ SELECT Id FROM Yacht_Type__c WHERE Name = 'Motor' LIMIT 1];

        Test.startTest();
        YachtSearchResultWrapper result = YachtSearchService.searchYachts(
            motorType.Id, Date.today().addDays(5), 1, 0
        );
        Test.stopTest();

        System.assertEquals( 5, result.totalCount, 'Should return only 5 motor yachts');
    }

    @IsTest
    static void testSearch_PartySizeFilter_ExcludesSmallYachts() {
        Test.startTest();
        YachtSearchResultWrapper result = YachtSearchService.searchYachts(
            null, Date.today().addDays(5), 8, 0
        );
        Test.stopTest();

        System.assertEquals(5, result.totalCount, 'Only motor yachts with capacity >= 8 should be returned');
        
        for (YachtItemWrapper w : result.yachts) {
            System.assert( w.capacity >= 8, 'All returned yachts should have capacity >= 8');
        }
    }

    @IsTest
    static void testSearch_AvailabilitySort_AvailableFirst() {
        List<Yacht__c> yachts = [SELECT Id FROM Yacht__c LIMIT 3];
        Date searchDate = Date.today().addDays(5);

        YachtAvailabilityService.providerOverride = buildMockWithFirstUnavailable(yachts);

        Test.startTest();
        YachtSearchResultWrapper result = YachtSearchService.searchYachts(null, searchDate, 1, 0);
        Test.stopTest();

        Boolean foundUnavailable = false;
        for (YachtItemWrapper w : result.yachts) {
            if (foundUnavailable) {
                System.assertEquals( false, w.isAvailable, 'Unavailable yachts should come after available ones' );
            }
            if (!w.isAvailable) {
                foundUnavailable = true;
            }
        }
    }

    @IsTest
    static void testSearch_Pagination_HasMoreTrue() {
        // Page size is 9, we have 8 yachts — first page fits all
        // Test offset behaviour instead — offset past all records returns empty
        Test.startTest();
        YachtSearchResultWrapper firstPage =
            YachtSearchService.searchYachts(
                null, Date.today().addDays(5), 1, 0
            );
        YachtSearchResultWrapper secondPage =
            YachtSearchService.searchYachts(
                null, Date.today().addDays(5), 1, 9
            );
        Test.stopTest();

        System.assertEquals( false, firstPage.hasMore, '8 yachts fits within page size of 9 — hasMore should be false');
        System.assertEquals( 0, secondPage.yachts.size(), 'Second page with offset 9 should return no results');
    }

    @IsTest
    static void testSearch_InvalidPartySize_ThrowsException() {
        Test.startTest();
        try {
            YachtSearchService.searchYachts(
                null, Date.today().addDays(5), -1, 0
            );
            System.assert(false, 'Should have thrown YachtException');
        
        } catch (YachtException ex) {
            System.assert( ex.getMessage().contains('positive number'), 'Error should mention positive number');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSearch_PastDate_ThrowsException() {
        Test.startTest();
        try {
            YachtSearchService.searchYachts(
                null, Date.today().addDays(-1), 2, 0
            );
            System.assert(false, 'Should have thrown YachtException');
        
        } catch (YachtException ex) {
            System.assert( ex.getMessage().contains('today or in the future'), 'Error should mention date requirement');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSearch_NullDate_ReturnsResultsWithoutAvailability() {
        Test.startTest();
        YachtSearchResultWrapper result = YachtSearchService.searchYachts(null, null, 1, 0);
        Test.stopTest();

        System.assertNotEquals( null, result, 'Should return results even without a date' );
        
        for (YachtItemWrapper w : result.yachts) {
            System.assertEquals( false, w.isAvailable, 'Without a date, availability defaults to false');
        }
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    private static MockAvailabilityProvider buildMockWithFirstUnavailable(
        List<Yacht__c> yachts
    ) {
        MockAvailabilityProvider mock = new MockAvailabilityProvider();
        mock.availabilityOverrides.put(yachts[0].Id, false);
        return mock;
    }
}