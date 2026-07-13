import 'driver_personal_qr_data.dart';

class PersonalVehicleData {
  const PersonalVehicleData({
    required this.id,
    required this.targa,
    required this.marca,
    required this.modello,
    required this.vin,
    required this.kilometraggio,
    required this.primaImmatricolazione,
    required this.assicurazione,
    required this.numeroPolizza,
    required this.numeroSinistro,
  });

  const PersonalVehicleData.empty({this.id = ''})
      : targa = '',
        marca = '',
        modello = '',
        vin = '',
        kilometraggio = '',
        primaImmatricolazione = '',
        assicurazione = '',
        numeroPolizza = '',
        numeroSinistro = '';

  final String id;
  final String targa;
  final String marca;
  final String modello;
  final String vin;
  final String kilometraggio;
  final String primaImmatricolazione;
  final String assicurazione;
  final String numeroPolizza;
  final String numeroSinistro;

  bool get hasAnyValue => [
        targa,
        marca,
        modello,
        vin,
        kilometraggio,
        primaImmatricolazione,
        assicurazione,
        numeroPolizza,
        numeroSinistro,
      ].any((value) => value.trim().isNotEmpty);

  String get displayName => [
        marca.trim(),
        modello.trim(),
      ].where((value) => value.isNotEmpty).join(' ');

  factory PersonalVehicleData.fromQrProfile(
    DriverPersonalQrData profile, {
    required String id,
  }) {
    return PersonalVehicleData(
      id: id,
      targa: profile.targa,
      marca: profile.marca,
      modello: profile.modello,
      vin: profile.vin,
      kilometraggio: profile.kilometraggio,
      primaImmatricolazione: profile.primaImmatricolazione,
      assicurazione: profile.assicurazione,
      numeroPolizza: profile.numeroPolizza,
      numeroSinistro: profile.numeroSinistro,
    );
  }

  DriverPersonalQrData applyToProfile(DriverPersonalQrData profile) {
    return profile.copyWith(
      targa: targa,
      marca: marca,
      modello: modello,
      vin: vin,
      kilometraggio: kilometraggio,
      primaImmatricolazione: primaImmatricolazione,
      assicurazione: assicurazione,
      numeroPolizza: numeroPolizza,
      numeroSinistro: numeroSinistro,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'plate': targa.trim(),
        'brand': marca.trim(),
        'model': modello.trim(),
        'vin': vin.trim(),
        'mileage': kilometraggio.trim(),
        'firstRegistration': primaImmatricolazione.trim(),
        'insurance': <String, dynamic>{
          'company': assicurazione.trim(),
          'policyNumber': numeroPolizza.trim(),
          'claimNumber': numeroSinistro.trim(),
        },
      };

  factory PersonalVehicleData.fromMap(Map<String, dynamic> map) {
    final rawInsurance = map['insurance'];
    final insurance = rawInsurance is Map
        ? Map<String, dynamic>.from(rawInsurance)
        : const <String, dynamic>{};

    String read(Map<String, dynamic> source, String key) =>
        source[key]?.toString().trim() ?? '';

    return PersonalVehicleData(
      id: read(map, 'id'),
      targa: read(map, 'plate'),
      marca: read(map, 'brand'),
      modello: read(map, 'model'),
      vin: read(map, 'vin'),
      kilometraggio: read(map, 'mileage'),
      primaImmatricolazione: read(map, 'firstRegistration'),
      assicurazione: read(insurance, 'company'),
      numeroPolizza: read(insurance, 'policyNumber'),
      numeroSinistro: read(insurance, 'claimNumber'),
    );
  }
}

class PersonalVehicleCollection {
  static const int currentVersion = 1;

  const PersonalVehicleCollection({
    this.version = currentVersion,
    required this.primaryVehicleId,
    required this.vehicles,
  });

  const PersonalVehicleCollection.empty()
      : version = currentVersion,
        primaryVehicleId = '',
        vehicles = const <PersonalVehicleData>[];

  final int version;
  final String primaryVehicleId;
  final List<PersonalVehicleData> vehicles;

  PersonalVehicleData? get primaryVehicle {
    for (final vehicle in vehicles) {
      if (vehicle.id == primaryVehicleId) return vehicle;
    }
    return vehicles.isEmpty ? null : vehicles.first;
  }

  PersonalVehicleCollection upsert(
    PersonalVehicleData vehicle, {
    bool makePrimary = false,
  }) {
    final updated = [...vehicles];
    final index = updated.indexWhere((item) => item.id == vehicle.id);
    if (index == -1) {
      updated.add(vehicle);
    } else {
      updated[index] = vehicle;
    }

    final nextPrimary =
        makePrimary || primaryVehicleId.isEmpty ? vehicle.id : primaryVehicleId;
    return PersonalVehicleCollection(
      primaryVehicleId: nextPrimary,
      vehicles: List.unmodifiable(updated),
    );
  }

  PersonalVehicleCollection remove(String vehicleId) {
    final updated = vehicles
        .where((vehicle) => vehicle.id != vehicleId)
        .toList(growable: false);
    final nextPrimary = primaryVehicleId == vehicleId
        ? (updated.isEmpty ? '' : updated.first.id)
        : primaryVehicleId;
    return PersonalVehicleCollection(
      primaryVehicleId: nextPrimary,
      vehicles: List.unmodifiable(updated),
    );
  }

  PersonalVehicleCollection setPrimary(String vehicleId) {
    if (!vehicles.any((vehicle) => vehicle.id == vehicleId)) return this;
    return PersonalVehicleCollection(
      primaryVehicleId: vehicleId,
      vehicles: vehicles,
    );
  }

  Map<String, dynamic> toMap() => {
        'version': version,
        'primaryVehicleId': primaryVehicleId,
        'vehicles': vehicles.map((vehicle) => vehicle.toMap()).toList(),
      };

  factory PersonalVehicleCollection.fromMap(Map<String, dynamic> map) {
    final rawVehicles = map['vehicles'];
    final vehicles = rawVehicles is List
        ? rawVehicles
            .whereType<Map>()
            .map(
              (item) => PersonalVehicleData.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((vehicle) => vehicle.id.isNotEmpty && vehicle.hasAnyValue)
            .toList(growable: false)
        : const <PersonalVehicleData>[];
    final requestedPrimary = map['primaryVehicleId']?.toString().trim() ?? '';
    final primaryExists = vehicles.any(
      (vehicle) => vehicle.id == requestedPrimary,
    );

    return PersonalVehicleCollection(
      version: (map['version'] as num?)?.toInt() ?? currentVersion,
      primaryVehicleId: primaryExists
          ? requestedPrimary
          : (vehicles.isEmpty ? '' : vehicles.first.id),
      vehicles: List.unmodifiable(vehicles),
    );
  }
}
