import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/user_role.dart';
import '../../widgets/h360_button.dart';

/// Short step-by-step guide (swipe through the pages).
/// Shown to every new account BEFORE its dashboard (the shells show it in
/// place of the dashboard and pass [onFinished]), and reopened any time from
/// Profile > Help & Support > How to Use Health360 (pushed as a page).
/// Added because validators asked where to press and how video visits work.
class HowToUseScreen extends StatefulWidget {
  const HowToUseScreen({super.key, required this.role, this.onFinished});

  final UserRole role;

  /// Called on "Get started" or "Skip" when the guide is shown in place of
  /// the dashboard. When null (opened from Help & Support) the page closes.
  final VoidCallback? onFinished;

  @override
  State<HowToUseScreen> createState() => _HowToUseScreenState();
}

class _GuidePage {
  const _GuidePage(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _HowToUseScreenState extends State<HowToUseScreen> {
  static const List<_GuidePage> _patientPages = [
    _GuidePage(
      Icons.home_rounded,
      'Your health at a glance',
      'The Home tab shows your next appointment, your health numbers and the medicines to take today.',
    ),
    _GuidePage(
      Icons.touch_app_rounded,
      'Find things in the bottom bar',
      'Tap Appointment to book a visit, Prescription for your medicines and reminders, Records for your results, and Profile for your account.',
    ),
    _GuidePage(
      Icons.auto_awesome_rounded,
      'Ask the assistant',
      'Tap Ask AI and describe how you feel. It gives general guidance, not a diagnosis. In an emergency, call 911.',
    ),
    _GuidePage(
      Icons.videocam_rounded,
      'Video consultations',
      'Video visits open in Google Meet, so you can use the Meet app or your phone browser. A steady internet connection helps. You can reopen this guide any time from Profile > Help & Support.',
    ),
  ];

  static const List<_GuidePage> _doctorPages = [
    _GuidePage(
      Icons.home_rounded,
      'Your day at a glance',
      "Home shows today's schedule and a quick overview of your appointments, patients, prescriptions and lab results.",
    ),
    _GuidePage(
      Icons.menu_rounded,
      'Open the menu',
      'Tap Menu in the bottom bar for the full list: appointments, patients, prescriptions, medical records, lab results and the dashboard.',
    ),
    _GuidePage(
      Icons.folder_shared_rounded,
      "Write your patients' records",
      'In Patients, open a patient to add consultation notes, prescriptions and lab results. The patient sees them in their Records and Prescriptions.',
    ),
    _GuidePage(
      Icons.dashboard_rounded,
      'Dashboard and profile',
      'The dashboard has shortcuts and recent activity. Manage your details and preferences in Profile. You can reopen this guide from Profile > Help & Support.',
    ),
  ];

  final PageController _controller = PageController();
  int _page = 0;

  List<_GuidePage> get _pages => widget.role == UserRole.patient ? _patientPages : _doctorPages;
  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "Get started" or "Skip": open the dashboard, or close the page.
  void _finish() {
    final onFinished = widget.onFinished;
    if (onFinished != null) {
      onFinished();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip (hidden on the last page so the layout does not jump)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Opacity(
                  opacity: _isLast ? 0 : 1,
                  child: TextButton(
                    onPressed: _isLast ? null : _finish,
                    child: const Text('Skip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _PageContent(page: pages[i]),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 26 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
              ],
            ),

            // Next / Get started
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: H360Button(
                    label: _isLast ? 'Get started' : 'Next',
                    icon: _isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page});

  final _GuidePage page;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: const BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
                child: Icon(page.icon, size: 64, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                page.body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, height: 1.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
