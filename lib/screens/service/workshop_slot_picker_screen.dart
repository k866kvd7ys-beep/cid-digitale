import 'dart:async';
import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:cid_digitale/services/local_image_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:table_calendar/table_calendar.dart';

class _GlassDamageImageDraft {
  const _GlassDamageImageDraft({
    required this.category,
    required this.fileName,
    required this.mimeType,
    required this.previewReference,
    this.localPath,
    this.cacheKey,
    this.bytes,
  });

  final String category;
  final String fileName;
  final String mimeType;
  final String previewReference;
  final String? localPath;
  final String? cacheKey;
  final Uint8List? bytes;

  AppointmentRequestImageInput toInput() {
    return AppointmentRequestImageInput(
      category: category,
      fileName: fileName,
      mimeType: mimeType,
      previewReference: previewReference,
      localPath: localPath,
      cacheKey: cacheKey,
      bytes: bytes,
    );
  }
}

class WorkshopSlotPickerScreen extends StatefulWidget {
  final String title;
  final String serviceType;
  final String? damageType;

  const WorkshopSlotPickerScreen({
    super.key,
    required this.title,
    required this.serviceType,
    this.damageType,
  });

  @override
  State<WorkshopSlotPickerScreen> createState() =>
      _WorkshopSlotPickerScreenState();
}

class _WorkshopSlotPickerScreenState extends State<WorkshopSlotPickerScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  DateTime? _selectedSlot;
  DateTime? _glassDamageDate;
  bool _loading = false;
  bool _submitting = false;
  bool _loadingSlots = false;
  List<DateTime> _bookedSlots = const [];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _glassTownCtrl = TextEditingController();
  final _appointmentService = AppointmentRequestsService();
  final _picker = ImagePicker();
  final List<_GlassDamageImageDraft> _glassVehicleDocumentImages = [];
  final List<_GlassDamageImageDraft> _glassCloseGlassImages = [];
  final List<_GlassDamageImageDraft> _glassFrontVehicleImages = [];

  bool get _isGlassDamage => widget.serviceType == 'damage_glass';

  bool _isTaken(DateTime slot) => false;

  String _copy({
    required BuildContext context,
    required String de,
    required String it,
    required String en,
    required String fr,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'it':
        return it;
      case 'en':
        return en;
      case 'fr':
        return fr;
      case 'de':
      default:
        return de;
    }
  }

  String _snackMissingName(BuildContext context) => _copy(
        context: context,
        de: 'Bitte Name eingeben',
        it: 'Inserisci nome e cognome',
        en: 'Please enter name and surname',
        fr: 'Veuillez saisir le nom et le prénom',
      );

  String _snackMissingSlot(BuildContext context) => _copy(
        context: context,
        de: 'Bitte Uhrzeit auswählen',
        it: 'Seleziona un orario',
        en: 'Please select a time slot',
        fr: 'Veuillez sélectionner un horaire',
      );

  String _snackTakenSlot(BuildContext context) => _copy(
        context: context,
        de: 'Dieser Termin ist bereits belegt.',
        it: 'Questo appuntamento è già occupato.',
        en: 'This appointment is already booked.',
        fr: 'Ce rendez-vous est déjà réservé.',
      );

  String _snackMissingTown(BuildContext context) => _copy(
        context: context,
        de: 'Bitte Ortschaft eingeben',
        it: 'Inserisci la località',
        en: 'Please enter the town',
        fr: 'Veuillez saisir la localité',
      );

  String _snackMissingDamageDate(BuildContext context) => _copy(
        context: context,
        de: 'Bitte Schadentag auswählen',
        it: 'Seleziona la data del danno',
        en: 'Please select the damage date',
        fr: 'Veuillez sélectionner la date du dommage',
      );

  String _snackUnsupportedImage(BuildContext context) => _copy(
        context: context,
        de: 'Nur PNG, JPG, JPEG und GIF werden unterstützt.',
        it: 'Sono supportati solo PNG, JPG, JPEG e GIF.',
        en: 'Only PNG, JPG, JPEG and GIF are supported.',
        fr: 'Seuls PNG, JPG, JPEG et GIF sont pris en charge.',
      );

  String _snackSuccess(BuildContext context, String slotLabel) => _copy(
        context: context,
        de: '✅ Termin gesendet ($slotLabel)',
        it: '✅ Appuntamento inviato ($slotLabel)',
        en: '✅ Appointment sent ($slotLabel)',
        fr: '✅ Rendez-vous envoyé ($slotLabel)',
      );

  String _snackOfflineQueued(BuildContext context) => _copy(
        context: context,
        de: 'Anfrage offline gespeichert. Sie wird automatisch synchronisiert.',
        it: 'Richiesta salvata offline. Verrà sincronizzata automaticamente.',
        en: 'Request saved offline. It will sync automatically.',
        fr: 'Demande enregistrée hors ligne. Elle sera synchronisée automatiquement.',
      );

  String _snackSendError(BuildContext context, Object error) => _copy(
        context: context,
        de: '❌ Fehler beim Senden: $error',
        it: '❌ Errore di invio: $error',
        en: '❌ Sending error: $error',
        fr: '❌ Erreur d’envoi : $error',
      );

  String _appBarTitle(BuildContext context) => _copy(
        context: context,
        de: 'Termin auswählen',
        it: 'Seleziona appuntamento',
        en: 'Select appointment',
        fr: 'Sélectionner le rendez-vous',
      );

  String _nameHint(BuildContext context) => _copy(
        context: context,
        de: 'Name und Nachname',
        it: 'Nome e cognome',
        en: 'Name and surname',
        fr: 'Nom et prénom',
      );

  String _phoneHint(BuildContext context) => _copy(
        context: context,
        de: 'Telefon',
        it: 'Telefono',
        en: 'Phone',
        fr: 'Téléphone',
      );

  String _emailHint(BuildContext context) => _copy(
        context: context,
        de: 'E-Mail',
        it: 'E-Mail',
        en: 'E-Mail',
        fr: 'E-Mail',
      );

  String _timeTitle(BuildContext context) => _copy(
        context: context,
        de: 'Bitte Uhrzeit auswählen',
        it: 'Seleziona un orario',
        en: 'Please select a time slot',
        fr: 'Veuillez sélectionner un horaire',
      );

  String _noSlotsText(BuildContext context) => _copy(
        context: context,
        de: 'Keine Uhrzeit verfügbar',
        it: 'Nessun orario disponibile',
        en: 'No time slots available',
        fr: 'Aucun horaire disponible',
      );

  String _glassSectionTitle(BuildContext context, String category) {
    switch (category) {
      case AppointmentRequestImageCategory.vehicleDocument:
        return _copy(
          context: context,
          de: 'Foto Fahrzeugausweis',
          it: 'Foto libretto',
          en: 'Vehicle document photo',
          fr: 'Photo carte grise',
        );
      case AppointmentRequestImageCategory.frontVehicle:
        return _copy(
          context: context,
          de: 'Frontfoto des Fahrzeugs',
          it: 'Foto frontale della macchina',
          en: 'Front vehicle photo',
          fr: 'Photo frontale du vehicule',
        );
      case AppointmentRequestImageCategory.closeGlass:
      default:
        return _copy(
          context: context,
          de: 'Nahaufnahme Glas',
          it: 'Foto vetro vicino',
          en: 'Close-up glass photo',
          fr: 'Photo rapprochee du verre',
        );
    }
  }

  String _takePhotoLabel(BuildContext context) => _copy(
        context: context,
        de: 'Foto aufnehmen',
        it: 'Scatta foto',
        en: 'Take photo',
        fr: 'Prendre une photo',
      );

  String _selectPhotosLabel(BuildContext context) => _copy(
        context: context,
        de: 'Foto auswählen',
        it: 'Seleziona foto',
        en: 'Select photo',
        fr: 'Selectionner une photo',
      );

  String _townLabel(BuildContext context) => _copy(
        context: context,
        de: 'In welcher Ortschaft ist es passiert?',
        it: 'In quale località è successo?',
        en: 'In which town did it happen?',
        fr: 'Dans quelle localité cela s’est-il produit ?',
      );

  String _dateLabel(BuildContext context) => _copy(
        context: context,
        de: 'An welchem Tag ereignete sich der Schaden?',
        it: 'In quale giorno è avvenuto il danno?',
        en: 'On which day did the damage occur?',
        fr: 'À quelle date le dommage est-il survenu ?',
      );

  String _pickDateButton(BuildContext context) => _copy(
        context: context,
        de: 'Datum auswählen',
        it: 'Seleziona data',
        en: 'Select date',
        fr: 'Sélectionner la date',
      );

  Widget _licensePlateCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.primary.withOpacity(0.12),
            ),
            child: Icon(Icons.confirmation_number_outlined,
                color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.license_plate_label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.70),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _plateCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: AppLocalizations.of(context)!.license_plate_hint,
                    border: InputBorder.none,
                  ),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _premiumFieldDec(BuildContext context, String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surface.withOpacity(0.22),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.6), width: 1.2),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _plateCtrl.dispose();
    _glassTownCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots(_selectedDay);
    unawaited(AppointmentRequestsSyncManager.trigger());
  }

  List<DateTime> _buildSlots(DateTime day) {
    final base = DateTime(day.year, day.month, day.day);
    final slots = <DateTime>[];
    for (int h = 8; h < 18; h++) {
      slots.add(base.add(Duration(hours: h, minutes: 0)));
      slots.add(base.add(Duration(hours: h, minutes: 30)));
    }
    return slots;
  }

  Future<void> _loadAvailableSlots(DateTime day) async {
    setState(() {
      _loadingSlots = true;
    });
    try {
      final booked = await _appointmentService.fetchBookedSlots(
        serviceKey: widget.serviceType,
        day: day,
      );
      if (mounted) setState(() => _bookedSlots = booked);
    } catch (_) {
      if (mounted) setState(() => _bookedSlots = const []);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  bool _isBooked(DateTime slot) {
    return _bookedSlots.any((b) =>
        b.year == slot.year &&
        b.month == slot.month &&
        b.day == slot.day &&
        b.hour == slot.hour &&
        b.minute == slot.minute);
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : 'image.jpg';
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  bool _isSupportedImageName(String value) {
    final lower = value.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif');
  }

  List<_GlassDamageImageDraft> _imagesForCategory(String category) {
    switch (category) {
      case AppointmentRequestImageCategory.vehicleDocument:
        return _glassVehicleDocumentImages;
      case AppointmentRequestImageCategory.frontVehicle:
        return _glassFrontVehicleImages;
      case AppointmentRequestImageCategory.closeGlass:
      default:
        return _glassCloseGlassImages;
    }
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case AppointmentRequestImageCategory.vehicleDocument:
        return Icons.description_outlined;
      case AppointmentRequestImageCategory.frontVehicle:
        return Icons.directions_car_outlined;
      case AppointmentRequestImageCategory.closeGlass:
      default:
        return Icons.broken_image_outlined;
    }
  }

  String _mimeTypeForName(String value) {
    final lower = value.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/jpg';
  }

  Future<String> _persistPickedFile(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${dir.path}/glass_damage_uploads');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final originalName = file.name.isNotEmpty ? file.name : _fileNameFromPath(file.path);
    final safeName =
        '${DateTime.now().millisecondsSinceEpoch}_${_sanitizeFileName(originalName)}';
    final targetPath = '${targetDir.path}/$safeName';
    final bytes = await file.readAsBytes();
    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  Future<void> _handlePickedFiles(
    List<XFile> files,
    String category,
  ) async {
    if (files.isEmpty) return;

    final newItems = <_GlassDamageImageDraft>[];
    for (final file in files) {
      final originalName =
          file.name.isNotEmpty ? file.name : _fileNameFromPath(file.path);
      if (!_isSupportedImageName(originalName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_snackUnsupportedImage(context))),
          );
        }
        continue;
      }

      final mimeType = _mimeTypeForName(originalName);
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final cacheKey =
            'glass_${DateTime.now().millisecondsSinceEpoch}_${newItems.length}';
        await LocalImageCache.saveImageLocally(cacheKey, bytes);
        newItems.add(
          _GlassDamageImageDraft(
            category: category,
            fileName: originalName,
            mimeType: mimeType,
            previewReference: 'cache:$cacheKey',
            cacheKey: cacheKey,
            bytes: bytes,
          ),
        );
      } else {
        final persistedPath = await _persistPickedFile(file);
        newItems.add(
          _GlassDamageImageDraft(
            category: category,
            fileName: originalName,
            mimeType: mimeType,
            previewReference: persistedPath,
            localPath: persistedPath,
          ),
        );
      }
    }

    if (!mounted || newItems.isEmpty) return;
    final target = _imagesForCategory(category);
    setState(() {
      target.addAll(newItems);
    });
  }

  Future<void> _pickGlassDamageCamera(String category) async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (file == null) return;
    await _handlePickedFiles([file], category);
  }

  Future<void> _pickGlassDamageGallery(String category) async {
    final files = await _picker.pickMultiImage(imageQuality: 92);
    if (files.isEmpty) return;
    await _handlePickedFiles(files, category);
  }

  Future<void> _removeGlassImage(String category, int index) async {
    final items = _imagesForCategory(category);
    final item = items[index];
    if (item.cacheKey != null && item.cacheKey!.isNotEmpty) {
      await LocalImageCache.deleteImage(item.cacheKey!);
    }
    if (!kIsWeb && item.localPath != null) {
      final file = File(item.localPath!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      items.removeAt(index);
    });
  }

  Future<void> _pickGlassDamageDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _glassDamageDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: Localizations.localeOf(context),
    );
    if (picked == null) return;
    setState(() {
      _glassDamageDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Widget _buildGlassImageSection(
    BuildContext context, {
    required String category,
  }) {
    final theme = Theme.of(context);
    final images = _imagesForCategory(category);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForCategory(category),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _glassSectionTitle(context, category),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickGlassDamageCamera(category),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_takePhotoLabel(context)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickGlassDamageGallery(category),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_selectPhotosLabel(context)),
                ),
              ),
            ],
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(images.length, (index) {
                final image = images[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 94,
                        height: 94,
                        color: Colors.black12,
                        child: image.bytes != null
                            ? Image.memory(image.bytes!, fit: BoxFit.cover)
                            : Image.file(
                                File(image.localPath!),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: IconButton.filled(
                        onPressed: () => _removeGlassImage(category, index),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints.tightFor(width: 28, height: 28),
                        icon: const Icon(Icons.close, size: 14),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassDamageSection(BuildContext context) {
    final theme = Theme.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = _glassDamageDate == null
        ? _pickDateButton(context)
        : DateFormat.yMMMMd(localeTag).format(_glassDamageDate!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGlassImageSection(
            context,
            category: AppointmentRequestImageCategory.vehicleDocument,
          ),
          const SizedBox(height: 12),
          _buildGlassImageSection(
            context,
            category: AppointmentRequestImageCategory.closeGlass,
          ),
          const SizedBox(height: 12),
          _buildGlassImageSection(
            context,
            category: AppointmentRequestImageCategory.frontVehicle,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _glassTownCtrl,
            textInputAction: TextInputAction.next,
            decoration: _premiumFieldDec(context, _townLabel(context)),
          ),
          const SizedBox(height: 12),
          Text(
            _dateLabel(context),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickGlassDamageDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(dateLabel)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onBookPressed() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_snackMissingName(context))),
      );
      return;
    }
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_snackMissingSlot(context))),
      );
      return;
    }
    if (_isTaken(_selectedSlot!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_snackTakenSlot(context))),
      );
      return;
    }
    if (_isGlassDamage && _glassTownCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_snackMissingTown(context))),
      );
      return;
    }
    if (_isGlassDamage && _glassDamageDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_snackMissingDamageDate(context))),
      );
      return;
    }

    setState(() {
      _loading = true;
      _submitting = true;
    });

    final slotStr = DateFormat('dd.MM.yyyy HH:mm').format(_selectedSlot!);

    try {
      final locale = Localizations.localeOf(context).languageCode;
      final request = await _appointmentService.createRequest(
        serviceType: widget.serviceType,
        damageType:
            widget.serviceType.startsWith('damage_') ? widget.serviceType : widget.damageType,
        appointmentDate: _selectedSlot,
        appointmentTime: DateFormat('HH:mm:ss').format(_selectedSlot!),
        durationMinutes: 60,
        customerName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        licensePlate: _plateCtrl.text.trim(),
        notes: null,
        locale: locale,
        glassDamageTown: _isGlassDamage ? _glassTownCtrl.text.trim() : null,
        glassDamageDate: _isGlassDamage && _glassDamageDate != null
            ? _glassDamageDate!.toUtc().toIso8601String()
            : null,
        glassDamageVehicleDocumentImages: _isGlassDamage
            ? _glassVehicleDocumentImages.map((e) => e.toInput()).toList()
            : const [],
        glassDamageCloseGlassImages: _isGlassDamage
            ? _glassCloseGlassImages.map((e) => e.toInput()).toList()
            : const [],
        glassDamageFrontVehicleImages: _isGlassDamage
            ? _glassFrontVehicleImages.map((e) => e.toInput()).toList()
            : const [],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            request.status == 'pending_sync'
                ? _snackOfflineQueued(context)
                : _snackSuccess(context, slotStr),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_snackSendError(context, e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tf = DateFormat('HH:mm');
    final slots =
        _buildSlots(_selectedDay).where((slot) => !_isBooked(slot)).toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_appBarTitle(context)),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _licensePlateCard(context),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: _premiumFieldDec(context, _nameHint(context)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.phone,
                    decoration: _premiumFieldDec(context, _phoneHint(context)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _premiumFieldDec(context, _emailHint(context)),
                  ),
                ),
              ],
            ),
            if (_isGlassDamage) ...[
              const SizedBox(height: 16),
              _buildGlassDamageSection(context),
            ],
            const SizedBox(height: 16),
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 120)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _selectedSlot = null;
                });
                _loadAvailableSlots(selectedDay);
              },
            ),
            const SizedBox(height: 12),
            Text(
              _timeTitle(context),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_loadingSlots)
              const Center(child: CircularProgressIndicator())
            else if (slots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.withOpacity(0.12),
                child: Text(_noSlotsText(context)),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.8,
                ),
                itemCount: slots.length,
                itemBuilder: (context, index) {
                  final slot = slots[index];
                  final selected = _selectedSlot != null &&
                      _selectedSlot!.year == slot.year &&
                      _selectedSlot!.month == slot.month &&
                      _selectedSlot!.day == slot.day &&
                      _selectedSlot!.hour == slot.hour &&
                      _selectedSlot!.minute == slot.minute;

                  final primary = Theme.of(context).colorScheme.primary;
                  final borderColor = selected
                      ? primary
                      : Theme.of(context).dividerColor.withOpacity(0.6);

                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: selected ? primary : Colors.transparent,
                      foregroundColor: selected ? Colors.white : primary,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedSlot = slot;
                      });
                    },
                    child: Text(
                      tf.format(slot),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 140),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading || _submitting ? null : _onBookPressed,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _loading || _submitting ? '...' : l10n.termin_buchen,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
