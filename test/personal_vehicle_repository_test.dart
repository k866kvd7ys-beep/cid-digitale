import 'dart:convert';

import 'package:cid_digitale/models/personal_vehicle_data.dart';
import 'package:cid_digitale/services/personal_vehicle_repository.dart';
import 'package:cid_digitale/services/personal_vehicle_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_personal_vehicle_remote_data_source.dart';

const userOne = 'customer-user-one';
const userTwo = 'customer-user-two';

PersonalVehicleData vehicle(
  String id,
  String plate, {
  String brand = 'Volvo',
  String model = 'XC40',
}) {
  return PersonalVehicleData(
    id: id,
    targa: plate,
    marca: brand,
    modello: model,
    vin: 'VIN-$id',
    kilometraggio: '42000',
    primaImmatricolazione: '2022',
    assicurazione: 'AXA',
    numeroPolizza: 'POL-$id',
    numeroSinistro: 'CLAIM-$id',
  );
}

Future<PersonalVehicleRepository> repositoryFor(
  FakePersonalVehicleRemoteDataSource remote,
) async {
  final preferences = await SharedPreferences.getInstance();
  return PersonalVehicleRepository(
    remoteDataSource: remote,
    localStorage: PersonalVehicleStorage(preferences: preferences),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('authenticated user without vehicles receives a confirmed empty list',
      () async {
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    );
    final repository = await repositoryFor(remote);

    final result = await repository.loadForUser(userOne);

    expect(result.vehicles, isEmpty);
    expect(remote.loadCalls, 1);
    expect(remote.insertVehiclesCalls, 0);
    final metadata = await PersonalVehicleStorage().loadCacheMetadata();
    expect(metadata?.userId, userOne);
    expect(metadata?.importCompleted, isTrue);
  });

  test('first added vehicle is automatically primary', () async {
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    );
    final repository = await repositoryFor(remote);
    final empty = await repository.loadForUser(userOne);
    final first = vehicle('vehicle-one', 'TI11111');

    final result = await repository.saveVehicle(
      userId: userOne,
      vehicle: first,
      currentCollection: empty,
    );

    expect(result.vehicles.map((item) => item.id), [first.id]);
    expect(result.primaryVehicleId, first.id);
    expect(
      remote.rowsFor(userOne).where((row) => row['is_primary'] == true),
      hasLength(1),
    );
  });

  test('two vehicles persist after refresh and in a new browser cache',
      () async {
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    );
    var repository = await repositoryFor(remote);
    var collection = await repository.loadForUser(userOne);
    final first = vehicle('vehicle-one', 'TI11111');
    final second = vehicle('vehicle-two', 'TI22222', brand: 'BMW', model: 'X3');

    collection = await repository.saveVehicle(
      userId: userOne,
      vehicle: first,
      currentCollection: collection,
    );
    collection = await repository.saveVehicle(
      userId: userOne,
      vehicle: second,
      currentCollection: collection,
    );
    expect(collection.vehicles, hasLength(2));

    repository = await repositoryFor(remote);
    expect(
      (await repository.loadForUser(userOne)).vehicles,
      hasLength(2),
    );

    SharedPreferences.setMockInitialValues({});
    repository = await repositoryFor(remote);
    final fromNewBrowser = await repository.loadForUser(userOne);
    expect(fromNewBrowser.vehicles.map((item) => item.id), {
      first.id,
      second.id,
    });
    expect(fromNewBrowser.primaryVehicleId, first.id);
  });

  test('editing updates the same remote record without creating duplicates',
      () async {
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    );
    final repository = await repositoryFor(remote);
    var collection = await repository.loadForUser(userOne);
    final original = vehicle('vehicle-one', 'TI11111');
    collection = await repository.saveVehicle(
      userId: userOne,
      vehicle: original,
      currentCollection: collection,
    );
    final edited = PersonalVehicleData.fromMap({
      ...original.toMap(),
      'plate': 'TI99999',
      'brand': 'Audi',
    });

    collection = await repository.saveVehicle(
      userId: userOne,
      vehicle: edited,
      currentCollection: collection,
    );

    expect(collection.vehicles, hasLength(1));
    expect(collection.vehicles.single.id, original.id);
    expect(collection.vehicles.single.targa, 'TI99999');
    expect(remote.rowsFor(userOne), hasLength(1));
    expect(remote.updateVehicleCalls, 1);
  });

  test('deleting only the selected non-primary vehicle persists', () async {
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    );
    final repository = await repositoryFor(remote);
    var collection = await repository.loadForUser(userOne);
    final first = vehicle('vehicle-one', 'TI11111');
    final second = vehicle('vehicle-two', 'TI22222');
    collection = await repository.saveVehicle(
      userId: userOne,
      vehicle: first,
      currentCollection: collection,
    );
    collection = await repository.saveVehicle(
      userId: userOne,
      vehicle: second,
      currentCollection: collection,
    );

    collection = await repository.deleteVehicle(
      userId: userOne,
      vehicleId: second.id,
    );

    expect(collection.vehicles.map((item) => item.id), [first.id]);
    expect(collection.primaryVehicleId, first.id);
    expect(remote.deleteCalls, 1);
  });

  test('deleting the primary promotes the oldest remaining vehicle', () async {
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    );
    final repository = await repositoryFor(remote);
    var collection = await repository.loadForUser(userOne);
    final oldest = vehicle('oldest', 'TI11111');
    final second = vehicle('second', 'TI22222');
    final newest = vehicle('newest', 'TI33333');
    for (final item in [oldest, second, newest]) {
      collection = await repository.saveVehicle(
        userId: userOne,
        vehicle: item,
        currentCollection: collection,
      );
    }
    collection = await repository.setPrimaryVehicle(
      userId: userOne,
      vehicleId: newest.id,
    );
    expect(collection.primaryVehicleId, newest.id);

    collection = await repository.deleteVehicle(
      userId: userOne,
      vehicleId: newest.id,
    );

    expect(collection.vehicles, hasLength(2));
    expect(collection.primaryVehicleId, oldest.id);
  });

  test('primary selection remains after repository recreation', () async {
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    );
    var repository = await repositoryFor(remote);
    var collection = await repository.loadForUser(userOne);
    final first = vehicle('vehicle-one', 'TI11111');
    final second = vehicle('vehicle-two', 'TI22222');
    for (final item in [first, second]) {
      collection = await repository.saveVehicle(
        userId: userOne,
        vehicle: item,
        currentCollection: collection,
      );
    }

    collection = await repository.setPrimaryVehicle(
      userId: userOne,
      vehicleId: second.id,
    );
    repository = await repositoryFor(remote);
    final reloaded = await repository.loadForUser(userOne);

    expect(collection.primaryVehicleId, second.id);
    expect(reloaded.primaryVehicleId, second.id);
    expect(
      remote.rowsFor(userOne).where((row) => row['is_primary'] == true),
      hasLength(1),
    );
  });

  test('logout and login reload remote data without cross-account import',
      () async {
    final first = vehicle('vehicle-one', 'TI11111');
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    )..seed(
        userOne,
        PersonalVehicleCollection(
          primaryVehicleId: first.id,
          vehicles: [first],
        ),
      );
    var repository = await repositoryFor(remote);
    expect(
      (await repository.loadForUser(userOne)).primaryVehicleId,
      first.id,
    );

    remote.authenticatedUserId = userTwo;
    repository = await repositoryFor(remote);
    final secondUser = await repository.loadForUser(userTwo);
    expect(secondUser.vehicles, isEmpty);
    expect(remote.rowsFor(userTwo), isEmpty);

    remote.authenticatedUserId = userOne;
    repository = await repositoryFor(remote);
    final loggedInAgain = await repository.loadForUser(userOne);
    expect(loggedInAgain.primaryVehicleId, first.id);
  });

  test('legacy local vehicles are imported once and remain locally available',
      () async {
    final first = vehicle('vehicle-one', 'TI11111');
    final second = vehicle('vehicle-two', 'TI22222');
    final localCollection = PersonalVehicleCollection(
      primaryVehicleId: second.id,
      vehicles: [first, second],
    );
    SharedPreferences.setMockInitialValues({
      PersonalVehicleStorage.storageKey: jsonEncode(localCollection.toMap()),
    });
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    );
    var repository = await repositoryFor(remote);

    final imported = await repository.loadForUser(userOne);
    repository = await repositoryFor(remote);
    final reopened = await repository.loadForUser(userOne);

    expect(imported.vehicles, hasLength(2));
    expect(imported.primaryVehicleId, second.id);
    expect(reopened.vehicles, hasLength(2));
    expect(remote.insertVehiclesCalls, 1);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(PersonalVehicleStorage.storageKey),
      isNotNull,
    );
  });

  test('existing remote vehicles prevent import of stale local data', () async {
    final local = vehicle('local', 'LOCAL1');
    final remoteVehicle = vehicle('remote', 'REMOTE1');
    SharedPreferences.setMockInitialValues({
      PersonalVehicleStorage.storageKey: jsonEncode(
        PersonalVehicleCollection(
          primaryVehicleId: local.id,
          vehicles: [local],
        ).toMap(),
      ),
    });
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    )..seed(
        userOne,
        PersonalVehicleCollection(
          primaryVehicleId: remoteVehicle.id,
          vehicles: [remoteVehicle],
        ),
      );
    final repository = await repositoryFor(remote);

    final result = await repository.loadForUser(userOne);

    expect(result.vehicles.map((item) => item.id), [remoteVehicle.id]);
    expect(remote.insertVehiclesCalls, 0);
  });

  test('local import removes duplicate ids and normalized vehicle duplicates',
      () async {
    final first = vehicle('same-id', 'TI 12345');
    final duplicateId = vehicle('same-id', 'TI99999');
    final duplicateSignature =
        vehicle('other-id', 'ti-12345', brand: 'VOLVO', model: 'xc 40');
    final distinct = vehicle('distinct', 'ZH88888', brand: 'Audi', model: 'A4');
    final localCollection = PersonalVehicleCollection(
      primaryVehicleId: duplicateSignature.id,
      vehicles: [first, duplicateId, duplicateSignature, distinct],
    );
    SharedPreferences.setMockInitialValues({
      PersonalVehicleStorage.storageKey: jsonEncode(localCollection.toMap()),
    });
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    );
    final repository = await repositoryFor(remote);

    final result = await repository.loadForUser(userOne);

    expect(result.vehicles.map((item) => item.id), {
      first.id,
      distinct.id,
    });
    expect(
      remote.rowsFor(userOne).where((row) => row['is_primary'] == true),
      hasLength(1),
    );
  });

  test('network load error is not interpreted as an empty remote list',
      () async {
    final local = vehicle('local', 'TI11111');
    final encoded = jsonEncode(
      PersonalVehicleCollection(
        primaryVehicleId: local.id,
        vehicles: [local],
      ).toMap(),
    );
    SharedPreferences.setMockInitialValues({
      PersonalVehicleStorage.storageKey: encoded,
    });
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    )..loadError = StateError('network unavailable');
    final repository = await repositoryFor(remote);

    await expectLater(
      repository.loadForUser(userOne),
      throwsA(isA<StateError>()),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(PersonalVehicleStorage.storageKey),
      encoded,
    );
    expect(remote.insertVehiclesCalls, 0);
  });

  test('database import error preserves local vehicles for a later retry',
      () async {
    final local = vehicle('local', 'TI11111');
    final encoded = jsonEncode(
      PersonalVehicleCollection(
        primaryVehicleId: local.id,
        vehicles: [local],
      ).toMap(),
    );
    SharedPreferences.setMockInitialValues({
      PersonalVehicleStorage.storageKey: encoded,
    });
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    )..insertError = StateError('database rejected insert');
    final repository = await repositoryFor(remote);

    await expectLater(
      repository.loadForUser(userOne),
      throwsA(isA<StateError>()),
    );

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(PersonalVehicleStorage.storageKey),
      encoded,
    );
    expect(
      preferences.getString(PersonalVehicleStorage.cacheMetadataKey),
      isNull,
    );
    expect(remote.rowsFor(userOne), isEmpty);
  });

  test('repository rejects access for a different authenticated user',
      () async {
    final remote = FakePersonalVehicleRemoteDataSource(
      authenticatedUserId: userOne,
    );
    final repository = await repositoryFor(remote);

    await expectLater(
      repository.loadForUser(userTwo),
      throwsA(isA<StateError>()),
    );
    expect(remote.rowsFor(userOne), isEmpty);
    expect(remote.rowsFor(userTwo), isEmpty);
  });
}
