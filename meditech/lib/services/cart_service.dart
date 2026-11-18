import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart.dart';

// Outcome of attempting to add an item to the single-branch cart
enum AddToCartOutcome {
  added,
  branchConflict,
}

// Talks to Supabase for the customer's cart, items, and prescription attachments
class CartService {
  CartService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Loads the signed-in customer's cart items and uploaded prescriptions
  Future<CustomerCart> getMyCart() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const CustomerCart();
    }

    final itemRows = await _client.rpc('get_my_cart') as List<dynamic>;
    final items = itemRows
        .map((row) => CartItem.fromJson(row as Map<String, dynamic>))
        .toList();

    final rxRows = await _client
        .from('cart_prescription_files')
        .select('id, storage_path, mime_type, size_bytes, uploaded_at')
        .eq('customer_id', userId)
        .order('uploaded_at', ascending: true);

    final prescriptions = (rxRows as List<dynamic>)
        .map(
          (row) => CartPrescriptionFile.fromJson(row as Map<String, dynamic>),
        )
        .toList();

    return CustomerCart(
      items: items,
      prescriptions: prescriptions,
    );
  }

  // Adds a medicine from one branch; returns branchConflict if another branch
  // is already in the cart and replaceBranch is false.
  Future<AddToCartOutcome> addToCart({
    required String branchId,
    required String medicineId,
    int quantity = 1,
    bool replaceBranch = false,
  }) async {
    final result = await _client.rpc(
      'add_to_cart',
      params: {
        'p_branch_id': branchId,
        'p_medicine_id': medicineId,
        'p_quantity': quantity,
        'p_replace_branch': replaceBranch,
      },
    ) as String;

    if (result == 'branch_conflict') {
      return AddToCartOutcome.branchConflict;
    }
    return AddToCartOutcome.added;
  }

  // Updates an item's quantity (removes item if quantity <= 0)
  Future<void> setItemQuantity({
    required String medicineId,
    required int quantity,
  }) async {
    await _client.rpc(
      'set_cart_item_quantity',
      params: {
        'p_medicine_id': medicineId,
        'p_quantity': quantity,
      },
    );
  }

  // Empties the entire cart
  Future<void> clearCart() async {
    await _client.rpc('clear_my_cart');
  }

  // Uploads a prescription file (<customer_id>/<timestamp>_<fileName>) to the
  // private prescriptions bucket and records metadata in cart_prescription_files.
  Future<CartPrescriptionFile> uploadPrescription({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in to upload a prescription.');
    }

    final sanitizedName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

    await _client.storage.from('prescriptions').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType),
        );

    final inserted = await _client
        .from('cart_prescription_files')
        .insert({
          'customer_id': userId,
          'storage_path': storagePath,
          'mime_type': mimeType,
          'size_bytes': bytes.lengthInBytes,
        })
        .select('id, storage_path, mime_type, size_bytes, uploaded_at')
        .single();

    return CartPrescriptionFile.fromJson(inserted);
  }

  // Deletes a prescription file from storage and cart_prescription_files
  Future<void> removePrescription(CartPrescriptionFile file) async {
    await _client.storage.from('prescriptions').remove([file.storagePath]);
    await _client
        .from('cart_prescription_files')
        .delete()
        .eq('id', file.id);
  }
}