import 'package:flutter/material.dart';

import '../../auth/customer_auth_strings.dart';
import '../../auth/customer_auth_validators.dart';
import '../../services/customer_auth_service.dart';
import '../../widgets/auth/auth_page_shell.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.service,
    this.onAuthenticated,
    this.onLocaleSelected,
    this.initialError,
    this.initialSuccessMessage,
  });

  final CustomerAuthService? service;
  final VoidCallback? onAuthenticated;
  final ValueChanged<String>? onLocaleSelected;
  final Object? initialError;
  final String? initialSuccessMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final CustomerAuthService _service;
  bool _loading = false;
  bool _passwordVisible = false;
  bool _submitted = false;
  Object? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SupabaseCustomerAuthService();
    _error = widget.initialError;
    _successMessage = widget.initialSuccessMessage;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _submitted = true;
      _error = null;
      _successMessage = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _service.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      widget.onAuthenticated?.call();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openRegistration() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterPage(
          service: _service,
          onAuthenticated: widget.onAuthenticated,
        ),
      ),
    );
  }

  void _openPasswordReset() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(service: _service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = CustomerAuthStrings.of(context);
    return AuthPageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onLocaleSelected != null) ...[
            Align(
              alignment: Alignment.centerRight,
              child: _LoginLanguageSelector(
                selectedLanguageCode:
                    Localizations.localeOf(context).languageCode,
                semanticLabel: strings.languageSelector,
                onSelected: widget.onLocaleSelected,
              ),
            ),
            const SizedBox(height: 12),
          ],
          AutofillGroup(
            child: Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: AuthCard(
                children: [
                  AuthPageHeader(
                    title: strings.welcomeTitle,
                    subtitle: strings.welcomeSubtitle,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    AuthErrorBanner(message: strings.errorFor(_error!)),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 20),
                    AuthSuccessBanner(message: _successMessage!),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('login_email'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: strings.email,
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) => CustomerAuthValidators.email(
                      value,
                      requiredMessage: strings.requiredField,
                      invalidMessage: strings.invalidEmail,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('login_password'),
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _loading ? null : _login(),
                    decoration: InputDecoration(
                      labelText: strings.password,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                        tooltip: _passwordVisible
                            ? strings.hidePassword
                            : strings.showPassword,
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => CustomerAuthValidators.requiredValue(
                      value,
                      strings.requiredField,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _openPasswordReset,
                      child: Text(strings.forgotPassword),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FilledButton(
                    key: const Key('login_submit'),
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(strings.signIn),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(strings.noAccount),
                      TextButton(
                        onPressed: _loading ? null : _openRegistration,
                        child: Text(strings.register),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginLanguageSelector extends StatelessWidget {
  const _LoginLanguageSelector({
    required this.selectedLanguageCode,
    required this.semanticLabel,
    required this.onSelected,
  });

  final String selectedLanguageCode;
  final String semanticLabel;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    const languages = <String>['it', 'de', 'fr', 'en'];
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        key: const Key('login_language_selector'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < languages.length; index++) ...[
              if (index > 0)
                const Text(
                  '|',
                  style: TextStyle(color: Color(0xFFCBD5E1)),
                ),
              _LanguageButton(
                languageCode: languages[index],
                selected: selectedLanguageCode == languages[index],
                onPressed: onSelected == null
                    ? null
                    : () => onSelected!(languages[index]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.languageCode,
    required this.selected,
    required this.onPressed,
  });

  final String languageCode;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: Key('login_language_$languageCode'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : const Color(0xFF64748B),
        textStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      child: Text(languageCode.toUpperCase()),
    );
  }
}
