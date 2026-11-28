import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/brand_logo.dart';

/// Validates a caregiver email input for sign-in and registration forms.
String? validateAuthEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your email.';
  }
  if (!value.contains('@')) {
    return 'Please enter a valid email address.';
  }
  return null;
}

/// Validates a caregiver password input.
///
/// When [minLength] is greater than zero, enforces a minimum character count.
String? validateAuthPassword(String? value, {int minLength = 0}) {
  if (value == null || value.isEmpty) {
    return minLength > 0
        ? 'Password must be at least $minLength characters.'
        : 'Please enter your password.';
  }
  if (minLength > 0 && value.length < minLength) {
    return 'Password must be at least $minLength characters.';
  }
  return null;
}

/// Shared responsive layout for authentication screens.
///
/// Renders a centered single-column layout on compact viewports and a two-pane
/// brand-and-form split layout on viewports wider than
/// [AppSizes.wideLayoutBreakpoint].
class AuthResponsiveLayout extends StatelessWidget {
  /// Creates an [AuthResponsiveLayout].
  const AuthResponsiveLayout({
    super.key,
    required this.panelTitle,
    required this.panelSubtitle,
    required this.panelHighlights,
    required this.card,
    this.footer,
    this.showCompactBrand = true,
    this.compactMaxWidth = 440,
    this.wideFormMaxWidth = 440,
  });

  /// Heading shown in the wide-viewport brand panel.
  final String panelTitle;

  /// Supporting copy shown in the wide-viewport brand panel.
  final String panelSubtitle;

  /// Key points rendered beneath [panelSubtitle] on wide viewports.
  final List<String> panelHighlights;

  /// Primary form or status card displayed in the main content area.
  final Widget card;

  /// Optional navigation footer displayed below [card].
  final Widget? footer;

  /// Whether to render the compact brand lockup above [card] on narrow screens.
  final bool showCompactBrand;

  /// Maximum width of the centered column on compact viewports.
  final double compactMaxWidth;

  /// Maximum width of the centered form column on wide viewports.
  final double wideFormMaxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppSizes.wideLayoutBreakpoint) {
            return _buildWide(theme, constraints);
          }
          return _buildCompact(theme, constraints);
        },
      ),
    );
  }

  Widget _buildCompact(ThemeData theme, BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space24,
        vertical: AppSpacing.space16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - (AppSpacing.space16 * 2)).clamp(
            0.0,
            double.infinity,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compactMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showCompactBrand) ...[
                  const Center(child: GrowthSymbol(size: 48)),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    'LittleSteps',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    'Small steps. Brighter tomorrows.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space20),
                ],
                card,
                if (footer != null) ...[
                  const SizedBox(height: AppSpacing.space16),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWide(ThemeData theme, BoxConstraints constraints) {
    final panelWidth = (constraints.maxWidth * 0.40).clamp(340.0, 460.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: panelWidth,
          decoration: const BoxDecoration(
            color: AppColors.cream,
            border: Border(right: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.space32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 72).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandLogo(symbolSize: 38, showTagline: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.space24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          panelTitle,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space12),
                        Text(
                          panelSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space20),
                        for (final item in panelHighlights)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.space8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(
                                    top: AppSpacing.space4 / 2,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: AppColors.forest,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.space8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Center(child: ParentChildIllustration(height: 168)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: AppColors.surfaceCard,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space32,
                vertical: AppSpacing.space24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - (AppSpacing.space24 * 2))
                      .clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wideFormMaxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        card,
                        if (footer != null) ...[
                          const SizedBox(height: AppSpacing.space16),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Elevated white surface card wrapping authentication forms and status views.
class AuthFormCard extends StatelessWidget {
  /// Creates an [AuthFormCard] containing [child].
  const AuthFormCard({super.key, required this.child});

  /// Content displayed inside the card.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.shadowSubtle,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Visual tone for [AuthMessageBanner].
enum AuthMessageTone {
  /// Informational notice styling (e.g., expired session reminder).
  notice,

  /// Error feedback styling (e.g., invalid credentials or validation block).
  error,
}

/// Accessible live-region banner for authentication notices and errors.
class AuthMessageBanner extends StatelessWidget {
  /// Creates an [AuthMessageBanner] displaying [message] with [tone].
  const AuthMessageBanner({
    super.key,
    required this.message,
    required this.tone,
  });

  /// Banner text shown to the caregiver.
  final String message;

  /// Visual tone controlling surface, border, and icon colors.
  final AuthMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = tone == AuthMessageTone.error;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space12),
        decoration: BoxDecoration(
          color: isError ? AppColors.surfaceError : AppColors.surfaceAdvisory,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: isError ? AppColors.borderError : AppColors.borderAdvisory,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              size: 20,
              color: isError ? AppColors.error : AppColors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isError ? AppColors.textError : AppColors.textPrimary,
                  fontWeight: isError ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standardized email input field for authentication forms.
class AuthEmailField extends StatelessWidget {
  /// Creates an [AuthEmailField] bound to [controller].
  const AuthEmailField({super.key, required this.controller});

  /// Controller for the email text value.
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      enableInteractiveSelection: true,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'you@example.com',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: validateAuthEmail,
    );
  }
}

/// Standardized password input field with visibility toggle and validation.
class AuthPasswordField extends StatelessWidget {
  /// Creates an [AuthPasswordField] bound to [controller].
  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.showPassword,
    required this.onToggleVisibility,
    required this.onSubmitted,
    this.autofillHint = AutofillHints.password,
    this.helperText,
    this.minLength = 0,
  });

  /// Controller for the password text value.
  final TextEditingController controller;

  /// Whether the password characters are currently visible.
  final bool showPassword;

  /// Callback toggling password visibility.
  final VoidCallback onToggleVisibility;

  /// Callback invoked when the keyboard done action is triggered.
  final VoidCallback onSubmitted;

  /// Platform autofill hint for the password field.
  final String autofillHint;

  /// Optional concise helper text shown below the input.
  final String? helperText;

  /// Minimum character count enforced by validation (`0` requires non-empty).
  final int minLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      textInputAction: TextInputAction.done,
      enableInteractiveSelection: true,
      autofillHints: [autofillHint],
      onFieldSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        labelText: 'Password',
        helperText: helperText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: Semantics(
          label: showPassword ? 'Hide password' : 'Show password',
          child: IconButton(
            icon: Icon(
              showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: onToggleVisibility,
          ),
        ),
      ),
      validator: (value) => validateAuthPassword(value, minLength: minLength),
    );
  }
}

/// Primary 48 dp submit button with loading indicator for authentication forms.
class AuthSubmitButton extends StatelessWidget {
  /// Creates an [AuthSubmitButton] with [label] and [onPressed].
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  /// Button label shown when [loading] is false.
  final String label;

  /// Callback invoked when tapped while not loading.
  final VoidCallback? onPressed;

  /// Whether a submission is currently in progress.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.touchTarget,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.surfaceCard,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Centered footer prompt linking between sign-in and account registration.
class AuthAccountFooter extends StatelessWidget {
  /// Creates an [AuthAccountFooter].
  const AuthAccountFooter({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onPressed,
  });

  /// Leading prompt text (e.g., "New to LittleSteps?").
  final String prompt;

  /// Action link text (e.g., "Create account").
  final String actionLabel;

  /// Callback invoked when the action link is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.space4,
      children: [
        Text(
          prompt,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          ),
          onPressed: onPressed,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

/// Compact privacy summary and acceptance checkbox shown before registration.
class AuthPrivacyNoticeCard extends StatelessWidget {
  /// Creates an [AuthPrivacyNoticeCard].
  const AuthPrivacyNoticeCard({
    super.key,
    required this.points,
    required this.accepted,
    required this.onChanged,
    this.contactTitle,
    this.contactDomain,
    this.onContactTap,
  });

  /// Ordered privacy summary headings and descriptions.
  final List<MapEntry<String, String>> points;

  /// Whether the caregiver has checked the privacy confirmation box.
  final bool accepted;

  /// Callback invoked when the acceptance checkbox changes.
  final ValueChanged<bool> onChanged;

  /// Optional contact organization title shown beneath [points].
  final String? contactTitle;

  /// Optional domain caption shown beneath [contactTitle].
  final String? contactDomain;

  /// Optional callback invoked when the caregiver taps the contact link tile.
  final VoidCallback? onContactTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCanvas,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 18,
                color: AppColors.forest,
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  'Privacy Notice',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space8),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.key,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    point.value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          if (contactTitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Semantics(
                    link: true,
                    hint: 'Opens external website',
                    child: Material(
                      color: AppColors.surfaceCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        side: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        dense: true,
                        minTileHeight: AppSizes.touchTarget,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space12,
                          vertical: AppSpacing.space4,
                        ),
                        title: Text(
                          contactTitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: contactDomain != null
                            ? Text(
                                contactDomain!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.forest,
                                ),
                              )
                            : null,
                        trailing: const Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: AppColors.forest,
                        ),
                        onTap: onContactTap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: AppSpacing.space12),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: accepted,
              onChanged: (val) => onChanged(val ?? false),
              title: Text(
                'I have read the privacy summary above',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ],
      ),
    );
  }
}
