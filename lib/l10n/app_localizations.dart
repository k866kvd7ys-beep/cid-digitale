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
  /// **'Räder wechsel'**
  String get raeder_wechsel;

  /// No description provided for @raeder_wechsel_title.
  ///
  /// In de, this message translates to:
  /// **'Räder wechsel'**
  String get raeder_wechsel_title;

  /// No description provided for @raeder_wechsel_sommer.
  ///
  /// In de, this message translates to:
  /// **'Räder wechsel Sommer'**
  String get raeder_wechsel_sommer;

  /// No description provided for @raeder_wechsel_winter.
  ///
  /// In de, this message translates to:
  /// **'Räder wechsel Winter'**
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
