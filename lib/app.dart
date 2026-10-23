import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

/// Root widget: applies the light/dark theme and the named-route table.
class Health360App extends StatelessWidget {
  const Health360App({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild when the user switches theme in Settings > App Theme.
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final controller = ThemeController.instance;
        return MaterialApp(
          title: 'Health360',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: controller.mode,
          initialRoute: AppRoutes.initialRoute,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          // Status-bar icons: dark on light mode, light on dark mode.
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: controller.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
