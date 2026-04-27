/**
 * Author          : Mansoor Ahmad
 * Created         : Apr 26, 2026
 * Description     : Test class for YachtAvailabilityService.
 *                   Covers successful availability fetch, invalid inputs,
 *                   cache upsert behaviour, and provider error handling.
 *
 * Change History  :
 *  Date           │ Author          │ Change
 * ─────────────────────────────────────────────────────────────────────────────
 *  Apr 26, 2026   │ Mansoor Ahmad   │ Initial version
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class YachtAvailabilityServiceTest {

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        Yacht_Type__c yachtType = new Yacht_Type__c(
            Name         = 'Motor Yacht',
            Is_Active__c = true
        );
        insert yachtType;

        List<Yacht__c> yachts = new List<Yacht__c>();
        for (Integer i = 1; i <= 3; i++) {
            yachts.add(new Yacht__c(
                Name                  = 'Test Yacht ' + i,
                Yacht_Type__c         = yachtType.Id,
                Capacity__c           = 10,
                Minimum_Party_Size__c = 2,
                Headline__c           = 'Test Headline ' + i,
                Image_URL__c          = 'https://example.com/yacht' + i + '.jpg',
                Is_Active__c          = true,
                External_Yacht_ID__c  = 'EXT-YACHT-' + i
            ));
        }
        insert yachts;
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    @IsTest
    static void testFetchAvailability_Success() {
        List<Yacht__c> yachts = [SELECT Id FROM Yacht__c];
        List<Id> yachtIds = new List<Id>();
        for (Yacht__c y : yachts) {
            yachtIds.add(y.Id);
        }

        Date searchDate = Date.today().addDays(7);

        Test.startTest();
        Map<Id, YachtAvailabilityService.AvailabilityResult> results =
            YachtAvailabilityService.fetchAvailability(yachtIds, searchDate);
        Test.stopTest();

        System.assertEquals(
            3, results.size(),
            'Should return availability for all 3 yachts'
        );
        for (Id yId : yachtIds) {
            System.assertNotEquals(
                null, results.get(yId),
                'Each yacht should have an availability result'
            );
        }
    }

    @IsTest
    static void testFetchAvailability_CachesResults() {
        List<Yacht__c> yachts = [SELECT Id FROM Yacht__c LIMIT 1];
        List<Id> yachtIds = new List<Id>{ yachts[0].Id };
        Date searchDate = Date.today().addDays(3);

        Test.startTest();
        YachtAvailabilityService.fetchAvailability(yachtIds, searchDate);
        Test.stopTest();

        List<Yacht_Availability__c> cached = [
            SELECT Id, Yacht__c, Available_Date__c, Is_Available__c, Price__c
            FROM Yacht_Availability__c
            WHERE Yacht__c = :yachts[0].Id
            AND Available_Date__c = :searchDate
        ];

        System.assertEquals(
            1, cached.size(),
            'Availability should be cached in Yacht_Availability__c'
        );
        System.assertNotEquals(
            null, cached[0].Price__c,
            'Cached record should have price populated'
        );
    }

    @IsTest
    static void testFetchAvailability_EmptyYachtIds() {
        Test.startTest();
        Map<Id, YachtAvailabilityService.AvailabilityResult> results =
            YachtAvailabilityService.fetchAvailability(
                new List<Id>(), Date.today().addDays(1)
            );
        Test.stopTest();

        System.assertEquals(
            0, results.size(),
            'Empty yacht ID list should return empty map'
        );
    }

    @IsTest
    static void testFetchAvailability_PastDate_ThrowsException() {
        List<Id> yachtIds = new List<Id>{
            [SELECT Id FROM Yacht__c LIMIT 1].Id
        };

        Test.startTest();
        try {
            YachtAvailabilityService.fetchAvailability(
                yachtIds, Date.today().addDays(-1)
            );
            System.assert(false, 'Should have thrown YachtException');
        } catch (YachtException ex) {
            System.assert(
                ex.getMessage().contains('today or in the future'),
                'Exception message should mention date requirement'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testFetchAvailability_NullDate_ThrowsException() {
        List<Id> yachtIds = new List<Id>{
            [SELECT Id FROM Yacht__c LIMIT 1].Id
        };

        Test.startTest();
        try {
            YachtAvailabilityService.fetchAvailability(yachtIds, null);
            System.assert(false, 'Should have thrown YachtException');
        } catch (YachtException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testFetchAvailability_WithProviderOverride() {
        List<Yacht__c> yachts = [SELECT Id FROM Yacht__c];
        List<Id> yachtIds = new List<Id>();
        for (Yacht__c y : yachts) {
            yachtIds.add(y.Id);
        }

        MockAvailabilityProvider mockProvider = new MockAvailabilityProvider();
        mockProvider.availabilityOverrides.put(yachtIds[0], false);
        mockProvider.priceOverrides.put(yachtIds[0], 999.99);

        YachtAvailabilityService.providerOverride = mockProvider;

        Date searchDate = Date.today().addDays(5);

        Test.startTest();
        Map<Id, YachtAvailabilityService.AvailabilityResult> results =
            YachtAvailabilityService.fetchAvailability(yachtIds, searchDate);
        Test.stopTest();

        System.assertEquals(
            false, results.get(yachtIds[0]).isAvailable,
            'Overridden yacht should be unavailable'
        );
        System.assertEquals(
            999.99, results.get(yachtIds[0]).price,
            'Overridden price should be 999.99'
        );
    }
}