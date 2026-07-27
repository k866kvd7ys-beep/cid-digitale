import 'dart:convert';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/models/driver_personal_qr_data.dart';
import 'package:cid_digitale/models/personal_vehicle_data.dart';
import 'package:cid_digitale/screens/driver_personal_qr_screen.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:cid_digitale/services/personal_vehicle_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_customer_auth_service.dart';

const _account = CustomerAccount(
  id: 'antonio-auth-user-id',
  email: 'antonio.auth@example.com',
  role: customerRole,
  firstName: 'Auth first name',
  lastName: 'Auth last name',
);

const _completeProfile = CustomerProfile(
  userId: 'antonio-auth-user-id',
  title: 'other',
  firstName: 'Antonio',
  lastName: 'Privitera',
  street: 'Via Cantonale 12',
  postalCode: '6900',
  city: 'Lugano',
  country: 'CH',
  phone: '+41 79 123 45 67',
  email: 'stale-profile-email@example.com',
  profileCompleted: true,
);

const _legacyQrData = DriverPersonalQrData(
  courtesy: DriverPersonalQrCourtesy.mr,
  nome: 'Vecchio',
  cognome: 'Cliente',
  indirizzo: 'Vecchia strada',
  zip: '0000',
  city: 'Vecchia città',
  country: 'IT',
  telefono: '000',
  email: 'vecchia@example.com',
  targa: 'OLD-PLATE',
  marca: 'Old brand',
  modello: 'Old model',
  vin: 'OLD-VIN',
  kilometraggio: '1',
  primaImmatricolazione: '2000',
  assicurazione: 'Old insurance',
  numeroPolizza: 'OLD-POLICY',
  numeroSinistro: 'OLD-CLAIM',
  customerNumber: '',
);

const _firstVehicle = PersonalVehicleData(
  id: 'vehicle-one',
  targa: 'TI11111',
  marca: 'Volvo',
  modello: 'XC40',
  vin: 'VIN-ONE',
  kilometraggio: '42000',
  primaImmatricolazione: '2022',
  assicurazione: 'AXA',
  numeroPolizza: 'POL-ONE',
  numeroSinistro: 'CLAIM-ONE',
);

const _primaryVehicle = PersonalVehicleData(
  id: 'vehicle-two',
  targa: 'TI22222',
  marca: 'BMW',
  modello: 'X3',
  vin: 'VIN-TWO',
  kilometraggio: '71000',
  primaImmatricolazione: '2020',
  assicurazione: 'Allianz',
  numeroPolizza: 'POL-TWO',
  numeroSinistro: 'CLAIM-TWO',
);

const _vehicleCollection = PersonalVehicleCollection(
  primaryVehicleId: 'vehicle-two',
  vehicles: [_firstVehicle, _primaryVehicle],
);

Widget _app(
  FakeCustomerAuthService service, {
  Key? screenKey,
}) {
  return MaterialApp(
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(useMaterial3: true),
    home: DriverPersonalQrScreen(
      key: screenKey,
      authService: service,
    ),
  );
}

Map<String, Object> _savedQrState() {
  final vehicleJson = jsonEncode(_vehicleCollection.toMap());
  return <String, Object>{
    PersonalVehicleStorage.storageKey: vehicleJson,
    PersonalVehicleStorage.legacyProfileKey:
        driverPersonalQrDataToJson(_legacyQrData),
    'driver_personal_qr_generated_v1':
        driverPersonalQrDataToJson(_legacyQrData),
  };
}

TextFormField _field(WidgetTester tester, String key) {
  return tester.widget<TextFormField>(find.byKey(Key(key)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(_savedQrState());
  });

  testWidgets(
      'authenticated customer_profile replaces legacy customer data read-only',
      (tester) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeCustomerAuthService(
      account: _account,
      profile: _completeProfile,
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(service.loadProfileCalls, 1);
    expect(service.lastLoadedProfileUserId, _account.id);
    expect(
      find.text(
        'Diese Daten werden automatisch aus deinem Kundenprofil übernommen.',
      ),
      findsWidgets,
    );

    final expectedFields = <String, String>{
      'personal_qr_customer_first_name': 'Antonio',
      'personal_qr_customer_last_name': 'Privitera',
      'personal_qr_customer_street': 'Via Cantonale 12',
      'personal_qr_customer_postal_code': '6900',
      'personal_qr_customer_city': 'Lugano',
      'personal_qr_customer_country': 'CH',
      'personal_qr_customer_phone': '+41 79 123 45 67',
      'personal_qr_customer_email': _account.email,
    };
    for (final entry in expectedFields.entries) {
      final field = _field(tester, entry.key);
      expect(field.controller?.text, entry.value);
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(entry.key)),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.readOnly, isTrue);
    }
    expect(find.text('Andere'), findsOneWidget);
    expect(find.text('Vecchio'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final payload = prefs.getString('driver_personal_qr_generated_v1');
    expect(payload, isNotNull);
    final scanned = driverPersonalQrDataFromQrPayload(payload!);
    expect(scanned, isNotNull);
    expect(scanned!.courtesy, DriverPersonalQrCourtesy.other);
    expect(scanned.nome, 'Antonio');
    expect(scanned.cognome, 'Privitera');
    expect(scanned.indirizzo, 'Via Cantonale 12');
    expect(scanned.zip, '6900');
    expect(scanned.city, 'Lugano');
    expect(scanned.country, 'CH');
    expect(scanned.telefono, '+41 79 123 45 67');
    expect(scanned.email, _account.email);
    expect(scanned.targa, _primaryVehicle.targa);
    expect(scanned.vin, _primaryVehicle.vin);
    expect(scanned.assicurazione, _primaryVehicle.assicurazione);
    expect(scanned.numeroPolizza, _primaryVehicle.numeroPolizza);
    expect(scanned.numeroSinistro, _primaryVehicle.numeroSinistro);
    expect(find.byType(QrImageView), findsWidgets);

    final storedVehicles = prefs.getString(PersonalVehicleStorage.storageKey);
    expect(storedVehicles, jsonEncode(_vehicleCollection.toMap()));
  });

  testWidgets('reopening the QR uses the newly saved customer_profile values',
      (tester) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeCustomerAuthService(
      account: _account,
      profile: _completeProfile,
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(_app(service, screenKey: const ValueKey('first')));
    await tester.pumpAndSettle();

    service.profile = _completeProfile.copyWith(
      firstName: 'Antonio aggiornato',
      street: 'Nuova strada 99',
      phone: '+41 91 999 99 99',
    );
    await tester.pumpWidget(
      _app(service, screenKey: const ValueKey('reopened')),
    );
    await tester.pumpAndSettle();

    expect(service.loadProfileCalls, 2);
    expect(
      _field(tester, 'personal_qr_customer_first_name').controller?.text,
      'Antonio aggiornato',
    );
    expect(
      _field(tester, 'personal_qr_customer_street').controller?.text,
      'Nuova strada 99',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final payload = prefs.getString('driver_personal_qr_generated_v1');
    expect(payload, isNotNull);
    final scanned = driverPersonalQrDataFromQrPayload(
      payload!,
    );
    expect(scanned?.nome, 'Antonio aggiornato');
    expect(scanned?.indirizzo, 'Nuova strada 99');
    expect(scanned?.telefono, '+41 91 999 99 99');
    expect(scanned?.targa, _primaryVehicle.targa);
    expect(
      prefs.getString(PersonalVehicleStorage.storageKey),
      jsonEncode(_vehicleCollection.toMap()),
    );
  });

  testWidgets(
      'incomplete customer_profile lists missing data and links profile',
      (tester) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeCustomerAuthService(
      account: _account,
      profile: _completeProfile.copyWith(
        street: '',
        postalCode: '',
        phone: '',
      ),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('personal_qr_profile_incomplete')),
      findsOneWidget,
    );
    final incompleteBanner =
        find.byKey(const Key('personal_qr_profile_incomplete'));
    expect(
      find.descendant(
        of: incompleteBanner,
        matching: find.textContaining('Strasse, PLZ, Telefon'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('personal_qr_edit_profile')),
    );
    await tester.tap(find.byKey(const Key('personal_qr_edit_profile')));
    await tester.pumpAndSettle();

    expect(find.text('Profil und Einstellungen'), findsWidgets);
    expect(find.byKey(const Key('profile_save')), findsOneWidget);
  });
}
