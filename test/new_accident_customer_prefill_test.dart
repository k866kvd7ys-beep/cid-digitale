import 'dart:async';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/main.dart';
import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/models/personal_vehicle_data.dart';
import 'package:cid_digitale/services/customer_incident_prefill_service.dart';
import 'package:cid_digitale/services/device_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

const _profile = CustomerProfile(
  userId: 'customer-1',
  title: 'mrs',
  firstName: 'Anna',
  lastName: 'Bianchi',
  street: 'Via Lago 1',
  postalCode: '6900',
  city: 'Lugano',
  country: 'CH',
  phone: '+41910000000',
  email: 'anna@example.com',
  profileCompleted: true,
);

const _vehicleOne = PersonalVehicleData(
  id: 'vehicle-one',
  targa: 'TI11111',
  marca: 'Volvo',
  modello: 'XC40',
  vin: 'VIN-ONE',
  kilometraggio: '42000',
  primaImmatricolazione: '2022',
  assicurazione: 'AXA',
  numeroPolizza: 'POL-ONE',
  numeroSinistro: '',
);

const _vehicleTwo = PersonalVehicleData(
  id: 'vehicle-two',
  targa: 'TI22222',
  marca: 'BMW',
  modello: 'X3',
  vin: 'VIN-TWO',
  kilometraggio: '18000',
  primaImmatricolazione: '2024',
  assicurazione: 'Zurich',
  numeroPolizza: 'POL-TWO',
  numeroSinistro: '',
);

class _FakePrefillLoader implements CustomerIncidentPrefillLoader {
  _FakePrefillLoader(this.result);

  final Future<CustomerIncidentPrefillData> result;
  int calls = 0;

  @override
  Future<CustomerIncidentPrefillData> load() {
    calls++;
    return result;
  }
}

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

CustomerIncidentPrefillData _prefill(List<PersonalVehicleData> vehicles) {
  return CustomerIncidentPrefillData(
    customerProfile: _profile,
    cachedPersonalData: null,
    vehicles: PersonalVehicleCollection(
      primaryVehicleId: vehicles.isEmpty ? '' : vehicles.first.id,
      vehicles: vehicles,
    ),
    accountEmail: 'anna@example.com',
  );
}

Widget _app(CustomerIncidentPrefillLoader loader) {
  return MaterialApp(
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(useMaterial3: true),
    home: NuovaPraticaIncidentePage(
      customerPrefillLoader: loader,
      locationService: const _DeniedLocationService(),
    ),
  );
}

TextFormField _field(WidgetTester tester, String key) {
  return tester.widget<TextFormField>(find.byKey(Key(key)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile action waits for backend prefill before reporting empty',
      (tester) async {
    tester.view.physicalSize = const Size(760, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final completion = Completer<CustomerIncidentPrefillData>();
    final loader = _FakePrefillLoader(completion.future);

    await tester.pumpWidget(_app(loader));
    await tester.pump();

    expect(
      find.byKey(const Key('incident_customer_prefill_loading')),
      findsOneWidget,
    );
    expect(find.text('Caricamento profilo…'), findsWidgets);

    completion.complete(_prefill(const [_vehicleOne]));
    await tester.pumpAndSettle();

    expect(loader.calls, 1);
    expect(
      find.byKey(const Key('incident_selected_vehicle_summary')),
      findsOneWidget,
    );
    expect(
      _field(tester, 'incident_driver_A_plate').controller?.text,
      'TI11111',
    );
    expect(
      _field(tester, 'incident_driver_A_brand').controller?.text,
      'Volvo',
    );
    expect(
      _field(tester, 'incident_driver_A_model').controller?.text,
      'XC40',
    );
    expect(
      _field(tester, 'incident_driver_A_insurance').controller?.text,
      'AXA',
    );

    final useProfile = find.text('Usa il mio profilo').first;
    await tester.ensureVisible(useProfile);
    await tester.tap(useProfile);
    await tester.pumpAndSettle();

    expect(
      _field(tester, 'incident_driver_A_first_name').controller?.text,
      'Anna',
    );
    expect(
      _field(tester, 'incident_driver_A_policy').controller?.text,
      'POL-ONE',
    );
  });

  testWidgets('multiple vehicles require selection and update plate insurance',
      (tester) async {
    tester.view.physicalSize = const Size(760, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final loader = _FakePrefillLoader(
      Future.value(_prefill(const [_vehicleOne, _vehicleTwo])),
    );

    await tester.pumpWidget(_app(loader));
    await tester.pumpAndSettle();

    expect(
      _field(tester, 'incident_driver_A_plate').controller?.text,
      isEmpty,
    );
    final formState = tester.state<FormState>(find.byType(Form));
    expect(formState.validate(), isFalse);
    await tester.pump();
    expect(
      find.text('Seleziona il veicolo da usare per il sinistro'),
      findsWidgets,
    );

    final selector = find.byKey(const Key('incident_vehicle_selector'));
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volvo XC40 · TI11111').last);
    await tester.pumpAndSettle();

    expect(
      _field(tester, 'incident_driver_A_plate').controller?.text,
      'TI11111',
    );
    expect(
      _field(tester, 'incident_driver_A_insurance').controller?.text,
      'AXA',
    );
    expect(
      _field(tester, 'incident_driver_A_brand').controller?.text,
      'Volvo',
    );
    expect(
      _field(tester, 'incident_driver_A_model').controller?.text,
      'XC40',
    );
    expect(
      _field(tester, 'incident_driver_A_vin').controller?.text,
      'VIN-ONE',
    );
    expect(
      _field(tester, 'incident_driver_A_policy').controller?.text,
      'POL-ONE',
    );

    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BMW X3 · TI22222').last);
    await tester.pumpAndSettle();

    expect(
      _field(tester, 'incident_driver_A_plate').controller?.text,
      'TI22222',
    );
    expect(
      _field(tester, 'incident_driver_A_insurance').controller?.text,
      'Zurich',
    );
    expect(
      _field(tester, 'incident_driver_A_brand').controller?.text,
      'BMW',
    );
    expect(
      _field(tester, 'incident_driver_A_model').controller?.text,
      'X3',
    );
    expect(
      _field(tester, 'incident_driver_A_vin').controller?.text,
      'VIN-TWO',
    );
    expect(
      _field(tester, 'incident_driver_A_policy').controller?.text,
      'POL-TWO',
    );
    expect(find.textContaining('POL-TWO'), findsWidgets);
  });
}
