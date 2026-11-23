import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/branch_reservation.dart';
import '../utils/app_failure.dart';

abstract class BranchReservationService {
  Future<List<BranchReservation>> getReservations(String branchId);
  Future<BranchReservation?> getReservationDetails(String reservationId);
  Future<void> confirmReservation(String reservationId);
  Future<void> rejectReservation(String reservationId, String reason);
  Future<void> markReady(String reservationId);
  Future<bool> checkPickupCode(String reservationId, String code);
  Future<void> completeReservation(String reservationId, String code);
  Future<void> cancelReservation(String reservationId, String reason);
  Future<String?> getPrescriptionUrl(String prescriptionId, {String? reservationId});
}

// Calls real Supabase database functions for reservations
class SupabaseBranchReservationService implements BranchReservationService {
  final SupabaseClient _client;

  SupabaseBranchReservationService(this._client);

  static void _applyCustomerProfileFields(Map<String, dynamic> map) {
    var profile = map['customer_profiles'] as Map<String, dynamic>?;
    profile ??= (map['accounts'] as Map<String, dynamic>?)?['customer_profiles']
        as Map<String, dynamic>?;
    if (profile != null) {
      final f = profile['first_name'] as String? ?? '';
      final l = profile['last_name'] as String? ?? '';
      map['customer_name'] = '$f $l'.trim();
      map['customer_phone'] = profile['mobile'] as String?;
    } else {
      map['customer_name'] = 'Customer';
    }
  }

  static const _listSelect = '''
          id,
          reference_no,
          customer_id,
          branch_id,
          status,
          has_rx,
          total_amount,
          submitted_at,
          expires_at,
          confirmed_at,
          ready_at,
          completed_at,
          closed_reason,
          accounts!customer_id (
            customer_profiles (first_name, last_name, mobile)
          ),
          reservation_items (
            line_no, medicine_id, inventory_item_id, brand_name,
            generic_name, strength, dosage_form, unit_sold,
            is_rx, unit_price, quantity, held_quantity
          )
        ''';

  static const _listSelectPlain = '''
          id,
          reference_no,
          customer_id,
          branch_id,
          status,
          has_rx,
          total_amount,
          submitted_at,
          expires_at,
          confirmed_at,
          ready_at,
          completed_at,
          closed_reason,
          reservation_items (
            line_no, medicine_id, inventory_item_id, brand_name,
            generic_name, strength, dosage_form, unit_sold,
            is_rx, unit_price, quantity, held_quantity
          )
        ''';

  List<BranchReservation> _mapReservationRows(List<dynamic> rows) {
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
      _applyCustomerProfileFields(map);
      map['items'] = map['reservation_items'];
      map['prescriptions'] = map['reservation_prescriptions'] ?? [];
      map['history'] = map['reservation_status_history'] ?? [];
      return BranchReservation.fromJson(map);
    }).toList();
  }

  @override
  Future<List<BranchReservation>> getReservations(String branchId) async {
    // Branch scope is enforced by RLS (my_branch_id()); do not filter by JWT alone.
    try {
      final response = await _client
          .from('reservations')
          .select(_listSelect)
          .order('submitted_at', ascending: false);
      return _mapReservationRows(response as List<dynamic>);
    } on PostgrestException {
      final response = await _client
          .from('reservations')
          .select(_listSelectPlain)
          .order('submitted_at', ascending: false);
      return _mapReservationRows(response as List<dynamic>);
    }
  }

  @override
  Future<BranchReservation?> getReservationDetails(String reservationId) async {
    final response = await _client
        .from('reservations')
        .select('''
          id,
          reference_no,
          customer_id,
          branch_id,
          status,
          has_rx,
          total_amount,
          submitted_at,
          expires_at,
          confirmed_at,
          ready_at,
          completed_at,
          closed_reason,
          accounts!customer_id (
            customer_profiles (first_name, last_name, mobile)
          ),
          reservation_items (
            line_no, medicine_id, inventory_item_id, brand_name,
            generic_name, strength, dosage_form, unit_sold,
            is_rx, unit_price, quantity, held_quantity,
            inventory_items (stock_quantity, held_quantity, out_of_stock_flag)
          ),
          reservation_prescriptions (
            id, display_id, storage_path, mime_type, size_bytes, uploaded_at
          ),
          reservation_status_history (
            id, from_status, to_status, actor_role, reason, created_at
          )
        ''')
        .eq('id', reservationId)
        .maybeSingle();

    if (response == null) return null;
    final map = Map<String, dynamic>.from(response);
    _applyCustomerProfileFields(map);

    final rawItems = (map['reservation_items'] as List<dynamic>? ?? []);
    final items = rawItems.map((item) {
      final itemMap = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final inv = itemMap['inventory_items'] as Map<String, dynamic>?;
      if (inv != null) {
        final stock = (inv['stock_quantity'] as num?)?.toInt() ?? 0;
        final held = (inv['held_quantity'] as num?)?.toInt() ?? 0;
        final oos = inv['out_of_stock_flag'] as bool? ?? false;
        itemMap['current_available_stock'] = oos ? 0 : (stock - held);
      }
      return itemMap;
    }).toList();

    map['items'] = items;
    map['prescriptions'] = map['reservation_prescriptions'];
    map['history'] = map['reservation_status_history'];
    return BranchReservation.fromJson(map);
  }

  Future<void> _rpcVoid(Future<void> Function() call) async {
    try {
      await call();
    } on PostgrestException catch (error) {
      throw AppFailure.fromPostgrest(error);
    }
  }

  @override
  Future<void> confirmReservation(String reservationId) async {
    await _rpcVoid(() => _client.rpc(
          'confirm_reservation',
          params: {'p_reservation_id': reservationId},
        ));
  }

  @override
  Future<void> rejectReservation(String reservationId, String reason) async {
    await _rpcVoid(() => _client.rpc(
          'reject_reservation',
          params: {
            'p_reservation_id': reservationId,
            'p_reason': reason,
          },
        ));
  }

  @override
  Future<void> markReady(String reservationId) async {
    await _rpcVoid(() => _client.rpc(
          'mark_ready',
          params: {'p_reservation_id': reservationId},
        ));
  }

  @override
  Future<bool> checkPickupCode(String reservationId, String code) async {
    final result = await _client.rpc(
      'check_pickup_code',
      params: {
        'p_reservation_id': reservationId,
        'p_code': code,
      },
    );
    return result as bool? ?? false;
  }

  @override
  Future<void> completeReservation(String reservationId, String code) async {
    await _rpcVoid(() => _client.rpc(
          'complete_reservation',
          params: {
            'p_reservation_id': reservationId,
            'p_code': code,
          },
        ));
  }

  @override
  Future<void> cancelReservation(String reservationId, String reason) async {
    await _rpcVoid(() => _client.rpc(
          'cancel_reservation',
          params: {
            'p_reservation_id': reservationId,
            'p_reason': reason,
          },
        ));
  }

  @override
  Future<String?> getPrescriptionUrl(String prescriptionId, {String? reservationId}) async {
    final path = await _client.rpc(
      'get_prescription_url',
      params: {
        'p_prescription_id': prescriptionId,
        ...?reservationId != null ? {'p_reservation_id': reservationId} : null,
      },
    );
    if (path == null) return null;
    return _client.storage.from('prescriptions').createSignedUrl(path as String, 3600);
  }
}

// Fake service seeded with the exact wireframes demo reservations (Ph-12 to Ph-20)
class FakeBranchReservationService implements BranchReservationService {
  final List<BranchReservation> _reservations;

  FakeBranchReservationService([List<BranchReservation>? initial])
      : _reservations = initial ?? List.from(_buildDemoReservations());

  static List<BranchReservation> _buildDemoReservations() {
    return [
      BranchReservation(
        id: 'res-1',
        referenceNo: 'RM-103026-0005',
        customerId: 'cus-1',
        customerName: 'Grace Villanueva',
        customerPhone: '09171112222',
        branchId: 'demo-branch',
        status: 'pending',
        hasRx: true,
        totalAmount: 252.00,
        submittedAt: DateTime(2026, 10, 30, 10, 42),
        expiresAt: DateTime(2026, 11, 6, 10, 42),
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'med-amoxil',
            inventoryItemId: 'inv-amoxil',
            brandName: 'Amoxil',
            genericName: 'Amoxicillin',
            strength: '500 mg',
            dosageForm: 'Capsule',
            unitSold: 'capsule',
            isRx: true,
            unitPrice: 12.00,
            quantity: 21,
            heldQuantity: 0,
            currentAvailableStock: 82,
          ),
        ],
        history: [
          BranchReservationHistory(
            id: 1,
            toStatus: 'pending',
            actorRole: 'customer',
            actorName: 'Grace Villanueva (patient)',
            createdAt: DateTime(2026, 10, 30, 10, 42),
          ),
        ],
        prescriptions: [
          BranchPrescription(
            id: 'prx-1',
            displayId: 'PRX-000001',
            storagePath: 'demo/grace_prescription.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 1024 * 350,
            uploadedAt: DateTime(2026, 10, 30, 10, 40),
          ),
        ],
      ),
      BranchReservation(
        id: 'res-2',
        referenceNo: 'RM-103026-0004',
        customerId: 'cus-2',
        customerName: 'Paolo Gomez',
        branchId: 'demo-branch',
        status: 'pending',
        hasRx: false,
        totalAmount: 110.00,
        submittedAt: DateTime(2026, 10, 30, 9, 58),
        expiresAt: DateTime(2026, 11, 6, 9, 58),
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'med-biogesic',
            inventoryItemId: 'inv-biogesic',
            brandName: 'Biogesic',
            genericName: 'Paracetamol',
            strength: '500 mg',
            dosageForm: 'Tablet',
            unitSold: 'tablet',
            isRx: false,
            unitPrice: 4.50,
            quantity: 20,
            heldQuantity: 0,
            currentAvailableStock: 220,
          ),
          BranchReservationItem(
            lineNo: 2,
            medicineId: 'med-neozep',
            inventoryItemId: 'inv-neozep',
            brandName: 'Neozep Forte',
            genericName: 'Phenylephrine + Paracetamol',
            strength: '10/2/500 mg',
            dosageForm: 'Tablet',
            unitSold: 'tablet',
            isRx: false,
            unitPrice: 6.50,
            quantity: 10,
            heldQuantity: 0,
            currentAvailableStock: 50,
          ),
        ],
        history: [
          BranchReservationHistory(
            id: 2,
            toStatus: 'pending',
            actorRole: 'customer',
            actorName: 'Paolo Gomez (patient)',
            createdAt: DateTime(2026, 10, 30, 9, 58),
          ),
        ],
      ),
      BranchReservation(
        id: 'res-3',
        referenceNo: 'RM-103026-0003',
        customerId: 'cus-3',
        customerName: 'Mark Sison',
        branchId: 'demo-branch',
        status: 'pending',
        hasRx: true,
        totalAmount: 180.00,
        submittedAt: DateTime(2026, 10, 30, 9, 20),
        expiresAt: DateTime(2026, 11, 6, 9, 20),
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'med-glucophage',
            inventoryItemId: 'inv-glucophage',
            brandName: 'Glucophage',
            genericName: 'Metformin',
            strength: '500 mg',
            dosageForm: 'Tablet',
            unitSold: 'tablet',
            isRx: true,
            unitPrice: 6.00,
            quantity: 30,
            heldQuantity: 0,
            currentAvailableStock: 8, // Out-of-stock/insufficient condition (Ph-17)
          ),
        ],
        history: [
          BranchReservationHistory(
            id: 3,
            toStatus: 'pending',
            actorRole: 'customer',
            actorName: 'Mark Sison (patient)',
            createdAt: DateTime(2026, 10, 30, 9, 20),
          ),
        ],
        prescriptions: [
          BranchPrescription(
            id: 'prx-3',
            displayId: 'PRX-000003',
            storagePath: 'demo/mark_prescription.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 1024 * 420,
            uploadedAt: DateTime(2026, 10, 30, 9, 15),
          ),
        ],
      ),
      BranchReservation(
        id: 'res-4',
        referenceNo: 'RM-103026-0002',
        customerId: 'cus-4',
        customerName: 'Carmela Reyes',
        branchId: 'demo-branch',
        status: 'confirmed',
        hasRx: false,
        totalAmount: 45.00,
        submittedAt: DateTime(2026, 10, 30, 8, 15),
        expiresAt: DateTime(2026, 11, 6, 8, 15),
        confirmedAt: DateTime(2026, 10, 30, 8, 25),
        pickupCodeSuffix: 'K7M4',
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'med-biogesic',
            inventoryItemId: 'inv-biogesic',
            brandName: 'Biogesic',
            genericName: 'Paracetamol',
            strength: '500 mg',
            dosageForm: 'Tablet',
            unitSold: 'tablet',
            isRx: false,
            unitPrice: 4.50,
            quantity: 10,
            heldQuantity: 10,
            currentAvailableStock: 220,
          ),
        ],
        history: [
          BranchReservationHistory(
            id: 4,
            toStatus: 'pending',
            actorRole: 'customer',
            actorName: 'Carmela Reyes (patient)',
            createdAt: DateTime(2026, 10, 30, 8, 15),
          ),
          BranchReservationHistory(
            id: 5,
            fromStatus: 'pending',
            toStatus: 'confirmed',
            actorRole: 'pharmacist',
            actorName: 'Jose Reyes (Pharmacist)',
            createdAt: DateTime(2026, 10, 30, 8, 25),
          ),
        ],
      ),
      BranchReservation(
        id: 'res-5',
        referenceNo: 'RM-102826-0012',
        customerId: 'cus-5',
        customerName: 'Luke Dela Cruz',
        branchId: 'demo-branch',
        status: 'ready_for_pickup',
        hasRx: false,
        totalAmount: 45.00,
        submittedAt: DateTime(2026, 10, 28, 17, 2),
        expiresAt: DateTime(2026, 11, 4, 17, 2),
        confirmedAt: DateTime(2026, 10, 28, 18, 40),
        readyAt: DateTime(2026, 10, 29, 16, 15),
        pickupCodeSuffix: 'K7M4',
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'med-biogesic',
            inventoryItemId: 'inv-biogesic',
            brandName: 'Biogesic',
            genericName: 'Paracetamol',
            strength: '500 mg',
            dosageForm: 'Tablet',
            unitSold: 'tablet',
            isRx: false,
            unitPrice: 4.50,
            quantity: 10,
            heldQuantity: 10,
            currentAvailableStock: 220,
          ),
        ],
        history: [
          BranchReservationHistory(
            id: 6,
            toStatus: 'pending',
            actorRole: 'customer',
            actorName: 'Luke Dela Cruz (patient)',
            createdAt: DateTime(2026, 10, 28, 17, 2),
          ),
          BranchReservationHistory(
            id: 7,
            fromStatus: 'pending',
            toStatus: 'confirmed',
            actorRole: 'pharmacist',
            actorName: 'Jose Reyes (Pharmacist)',
            createdAt: DateTime(2026, 10, 28, 18, 40),
          ),
          BranchReservationHistory(
            id: 8,
            fromStatus: 'confirmed',
            toStatus: 'ready_for_pickup',
            actorRole: 'staff',
            actorName: 'Ana Lim (Staff)',
            createdAt: DateTime(2026, 10, 29, 16, 15),
          ),
        ],
      ),
      BranchReservation(
        id: 'res-6',
        referenceNo: 'RM-102926-0008',
        customerId: 'cus-6',
        customerName: 'Nico Ramos',
        branchId: 'demo-branch',
        status: 'ready_for_pickup',
        hasRx: true,
        totalAmount: 168.00,
        submittedAt: DateTime(2026, 10, 29, 14, 40),
        expiresAt: DateTime(2026, 11, 5, 14, 40),
        confirmedAt: DateTime(2026, 10, 29, 15, 5),
        readyAt: DateTime(2026, 10, 30, 9, 0),
        pickupCodeSuffix: 'H3NP',
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'med-amoxil',
            inventoryItemId: 'inv-amoxil',
            brandName: 'Amoxil',
            genericName: 'Amoxicillin',
            strength: '500 mg',
            dosageForm: 'Capsule',
            unitSold: 'capsule',
            isRx: true,
            unitPrice: 12.00,
            quantity: 14,
            heldQuantity: 14,
            currentAvailableStock: 82,
          ),
        ],
        history: [
          BranchReservationHistory(
            id: 9,
            toStatus: 'pending',
            actorRole: 'customer',
            actorName: 'Nico Ramos (patient)',
            createdAt: DateTime(2026, 10, 29, 14, 40),
          ),
          BranchReservationHistory(
            id: 10,
            fromStatus: 'pending',
            toStatus: 'confirmed',
            actorRole: 'pharmacist',
            actorName: 'Jose Reyes (Pharmacist)',
            createdAt: DateTime(2026, 10, 29, 15, 5),
          ),
          BranchReservationHistory(
            id: 11,
            fromStatus: 'confirmed',
            toStatus: 'ready_for_pickup',
            actorRole: 'staff',
            actorName: 'Ana Lim (Staff)',
            createdAt: DateTime(2026, 10, 30, 9, 0),
          ),
        ],
        prescriptions: [
          BranchPrescription(
            id: 'prx-6',
            displayId: 'PRX-000006',
            storagePath: 'demo/nico_prescription.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 1024 * 280,
            uploadedAt: DateTime(2026, 10, 29, 14, 35),
          ),
        ],
      ),
      BranchReservation(
        id: 'res-7',
        referenceNo: 'RM-102926-0004',
        customerId: 'cus-7',
        customerName: 'Jun Bautista',
        branchId: 'demo-branch',
        status: 'completed',
        hasRx: true,
        totalAmount: 168.00,
        submittedAt: DateTime(2026, 10, 29, 11, 5),
        expiresAt: DateTime(2026, 11, 5, 11, 5),
        completedAt: DateTime(2026, 10, 29, 16, 30),
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'med-amoxil',
            inventoryItemId: 'inv-amoxil',
            brandName: 'Amoxil',
            genericName: 'Amoxicillin',
            strength: '500 mg',
            dosageForm: 'Capsule',
            unitSold: 'capsule',
            isRx: true,
            unitPrice: 12.00,
            quantity: 14,
            heldQuantity: 0,
          ),
        ],
        history: const [],
      ),
      BranchReservation(
        id: 'res-8',
        referenceNo: 'RM-102726-0009',
        customerId: 'cus-8',
        customerName: 'Liza Mendoza',
        branchId: 'demo-branch',
        status: 'rejected',
        hasRx: true,
        totalAmount: 555.00,
        closedReason: 'Prescription image is unclear. Please upload a clearer photo.',
        submittedAt: DateTime(2026, 10, 27, 13, 10),
        expiresAt: DateTime(2026, 11, 3, 13, 10),
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'med-cozaar',
            inventoryItemId: 'inv-cozaar',
            brandName: 'Cozaar',
            genericName: 'Losartan',
            strength: '50 mg',
            dosageForm: 'Tablet',
            unitSold: 'tablet',
            isRx: true,
            unitPrice: 18.50,
            quantity: 30,
            heldQuantity: 0,
          ),
        ],
        history: const [],
      ),
      BranchReservation(
        id: 'res-9',
        referenceNo: 'RM-102526-0002',
        customerId: 'cus-9',
        customerName: 'Ramon Cruz',
        branchId: 'demo-branch',
        status: 'cancelled',
        hasRx: false,
        totalAmount: 65.00,
        closedReason: 'Customer requested cancellation over the phone.',
        submittedAt: DateTime(2026, 10, 25, 10, 0),
        expiresAt: DateTime(2026, 11, 1, 10, 0),
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'med-virlix',
            inventoryItemId: 'inv-virlix',
            brandName: 'Virlix',
            genericName: 'Cetirizine',
            strength: '10 mg',
            dosageForm: 'Tablet',
            unitSold: 'tablet',
            isRx: false,
            unitPrice: 6.50,
            quantity: 10,
            heldQuantity: 0,
          ),
        ],
        history: const [],
      ),
      BranchReservation(
        id: 'res-10',
        referenceNo: 'RM-102126-0006',
        customerId: 'cus-10',
        customerName: 'Tess Aquino',
        branchId: 'demo-branch',
        status: 'expired',
        hasRx: false,
        totalAmount: 90.00,
        submittedAt: DateTime(2026, 10, 21, 14, 30),
        expiresAt: DateTime(2026, 10, 28, 14, 30),
        items: const [
          BranchReservationItem(
            lineNo: 1,
            medicineId: 'med-biogesic',
            inventoryItemId: 'inv-biogesic',
            brandName: 'Biogesic',
            genericName: 'Paracetamol',
            strength: '500 mg',
            dosageForm: 'Tablet',
            unitSold: 'tablet',
            isRx: false,
            unitPrice: 4.50,
            quantity: 20,
            heldQuantity: 0,
          ),
        ],
        history: const [],
      ),
    ];
  }

  @override
  Future<List<BranchReservation>> getReservations(String branchId) async {
    return List.from(_reservations);
  }

  @override
  Future<BranchReservation?> getReservationDetails(String reservationId) async {
    final idx = _reservations.indexWhere((r) => r.id == reservationId);
    if (idx == -1) return null;
    return _reservations[idx];
  }

  @override
  Future<void> confirmReservation(String reservationId) async {
    final idx = _reservations.indexWhere((r) => r.id == reservationId);
    if (idx == -1) throw Exception('Reservation not found');
    final res = _reservations[idx];
    if (res.status != 'pending') {
      throw Exception('Only pending reservations can be confirmed');
    }

    _reservations[idx] = res.copyWith(
      status: 'confirmed',
      confirmedAt: DateTime.now(),
      pickupCodeSuffix: res.pickupCodeSuffix ?? 'K7M4',
      history: [
        ...res.history,
        BranchReservationHistory(
          id: res.history.length + 1,
          fromStatus: 'pending',
          toStatus: 'confirmed',
          actorRole: 'pharmacist',
          actorName: 'Jose Reyes (Pharmacist)',
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Future<void> rejectReservation(String reservationId, String reason) async {
    final idx = _reservations.indexWhere((r) => r.id == reservationId);
    if (idx == -1) throw Exception('Reservation not found');
    final res = _reservations[idx];
    if (res.status != 'pending') {
      throw Exception('Only pending reservations can be rejected');
    }

    _reservations[idx] = res.copyWith(
      status: 'rejected',
      closedReason: reason,
      history: [
        ...res.history,
        BranchReservationHistory(
          id: res.history.length + 1,
          fromStatus: 'pending',
          toStatus: 'rejected',
          actorRole: 'pharmacist',
          actorName: 'Jose Reyes (Pharmacist)',
          reason: reason,
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Future<void> markReady(String reservationId) async {
    final idx = _reservations.indexWhere((r) => r.id == reservationId);
    if (idx == -1) throw Exception('Reservation not found');
    final res = _reservations[idx];
    if (res.status != 'confirmed') {
      throw Exception('Only confirmed reservations can be marked as ready');
    }

    _reservations[idx] = res.copyWith(
      status: 'ready_for_pickup',
      readyAt: DateTime.now(),
      history: [
        ...res.history,
        BranchReservationHistory(
          id: res.history.length + 1,
          fromStatus: 'confirmed',
          toStatus: 'ready_for_pickup',
          actorRole: 'staff',
          actorName: 'Ana Lim (Staff)',
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Future<bool> checkPickupCode(String reservationId, String code) async {
    final idx = _reservations.indexWhere((r) => r.id == reservationId);
    if (idx == -1) throw Exception('Reservation not found');
    final res = _reservations[idx];
    final expected = res.pickupCodeSuffix ?? 'K7M4';
    return code.trim().toUpperCase() == expected.toUpperCase();
  }

  @override
  Future<void> completeReservation(String reservationId, String code) async {
    final valid = await checkPickupCode(reservationId, code);
    if (!valid) throw Exception('Incorrect pickup code');

    final idx = _reservations.indexWhere((r) => r.id == reservationId);
    if (idx == -1) throw Exception('Reservation not found');
    final res = _reservations[idx];

    _reservations[idx] = res.copyWith(
      status: 'completed',
      completedAt: DateTime.now(),
      history: [
        ...res.history,
        BranchReservationHistory(
          id: res.history.length + 1,
          fromStatus: res.status,
          toStatus: 'completed',
          actorRole: 'staff',
          actorName: 'Staff',
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Future<void> cancelReservation(String reservationId, String reason) async {
    final idx = _reservations.indexWhere((r) => r.id == reservationId);
    if (idx == -1) throw Exception('Reservation not found');
    final res = _reservations[idx];

    _reservations[idx] = res.copyWith(
      status: 'cancelled',
      closedReason: reason,
      history: [
        ...res.history,
        BranchReservationHistory(
          id: res.history.length + 1,
          fromStatus: res.status,
          toStatus: 'cancelled',
          actorRole: 'owner',
          actorName: 'Owner',
          reason: reason,
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Future<String?> getPrescriptionUrl(String prescriptionId, {String? reservationId}) async {
    return 'https://fake-storage.local/prescriptions/$prescriptionId.jpg';
  }
}
