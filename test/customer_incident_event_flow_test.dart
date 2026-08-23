import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/main.dart';
import 'package:cid_digitale/models/customer_incident_event.dart';
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
    locale: Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: NuovaPraticaIncidentePage(
      initialIncidentEventType: CustomerIncidentEventType.naturalEvent,
      initialIncidentEventSubtype: CustomerIncidentEventSubtype.stormWind,
      locationService: _DeniedLocationService(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'damage page hides the duplicate picker and keeps the Home category',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Was ist passiert?'), findsNothing);
    expect(find.text('Ereignisart'), findsNothing);
    expect(find.byKey(const Key('incident_event_type')), findsNothing);
    expect(find.text('Unfallbeschreibung'), findsOneWidget);
    expect(
      find.text('Gibt es Sachschäden an anderen Gegenständen?'),
      findsOneWidget,
    );
    expect(
      find.text('Gibt es Sachschäden an anderen Fahrzeugen?'),
      findsOneWidget,
    );

    final description = find.byKey(const Key('incident_description'));
    await tester.scrollUntilVisible(
      description,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(description, 'Sturmschaden am Fahrzeug');

    final dynamic state = tester.state(
      find.byType(NuovaPraticaIncidentePage),
    );
    expect(state.incidentEventTypeForTesting, 'natural_event');
    expect(state.incidentEventSubtypeForTesting, 'storm_wind');
    expect(
      tester.widget<TextFormField>(description).controller?.text,
      'Sturmschaden am Fahrzeug',
    );
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
