import 'package:flutter/material.dart';
import 'package:websupark/screens/driver/driver_common.dart';
import 'package:websupark/theme/app_colors.dart';
import 'package:websupark/widgets/phone_frame.dart';

// ---------------------------------------------------------------------------
// SAMPLE DATA shared by the renewal screens (layout only)
// TODO: replace with repository data
// ---------------------------------------------------------------------------
const String renewalFee = '₱500.00'; // TODO: replace with repository data
const String renewalVehicle = 'White Toyota Vios'; // TODO: replace with repository data
const String renewalPlate = 'ABC-1234'; // TODO: replace with repository data
const String renewalPass = 'BLUE-025'; // TODO: replace with repository data
const String renewalValidUntil = 'March 31, 2027'; // TODO: replace with repository data

/// Page frame for every renewal screen: back button, title, optional
/// 3-step progress bar and a scrolling body. The renewal screens are opened
/// on top of the driver tabs, so they have no bottom navigation bar.
class RenewalScaffold extends StatelessWidget {
  const RenewalScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.step,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  /// Current step (1 to 3). Null hides the progress bar.
  final int? step;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Header: back arrow, title and subtitle, icon button.
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      color: AppColors.textPrimary,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DriverIconBox(icon: icon, size: 36),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (step != null) ...[
                        _StepProgress(step: step!),
                        const SizedBox(height: 22),
                      ],
                      ...children,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three thin bars. The first `step` bars are blue.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 3; i++)
          Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
              decoration: BoxDecoration(
                color: i <= step ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Big heading with a small gray line under it.
class RenewalHeading extends StatelessWidget {
  const RenewalHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// One label / value line inside a RenewalRowsCard.
class RenewalRow {
  const RenewalRow(this.label, this.value, {this.trailing});

  final String label;
  final String value;

  /// Shown instead of the value text when given (e.g. a status chip).
  final Widget? trailing;
}

/// White card listing label / value rows with thin lines between them.
class RenewalRowsCard extends StatelessWidget {
  const RenewalRowsCard({super.key, required this.rows});

  final List<RenewalRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    rows[i].trailing ??
                        Text(
                          rows[i].value,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                  ],
                ),
              ),
              if (i != rows.length - 1)
                const Divider(height: 1, color: AppColors.border),
            ],
          ],
        ),
      ),
    );
  }
}
