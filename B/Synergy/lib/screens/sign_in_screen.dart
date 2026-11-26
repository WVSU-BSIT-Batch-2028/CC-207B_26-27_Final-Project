import 'package:flutter/material.dart';

import '../app_store.dart';

// One screen for both signing in and registering
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registering = false; // false = Sign in, true = Register
  bool _busy = false; // true while signing in or registering
  String? _error; // message shown above the button

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = _registering
        ? await widget.store.register(_name.text, _email.text, _password.text)
        : widget.store.signIn(_email.text, _password.text);

    // On success the app switches screens, so this one may be gone
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error = _registering
            ? 'An account with this email already exists'
            : 'Wrong email or password';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final action = _registering ? 'Register' : 'Sign in';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/synergy-logo.png', height: 64),
                      const SizedBox(height: 12),
                      Text(
                        'Synergy',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),

                      // Switch between Sign in and Register
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Sign in')),
                          ButtonSegment(value: true, label: Text('Register')),
                        ],
                        selected: {_registering},
                        onSelectionChanged: _busy
                            ? null
                            : (s) => setState(() {
                                _registering = s.first;
                                _error = null;
                              }),
                      ),
                      const SizedBox(height: 20),

                      if (_registering) ...[
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Startup name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Enter your startup name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').contains('@')
                            ? null
                            : 'Enter a valid email',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').length >= 6
                            ? null
                            : 'Use at least 6 characters',
                        onFieldSubmitted: (_) => _submit(), // Enter key
                      ),
                      const SizedBox(height: 16),

                      if (_error != null) ...[
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error),
                        ),
                        const SizedBox(height: 12),
                      ],

                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(action),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Demo-only sign-in: use a dummy password.\n'
                        'Sample: budgetbuddy@demo.test · demo123',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
