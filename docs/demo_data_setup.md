# Demo data setup (before the presentation)

Goal: every screen has realistic data, so the live demo never shows an empty
account by accident. All names are fictional (sample data only, RA 10173).
Doing it through the app (steps 2 to 6) is also a full rehearsal of the demo.

Time needed: about 30 minutes. Use Chrome, port 5000:
`flutter run -d chrome --web-port=5000 --dart-define-from-file=firebase_config.json`

Tip: keep the patient in a normal Chrome window and the doctor in an
Incognito window, so both stay signed in.

---

## 1. Doctors (Firebase console, once)

Booking now reads each doctor's details from their `users/{uid}` document
(nothing is written in the code any more). Open **Firestore Database > Data >
users**, open each doctor document below and **Add field** (types in brackets):

| Document ID (uid) | fullName (string) | specialty (string) | consultationType (string) | consultationFee (number) |
|---|---|---|---|---|
| `CHFpIARAwchObyj36q8eiOvsp2G3` | Dr. Elena Cruz | General Practitioner | Clinic Visit | 500 |
| `OxrNwBrh3rTv7AuWNh5my5jvdC53` | Dr. Miguel Reyes | Pediatrician | Video Consultation | 650 |
| `hVpQuMpcSQPHBbP3nRfkBCCiYU32` | Dr. Andrea Santos | Internal Medicine | Clinic Visit | 700 |
| `UkGPnVq37fZP5SLQDXKqhECxr582` | Dr. Rafael Mendoza | General Practitioner | Video Consultation | 500 |
| `4M3lq0ZJ3JdcPw4oSnqulawLobG3` | Dr. Sofia Villanueva | Pediatrician | Clinic Visit | 650 |

Check that `role` is `doctor` (lowercase) on each. Keep `fullName` if it is
already there. A new doctor: Authentication > Add user, then a `users`
document whose ID is the new UID with `fullName`, `email`, `role: doctor` and
the fields above.

Write down the email and password of **Dr. Andrea Santos**: she is the doctor
used in the demo below. (Reset the password from Authentication > ⋮ if needed.)

## 2. Patients (in the app)

Log out, tap **Register**, and create two patients (any password you will remember):

| Full name | Email |
|---|---|
| Maria Dela Cruz | `maria.demo@health360.test` |
| Paolo Ramirez | `paolo.demo@health360.test` |

As **Maria**: Profile > Personal Information > Edit, fill in mobile
`09171234567`, birth date, gender and address, and Save (this is now saved in
Firestore).

## 3. Appointments (as the patients)

As **Maria** (Appointment tab > Book):
1. Dr. Andrea Santos, **tomorrow 10:00 AM**, Clinic Visit, reminder on.
2. Dr. Miguel Reyes, **in 3 days, 2:00 PM**, Video Consultation.

As **Paolo**: Dr. Andrea Santos, **tomorrow 1:30 PM**, Clinic Visit.

(Times must be Monday to Saturday, 8:00 AM to 4:30 PM.)

## 4. Doctor side (as Dr. Andrea Santos)

1. **Appointments**: Confirm Maria's appointment. Leave Paolo's as Pending (shows the Pending label).
2. **Patients > Maria Dela Cruz > Edit Patient Info**: age 34, Female, condition
   `Hypertension`, allergies `Penicillin`, immunizations `Influenza (2025)`,
   history `Hypertension (2019)`. Save.
3. **Add Consultation Notes**: Internal Medicine, today, assessment
   `Elevated blood pressure, no chest pain`, treatment
   `Low-salt diet, walk 30 minutes a day, recheck in 2 weeks`.
4. **View Full Record > Prescriptions > Add Prescription** (two):
   - Amlodipine 5mg, **Once a day**, **30 days**, start **today**, note `Take in the morning` (active: used for Mark as Taken and reminders).
   - Cetirizine 10mg, **Once a day**, **5 days**, start **3 days ago** (its refill opens today, 2 days before the course ends).
5. **Lab Results > Add Lab Result**:
   - Complete Blood Count: Hemoglobin `11.2` (shows **Low**), Hematocrit `38`, WBC `7.5`, Platelets `250`; overall `Mild anemia`.
   - Lipid Profile: Total `210` (**High**), LDL `135` (**High**), HDL `45`, Triglycerides `140`; overall `High cholesterol`, notes `Repeat in 3 months`.

## 5. Patient actions (as Maria)

1. **Home**: tap Heart Rate and Blood Pressure and add a reading each (e.g. 78 bpm, 135/88).
2. **Prescription**: open Amlodipine, **Mark as Taken**; **Set a Reminder** > Custom Time **2 to 3 minutes from now** (to show the popup in the demo, set it again just before presenting).
3. Open Cetirizine > **Request Refill**.
4. **Records**: the consultation notes and both lab results are there.

## 6. Answer the refill (as Dr. Andrea Santos)

Notifications (Profile) and Recent Activity show the refill request. Open
Patients > Maria > View Full Record > Prescriptions and **Approve** it.

## 7. One past appointment (Firebase console)

The app only books future times, so to show **Done / No-show** make one
appointment "past": Firestore > `appointments` > Paolo's appointment >
`dateTime` > change it to **yesterday 1:30 PM** and `status` to `confirmed`.
As the doctor, open Appointments and mark it **Done**.

---

## Before you present

- Log in once as each account (patient, doctor) on the demo computer.
- Set Maria's reminder for a time during your demo slot.
- The demo switch (long-press the avatar on Home) is back on **Normal**.
- AI screen ⋮ > *Simulate AI outage* is **off**.
- Record the backup video after this setup, following the same order.
