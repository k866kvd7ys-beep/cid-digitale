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
  String get raeder_wechsel => 'Räder wechsel';

  @override
  String get raeder_wechsel_title => 'Räder wechsel';

  @override
  String get raeder_wechsel_sommer => 'Räder wechsel Sommer';

  @override
  String get raeder_wechsel_winter => 'Räder wechsel Winter';

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
  String get my_requests_filter_tires => 'Räder wechsel';

  @override
  String get my_requests_filter_damage => 'Schaden';

  @override
  String get service_type_service => 'Service anmelden';

  @override
  String get service_type_tires => 'Räder wechsel';

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
}
