// The heart button for following a crop listing or a farmer. It checks
// whether the buyer already follows it, and toggles on tap.

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/following_service.dart';
import '../utils/app_exception.dart';
import '../utils/snackbars.dart';
import '../utils/theme.dart';

/// Follow / Unfollow toggle for one listing or farmer.
class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.targetId,
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final String targetId; // listing id or farmer id
  final String type; // FollowType.listing or FollowType.farmer
  final String title; // saved with the follow, shown on the Following tab
  final String subtitle;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  final _service = FollowingService();
  final _userId = AuthService.currentUser!.id;
  bool _isFollowing = false;
  bool _isBusy = true; // true while checking or saving

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final following = await _service.isFollowing(_userId, widget.targetId);
      if (mounted) setState(() => _isFollowing = following);
    } catch (_) {
      // If the check fails we show "Follow"; tapping it will retry.
    }
    if (mounted) setState(() => _isBusy = false);
  }

  Future<void> _toggle() async {
    setState(() => _isBusy = true);
    try {
      if (_isFollowing) {
        await _service.unfollow(_userId, widget.targetId);
      } else {
        await _service.follow(
          userId: _userId,
          targetId: widget.targetId,
          type: widget.type,
          title: widget.title,
          subtitle: widget.subtitle,
        );
      }
      if (!mounted) return;
      setState(() => _isFollowing = !_isFollowing);
      showMessage(
        context,
        _isFollowing ? 'Added to Following.' : 'Removed from Following.',
      );
    } catch (e) {
      if (mounted) showError(context, friendlyMessage(e));
    }
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isBusy ? null : _toggle,
      icon: Icon(
        _isFollowing ? Icons.favorite : Icons.favorite_border,
        color: AppColors.danger,
      ),
      // The text changes too, so the state is not shown by color alone.
      label: Text(_isFollowing ? 'Following' : 'Follow'),
    );
  }
}
