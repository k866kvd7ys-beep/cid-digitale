import 'package:flutter/material.dart';

import '../../auth/customer_auth_strings.dart';
import '../../auth/customer_auth_validators.dart';
import '../../models/customer_legal_acceptance.dart';
import '../../screens/legal/legal_document_page.dart';
import '../../services/customer_auth_service.dart';
import '../../widgets/auth/auth_page_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.service,
    this.onAuthenticated,
  });

  final CustomerAuthService service;
  final VoidCallback? onAuthenticated;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmationVisible = false;
  bool _submitted = false;
  bool _legalAccepted = false;
  CustomerLegalAcceptance? _legalAcceptance;
  bool _awaitingEmailConfirmation = false;
  Object? _error;

  bool get _emailAlreadyRegistered =>
      _error is CustomerAuthException &&
      (_error as CustomerAuthException).code ==
          CustomerAuthErrorCode.emailAlreadyRegistered;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_loading) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final legalAcceptance =
        _legalAcceptance ??= CustomerLegalAcceptance.acceptedNow();

    setState(() => _loading = true);
    try {
      final result = await widget.service.signUp(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        legalAcceptance: legalAcceptance,
      );
      if (!mounted) return;
      if (result.emailConfirmationRequired) {
        setState(() => _awaitingEmailConfirmation = true);
      } else if (result.hasSession) {
        widget.onAuthenticated?.call();
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _legalAcceptanceField({
    required Key key,
    required bool value,
    required String prefix,
    required String privacyLinkLabel,
    required String middle,
    required String termsLinkLabel,
    required String suffix,
    required ValueChanged<bool> onChanged,
  }) {
    final strings = CustomerAuthStrings.of(context);
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF334155),
          height: 1.35,
        );
    return FormField<bool>(
      key: key,
      initialValue: value,
      validator: (accepted) =>
          accepted == true ? null : strings.legalAcceptanceRequired,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Checkbox(
                    value: value,
                    onChanged: _loading
                        ? null
                        : (checked) {
                            final accepted = checked ?? false;
                            onChanged(accepted);
                            field.didChange(accepted);
                          },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('$prefix ', style: textStyle),
                        TextButton(
                          onPressed: () => openLegalDocument(
                            context,
                            LegalDocumentType.privacyPolicy,
                          ),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            privacyLinkLabel,
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(' $middle ', style: textStyle),
                        TextButton(
                          onPressed: () => openLegalDocument(
                            context,
                            LegalDocumentType.termsOfUse,
                          ),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            termsLinkLabel,
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (suffix.isNotEmpty) Text(suffix, style: textStyle),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (field.errorText != null)
              Padding(
                padding: const EdgeInsets.only(left: 52, top: 2),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = CustomerAuthStrings.of(context);
    if (_awaitingEmailConfirmation) {
      return AuthPageShell(
        child: AuthSuccessState(
          title: strings.confirmationTitle,
          message: strings.confirmationBody,
          actionLabel: strings.backToLogin,
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    return AuthPageShell(
      maxWidth: 560,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: AuthCard(
            children: [
              AuthPageHeader(
                title: strings.registrationTitle,
                subtitle: strings.registrationSubtitle,
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                AuthErrorBanner(message: strings.errorFor(_error!)),
                if (_emailAlreadyRegistered) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('register_existing_account_login'),
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(strings.signInAndCompleteCustomerProfile),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('register_first_name'),
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                decoration: InputDecoration(labelText: strings.firstName),
                validator: (value) => CustomerAuthValidators.requiredValue(
                  value,
                  strings.requiredField,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register_last_name'),
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                decoration: InputDecoration(labelText: strings.lastName),
                validator: (value) => CustomerAuthValidators.requiredValue(
                  value,
                  strings.requiredField,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register_email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: InputDecoration(labelText: strings.email),
                validator: (value) => CustomerAuthValidators.email(
                  value,
                  requiredMessage: strings.requiredField,
                  invalidMessage: strings.invalidEmail,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register_password'),
                controller: _passwordController,
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: strings.password,
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
                validator: (value) => CustomerAuthValidators.password(
                  value,
                  requiredMessage: strings.requiredField,
                  tooShortMessage: strings.passwordTooShort,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register_password_confirmation'),
                controller: _confirmationController,
                obscureText: !_confirmationVisible,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _loading ? null : _register(),
                decoration: InputDecoration(
                  labelText: strings.confirmPassword,
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _confirmationVisible = !_confirmationVisible,
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
              const SizedBox(height: 18),
              _legalAcceptanceField(
                key: const Key('register_legal_acceptance'),
                value: _legalAccepted,
                prefix: strings.legalAcceptancePrefix,
                privacyLinkLabel: strings.privacyPolicy,
                middle: strings.legalAcceptanceMiddle,
                termsLinkLabel: strings.termsOfUse,
                suffix: strings.legalAcceptanceSuffix,
                onChanged: (value) => setState(() => _legalAccepted = value),
              ),
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('register_submit'),
                onPressed: _loading ? null : _register,
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
                    : Text(strings.register),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(strings.haveAccount),
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(),
                    child: Text(strings.signIn),
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
