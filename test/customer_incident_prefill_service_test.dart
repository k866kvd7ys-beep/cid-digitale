import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/models/personal_vehicle_data.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:cid_digitale/services/customer_incident_prefill_service.dart';
import 'package:cid_digitale/services/personal_vehicle_repository.dart';
import 'package:cid_digitale/services/personal_vehicle_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_customer_auth_service.dart';
import 'helpers/fake_personal_vehicle_remote_data_source.dart';

const _userId = 'customer-prefill-user';
const _account = CustomerAccount(
  id: _userId,
  email: 'anna@example.com',
  role: customerRole,
);
const _profile = CustomerProfile(
  userId: _userId,
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
const _vehicle = PersonalVehicleData(
  id: 'vehicle-one',
  targa: 'TI12345',
  marca: 'Volvo',
  modello: 'XC40',
  vin: 'VIN-ONE',
  kilometraggio: '42000',
  primaImmatricolazione: '2022',
  assicurazione: 'AXA',
  numeroPolizza: 'POL-ONE',
  numeroSinistro: '',
);
const _staleCachedVehicle = PersonalVehicleData(
  id: 'vehicle-one',
  targa: 'TI00000',
  marca: 'Old',
  modello: 'Cache',
  vin: 'OLD-VIN',
  kilometraggio: '1',
  primaImmatricolazione: '2000',
  assicurazione: 'Old Insurance',
  numeroPolizza: 'OLD-POLICY',
  numeroSinistro: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads profile and vehicles without opening the personal QR page',
      () async {
    final auth = FakeCustomerAuthService(account: _account, profile: _profile);
    addTearDown(auth.dispose);
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: _userId,
    )..seed(
        _userId,
        const PersonalVehicleCollection(
          primaryVehicleId: 'vehicle-one',
          vehicles: [_vehicle],
        ),
      );
    final preferences = await SharedPreferences.getInstance();
    final service = CustomerIncidentPrefillService(
      authService: auth,
      vehicleRepository: PersonalVehicleRepository(
        remoteDataSource: remote,
        localStorage: PersonalVehicleStorage(preferences: preferences),
      ),
      localVehicleStorage: PersonalVehicleStorage(preferences: preferences),
      preferences: preferences,
    );

    final result = await service.load();
    final driver = result.driverDataForVehicle(result.vehicles.primaryVehicle);

    expect(auth.loadProfileCalls, 1);
    expect(remote.loadCalls, 1);
    expect(driver?.nome, 'Anna');
    expect(driver?.cognome, 'Bianchi');
    expect(driver?.marca, 'Volvo');
    expect(driver?.modello, 'XC40');
    expect(driver?.targa, 'TI12345');
    expect(driver?.assicurazione, 'AXA');
    expect(driver?.numeroPolizza, 'POL-ONE');
    expect(driver?.vin, 'VIN-ONE');
    expect(driver?.kilometraggio, '42000');
    expect(driver?.primaImmatricolazione, '2022');
  });

  test('backend vehicles replace an older scoped cache on page load', () async {
    final auth = FakeCustomerAuthService(account: _account, profile: _profile);
    addTearDown(auth.dispose);
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: _userId,
    )..seed(
        _userId,
        const PersonalVehicleCollection(
          primaryVehicleId: 'vehicle-one',
          vehicles: [_vehicle],
        ),
      );
    final preferences = await SharedPreferences.getInstance();
    final storage = PersonalVehicleStorage(preferences: preferences);
    await storage.saveCacheForUser(
      userId: _userId,
      collection: const PersonalVehicleCollection(
        primaryVehicleId: 'vehicle-one',
        vehicles: [_staleCachedVehicle],
      ),
      importCompleted: true,
    );
    final service = CustomerIncidentPrefillService(
      authService: auth,
      vehicleRepository: PersonalVehicleRepository(
        remoteDataSource: remote,
        localStorage: storage,
      ),
      localVehicleStorage: storage,
      preferences: preferences,
    );

    final result = await service.load();

    expect(remote.loadCalls, 1);
    expect(result.vehicles.primaryVehicle?.marca, 'Volvo');
    expect(result.vehicles.primaryVehicle?.targa, 'TI12345');
    expect((await storage.load()).primaryVehicle?.marca, 'Volvo');
  });

  test('scoped cache is used only as fallback when backend loading fails',
      () async {
    final auth = FakeCustomerAuthService(account: _account, profile: _profile);
    addTearDown(auth.dispose);
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: _userId,
    )..loadError = StateError('network unavailable');
    final preferences = await SharedPreferences.getInstance();
    final storage = PersonalVehicleStorage(preferences: preferences);
    await storage.saveCacheForUser(
      userId: _userId,
      collection: const PersonalVehicleCollection(
        primaryVehicleId: 'vehicle-one',
        vehicles: [_vehicle],
      ),
      importCompleted: true,
    );
    final service = CustomerIncidentPrefillService(
      authService: auth,
      vehicleRepository: PersonalVehicleRepository(
        remoteDataSource: remote,
        localStorage: storage,
      ),
      localVehicleStorage: storage,
      preferences: preferences,
    );

    final result = await service.load();

    expect(remote.loadCalls, 1);
    expect(result.vehicleLoadError, isNotNull);
    expect(result.vehicles.primaryVehicle?.marca, 'Volvo');
    expect(result.vehicles.primaryVehicle?.numeroPolizza, 'POL-ONE');
  });
}
