
# Topic Coverage – Appointments Module

| File | Class | Description |
|---|---|---|
| `lib/models/appointment.dart` | `Appointment` | Represents an appointment, including its ID, patient information, doctor, specialty, date and time, location, consultation type, status, consultation fee, reminder setting, and optional Google Meet URL. |
| `lib/models/appointment_status.dart` | `AppointmentStatus` / `AppointmentStatusX` | Defines appointment statuses: Confirmed, Pending, and Cancelled, including their display labels. |
| `lib/services/appointment_service.dart` | `AppointmentService` | Provides shared mock appointment data for the patient and doctor sides, simulates loading and management actions, supports normal, empty, and error scenarios, creates appointments, confirms or cancels appointments, and updates Google Meet URLs. |
| `lib/services/appointment_service.dart` | `AppointmentException` | Handles errors when appointment data cannot be loaded or when appointment management actions fail. |
| `lib/screens/patient/appointments/appointments_screen.dart` | `AppointmentsScreen` | Displays the patient's appointments, supports Upcoming and Past filters, and handles loading, empty, and error states. |
| `lib/screens/patient/appointments/appointments_screen.dart` | `_AppointmentCard` | Displays an individual appointment's information and status. |
| `lib/screens/patient/appointments/appointments_screen.dart` | `_AppointmentInfoRow` | Displays appointment details with an icon and text. |
| `lib/widgets/appointment_status_chip.dart` | `AppointmentStatusChip` | Displays consistent Confirmed, Pending, and Cancelled status labels. |
| `lib/models/doctor.dart` | `Doctor` | Represents a doctor available for appointment booking, including name, specialty, category, next available schedule, consultation type, and consultation fee. |
| `lib/services/booking_doctor_service.dart` | `BookingDoctorService` | Retrieves mock doctors, simulates loading, and supports normal, empty, and error scenarios for the booking flow. |
| `lib/services/booking_doctor_service.dart` | `DoctorBookingException` | Handles errors when doctor information cannot be loaded. |
| `lib/screens/patient/appointments/booking/doctor_selection_screen.dart` | `DoctorSelectionScreen` | Displays available doctors and allows patients to search, filter by specialty, select a doctor, and continue the booking process. |
| `lib/screens/patient/appointments/booking/date_time_selection_screen.dart` | `DateTimeSelectionScreen` | Allows patients to select their preferred appointment date and time. |
| `lib/screens/patient/appointments/booking/appointment_details_screen.dart` | `AppointmentDetailsScreen` | Allows patients to choose between in-person and video consultation, review the consultation fee, and enable a one-day-before reminder. |
| `lib/screens/patient/appointments/booking/appointment_confirmation_screen.dart` | `AppointmentConfirmationScreen` | Processes appointment booking, displays loading and error states, and shows the booking confirmation details. |
| `lib/screens/patient/appointments/video_consultation_screen.dart` | `VideoConsultationScreen` | Displays video consultation details, Google Meet joining instructions, the meeting link when available, and clinic contact information. |
| `lib/screens/doctor/appointments/doctor_appointments_screen.dart` | `DoctorAppointmentsScreen` | Displays all appointments in the doctor-side management view, supports patient-name search and status filters, shows appointment details, and allows the doctor to confirm or cancel appointments and save Google Meet links for confirmed video consultations. |
| `lib/screens/doctor/appointments/doctor_appointments_screen.dart` | `_MeetingUrlDialog` | Provides a dialog for entering and validating a Google Meet URL before saving it to an appointment. |
| `lib/screens/patient/patient_shell.dart` | `PatientShell` | Integrates the Patient Appointments Overview and navigates to the doctor selection screen when the patient chooses to book an appointment. |
| `lib/screens/doctor/doctor_shell.dart` | `DoctorShell` | Integrates the Doctor Appointments Management screen into the doctor's navigation tabs. |
