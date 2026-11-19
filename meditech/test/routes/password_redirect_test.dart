import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/routes/password_redirect.dart';

void main() {
  const staff = SignedInAccount(
    accountType: 'staff',
    state: 'active',
    mustChangePassword: true,
  );

  // A temporary password opens the change-password page
  test('temporary password leaves the sign-in page', () {
    expect(redirectForPasswordChange(staff, '/'), '/change-password');
  });

  // After the password is saved, the change page is left
  test('a finished password change leaves that page', () {
    const done = SignedInAccount(
      accountType: 'staff',
      state: 'active',
      mustChangePassword: false,
    );
    expect(redirectForPasswordChange(done, '/change-password'), '/');
  });

  // Waiting owners only see the application status page
  test('waiting owner goes to application status', () {
    const waiting = SignedInAccount(
      accountType: 'staff',
      state: 'pending_approval',
      role: 'owner',
    );
    expect(redirectForPharmacySession(waiting, '/'), '/application-status');
    expect(redirectForPharmacySession(waiting, '/activity-log'), '/application-status');
    expect(redirectForPharmacySession(waiting, '/application-status'), null);
    expect(redirectForPharmacySession(waiting, '/register'), null);
  });

  // Rejected owners can open status or resubmit registration
  test('rejected owner stays on status or register', () {
    const rejected = SignedInAccount(
      accountType: 'staff',
      state: 'rejected',
      role: 'owner',
    );
    expect(redirectForPharmacySession(rejected, '/notifications'), '/application-status');
    expect(redirectForPharmacySession(rejected, '/register'), null);
  });

  // Suspended owners only see the suspended page
  test('suspended owner goes to the suspended page', () {
    const suspended = SignedInAccount(
      accountType: 'staff',
      state: 'suspended',
      role: 'owner',
    );
    expect(redirectForPharmacySession(suspended, '/'), '/suspended');
    expect(redirectForPharmacySession(suspended, '/suspended'), null);
  });

  // Guests cannot open status pages directly
  test('signed-out users leave status pages', () {
    expect(redirectForPharmacySession(null, '/application-status'), '/');
    expect(redirectForPharmacySession(null, '/suspended'), '/');
    expect(redirectForPharmacySession(null, '/'), null);
  });
}
