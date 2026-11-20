# Topic Coverage – Appointments Module

| File | Class | Description |
|---|---|---|
| `lib/models/appointment.dart` | `Appointment` | Represents an appointment, including its ID, title, doctor, specialty, date and time, location, consultation type, and status. |
| `lib/models/appointment_status.dart` | `AppointmentStatus` / `AppointmentStatusX` | Defines appointment statuses: Confirmed, Pending, and Cancelled, including their display labels. |
| `lib/services/appointment_service.dart` | `AppointmentService` | Retrieves mock appointment data, simulates loading, and supports normal, empty, and error scenarios. |
| `lib/services/appointment_service.dart` | `AppointmentException` | Handles errors when appointment data cannot be loaded. |
| `lib/screens/patient/appointments/appointments_screen.dart` | `AppointmentsScreen` | Displays the patient's appointments, supports Upcoming and Past filters, and handles loading, empty, and error states. |
| `lib/screens/patient/appointments/appointments_screen.dart` | `_AppointmentCard` | Displays an individual appointment's information and status. |
| `lib/screens/patient/appointments/appointments_screen.dart` | `_AppointmentInfoRow` | Displays appointment details with an icon and text. |
| `lib/widgets/appointment_status_chip.dart` | `AppointmentStatusChip` | Displays consistent Confirmed, Pending, and Cancelled status labels. |
| `lib/models/doctor.dart` | `Doctor` | Represents a doctor available for appointment booking, including name, specialty, category, next available schedule, consultation type, and consultation fee. |
| `lib/services/booking_doctor_service.dart` | `BookingDoctorService` | Retrieves mock doctors, simulates loading, and supports normal, empty, and error scenarios for the booking flow. |
| `lib/services/booking_doctor_service.dart` | `DoctorBookingException` | Handles errors when doctor information cannot be loaded. |
| `lib/screens/patient/appointments/booking/doctor_selection_screen.dart` | `DoctorSelectionScreen` | Displays available doctors and allows patients to search, filter by specialty, select a doctor, and continue the booking process. |
| `lib/screens/patient/patient_shell.dart` | `PatientShell` | Integrates the Patient Appointments Overview and navigates to the doctor selection screen when the patient chooses to book an appointment. |