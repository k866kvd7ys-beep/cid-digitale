import 'package:cid_digitale/services/app_locale_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocaleTestValue();
  });

  test('selected locale survives a new service instance', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = AppLocaleService(preferences: preferences);

    await service.save('fr');

    final reloaded = AppLocaleService(
      preferences: await SharedPreferences.getInstance(),
    );
    expect(await reloaded.load(), const Locale('fr'));
    expect(
      preferences.getString(AppLocaleService.selectedLocaleKey),
      'fr',
    );
  });

  test('legacy locale remains compatible', () async {
    SharedPreferences.setMockInitialValues({
      AppLocaleService.legacyLocaleKey: 'en',
    });
    final service = AppLocaleService(
      preferences: await SharedPreferences.getInstance(),
    );

    expect(await service.load(), const Locale('en'));
  });
}
