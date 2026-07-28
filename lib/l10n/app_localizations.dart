import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('it')
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'CID Digitale'**
  String get appTitle;

  /// No description provided for @faultLiabilityHintA.
  ///
  /// In de, this message translates to:
  /// **'Eurer Meinung nach ist Fahrer A schuld.'**
  String get faultLiabilityHintA;

  /// No description provided for @faultLiabilityHintB.
  ///
  /// In de, this message translates to:
  /// **'Eurer Meinung nach ist Fahrer B schuld.'**
  String get faultLiabilityHintB;

  /// No description provided for @integrityNotVerifiedWarning.
  ///
  /// In de, this message translates to:
  /// **'Achtung: Integrität nicht verifiziert (Daten oder Anhänge könnten geändert worden sein).'**
  String get integrityNotVerifiedWarning;

  /// No description provided for @labelDateTime.
  ///
  /// In de, this message translates to:
  /// **'Datum und Uhrzeit:'**
  String get labelDateTime;

  /// No description provided for @labelPlace.
  ///
  /// In de, this message translates to:
  /// **'Ort:'**
  String get labelPlace;

  /// No description provided for @labelDriverA.
  ///
  /// In de, this message translates to:
  /// **'Fahrer A'**
  String get labelDriverA;

  /// No description provided for @labelDriverB.
  ///
  /// In de, this message translates to:
  /// **'Fahrer B'**
  String get labelDriverB;

  /// No description provided for @labelDriverAText.
  ///
  /// In de, this message translates to:
  /// **'Fahrer A (Text):'**
  String get labelDriverAText;

  /// No description provided for @labelDriverBText.
  ///
  /// In de, this message translates to:
  /// **'Fahrer B (Text):'**
  String get labelDriverBText;

  /// No description provided for @labelDriverAVoice.
  ///
  /// In de, this message translates to:
  /// **'Sprachnotiz Fahrer A'**
  String get labelDriverAVoice;

  /// No description provided for @labelDriverBVoice.
  ///
  /// In de, this message translates to:
  /// **'Sprachnotiz Fahrer B'**
  String get labelDriverBVoice;

  /// No description provided for @labelDriverAColon.
  ///
  /// In de, this message translates to:
  /// **'Fahrer A:'**
  String get labelDriverAColon;

  /// No description provided for @labelDriverBColon.
  ///
  /// In de, this message translates to:
  /// **'Fahrer B:'**
  String get labelDriverBColon;

  /// No description provided for @driverA.
  ///
  /// In de, this message translates to:
  /// **'Fahrer A'**
  String get driverA;

  /// No description provided for @driverB.
  ///
  /// In de, this message translates to:
  /// **'Fahrer B'**
  String get driverB;

  /// No description provided for @firstName.
  ///
  /// In de, this message translates to:
  /// **'Vorname'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In de, this message translates to:
  /// **'Nachname'**
  String get lastName;

  /// No description provided for @zip.
  ///
  /// In de, this message translates to:
  /// **'PLZ'**
  String get zip;

  /// No description provided for @city.
  ///
  /// In de, this message translates to:
  /// **'Ort'**
  String get city;

  /// No description provided for @service_anmelden.
  ///
  /// In de, this message translates to:
  /// **'Service anmelden'**
  String get service_anmelden;

  /// No description provided for @raeder_wechsel.
  ///
  /// In de, this message translates to:
  /// **'Reifenwechsel'**
  String get raeder_wechsel;

  /// No description provided for @raeder_wechsel_title.
  ///
  /// In de, this message translates to:
  /// **'Reifenwechsel'**
  String get raeder_wechsel_title;

  /// No description provided for @raeder_wechsel_sommer.
  ///
  /// In de, this message translates to:
  /// **'Sommerreifenwechsel'**
  String get raeder_wechsel_sommer;

  /// No description provided for @raeder_wechsel_winter.
  ///
  /// In de, this message translates to:
  /// **'Winterreifenwechsel'**
  String get raeder_wechsel_winter;

  /// No description provided for @pick_slot.
  ///
  /// In de, this message translates to:
  /// **'Termin auswählen'**
  String get pick_slot;

  /// No description provided for @slot_taken.
  ///
  /// In de, this message translates to:
  /// **'Dieser Termin ist bereits belegt.'**
  String get slot_taken;

  /// No description provided for @slot_ok.
  ///
  /// In de, this message translates to:
  /// **'Termin gebucht!'**
  String get slot_ok;

  /// No description provided for @customer_name.
  ///
  /// In de, this message translates to:
  /// **'Name und Nachname'**
  String get customer_name;

  /// No description provided for @customer_phone.
  ///
  /// In de, this message translates to:
  /// **'Telefon'**
  String get customer_phone;

  /// No description provided for @customer_email.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get customer_email;

  /// No description provided for @enter_name.
  ///
  /// In de, this message translates to:
  /// **'Bitte Namen eingeben'**
  String get enter_name;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @yes.
  ///
  /// In de, this message translates to:
  /// **'Ja'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In de, this message translates to:
  /// **'Nein'**
  String get no;

  /// No description provided for @damage_type_title.
  ///
  /// In de, this message translates to:
  /// **'Um welchen Schaden handelt es sich?'**
  String get damage_type_title;

  /// No description provided for @damage_type_subtitle.
  ///
  /// In de, this message translates to:
  /// **'Wähle die Art des Schadens aus.'**
  String get damage_type_subtitle;

  /// No description provided for @damage_glass.
  ///
  /// In de, this message translates to:
  /// **'Glasschaden'**
  String get damage_glass;

  /// No description provided for @damage_hail.
  ///
  /// In de, this message translates to:
  /// **'Hagelschaden'**
  String get damage_hail;

  /// No description provided for @damage_marten.
  ///
  /// In de, this message translates to:
  /// **'Marderschaden'**
  String get damage_marten;

  /// No description provided for @damage_parking.
  ///
  /// In de, this message translates to:
  /// **'Parkschaden'**
  String get damage_parking;

  /// No description provided for @damage_comprehensive.
  ///
  /// In de, this message translates to:
  /// **'Vollkasko'**
  String get damage_comprehensive;

  /// No description provided for @license_plate_label.
  ///
  /// In de, this message translates to:
  /// **'Kennzeichen'**
  String get license_plate_label;

  /// No description provided for @license_plate_hint.
  ///
  /// In de, this message translates to:
  /// **'z.B. ZH 123456'**
  String get license_plate_hint;

  /// No description provided for @other_object_damage_q.
  ///
  /// In de, this message translates to:
  /// **'Gibt es Sachschäden an anderen Gegenständen?'**
  String get other_object_damage_q;

  /// No description provided for @other_vehicle_damage_q.
  ///
  /// In de, this message translates to:
  /// **'Gibt es Sachschäden an anderen Fahrzeugen?'**
  String get other_vehicle_damage_q;

  /// No description provided for @workshop_services_title.
  ///
  /// In de, this message translates to:
  /// **'Werkstatt-Services'**
  String get workshop_services_title;

  /// No description provided for @termin_buchen.
  ///
  /// In de, this message translates to:
  /// **'Termin buchen'**
  String get termin_buchen;

  /// No description provided for @quick_actions_title.
  ///
  /// In de, this message translates to:
  /// **'Schnellaktionen'**
  String get quick_actions_title;

  /// No description provided for @my_requests_title.
  ///
  /// In de, this message translates to:
  /// **'Meine Anfragen'**
  String get my_requests_title;

  /// No description provided for @tab_appointments.
  ///
  /// In de, this message translates to:
  /// **'Termine'**
  String get tab_appointments;

  /// No description provided for @tab_incidents.
  ///
  /// In de, this message translates to:
  /// **'Unfälle'**
  String get tab_incidents;

  /// No description provided for @empty_appointments.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Termine'**
  String get empty_appointments;

  /// No description provided for @my_requests_filter_all.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get my_requests_filter_all;

  /// No description provided for @my_requests_filter_service.
  ///
  /// In de, this message translates to:
  /// **'Service'**
  String get my_requests_filter_service;

  /// No description provided for @my_requests_filter_tires.
  ///
  /// In de, this message translates to:
  /// **'Reifenwechsel'**
  String get my_requests_filter_tires;

  /// No description provided for @my_requests_filter_damage.
  ///
  /// In de, this message translates to:
  /// **'Schaden'**
  String get my_requests_filter_damage;

  /// No description provided for @service_type_service.
  ///
  /// In de, this message translates to:
  /// **'Service anmelden'**
  String get service_type_service;

  /// No description provided for @service_type_tires.
  ///
  /// In de, this message translates to:
  /// **'Reifenwechsel'**
  String get service_type_tires;

  /// No description provided for @service_type_damage.
  ///
  /// In de, this message translates to:
  /// **'Schaden'**
  String get service_type_damage;

  /// No description provided for @damageTitle.
  ///
  /// In de, this message translates to:
  /// **'Beschädigung'**
  String get damageTitle;

  /// No description provided for @damageVehicleA.
  ///
  /// In de, this message translates to:
  /// **'Beschädigung des Fahrzeugs A'**
  String get damageVehicleA;

  /// No description provided for @damageVehicleB.
  ///
  /// In de, this message translates to:
  /// **'Beschädigung des Fahrzeugs B'**
  String get damageVehicleB;

  /// No description provided for @pdfDriverA.
  ///
  /// In de, this message translates to:
  /// **'Fahrer A'**
  String get pdfDriverA;

  /// No description provided for @pdfDriverB.
  ///
  /// In de, this message translates to:
  /// **'Fahrer B'**
  String get pdfDriverB;

  /// No description provided for @pdfLiabilityHeading.
  ///
  /// In de, this message translates to:
  /// **'Haftung (Angabe der Parteien):'**
  String get pdfLiabilityHeading;

  /// No description provided for @pdfLiabilityAccordingToParties.
  ///
  /// In de, this message translates to:
  /// **'Laut den Parteien ist der schuldige Fahrer {driver}.'**
  String pdfLiabilityAccordingToParties(Object driver);

  /// No description provided for @pdfDriverLabelA.
  ///
  /// In de, this message translates to:
  /// **'Fahrer A'**
  String get pdfDriverLabelA;

  /// No description provided for @pdfDriverLabelB.
  ///
  /// In de, this message translates to:
  /// **'Fahrer B'**
  String get pdfDriverLabelB;

  /// No description provided for @driverPersonalQrPageTitle.
  ///
  /// In de, this message translates to:
  /// **'Mein persönlicher QR'**
  String get driverPersonalQrPageTitle;

  /// No description provided for @driverPersonalQrIntroTitle.
  ///
  /// In de, this message translates to:
  /// **'Erstelle deinen Fahrer-QR'**
  String get driverPersonalQrIntroTitle;

  /// No description provided for @driverPersonalQrIntroBody.
  ///
  /// In de, this message translates to:
  /// **'Speichere Kunden-, Fahrzeug- und Versicherungsdaten in einem persönlichen QR, der in der Werkstatt bei Neue Akte sofort gescannt werden kann.'**
  String get driverPersonalQrIntroBody;

  /// No description provided for @driverPersonalQrLocalSaveNote.
  ///
  /// In de, this message translates to:
  /// **'Die Daten werden lokal auf diesem Gerät bzw. Browser gespeichert.'**
  String get driverPersonalQrLocalSaveNote;

  /// No description provided for @driverPersonalQrPrivacyNote.
  ///
  /// In de, this message translates to:
  /// **'Der QR enthält nur Kunden-, Fahrzeug- und Versicherungsdaten.'**
  String get driverPersonalQrPrivacyNote;

  /// No description provided for @driverPersonalQrStatusReady.
  ///
  /// In de, this message translates to:
  /// **'QR bereits bereit / Daten gespeichert'**
  String get driverPersonalQrStatusReady;

  /// No description provided for @driverPersonalQrStatusReadyMessage.
  ///
  /// In de, this message translates to:
  /// **'Der QR ist aktuell und kann direkt von der Werkstatt gescannt werden.'**
  String get driverPersonalQrStatusReadyMessage;

  /// No description provided for @driverPersonalQrStatusNeedsUpdate.
  ///
  /// In de, this message translates to:
  /// **'Daten geändert / QR aktualisieren'**
  String get driverPersonalQrStatusNeedsUpdate;

  /// No description provided for @driverPersonalQrStatusNeedsUpdateMessage.
  ///
  /// In de, this message translates to:
  /// **'Die gespeicherten Daten wurden geändert. Aktualisiere den QR, damit die neueste Version codiert wird.'**
  String get driverPersonalQrStatusNeedsUpdateMessage;

  /// No description provided for @driverPersonalQrStatusDraftSaved.
  ///
  /// In de, this message translates to:
  /// **'Daten lokal gespeichert'**
  String get driverPersonalQrStatusDraftSaved;

  /// No description provided for @driverPersonalQrStatusDraftSavedMessage.
  ///
  /// In de, this message translates to:
  /// **'Die Daten sind bereits auf diesem Gerät gespeichert. Erstelle den QR, sobald sie scanbar sein sollen.'**
  String get driverPersonalQrStatusDraftSavedMessage;

  /// No description provided for @driverPersonalQrStatusEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Daten gespeichert'**
  String get driverPersonalQrStatusEmpty;

  /// No description provided for @driverPersonalQrStatusEmptyMessage.
  ///
  /// In de, this message translates to:
  /// **'Erfasse Kunden-, Fahrzeug- und Versicherungsdaten, um deinen persönlichen QR vorzubereiten.'**
  String get driverPersonalQrStatusEmptyMessage;

  /// No description provided for @driverPersonalQrCustomerSectionTitle.
  ///
  /// In de, this message translates to:
  /// **'Kundendaten'**
  String get driverPersonalQrCustomerSectionTitle;

  /// No description provided for @driverPersonalQrCustomerSectionSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Erfasse die Kunden- oder Fahrerdaten, damit die Werkstatt sie sofort übernehmen kann.'**
  String get driverPersonalQrCustomerSectionSubtitle;

  /// No description provided for @driverPersonalQrProfileSourceNote.
  ///
  /// In de, this message translates to:
  /// **'Diese Daten werden automatisch aus deinem Kundenprofil übernommen.'**
  String get driverPersonalQrProfileSourceNote;

  /// No description provided for @driverPersonalQrProfileIncompleteMessage.
  ///
  /// In de, this message translates to:
  /// **'Dein Kundenprofil ist noch nicht vollständig. Ergänze die fehlenden Angaben, damit dein persönlicher QR alle Kundendaten enthält.'**
  String get driverPersonalQrProfileIncompleteMessage;

  /// No description provided for @driverPersonalQrProfileMissingFieldsLabel.
  ///
  /// In de, this message translates to:
  /// **'Fehlende Angaben'**
  String get driverPersonalQrProfileMissingFieldsLabel;

  /// No description provided for @driverPersonalQrVehicleSectionTitle.
  ///
  /// In de, this message translates to:
  /// **'Fahrzeugdaten'**
  String get driverPersonalQrVehicleSectionTitle;

  /// No description provided for @driverPersonalQrVehicleSectionSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Füge die wichtigsten Fahrzeugdaten hinzu, um die Akte schneller zu eröffnen.'**
  String get driverPersonalQrVehicleSectionSubtitle;

  /// No description provided for @driverPersonalQrInsuranceSectionTitle.
  ///
  /// In de, this message translates to:
  /// **'Versicherungsdaten'**
  String get driverPersonalQrInsuranceSectionTitle;

  /// No description provided for @driverPersonalQrInsuranceSectionSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Ergänze die relevanten Versicherungsangaben für die Schadenbearbeitung.'**
  String get driverPersonalQrInsuranceSectionSubtitle;

  /// No description provided for @driverPersonalQrFormActionCreate.
  ///
  /// In de, this message translates to:
  /// **'Persönlichen QR erstellen'**
  String get driverPersonalQrFormActionCreate;

  /// No description provided for @driverPersonalQrFormActionUpdate.
  ///
  /// In de, this message translates to:
  /// **'QR aktualisieren'**
  String get driverPersonalQrFormActionUpdate;

  /// No description provided for @driverPersonalQrEditSavedData.
  ///
  /// In de, this message translates to:
  /// **'Gespeicherte Daten bearbeiten'**
  String get driverPersonalQrEditSavedData;

  /// No description provided for @driverPersonalQrQrCardTitle.
  ///
  /// In de, this message translates to:
  /// **'Persönlicher Fahrer-QR'**
  String get driverPersonalQrQrCardTitle;

  /// No description provided for @driverPersonalQrQrCardSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Zeige diesen QR der Werkstatt, damit die verfügbaren Daten automatisch übernommen werden.'**
  String get driverPersonalQrQrCardSubtitle;

  /// No description provided for @driverPersonalQrQrEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'QR noch nicht erstellt'**
  String get driverPersonalQrQrEmptyTitle;

  /// No description provided for @driverPersonalQrTapToEnlarge.
  ///
  /// In de, this message translates to:
  /// **'Zum Vergrößern antippen'**
  String get driverPersonalQrTapToEnlarge;

  /// No description provided for @driverPersonalQrFullscreenHint.
  ///
  /// In de, this message translates to:
  /// **'Zeige diesen QR der Werkstatt'**
  String get driverPersonalQrFullscreenHint;

  /// No description provided for @driverPersonalQrCloseFullscreen.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get driverPersonalQrCloseFullscreen;

  /// No description provided for @driverPersonalQrMinimumHint.
  ///
  /// In de, this message translates to:
  /// **'Fülle mindestens Vorname, Nachname und Kennzeichen aus, um den QR zu erstellen.'**
  String get driverPersonalQrMinimumHint;

  /// No description provided for @driverPersonalQrCreateSuccess.
  ///
  /// In de, this message translates to:
  /// **'QR erfolgreich erstellt'**
  String get driverPersonalQrCreateSuccess;

  /// No description provided for @driverPersonalQrUpdateSuccess.
  ///
  /// In de, this message translates to:
  /// **'QR erfolgreich aktualisiert'**
  String get driverPersonalQrUpdateSuccess;

  /// No description provided for @driverPersonalQrSaveError.
  ///
  /// In de, this message translates to:
  /// **'Der persönliche QR konnte lokal nicht gespeichert werden.'**
  String get driverPersonalQrSaveError;

  /// No description provided for @driverPersonalQrDeleteProfileAction.
  ///
  /// In de, this message translates to:
  /// **'Profil löschen'**
  String get driverPersonalQrDeleteProfileAction;

  /// No description provided for @driverPersonalQrDeleteProfileTitle.
  ///
  /// In de, this message translates to:
  /// **'Profil löschen?'**
  String get driverPersonalQrDeleteProfileTitle;

  /// No description provided for @driverPersonalQrDeleteProfileMessage.
  ///
  /// In de, this message translates to:
  /// **'Die gespeicherten persönlichen Daten und der persönliche QR werden von diesem Gerät gelöscht.'**
  String get driverPersonalQrDeleteProfileMessage;

  /// No description provided for @driverPersonalQrDeleteProfileConfirm.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get driverPersonalQrDeleteProfileConfirm;

  /// No description provided for @driverPersonalQrDeleteProfileSuccess.
  ///
  /// In de, this message translates to:
  /// **'Persönliches Profil gelöscht'**
  String get driverPersonalQrDeleteProfileSuccess;

  /// No description provided for @driverPersonalQrDeleteProfileError.
  ///
  /// In de, this message translates to:
  /// **'Das persönliche Profil konnte nicht gelöscht werden.'**
  String get driverPersonalQrDeleteProfileError;

  /// No description provided for @personalVehiclesTitle.
  ///
  /// In de, this message translates to:
  /// **'Meine Fahrzeuge'**
  String get personalVehiclesTitle;

  /// No description provided for @personalVehicleAdd.
  ///
  /// In de, this message translates to:
  /// **'Fahrzeug hinzufügen'**
  String get personalVehicleAdd;

  /// No description provided for @personalVehicleEdit.
  ///
  /// In de, this message translates to:
  /// **'Fahrzeug bearbeiten'**
  String get personalVehicleEdit;

  /// No description provided for @personalVehicleSave.
  ///
  /// In de, this message translates to:
  /// **'Fahrzeug speichern'**
  String get personalVehicleSave;

  /// No description provided for @personalVehicleDelete.
  ///
  /// In de, this message translates to:
  /// **'Fahrzeug löschen'**
  String get personalVehicleDelete;

  /// No description provided for @personalVehicleDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Dieses Fahrzeug löschen?'**
  String get personalVehicleDeleteConfirm;

  /// No description provided for @personalVehicleDeleteMessage.
  ///
  /// In de, this message translates to:
  /// **'Das Fahrzeug wird dauerhaft aus deinem Kundenkonto entfernt.'**
  String get personalVehicleDeleteMessage;

  /// No description provided for @personalVehiclePrimary.
  ///
  /// In de, this message translates to:
  /// **'Hauptfahrzeug'**
  String get personalVehiclePrimary;

  /// No description provided for @personalVehicleSetPrimary.
  ///
  /// In de, this message translates to:
  /// **'Als Hauptfahrzeug festlegen'**
  String get personalVehicleSetPrimary;

  /// No description provided for @personalVehicleSelect.
  ///
  /// In de, this message translates to:
  /// **'Fahrzeug auswählen'**
  String get personalVehicleSelect;

  /// No description provided for @personalVehicleContinueWithSelection.
  ///
  /// In de, this message translates to:
  /// **'Mit diesem Fahrzeug fortfahren'**
  String get personalVehicleContinueWithSelection;

  /// No description provided for @personalVehiclesEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Fahrzeuge gespeichert'**
  String get personalVehiclesEmpty;

  /// No description provided for @personalVehicleSaved.
  ///
  /// In de, this message translates to:
  /// **'Fahrzeug gespeichert'**
  String get personalVehicleSaved;

  /// No description provided for @personalVehicleDeleted.
  ///
  /// In de, this message translates to:
  /// **'Fahrzeug gelöscht'**
  String get personalVehicleDeleted;

  /// No description provided for @personalVehiclePlateRequired.
  ///
  /// In de, this message translates to:
  /// **'Gib das Fahrzeugkennzeichen ein.'**
  String get personalVehiclePlateRequired;

  /// No description provided for @personalVehicleSaveError.
  ///
  /// In de, this message translates to:
  /// **'Das Fahrzeug konnte nicht gespeichert werden.'**
  String get personalVehicleSaveError;

  /// No description provided for @personalVehicleDeleteError.
  ///
  /// In de, this message translates to:
  /// **'Das Fahrzeug konnte nicht gelöscht werden.'**
  String get personalVehicleDeleteError;

  /// No description provided for @driverPersonalQrSavedDataPreviewTitle.
  ///
  /// In de, this message translates to:
  /// **'Vorschau der gespeicherten Daten'**
  String get driverPersonalQrSavedDataPreviewTitle;

  /// No description provided for @driverPersonalQrJsonPreviewTitle.
  ///
  /// In de, this message translates to:
  /// **'QR-Inhalt (JSON)'**
  String get driverPersonalQrJsonPreviewTitle;

  /// No description provided for @driverPersonalQrJsonPreviewHint.
  ///
  /// In de, this message translates to:
  /// **'Dies ist das lesbare JSON, das im QR codiert ist und vom Werkstatt-Scanner gelesen werden kann.'**
  String get driverPersonalQrJsonPreviewHint;

  /// No description provided for @driverPersonalQrTechnicalDetailsTitle.
  ///
  /// In de, this message translates to:
  /// **'Technische Details (JSON)'**
  String get driverPersonalQrTechnicalDetailsTitle;

  /// No description provided for @driverPersonalQrTechnicalDetailsDescription.
  ///
  /// In de, this message translates to:
  /// **'Technische Details, die vom Werkstatt-Scanner verwendet werden.\nNormalerweise müssen sie nicht angezeigt werden.'**
  String get driverPersonalQrTechnicalDetailsDescription;

  /// No description provided for @driverPersonalQrTitleLabel.
  ///
  /// In de, this message translates to:
  /// **'Anrede / Titel'**
  String get driverPersonalQrTitleLabel;

  /// No description provided for @driverPersonalQrStreetLabel.
  ///
  /// In de, this message translates to:
  /// **'Strasse'**
  String get driverPersonalQrStreetLabel;

  /// No description provided for @driverPersonalQrCountryLabel.
  ///
  /// In de, this message translates to:
  /// **'Land'**
  String get driverPersonalQrCountryLabel;

  /// No description provided for @driverPersonalQrBrandLabel.
  ///
  /// In de, this message translates to:
  /// **'Marke'**
  String get driverPersonalQrBrandLabel;

  /// No description provided for @driverPersonalQrModelLabel.
  ///
  /// In de, this message translates to:
  /// **'Modell / Typ'**
  String get driverPersonalQrModelLabel;

  /// No description provided for @driverPersonalQrVinLabel.
  ///
  /// In de, this message translates to:
  /// **'Fahrgestellnummer VIN'**
  String get driverPersonalQrVinLabel;

  /// No description provided for @driverPersonalQrMileageLabel.
  ///
  /// In de, this message translates to:
  /// **'Kilometerstand'**
  String get driverPersonalQrMileageLabel;

  /// No description provided for @driverPersonalQrFirstRegistrationLabel.
  ///
  /// In de, this message translates to:
  /// **'1. Inverkehrsetzung'**
  String get driverPersonalQrFirstRegistrationLabel;

  /// No description provided for @driverPersonalQrInsuranceLabel.
  ///
  /// In de, this message translates to:
  /// **'Versicherung'**
  String get driverPersonalQrInsuranceLabel;

  /// No description provided for @driverPersonalQrPolicyNumberLabel.
  ///
  /// In de, this message translates to:
  /// **'Policennummer'**
  String get driverPersonalQrPolicyNumberLabel;

  /// No description provided for @driverPersonalQrClaimNumberLabel.
  ///
  /// In de, this message translates to:
  /// **'Schadennummer'**
  String get driverPersonalQrClaimNumberLabel;

  /// No description provided for @driverPersonalQrLocationLabel.
  ///
  /// In de, this message translates to:
  /// **'PLZ / Ort / Land'**
  String get driverPersonalQrLocationLabel;

  /// No description provided for @driverPersonalQrTitleMr.
  ///
  /// In de, this message translates to:
  /// **'Herr'**
  String get driverPersonalQrTitleMr;

  /// No description provided for @driverPersonalQrTitleMrs.
  ///
  /// In de, this message translates to:
  /// **'Frau'**
  String get driverPersonalQrTitleMrs;

  /// No description provided for @driverPersonalQrTitleCompany.
  ///
  /// In de, this message translates to:
  /// **'Firma'**
  String get driverPersonalQrTitleCompany;

  /// No description provided for @driverPersonalQrUseAsCustomerDriver.
  ///
  /// In de, this message translates to:
  /// **'Als Kunde/Fahrer verwenden'**
  String get driverPersonalQrUseAsCustomerDriver;

  /// No description provided for @driverPersonalQrUseAsWitness.
  ///
  /// In de, this message translates to:
  /// **'Als Zeuge verwenden'**
  String get driverPersonalQrUseAsWitness;

  /// No description provided for @driverPersonalQrUseAsInjured.
  ///
  /// In de, this message translates to:
  /// **'Als verletzte Person verwenden'**
  String get driverPersonalQrUseAsInjured;

  /// No description provided for @preferredWorkshopTitle.
  ///
  /// In de, this message translates to:
  /// **'Bevorzugte Werkstatt'**
  String get preferredWorkshopTitle;

  /// No description provided for @preferredWorkshopNone.
  ///
  /// In de, this message translates to:
  /// **'Keine bevorzugte Werkstatt ausgewählt.'**
  String get preferredWorkshopNone;

  /// No description provided for @preferredWorkshopChoose.
  ///
  /// In de, this message translates to:
  /// **'Werkstatt auswählen'**
  String get preferredWorkshopChoose;

  /// No description provided for @preferredWorkshopEdit.
  ///
  /// In de, this message translates to:
  /// **'Werkstatt ändern'**
  String get preferredWorkshopEdit;

  /// No description provided for @preferredWorkshopRemove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get preferredWorkshopRemove;

  /// No description provided for @preferredWorkshopYours.
  ///
  /// In de, this message translates to:
  /// **'Deine bevorzugte Werkstatt'**
  String get preferredWorkshopYours;

  /// No description provided for @preferredWorkshopUse.
  ///
  /// In de, this message translates to:
  /// **'Diese Werkstatt verwenden'**
  String get preferredWorkshopUse;

  /// No description provided for @preferredWorkshopSaved.
  ///
  /// In de, this message translates to:
  /// **'Bevorzugte Werkstatt gespeichert.'**
  String get preferredWorkshopSaved;

  /// No description provided for @preferredWorkshopRemoved.
  ///
  /// In de, this message translates to:
  /// **'Bevorzugte Werkstatt entfernt.'**
  String get preferredWorkshopRemoved;

  /// No description provided for @preferredWorkshopLoadError.
  ///
  /// In de, this message translates to:
  /// **'Die bevorzugte Werkstatt konnte nicht geladen werden.'**
  String get preferredWorkshopLoadError;

  /// No description provided for @preferredWorkshopSaveError.
  ///
  /// In de, this message translates to:
  /// **'Die bevorzugte Werkstatt konnte nicht gespeichert werden.'**
  String get preferredWorkshopSaveError;

  /// No description provided for @preferredWorkshopOpen.
  ///
  /// In de, this message translates to:
  /// **'Geöffnet'**
  String get preferredWorkshopOpen;

  /// No description provided for @preferredWorkshopClosed.
  ///
  /// In de, this message translates to:
  /// **'Geschlossen'**
  String get preferredWorkshopClosed;

  /// No description provided for @preferredWorkshopStatusUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Status nicht verfügbar'**
  String get preferredWorkshopStatusUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
