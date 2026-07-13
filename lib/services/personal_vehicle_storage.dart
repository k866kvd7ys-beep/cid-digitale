import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver_personal_qr_data.dart';
import '../models/personal_vehicle_data.dart';

class PersonalVehicleStorage {
  PersonalVehicleStorage({SharedPreferences? preferences})
      : _preferences = preferences;

  static const String storageKey = 'driver_personal_vehicles_v1';
  static const String legacyProfileKey = 'driver_personal_qr_data_v1';

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

  Future<void> clear() async {
    final prefs = await _prefs();
    final removed = await prefs.remove(storageKey);
    if (!removed && prefs.containsKey(storageKey)) {
      throw StateError('Personal vehicle storage delete failed');
    }
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
