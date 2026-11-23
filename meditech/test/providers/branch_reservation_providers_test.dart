import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/providers/branch_reservation_providers.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/services/branch_reservation_service.dart';

const _staffSession = SignedInAccount(
  accountType: 'staff',
  state: 'active',
  role: 'pharmacist',
  branchId: 'demo-branch',
);

void main() {
  group('BranchReservation providers and fake service', () {
    test('fetches demo reservations matching wireframe count', () async {
      final fakeService = FakeBranchReservationService();
      final container = ProviderContainer(
        overrides: [
          branchReservationServiceProvider.overrideWithValue(fakeService),
          sessionProvider.overrideWith(() => _FakeSession(_staffSession)),
        ],
      );
      addTearDown(container.dispose);

      final reservations =
          await container.read(branchReservationsProvider.future);
      expect(reservations.length, 10);
      expect(reservations.first.referenceNo, 'RM-103026-0005');
      expect(reservations.first.customerName, 'Grace Villanueva');
      expect(reservations.first.hasRx, isTrue);
    });

    test('confirm updates reservation state in provider', () async {
      final fakeService = FakeBranchReservationService();
      final container = ProviderContainer(
        overrides: [
          branchReservationServiceProvider.overrideWithValue(fakeService),
          sessionProvider.overrideWith(() => _FakeSession(_staffSession)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(branchReservationsProvider.notifier);
      await notifier.confirm('res-1');

      final updated =
          await container.read(branchReservationsProvider.future);
      final res1 = updated.firstWhere((r) => r.id == 'res-1');
      expect(res1.status, 'confirmed');
      expect(res1.isConfirmed, isTrue);
    });

    test('reject updates reservation with reason', () async {
      final fakeService = FakeBranchReservationService();
      final container = ProviderContainer(
        overrides: [
          branchReservationServiceProvider.overrideWithValue(fakeService),
          sessionProvider.overrideWith(() => _FakeSession(_staffSession)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(branchReservationsProvider.notifier);
      await notifier.reject('res-2', 'Prescription was not legible.');

      final updated =
          await container.read(branchReservationsProvider.future);
      final res2 = updated.firstWhere((r) => r.id == 'res-2');
      expect(res2.status, 'rejected');
      expect(res2.closedReason, 'Prescription was not legible.');
    });

    test('verifies pickup code and completes reservation', () async {
      final fakeService = FakeBranchReservationService();
      final container = ProviderContainer(
        overrides: [
          branchReservationServiceProvider.overrideWithValue(fakeService),
          sessionProvider.overrideWith(() => _FakeSession(_staffSession)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(branchReservationsProvider.notifier);

      // Verify wrong code
      final wrongCheck = await notifier.checkCode('res-5', 'WRONG');
      expect(wrongCheck, isFalse);

      // Verify correct code ('K7M4')
      final rightCheck = await notifier.checkCode('res-5', 'K7M4');
      expect(rightCheck, isTrue);

      // Complete reservation
      await notifier.complete('res-5', 'K7M4');
      final updated =
          await container.read(branchReservationsProvider.future);
      final res5 = updated.firstWhere((r) => r.id == 'res-5');
      expect(res5.status, 'completed');
    });
  });
}

class _FakeSession extends SessionNotifier {
  _FakeSession(this._account);

  final SignedInAccount _account;

  @override
  SignedInAccount? build() => _account;
}
