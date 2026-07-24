import 'package:flutter/material.dart';

import '../../auth/customer_auth_strings.dart';
import '../../auth/customer_auth_validators.dart';
import '../../services/customer_auth_service.dart';
import '../../widgets/auth/auth_page_shell.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.service,
  });

  final CustomerAuthService service;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _submitted = false;
  bool _sent = false;
  Object? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await widget.service.sendPasswordReset(_emailController.text);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = CustomerAuthStrings.of(context);
    if (_sent) {
      return AuthPageShell(
        child: AuthSuccessState(
          title: strings.resetSentTitle,
          message: strings.resetSentBody,
          actionLabel: strings.backToLogin,
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    return AuthPageShell(
      child: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: AuthCard(
          children: [
            AuthPageHeader(
              title: strings.resetTitle,
              subtitle: strings.resetSubtitle,
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              AuthErrorBanner(message: strings.errorFor(_error!)),
            ],
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('reset_email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onFieldSubmitted: (_) => _loading ? null : _send(),
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
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const Key('reset_submit'),
              onPressed: _loading ? null : _send,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.outgoing_mail),
              label: Text(strings.sendReset),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(),
              child: Text(strings.backToLogin),
            ),
          ],
        ),
      ),
    );
  }
}
