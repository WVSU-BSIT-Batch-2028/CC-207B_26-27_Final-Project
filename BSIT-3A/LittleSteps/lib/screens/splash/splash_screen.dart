import 'dart:async';

import 'package:flutter/material.dart';

import '../../routing/app_router.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/brand_logo.dart';

/// Initial launch screen displaying the LittleSteps brand identity while
/// resolving the caregiver's authentication route.
///
/// Matches the native launch canvas ([AppColors.surfaceCanvas]), respects
/// system reduce-motion preferences via [MediaQuery.disableAnimationsOf], and
/// routes immediately after [AppMotion.splashDelay].
class SplashScreen extends StatefulWidget {
  /// Creates a [SplashScreen].
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const double _emblemContainerSize = 96;
  static const double _emblemIconSize = 56;
  static const double _initialScale = 0.94;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _navigationTimer;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.durationBase,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.easingStandard,
    );
    _fadeAnimation = curved;
    _scaleAnimation = Tween<double>(
      begin: _initialScale,
      end: 1.0,
    ).animate(curved);

    _navigationTimer = Timer(AppMotion.splashDelay, _navigateNext);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationStarted) return;
    _animationStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  void _navigateNext() {
    if (!mounted) return;
    final isAuthenticated =
        AuthScope.maybeOf(context)?.isAuthenticated ?? false;
    Navigator.pushReplacementNamed(
      context,
      isAuthenticated ? AppRoutes.home : AppRoutes.signIn,
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.space24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - (AppSpacing.space24 * 2))
                      .clamp(0.0, double.infinity),
                ),
                child: Semantics(
                  label: 'LittleSteps. Small steps. Brighter tomorrows.',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.space16),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: _emblemContainerSize,
                                height: _emblemContainerSize,
                                decoration: BoxDecoration(
                                  color: AppColors.softGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.borderSubtle,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const GrowthSymbol(
                                  size: _emblemIconSize,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space20),
                              Text(
                                'LittleSteps',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: AppColors.forest,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space8),
                              Text(
                                'Small steps. Brighter tomorrows.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.space24),
                        child: Text(
                          'Play & observation companion for caregivers',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
