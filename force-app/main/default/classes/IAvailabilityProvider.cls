/**
 * Author          : Mansoor Ahmad
 * Created         : Apr 26, 2026
 * Description     : Interface for availability provider implementations.
 *                   Allows swapping between real external callout and mock.
 *                   Active provider controlled via Yacht_Integration_Settings__mdt
 *
 * Change History  :
 *  Date           │ Author          │ Change
 * ─────────────────────────────────────────────────────────────────────────────
 *  Apr 26, 2026   │ Mansoor Ahmad   │ Initial version
 * ─────────────────────────────────────────────────────────────────────────────
 */
public interface IAvailabilityProvider {

    /**
     * @param yachtIds   List of Yacht__c IDs to check
     * @param searchDate Date to check availability for
     * @return           Map of Yacht ID to AvailabilityResult
     */
    Map<Id, YachtAvailabilityService.AvailabilityResult> getAvailability(
        List<Id> yachtIds,
        Date searchDate
    );
}