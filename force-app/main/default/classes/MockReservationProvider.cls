/**
 * Author          : Mansoor Ahmad
 * Description     : Mock implementation of IReservationProvider.
 *                   Returns controlled reservation results without HTTP callouts.
 *                   Used when Yacht_Integration_Settings__mdt.Use_Mock_Provider__c
 *                   is true or when injected directly in test classes.
 *
 */
public class MockReservationProvider implements IReservationProvider {

    // Configurable for tests — simulate success or failure
    @TestVisible
    private Boolean shouldFail = false;

    @TestVisible
    private String failureMessage = 'Mock reservation failure';

    /**
     * @description Returns a mock confirmed reservation or simulated failure.
     */
    public YachtReservationService.ReservationResult submitReservation(YachtReservationService.ReservationRequest request) {
        if (shouldFail) {
            return new YachtReservationService.ReservationResult(failureMessage);
        }

        String confirmationNumber = 'CNF-' + String.valueOf(DateTime.now().getTime()).right(8);

        String externalRefId = 'EXT-' + request.yachtId + '-' + String.valueOf(request.reservationDate).replace('-', '');

        return new YachtReservationService.ReservationResult(
            true,
            confirmationNumber,
            externalRefId
        );
    }
}