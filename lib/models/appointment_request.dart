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
    this.tireServiceType,
    this.serviceSelectionKey,
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
    this.marderDamageTown,
    this.marderDamageDate,
    this.marderDamageTime,
    this.marderDamageDrivable,
    this.marderDamageDescription,
    this.marderDamageVehicleDocumentImages = const [],
    this.marderDamageEngineBayImages = const [],
    this.marderDamageCableImages = const [],
    this.marderDamageCurrentKmImages = const [],
    this.marderDamageExtraImages = const [],
    this.fullDamageTown,
    this.fullDamageDate,
    this.fullDamageTime,
    this.fullDamageDrivable,
    this.fullDamageDescription,
    this.fullDamageVehicleDocumentImages = const [],
    this.fullDamageCloseImages = const [],
    this.fullDamageOverviewImages = const [],
    this.fullDamageCurrentKmImages = const [],
    this.fullDamageExtraImages = const [],
    this.otherDamageTown,
    this.otherDamageDate,
    this.otherDamageTime,
    this.otherDamageCategory,
    this.otherDamageDescription,
    this.otherDamageVehicleDocumentImages = const [],
    this.otherDamageProblemImages = const [],
    this.otherDamageCurrentKmImages = const [],
    this.otherDamageExtraImages = const [],
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
  final String? tireServiceType;
  final String? serviceSelectionKey;
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
  final String? marderDamageTown;
  final String? marderDamageDate;
  final String? marderDamageTime;
  final String? marderDamageDrivable;
  final String? marderDamageDescription;
  final List<String> marderDamageVehicleDocumentImages;
  final List<String> marderDamageEngineBayImages;
  final List<String> marderDamageCableImages;
  final List<String> marderDamageCurrentKmImages;
  final List<String> marderDamageExtraImages;
  final String? fullDamageTown;
  final String? fullDamageDate;
  final String? fullDamageTime;
  final String? fullDamageDrivable;
  final String? fullDamageDescription;
  final List<String> fullDamageVehicleDocumentImages;
  final List<String> fullDamageCloseImages;
  final List<String> fullDamageOverviewImages;
  final List<String> fullDamageCurrentKmImages;
  final List<String> fullDamageExtraImages;
  final String? otherDamageTown;
  final String? otherDamageDate;
  final String? otherDamageTime;
  final String? otherDamageCategory;
  final String? otherDamageDescription;
  final List<String> otherDamageVehicleDocumentImages;
  final List<String> otherDamageProblemImages;
  final List<String> otherDamageCurrentKmImages;
  final List<String> otherDamageExtraImages;
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
    final marderDamageVehicleDocumentImages = _readStringList(
      map['marderDamageVehicleDocumentImages'] ??
          map['marder_damage_vehicle_document_images'] ??
          structuredNotes['marderDamageVehicleDocumentImages'],
    );
    final marderDamageEngineBayImages = _readStringList(
      map['marderDamageEngineBayImages'] ??
          map['marder_damage_engine_bay_images'] ??
          structuredNotes['marderDamageEngineBayImages'],
    );
    final marderDamageCableImages = _readStringList(
      map['marderDamageCableImages'] ??
          map['marder_damage_cable_images'] ??
          structuredNotes['marderDamageCableImages'],
    );
    final marderDamageCurrentKmImages = _readStringList(
      map['marderDamageCurrentKmImages'] ??
          map['marder_damage_current_km_images'] ??
          structuredNotes['marderDamageCurrentKmImages'],
    );
    final marderDamageExtraImages = _readStringList(
      map['marderDamageExtraImages'] ??
          map['marder_damage_extra_images'] ??
          structuredNotes['marderDamageExtraImages'],
    );
    final fullDamageVehicleDocumentImages = _readStringList(
      map['fullDamageVehicleDocumentImages'] ??
          map['full_damage_vehicle_document_images'] ??
          structuredNotes['fullDamageVehicleDocumentImages'],
    );
    final fullDamageCloseImages = _readStringList(
      map['fullDamageCloseImages'] ??
          map['full_damage_close_images'] ??
          structuredNotes['fullDamageCloseImages'],
    );
    final fullDamageOverviewImages = _readStringList(
      map['fullDamageOverviewImages'] ??
          map['full_damage_overview_images'] ??
          structuredNotes['fullDamageOverviewImages'],
    );
    final fullDamageCurrentKmImages = _readStringList(
      map['fullDamageCurrentKmImages'] ??
          map['full_damage_current_km_images'] ??
          structuredNotes['fullDamageCurrentKmImages'],
    );
    final fullDamageExtraImages = _readStringList(
      map['fullDamageExtraImages'] ??
          map['full_damage_extra_images'] ??
          structuredNotes['fullDamageExtraImages'],
    );
    final otherDamageVehicleDocumentImages = _readStringList(
      map['otherDamageVehicleDocumentImages'] ??
          map['other_damage_vehicle_document_images'] ??
          structuredNotes['otherDamageVehicleDocumentImages'],
    );
    final otherDamageProblemImages = _readStringList(
      map['otherDamageProblemImages'] ??
          map['other_damage_problem_images'] ??
          structuredNotes['otherDamageProblemImages'],
    );
    final otherDamageCurrentKmImages = _readStringList(
      map['otherDamageCurrentKmImages'] ??
          map['other_damage_current_km_images'] ??
          structuredNotes['otherDamageCurrentKmImages'],
    );
    final otherDamageExtraImages = _readStringList(
      map['otherDamageExtraImages'] ??
          map['other_damage_extra_images'] ??
          structuredNotes['otherDamageExtraImages'],
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
    final resolvedTireServiceType = (map['tireServiceType'] ??
            map['tire_service_type'] ??
            structuredNotes['tireServiceType'] ??
            structuredNotes['tire_service_type'])
        ?.toString()
        .trim();
    final resolvedServiceSelectionKey = (map['serviceSelectionKey'] ??
            map['service_selection_key'] ??
            structuredNotes['serviceSelectionKey'] ??
            structuredNotes['service_selection_key'])
        ?.toString()
        .trim();
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
      tireServiceType: (resolvedTireServiceType?.isEmpty ?? true)
          ? null
          : resolvedTireServiceType,
      serviceSelectionKey: (resolvedServiceSelectionKey?.isEmpty ?? true)
          ? null
          : resolvedServiceSelectionKey,
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
      marderDamageTown: (map['marderDamageTown'] ??
              map['marder_damage_town'] ??
              structuredNotes['marderDamageTown'])
          ?.toString(),
      marderDamageDate: (map['marderDamageDate'] ??
              map['marder_damage_date'] ??
              structuredNotes['marderDamageDate'])
          ?.toString(),
      marderDamageTime: (map['marderDamageTime'] ??
              map['marder_damage_time'] ??
              structuredNotes['marderDamageTime'])
          ?.toString(),
      marderDamageDrivable: (map['marderDamageDrivable'] ??
              map['marder_damage_drivable'] ??
              structuredNotes['marderDamageDrivable'])
          ?.toString(),
      marderDamageDescription: (map['marderDamageDescription'] ??
              map['marder_damage_description'] ??
              structuredNotes['marderDamageDescription'])
          ?.toString(),
      marderDamageVehicleDocumentImages: marderDamageVehicleDocumentImages,
      marderDamageEngineBayImages: marderDamageEngineBayImages,
      marderDamageCableImages: marderDamageCableImages,
      marderDamageCurrentKmImages: marderDamageCurrentKmImages,
      marderDamageExtraImages: marderDamageExtraImages,
      fullDamageTown: (map['fullDamageTown'] ??
              map['full_damage_town'] ??
              structuredNotes['fullDamageTown'])
          ?.toString(),
      fullDamageDate: (map['fullDamageDate'] ??
              map['full_damage_date'] ??
              structuredNotes['fullDamageDate'])
          ?.toString(),
      fullDamageTime: (map['fullDamageTime'] ??
              map['full_damage_time'] ??
              structuredNotes['fullDamageTime'])
          ?.toString(),
      fullDamageDrivable: (map['fullDamageDrivable'] ??
              map['full_damage_drivable'] ??
              structuredNotes['fullDamageDrivable'])
          ?.toString(),
      fullDamageDescription: (map['fullDamageDescription'] ??
              map['full_damage_description'] ??
              structuredNotes['fullDamageDescription'])
          ?.toString(),
      fullDamageVehicleDocumentImages: fullDamageVehicleDocumentImages,
      fullDamageCloseImages: fullDamageCloseImages,
      fullDamageOverviewImages: fullDamageOverviewImages,
      fullDamageCurrentKmImages: fullDamageCurrentKmImages,
      fullDamageExtraImages: fullDamageExtraImages,
      otherDamageTown: (map['otherDamageTown'] ??
              map['other_damage_town'] ??
              structuredNotes['otherDamageTown'])
          ?.toString(),
      otherDamageDate: (map['otherDamageDate'] ??
              map['other_damage_date'] ??
              structuredNotes['otherDamageDate'])
          ?.toString(),
      otherDamageTime: (map['otherDamageTime'] ??
              map['other_damage_time'] ??
              structuredNotes['otherDamageTime'])
          ?.toString(),
      otherDamageCategory: (map['otherDamageCategory'] ??
              map['other_damage_category'] ??
              structuredNotes['otherDamageCategory'])
          ?.toString(),
      otherDamageDescription: (map['otherDamageDescription'] ??
              map['other_damage_description'] ??
              structuredNotes['otherDamageDescription'])
          ?.toString(),
      otherDamageVehicleDocumentImages: otherDamageVehicleDocumentImages,
      otherDamageProblemImages: otherDamageProblemImages,
      otherDamageCurrentKmImages: otherDamageCurrentKmImages,
      otherDamageExtraImages: otherDamageExtraImages,
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
      'tireServiceType': tireServiceType,
      'tire_service_type': tireServiceType,
      'serviceSelectionKey': serviceSelectionKey,
      'service_selection_key': serviceSelectionKey,
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
      'marderDamageTown': marderDamageTown,
      'marderDamageDate': marderDamageDate,
      'marderDamageTime': marderDamageTime,
      'marderDamageDrivable': marderDamageDrivable,
      'marderDamageDescription': marderDamageDescription,
      'marderDamageVehicleDocumentImages': marderDamageVehicleDocumentImages,
      'marderDamageEngineBayImages': marderDamageEngineBayImages,
      'marderDamageCableImages': marderDamageCableImages,
      'marderDamageCurrentKmImages': marderDamageCurrentKmImages,
      'marderDamageExtraImages': marderDamageExtraImages,
      'fullDamageTown': fullDamageTown,
      'fullDamageDate': fullDamageDate,
      'fullDamageTime': fullDamageTime,
      'fullDamageDrivable': fullDamageDrivable,
      'fullDamageDescription': fullDamageDescription,
      'fullDamageVehicleDocumentImages': fullDamageVehicleDocumentImages,
      'fullDamageCloseImages': fullDamageCloseImages,
      'fullDamageOverviewImages': fullDamageOverviewImages,
      'fullDamageCurrentKmImages': fullDamageCurrentKmImages,
      'fullDamageExtraImages': fullDamageExtraImages,
      'otherDamageTown': otherDamageTown,
      'otherDamageDate': otherDamageDate,
      'otherDamageTime': otherDamageTime,
      'otherDamageCategory': otherDamageCategory,
      'otherDamageDescription': otherDamageDescription,
      'otherDamageVehicleDocumentImages': otherDamageVehicleDocumentImages,
      'otherDamageProblemImages': otherDamageProblemImages,
      'otherDamageCurrentKmImages': otherDamageCurrentKmImages,
      'otherDamageExtraImages': otherDamageExtraImages,
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
