import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/paper_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.authService,
    required this.onLoggedIn,
    super.key,
  });

  final AuthService authService;
  final ValueChanged<AppSession> onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _role = UserRole.student;
  bool _isLoading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _studentIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  String? _validateStudentId(String? value) {
    final error = _requiredField(value, 'Student ID');
    if (error != null) return error;
    // Letters, numbers and dashes, 4 to 20 characters. Change if needed.
    if (!RegExp(r'^[A-Za-z0-9\-]{4,20}$').hasMatch(value!.trim())) {
      return 'Use 4-20 letters, numbers, or dashes.';
    }
    return null;
  }

  String? _validateStudentName(String? value) {
    final error = _requiredField(value, 'Name');
    if (error != null) return error;
    if (value!.trim().length > 80) {
      return 'Name must be 80 characters or fewer.';
    }
    return null;
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      default:
        return 'Could not sign in. Please try again.';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = _role == UserRole.student
          ? await widget.authService.signInStudent(
              studentId: _studentIdController.text,
              name: _nameController.text,
            )
          : await widget.authService.signInStaff(
              email: _emailController.text,
              password: _passwordController.text,
            );

      if (!mounted) return;
      widget.onLoggedIn(session);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyAuthError(e));
    } on StudentIdentityException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on StateError {
      if (!mounted) return;
      setState(() => _error = 'This account is not registered as staff.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not sign in. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = _role == UserRole.student;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Paper.ink, width: 1.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(8),
                ),
                boxShadow: const [
                  BoxShadow(color: Paper.ink, offset: Offset(5, 5)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('welcome to', style: Paper.hand(26)),
                    Text('MatchBack', style: Paper.display(36)),
                    const SizedBox(height: 6),
                    Text(
                      'Campus Lost and Found. Tell us who you are to continue.',
                      style: Paper.body(15),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<UserRole>(
                        segments: const [
                          ButtonSegment(
                            value: UserRole.student,
                            label: Text('Student'),
                            icon: Icon(Icons.school_outlined),
                          ),
                          ButtonSegment(
                            value: UserRole.staff,
                            label: Text('Staff'),
                            icon: Icon(Icons.admin_panel_settings_outlined),
                          ),
                        ],
                        selected: {_role},
                        onSelectionChanged: _isLoading
                            ? null
                            : (selection) {
                                setState(() {
                                  _role = selection.first;
                                  _error = null;
                                });
                              },
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isStudent) ...[
                      TextFormField(
                        controller: _studentIdController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Student ID',
                          hintText: 'Example: 2023-12345',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: _validateStudentId,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        enabled: !_isLoading,
                        maxLength: 80,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: _validateStudentName,
                      ),
                      const SizedBox(height: 12),
                      // Privacy notice (Data Privacy Act of 2012, RA 10173):
                      // tells students what is collected, who sees it, and why.
                      Text(
                        'Privacy notice: MatchBack collects your student ID '
                        'and your name to link your reports '
                        'and claims to you. When you submit a report or '
                        'claim, you also give a full name and an email or '
                        'phone number so staff can contact you about your '
                        'item. Only staff can see these contact details. '
                        'Report details and photos you submit are visible to '
                        'other signed-in users, but private details are not '
                        'shown to other students. Your data is used only for '
                        'campus lost-and-found. By continuing, you agree to '
                        'this use of your data.',
                        style: Paper.body(13),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Staff email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) => _requiredField(value, 'Email'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required.';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: Paper.body(14, color: Colors.red.shade700),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(_isLoading ? 'Signing in...' : 'Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
