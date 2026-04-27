/**
 * Author          : Mansoor Ahmad
 * Description     : Test class for YachtSearchController.
 *
 */
@IsTest
private class YachtSearchControllerTest {

    @TestSetup
    static void setupData() {
        List<Yacht_Type__c> lstYachtTypeInsert = new List<Yacht_Type__c>();
        Yacht_Type__c yachtType = new Yacht_Type__c(
            Name             = 'Catamaran',
            Is_Active__c     = true,
            Display_Order__c = 1
        );

        lstYachtTypeInsert.add(yachtType);
        insert lstYachtTypeInsert;

        List<Yacht__c> lstYachtsInsert = new List<Yacht__c>();
        Yacht__c testCatamaran  = new Yacht__c(
            Name                  = 'Test Catamaran',
            Yacht_Type__c         = yachtType.Id,
            Capacity__c           = 12,
            Minimum_Party_Size__c = 2,
            Headline__c           = 'Spacious catamaran',
            Image_URL__c          = 'https://example.com/cat.jpg',
            Is_Active__c          = true,
            External_Yacht_ID__c  = 'EXT-CAT-001'
        );

        lstYachtsInsert.add(testCatamaran);
        insert lstYachtsInsert;
    }

    @IsTest
    static void testGetYachtTypesReturnsActiveTypes() {
        Test.startTest();
        List<Yacht_Type__c> types = YachtSearchController.getYachtTypes();
        Test.stopTest();

        System.assertEquals(1, types.size(),'Should return 1 active yacht type');
        System.assertEquals('Catamaran', types[0].Name);
    }

    @IsTest
    static void testSearchYachtsValidInputReturnsResults() {
        String searchDate = String.valueOf(Date.today().addDays(7));

        Test.startTest();
        YachtSearchResultWrapper result = YachtSearchController.searchYachts(null, searchDate, 2, 0);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.totalCount, 'Should find 1 yacht');
    }

    @IsTest
    static void testSearchYachtsWithTypeFilter() {
        Yacht_Type__c yachtType = [SELECT Id FROM Yacht_Type__c WHERE Name = 'Catamaran' LIMIT 1];
        String searchDate = String.valueOf(Date.today().addDays(7));

        Test.startTest();
        YachtSearchResultWrapper result = YachtSearchController.searchYachts(yachtType.Id, searchDate, 2, 0);
        Test.stopTest();

        System.assertEquals(1, result.totalCount);
    }

    @IsTest
    static void testSearchYachts_InvalidDate_ThrowsAuraHandled() {
        Test.startTest();
        try {
            YachtSearchController.searchYachts( null, String.valueOf(Date.today().addDays(-1)), 2, 0
            );

            System.assert(false, 'Should have thrown AuraHandledException');
        
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        
        Test.stopTest();
    }

    @IsTest
    static void testReserveYacht_Success() {
        Yacht__c yacht = [SELECT Id FROM Yacht__c LIMIT 1];

        MockReservationProvider mockProvider = new MockReservationProvider();
        YachtReservationService.providerOverride = mockProvider;

        YachtReservationService.ReservationRequest req = new YachtReservationService.ReservationRequest();
        req.yachtId         = yacht.Id;
        req.reservationDate = Date.today().addDays(10);
        req.partySize       = 4;
        req.guestName       = 'Test Guest';
        req.guestEmail      = 'guest@test.com';
        req.totalPrice      = 600.00;

        Test.startTest();
        YachtReservationService.ReservationResult result = YachtSearchController.reserveYacht(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertNotEquals(null, result.confirmationNumber);
    }

    @IsTest
    static void testReserveYacht_InvalidJson_ThrowsAuraHandled() {
        Test.startTest();
        
        try {
            YachtSearchController.reserveYacht('not-valid-json');
            System.assert(false, 'Should have thrown AuraHandledException');
        
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        
        Test.stopTest();
    }

    @IsTest
    static void testReserveYacht_PartySizeExceedsCapacity_ReturnsError() {
        Yacht__c yacht = [SELECT Id FROM Yacht__c LIMIT 1];
        // Yacht capacity is 12, max party size CMT is 20
        // Use 15 — above yacht capacity but below CMT max
        MockReservationProvider mockProvider = new MockReservationProvider();
        YachtReservationService.providerOverride = mockProvider;

        YachtReservationService.ReservationRequest req = new YachtReservationService.ReservationRequest();
        req.yachtId         = yacht.Id;
        req.reservationDate = Date.today().addDays(10);
        req.partySize       = 15;
        req.guestName       = 'Test Guest';
        req.guestEmail      = 'guest@test.com';
        req.totalPrice      = 600.00;

        Test.startTest();
        YachtReservationService.ReservationResult result = YachtSearchController.reserveYacht(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert( result.errorMessage.contains('capacity'), 'Error should mention capacity. Actual: ' + result.errorMessage);
    }
}