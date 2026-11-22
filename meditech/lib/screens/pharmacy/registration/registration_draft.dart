import 'package:flutter/material.dart';

import '../../../models/pharmacy_application.dart';

// Opening hours for one day while the form is being filled in
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
  // True when fixing a rejected application instead of registering
  bool editing = false;

  // Step 1: pharmacy
  final pharmacyName = TextEditingController();
  final branchName = TextEditingController();
  final address = TextEditingController();
  final contactNumber = TextEditingController();
  final pharmacyEmail = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  String? claimedOsmListingId;

  // Hours for each day (0 = Sunday); every day starts open
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
      double.tryParse(latitude.text) != null && double.tryParse(longitude.text) != null;

  // Opening hours for all 7 days, in the shape the server expects
  List<DayHours> get hours => [
        for (var day = 0; day < 7; day++)
          days[day].isOpen
              ? DayHours(weekday: day, opensAt: _time(days[day].opensAt), closesAt: _time(days[day].closesAt))
              : DayHours(weekday: day, isClosed: true),
      ];

  // Time as "08:00"
  static String _time(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // "08:00:00" → 8:00 AM
  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // Fill the form from a rejected application
  void fillFrom(Map<String, dynamic> j) {
    pharmacyName.text = j['pharmacy_name'] as String? ?? '';
    branchName.text = j['branch_name'] as String? ?? '';
    address.text = j['address'] as String? ?? '';
    contactNumber.text = j['contact_number'] as String? ?? '';
    pharmacyEmail.text = j['pharmacy_email'] as String? ?? '';
    latitude.text = (j['latitude'] as num).toStringAsFixed(6);
    longitude.text = (j['longitude'] as num).toStringAsFixed(6);
    ltoNumber.text = j['lto_number'] as String? ?? '';
    ltoExpiry = DateTime.parse(j['lto_expiry'] as String);
    firstName.text = j['first_name'] as String? ?? '';
    middleName.text = j['middle_name'] as String? ?? '';
    lastName.text = j['last_name'] as String? ?? '';
    mobile.text = j['mobile'] as String? ?? '';

    // Opening hours, day by day
    for (final h in (j['hours'] as List).cast<Map<String, dynamic>>()) {
      final day = days[h['weekday'] as int];
      day.isOpen = !(h['is_closed'] as bool? ?? false);
      if (h['opens_at'] != null) day.opensAt = _parseTime(h['opens_at'] as String);
      if (h['closes_at'] != null) day.closesAt = _parseTime(h['closes_at'] as String);
    }
  }

  // The edited details to send (files and sign-in details are handled separately)
  Map<String, dynamic> toResubmitJson() => {
        'pharmacy_name': pharmacyName.text.trim(),
        'branch_name': branchName.text.trim(),
        'address': address.text.trim(),
        'contact_number': contactNumber.text.trim(),
        'pharmacy_email': pharmacyEmail.text.trim(),
        'latitude': double.parse(latitude.text),
        'longitude': double.parse(longitude.text),
        'hours': hours.map((h) => h.toJson()).toList(),
        'lto_number': ltoNumber.text.trim(),
        'lto_expiry': ltoExpiry!.toIso8601String().substring(0, 10),
        'first_name': firstName.text.trim(),
        'middle_name': middleName.text.trim(),
        'last_name': lastName.text.trim(),
        'mobile': mobile.text.trim(),
      };

  // Turn the draft into a new application to send
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
      pharmacyName, branchName, address, contactNumber, pharmacyEmail, latitude, longitude,
      ltoNumber, firstName, middleName, lastName, mobile, email, username, password, confirmPassword,
    ]) {
      c.dispose();
    }
  }
}