import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/main.dart';
import 'package:cid_digitale/services/device_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DeniedLocationService extends DeviceLocationService {
  const _DeniedLocationService();

  @override
  Future<DeviceLocationResult> requestCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const DeviceLocationResult(
      serviceEnabled: true,
      permission: LocationPermission.denied,
      position: null,
    );
  }
}

Widget _app() {
  return const MaterialApp(
    locale: Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: NuovaPraticaIncidentePage(
      locationService: _DeniedLocationService(),
    ),
  );
}

Future<void> _showEventSelection(WidgetTester tester) async {
  final finder = find.byKey(const Key('incident_event_type'));
  await tester.scrollUntilVisible(
    finder,
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('customer selects all event types and conditional subtypes',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _showEventSelection(tester);

    expect(find.textContaining('Haftpflicht'), findsNothing);
    expect(find.textContaining('Teilkasko'), findsNothing);
    expect(find.textContaining('Vollkasko'), findsNothing);
    expect(find.textContaining('copert', findRichText: true), findsNothing);
    expect(find.textContaining('pagher', findRichText: true), findsNothing);

    await tester.tap(find.byKey(const Key('incident_event_type')));
    await tester.pumpAndSettle();
    expect(find.text('Incidente / Collisione'), findsOneWidget);
    expect(find.text('Incendio'), findsOneWidget);
    expect(find.text('Collisione con animale'), findsOneWidget);
    await tester.tap(find.text('Danno naturale').last);
    await tester.pumpAndSettle();

    final naturalSubtype =
        find.byKey(const Key('incident_event_subtype_natural_event'));
    expect(naturalSubtype, findsOneWidget);
    await tester.tap(naturalSubtype);
    await tester.pumpAndSettle();
    expect(find.text('Tempesta / vento forte'), findsOneWidget);
    expect(find.text('Altro evento naturale'), findsOneWidget);
    await tester.tap(find.text('Tempesta / vento forte'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('incident_event_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Furto / tentato furto').last);
    await tester.pumpAndSettle();

    final theftSubtype = find.byKey(const Key('incident_event_subtype_theft'));
    expect(theftSubtype, findsOneWidget);
    await tester.tap(theftSubtype);
    await tester.pumpAndSettle();
    expect(find.text('Veicolo rubato'), findsOneWidget);
    expect(
      find.text('Danni causati durante il furto/tentato furto'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentato furto'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('structured event survives save/reopen and keeps internal metadata', () {
    final incident = Incidente.fromJson({
      'id': 'event-round-trip',
      'dataOra': '2026-08-22T10:00:00.000Z',
      'incidentEventType': 'natural_event',
      'incidentEventSubtype': 'storm_wind',
      'damage_type': 'natural_event',
    });

    final payload = incident.toJson();
    final reopened = Incidente.fromJson(payload);
    final classification =
        payload['damage_classification'] as Map<String, dynamic>;

    expect(reopened.incidentEventType, 'natural_event');
    expect(reopened.incidentEventSubtype, 'storm_wind');
    expect(payload['damage_type'], 'natural_event');
    expect(payload['damage_subtype'], 'storm_wind');
    expect(classification['event_category'], 'natural_event');
    expect(classification['insurance_area'], 'partial_comprehensive');
    expect(classification['policy_verification_required'], isTrue);
    expect(classification.containsKey('covered'), isFalse);
    expect(reopened.colpevole, isEmpty);
  });

  test('legacy incident keeps original damage type and hash payload shape', () {
    final incident = Incidente.fromJson({
      'id': 'legacy-event',
      'dataOra': '2025-01-02T10:00:00.000Z',
      'damage_type': 'Haftpflichtschaden',
      'hashIntegrita': 'legacy-hash',
    });

    final payload = incident.toJson();
    expect(incident.incidentEventType, 'collision');
    expect(incident.hasStructuredIncidentEvent, isFalse);
    expect(payload['damage_type'], 'Haftpflichtschaden');
    expect(payload.containsKey('incidentEventType'), isFalse);
    expect(payload.containsKey('damage_classification'), isFalse);
    expect(payload['hashIntegrita'], 'legacy-hash');

    final unknown = Incidente.fromJson({
      'dataOra': '2025-01-02T10:00:00.000Z',
      'damage_type': 'legacy_special_category',
    });
    expect(unknown.incidentEventType, 'legacy_special_category');
    expect(unknown.toJson()['damage_type'], 'legacy_special_category');
  });
}
