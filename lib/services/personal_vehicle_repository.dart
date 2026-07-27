import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/personal_vehicle_data.dart';
import 'personal_vehicle_storage.dart';

abstract interface class PersonalVehicleRemoteDataSource {
  Future<List<Map<String, dynamic>>> loadVehicles(String userId);

  Future<void> insertVehicles(
    String userId,
    List<Map<String, dynamic>> rows,
  );

  Future<void> insertVehicle(
    String userId,
    Map<String, dynamic> row,
  );

  Future<void> updateVehicle(
    String userId,
    String vehicleId,
    Map<String, dynamic> values,
  );

  Future<void> setPrimaryVehicle(String userId, String vehicleId);

  Future<void> deleteVehicle(String userId, String vehicleId);
}

class SupabasePersonalVehicleRemoteDataSource
    implements PersonalVehicleRemoteDataSource {
  SupabasePersonalVehicleRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  void _ensureAuthenticatedOwner(String userId) {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId != userId) {
      throw StateError('Authenticated customer does not match vehicle owner');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadVehicles(String userId) async {
    _ensureAuthenticatedOwner(userId);
    final response = await _client
        .from('customer_vehicles')
        .select()
        .eq('user_id', userId)
        .order('created_at')
        .order('vehicle_id');
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  @override
  Future<void> insertVehicles(
    String userId,
    List<Map<String, dynamic>> rows,
  ) async {
    _ensureAuthenticatedOwner(userId);
    if (rows.isEmpty) return;
    await _client.from('customer_vehicles').insert(rows);
  }

  @override
  Future<void> insertVehicle(
    String userId,
    Map<String, dynamic> row,
  ) async {
    _ensureAuthenticatedOwner(userId);
    await _client.from('customer_vehicles').insert(row);
  }

  @override
  Future<void> updateVehicle(
    String userId,
    String vehicleId,
    Map<String, dynamic> values,
  ) async {
    _ensureAuthenticatedOwner(userId);
    final response = await _client
        .from('customer_vehicles')
        .update(values)
        .eq('user_id', userId)
        .eq('vehicle_id', vehicleId)
        .select('vehicle_id');
    if ((response as List).isEmpty) {
      throw StateError('Customer vehicle was not found');
    }
  }

  @override
  Future<void> setPrimaryVehicle(String userId, String vehicleId) async {
    _ensureAuthenticatedOwner(userId);
    await _client.rpc(
      'set_customer_primary_vehicle',
      params: {'p_vehicle_id': vehicleId},
    );
  }

  @override
  Future<void> deleteVehicle(String userId, String vehicleId) async {
    _ensureAuthenticatedOwner(userId);
    await _client.rpc(
      'delete_customer_vehicle',
      params: {'p_vehicle_id': vehicleId},
    );
  }
}

class PersonalVehicleRepository {
  PersonalVehicleRepository({
    PersonalVehicleRemoteDataSource? remoteDataSource,
    PersonalVehicleStorage? localStorage,
  })  : _remoteDataSource =
            remoteDataSource ?? SupabasePersonalVehicleRemoteDataSource(),
        _localStorage = localStorage ?? PersonalVehicleStorage();

  final PersonalVehicleRemoteDataSource _remoteDataSource;
  final PersonalVehicleStorage _localStorage;

  Future<PersonalVehicleCollection> loadForUser(String userId) async {
    final normalizedUserId = _requireUserId(userId);
    final remoteRows = await _remoteDataSource.loadVehicles(normalizedUserId);
    if (remoteRows.isNotEmpty) {
      final collection = await _normalizeRemotePrimary(
        normalizedUserId,
        remoteRows,
      );
      await _cacheSafely(normalizedUserId, collection);
      return collection;
    }

    return _importLocalVehiclesIfEligible(normalizedUserId);
  }

  Future<PersonalVehicleCollection> saveVehicle({
    required String userId,
    required PersonalVehicleData vehicle,
    required PersonalVehicleCollection currentCollection,
  }) async {
    final normalizedUserId = _requireUserId(userId);
    if (vehicle.id.trim().isEmpty || !vehicle.hasAnyValue) {
      throw ArgumentError.value(vehicle, 'vehicle', 'Vehicle is not valid');
    }

    final exists = currentCollection.vehicles.any(
      (item) => item.id == vehicle.id,
    );
    if (exists) {
      await _remoteDataSource.updateVehicle(
        normalizedUserId,
        vehicle.id,
        _vehicleValues(vehicle),
      );
    } else {
      await _remoteDataSource.insertVehicle(
        normalizedUserId,
        _vehicleRow(
          normalizedUserId,
          vehicle,
          isPrimary: currentCollection.vehicles.isEmpty,
        ),
      );
    }

    return _reloadAndCache(normalizedUserId);
  }

  Future<PersonalVehicleCollection> setPrimaryVehicle({
    required String userId,
    required String vehicleId,
  }) async {
    final normalizedUserId = _requireUserId(userId);
    await _remoteDataSource.setPrimaryVehicle(
      normalizedUserId,
      vehicleId,
    );
    return _reloadAndCache(normalizedUserId);
  }

  Future<PersonalVehicleCollection> deleteVehicle({
    required String userId,
    required String vehicleId,
  }) async {
    final normalizedUserId = _requireUserId(userId);
    await _remoteDataSource.deleteVehicle(
      normalizedUserId,
      vehicleId,
    );
    return _reloadAndCache(normalizedUserId);
  }

  Future<PersonalVehicleCollection> _reloadAndCache(String userId) async {
    final rows = await _remoteDataSource.loadVehicles(userId);
    final collection = await _normalizeRemotePrimary(userId, rows);
    await _cacheSafely(userId, collection);
    return collection;
  }

  Future<PersonalVehicleCollection> _normalizeRemotePrimary(
    String userId,
    List<Map<String, dynamic>> rows,
  ) async {
    var collection = _collectionFromRows(rows);
    if (collection.vehicles.isEmpty) return collection;

    final hasRemotePrimary = rows.any((row) => row['is_primary'] == true);
    if (!hasRemotePrimary) {
      await _remoteDataSource.setPrimaryVehicle(
        userId,
        collection.vehicles.first.id,
      );
      final normalizedRows = await _remoteDataSource.loadVehicles(userId);
      collection = _collectionFromRows(normalizedRows);
    }
    return collection;
  }

  Future<PersonalVehicleCollection> _importLocalVehiclesIfEligible(
    String userId,
  ) async {
    PersonalVehicleCollection localCollection;
    PersonalVehicleCacheMetadata? metadata;
    bool metadataKeyExists;
    try {
      metadataKeyExists = await _localStorage.hasCacheMetadata();
      localCollection = await _localStorage.loadOrMigrate();
      metadata = await _localStorage.loadCacheMetadata();
    } catch (_) {
      return const PersonalVehicleCollection.empty();
    }

    if (metadataKeyExists && metadata == null) {
      return const PersonalVehicleCollection.empty();
    }
    if (metadata != null) {
      if (!metadata.matches(userId, localCollection) ||
          metadata.importCompleted) {
        if (metadata.importCompleted) {
          await _cacheSafely(
            userId,
            const PersonalVehicleCollection.empty(),
          );
        }
        return const PersonalVehicleCollection.empty();
      }
    }

    final sanitized = _sanitizeLocalCollection(localCollection);
    if (sanitized.vehicles.isEmpty) {
      await _cacheSafely(
        userId,
        const PersonalVehicleCollection.empty(),
      );
      return const PersonalVehicleCollection.empty();
    }

    final orderedVehicles = [
      sanitized.primaryVehicle!,
      ...sanitized.vehicles.where(
        (vehicle) => vehicle.id != sanitized.primaryVehicleId,
      ),
    ];
    final rows = orderedVehicles
        .map(
          (vehicle) => _vehicleRow(
            userId,
            vehicle,
            isPrimary: vehicle.id == sanitized.primaryVehicleId,
          ),
        )
        .toList(growable: false);

    await _remoteDataSource.insertVehicles(userId, rows);
    final confirmedRows = await _remoteDataSource.loadVehicles(userId);
    final confirmed = await _normalizeRemotePrimary(userId, confirmedRows);
    _verifyImportedVehicles(sanitized, confirmed);
    await _cacheSafely(userId, confirmed);
    return confirmed;
  }

  PersonalVehicleCollection _sanitizeLocalCollection(
    PersonalVehicleCollection source,
  ) {
    final vehicles = <PersonalVehicleData>[];
    final seenIds = <String>{};
    final seenSignatures = <String>{};

    for (final vehicle in source.vehicles) {
      final id = vehicle.id.trim();
      if (id.isEmpty || !vehicle.hasAnyValue || !seenIds.add(id)) continue;

      final signature = _normalizedVehicleSignature(vehicle);
      if (signature.isNotEmpty && !seenSignatures.add(signature)) continue;
      vehicles.add(vehicle);
    }

    if (vehicles.isEmpty) {
      return const PersonalVehicleCollection.empty();
    }
    final requestedPrimary = source.primaryVehicleId;
    final primaryId = vehicles.any(
      (vehicle) => vehicle.id == requestedPrimary,
    )
        ? requestedPrimary
        : vehicles.first.id;
    return PersonalVehicleCollection(
      primaryVehicleId: primaryId,
      vehicles: List.unmodifiable(vehicles),
    );
  }

  String _normalizedVehicleSignature(PersonalVehicleData vehicle) {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final plate = normalize(vehicle.targa);
    final brand = normalize(vehicle.marca);
    final model = normalize(vehicle.modello);
    if (plate.isEmpty && brand.isEmpty && model.isEmpty) return '';
    return '$plate|$brand|$model';
  }

  PersonalVehicleCollection _collectionFromRows(
    List<Map<String, dynamic>> rows,
  ) {
    final vehicles = <PersonalVehicleData>[];
    String primaryVehicleId = '';
    for (final row in rows) {
      final vehicle = _vehicleFromRow(row);
      if (vehicle.id.isEmpty || !vehicle.hasAnyValue) continue;
      vehicles.add(vehicle);
      if (primaryVehicleId.isEmpty && row['is_primary'] == true) {
        primaryVehicleId = vehicle.id;
      }
    }

    if (vehicles.isEmpty) {
      return const PersonalVehicleCollection.empty();
    }
    return PersonalVehicleCollection(
      primaryVehicleId:
          primaryVehicleId.isEmpty ? vehicles.first.id : primaryVehicleId,
      vehicles: List.unmodifiable(vehicles),
    );
  }

  PersonalVehicleData _vehicleFromRow(Map<String, dynamic> row) {
    String read(String key) => row[key]?.toString().trim() ?? '';
    return PersonalVehicleData(
      id: read('vehicle_id'),
      targa: read('plate'),
      marca: read('brand'),
      modello: read('model'),
      vin: read('vin'),
      kilometraggio: read('mileage'),
      primaImmatricolazione: read('first_registration'),
      assicurazione: read('insurance_company'),
      numeroPolizza: read('policy_number'),
      numeroSinistro: read('claim_number'),
    );
  }

  Map<String, dynamic> _vehicleRow(
    String userId,
    PersonalVehicleData vehicle, {
    required bool isPrimary,
  }) {
    return {
      'user_id': userId,
      'vehicle_id': vehicle.id,
      ..._vehicleValues(vehicle),
      'is_primary': isPrimary,
    };
  }

  Map<String, dynamic> _vehicleValues(PersonalVehicleData vehicle) => {
        'plate': vehicle.targa.trim(),
        'brand': vehicle.marca.trim(),
        'model': vehicle.modello.trim(),
        'vin': vehicle.vin.trim(),
        'mileage': vehicle.kilometraggio.trim(),
        'first_registration': vehicle.primaImmatricolazione.trim(),
        'insurance_company': vehicle.assicurazione.trim(),
        'policy_number': vehicle.numeroPolizza.trim(),
        'claim_number': vehicle.numeroSinistro.trim(),
      };

  void _verifyImportedVehicles(
    PersonalVehicleCollection expected,
    PersonalVehicleCollection actual,
  ) {
    if (actual.vehicles.length < expected.vehicles.length) {
      throw StateError('Local vehicle import could not be confirmed');
    }

    for (final vehicle in expected.vehicles) {
      final matches = actual.vehicles.any(
        (candidate) =>
            candidate.id == vehicle.id &&
            jsonEncode(candidate.toMap()) == jsonEncode(vehicle.toMap()),
      );
      if (!matches) {
        throw StateError('Local vehicle import could not be confirmed');
      }
    }
    if (actual.primaryVehicleId != expected.primaryVehicleId) {
      throw StateError('Imported primary vehicle could not be confirmed');
    }
  }

  Future<void> _cacheSafely(
    String userId,
    PersonalVehicleCollection collection,
  ) async {
    try {
      await _localStorage.saveCacheForUser(
        userId: userId,
        collection: collection,
        importCompleted: true,
      );
    } catch (_) {
      // Supabase remains authoritative even when the optional local cache fails.
    }
  }

  String _requireUserId(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty');
    }
    return normalized;
  }
}
