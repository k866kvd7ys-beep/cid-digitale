import 'package:flutter/material.dart';

import '../../auth/customer_auth_strings.dart';
import '../../auth/customer_auth_validators.dart';
import '../../services/customer_auth_service.dart';
import '../../widgets/auth/auth_page_shell.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    super.key,
    required this.service,
    required this.onCompleted,
  });

  final CustomerAuthService service;
  final Future<void> Function() onCompleted;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmationVisible = false;
  bool _submitted = false;
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.service.updatePassword(_passwordController.text);
      await widget.onCompleted();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                title: strings.newPasswordTitle,
                subtitle: strings.newPasswordSubtitle,
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                AuthErrorBanner(message: strings.errorFor(_error!)),
              ],
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('recovery_password'),
                controller: _passwordController,
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: strings.newPassword,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: _saving
                        ? null
                        : () => setState(
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
                validator: (value) => CustomerAuthValidators.password(
                  value,
                  requiredMessage: strings.requiredField,
                  tooShortMessage: strings.passwordTooShort,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('recovery_password_confirmation'),
                controller: _confirmationController,
                obscureText: !_confirmationVisible,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _saving ? null : _savePassword(),
                decoration: InputDecoration(
                  labelText: strings.confirmNewPassword,
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    onPressed: _saving
                        ? null
                        : () => setState(
                              () =>
                                  _confirmationVisible = !_confirmationVisible,
                            ),
                    tooltip: _confirmationVisible
                        ? strings.hidePassword
                        : strings.showPassword,
                    icon: Icon(
                      _confirmationVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) =>
                    CustomerAuthValidators.passwordConfirmation(
                  value,
                  password: _passwordController.text,
                  requiredMessage: strings.requiredField,
                  mismatchMessage: strings.passwordMismatch,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                key: const Key('recovery_submit'),
                onPressed: _saving ? null : _savePassword,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.password_rounded),
                label: Text(strings.saveNewPassword),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InvalidPasswordRecoveryPage extends StatelessWidget {
  const InvalidPasswordRecoveryPage({
    super.key,
    required this.onRequestNewEmail,
  });

  final VoidCallback onRequestNewEmail;

  @override
  Widget build(BuildContext context) {
    final strings = CustomerAuthStrings.of(context);
    return AuthPageShell(
      child: AuthCard(
        children: [
          AuthPageHeader(
            title: strings.resetTitle,
            subtitle: strings.recoveryLinkInvalid,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('recovery_request_new_email'),
            onPressed: onRequestNewEmail,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            icon: const Icon(Icons.outgoing_mail),
            label: Text(strings.requestNewRecoveryEmail),
          ),
        ],
      ),
    );
  }
}
