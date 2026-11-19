import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/branch_reservation.dart';

void main() {
  group('BranchReservation model', () {
    test('computes medicinesSummary for single and multiple items', () {
      final resSingle = BranchReservation(
        id: 'r1',
        referenceNo: 'RM-103026-0005',
        customerId: 'c1',
        customerName: 'Grace Villanueva',
        branchId: 'b1',
        status: 'pending',
        hasRx: true,
        totalAmount: 252.0,
        submittedAt: DateTime(2026, 10, 30),
        expiresAt: DateTime(2026, 11, 6),
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'm1',
            inventoryItemId: 'inv1',
            brandName: 'Amoxil',
            genericName: 'Amoxicillin',
            strength: '500 mg',
            dosageForm: 'Capsule',
            unitSold: 'capsule',
            isRx: true,
            unitPrice: 12.0,
            quantity: 21,
            heldQuantity: 0,
          ),
        ],
      );

      expect(resSingle.medicinesSummary, 'Amoxil × 21');

      final resMulti = resSingle.copyWith(
        items: [
          ...resSingle.items,
          const BranchReservationItem(
            lineNo: 2,
            medicineId: 'm2',
            inventoryItemId: 'inv2',
            brandName: 'Biogesic',
            genericName: 'Paracetamol',
            strength: '500 mg',
            dosageForm: 'Tablet',
            unitSold: 'tablet',
            isRx: false,
            unitPrice: 4.5,
            quantity: 10,
            heldQuantity: 0,
          ),
        ],
      );

      expect(resMulti.medicinesSummary, 'Amoxil × 21 + 1 more');
    });

    test('serializes and deserializes from json cleanly', () {
      final json = {
        'id': 'res-123',
        'reference_no': 'RM-103026-0001',
        'customer_id': 'c-123',
        'customer_name': 'Juan Dela Cruz',
        'branch_id': 'b-123',
        'status': 'confirmed',
        'has_rx': true,
        'total_amount': 150.50,
        'submitted_at': '2026-10-30T10:00:00.000Z',
        'expires_at': '2026-11-06T10:00:00.000Z',
        'pickup_code_suffix': 'K7M4',
        'items': [
          {
            'line_no': 1,
            'medicine_id': 'm-1',
            'inventory_item_id': 'inv-1',
            'brandName': 'Biogesic',
            'generic_name': 'Paracetamol',
            'strength': '500 mg',
            'dosage_form': 'Tablet',
            'unit_sold': 'tablet',
            'is_rx': false,
            'unit_price': 5.0,
            'quantity': 10,
            'held_quantity': 10,
          }
        ],
        'history': [
          {
            'id': 1,
            'to_status': 'confirmed',
            'actor_role': 'pharmacist',
            'actor_name': 'Jose Reyes (Pharmacist)',
            'created_at': '2026-10-30T10:05:00.000Z',
          }
        ],
        'prescriptions': [
          {
            'id': 'prx-1',
            'display_id': 'PRX-000001',
            'storage_path': 'path/to/rx.jpg',
            'mime_type': 'image/jpeg',
            'size_bytes': 2048,
            'uploaded_at': '2026-10-30T09:55:00.000Z',
          }
        ],
      };

      final parsed = BranchReservation.fromJson(json);
      expect(parsed.id, 'res-123');
      expect(parsed.referenceNo, 'RM-103026-0001');
      expect(parsed.isConfirmed, isTrue);
      expect(parsed.items.length, 1);
      expect(parsed.history.length, 1);
      expect(parsed.prescriptions.length, 1);
      expect(parsed.pickupCodeSuffix, 'K7M4');
    });
  });
}
