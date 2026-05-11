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
    this.notes,
    this.damageType,
    this.locale,
    this.glassDamageTown,
    this.glassDamageDate,
    this.glassDamageVehicleDocumentImages = const [],
    this.glassDamageCloseGlassImages = const [],
    this.glassDamageFrontVehicleImages = const [],
    this.glassDamageImages = const [],
    this.hailDamageTown,
    this.hailDamageDate,
    this.hailDamageTime,
    this.hailDamageVehicleDocumentImages = const [],
    this.hailDamageDamageImages = const [],
    this.hailDamageImages = const [],
    this.hailDamageOverviewImages = const [],
    this.hailDamageExtraImages = const [],
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
  final String? notes;
  final String? damageType;
  final String? locale;
  final String? glassDamageTown;
  final String? glassDamageDate;
  final List<String> glassDamageVehicleDocumentImages;
  final List<String> glassDamageCloseGlassImages;
  final List<String> glassDamageFrontVehicleImages;
  final List<String> glassDamageImages;
  final String? hailDamageTown;
  final String? hailDamageDate;
  final String? hailDamageTime;
  final List<String> hailDamageVehicleDocumentImages;
  final List<String> hailDamageDamageImages;
  final List<String> hailDamageImages;
  final List<String> hailDamageOverviewImages;
  final List<String> hailDamageExtraImages;

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
    final hailDamageExtraImages = _readStringList(
      map['hailDamageExtraImages'] ??
          map['hail_damage_extra_images'] ??
          structuredNotes['hailDamageExtraImages'],
    );
    final mergedGlassDamageImages = glassDamageImages.isNotEmpty
        ? glassDamageImages
        : _mergeImageLists([
            glassDamageVehicleDocumentImages,
            glassDamageCloseGlassImages,
            glassDamageFrontVehicleImages,
          ]);
    final mergedHailDamageImages = hailDamageImages.isNotEmpty
        ? hailDamageImages
        : _mergeImageLists([
            hailDamageVehicleDocumentImages,
            hailDamageDamageImages,
            hailDamageOverviewImages,
            hailDamageExtraImages,
          ]);
    final extractedNotes = structuredNotes['text']?.toString();

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
      notes: extractedNotes ?? (structuredNotes.isEmpty ? map['notes'] as String? : null),
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
      hailDamageExtraImages: hailDamageExtraImages,
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
      'notes': notes,
      'damage_type': damageType,
      'locale': locale,
      'glassDamageTown': glassDamageTown,
      'glassDamageDate': glassDamageDate,
      'glassDamageVehicleDocumentImages': glassDamageVehicleDocumentImages,
      'glassDamageCloseGlassImages': glassDamageCloseGlassImages,
      'glassDamageFrontVehicleImages': glassDamageFrontVehicleImages,
      'glassDamageImages': glassDamageImages,
      'hailDamageTown': hailDamageTown,
      'hailDamageDate': hailDamageDate,
      'hailDamageTime': hailDamageTime,
      'hailDamageVehicleDocumentImages': hailDamageVehicleDocumentImages,
      'hailDamageDamageImages': hailDamageDamageImages,
      'hailDamageImages': hailDamageImages,
      'hailDamageOverviewImages': hailDamageOverviewImages,
      'hailDamageExtraImages': hailDamageExtraImages,
    };
  }
}
