// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CID Digitale';

  @override
  String get faultLiabilityHintA => 'In your opinion, driver A is at fault.';

  @override
  String get faultLiabilityHintB => 'In your opinion, driver B is at fault.';

  @override
  String get integrityNotVerifiedWarning =>
      'Warning: integrity not verified (data or attachments may have been changed).';

  @override
  String get labelDateTime => 'Date and time:';

  @override
  String get labelPlace => 'Place:';

  @override
  String get labelDriverA => 'Driver A';

  @override
  String get labelDriverB => 'Driver B';

  @override
  String get labelDriverAText => 'Driver A (text):';

  @override
  String get labelDriverBText => 'Driver B (text):';

  @override
  String get labelDriverAVoice => 'Driver A voice note';

  @override
  String get labelDriverBVoice => 'Driver B voice note';

  @override
  String get labelDriverAColon => 'Driver A:';

  @override
  String get labelDriverBColon => 'Driver B:';

  @override
  String get pdfDriverA => 'Driver A';

  @override
  String get pdfDriverB => 'Driver B';

  @override
  String get pdfLiabilityHeading => 'Liability (as stated by the parties):';

  @override
  String pdfLiabilityAccordingToParties(Object driver) {
    return 'According to the parties, the liable driver is $driver.';
  }

  @override
  String get pdfDriverLabelA => 'Driver A';

  @override
  String get pdfDriverLabelB => 'Driver B';
}
