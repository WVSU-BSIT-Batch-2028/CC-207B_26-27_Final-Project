import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../services/dashboard_service.dart';

/// Demo-only sheet (open it by long-pressing the avatar on a Home screen).
/// Switches the mock data between normal / empty / error so the loading,
/// empty and error states can be shown live. [onChanged] reloads the screen.
Future<void> showDemoScenarioSheet(BuildContext context, VoidCallback onChanged) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (sheetContext) {
      Widget option(String label, String hint, DemoScenario scenario) {
        final selected = DashboardService.instance.scenario == scenario;
        return ListTile(
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(hint),
          trailing: selected ? Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
          onTap: () {
            DashboardService.instance.scenario = scenario;
            Navigator.of(sheetContext).pop();
            onChanged();
          },
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Demo data state', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
              option('Normal', 'Sample data', DemoScenario.normal),
              option('Empty', 'New account with no records', DemoScenario.empty),
              option('Error', 'Simulate a network failure', DemoScenario.error),
            ],
          ),
        ),
      );
    },
  );
}
