import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/main.dart';
import 'package:cid_digitale/models/driver_personal_qr_data.dart';
import 'package:cid_digitale/models/incidente.dart' as workshop_model;
import 'package:cid_digitale/screens/supabase_demo_screen.dart';
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

Widget _localizedApp(Widget home) {
  return MaterialApp(
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(useMaterial3: true),
    home: home,
  );
}

TextFormField _field(WidgetTester tester, String key) {
  return tester.widget<TextFormField>(find.byKey(Key(key)));
}

const _driverBQr = DriverPersonalQrData(
  nome: 'Mario',
  cognome: 'Rossi',
  indirizzo: 'Via Centro 8',
  zip: '8000',
  city: 'Zurigo',
  country: 'CH',
  telefono: '+41440000000',
  email: 'mario@example.com',
  targa: 'ZH222222',
  marca: 'Audi',
  modello: 'A4',
  vin: 'VIN-B',
  kilometraggio: '51000',
  primaImmatricolazione: '2021',
  assicurazione: 'Helvetia',
  numeroPolizza: 'POL-B',
  numeroSinistro: 'SIN-B',
  customerNumber: 'CUSTOMER-B',
);

Incidente _incident() {
  return Incidente(
    id: 'vehicle-contract-test',
    dataOra: DateTime.utc(2026, 8, 22, 10),
    luogo: 'Lugano',
    nomeA: 'Anna',
    cognomeA: 'Bianchi',
    targaA: 'TI11111',
    marcaA: 'Volvo',
    modelloA: 'XC40',
    vinA: 'VIN-A',
    kilometraggioA: '42000',
    primaImmatricolazioneA: '2022',
    assicurazioneA: 'AXA',
    numeroPolizzaA: 'POL-A',
    numeroSinistroA: 'SIN-A',
    telefonoA: '+41910000000',
    emailA: 'anna@example.com',
    indirizzoA: 'Via Lago 1',
    zipA: '6900',
    cityA: 'Lugano',
    nomeB: 'Mario',
    cognomeB: 'Rossi',
    targaB: 'ZH222222',
    marcaB: 'Audi',
    modelloB: 'A4',
    vinB: 'VIN-B',
    kilometraggioB: '51000',
    primaImmatricolazioneB: '2021',
    assicurazioneB: 'Helvetia',
    numeroPolizzaB: 'POL-B',
    numeroSinistroB: 'SIN-B',
    telefonoB: '+41440000000',
    emailB: 'mario@example.com',
    indirizzoB: 'Via Centro 8',
    zipB: '8000',
    cityB: 'Zurigo',
    descrizione: 'Collisione lieve',
    danniVeicoloA: '',
    danniVeicoloB: '',
    otherObjectDamage: false,
    otherVehicleDamage: true,
    testimoni: const [],
    feriti: const [],
    conducentiAggiuntivi: [
      ConducenteAggiuntivo(
        driverKey: 'C',
        nome: 'Luca',
        cognome: 'Verdi',
        targa: 'GR33333',
        marca: 'BMW',
        modello: 'X3',
        vin: 'VIN-C',
        kilometraggio: '18000',
        primaImmatricolazione: '2024',
        assicurazione: 'Zurich',
        numeroPolizza: 'POL-C',
        numeroSinistro: 'SIN-C',
        indirizzo: '',
        zip: '',
        city: '',
        telefono: '',
        email: '',
      ),
    ],
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
    codiceOfficina: 'OFF-1',
    hashIntegrita: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('driver B QR imports person and its complete vehicle only',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        const NuovaPraticaIncidentePage(
          locationService: _DeniedLocationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dynamic state = tester.state(
      find.byType(NuovaPraticaIncidentePage),
    );
    await state.importDriverQrData(_driverBQr, const DriverTarget.driverB());
    await tester.pump();

    expect(
      _field(tester, 'incident_driver_B_first_name').controller?.text,
      'Mario',
    );
    expect(_field(tester, 'incident_driver_B_brand').controller?.text, 'Audi');
    expect(_field(tester, 'incident_driver_B_model').controller?.text, 'A4');
    expect(
      _field(tester, 'incident_driver_B_plate').controller?.text,
      'ZH222222',
    );
    expect(
      _field(tester, 'incident_driver_B_insurance').controller?.text,
      'Helvetia',
    );
    expect(
      _field(tester, 'incident_driver_B_policy').controller?.text,
      'POL-B',
    );
    expect(_field(tester, 'incident_driver_B_vin').controller?.text, 'VIN-B');
    expect(_field(tester, 'incident_driver_A_brand').controller?.text, isEmpty);
  });

  testWidgets(
      'driver B and additional drivers expose independent manual fields',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        const NuovaPraticaIncidentePage(
          locationService: _DeniedLocationService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('incident_driver_A_brand')), findsOneWidget);
    expect(find.byKey(const Key('incident_driver_A_model')), findsOneWidget);
    expect(find.byKey(const Key('incident_driver_A_plate')), findsOneWidget);
    expect(
      find.byKey(const Key('incident_driver_A_insurance')),
      findsOneWidget,
    );
    _field(tester, 'incident_driver_A_brand').controller?.text = 'Toyota';
    _field(tester, 'incident_driver_A_model').controller?.text = 'Corolla';

    _field(tester, 'incident_driver_B_brand').controller?.text = 'Ford';
    _field(tester, 'incident_driver_B_model').controller?.text = 'Focus';
    _field(tester, 'incident_driver_B_plate').controller?.text = 'BE44444';
    _field(tester, 'incident_driver_B_insurance').controller?.text = 'Baloise';

    final addDriver = find.text('Aggiungi conducente');
    await tester.ensureVisible(addDriver);
    await tester.tap(addDriver);
    await tester.pump();

    expect(find.byKey(const Key('incident_driver_C_brand')), findsOneWidget);
    expect(find.byKey(const Key('incident_driver_C_model')), findsOneWidget);
    expect(find.byKey(const Key('incident_driver_C_plate')), findsOneWidget);
    expect(
      find.byKey(const Key('incident_driver_C_insurance')),
      findsOneWidget,
    );
    expect(_field(tester, 'incident_driver_B_brand').controller?.text, 'Ford');
    expect(_field(tester, 'incident_driver_C_brand').controller?.text, isEmpty);
    expect(
      _field(tester, 'incident_driver_A_brand').controller?.text,
      'Toyota',
    );
  });

  test('incident payload round-trip keeps every driver vehicle and old data',
      () {
    final incident = _incident();
    final json = incident.toJson();
    final restored = Incidente.fromJson(json);

    expect(restored.marcaA, 'Volvo');
    expect(restored.modelloA, 'XC40');
    expect(restored.numeroPolizzaA, 'POL-A');
    expect(restored.marcaB, 'Audi');
    expect(restored.numeroSinistroB, 'SIN-B');
    expect(restored.conducentiAggiuntivi.single.marca, 'BMW');
    expect(
      (json['driverA'] as Map<String, dynamic>)['vehicle'],
      containsPair('brand', 'Volvo'),
    );

    final legacy = Map<String, dynamic>.from(json)
      ..remove('marcaA')
      ..remove('modelloA')
      ..remove('numeroPolizzaA')
      ..remove('driverA');
    final restoredLegacy = Incidente.fromJson(legacy);
    expect(restoredLegacy.targaA, 'TI11111');
    expect(restoredLegacy.assicurazioneA, 'AXA');
    expect(restoredLegacy.marcaA, isEmpty);
    expect(restoredLegacy.modelloA, isEmpty);
  });

  testWidgets('customer detail email and PDF use each associated vehicle',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(DettaglioIncidentePage(incidente: _incident())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('incident-detail-driver-A')), findsOneWidget);
    expect(find.byKey(const Key('incident-detail-driver-B')), findsOneWidget);
    expect(find.byKey(const Key('incident-detail-driver-C')), findsOneWidget);
    expect(
      find.text('Anna Bianchi · Volvo XC40 · TI11111 · AXA'),
      findsOneWidget,
    );
    expect(
      find.text('Mario Rossi · Audi A4 · ZH222222 · Helvetia'),
      findsOneWidget,
    );

    final dynamic state = tester.state(find.byType(DettaglioIncidentePage));
    final email =
        state.buildLocalizedCidEmailContentForTesting() as Map<String, String>;
    expect(email['body'], contains('Veicolo: Volvo XC40'));
    expect(email['body'], contains('Targa: ZH222222'));
    expect(email['body'], contains('Polizza: POL-C'));

    final pdfBytes = await state.buildIncidentPdfBytesForTesting() as List<int>;
    expect(pdfBytes, isNotEmpty);
  });

  testWidgets('workshop detail shows the vehicle of every driver',
      (tester) async {
    final workshopIncident = workshop_model.Incidente.fromJson(
      _incident().toJson(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkshopImportedClaimDetailPage(
          incidente: workshopIncident,
        ),
      ),
    );

    expect(find.byKey(const Key('workshop-claim-driver-A')), findsOneWidget);
    expect(find.byKey(const Key('workshop-claim-driver-B')), findsOneWidget);
    expect(find.byKey(const Key('workshop-claim-driver-C')), findsOneWidget);
    expect(
      find.text('Anna Bianchi · Volvo XC40 · TI11111 · AXA'),
      findsOneWidget,
    );
    expect(
      find.text('Mario Rossi · Audi A4 · ZH222222 · Helvetia'),
      findsOneWidget,
    );
  });
}
