import 'dart:async';
import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/screens/my_requests_page.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:cid_digitale/services/local_image_cache.dart';
import 'package:cid_digitale/utils/service_booking_helper.dart';
import 'package:cid_digitale/utils/tire_service_type_helper.dart';
import 'package:cid_digitale/widgets/damage_type_picker_sheet.dart';
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

class _SummaryPhotoCountData {
  const _SummaryPhotoCountData({
    required this.title,
    required this.count,
    required this.optional,
  });

  final String title;
  final int count;
  final bool optional;
}

class WorkshopSlotPickerScreen extends StatefulWidget {
  final String title;
  final String serviceType;
  final String? damageType;
  final String? tireServiceType;
  final String? serviceSelectionKey;

  const WorkshopSlotPickerScreen({
    super.key,
    required this.title,
    required this.serviceType,
    this.damageType,
    this.tireServiceType,
    this.serviceSelectionKey,
  });

  @override
  State<WorkshopSlotPickerScreen> createState() =>
      _WorkshopSlotPickerScreenState();
}

class _WorkshopSlotPickerScreenState extends State<WorkshopSlotPickerScreen>
    with SingleTickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  DateTime? _selectedSlot;
  DateTime? _glassDamageDate;
  TimeOfDay? _hailDamageTime;
  bool _showValidationErrors = false;
  bool _loading = false;
  bool _submitting = false;
  bool _loadingSlots = false;
  bool _confirmationAccepted = false;
  bool _summaryCardVisible = false;
  bool _submitPressed = false;
  List<DateTime> _bookedSlots = const [];
  final Set<String> _photoLoadingCategories = <String>{};
  late final AnimationController _skeletonController;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _glassTownCtrl = TextEditingController();
  final _marderDescriptionCtrl = TextEditingController();
  final _fullDamageDescriptionCtrl = TextEditingController();
  final _otherDamageDescriptionCtrl = TextEditingController();
  late final Listenable _summaryFormListenable;
  final _appointmentService = AppointmentRequestsService();
  final _picker = ImagePicker();
  final List<_GlassDamageImageDraft> _glassVehicleDocumentImages = [];
  final List<_GlassDamageImageDraft> _glassCloseGlassImages = [];
  final List<_GlassDamageImageDraft> _glassFrontVehicleImages = [];
  final List<_GlassDamageImageDraft> _glassCurrentKmImages = [];
  final List<_GlassDamageImageDraft> _hailVehicleDocumentImages = [];
  final List<_GlassDamageImageDraft> _hailDamageImages = [];
  final List<_GlassDamageImageDraft> _hailOverviewImages = [];
  final List<_GlassDamageImageDraft> _hailCurrentKmImages = [];
  final List<_GlassDamageImageDraft> _hailExtraImage1 = [];
  final List<_GlassDamageImageDraft> _hailExtraImage2 = [];
  final List<_GlassDamageImageDraft> _marderVehicleDocumentImages = [];
  final List<_GlassDamageImageDraft> _marderEngineBayImages = [];
  final List<_GlassDamageImageDraft> _marderCableImages = [];
  final List<_GlassDamageImageDraft> _marderCurrentKmImages = [];
  final List<_GlassDamageImageDraft> _marderExtraImages = [];
  final List<_GlassDamageImageDraft> _fullVehicleDocumentImages = [];
  final List<_GlassDamageImageDraft> _fullCloseImages = [];
  final List<_GlassDamageImageDraft> _fullOverviewImages = [];
  final List<_GlassDamageImageDraft> _fullCurrentKmImages = [];
  final List<_GlassDamageImageDraft> _fullExtraImages = [];
  final List<_GlassDamageImageDraft> _otherVehicleDocumentImages = [];
  final List<_GlassDamageImageDraft> _otherProblemImages = [];
  final List<_GlassDamageImageDraft> _otherCurrentKmImages = [];
  final List<_GlassDamageImageDraft> _otherExtraImages = [];
  final List<_GlassDamageImageDraft> _parkingVehicleDocumentImages = [];
  final List<_GlassDamageImageDraft> _parkingDamageImages = [];
  final List<_GlassDamageImageDraft> _parkingOverviewImages = [];
  final List<_GlassDamageImageDraft> _parkingCurrentKmImages = [];
  final List<_GlassDamageImageDraft> _parkingExtraImages = [];
  String? _marderDamageDrivable;
  String? _fullDamageDrivable;
  String? _otherDamageCategory;

  bool get _isGlassDamage => widget.serviceType == 'damage_glass';
  bool get _isHailDamage => widget.serviceType == 'damage_hail';
  bool get _isMartenDamage => widget.serviceType == 'damage_marten';
  bool get _isComprehensiveDamage =>
      widget.serviceType == 'damage_comprehensive';
  bool get _isOtherDamage => widget.serviceType == 'damage_other';
  bool get _isParkingDamage => widget.serviceType == 'damage_parking';
  bool get _isTireService => isTireAppointmentService(widget.serviceType);
  bool get _usesDamageDetailsForm =>
      _isGlassDamage ||
      _isHailDamage ||
      _isMartenDamage ||
      _isComprehensiveDamage ||
      _isOtherDamage ||
      _isParkingDamage;
  bool get _usesDamageTimeField =>
      _isHailDamage ||
      _isMartenDamage ||
      _isComprehensiveDamage ||
      _isOtherDamage ||
      _isParkingDamage;
  bool get _showInitialSkeleton => _loadingSlots && _bookedSlots.isEmpty;

  static const _marderDrivableYes = 'yes';
  static const _marderDrivableNo = 'no';
  static const _marderDrivableNotSure = 'not_sure';
  static const _otherCategoryEngineWarning = 'engine_warning';
  static const _otherCategoryBattery = 'battery';
  static const _otherCategoryAirConditioning = 'air_conditioning';
  static const _otherCategoryElectronics = 'electronics';
  static const _otherCategoryNoiseVibration = 'noise_vibration';
  static const _otherCategoryRecall = 'recall';
  static const _otherCategoryOther = 'other';

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

  String _snackTakenSlot(BuildContext context) => _copy(
        context: context,
        de: 'Dieser Termin ist bereits belegt.',
        it: 'Questo appuntamento è già occupato.',
        en: 'This appointment is already booked.',
        fr: 'Ce rendez-vous est déjà réservé.',
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

  String _formHeaderTitle(BuildContext context) {
    if (_isTireService) {
      return localizedTireServiceType(
        tireLocaleCode(context),
        tireServiceType: widget.tireServiceType,
        serviceType: widget.serviceType,
      );
    }
    if (_isComprehensiveDamage) {
      return AppLocalizations.of(context)!.damage_comprehensive;
    }
    if (_isOtherDamage) {
      return _copy(
        context: context,
        de: 'Sonstige Schäden oder technische Probleme',
        it: 'Altri danni o problemi tecnici',
        en: 'Other damages or technical problems',
        fr: 'Autres dommages ou problèmes techniques',
      );
    }
    return widget.title;
  }

  String? _formHeaderSubtitle(BuildContext context) {
    if (_isComprehensiveDamage) {
      return _copy(
        context: context,
        de: 'Kollision mit Objekt oder selbst verursachter Schaden',
        it: 'Collisione con oggetto o danno causato dal conducente',
        en: 'Collision with object or self-caused damage',
        fr: 'Collision avec un objet ou dommage causé par le conducteur',
      );
    }
    if (_isOtherDamage) {
      return _copy(
        context: context,
        de: 'Melden Sie technische Probleme, Warnmeldungen oder sonstige Schäden.',
        it: 'Segnala problemi tecnici, spie o altri danni.',
        en: 'Report technical problems, warning lights or other damages.',
        fr: 'Signalez des problèmes techniques, voyants ou autres dommages.',
      );
    }
    return null;
  }

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
        return _copy(
          context: context,
          de: 'Nahaufnahme Glas',
          it: 'Foto vetro vicino',
          en: 'Close-up glass photo',
          fr: 'Photo rapprochee du verre',
        );
      case AppointmentRequestImageCategory.glassCurrentKm:
      case AppointmentRequestImageCategory.hailCurrentKm:
      case AppointmentRequestImageCategory.parkingCurrentKm:
        return _copy(
          context: context,
          de: 'Foto aktueller KM-Stand',
          it: 'Foto stato attuale KM',
          en: 'Current mileage photo',
          fr: 'Photo kilometrage actuel',
        );
      case AppointmentRequestImageCategory.hailDamage:
        return _copy(
          context: context,
          de: 'Foto Hagelschaden',
          it: 'Foto dei danni da grandine',
          en: 'Hail damage photo',
          fr: 'Photo degats grele',
        );
      case AppointmentRequestImageCategory.hailOverview:
        return _copy(
          context: context,
          de: 'Uebersichtsfoto Fahrzeug',
          it: 'Foto panoramica veicolo',
          en: 'Vehicle overview photo',
          fr: 'Photo generale du vehicule',
        );
      case AppointmentRequestImageCategory.hailVehicleDocument:
        return _copy(
          context: context,
          de: 'Foto Fahrzeugausweis',
          it: 'Foto libretto',
          en: 'Vehicle document photo',
          fr: 'Photo carte grise',
        );
      case AppointmentRequestImageCategory.hailExtra1:
      case AppointmentRequestImageCategory.hailExtra2:
        return _copy(
          context: context,
          de: 'Zusaetzliches Foto',
          it: 'Foto aggiuntiva',
          en: 'Additional photo',
          fr: 'Photo supplementaire',
        );
      case AppointmentRequestImageCategory.marderVehicleDocument:
        return _copy(
          context: context,
          de: 'Foto Fahrzeugausweis',
          it: 'Foto libretto',
          en: 'Vehicle document photo',
          fr: 'Photo carte grise',
        );
      case AppointmentRequestImageCategory.marderEngineBay:
        return _copy(
          context: context,
          de: 'Foto Motorraum',
          it: 'Foto vano motore',
          en: 'Engine bay photo',
          fr: 'Photo compartiment moteur',
        );
      case AppointmentRequestImageCategory.marderCable:
        return _copy(
          context: context,
          de: 'Foto beschädigte Kabel',
          it: 'Foto cavi danneggiati',
          en: 'Damaged cable photo',
          fr: 'Photo cables endommages',
        );
      case AppointmentRequestImageCategory.marderCurrentKm:
        return _copy(
          context: context,
          de: 'Foto aktueller KM-Stand',
          it: 'Foto stato attuale KM',
          en: 'Current mileage photo',
          fr: 'Photo kilometrage actuel',
        );
      case AppointmentRequestImageCategory.marderExtra:
        return _copy(
          context: context,
          de: 'Zusaetzliches Foto',
          it: 'Foto aggiuntiva',
          en: 'Additional photo',
          fr: 'Photo supplementaire',
        );
      case AppointmentRequestImageCategory.fullVehicleDocument:
        return _copy(
          context: context,
          de: 'Foto Fahrzeugausweis',
          it: 'Foto libretto',
          en: 'Vehicle document photo',
          fr: 'Photo carte grise',
        );
      case AppointmentRequestImageCategory.fullClose:
        return _copy(
          context: context,
          de: 'Foto Schaden Nahaufnahme',
          it: 'Foto danno ravvicinata',
          en: 'Damage close-up photo',
          fr: 'Photo gros plan du dommage',
        );
      case AppointmentRequestImageCategory.fullOverview:
        return _copy(
          context: context,
          de: 'Foto Gesamtansicht Fahrzeug',
          it: 'Foto panoramica veicolo',
          en: 'Vehicle overview photo',
          fr: 'Photo vue d ensemble du véhicule',
        );
      case AppointmentRequestImageCategory.fullCurrentKm:
        return _copy(
          context: context,
          de: 'Foto aktueller KM-Stand',
          it: 'Foto stato attuale KM',
          en: 'Current mileage photo',
          fr: 'Photo kilometrage actuel',
        );
      case AppointmentRequestImageCategory.fullExtra:
        return _copy(
          context: context,
          de: 'Zusaetzliches Foto',
          it: 'Foto aggiuntiva',
          en: 'Additional photo',
          fr: 'Photo supplementaire',
        );
      case AppointmentRequestImageCategory.otherVehicleDocument:
        return _copy(
          context: context,
          de: 'Foto Fahrzeugausweis',
          it: 'Foto libretto',
          en: 'Vehicle document photo',
          fr: 'Photo carte grise',
        );
      case AppointmentRequestImageCategory.otherProblem:
        return _copy(
          context: context,
          de: 'Foto Problem / Schaden',
          it: 'Foto problema / danno',
          en: 'Problem / damage photo',
          fr: 'Photo problème / dommage',
        );
      case AppointmentRequestImageCategory.otherCurrentKm:
        return _copy(
          context: context,
          de: 'Foto aktueller KM-Stand',
          it: 'Foto stato attuale KM',
          en: 'Current mileage photo',
          fr: 'Photo kilometrage actuel',
        );
      case AppointmentRequestImageCategory.otherExtra:
        return _copy(
          context: context,
          de: 'Zusaetzliches Foto',
          it: 'Foto aggiuntiva',
          en: 'Additional photo',
          fr: 'Photo supplementaire',
        );
      case AppointmentRequestImageCategory.parkingDamage:
        return _copy(
          context: context,
          de: 'Foto Parkschaden',
          it: 'Foto danno parcheggio',
          en: 'Parking damage photo',
          fr: 'Photo dommage parking',
        );
      case AppointmentRequestImageCategory.parkingOverview:
        return _copy(
          context: context,
          de: 'Uebersichtsfoto Fahrzeug',
          it: 'Foto panoramica veicolo',
          en: 'Vehicle overview photo',
          fr: 'Photo generale du vehicule',
        );
      case AppointmentRequestImageCategory.parkingVehicleDocument:
        return _copy(
          context: context,
          de: 'Foto Fahrzeugausweis',
          it: 'Foto libretto',
          en: 'Vehicle document photo',
          fr: 'Photo carte grise',
        );
      case AppointmentRequestImageCategory.parkingExtra:
        return _copy(
          context: context,
          de: 'Zusaetzliches Foto',
          it: 'Foto aggiuntiva',
          en: 'Additional photo',
          fr: 'Photo supplementaire',
        );
      default:
        return '';
    }
  }

  String _glassSectionSubtitle(BuildContext context, String category) {
    switch (category) {
      case AppointmentRequestImageCategory.vehicleDocument:
        return _copy(
          context: context,
          de: 'Fahrzeugdokument',
          it: 'Documento del veicolo',
          en: 'Vehicle document',
          fr: 'Document du vehicule',
        );
      case AppointmentRequestImageCategory.frontVehicle:
        return _copy(
          context: context,
          de: 'Gesamtansicht des Fahrzeugs',
          it: 'Vista completa del veicolo',
          en: 'Full vehicle view',
          fr: 'Vue complete du vehicule',
        );
      case AppointmentRequestImageCategory.closeGlass:
        return _copy(
          context: context,
          de: 'Detail des Schadens',
          it: 'Dettaglio del danno',
          en: 'Damage detail',
          fr: 'Detail du dommage',
        );
      case AppointmentRequestImageCategory.hailDamage:
      case AppointmentRequestImageCategory.hailOverview:
      case AppointmentRequestImageCategory.hailVehicleDocument:
      case AppointmentRequestImageCategory.hailExtra1:
      case AppointmentRequestImageCategory.hailExtra2:
      case AppointmentRequestImageCategory.hailCurrentKm:
      case AppointmentRequestImageCategory.marderVehicleDocument:
      case AppointmentRequestImageCategory.marderEngineBay:
      case AppointmentRequestImageCategory.marderCable:
      case AppointmentRequestImageCategory.marderCurrentKm:
      case AppointmentRequestImageCategory.marderExtra:
      case AppointmentRequestImageCategory.fullVehicleDocument:
      case AppointmentRequestImageCategory.fullClose:
      case AppointmentRequestImageCategory.fullOverview:
      case AppointmentRequestImageCategory.fullCurrentKm:
      case AppointmentRequestImageCategory.fullExtra:
      case AppointmentRequestImageCategory.otherVehicleDocument:
      case AppointmentRequestImageCategory.otherProblem:
      case AppointmentRequestImageCategory.otherCurrentKm:
      case AppointmentRequestImageCategory.otherExtra:
      case AppointmentRequestImageCategory.parkingDamage:
      case AppointmentRequestImageCategory.parkingOverview:
      case AppointmentRequestImageCategory.parkingVehicleDocument:
      case AppointmentRequestImageCategory.parkingExtra:
      case AppointmentRequestImageCategory.parkingCurrentKm:
      case AppointmentRequestImageCategory.glassCurrentKm:
        return '';
      default:
        return '';
    }
  }

  String _requiredPhotosTitle(BuildContext context) => _copy(
        context: context,
        de: _isHailDamage
            ? 'Fotos Hagelschaden'
            : _isMartenDamage
                ? 'Fotos Marderschaden'
                : _isComprehensiveDamage
                    ? 'Fotos Vollkasko'
                    : _isOtherDamage
                        ? 'Fotos Sonstige Schäden'
                        : _isParkingDamage
                            ? 'Fotos Parkschaden'
                            : 'Benoetigte Fotos',
        it: _isHailDamage
            ? 'Foto danno grandine'
            : _isMartenDamage
                ? 'Foto danno da martora'
                : _isComprehensiveDamage
                    ? 'Foto Vollkasko'
                    : _isOtherDamage
                        ? 'Foto altri danni'
                        : _isParkingDamage
                            ? 'Foto danno parcheggio'
                            : 'Foto richieste',
        en: _isHailDamage
            ? 'Hail damage photos'
            : _isMartenDamage
                ? 'Marten damage photos'
                : _isComprehensiveDamage
                    ? 'Comprehensive damage photos'
                    : _isOtherDamage
                        ? 'Other damage photos'
                        : _isParkingDamage
                            ? 'Parking damage photos'
                            : 'Required photos',
        fr: _isHailDamage
            ? 'Photos degats grele'
            : _isMartenDamage
                ? 'Photos dommage fouine'
                : _isComprehensiveDamage
                    ? 'Photos Vollkasko'
                    : _isOtherDamage
                        ? 'Photos autres dommages'
                        : _isParkingDamage
                            ? 'Photos dommage parking'
                            : 'Photos requises',
      );

  String _requiredPhotosSubtitle(BuildContext context) => _copy(
        context: context,
        de: 'Laden Sie die erforderlichen Bilder für die Anfrage hoch.',
        it: 'Carica le immagini necessarie per la richiesta.',
        en: 'Upload the images needed for the request.',
        fr: 'Téléchargez les images nécessaires pour la demande.',
      );

  String _statusAddLabel(BuildContext context) => _copy(
        context: context,
        de: 'Hinzufügen',
        it: 'Aggiungi',
        en: 'Add',
        fr: 'Ajouter',
      );

  String _statusChangeLabel(BuildContext context) => _copy(
        context: context,
        de: 'Ändern',
        it: 'Modifica',
        en: 'Change',
        fr: 'Modifier',
      );

  String _photoUploadingLabel(BuildContext context) => _copy(
        context: context,
        de: 'Wird hochgeladen...',
        it: 'Caricamento...',
        en: 'Uploading...',
        fr: 'Telechargement...',
      );

  String _submitLoadingLabel(BuildContext context) => _copy(
        context: context,
        de: 'Wird gesendet...',
        it: 'Invio...',
        en: 'Sending...',
        fr: 'Envoi...',
      );

  String _submitOverlayTitle(BuildContext context) => _copy(
        context: context,
        de: 'Anfrage wird gesendet...',
        it: 'Invio richiesta in corso...',
        en: 'Sending request...',
        fr: 'Envoi de la demande...',
      );

  String _submitOverlaySubtitle(BuildContext context) => _copy(
        context: context,
        de: 'Bitte warten Sie einen Moment.',
        it: 'Attendere qualche secondo.',
        en: 'Please wait a moment.',
        fr: 'Veuillez patienter quelques secondes.',
      );

  String _photoAddedLabel(BuildContext context) => _copy(
        context: context,
        de: 'Foto hinzugefügt',
        it: 'Foto aggiunta',
        en: 'Photo added',
        fr: 'Photo ajoutée',
      );

  String _photoLoadingLabel(BuildContext context) => _copy(
        context: context,
        de: 'Wird geladen',
        it: 'Caricamento',
        en: 'Loading',
        fr: 'Chargement',
      );

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

  String _previewPhotoTooltip(BuildContext context) => _copy(
        context: context,
        de: 'Foto anzeigen',
        it: 'Visualizza foto',
        en: 'Preview photo',
        fr: 'Voir la photo',
      );

  String _removePhotoTooltip(BuildContext context) => _copy(
        context: context,
        de: 'Foto entfernen',
        it: 'Rimuovi foto',
        en: 'Remove photo',
        fr: 'Supprimer la photo',
      );

  String _townLabel(BuildContext context) => _copy(
        context: context,
        de: _isOtherDamage
            ? 'In welcher Ortschaft befindet sich das Fahrzeug?'
            : 'In welcher Ortschaft ist es passiert?',
        it: _isOtherDamage
            ? 'In quale località si trova il veicolo?'
            : 'In quale località è successo?',
        en: _isOtherDamage
            ? 'In which town is the vehicle located?'
            : 'In which town did it happen?',
        fr: _isOtherDamage
            ? 'Dans quelle localité se trouve le véhicule ?'
            : 'Dans quelle localité cela s’est-il produit ?',
      );

  String _dateLabel(BuildContext context) => _copy(
        context: context,
        de: _isOtherDamage
            ? 'An welchem Tag trat das Problem auf?'
            : _isMartenDamage
                ? 'An welchem Tag wurde der Schaden bemerkt?'
                : 'An welchem Tag ereignete sich der Schaden?',
        it: _isOtherDamage
            ? 'In quale giorno si è verificato il problema?'
            : _isMartenDamage
                ? 'In quale giorno è stato notato il danno?'
                : 'In quale giorno è avvenuto il danno?',
        en: _isOtherDamage
            ? 'On which day did the problem occur?'
            : _isMartenDamage
                ? 'On which day was the damage noticed?'
                : 'On which day did the damage occur?',
        fr: _isOtherDamage
            ? 'À quelle date le problème s’est-il produit ?'
            : _isMartenDamage
                ? 'À quelle date le dommage a-t-il été constaté ?'
                : 'À quelle date le dommage est-il survenu ?',
      );

  String _hailTimeLabel(BuildContext context) => _copy(
        context: context,
        de: _isOtherDamage
            ? 'Zu welcher Uhrzeit trat das Problem auf?'
            : _isMartenDamage
                ? 'Zu welcher Uhrzeit wurde der Schaden bemerkt?'
                : 'Zu welcher Uhrzeit ist der Schaden passiert?',
        it: _isOtherDamage
            ? 'A che ora si è verificato il problema?'
            : _isMartenDamage
                ? 'A che ora è stato notato il danno?'
                : 'A che ora è avvenuto il danno?',
        en: _isOtherDamage
            ? 'At what time did the problem occur?'
            : _isMartenDamage
                ? 'At what time was the damage noticed?'
                : 'At what time did the damage occur?',
        fr: _isOtherDamage
            ? 'À quelle heure le problème s’est-il produit ?'
            : _isMartenDamage
                ? 'À quelle heure le dommage a-t-il été constaté ?'
                : 'À quelle heure le dommage est-il survenu ?',
      );

  String _pickDateButton(BuildContext context) => _copy(
        context: context,
        de: 'Datum auswählen',
        it: 'Seleziona data',
        en: 'Select date',
        fr: 'Sélectionner la date',
      );

  String _pickTimeButton(BuildContext context) => _copy(
        context: context,
        de: 'Uhrzeit auswählen',
        it: 'Seleziona orario',
        en: 'Select time',
        fr: 'Selectionner l heure',
      );

  String _calendarGuideTitle(BuildContext context) => _copy(
        context: context,
        de: 'Wählen Sie einen verfügbaren Tag und eine Uhrzeit aus',
        it: 'Seleziona un giorno e un orario disponibili',
        en: 'Select an available day and time',
        fr: 'Sélectionnez un jour et une heure disponibles',
      );

  String _calendarGuideSubtitle(BuildContext context) => _copy(
        context: context,
        de: 'Hier sehen Sie alle verfügbaren Termine in Ihrer Nähe.',
        it: 'Qui puoi vedere tutti gli appuntamenti disponibili vicino a te.',
        en: 'Here you can see all available appointments near you.',
        fr: 'Vous pouvez voir ici tous les rendez-vous disponibles près de chez vous.',
      );

  String _validationSnackBarText(BuildContext context) => _copy(
        context: context,
        de: 'Bitte füllen Sie die markierten Pflichtfelder aus.',
        it: 'Compila i campi obbligatori evidenziati.',
        en: 'Please fill in the highlighted required fields.',
        fr: 'Veuillez remplir les champs obligatoires indiqués.',
      );

  String _requiredPhotoText(BuildContext context) => _copy(
        context: context,
        de: 'Foto erforderlich',
        it: 'Foto obbligatoria',
        en: 'Photo required',
        fr: 'Photo obligatoire',
      );

  String _calendarRequiredText(BuildContext context) => _copy(
        context: context,
        de: 'Wählen Sie Tag und Uhrzeit aus',
        it: 'Seleziona giorno e orario',
        en: 'Select day and time',
        fr: 'Sélectionnez le jour et l’heure',
      );

  String _requiredLicensePlateText(BuildContext context) => _copy(
        context: context,
        de: 'Kennzeichen erforderlich',
        it: 'Targa obbligatoria',
        en: 'License plate required',
        fr: 'Plaque obligatoire',
      );

  String _requiredNameText(BuildContext context) => _copy(
        context: context,
        de: 'Name und Nachname erforderlich',
        it: 'Nome e cognome obbligatori',
        en: 'Name and surname required',
        fr: 'Nom et prénom obligatoires',
      );

  String _requiredContactText(BuildContext context) => _copy(
        context: context,
        de: 'Telefon oder E-Mail erforderlich',
        it: 'Telefono o e-mail obbligatori',
        en: 'Phone or email required',
        fr: 'Téléphone ou e-mail obligatoires',
      );

  String _requiredTownText(BuildContext context) => _copy(
        context: context,
        de: 'Ortschaft erforderlich',
        it: 'Località obbligatoria',
        en: 'Town required',
        fr: 'Localité obligatoire',
      );

  String _requiredDamageDateText(BuildContext context) => _copy(
        context: context,
        de: 'Schadentag erforderlich',
        it: 'Data danno obbligatoria',
        en: 'Damage date required',
        fr: 'Date du dommage obligatoire',
      );

  String _requiredDamageTimeText(BuildContext context) => _copy(
        context: context,
        de: 'Schadenzeit erforderlich',
        it: 'Ora danno obbligatoria',
        en: 'Damage time required',
        fr: 'Heure du dommage obligatoire',
      );

  String _marderDrivableQuestion(BuildContext context) => _copy(
        context: context,
        de: 'Ist das Fahrzeug noch fahrbereit?',
        it: 'Il veicolo è ancora marciante?',
        en: 'Is the vehicle still drivable?',
        fr: 'Le véhicule peut-il encore rouler ?',
      );

  String _marderDrivableOptionLabel(BuildContext context, String value) {
    switch (value) {
      case _marderDrivableYes:
        return _copy(
          context: context,
          de: 'Ja',
          it: 'Sì',
          en: 'Yes',
          fr: 'Oui',
        );
      case _marderDrivableNo:
        return _copy(
          context: context,
          de: 'Nein',
          it: 'No',
          en: 'No',
          fr: 'Non',
        );
      case _marderDrivableNotSure:
      default:
        return _copy(
          context: context,
          de: 'Unsicher',
          it: 'Non sicuro',
          en: 'Not sure',
          fr: 'Pas sûr',
        );
    }
  }

  String _marderDescriptionLabel(BuildContext context) => _copy(
        context: context,
        de: 'Beschreiben Sie kurz das Problem',
        it: 'Descrivi brevemente il problema',
        en: 'Briefly describe the problem',
        fr: 'Décrivez brièvement le problème',
      );

  String _fullDescriptionLabel(BuildContext context) => _copy(
        context: context,
        de: 'Beschreiben Sie kurz den Unfall',
        it: 'Descrivi brevemente il danno',
        en: 'Briefly describe the accident',
        fr: 'Décrivez brièvement l’accident',
      );

  String _otherCategoryLabel(BuildContext context) => _copy(
        context: context,
        de: 'Was ist das Problem?',
        it: 'Qual è il problema?',
        en: 'What is the problem?',
        fr: 'Quel est le problème ?',
      );

  String _otherDescriptionLabel(BuildContext context) => _copy(
        context: context,
        de: 'Beschreiben Sie das Problem',
        it: 'Descrivi il problema',
        en: 'Describe the problem',
        fr: 'Décrivez le problème',
      );

  String _requiredMarderDrivableText(BuildContext context) => _copy(
        context: context,
        de: 'Bitte Fahrbereitschaft auswählen',
        it: 'Seleziona se il veicolo è marciante',
        en: 'Please select whether the vehicle is drivable',
        fr: 'Veuillez indiquer si le véhicule peut encore rouler',
      );

  String _requiredOtherCategoryText(BuildContext context) => _copy(
        context: context,
        de: 'Bitte Problemkategorie auswählen',
        it: 'Seleziona la categoria del problema',
        en: 'Please select the problem category',
        fr: 'Veuillez sélectionner la catégorie du problème',
      );

  String _requiredDescriptionText(BuildContext context) => _copy(
        context: context,
        de: 'Beschreibung erforderlich',
        it: 'Descrizione obbligatoria',
        en: 'Description required',
        fr: 'Description obligatoire',
      );

  String _summaryTitle(BuildContext context) => _copy(
        context: context,
        de: 'Ihre Anfrage im Ueberblick',
        it: 'Riepilogo della tua richiesta',
        en: 'Your request summary',
        fr: 'Resume de votre demande',
      );

  String _summarySubtitle(BuildContext context) => _copy(
        context: context,
        de: 'Bitte pruefen Sie alle Angaben vor der finalen Terminbuchung.',
        it: 'Controlla tutti i dati prima della conferma finale dell’appuntamento.',
        en: 'Please review all details before confirming the appointment.',
        fr: 'Veuillez verifier toutes les informations avant la confirmation finale.',
      );

  String _summaryVehicleSectionTitle(BuildContext context) => _copy(
        context: context,
        de: 'Fahrzeug',
        it: 'Veicolo',
        en: 'Vehicle',
        fr: 'Vehicule',
      );

  String _summaryDamageSectionTitle(BuildContext context) => _copy(
        context: context,
        de: 'Schaden',
        it: 'Danno',
        en: 'Damage',
        fr: 'Dommage',
      );

  String _summaryPhotosSectionTitle(BuildContext context) => _copy(
        context: context,
        de: 'Bilder',
        it: 'Immagini',
        en: 'Images',
        fr: 'Images',
      );

  String _summaryAppointmentSectionTitle(BuildContext context) => _copy(
        context: context,
        de: 'Termin',
        it: 'Appuntamento',
        en: 'Appointment',
        fr: 'Rendez-vous',
      );

  String _summaryTypeLabel(BuildContext context) => _copy(
        context: context,
        de: 'Schadenart',
        it: 'Tipo danno',
        en: 'Damage type',
        fr: 'Type de dommage',
      );

  String _summaryTownShortLabel(BuildContext context) => _copy(
        context: context,
        de: 'Ortschaft',
        it: 'Localita',
        en: 'Town',
        fr: 'Localite',
      );

  String _summaryDamageDateShortLabel(BuildContext context) => _copy(
        context: context,
        de: 'Schadentag',
        it: 'Data danno',
        en: 'Damage date',
        fr: 'Date du dommage',
      );

  String _summaryDamageTimeShortLabel(BuildContext context) => _copy(
        context: context,
        de: 'Schadenzeit',
        it: 'Ora danno',
        en: 'Damage time',
        fr: 'Heure du dommage',
      );

  String _summaryDayLabel(BuildContext context) => _copy(
        context: context,
        de: 'Tag',
        it: 'Giorno',
        en: 'Day',
        fr: 'Jour',
      );

  String _summaryTimeLabel(BuildContext context) => _copy(
        context: context,
        de: 'Uhrzeit',
        it: 'Orario',
        en: 'Time',
        fr: 'Heure',
      );

  String _summaryWorkshopLabel(BuildContext context) => _copy(
        context: context,
        de: 'Werkstatt',
        it: 'Officina',
        en: 'Workshop',
        fr: 'Atelier',
      );

  String _summaryCustomerLabel(BuildContext context) => _copy(
        context: context,
        de: 'Kunde',
        it: 'Cliente',
        en: 'Customer',
        fr: 'Client',
      );

  String _confirmationLabel(BuildContext context) => _copy(
        context: context,
        de: 'Ich bestaetige die Richtigkeit meiner Angaben',
        it: 'Confermo la correttezza dei miei dati',
        en: 'I confirm that my information is correct',
        fr: 'Je confirme l’exactitude de mes informations',
      );

  String _confirmationHint(BuildContext context) => _copy(
        context: context,
        de: 'Bitte bestaetigen Sie Ihre Angaben, um den Termin zu buchen.',
        it: 'Conferma i tuoi dati per poter prenotare l’appuntamento.',
        en: 'Please confirm your details to book the appointment.',
        fr: 'Veuillez confirmer vos informations pour reserver le rendez-vous.',
      );

  List<String> get _otherDamageCategories => const [
        _otherCategoryEngineWarning,
        _otherCategoryBattery,
        _otherCategoryAirConditioning,
        _otherCategoryElectronics,
        _otherCategoryNoiseVibration,
        _otherCategoryRecall,
        _otherCategoryOther,
      ];

  String _otherCategoryOptionLabel(BuildContext context, String value) {
    switch (value) {
      case _otherCategoryEngineWarning:
        return _copy(
          context: context,
          de: 'Motorwarnleuchte',
          it: 'Spia motore',
          en: 'Engine warning light',
          fr: 'Voyant moteur',
        );
      case _otherCategoryBattery:
        return _copy(
          context: context,
          de: 'Batterieproblem',
          it: 'Problema batteria',
          en: 'Battery problem',
          fr: 'Problème de batterie',
        );
      case _otherCategoryAirConditioning:
        return _copy(
          context: context,
          de: 'Klimaanlage',
          it: 'Aria condizionata',
          en: 'Air conditioning',
          fr: 'Climatisation',
        );
      case _otherCategoryElectronics:
        return _copy(
          context: context,
          de: 'Elektronikproblem',
          it: 'Problema elettronico',
          en: 'Electronic problem',
          fr: 'Problème électronique',
        );
      case _otherCategoryNoiseVibration:
        return _copy(
          context: context,
          de: 'Geräusch/Vibration',
          it: 'Rumore/Vibrazione',
          en: 'Noise/Vibration',
          fr: 'Bruit/Vibration',
        );
      case _otherCategoryRecall:
        return _copy(
          context: context,
          de: 'Rückrufaktion',
          it: 'Richiamo ufficiale',
          en: 'Official recall',
          fr: 'Rappel officiel',
        );
      case _otherCategoryOther:
      default:
        return _copy(
          context: context,
          de: 'Sonstiges',
          it: 'Altro',
          en: 'Other',
          fr: 'Autre',
        );
    }
  }

  String _calendarLocaleTag(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'it':
        return 'it_IT';
      case 'fr':
        return 'fr_FR';
      case 'en':
        return 'en_US';
      case 'de':
      default:
        return 'de_DE';
    }
  }

  String _calendarMonthLabel(BuildContext context, int month) {
    const it = <String>[
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];
    const de = <String>[
      'Januar',
      'Februar',
      'Maerz',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    const en = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const fr = <String>[
      'Janvier',
      'Fevrier',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Aout',
      'Septembre',
      'Octobre',
      'Novembre',
      'Decembre',
    ];

    final safeIndex = month < 1
        ? 0
        : month > 12
            ? 11
            : month - 1;
    switch (Localizations.localeOf(context).languageCode) {
      case 'it':
        return it[safeIndex];
      case 'fr':
        return fr[safeIndex];
      case 'en':
        return en[safeIndex];
      case 'de':
      default:
        return de[safeIndex];
    }
  }

  String _calendarWeekdayLabel(BuildContext context, int weekday) {
    const it = <String>['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    const de = <String>['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const en = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const fr = <String>['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    final safeIndex = weekday < 1
        ? 0
        : weekday > 7
            ? 6
            : weekday - 1;
    switch (Localizations.localeOf(context).languageCode) {
      case 'it':
        return it[safeIndex];
      case 'fr':
        return fr[safeIndex];
      case 'en':
        return en[safeIndex];
      case 'de':
      default:
        return de[safeIndex];
    }
  }

  Map<CalendarFormat, String> _calendarFormatLabels(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'it':
        return const {
          CalendarFormat.month: 'Mese',
          CalendarFormat.twoWeeks: '2 settimane',
          CalendarFormat.week: 'Settimana',
        };
      case 'fr':
        return const {
          CalendarFormat.month: 'Mois',
          CalendarFormat.twoWeeks: '2 semaines',
          CalendarFormat.week: 'Semaine',
        };
      case 'en':
        return const {
          CalendarFormat.month: 'Month',
          CalendarFormat.twoWeeks: '2 weeks',
          CalendarFormat.week: 'Week',
        };
      case 'de':
      default:
        return const {
          CalendarFormat.month: 'Monat',
          CalendarFormat.twoWeeks: '2 Wochen',
          CalendarFormat.week: 'Woche',
        };
    }
  }

  Widget _licensePlateCard(BuildContext context) {
    final theme = Theme.of(context);
    final showError = _showValidationErrors &&
        _usesDamageDetailsForm &&
        _isLicensePlateMissing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showError
              ? theme.colorScheme.error
              : theme.dividerColor.withOpacity(0.35),
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
              color: (showError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary)
                  .withOpacity(0.12),
            ),
            child: Icon(Icons.confirmation_number_outlined,
                color: showError
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.license_plate_label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: showError
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withOpacity(0.70),
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
                if (showError) ...[
                  const SizedBox(height: 6),
                  Text(
                    _requiredLicensePlateText(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _premiumFieldDec(
    BuildContext context,
    String hint, {
    bool isError = false,
    String? errorText,
  }) {
    final theme = Theme.of(context);
    final borderColor = isError
        ? theme.colorScheme.error
        : theme.dividerColor.withOpacity(0.35);
    final focusColor = isError
        ? theme.colorScheme.error
        : theme.colorScheme.primary.withOpacity(0.6);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surface.withOpacity(0.22),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      errorText: errorText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: focusColor, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1.2),
      ),
    );
  }

  void _onValidationFieldChanged() {
    if (!mounted || !_showValidationErrors) return;
    setState(() {});
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    _nameCtrl.removeListener(_onValidationFieldChanged);
    _phoneCtrl.removeListener(_onValidationFieldChanged);
    _emailCtrl.removeListener(_onValidationFieldChanged);
    _plateCtrl.removeListener(_onValidationFieldChanged);
    _glassTownCtrl.removeListener(_onValidationFieldChanged);
    _marderDescriptionCtrl.removeListener(_onValidationFieldChanged);
    _fullDamageDescriptionCtrl.removeListener(_onValidationFieldChanged);
    _otherDamageDescriptionCtrl.removeListener(_onValidationFieldChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _plateCtrl.dispose();
    _glassTownCtrl.dispose();
    _marderDescriptionCtrl.dispose();
    _fullDamageDescriptionCtrl.dispose();
    _otherDamageDescriptionCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _skeletonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..repeat(reverse: true);
    _summaryFormListenable = Listenable.merge([
      _nameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _plateCtrl,
      _glassTownCtrl,
      _marderDescriptionCtrl,
      _fullDamageDescriptionCtrl,
      _otherDamageDescriptionCtrl,
    ]);
    _nameCtrl.addListener(_onValidationFieldChanged);
    _phoneCtrl.addListener(_onValidationFieldChanged);
    _emailCtrl.addListener(_onValidationFieldChanged);
    _plateCtrl.addListener(_onValidationFieldChanged);
    _glassTownCtrl.addListener(_onValidationFieldChanged);
    _marderDescriptionCtrl.addListener(_onValidationFieldChanged);
    _fullDamageDescriptionCtrl.addListener(_onValidationFieldChanged);
    _otherDamageDescriptionCtrl.addListener(_onValidationFieldChanged);
    _loadAvailableSlots(_selectedDay);
    unawaited(AppointmentRequestsSyncManager.trigger());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _summaryCardVisible = true;
      });
    });
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
      case AppointmentRequestImageCategory.glassCurrentKm:
        return _glassCurrentKmImages;
      case AppointmentRequestImageCategory.hailVehicleDocument:
        return _hailVehicleDocumentImages;
      case AppointmentRequestImageCategory.hailDamage:
        return _hailDamageImages;
      case AppointmentRequestImageCategory.hailOverview:
        return _hailOverviewImages;
      case AppointmentRequestImageCategory.hailCurrentKm:
        return _hailCurrentKmImages;
      case AppointmentRequestImageCategory.hailExtra1:
        return _hailExtraImage1;
      case AppointmentRequestImageCategory.hailExtra2:
        return _hailExtraImage2;
      case AppointmentRequestImageCategory.marderVehicleDocument:
        return _marderVehicleDocumentImages;
      case AppointmentRequestImageCategory.marderEngineBay:
        return _marderEngineBayImages;
      case AppointmentRequestImageCategory.marderCable:
        return _marderCableImages;
      case AppointmentRequestImageCategory.marderCurrentKm:
        return _marderCurrentKmImages;
      case AppointmentRequestImageCategory.marderExtra:
        return _marderExtraImages;
      case AppointmentRequestImageCategory.fullVehicleDocument:
        return _fullVehicleDocumentImages;
      case AppointmentRequestImageCategory.fullClose:
        return _fullCloseImages;
      case AppointmentRequestImageCategory.fullOverview:
        return _fullOverviewImages;
      case AppointmentRequestImageCategory.fullCurrentKm:
        return _fullCurrentKmImages;
      case AppointmentRequestImageCategory.fullExtra:
        return _fullExtraImages;
      case AppointmentRequestImageCategory.otherVehicleDocument:
        return _otherVehicleDocumentImages;
      case AppointmentRequestImageCategory.otherProblem:
        return _otherProblemImages;
      case AppointmentRequestImageCategory.otherCurrentKm:
        return _otherCurrentKmImages;
      case AppointmentRequestImageCategory.otherExtra:
        return _otherExtraImages;
      case AppointmentRequestImageCategory.parkingVehicleDocument:
        return _parkingVehicleDocumentImages;
      case AppointmentRequestImageCategory.parkingDamage:
        return _parkingDamageImages;
      case AppointmentRequestImageCategory.parkingOverview:
        return _parkingOverviewImages;
      case AppointmentRequestImageCategory.parkingCurrentKm:
        return _parkingCurrentKmImages;
      case AppointmentRequestImageCategory.parkingExtra:
        return _parkingExtraImages;
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
      case AppointmentRequestImageCategory.glassCurrentKm:
      case AppointmentRequestImageCategory.hailCurrentKm:
      case AppointmentRequestImageCategory.parkingCurrentKm:
        return Icons.speed_outlined;
      case AppointmentRequestImageCategory.hailVehicleDocument:
        return Icons.description_outlined;
      case AppointmentRequestImageCategory.hailDamage:
        return Icons.broken_image_outlined;
      case AppointmentRequestImageCategory.hailOverview:
        return Icons.directions_car_filled_outlined;
      case AppointmentRequestImageCategory.hailExtra1:
      case AppointmentRequestImageCategory.hailExtra2:
        return Icons.add_a_photo_outlined;
      case AppointmentRequestImageCategory.marderVehicleDocument:
        return Icons.description_outlined;
      case AppointmentRequestImageCategory.marderEngineBay:
        return Icons.car_repair_outlined;
      case AppointmentRequestImageCategory.marderCable:
        return Icons.electrical_services_outlined;
      case AppointmentRequestImageCategory.marderCurrentKm:
        return Icons.speed_outlined;
      case AppointmentRequestImageCategory.marderExtra:
        return Icons.add_a_photo_outlined;
      case AppointmentRequestImageCategory.fullVehicleDocument:
        return Icons.description_outlined;
      case AppointmentRequestImageCategory.fullClose:
        return Icons.broken_image_outlined;
      case AppointmentRequestImageCategory.fullOverview:
        return Icons.directions_car_filled_outlined;
      case AppointmentRequestImageCategory.fullCurrentKm:
        return Icons.speed_outlined;
      case AppointmentRequestImageCategory.fullExtra:
        return Icons.add_a_photo_outlined;
      case AppointmentRequestImageCategory.otherVehicleDocument:
        return Icons.description_outlined;
      case AppointmentRequestImageCategory.otherProblem:
        return Icons.warning_amber_rounded;
      case AppointmentRequestImageCategory.otherCurrentKm:
        return Icons.speed_outlined;
      case AppointmentRequestImageCategory.otherExtra:
        return Icons.add_a_photo_outlined;
      case AppointmentRequestImageCategory.parkingVehicleDocument:
        return Icons.description_outlined;
      case AppointmentRequestImageCategory.parkingDamage:
        return Icons.car_crash_outlined;
      case AppointmentRequestImageCategory.parkingOverview:
        return Icons.directions_car_filled_outlined;
      case AppointmentRequestImageCategory.parkingExtra:
        return Icons.add_a_photo_outlined;
      case AppointmentRequestImageCategory.closeGlass:
      default:
        return Icons.broken_image_outlined;
    }
  }

  _GlassDamageImageDraft? _primaryImageForCategory(String category) {
    final items = _imagesForCategory(category);
    if (items.isEmpty) return null;
    return items.last;
  }

  bool get _isLicensePlateMissing => _plateCtrl.text.trim().isEmpty;

  bool get _isNameMissing => _nameCtrl.text.trim().isEmpty;

  bool get _isContactMissing =>
      _phoneCtrl.text.trim().isEmpty && _emailCtrl.text.trim().isEmpty;

  bool get _isVehicleDocumentPhotoMissing =>
      _glassVehicleDocumentImages.isEmpty;

  bool get _isCloseGlassPhotoMissing => _glassCloseGlassImages.isEmpty;

  bool get _isFrontVehiclePhotoMissing => _glassFrontVehicleImages.isEmpty;

  bool get _isGlassCurrentKmPhotoMissing => _glassCurrentKmImages.isEmpty;

  bool get _isHailVehicleDocumentPhotoMissing =>
      _hailVehicleDocumentImages.isEmpty;

  bool get _isHailDamagePhotoMissing => _hailDamageImages.isEmpty;

  bool get _isHailOverviewPhotoMissing => _hailOverviewImages.isEmpty;

  bool get _isHailCurrentKmPhotoMissing => _hailCurrentKmImages.isEmpty;

  bool get _isMarderVehicleDocumentPhotoMissing =>
      _marderVehicleDocumentImages.isEmpty;

  bool get _isMarderEngineBayPhotoMissing => _marderEngineBayImages.isEmpty;

  bool get _isMarderCablePhotoMissing => _marderCableImages.isEmpty;

  bool get _isMarderCurrentKmPhotoMissing => _marderCurrentKmImages.isEmpty;

  bool get _isFullVehicleDocumentPhotoMissing =>
      _fullVehicleDocumentImages.isEmpty;

  bool get _isFullClosePhotoMissing => _fullCloseImages.isEmpty;

  bool get _isFullOverviewPhotoMissing => _fullOverviewImages.isEmpty;

  bool get _isFullCurrentKmPhotoMissing => _fullCurrentKmImages.isEmpty;

  bool get _isOtherVehicleDocumentPhotoMissing =>
      _otherVehicleDocumentImages.isEmpty;

  bool get _isOtherProblemPhotoMissing => _otherProblemImages.isEmpty;

  bool get _isOtherCurrentKmPhotoMissing => _otherCurrentKmImages.isEmpty;

  bool get _isParkingVehicleDocumentPhotoMissing =>
      _parkingVehicleDocumentImages.isEmpty;

  bool get _isParkingDamagePhotoMissing => _parkingDamageImages.isEmpty;

  bool get _isParkingOverviewPhotoMissing => _parkingOverviewImages.isEmpty;

  bool get _isParkingCurrentKmPhotoMissing => _parkingCurrentKmImages.isEmpty;

  bool get _isTownMissing => _glassTownCtrl.text.trim().isEmpty;

  bool get _isDamageDateMissing => _glassDamageDate == null;

  bool get _isDamageTimeMissing =>
      _usesDamageTimeField && _hailDamageTime == null;

  bool get _isMarderDrivableMissing =>
      (_marderDamageDrivable?.trim().isEmpty ?? true);

  bool get _isFullDrivableMissing =>
      (_fullDamageDrivable?.trim().isEmpty ?? true);

  bool get _isFullDescriptionMissing =>
      _fullDamageDescriptionCtrl.text.trim().isEmpty;

  bool get _isOtherCategoryMissing =>
      (_otherDamageCategory?.trim().isEmpty ?? true);

  bool get _isOtherDescriptionMissing =>
      _otherDamageDescriptionCtrl.text.trim().isEmpty;

  bool get _isAppointmentSelectionMissing => _selectedSlot == null;

  bool get _hasGlassValidationErrors =>
      _isLicensePlateMissing ||
      _isNameMissing ||
      _isContactMissing ||
      _isVehicleDocumentPhotoMissing ||
      _isCloseGlassPhotoMissing ||
      _isFrontVehiclePhotoMissing ||
      _isGlassCurrentKmPhotoMissing ||
      _isTownMissing ||
      _isDamageDateMissing ||
      _isAppointmentSelectionMissing;

  bool get _hasHailValidationErrors =>
      _isLicensePlateMissing ||
      _isNameMissing ||
      _isContactMissing ||
      _isHailVehicleDocumentPhotoMissing ||
      _isHailDamagePhotoMissing ||
      _isHailOverviewPhotoMissing ||
      _isHailCurrentKmPhotoMissing ||
      _isTownMissing ||
      _isDamageDateMissing ||
      _isDamageTimeMissing ||
      _isAppointmentSelectionMissing;

  bool get _hasMartenValidationErrors =>
      _isLicensePlateMissing ||
      _isNameMissing ||
      _isContactMissing ||
      _isMarderVehicleDocumentPhotoMissing ||
      _isMarderEngineBayPhotoMissing ||
      _isMarderCablePhotoMissing ||
      _isMarderCurrentKmPhotoMissing ||
      _isTownMissing ||
      _isDamageDateMissing ||
      _isDamageTimeMissing ||
      _isMarderDrivableMissing ||
      _isAppointmentSelectionMissing;

  bool get _hasComprehensiveValidationErrors =>
      _isLicensePlateMissing ||
      _isNameMissing ||
      _isContactMissing ||
      _isFullVehicleDocumentPhotoMissing ||
      _isFullClosePhotoMissing ||
      _isFullOverviewPhotoMissing ||
      _isFullCurrentKmPhotoMissing ||
      _isTownMissing ||
      _isDamageDateMissing ||
      _isDamageTimeMissing ||
      _isFullDrivableMissing ||
      _isFullDescriptionMissing ||
      _isAppointmentSelectionMissing;

  bool get _hasOtherValidationErrors =>
      _isLicensePlateMissing ||
      _isNameMissing ||
      _isContactMissing ||
      _isOtherVehicleDocumentPhotoMissing ||
      _isOtherProblemPhotoMissing ||
      _isOtherCurrentKmPhotoMissing ||
      _isTownMissing ||
      _isDamageDateMissing ||
      _isDamageTimeMissing ||
      _isOtherCategoryMissing ||
      _isOtherDescriptionMissing ||
      _isAppointmentSelectionMissing;

  bool get _hasParkingValidationErrors =>
      _isLicensePlateMissing ||
      _isNameMissing ||
      _isContactMissing ||
      _isParkingVehicleDocumentPhotoMissing ||
      _isParkingDamagePhotoMissing ||
      _isParkingOverviewPhotoMissing ||
      _isParkingCurrentKmPhotoMissing ||
      _isTownMissing ||
      _isDamageDateMissing ||
      _isDamageTimeMissing ||
      _isAppointmentSelectionMissing;

  bool get _canSubmitRequest {
    if (_selectedSlot == null) return false;
    if (_isGlassDamage) return !_hasGlassValidationErrors;
    if (_isHailDamage) return !_hasHailValidationErrors;
    if (_isMartenDamage) return !_hasMartenValidationErrors;
    if (_isComprehensiveDamage) return !_hasComprehensiveValidationErrors;
    if (_isOtherDamage) return !_hasOtherValidationErrors;
    if (_isParkingDamage) return !_hasParkingValidationErrors;
    return _nameCtrl.text.trim().isNotEmpty;
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
    final folderName = _isHailDamage
        ? 'hail_damage_uploads'
        : _isMartenDamage
            ? 'marder_damage_uploads'
            : _isComprehensiveDamage
                ? 'full_damage_uploads'
                : _isOtherDamage
                    ? 'other_damage_uploads'
                    : _isParkingDamage
                        ? 'parking_damage_uploads'
                        : 'glass_damage_uploads';
    final targetDir = Directory('${dir.path}/$folderName');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final originalName =
        file.name.isNotEmpty ? file.name : _fileNameFromPath(file.path);
    final safeName =
        '${DateTime.now().millisecondsSinceEpoch}_${_sanitizeFileName(originalName)}';
    final targetPath = '${targetDir.path}/$safeName';
    final bytes = await file.readAsBytes();
    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  Future<void> _deleteGlassImageDraft(_GlassDamageImageDraft item) async {
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
  }

  Future<void> _handlePickedFile(
    XFile? file,
    String category,
  ) async {
    if (file == null) return;

    final originalName =
        file.name.isNotEmpty ? file.name : _fileNameFromPath(file.path);
    if (!_isSupportedImageName(originalName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_snackUnsupportedImage(context))),
        );
      }
      return;
    }

    final mimeType = _mimeTypeForName(originalName);
    late final _GlassDamageImageDraft newItem;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      final prefix = _isHailDamage
          ? 'hail'
          : _isMartenDamage
              ? 'marder'
              : _isComprehensiveDamage
                  ? 'full'
                  : _isOtherDamage
                      ? 'other'
                      : _isParkingDamage
                          ? 'parking'
                          : 'glass';
      final cacheKey =
          '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$category';
      await LocalImageCache.saveImageLocally(cacheKey, bytes);
      newItem = _GlassDamageImageDraft(
        category: category,
        fileName: originalName,
        mimeType: mimeType,
        previewReference: 'cache:$cacheKey',
        cacheKey: cacheKey,
        bytes: bytes,
      );
    } else {
      final persistedPath = await _persistPickedFile(file);
      newItem = _GlassDamageImageDraft(
        category: category,
        fileName: originalName,
        mimeType: mimeType,
        previewReference: persistedPath,
        localPath: persistedPath,
      );
    }

    final target = _imagesForCategory(category);
    final previousItems = List<_GlassDamageImageDraft>.from(target);
    for (final item in previousItems) {
      await _deleteGlassImageDraft(item);
    }
    if (!mounted) return;
    setState(() {
      target
        ..clear()
        ..add(newItem);
    });
  }

  Future<void> _pickGlassDamageCamera(String category) async {
    setState(() => _photoLoadingCategories.add(category));
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      await _handlePickedFile(file, category);
    } finally {
      if (!mounted) return;
      setState(() => _photoLoadingCategories.remove(category));
    }
  }

  Future<void> _pickGlassDamageGallery(String category) async {
    setState(() => _photoLoadingCategories.add(category));
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      await _handlePickedFile(file, category);
    } finally {
      if (!mounted) return;
      setState(() => _photoLoadingCategories.remove(category));
    }
  }

  Future<void> _removeGlassImage(String category, int index) async {
    setState(() => _photoLoadingCategories.add(category));
    final items = _imagesForCategory(category);
    final item = items[index];
    try {
      await _deleteGlassImageDraft(item);
      if (!mounted) return;
      setState(() {
        items.removeAt(index);
      });
    } finally {
      if (!mounted) return;
      setState(() => _photoLoadingCategories.remove(category));
    }
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

  Future<void> _pickHailDamageTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hailDamageTime ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      _hailDamageTime = picked;
    });
  }

  Future<void> _showGlassImageActionSheet(String category) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(_takePhotoLabel(context)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickGlassDamageCamera(category);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(_selectPhotosLabel(context)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickGlassDamageGallery(category);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openGlassImagePreview(_GlassDamageImageDraft image) async {
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
                        child: image.bytes != null
                            ? Image.memory(image.bytes!, fit: BoxFit.contain)
                            : (!kIsWeb && image.localPath != null)
                                ? Image.file(
                                    File(image.localPath!),
                                    fit: BoxFit.contain,
                                  )
                                : const Icon(
                                    Icons.broken_image_outlined,
                                    size: 72,
                                    color: Colors.white70,
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
                    tooltip: _previewPhotoTooltip(context),
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

  List<String> _activePhotoCategories() {
    if (_isGlassDamage) {
      return const [
        AppointmentRequestImageCategory.vehicleDocument,
        AppointmentRequestImageCategory.closeGlass,
        AppointmentRequestImageCategory.frontVehicle,
        AppointmentRequestImageCategory.glassCurrentKm,
      ];
    }
    if (_isHailDamage) {
      return const [
        AppointmentRequestImageCategory.hailVehicleDocument,
        AppointmentRequestImageCategory.hailDamage,
        AppointmentRequestImageCategory.hailOverview,
        AppointmentRequestImageCategory.hailCurrentKm,
        AppointmentRequestImageCategory.hailExtra1,
        AppointmentRequestImageCategory.hailExtra2,
      ];
    }
    if (_isMartenDamage) {
      return const [
        AppointmentRequestImageCategory.marderVehicleDocument,
        AppointmentRequestImageCategory.marderEngineBay,
        AppointmentRequestImageCategory.marderCable,
        AppointmentRequestImageCategory.marderCurrentKm,
        AppointmentRequestImageCategory.marderExtra,
      ];
    }
    if (_isComprehensiveDamage) {
      return const [
        AppointmentRequestImageCategory.fullVehicleDocument,
        AppointmentRequestImageCategory.fullClose,
        AppointmentRequestImageCategory.fullOverview,
        AppointmentRequestImageCategory.fullCurrentKm,
        AppointmentRequestImageCategory.fullExtra,
      ];
    }
    if (_isOtherDamage) {
      return const [
        AppointmentRequestImageCategory.otherVehicleDocument,
        AppointmentRequestImageCategory.otherProblem,
        AppointmentRequestImageCategory.otherCurrentKm,
        AppointmentRequestImageCategory.otherExtra,
      ];
    }
    if (_isParkingDamage) {
      return const [
        AppointmentRequestImageCategory.parkingVehicleDocument,
        AppointmentRequestImageCategory.parkingDamage,
        AppointmentRequestImageCategory.parkingOverview,
        AppointmentRequestImageCategory.parkingCurrentKm,
        AppointmentRequestImageCategory.parkingExtra,
      ];
    }
    return const [];
  }

  bool _isOptionalPhotoCategory(String category) {
    switch (category) {
      case AppointmentRequestImageCategory.hailExtra1:
      case AppointmentRequestImageCategory.hailExtra2:
      case AppointmentRequestImageCategory.marderExtra:
      case AppointmentRequestImageCategory.fullExtra:
      case AppointmentRequestImageCategory.otherExtra:
      case AppointmentRequestImageCategory.parkingExtra:
        return true;
      default:
        return false;
    }
  }

  String _summaryPhotoTitle(BuildContext context, String category) {
    switch (category) {
      case AppointmentRequestImageCategory.vehicleDocument:
      case AppointmentRequestImageCategory.hailVehicleDocument:
      case AppointmentRequestImageCategory.marderVehicleDocument:
      case AppointmentRequestImageCategory.fullVehicleDocument:
      case AppointmentRequestImageCategory.otherVehicleDocument:
      case AppointmentRequestImageCategory.parkingVehicleDocument:
        return _copy(
          context: context,
          de: 'Foto Fahrzeugausweis',
          it: 'Foto libretto',
          en: 'Vehicle document photo',
          fr: 'Photo carte grise',
        );
      case AppointmentRequestImageCategory.closeGlass:
      case AppointmentRequestImageCategory.hailDamage:
      case AppointmentRequestImageCategory.fullClose:
      case AppointmentRequestImageCategory.otherProblem:
      case AppointmentRequestImageCategory.parkingDamage:
        return _copy(
          context: context,
          de: 'Schadenfoto',
          it: 'Foto danno',
          en: 'Damage photo',
          fr: 'Photo du dommage',
        );
      case AppointmentRequestImageCategory.frontVehicle:
      case AppointmentRequestImageCategory.hailOverview:
      case AppointmentRequestImageCategory.fullOverview:
      case AppointmentRequestImageCategory.parkingOverview:
        return _copy(
          context: context,
          de: 'Uebersicht Fahrzeug',
          it: 'Panoramica veicolo',
          en: 'Vehicle overview',
          fr: 'Vue d’ensemble du vehicule',
        );
      case AppointmentRequestImageCategory.glassCurrentKm:
      case AppointmentRequestImageCategory.hailCurrentKm:
      case AppointmentRequestImageCategory.marderCurrentKm:
      case AppointmentRequestImageCategory.fullCurrentKm:
      case AppointmentRequestImageCategory.otherCurrentKm:
      case AppointmentRequestImageCategory.parkingCurrentKm:
        return _copy(
          context: context,
          de: 'KM Foto',
          it: 'Foto KM',
          en: 'Mileage photo',
          fr: 'Photo kilometrage',
        );
      case AppointmentRequestImageCategory.marderEngineBay:
        return _copy(
          context: context,
          de: 'Foto Motorraum',
          it: 'Foto vano motore',
          en: 'Engine bay photo',
          fr: 'Photo compartiment moteur',
        );
      case AppointmentRequestImageCategory.marderCable:
        return _copy(
          context: context,
          de: 'Foto Kabel',
          it: 'Foto cavi',
          en: 'Cable photo',
          fr: 'Photo cables',
        );
      case AppointmentRequestImageCategory.hailExtra1:
      case AppointmentRequestImageCategory.hailExtra2:
      case AppointmentRequestImageCategory.marderExtra:
      case AppointmentRequestImageCategory.fullExtra:
      case AppointmentRequestImageCategory.otherExtra:
      case AppointmentRequestImageCategory.parkingExtra:
        return _copy(
          context: context,
          de: 'Extra',
          it: 'Extra',
          en: 'Extra',
          fr: 'Extra',
        );
      default:
        return _glassSectionTitle(context, category);
    }
  }

  List<_SummaryPhotoCountData> _summaryPhotoCounts(BuildContext context) {
    final titlesInOrder = <String>[];
    final counts = <String, int>{};
    final optionalMap = <String, bool>{};

    for (final category in _activePhotoCategories()) {
      final title = _summaryPhotoTitle(context, category);
      if (title.trim().isEmpty) continue;
      if (!counts.containsKey(title)) {
        titlesInOrder.add(title);
        counts[title] = 0;
        optionalMap[title] = _isOptionalPhotoCategory(category);
      }
      counts[title] =
          (counts[title] ?? 0) + _imagesForCategory(category).length;
      optionalMap[title] =
          (optionalMap[title] ?? true) && _isOptionalPhotoCategory(category);
    }

    return [
      for (final title in titlesInOrder)
        _SummaryPhotoCountData(
          title: title,
          count: counts[title] ?? 0,
          optional: optionalMap[title] ?? false,
        ),
    ];
  }

  Widget _buildGlassImageThumbnail(
    BuildContext context, {
    required _GlassDamageImageDraft image,
  }) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        color: theme.colorScheme.surface.withOpacity(0.24),
        child: image.bytes != null
            ? Image.memory(image.bytes!, fit: BoxFit.cover)
            : Image.file(
                File(image.localPath!),
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildGlassPhotoRow(
    BuildContext context, {
    required String category,
    required bool showDivider,
  }) {
    final theme = Theme.of(context);
    final image = _primaryImageForCategory(category);
    final hasImage = image != null;
    final isBusy = _photoLoadingCategories.contains(category);
    final subtitle = _glassSectionSubtitle(context, category);
    final hasError = _showValidationErrors &&
        _usesDamageDetailsForm &&
        ((category == AppointmentRequestImageCategory.vehicleDocument &&
                _isVehicleDocumentPhotoMissing) ||
            (category == AppointmentRequestImageCategory.hailVehicleDocument &&
                _isHailVehicleDocumentPhotoMissing) ||
            (category ==
                    AppointmentRequestImageCategory.parkingVehicleDocument &&
                _isParkingVehicleDocumentPhotoMissing) ||
            (category == AppointmentRequestImageCategory.closeGlass &&
                _isCloseGlassPhotoMissing) ||
            (category == AppointmentRequestImageCategory.frontVehicle &&
                _isFrontVehiclePhotoMissing) ||
            (category == AppointmentRequestImageCategory.glassCurrentKm &&
                _isGlassCurrentKmPhotoMissing) ||
            (category == AppointmentRequestImageCategory.hailDamage &&
                _isHailDamagePhotoMissing) ||
            (category == AppointmentRequestImageCategory.parkingDamage &&
                _isParkingDamagePhotoMissing) ||
            (category == AppointmentRequestImageCategory.hailOverview &&
                _isHailOverviewPhotoMissing) ||
            (category == AppointmentRequestImageCategory.hailCurrentKm &&
                _isHailCurrentKmPhotoMissing) ||
            (category == AppointmentRequestImageCategory.marderVehicleDocument &&
                _isMarderVehicleDocumentPhotoMissing) ||
            (category == AppointmentRequestImageCategory.marderEngineBay &&
                _isMarderEngineBayPhotoMissing) ||
            (category == AppointmentRequestImageCategory.marderCable &&
                _isMarderCablePhotoMissing) ||
            (category == AppointmentRequestImageCategory.marderCurrentKm &&
                _isMarderCurrentKmPhotoMissing) ||
            (category == AppointmentRequestImageCategory.fullVehicleDocument &&
                _isFullVehicleDocumentPhotoMissing) ||
            (category == AppointmentRequestImageCategory.fullClose &&
                _isFullClosePhotoMissing) ||
            (category == AppointmentRequestImageCategory.fullOverview &&
                _isFullOverviewPhotoMissing) ||
            (category == AppointmentRequestImageCategory.fullCurrentKm &&
                _isFullCurrentKmPhotoMissing) ||
            (category == AppointmentRequestImageCategory.otherVehicleDocument &&
                _isOtherVehicleDocumentPhotoMissing) ||
            (category ==
                    AppointmentRequestImageCategory.otherProblem &&
                _isOtherProblemPhotoMissing) ||
            (category == AppointmentRequestImageCategory.otherCurrentKm &&
                _isOtherCurrentKmPhotoMissing) ||
            (category == AppointmentRequestImageCategory.parkingOverview &&
                _isParkingOverviewPhotoMissing) ||
            (category == AppointmentRequestImageCategory.parkingCurrentKm &&
                _isParkingCurrentKmPhotoMissing));
    final borderColor = hasError
        ? Colors.red.withOpacity(0.25)
        : hasImage
            ? const Color(0xFF4CAF50).withOpacity(0.25)
            : theme.dividerColor.withOpacity(0.18);
    final showUploadProgress = isBusy || (_submitting && hasImage);
    final statusText = isBusy
        ? _photoLoadingLabel(context)
        : hasImage
            ? _photoAddedLabel(context)
            : subtitle;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: hasImage || hasError ? 1.2 : 1,
            ),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isBusy ? null : () => _showGlassImageActionSheet(category),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (hasError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForCategory(category),
                      color: hasError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _glassSectionTitle(context, category),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty ||
                            hasImage ||
                            hasError ||
                            isBusy) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isBusy) ...[
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ] else if (hasImage) ...[
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Color(0xFF4CAF50),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  statusText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: hasError
                                        ? Colors.red.withOpacity(0.75)
                                        : hasImage
                                            ? const Color(0xFF2E7D32)
                                            : theme.colorScheme.onSurface
                                                .withOpacity(0.68),
                                    fontWeight: hasImage || hasError || isBusy
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasError) ...[
                          const SizedBox(height: 4),
                          Text(
                            _requiredPhotoText(context),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: isBusy
                              ? null
                              : () => _openGlassImagePreview(image),
                          child: Tooltip(
                            message: _previewPhotoTooltip(context),
                            child: _buildGlassImageThumbnail(context,
                                image: image),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          child: showUploadProgress
                              ? Padding(
                                  key: ValueKey('${category}_progress'),
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _buildPhotoUploadProgress(context),
                                )
                              : const SizedBox(
                                  key: ValueKey('no_progress'),
                                  height: 0,
                                ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child: Container(
                      key: ValueKey('${category}_action_$isBusy$hasImage'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: hasImage
                              ? const Color(0xFF4CAF50).withOpacity(0.22)
                              : theme.dividerColor.withOpacity(0.20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBusy) ...[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            isBusy
                                ? _photoLoadingLabel(context)
                                : hasImage
                                    ? _statusChangeLabel(context)
                                    : _statusAddLabel(context),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isBusy
                                  ? theme.colorScheme.onSurface.withOpacity(0.7)
                                  : hasImage
                                      ? const Color(0xFF2E7D32)
                                      : theme.colorScheme.onSurface
                                          .withOpacity(0.75),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed:
                          isBusy ? null : () => _removeGlassImage(category, 0),
                      tooltip: _removePhotoTooltip(context),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ] else ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: theme.dividerColor.withOpacity(0.22),
          ),
      ],
    );
  }

  Widget _buildPhotoUploadProgress(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _photoUploadingLabel(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox(
              height: 5,
              child: LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: Color(0xFFE7EEF9),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3D82F6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonBlock({
    required double height,
    double? width,
    double radius = 16,
  }) {
    return AnimatedBuilder(
      animation: _skeletonController,
      builder: (context, child) {
        final color = Color.lerp(
          const Color(0xFFF2F4F7),
          const Color(0xFFE7ECF3),
          _skeletonController.value,
        )!;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }

  Widget _buildInitialLoadingSkeleton(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildSkeletonBlock(height: 22, width: 220, radius: 12),
        const SizedBox(height: 10),
        _buildSkeletonBlock(height: 16, width: 260, radius: 10),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSkeletonBlock(height: 18, width: 160),
              const SizedBox(height: 12),
              _buildSkeletonBlock(height: 52, radius: 18),
              const SizedBox(height: 10),
              _buildSkeletonBlock(height: 52, radius: 18),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: List.generate(
              4,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
                child: Row(
                  children: [
                    _buildSkeletonBlock(height: 42, width: 42, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildSkeletonBlock(height: 44, radius: 14)),
                    const SizedBox(width: 12),
                    _buildSkeletonBlock(height: 56, width: 56, radius: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkeletonBlock(height: 18, width: 170),
              const SizedBox(height: 14),
              _buildSkeletonBlock(height: 270, radius: 20),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(
                  6,
                  (_) => _buildSkeletonBlock(
                    height: 38,
                    width: (MediaQuery.of(context).size.width - 92) / 3,
                    radius: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSkeletonBlock(height: 18, width: 180),
              const SizedBox(height: 12),
              _buildSkeletonBlock(height: 140, radius: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitLoadingOverlay(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      ignoring: !_submitting,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        opacity: _submitting ? 1 : 0,
        child: Container(
          color: const Color(0x47000000),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF3D82F6)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _submitOverlayTitle(context),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _submitOverlaySubtitle(context),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrivableSection(
    BuildContext context, {
    required String? selectedValue,
    required bool showError,
    required ValueChanged<String> onChanged,
  }) {
    final theme = Theme.of(context);
    const options = [
      _marderDrivableYes,
      _marderDrivableNo,
      _marderDrivableNotSure,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showError
              ? theme.colorScheme.error
              : theme.dividerColor.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: (showError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary)
                      .withOpacity(0.12),
                ),
                child: Icon(
                  Icons.directions_car_outlined,
                  color: showError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _marderDrivableQuestion(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: showError ? theme.colorScheme.error : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((value) {
              final selected = selectedValue == value;
              return ChoiceChip(
                label: Text(_marderDrivableOptionLabel(context, value)),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    onChanged(value);
                  });
                },
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.onSurface.withOpacity(0.78),
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: theme.colorScheme.surface.withOpacity(0.26),
                selectedColor: theme.colorScheme.primary,
                side: BorderSide(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.dividerColor.withOpacity(0.30),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              );
            }).toList(),
          ),
          if (showError) ...[
            const SizedBox(height: 8),
            Text(
              _requiredMarderDrivableText(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarderDrivableSection(BuildContext context) {
    return _buildDrivableSection(
      context,
      selectedValue: _marderDamageDrivable,
      showError: _showValidationErrors && _isMarderDrivableMissing,
      onChanged: (value) => _marderDamageDrivable = value,
    );
  }

  Widget _buildFullDamageDrivableSection(BuildContext context) {
    return _buildDrivableSection(
      context,
      selectedValue: _fullDamageDrivable,
      showError: _showValidationErrors && _isFullDrivableMissing,
      onChanged: (value) => _fullDamageDrivable = value,
    );
  }

  Widget _buildOtherCategorySection(BuildContext context) {
    final theme = Theme.of(context);
    final showError = _showValidationErrors && _isOtherCategoryMissing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showError
              ? theme.colorScheme.error
              : theme.dividerColor.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: (showError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary)
                      .withOpacity(0.12),
                ),
                child: Icon(
                  Icons.build_circle_outlined,
                  color: showError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _otherCategoryLabel(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: showError ? theme.colorScheme.error : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _otherDamageCategory,
            items: _otherDamageCategories
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(_otherCategoryOptionLabel(context, value)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _otherDamageCategory = value;
              });
            },
            decoration: _premiumFieldDec(
              context,
              _otherCategoryLabel(context),
              isError: showError,
            ),
          ),
          if (showError) ...[
            const SizedBox(height: 8),
            Text(
              _requiredOtherCategoryText(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassDamageSection(BuildContext context) {
    final theme = Theme.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final categories = _activePhotoCategories();
    final dateLabel = _glassDamageDate == null
        ? _pickDateButton(context)
        : DateFormat.yMMMMd(localeTag).format(_glassDamageDate!);
    final timeLabel = _hailDamageTime == null
        ? _pickTimeButton(context)
        : _hailDamageTime!.format(context);
    final showTownError = _showValidationErrors && _isTownMissing;
    final showDamageDateError = _showValidationErrors && _isDamageDateMissing;
    final showDamageTimeError = _showValidationErrors && _isDamageTimeMissing;
    final marderDescriptionLabel = _marderDescriptionLabel(context);
    final fullDescriptionLabel = _fullDescriptionLabel(context);
    final otherDescriptionLabel = _otherDescriptionLabel(context);
    final showFullDescriptionError =
        _showValidationErrors && _isFullDescriptionMissing;
    final showOtherDescriptionError =
        _showValidationErrors && _isOtherDescriptionMissing;

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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
                Text(
                  _requiredPhotosTitle(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _requiredPhotosSubtitle(context),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.68),
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < categories.length; i++)
                  _buildGlassPhotoRow(
                    context,
                    category: categories[i],
                    showDivider: i != categories.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _glassTownCtrl,
            textInputAction: TextInputAction.next,
            decoration: _premiumFieldDec(
              context,
              _townLabel(context),
              isError: showTownError,
              errorText: showTownError ? _requiredTownText(context) : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _dateLabel(context),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: showDamageDateError ? theme.colorScheme.error : null,
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
                  color: showDamageDateError
                      ? theme.colorScheme.error
                      : theme.dividerColor.withOpacity(0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    color: showDamageDateError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(dateLabel)),
                ],
              ),
            ),
          ),
          if (showDamageDateError) ...[
            const SizedBox(height: 6),
            Text(
              _requiredDamageDateText(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_usesDamageTimeField) ...[
            const SizedBox(height: 12),
            Text(
              _hailTimeLabel(context),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: showDamageTimeError ? theme.colorScheme.error : null,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickHailDamageTime,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: showDamageTimeError
                        ? theme.colorScheme.error
                        : theme.dividerColor.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_outlined,
                      color: showDamageTimeError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(timeLabel)),
                  ],
                ),
              ),
            ),
            if (showDamageTimeError) ...[
              const SizedBox(height: 6),
              Text(
                _requiredDamageTimeText(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
          if (_isMartenDamage) ...[
            const SizedBox(height: 12),
            _buildMarderDrivableSection(context),
            const SizedBox(height: 12),
            TextField(
              controller: _marderDescriptionCtrl,
              textInputAction: TextInputAction.done,
              minLines: 3,
              maxLines: 5,
              decoration: _premiumFieldDec(
                context,
                marderDescriptionLabel,
              ),
            ),
          ],
          if (_isComprehensiveDamage) ...[
            const SizedBox(height: 12),
            _buildFullDamageDrivableSection(context),
            const SizedBox(height: 12),
            TextField(
              controller: _fullDamageDescriptionCtrl,
              textInputAction: TextInputAction.done,
              minLines: 3,
              maxLines: 5,
              decoration: _premiumFieldDec(
                context,
                fullDescriptionLabel,
                isError: showFullDescriptionError,
                errorText: showFullDescriptionError
                    ? _requiredDescriptionText(context)
                    : null,
              ),
            ),
          ],
          if (_isOtherDamage) ...[
            const SizedBox(height: 12),
            _buildOtherCategorySection(context),
            const SizedBox(height: 12),
            TextField(
              controller: _otherDamageDescriptionCtrl,
              textInputAction: TextInputAction.done,
              minLines: 3,
              maxLines: 5,
              decoration: _premiumFieldDec(
                context,
                otherDescriptionLabel,
                isError: showOtherDescriptionError,
                errorText: showOtherDescriptionError
                    ? _requiredDescriptionText(context)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarGuideCard(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = _showValidationErrors &&
        _usesDamageDetailsForm &&
        _isAppointmentSelectionMissing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasError
            ? theme.colorScheme.error.withOpacity(0.05)
            : theme.colorScheme.surface.withOpacity(0.24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? theme.colorScheme.error.withOpacity(0.40)
              : theme.dividerColor.withOpacity(0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (hasError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              color: hasError
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _calendarGuideTitle(context),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _calendarGuideSubtitle(context),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.70),
                    height: 1.35,
                  ),
                ),
                if (hasError) ...[
                  const SizedBox(height: 6),
                  Text(
                    _calendarRequiredText(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _selectedRequestTypeLabel(BuildContext context) {
    if (_isGlassDamage) return AppLocalizations.of(context)!.damage_glass;
    if (_isHailDamage) return AppLocalizations.of(context)!.damage_hail;
    if (_isMartenDamage) return AppLocalizations.of(context)!.damage_marten;
    if (_isParkingDamage) return AppLocalizations.of(context)!.damage_parking;
    if (_isComprehensiveDamage) {
      return AppLocalizations.of(context)!.damage_comprehensive;
    }
    if (_isOtherDamage) {
      return _copy(
        context: context,
        de: 'Sonstige Schaeden oder technische Probleme',
        it: 'Altri danni o problemi tecnici',
        en: 'Other damages or technical problems',
        fr: 'Autres dommages ou problemes techniques',
      );
    }
    if (widget.serviceType == 'service_anmelden') {
      return workshopServiceLabel(
        Localizations.localeOf(context).languageCode,
        widget.serviceSelectionKey,
      );
    }
    if (_isTireService) {
      return localizedTireServiceType(
        tireLocaleCode(context),
        tireServiceType: widget.tireServiceType,
        serviceType: widget.serviceType,
      );
    }
    return widget.title;
  }

  String _selectedWorkshopName(BuildContext context) => _copy(
        context: context,
        de: 'CrashForm Partnerwerkstatt',
        it: 'Officina partner CrashForm',
        en: 'CrashForm partner workshop',
        fr: 'Atelier partenaire CrashForm',
      );

  String _summaryValue(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '-' : trimmed;
  }

  String _summaryDamageDateValue(BuildContext context) {
    if (_glassDamageDate == null) return '-';
    return DateFormat.yMMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(_glassDamageDate!);
  }

  String _summaryDamageTimeValue(BuildContext context) {
    if (!_usesDamageTimeField) return '-';
    return _hailDamageTime == null ? '-' : _hailDamageTime!.format(context);
  }

  String _summaryAppointmentDateValue(BuildContext context) {
    if (_selectedSlot == null) return '-';
    return DateFormat.yMMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(_selectedSlot!);
  }

  String _summaryAppointmentTimeValue(BuildContext context) {
    if (_selectedSlot == null) return '-';
    return DateFormat('HH:mm').format(_selectedSlot!);
  }

  Widget _summarySectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _summaryInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);
    final displayValue = _summaryValue(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayValue,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPhotoRow(
    BuildContext context, {
    required _SummaryPhotoCountData item,
  }) {
    final theme = Theme.of(context);
    final hasPhotos = item.count > 0;
    final iconColor =
        hasPhotos ? const Color(0xFF16A34A) : const Color(0xFF94A3B8);
    final icon = hasPhotos
        ? Icons.check_circle_rounded
        : item.optional
            ? Icons.add_circle_outline_rounded
            : Icons.radio_button_unchecked_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${item.count}x ${item.title}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hasPhotos
                    ? const Color(0xFF0F172A)
                    : theme.colorScheme.onSurface.withOpacity(0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final photoItems = _summaryPhotoCounts(context);
    final showConfirmationAccent = _canSubmitRequest && !_confirmationAccepted;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      offset: _summaryCardVisible ? Offset.zero : const Offset(0, 0.06),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        opacity: _summaryCardVisible ? 1 : 0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5EDF7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.05),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _summaryTitle(context),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _summarySubtitle(context),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              _summarySectionCard(
                context,
                icon: Icons.directions_car_outlined,
                title: _summaryVehicleSectionTitle(context),
                children: [
                  _summaryInfoRow(
                    context,
                    label: AppLocalizations.of(context)!.license_plate_label,
                    value: _plateCtrl.text,
                    emphasize: true,
                  ),
                  _summaryInfoRow(
                    context,
                    label: _summaryCustomerLabel(context),
                    value: _nameCtrl.text,
                  ),
                  _summaryInfoRow(
                    context,
                    label: _phoneHint(context),
                    value: _phoneCtrl.text,
                  ),
                  _summaryInfoRow(
                    context,
                    label: _emailHint(context),
                    value: _emailCtrl.text,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _summarySectionCard(
                context,
                icon: Icons.report_gmailerrorred_outlined,
                title: _summaryDamageSectionTitle(context),
                children: [
                  _summaryInfoRow(
                    context,
                    label: _summaryTypeLabel(context),
                    value: _selectedRequestTypeLabel(context),
                  ),
                  _summaryInfoRow(
                    context,
                    label: _summaryTownShortLabel(context),
                    value: _glassTownCtrl.text,
                  ),
                  _summaryInfoRow(
                    context,
                    label: _summaryDamageDateShortLabel(context),
                    value: _summaryDamageDateValue(context),
                  ),
                  _summaryInfoRow(
                    context,
                    label: _summaryDamageTimeShortLabel(context),
                    value: _summaryDamageTimeValue(context),
                  ),
                ],
              ),
              if (photoItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                _summarySectionCard(
                  context,
                  icon: Icons.photo_library_outlined,
                  title: _summaryPhotosSectionTitle(context),
                  children: [
                    for (final item in photoItems)
                      _summaryPhotoRow(context, item: item),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _summarySectionCard(
                context,
                icon: Icons.event_available_outlined,
                title: _summaryAppointmentSectionTitle(context),
                children: [
                  _summaryInfoRow(
                    context,
                    label: _summaryDayLabel(context),
                    value: _summaryAppointmentDateValue(context),
                  ),
                  _summaryInfoRow(
                    context,
                    label: _summaryTimeLabel(context),
                    value: _summaryAppointmentTimeValue(context),
                  ),
                  _summaryInfoRow(
                    context,
                    label: _summaryWorkshopLabel(context),
                    value: _selectedWorkshopName(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: showConfirmationAccent
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: showConfirmationAccent
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Checkbox.adaptive(
                        value: _confirmationAccepted,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: _submitting
                            ? null
                            : (value) {
                                setState(() {
                                  _confirmationAccepted = value ?? false;
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _confirmationLabel(context),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _confirmationHint(context),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSubmitButton(
    BuildContext context, {
    required bool canTapSubmit,
    required bool submitReady,
  }) {
    final theme = Theme.of(context);
    final gradient = submitReady
        ? const LinearGradient(
            colors: [
              Color(0xFF79B6FF),
              Color(0xFF3D82F6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              const Color(0xFFCBD5E1).withOpacity(0.9),
              const Color(0xFF94A3B8).withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _submitPressed && canTapSubmit ? 0.985 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: submitReady
              ? [
                  BoxShadow(
                    color: const Color(0xFF3D82F6).withOpacity(0.26),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: canTapSubmit ? _onBookPressed : null,
            onTapDown: canTapSubmit
                ? (_) {
                    setState(() {
                      _submitPressed = true;
                    });
                  }
                : null,
            onTapUp: canTapSubmit
                ? (_) {
                    setState(() {
                      _submitPressed = false;
                    });
                  }
                : null,
            onTapCancel: canTapSubmit
                ? () {
                    setState(() {
                      _submitPressed = false;
                    });
                  }
                : null,
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: _loading || _submitting
                      ? Row(
                          key: const ValueKey('submit_loading'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _submitLoadingLabel(context),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          AppLocalizations.of(context)!.termin_buchen,
                          key: const ValueKey('submit_idle'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Route<void> _buildSuccessRoute({
    required AppointmentRequest request,
    required String requestTypeLabel,
    required String appointmentLabel,
    required String town,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _ClientRequestSuccessScreen(
        request: request,
        requestTypeLabel: requestTypeLabel,
        appointmentLabel: appointmentLabel,
        town: town,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.045),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _onBookPressed() async {
    if (!_confirmationAccepted) {
      return;
    }
    final name = _nameCtrl.text.trim();
    final hasValidationErrors = _isGlassDamage
        ? _hasGlassValidationErrors
        : _isHailDamage
            ? _hasHailValidationErrors
            : _isMartenDamage
                ? _hasMartenValidationErrors
                : _isComprehensiveDamage
                    ? _hasComprehensiveValidationErrors
                    : _isOtherDamage
                        ? _hasOtherValidationErrors
                        : _isParkingDamage
                            ? _hasParkingValidationErrors
                            : name.isEmpty || _selectedSlot == null;

    if (hasValidationErrors) {
      setState(() {
        _showValidationErrors = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_validationSnackBarText(context))),
      );
      return;
    }
    setState(() {
      _showValidationErrors = false;
    });
    if (_isTaken(_selectedSlot!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_snackTakenSlot(context))),
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
        tireServiceType: widget.tireServiceType,
        serviceSelectionKey: widget.serviceSelectionKey,
        damageType: widget.serviceType.startsWith('damage_')
            ? widget.serviceType
            : widget.damageType,
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
        hailDamageTown: _isHailDamage ? _glassTownCtrl.text.trim() : null,
        hailDamageDate: _isHailDamage && _glassDamageDate != null
            ? _glassDamageDate!.toUtc().toIso8601String()
            : null,
        hailDamageTime: _isHailDamage && _hailDamageTime != null
            ? '${_hailDamageTime!.hour.toString().padLeft(2, '0')}:${_hailDamageTime!.minute.toString().padLeft(2, '0')}'
            : null,
        marderDamageTown: _isMartenDamage ? _glassTownCtrl.text.trim() : null,
        marderDamageDate: _isMartenDamage && _glassDamageDate != null
            ? _glassDamageDate!.toUtc().toIso8601String()
            : null,
        marderDamageTime: _isMartenDamage && _hailDamageTime != null
            ? '${_hailDamageTime!.hour.toString().padLeft(2, '0')}:${_hailDamageTime!.minute.toString().padLeft(2, '0')}'
            : null,
        marderDamageDrivable: _isMartenDamage ? _marderDamageDrivable : null,
        marderDamageDescription:
            _isMartenDamage ? _marderDescriptionCtrl.text.trim() : null,
        fullDamageTown:
            _isComprehensiveDamage ? _glassTownCtrl.text.trim() : null,
        fullDamageDate: _isComprehensiveDamage && _glassDamageDate != null
            ? _glassDamageDate!.toUtc().toIso8601String()
            : null,
        fullDamageTime: _isComprehensiveDamage && _hailDamageTime != null
            ? '${_hailDamageTime!.hour.toString().padLeft(2, '0')}:${_hailDamageTime!.minute.toString().padLeft(2, '0')}'
            : null,
        fullDamageDrivable: _isComprehensiveDamage ? _fullDamageDrivable : null,
        fullDamageDescription: _isComprehensiveDamage
            ? _fullDamageDescriptionCtrl.text.trim()
            : null,
        otherDamageTown: _isOtherDamage ? _glassTownCtrl.text.trim() : null,
        otherDamageDate: _isOtherDamage && _glassDamageDate != null
            ? _glassDamageDate!.toUtc().toIso8601String()
            : null,
        otherDamageTime: _isOtherDamage && _hailDamageTime != null
            ? '${_hailDamageTime!.hour.toString().padLeft(2, '0')}:${_hailDamageTime!.minute.toString().padLeft(2, '0')}'
            : null,
        otherDamageCategory: _isOtherDamage ? _otherDamageCategory : null,
        otherDamageDescription:
            _isOtherDamage ? _otherDamageDescriptionCtrl.text.trim() : null,
        parkingDamageTown: _isParkingDamage ? _glassTownCtrl.text.trim() : null,
        parkingDamageDate: _isParkingDamage && _glassDamageDate != null
            ? _glassDamageDate!.toUtc().toIso8601String()
            : null,
        parkingDamageTime: _isParkingDamage && _hailDamageTime != null
            ? '${_hailDamageTime!.hour.toString().padLeft(2, '0')}:${_hailDamageTime!.minute.toString().padLeft(2, '0')}'
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
        glassDamageCurrentKmImages: _isGlassDamage
            ? _glassCurrentKmImages.map((e) => e.toInput()).toList()
            : const [],
        hailDamageVehicleDocumentImages: _isHailDamage
            ? _hailVehicleDocumentImages.map((e) => e.toInput()).toList()
            : const [],
        hailDamageDamageImages: _isHailDamage
            ? _hailDamageImages.map((e) => e.toInput()).toList()
            : const [],
        hailDamageOverviewImages: _isHailDamage
            ? _hailOverviewImages.map((e) => e.toInput()).toList()
            : const [],
        hailDamageCurrentKmImages: _isHailDamage
            ? _hailCurrentKmImages.map((e) => e.toInput()).toList()
            : const [],
        hailDamageExtraImages: _isHailDamage
            ? [
                ..._hailExtraImage1.map((e) => e.toInput()),
                ..._hailExtraImage2.map((e) => e.toInput()),
              ]
            : const [],
        marderDamageVehicleDocumentImages: _isMartenDamage
            ? _marderVehicleDocumentImages.map((e) => e.toInput()).toList()
            : const [],
        marderDamageEngineBayImages: _isMartenDamage
            ? _marderEngineBayImages.map((e) => e.toInput()).toList()
            : const [],
        marderDamageCableImages: _isMartenDamage
            ? _marderCableImages.map((e) => e.toInput()).toList()
            : const [],
        marderDamageCurrentKmImages: _isMartenDamage
            ? _marderCurrentKmImages.map((e) => e.toInput()).toList()
            : const [],
        marderDamageExtraImages: _isMartenDamage
            ? _marderExtraImages.map((e) => e.toInput()).toList()
            : const [],
        fullDamageVehicleDocumentImages: _isComprehensiveDamage
            ? _fullVehicleDocumentImages.map((e) => e.toInput()).toList()
            : const [],
        fullDamageCloseImages: _isComprehensiveDamage
            ? _fullCloseImages.map((e) => e.toInput()).toList()
            : const [],
        fullDamageOverviewImages: _isComprehensiveDamage
            ? _fullOverviewImages.map((e) => e.toInput()).toList()
            : const [],
        fullDamageCurrentKmImages: _isComprehensiveDamage
            ? _fullCurrentKmImages.map((e) => e.toInput()).toList()
            : const [],
        fullDamageExtraImages: _isComprehensiveDamage
            ? _fullExtraImages.map((e) => e.toInput()).toList()
            : const [],
        otherDamageVehicleDocumentImages: _isOtherDamage
            ? _otherVehicleDocumentImages.map((e) => e.toInput()).toList()
            : const [],
        otherDamageProblemImages: _isOtherDamage
            ? _otherProblemImages.map((e) => e.toInput()).toList()
            : const [],
        otherDamageCurrentKmImages: _isOtherDamage
            ? _otherCurrentKmImages.map((e) => e.toInput()).toList()
            : const [],
        otherDamageExtraImages: _isOtherDamage
            ? _otherExtraImages.map((e) => e.toInput()).toList()
            : const [],
        parkingDamageVehicleDocumentImages: _isParkingDamage
            ? _parkingVehicleDocumentImages.map((e) => e.toInput()).toList()
            : const [],
        parkingDamageDamageImages: _isParkingDamage
            ? _parkingDamageImages.map((e) => e.toInput()).toList()
            : const [],
        parkingDamageOverviewImages: _isParkingDamage
            ? _parkingOverviewImages.map((e) => e.toInput()).toList()
            : const [],
        parkingDamageCurrentKmImages: _isParkingDamage
            ? _parkingCurrentKmImages.map((e) => e.toInput()).toList()
            : const [],
        parkingDamageExtraImages: _isParkingDamage
            ? _parkingExtraImages.map((e) => e.toInput()).toList()
            : const [],
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        _buildSuccessRoute(
          request: request,
          requestTypeLabel: _selectedRequestTypeLabel(context),
          appointmentLabel: slotStr,
          town: _glassTownCtrl.text.trim(),
        ),
      );
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
    final theme = Theme.of(context);
    final tf = DateFormat('HH:mm');
    final slots =
        _buildSlots(_selectedDay).where((slot) => !_isBooked(slot)).toList();
    final usesDamageValidation = _usesDamageDetailsForm;
    final showNameError =
        _showValidationErrors && usesDamageValidation && _isNameMissing;
    final showContactError =
        _showValidationErrors && usesDamageValidation && _isContactMissing;
    final showAppointmentError = _showValidationErrors &&
        usesDamageValidation &&
        _isAppointmentSelectionMissing;
    final formHeaderTitle = _formHeaderTitle(context);
    final formHeaderSubtitle = _formHeaderSubtitle(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_appBarTitle(context)),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: _showInitialSkeleton
                ? _buildInitialLoadingSkeleton(context)
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        formHeaderTitle,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      if (formHeaderSubtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          formHeaderSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.72),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _licensePlateCard(context),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: _premiumFieldDec(
                          context,
                          _nameHint(context),
                          isError: showNameError,
                          errorText:
                              showNameError ? _requiredNameText(context) : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _phoneCtrl,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.phone,
                                  decoration: _premiumFieldDec(
                                    context,
                                    _phoneHint(context),
                                    isError: showContactError,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _emailCtrl,
                                  textInputAction: TextInputAction.done,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _premiumFieldDec(
                                    context,
                                    _emailHint(context),
                                    isError: showContactError,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (showContactError) ...[
                            const SizedBox(height: 6),
                            Text(
                              _requiredContactText(context),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_usesDamageDetailsForm) ...[
                        const SizedBox(height: 16),
                        _buildGlassDamageSection(context),
                      ],
                      const SizedBox(height: 16),
                      _buildCalendarGuideCard(context),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: showAppointmentError
                              ? theme.colorScheme.error.withOpacity(0.04)
                              : theme.colorScheme.surface.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: showAppointmentError
                                ? theme.colorScheme.error.withOpacity(0.40)
                                : theme.dividerColor.withOpacity(0.28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TableCalendar(
                              firstDay: DateTime.now(),
                              lastDay:
                                  DateTime.now().add(const Duration(days: 120)),
                              focusedDay: _focusedDay,
                              locale: _calendarLocaleTag(context),
                              startingDayOfWeek: StartingDayOfWeek.monday,
                              availableCalendarFormats:
                                  _calendarFormatLabels(context),
                              headerStyle: HeaderStyle(
                                titleCentered: true,
                                titleTextFormatter: (date, _) =>
                                    '${_calendarMonthLabel(context, date.month)} ${date.year}',
                              ),
                              daysOfWeekStyle: DaysOfWeekStyle(
                                dowTextFormatter: (date, _) =>
                                    _calendarWeekdayLabel(
                                        context, date.weekday),
                              ),
                              selectedDayPredicate: (d) =>
                                  isSameDay(d, _selectedDay),
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
                            if (showAppointmentError) ...[
                              const SizedBox(height: 6),
                              Text(
                                _calendarRequiredText(context),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
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

                                  final primary = theme.colorScheme.primary;
                                  final borderColor = selected
                                      ? primary
                                      : theme.dividerColor.withOpacity(0.6);

                                  return OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: selected
                                          ? primary
                                          : Colors.transparent,
                                      foregroundColor:
                                          selected ? Colors.white : primary,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: _summaryFormListenable,
                        builder: (context, _) {
                          final canTapSubmit = !_loading &&
                              !_submitting &&
                              _confirmationAccepted;
                          final submitReady =
                              _canSubmitRequest && _confirmationAccepted;
                          return Column(
                            children: [
                              _buildPremiumSummaryCard(context),
                              const SizedBox(height: 18),
                              _buildPremiumSubmitButton(
                                context,
                                canTapSubmit: canTapSubmit,
                                submitReady: submitReady,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SafeArea(
                        top: false,
                        child: const SizedBox(height: 8),
                      ),
                    ],
                  ),
          ),
          _buildSubmitLoadingOverlay(context),
        ],
      ),
    );
  }
}

class _ClientRequestSuccessScreen extends StatefulWidget {
  const _ClientRequestSuccessScreen({
    required this.request,
    required this.requestTypeLabel,
    required this.appointmentLabel,
    required this.town,
  });

  final AppointmentRequest request;
  final String requestTypeLabel;
  final String appointmentLabel;
  final String town;

  @override
  State<_ClientRequestSuccessScreen> createState() =>
      _ClientRequestSuccessScreenState();
}

enum _OfflineSyncBadgeState { savedOffline, syncing, synced }

class _ClientRequestSuccessScreenState
    extends State<_ClientRequestSuccessScreen> {
  bool get _isOffline => widget.request.status == 'pending_sync';
  final _syncService = AppointmentRequestsService();
  Timer? _syncStatusTimer;
  bool _syncCheckInFlight = false;
  _OfflineSyncBadgeState _offlineSyncState =
      _OfflineSyncBadgeState.savedOffline;

  @override
  void initState() {
    super.initState();
    if (_isOffline) {
      Future<void>.delayed(
        const Duration(seconds: 2),
        _refreshOfflineSyncStatus,
      );
      _syncStatusTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _refreshOfflineSyncStatus(),
      );
    }
  }

  @override
  void dispose() {
    _syncStatusTimer?.cancel();
    super.dispose();
  }

  String _copy(
    BuildContext context, {
    required String de,
    required String it,
    required String en,
    required String fr,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'it':
        return it;
      case 'fr':
        return fr;
      case 'en':
        return en;
      default:
        return de;
    }
  }

  String _title(BuildContext context) {
    if (_isOffline) {
      return _copy(
        context,
        de: 'Anfrage lokal gespeichert',
        it: 'Richiesta salvata offline',
        en: 'Request saved offline',
        fr: 'Demande enregistree hors ligne',
      );
    }
    return _copy(
      context,
      de: 'Anfrage erfolgreich gesendet',
      it: 'Richiesta inviata con successo',
      en: 'Request sent successfully',
      fr: 'Demande envoyee avec succes',
    );
  }

  String _subtitle(BuildContext context) {
    if (_isOffline) {
      return _copy(
        context,
        de: 'Sie wird automatisch gesendet, sobald wieder Internet verfugbar ist.',
        it: 'Verra inviata automaticamente appena torna la connessione.',
        en: 'It will be sent automatically once internet is available again.',
        fr: 'Elle sera envoyee automatiquement des que la connexion sera disponible.',
      );
    }
    return _copy(
      context,
      de: 'Ihre Anfrage wurde gespeichert und an die Werkstatt ubermittelt.',
      it: 'La tua richiesta e stata salvata e inviata all’officina.',
      en: 'Your request has been saved and sent to the workshop.',
      fr: 'Votre demande a ete enregistree et envoyee a l’atelier.',
    );
  }

  String _summaryTitle(BuildContext context) {
    return _copy(
      context,
      de: 'Ubersicht Ihrer Anfrage',
      it: 'Riepilogo della richiesta',
      en: 'Request overview',
      fr: 'Apercu de votre demande',
    );
  }

  String _timelineTitle(BuildContext context) {
    return _copy(
      context,
      de: 'Status der Ubermittlung',
      it: 'Stato della trasmissione',
      en: 'Submission status',
      fr: 'Statut de l’envoi',
    );
  }

  String _damageTypeLabel(BuildContext context) {
    return _copy(
      context,
      de: 'Schadentyp',
      it: 'Tipo danno',
      en: 'Damage type',
      fr: 'Type de dommage',
    );
  }

  String _plateLabel(BuildContext context) {
    return _copy(
      context,
      de: 'Kennzeichen',
      it: 'Targa',
      en: 'License plate',
      fr: 'Plaque',
    );
  }

  String _appointmentLabelTitle(BuildContext context) {
    return _copy(
      context,
      de: 'Termin',
      it: 'Appuntamento',
      en: 'Appointment',
      fr: 'Rendez-vous',
    );
  }

  String _townLabel(BuildContext context) {
    return _copy(
      context,
      de: 'Ort',
      it: 'Localita',
      en: 'Location',
      fr: 'Lieu',
    );
  }

  String _referenceLabel(BuildContext context) {
    return _copy(
      context,
      de: 'Referenznummer',
      it: 'Numero pratica',
      en: 'Reference number',
      fr: 'Numero de dossier',
    );
  }

  String _overviewButtonLabel(BuildContext context) {
    return _copy(
      context,
      de: 'Zur Ubersicht',
      it: 'Vai al riepilogo',
      en: 'Go to overview',
      fr: 'Aller a l’aperçu',
    );
  }

  String _newRequestButtonLabel(BuildContext context) {
    return _copy(
      context,
      de: 'Neue Anfrage erstellen',
      it: 'Crea nuova richiesta',
      en: 'Create new request',
      fr: 'Creer une nouvelle demande',
    );
  }

  String _emptyValue(BuildContext context) {
    return _copy(
      context,
      de: 'Nicht angegeben',
      it: 'Non indicato',
      en: 'Not provided',
      fr: 'Non indique',
    );
  }

  String _otherDamageLabel(BuildContext context) {
    return _copy(
      context,
      de: 'Sonstige Schaden',
      it: 'Altri danni',
      en: 'Other damages',
      fr: 'Autres dommages',
    );
  }

  String _offlineSavedLabel(BuildContext context) => _copy(
        context,
        de: 'Offline gespeichert',
        it: 'Salvato offline',
        en: 'Saved offline',
        fr: 'Enregistre hors ligne',
      );

  String _syncingLabel(BuildContext context) => _copy(
        context,
        de: 'Synchronisierung...',
        it: 'Sincronizzazione...',
        en: 'Synchronizing...',
        fr: 'Synchronisation...',
      );

  String _syncedLabel(BuildContext context) => _copy(
        context,
        de: 'Synchronisiert',
        it: 'Sincronizzato',
        en: 'Synchronized',
        fr: 'Synchronise',
      );

  Future<void> _refreshOfflineSyncStatus() async {
    if (!_isOffline || !mounted || _syncCheckInFlight) return;
    if (_offlineSyncState == _OfflineSyncBadgeState.synced) return;
    _syncCheckInFlight = true;
    setState(() {
      _offlineSyncState = _OfflineSyncBadgeState.syncing;
    });
    try {
      await AppointmentRequestsSyncManager.trigger();
      final request = await _syncService.fetchRequestById(widget.request.id);
      if (!mounted) return;
      setState(() {
        _offlineSyncState = request == null
            ? _OfflineSyncBadgeState.synced
            : _OfflineSyncBadgeState.savedOffline;
      });
      if (_offlineSyncState == _OfflineSyncBadgeState.synced) {
        _syncStatusTimer?.cancel();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _offlineSyncState = _OfflineSyncBadgeState.savedOffline;
      });
    } finally {
      _syncCheckInFlight = false;
    }
  }

  Widget _buildOfflineSyncBadge(BuildContext context) {
    late final IconData icon;
    late final Color foreground;
    late final Color background;
    late final String text;

    switch (_offlineSyncState) {
      case _OfflineSyncBadgeState.savedOffline:
        icon = Icons.cloud_off_rounded;
        foreground = const Color(0xFFB8651F);
        background = const Color(0xFFFFF3E8);
        text = _offlineSavedLabel(context);
        break;
      case _OfflineSyncBadgeState.syncing:
        icon = Icons.sync_rounded;
        foreground = const Color(0xFF1D5B9C);
        background = const Color(0xFFEFF6FF);
        text = _syncingLabel(context);
        break;
      case _OfflineSyncBadgeState.synced:
        icon = Icons.check_rounded;
        foreground = const Color(0xFF169455);
        background = const Color(0xFFE7F7EE);
        text = '✓ ${_syncedLabel(context)}';
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: Container(
        key: ValueKey(_offlineSyncState),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 8),
            Text(
              text,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolvedTown() {
    final town = widget.town.trim();
    if (town.isNotEmpty) return town;
    final request = widget.request;
    return request.glassDamageTown?.trim().isNotEmpty == true
        ? request.glassDamageTown!.trim()
        : request.hailDamageTown?.trim().isNotEmpty == true
            ? request.hailDamageTown!.trim()
            : request.marderDamageTown?.trim().isNotEmpty == true
                ? request.marderDamageTown!.trim()
                : request.fullDamageTown?.trim().isNotEmpty == true
                    ? request.fullDamageTown!.trim()
                    : request.otherDamageTown?.trim().isNotEmpty == true
                        ? request.otherDamageTown!.trim()
                        : request.parkingDamageTown?.trim().isNotEmpty == true
                            ? request.parkingDamageTown!.trim()
                            : '';
  }

  String _resolvedAppointmentLabel() {
    final label = widget.appointmentLabel.trim();
    if (label.isNotEmpty) return label;
    final date =
        DateFormat('dd.MM.yyyy').format(widget.request.appointmentDate);
    final time = widget.request.appointmentTime.trim();
    if (time.isEmpty) return date;
    return '$date ${time.length >= 5 ? time.substring(0, 5) : time}';
  }

  String _referenceNumber() {
    final id = widget.request.id.trim();
    if (id.isEmpty) return '-';
    if (id.startsWith('local_req_')) {
      final suffix = id.replaceFirst('local_req_', '');
      final short =
          suffix.length > 8 ? suffix.substring(suffix.length - 8) : suffix;
      return 'LOC-$short';
    }
    final compact = id.replaceAll('-', '').toUpperCase();
    if (compact.length <= 10) return compact;
    return compact.substring(0, 10);
  }

  IconData _damageIconFor(DamageType type) {
    switch (type) {
      case DamageType.glass:
        return Icons.grid_view_rounded;
      case DamageType.hail:
        return Icons.grain_rounded;
      case DamageType.marten:
        return Icons.pets_rounded;
      case DamageType.parking:
        return Icons.local_parking_rounded;
      case DamageType.comprehensive:
        return Icons.description_rounded;
      case DamageType.other:
        return Icons.more_horiz_rounded;
    }
  }

  String _damageLabelForType(BuildContext context, DamageType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case DamageType.glass:
        return l10n.damage_glass;
      case DamageType.hail:
        return l10n.damage_hail;
      case DamageType.marten:
        return l10n.damage_marten;
      case DamageType.parking:
        return l10n.damage_parking;
      case DamageType.comprehensive:
        return l10n.damage_comprehensive;
      case DamageType.other:
        return _otherDamageLabel(context);
    }
  }

  String _damageServiceType(DamageType type) {
    switch (type) {
      case DamageType.glass:
        return 'damage_glass';
      case DamageType.hail:
        return 'damage_hail';
      case DamageType.marten:
        return 'damage_marten';
      case DamageType.parking:
        return 'damage_parking';
      case DamageType.comprehensive:
        return 'damage_comprehensive';
      case DamageType.other:
        return 'damage_other';
    }
  }

  Future<void> _openOverview() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyRequestsPage()),
    );
  }

  Future<void> _openNewRequestPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<DamageType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: DamageTypePickerSheet(
            title: l10n.damage_type_title,
            subtitle: l10n.damage_type_subtitle,
            cancelText: l10n.cancel,
            types: const [
              DamageType.glass,
              DamageType.hail,
              DamageType.marten,
              DamageType.parking,
              DamageType.comprehensive,
              DamageType.other,
            ],
            selectedDamageType: null,
            iconFor: _damageIconFor,
            labelFor: (type) => _damageLabelForType(context, type),
            onSelected: (type) => Navigator.of(sheetContext).pop(type),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    final title =
        '${l10n.damage_type_title} - ${_damageLabelForType(context, selected)}';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkshopSlotPickerScreen(
          title: title,
          serviceType: _damageServiceType(selected),
          damageType: selected.name,
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1D5B9C), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF6A7C92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF10243E),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final town = _resolvedTown();
    final requestType = widget.requestTypeLabel.trim().isEmpty
        ? _emptyValue(context)
        : widget.requestTypeLabel.trim();
    final plate = widget.request.licensePlate?.trim().isNotEmpty == true
        ? widget.request.licensePlate!.trim()
        : _emptyValue(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B1F33),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 540;
          final itemWidth = twoColumns
              ? (constraints.maxWidth - 14) / 2
              : constraints.maxWidth;

          final items = [
            (
              icon: Icons.layers_rounded,
              label: _damageTypeLabel(context),
              value: requestType,
            ),
            (
              icon: Icons.directions_car_filled_rounded,
              label: _plateLabel(context),
              value: plate,
            ),
            (
              icon: Icons.event_available_rounded,
              label: _appointmentLabelTitle(context),
              value: _resolvedAppointmentLabel(),
            ),
            (
              icon: Icons.place_rounded,
              label: _townLabel(context),
              value: town.isEmpty ? _emptyValue(context) : town,
            ),
            (
              icon: Icons.tag_rounded,
              label: _referenceLabel(context),
              value: _referenceNumber(),
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _summaryTitle(context),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF10243E),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: itemWidth,
                      child: _buildSummaryItem(
                        context,
                        icon: item.icon,
                        label: item.label,
                        value: item.value,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<_SuccessTimelineEntry> _timelineEntries(BuildContext context) {
    final complete = !_isOffline;
    return [
      _SuccessTimelineEntry(
        label: _copy(
          context,
          de: 'Anfrage erstellt',
          it: 'Richiesta creata',
          en: 'Request created',
          fr: 'Demande creee',
        ),
        completed: true,
      ),
      _SuccessTimelineEntry(
        label: _copy(
          context,
          de: 'Daten gespeichert',
          it: 'Dati salvati',
          en: 'Data saved',
          fr: 'Donnees enregistrees',
        ),
        completed: true,
      ),
      _SuccessTimelineEntry(
        label: _copy(
          context,
          de: 'Fotos hochgeladen',
          it: 'Foto caricate',
          en: 'Photos uploaded',
          fr: 'Photos telechargees',
        ),
        completed: complete,
      ),
      _SuccessTimelineEntry(
        label: _copy(
          context,
          de: 'Werkstatt informiert',
          it: 'Officina informata',
          en: 'Workshop notified',
          fr: 'Atelier informe',
        ),
        completed: complete,
      ),
    ];
  }

  Widget _buildTimelineCard(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _timelineEntries(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B1F33),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _timelineTitle(context),
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF10243E),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < entries.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: entries[i].completed
                            ? const Color(0xFFE7F7EE)
                            : const Color(0xFFEAF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        entries[i].completed
                            ? Icons.check_rounded
                            : Icons.sync_rounded,
                        color: entries[i].completed
                            ? const Color(0xFF169455)
                            : const Color(0xFF1D5B9C),
                        size: 18,
                      ),
                    ),
                    if (i != entries.length - 1)
                      Container(
                        width: 2,
                        height: 24,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: const Color(0xFFDCE6F0),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entries[i].label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: entries[i].completed
                            ? const Color(0xFF10243E)
                            : const Color(0xFF5F7690),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF2B6CB0), Color(0xFF5A8FD8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x223E7BCB),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openOverview,
            child: SizedBox(
              height: 58,
              child: Center(
                child: Text(
                  _overviewButtonLabel(context),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _openNewRequestPicker,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: Color(0xFFBFD0E4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: const Color(0xEBFFFFFF),
        ),
        child: Text(
          _newRequestButtonLabel(context),
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF1D5B9C),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x222B6CB0), Color(0x002B6CB0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: -70,
            top: 220,
            child: Container(
              width: 210,
              height: 210,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x1A20A86B), Color(0x0020A86B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  24,
                  16,
                  24 + media.viewPadding.bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 28 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 620),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.78 + (0.22 * value),
                                child: child,
                              ),
                            );
                          },
                          child: Center(
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFE6F8EE),
                                    Color(0xFFD8F1E4),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x1F169455),
                                    blurRadius: 24,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 56,
                                color: Color(0xFF169455),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          _title(context),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF10243E),
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _subtitle(context),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF5F7690),
                            height: 1.45,
                          ),
                        ),
                        if (_isOffline) ...[
                          const SizedBox(height: 16),
                          Center(child: _buildOfflineSyncBadge(context)),
                        ],
                        const SizedBox(height: 28),
                        _buildSummaryCard(context),
                        const SizedBox(height: 18),
                        _buildTimelineCard(context),
                        const SizedBox(height: 26),
                        _buildPrimaryButton(context),
                        const SizedBox(height: 12),
                        _buildSecondaryButton(context),
                      ],
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
}

class _SuccessTimelineEntry {
  const _SuccessTimelineEntry({
    required this.label,
    required this.completed,
  });

  final String label;
  final bool completed;
}
