import 'package:flutter/material.dart';

import '../../../models/pharmacy_application.dart';

class DayHoursDraft {
  DayHoursDraft({
    required this.isOpen,
    this.opensAt = const TimeOfDay(hour: 8, minute: 0),
    this.closesAt = const TimeOfDay(hour: 20, minute: 0),
  });

  bool isOpen;
  TimeOfDay opensAt;
  TimeOfDay closesAt;
}

// Everything typed into the registration form, kept while moving between steps
class RegistrationDraft {
  // Step 1: pharmacy
  final pharmacyName = TextEditingController();
  final branchName = TextEditingController();
  final address = TextEditingController();
  final contactNumber = TextEditingController();
  final pharmacyEmail = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  // Hours for each day (0 = Sunday); all days start open and can be changed.
  final days = List.generate(7, (_) => DayHoursDraft(isOpen: true));

  // When true, every open day uses the same hours
  bool sameHours = false;

  // Step 2: license
  final ltoNumber = TextEditingController();
  DateTime? ltoExpiry;
  PickedDocument? ltoFile;
  PickedDocument? storefrontFile;

  // Step 3: owner account
  final firstName = TextEditingController();
  final middleName = TextEditingController();
  final lastName = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  // Step 4: review
  bool agreed = false;

  // Has a map pin been set?
  bool get hasLocation =>
      double.tryParse(latitude.text) != null &&
      double.tryParse(longitude.text) != null;

  // Opening hours for all 7 days, in the shape the server expects
  List<DayHours> get hours => [
    for (var day = 0; day < 7; day++)
      days[day].isOpen
          ? DayHours(
              weekday: day,
              opensAt: _time(days[day].opensAt),
              closesAt: _time(days[day].closesAt),
            )
          : DayHours(weekday: day, isClosed: true),
  ];

  // Time as "08:00"
  static String _time(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Turn the draft into an application to send
  PharmacyApplication toApplication() => PharmacyApplication(
    pharmacyName: pharmacyName.text,
    branchName: branchName.text,
    address: address.text,
    contactNumber: contactNumber.text,
    pharmacyEmail: pharmacyEmail.text,
    latitude: double.parse(latitude.text),
    longitude: double.parse(longitude.text),
    hours: hours,
    ltoNumber: ltoNumber.text,
    ltoExpiry: ltoExpiry!,
    ltoFile: ltoFile!,
    storefrontFile: storefrontFile!,
    firstName: firstName.text,
    middleName: middleName.text.trim().isEmpty ? null : middleName.text,
    lastName: lastName.text,
    mobile: mobile.text,
    email: email.text,
    username: username.text,
    password: password.text,
  );

  // Free the text boxes when the screen closes
  void dispose() {
    for (final c in [
      pharmacyName,
      branchName,
      address,
      contactNumber,
      pharmacyEmail,
      latitude,
      longitude,
      ltoNumber,
      firstName,
      middleName,
      lastName,
      mobile,
      email,
      username,
      password,
      confirmPassword,
    ]) {
      c.dispose();
    }
  }
}
