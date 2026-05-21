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
  TimeOfDay? _hailDamageTime;
  bool _showValidationErrors = false;
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
  final List<_GlassDamageImageDraft> _glassCurrentKmImages = [];
  final List<_GlassDamageImageDraft> _hailVehicleDocumentImages = [];
  final List<_GlassDamageImageDraft> _hailDamageImages = [];
  final List<_GlassDamageImageDraft> _hailOverviewImages = [];
  final List<_GlassDamageImageDraft> _hailCurrentKmImages = [];
  final List<_GlassDamageImageDraft> _hailExtraImage1 = [];
  final List<_GlassDamageImageDraft> _hailExtraImage2 = [];
  final List<_GlassDamageImageDraft> _parkingVehicleDocumentImages = [];
  final List<_GlassDamageImageDraft> _parkingDamageImages = [];
  final List<_GlassDamageImageDraft> _parkingOverviewImages = [];
  final List<_GlassDamageImageDraft> _parkingCurrentKmImages = [];
  final List<_GlassDamageImageDraft> _parkingExtraImages = [];

  bool get _isGlassDamage => widget.serviceType == 'damage_glass';
  bool get _isHailDamage => widget.serviceType == 'damage_hail';
  bool get _isParkingDamage => widget.serviceType == 'damage_parking';
  bool get _usesDamageDetailsForm =>
      _isGlassDamage || _isHailDamage || _isParkingDamage;

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
            : _isParkingDamage
                ? 'Fotos Parkschaden'
                : 'Benoetigte Fotos',
        it: _isHailDamage
            ? 'Foto danno grandine'
            : _isParkingDamage
                ? 'Foto danno parcheggio'
                : 'Foto richieste',
        en: _isHailDamage
            ? 'Hail damage photos'
            : _isParkingDamage
                ? 'Parking damage photos'
                : 'Required photos',
        fr: _isHailDamage
            ? 'Photos degats grele'
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

  String _hailTimeLabel(BuildContext context) => _copy(
        context: context,
        de: 'Zu welcher Uhrzeit ist der Schaden passiert?',
        it: 'A che ora è avvenuto il danno?',
        en: 'At what time did the damage occur?',
        fr: 'À quelle heure le dommage est-il survenu ?',
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
    _nameCtrl.removeListener(_onValidationFieldChanged);
    _phoneCtrl.removeListener(_onValidationFieldChanged);
    _emailCtrl.removeListener(_onValidationFieldChanged);
    _plateCtrl.removeListener(_onValidationFieldChanged);
    _glassTownCtrl.removeListener(_onValidationFieldChanged);
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
    _nameCtrl.addListener(_onValidationFieldChanged);
    _phoneCtrl.addListener(_onValidationFieldChanged);
    _emailCtrl.addListener(_onValidationFieldChanged);
    _plateCtrl.addListener(_onValidationFieldChanged);
    _glassTownCtrl.addListener(_onValidationFieldChanged);
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

  bool get _isParkingVehicleDocumentPhotoMissing =>
      _parkingVehicleDocumentImages.isEmpty;

  bool get _isParkingDamagePhotoMissing => _parkingDamageImages.isEmpty;

  bool get _isParkingOverviewPhotoMissing => _parkingOverviewImages.isEmpty;

  bool get _isParkingCurrentKmPhotoMissing => _parkingCurrentKmImages.isEmpty;

  bool get _isTownMissing => _glassTownCtrl.text.trim().isEmpty;

  bool get _isDamageDateMissing => _glassDamageDate == null;

  bool get _isDamageTimeMissing =>
      (_isHailDamage || _isParkingDamage) && _hailDamageTime == null;

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
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    await _handlePickedFile(file, category);
  }

  Future<void> _pickGlassDamageGallery(String category) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    await _handlePickedFile(file, category);
  }

  Future<void> _removeGlassImage(String category, int index) async {
    final items = _imagesForCategory(category);
    final item = items[index];
    await _deleteGlassImageDraft(item);
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
            (category == AppointmentRequestImageCategory.parkingOverview &&
                _isParkingOverviewPhotoMissing) ||
            (category == AppointmentRequestImageCategory.parkingCurrentKm &&
                _isParkingCurrentKmPhotoMissing));

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError
                  ? theme.colorScheme.error.withOpacity(0.45)
                  : Colors.transparent,
            ),
            color: hasError
                ? theme.colorScheme.error.withOpacity(0.04)
                : Colors.transparent,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showGlassImageActionSheet(category),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
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
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.68),
                            ),
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
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasImage
                          ? const Color(0xFF16A34A).withOpacity(0.12)
                          : theme.colorScheme.surface.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasImage) ...[
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          hasImage
                              ? _statusChangeLabel(context)
                              : _statusAddLabel(context),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: hasImage
                                ? const Color(0xFF16A34A)
                                : theme.colorScheme.onSurface.withOpacity(0.75),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openGlassImagePreview(image),
                      child: Tooltip(
                        message: _previewPhotoTooltip(context),
                        child: _buildGlassImageThumbnail(context, image: image),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _removeGlassImage(category, 0),
                      tooltip: _removePhotoTooltip(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
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
          if (_isHailDamage || _isParkingDamage) ...[
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

  Future<void> _onBookPressed() async {
    final name = _nameCtrl.text.trim();
    final hasValidationErrors = _isGlassDamage
        ? _hasGlassValidationErrors
        : _isHailDamage
            ? _hasHailValidationErrors
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
    final isCurrentKmPhotoMissing = _isGlassDamage
        ? _isGlassCurrentKmPhotoMissing
        : _isHailDamage
            ? _isHailCurrentKmPhotoMissing
            : _isParkingDamage
                ? _isParkingCurrentKmPhotoMissing
                : false;
    final canTapSubmit = !_loading && !_submitting;
    final submitReady = _canSubmitRequest;

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
              decoration: _premiumFieldDec(
                context,
                _nameHint(context),
                isError: showNameError,
                errorText: showNameError ? _requiredNameText(context) : null,
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
                    lastDay: DateTime.now().add(const Duration(days: 120)),
                    focusedDay: _focusedDay,
                    locale: _calendarLocaleTag(context),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    availableCalendarFormats: _calendarFormatLabels(context),
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      titleTextFormatter: (date, _) =>
                          '${_calendarMonthLabel(context, date.month)} ${date.year}',
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      dowTextFormatter: (date, _) =>
                          _calendarWeekdayLabel(context, date.weekday),
                    ),
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
                            backgroundColor:
                                selected ? primary : Colors.transparent,
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
                ],
              ),
            ),
            const SizedBox(height: 28),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: submitReady
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : const [],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canTapSubmit && !isCurrentKmPhotoMissing
                      ? _onBookPressed
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: submitReady
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withOpacity(0.36),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        theme.colorScheme.primary.withOpacity(0.24),
                    disabledForegroundColor:
                        theme.colorScheme.onSurface.withOpacity(0.48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _loading || _submitting ? '...' : l10n.termin_buchen,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: submitReady
                          ? Colors.white
                          : theme.colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SafeArea(
              top: false,
              child: const SizedBox(height: 8),
            ),
          ],
        ),
      ),
    );
  }
}
