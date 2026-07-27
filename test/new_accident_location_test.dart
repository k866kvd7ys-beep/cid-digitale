import 'dart:collection';
import 'dart:convert';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/main.dart';
import 'package:cid_digitale/services/device_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeDeviceLocationService extends DeviceLocationService {
  _FakeDeviceLocationService(Iterable<Future<DeviceLocationResult>> results)
      : _results = Queue.of(results);

  final Queue<Future<DeviceLocationResult>> _results;
  int calls = 0;

  @override
  Future<DeviceLocationResult> requestCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 10),
  }) {
    calls += 1;
    if (_results.isEmpty) {
      throw StateError('No fake location result configured');
    }
    return _results.removeFirst();
  }
}

Position _position(double latitude, double longitude) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 7, 27, 12),
    accuracy: 4,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
    isMocked: false,
  );
}

DeviceLocationResult _success(Position position) {
  return DeviceLocationResult(
    serviceEnabled: true,
    permission: LocationPermission.whileInUse,
    position: position,
  );
}

const _denied = DeviceLocationResult(
  serviceEnabled: true,
  permission: LocationPermission.denied,
  position: null,
);

const _temporarilyUnavailable = DeviceLocationResult(
  serviceEnabled: true,
  permission: LocationPermission.whileInUse,
  position: null,
);

http.Response _addressResponse({
  required String road,
  required String houseNumber,
  required String postcode,
  required String city,
}) {
  return http.Response(
    jsonEncode({
      'address': {
        'road': road,
        'house_number': houseNumber,
        'postcode': postcode,
        'city': city,
        'country': 'Schweiz/Suisse',
      },
    }),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Widget _app(
  DeviceLocationService locationService,
  http.Client reverseGeocodingClient,
) {
  return MaterialApp(
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(useMaterial3: true),
    home: NuovaPraticaIncidentePage(
      locationService: locationService,
      reverseGeocodingClient: reverseGeocodingClient,
    ),
  );
}

TextFormField _locationField(WidgetTester tester) {
  return tester.widget<TextFormField>(
    find.byKey(const Key('accident_location_field')),
  );
}

TextField _locationTextField(WidgetTester tester) {
  return tester.widget<TextField>(
    find.descendant(
      of: find.byKey(const Key('accident_location_field')),
      matching: find.byType(TextField),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocaleTestValue();
  });

  testWidgets(
      'detects the location on open, locks the address and retries without stale data',
      (tester) async {
    tester.view.physicalSize = const Size(700, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final firstPosition = _position(46.0050, 8.9516);
    final secondPosition = _position(46.0100, 8.9600);
    final retryResult = Future<DeviceLocationResult>.delayed(
      const Duration(milliseconds: 500),
      () => _success(secondPosition),
    );
    final locationService = _FakeDeviceLocationService([
      Future.value(_success(firstPosition)),
      retryResult,
    ]);
    final reverseRequests = <Uri>[];
    var reverseCall = 0;
    final reverseClient = MockClient((request) async {
      reverseRequests.add(request.url);
      reverseCall += 1;
      return reverseCall == 1
          ? _addressResponse(
              road: 'Via Cantonale',
              houseNumber: '12',
              postcode: '6900',
              city: 'Lugano',
            )
          : _addressResponse(
              road: 'Via Nuova',
              houseNumber: '8',
              postcode: '6900',
              city: 'Lugano',
            );
    });
    addTearDown(reverseClient.close);

    await tester.pumpWidget(_app(locationService, reverseClient));
    await tester.pumpAndSettle();

    expect(locationService.calls, 1);
    expect(
      _locationField(tester).controller?.text,
      'Via Cantonale 12, 6900 Lugano, Schweiz/Suisse',
    );
    expect(_locationTextField(tester).readOnly, isTrue);
    expect(_locationTextField(tester).showCursor, isFalse);
    expect(_locationTextField(tester).enableInteractiveSelection, isFalse);
    expect(find.text('Karte öffnen'), findsNothing);
    expect(find.byIcon(Icons.map_outlined), findsNothing);
    expect(find.text('Standort erneut ermitteln'), findsOneWidget);
    expect(find.text('Datum und Uhrzeit'), findsOneWidget);
    expect(reverseRequests.single.queryParameters['lat'], '46.005');
    expect(reverseRequests.single.queryParameters['lon'], '8.9516');

    await tester.tap(find.byKey(const Key('accident_location_field')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);

    final retryButton = find.byKey(const Key('accident_location_retry_button'));
    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);
    await tester.pump();

    expect(locationService.calls, 2);
    expect(_locationField(tester).controller?.text, isEmpty);
    expect(find.text('Standort wird ermittelt...'), findsWidgets);

    await tester.pumpAndSettle();
    expect(
      _locationField(tester).controller?.text,
      'Via Nuova 8, 6900 Lugano, Schweiz/Suisse',
    );
    expect(find.text('Standort erneut ermitteln'), findsOneWidget);
    expect(reverseRequests.last.queryParameters['lat'], '46.01');
    expect(reverseRequests.last.queryParameters['lon'], '8.96');
  });

  testWidgets('shows a professional permission error and permits retry',
      (tester) async {
    tester.view.physicalSize = const Size(700, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final locationService = _FakeDeviceLocationService([
      Future.value(_denied),
      Future.value(_success(_position(46.2, 9.0))),
    ]);
    final reverseClient = MockClient(
      (_) async => _addressResponse(
        road: 'Hauptstrasse',
        houseNumber: '1',
        postcode: '6500',
        city: 'Bellinzona',
      ),
    );
    addTearDown(reverseClient.close);

    await tester.pumpWidget(_app(locationService, reverseClient));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Der Standort kann nicht ermittelt werden. Erlaube den '
        'Standortzugriff in den Browsereinstellungen und versuche es erneut.',
      ),
      findsOneWidget,
    );
    expect(_locationField(tester).controller?.text, isEmpty);
    expect(find.text('Erneut versuchen'), findsOneWidget);

    final retryButton = find.byKey(const Key('accident_location_retry_button'));
    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(locationService.calls, 2);
    expect(
      _locationField(tester).controller?.text,
      'Hauptstrasse 1, 6500 Bellinzona, Schweiz/Suisse',
    );
  });

  testWidgets('keeps the address empty after a temporary GPS error',
      (tester) async {
    tester.view.physicalSize = const Size(700, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final locationService = _FakeDeviceLocationService([
      Future.value(_temporarilyUnavailable),
    ]);
    final reverseClient = MockClient(
      (_) async => throw StateError('Reverse geocoding must not run'),
    );
    addTearDown(reverseClient.close);

    await tester.pumpWidget(_app(locationService, reverseClient));
    await tester.pumpAndSettle();

    expect(_locationField(tester).controller?.text, isEmpty);
    expect(
      find.text(
        'Standort konnte nicht ermittelt werden. Bitte prüfe die '
        'Standortfreigabe und versuche es erneut.',
      ),
      findsOneWidget,
    );
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  testWidgets('rejects a failed reverse geocode and keeps retry available',
      (tester) async {
    tester.view.physicalSize = const Size(700, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final locationService = _FakeDeviceLocationService([
      Future.value(_success(_position(46.005, 8.9516))),
    ]);
    final reverseClient =
        MockClient((_) async => http.Response('Unavailable', 503));
    addTearDown(reverseClient.close);

    await tester.pumpWidget(_app(locationService, reverseClient));
    await tester.pumpAndSettle();

    expect(_locationField(tester).controller?.text, isEmpty);
    expect(
      find.text(
        'Standort konnte nicht ermittelt werden. Bitte prüfe die '
        'Standortfreigabe und versuche es erneut.',
      ),
      findsOneWidget,
    );
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  test('incident payload keeps the detected address and automatic date/time',
      () {
    final detectedAt = DateTime.utc(2026, 7, 27, 10, 15);
    final incident = Incidente(
      id: 'location-contract-test',
      dataOra: detectedAt,
      luogo: 'Via Cantonale 12, 6900 Lugano, Schweiz/Suisse',
      nomeA: '',
      cognomeA: '',
      targaA: '',
      assicurazioneA: '',
      telefonoA: '',
      emailA: '',
      indirizzoA: '',
      zipA: '',
      cityA: '',
      nomeB: '',
      cognomeB: '',
      targaB: '',
      assicurazioneB: '',
      telefonoB: '',
      emailB: '',
      indirizzoB: '',
      zipB: '',
      cityB: '',
      descrizione: '',
      danniVeicoloA: '',
      danniVeicoloB: '',
      otherObjectDamage: null,
      otherVehicleDamage: null,
      testimoni: const [],
      feriti: const [],
      conducentiAggiuntivi: const [],
      notaVocaleA: '',
      notaVocaleB: '',
      notaAudioAPath: '',
      notaAudioBPath: '',
      fotoLibrettoA: '',
      fotoLibrettoB: '',
      fotoDanni: const [],
      firmaAPath: '',
      firmaBPath: '',
      timestampFirmaA: '',
      timestampFirmaB: '',
      colpevole: '',
      codiceOfficina: '',
      hashIntegrita: '',
    );

    expect(
      incident.toJson()['luogo'],
      'Via Cantonale 12, 6900 Lugano, Schweiz/Suisse',
    );
    expect(incident.toJson()['dataOra'], detectedAt.toIso8601String());
  });
}
