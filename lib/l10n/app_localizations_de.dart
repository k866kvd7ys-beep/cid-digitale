// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'CID Digitale';

  @override
  String get faultLiabilityHintA => 'Eurer Meinung nach ist Fahrer A schuld.';

  @override
  String get faultLiabilityHintB => 'Eurer Meinung nach ist Fahrer B schuld.';

  @override
  String get integrityNotVerifiedWarning =>
      'Achtung: Integrität nicht verifiziert (Daten oder Anhänge könnten geändert worden sein).';

  @override
  String get labelDateTime => 'Datum und Uhrzeit:';

  @override
  String get labelPlace => 'Ort:';

  @override
  String get labelDriverA => 'Fahrer A';

  @override
  String get labelDriverB => 'Fahrer B';

  @override
  String get labelDriverAText => 'Fahrer A (Text):';

  @override
  String get labelDriverBText => 'Fahrer B (Text):';

  @override
  String get labelDriverAVoice => 'Sprachnotiz Fahrer A';

  @override
  String get labelDriverBVoice => 'Sprachnotiz Fahrer B';

  @override
  String get labelDriverAColon => 'Fahrer A:';

  @override
  String get labelDriverBColon => 'Fahrer B:';

  @override
  String get driverA => 'Fahrer A';

  @override
  String get driverB => 'Fahrer B';

  @override
  String get firstName => 'Vorname';

  @override
  String get lastName => 'Nachname';

  @override
  String get zip => 'PLZ';

  @override
  String get city => 'Ort';

  @override
  String get service_anmelden => 'Service anmelden';

  @override
  String get raeder_wechsel => 'Reifenwechsel';

  @override
  String get raeder_wechsel_title => 'Reifenwechsel';

  @override
  String get raeder_wechsel_sommer => 'Sommerreifenwechsel';

  @override
  String get raeder_wechsel_winter => 'Winterreifenwechsel';

  @override
  String get pick_slot => 'Termin auswählen';

  @override
  String get slot_taken => 'Dieser Termin ist bereits belegt.';

  @override
  String get slot_ok => 'Termin gebucht!';

  @override
  String get customer_name => 'Name und Nachname';

  @override
  String get customer_phone => 'Telefon';

  @override
  String get customer_email => 'E-Mail';

  @override
  String get enter_name => 'Bitte Namen eingeben';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get damage_type_title => 'Um welchen Schaden handelt es sich?';

  @override
  String get damage_type_subtitle => 'Wähle die Art des Schadens aus.';

  @override
  String get damage_glass => 'Glasschaden';

  @override
  String get damage_hail => 'Hagelschaden';

  @override
  String get damage_marten => 'Marderschaden';

  @override
  String get damage_parking => 'Parkschaden';

  @override
  String get damage_comprehensive => 'Vollkasko';

  @override
  String get license_plate_label => 'Kennzeichen';

  @override
  String get license_plate_hint => 'z.B. ZH 123456';

  @override
  String get other_object_damage_q =>
      'Gibt es Sachschäden an anderen Gegenständen?';

  @override
  String get other_vehicle_damage_q =>
      'Gibt es Sachschäden an anderen Fahrzeugen?';

  @override
  String get workshop_services_title => 'Werkstatt-Services';

  @override
  String get termin_buchen => 'Termin buchen';

  @override
  String get quick_actions_title => 'Schnellaktionen';

  @override
  String get my_requests_title => 'Meine Anfragen';

  @override
  String get tab_appointments => 'Termine';

  @override
  String get tab_incidents => 'Unfälle';

  @override
  String get empty_appointments => 'Noch keine Termine';

  @override
  String get my_requests_filter_all => 'Alle';

  @override
  String get my_requests_filter_service => 'Service';

  @override
  String get my_requests_filter_tires => 'Reifenwechsel';

  @override
  String get my_requests_filter_damage => 'Schaden';

  @override
  String get service_type_service => 'Service anmelden';

  @override
  String get service_type_tires => 'Reifenwechsel';

  @override
  String get service_type_damage => 'Schaden';

  @override
  String get damageTitle => 'Beschädigung';

  @override
  String get damageVehicleA => 'Beschädigung des Fahrzeugs A';

  @override
  String get damageVehicleB => 'Beschädigung des Fahrzeugs B';

  @override
  String get pdfDriverA => 'Fahrer A';

  @override
  String get pdfDriverB => 'Fahrer B';

  @override
  String get pdfLiabilityHeading => 'Haftung (Angabe der Parteien):';

  @override
  String pdfLiabilityAccordingToParties(Object driver) {
    return 'Laut den Parteien ist der schuldige Fahrer $driver.';
  }

  @override
  String get pdfDriverLabelA => 'Fahrer A';

  @override
  String get pdfDriverLabelB => 'Fahrer B';

  @override
  String get driverPersonalQrPageTitle => 'Mein persönlicher QR';

  @override
  String get driverPersonalQrIntroTitle => 'Erstelle deinen Fahrer-QR';

  @override
  String get driverPersonalQrIntroBody =>
      'Speichere Kunden-, Fahrzeug- und Versicherungsdaten in einem persönlichen QR, der in der Werkstatt bei Neue Akte sofort gescannt werden kann.';

  @override
  String get driverPersonalQrLocalSaveNote =>
      'Die Daten werden lokal auf diesem Gerät bzw. Browser gespeichert.';

  @override
  String get driverPersonalQrPrivacyNote =>
      'Der QR enthält nur Kunden-, Fahrzeug- und Versicherungsdaten.';

  @override
  String get driverPersonalQrStatusReady =>
      'QR bereits bereit / Daten gespeichert';

  @override
  String get driverPersonalQrStatusReadyMessage =>
      'Der QR ist aktuell und kann direkt von der Werkstatt gescannt werden.';

  @override
  String get driverPersonalQrStatusNeedsUpdate =>
      'Daten geändert / QR aktualisieren';

  @override
  String get driverPersonalQrStatusNeedsUpdateMessage =>
      'Die gespeicherten Daten wurden geändert. Aktualisiere den QR, damit die neueste Version codiert wird.';

  @override
  String get driverPersonalQrStatusDraftSaved => 'Daten lokal gespeichert';

  @override
  String get driverPersonalQrStatusDraftSavedMessage =>
      'Die Daten sind bereits auf diesem Gerät gespeichert. Erstelle den QR, sobald sie scanbar sein sollen.';

  @override
  String get driverPersonalQrStatusEmpty => 'Noch keine Daten gespeichert';

  @override
  String get driverPersonalQrStatusEmptyMessage =>
      'Erfasse Kunden-, Fahrzeug- und Versicherungsdaten, um deinen persönlichen QR vorzubereiten.';

  @override
  String get driverPersonalQrCustomerSectionTitle => 'Kundendaten';

  @override
  String get driverPersonalQrCustomerSectionSubtitle =>
      'Erfasse die Kunden- oder Fahrerdaten, damit die Werkstatt sie sofort übernehmen kann.';

  @override
  String get driverPersonalQrVehicleSectionTitle => 'Fahrzeugdaten';

  @override
  String get driverPersonalQrVehicleSectionSubtitle =>
      'Füge die wichtigsten Fahrzeugdaten hinzu, um die Akte schneller zu eröffnen.';

  @override
  String get driverPersonalQrInsuranceSectionTitle => 'Versicherungsdaten';

  @override
  String get driverPersonalQrInsuranceSectionSubtitle =>
      'Ergänze die relevanten Versicherungsangaben für die Schadenbearbeitung.';

  @override
  String get driverPersonalQrFormActionCreate => 'Persönlichen QR erstellen';

  @override
  String get driverPersonalQrFormActionUpdate => 'QR aktualisieren';

  @override
  String get driverPersonalQrEditSavedData => 'Gespeicherte Daten bearbeiten';

  @override
  String get driverPersonalQrQrCardTitle => 'Persönlicher Fahrer-QR';

  @override
  String get driverPersonalQrQrCardSubtitle =>
      'Zeige diesen QR der Werkstatt, damit die verfügbaren Daten automatisch übernommen werden.';

  @override
  String get driverPersonalQrQrEmptyTitle => 'QR noch nicht erstellt';

  @override
  String get driverPersonalQrTapToEnlarge => 'Zum Vergrößern antippen';

  @override
  String get driverPersonalQrFullscreenHint => 'Zeige diesen QR der Werkstatt';

  @override
  String get driverPersonalQrCloseFullscreen => 'Schließen';

  @override
  String get driverPersonalQrMinimumHint =>
      'Fülle mindestens Vorname, Nachname und Kennzeichen aus, um den QR zu erstellen.';

  @override
  String get driverPersonalQrCreateSuccess => 'QR erfolgreich erstellt';

  @override
  String get driverPersonalQrUpdateSuccess => 'QR erfolgreich aktualisiert';

  @override
  String get driverPersonalQrSaveError =>
      'Der persönliche QR konnte lokal nicht gespeichert werden.';

  @override
  String get driverPersonalQrDeleteProfileAction => 'Profil löschen';

  @override
  String get driverPersonalQrDeleteProfileTitle => 'Profil löschen?';

  @override
  String get driverPersonalQrDeleteProfileMessage =>
      'Die gespeicherten persönlichen Daten und der persönliche QR werden von diesem Gerät gelöscht.';

  @override
  String get driverPersonalQrDeleteProfileConfirm => 'Löschen';

  @override
  String get driverPersonalQrDeleteProfileSuccess =>
      'Persönliches Profil gelöscht';

  @override
  String get driverPersonalQrDeleteProfileError =>
      'Das persönliche Profil konnte nicht gelöscht werden.';

  @override
  String get personalVehiclesTitle => 'Meine Fahrzeuge';

  @override
  String get personalVehicleAdd => 'Fahrzeug hinzufügen';

  @override
  String get personalVehicleEdit => 'Fahrzeug bearbeiten';

  @override
  String get personalVehicleSave => 'Fahrzeug speichern';

  @override
  String get personalVehicleDelete => 'Fahrzeug löschen';

  @override
  String get personalVehicleDeleteConfirm => 'Dieses Fahrzeug löschen?';

  @override
  String get personalVehicleDeleteMessage =>
      'Das Fahrzeug wird aus den auf diesem Gerät gespeicherten Daten entfernt.';

  @override
  String get personalVehiclePrimary => 'Hauptfahrzeug';

  @override
  String get personalVehicleSetPrimary => 'Als Hauptfahrzeug festlegen';

  @override
  String get personalVehicleSelect => 'Fahrzeug auswählen';

  @override
  String get personalVehicleContinueWithSelection =>
      'Mit diesem Fahrzeug fortfahren';

  @override
  String get personalVehiclesEmpty => 'Keine Fahrzeuge gespeichert';

  @override
  String get personalVehicleSaved => 'Fahrzeug gespeichert';

  @override
  String get personalVehicleDeleted => 'Fahrzeug gelöscht';

  @override
  String get personalVehiclePlateRequired => 'Gib das Fahrzeugkennzeichen ein.';

  @override
  String get personalVehicleSaveError =>
      'Das Fahrzeug konnte nicht gespeichert werden.';

  @override
  String get personalVehicleDeleteError =>
      'Das Fahrzeug konnte nicht gelöscht werden.';

  @override
  String get driverPersonalQrSavedDataPreviewTitle =>
      'Vorschau der gespeicherten Daten';

  @override
  String get driverPersonalQrJsonPreviewTitle => 'QR-Inhalt (JSON)';

  @override
  String get driverPersonalQrJsonPreviewHint =>
      'Dies ist das lesbare JSON, das im QR codiert ist und vom Werkstatt-Scanner gelesen werden kann.';

  @override
  String get driverPersonalQrTechnicalDetailsTitle =>
      'Technische Details (JSON)';

  @override
  String get driverPersonalQrTechnicalDetailsDescription =>
      'Technische Details, die vom Werkstatt-Scanner verwendet werden.\nNormalerweise müssen sie nicht angezeigt werden.';

  @override
  String get driverPersonalQrTitleLabel => 'Anrede / Titel';

  @override
  String get driverPersonalQrStreetLabel => 'Strasse';

  @override
  String get driverPersonalQrCountryLabel => 'Land';

  @override
  String get driverPersonalQrBrandLabel => 'Marke';

  @override
  String get driverPersonalQrModelLabel => 'Modell / Typ';

  @override
  String get driverPersonalQrVinLabel => 'Fahrgestellnummer VIN';

  @override
  String get driverPersonalQrMileageLabel => 'Kilometerstand';

  @override
  String get driverPersonalQrFirstRegistrationLabel => '1. Inverkehrsetzung';

  @override
  String get driverPersonalQrInsuranceLabel => 'Versicherung';

  @override
  String get driverPersonalQrPolicyNumberLabel => 'Policennummer';

  @override
  String get driverPersonalQrClaimNumberLabel => 'Schadennummer';

  @override
  String get driverPersonalQrLocationLabel => 'PLZ / Ort / Land';

  @override
  String get driverPersonalQrTitleMr => 'Herr';

  @override
  String get driverPersonalQrTitleMrs => 'Frau';

  @override
  String get driverPersonalQrTitleCompany => 'Firma';

  @override
  String get driverPersonalQrUseAsCustomerDriver =>
      'Als Kunde/Fahrer verwenden';

  @override
  String get driverPersonalQrUseAsWitness => 'Als Zeuge verwenden';

  @override
  String get driverPersonalQrUseAsInjured => 'Als verletzte Person verwenden';
}
