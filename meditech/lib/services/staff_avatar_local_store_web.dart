import 'package:web/web.dart' as web;

import 'staff_avatar_local_store.dart';

StaffAvatarLocalStore createStaffAvatarLocalStore() => _WebStore();

class _WebStore implements StaffAvatarLocalStore {
  static String _key(String accountId) => 'meditech.staff-avatar.$accountId';

  @override
  Future<String?> load(String accountId) async {
    final value = web.window.localStorage.getItem(_key(accountId));
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> save(String accountId, String dataUrl) async {
    web.window.localStorage.setItem(_key(accountId), dataUrl);
  }
}
