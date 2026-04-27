/**
 * Author          : Mansoor Ahmad
 * Created         : Apr 26, 2026
 * Description     : Test class for YachtReservationService.
 *                   Covers successful reservation, failure handling,
 *                   idempotency, validation rules, and capacity checks.
 *
 * Change History  :
 *  Date           │ Author          │ Change
 * ─────────────────────────────────────────────────────────────────────────────
 *  Apr 26, 2026   │ Mansoor Ahmad   │ Initial version
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class YachtReservationServiceTest {

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        Yacht_Type__c yachtType = new Yacht_Type__c(
            Name         = 'Sailing Yacht',
            Is_Active__c = true
        );
        insert yachtType;

        insert new Yacht__c(
            Name                  = 'Test Sailing Yacht',
            Yacht_Type__c         = yachtType.Id,
            Capacity__c           = 8,
            Minimum_Party_Size__c = 2,
            Headline__c           = 'Beautiful sailing yacht',
            Image_URL__c          = 'https://example.com/sail.jpg',
            Is_Active__c          = true,
            External_Yacht_ID__c  = 'EXT-SAIL-001'
        );
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    private static YachtReservationService.ReservationRequest buildRequest(
        Id yachtId,
        Integer partySize,
        Date resDate
    ) {
        YachtReservationService.ReservationRequest req =
            new YachtReservationService.ReservationRequest();
        req.yachtId         = yachtId;
        req.reservationDate = resDate;
        req.partySize       = partySize;
        req.guestName       = 'Test Guest';
        req.guestEmail      = 'test@example.com';
        req.totalPrice      = 500.00;
        return req;
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    @IsTest
    static void testReserve_Success_CreatesRecord() {
        Yacht__c yacht = [SELECT Id FROM Yacht__c LIMIT 1];
        Date resDate   = Date.today().addDays(10);

        MockReservationProvider mockProvider = new MockReservationProvider();
        YachtReservationService.providerOverride = mockProvider;

        Test.startTest();
        YachtReservationService.ReservationResult result =
            YachtReservationService.reserve(buildRequest(yacht.Id, 4, resDate));
        Test.stopTest();

        System.assertEquals(
            true, result.success,
            'Reservation should succeed'
        );
        System.assertNotEquals(
            null, result.confirmationNumber,
            'Confirmation number should be populated'
        );

        List<Yacht_Reservation__c> saved = [
            SELECT Id, Status__c, Party_Size__c
            FROM Yacht_Reservation__c
            WHERE Yacht__c = :yacht.Id
        ];
        System.assertEquals(1, saved.size(), 'One reservation record should exist');
        System.assertEquals('Confirmed', saved[0].Status__c);
        System.assertEquals(4, (Integer)saved[0].Party_Size__c);
    }

    @IsTest
    static void testReserve_Failure_SavesFailedRecord() {
        Yacht__c yacht = [SELECT Id FROM Yacht__c LIMIT 1];
        Date resDate   = Date.today().addDays(10);

        MockReservationProvider mockProvider = new MockReservationProvider();
        mockProvider.shouldFail     = true;
        mockProvider.failureMessage = 'External system unavailable';
        YachtReservationService.providerOverride = mockProvider;

        Test.startTest();
        YachtReservationService.ReservationResult result =
            YachtReservationService.reserve(buildRequest(yacht.Id, 4, resDate));
        Test.stopTest();

        System.assertEquals(
            false, result.success,
            'Reservation should fail'
        );

        List<Yacht_Reservation__c> saved = [
            SELECT Id, Status__c
            FROM Yacht_Reservation__c
            WHERE Yacht__c = :yacht.Id
        ];
        System.assertEquals(1, saved.size(), 'Failed attempt should still be recorded');
        System.assertEquals('Failed', saved[0].Status__c);
    }

    @IsTest
    static void testReserve_Idempotency_BlocksDuplicate() {
        Yacht__c yacht = [SELECT Id FROM Yacht__c LIMIT 1];
        Date resDate   = Date.today().addDays(10);

        MockReservationProvider mockProvider = new MockReservationProvider();
        YachtReservationService.providerOverride = mockProvider;

        YachtReservationService.ReservationRequest req =
            buildRequest(yacht.Id, 4, resDate);

        Test.startTest();
        YachtReservationService.reserve(req);
        YachtReservationService.ReservationResult secondResult =
            YachtReservationService.reserve(req);
        Test.stopTest();

        System.assertEquals(
            false, secondResult.success,
            'Duplicate reservation should be blocked'
        );
        System.assert(
            secondResult.errorMessage.contains('already exists'),
            'Error message should mention duplicate'
        );
    }

    @IsTest
    static void testReserve_PartySizeExceedsCapacity() {
        Yacht__c yacht = [SELECT Id FROM Yacht__c LIMIT 1];
        // Yacht capacity is 8, max party size CMT is 20
        // Use 15 — above yacht capacity but below CMT max
        MockReservationProvider mockProvider = new MockReservationProvider();
        YachtReservationService.providerOverride = mockProvider;

        Test.startTest();
        YachtReservationService.ReservationResult result =
            YachtReservationService.reserve(
                buildRequest(yacht.Id, 15, Date.today().addDays(5))
            );
        Test.stopTest();

        System.assertEquals(
            false, result.success,
            'Should fail when party size exceeds yacht capacity'
        );
        System.assert(
            result.errorMessage.contains('capacity'),
            'Error should mention capacity. Actual: ' + result.errorMessage
        );
    }

    @IsTest
    static void testReserve_BelowMinPartySize() {
        Yacht__c yacht = [SELECT Id FROM Yacht__c LIMIT 1];

        MockReservationProvider mockProvider = new MockReservationProvider();
        YachtReservationService.providerOverride = mockProvider;

        Test.startTest();
        YachtReservationService.ReservationResult result =
            YachtReservationService.reserve(
                buildRequest(yacht.Id, 1, Date.today().addDays(5))
            );
        Test.stopTest();

        System.assertEquals(
            false, result.success,
            'Should fail when party size is below minimum'
        );
        System.assert(
            result.errorMessage.contains('Minimum party size'),
            'Error should mention minimum party size'
        );
    }

    @IsTest
    static void testReserve_ZeroPartySize_ThrowsValidation() {
        Yacht__c yacht = [SELECT Id FROM Yacht__c LIMIT 1];

        MockReservationProvider mockProvider = new MockReservationProvider();
        YachtReservationService.providerOverride = mockProvider;

        Test.startTest();
        YachtReservationService.ReservationResult result =
            YachtReservationService.reserve(
                buildRequest(yacht.Id, 0, Date.today().addDays(5))
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(
            result.errorMessage.contains('positive number'),
            'Error should mention positive number requirement'
        );
    }

    @IsTest
    static void testReserve_PastDate_ThrowsValidation() {
        Yacht__c yacht = [SELECT Id FROM Yacht__c LIMIT 1];

        MockReservationProvider mockProvider = new MockReservationProvider();
        YachtReservationService.providerOverride = mockProvider;

        Test.startTest();
        YachtReservationService.ReservationResult result =
            YachtReservationService.reserve(
                buildRequest(yacht.Id, 4, Date.today().addDays(-1))
            );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(
            result.errorMessage.contains('today or in the future'),
            'Error should mention date requirement'
        );
    }

    @IsTest
    static void testReserve_MarksAvailabilityUnavailable() {
        Yacht__c yacht = [SELECT Id FROM Yacht__c LIMIT 1];
        Date resDate   = Date.today().addDays(10);

        insert new Yacht_Availability__c(
            Yacht__c                    = yacht.Id,
            Available_Date__c           = resDate,
            Is_Available__c             = true,
            Price__c                    = 500,
            External_Availability_ID__c = 'EXT-AVAIL-TEST-001'
        );

        MockReservationProvider mockProvider = new MockReservationProvider();
        YachtReservationService.providerOverride = mockProvider;

        Test.startTest();
        YachtReservationService.reserve(buildRequest(yacht.Id, 4, resDate));
        Test.stopTest();

        Yacht_Availability__c avail = [
            SELECT Is_Available__c
            FROM Yacht_Availability__c
            WHERE Yacht__c = :yacht.Id
            AND Available_Date__c = :resDate
            LIMIT 1
        ];
        System.assertEquals(
            false, avail.Is_Available__c,
            'Availability should be marked false after reservation'
        );
    }
}