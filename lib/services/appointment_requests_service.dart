import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/appointment_request.dart';
import 'email_notifications_service.dart';
import 'local_image_cache.dart';

class AppointmentRequestImageCategory {
  static const vehicleDocument = 'document';
  static const closeGlass = 'close_glass';
  static const frontVehicle = 'front_vehicle';
  static const glassCurrentKm = 'glass_current_km';
  static const hailVehicleDocument = 'hail_vehicle_document';
  static const hailDamage = 'hail_damage';
  static const hailOverview = 'hail_overview';
  static const hailCurrentKm = 'hail_current_km';
  static const hailExtra1 = 'hail_extra_1';
  static const hailExtra2 = 'hail_extra_2';
  static const marderVehicleDocument = 'marder_vehicle_document';
  static const marderEngineBay = 'marder_engine_bay';
  static const marderCable = 'marder_cable';
  static const marderCurrentKm = 'marder_current_km';
  static const marderExtra = 'marder_extra';
  static const fullVehicleDocument = 'full_vehicle_document';
  static const fullClose = 'full_close';
  static const fullOverview = 'full_overview';
  static const fullCurrentKm = 'full_current_km';
  static const fullExtra = 'full_extra';
  static const otherVehicleDocument = 'other_vehicle_document';
  static const otherProblem = 'other_problem';
  static const otherCurrentKm = 'other_current_km';
  static const otherExtra = 'other_extra';
  static const parkingVehicleDocument = 'parking_vehicle_document';
  static const parkingDamage = 'parking_damage';
  static const parkingOverview = 'parking_overview';
  static const parkingCurrentKm = 'parking_current_km';
  static const parkingExtra = 'parking_extra';
}

class AppointmentRequestImageInput {
  const AppointmentRequestImageInput({
    required this.category,
    required this.fileName,
    required this.mimeType,
    required this.previewReference,
    this.localPath,
    this.cacheKey,
    this.bytes,
  });

  final String category;
  final String fileName;
  final String mimeType;
  final String previewReference;
  final String? localPath;
  final String? cacheKey;
  final Uint8List? bytes;

  Map<String, dynamic> toQueueMap() {
    return {
      'category': category,
      'fileName': fileName,
      'mimeType': mimeType,
      'previewReference': previewReference,
      'localPath': localPath,
      'cacheKey': cacheKey,
      'bytesBase64': bytes != null ? base64Encode(bytes!) : null,
    };
  }
}

class _DamageRequestImageGroups {
  const _DamageRequestImageGroups({
    this.vehicleDocumentImages = const [],
    this.closeGlassImages = const [],
    this.frontVehicleImages = const [],
    this.glassCurrentKmImages = const [],
    this.hailVehicleDocumentImages = const [],
    this.hailDamageImages = const [],
    this.hailOverviewImages = const [],
    this.hailCurrentKmImages = const [],
    this.hailExtraImages = const [],
    this.marderVehicleDocumentImages = const [],
    this.marderEngineBayImages = const [],
    this.marderCableImages = const [],
    this.marderCurrentKmImages = const [],
    this.marderExtraImages = const [],
    this.fullVehicleDocumentImages = const [],
    this.fullCloseImages = const [],
    this.fullOverviewImages = const [],
    this.fullCurrentKmImages = const [],
    this.fullExtraImages = const [],
    this.otherVehicleDocumentImages = const [],
    this.otherProblemImages = const [],
    this.otherCurrentKmImages = const [],
    this.otherExtraImages = const [],
    this.parkingVehicleDocumentImages = const [],
    this.parkingDamageImages = const [],
    this.parkingOverviewImages = const [],
    this.parkingCurrentKmImages = const [],
    this.parkingExtraImages = const [],
  });

  final List<String> vehicleDocumentImages;
  final List<String> closeGlassImages;
  final List<String> frontVehicleImages;
  final List<String> glassCurrentKmImages;
  final List<String> hailVehicleDocumentImages;
  final List<String> hailDamageImages;
  final List<String> hailOverviewImages;
  final List<String> hailCurrentKmImages;
  final List<String> hailExtraImages;
  final List<String> marderVehicleDocumentImages;
  final List<String> marderEngineBayImages;
  final List<String> marderCableImages;
  final List<String> marderCurrentKmImages;
  final List<String> marderExtraImages;
  final List<String> fullVehicleDocumentImages;
  final List<String> fullCloseImages;
  final List<String> fullOverviewImages;
  final List<String> fullCurrentKmImages;
  final List<String> fullExtraImages;
  final List<String> otherVehicleDocumentImages;
  final List<String> otherProblemImages;
  final List<String> otherCurrentKmImages;
  final List<String> otherExtraImages;
  final List<String> parkingVehicleDocumentImages;
  final List<String> parkingDamageImages;
  final List<String> parkingOverviewImages;
  final List<String> parkingCurrentKmImages;
  final List<String> parkingExtraImages;

  List<String> get allImages => _mergeUniqueUrls([
        vehicleDocumentImages,
        closeGlassImages,
        frontVehicleImages,
        glassCurrentKmImages,
        hailVehicleDocumentImages,
        hailDamageImages,
        hailOverviewImages,
        hailCurrentKmImages,
        hailExtraImages,
        marderVehicleDocumentImages,
        marderEngineBayImages,
        marderCableImages,
        marderCurrentKmImages,
        marderExtraImages,
        fullVehicleDocumentImages,
        fullCloseImages,
        fullOverviewImages,
        fullCurrentKmImages,
        fullExtraImages,
        otherVehicleDocumentImages,
        otherProblemImages,
        otherCurrentKmImages,
        otherExtraImages,
        parkingVehicleDocumentImages,
        parkingDamageImages,
        parkingOverviewImages,
        parkingCurrentKmImages,
        parkingExtraImages,
      ]);
}

List<String> _mergeUniqueUrls(Iterable<List<String>> lists) {
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

class AppointmentRequestsSyncManager {
  static Timer? _timer;
  static bool _running = false;

  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(trigger()),
    );
    unawaited(trigger());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> trigger() async {
    if (_running) return;
    _running = true;
    try {
      await AppointmentRequestsService().syncPendingRequests();
    } finally {
      _running = false;
    }
  }
}

class AppointmentRequestsService {
  AppointmentRequestsService(
      {SupabaseClient? client, EmailNotificationsService? emailService})
      : _client = client ?? Supabase.instance.client,
        _emailNotifications = emailService ??
            EmailNotificationsService(
                client: client ?? Supabase.instance.client);

  static const _queueKey = 'pendingAppointmentRequestsQueue';
  static const _storageBucket = 'claim_attachments';

  final SupabaseClient _client;
  final EmailNotificationsService _emailNotifications;

  Future<List<AppointmentRequest>> fetchMyRequests({
    String? email,
    String? phone,
    String? licensePlate,
    String? serviceFilter, // 'all'|'service'|'tires'|'damage'
  }) async {
    final remoteItems = <AppointmentRequest>[];
    try {
      var query = _client.from('appointment_requests').select();

      switch (serviceFilter) {
        case 'service':
          query = query.eq('service_type', 'service_anmelden');
          break;
        case 'tires':
          query = query.filter(
            'service_type',
            'in',
            '(raeder_sommer,raeder_winter)',
          );
          break;
        case 'damage':
          query = query.ilike('service_type', 'damage%');
          break;
        default:
          break;
      }

      if (licensePlate != null && licensePlate.trim().isNotEmpty) {
        query = query.ilike('license_plate', '%${licensePlate.trim()}%');
      } else if (email != null && email.trim().isNotEmpty) {
        query = query.ilike('email', '%${email.trim()}%');
      } else if (phone != null && phone.trim().isNotEmpty) {
        query = query.ilike('phone', '%${phone.trim()}%');
      }

      final res = await query.order('created_at', ascending: false).limit(200);
      final list = (res as List).cast<Map<String, dynamic>>();
      remoteItems.addAll(list.map(AppointmentRequest.fromMap));
    } catch (e) {
      debugPrint('fetchMyRequests remote failed: $e');
    }

    final localItems = await _loadPendingRequestsFromQueue(
      email: email,
      phone: phone,
      licensePlate: licensePlate,
      serviceFilter: serviceFilter,
    );

    final merged = <AppointmentRequest>[
      ...localItems,
      ...remoteItems,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return merged;
  }

  Future<AppointmentRequest> createRequest({
    required String serviceType,
    String? tireServiceType,
    DateTime? appointmentDate,
    String? appointmentTime,
    int durationMinutes = 60,
    String? customerName,
    String? phone,
    String? email,
    String? licensePlate,
    String? notes,
    String? locale,
    String? damageType,
    String? glassDamageTown,
    String? glassDamageDate,
    String? hailDamageTown,
    String? hailDamageDate,
    String? hailDamageTime,
    String? marderDamageTown,
    String? marderDamageDate,
    String? marderDamageTime,
    String? marderDamageDrivable,
    String? marderDamageDescription,
    String? fullDamageTown,
    String? fullDamageDate,
    String? fullDamageTime,
    String? fullDamageDrivable,
    String? fullDamageDescription,
    String? otherDamageTown,
    String? otherDamageDate,
    String? otherDamageTime,
    String? otherDamageCategory,
    String? otherDamageDescription,
    String? parkingDamageTown,
    String? parkingDamageDate,
    String? parkingDamageTime,
    List<AppointmentRequestImageInput> glassDamageVehicleDocumentImages =
        const [],
    List<AppointmentRequestImageInput> glassDamageCloseGlassImages = const [],
    List<AppointmentRequestImageInput> glassDamageFrontVehicleImages = const [],
    List<AppointmentRequestImageInput> glassDamageCurrentKmImages = const [],
    List<AppointmentRequestImageInput> hailDamageVehicleDocumentImages =
        const [],
    List<AppointmentRequestImageInput> hailDamageDamageImages = const [],
    List<AppointmentRequestImageInput> hailDamageOverviewImages = const [],
    List<AppointmentRequestImageInput> hailDamageCurrentKmImages = const [],
    List<AppointmentRequestImageInput> hailDamageExtraImages = const [],
    List<AppointmentRequestImageInput> marderDamageVehicleDocumentImages =
        const [],
    List<AppointmentRequestImageInput> marderDamageEngineBayImages = const [],
    List<AppointmentRequestImageInput> marderDamageCableImages = const [],
    List<AppointmentRequestImageInput> marderDamageCurrentKmImages = const [],
    List<AppointmentRequestImageInput> marderDamageExtraImages = const [],
    List<AppointmentRequestImageInput> fullDamageVehicleDocumentImages =
        const [],
    List<AppointmentRequestImageInput> fullDamageCloseImages = const [],
    List<AppointmentRequestImageInput> fullDamageOverviewImages = const [],
    List<AppointmentRequestImageInput> fullDamageCurrentKmImages = const [],
    List<AppointmentRequestImageInput> fullDamageExtraImages = const [],
    List<AppointmentRequestImageInput> otherDamageVehicleDocumentImages =
        const [],
    List<AppointmentRequestImageInput> otherDamageProblemImages = const [],
    List<AppointmentRequestImageInput> otherDamageCurrentKmImages = const [],
    List<AppointmentRequestImageInput> otherDamageExtraImages = const [],
    List<AppointmentRequestImageInput> parkingDamageVehicleDocumentImages =
        const [],
    List<AppointmentRequestImageInput> parkingDamageDamageImages = const [],
    List<AppointmentRequestImageInput> parkingDamageOverviewImages = const [],
    List<AppointmentRequestImageInput> parkingDamageCurrentKmImages = const [],
    List<AppointmentRequestImageInput> parkingDamageExtraImages = const [],
  }) async {
    final normalizedDate = appointmentDate ?? DateTime.now();
    final normalizedTime = appointmentTime ?? '08:00:00';
    const normalizedRequestStatus = 'pending';
    final normalizedStatusUpdatedAt = DateTime.now().toUtc().toIso8601String();

    if (!await _hasInternetConnection()) {
      return _queueOfflineRequest(
        serviceType: serviceType,
        appointmentDate: normalizedDate,
        appointmentTime: normalizedTime,
        durationMinutes: durationMinutes,
        customerName: customerName,
        phone: phone,
        email: email,
        licensePlate: licensePlate,
        notes: notes,
        locale: locale,
        damageType: damageType,
        tireServiceType: tireServiceType,
        requestStatus: normalizedRequestStatus,
        statusUpdatedAt: normalizedStatusUpdatedAt,
        glassDamageTown: glassDamageTown,
        glassDamageDate: glassDamageDate,
        hailDamageTown: hailDamageTown,
        hailDamageDate: hailDamageDate,
        hailDamageTime: hailDamageTime,
        marderDamageTown: marderDamageTown,
        marderDamageDate: marderDamageDate,
        marderDamageTime: marderDamageTime,
        marderDamageDrivable: marderDamageDrivable,
        marderDamageDescription: marderDamageDescription,
        fullDamageTown: fullDamageTown,
        fullDamageDate: fullDamageDate,
        fullDamageTime: fullDamageTime,
        fullDamageDrivable: fullDamageDrivable,
        fullDamageDescription: fullDamageDescription,
        otherDamageTown: otherDamageTown,
        otherDamageDate: otherDamageDate,
        otherDamageTime: otherDamageTime,
        otherDamageCategory: otherDamageCategory,
        otherDamageDescription: otherDamageDescription,
        parkingDamageTown: parkingDamageTown,
        parkingDamageDate: parkingDamageDate,
        parkingDamageTime: parkingDamageTime,
        glassDamageVehicleDocumentImages: glassDamageVehicleDocumentImages,
        glassDamageCloseGlassImages: glassDamageCloseGlassImages,
        glassDamageFrontVehicleImages: glassDamageFrontVehicleImages,
        glassDamageCurrentKmImages: glassDamageCurrentKmImages,
        hailDamageVehicleDocumentImages: hailDamageVehicleDocumentImages,
        hailDamageDamageImages: hailDamageDamageImages,
        hailDamageOverviewImages: hailDamageOverviewImages,
        hailDamageCurrentKmImages: hailDamageCurrentKmImages,
        hailDamageExtraImages: hailDamageExtraImages,
        marderDamageVehicleDocumentImages: marderDamageVehicleDocumentImages,
        marderDamageEngineBayImages: marderDamageEngineBayImages,
        marderDamageCableImages: marderDamageCableImages,
        marderDamageCurrentKmImages: marderDamageCurrentKmImages,
        marderDamageExtraImages: marderDamageExtraImages,
        fullDamageVehicleDocumentImages: fullDamageVehicleDocumentImages,
        fullDamageCloseImages: fullDamageCloseImages,
        fullDamageOverviewImages: fullDamageOverviewImages,
        fullDamageCurrentKmImages: fullDamageCurrentKmImages,
        fullDamageExtraImages: fullDamageExtraImages,
        otherDamageVehicleDocumentImages: otherDamageVehicleDocumentImages,
        otherDamageProblemImages: otherDamageProblemImages,
        otherDamageCurrentKmImages: otherDamageCurrentKmImages,
        otherDamageExtraImages: otherDamageExtraImages,
        parkingDamageVehicleDocumentImages: parkingDamageVehicleDocumentImages,
        parkingDamageDamageImages: parkingDamageDamageImages,
        parkingDamageOverviewImages: parkingDamageOverviewImages,
        parkingDamageCurrentKmImages: parkingDamageCurrentKmImages,
        parkingDamageExtraImages: parkingDamageExtraImages,
      );
    }

    AppointmentRequest record;
    try {
      record = await _createRemoteRequest(
        serviceType: serviceType,
        appointmentDate: normalizedDate,
        appointmentTime: normalizedTime,
        durationMinutes: durationMinutes,
        customerName: customerName,
        phone: phone,
        email: email,
        licensePlate: licensePlate,
        notes: notes,
        locale: locale,
        damageType: damageType,
        tireServiceType: tireServiceType,
        requestStatus: normalizedRequestStatus,
        statusUpdatedAt: normalizedStatusUpdatedAt,
        glassDamageTown: glassDamageTown,
        glassDamageDate: glassDamageDate,
        hailDamageTown: hailDamageTown,
        hailDamageDate: hailDamageDate,
        hailDamageTime: hailDamageTime,
        marderDamageTown: marderDamageTown,
        marderDamageDate: marderDamageDate,
        marderDamageTime: marderDamageTime,
        marderDamageDrivable: marderDamageDrivable,
        marderDamageDescription: marderDamageDescription,
        fullDamageTown: fullDamageTown,
        fullDamageDate: fullDamageDate,
        fullDamageTime: fullDamageTime,
        fullDamageDrivable: fullDamageDrivable,
        fullDamageDescription: fullDamageDescription,
        otherDamageTown: otherDamageTown,
        otherDamageDate: otherDamageDate,
        otherDamageTime: otherDamageTime,
        otherDamageCategory: otherDamageCategory,
        otherDamageDescription: otherDamageDescription,
        parkingDamageTown: parkingDamageTown,
        parkingDamageDate: parkingDamageDate,
        parkingDamageTime: parkingDamageTime,
        glassDamageVehicleDocumentImages: const [],
        glassDamageCloseGlassImages: const [],
        glassDamageFrontVehicleImages: const [],
        glassDamageCurrentKmImages: const [],
        hailDamageVehicleDocumentImages: const [],
        hailDamageDamageImages: const [],
        hailDamageOverviewImages: const [],
        hailDamageCurrentKmImages: const [],
        hailDamageExtraImages: const [],
        marderDamageVehicleDocumentImages: const [],
        marderDamageEngineBayImages: const [],
        marderDamageCableImages: const [],
        marderDamageCurrentKmImages: const [],
        marderDamageExtraImages: const [],
        fullDamageVehicleDocumentImages: const [],
        fullDamageCloseImages: const [],
        fullDamageOverviewImages: const [],
        fullDamageCurrentKmImages: const [],
        fullDamageExtraImages: const [],
        otherDamageVehicleDocumentImages: const [],
        otherDamageProblemImages: const [],
        otherDamageCurrentKmImages: const [],
        otherDamageExtraImages: const [],
        parkingDamageVehicleDocumentImages: const [],
        parkingDamageDamageImages: const [],
        parkingDamageOverviewImages: const [],
        parkingDamageCurrentKmImages: const [],
        parkingDamageExtraImages: const [],
      );
    } catch (e) {
      if (await _shouldQueueOffline(e)) {
        return _queueOfflineRequest(
          serviceType: serviceType,
          appointmentDate: normalizedDate,
          appointmentTime: normalizedTime,
          durationMinutes: durationMinutes,
          customerName: customerName,
          phone: phone,
          email: email,
          licensePlate: licensePlate,
          notes: notes,
          locale: locale,
          damageType: damageType,
          tireServiceType: tireServiceType,
          requestStatus: normalizedRequestStatus,
          statusUpdatedAt: normalizedStatusUpdatedAt,
          glassDamageTown: glassDamageTown,
          glassDamageDate: glassDamageDate,
          hailDamageTown: hailDamageTown,
          hailDamageDate: hailDamageDate,
          hailDamageTime: hailDamageTime,
          marderDamageTown: marderDamageTown,
          marderDamageDate: marderDamageDate,
          marderDamageTime: marderDamageTime,
          marderDamageDrivable: marderDamageDrivable,
          marderDamageDescription: marderDamageDescription,
          fullDamageTown: fullDamageTown,
          fullDamageDate: fullDamageDate,
          fullDamageTime: fullDamageTime,
          fullDamageDrivable: fullDamageDrivable,
          fullDamageDescription: fullDamageDescription,
          otherDamageTown: otherDamageTown,
          otherDamageDate: otherDamageDate,
          otherDamageTime: otherDamageTime,
          otherDamageCategory: otherDamageCategory,
          otherDamageDescription: otherDamageDescription,
          parkingDamageTown: parkingDamageTown,
          parkingDamageDate: parkingDamageDate,
          parkingDamageTime: parkingDamageTime,
          glassDamageVehicleDocumentImages: glassDamageVehicleDocumentImages,
          glassDamageCloseGlassImages: glassDamageCloseGlassImages,
          glassDamageFrontVehicleImages: glassDamageFrontVehicleImages,
          glassDamageCurrentKmImages: glassDamageCurrentKmImages,
          hailDamageVehicleDocumentImages: hailDamageVehicleDocumentImages,
          hailDamageDamageImages: hailDamageDamageImages,
          hailDamageOverviewImages: hailDamageOverviewImages,
          hailDamageCurrentKmImages: hailDamageCurrentKmImages,
          hailDamageExtraImages: hailDamageExtraImages,
          marderDamageVehicleDocumentImages: marderDamageVehicleDocumentImages,
          marderDamageEngineBayImages: marderDamageEngineBayImages,
          marderDamageCableImages: marderDamageCableImages,
          marderDamageCurrentKmImages: marderDamageCurrentKmImages,
          marderDamageExtraImages: marderDamageExtraImages,
          fullDamageVehicleDocumentImages: fullDamageVehicleDocumentImages,
          fullDamageCloseImages: fullDamageCloseImages,
          fullDamageOverviewImages: fullDamageOverviewImages,
          fullDamageCurrentKmImages: fullDamageCurrentKmImages,
          fullDamageExtraImages: fullDamageExtraImages,
          otherDamageVehicleDocumentImages: otherDamageVehicleDocumentImages,
          otherDamageProblemImages: otherDamageProblemImages,
          otherDamageCurrentKmImages: otherDamageCurrentKmImages,
          otherDamageExtraImages: otherDamageExtraImages,
          parkingDamageVehicleDocumentImages:
              parkingDamageVehicleDocumentImages,
          parkingDamageDamageImages: parkingDamageDamageImages,
          parkingDamageOverviewImages: parkingDamageOverviewImages,
          parkingDamageCurrentKmImages: parkingDamageCurrentKmImages,
          parkingDamageExtraImages: parkingDamageExtraImages,
        );
      }
      rethrow;
    }

    if (glassDamageVehicleDocumentImages.isNotEmpty ||
        glassDamageCloseGlassImages.isNotEmpty ||
        glassDamageFrontVehicleImages.isNotEmpty ||
        glassDamageCurrentKmImages.isNotEmpty ||
        hailDamageVehicleDocumentImages.isNotEmpty ||
        hailDamageDamageImages.isNotEmpty ||
        hailDamageOverviewImages.isNotEmpty ||
        hailDamageCurrentKmImages.isNotEmpty ||
        hailDamageExtraImages.isNotEmpty ||
        marderDamageVehicleDocumentImages.isNotEmpty ||
        marderDamageEngineBayImages.isNotEmpty ||
        marderDamageCableImages.isNotEmpty ||
        marderDamageCurrentKmImages.isNotEmpty ||
        marderDamageExtraImages.isNotEmpty ||
        fullDamageVehicleDocumentImages.isNotEmpty ||
        fullDamageCloseImages.isNotEmpty ||
        fullDamageOverviewImages.isNotEmpty ||
        fullDamageCurrentKmImages.isNotEmpty ||
        fullDamageExtraImages.isNotEmpty ||
        otherDamageVehicleDocumentImages.isNotEmpty ||
        otherDamageProblemImages.isNotEmpty ||
        otherDamageCurrentKmImages.isNotEmpty ||
        otherDamageExtraImages.isNotEmpty ||
        parkingDamageVehicleDocumentImages.isNotEmpty ||
        parkingDamageDamageImages.isNotEmpty ||
        parkingDamageOverviewImages.isNotEmpty ||
        parkingDamageCurrentKmImages.isNotEmpty ||
        parkingDamageExtraImages.isNotEmpty) {
      try {
        final uploadedImages = await _uploadDamageImages(
          record.id,
          [
            ...glassDamageVehicleDocumentImages,
            ...glassDamageCloseGlassImages,
            ...glassDamageFrontVehicleImages,
            ...glassDamageCurrentKmImages,
            ...hailDamageVehicleDocumentImages,
            ...hailDamageDamageImages,
            ...hailDamageOverviewImages,
            ...hailDamageCurrentKmImages,
            ...hailDamageExtraImages,
            ...marderDamageVehicleDocumentImages,
            ...marderDamageEngineBayImages,
            ...marderDamageCableImages,
            ...marderDamageCurrentKmImages,
            ...marderDamageExtraImages,
            ...fullDamageVehicleDocumentImages,
            ...fullDamageCloseImages,
            ...fullDamageOverviewImages,
            ...fullDamageCurrentKmImages,
            ...fullDamageExtraImages,
            ...otherDamageVehicleDocumentImages,
            ...otherDamageProblemImages,
            ...otherDamageCurrentKmImages,
            ...otherDamageExtraImages,
            ...parkingDamageVehicleDocumentImages,
            ...parkingDamageDamageImages,
            ...parkingDamageOverviewImages,
            ...parkingDamageCurrentKmImages,
            ...parkingDamageExtraImages,
          ],
        );
        record = await _updateRequestMetadata(
          requestId: record.id,
          existing: record,
          glassDamageVehicleDocumentImages:
              uploadedImages.vehicleDocumentImages,
          glassDamageCloseGlassImages: uploadedImages.closeGlassImages,
          glassDamageFrontVehicleImages: uploadedImages.frontVehicleImages,
          glassDamageCurrentKmImages: uploadedImages.glassCurrentKmImages,
          hailDamageVehicleDocumentImages:
              uploadedImages.hailVehicleDocumentImages,
          hailDamageDamageImages: uploadedImages.hailDamageImages,
          hailDamageOverviewImages: uploadedImages.hailOverviewImages,
          hailDamageCurrentKmImages: uploadedImages.hailCurrentKmImages,
          hailDamageExtraImages: uploadedImages.hailExtraImages,
          marderDamageVehicleDocumentImages:
              uploadedImages.marderVehicleDocumentImages,
          marderDamageEngineBayImages: uploadedImages.marderEngineBayImages,
          marderDamageCableImages: uploadedImages.marderCableImages,
          marderDamageCurrentKmImages: uploadedImages.marderCurrentKmImages,
          marderDamageExtraImages: uploadedImages.marderExtraImages,
          fullDamageVehicleDocumentImages:
              uploadedImages.fullVehicleDocumentImages,
          fullDamageCloseImages: uploadedImages.fullCloseImages,
          fullDamageOverviewImages: uploadedImages.fullOverviewImages,
          fullDamageCurrentKmImages: uploadedImages.fullCurrentKmImages,
          fullDamageExtraImages: uploadedImages.fullExtraImages,
          otherDamageVehicleDocumentImages:
              uploadedImages.otherVehicleDocumentImages,
          otherDamageProblemImages: uploadedImages.otherProblemImages,
          otherDamageCurrentKmImages: uploadedImages.otherCurrentKmImages,
          otherDamageExtraImages: uploadedImages.otherExtraImages,
          parkingDamageVehicleDocumentImages:
              uploadedImages.parkingVehicleDocumentImages,
          parkingDamageDamageImages: uploadedImages.parkingDamageImages,
          parkingDamageOverviewImages: uploadedImages.parkingOverviewImages,
          parkingDamageCurrentKmImages: uploadedImages.parkingCurrentKmImages,
          parkingDamageExtraImages: uploadedImages.parkingExtraImages,
        );
      } catch (e) {
        debugPrint('Damage image upload failed: $e');
      }
    }

    try {
      await _emailNotifications.sendAppointmentConfirmation(request: record);
    } catch (e) {
      debugPrint('Appointment email send failed: $e');
    }

    return record;
  }

  Future<List<DateTime>> fetchBookedSlots({
    required String serviceKey,
    required DateTime day,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);

    final res = await _client
        .from('appointment_requests')
        .select('appointment_time, appointment_date, status')
        .eq('service_type', serviceKey)
        .eq('appointment_date', dateStr)
        .neq('status', 'cancelled');

    final list = (res as List).cast<Map<String, dynamic>>();
    final base = DateTime(day.year, day.month, day.day);

    final parsed = list
        .map((row) {
          final tRaw = row['appointment_time']?.toString() ?? '';
          if (tRaw.isEmpty) return null;
          final t = tRaw.length == 5 ? '$tRaw:00' : tRaw;
          final parsedTime = DateFormat('HH:mm:ss').tryParse(t);
          if (parsedTime == null) return null;
          return DateTime(
            base.year,
            base.month,
            base.day,
            parsedTime.hour,
            parsedTime.minute,
            parsedTime.second,
          );
        })
        .whereType<DateTime>()
        .toList();

    return parsed;
  }

  Future<AppointmentRequest?> fetchRequestById(String id) async {
    if (_isLocalRequestId(id)) {
      final queue = await _loadQueue();
      for (final entry in queue) {
        if (entry['id'] != id) continue;
        final raw = entry['request'];
        if (raw is! Map) return null;
        return AppointmentRequest.fromMap(Map<String, dynamic>.from(raw));
      }
      return null;
    }

    try {
      final res = await _client
          .from('appointment_requests')
          .select()
          .eq('id', id)
          .single();
      return AppointmentRequest.fromMap(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('fetchRequestById failed for $id: $e');
      return null;
    }
  }

  Future<AppointmentRequest> updateRequestStatus({
    required String requestId,
    required String requestStatus,
  }) async {
    final normalizedStatus =
        requestStatus.trim().isEmpty ? 'pending' : requestStatus.trim();
    final updatedAt = DateTime.now().toUtc().toIso8601String();

    if (_isLocalRequestId(requestId)) {
      final queue = await _loadQueue();
      for (final entry in queue) {
        if (entry['id'] != requestId) continue;
        final raw = entry['request'];
        if (raw is! Map) break;
        final map = Map<String, dynamic>.from(raw)
          ..['requestStatus'] = normalizedStatus
          ..['statusUpdatedAt'] = updatedAt;
        if (normalizedStatus == 'cancelled') {
          map['status'] = 'cancelled';
          map['cancelled_at'] = updatedAt;
        }
        entry['request'] = map;
        await _saveQueue(queue);
        return AppointmentRequest.fromMap(map);
      }
      throw StateError('Local request not found: $requestId');
    }

    final existing = await fetchRequestById(requestId);
    if (existing == null) {
      throw StateError('Request not found: $requestId');
    }

    final updatePayload = <String, dynamic>{
      'status': normalizedStatus,
      'notes': _buildStructuredNotes(
        notes: existing.notes,
        tireServiceType: existing.tireServiceType,
        requestStatus: normalizedStatus,
        statusUpdatedAt: updatedAt,
        glassDamageTown: existing.glassDamageTown,
        glassDamageDate: existing.glassDamageDate,
        hailDamageTown: existing.hailDamageTown,
        hailDamageDate: existing.hailDamageDate,
        hailDamageTime: existing.hailDamageTime,
        marderDamageTown: existing.marderDamageTown,
        marderDamageDate: existing.marderDamageDate,
        marderDamageTime: existing.marderDamageTime,
        marderDamageDrivable: existing.marderDamageDrivable,
        marderDamageDescription: existing.marderDamageDescription,
        fullDamageTown: existing.fullDamageTown,
        fullDamageDate: existing.fullDamageDate,
        fullDamageTime: existing.fullDamageTime,
        fullDamageDrivable: existing.fullDamageDrivable,
        fullDamageDescription: existing.fullDamageDescription,
        otherDamageTown: existing.otherDamageTown,
        otherDamageDate: existing.otherDamageDate,
        otherDamageTime: existing.otherDamageTime,
        otherDamageCategory: existing.otherDamageCategory,
        otherDamageDescription: existing.otherDamageDescription,
        parkingDamageTown: existing.parkingDamageTown,
        parkingDamageDate: existing.parkingDamageDate,
        parkingDamageTime: existing.parkingDamageTime,
        glassDamageVehicleDocumentImages:
            existing.glassDamageVehicleDocumentImages,
        glassDamageCloseGlassImages: existing.glassDamageCloseGlassImages,
        glassDamageFrontVehicleImages: existing.glassDamageFrontVehicleImages,
        glassDamageCurrentKmImages: existing.glassDamageCurrentKmImages,
        hailDamageVehicleDocumentImages:
            existing.hailDamageVehicleDocumentImages,
        hailDamageDamageImages: existing.hailDamageDamageImages,
        hailDamageOverviewImages: existing.hailDamageOverviewImages,
        hailDamageCurrentKmImages: existing.hailDamageCurrentKmImages,
        hailDamageExtraImages: existing.hailDamageExtraImages,
        marderDamageVehicleDocumentImages:
            existing.marderDamageVehicleDocumentImages,
        marderDamageEngineBayImages: existing.marderDamageEngineBayImages,
        marderDamageCableImages: existing.marderDamageCableImages,
        marderDamageCurrentKmImages: existing.marderDamageCurrentKmImages,
        marderDamageExtraImages: existing.marderDamageExtraImages,
        fullDamageVehicleDocumentImages:
            existing.fullDamageVehicleDocumentImages,
        fullDamageCloseImages: existing.fullDamageCloseImages,
        fullDamageOverviewImages: existing.fullDamageOverviewImages,
        fullDamageCurrentKmImages: existing.fullDamageCurrentKmImages,
        fullDamageExtraImages: existing.fullDamageExtraImages,
        otherDamageVehicleDocumentImages:
            existing.otherDamageVehicleDocumentImages,
        otherDamageProblemImages: existing.otherDamageProblemImages,
        otherDamageCurrentKmImages: existing.otherDamageCurrentKmImages,
        otherDamageExtraImages: existing.otherDamageExtraImages,
        parkingDamageVehicleDocumentImages:
            existing.parkingDamageVehicleDocumentImages,
        parkingDamageDamageImages: existing.parkingDamageDamageImages,
        parkingDamageOverviewImages: existing.parkingDamageOverviewImages,
        parkingDamageCurrentKmImages: existing.parkingDamageCurrentKmImages,
        parkingDamageExtraImages: existing.parkingDamageExtraImages,
      ),
    };
    if (normalizedStatus == 'cancelled') {
      updatePayload['cancelled_at'] = updatedAt;
    }

    final res = await _client
        .from('appointment_requests')
        .update(updatePayload)
        .eq('id', requestId)
        .select()
        .single();
    return AppointmentRequest.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> cancelRequest(String id) async {
    if (_isLocalRequestId(id)) {
      await _removeQueueEntry(id);
      return;
    }

    await updateRequestStatus(
      requestId: id,
      requestStatus: 'cancelled',
    );
  }

  Future<void> syncPendingRequests() async {
    if (!await _hasInternetConnection()) return;
    final queue = await _loadQueue();
    if (queue.isEmpty) return;

    for (final rawEntry in List<Map<String, dynamic>>.from(queue)) {
      final requestMap =
          Map<String, dynamic>.from(rawEntry['request'] as Map? ?? const {});
      if (requestMap.isEmpty) continue;

      final localRequest = AppointmentRequest.fromMap(requestMap);
      final imageDescriptors =
          ((rawEntry['image_descriptors'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

      try {
        var record = await _createRemoteRequest(
          serviceType: localRequest.serviceType,
          appointmentDate: localRequest.appointmentDate,
          appointmentTime: localRequest.appointmentTime,
          durationMinutes: localRequest.durationMinutes,
          customerName: localRequest.customerName,
          phone: localRequest.customerPhone,
          email: localRequest.customerEmail,
          licensePlate: localRequest.licensePlate,
          notes: localRequest.notes,
          locale: localRequest.locale,
          damageType: localRequest.damageType,
          tireServiceType: localRequest.tireServiceType,
          requestStatus: localRequest.requestStatus,
          statusUpdatedAt: localRequest.statusUpdatedAt ??
              DateTime.now().toUtc().toIso8601String(),
          glassDamageTown: localRequest.glassDamageTown,
          glassDamageDate: localRequest.glassDamageDate,
          hailDamageTown: localRequest.hailDamageTown,
          hailDamageDate: localRequest.hailDamageDate,
          hailDamageTime: localRequest.hailDamageTime,
          marderDamageTown: localRequest.marderDamageTown,
          marderDamageDate: localRequest.marderDamageDate,
          marderDamageTime: localRequest.marderDamageTime,
          marderDamageDrivable: localRequest.marderDamageDrivable,
          marderDamageDescription: localRequest.marderDamageDescription,
          fullDamageTown: localRequest.fullDamageTown,
          fullDamageDate: localRequest.fullDamageDate,
          fullDamageTime: localRequest.fullDamageTime,
          fullDamageDrivable: localRequest.fullDamageDrivable,
          fullDamageDescription: localRequest.fullDamageDescription,
          otherDamageTown: localRequest.otherDamageTown,
          otherDamageDate: localRequest.otherDamageDate,
          otherDamageTime: localRequest.otherDamageTime,
          otherDamageCategory: localRequest.otherDamageCategory,
          otherDamageDescription: localRequest.otherDamageDescription,
          parkingDamageTown: localRequest.parkingDamageTown,
          parkingDamageDate: localRequest.parkingDamageDate,
          parkingDamageTime: localRequest.parkingDamageTime,
          glassDamageVehicleDocumentImages: const [],
          glassDamageCloseGlassImages: const [],
          glassDamageFrontVehicleImages: const [],
          glassDamageCurrentKmImages: const [],
          hailDamageVehicleDocumentImages: const [],
          hailDamageDamageImages: const [],
          hailDamageOverviewImages: const [],
          hailDamageCurrentKmImages: const [],
          hailDamageExtraImages: const [],
          marderDamageVehicleDocumentImages: const [],
          marderDamageEngineBayImages: const [],
          marderDamageCableImages: const [],
          marderDamageCurrentKmImages: const [],
          marderDamageExtraImages: const [],
          fullDamageVehicleDocumentImages: const [],
          fullDamageCloseImages: const [],
          fullDamageOverviewImages: const [],
          fullDamageCurrentKmImages: const [],
          fullDamageExtraImages: const [],
          otherDamageVehicleDocumentImages: const [],
          otherDamageProblemImages: const [],
          otherDamageCurrentKmImages: const [],
          otherDamageExtraImages: const [],
          parkingDamageVehicleDocumentImages: const [],
          parkingDamageDamageImages: const [],
          parkingDamageOverviewImages: const [],
          parkingDamageCurrentKmImages: const [],
          parkingDamageExtraImages: const [],
        );

        if (imageDescriptors.isNotEmpty) {
          try {
            final uploadedImages = await _uploadDamageImagesFromQueue(
              record.id,
              imageDescriptors,
            );
            record = await _updateRequestMetadata(
              requestId: record.id,
              existing: record,
              glassDamageVehicleDocumentImages:
                  uploadedImages.vehicleDocumentImages,
              glassDamageCloseGlassImages: uploadedImages.closeGlassImages,
              glassDamageFrontVehicleImages: uploadedImages.frontVehicleImages,
              glassDamageCurrentKmImages: uploadedImages.glassCurrentKmImages,
              hailDamageVehicleDocumentImages:
                  uploadedImages.hailVehicleDocumentImages,
              hailDamageDamageImages: uploadedImages.hailDamageImages,
              hailDamageOverviewImages: uploadedImages.hailOverviewImages,
              hailDamageCurrentKmImages: uploadedImages.hailCurrentKmImages,
              hailDamageExtraImages: uploadedImages.hailExtraImages,
              marderDamageVehicleDocumentImages:
                  uploadedImages.marderVehicleDocumentImages,
              marderDamageEngineBayImages: uploadedImages.marderEngineBayImages,
              marderDamageCableImages: uploadedImages.marderCableImages,
              marderDamageCurrentKmImages: uploadedImages.marderCurrentKmImages,
              marderDamageExtraImages: uploadedImages.marderExtraImages,
              fullDamageVehicleDocumentImages:
                  uploadedImages.fullVehicleDocumentImages,
              fullDamageCloseImages: uploadedImages.fullCloseImages,
              fullDamageOverviewImages: uploadedImages.fullOverviewImages,
              fullDamageCurrentKmImages: uploadedImages.fullCurrentKmImages,
              fullDamageExtraImages: uploadedImages.fullExtraImages,
              otherDamageVehicleDocumentImages:
                  uploadedImages.otherVehicleDocumentImages,
              otherDamageProblemImages: uploadedImages.otherProblemImages,
              otherDamageCurrentKmImages: uploadedImages.otherCurrentKmImages,
              otherDamageExtraImages: uploadedImages.otherExtraImages,
              parkingDamageVehicleDocumentImages:
                  uploadedImages.parkingVehicleDocumentImages,
              parkingDamageDamageImages: uploadedImages.parkingDamageImages,
              parkingDamageOverviewImages: uploadedImages.parkingOverviewImages,
              parkingDamageCurrentKmImages:
                  uploadedImages.parkingCurrentKmImages,
              parkingDamageExtraImages: uploadedImages.parkingExtraImages,
            );
          } catch (e) {
            debugPrint('syncPendingRequests image upload failed: $e');
          }
        }

        try {
          await _emailNotifications.sendAppointmentConfirmation(
              request: record);
        } catch (e) {
          debugPrint('Appointment email send failed after sync: $e');
        }

        await _removeQueueEntry(localRequest.id);
        await _cleanupQueuedImages(imageDescriptors);
      } catch (e) {
        debugPrint('syncPendingRequests failed for ${localRequest.id}: $e');
      }
    }
  }

  Future<AppointmentRequest> _createRemoteRequest({
    required String serviceType,
    required DateTime appointmentDate,
    required String appointmentTime,
    required int durationMinutes,
    String? customerName,
    String? phone,
    String? email,
    String? licensePlate,
    String? notes,
    String? locale,
    String? damageType,
    String? tireServiceType,
    required String requestStatus,
    required String statusUpdatedAt,
    String? glassDamageTown,
    String? glassDamageDate,
    String? hailDamageTown,
    String? hailDamageDate,
    String? hailDamageTime,
    String? marderDamageTown,
    String? marderDamageDate,
    String? marderDamageTime,
    String? marderDamageDrivable,
    String? marderDamageDescription,
    String? fullDamageTown,
    String? fullDamageDate,
    String? fullDamageTime,
    String? fullDamageDrivable,
    String? fullDamageDescription,
    String? otherDamageTown,
    String? otherDamageDate,
    String? otherDamageTime,
    String? otherDamageCategory,
    String? otherDamageDescription,
    String? parkingDamageTown,
    String? parkingDamageDate,
    String? parkingDamageTime,
    required List<String> glassDamageVehicleDocumentImages,
    required List<String> glassDamageCloseGlassImages,
    required List<String> glassDamageFrontVehicleImages,
    required List<String> glassDamageCurrentKmImages,
    required List<String> hailDamageVehicleDocumentImages,
    required List<String> hailDamageDamageImages,
    required List<String> hailDamageOverviewImages,
    required List<String> hailDamageCurrentKmImages,
    required List<String> hailDamageExtraImages,
    required List<String> marderDamageVehicleDocumentImages,
    required List<String> marderDamageEngineBayImages,
    required List<String> marderDamageCableImages,
    required List<String> marderDamageCurrentKmImages,
    required List<String> marderDamageExtraImages,
    required List<String> fullDamageVehicleDocumentImages,
    required List<String> fullDamageCloseImages,
    required List<String> fullDamageOverviewImages,
    required List<String> fullDamageCurrentKmImages,
    required List<String> fullDamageExtraImages,
    required List<String> otherDamageVehicleDocumentImages,
    required List<String> otherDamageProblemImages,
    required List<String> otherDamageCurrentKmImages,
    required List<String> otherDamageExtraImages,
    required List<String> parkingDamageVehicleDocumentImages,
    required List<String> parkingDamageDamageImages,
    required List<String> parkingDamageOverviewImages,
    required List<String> parkingDamageCurrentKmImages,
    required List<String> parkingDamageExtraImages,
  }) async {
    final payload = <String, dynamic>{
      'service_type': serviceType,
      'appointment_date': appointmentDate.toIso8601String(),
      'appointment_time': appointmentTime,
      'duration_minutes': durationMinutes,
      'customer_name': customerName,
      'phone': phone,
      'email': email,
      'license_plate': licensePlate,
      'status': requestStatus,
      'notes': _buildStructuredNotes(
        notes: notes,
        tireServiceType: tireServiceType,
        requestStatus: requestStatus,
        statusUpdatedAt: statusUpdatedAt,
        glassDamageTown: glassDamageTown,
        glassDamageDate: glassDamageDate,
        hailDamageTown: hailDamageTown,
        hailDamageDate: hailDamageDate,
        hailDamageTime: hailDamageTime,
        marderDamageTown: marderDamageTown,
        marderDamageDate: marderDamageDate,
        marderDamageTime: marderDamageTime,
        marderDamageDrivable: marderDamageDrivable,
        marderDamageDescription: marderDamageDescription,
        fullDamageTown: fullDamageTown,
        fullDamageDate: fullDamageDate,
        fullDamageTime: fullDamageTime,
        fullDamageDrivable: fullDamageDrivable,
        fullDamageDescription: fullDamageDescription,
        otherDamageTown: otherDamageTown,
        otherDamageDate: otherDamageDate,
        otherDamageTime: otherDamageTime,
        otherDamageCategory: otherDamageCategory,
        otherDamageDescription: otherDamageDescription,
        parkingDamageTown: parkingDamageTown,
        parkingDamageDate: parkingDamageDate,
        parkingDamageTime: parkingDamageTime,
        glassDamageVehicleDocumentImages: glassDamageVehicleDocumentImages,
        glassDamageCloseGlassImages: glassDamageCloseGlassImages,
        glassDamageFrontVehicleImages: glassDamageFrontVehicleImages,
        glassDamageCurrentKmImages: glassDamageCurrentKmImages,
        hailDamageVehicleDocumentImages: hailDamageVehicleDocumentImages,
        hailDamageDamageImages: hailDamageDamageImages,
        hailDamageOverviewImages: hailDamageOverviewImages,
        hailDamageCurrentKmImages: hailDamageCurrentKmImages,
        hailDamageExtraImages: hailDamageExtraImages,
        marderDamageVehicleDocumentImages: marderDamageVehicleDocumentImages,
        marderDamageEngineBayImages: marderDamageEngineBayImages,
        marderDamageCableImages: marderDamageCableImages,
        marderDamageCurrentKmImages: marderDamageCurrentKmImages,
        marderDamageExtraImages: marderDamageExtraImages,
        fullDamageVehicleDocumentImages: fullDamageVehicleDocumentImages,
        fullDamageCloseImages: fullDamageCloseImages,
        fullDamageOverviewImages: fullDamageOverviewImages,
        fullDamageCurrentKmImages: fullDamageCurrentKmImages,
        fullDamageExtraImages: fullDamageExtraImages,
        otherDamageVehicleDocumentImages: otherDamageVehicleDocumentImages,
        otherDamageProblemImages: otherDamageProblemImages,
        otherDamageCurrentKmImages: otherDamageCurrentKmImages,
        otherDamageExtraImages: otherDamageExtraImages,
        parkingDamageVehicleDocumentImages: parkingDamageVehicleDocumentImages,
        parkingDamageDamageImages: parkingDamageDamageImages,
        parkingDamageOverviewImages: parkingDamageOverviewImages,
        parkingDamageCurrentKmImages: parkingDamageCurrentKmImages,
        parkingDamageExtraImages: parkingDamageExtraImages,
      ),
      'locale': locale,
      'damage_type': damageType,
    };

    final res = await _client
        .from('appointment_requests')
        .insert(payload)
        .select()
        .single();

    return AppointmentRequest.fromMap(Map<String, dynamic>.from(res));
  }

  Future<AppointmentRequest> _updateRequestMetadata({
    required String requestId,
    required AppointmentRequest existing,
    required List<String> glassDamageVehicleDocumentImages,
    required List<String> glassDamageCloseGlassImages,
    required List<String> glassDamageFrontVehicleImages,
    required List<String> glassDamageCurrentKmImages,
    required List<String> hailDamageVehicleDocumentImages,
    required List<String> hailDamageDamageImages,
    required List<String> hailDamageOverviewImages,
    required List<String> hailDamageCurrentKmImages,
    required List<String> hailDamageExtraImages,
    required List<String> marderDamageVehicleDocumentImages,
    required List<String> marderDamageEngineBayImages,
    required List<String> marderDamageCableImages,
    required List<String> marderDamageCurrentKmImages,
    required List<String> marderDamageExtraImages,
    required List<String> fullDamageVehicleDocumentImages,
    required List<String> fullDamageCloseImages,
    required List<String> fullDamageOverviewImages,
    required List<String> fullDamageCurrentKmImages,
    required List<String> fullDamageExtraImages,
    required List<String> otherDamageVehicleDocumentImages,
    required List<String> otherDamageProblemImages,
    required List<String> otherDamageCurrentKmImages,
    required List<String> otherDamageExtraImages,
    required List<String> parkingDamageVehicleDocumentImages,
    required List<String> parkingDamageDamageImages,
    required List<String> parkingDamageOverviewImages,
    required List<String> parkingDamageCurrentKmImages,
    required List<String> parkingDamageExtraImages,
  }) async {
    final res = await _client
        .from('appointment_requests')
        .update({
          'notes': _buildStructuredNotes(
            notes: existing.notes,
            tireServiceType: existing.tireServiceType,
            requestStatus: existing.requestStatus,
            statusUpdatedAt: existing.statusUpdatedAt,
            glassDamageTown: existing.glassDamageTown,
            glassDamageDate: existing.glassDamageDate,
            hailDamageTown: existing.hailDamageTown,
            hailDamageDate: existing.hailDamageDate,
            hailDamageTime: existing.hailDamageTime,
            marderDamageTown: existing.marderDamageTown,
            marderDamageDate: existing.marderDamageDate,
            marderDamageTime: existing.marderDamageTime,
            marderDamageDrivable: existing.marderDamageDrivable,
            marderDamageDescription: existing.marderDamageDescription,
            fullDamageTown: existing.fullDamageTown,
            fullDamageDate: existing.fullDamageDate,
            fullDamageTime: existing.fullDamageTime,
            fullDamageDrivable: existing.fullDamageDrivable,
            fullDamageDescription: existing.fullDamageDescription,
            otherDamageTown: existing.otherDamageTown,
            otherDamageDate: existing.otherDamageDate,
            otherDamageTime: existing.otherDamageTime,
            otherDamageCategory: existing.otherDamageCategory,
            otherDamageDescription: existing.otherDamageDescription,
            parkingDamageTown: existing.parkingDamageTown,
            parkingDamageDate: existing.parkingDamageDate,
            parkingDamageTime: existing.parkingDamageTime,
            glassDamageVehicleDocumentImages: glassDamageVehicleDocumentImages,
            glassDamageCloseGlassImages: glassDamageCloseGlassImages,
            glassDamageFrontVehicleImages: glassDamageFrontVehicleImages,
            glassDamageCurrentKmImages: glassDamageCurrentKmImages,
            hailDamageVehicleDocumentImages: hailDamageVehicleDocumentImages,
            hailDamageDamageImages: hailDamageDamageImages,
            hailDamageOverviewImages: hailDamageOverviewImages,
            hailDamageCurrentKmImages: hailDamageCurrentKmImages,
            hailDamageExtraImages: hailDamageExtraImages,
            marderDamageVehicleDocumentImages:
                marderDamageVehicleDocumentImages,
            marderDamageEngineBayImages: marderDamageEngineBayImages,
            marderDamageCableImages: marderDamageCableImages,
            marderDamageCurrentKmImages: marderDamageCurrentKmImages,
            marderDamageExtraImages: marderDamageExtraImages,
            fullDamageVehicleDocumentImages: fullDamageVehicleDocumentImages,
            fullDamageCloseImages: fullDamageCloseImages,
            fullDamageOverviewImages: fullDamageOverviewImages,
            fullDamageCurrentKmImages: fullDamageCurrentKmImages,
            fullDamageExtraImages: fullDamageExtraImages,
            otherDamageVehicleDocumentImages: otherDamageVehicleDocumentImages,
            otherDamageProblemImages: otherDamageProblemImages,
            otherDamageCurrentKmImages: otherDamageCurrentKmImages,
            otherDamageExtraImages: otherDamageExtraImages,
            parkingDamageVehicleDocumentImages:
                parkingDamageVehicleDocumentImages,
            parkingDamageDamageImages: parkingDamageDamageImages,
            parkingDamageOverviewImages: parkingDamageOverviewImages,
            parkingDamageCurrentKmImages: parkingDamageCurrentKmImages,
            parkingDamageExtraImages: parkingDamageExtraImages,
          ),
        })
        .eq('id', requestId)
        .select()
        .single();

    return AppointmentRequest.fromMap(Map<String, dynamic>.from(res));
  }

  String? _buildStructuredNotes({
    String? notes,
    String? tireServiceType,
    String? requestStatus,
    String? statusUpdatedAt,
    String? glassDamageTown,
    String? glassDamageDate,
    String? hailDamageTown,
    String? hailDamageDate,
    String? hailDamageTime,
    String? marderDamageTown,
    String? marderDamageDate,
    String? marderDamageTime,
    String? marderDamageDrivable,
    String? marderDamageDescription,
    String? fullDamageTown,
    String? fullDamageDate,
    String? fullDamageTime,
    String? fullDamageDrivable,
    String? fullDamageDescription,
    String? otherDamageTown,
    String? otherDamageDate,
    String? otherDamageTime,
    String? otherDamageCategory,
    String? otherDamageDescription,
    String? parkingDamageTown,
    String? parkingDamageDate,
    String? parkingDamageTime,
    List<String> glassDamageVehicleDocumentImages = const [],
    List<String> glassDamageCloseGlassImages = const [],
    List<String> glassDamageFrontVehicleImages = const [],
    List<String> glassDamageCurrentKmImages = const [],
    List<String> hailDamageVehicleDocumentImages = const [],
    List<String> hailDamageDamageImages = const [],
    List<String> hailDamageOverviewImages = const [],
    List<String> hailDamageCurrentKmImages = const [],
    List<String> hailDamageExtraImages = const [],
    List<String> marderDamageVehicleDocumentImages = const [],
    List<String> marderDamageEngineBayImages = const [],
    List<String> marderDamageCableImages = const [],
    List<String> marderDamageCurrentKmImages = const [],
    List<String> marderDamageExtraImages = const [],
    List<String> fullDamageVehicleDocumentImages = const [],
    List<String> fullDamageCloseImages = const [],
    List<String> fullDamageOverviewImages = const [],
    List<String> fullDamageCurrentKmImages = const [],
    List<String> fullDamageExtraImages = const [],
    List<String> otherDamageVehicleDocumentImages = const [],
    List<String> otherDamageProblemImages = const [],
    List<String> otherDamageCurrentKmImages = const [],
    List<String> otherDamageExtraImages = const [],
    List<String> parkingDamageVehicleDocumentImages = const [],
    List<String> parkingDamageDamageImages = const [],
    List<String> parkingDamageOverviewImages = const [],
    List<String> parkingDamageCurrentKmImages = const [],
    List<String> parkingDamageExtraImages = const [],
  }) {
    final trimmedNotes = notes?.trim();
    final trimmedTireServiceType = tireServiceType?.trim();
    final trimmedRequestStatus = requestStatus?.trim();
    final trimmedStatusUpdatedAt = statusUpdatedAt?.trim();
    final trimmedGlassTown = glassDamageTown?.trim();
    final trimmedGlassDate = glassDamageDate?.trim();
    final trimmedHailTown = hailDamageTown?.trim();
    final trimmedHailDate = hailDamageDate?.trim();
    final trimmedHailTime = hailDamageTime?.trim();
    final trimmedMarderTown = marderDamageTown?.trim();
    final trimmedMarderDate = marderDamageDate?.trim();
    final trimmedMarderTime = marderDamageTime?.trim();
    final trimmedMarderDrivable = marderDamageDrivable?.trim();
    final trimmedMarderDescription = marderDamageDescription?.trim();
    final trimmedFullTown = fullDamageTown?.trim();
    final trimmedFullDate = fullDamageDate?.trim();
    final trimmedFullTime = fullDamageTime?.trim();
    final trimmedFullDrivable = fullDamageDrivable?.trim();
    final trimmedFullDescription = fullDamageDescription?.trim();
    final trimmedOtherTown = otherDamageTown?.trim();
    final trimmedOtherDate = otherDamageDate?.trim();
    final trimmedOtherTime = otherDamageTime?.trim();
    final trimmedOtherCategory = otherDamageCategory?.trim();
    final trimmedOtherDescription = otherDamageDescription?.trim();
    final trimmedParkingTown = parkingDamageTown?.trim();
    final trimmedParkingDate = parkingDamageDate?.trim();
    final trimmedParkingTime = parkingDamageTime?.trim();
    final cleanedDocumentImages = glassDamageVehicleDocumentImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedCloseGlassImages = glassDamageCloseGlassImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedFrontVehicleImages = glassDamageFrontVehicleImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedGlassCurrentKmImages = glassDamageCurrentKmImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedHailVehicleDocumentImages = hailDamageVehicleDocumentImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedHailDamageImages = hailDamageDamageImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedHailOverviewImages = hailDamageOverviewImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedHailCurrentKmImages = hailDamageCurrentKmImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedHailExtraImages = hailDamageExtraImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    final cleanedMarderVehicleDocumentImages = marderDamageVehicleDocumentImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedMarderEngineBayImages = marderDamageEngineBayImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedMarderCableImages = marderDamageCableImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedMarderCurrentKmImages = marderDamageCurrentKmImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedMarderExtraImages = marderDamageExtraImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    final cleanedFullVehicleDocumentImages = fullDamageVehicleDocumentImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedFullCloseImages = fullDamageCloseImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedFullOverviewImages = fullDamageOverviewImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedFullCurrentKmImages = fullDamageCurrentKmImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedFullExtraImages = fullDamageExtraImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    final cleanedOtherVehicleDocumentImages = otherDamageVehicleDocumentImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedOtherProblemImages = otherDamageProblemImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedOtherCurrentKmImages = otherDamageCurrentKmImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedOtherExtraImages = otherDamageExtraImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    final cleanedParkingVehicleDocumentImages =
        parkingDamageVehicleDocumentImages
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    final cleanedParkingDamageImages = parkingDamageDamageImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedParkingOverviewImages = parkingDamageOverviewImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedParkingCurrentKmImages = parkingDamageCurrentKmImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedParkingExtraImages = parkingDamageExtraImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
    final cleanedGlassImages = _mergeUniqueUrls([
      cleanedDocumentImages,
      cleanedCloseGlassImages,
      cleanedFrontVehicleImages,
      cleanedGlassCurrentKmImages,
    ]);
    final cleanedHailImages = _mergeUniqueUrls([
      cleanedHailVehicleDocumentImages,
      cleanedHailDamageImages,
      cleanedHailOverviewImages,
      cleanedHailCurrentKmImages,
      cleanedHailExtraImages,
    ]);
    final cleanedParkingImages = _mergeUniqueUrls([
      cleanedParkingVehicleDocumentImages,
      cleanedParkingDamageImages,
      cleanedParkingOverviewImages,
      cleanedParkingCurrentKmImages,
      cleanedParkingExtraImages,
    ]);

    final hasStructuredData = (trimmedGlassTown?.isNotEmpty ?? false) ||
        (trimmedGlassDate?.isNotEmpty ?? false) ||
        (trimmedTireServiceType?.isNotEmpty ?? false) ||
        (trimmedRequestStatus?.isNotEmpty ?? false) ||
        (trimmedStatusUpdatedAt?.isNotEmpty ?? false) ||
        (trimmedHailTown?.isNotEmpty ?? false) ||
        (trimmedHailDate?.isNotEmpty ?? false) ||
        (trimmedHailTime?.isNotEmpty ?? false) ||
        (trimmedMarderTown?.isNotEmpty ?? false) ||
        (trimmedMarderDate?.isNotEmpty ?? false) ||
        (trimmedMarderTime?.isNotEmpty ?? false) ||
        (trimmedMarderDrivable?.isNotEmpty ?? false) ||
        (trimmedMarderDescription?.isNotEmpty ?? false) ||
        (trimmedFullTown?.isNotEmpty ?? false) ||
        (trimmedFullDate?.isNotEmpty ?? false) ||
        (trimmedFullTime?.isNotEmpty ?? false) ||
        (trimmedFullDrivable?.isNotEmpty ?? false) ||
        (trimmedFullDescription?.isNotEmpty ?? false) ||
        (trimmedOtherTown?.isNotEmpty ?? false) ||
        (trimmedOtherDate?.isNotEmpty ?? false) ||
        (trimmedOtherTime?.isNotEmpty ?? false) ||
        (trimmedOtherCategory?.isNotEmpty ?? false) ||
        (trimmedOtherDescription?.isNotEmpty ?? false) ||
        (trimmedParkingTown?.isNotEmpty ?? false) ||
        (trimmedParkingDate?.isNotEmpty ?? false) ||
        (trimmedParkingTime?.isNotEmpty ?? false) ||
        cleanedDocumentImages.isNotEmpty ||
        cleanedCloseGlassImages.isNotEmpty ||
        cleanedFrontVehicleImages.isNotEmpty ||
        cleanedGlassCurrentKmImages.isNotEmpty ||
        cleanedHailVehicleDocumentImages.isNotEmpty ||
        cleanedHailDamageImages.isNotEmpty ||
        cleanedHailOverviewImages.isNotEmpty ||
        cleanedHailCurrentKmImages.isNotEmpty ||
        cleanedHailExtraImages.isNotEmpty ||
        cleanedMarderVehicleDocumentImages.isNotEmpty ||
        cleanedMarderEngineBayImages.isNotEmpty ||
        cleanedMarderCableImages.isNotEmpty ||
        cleanedMarderCurrentKmImages.isNotEmpty ||
        cleanedMarderExtraImages.isNotEmpty ||
        cleanedFullVehicleDocumentImages.isNotEmpty ||
        cleanedFullCloseImages.isNotEmpty ||
        cleanedFullOverviewImages.isNotEmpty ||
        cleanedFullCurrentKmImages.isNotEmpty ||
        cleanedFullExtraImages.isNotEmpty ||
        cleanedOtherVehicleDocumentImages.isNotEmpty ||
        cleanedOtherProblemImages.isNotEmpty ||
        cleanedOtherCurrentKmImages.isNotEmpty ||
        cleanedOtherExtraImages.isNotEmpty ||
        cleanedParkingVehicleDocumentImages.isNotEmpty ||
        cleanedParkingDamageImages.isNotEmpty ||
        cleanedParkingOverviewImages.isNotEmpty ||
        cleanedParkingCurrentKmImages.isNotEmpty ||
        cleanedParkingExtraImages.isNotEmpty ||
        cleanedHailImages.isNotEmpty ||
        cleanedParkingImages.isNotEmpty ||
        cleanedGlassImages.isNotEmpty;

    if (!hasStructuredData) {
      return trimmedNotes?.isEmpty ?? true ? null : trimmedNotes;
    }

    return jsonEncode({
      if (trimmedNotes?.isNotEmpty ?? false) 'text': trimmedNotes,
      if (trimmedTireServiceType?.isNotEmpty ?? false)
        'tire_service_type': trimmedTireServiceType,
      if (trimmedTireServiceType?.isNotEmpty ?? false)
        'tireServiceType': trimmedTireServiceType,
      if (trimmedRequestStatus?.isNotEmpty ?? false)
        'requestStatus': trimmedRequestStatus,
      if (trimmedStatusUpdatedAt?.isNotEmpty ?? false)
        'statusUpdatedAt': trimmedStatusUpdatedAt,
      if (trimmedGlassTown?.isNotEmpty ?? false)
        'glassDamageTown': trimmedGlassTown,
      if (trimmedGlassDate?.isNotEmpty ?? false)
        'glassDamageDate': trimmedGlassDate,
      if (cleanedDocumentImages.isNotEmpty)
        'glassDamageVehicleDocumentImages': cleanedDocumentImages,
      if (cleanedCloseGlassImages.isNotEmpty)
        'glassDamageCloseGlassImages': cleanedCloseGlassImages,
      if (cleanedFrontVehicleImages.isNotEmpty)
        'glassDamageFrontVehicleImages': cleanedFrontVehicleImages,
      if (cleanedGlassCurrentKmImages.isNotEmpty)
        'glassDamageCurrentKmImages': cleanedGlassCurrentKmImages,
      if (trimmedHailTown?.isNotEmpty ?? false)
        'hailDamageTown': trimmedHailTown,
      if (trimmedHailDate?.isNotEmpty ?? false)
        'hailDamageDate': trimmedHailDate,
      if (trimmedHailTime?.isNotEmpty ?? false)
        'hailDamageTime': trimmedHailTime,
      if (cleanedHailVehicleDocumentImages.isNotEmpty)
        'hailDamageVehicleDocumentImages': cleanedHailVehicleDocumentImages,
      if (cleanedHailDamageImages.isNotEmpty)
        'hailDamageDamageImages': cleanedHailDamageImages,
      if (cleanedHailOverviewImages.isNotEmpty)
        'hailDamageOverviewImages': cleanedHailOverviewImages,
      if (cleanedHailCurrentKmImages.isNotEmpty)
        'hailDamageCurrentKmImages': cleanedHailCurrentKmImages,
      if (cleanedHailExtraImages.isNotEmpty)
        'hailDamageExtraImages': cleanedHailExtraImages,
      if (trimmedMarderTown?.isNotEmpty ?? false)
        'marderDamageTown': trimmedMarderTown,
      if (trimmedMarderDate?.isNotEmpty ?? false)
        'marderDamageDate': trimmedMarderDate,
      if (trimmedMarderTime?.isNotEmpty ?? false)
        'marderDamageTime': trimmedMarderTime,
      if (trimmedMarderDrivable?.isNotEmpty ?? false)
        'marderDamageDrivable': trimmedMarderDrivable,
      if (trimmedMarderDescription?.isNotEmpty ?? false)
        'marderDamageDescription': trimmedMarderDescription,
      if (cleanedMarderVehicleDocumentImages.isNotEmpty)
        'marderDamageVehicleDocumentImages': cleanedMarderVehicleDocumentImages,
      if (cleanedMarderEngineBayImages.isNotEmpty)
        'marderDamageEngineBayImages': cleanedMarderEngineBayImages,
      if (cleanedMarderCableImages.isNotEmpty)
        'marderDamageCableImages': cleanedMarderCableImages,
      if (cleanedMarderCurrentKmImages.isNotEmpty)
        'marderDamageCurrentKmImages': cleanedMarderCurrentKmImages,
      if (cleanedMarderExtraImages.isNotEmpty)
        'marderDamageExtraImages': cleanedMarderExtraImages,
      if (trimmedFullTown?.isNotEmpty ?? false)
        'fullDamageTown': trimmedFullTown,
      if (trimmedFullDate?.isNotEmpty ?? false)
        'fullDamageDate': trimmedFullDate,
      if (trimmedFullTime?.isNotEmpty ?? false)
        'fullDamageTime': trimmedFullTime,
      if (trimmedFullDrivable?.isNotEmpty ?? false)
        'fullDamageDrivable': trimmedFullDrivable,
      if (trimmedFullDescription?.isNotEmpty ?? false)
        'fullDamageDescription': trimmedFullDescription,
      if (cleanedFullVehicleDocumentImages.isNotEmpty)
        'fullDamageVehicleDocumentImages': cleanedFullVehicleDocumentImages,
      if (cleanedFullCloseImages.isNotEmpty)
        'fullDamageCloseImages': cleanedFullCloseImages,
      if (cleanedFullOverviewImages.isNotEmpty)
        'fullDamageOverviewImages': cleanedFullOverviewImages,
      if (cleanedFullCurrentKmImages.isNotEmpty)
        'fullDamageCurrentKmImages': cleanedFullCurrentKmImages,
      if (cleanedFullExtraImages.isNotEmpty)
        'fullDamageExtraImages': cleanedFullExtraImages,
      if (trimmedOtherTown?.isNotEmpty ?? false)
        'otherDamageTown': trimmedOtherTown,
      if (trimmedOtherDate?.isNotEmpty ?? false)
        'otherDamageDate': trimmedOtherDate,
      if (trimmedOtherTime?.isNotEmpty ?? false)
        'otherDamageTime': trimmedOtherTime,
      if (trimmedOtherCategory?.isNotEmpty ?? false)
        'otherDamageCategory': trimmedOtherCategory,
      if (trimmedOtherDescription?.isNotEmpty ?? false)
        'otherDamageDescription': trimmedOtherDescription,
      if (cleanedOtherVehicleDocumentImages.isNotEmpty)
        'otherDamageVehicleDocumentImages': cleanedOtherVehicleDocumentImages,
      if (cleanedOtherProblemImages.isNotEmpty)
        'otherDamageProblemImages': cleanedOtherProblemImages,
      if (cleanedOtherCurrentKmImages.isNotEmpty)
        'otherDamageCurrentKmImages': cleanedOtherCurrentKmImages,
      if (cleanedOtherExtraImages.isNotEmpty)
        'otherDamageExtraImages': cleanedOtherExtraImages,
      if (trimmedParkingTown?.isNotEmpty ?? false)
        'parkingDamageTown': trimmedParkingTown,
      if (trimmedParkingDate?.isNotEmpty ?? false)
        'parkingDamageDate': trimmedParkingDate,
      if (trimmedParkingTime?.isNotEmpty ?? false)
        'parkingDamageTime': trimmedParkingTime,
      if (cleanedParkingVehicleDocumentImages.isNotEmpty)
        'parkingDamageVehicleDocumentImages':
            cleanedParkingVehicleDocumentImages,
      if (cleanedParkingDamageImages.isNotEmpty)
        'parkingDamageDamageImages': cleanedParkingDamageImages,
      if (cleanedParkingOverviewImages.isNotEmpty)
        'parkingDamageOverviewImages': cleanedParkingOverviewImages,
      if (cleanedParkingCurrentKmImages.isNotEmpty)
        'parkingDamageCurrentKmImages': cleanedParkingCurrentKmImages,
      if (cleanedParkingExtraImages.isNotEmpty)
        'parkingDamageExtraImages': cleanedParkingExtraImages,
      if (cleanedHailImages.isNotEmpty) 'hailDamageImages': cleanedHailImages,
      if (cleanedParkingImages.isNotEmpty)
        'parkingDamageImages': cleanedParkingImages,
      if (cleanedGlassImages.isNotEmpty)
        'glassDamageImages': cleanedGlassImages,
    });
  }

  String _storageRootForDamageImageCategory(String category) {
    switch (category) {
      case AppointmentRequestImageCategory.hailVehicleDocument:
      case AppointmentRequestImageCategory.hailDamage:
      case AppointmentRequestImageCategory.hailOverview:
      case AppointmentRequestImageCategory.hailCurrentKm:
      case AppointmentRequestImageCategory.hailExtra1:
      case AppointmentRequestImageCategory.hailExtra2:
        return 'hail_damage';
      case AppointmentRequestImageCategory.marderVehicleDocument:
      case AppointmentRequestImageCategory.marderEngineBay:
      case AppointmentRequestImageCategory.marderCable:
      case AppointmentRequestImageCategory.marderCurrentKm:
      case AppointmentRequestImageCategory.marderExtra:
        return 'marder_damage';
      case AppointmentRequestImageCategory.fullVehicleDocument:
      case AppointmentRequestImageCategory.fullClose:
      case AppointmentRequestImageCategory.fullOverview:
      case AppointmentRequestImageCategory.fullCurrentKm:
      case AppointmentRequestImageCategory.fullExtra:
        return 'full_damage';
      case AppointmentRequestImageCategory.otherVehicleDocument:
      case AppointmentRequestImageCategory.otherProblem:
      case AppointmentRequestImageCategory.otherCurrentKm:
      case AppointmentRequestImageCategory.otherExtra:
        return 'other_damage';
      case AppointmentRequestImageCategory.parkingVehicleDocument:
      case AppointmentRequestImageCategory.parkingDamage:
      case AppointmentRequestImageCategory.parkingOverview:
      case AppointmentRequestImageCategory.parkingCurrentKm:
      case AppointmentRequestImageCategory.parkingExtra:
        return 'parking_damage';
      default:
        return 'glass_damage';
    }
  }

  String _storagePathForDamageImageCategory(String category) {
    switch (category) {
      case AppointmentRequestImageCategory.vehicleDocument:
        return 'document';
      case AppointmentRequestImageCategory.closeGlass:
        return 'close_glass';
      case AppointmentRequestImageCategory.frontVehicle:
        return 'front_vehicle';
      case AppointmentRequestImageCategory.glassCurrentKm:
        return 'current_km';
      case AppointmentRequestImageCategory.hailVehicleDocument:
        return 'document';
      case AppointmentRequestImageCategory.hailDamage:
        return 'damage';
      case AppointmentRequestImageCategory.hailOverview:
        return 'overview';
      case AppointmentRequestImageCategory.hailCurrentKm:
        return 'current_km';
      case AppointmentRequestImageCategory.hailExtra1:
      case AppointmentRequestImageCategory.hailExtra2:
        return 'extra';
      case AppointmentRequestImageCategory.marderVehicleDocument:
        return 'document';
      case AppointmentRequestImageCategory.marderEngineBay:
        return 'engine_bay';
      case AppointmentRequestImageCategory.marderCable:
        return 'cable';
      case AppointmentRequestImageCategory.marderCurrentKm:
        return 'current_km';
      case AppointmentRequestImageCategory.marderExtra:
        return 'extra';
      case AppointmentRequestImageCategory.fullVehicleDocument:
        return 'document';
      case AppointmentRequestImageCategory.fullClose:
        return 'close';
      case AppointmentRequestImageCategory.fullOverview:
        return 'overview';
      case AppointmentRequestImageCategory.fullCurrentKm:
        return 'current_km';
      case AppointmentRequestImageCategory.fullExtra:
        return 'extra';
      case AppointmentRequestImageCategory.otherVehicleDocument:
        return 'document';
      case AppointmentRequestImageCategory.otherProblem:
        return 'problem';
      case AppointmentRequestImageCategory.otherCurrentKm:
        return 'current_km';
      case AppointmentRequestImageCategory.otherExtra:
        return 'extra';
      case AppointmentRequestImageCategory.parkingVehicleDocument:
        return 'document';
      case AppointmentRequestImageCategory.parkingDamage:
        return 'damage';
      case AppointmentRequestImageCategory.parkingOverview:
        return 'overview';
      case AppointmentRequestImageCategory.parkingCurrentKm:
        return 'current_km';
      case AppointmentRequestImageCategory.parkingExtra:
        return 'extra';
      default:
        return '';
    }
  }

  Future<_DamageRequestImageGroups> _uploadDamageImages(
    String requestId,
    List<AppointmentRequestImageInput> images,
  ) async {
    final vehicleDocumentImages = <String>[];
    final closeGlassImages = <String>[];
    final frontVehicleImages = <String>[];
    final glassCurrentKmImages = <String>[];
    final hailVehicleDocumentImages = <String>[];
    final hailDamageImages = <String>[];
    final hailOverviewImages = <String>[];
    final hailCurrentKmImages = <String>[];
    final hailExtraImages = <String>[];
    final marderVehicleDocumentImages = <String>[];
    final marderEngineBayImages = <String>[];
    final marderCableImages = <String>[];
    final marderCurrentKmImages = <String>[];
    final marderExtraImages = <String>[];
    final fullVehicleDocumentImages = <String>[];
    final fullCloseImages = <String>[];
    final fullOverviewImages = <String>[];
    final fullCurrentKmImages = <String>[];
    final fullExtraImages = <String>[];
    final otherVehicleDocumentImages = <String>[];
    final otherProblemImages = <String>[];
    final otherCurrentKmImages = <String>[];
    final otherExtraImages = <String>[];
    final parkingVehicleDocumentImages = <String>[];
    final parkingDamageImages = <String>[];
    final parkingOverviewImages = <String>[];
    final parkingCurrentKmImages = <String>[];
    final parkingExtraImages = <String>[];
    for (final image in images) {
      final bytes = await _resolveInputBytes(image);
      if (bytes == null || bytes.isEmpty) continue;
      final safeName = image.fileName.replaceAll(' ', '_');
      final rootPath = _storageRootForDamageImageCategory(image.category);
      final categoryPath = _storagePathForDamageImageCategory(image.category);
      final separator = categoryPath.isEmpty ? '' : '$categoryPath/';
      final path = 'appointment_requests/$requestId/$rootPath/'
          '$separator${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await _client.storage.from(_storageBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: image.mimeType,
              upsert: true,
            ),
          );
      final publicUrl = _client.storage.from(_storageBucket).getPublicUrl(path);
      switch (image.category) {
        case AppointmentRequestImageCategory.vehicleDocument:
          vehicleDocumentImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.closeGlass:
          closeGlassImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.frontVehicle:
          frontVehicleImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.glassCurrentKm:
          glassCurrentKmImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.hailVehicleDocument:
          hailVehicleDocumentImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.hailDamage:
          hailDamageImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.hailOverview:
          hailOverviewImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.hailCurrentKm:
          hailCurrentKmImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.hailExtra1:
        case AppointmentRequestImageCategory.hailExtra2:
          hailExtraImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.marderVehicleDocument:
          marderVehicleDocumentImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.marderEngineBay:
          marderEngineBayImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.marderCable:
          marderCableImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.marderCurrentKm:
          marderCurrentKmImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.marderExtra:
          marderExtraImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.fullVehicleDocument:
          fullVehicleDocumentImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.fullClose:
          fullCloseImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.fullOverview:
          fullOverviewImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.fullCurrentKm:
          fullCurrentKmImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.fullExtra:
          fullExtraImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.otherVehicleDocument:
          otherVehicleDocumentImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.otherProblem:
          otherProblemImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.otherCurrentKm:
          otherCurrentKmImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.otherExtra:
          otherExtraImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.parkingVehicleDocument:
          parkingVehicleDocumentImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.parkingDamage:
          parkingDamageImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.parkingOverview:
          parkingOverviewImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.parkingCurrentKm:
          parkingCurrentKmImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.parkingExtra:
          parkingExtraImages.add(publicUrl);
          break;
        default:
          closeGlassImages.add(publicUrl);
          break;
      }
    }
    return _DamageRequestImageGroups(
      vehicleDocumentImages: vehicleDocumentImages,
      closeGlassImages: closeGlassImages,
      frontVehicleImages: frontVehicleImages,
      glassCurrentKmImages: glassCurrentKmImages,
      hailVehicleDocumentImages: hailVehicleDocumentImages,
      hailDamageImages: hailDamageImages,
      hailOverviewImages: hailOverviewImages,
      hailCurrentKmImages: hailCurrentKmImages,
      hailExtraImages: hailExtraImages,
      marderVehicleDocumentImages: marderVehicleDocumentImages,
      marderEngineBayImages: marderEngineBayImages,
      marderCableImages: marderCableImages,
      marderCurrentKmImages: marderCurrentKmImages,
      marderExtraImages: marderExtraImages,
      fullVehicleDocumentImages: fullVehicleDocumentImages,
      fullCloseImages: fullCloseImages,
      fullOverviewImages: fullOverviewImages,
      fullCurrentKmImages: fullCurrentKmImages,
      fullExtraImages: fullExtraImages,
      otherVehicleDocumentImages: otherVehicleDocumentImages,
      otherProblemImages: otherProblemImages,
      otherCurrentKmImages: otherCurrentKmImages,
      otherExtraImages: otherExtraImages,
      parkingVehicleDocumentImages: parkingVehicleDocumentImages,
      parkingDamageImages: parkingDamageImages,
      parkingOverviewImages: parkingOverviewImages,
      parkingCurrentKmImages: parkingCurrentKmImages,
      parkingExtraImages: parkingExtraImages,
    );
  }

  Future<_DamageRequestImageGroups> _uploadDamageImagesFromQueue(
    String requestId,
    List<Map<String, dynamic>> descriptors,
  ) async {
    final images = descriptors.map((descriptor) {
      final bytesBase64 = descriptor['bytesBase64']?.toString();
      return AppointmentRequestImageInput(
        category: descriptor['category']?.toString() ??
            AppointmentRequestImageCategory.closeGlass,
        fileName: descriptor['fileName']?.toString() ?? 'glass_damage.jpg',
        mimeType: descriptor['mimeType']?.toString() ?? 'image/jpeg',
        previewReference: descriptor['previewReference']?.toString() ?? '',
        localPath: descriptor['localPath']?.toString(),
        cacheKey: descriptor['cacheKey']?.toString(),
        bytes: (bytesBase64 != null && bytesBase64.isNotEmpty)
            ? base64Decode(bytesBase64)
            : null,
      );
    }).toList();
    return _uploadDamageImages(requestId, images);
  }

  Future<Uint8List?> _resolveInputBytes(
      AppointmentRequestImageInput image) async {
    if (image.bytes != null && image.bytes!.isNotEmpty) {
      return image.bytes!;
    }

    final localPath = image.localPath?.trim() ?? '';
    if (localPath.isNotEmpty && !kIsWeb) {
      final file = File(localPath);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }

    final cacheKey = image.cacheKey?.trim() ?? '';
    if (cacheKey.isNotEmpty) {
      return LocalImageCache.getImage(cacheKey);
    }

    return null;
  }

  Future<AppointmentRequest> _queueOfflineRequest({
    required String serviceType,
    String? tireServiceType,
    required DateTime appointmentDate,
    required String appointmentTime,
    required int durationMinutes,
    String? customerName,
    String? phone,
    String? email,
    String? licensePlate,
    String? notes,
    String? locale,
    String? damageType,
    required String requestStatus,
    required String statusUpdatedAt,
    String? glassDamageTown,
    String? glassDamageDate,
    String? hailDamageTown,
    String? hailDamageDate,
    String? hailDamageTime,
    String? marderDamageTown,
    String? marderDamageDate,
    String? marderDamageTime,
    String? marderDamageDrivable,
    String? marderDamageDescription,
    String? fullDamageTown,
    String? fullDamageDate,
    String? fullDamageTime,
    String? fullDamageDrivable,
    String? fullDamageDescription,
    String? otherDamageTown,
    String? otherDamageDate,
    String? otherDamageTime,
    String? otherDamageCategory,
    String? otherDamageDescription,
    String? parkingDamageTown,
    String? parkingDamageDate,
    String? parkingDamageTime,
    required List<AppointmentRequestImageInput>
        glassDamageVehicleDocumentImages,
    required List<AppointmentRequestImageInput> glassDamageCloseGlassImages,
    required List<AppointmentRequestImageInput> glassDamageFrontVehicleImages,
    required List<AppointmentRequestImageInput> glassDamageCurrentKmImages,
    required List<AppointmentRequestImageInput> hailDamageVehicleDocumentImages,
    required List<AppointmentRequestImageInput> hailDamageDamageImages,
    required List<AppointmentRequestImageInput> hailDamageOverviewImages,
    required List<AppointmentRequestImageInput> hailDamageCurrentKmImages,
    required List<AppointmentRequestImageInput> hailDamageExtraImages,
    required List<AppointmentRequestImageInput>
        marderDamageVehicleDocumentImages,
    required List<AppointmentRequestImageInput> marderDamageEngineBayImages,
    required List<AppointmentRequestImageInput> marderDamageCableImages,
    required List<AppointmentRequestImageInput> marderDamageCurrentKmImages,
    required List<AppointmentRequestImageInput> marderDamageExtraImages,
    required List<AppointmentRequestImageInput> fullDamageVehicleDocumentImages,
    required List<AppointmentRequestImageInput> fullDamageCloseImages,
    required List<AppointmentRequestImageInput> fullDamageOverviewImages,
    required List<AppointmentRequestImageInput> fullDamageCurrentKmImages,
    required List<AppointmentRequestImageInput> fullDamageExtraImages,
    required List<AppointmentRequestImageInput>
        otherDamageVehicleDocumentImages,
    required List<AppointmentRequestImageInput> otherDamageProblemImages,
    required List<AppointmentRequestImageInput> otherDamageCurrentKmImages,
    required List<AppointmentRequestImageInput> otherDamageExtraImages,
    required List<AppointmentRequestImageInput>
        parkingDamageVehicleDocumentImages,
    required List<AppointmentRequestImageInput> parkingDamageDamageImages,
    required List<AppointmentRequestImageInput> parkingDamageOverviewImages,
    required List<AppointmentRequestImageInput> parkingDamageCurrentKmImages,
    required List<AppointmentRequestImageInput> parkingDamageExtraImages,
  }) async {
    final localId = 'local_req_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toUtc();
    final allImages = [
      ...glassDamageVehicleDocumentImages,
      ...glassDamageCloseGlassImages,
      ...glassDamageFrontVehicleImages,
      ...glassDamageCurrentKmImages,
      ...hailDamageVehicleDocumentImages,
      ...hailDamageDamageImages,
      ...hailDamageOverviewImages,
      ...hailDamageCurrentKmImages,
      ...hailDamageExtraImages,
      ...marderDamageVehicleDocumentImages,
      ...marderDamageEngineBayImages,
      ...marderDamageCableImages,
      ...marderDamageCurrentKmImages,
      ...marderDamageExtraImages,
      ...fullDamageVehicleDocumentImages,
      ...fullDamageCloseImages,
      ...fullDamageOverviewImages,
      ...fullDamageCurrentKmImages,
      ...fullDamageExtraImages,
      ...otherDamageVehicleDocumentImages,
      ...otherDamageProblemImages,
      ...otherDamageCurrentKmImages,
      ...otherDamageExtraImages,
      ...parkingDamageVehicleDocumentImages,
      ...parkingDamageDamageImages,
      ...parkingDamageOverviewImages,
      ...parkingDamageCurrentKmImages,
      ...parkingDamageExtraImages,
    ];
    final allGlassImages = [
      ...glassDamageVehicleDocumentImages,
      ...glassDamageCloseGlassImages,
      ...glassDamageFrontVehicleImages,
      ...glassDamageCurrentKmImages,
    ];
    final allHailImages = [
      ...hailDamageVehicleDocumentImages,
      ...hailDamageDamageImages,
      ...hailDamageOverviewImages,
      ...hailDamageCurrentKmImages,
      ...hailDamageExtraImages,
    ];
    final allParkingImages = [
      ...parkingDamageVehicleDocumentImages,
      ...parkingDamageDamageImages,
      ...parkingDamageOverviewImages,
      ...parkingDamageCurrentKmImages,
      ...parkingDamageExtraImages,
    ];
    final localRequest = AppointmentRequest(
      id: localId,
      createdAt: now,
      updatedAt: now,
      serviceType: serviceType,
      appointmentDate: appointmentDate,
      appointmentTime: appointmentTime,
      durationMinutes: durationMinutes,
      customerName: customerName,
      customerPhone: phone,
      customerEmail: email,
      licensePlate: licensePlate,
      status: 'pending_sync',
      requestStatus: requestStatus,
      statusUpdatedAt: statusUpdatedAt,
      notes: notes,
      damageType: damageType,
      tireServiceType: tireServiceType,
      locale: locale,
      glassDamageTown: glassDamageTown,
      glassDamageDate: glassDamageDate,
      hailDamageTown: hailDamageTown,
      hailDamageDate: hailDamageDate,
      hailDamageTime: hailDamageTime,
      marderDamageTown: marderDamageTown,
      marderDamageDate: marderDamageDate,
      marderDamageTime: marderDamageTime,
      marderDamageDrivable: marderDamageDrivable,
      marderDamageDescription: marderDamageDescription,
      fullDamageTown: fullDamageTown,
      fullDamageDate: fullDamageDate,
      fullDamageTime: fullDamageTime,
      fullDamageDrivable: fullDamageDrivable,
      fullDamageDescription: fullDamageDescription,
      otherDamageTown: otherDamageTown,
      otherDamageDate: otherDamageDate,
      otherDamageTime: otherDamageTime,
      otherDamageCategory: otherDamageCategory,
      otherDamageDescription: otherDamageDescription,
      fullDamageVehicleDocumentImages: fullDamageVehicleDocumentImages
          .map((image) => image.previewReference)
          .toList(),
      fullDamageCloseImages:
          fullDamageCloseImages.map((image) => image.previewReference).toList(),
      fullDamageOverviewImages: fullDamageOverviewImages
          .map((image) => image.previewReference)
          .toList(),
      fullDamageCurrentKmImages: fullDamageCurrentKmImages
          .map((image) => image.previewReference)
          .toList(),
      fullDamageExtraImages:
          fullDamageExtraImages.map((image) => image.previewReference).toList(),
      otherDamageVehicleDocumentImages: otherDamageVehicleDocumentImages
          .map((image) => image.previewReference)
          .toList(),
      otherDamageProblemImages: otherDamageProblemImages
          .map((image) => image.previewReference)
          .toList(),
      otherDamageCurrentKmImages: otherDamageCurrentKmImages
          .map((image) => image.previewReference)
          .toList(),
      otherDamageExtraImages: otherDamageExtraImages
          .map((image) => image.previewReference)
          .toList(),
      marderDamageVehicleDocumentImages: marderDamageVehicleDocumentImages
          .map((image) => image.previewReference)
          .toList(),
      marderDamageEngineBayImages: marderDamageEngineBayImages
          .map((image) => image.previewReference)
          .toList(),
      marderDamageCableImages: marderDamageCableImages
          .map((image) => image.previewReference)
          .toList(),
      marderDamageCurrentKmImages: marderDamageCurrentKmImages
          .map((image) => image.previewReference)
          .toList(),
      marderDamageExtraImages: marderDamageExtraImages
          .map((image) => image.previewReference)
          .toList(),
      parkingDamageTown: parkingDamageTown,
      parkingDamageDate: parkingDamageDate,
      parkingDamageTime: parkingDamageTime,
      glassDamageVehicleDocumentImages: glassDamageVehicleDocumentImages
          .map((image) => image.previewReference)
          .toList(),
      glassDamageCloseGlassImages: glassDamageCloseGlassImages
          .map((image) => image.previewReference)
          .toList(),
      glassDamageFrontVehicleImages: glassDamageFrontVehicleImages
          .map((image) => image.previewReference)
          .toList(),
      glassDamageCurrentKmImages: glassDamageCurrentKmImages
          .map((image) => image.previewReference)
          .toList(),
      hailDamageVehicleDocumentImages: hailDamageVehicleDocumentImages
          .map((image) => image.previewReference)
          .toList(),
      hailDamageDamageImages: hailDamageDamageImages
          .map((image) => image.previewReference)
          .toList(),
      hailDamageImages:
          allHailImages.map((image) => image.previewReference).toList(),
      hailDamageOverviewImages: hailDamageOverviewImages
          .map((image) => image.previewReference)
          .toList(),
      hailDamageCurrentKmImages: hailDamageCurrentKmImages
          .map((image) => image.previewReference)
          .toList(),
      hailDamageExtraImages:
          hailDamageExtraImages.map((image) => image.previewReference).toList(),
      parkingDamageVehicleDocumentImages: parkingDamageVehicleDocumentImages
          .map((image) => image.previewReference)
          .toList(),
      parkingDamageDamageImages: parkingDamageDamageImages
          .map((image) => image.previewReference)
          .toList(),
      parkingDamageImages:
          allParkingImages.map((image) => image.previewReference).toList(),
      parkingDamageOverviewImages: parkingDamageOverviewImages
          .map((image) => image.previewReference)
          .toList(),
      parkingDamageCurrentKmImages: parkingDamageCurrentKmImages
          .map((image) => image.previewReference)
          .toList(),
      parkingDamageExtraImages: parkingDamageExtraImages
          .map((image) => image.previewReference)
          .toList(),
      glassDamageImages:
          allGlassImages.map((image) => image.previewReference).toList(),
    );

    final queue = await _loadQueue();
    queue.removeWhere((entry) => entry['id'] == localId);
    queue.add({
      'id': localId,
      'request': localRequest.toMap(),
      'image_descriptors':
          allImages.map((image) => image.toQueueMap()).toList(),
    });
    await _saveQueue(queue);
    return localRequest;
  }

  Future<List<AppointmentRequest>> _loadPendingRequestsFromQueue({
    String? email,
    String? phone,
    String? licensePlate,
    String? serviceFilter,
  }) async {
    final queue = await _loadQueue();
    return queue
        .map((entry) {
          final raw = entry['request'];
          if (raw is! Map) return null;
          return AppointmentRequest.fromMap(Map<String, dynamic>.from(raw));
        })
        .whereType<AppointmentRequest>()
        .where((request) => _matchesFilters(
              request,
              email: email,
              phone: phone,
              licensePlate: licensePlate,
              serviceFilter: serviceFilter,
            ))
        .toList();
  }

  bool _matchesFilters(
    AppointmentRequest request, {
    String? email,
    String? phone,
    String? licensePlate,
    String? serviceFilter,
  }) {
    switch (serviceFilter) {
      case 'service':
        if (request.serviceType != 'service_anmelden') return false;
        break;
      case 'tires':
        if (request.serviceType != 'raeder_sommer' &&
            request.serviceType != 'raeder_winter') {
          return false;
        }
        break;
      case 'damage':
        if (!request.serviceType.startsWith('damage')) return false;
        break;
      default:
        break;
    }

    if (licensePlate != null && licensePlate.trim().isNotEmpty) {
      return (request.licensePlate ?? '')
          .toLowerCase()
          .contains(licensePlate.trim().toLowerCase());
    }
    if (email != null && email.trim().isNotEmpty) {
      return (request.customerEmail ?? '')
          .toLowerCase()
          .contains(email.trim().toLowerCase());
    }
    if (phone != null && phone.trim().isNotEmpty) {
      return (request.customerPhone ?? '')
          .toLowerCase()
          .contains(phone.trim().toLowerCase());
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (e) {
      debugPrint('load appointment queue failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<void> _removeQueueEntry(String localId) async {
    final queue = await _loadQueue();
    queue.removeWhere((entry) => entry['id'] == localId);
    await _saveQueue(queue);
  }

  Future<void> _cleanupQueuedImages(
    List<Map<String, dynamic>> descriptors,
  ) async {
    for (final descriptor in descriptors) {
      final localPath = descriptor['localPath']?.toString() ?? '';
      if (localPath.isNotEmpty && !kIsWeb) {
        final file = File(localPath);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
      final cacheKey = descriptor['cacheKey']?.toString() ?? '';
      if (cacheKey.isNotEmpty) {
        await LocalImageCache.deleteImage(cacheKey);
      }
    }
  }

  bool _isLocalRequestId(String id) => id.startsWith('local_req_');

  Future<bool> _hasInternetConnection() async {
    try {
      final uri = Uri.parse('$supabaseUrl/auth/v1/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _shouldQueueOffline(Object error) async {
    final message = error.toString().toLowerCase();
    if (message.contains('socketexception') ||
        message.contains('network') ||
        message.contains('timeout') ||
        message.contains('xmlhttprequest') ||
        message.contains('failed host lookup') ||
        message.contains('clientexception')) {
      return true;
    }
    return !await _hasInternetConnection();
  }
}
