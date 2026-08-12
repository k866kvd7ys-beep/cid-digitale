import 'dart:async';
import 'dart:convert';

import 'package:cid_digitale/main.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fake_customer_auth_service.dart';

const _towNumber = '+41 91 111 11 11';
const _workshopNumber = '+41 91 222 22 22';
const _workshopEmail = 'werkstatt@example.ch';

const _accountA = CustomerAccount(
  id: 'customer-a',
  email: 'customer-a@example.ch',
  role: customerRole,
);
const _accountB = CustomerAccount(
  id: 'customer-b',
  email: 'customer-b@example.ch',
  role: customerRole,
);

OfficinaConfig _config({
  String tow = _towNumber,
  String workshop = _workshopNumber,
  String email = _workshopEmail,
}) {
  return OfficinaConfig(
    carroNumero: tow,
    concessionariaNumero: workshop,
    concessionariaEmail: email,
  );
}

OfficinaConfig _copy(OfficinaConfig value) => OfficinaConfig.fromJson(
      Map<String, dynamic>.from(value.toJson()),
    );

class _FakeOfficinaConfigRepository implements OfficinaConfigRepository {
  _FakeOfficinaConfigRepository({Map<String, OfficinaConfig>? initialValues})
      : values = {
          for (final entry in (initialValues ?? {}).entries)
            entry.key: _copy(entry.value),
        };

  final Map<String, OfficinaConfig> values;
  final List<String> loadedUserIds = [];
  final List<String> savedUserIds = [];
  Object? loadError;
  Object? saveError;
  Completer<void>? loadGate;
  Completer<void>? saveGate;

  int get saveCount => savedUserIds.length;

  @override
  Future<OfficinaConfig> loadForUser(String userId) async {
    loadedUserIds.add(userId);
    if (loadGate case final gate?) await gate.future;
    if (loadError case final error?) throw error;
    return _copy(values[userId] ?? OfficinaConfig.empty());
  }

  @override
  Future<void> saveForUser(String userId, OfficinaConfig config) async {
    savedUserIds.add(userId);
    if (saveGate case final gate?) await gate.future;
    if (saveError case final error?) throw error;
    values[userId] = _copy(config);
  }
}

Widget _app({
  required CustomerAuthService authService,
  required OfficinaConfigRepository repository,
  Locale locale = const Locale('de'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [
      Locale('it'),
      Locale('de'),
      Locale('fr'),
      Locale('en'),
    ],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: ImpostazioniOfficinaPage(
      authService: authService,
      repository: repository,
    ),
  );
}

Finder _field(String key) => find.byKey(Key(key));

String _fieldText(WidgetTester tester, String key) {
  return tester.widget<TextFormField>(_field(key)).controller?.text ?? '';
}

Future<void> _enterSettings(
  WidgetTester tester, {
  required String tow,
  required String workshop,
  required String email,
}) async {
  await tester.enterText(_field('workshop_settings_tow_number'), tow);
  await tester.enterText(
    _field('workshop_settings_dealer_number'),
    workshop,
  );
  await tester.enterText(_field('workshop_settings_dealer_email'), email);
}

Future<void> _tapSave(WidgetTester tester) async {
  final button = _field('workshop_settings_save');
  await tester.ensureVisible(button);
  await tester.tap(button);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCustomerAuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configOfficina = OfficinaConfig.empty();
    authService = FakeCustomerAuthService(account: _accountA);
  });

  tearDown(() async {
    await authService.dispose();
  });

  test('page uses the server-authoritative repository by default', () {
    final page = ImpostazioniOfficinaPage(authService: authService);
    expect(page.repository, isA<SupabaseOfficinaConfigRepository>());
  });

  testWidgets('shows loading while reading the authenticated user settings',
      (tester) async {
    final gate = Completer<void>();
    final repository = _FakeOfficinaConfigRepository()..loadGate = gate;

    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pump();

    expect(repository.loadedUserIds, [_accountA.id]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Werkstatteinstellungen werden geladen…'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('autofills all three controllers from saved settings',
      (tester) async {
    final repository = _FakeOfficinaConfigRepository(
      initialValues: {_accountA.id: _config()},
    );

    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'workshop_settings_tow_number'), _towNumber);
    expect(
      _fieldText(tester, 'workshop_settings_dealer_number'),
      _workshopNumber,
    );
    expect(
      _fieldText(tester, 'workshop_settings_dealer_email'),
      _workshopEmail,
    );
    expect(find.text('Kalender'), findsNothing);
  });

  testWidgets('trims and saves all three values after the write completes',
      (tester) async {
    final repository = _FakeOfficinaConfigRepository();
    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();

    await _enterSettings(
      tester,
      tow: '  +41 91 333 33 33  ',
      workshop: '  +41 (0)91 444-44-44  ',
      email: '  neu@example.ch  ',
    );
    await _tapSave(tester);
    await tester.pumpAndSettle();

    final saved = repository.values[_accountA.id]!;
    expect(saved.carroNumero, '+41 91 333 33 33');
    expect(saved.concessionariaNumero, '+41 (0)91 444-44-44');
    expect(saved.concessionariaEmail, 'neu@example.ch');
    expect(find.text('Werkstatteinstellungen gespeichert.'), findsOneWidget);
    expect(
        _fieldText(tester, 'workshop_settings_tow_number'), saved.carroNumero);
  });

  testWidgets('keeps values after the page is reconstructed', (tester) async {
    const repository = SharedPreferencesOfficinaConfigRepository();

    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();
    await _enterSettings(
      tester,
      tow: _towNumber,
      workshop: _workshopNumber,
      email: _workshopEmail,
    );
    await _tapSave(tester);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(
        authService: authService,
        repository: const SharedPreferencesOfficinaConfigRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'workshop_settings_tow_number'), _towNumber);
    expect(
      _fieldText(tester, 'workshop_settings_dealer_number'),
      _workshopNumber,
    );
    expect(
      _fieldText(tester, 'workshop_settings_dealer_email'),
      _workshopEmail,
    );
  });

  testWidgets('accepts and persists three empty optional fields',
      (tester) async {
    final repository = _FakeOfficinaConfigRepository(
      initialValues: {_accountA.id: _config()},
    );
    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();

    await _enterSettings(tester, tow: '', workshop: '', email: '');
    await _tapSave(tester);
    await tester.pumpAndSettle();

    final saved = repository.values[_accountA.id]!;
    expect(saved.carroNumero, isEmpty);
    expect(saved.concessionariaNumero, isEmpty);
    expect(saved.concessionariaEmail, isEmpty);
  });

  testWidgets('rejects an invalid optional email without writing',
      (tester) async {
    final repository = _FakeOfficinaConfigRepository();
    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();

    await _enterSettings(
      tester,
      tow: '',
      workshop: '',
      email: 'keine-gueltige-email',
    );
    await _tapSave(tester);
    await tester.pump();

    expect(find.text('Ungültige E-Mail'), findsOneWidget);
    expect(repository.saveCount, 0);
  });

  testWidgets('accepts international telephone symbols', (tester) async {
    final repository = _FakeOfficinaConfigRepository();
    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();

    await _enterSettings(
      tester,
      tow: '+41 (0)91 123-45-67',
      workshop: '+39 02 1234 5678',
      email: '',
    );
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.saveCount, 1);
    expect(
      repository.values[_accountA.id]!.carroNumero,
      '+41 (0)91 123-45-67',
    );
  });

  testWidgets('handles load errors without crashing and offers retry',
      (tester) async {
    final repository = _FakeOfficinaConfigRepository()
      ..loadError = StateError('load failed');

    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Die Werkstatteinstellungen konnten nicht geladen werden. Bitte erneut versuchen.',
      ),
      findsOneWidget,
    );
    expect(find.text('Erneut versuchen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new page states are localized in all four supported languages',
      (tester) async {
    const localizedStates = <String, List<String>>{
      'it': [
        'Caricamento impostazioni officina…',
        'Impossibile caricare le impostazioni officina. Riprova.',
        'Impostazioni officina salvate.',
        'Impossibile salvare le impostazioni officina. Riprova.',
      ],
      'de': [
        'Werkstatteinstellungen werden geladen…',
        'Die Werkstatteinstellungen konnten nicht geladen werden. Bitte erneut versuchen.',
        'Werkstatteinstellungen gespeichert.',
        'Die Werkstatteinstellungen konnten nicht gespeichert werden. Bitte erneut versuchen.',
      ],
      'fr': [
        'Chargement des réglages du garage…',
        'Impossible de charger les réglages du garage. Veuillez réessayer.',
        'Réglages du garage enregistrés.',
        'Impossible d’enregistrer les réglages du garage. Veuillez réessayer.',
      ],
      'en': [
        'Loading workshop settings…',
        'Workshop settings could not be loaded. Please try again.',
        'Workshop settings saved.',
        'Workshop settings could not be saved. Please try again.',
      ],
    };

    for (final entry in localizedStates.entries) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final gate = Completer<void>();
      final repository = _FakeOfficinaConfigRepository()
        ..loadGate = gate
        ..loadError = StateError('load failed');
      await tester.pumpWidget(
        _app(
          authService: authService,
          repository: repository,
          locale: Locale(entry.key),
        ),
      );
      await tester.pump();
      expect(find.text(entry.value[0]), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(entry.value[1]), findsOneWidget);

      await _enterSettings(
        tester,
        tow: _towNumber,
        workshop: _workshopNumber,
        email: _workshopEmail,
      );
      await _tapSave(tester);
      await tester.pumpAndSettle();
      expect(find.text(entry.value[2]), findsOneWidget);

      repository.saveError = StateError('save failed');
      await _tapSave(tester);
      await tester.pumpAndSettle();
      expect(find.text(entry.value[3]), findsOneWidget);
    }
  });

  testWidgets('keeps field values when saving fails', (tester) async {
    final repository = _FakeOfficinaConfigRepository()
      ..saveError = StateError('save failed');
    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();

    await _enterSettings(
      tester,
      tow: _towNumber,
      workshop: _workshopNumber,
      email: _workshopEmail,
    );
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Die Werkstatteinstellungen konnten nicht gespeichert werden. Bitte erneut versuchen.',
      ),
      findsOneWidget,
    );
    expect(_fieldText(tester, 'workshop_settings_tow_number'), _towNumber);
    expect(
      _fieldText(tester, 'workshop_settings_dealer_number'),
      _workshopNumber,
    );
    expect(
      _fieldText(tester, 'workshop_settings_dealer_email'),
      _workshopEmail,
    );
  });

  testWidgets('ignores a second save tap while the first write is pending',
      (tester) async {
    final gate = Completer<void>();
    final repository = _FakeOfficinaConfigRepository()..saveGate = gate;
    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();
    await _enterSettings(
      tester,
      tow: _towNumber,
      workshop: _workshopNumber,
      email: _workshopEmail,
    );

    await _tapSave(tester);
    await _tapSave(tester);
    await tester.pump();
    expect(repository.saveCount, 1);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const Key('workshop_settings_save')),
          )
          .onPressed,
      isNull,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(repository.saveCount, 1);
  });

  testWidgets('saving for one authenticated user does not alter another user',
      (tester) async {
    final otherSettings = _config(
      tow: '+33 1 22 33 44 55',
      workshop: '+33 1 55 66 77 88',
      email: 'garage-b@example.fr',
    );
    final repository = _FakeOfficinaConfigRepository(
      initialValues: {
        _accountA.id: _config(),
        _accountB.id: otherSettings,
      },
    );
    await tester.pumpWidget(
      _app(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();

    await _enterSettings(
      tester,
      tow: '+41 79 999 99 99',
      workshop: '',
      email: 'changed-a@example.ch',
    );
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.savedUserIds, [_accountA.id]);
    expect(repository.values[_accountB.id]!.toJson(), otherSettings.toJson());
  });

  test('legacy settings migrate once and remain isolated by authenticated user',
      () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesOfficinaConfigRepository.legacyStorageKey:
          jsonEncode(_config().toJson()),
    });
    const repository = SharedPreferencesOfficinaConfigRepository();

    final migrated = await repository.loadForUser(_accountA.id);
    final otherUser = await repository.loadForUser(_accountB.id);
    final preferences = await SharedPreferences.getInstance();

    expect(migrated.toJson(), _config().toJson());
    expect(otherUser.toJson(), OfficinaConfig.empty().toJson());
    expect(
      preferences.getString(
        SharedPreferencesOfficinaConfigRepository.storageKeyForUser(
          _accountA.id,
        ),
      ),
      isNotNull,
    );
    expect(
      preferences.getString(
        SharedPreferencesOfficinaConfigRepository.storageKeyForUser(
          _accountB.id,
        ),
      ),
      isNull,
    );
  });

  test(
      'Supabase repository survives refresh, login, update and intentional clear',
      () async {
    Map<String, dynamic>? serverSettings;
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://workshop-settings-test.supabase.co',
      'workshop-settings-test-anon-key',
      accessToken: () async => 'customer-access-token',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.url.path, '/rest/v1/customer_profiles');
        expect(request.url.queryParameters['user_id'], 'eq.${_accountA.id}');

        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({'workshop_settings': serverSettings}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.keys, {'workshop_settings'});
          serverSettings = Map<String, dynamic>.from(
            body['workshop_settings'] as Map,
          );
          return http.Response(
            jsonEncode({'workshop_settings': serverSettings}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response('Unsupported method', 405);
      }),
    );
    addTearDown(client.dispose);

    final firstSession = SupabaseOfficinaConfigRepository(
      client: client,
      cacheRepository: null,
    );
    await firstSession.saveForUser(_accountA.id, _config());

    final afterRefreshAndLogin = SupabaseOfficinaConfigRepository(
      client: client,
      cacheRepository: null,
    );
    final reloaded = await afterRefreshAndLogin.loadForUser(_accountA.id);
    expect(reloaded.toJson(), _config().toJson());

    final modified = _config(tow: '+41 91 999 99 99');
    await afterRefreshAndLogin.saveForUser(_accountA.id, modified);
    final modifiedReload = await SupabaseOfficinaConfigRepository(
      client: client,
      cacheRepository: null,
    ).loadForUser(_accountA.id);
    expect(modifiedReload.toJson(), modified.toJson());

    await afterRefreshAndLogin.saveForUser(
      _accountA.id,
      _config(workshop: '', email: ''),
    );
    final clearedReload = await SupabaseOfficinaConfigRepository(
      client: client,
      cacheRepository: null,
    ).loadForUser(_accountA.id);
    expect(clearedReload.carroNumero, _towNumber);
    expect(clearedReload.concessionariaNumero, isEmpty);
    expect(clearedReload.concessionariaEmail, isEmpty);

    expect(
        requests.where((request) => request.method == 'PATCH'), hasLength(3));
    expect(requests.where((request) => request.method == 'GET'), hasLength(3));
  });

  test(
      'Supabase repository migrates existing local settings only when remote is null',
      () async {
    Map<String, dynamic>? serverSettings;
    var patchCount = 0;
    final cache = _FakeOfficinaConfigRepository(
      initialValues: {_accountA.id: _config()},
    );
    final client = SupabaseClient(
      'https://workshop-settings-migration-test.supabase.co',
      'workshop-settings-migration-test-anon-key',
      accessToken: () async => 'customer-access-token',
      httpClient: MockClient((request) async {
        if (request.method == 'PATCH') {
          patchCount++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          serverSettings = Map<String, dynamic>.from(
            body['workshop_settings'] as Map,
          );
        }
        return http.Response(
          jsonEncode({'workshop_settings': serverSettings}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseOfficinaConfigRepository(
      client: client,
      cacheRepository: cache,
    );

    expect((await repository.loadForUser(_accountA.id)).toJson(),
        _config().toJson());
    expect(patchCount, 1);
    expect((await repository.loadForUser(_accountA.id)).toJson(),
        _config().toJson());
    expect(patchCount, 1);
  });
}
