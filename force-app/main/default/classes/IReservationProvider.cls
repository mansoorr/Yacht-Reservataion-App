/**
 * Author          : Mansoor Ahmad
 * Description     : Interface for reservation provider implementations.
 *                   Allows swapping between real external callout and mock.
 *                   Active provider controlled via Yacht_Integration_Settings__mdt
 *
 */
public interface IReservationProvider {

    /**
     * @param request Reservation request wrapper containing all booking details
     * @return        ReservationResult with confirmation or error details
     */
    YachtReservationService.ReservationResult submitReservation(YachtReservationService.ReservationRequest request);
}