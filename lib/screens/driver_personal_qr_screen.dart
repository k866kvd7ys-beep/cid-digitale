import 'dart:async';
import 'dart:convert';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/driver_personal_qr_data.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _QrPreviewState {
  empty,
  draftSaved,
  needsUpdate,
  ready,
}

class _ResponsiveFieldItem {
  const _ResponsiveFieldItem({
    required this.child,
    this.fullWidth = false,
  });

  final Widget child;
  final bool fullWidth;
}

class DriverPersonalQrScreen extends StatefulWidget {
  const DriverPersonalQrScreen({super.key});

  @override
  State<DriverPersonalQrScreen> createState() => _DriverPersonalQrScreenState();
}

class _DriverPersonalQrScreenState extends State<DriverPersonalQrScreen> {
  static const String _storageKey = 'driver_personal_qr_data_v1';
  static const String _generatedQrKey = 'driver_personal_qr_generated_v1';
  static const Color _pageBackground = Color(0xFFF3F6FB);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _cardShadow = Color(0x120F172A);
  static const Color _primaryBlue = Color(0xFF1D4ED8);
  static const Color _primaryBlueDark = Color(0xFF0F172A);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _successBackground = Color(0xFFECFDF3);
  static const Color _successForeground = Color(0xFF166534);
  static const Color _warningBackground = Color(0xFFFFF7ED);
  static const Color _warningForeground = Color(0xFF9A3412);
  static const Color _infoBackground = Color(0xFFEFF6FF);
  static const Color _infoForeground = Color(0xFF1D4ED8);
  static const Color _emptyBackground = Color(0xFFF8FAFC);
  static const Color _emptyForeground = Color(0xFF475569);

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _formAnchorKey = GlobalKey();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cognomeController = TextEditingController();
  final TextEditingController _indirizzoController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _targaController = TextEditingController();
  final TextEditingController _marcaController = TextEditingController();
  final TextEditingController _modelloController = TextEditingController();
  final TextEditingController _vinController = TextEditingController();
  final TextEditingController _kilometraggioController =
      TextEditingController();
  final TextEditingController _primaImmatricolazioneController =
      TextEditingController();
  final TextEditingController _assicurazioneController =
      TextEditingController();
  final TextEditingController _numeroPolizzaController =
      TextEditingController();
  final TextEditingController _numeroSinistroController =
      TextEditingController();

  DriverPersonalQrCourtesy? _courtesy;
  Timer? _persistDebounce;
  Future<void>? _draftPersistOperation;
  bool _profileLoaded = false;
  bool _isLoadingProfile = false;
  bool _hydrating = false;
  bool _deletingProfile = false;
  String? _qrPayload;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  List<TextEditingController> get _controllers => [
        _nomeController,
        _cognomeController,
        _indirizzoController,
        _zipController,
        _cityController,
        _countryController,
        _telefonoController,
        _emailController,
        _targaController,
        _marcaController,
        _modelloController,
        _vinController,
        _kilometraggioController,
        _primaImmatricolazioneController,
        _assicurazioneController,
        _numeroPolizzaController,
        _numeroSinistroController,
      ];

  DriverPersonalQrData get _draft => _buildDraftModel();

  String get _currentDraftJson => driverPersonalQrDataToJson(_draft);

  bool get _hasGeneratedQr => _qrPayload?.trim().isNotEmpty == true;

  bool get _hasSavedDraft => _draft.hasAnyValue;

  bool get _isQrDirty {
    final payload = _qrPayload?.trim();
    if (payload == null || payload.isEmpty) return false;
    return payload != _currentDraftJson;
  }

  bool get _isQrReady => _hasGeneratedQr && !_isQrDirty;

  bool get _canGenerateQr => _draft.hasMinimumData;

  _QrPreviewState get _previewState {
    if (_isQrReady) return _QrPreviewState.ready;
    if (_hasGeneratedQr && _isQrDirty) return _QrPreviewState.needsUpdate;
    if (_hasSavedDraft) return _QrPreviewState.draftSaved;
    return _QrPreviewState.empty;
  }

  @override
  void initState() {
    super.initState();
    _attachDraftListeners();
    unawaited(_loadSavedProfile());
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _scrollController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _attachDraftListeners() {
    for (final controller in _controllers) {
      controller.addListener(_handleDraftChanged);
    }
  }

  DriverPersonalQrData? _decodeSavedProfile(String? raw) {
    final source = raw?.trim() ?? '';
    if (source.isEmpty) return null;

    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return null;
      final data = DriverPersonalQrData.fromMap(
        Map<String, dynamic>.from(decoded),
      );
      return data.hasAnyValue ? data : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadSavedProfile() async {
    if (_profileLoaded || _isLoadingProfile) return;

    _isLoadingProfile = true;
    debugPrint('[PERSONAL_QR_STORAGE] load started');

    DriverPersonalQrData? restoredProfile;
    String? restoredQrPayload;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawProfile = prefs.getString(_storageKey)?.trim();
      final rawQr = prefs.getString(_generatedQrKey)?.trim();
      final profileKeyExists = rawProfile?.isNotEmpty == true;
      final qrKeyExists = rawQr?.isNotEmpty == true;

      debugPrint(
        '[PERSONAL_QR_STORAGE] profile key exists=$profileKeyExists',
      );
      debugPrint('[PERSONAL_QR_STORAGE] qr key exists=$qrKeyExists');

      final profileFromProfileKey = _decodeSavedProfile(rawProfile);
      final profileFromQrKey = _decodeSavedProfile(rawQr);
      restoredProfile = profileFromProfileKey ?? profileFromQrKey;

      if (profileFromQrKey != null && rawQr != null) {
        restoredQrPayload = rawQr;
      } else if (restoredProfile != null) {
        restoredQrPayload = driverPersonalQrDataToJson(restoredProfile);
        final qrSaved = await prefs.setString(
          _generatedQrKey,
          restoredQrPayload,
        );
        debugPrint('[PERSONAL_QR_STORAGE] save qr success=$qrSaved');
      }

      if (profileFromProfileKey == null && restoredProfile != null) {
        final profileSaved = await prefs.setString(
          _storageKey,
          driverPersonalQrDataToJson(restoredProfile),
        );
        debugPrint(
          '[PERSONAL_QR_STORAGE] save profile success=$profileSaved',
        );
      }

      if (!mounted) return;
      if (restoredProfile != null) {
        _hydrateDraft(restoredProfile);
      }

      setState(() {
        _qrPayload = restoredQrPayload;
        _profileLoaded = true;
        _isLoadingProfile = false;
      });
      debugPrint(
        '[PERSONAL_QR_STORAGE] profile restored=${restoredProfile != null}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileLoaded = true;
        _isLoadingProfile = false;
      });
      debugPrint('[PERSONAL_QR_STORAGE] profile key exists=false');
      debugPrint('[PERSONAL_QR_STORAGE] qr key exists=false');
      debugPrint('[PERSONAL_QR_STORAGE] profile restored=false');
    }
  }

  void _hydrateDraft(DriverPersonalQrData data) {
    _hydrating = true;
    _courtesy = data.courtesy;
    _nomeController.text = data.nome;
    _cognomeController.text = data.cognome;
    _indirizzoController.text = data.indirizzo;
    _zipController.text = data.zip;
    _cityController.text = data.city;
    _countryController.text = data.country;
    _telefonoController.text = data.telefono;
    _emailController.text = data.email;
    _targaController.text = data.targa;
    _marcaController.text = data.marca;
    _modelloController.text = data.modello;
    _vinController.text = data.vin;
    _kilometraggioController.text = data.kilometraggio;
    _primaImmatricolazioneController.text = data.primaImmatricolazione;
    _assicurazioneController.text = data.assicurazione;
    _numeroPolizzaController.text = data.numeroPolizza;
    _numeroSinistroController.text = data.numeroSinistro;
    _hydrating = false;
  }

  void _handleDraftChanged() {
    if (_hydrating || _isLoadingProfile || !_profileLoaded) return;
    if (mounted) {
      setState(() {});
    }
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 350), () {
      final previousOperation = _draftPersistOperation;
      _draftPersistOperation = () async {
        await previousOperation;
        await _persistDraft();
      }();
      unawaited(_draftPersistOperation);
    });
  }

  Future<void> _persistDraft() async {
    if (_isLoadingProfile || !_profileLoaded || !_draft.hasAnyValue) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_storageKey, _currentDraftJson);
      debugPrint('[PERSONAL_QR_STORAGE] save profile success=$success');
    } catch (_) {
      debugPrint('[PERSONAL_QR_STORAGE] save profile success=false');
    }
  }

  Future<void> _generateQr() async {
    final model = _draft;
    if (!model.hasMinimumData) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.driverPersonalQrMinimumHint)),
      );
      return;
    }

    bool? profileSaved;
    bool? qrSaved;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = _currentDraftJson;
      final wasUpdate = _hasGeneratedQr;
      profileSaved = await prefs.setString(_storageKey, payload);
      debugPrint(
        '[PERSONAL_QR_STORAGE] save profile success=$profileSaved',
      );
      if (!profileSaved) {
        throw StateError('Personal profile storage write failed');
      }

      qrSaved = await prefs.setString(_generatedQrKey, payload);
      debugPrint('[PERSONAL_QR_STORAGE] save qr success=$qrSaved');
      if (!qrSaved) {
        throw StateError('Personal QR storage write failed');
      }

      if (!mounted) return;
      setState(() => _qrPayload = payload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasUpdate
                ? _l10n.driverPersonalQrUpdateSuccess
                : _l10n.driverPersonalQrCreateSuccess,
          ),
        ),
      );
    } catch (_) {
      if (profileSaved == null) {
        debugPrint('[PERSONAL_QR_STORAGE] save profile success=false');
      }
      if (qrSaved == null) {
        debugPrint('[PERSONAL_QR_STORAGE] save qr success=false');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.driverPersonalQrSaveError)),
      );
    }
  }

  Future<void> _deleteProfile() async {
    if (_deletingProfile) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.driverPersonalQrDeleteProfileTitle),
        content: Text(_l10n.driverPersonalQrDeleteProfileMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(_l10n.driverPersonalQrDeleteProfileConfirm),
          ),
        ],
      ),
    );
    debugPrint('[PERSONAL_QR_STORAGE] delete confirmed=${confirmed == true}');
    if (confirmed != true || !mounted) return;

    setState(() => _deletingProfile = true);
    _persistDebounce?.cancel();

    try {
      await _draftPersistOperation;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      await prefs.remove(_generatedQrKey);

      _hydrateDraft(const DriverPersonalQrData.empty());
      if (!mounted) return;
      setState(() {
        _qrPayload = null;
        _deletingProfile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.driverPersonalQrDeleteProfileSuccess)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.driverPersonalQrDeleteProfileError)),
      );
    }
  }

  Future<void> _scrollToForm() async {
    final formContext = _formAnchorKey.currentContext;
    if (formContext == null) return;
    await Scrollable.ensureVisible(
      formContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _showQrFullscreenPreview() async {
    final payload = _qrPayload?.trim();
    if (payload == null || payload.isEmpty || !mounted) return;

    final qrSize =
        (MediaQuery.sizeOf(context).width - 48).clamp(240.0, 350.0).toDouble();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: _l10n.driverPersonalQrCloseFullscreen,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  right: 10,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(_l10n.driverPersonalQrCloseFullscreen),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: QrImageView(
                            data: payload,
                            version: QrVersions.auto,
                            size: qrSize,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _l10n.driverPersonalQrFullscreenHint,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  DriverPersonalQrData _buildDraftModel() {
    return DriverPersonalQrData(
      courtesy: _courtesy,
      nome: _nomeController.text,
      cognome: _cognomeController.text,
      indirizzo: _indirizzoController.text,
      zip: _zipController.text,
      city: _cityController.text,
      country: _countryController.text,
      telefono: _telefonoController.text,
      email: _emailController.text,
      targa: _targaController.text,
      marca: _marcaController.text,
      modello: _modelloController.text,
      vin: _vinController.text,
      kilometraggio: _kilometraggioController.text,
      primaImmatricolazione: _primaImmatricolazioneController.text,
      assicurazione: _assicurazioneController.text,
      numeroPolizza: _numeroPolizzaController.text,
      numeroSinistro: _numeroSinistroController.text,
      customerNumber: '',
    );
  }

  String get _primaryButtonLabel => _hasGeneratedQr
      ? _l10n.driverPersonalQrFormActionUpdate
      : _l10n.driverPersonalQrFormActionCreate;

  String get _payloadPreview {
    final payload = _qrPayload?.trim();
    if (payload == null || payload.isEmpty) return '';
    try {
      final decoded = jsonDecode(payload);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return payload;
    }
  }

  String get _customerLocationLine {
    final parts = [
      _draft.zip.trim(),
      _draft.city.trim(),
      _draft.country.trim(),
    ].where((value) => value.isNotEmpty).toList();
    if (parts.isEmpty) return '-';
    return parts.join(' · ');
  }

  String get _vehicleIdentityLine {
    final summary = _draft.vehicleSummary;
    if (summary.isNotEmpty) return summary;
    return '-';
  }

  String get _insuranceIdentityLine {
    final summary = _draft.insuranceSummary;
    if (summary.isNotEmpty) return summary;
    return '-';
  }

  String _valueOrDash(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '-' : normalized;
  }

  Color _statusBackground(_QrPreviewState state) {
    switch (state) {
      case _QrPreviewState.ready:
        return _successBackground;
      case _QrPreviewState.needsUpdate:
        return _warningBackground;
      case _QrPreviewState.draftSaved:
        return _infoBackground;
      case _QrPreviewState.empty:
        return _emptyBackground;
    }
  }

  Color _statusForeground(_QrPreviewState state) {
    switch (state) {
      case _QrPreviewState.ready:
        return _successForeground;
      case _QrPreviewState.needsUpdate:
        return _warningForeground;
      case _QrPreviewState.draftSaved:
        return _infoForeground;
      case _QrPreviewState.empty:
        return _emptyForeground;
    }
  }

  IconData _statusIcon(_QrPreviewState state) {
    switch (state) {
      case _QrPreviewState.ready:
        return Icons.verified_rounded;
      case _QrPreviewState.needsUpdate:
        return Icons.sync_problem_rounded;
      case _QrPreviewState.draftSaved:
        return Icons.save_outlined;
      case _QrPreviewState.empty:
        return Icons.info_outline_rounded;
    }
  }

  String _statusLabel(_QrPreviewState state) {
    switch (state) {
      case _QrPreviewState.ready:
        return _l10n.driverPersonalQrStatusReady;
      case _QrPreviewState.needsUpdate:
        return _l10n.driverPersonalQrStatusNeedsUpdate;
      case _QrPreviewState.draftSaved:
        return _l10n.driverPersonalQrStatusDraftSaved;
      case _QrPreviewState.empty:
        return _l10n.driverPersonalQrStatusEmpty;
    }
  }

  String _statusMessage(_QrPreviewState state) {
    switch (state) {
      case _QrPreviewState.ready:
        return _l10n.driverPersonalQrStatusReadyMessage;
      case _QrPreviewState.needsUpdate:
        return _l10n.driverPersonalQrStatusNeedsUpdateMessage;
      case _QrPreviewState.draftSaved:
        return _l10n.driverPersonalQrStatusDraftSavedMessage;
      case _QrPreviewState.empty:
        return _l10n.driverPersonalQrStatusEmptyMessage;
    }
  }

  String _courtesyOptionLabel(DriverPersonalQrCourtesy value) {
    switch (value) {
      case DriverPersonalQrCourtesy.mr:
        return _l10n.driverPersonalQrTitleMr;
      case DriverPersonalQrCourtesy.mrs:
        return _l10n.driverPersonalQrTitleMrs;
      case DriverPersonalQrCourtesy.company:
        return _l10n.driverPersonalQrTitleCompany;
    }
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(22),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: _cardShadow,
            blurRadius: 22,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _primaryBlue),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _primaryBlueDark,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return _buildCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: _primaryBlue,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _l10n.driverPersonalQrIntroTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _primaryBlueDark,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            _l10n.driverPersonalQrIntroBody,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _mutedText,
                  height: 1.5,
                ),
          ),
          if (_hasGeneratedQr) ...[
            const SizedBox(height: 20),
            _buildTopQrPreview(),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildInfoPill(
                icon: Icons.save_outlined,
                text: _l10n.driverPersonalQrLocalSaveNote,
              ),
              _buildInfoPill(
                icon: Icons.lock_outline_rounded,
                text: _l10n.driverPersonalQrPrivacyNote,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopQrPreview() {
    final payload = _qrPayload?.trim();
    if (payload == null || payload.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: InkWell(
        onTap: _showQrFullscreenPreview,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 120,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _l10n.driverPersonalQrTapToEnlarge,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.3),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: _inputDecoration(label: label, hint: hint),
    );
  }

  Widget _buildResponsiveFieldGrid(List<_ResponsiveFieldItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 560;
        const spacing = 12.0;
        final fieldWidth = useTwoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: item.fullWidth && useTwoColumns
                      ? constraints.maxWidth
                      : fieldWidth,
                  child: item.child,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: _primaryBlueDark,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _mutedText,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return _buildSectionCard(
      icon: Icons.badge_outlined,
      title: _l10n.driverPersonalQrCustomerSectionTitle,
      subtitle: _l10n.driverPersonalQrCustomerSectionSubtitle,
      child: _buildResponsiveFieldGrid(
        [
          _ResponsiveFieldItem(
            child: DropdownButtonFormField<DriverPersonalQrCourtesy>(
              initialValue: _courtesy,
              isExpanded: true,
              decoration: _inputDecoration(
                label: _l10n.driverPersonalQrTitleLabel,
              ),
              items: DriverPersonalQrCourtesy.values
                  .map(
                    (value) => DropdownMenuItem<DriverPersonalQrCourtesy>(
                      value: value,
                      child: Text(_courtesyOptionLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _courtesy = value);
                _handleDraftChanged();
              },
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _nomeController,
              label: _l10n.firstName,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _cognomeController,
              label: _l10n.lastName,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          _ResponsiveFieldItem(
            fullWidth: true,
            child: _buildTextField(
              controller: _indirizzoController,
              label: _l10n.driverPersonalQrStreetLabel,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _zipController,
              label: _l10n.zip,
              keyboardType: TextInputType.number,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _cityController,
              label: _l10n.city,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _countryController,
              label: _l10n.driverPersonalQrCountryLabel,
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _telefonoController,
              label: _l10n.customer_phone,
              keyboardType: TextInputType.phone,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _emailController,
              label: _l10n.customer_email,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSection() {
    return _buildSectionCard(
      icon: Icons.directions_car_outlined,
      title: _l10n.driverPersonalQrVehicleSectionTitle,
      subtitle: _l10n.driverPersonalQrVehicleSectionSubtitle,
      child: _buildResponsiveFieldGrid(
        [
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _marcaController,
              label: _l10n.driverPersonalQrBrandLabel,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _modelloController,
              label: _l10n.driverPersonalQrModelLabel,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _targaController,
              label: _l10n.license_plate_label,
              hint: _l10n.license_plate_hint,
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _vinController,
              label: _l10n.driverPersonalQrVinLabel,
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _kilometraggioController,
              label: _l10n.driverPersonalQrMileageLabel,
              keyboardType: TextInputType.number,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _primaImmatricolazioneController,
              label: _l10n.driverPersonalQrFirstRegistrationLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceSection() {
    return _buildSectionCard(
      icon: Icons.shield_outlined,
      title: _l10n.driverPersonalQrInsuranceSectionTitle,
      subtitle: _l10n.driverPersonalQrInsuranceSectionSubtitle,
      child: _buildResponsiveFieldGrid(
        [
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _assicurazioneController,
              label: _l10n.driverPersonalQrInsuranceLabel,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _numeroPolizzaController,
              label: _l10n.driverPersonalQrPolicyNumberLabel,
            ),
          ),
          _ResponsiveFieldItem(
            child: _buildTextField(
              controller: _numeroSinistroController,
              label: _l10n.driverPersonalQrClaimNumberLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionCard() {
    return _buildCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _l10n.driverPersonalQrPrivacyNote,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            _l10n.driverPersonalQrMinimumHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _primaryBlueDark,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _canGenerateQr ? _generateQr : null,
            icon: const Icon(Icons.qr_code_2_rounded),
            label: Text(_primaryButtonLabel),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryBlue,
              disabledBackgroundColor: const Color(0xFFD1D5DB),
              disabledForegroundColor: const Color(0xFF6B7280),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBlock({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _primaryBlueDark,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryLine({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _mutedText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _primaryBlueDark,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader() {
    final state = _previewState;
    final foreground = _statusForeground(state);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _statusBackground(state),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_statusIcon(state), color: foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(state),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMessage(state),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrVisualCard() {
    final payload = _qrPayload?.trim();

    if (payload == null || payload.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: _primaryBlue,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _l10n.driverPersonalQrQrEmptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _primaryBlueDark,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _l10n.driverPersonalQrMinimumHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _mutedText,
                    height: 1.45,
                  ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _previewState == _QrPreviewState.needsUpdate
              ? const Color(0xFFFAC9A5)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _showQrFullscreenPreview,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth < 320 ? 220.0 : 270.0;
                  return QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: size,
                    backgroundColor: Colors.white,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _l10n.driverPersonalQrQrCardSubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _primaryBlueDark,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _l10n.driverPersonalQrPrivacyNote,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedText,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _l10n.driverPersonalQrTapToEnlarge,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedDataPreview() {
    return _buildSummaryBlock(
      title: _l10n.driverPersonalQrSavedDataPreviewTitle,
      children: [
        _buildSummaryLine(
          label: _l10n.driverPersonalQrCustomerSectionTitle,
          value: _draft.fullName.isEmpty ? '-' : _draft.fullName,
        ),
        _buildSummaryLine(
          label: _l10n.driverPersonalQrStreetLabel,
          value: _valueOrDash(_draft.indirizzo),
        ),
        _buildSummaryLine(
          label: _l10n.driverPersonalQrLocationLabel,
          value: _customerLocationLine,
        ),
        _buildSummaryLine(
          label: _l10n.customer_phone,
          value: _valueOrDash(_draft.telefono),
        ),
        _buildSummaryLine(
          label: _l10n.customer_email,
          value: _valueOrDash(_draft.email),
        ),
        const SizedBox(height: 8),
        _buildSummaryLine(
          label: _l10n.driverPersonalQrVehicleSectionTitle,
          value: _vehicleIdentityLine,
        ),
        _buildSummaryLine(
          label: _l10n.license_plate_label,
          value: _valueOrDash(_draft.targa),
        ),
        _buildSummaryLine(
          label: _l10n.driverPersonalQrVinLabel,
          value: _valueOrDash(_draft.vin),
        ),
        _buildSummaryLine(
          label: _l10n.driverPersonalQrMileageLabel,
          value: _valueOrDash(_draft.kilometraggio),
        ),
        _buildSummaryLine(
          label: _l10n.driverPersonalQrFirstRegistrationLabel,
          value: _valueOrDash(_draft.primaImmatricolazione),
        ),
        const SizedBox(height: 8),
        _buildSummaryLine(
          label: _l10n.driverPersonalQrInsuranceSectionTitle,
          value: _insuranceIdentityLine,
        ),
        _buildSummaryLine(
          label: _l10n.driverPersonalQrClaimNumberLabel,
          value: _valueOrDash(_draft.numeroSinistro),
        ),
      ],
    );
  }

  Widget _buildJsonPreview() {
    final payloadPreview = _payloadPreview;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const PageStorageKey<String>('driver-personal-qr-json-preview'),
        controlAffinity: ListTileControlAffinity.leading,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 10),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          _l10n.driverPersonalQrTechnicalDetailsTitle,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: _primaryBlueDark,
                fontWeight: FontWeight.w800,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _l10n.driverPersonalQrTechnicalDetailsDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedText,
                  height: 1.45,
                ),
          ),
        ),
        children: [
          if (!_hasGeneratedQr)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                _l10n.driverPersonalQrMinimumHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _mutedText,
                      height: 1.45,
                    ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      payloadPreview,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _primaryBlueDark,
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.4,
                          ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stackHeaderButton = constraints.maxWidth < 420;
              final editButton = _hasSavedDraft
                  ? OutlinedButton.icon(
                      onPressed: _scrollToForm,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(_l10n.driverPersonalQrEditSavedData),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            Size.fromHeight(stackHeaderButton ? 44 : 42),
                        foregroundColor: _primaryBlue,
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                  : null;

              final titleBlock = Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: _primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CID DIGITALE',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: _primaryBlue,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _l10n.driverPersonalQrQrCardTitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _mutedText,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (editButton == null) {
                return titleBlock;
              }

              if (stackHeaderButton) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleBlock,
                    const SizedBox(height: 14),
                    editButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  editButton,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _buildPreviewHeader(),
          const SizedBox(height: 18),
          _buildQrVisualCard(),
          const SizedBox(height: 18),
          _buildSavedDataPreview(),
          const SizedBox(height: 18),
          _buildJsonPreview(),
          if (_hasSavedDraft || _hasGeneratedQr) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _deletingProfile ? null : _deleteProfile,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(_l10n.driverPersonalQrDeleteProfileAction),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormColumn() {
    return Column(
      key: _formAnchorKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCustomerSection(),
        const SizedBox(height: 18),
        _buildVehicleSection(),
        const SizedBox(height: 18),
        _buildInsuranceSection(),
        const SizedBox(height: 18),
        _buildPrimaryActionCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: Text(_l10n.driverPersonalQrPageTitle),
      ),
      body: _isLoadingProfile || !_profileLoaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final useTwoColumns = constraints.maxWidth >= 1024;
                            if (!useTwoColumns) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildFormColumn(),
                                  const SizedBox(height: 18),
                                  _buildPreviewCard(),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _buildFormColumn(),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 9,
                                  child: _buildPreviewCard(),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
