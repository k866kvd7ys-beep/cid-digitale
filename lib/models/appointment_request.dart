import 'dart:convert';

class AppointmentRequest {
  AppointmentRequest({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.serviceType,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.durationMinutes,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.licensePlate,
    required this.status,
    this.requestStatus = 'pending',
    this.statusUpdatedAt,
    this.notes,
    this.damageType,
    this.locale,
    this.glassDamageTown,
    this.glassDamageDate,
    this.glassDamageVehicleDocumentImages = const [],
    this.glassDamageCloseGlassImages = const [],
    this.glassDamageFrontVehicleImages = const [],
    this.glassDamageCurrentKmImages = const [],
    this.glassDamageImages = const [],
    this.hailDamageTown,
    this.hailDamageDate,
    this.hailDamageTime,
    this.hailDamageVehicleDocumentImages = const [],
    this.hailDamageDamageImages = const [],
    this.hailDamageImages = const [],
    this.hailDamageOverviewImages = const [],
    this.hailDamageCurrentKmImages = const [],
    this.hailDamageExtraImages = const [],
    this.parkingDamageTown,
    this.parkingDamageDate,
    this.parkingDamageTime,
    this.parkingDamageVehicleDocumentImages = const [],
    this.parkingDamageDamageImages = const [],
    this.parkingDamageImages = const [],
    this.parkingDamageOverviewImages = const [],
    this.parkingDamageCurrentKmImages = const [],
    this.parkingDamageExtraImages = const [],
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String serviceType;
  final DateTime appointmentDate;
  final String appointmentTime;
  final int durationMinutes;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? licensePlate;
  final String status;
  final String requestStatus;
  final String? statusUpdatedAt;
  final String? notes;
  final String? damageType;
  final String? locale;
  final String? glassDamageTown;
  final String? glassDamageDate;
  final List<String> glassDamageVehicleDocumentImages;
  final List<String> glassDamageCloseGlassImages;
  final List<String> glassDamageFrontVehicleImages;
  final List<String> glassDamageCurrentKmImages;
  final List<String> glassDamageImages;
  final String? hailDamageTown;
  final String? hailDamageDate;
  final String? hailDamageTime;
  final List<String> hailDamageVehicleDocumentImages;
  final List<String> hailDamageDamageImages;
  final List<String> hailDamageImages;
  final List<String> hailDamageOverviewImages;
  final List<String> hailDamageCurrentKmImages;
  final List<String> hailDamageExtraImages;
  final String? parkingDamageTown;
  final String? parkingDamageDate;
  final String? parkingDamageTime;
  final List<String> parkingDamageVehicleDocumentImages;
  final List<String> parkingDamageDamageImages;
  final List<String> parkingDamageImages;
  final List<String> parkingDamageOverviewImages;
  final List<String> parkingDamageCurrentKmImages;
  final List<String> parkingDamageExtraImages;

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<String> _mergeImageLists(Iterable<List<String>> lists) {
    final merged = <String>[];
    for (final list in lists) {
      for (final item in list) {
        final normalized = item.trim();
        if (normalized.isEmpty || merged.contains(normalized)) continue;
        merged.add(normalized);
      }
    }
    return merged;
  }

  static Map<String, dynamic> _decodeStructuredNotes(dynamic rawNotes) {
    final notesText = rawNotes?.toString() ?? '';
    if (notesText.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(notesText);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  factory AppointmentRequest.fromMap(Map<String, dynamic> map) {
    final createdStr = map['created_at']?.toString();
    final updatedStr = map['updated_at']?.toString();
    final dateStr = map['appointment_date']?.toString();
    final structuredNotes = _decodeStructuredNotes(map['notes']);
    final glassDamageVehicleDocumentImages = _readStringList(
      map['glassDamageVehicleDocumentImages'] ??
          map['glass_damage_vehicle_document_images'] ??
          structuredNotes['glassDamageVehicleDocumentImages'],
    );
    final glassDamageCloseGlassImages = _readStringList(
      map['glassDamageCloseGlassImages'] ??
          map['glass_damage_close_glass_images'] ??
          structuredNotes['glassDamageCloseGlassImages'],
    );
    final glassDamageFrontVehicleImages = _readStringList(
      map['glassDamageFrontVehicleImages'] ??
          map['glass_damage_front_vehicle_images'] ??
          structuredNotes['glassDamageFrontVehicleImages'],
    );
    final glassDamageImages = _readStringList(
      map['glassDamageImages'] ??
          map['glass_damage_images'] ??
          structuredNotes['glassDamageImages'],
    );
    final glassDamageCurrentKmImages = _readStringList(
      map['glassDamageCurrentKmImages'] ??
          map['glass_damage_current_km_images'] ??
          structuredNotes['glassDamageCurrentKmImages'],
    );
    final hailDamageImages = _readStringList(
      map['hailDamageImages'] ??
          map['hail_damage_images'] ??
          structuredNotes['hailDamageImages'],
    );
    final hailDamageVehicleDocumentImages = _readStringList(
      map['hailDamageVehicleDocumentImages'] ??
          map['hail_damage_vehicle_document_images'] ??
          structuredNotes['hailDamageVehicleDocumentImages'],
    );
    final hailDamageDamageImages = _readStringList(
      map['hailDamageDamageImages'] ??
          map['hail_damage_damage_images'] ??
          structuredNotes['hailDamageDamageImages'] ??
          hailDamageImages,
    );
    final hailDamageOverviewImages = _readStringList(
      map['hailDamageOverviewImages'] ??
          map['hail_damage_overview_images'] ??
          structuredNotes['hailDamageOverviewImages'],
    );
    final hailDamageCurrentKmImages = _readStringList(
      map['hailDamageCurrentKmImages'] ??
          map['hail_damage_current_km_images'] ??
          structuredNotes['hailDamageCurrentKmImages'],
    );
    final hailDamageExtraImages = _readStringList(
      map['hailDamageExtraImages'] ??
          map['hail_damage_extra_images'] ??
          structuredNotes['hailDamageExtraImages'],
    );
    final parkingDamageImages = _readStringList(
      map['parkingDamageImages'] ??
          map['parking_damage_images'] ??
          structuredNotes['parkingDamageImages'],
    );
    final parkingDamageVehicleDocumentImages = _readStringList(
      map['parkingDamageVehicleDocumentImages'] ??
          map['parking_damage_vehicle_document_images'] ??
          structuredNotes['parkingDamageVehicleDocumentImages'],
    );
    final parkingDamageDamageImages = _readStringList(
      map['parkingDamageDamageImages'] ??
          map['parking_damage_damage_images'] ??
          structuredNotes['parkingDamageDamageImages'] ??
          parkingDamageImages,
    );
    final parkingDamageOverviewImages = _readStringList(
      map['parkingDamageOverviewImages'] ??
          map['parking_damage_overview_images'] ??
          structuredNotes['parkingDamageOverviewImages'],
    );
    final parkingDamageCurrentKmImages = _readStringList(
      map['parkingDamageCurrentKmImages'] ??
          map['parking_damage_current_km_images'] ??
          structuredNotes['parkingDamageCurrentKmImages'],
    );
    final parkingDamageExtraImages = _readStringList(
      map['parkingDamageExtraImages'] ??
          map['parking_damage_extra_images'] ??
          structuredNotes['parkingDamageExtraImages'],
    );
    final mergedGlassDamageImages = glassDamageImages.isNotEmpty
        ? glassDamageImages
        : _mergeImageLists([
            glassDamageVehicleDocumentImages,
            glassDamageCloseGlassImages,
            glassDamageFrontVehicleImages,
            glassDamageCurrentKmImages,
          ]);
    final mergedHailDamageImages = hailDamageImages.isNotEmpty
        ? hailDamageImages
        : _mergeImageLists([
            hailDamageVehicleDocumentImages,
            hailDamageDamageImages,
            hailDamageOverviewImages,
            hailDamageCurrentKmImages,
            hailDamageExtraImages,
          ]);
    final mergedParkingDamageImages = parkingDamageImages.isNotEmpty
        ? parkingDamageImages
        : _mergeImageLists([
            parkingDamageVehicleDocumentImages,
            parkingDamageDamageImages,
            parkingDamageOverviewImages,
            parkingDamageCurrentKmImages,
            parkingDamageExtraImages,
          ]);
    final extractedNotes = structuredNotes['text']?.toString();
    final resolvedRequestStatus = (map['request_status'] ??
                map['requestStatus'] ??
                structuredNotes['requestStatus'] ??
                map['status'])
            ?.toString()
            .trim() ??
        'pending';
    final resolvedStatusUpdatedAt = (map['status_updated_at'] ??
            map['statusUpdatedAt'] ??
            structuredNotes['statusUpdatedAt'])
        ?.toString();

    return AppointmentRequest(
      id: (map['id'] ?? '').toString(),
      createdAt: DateTime.tryParse(createdStr ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(updatedStr ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      serviceType: (map['service_type'] ?? '').toString(),
      appointmentDate: DateTime.tryParse(dateStr ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      appointmentTime: (map['appointment_time'] ?? '').toString(),
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 60,
      customerName: (map['customer_name'] ?? map['customerName']) as String?,
      customerPhone: (map['phone'] ??
          map['customer_phone'] ??
          map['customerPhone']) as String?,
      customerEmail: (map['email'] ??
          map['customer_email'] ??
          map['customerEmail']) as String?,
      licensePlate: (map['license_plate'] ?? map['licensePlate']) as String?,
      status: (map['status'] ?? 'pending').toString(),
      requestStatus:
          resolvedRequestStatus.isEmpty ? 'pending' : resolvedRequestStatus,
      statusUpdatedAt: (resolvedStatusUpdatedAt?.trim().isEmpty ?? true)
          ? null
          : resolvedStatusUpdatedAt!.trim(),
      notes: extractedNotes ??
          (structuredNotes.isEmpty ? map['notes'] as String? : null),
      damageType: (map['damage_type'] ?? map['damageType'])?.toString(),
      locale: (map['locale'] ?? map['languageCode'])?.toString(),
      glassDamageTown: (map['glassDamageTown'] ??
              map['glass_damage_town'] ??
              structuredNotes['glassDamageTown'])
          ?.toString(),
      glassDamageDate: (map['glassDamageDate'] ??
              map['glass_damage_date'] ??
              structuredNotes['glassDamageDate'])
          ?.toString(),
      glassDamageVehicleDocumentImages: glassDamageVehicleDocumentImages,
      glassDamageCloseGlassImages: glassDamageCloseGlassImages,
      glassDamageFrontVehicleImages: glassDamageFrontVehicleImages,
      glassDamageCurrentKmImages: glassDamageCurrentKmImages,
      glassDamageImages: mergedGlassDamageImages,
      hailDamageTown: (map['hailDamageTown'] ??
              map['hail_damage_town'] ??
              structuredNotes['hailDamageTown'])
          ?.toString(),
      hailDamageDate: (map['hailDamageDate'] ??
              map['hail_damage_date'] ??
              structuredNotes['hailDamageDate'])
          ?.toString(),
      hailDamageTime: (map['hailDamageTime'] ??
              map['hail_damage_time'] ??
              structuredNotes['hailDamageTime'])
          ?.toString(),
      hailDamageVehicleDocumentImages: hailDamageVehicleDocumentImages,
      hailDamageDamageImages: hailDamageDamageImages,
      hailDamageImages: mergedHailDamageImages,
      hailDamageOverviewImages: hailDamageOverviewImages,
      hailDamageCurrentKmImages: hailDamageCurrentKmImages,
      hailDamageExtraImages: hailDamageExtraImages,
      parkingDamageTown: (map['parkingDamageTown'] ??
              map['parking_damage_town'] ??
              structuredNotes['parkingDamageTown'])
          ?.toString(),
      parkingDamageDate: (map['parkingDamageDate'] ??
              map['parking_damage_date'] ??
              structuredNotes['parkingDamageDate'])
          ?.toString(),
      parkingDamageTime: (map['parkingDamageTime'] ??
              map['parking_damage_time'] ??
              structuredNotes['parkingDamageTime'])
          ?.toString(),
      parkingDamageVehicleDocumentImages: parkingDamageVehicleDocumentImages,
      parkingDamageDamageImages: parkingDamageDamageImages,
      parkingDamageImages: mergedParkingDamageImages,
      parkingDamageOverviewImages: parkingDamageOverviewImages,
      parkingDamageCurrentKmImages: parkingDamageCurrentKmImages,
      parkingDamageExtraImages: parkingDamageExtraImages,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'service_type': serviceType,
      'appointment_date': appointmentDate.toIso8601String().substring(0, 10),
      'appointment_time': appointmentTime,
      'duration_minutes': durationMinutes,
      'customer_name': customerName,
      'phone': customerPhone,
      'email': customerEmail,
      'license_plate': licensePlate,
      'status': status,
      'requestStatus': requestStatus,
      'statusUpdatedAt': statusUpdatedAt,
      'notes': notes,
      'damage_type': damageType,
      'locale': locale,
      'glassDamageTown': glassDamageTown,
      'glassDamageDate': glassDamageDate,
      'glassDamageVehicleDocumentImages': glassDamageVehicleDocumentImages,
      'glassDamageCloseGlassImages': glassDamageCloseGlassImages,
      'glassDamageFrontVehicleImages': glassDamageFrontVehicleImages,
      'glassDamageCurrentKmImages': glassDamageCurrentKmImages,
      'glassDamageImages': glassDamageImages,
      'hailDamageTown': hailDamageTown,
      'hailDamageDate': hailDamageDate,
      'hailDamageTime': hailDamageTime,
      'hailDamageVehicleDocumentImages': hailDamageVehicleDocumentImages,
      'hailDamageDamageImages': hailDamageDamageImages,
      'hailDamageImages': hailDamageImages,
      'hailDamageOverviewImages': hailDamageOverviewImages,
      'hailDamageCurrentKmImages': hailDamageCurrentKmImages,
      'hailDamageExtraImages': hailDamageExtraImages,
      'parkingDamageTown': parkingDamageTown,
      'parkingDamageDate': parkingDamageDate,
      'parkingDamageTime': parkingDamageTime,
      'parkingDamageVehicleDocumentImages': parkingDamageVehicleDocumentImages,
      'parkingDamageDamageImages': parkingDamageDamageImages,
      'parkingDamageImages': parkingDamageImages,
      'parkingDamageOverviewImages': parkingDamageOverviewImages,
      'parkingDamageCurrentKmImages': parkingDamageCurrentKmImages,
      'parkingDamageExtraImages': parkingDamageExtraImages,
    };
  }
}
