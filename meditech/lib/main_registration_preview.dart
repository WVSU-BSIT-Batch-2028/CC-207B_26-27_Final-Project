import 'package:flutter/material.dart';

import 'app/bootstrap.dart';
import 'screens/pharmacy/registration/registration_screen.dart';
import 'widgets/theme/app_theme.dart';

// Temporary: opens the registration form directly for testing
void main() => bootstrap(MaterialApp(
      theme: AppTheme.light,
      home: const RegistrationScreen(),
    ));