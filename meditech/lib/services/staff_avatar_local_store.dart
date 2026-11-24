import 'staff_avatar_local_store_stub.dart'
    if (dart.library.html) 'staff_avatar_local_store_web.dart';

/// Remembers a profile photo on this device when storage is not available yet.
abstract class StaffAvatarLocalStore {
  Future<void> save(String accountId, String dataUrl);
  Future<String?> load(String accountId);
}

StaffAvatarLocalStore staffAvatarLocalStore() => createStaffAvatarLocalStore();
