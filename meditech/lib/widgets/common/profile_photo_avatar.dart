import 'package:flutter/material.dart';

import 'network_avatar_image.dart';
import '../theme/app_colors.dart';

/// Circle avatar with optional network photo and camera affordance when [onTap] is set.
class ProfilePhotoAvatar extends StatelessWidget {
  const ProfilePhotoAvatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.radius = 28,
    this.onTap,
    this.showCameraBadge = false,
  });

  final String displayName;
  final String? photoUrl;
  final double radius;
  final VoidCallback? onTap;
  final bool showCameraBadge;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = Text(
      _initials(displayName),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: radius * 0.65,
      ),
    );

    final avatar = CircleAvatar(
      key: ValueKey(photoUrl ?? displayName),
      radius: radius,
      backgroundColor: AppColors.primary,
      child: photoUrl != null
          ? NetworkAvatarImage(
              url: photoUrl!,
              radius: radius,
              backgroundColor: AppColors.primary,
              fallback: Center(child: initials),
            )
          : initials,
    );

    if (onTap == null && !showCameraBadge) return avatar;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (showCameraBadge && onTap != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: CircleAvatar(
                radius: radius * 0.38,
                backgroundColor: AppColors.primary,
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: radius * 0.42,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}