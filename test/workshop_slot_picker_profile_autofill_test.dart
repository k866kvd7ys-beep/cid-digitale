import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/models/personal_vehicle_data.dart';
import 'package:cid_digitale/models/workshop_model.dart';
import 'package:cid_digitale/screens/service/workshop_slot_picker_screen.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:cid_digitale/services/personal_vehicle_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fake_customer_auth_service.dart';
import 'helpers/fake_personal_vehicle_remote_data_source.dart';

const _account = CustomerAccount(
  id: 'booking-customer',
  email: 'antonio.privitera@example.com',
  role: customerRole,
  firstName: 'Antonio',
  lastName: 'Privitera',
);

const _completeProfile = CustomerProfile(
  userId: 'booking-customer',
  title: 'mr',
  firstName: 'Antonio',
  lastName: 'Privitera',
  street: 'Via Cantonale 12',
  postalCode: '6900',
  city: 'Lugano',
  country: 'CH',
  phone: '+41 79 123 45 67',
  email: 'profile-copy@example.com',
  profileCompleted: true,
);

const _incompleteProfile = CustomerProfile(
  userId: 'booking-customer',
  title: '',
  firstName: '',
  lastName: 'Privitera',
  street: '',
  postalCode: '6900',
  city: '',
  country: 'CH',
  phone: '',
  email: 'profile-copy@example.com',
  profileCompleted: false,
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
  numeroSinistro: '',
);

const _primaryVehicle = PersonalVehicleData(
  id: 'vehicle-primary',
  targa: 'TI22222',
  marca: 'BMW',
  modello: 'X3',
  vin: 'VIN-TWO',
  kilometraggio: '71000',
  primaImmatricolazione: '2020',
  assicurazione: 'Allianz',
  numeroPolizza: 'POL-TWO',
  numeroSinistro: '',
);

const _bookingVehicle = PersonalVehicleData(
  id: 'vehicle-booking',
  targa: 'AG399854',
  marca: 'Audi',
  modello: 'e-tron',
  vin: 'VIN-BOOKING',
  kilometraggio: '24000',
  primaImmatricolazione: '2023',
  assicurazione: 'Zurich',
  numeroPolizza: 'POL-BOOKING',
  numeroSinistro: '',
);

const _workshop = WorkshopModel(
  id: 'workshop-one',
  name: 'Garage Lugano',
  email: 'garage@example.com',
  phone: '+41 91 000 00 00',
  address: 'Via Officina 1',
  city: 'Lugano',
  rating: 4.8,
  distanceKm: 2.3,
);

class _FakeAppointmentRequestsService extends AppointmentRequestsService {
  _FakeAppointmentRequestsService()
      : super(
          client: SupabaseClient(
            'https://booking-test.supabase.co',
            'booking-test-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<List<DateTime>> fetchBookedSlots({
    required String serviceKey,
    required DateTime day,
  }) async {
    return const [];
  }
}

class _RecordingAppointmentRequestsService
    implements AppointmentRequestsService {
  final Completer<AppointmentRequest> _pendingRequest =
      Completer<AppointmentRequest>();
  Map<Symbol, dynamic>? createRequestArguments;
  AppointmentRequest? createdRequest;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #fetchBookedSlots) {
      return Future<List<DateTime>>.value(const []);
    }
    if (invocation.memberName == #createRequest) {
      final arguments = invocation.namedArguments;
      createRequestArguments = arguments;
      final timestamp = DateTime.utc(2026, 8, 29, 12);
      final request = AppointmentRequest(
        id: 'request-booking',
        createdAt: timestamp,
        updatedAt: timestamp,
        serviceType: arguments[#serviceType] as String,
        appointmentDate: arguments[#appointmentDate] as DateTime,
        appointmentTime: arguments[#appointmentTime] as String,
        durationMinutes: arguments[#durationMinutes] as int,
        customerName: arguments[#customerName] as String?,
        customerPhone: arguments[#phone] as String?,
        customerEmail: arguments[#email] as String?,
        licensePlate: arguments[#licensePlate] as String?,
        vehicleBrand: arguments[#vehicleBrand] as String?,
        vehicleModel: arguments[#vehicleModel] as String?,
        insurance: arguments[#insurance] as String?,
        policyNumber: arguments[#policyNumber] as String?,
        garageId: arguments[#garageId] as String?,
        garageName: arguments[#garageName] as String?,
        garageEmail: arguments[#garageEmail] as String?,
        garagePhone: arguments[#garagePhone] as String?,
        garageAddress: arguments[#garageAddress] as String?,
        garageCity: arguments[#garageCity] as String?,
        status: 'pending',
        locale: arguments[#locale] as String?,
      );
      createdRequest = request;
      return _pendingRequest.future;
    }
    return super.noSuchMethod(invocation);
  }
}

PersonalVehicleRepository _repository(
  FakePersonalVehicleRemoteDataSource remote,
) {
  return PersonalVehicleRepository(remoteDataSource: remote);
}

Widget _app({
  required FakeCustomerAuthService authService,
  required PersonalVehicleRepository vehicleRepository,
  required AppointmentRequestsService appointmentService,
  Locale locale = const Locale('it'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(useMaterial3: true),
    home: WorkshopSlotPickerScreen(
      title: 'Servizio officina',
      serviceType: 'service_inspection',
      selectedWorkshop: _workshop,
      customerAuthService: authService,
      personalVehicleRepository: vehicleRepository,
      appointmentRequestsService: appointmentService,
    ),
  );
}

Future<void> _pumpBooking(
  WidgetTester tester, {
  required FakeCustomerAuthService authService,
  required PersonalVehicleRepository vehicleRepository,
  AppointmentRequestsService? appointmentService,
  Locale locale = const Locale('it'),
  Size physicalSize = const Size(900, 2200),
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _app(
      authService: authService,
      vehicleRepository: vehicleRepository,
      appointmentService:
          appointmentService ?? _FakeAppointmentRequestsService(),
      locale: locale,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _useProfile(WidgetTester tester) async {
  final button = find.byKey(const Key('booking_use_profile_button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

String _fieldValue(WidgetTester tester, String key) {
  return tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
}

List<String> _vehicleSelectorLabels(WidgetTester tester) {
  final dropdown = tester.widget<DropdownButton<String>>(
    find.descendant(
      of: find.byKey(const Key('booking_vehicle_selector')),
      matching: find.byType(DropdownButton<String>),
    ),
  );
  return dropdown.items!
      .map((item) => (item.child as Text).data!)
      .toList(growable: false);
}

void _expectNoRemoteMutations(FakePersonalVehicleRemoteDataSource remote) {
  expect(remote.insertVehiclesCalls, 0);
  expect(remote.insertVehicleCalls, 0);
  expect(remote.updateVehicleCalls, 0);
  expect(remote.setPrimaryCalls, 0);
  expect(remote.deleteCalls, 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'complete profile and one vehicle fill editable booking fields below workshop card',
      (tester) async {
    final auth = FakeCustomerAuthService(
      account: _account,
      profile: _completeProfile,
    );
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: _account.id,
    )..seed(
        _account.id,
        const PersonalVehicleCollection(
          primaryVehicleId: 'vehicle-one',
          vehicles: [_firstVehicle],
        ),
      );
    addTearDown(auth.dispose);

    await _pumpBooking(
      tester,
      authService: auth,
      vehicleRepository: _repository(remote),
      physicalSize: const Size(390, 2400),
    );

    final overview = find.byKey(const Key('booking_workshop_overview_card'));
    final profileButton = find.byKey(const Key('booking_use_profile_button'));
    final plateCard = find.byKey(const Key('booking_license_plate_card'));
    expect(tester.getBottomLeft(overview).dy,
        lessThan(tester.getTopLeft(profileButton).dy));
    expect(tester.getBottomLeft(profileButton).dy,
        lessThan(tester.getTopLeft(plateCard).dy));

    await _useProfile(tester);

    expect(auth.loadProfileCalls, 1);
    expect(_fieldValue(tester, 'booking_name_field'), 'Antonio Privitera');
    expect(_fieldValue(tester, 'booking_phone_field'), '+41 79 123 45 67');
    expect(_fieldValue(tester, 'booking_email_field'), _account.email);
    expect(_fieldValue(tester, 'booking_plate_field'), _firstVehicle.targa);
    expect(find.byKey(const Key('booking_vehicle_selector')), findsNothing);
    expect(
      find.text(
        'I dati del profilo sono stati inseriti nella prenotazione.',
      ),
      findsOneWidget,
    );

    final nameRect =
        tester.getRect(find.byKey(const Key('booking_name_field')));
    final phoneRect =
        tester.getRect(find.byKey(const Key('booking_phone_field')));
    final emailRect =
        tester.getRect(find.byKey(const Key('booking_email_field')));
    expect(phoneRect.width, closeTo(nameRect.width, 0.01));
    expect(emailRect.width, closeTo(nameRect.width, 0.01));
    expect(phoneRect.top, greaterThan(nameRect.bottom));
    expect(emailRect.top, greaterThan(phoneRect.bottom));

    await tester.enterText(
      find.byKey(const Key('booking_name_field')),
      'Nome modificato solo per la prenotazione',
    );
    await tester.enterText(
      find.byKey(const Key('booking_plate_field')),
      'TI99999',
    );
    await tester.enterText(
      find.byKey(const Key('booking_phone_field')),
      '+41 79 999 99 99',
    );
    await tester.enterText(
      find.byKey(const Key('booking_email_field')),
      'prenotazione@example.com',
    );
    expect(
      _fieldValue(tester, 'booking_name_field'),
      'Nome modificato solo per la prenotazione',
    );
    expect(_fieldValue(tester, 'booking_plate_field'), 'TI99999');
    expect(_fieldValue(tester, 'booking_phone_field'), '+41 79 999 99 99');
    expect(
      _fieldValue(tester, 'booking_email_field'),
      'prenotazione@example.com',
    );
    expect(auth.saveProfileCalls, 0);
    _expectNoRemoteMutations(remote);
  });

  testWidgets(
      'multiple vehicles preselect primary and local selection updates only booking plate',
      (tester) async {
    final auth = FakeCustomerAuthService(
      account: _account,
      profile: _completeProfile,
    );
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: _account.id,
    )..seed(
        _account.id,
        const PersonalVehicleCollection(
          primaryVehicleId: 'vehicle-primary',
          vehicles: [_firstVehicle, _primaryVehicle],
        ),
      );
    final rowsBefore = jsonEncode(remote.rowsFor(_account.id));
    addTearDown(auth.dispose);

    await _pumpBooking(
      tester,
      authService: auth,
      vehicleRepository: _repository(remote),
    );
    await _useProfile(tester);

    expect(_fieldValue(tester, 'booking_plate_field'), _primaryVehicle.targa);
    final selector = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('booking_vehicle_selector')),
    );
    expect(selector.initialValue, _primaryVehicle.id);
    expect(
      _vehicleSelectorLabels(tester),
      const ['Volvo XC40', 'BMW X3 · Veicolo principale'],
    );
    expect(
      _vehicleSelectorLabels(tester).join(' '),
      isNot(contains(_firstVehicle.targa)),
    );
    expect(
      _vehicleSelectorLabels(tester).join(' '),
      isNot(contains(_primaryVehicle.targa)),
    );

    selector.onChanged!.call(_firstVehicle.id);
    await tester.pump();

    expect(_fieldValue(tester, 'booking_plate_field'), _firstVehicle.targa);
    expect(jsonEncode(remote.rowsFor(_account.id)), rowsBefore);
    expect(auth.saveProfileCalls, 0);
    _expectNoRemoteMutations(remote);
  });

  testWidgets(
      'selected saved vehicle reaches summary and AppointmentRequest with normalized plate',
      (tester) async {
    final auth = FakeCustomerAuthService(
      account: _account,
      profile: _completeProfile,
    );
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: _account.id,
    )..seed(
        _account.id,
        const PersonalVehicleCollection(
          primaryVehicleId: 'vehicle-booking',
          vehicles: [_bookingVehicle],
        ),
      );
    final appointmentService = _RecordingAppointmentRequestsService();
    addTearDown(auth.dispose);

    await _pumpBooking(
      tester,
      authService: auth,
      vehicleRepository: _repository(remote),
      appointmentService: appointmentService,
      physicalSize: const Size(390, 5200),
    );
    await _useProfile(tester);

    expect(_fieldValue(tester, 'booking_plate_field'), 'AG399854');
    await tester.enterText(
      find.byKey(const Key('booking_plate_field')),
      'AG 399854',
    );
    await tester.pump();
    expect(find.text('Audi e-tron'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('booking_plate_field')),
      'AG399854',
    );
    await tester.pump();

    expect(find.text('Marca e modello'), findsOneWidget);
    expect(find.text('Audi e-tron'), findsOneWidget);
    expect(find.text('AG399854'), findsWidgets);

    final firstSlot = find.widgetWithText(OutlinedButton, '08:00');
    tester.widget<OutlinedButton>(firstSlot).onPressed!.call();
    tester.widget<Checkbox>(find.byType(Checkbox).last).onChanged!.call(true);
    await tester.pump();

    final submitButton = find.ancestor(
      of: find.byKey(const ValueKey('submit_idle')),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(submitButton).onTap!.call();
    await tester.pump();

    expect(appointmentService.createRequestArguments?[#vehicleBrand], 'Audi');
    expect(
      appointmentService.createRequestArguments?[#vehicleModel],
      'e-tron',
    );
    expect(
      appointmentService.createRequestArguments?[#insurance],
      'Zurich',
    );
    expect(
      appointmentService.createRequestArguments?[#policyNumber],
      'POL-BOOKING',
    );
    expect(
      appointmentService.createRequestArguments?[#licensePlate],
      'AG399854',
    );
    expect(
      appointmentService.createRequestArguments?[#phone],
      '+41 79 123 45 67',
    );
    expect(appointmentService.createdRequest?.vehicleBrand, 'Audi');
    expect(appointmentService.createdRequest?.vehicleModel, 'e-tron');
    expect(appointmentService.createdRequest?.licensePlate, 'AG399854');
    expect(
      appointmentService.createdRequest?.customerPhone,
      '+41 79 123 45 67',
    );
    _expectNoRemoteMutations(remote);
  });

  testWidgets('incomplete profile fills available data and offers profile link',
      (tester) async {
    final auth = FakeCustomerAuthService(
      account: _account,
      profile: _incompleteProfile,
    );
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: _account.id,
    )..seed(
        _account.id,
        const PersonalVehicleCollection(
          primaryVehicleId: 'vehicle-one',
          vehicles: [_firstVehicle],
        ),
      );
    addTearDown(auth.dispose);

    await _pumpBooking(
      tester,
      authService: auth,
      vehicleRepository: _repository(remote),
    );
    await _useProfile(tester);

    expect(_fieldValue(tester, 'booking_name_field'), 'Privitera');
    expect(_fieldValue(tester, 'booking_phone_field'), isEmpty);
    expect(_fieldValue(tester, 'booking_email_field'), _account.email);
    expect(_fieldValue(tester, 'booking_plate_field'), _firstVehicle.targa);
    expect(find.textContaining('Dati mancanti nel profilo:'), findsOneWidget);
    expect(find.textContaining('Nome'), findsWidgets);
    expect(find.textContaining('Telefono'), findsWidgets);
    expect(
      find.byKey(const Key('booking_edit_profile_button')),
      findsOneWidget,
    );
    expect(find.text('Profilo e impostazioni'), findsOneWidget);
    expect(auth.saveProfileCalls, 0);
    _expectNoRemoteMutations(remote);
  });

  testWidgets('no vehicles fills customer data and shows no-vehicle message',
      (tester) async {
    final auth = FakeCustomerAuthService(
      account: _account,
      profile: _completeProfile,
    );
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: _account.id,
    );
    addTearDown(auth.dispose);

    await _pumpBooking(
      tester,
      authService: auth,
      vehicleRepository: _repository(remote),
    );
    await _useProfile(tester);

    expect(_fieldValue(tester, 'booking_name_field'), 'Antonio Privitera');
    expect(_fieldValue(tester, 'booking_phone_field'), '+41 79 123 45 67');
    expect(_fieldValue(tester, 'booking_email_field'), _account.email);
    expect(_fieldValue(tester, 'booking_plate_field'), isEmpty);
    expect(
      find.text('Aggiungi o seleziona un veicolo per compilare la targa.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'I dati del profilo sono stati inseriti nella prenotazione.',
      ),
      findsNothing,
    );
    expect(auth.saveProfileCalls, 0);
    _expectNoRemoteMutations(remote);
  });

  testWidgets('vehicle load failure shows error without false success',
      (tester) async {
    final auth = FakeCustomerAuthService(
      account: _account,
      profile: _completeProfile,
    );
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: _account.id,
    )..loadError = StateError('network unavailable');
    addTearDown(auth.dispose);

    await _pumpBooking(
      tester,
      authService: auth,
      vehicleRepository: _repository(remote),
    );
    await _useProfile(tester);

    expect(_fieldValue(tester, 'booking_name_field'), isEmpty);
    expect(_fieldValue(tester, 'booking_phone_field'), isEmpty);
    expect(_fieldValue(tester, 'booking_email_field'), isEmpty);
    expect(_fieldValue(tester, 'booking_plate_field'), isEmpty);
    expect(
      find.text(
        'Non è stato possibile caricare il profilo e i veicoli. Riprova.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'I dati del profilo sono stati inseriti nella prenotazione.',
      ),
      findsNothing,
    );
    expect(auth.saveProfileCalls, 0);
    _expectNoRemoteMutations(remote);
  });

  testWidgets('use-profile button has all four required translations',
      (tester) async {
    final translations = <Locale, (String, String)>{
      const Locale('it'): ('Usa il mio profilo', 'Veicolo principale'),
      const Locale('de'): ('Mein Profil verwenden', 'Hauptfahrzeug'),
      const Locale('fr'): ('Utiliser mon profil', 'Véhicule principal'),
      const Locale('en'): ('Use my profile', 'Primary vehicle'),
    };

    for (final entry in translations.entries) {
      final auth = FakeCustomerAuthService(
        account: _account,
        profile: _completeProfile,
      );
      final remote = FakePersonalVehicleRemoteDataSource(
        authenticatedUserId: _account.id,
      )..seed(
          _account.id,
          const PersonalVehicleCollection(
            primaryVehicleId: 'vehicle-primary',
            vehicles: [_firstVehicle, _primaryVehicle],
          ),
        );

      await _pumpBooking(
        tester,
        authService: auth,
        vehicleRepository: _repository(remote),
        locale: entry.key,
      );
      expect(find.text(entry.value.$1), findsOneWidget);
      await _useProfile(tester);
      expect(
        _vehicleSelectorLabels(tester),
        ['Volvo XC40', 'BMW X3 · ${entry.value.$2}'],
      );
      await auth.dispose();
    }
  });

  test('booking submission contract and workshop routing remain unchanged', () {
    final source = File(
      'lib/screens/service/workshop_slot_picker_screen.dart',
    ).readAsStringSync();

    expect(source, contains('customerName: _nameCtrl.text.trim(),'));
    expect(source, contains('phone: _phoneCtrl.text.trim(),'));
    expect(source, contains('email: _emailCtrl.text.trim(),'));
    expect(source, contains('licensePlate: _plateCtrl.text.trim(),'));
    expect(source, contains('vehicleBrand: selectedVehicle?.marca.trim(),'));
    expect(source, contains('vehicleModel: selectedVehicle?.modello.trim(),'));
    expect(
      source,
      contains('insurance: selectedVehicle?.assicurazione.trim(),'),
    );
    expect(
      source,
      contains('policyNumber: selectedVehicle?.numeroPolizza.trim(),'),
    );
    expect(source, contains('garageId: widget.selectedWorkshop?.id,'));
    expect(source, contains('garageName: widget.selectedWorkshop?.name,'));
    expect(source, isNot(contains('_customerAuthService.saveProfile(')));
    expect(source, isNot(contains('_personalVehicleRepository.saveVehicle(')));
    expect(
      source,
      isNot(contains('_personalVehicleRepository.setPrimaryVehicle(')),
    );
  });
}
