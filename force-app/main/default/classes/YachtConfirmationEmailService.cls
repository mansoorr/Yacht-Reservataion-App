/**
 * Author          : Mansoor Ahmad
 * Created         : Apr 26, 2026
 * Description     : Sends branded confirmation email to guest after successful
 *                   yacht reservation. Called from YachtReservationService
 *                   after reservation record is created.
 *                   Uses Messaging.SingleEmailMessage — no template required.
 *
 * Change History  :
 *  Date           │ Author          │ Change
 * ─────────────────────────────────────────────────────────────────────────────
 *  Apr 26, 2026   │ Mansoor Ahmad   │ Initial version
 * ─────────────────────────────────────────────────────────────────────────────
 */
public with sharing class YachtConfirmationEmailService {

    /**
     * @description Sends a reservation confirmation email to the guest.
     * @param guestEmail        Guest email address
     * @param guestName         Guest full name
     * @param yachtName         Name of the reserved yacht
     * @param reservationDate   Date of reservation
     * @param partySize         Number of guests
     * @param confirmationNumber Confirmation reference number
     * @param totalPrice        Total price for the reservation
     */
    public static void sendConfirmation( String guestEmail, String guestName, String yachtName, Date reservationDate, Integer partySize, String confirmationNumber, Decimal totalPrice ) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

            email.setToAddresses(new List<String>{ guestEmail });
            email.setSubject('Your Yacht Reservation is Confirmed — ' + confirmationNumber);
            email.setHtmlBody(
                buildEmailBody(
                    guestName,
                    yachtName,
                    reservationDate,
                    partySize,
                    confirmationNumber,
                    totalPrice
                )
            );
            email.setSaveAsActivity(false);

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });

        } catch (Exception ex) {
            Logger.warn(
                'Confirmation email failed for ' + guestEmail
                + ': ' + ex.getMessage()
            );
            Logger.saveLog();
            // Do not rethrow — email failure should not fail the reservation
        }
    }

    // ─── Private ─────────────────────────────────────────────────────────────

    private static String buildEmailBody(String guestName, String yachtName, Date reservationDate, Integer partySize, String confirmationNumber, Decimal totalPrice) {
        String formattedPrice = totalPrice != null
            ? 'AED ' + totalPrice.format()
            : 'To be confirmed';

        return 'Dear ' + guestName + ',\n\n'
            + 'Your yacht reservation has been confirmed.\n\n'
            + 'RESERVATION DETAILS\n'
            + '-------------------\n'
            + 'Confirmation Number : ' + confirmationNumber + '\n'
            + 'Yacht               : ' + yachtName + '\n'
            + 'Date                : ' + reservationDate.format() + '\n'
            + 'Party Size          : ' + partySize + ' guests\n'
            + 'Total Price         : ' + formattedPrice + '\n\n'
            + 'We look forward to welcoming you aboard.\n\n'
            + 'Yacht Reservation Portal\n'
            + 'Dubai';
    }
}