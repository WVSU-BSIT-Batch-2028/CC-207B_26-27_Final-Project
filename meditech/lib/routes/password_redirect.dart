import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/signed_in_account.dart';
import '../providers/session_providers.dart';

// Temporary passwords must be changed before anything else
String? redirectForPasswordChange(SignedInAccount? account, String location) {
  final changing = location == '/change-password';
  if (account?.mustChangePassword == true && !changing) {
    return '/change-password';
  }
  if (account != null && !account.mustChangePassword && changing) {
    return '/';
  }
  return null;
}

// Pharmacy owners waiting, rejected, or suspended only see their status pages
String? redirectForPharmacySession(SignedInAccount? account, String location) {
  final passwordRedirect = redirectForPasswordChange(account, location);
  if (passwordRedirect != null) return passwordRedirect;

  if (account == null) {
    if (location == '/application-status' || location == '/suspended') {
      return '/';
    }
    return null;
  }

  final waiting = account.state == 'pending_approval' || account.state == 'rejected';
  final suspended = account.state == 'suspended';

  if (waiting) {
    const allowed = {'/application-status', '/change-password', '/register'};
    if (!allowed.contains(location)) return '/application-status';
    return null;
  }

  if (suspended) {
    const allowed = {'/suspended', '/change-password'};
    if (!allowed.contains(location)) return '/suspended';
    return null;
  }

  if (location == '/application-status' || location == '/suspended') {
    return '/';
  }
  return null;
}

class SessionRefresh extends ChangeNotifier {
  SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}
