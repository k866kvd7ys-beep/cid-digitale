import 'dart:async';

import 'package:cid_digitale/models/driver_personal_qr_data.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverPersonalQrScreen extends StatefulWidget {
  const DriverPersonalQrScreen({super.key});

  @override
  State<DriverPersonalQrScreen> createState() => _DriverPersonalQrScreenState();
}

class _DriverPersonalQrScreenState extends State<DriverPersonalQrScreen> {
  static const String _storageKey = 'driver_personal_qr_data_v1';
  static const Color _pageBackground = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE5E7EB);
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _mutedText = Color(0xFF6B7280);
  static const Color _titleText = Color(0xFF111827);

  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _indirizzoController = TextEditingController();
  final _zipController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _targaController = TextEditingController();
  final _assicurazioneController = TextEditingController();

  DriverPersonalQrCourtesy? _courtesy;
  Timer? _persistDebounce;
  bool _loading = true;
  bool _hydrating = false;
  String? _qrPayload;

  @override
  void initState() {
    super.initState();
    _attachDraftListeners();
    _loadSavedDraft();
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _nomeController.dispose();
    _cognomeController.dispose();
    _indirizzoController.dispose();
    _zipController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _targaController.dispose();
    _assicurazioneController.dispose();
    super.dispose();
  }

  void _attachDraftListeners() {
    final controllers = [
      _nomeController,
      _cognomeController,
      _indirizzoController,
      _zipController,
      _cityController,
      _countryController,
      _telefonoController,
      _emailController,
      _targaController,
      _assicurazioneController,
    ];
    for (final controller in controllers) {
      controller.addListener(_handleDraftChanged);
    }
  }

  String _text({
    required String it,
    required String de,
    required String fr,
    required String en,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'de':
        return de;
      case 'fr':
        return fr;
      case 'en':
        return en;
      default:
        return it;
    }
  }

  String get _pageTitle => _text(
        it: 'Il mio QR personale',
        de: 'Mein persönlicher QR',
        fr: 'Mon QR personnel',
        en: 'My personal QR',
      );

  String get _introTitle => _text(
        it: 'Crea il tuo QR conducente',
        de: 'Erstelle deinen Fahrer-QR',
        fr: 'Créez votre QR conducteur',
        en: 'Create your driver QR',
      );

  String get _introBody => _text(
        it:
            'Compila i tuoi dati personali e del veicolo per generare un QR pronto per l\'autocompilazione futura.',
        de:
            'Erfasse deine persönlichen Daten und Fahrzeugdaten, um einen QR für die künftige automatische Befüllung zu erzeugen.',
        fr:
            'Renseignez vos informations personnelles et véhicule pour générer un QR prêt pour le remplissage automatique futur.',
        en:
            'Fill in your personal and vehicle details to generate a QR ready for future auto-fill.',
      );

  String get _localSaveNote => _text(
        it: 'I dati vengono salvati localmente su questo dispositivo/browser.',
        de: 'Die Daten werden lokal auf diesem Gerät bzw. Browser gespeichert.',
        fr: 'Les données sont enregistrées localement sur cet appareil/navigateur.',
        en: 'Data is stored locally on this device/browser.',
      );

  String get _privacyNote => _text(
        it: 'Il QR contiene solo dati anagrafici e del veicolo del conducente.',
        de: 'Der QR enthält nur Fahrer- und Fahrzeugdaten.',
        fr: 'Le QR contient uniquement les données du conducteur et du véhicule.',
        en: 'The QR contains only driver and vehicle details.',
      );

  String get _formTitle => _text(
        it: 'Dati da includere nel QR',
        de: 'Daten für den QR',
        fr: 'Données à inclure dans le QR',
        en: 'Data to include in the QR',
      );

  String get _courtesyLabel => _text(
        it: 'Titolo / forma giuridica',
        de: 'Anrede / Rechtsform',
        fr: 'Civilité / forme juridique',
        en: 'Title / legal form',
      );

  String get _firstNameLabel => _text(
        it: 'Nome',
        de: 'Vorname',
        fr: 'Prénom',
        en: 'First Name',
      );

  String get _lastNameLabel => _text(
        it: 'Cognome',
        de: 'Nachname',
        fr: 'Nom',
        en: 'Last Name',
      );

  String get _addressLabel => _text(
        it: 'Indirizzo',
        de: 'Adresse',
        fr: 'Adresse',
        en: 'Address',
      );

  String get _zipLabel => _text(
        it: 'CAP / ZIP',
        de: 'PLZ',
        fr: 'Code postal',
        en: 'ZIP',
      );

  String get _cityLabel => _text(
        it: 'Città',
        de: 'Ort',
        fr: 'Ville',
        en: 'City',
      );

  String get _countryLabel => _text(
        it: 'Paese',
        de: 'Land',
        fr: 'Pays',
        en: 'Country',
      );

  String get _phoneLabel => _text(
        it: 'Telefono',
        de: 'Telefon',
        fr: 'Telephone',
        en: 'Phone',
      );

  String get _emailLabel => _text(
        it: 'E-mail',
        de: 'E-Mail',
        fr: 'E-mail',
        en: 'E-mail',
      );

  String get _plateLabel => _text(
        it: 'Targa veicolo',
        de: 'Kennzeichen Fahrzeug',
        fr: 'Plaque véhicule',
        en: 'Vehicle plate',
      );

  String get _insuranceLabel => _text(
        it: 'Assicurazione veicolo',
        de: 'Fahrzeugversicherung',
        fr: 'Assurance véhicule',
        en: 'Vehicle insurance',
      );

  String get _generateLabel => _text(
        it: 'Crea QR personale',
        de: 'Persönlichen QR erstellen',
        fr: 'Créer QR personnel',
        en: 'Create personal QR',
      );

  String get _generatedTitle => _text(
        it: 'QR personale',
        de: 'Persönlicher QR',
        fr: 'QR personnel',
        en: 'Personal QR',
      );

  String get _generatedHint => _text(
        it:
            'Scansiona questo codice per compilare automaticamente i dati del conducente.',
        de:
            'Scanne diesen Code, um die Fahrerdaten automatisch auszufüllen.',
        fr:
            'Scannez ce code pour remplir automatiquement les données du conducteur.',
        en:
            'Scan this code to automatically fill in the driver data.',
      );

  String get _emptyQrHint => _text(
        it: 'Compila almeno il nome per generare il tuo QR personale.',
        de: 'Trage mindestens den Vornamen ein, um deinen persönlichen QR zu erstellen.',
        fr: 'Renseignez au moins le prénom pour générer votre QR personnel.',
        en: 'Enter at least the first name to generate your personal QR.',
      );

  String get _savedMessage => _text(
        it: 'QR personale aggiornato e salvato localmente.',
        de: 'Persönlicher QR aktualisiert und lokal gespeichert.',
        fr: 'QR personnel mis à jour et enregistré localement.',
        en: 'Personal QR updated and saved locally.',
      );

  String get _saveErrorMessage => _text(
        it: 'Impossibile salvare localmente il QR personale.',
        de: 'Der persönliche QR konnte lokal nicht gespeichert werden.',
        fr: 'Impossible d\'enregistrer localement le QR personnel.',
        en: 'Unable to save the personal QR locally.',
      );

  String get _placeholderMessage => _text(
        it: 'Funzione in preparazione',
        de: 'Funktion in Vorbereitung',
        fr: 'Fonction en préparation',
        en: 'Feature in preparation',
      );

  String get _shareQrLabel => _text(
        it: 'Condividi QR',
        de: 'QR teilen',
        fr: 'Partager QR',
        en: 'Share QR',
      );

  String get _saveImageLabel => _text(
        it: 'Salva come immagine',
        de: 'Als Bild speichern',
        fr: 'Enregistrer comme image',
        en: 'Save as image',
      );

  String _courtesyOptionLabel(DriverPersonalQrCourtesy value) {
    switch (value) {
      case DriverPersonalQrCourtesy.mr:
        return _text(
          it: 'Signor',
          de: 'Herr',
          fr: 'Monsieur',
          en: 'Mr.',
        );
      case DriverPersonalQrCourtesy.mrs:
        return _text(
          it: 'Signora',
          de: 'Frau',
          fr: 'Madame',
          en: 'Mrs.',
        );
      case DriverPersonalQrCourtesy.company:
        return _text(
          it: 'Ditta',
          de: 'Firma',
          fr: 'Société',
          en: 'Company',
        );
    }
  }

  void _showPlaceholderAction() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_placeholderMessage)),
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
      assicurazione: _assicurazioneController.text,
    );
  }

  Future<void> _loadSavedDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final data = driverPersonalQrDataFromJson(raw);
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
    _assicurazioneController.text = data.assicurazione;
    _hydrating = false;

    if (!mounted) return;
    setState(() {
      _qrPayload = data.hasMinimumData ? driverPersonalQrDataToJson(data) : null;
      _loading = false;
    });
  }

  void _handleDraftChanged() {
    if (_hydrating) return;
    final model = _buildDraftModel();
    if (mounted) {
      setState(() {
        if (!model.hasMinimumData) {
          _qrPayload = null;
        } else if (_qrPayload != null) {
          _qrPayload = driverPersonalQrDataToJson(model);
        }
      });
    }
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistDraft());
    });
  }

  Future<void> _persistDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        driverPersonalQrDataToJson(_buildDraftModel()),
      );
    } catch (_) {}
  }

  Future<void> _generateQr() async {
    final model = _buildDraftModel();
    if (!model.hasMinimumData) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_emptyQrHint)),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = driverPersonalQrDataToJson(model);
      await prefs.setString(_storageKey, payload);
      if (!mounted) return;
      setState(() => _qrPayload = payload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_savedMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_saveErrorMessage)),
      );
    }
  }

  bool get _canGenerateQr => _buildDraftModel().hasMinimumData;

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(22),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.2),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label),
    );
  }

  Widget _buildFormGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final fieldWidth = wide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<DriverPersonalQrCourtesy>(
                initialValue: _courtesy,
                isExpanded: true,
                decoration: _inputDecoration(_courtesyLabel),
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
            SizedBox(
              width: fieldWidth,
              child: _buildTextField(
                controller: _nomeController,
                label: _firstNameLabel,
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _buildTextField(
                controller: _cognomeController,
                label: _lastNameLabel,
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _buildTextField(
                controller: _indirizzoController,
                label: _addressLabel,
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _buildTextField(
                controller: _zipController,
                label: _zipLabel,
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _buildTextField(
                controller: _cityController,
                label: _cityLabel,
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _buildTextField(
                controller: _countryController,
                label: _countryLabel,
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _buildTextField(
                controller: _telefonoController,
                label: _phoneLabel,
                keyboardType: TextInputType.phone,
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _buildTextField(
                controller: _emailController,
                label: _emailLabel,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _buildTextField(
                controller: _targaController,
                label: _plateLabel,
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: _buildTextField(
                controller: _assicurazioneController,
                label: _insuranceLabel,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGeneratedQrCard() {
    final payload = _qrPayload;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _generatedTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _titleText,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _generatedHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: payload == null
                ? Container(
                    key: const ValueKey('empty-qr'),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: _primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _emptyQrHint,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: _mutedText,
                                      height: 1.4,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    key: const ValueKey('ready-qr'),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD7E3FF)),
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: payload,
                          version: QrVersions.auto,
                          size: 244,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _generatedHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _titleText,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _privacyNote,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _mutedText,
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 420;
                            final buttons = [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showPlaceholderAction,
                                  icon: const Icon(Icons.share_outlined),
                                  label: Text(_shareQrLabel),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showPlaceholderAction,
                                  icon: const Icon(Icons.download_outlined),
                                  label: Text(_saveImageLabel),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ];

                            if (wide) {
                              return Row(
                                children: [
                                  buttons[0],
                                  const SizedBox(width: 12),
                                  buttons[1],
                                ],
                              );
                            }

                            return Column(
                              children: [
                                buttons[0],
                                const SizedBox(height: 12),
                                buttons[1],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: Text(_pageTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.shield_outlined,
                                      color: _primaryBlue,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _introTitle,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: _titleText,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _introBody,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: _mutedText,
                                                height: 1.5,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _localSaveNote,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: _titleText,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _privacyNote,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: _mutedText,
                                            height: 1.4,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _formTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: _titleText,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              _buildFormGrid(),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _canGenerateQr ? _generateQr : null,
                                icon: const Icon(Icons.qr_code_2_rounded),
                                label: Text(_generateLabel),
                                style: ButtonStyle(
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.disabled)) {
                                      return const Color(0xFFD1D5DB);
                                    }
                                    return _primaryBlue;
                                  }),
                                  foregroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.disabled)) {
                                      return const Color(0xFF6B7280);
                                    }
                                    return Colors.white;
                                  }),
                                  minimumSize: WidgetStateProperty.all(
                                    const Size.fromHeight(56),
                                  ),
                                  shape: WidgetStateProperty.all(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildGeneratedQrCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
