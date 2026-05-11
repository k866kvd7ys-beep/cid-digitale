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
  static const hailDamage = 'hail_damage';
  static const hailOverview = 'hail_overview';
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
    this.hailDamageImages = const [],
    this.hailOverviewImages = const [],
  });

  final List<String> vehicleDocumentImages;
  final List<String> closeGlassImages;
  final List<String> frontVehicleImages;
  final List<String> hailDamageImages;
  final List<String> hailOverviewImages;

  List<String> get allImages => _mergeUniqueUrls([
        vehicleDocumentImages,
        closeGlassImages,
        frontVehicleImages,
        hailDamageImages,
        hailOverviewImages,
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
    List<AppointmentRequestImageInput> glassDamageVehicleDocumentImages =
        const [],
    List<AppointmentRequestImageInput> glassDamageCloseGlassImages = const [],
    List<AppointmentRequestImageInput> glassDamageFrontVehicleImages = const [],
    List<AppointmentRequestImageInput> hailDamageImages = const [],
    List<AppointmentRequestImageInput> hailDamageOverviewImages = const [],
  }) async {
    final normalizedDate = appointmentDate ?? DateTime.now();
    final normalizedTime = appointmentTime ?? '08:00:00';

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
        glassDamageTown: glassDamageTown,
        glassDamageDate: glassDamageDate,
        hailDamageTown: hailDamageTown,
        hailDamageDate: hailDamageDate,
        glassDamageVehicleDocumentImages: glassDamageVehicleDocumentImages,
        glassDamageCloseGlassImages: glassDamageCloseGlassImages,
        glassDamageFrontVehicleImages: glassDamageFrontVehicleImages,
        hailDamageImages: hailDamageImages,
        hailDamageOverviewImages: hailDamageOverviewImages,
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
        glassDamageTown: glassDamageTown,
        glassDamageDate: glassDamageDate,
        hailDamageTown: hailDamageTown,
        hailDamageDate: hailDamageDate,
        glassDamageVehicleDocumentImages: const [],
        glassDamageCloseGlassImages: const [],
        glassDamageFrontVehicleImages: const [],
        hailDamageImages: const [],
        hailDamageOverviewImages: const [],
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
          glassDamageTown: glassDamageTown,
          glassDamageDate: glassDamageDate,
          hailDamageTown: hailDamageTown,
          hailDamageDate: hailDamageDate,
          glassDamageVehicleDocumentImages: glassDamageVehicleDocumentImages,
          glassDamageCloseGlassImages: glassDamageCloseGlassImages,
          glassDamageFrontVehicleImages: glassDamageFrontVehicleImages,
          hailDamageImages: hailDamageImages,
          hailDamageOverviewImages: hailDamageOverviewImages,
        );
      }
      rethrow;
    }

    if (glassDamageVehicleDocumentImages.isNotEmpty ||
        glassDamageCloseGlassImages.isNotEmpty ||
        glassDamageFrontVehicleImages.isNotEmpty ||
        hailDamageImages.isNotEmpty ||
        hailDamageOverviewImages.isNotEmpty) {
      try {
        final uploadedImages = await _uploadDamageImages(
          record.id,
          [
            ...glassDamageVehicleDocumentImages,
            ...glassDamageCloseGlassImages,
            ...glassDamageFrontVehicleImages,
            ...hailDamageImages,
            ...hailDamageOverviewImages,
          ],
        );
        record = await _updateRequestMetadata(
          requestId: record.id,
          existing: record,
          glassDamageVehicleDocumentImages:
              uploadedImages.vehicleDocumentImages,
          glassDamageCloseGlassImages: uploadedImages.closeGlassImages,
          glassDamageFrontVehicleImages: uploadedImages.frontVehicleImages,
          hailDamageImages: uploadedImages.hailDamageImages,
          hailDamageOverviewImages: uploadedImages.hailOverviewImages,
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

  Future<void> cancelRequest(String id) async {
    if (_isLocalRequestId(id)) {
      await _removeQueueEntry(id);
      return;
    }

    await _client.from('appointment_requests').update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
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
      final imageDescriptors = ((rawEntry['image_descriptors'] as List?) ?? const [])
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
          glassDamageTown: localRequest.glassDamageTown,
          glassDamageDate: localRequest.glassDamageDate,
          hailDamageTown: localRequest.hailDamageTown,
          hailDamageDate: localRequest.hailDamageDate,
          glassDamageVehicleDocumentImages: const [],
          glassDamageCloseGlassImages: const [],
          glassDamageFrontVehicleImages: const [],
          hailDamageImages: const [],
          hailDamageOverviewImages: const [],
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
              hailDamageImages: uploadedImages.hailDamageImages,
              hailDamageOverviewImages: uploadedImages.hailOverviewImages,
            );
          } catch (e) {
            debugPrint('syncPendingRequests image upload failed: $e');
          }
        }

        try {
          await _emailNotifications.sendAppointmentConfirmation(request: record);
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
    String? glassDamageTown,
    String? glassDamageDate,
    String? hailDamageTown,
    String? hailDamageDate,
    required List<String> glassDamageVehicleDocumentImages,
    required List<String> glassDamageCloseGlassImages,
    required List<String> glassDamageFrontVehicleImages,
    required List<String> hailDamageImages,
    required List<String> hailDamageOverviewImages,
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
      'notes': _buildStructuredNotes(
        notes: notes,
        glassDamageTown: glassDamageTown,
        glassDamageDate: glassDamageDate,
        hailDamageTown: hailDamageTown,
        hailDamageDate: hailDamageDate,
        glassDamageVehicleDocumentImages: glassDamageVehicleDocumentImages,
        glassDamageCloseGlassImages: glassDamageCloseGlassImages,
        glassDamageFrontVehicleImages: glassDamageFrontVehicleImages,
        hailDamageImages: hailDamageImages,
        hailDamageOverviewImages: hailDamageOverviewImages,
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
    required List<String> hailDamageImages,
    required List<String> hailDamageOverviewImages,
  }) async {
    final res = await _client
        .from('appointment_requests')
        .update({
          'notes': _buildStructuredNotes(
            notes: existing.notes,
            glassDamageTown: existing.glassDamageTown,
            glassDamageDate: existing.glassDamageDate,
            hailDamageTown: existing.hailDamageTown,
            hailDamageDate: existing.hailDamageDate,
            glassDamageVehicleDocumentImages:
                glassDamageVehicleDocumentImages,
            glassDamageCloseGlassImages: glassDamageCloseGlassImages,
            glassDamageFrontVehicleImages: glassDamageFrontVehicleImages,
            hailDamageImages: hailDamageImages,
            hailDamageOverviewImages: hailDamageOverviewImages,
          ),
        })
        .eq('id', requestId)
        .select()
        .single();

    return AppointmentRequest.fromMap(Map<String, dynamic>.from(res));
  }

  String? _buildStructuredNotes({
    String? notes,
    String? glassDamageTown,
    String? glassDamageDate,
    String? hailDamageTown,
    String? hailDamageDate,
    List<String> glassDamageVehicleDocumentImages = const [],
    List<String> glassDamageCloseGlassImages = const [],
    List<String> glassDamageFrontVehicleImages = const [],
    List<String> hailDamageImages = const [],
    List<String> hailDamageOverviewImages = const [],
  }) {
    final trimmedNotes = notes?.trim();
    final trimmedGlassTown = glassDamageTown?.trim();
    final trimmedGlassDate = glassDamageDate?.trim();
    final trimmedHailTown = hailDamageTown?.trim();
    final trimmedHailDate = hailDamageDate?.trim();
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
    final cleanedHailDamageImages = hailDamageImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedHailOverviewImages = hailDamageOverviewImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final cleanedGlassImages = _mergeUniqueUrls([
      cleanedDocumentImages,
      cleanedCloseGlassImages,
      cleanedFrontVehicleImages,
    ]);

    final hasStructuredData = (trimmedGlassTown?.isNotEmpty ?? false) ||
        (trimmedGlassDate?.isNotEmpty ?? false) ||
        (trimmedHailTown?.isNotEmpty ?? false) ||
        (trimmedHailDate?.isNotEmpty ?? false) ||
        cleanedDocumentImages.isNotEmpty ||
        cleanedCloseGlassImages.isNotEmpty ||
        cleanedFrontVehicleImages.isNotEmpty ||
        cleanedHailDamageImages.isNotEmpty ||
        cleanedHailOverviewImages.isNotEmpty ||
        cleanedGlassImages.isNotEmpty;

    if (!hasStructuredData) {
      return trimmedNotes?.isEmpty ?? true ? null : trimmedNotes;
    }

    return jsonEncode({
      if (trimmedNotes?.isNotEmpty ?? false) 'text': trimmedNotes,
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
      if (trimmedHailTown?.isNotEmpty ?? false) 'hailDamageTown': trimmedHailTown,
      if (trimmedHailDate?.isNotEmpty ?? false) 'hailDamageDate': trimmedHailDate,
      if (cleanedHailDamageImages.isNotEmpty)
        'hailDamageImages': cleanedHailDamageImages,
      if (cleanedHailOverviewImages.isNotEmpty)
        'hailDamageOverviewImages': cleanedHailOverviewImages,
      if (cleanedGlassImages.isNotEmpty) 'glassDamageImages': cleanedGlassImages,
    });
  }

  String _storageRootForDamageImageCategory(String category) {
    switch (category) {
      case AppointmentRequestImageCategory.hailDamage:
      case AppointmentRequestImageCategory.hailOverview:
        return 'hail_damage';
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
      case AppointmentRequestImageCategory.hailDamage:
        return 'damage';
      case AppointmentRequestImageCategory.hailOverview:
        return 'overview';
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
    final hailDamageImages = <String>[];
    final hailOverviewImages = <String>[];
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
        case AppointmentRequestImageCategory.hailDamage:
          hailDamageImages.add(publicUrl);
          break;
        case AppointmentRequestImageCategory.hailOverview:
          hailOverviewImages.add(publicUrl);
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
      hailDamageImages: hailDamageImages,
      hailOverviewImages: hailOverviewImages,
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

  Future<Uint8List?> _resolveInputBytes(AppointmentRequestImageInput image) async {
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
    String? glassDamageTown,
    String? glassDamageDate,
    String? hailDamageTown,
    String? hailDamageDate,
    required List<AppointmentRequestImageInput> glassDamageVehicleDocumentImages,
    required List<AppointmentRequestImageInput> glassDamageCloseGlassImages,
    required List<AppointmentRequestImageInput> glassDamageFrontVehicleImages,
    required List<AppointmentRequestImageInput> hailDamageImages,
    required List<AppointmentRequestImageInput> hailDamageOverviewImages,
  }) async {
    final localId = 'local_req_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toUtc();
    final allImages = [
      ...glassDamageVehicleDocumentImages,
      ...glassDamageCloseGlassImages,
      ...glassDamageFrontVehicleImages,
      ...hailDamageImages,
      ...hailDamageOverviewImages,
    ];
    final allGlassImages = [
      ...glassDamageVehicleDocumentImages,
      ...glassDamageCloseGlassImages,
      ...glassDamageFrontVehicleImages,
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
      notes: notes,
      damageType: damageType,
      locale: locale,
      glassDamageTown: glassDamageTown,
      glassDamageDate: glassDamageDate,
      hailDamageTown: hailDamageTown,
      hailDamageDate: hailDamageDate,
      glassDamageVehicleDocumentImages: glassDamageVehicleDocumentImages
          .map((image) => image.previewReference)
          .toList(),
      glassDamageCloseGlassImages:
          glassDamageCloseGlassImages.map((image) => image.previewReference).toList(),
      glassDamageFrontVehicleImages: glassDamageFrontVehicleImages
          .map((image) => image.previewReference)
          .toList(),
      hailDamageImages:
          hailDamageImages.map((image) => image.previewReference).toList(),
      hailDamageOverviewImages:
          hailDamageOverviewImages.map((image) => image.previewReference).toList(),
      glassDamageImages:
          allGlassImages.map((image) => image.previewReference).toList(),
    );

    final queue = await _loadQueue();
    queue.removeWhere((entry) => entry['id'] == localId);
    queue.add({
      'id': localId,
      'request': localRequest.toMap(),
      'image_descriptors': allImages.map((image) => image.toQueueMap()).toList(),
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
