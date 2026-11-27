//updated to connect to firestore - Joshua

//firebase
import 'package:final_project_look_out/widgets/loader.dart';
import 'package:final_project_look_out/widgets/popup_notif.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

//services
import '../../app/themes/app_colors.dart';
import '../../services/auth_service.dart';

// Pages
import '../home/admin_home_screen.dart';
import '../home/commuter_home_screen.dart';
import '../home/driver_home_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool isLoading = false;
  final _authService = AuthService();

  final _commuterFormKey = GlobalKey<FormState>();
  final _driverFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  final _commuterEmailCtrl = TextEditingController();
  final _commuterPassCtrl = TextEditingController();

  final _driverEmailCtrl = TextEditingController();
  final _driverPassCtrl = TextEditingController();

  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();

  String _signupRole = 'commuter';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _commuterEmailCtrl.dispose();
    _commuterPassCtrl.dispose();
    _driverEmailCtrl.dispose();
    _driverPassCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPassCtrl.dispose();

    super.dispose();
  }

  // LOGIN
  void _handleLogin({
    required GlobalKey<FormState> formKey,
    required String expectedRole,
    required String rawEmail,
    required String rawPassword,
  }) async {
    if (!formKey.currentState!.validate()) return;

    final email = rawEmail.trim().toLowerCase();
    final password = rawPassword.trim();

    setState(() => isLoading = true);
    try {
      final userData = await _authService.login(
        email: email,
        password: password,
        loginTab: expectedRole,
      );

      if (!mounted) return;

      _showMessage('Logged in successfully', 'Success', NotifType.success);

      if (userData == null) {
        await _authService.signOut();
        _showMessage("User Not FOund", 'Warning', NotifType.warning);
        return;
      }

      final String actualRole = userData['role'] ?? 'commuter';

      if (actualRole != 'admin' && actualRole != expectedRole) {
        _showMessage(
          "Wrong login tab. This account is registered as${actualRole.toUpperCase()}",
          'Warning',
          NotifType.warning,
        );
      }

      _navigateToDashboard(actualRole);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), 'Warning', NotifType.warning,);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Login failed. Please try again.', 'Error', NotifType.error,);
    } finally {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        setState(() => isLoading = false);
      }
    }
  }

  // SIGN UP
  void _handleSignup() async {
    if (!_signupFormKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      await _authService.signUp(
        email: _signupEmailCtrl.text.trim(),
        password: _signupPassCtrl.text.trim(),
        fullName: _signupNameCtrl.text.trim(),
        role: _signupRole,
      );

      await _authService.signOut();

      if (!mounted) return;

      _showMessage(
        'Registered as ${_signupRole.toUpperCase()}! You can now log in.',
        'Success',
        NotifType.success
      );

      _signupNameCtrl.clear();
      _signupEmailCtrl.clear();
      _signupPassCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), 'Error', NotifType.error);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // NAVIGATION
  void _navigateToDashboard(String role) {
    Navigator.pushReplacement(
      context,
      role == 'commuter'
          ? MaterialPageRoute(builder: (_) => CommuterHomeScreen())
          : role == 'driver'
          ? MaterialPageRoute(builder: (_) => DriverHomeScreen())
          : MaterialPageRoute(builder: (_) => AdminHomeScreen()),
    );
  }

  // NOTIFICATION
  void _showMessage(String text, String title, NotifType type,) {
    PopupNotif(message: text, title: title, type:type ).show(context);
  }

  // REUSABLE INPUT DECORATION
  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColor.primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
    );
  }

  // REUSABLE BLUE-TO-TEAL BUTTON
  Widget _gradientButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColor.primaryBlue, AppColor.secondaryTeal],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColor.surfaceLight,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }

  // MAIN BUILD
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColor.brandNavy,
        body: isLoading
            ? const Loader.circular()
            : SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        // LOOKOUT BANNER
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Image.asset(
                                'assets/images/lookOut!Banner.png',
                                width: double.infinity,
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                        ),

                        // AUTHENTICATION SECTION
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 440,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // AUTHENTICATION CARD
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: AppColor.secondaryTeal
                                              .withValues(alpha: 0.7),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.22,
                                            ),
                                            blurRadius: 22,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          // WELCOME TEXT
                                          Text(
                                            'Welcome!',
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: colors.onSurface,
                                                ),
                                          ),

                                          const SizedBox(height: 6),

                                          Text(
                                            'Log in or create an account to get started.',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),

                                          const SizedBox(height: 20),

                                          // ROLE AND SIGNUP TABS
                                          TabBar(
                                            labelColor: AppColor.surfaceLight,
                                            unselectedLabelColor:
                                                colors.onSurfaceVariant,
                                            indicatorSize:
                                                TabBarIndicatorSize.tab,
                                            indicator: BoxDecoration(
                                              color: AppColor.primaryBlue,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            dividerColor: Colors.transparent,
                                            labelStyle: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            unselectedLabelStyle:
                                                const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                            tabs: const [
                                              Tab(
                                                icon: Icon(
                                                  Icons.person_outline,
                                                ),
                                                text: 'Commuter',
                                              ),
                                              Tab(
                                                icon: Icon(
                                                  Icons.directions_bus_outlined,
                                                ),
                                                text: 'Driver',
                                              ),
                                              Tab(
                                                icon: Icon(
                                                  Icons.person_add_outlined,
                                                ),
                                                text: 'Sign Up',
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 16),

                                          // TAB CONTENT
                                          SizedBox(
                                            height: 410,
                                            child: TabBarView(
                                              children: [
                                                // COMMUTER LOGIN
                                                _buildLoginForm(
                                                  formKey: _commuterFormKey,
                                                  roleLabel: 'Commuter',
                                                  expectedRole: 'commuter',
                                                  emailController:
                                                      _commuterEmailCtrl,
                                                  passwordController:
                                                      _commuterPassCtrl,
                                                ),

                                                // DRIVER LOGIN
                                                _buildLoginForm(
                                                  formKey: _driverFormKey,
                                                  roleLabel: 'Driver',
                                                  expectedRole: 'driver',
                                                  emailController:
                                                      _driverEmailCtrl,
                                                  passwordController:
                                                      _driverPassCtrl,
                                                ),

                                                // SIGNUP
                                                _buildSignupForm(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    // FOOTER
                                    Text(
                                      'MADE FOR ILOILO CITY',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColor.surfaceLight
                                                .withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  // LOGIN FORM
  Widget _buildLoginForm({
    required GlobalKey<FormState> formKey,
    required String roleLabel,
    required String expectedRole,
    required TextEditingController emailController,
    required TextEditingController passwordController,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$roleLabel Login',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Enter your account details to continue.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 20),

          // EMAIL
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(
              context,
              label: 'Email',
              icon: Icons.email_outlined,
            ),
            validator: (val) => (val == null || !val.contains('@'))
                ? 'Enter a valid email'
                : null,
          ),

          const SizedBox(height: 16),

          // PASSWORD
          TextFormField(
            controller: passwordController,
            obscureText: _obscurePassword,
            decoration:
                _inputDecoration(
                  context,
                  label: 'Password',
                  icon: Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
            validator: (val) =>
                (val == null || val.isEmpty) ? 'Enter your password' : null,
          ),

          const SizedBox(height: 24),

          // LOGIN BUTTON
          _gradientButton(
            label: 'Log In as $roleLabel',
            onPressed: () => _handleLogin(
              formKey: formKey,
              expectedRole: expectedRole,
              rawEmail: emailController.text,
              rawPassword: passwordController.text,
            ),
          ),
        ],
      ),
    );
  }

  // SIGNUP FORM
  Widget _buildSignupForm() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Form(
      key: _signupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create an Account',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Choose your account type and enter your details.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          // ROLE SELECTION
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'commuter',
                label: Text('Commuter'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: 'driver',
                label: Text('Driver'),
                icon: Icon(Icons.directions_bus_outlined),
              ),
            ],
            selected: {_signupRole},
            onSelectionChanged: (selection) {
              setState(() {
                _signupRole = selection.first;
              });
            },
          ),

          const SizedBox(height: 16),

          // FULL NAME
          TextFormField(
            controller: _signupNameCtrl,
            decoration: _inputDecoration(
              context,
              label: 'Full Name',
              icon: Icons.badge_outlined,
            ),
            validator: (val) =>
                (val == null || val.trim().isEmpty) ? 'Enter your name' : null,
          ),

          const SizedBox(height: 12),

          // EMAIL
          TextFormField(
            controller: _signupEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(
              context,
              label: 'Email',
              icon: Icons.email_outlined,
            ),
            validator: (val) => (val == null || !val.contains('@'))
                ? 'Enter a valid email'
                : null,
          ),

          const SizedBox(height: 12),

          // PASSWORD
          TextFormField(
            controller: _signupPassCtrl,
            obscureText: _obscurePassword,
            decoration:
                _inputDecoration(
                  context,
                  label: 'Password (min 6 chars)',
                  icon: Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
            validator: (val) =>
                (val == null || val.length < 6) ? 'Minimum 6 characters' : null,
          ),

          const SizedBox(height: 20),

          // CREATE ACCOUNT BUTTON
          _gradientButton(
            label:
                'Create ${_signupRole == 'commuter' ? 'Commuter' : 'Driver'} Account',
            onPressed: _handleSignup,
          ),
        ],
      ),
    );
  }
}
