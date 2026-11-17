import 'package:flutter/material.dart';
import 'package:websupark/widgets/phone_frame.dart';
import 'package:websupark/widgets/placeholder_page.dart';

/// Temporary stand-in for one screen of the guard flow (S1 to S6).
/// The guard owner replaces each entry in AppRouter with the real screen.
class GuardFlowScreen extends StatelessWidget {
  const GuardFlowScreen({
    super.key,
    required this.title,
    required this.screenCode,
    this.nextRoute,
    this.nextLabel,
  });

  final String title; // name of the prototype screen
  final String screenCode; // S1 ... S6
  final String? nextRoute; // route opened by the temporary button
  final String? nextLabel; // text on the temporary button

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        // The back arrow appears automatically when a screen was pushed.
        appBar: AppBar(title: Text(title)),
        body: Column(
          children: [
            Expanded(
              child: PlaceholderPage(
                title: title,
                screenCode: screenCode,
                owner: 'Guard owner',
              ),
            ),
            // Temporary button so the flow can be clicked through.
            if (nextRoute != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, nextRoute!),
                  child: Text(nextLabel ?? 'Next'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}