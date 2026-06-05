import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:cid_digitale/services/local_image_cache.dart';
import 'package:cid_digitale/services/premium_workshop_pdf_service.dart';
import 'package:cid_digitale/utils/tire_service_type_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.request});

  final AppointmentRequest request;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _service = AppointmentRequestsService();
  final _premiumPdfService = PremiumWorkshopPdfService();
  bool _busy = false;
  bool _pdfBusy = false;
  Timer? _refreshTimer;
  late AppointmentRequest _request;

  AppointmentRequest get request => _request;
  bool get _isGlassDamageRequest =>
      request.serviceType == 'damage_glass' ||
      request.damageType == 'damage_glass';
  bool get _isHailDamageRequest =>
      request.serviceType == 'damage_hail' ||
      request.damageType == 'damage_hail';
  bool get _isMartenDamageRequest =>
      request.serviceType == 'damage_marten' ||
      request.damageType == 'damage_marten';
  bool get _isComprehensiveDamageRequest =>
      request.serviceType == 'damage_comprehensive' ||
      request.damageType == 'damage_comprehensive';
  bool get _isOtherDamageRequest =>
      request.serviceType == 'damage_other' ||
      request.damageType == 'damage_other';
  bool get _isParkingDamageRequest =>
      request.serviceType == 'damage_parking' ||
      request.damageType == 'damage_parking';
  bool get _hasDamagePhotoSections =>
      _isGlassDamageRequest ||
      _isHailDamageRequest ||
      _isMartenDamageRequest ||
      _isComprehensiveDamageRequest ||
      _isOtherDamageRequest ||
      _isParkingDamageRequest;
  bool get _supportsPremiumWorkshopPdf => _hasDamagePhotoSections;
  bool get _isTireRequest => isTireAppointmentService(request.serviceType);
  String get _tireLocaleCode => tireLocaleCode(context);

  String _copy({
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

  String get _photosTitle => _copy(
        de: 'Fotos',
        it: 'Foto',
        en: 'Photos',
        fr: 'Photos',
      );

  String get _tireServiceTypeFieldLabel =>
      tireServiceSectionLabel(_tireLocaleCode);

  String get _tireServiceTypeLabel => localizedTireServiceType(
        _tireLocaleCode,
        tireServiceType: request.tireServiceType,
        serviceType: request.serviceType,
      );

  String get _vehicleDocumentPhotosTitle => _copy(
        de: 'Foto Fahrzeugausweis',
        it: 'Foto libretto',
        en: 'Vehicle document photo',
        fr: 'Photo carte grise',
      );

  String get _closeGlassPhotosTitle => _copy(
        de: 'Nahaufnahme Glas',
        it: 'Foto vetro vicino',
        en: 'Close-up glass photo',
        fr: 'Photo rapprochee du verre',
      );

  String get _frontVehiclePhotosTitle => _copy(
        de: 'Frontfoto des Fahrzeugs',
        it: 'Foto frontale della macchina',
        en: 'Front vehicle photo',
        fr: 'Photo frontale du vehicule',
      );

  String get _currentKmPhotosTitle => _copy(
        de: 'Foto aktueller KM-Stand',
        it: 'Foto stato attuale KM',
        en: 'Current mileage photo',
        fr: 'Photo kilometrage actuel',
      );

  String get _hailDamagePhotosTitle => _copy(
        de: 'Foto Hagelschaden',
        it: 'Foto dei danni da grandine',
        en: 'Hail damage photo',
        fr: 'Photo degats grele',
      );

  String get _hailOverviewPhotosTitle => _copy(
        de: 'Uebersichtsfoto Fahrzeug',
        it: 'Foto panoramica veicolo',
        en: 'Vehicle overview photo',
        fr: 'Photo generale du vehicule',
      );

  String get _hailVehicleDocumentPhotosTitle => _copy(
        de: 'Foto Fahrzeugausweis',
        it: 'Foto libretto',
        en: 'Vehicle document photo',
        fr: 'Photo carte grise',
      );

  String get _hailExtraPhotosTitle => _copy(
        de: 'Zusaetzliches Foto',
        it: 'Foto aggiuntiva',
        en: 'Additional photo',
        fr: 'Photo supplementaire',
      );

  String get _marderVehicleDocumentPhotosTitle => _copy(
        de: 'Foto Fahrzeugausweis',
        it: 'Foto libretto',
        en: 'Vehicle document photo',
        fr: 'Photo carte grise',
      );

  String get _marderEngineBayPhotosTitle => _copy(
        de: 'Foto Motorraum',
        it: 'Foto vano motore',
        en: 'Engine bay photo',
        fr: 'Photo compartiment moteur',
      );

  String get _marderCablePhotosTitle => _copy(
        de: 'Foto beschädigte Kabel',
        it: 'Foto cavi danneggiati',
        en: 'Damaged cable photo',
        fr: 'Photo cables endommages',
      );

  String get _marderExtraPhotosTitle => _copy(
        de: 'Zusaetzliches Foto',
        it: 'Foto aggiuntiva',
        en: 'Additional photo',
        fr: 'Photo supplementaire',
      );

  String get _fullVehicleDocumentPhotosTitle => _copy(
        de: 'Foto Fahrzeugausweis',
        it: 'Foto libretto',
        en: 'Vehicle document photo',
        fr: 'Photo carte grise',
      );

  String get _fullClosePhotosTitle => _copy(
        de: 'Foto Schaden Nahaufnahme',
        it: 'Foto danno ravvicinata',
        en: 'Damage close-up photo',
        fr: 'Photo gros plan du dommage',
      );

  String get _fullOverviewPhotosTitle => _copy(
        de: 'Foto Gesamtansicht Fahrzeug',
        it: 'Foto panoramica veicolo',
        en: 'Vehicle overview photo',
        fr: 'Photo vue d ensemble du véhicule',
      );

  String get _fullExtraPhotosTitle => _copy(
        de: 'Zusaetzliches Foto',
        it: 'Foto aggiuntiva',
        en: 'Additional photo',
        fr: 'Photo supplementaire',
      );

  String get _otherVehicleDocumentPhotosTitle => _copy(
        de: 'Foto Fahrzeugausweis',
        it: 'Foto libretto',
        en: 'Vehicle document photo',
        fr: 'Photo carte grise',
      );

  String get _otherProblemPhotosTitle => _copy(
        de: 'Foto Problem / Schaden',
        it: 'Foto problema / danno',
        en: 'Problem / damage photo',
        fr: 'Photo problème / dommage',
      );

  String get _otherExtraPhotosTitle => _copy(
        de: 'Zusaetzliches Foto',
        it: 'Foto aggiuntiva',
        en: 'Additional photo',
        fr: 'Photo supplementaire',
      );

  String get _parkingDamagePhotosTitle => _copy(
        de: 'Foto Parkschaden',
        it: 'Foto danno parcheggio',
        en: 'Parking damage photo',
        fr: 'Photo dommage parking',
      );

  String get _parkingOverviewPhotosTitle => _copy(
        de: 'Uebersichtsfoto Fahrzeug',
        it: 'Foto panoramica veicolo',
        en: 'Vehicle overview photo',
        fr: 'Photo generale du vehicule',
      );

  String get _parkingVehicleDocumentPhotosTitle => _copy(
        de: 'Foto Fahrzeugausweis',
        it: 'Foto libretto',
        en: 'Vehicle document photo',
        fr: 'Photo carte grise',
      );

  String get _parkingExtraPhotosTitle => _copy(
        de: 'Zusaetzliches Foto',
        it: 'Foto aggiuntiva',
        en: 'Additional photo',
        fr: 'Photo supplementaire',
      );

  String get _noPhotosText => _copy(
        de: 'Keine Fotos vorhanden.',
        it: 'Nessuna foto disponibile.',
        en: 'No photos available.',
        fr: 'Aucune photo disponible.',
      );

  String get _closePhotoText => _copy(
        de: 'Foto schließen',
        it: 'Chiudi foto',
        en: 'Close photo',
        fr: 'Fermer la photo',
      );

  String get _damageTownFieldLabel => _copy(
        de: 'Ort',
        it: 'Localita',
        en: 'Town',
        fr: 'Localite',
      );

  String get _damageDateFieldLabel => _copy(
        de: _isOtherDamageRequest ? 'Problemtag' : 'Schadentag',
        it: _isOtherDamageRequest ? 'Data problema' : 'Data danno',
        en: _isOtherDamageRequest ? 'Problem date' : 'Damage date',
        fr: _isOtherDamageRequest ? 'Date du problème' : 'Date du dommage',
      );

  String get _damageTimeFieldLabel => _copy(
        de: _isOtherDamageRequest ? 'Problemzeit' : 'Schadenzeit',
        it: _isOtherDamageRequest ? 'Ora problema' : 'Ora danno',
        en: _isOtherDamageRequest ? 'Problem time' : 'Damage time',
        fr: _isOtherDamageRequest ? 'Heure du problème' : 'Heure du dommage',
      );

  String get _marderDrivableFieldLabel => _copy(
        de: 'Fahrbereit',
        it: 'Marciante',
        en: 'Drivable',
        fr: 'Peut rouler',
      );

  String get _marderDescriptionFieldLabel => _copy(
        de: 'Problembeschreibung',
        it: 'Descrizione problema',
        en: 'Problem description',
        fr: 'Description du problème',
      );

  String get _fullDrivableFieldLabel => _copy(
        de: 'Fahrbereit',
        it: 'Marciante',
        en: 'Drivable',
        fr: 'Peut rouler',
      );

  String get _fullDescriptionFieldLabel => _copy(
        de: 'Unfallbeschreibung',
        it: 'Descrizione danno',
        en: 'Accident description',
        fr: 'Description de l’accident',
      );

  String get _otherCategoryFieldLabel => _copy(
        de: 'Problemkategorie',
        it: 'Categoria problema',
        en: 'Problem category',
        fr: 'Catégorie du problème',
      );

  String get _otherDescriptionFieldLabel => _copy(
        de: 'Problembeschreibung',
        it: 'Descrizione problema',
        en: 'Problem description',
        fr: 'Description du problème',
      );

  String _requestStatusLabel(String status) => _copy(
        de: switch (status) {
          'confirmed' => 'Termin bestaetigt',
          'in_progress' => 'Fahrzeug in Bearbeitung',
          'completed' => 'Reparatur abgeschlossen',
          'cancelled' => 'Termin storniert',
          _ => 'Anfrage gesendet',
        },
        it: switch (status) {
          'confirmed' => 'Appuntamento confermato',
          'in_progress' => 'Veicolo in lavorazione',
          'completed' => 'Riparazione completata',
          'cancelled' => 'Appuntamento annullato',
          _ => 'Richiesta inviata',
        },
        en: switch (status) {
          'confirmed' => 'Appointment confirmed',
          'in_progress' => 'Vehicle in progress',
          'completed' => 'Repair completed',
          'cancelled' => 'Appointment cancelled',
          _ => 'Request sent',
        },
        fr: switch (status) {
          'confirmed' => 'Rendez-vous confirme',
          'in_progress' => 'Vehicule en reparation',
          'completed' => 'Reparation terminee',
          'cancelled' => 'Rendez-vous annule',
          _ => 'Demande envoyee',
        },
      );

  String _statusUpdatedSnackBarText() => _copy(
        de: 'Anfragestatus aktualisiert',
        it: 'Stato richiesta aggiornato',
        en: 'Request status updated',
        fr: 'Statut de la demande mis a jour',
      );

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'in_progress':
        return const Color(0xFF7C3AED);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'pending':
      default:
        return const Color(0xFFEA580C);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.event_available_outlined;
      case 'in_progress':
        return Icons.autorenew_rounded;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'pending':
      default:
        return Icons.schedule_send_outlined;
    }
  }

  String _lastUpdatedLabel() => _copy(
        de: 'Letzte Aktualisierung',
        it: 'Ultimo aggiornamento',
        en: 'Last update',
        fr: 'Derniere mise a jour',
      );

  String _appointmentDateLabel() => _copy(
        de: 'Termindatum',
        it: 'Data appuntamento',
        en: 'Appointment date',
        fr: 'Date du rendez-vous',
      );

  String _pdfActionsTitle() => _copy(
        de: 'PDF',
        it: 'PDF',
        en: 'PDF',
        fr: 'PDF',
      );

  String _pdfShareLabel() => _copy(
        de: 'PDF teilen',
        it: 'Condividi PDF',
        en: 'Share PDF',
        fr: 'Partager PDF',
      );

  String _pdfLoadingTitle() => _copy(
        de: 'PDF wird erstellt...',
        it: 'Creazione PDF...',
        en: 'Creating PDF...',
        fr: 'Creation du PDF...',
      );

  String _pdfLoadingSubtitle() => _copy(
        de: 'Bitte warten Sie einen Moment.',
        it: 'Attendere qualche secondo.',
        en: 'Please wait a moment.',
        fr: 'Veuillez patienter un instant.',
      );

  String _pdfShareErrorText() => _copy(
        de: 'PDF konnte nicht geteilt werden.',
        it: 'Impossibile condividere il PDF.',
        en: 'Unable to share the PDF.',
        fr: 'Impossible de partager le PDF.',
      );

  String _pdfUnavailableText() => _copy(
        de: 'PDF ist nur fuer Schadensanfragen verfuegbar.',
        it: 'Il PDF e disponibile solo per richieste danni.',
        en: 'PDF is only available for damage requests.',
        fr: 'Le PDF est disponible uniquement pour les demandes dommage.',
      );

  String _pdfShareDescriptionText() => _copy(
        de: 'Teilen Sie den PDF-Bericht per Mail, WhatsApp oder speichern Sie ihn in Dateien.',
        it: 'Condividi il PDF via Mail, WhatsApp oppure salvalo su File.',
        en: 'Share the PDF report by Mail, WhatsApp or save it to Files.',
        fr: 'Partagez le rapport PDF par mail, WhatsApp ou enregistrez-le dans Fichiers.',
      );

  String _pdfShareFallbackText(String claimId) => _copy(
        de: 'PDF-Bericht fuer die Anfrage $claimId',
        it: 'PDF generato per la richiesta $claimId',
        en: 'PDF generated for request $claimId',
        fr: 'PDF genere pour la demande $claimId',
      );

  String _workshopFallbackName() => _copy(
        de: 'CrashForm Partnerwerkstatt',
        it: 'CrashForm Partnerwerkstatt',
        en: 'CrashForm Partner Workshop',
        fr: 'Atelier partenaire CrashForm',
      );

  String _localizedRequestLocale() {
    final appLocale =
        Localizations.localeOf(context).languageCode.toLowerCase();
    if (appLocale.startsWith('it')) return 'it';
    if (appLocale.startsWith('en')) return 'en';
    if (appLocale.startsWith('fr')) return 'fr';
    if (appLocale.startsWith('de')) return 'de';

    final raw = request.locale?.trim().toLowerCase() ?? '';
    if (raw.startsWith('it')) return 'it';
    if (raw.startsWith('en')) return 'en';
    if (raw.startsWith('fr')) return 'fr';
    if (raw.startsWith('de')) return 'de';
    return 'de';
  }

  String _glassDamageDateLabel() {
    final raw = request.glassDamageDate?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toLocal().toIso8601String().substring(0, 10);
  }

  String _statusUpdatedAtLabel() {
    final raw = request.statusUpdatedAt?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed
        .toLocal()
        .toIso8601String()
        .replaceFirst('T', ' ')
        .substring(0, 16);
  }

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshRequest(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _hailDamageDateLabel() {
    final raw = request.hailDamageDate?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toLocal().toIso8601String().substring(0, 10);
  }

  String _hailDamageTimeLabel() {
    final raw = request.hailDamageTime?.trim() ?? '';
    if (raw.isEmpty) return '-';
    return raw.length == 5
        ? raw
        : raw.substring(0, raw.length >= 5 ? 5 : raw.length);
  }

  String _marderDamageDateLabel() {
    final raw = request.marderDamageDate?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toLocal().toIso8601String().substring(0, 10);
  }

  String _marderDamageTimeLabel() {
    final raw = request.marderDamageTime?.trim() ?? '';
    if (raw.isEmpty) return '-';
    return raw.length == 5
        ? raw
        : raw.substring(0, raw.length >= 5 ? 5 : raw.length);
  }

  String _marderDamageDrivableLabel() {
    return _drivableAnswerLabel(request.marderDamageDrivable);
  }

  String _drivableAnswerLabel(String? rawValue) {
    switch (rawValue?.trim()) {
      case 'yes':
        return _copy(
          de: 'Ja',
          it: 'Sì',
          en: 'Yes',
          fr: 'Oui',
        );
      case 'no':
        return _copy(
          de: 'Nein',
          it: 'No',
          en: 'No',
          fr: 'Non',
        );
      case 'not_sure':
        return _copy(
          de: 'Unsicher',
          it: 'Non sicuro',
          en: 'Not sure',
          fr: 'Pas sûr',
        );
      default:
        return '-';
    }
  }

  String _fullDamageDateLabel() {
    final raw = request.fullDamageDate?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toLocal().toIso8601String().substring(0, 10);
  }

  String _fullDamageTimeLabel() {
    final raw = request.fullDamageTime?.trim() ?? '';
    if (raw.isEmpty) return '-';
    return raw.length == 5
        ? raw
        : raw.substring(0, raw.length >= 5 ? 5 : raw.length);
  }

  String _fullDamageDrivableLabel() {
    return _drivableAnswerLabel(request.fullDamageDrivable);
  }

  String _otherDamageDateLabel() {
    final raw = request.otherDamageDate?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toLocal().toIso8601String().substring(0, 10);
  }

  String _otherDamageTimeLabel() {
    final raw = request.otherDamageTime?.trim() ?? '';
    if (raw.isEmpty) return '-';
    return raw.length == 5
        ? raw
        : raw.substring(0, raw.length >= 5 ? 5 : raw.length);
  }

  String _otherDamageCategoryLabel() {
    switch (request.otherDamageCategory?.trim()) {
      case 'engine_warning':
        return _copy(
          de: 'Motorwarnleuchte',
          it: 'Spia motore',
          en: 'Engine warning light',
          fr: 'Voyant moteur',
        );
      case 'battery':
        return _copy(
          de: 'Batterieproblem',
          it: 'Problema batteria',
          en: 'Battery problem',
          fr: 'Problème de batterie',
        );
      case 'air_conditioning':
        return _copy(
          de: 'Klimaanlage',
          it: 'Aria condizionata',
          en: 'Air conditioning',
          fr: 'Climatisation',
        );
      case 'electronics':
        return _copy(
          de: 'Elektronikproblem',
          it: 'Problema elettronico',
          en: 'Electronic problem',
          fr: 'Problème électronique',
        );
      case 'noise_vibration':
        return _copy(
          de: 'Geräusch/Vibration',
          it: 'Rumore/Vibrazione',
          en: 'Noise/Vibration',
          fr: 'Bruit/Vibration',
        );
      case 'recall':
        return _copy(
          de: 'Rückrufaktion',
          it: 'Richiamo ufficiale',
          en: 'Official recall',
          fr: 'Rappel officiel',
        );
      case 'other':
        return _copy(
          de: 'Sonstiges',
          it: 'Altro',
          en: 'Other',
          fr: 'Autre',
        );
      default:
        return '-';
    }
  }

  String _parkingDamageDateLabel() {
    final raw = request.parkingDamageDate?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toLocal().toIso8601String().substring(0, 10);
  }

  String _parkingDamageTimeLabel() {
    final raw = request.parkingDamageTime?.trim() ?? '';
    if (raw.isEmpty) return '-';
    return raw.length == 5
        ? raw
        : raw.substring(0, raw.length >= 5 ? 5 : raw.length);
  }

  String _damageTownValue() {
    if (_isHailDamageRequest) return request.hailDamageTown?.trim() ?? '';
    if (_isMartenDamageRequest) return request.marderDamageTown?.trim() ?? '';
    if (_isComprehensiveDamageRequest) {
      return request.fullDamageTown?.trim() ?? '';
    }
    if (_isOtherDamageRequest) return request.otherDamageTown?.trim() ?? '';
    if (_isParkingDamageRequest) return request.parkingDamageTown?.trim() ?? '';
    return request.glassDamageTown?.trim() ?? '';
  }

  String _damageDateValue() {
    if (_isHailDamageRequest) return request.hailDamageDate?.trim() ?? '';
    if (_isMartenDamageRequest) return request.marderDamageDate?.trim() ?? '';
    if (_isComprehensiveDamageRequest) {
      return request.fullDamageDate?.trim() ?? '';
    }
    if (_isOtherDamageRequest) return request.otherDamageDate?.trim() ?? '';
    if (_isParkingDamageRequest) return request.parkingDamageDate?.trim() ?? '';
    return request.glassDamageDate?.trim() ?? '';
  }

  String _damageDateLabel() {
    if (_isHailDamageRequest) return _hailDamageDateLabel();
    if (_isMartenDamageRequest) return _marderDamageDateLabel();
    if (_isComprehensiveDamageRequest) return _fullDamageDateLabel();
    if (_isOtherDamageRequest) return _otherDamageDateLabel();
    if (_isParkingDamageRequest) return _parkingDamageDateLabel();
    return _glassDamageDateLabel();
  }

  String _resolvedPhotoUrl(String source) {
    final trimmed = source.trim();
    if (!trimmed.startsWith('http')) return trimmed;
    try {
      return Uri.parse(trimmed).toString();
    } catch (_) {
      return trimmed;
    }
  }

  String _shortUrl(String url) {
    if (url.length <= 90) return url;
    return '${url.substring(0, 87)}...';
  }

  List<String> _readImageListFromNotes(String key) {
    final notes = request.notes?.trim() ?? '';
    if (notes.isEmpty || !notes.startsWith('{')) return const [];
    try {
      final decoded = jsonDecode(notes);
      if (decoded is Map && decoded[key] is List) {
        return (decoded[key] as List)
            .map((image) => image?.toString().trim() ?? '')
            .where((image) => image.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  List<String> _vehicleDocumentImageSources() {
    final direct = request.glassDamageVehicleDocumentImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('glassDamageVehicleDocumentImages');
  }

  List<String> _closeGlassImageSources() {
    final direct = request.glassDamageCloseGlassImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('glassDamageCloseGlassImages');
  }

  List<String> _frontVehicleImageSources() {
    final direct = request.glassDamageFrontVehicleImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('glassDamageFrontVehicleImages');
  }

  List<String> _glassImageSources() {
    final direct = request.glassDamageImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;

    final notes = request.notes?.trim() ?? '';
    if (notes.isEmpty || !notes.startsWith('{')) return const [];

    try {
      final decoded = jsonDecode(notes);
      if (decoded is Map && decoded['glassDamageImages'] is List) {
        return (decoded['glassDamageImages'] as List)
            .map((image) => image?.toString().trim() ?? '')
            .where((image) => image.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    return const [];
  }

  List<String> _glassCurrentKmImageSources() {
    final direct = request.glassDamageCurrentKmImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('glassDamageCurrentKmImages');
  }

  List<String> _hailDamageImageSources() {
    final direct = request.hailDamageDamageImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    final specific = _readImageListFromNotes('hailDamageDamageImages');
    if (specific.isNotEmpty) return specific;
    return _readImageListFromNotes('hailDamageImages');
  }

  List<String> _hailVehicleDocumentImageSources() {
    final direct = request.hailDamageVehicleDocumentImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('hailDamageVehicleDocumentImages');
  }

  List<String> _hailOverviewImageSources() {
    final direct = request.hailDamageOverviewImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('hailDamageOverviewImages');
  }

  List<String> _hailCurrentKmImageSources() {
    final direct = request.hailDamageCurrentKmImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('hailDamageCurrentKmImages');
  }

  List<String> _hailExtraImageSources() {
    final direct = request.hailDamageExtraImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('hailDamageExtraImages');
  }

  List<String> _marderVehicleDocumentImageSources() {
    final direct = request.marderDamageVehicleDocumentImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('marderDamageVehicleDocumentImages');
  }

  List<String> _marderEngineBayImageSources() {
    final direct = request.marderDamageEngineBayImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('marderDamageEngineBayImages');
  }

  List<String> _marderCableImageSources() {
    final direct = request.marderDamageCableImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('marderDamageCableImages');
  }

  List<String> _marderCurrentKmImageSources() {
    final direct = request.marderDamageCurrentKmImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('marderDamageCurrentKmImages');
  }

  List<String> _marderExtraImageSources() {
    final direct = request.marderDamageExtraImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('marderDamageExtraImages');
  }

  List<String> _fullVehicleDocumentImageSources() {
    final direct = request.fullDamageVehicleDocumentImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('fullDamageVehicleDocumentImages');
  }

  List<String> _fullCloseImageSources() {
    final direct = request.fullDamageCloseImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('fullDamageCloseImages');
  }

  List<String> _fullOverviewImageSources() {
    final direct = request.fullDamageOverviewImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('fullDamageOverviewImages');
  }

  List<String> _fullCurrentKmImageSources() {
    final direct = request.fullDamageCurrentKmImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('fullDamageCurrentKmImages');
  }

  List<String> _fullExtraImageSources() {
    final direct = request.fullDamageExtraImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('fullDamageExtraImages');
  }

  List<String> _otherVehicleDocumentImageSources() {
    final direct = request.otherDamageVehicleDocumentImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('otherDamageVehicleDocumentImages');
  }

  List<String> _otherProblemImageSources() {
    final direct = request.otherDamageProblemImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('otherDamageProblemImages');
  }

  List<String> _otherCurrentKmImageSources() {
    final direct = request.otherDamageCurrentKmImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('otherDamageCurrentKmImages');
  }

  List<String> _otherExtraImageSources() {
    final direct = request.otherDamageExtraImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('otherDamageExtraImages');
  }

  List<String> _parkingDamageImageSources() {
    final direct = request.parkingDamageDamageImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    final specific = _readImageListFromNotes('parkingDamageDamageImages');
    if (specific.isNotEmpty) return specific;
    return _readImageListFromNotes('parkingDamageImages');
  }

  List<String> _parkingVehicleDocumentImageSources() {
    final direct = request.parkingDamageVehicleDocumentImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('parkingDamageVehicleDocumentImages');
  }

  List<String> _parkingOverviewImageSources() {
    final direct = request.parkingDamageOverviewImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('parkingDamageOverviewImages');
  }

  List<String> _parkingCurrentKmImageSources() {
    final direct = request.parkingDamageCurrentKmImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('parkingDamageCurrentKmImages');
  }

  List<String> _parkingExtraImageSources() {
    final direct = request.parkingDamageExtraImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('parkingDamageExtraImages');
  }

  Widget _photoGrid(List<String> images) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 700 ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: images.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final image = images[index];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openPhotoViewer(image),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _GlassDamageImage(
                  source: image,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                  showLoadingIndicator: true,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _photoSection({
    required String title,
    required List<String> images,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _photoGrid(images),
      ],
    );
  }

  Future<void> _openPhotoViewer(String source) async {
    final url = _resolvedPhotoUrl(source);
    debugPrint('OPEN GLASS PHOTO URL: $url');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    child: Center(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: url.startsWith('http')
                            ? Image.network(
                                url,
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white,
                                        size: 42,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Foto non caricata',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _shortUrl(url),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : _GlassDamageImage(
                                source: url,
                                fit: BoxFit.contain,
                                borderRadius: BorderRadius.zero,
                                showLoadingIndicator: true,
                              ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    tooltip: _closePhotoText,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshRequest({bool showSnackBar = false}) async {
    final updated = await _service.fetchRequestById(request.id);
    if (!mounted || updated == null) return;
    setState(() {
      _request = updated;
    });
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_statusUpdatedSnackBarText())),
      );
    }
  }

  Future<void> _sharePremiumPdf() async {
    if (!_supportsPremiumWorkshopPdf) {
      _showSnackBar(_pdfUnavailableText());
      return;
    }

    setState(() => _pdfBusy = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final pdf = await _generatePremiumPdf();
      if (!mounted) return;
      await _sharePdfResult(pdf);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(_pdfShareErrorText());
    } finally {
      if (mounted) {
        setState(() => _pdfBusy = false);
      }
    }
  }

  Future<PremiumWorkshopPdfResult> _generatePremiumPdf() {
    return _premiumPdfService.generatePremiumWorkshopPdf(
      request: request,
      localeCode: _localizedRequestLocale(),
      workshopName: _workshopFallbackName(),
    );
  }

  Future<void> _sharePdfResult(PremiumWorkshopPdfResult pdf) async {
    final shareOrigin = _sharePositionOrigin();
    final shareText = _pdfShareFallbackText(request.id);

    if (kIsWeb) {
      final originalDownloadFallback = Share.downloadFallbackEnabled;
      try {
        Share.downloadFallbackEnabled = false;
        await Share.shareXFiles(
          [
            XFile.fromData(
              pdf.bytes,
              mimeType: 'application/pdf',
              name: pdf.fileName,
            ),
          ],
          subject: pdf.fileName,
          text: shareText,
          sharePositionOrigin: shareOrigin,
          fileNameOverrides: [pdf.fileName],
        );
      } catch (_) {
        await Share.share(
          shareText,
          subject: pdf.fileName,
          sharePositionOrigin: shareOrigin,
        );
      } finally {
        Share.downloadFallbackEnabled = originalDownloadFallback;
      }
      return;
    }

    final file = await _writePdfFile(pdf.bytes, pdf.fileName);
    try {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: pdf.fileName)],
        text: shareText,
        subject: pdf.fileName,
        sharePositionOrigin: shareOrigin,
        fileNameOverrides: [pdf.fileName],
      );
    } catch (_) {
      await Share.share(
        shareText,
        subject: pdf.fileName,
        sharePositionOrigin: shareOrigin,
      );
    }
  }

  Rect? _sharePositionOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  Future<File> _writePdfFile(Uint8List bytes, String fileName) async {
    final directory = await getTemporaryDirectory();
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final path = '${directory.path}/$safeFileName';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _statusCard(BuildContext context) {
    final theme = Theme.of(context);
    final status = request.requestStatus;
    final statusColor = _statusColor(status);
    const progressSteps = ['pending', 'confirmed', 'in_progress', 'completed'];
    final currentIndex = progressSteps.indexOf(status);
    final isCancelled = status == 'cancelled';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: statusColor.withOpacity(0.08),
        border: Border.all(color: statusColor.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon(status), color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _requestStatusLabel(status),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_lastUpdatedLabel()}: ${_statusUpdatedAtLabel()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_appointmentDateLabel()}: ${request.appointmentDate.toLocal().toIso8601String().substring(0, 10)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isCancelled)
            Text(
              _requestStatusLabel(status),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Row(
              children: List.generate(progressSteps.length, (index) {
                final active = currentIndex >= index;
                return Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: active
                              ? _statusColor(progressSteps[index])
                              : theme.dividerColor.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (index != progressSteps.length - 1)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: currentIndex > index
                                  ? _statusColor(progressSteps[index + 1])
                                      .withOpacity(0.55)
                                  : theme.dividerColor.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _photosSection() {
    if (_isHailDamageRequest) {
      final hailVehicleDocumentImages = _hailVehicleDocumentImageSources();
      final hailDamageImages = _hailDamageImageSources();
      final hailOverviewImages = _hailOverviewImageSources();
      final hailCurrentKmImages = _hailCurrentKmImageSources();
      final hailExtraImages = _hailExtraImageSources();
      final hasSpecificSections = hailVehicleDocumentImages.isNotEmpty ||
          hailDamageImages.isNotEmpty ||
          hailOverviewImages.isNotEmpty ||
          hailCurrentKmImages.isNotEmpty ||
          hailExtraImages.isNotEmpty;
      final sections = <Widget>[
        if (hailVehicleDocumentImages.isNotEmpty)
          _photoSection(
            title: _hailVehicleDocumentPhotosTitle,
            images: hailVehicleDocumentImages,
          ),
        if (hailDamageImages.isNotEmpty)
          _photoSection(
            title: _hailDamagePhotosTitle,
            images: hailDamageImages,
          ),
        if (hailOverviewImages.isNotEmpty)
          _photoSection(
            title: _hailOverviewPhotosTitle,
            images: hailOverviewImages,
          ),
        if (hailCurrentKmImages.isNotEmpty)
          _photoSection(
            title: _currentKmPhotosTitle,
            images: hailCurrentKmImages,
          ),
        if (hailExtraImages.isNotEmpty)
          _photoSection(
            title: _hailExtraPhotosTitle,
            images: hailExtraImages,
          ),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (hasSpecificSections) ...[
            for (var i = 0; i < sections.length; i++) ...[
              sections[i],
              if (i != sections.length - 1) const SizedBox(height: 12),
            ],
          ] else
            Text(
              _noPhotosText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      );
    }

    if (_isParkingDamageRequest) {
      final parkingVehicleDocumentImages =
          _parkingVehicleDocumentImageSources();
      final parkingDamageImages = _parkingDamageImageSources();
      final parkingOverviewImages = _parkingOverviewImageSources();
      final parkingCurrentKmImages = _parkingCurrentKmImageSources();
      final parkingExtraImages = _parkingExtraImageSources();
      final hasSpecificSections = parkingVehicleDocumentImages.isNotEmpty ||
          parkingDamageImages.isNotEmpty ||
          parkingOverviewImages.isNotEmpty ||
          parkingCurrentKmImages.isNotEmpty ||
          parkingExtraImages.isNotEmpty;
      final sections = <Widget>[
        if (parkingVehicleDocumentImages.isNotEmpty)
          _photoSection(
            title: _parkingVehicleDocumentPhotosTitle,
            images: parkingVehicleDocumentImages,
          ),
        if (parkingDamageImages.isNotEmpty)
          _photoSection(
            title: _parkingDamagePhotosTitle,
            images: parkingDamageImages,
          ),
        if (parkingOverviewImages.isNotEmpty)
          _photoSection(
            title: _parkingOverviewPhotosTitle,
            images: parkingOverviewImages,
          ),
        if (parkingCurrentKmImages.isNotEmpty)
          _photoSection(
            title: _currentKmPhotosTitle,
            images: parkingCurrentKmImages,
          ),
        if (parkingExtraImages.isNotEmpty)
          _photoSection(
            title: _parkingExtraPhotosTitle,
            images: parkingExtraImages,
          ),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (hasSpecificSections) ...[
            for (var i = 0; i < sections.length; i++) ...[
              sections[i],
              if (i != sections.length - 1) const SizedBox(height: 12),
            ],
          ] else
            Text(
              _noPhotosText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      );
    }

    if (_isMartenDamageRequest) {
      final marderVehicleDocumentImages = _marderVehicleDocumentImageSources();
      final marderEngineBayImages = _marderEngineBayImageSources();
      final marderCableImages = _marderCableImageSources();
      final marderCurrentKmImages = _marderCurrentKmImageSources();
      final marderExtraImages = _marderExtraImageSources();
      final hasSpecificSections = marderVehicleDocumentImages.isNotEmpty ||
          marderEngineBayImages.isNotEmpty ||
          marderCableImages.isNotEmpty ||
          marderCurrentKmImages.isNotEmpty ||
          marderExtraImages.isNotEmpty;
      final sections = <Widget>[
        if (marderVehicleDocumentImages.isNotEmpty)
          _photoSection(
            title: _marderVehicleDocumentPhotosTitle,
            images: marderVehicleDocumentImages,
          ),
        if (marderEngineBayImages.isNotEmpty)
          _photoSection(
            title: _marderEngineBayPhotosTitle,
            images: marderEngineBayImages,
          ),
        if (marderCableImages.isNotEmpty)
          _photoSection(
            title: _marderCablePhotosTitle,
            images: marderCableImages,
          ),
        if (marderCurrentKmImages.isNotEmpty)
          _photoSection(
            title: _currentKmPhotosTitle,
            images: marderCurrentKmImages,
          ),
        if (marderExtraImages.isNotEmpty)
          _photoSection(
            title: _marderExtraPhotosTitle,
            images: marderExtraImages,
          ),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (hasSpecificSections) ...[
            for (var i = 0; i < sections.length; i++) ...[
              sections[i],
              if (i != sections.length - 1) const SizedBox(height: 12),
            ],
          ] else
            Text(
              _noPhotosText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      );
    }

    if (_isComprehensiveDamageRequest) {
      final fullVehicleDocumentImages = _fullVehicleDocumentImageSources();
      final fullCloseImages = _fullCloseImageSources();
      final fullOverviewImages = _fullOverviewImageSources();
      final fullCurrentKmImages = _fullCurrentKmImageSources();
      final fullExtraImages = _fullExtraImageSources();
      final hasSpecificSections = fullVehicleDocumentImages.isNotEmpty ||
          fullCloseImages.isNotEmpty ||
          fullOverviewImages.isNotEmpty ||
          fullCurrentKmImages.isNotEmpty ||
          fullExtraImages.isNotEmpty;
      final sections = <Widget>[
        if (fullVehicleDocumentImages.isNotEmpty)
          _photoSection(
            title: _fullVehicleDocumentPhotosTitle,
            images: fullVehicleDocumentImages,
          ),
        if (fullCloseImages.isNotEmpty)
          _photoSection(
            title: _fullClosePhotosTitle,
            images: fullCloseImages,
          ),
        if (fullOverviewImages.isNotEmpty)
          _photoSection(
            title: _fullOverviewPhotosTitle,
            images: fullOverviewImages,
          ),
        if (fullCurrentKmImages.isNotEmpty)
          _photoSection(
            title: _currentKmPhotosTitle,
            images: fullCurrentKmImages,
          ),
        if (fullExtraImages.isNotEmpty)
          _photoSection(
            title: _fullExtraPhotosTitle,
            images: fullExtraImages,
          ),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (hasSpecificSections) ...[
            for (var i = 0; i < sections.length; i++) ...[
              sections[i],
              if (i != sections.length - 1) const SizedBox(height: 12),
            ],
          ] else
            Text(
              _noPhotosText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      );
    }

    if (_isOtherDamageRequest) {
      final otherVehicleDocumentImages = _otherVehicleDocumentImageSources();
      final otherProblemImages = _otherProblemImageSources();
      final otherCurrentKmImages = _otherCurrentKmImageSources();
      final otherExtraImages = _otherExtraImageSources();
      final hasSpecificSections = otherVehicleDocumentImages.isNotEmpty ||
          otherProblemImages.isNotEmpty ||
          otherCurrentKmImages.isNotEmpty ||
          otherExtraImages.isNotEmpty;
      final sections = <Widget>[
        if (otherVehicleDocumentImages.isNotEmpty)
          _photoSection(
            title: _otherVehicleDocumentPhotosTitle,
            images: otherVehicleDocumentImages,
          ),
        if (otherProblemImages.isNotEmpty)
          _photoSection(
            title: _otherProblemPhotosTitle,
            images: otherProblemImages,
          ),
        if (otherCurrentKmImages.isNotEmpty)
          _photoSection(
            title: _currentKmPhotosTitle,
            images: otherCurrentKmImages,
          ),
        if (otherExtraImages.isNotEmpty)
          _photoSection(
            title: _otherExtraPhotosTitle,
            images: otherExtraImages,
          ),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (hasSpecificSections) ...[
            for (var i = 0; i < sections.length; i++) ...[
              sections[i],
              if (i != sections.length - 1) const SizedBox(height: 12),
            ],
          ] else
            Text(
              _noPhotosText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      );
    }

    final vehicleDocumentImages = _vehicleDocumentImageSources();
    final closeGlassImages = _closeGlassImageSources();
    final frontVehicleImages = _frontVehicleImageSources();
    final currentKmImages = _glassCurrentKmImageSources();
    final fallbackImages = _glassImageSources();
    final categorizedImages = <String>{
      ...vehicleDocumentImages.map((image) => image.trim()),
      ...closeGlassImages.map((image) => image.trim()),
      ...frontVehicleImages.map((image) => image.trim()),
      ...currentKmImages.map((image) => image.trim()),
    };
    final fallbackOnlyImages = fallbackImages
        .where((image) => !categorizedImages.contains(image.trim()))
        .toList();
    final hasSpecificSections = vehicleDocumentImages.isNotEmpty ||
        closeGlassImages.isNotEmpty ||
        frontVehicleImages.isNotEmpty ||
        currentKmImages.isNotEmpty;
    final sections = <Widget>[
      if (vehicleDocumentImages.isNotEmpty)
        _photoSection(
          title: _vehicleDocumentPhotosTitle,
          images: vehicleDocumentImages,
        ),
      if (closeGlassImages.isNotEmpty)
        _photoSection(
          title: _closeGlassPhotosTitle,
          images: closeGlassImages,
        ),
      if (frontVehicleImages.isNotEmpty)
        _photoSection(
          title: _frontVehiclePhotosTitle,
          images: frontVehicleImages,
        ),
      if (currentKmImages.isNotEmpty)
        _photoSection(
          title: _currentKmPhotosTitle,
          images: currentKmImages,
        ),
      if (fallbackOnlyImages.isNotEmpty)
        _photoSection(
          title: _photosTitle,
          images: fallbackOnlyImages,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (hasSpecificSections) ...[
          for (var i = 0; i < sections.length; i++) ...[
            sections[i],
            if (i != sections.length - 1) const SizedBox(height: 12),
          ],
        ] else if (fallbackImages.isEmpty)
          Text(
            _noPhotosText,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          _photoSection(
            title: _photosTitle,
            images: fallbackImages,
          ),
      ],
    );
  }

  Widget _pdfActionsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _pdfActionsTitle(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _pdfBusy ? null : _sharePremiumPdf,
                icon: const Icon(Icons.share_rounded),
                label: Text(_pdfShareLabel()),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _pdfShareDescriptionText(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfLoadingOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.28),
          alignment: Alignment.center,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFFEAEAEA),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF4B7BFF),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _pdfLoadingTitle(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _pdfLoadingSubtitle(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String value(String key) => (request.toMap()[key] ?? '').toString();

    String dateLabel() =>
        request.appointmentDate.toLocal().toIso8601String().substring(0, 10);

    String timeLabel() {
      final v = request.appointmentTime;
      if (v.isEmpty) return '-';
      return v.length == 5 ? '$v:00' : v;
    }

    String serviceLabel() {
      final serviceType = request.serviceType;
      final damageType = value('damage_type');
      if (serviceType.startsWith('damage_')) {
        switch (damageType) {
          case 'damage_glass':
            return l10n.damage_glass;
          case 'damage_hail':
            return l10n.damage_hail;
          case 'damage_marten':
            return l10n.damage_marten;
          case 'damage_parking':
            return l10n.damage_parking;
          case 'damage_comprehensive':
            return l10n.damage_comprehensive;
          case 'damage_other':
            return _copy(
              de: 'Sonstige Schäden oder technische Probleme',
              it: 'Altri danni o problemi tecnici',
              en: 'Other damages or technical problems',
              fr: 'Autres dommages ou problèmes techniques',
            );
          default:
            return l10n.service_type_damage;
        }
      }
      if (serviceType == 'service_anmelden') return l10n.service_type_service;
      if (serviceType == 'raeder_sommer' || serviceType == 'raeder_winter') {
        return l10n.service_type_tires;
      }
      return serviceType.isEmpty ? l10n.my_requests_title : serviceType;
    }

    final canCancel =
        request.id.isNotEmpty && request.requestStatus != 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anfrage Details'),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statusCard(context),
                          const SizedBox(height: 16),
                          _row(l10n.service_type_service, serviceLabel()),
                          if (_isTireRequest)
                            _row(
                              _tireServiceTypeFieldLabel,
                              _tireServiceTypeLabel,
                            ),
                          _row('Datum', dateLabel()),
                          _row('Uhrzeit', timeLabel()),
                          _row('Werkstatt', value('workshop_name')),
                          _row(l10n.license_plate_label,
                              request.licensePlate ?? ''),
                          _row('Name', request.customerName ?? ''),
                          _row('Telefon', request.customerPhone ?? ''),
                          _row('E-Mail', request.customerEmail ?? ''),
                          if (_damageTownValue().isNotEmpty)
                            _row(_damageTownFieldLabel, _damageTownValue()),
                          if (_damageDateValue().isNotEmpty)
                            _row(_damageDateFieldLabel, _damageDateLabel()),
                          if (_isHailDamageRequest &&
                              (request.hailDamageTime ?? '').trim().isNotEmpty)
                            _row(_damageTimeFieldLabel, _hailDamageTimeLabel()),
                          if (_isMartenDamageRequest &&
                              (request.marderDamageTime ?? '')
                                  .trim()
                                  .isNotEmpty)
                            _row(_damageTimeFieldLabel,
                                _marderDamageTimeLabel()),
                          if (_isComprehensiveDamageRequest &&
                              (request.fullDamageTime ?? '').trim().isNotEmpty)
                            _row(_damageTimeFieldLabel, _fullDamageTimeLabel()),
                          if (_isOtherDamageRequest &&
                              (request.otherDamageTime ?? '').trim().isNotEmpty)
                            _row(
                                _damageTimeFieldLabel, _otherDamageTimeLabel()),
                          if (_isParkingDamageRequest &&
                              (request.parkingDamageTime ?? '')
                                  .trim()
                                  .isNotEmpty)
                            _row(_damageTimeFieldLabel,
                                _parkingDamageTimeLabel()),
                          if (_isMartenDamageRequest &&
                              (request.marderDamageDrivable ?? '')
                                  .trim()
                                  .isNotEmpty)
                            _row(_marderDrivableFieldLabel,
                                _marderDamageDrivableLabel()),
                          if (_isComprehensiveDamageRequest &&
                              (request.fullDamageDrivable ?? '')
                                  .trim()
                                  .isNotEmpty)
                            _row(_fullDrivableFieldLabel,
                                _fullDamageDrivableLabel()),
                          if (_isMartenDamageRequest &&
                              (request.marderDamageDescription ?? '')
                                  .trim()
                                  .isNotEmpty)
                            _row(_marderDescriptionFieldLabel,
                                request.marderDamageDescription!.trim()),
                          if (_isComprehensiveDamageRequest &&
                              (request.fullDamageDescription ?? '')
                                  .trim()
                                  .isNotEmpty)
                            _row(_fullDescriptionFieldLabel,
                                request.fullDamageDescription!.trim()),
                          if (_isOtherDamageRequest &&
                              (request.otherDamageCategory ?? '')
                                  .trim()
                                  .isNotEmpty)
                            _row(_otherCategoryFieldLabel,
                                _otherDamageCategoryLabel()),
                          if (_isOtherDamageRequest &&
                              (request.otherDamageDescription ?? '')
                                  .trim()
                                  .isNotEmpty)
                            _row(_otherDescriptionFieldLabel,
                                request.otherDamageDescription!.trim()),
                          _row('Status',
                              _requestStatusLabel(request.requestStatus)),
                          if ((request.notes ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Notizen',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(request.notes ?? ''),
                          ],
                          if (_hasDamagePhotoSections) _photosSection(),
                        ],
                      ),
                    ),
                  ),
                  if (_supportsPremiumWorkshopPdf) ...[
                    const SizedBox(height: 16),
                    _pdfActionsCard(),
                  ],
                  const SizedBox(height: 16),
                  if (canCancel) _cancelButton(context),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (_pdfBusy) _buildPdfLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _cancelButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Termin stornieren'),
        onPressed: (_busy || _pdfBusy)
            ? null
            : () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Termin stornieren?'),
                    content: const Text(
                        'Möchtest du diese Anfrage wirklich stornieren?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Nein'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Ja'),
                      ),
                    ],
                  ),
                );

                if (ok != true) return;

                setState(() => _busy = true);
                try {
                  await _service.cancelRequest(request.id);
                  if (!mounted) return;
                  Navigator.of(this.context).pop('cancelled');
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('❌ Fehler: $e')),
                  );
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }
}

class _GlassDamageImage extends StatelessWidget {
  const _GlassDamageImage({
    required this.source,
    required this.fit,
    required this.borderRadius,
    this.showLoadingIndicator = false,
  });

  final String source;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final bool showLoadingIndicator;

  @override
  Widget build(BuildContext context) {
    final normalized = source.trim();
    String resolvedNetworkUrl(String value) {
      try {
        return Uri.parse(value).toString();
      } catch (_) {
        return value;
      }
    }

    Widget placeholder() => Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Colors.black12,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined),
        );

    if (normalized.startsWith('http')) {
      final url = resolvedNetworkUrl(normalized);
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          if (!showLoadingIndicator) return placeholder();
          return Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: Colors.black12,
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }

    if (normalized.startsWith('cache:')) {
      final cacheKey = normalized.substring('cache:'.length);
      return FutureBuilder<Uint8List?>(
        future: LocalImageCache.getImage(cacheKey),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) return placeholder();
          return Image.memory(
            bytes,
            fit: fit,
          );
        },
      );
    }

    if (!kIsWeb && normalized.isNotEmpty) {
      return Image.file(
        File(normalized),
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }

    return placeholder();
  }
}
