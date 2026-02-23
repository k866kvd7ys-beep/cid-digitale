// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'CID Digitale';

  @override
  String get faultLiabilityHintA => 'Secondo voi è colpevole il conducente A.';

  @override
  String get faultLiabilityHintB => 'Secondo voi è colpevole il conducente B.';

  @override
  String get integrityNotVerifiedWarning =>
      'Attenzione: integrità non verificata (dati o allegati potrebbero essere cambiati).';

  @override
  String get labelDateTime => 'Data e ora:';

  @override
  String get labelPlace => 'Luogo:';

  @override
  String get labelDriverA => 'Conducente A';

  @override
  String get labelDriverB => 'Conducente B';

  @override
  String get labelDriverAText => 'Conducente A (testo):';

  @override
  String get labelDriverBText => 'Conducente B (testo):';

  @override
  String get labelDriverAVoice => 'Sprachnotiz Conducente A';

  @override
  String get labelDriverBVoice => 'Sprachnotiz Conducente B';

  @override
  String get labelDriverAColon => 'Conducente A:';

  @override
  String get labelDriverBColon => 'Conducente B:';

  @override
  String get driverA => 'Conducente A';

  @override
  String get driverB => 'Conducente B';

  @override
  String get firstName => 'Nome';

  @override
  String get lastName => 'Cognome';

  @override
  String get damageTitle => 'Danni';

  @override
  String get damageVehicleA => 'Danni del veicolo A';

  @override
  String get damageVehicleB => 'Danni del veicolo B';

  @override
  String get pdfDriverA => 'Conducente A';

  @override
  String get pdfDriverB => 'Conducente B';

  @override
  String get pdfLiabilityHeading => 'Responsabilità (Angabe der Parteien):';

  @override
  String pdfLiabilityAccordingToParties(Object driver) {
    return 'Secondo le parti il conducente ritenuto colpevole è $driver.';
  }

  @override
  String get pdfDriverLabelA => 'Conducente A';

  @override
  String get pdfDriverLabelB => 'Conducente B';
}
