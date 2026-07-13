import 'dart:convert';

import 'package:cid_digitale/models/driver_personal_qr_data.dart';
import 'package:cid_digitale/models/personal_vehicle_data.dart';
import 'package:cid_digitale/services/personal_vehicle_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DriverPersonalQrData profileWithVehicle({
  String plate = 'TI12345',
  String brand = 'Volvo',
}) {
  return DriverPersonalQrData(
    courtesy: null,
    nome: 'Test',
    cognome: 'Person',
    indirizzo: '',
    zip: '',
    city: '',
    country: '',
    telefono: '',
    email: '',
    targa: plate,
    marca: brand,
    modello: 'XC40',
    vin: 'VIN123',
    kilometraggio: '42000',
    primaImmatricolazione: '2022',
    assicurazione: 'AXA',
    numeroPolizza: 'POL-1',
    numeroSinistro: 'SIN-1',
    customerNumber: '',
  );
}

PersonalVehicleData vehicle(String id, String plate) => PersonalVehicleData(
      id: id,
      targa: plate,
      marca: 'Brand $id',
      modello: 'Model $id',
      vin: 'VIN-$id',
      kilometraggio: '1000',
      primaImmatricolazione: '2024',
      assicurazione: 'Insurance $id',
      numeroPolizza: 'POL-$id',
      numeroSinistro: 'CLAIM-$id',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('vehicle model round-trips every supported field', () {
    final original = vehicle('one', 'TI12345');
    final restored = PersonalVehicleData.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.targa, original.targa);
    expect(restored.marca, original.marca);
    expect(restored.modello, original.modello);
    expect(restored.vin, original.vin);
    expect(restored.kilometraggio, original.kilometraggio);
    expect(restored.primaImmatricolazione, original.primaImmatricolazione);
    expect(restored.assicurazione, original.assicurazione);
    expect(restored.numeroPolizza, original.numeroPolizza);
    expect(restored.numeroSinistro, original.numeroSinistro);
  });

  test('migrates the legacy QR vehicle once and makes it primary', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PersonalVehicleStorage.legacyProfileKey,
      driverPersonalQrDataToJson(profileWithVehicle()),
    );
    final storage = PersonalVehicleStorage(preferences: prefs);

    final migrated = await storage.loadOrMigrate();
    expect(migrated.vehicles, hasLength(1));
    expect(migrated.primaryVehicleId, 'legacy_vehicle');
    expect(migrated.primaryVehicle?.targa, 'TI12345');

    await prefs.setString(
      PersonalVehicleStorage.legacyProfileKey,
      driverPersonalQrDataToJson(
        profileWithVehicle(plate: 'ZH999999', brand: 'Changed'),
      ),
    );
    final loadedAgain = await storage.loadOrMigrate();
    expect(loadedAgain.vehicles, hasLength(1));
    expect(loadedAgain.primaryVehicle?.targa, 'TI12345');
  });

  test('persists edits, primary selection and deletion', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = PersonalVehicleStorage(preferences: prefs);
    final first = vehicle('first', 'TI11111');
    final second = vehicle('second', 'TI22222');

    var collection =
        const PersonalVehicleCollection.empty().upsert(first).upsert(second);
    await storage.save(collection);

    collection = collection.setPrimary(second.id);
    await storage.save(collection);
    var restored = await storage.load();
    expect(restored.primaryVehicle?.id, second.id);

    final edited = PersonalVehicleData.fromMap({
      ...second.toMap(),
      'plate': 'TI33333',
    });
    collection = restored.upsert(edited);
    await storage.save(collection);
    restored = await storage.load();
    expect(restored.primaryVehicle?.targa, 'TI33333');

    collection = restored.remove(second.id);
    await storage.save(collection);
    restored = await storage.load();
    expect(restored.vehicles, hasLength(1));
    expect(restored.primaryVehicle?.id, first.id);
  });

  test('primary vehicle projects into the unchanged QR v1 structure', () {
    final profile = profileWithVehicle(plate: 'OLD');
    final selected = vehicle('selected', 'TI77777');
    final payload = jsonDecode(
      driverPersonalQrDataToJson(selected.applyToProfile(profile)),
    ) as Map<String, dynamic>;

    expect(payload['type'], DriverPersonalQrData.qrType);
    expect(payload['version'], DriverPersonalQrData.qrVersion);
    expect((payload['vehicle'] as Map)['plate'], 'TI77777');
    expect((payload['insurance'] as Map)['company'], selected.assicurazione);
    expect(payload.containsKey('vehicles'), isFalse);
  });
}
