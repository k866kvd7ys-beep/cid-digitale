import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleService {
  AppLocaleService({SharedPreferences? preferences})
      : _preferences = preferences;

  static const supportedLanguageCodes = <String>['it', 'de', 'fr', 'en'];
  static const selectedLocaleKey = 'selected_locale';
  static const legacyLocaleKey = 'lang_preference';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _preferencesInstance() async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<Locale> load() async {
    final preferences = await _preferencesInstance();
    final saved = preferences.getString(selectedLocaleKey) ??
        preferences.getString(legacyLocaleKey);
    if (saved != null && supportedLanguageCodes.contains(saved)) {
      return Locale(saved);
    }

    final systemCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (supportedLanguageCodes.contains(systemCode)) {
      return Locale(systemCode);
    }
    return const Locale('de');
  }

  Future<void> save(String languageCode) async {
    if (!supportedLanguageCodes.contains(languageCode)) {
      throw ArgumentError.value(
        languageCode,
        'languageCode',
        'Unsupported application locale',
      );
    }
    final preferences = await _preferencesInstance();
    await Future.wait([
      preferences.setString(selectedLocaleKey, languageCode),
      preferences.setString(legacyLocaleKey, languageCode),
    ]);
  }
}
