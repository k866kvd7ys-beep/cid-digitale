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
    this.initialError,
  });

  final CustomerAuthService? service;
  final VoidCallback? onAuthenticated;
  final Object? initialError;

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

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SupabaseCustomerAuthService();
    _error = widget.initialError;
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
      child: AutofillGroup(
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
    );
  }
}
