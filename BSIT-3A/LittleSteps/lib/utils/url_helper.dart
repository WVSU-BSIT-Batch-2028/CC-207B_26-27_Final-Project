import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches an external [url] in the system browser.
Future<void> openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return;
  var launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!launched && context.mounted) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}
