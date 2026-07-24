import 'package:flutter/material.dart';

import '../../auth/customer_auth_strings.dart';
import '../../auth/customer_auth_validators.dart';
import '../../models/customer_profile.dart';
import '../../services/customer_auth_service.dart';
import '../../widgets/auth/auth_page_shell.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({
    super.key,
    required this.service,
    required this.account,
    required this.isOnboarding,
    this.initialProfile,
    this.onSaved,
  });

  final CustomerAuthService service;
  final CustomerAccount account;
  final CustomerProfile? initialProfile;
  final bool isOnboarding;
  final ValueChanged<CustomerProfile>? onSaved;

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _streetController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _phoneController;
  String _title = '';
  bool _saving = false;
  bool _submitted = false;
  bool _saved = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _title =
        {'mr', 'mrs', 'other'}.contains(profile?.title) ? profile!.title : '';
    _firstNameController = TextEditingController(
      text: profile?.firstName ?? widget.account.firstName,
    );
    _lastNameController = TextEditingController(
      text: profile?.lastName ?? widget.account.lastName,
    );
    _streetController = TextEditingController(text: profile?.street ?? '');
    _postalCodeController =
        TextEditingController(text: profile?.postalCode ?? '');
    _cityController = TextEditingController(text: profile?.city ?? '');
    _countryController = TextEditingController(text: profile?.country ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _streetController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
      _saved = false;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final saved = await widget.service.saveProfile(
        CustomerProfile(
          userId: widget.account.id,
          title: _title,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          street: _streetController.text,
          postalCode: _postalCodeController.text,
          city: _cityController.text,
          country: _countryController.text,
          phone: _phoneController.text,
          email: widget.account.email,
          profileCompleted: true,
          createdAt: widget.initialProfile?.createdAt,
        ),
      );
      if (!mounted) return;
      setState(() => _saved = true);
      widget.onSaved?.call(saved);
      if (!widget.isOnboarding) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CustomerAuthStrings.of(context).profileSaved),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field({
    required Widget child,
    required double width,
  }) {
    return SizedBox(width: width, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final strings = CustomerAuthStrings.of(context);
    final content = AuthCard(
      children: [
        AuthPageHeader(
          title: widget.isOnboarding
              ? strings.profileSetupTitle
              : strings.profileEditTitle,
          subtitle: strings.profileSetupSubtitle,
        ),
        if (_error != null) ...[
          const SizedBox(height: 20),
          AuthErrorBanner(message: strings.errorFor(_error!)),
        ],
        if (_saved && widget.isOnboarding) ...[
          const SizedBox(height: 20),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF15803D),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.profileSaved,
                      style: const TextStyle(
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 14.0;
              final twoColumns = constraints.maxWidth >= 600;
              final fieldWidth = twoColumns
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _field(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      key: const Key('profile_title'),
                      initialValue: _title,
                      decoration: InputDecoration(labelText: strings.title),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('—')),
                        DropdownMenuItem(
                          value: 'mr',
                          child: Text(strings.titleMr),
                        ),
                        DropdownMenuItem(
                          value: 'mrs',
                          child: Text(strings.titleMrs),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text(strings.titleOther),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _title = value ?? ''),
                    ),
                  ),
                  _field(
                    width: fieldWidth,
                    child: TextFormField(
                      key: const Key('profile_first_name'),
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: strings.firstName),
                      validator: (value) =>
                          CustomerAuthValidators.requiredValue(
                        value,
                        strings.requiredField,
                      ),
                    ),
                  ),
                  _field(
                    width: fieldWidth,
                    child: TextFormField(
                      key: const Key('profile_last_name'),
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: strings.lastName),
                      validator: (value) =>
                          CustomerAuthValidators.requiredValue(
                        value,
                        strings.requiredField,
                      ),
                    ),
                  ),
                  _field(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _streetController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.streetAddressLine1],
                      decoration: InputDecoration(labelText: strings.street),
                    ),
                  ),
                  _field(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _postalCodeController,
                      keyboardType: TextInputType.streetAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.postalCode],
                      decoration:
                          InputDecoration(labelText: strings.postalCode),
                    ),
                  ),
                  _field(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.addressCity],
                      decoration: InputDecoration(labelText: strings.city),
                    ),
                  ),
                  _field(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _countryController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.countryName],
                      decoration: InputDecoration(labelText: strings.country),
                    ),
                  ),
                  _field(
                    width: fieldWidth,
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: InputDecoration(labelText: strings.phone),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: TextFormField(
                      initialValue: widget.account.email,
                      readOnly: true,
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        labelText: strings.accountEmail,
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('profile_save'),
          onPressed: _saving ? null : _save,
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
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? strings.saving : strings.saveProfile),
        ),
      ],
    );

    if (widget.isOnboarding) {
      return PopScope(
        canPop: false,
        child: AuthPageShell(maxWidth: 760, child: content),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(strings.profileEditTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
