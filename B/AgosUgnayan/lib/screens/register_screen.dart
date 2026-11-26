// Register form: name, email, password, role (farmer or buyer) and town,
// plus the privacy notice the user must agree to (RA 10173).

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../utils/app_exception.dart';
import '../utils/constants.dart';
import '../utils/snackbars.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import '../widgets/dropdown_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/notice_box.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive_body.dart';
import 'home_screen.dart';

/// Creates a new farmer or buyer account.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = UserRole.farmer;
  String? _town = 'Leon';
  bool _agreed = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      showError(context, 'Please agree to the privacy notice to continue.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService().register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: _role,
        town: _town!,
      );
      if (!mounted) return;
      // Remove Login and Register from the back stack: go straight home.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showError(context, friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Form(
        key: _formKey,
        child: ResponsiveBody(
          maxWidth: AppSizes.maxFormWidth,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              const PageHeader(
                eyebrow: 'New account',
                title: 'Join AgosUgnayan',
                lead: 'It takes one minute. You can change your town later.',
              ),
              const SizedBox(height: AppSizes.sectionGap),
              const Text(
                'I am a…',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSizes.small),
              // Two big cards to pick the role, like the website.
              Row(
                children: [
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.agriculture,
                      title: 'Farmer',
                      description: 'I grow and sell crops.',
                      isSelected: _role == UserRole.farmer,
                      onTap: () => setState(() => _role = UserRole.farmer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.shopping_basket_outlined,
                      title: 'Buyer',
                      description: 'I buy crops for my store or business.',
                      isSelected: _role == UserRole.buyer,
                      onTap: () => setState(() => _role = UserRole.buyer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sectionGap),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  hintText: 'e.g. Pedro Santos',
                ),
                textCapitalization: TextCapitalization.words,
                validator: Validators.name,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: Validators.password,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                obscureText: true,
                // Compare with whatever is in the password field right now.
                validator: (value) =>
                    Validators.matches(_passwordController.text)(value),
              ),
              const SizedBox(height: AppSizes.fieldGap),
              DropdownField(
                label: 'Town',
                items: kTowns,
                value: _town,
                onChanged: (value) => setState(() => _town = value),
              ),
              const SizedBox(height: AppSizes.sectionGap),
              const NoticeBox(
                kind: NoticeKind.info,
                message:
                    'AgosUgnayan saves your name, email and town so buyers and '
                    'farmers can find and message you. We do not share them '
                    'with anyone else. (Data Privacy Act, RA 10173)',
              ),
              CheckboxListTile(
                value: _agreed,
                onChanged: (value) => setState(() => _agreed = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I agree to the privacy notice above.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: AppSizes.small),
              LoadingButton(
                label: 'Create account',
                isLoading: _isLoading,
                onPressed: _register,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable card for picking Farmer or Buyer (website .rolecard).
/// The selected card gets a green border and a light green background.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? AppColors.primaryLight : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.line,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primaryLight,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: isSelected ? Colors.white : AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: AppTextStyles.meta),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
