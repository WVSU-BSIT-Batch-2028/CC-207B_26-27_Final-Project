import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String _avatarBucket = 'foodwise-avatars';
  static const int _maxAvatarBytes = 5 * 1024 * 1024;

  /// The currently authenticated Supabase user.
  static User? get currentUser => _client.auth.currentUser;

  static Future<AuthResponse> registerStudent({
    required String fullName,
    String? phone,
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
  }

  static Future<AuthResponse> loginStudent({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> resendVerificationEmail(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  static Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Returns the signed-in student's row from the profiles table.
  static Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final profile = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) return null;

    return _withSignedAvatarUrl(profile);
  }

  /// Converts the private Storage path in profiles.avatar_url into a
  /// short-lived URL that the signed-in user can display in the app.
  static Future<Map<String, dynamic>> _withSignedAvatarUrl(
    Map<String, dynamic> profile,
  ) async {
    final avatarPath = profile['avatar_url']?.toString();
    if (avatarPath != null && avatarPath.isNotEmpty) {
      try {
        profile['avatar_url'] = await _client.storage
            .from(_avatarBucket)
            .createSignedUrl(avatarPath, 60 * 60);
      } catch (_) {
        // A missing photo should not prevent the rest of the profile from
        // loading. The screen will show the student's initials instead.
        profile['avatar_url'] = null;
      }
    }
    return profile;
  }

  /// Updates only fields that a student is allowed to edit.
  /// The role and profile ID are deliberately never accepted from the UI.
  /// Pass [phone] only when the profiles table contains a phone column.
  static Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Your session has expired. Please sign in again.');
    }

    final cleanName = fullName.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Full name cannot be empty.');
    }

    final updates = <String, dynamic>{'full_name': cleanName};
    if (phone != null) updates['phone'] = phone.trim();

    final updated = await _client
        .from('profiles')
        .update(updates)
        .eq('id', user.id)
        .select()
        .maybeSingle();

    if (updated == null) {
      throw StateError(
        'Your profile could not be updated. Check that your profile row exists '
        'and that your Supabase RLS policy allows students to update their own profile.',
      );
    }

    return _withSignedAvatarUrl(updated);
  }

  /// Uploads a student's avatar to the private `foodwise-avatars` Storage bucket and
  /// saves its object path in profiles.avatar_url.
  ///
  /// The object path is scoped to the authenticated user's ID. Storage RLS
  /// must enforce the same folder restriction.
  static Future<Map<String, dynamic>> uploadProfileAvatar(XFile image) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Your session has expired. Please sign in again.');
    }

    final extension = image.name.split('.').last.toLowerCase();
    const contentTypes = <String, String>{
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };
    final contentType = contentTypes[extension];
    if (contentType == null) {
      throw FormatException('Choose a JPG, PNG, or WebP image.');
    }

    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw FormatException(
        'The selected image is empty. Choose another photo.',
      );
    }
    if (bytes.length > _maxAvatarBytes) {
      throw FormatException('Choose an image smaller than 5 MB.');
    }

    final existingProfile = await getProfile();
    final previousPath = _avatarStoragePath(
      existingProfile?['avatar_url']?.toString(),
      user.id,
    );

    final path =
        '${user.id}/avatar_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final storage = _client.storage.from(_avatarBucket);

    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
        cacheControl: '3600',
      ),
    );

    Map<String, dynamic> updated;
    try {
      final row = await _client
          .from('profiles')
          .update({'avatar_url': path})
          .eq('id', user.id)
          .select()
          .maybeSingle();

      if (row == null) {
        throw StateError(
          'Your profile photo was uploaded, but your profile could not be updated. Please try again or contact support.',
        );
      }
      updated = row;
    } catch (_) {
      // If the database update failed and this is a newly-created object,
      // clean it up so the user does not accumulate unused uploads.
      if (previousPath != path) {
        try {
          await storage.remove([path]);
        } catch (_) {
          // Preserve the original database error for the UI.
        }
      }
      rethrow;
    }

    // Remove the previous object only after the new path is saved successfully.
    if (previousPath != null && previousPath != path) {
      try {
        await storage.remove([previousPath]);
      } catch (_) {
        // The new photo is already saved; a leftover old object does not
        // prevent the updated profile photo from working.
      }
    }

    // Return a short-lived URL for rendering; the database keeps only the
    // private Storage path. The next profile load will create a fresh URL.
    return _withSignedAvatarUrl(updated);
  }

  /// Removes the avatar path from the student's profile and best-effort deletes
  /// the corresponding object from Storage.
  static Future<Map<String, dynamic>> removeProfileAvatar() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Your session has expired. Please sign in again.');
    }

    final existingProfile = await getProfile();
    final previousPath = _avatarStoragePath(
      existingProfile?['avatar_url']?.toString(),
      user.id,
    );

    final updated = await _client
        .from('profiles')
        .update({'avatar_url': null})
        .eq('id', user.id)
        .select()
        .maybeSingle();

    if (updated == null) {
      throw StateError(
        'Your profile photo could not be removed. Please try again.',
      );
    }

    if (previousPath != null) {
      try {
        await _client.storage.from(_avatarBucket).remove([previousPath]);
      } catch (_) {
        // The profile no longer references the image. If Storage cleanup is
        // blocked, the unused object can be removed from the dashboard later.
      }
    }

    return updated;
  }

  static String? _avatarStoragePath(String? avatarUrl, String userId) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;

    final uri = Uri.tryParse(avatarUrl);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(_avatarBucket);
    if (bucketIndex < 0 || bucketIndex + 1 >= segments.length) return null;

    final path = segments.skip(bucketIndex + 1).join('/');
    if (!path.startsWith('$userId/')) return null;
    return path;
  }

  /// Requests an email change through Supabase Auth.
  /// Supabase may require the user to confirm the new email address.
  static Future<void> updateEmail(String newEmail) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Your session has expired. Please sign in again.');
    }

    final cleanEmail = newEmail.trim();
    if (cleanEmail.isEmpty) {
      throw ArgumentError('Email address cannot be empty.');
    }

    await _client.auth.updateUser(UserAttributes(email: cleanEmail));
  }

  /// Re-authenticates with the current email and password before changing it.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _client.auth.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      throw StateError(
        'No signed-in email account was found. Please sign in again.',
      );
    }

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      throw ArgumentError('Please complete all password fields.');
    }

    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );

    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  static Future<void> logout() async {
    await _client.auth.signOut();
  }

  static bool isLoggedIn() {
    return _client.auth.currentSession != null;
  }
}
