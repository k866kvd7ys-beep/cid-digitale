import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/main.dart';
import 'package:cid_digitale/services/customer_incident_history_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userA = '103e1b0b-9f11-4504-a8d7-fceac36facff';
const _userB = '203e1b0b-9f11-4504-a8d7-fceac36facff';
const _claimA = 'ffa2e63f-9082-4ba0-8575-d5e23d220f99';
const _claimB = 'bba2e63f-9082-4ba0-8575-d5e23d220f88';

Map<String, dynamic> _payload({
  required String id,
  required String dateTime,
  String place = 'Baden',
  String plate = 'AG12345',
  String insurance = 'Allianz',
}) {
  return {
    'id': id,
    'dataOra': dateTime,
    'luogo': place,
    'nomeA': 'Antonio',
    'cognomeA': 'Cliente',
    'targaA': plate,
    'assicurazioneA': insurance,
    'telefonoA': '',
    'emailA': '',
    'indirizzoA': '',
    'zipA': '',
    'cityA': '',
    'nomeB': '',
    'cognomeB': '',
    'targaB': '',
    'assicurazioneB': '',
    'telefonoB': '',
    'emailB': '',
    'indirizzoB': '',
    'zipB': '',
    'cityB': '',
    'descrizione': '',
    'danniVeicoloA': '',
    'danniVeicoloB': '',
    'testimoni': <Map<String, dynamic>>[],
    'feriti': <Map<String, dynamic>>[],
    'conducentiAggiuntivi': <Map<String, dynamic>>[],
    'fotoDanni': <String>[],
    'colpevole': 'A',
    'codiceOfficina': '220f99',
    'hashIntegrita': 'hash-$id',
  };
}

Map<String, dynamic> _row({
  required String id,
  required String createdAt,
  String status = 'freigegeben',
  Map<String, dynamic>? payload,
}) {
  return {
    'id': id,
    'payload_json': payload ??
        _payload(
          id: id,
          dateTime: createdAt,
        ),
    'status': status,
    'created_at': createdAt,
  };
}

class _FakeRemoteDataSource implements CustomerIncidentHistoryRemoteDataSource {
  final Map<String, List<Map<String, dynamic>>> rowsByUser = {};
  final List<String> requestedUserIds = [];
  Object? loadError;
  Completer<void>? loadGate;

  @override
  Future<List<Map<String, dynamic>>> loadClaims(String userId) async {
    requestedUserIds.add(userId);
    final gate = loadGate;
    if (gate != null) await gate.future;
    if (loadError case final error?) throw error;
    return (rowsByUser[userId] ?? const [])
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }
}

class _FakeHistorySession implements CustomerIncidentHistorySession {
  _FakeHistorySession(this._currentUserId);

  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();
  String? _currentUserId;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Stream<String?> get userChanges => _controller.stream;

  void changeUser(String? userId) {
    _currentUserId = userId;
    _controller.add(userId);
  }

  Future<void> dispose() => _controller.close();
}

Future<CustomerIncidentHistoryRepository> _repository(
  _FakeRemoteDataSource remote,
) async {
  return CustomerIncidentHistoryRepository(
    remoteDataSource: remote,
    preferences: await SharedPreferences.getInstance(),
  );
}

Widget _historyApp({
  required CustomerIncidentHistoryRepository repository,
  required CustomerIncidentHistorySession session,
}) {
  return MaterialApp(
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: StoricoPage(
        embedOnlyBody: true,
        historyRepository: repository,
        historySession: session,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    incidentiSalvati = [];
  });

  test('production query is owner-filtered and sorted without unsafe fields',
      () async {
    final source = File(
      'lib/services/customer_incident_history_repository.dart',
    ).readAsStringSync();

    expect(source, contains(".from('claims')"));
    expect(source, contains(".eq('created_by', userId)"));
    expect(
      source,
      contains(".order('created_at', ascending: false)"),
    );
    expect(source, isNot(contains(".from('incidents')")));
    expect(source, isNot(contains(".eq('email")));
    expect(source, isNot(contains(".eq('telefono")));
  });

  test('remote rows are parsed safely and sorted newest first', () async {
    final remote = _FakeRemoteDataSource()
      ..rowsByUser[_userA] = [
        _row(
          id: _claimA,
          createdAt: '2026-08-01T06:12:10Z',
          payload: {
            ..._payload(
              id: _claimA,
              dateTime: '2026-08-01T08:09:46.621',
            ),
            'luogo': 123,
            'fotoDanni': 'invalid',
          },
        ),
        _row(
          id: _claimB,
          createdAt: '2026-08-02T06:12:10Z',
        ),
      ];
    final repository = await _repository(remote);

    final result = await repository.loadForUser(
      userId: _userA,
      localPayloads: const [],
    );

    expect(remote.requestedUserIds, [_userA]);
    expect(result.remoteSucceeded, isTrue);
    expect(result.entries.map((entry) => entry.id), [_claimB, _claimA]);
    expect(result.entries.last.incidentPayload['id'], _claimA);
    expect(result.entries.last.incidentPayload['luogo'], '123');
    expect(result.entries.last.incidentPayload['fotoDanni'], isEmpty);
  });

  test('remote wins and local drafts never appear in customer history',
      () async {
    final remotePayload = _payload(
      id: _claimA,
      dateTime: '2026-08-01T08:09:46.621',
      place: 'Remote place',
    );
    final remote = _FakeRemoteDataSource()
      ..rowsByUser[_userA] = [
        _row(
          id: _claimA,
          createdAt: '2026-08-01T06:12:10Z',
          payload: remotePayload,
        ),
      ];
    final repository = await _repository(remote);
    final localDuplicate = _payload(
      id: _claimA,
      dateTime: '2026-08-01T08:09:46.621',
      place: 'Stale local place',
    );
    final localDraft = _payload(
      id: 'local-draft-1',
      dateTime: '2026-08-03T08:09:46.621',
      place: 'Draft place',
    );

    final result = await repository.loadForUser(
      userId: _userA,
      localPayloads: [localDuplicate, localDraft, localDraft],
    );

    expect(result.entries, hasLength(1));
    expect(
      result.entries
          .singleWhere((entry) => entry.id == _claimA)
          .payload['luogo'],
      'Remote place',
    );
    expect(
      result.entries.where((entry) => entry.id == 'local-draft-1'),
      isEmpty,
    );
  });

  test('empty database drafts are excluded instead of receiving current time',
      () async {
    final remote = _FakeRemoteDataSource()
      ..rowsByUser[_userA] = [
        _row(
          id: _claimA,
          createdAt: '2026-08-22T07:00:00Z',
          payload: const <String, dynamic>{},
        ),
      ];
    final repository = await _repository(remote);

    final result = await repository.loadForUser(
      userId: _userA,
      localPayloads: const [],
    );

    expect(result.remoteSucceeded, isTrue);
    expect(result.entries, isEmpty);
  });

  test('remote error returns only the same-user cache and permits retry',
      () async {
    final remote = _FakeRemoteDataSource()
      ..rowsByUser[_userA] = [
        _row(id: _claimA, createdAt: '2026-08-01T06:12:10Z'),
      ];
    final repository = await _repository(remote);
    final successful = await repository.loadForUser(
      userId: _userA,
      localPayloads: const [],
    );
    expect(successful.remoteSucceeded, isTrue);

    remote.loadError = StateError('temporary failure');
    final fallback = await repository.loadForUser(
      userId: _userA,
      localPayloads: const [],
    );

    expect(fallback.remoteSucceeded, isFalse);
    expect(fallback.entries.single.id, _claimA);
    expect(
      (await SharedPreferences.getInstance()).getString(
        CustomerIncidentHistoryRepository.cacheKeyForUser(_userB),
      ),
      isNull,
    );
  });

  testWidgets('empty state appears only after the remote query completes',
      (tester) async {
    final gate = Completer<void>();
    final remote = _FakeRemoteDataSource()..loadGate = gate;
    final session = _FakeHistorySession(_userA);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      _historyApp(
        repository: await _repository(remote),
        session: session,
      ),
    );
    await tester.pump();

    expect(find.text('Caricamento incidenti…'), findsOneWidget);
    expect(find.text('Nessun incidente salvato.'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nessun incidente salvato.'), findsOneWidget);
  });

  testWidgets('error state retries and then displays the real claim',
      (tester) async {
    final remote = _FakeRemoteDataSource()
      ..loadError = StateError('temporary failure');
    final session = _FakeHistorySession(_userA);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      _historyApp(
        repository: await _repository(remote),
        session: session,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-incident-retry')), findsOneWidget);
    expect(find.text('Nessun incidente salvato.'), findsNothing);

    remote
      ..loadError = null
      ..rowsByUser[_userA] = [
        _row(
          id: _claimA,
          createdAt: '2026-08-01T06:12:10Z',
          payload: _payload(
            id: _claimA,
            dateTime: '2026-08-01T08:09:46.621',
          ),
        ),
      ];
    await tester.tap(find.byKey(const Key('customer-incident-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-incident-$_claimA')), findsOneWidget);
    expect(find.text('CID-2026-304259'), findsOneWidget);
  });

  testWidgets('account change clears old state and reloads with the new UID',
      (tester) async {
    final remote = _FakeRemoteDataSource()
      ..rowsByUser[_userA] = [
        _row(id: _claimA, createdAt: '2026-08-01T06:12:10Z'),
      ]
      ..rowsByUser[_userB] = [
        _row(id: _claimB, createdAt: '2026-08-02T06:12:10Z'),
      ];
    final session = _FakeHistorySession(_userA);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      _historyApp(
        repository: await _repository(remote),
        session: session,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-incident-$_claimA')), findsOneWidget);

    session.changeUser(_userB);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-incident-$_claimA')), findsNothing);
    expect(find.byKey(const Key('customer-incident-$_claimB')), findsOneWidget);
    expect(remote.requestedUserIds, [_userA, _userB]);

    session.changeUser(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-incident-$_claimB')), findsNothing);
    expect(incidentiSalvati, isEmpty);
  });

  testWidgets('opening a remote card passes the real claim id and row metadata',
      (tester) async {
    final remote = _FakeRemoteDataSource()
      ..rowsByUser[_userA] = [
        _row(
          id: _claimA,
          createdAt: '2026-08-01T06:12:10Z',
          payload: _payload(
            id: 'stale-local-id',
            dateTime: '2026-08-01T08:09:46.621',
          ),
        ),
      ];
    final session = _FakeHistorySession(_userA);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      _historyApp(
        repository: await _repository(remote),
        session: session,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('customer-incident-$_claimA')));
    await tester.pumpAndSettle();

    final detail = tester.widget<DettaglioIncidentePage>(
      find.byType(DettaglioIncidentePage),
    );
    expect(detail.incidente.id, _claimA);
    expect(detail.claimStatus, 'freigegeben');
    expect(detail.claimCreatedAt, DateTime.parse('2026-08-01T06:12:10Z'));
  });

  test('selecting the incidents tab is wired to request a history refresh', () {
    final requestsPage =
        File('lib/screens/my_requests_page.dart').readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(requestsPage, contains('widget.onIncidentsTabSelected?.call()'));
    expect(mainSource, contains('refreshAfterTabSelected()'));
  });

  test('new incident history copy exists in all four ARB files', () {
    for (final language in const ['de', 'it', 'fr', 'en']) {
      final arb = jsonDecode(
        File('lib/l10n/app_$language.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final key in const [
        'customerIncidentLoading',
        'customerIncidentLoadError',
        'customerIncidentRetry',
        'customerIncidentEmpty',
        'customerIncidentLocalDraft',
        'customerIncidentRefresh',
      ]) {
        expect(arb[key]?.toString().trim(), isNotEmpty,
            reason: '$language $key');
      }
    }
  });
}
