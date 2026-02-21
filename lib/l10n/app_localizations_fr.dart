// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'CID Digitale';

  @override
  String get faultLiabilityHintA =>
      'Selon vous, le conducteur A est responsable.';

  @override
  String get faultLiabilityHintB =>
      'Selon vous, le conducteur B est responsable.';

  @override
  String get integrityNotVerifiedWarning =>
      'Attention : intégrité non vérifiée (données ou pièces jointes peuvent avoir été modifiées).';

  @override
  String get labelDateTime => 'Date et heure :';

  @override
  String get labelPlace => 'Lieu :';

  @override
  String get labelDriverA => 'Conducteur A';

  @override
  String get labelDriverB => 'Conducteur B';

  @override
  String get labelDriverAText => 'Conducteur A (texte) :';

  @override
  String get labelDriverBText => 'Conducteur B (texte) :';

  @override
  String get labelDriverAVoice => 'Note vocale conducteur A';

  @override
  String get labelDriverBVoice => 'Note vocale conducteur B';

  @override
  String get labelDriverAColon => 'Conducteur A :';

  @override
  String get labelDriverBColon => 'Conducteur B :';

  @override
  String get pdfDriverA => 'Conducteur A';

  @override
  String get pdfDriverB => 'Conducteur B';

  @override
  String get pdfLiabilityHeading =>
      'Responsabilité (déclarée par les parties) :';

  @override
  String pdfLiabilityAccordingToParties(Object driver) {
    return 'Selon les parties, le conducteur responsable est $driver.';
  }

  @override
  String get pdfDriverLabelA => 'Conducteur A';

  @override
  String get pdfDriverLabelB => 'Conducteur B';
}
