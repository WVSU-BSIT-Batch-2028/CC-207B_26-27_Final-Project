import 'staff_avatar_local_store.dart';

StaffAvatarLocalStore createStaffAvatarLocalStore() => _MemoryStore();

class _MemoryStore implements StaffAvatarLocalStore {
  static final _values = <String, String>{};

  @override
  Future<String?> load(String accountId) async => _values[accountId];

  @override
  Future<void> save(String accountId, String dataUrl) async {
    _values[accountId] = dataUrl;
  }
}
