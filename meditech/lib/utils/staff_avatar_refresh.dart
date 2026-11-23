import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pharmacy_staff_providers.dart';
void _evictNetworkUrl(String? url) {
  if (url == null || url.isEmpty) return;
  try {
    NetworkImage(url).evict();
  } catch (_) {}
}

/// After a successful upload: bust URL cache, refresh header, reload profile row.
Future<void> applyStaffAvatarRefresh(
  WidgetRef ref, {
  required String? storedPath,
}) async {
  if (storedPath == null || storedPath.isEmpty) return;

  final priorUrl = ref.read(staffHeaderPhotoUrlProvider);
  _evictNetworkUrl(priorUrl);

  ref.read(staffAvatarPathOverrideProvider.notifier).set(storedPath);
  ref.read(staffAvatarRevisionProvider.notifier).bump();

  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();

  ref.invalidate(pharmacyStaffProfileProvider);
  try {
    await ref.read(pharmacyStaffProfileProvider.future);
    final path = ref.read(pharmacyStaffProfileProvider).value?.avatarStoragePath;
    if (path == storedPath) {
      ref.read(staffAvatarPathOverrideProvider.notifier).clear();
    }
  } catch (_) {
    // Keep path override so header still shows the new upload.
  }

  _evictNetworkUrl(ref.read(staffHeaderPhotoUrlProvider));
}