
# Topic Coverage – Prescriptions Module (Patient)

## Models

| File | Class | Description |
|---|---|---|
| `lib/models/prescription.dart` | `Prescription` | Represents a prescribed medicine, including its name, strength, form, instruction, duration, start date, prescriber, doctor phone, prescribed date, optional refill and last-refill dates, and the doctor's notes. The doctor's phone is optional. Works out the last day of the course and whether the prescription is still active or a refill is available on a given date. |
| `lib/models/refill_request.dart` | `RefillRequest` | Represents a patient's request for a refill, including the prescription it belongs to, when it was sent, and its status. |
| `lib/models/refill_request.dart` | `RefillStatus` / `RefillStatusX` | Defines the refill statuses Pending, Approved, and Declined, including their display labels. |
| `lib/models/reminder_setting.dart` | `ReminderSetting` / `ReminderMode` | Represents a saved medicine reminder (every 8 hours or a custom daily time) with its start date and notification switch. Provides the summary text for the confirmation message and converts the reminder to and from JSON for saving. |
| `lib/models/taken_history.dart` | `TakenHistory` | Holds the days on which a prescription was marked as taken, with the number of days and the most recent days. |

## Service

| File | Class | Description |
|---|---|---|
| `lib/services/prescription_mapper.dart` | `prescriptionFromData` / `doctorPrescriptionFromData` / `doctorPrescriptionToData` / `refillRequestFromData` | Converts Firestore documents into the patient and doctor prescription models, and a doctor's new prescription into a document. Plain functions with no Firebase calls, so they can be unit tested. |
| `lib/services/prescription_service.dart` | `PrescriptionService` | The single place all Prescriptions screens use, backed by Firestore. Loads the patient's prescriptions, records taken doses, creates refill requests, saves reminders, and loads the taken-dose history. For the doctor side it reads and adds prescriptions, loads the patient's refill requests and taken doses, and records the doctor's answer to a refill request. Also provides today's medicines for the Home checklist. |
| `lib/services/prescription_service.dart` | `PrescriptionException` | Handles errors when prescription data cannot be loaded or when an action such as a refill request fails. |
| `lib/services/drug_info_service.dart` | `DrugInfoService` / `DrugInfo` / `DrugInfoException` / `drugInfoFromLabel` | Looks up a medicine's uses and warnings from the openFDA drug label service (using the `http` package), keeps results for a short time so the same medicine is not requested twice, and reports a friendly error when the service cannot be reached. The label-reading function has no network calls, so it can be unit tested. |
| `lib/services/prescription_service.dart` | `PrescriptionActivity` | Groups what has happened with one prescription: whether it was taken today and whether a refill request exists. |

## Shared widgets

| File | Class | Description |
|---|---|---|
| `lib/widgets/active_history_toggle.dart` | `ActiveHistoryToggle` | Provides the Active / History switch shown above the prescription list. |
| `lib/widgets/prescription_info_card.dart` | `PrescriptionInfoCard` | Provides the shared card layout (icon box plus content) used on the prescription detail screens. |
| `lib/widgets/refill_status_chip.dart` | `RefillStatusChip` | Displays consistent Pending, Approved, and Declined refill labels with an icon and text. |
| `lib/widgets/taken_history_card.dart` | `TakenHistoryCard` | Displays how many days a medicine was taken and the most recent days. |
| `lib/widgets/refill_request_card.dart` | `RefillRequestCard` | Shows a patient's refill request to the doctor, with Approve and Decline buttons while it is pending. |
| `lib/widgets/drug_info_card.dart` | `DrugInfoCard` | Shows the FDA reference text (uses and warnings) for a medicine, with loading, not-found, and error states. |

## Patient screens

| File | Class | Description |
|---|---|---|
| `lib/screens/patient/prescriptions/prescriptions_screen.dart` | `PrescriptionsScreen` | Displays the patient's prescriptions, supports Active and History tabs, opens the matching details screen, and handles loading, empty, and error states with pull-to-refresh. |
| `lib/screens/patient/prescriptions/prescriptions_screen.dart` | `_PrescriptionCard` | Displays one prescription's name, instruction, and refill or prescribed date. |
| `lib/screens/patient/prescriptions/prescription_details_screen.dart` | `PrescriptionDetailsScreen` | Displays an active prescription with the doctor's notes, prescriber, and refill information. Allows the patient to mark a dose as taken (with undo), open the reminder screen, and request a refill. |
| `lib/screens/patient/prescriptions/set_reminder_screen.dart` | `SetReminderScreen` | Allows the patient to choose an every-8-hours or custom-time reminder, pick a start date, turn notifications on or off, and save with a confirmation message. Includes a demo preview of the reminder pop-up. |
| `lib/screens/patient/prescriptions/prescription_history_details_screen.dart` | `PrescriptionHistoryDetailsScreen` | Displays a finished prescription in read-only form, including the last refill, the doctor's notes, and the doses-taken history. |

## Integration in shared files

| File | Class | Description |
|---|---|---|
| `lib/screens/patient/patient_shell.dart` | `PatientShell` | Integrates the Patient Prescriptions screen into the patient's navigation tabs. |

## Tests

| File | Description |
|---|---|
| `test/prescription_test.dart` | Checks the prescription title, the active and finished rules, the last day of the course, and when a refill becomes available. |
| `test/reminder_setting_test.dart` | Checks the reminder summary text and that a reminder survives being saved and loaded as JSON. |
| `test/taken_history_test.dart` | Checks the taken-day count and the most-recent-days helper. |
| `test/prescription_mapper_test.dart` | Checks that Firestore documents become the right patient and doctor models, that a prescription survives being written and read back, and how refill statuses are read. |
| `test/drug_info_test.dart` | Checks that a drug label becomes the right uses and warnings text, and that labels with no useful text are ignored. |
