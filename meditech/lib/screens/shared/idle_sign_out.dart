import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/session_providers.dart';

// Signs the pharmacy tablet out after 10 idle minutes
class IdleSignOut extends ConsumerStatefulWidget {
  const IdleSignOut({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IdleSignOut> createState() => _IdleSignOutState();
}

class _IdleSignOutState extends ConsumerState<IdleSignOut> {
  static const _idleLimit = Duration(minutes: 10);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Any tap or keypress restarts the 10-minute wait
  void _restart() {
    _timer?.cancel();
    if (ref.read(sessionProvider) == null) return;
    _timer = Timer(_idleLimit, _signOut);
  }

  Future<void> _signOut() async {
    await ref.read(sessionProvider.notifier).signOut();
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    router?.go('/');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (next == null) {
        _timer?.cancel();
      } else {
        _restart();
      }
    });

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      child: widget.child,
    );
  }
}