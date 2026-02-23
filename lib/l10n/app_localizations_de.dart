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
