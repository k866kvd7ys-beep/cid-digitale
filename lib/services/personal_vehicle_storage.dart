import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver_personal_qr_data.dart';
import '../models/personal_vehicle_data.dart';

class PersonalVehicleCacheMetadata {
  const PersonalVehicleCacheMetadata({
    required this.userId,
    required this.importCompleted,
    required this.collectionDigest,
  });

  final String userId;
  final bool importCompleted;
  final String collectionDigest;

  bool matches(String expectedUserId, PersonalVehicleCollection collection) {
    return userId == expectedUserId &&
        collectionDigest == PersonalVehicleStorage.digestOf(collection);
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'importCompleted': importCompleted,
        'collectionDigest': collectionDigest,
      };

  factory PersonalVehicleCacheMetadata.fromMap(Map<String, dynamic> map) {
    return PersonalVehicleCacheMetadata(
      userId: map['userId']?.toString().trim() ?? '',
      importCompleted: map['importCompleted'] == true,
      collectionDigest: map['collectionDigest']?.toString().trim() ?? '',
    );
  }
}

class PersonalVehicleStorage {
  PersonalVehicleStorage({SharedPreferences? preferences})
      : _preferences = preferences;

  static const String storageKey = 'driver_personal_vehicles_v1';
  static const String legacyProfileKey = 'driver_personal_qr_data_v1';
  static const String cacheMetadataKey =
      'driver_personal_vehicles_cache_metadata_v1';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    final preferences = _preferences;
    if (preferences != null) return preferences;
    return SharedPreferences.getInstance();
  }

  Future<PersonalVehicleCollection> loadOrMigrate() async {
    final prefs = await _prefs();
    await prefs.reload();

    if (prefs.containsKey(storageKey)) {
      return _decodeCollection(prefs.getString(storageKey));
    }

    final legacyRaw = prefs.getString(legacyProfileKey)?.trim() ?? '';
    final legacyProfile = driverPersonalQrDataFromJson(legacyRaw);
    final legacyVehicle = PersonalVehicleData.fromQrProfile(
      legacyProfile,
      id: 'legacy_vehicle',
    );
    final migrated = legacyVehicle.hasAnyValue
        ? PersonalVehicleCollection(
            primaryVehicleId: legacyVehicle.id,
            vehicles: [legacyVehicle],
          )
        : const PersonalVehicleCollection.empty();

    await save(migrated);
    return migrated;
  }

  Future<PersonalVehicleCollection> load() async {
    final prefs = await _prefs();
    await prefs.reload();
    return _decodeCollection(prefs.getString(storageKey));
  }

  Future<void> save(PersonalVehicleCollection collection) async {
    final prefs = await _prefs();
    final saved = await prefs.setString(
      storageKey,
      jsonEncode(collection.toMap()),
    );
    if (!saved) {
      throw StateError('Personal vehicle storage write failed');
    }
  }

  Future<PersonalVehicleCacheMetadata?> loadCacheMetadata() async {
    final prefs = await _prefs();
    await prefs.reload();
    final raw = prefs.getString(cacheMetadataKey)?.trim() ?? '';
    if (raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final metadata = PersonalVehicleCacheMetadata.fromMap(
        Map<String, dynamic>.from(decoded),
      );
      if (metadata.userId.isEmpty || metadata.collectionDigest.isEmpty) {
        return null;
      }
      return metadata;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasCacheMetadata() async {
    final prefs = await _prefs();
    await prefs.reload();
    return prefs.containsKey(cacheMetadataKey);
  }

  Future<void> saveCacheForUser({
    required String userId,
    required PersonalVehicleCollection collection,
    required bool importCompleted,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty');
    }

    await save(collection);
    final prefs = await _prefs();
    final metadata = PersonalVehicleCacheMetadata(
      userId: normalizedUserId,
      importCompleted: importCompleted,
      collectionDigest: digestOf(collection),
    );
    final saved = await prefs.setString(
      cacheMetadataKey,
      jsonEncode(metadata.toMap()),
    );
    if (!saved) {
      throw StateError('Personal vehicle cache metadata write failed');
    }
  }

  Future<void> clear() async {
    final prefs = await _prefs();
    final vehiclesRemoved = await prefs.remove(storageKey);
    final metadataRemoved = await prefs.remove(cacheMetadataKey);
    if ((!vehiclesRemoved && prefs.containsKey(storageKey)) ||
        (!metadataRemoved && prefs.containsKey(cacheMetadataKey))) {
      throw StateError('Personal vehicle storage delete failed');
    }
  }

  static String digestOf(PersonalVehicleCollection collection) {
    final raw = jsonEncode(collection.toMap());
    return sha256.convert(utf8.encode(raw)).toString();
  }

  PersonalVehicleCollection _decodeCollection(String? raw) {
    final source = raw?.trim() ?? '';
    if (source.isEmpty) return const PersonalVehicleCollection.empty();
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) {
        return PersonalVehicleCollection.fromMap(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}
    return const PersonalVehicleCollection.empty();
  }
}
