import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment_request.dart';
import '../utils/service_booking_helper.dart';
import '../utils/tire_service_type_helper.dart';

/// Centralized email notifications helper.
/// Best-effort: failures are logged and never rethrown to callers.
class EmailNotificationsService {
  EmailNotificationsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Sends a confirmation email for an appointment request via Supabase Edge Function.
  Future<void> sendAppointmentConfirmation({
    required AppointmentRequest request,
    String functionName = 'send-appointment-confirmation',
  }) async {
    final recipient = request.customerEmail?.trim() ?? '';
    if (recipient.isEmpty) {
      debugPrint('Skip email confirmation: missing recipient');
      return;
    }

    final payload = _buildPayload(request);

    try {
      await _client.functions.invoke(functionName, body: payload);
    } catch (e) {
      debugPrint('sendAppointmentConfirmation failed: $e');
    }
  }

  Map<String, dynamic> _buildPayload(AppointmentRequest request) {
    final dateLabel = DateFormat('dd.MM.yyyy').format(request.appointmentDate);
    final timeLabel = _formatTime(request.appointmentTime);
    final locale = normalizeWorkshopServiceLocale(request.locale);
    final cleaningPackage = _cleaningPackageLabel(request);
    final inspectionDetail = _inspectionDetailLabel(request);
    final additionalServices = _additionalServiceLabels(request);
    final serviceLabel = _mapServiceLabel(request);

    return {
      'recipient': request.customerEmail,
      'name': request.customerName,
      'plate': request.licensePlate,
      'service': cleaningPackage == null &&
              inspectionDetail == null &&
              additionalServices.isEmpty
          ? serviceLabel
          : [
              serviceLabel,
              if (inspectionDetail != null)
                '${workshopInspectionSelectionFieldLabel(locale)}: $inspectionDetail',
              if (cleaningPackage != null)
                '${workshopCleaningPackageFieldLabel(locale)}: $cleaningPackage',
              if (additionalServices.isNotEmpty)
                '${workshopAdditionalServicesFieldLabel(locale)}:\n- ${additionalServices.join('\n- ')}',
            ].join('\n'),
      'date': dateLabel,
      'time': timeLabel,
      if (inspectionDetail != null)
        'service_detail_label': workshopInspectionSelectionFieldLabel(locale),
      if (inspectionDetail != null) 'service_detail': inspectionDetail,
      if (cleaningPackage != null)
        'cleaning_package_label': workshopCleaningPackageFieldLabel(locale),
      if (cleaningPackage != null) 'cleaning_package': cleaningPackage,
      if (additionalServices.isNotEmpty)
        'additional_services_label':
            workshopAdditionalServicesFieldLabel(locale),
      if (additionalServices.isNotEmpty)
        'additional_services': additionalServices,
    };
  }

  String _formatTime(String raw) {
    final normalized = raw.length == 5 ? '$raw:00' : raw;
    final parsed = DateFormat('HH:mm:ss').tryParse(normalized);
    if (parsed == null) return raw;
    return DateFormat('HH:mm').format(parsed);
  }

  String _mapServiceLabel(AppointmentRequest request) {
    if (isTireAppointmentService(request.serviceType)) {
      return localizedTireServiceType(
        tireLocaleFromString(request.locale),
        tireServiceType: request.tireServiceType,
        serviceType: request.serviceType,
      );
    }

    switch (request.serviceType) {
      case 'raeder_sommer':
        return 'Räderwechsel Sommer';
      case 'raeder_winter':
        return 'Räderwechsel Winter';
      case 'service_anmelden':
        return request.serviceSelectionKey?.trim().isNotEmpty == true
            ? workshopServiceLabel(
                normalizeWorkshopServiceLocale(request.locale),
                request.serviceSelectionKey,
              )
            : 'Service';
      case workshopServiceInspection:
        return workshopServiceLabel(
          normalizeWorkshopServiceLocale(request.locale),
          workshopServiceInspection,
        );
      case 'damage_glass':
        return 'Glasschaden';
      default:
        return request.serviceType;
    }
  }

  String? _cleaningPackageLabel(AppointmentRequest request) {
    final isRepairFlow = request.serviceType == 'service_anmelden' &&
        request.serviceSelectionKey == workshopServiceRepair;
    final isInspectionFlow = request.serviceType == workshopServiceInspection;
    if (!isRepairFlow && !isInspectionFlow) {
      return null;
    }

    return workshopCleaningPackageLabel(
      normalizeWorkshopServiceLocale(request.locale),
      request.cleaningPackage,
    );
  }

  String? _inspectionDetailLabel(AppointmentRequest request) {
    if (request.serviceType != workshopServiceInspection ||
        request.serviceDetail?.trim().isNotEmpty != true) {
      return null;
    }
    return workshopInspectionDetailLabel(
      normalizeWorkshopServiceLocale(request.locale),
      request.serviceDetail,
    );
  }

  List<String> _additionalServiceLabels(AppointmentRequest request) {
    if (request.additionalServices.isEmpty) return const [];
    final locale = normalizeWorkshopServiceLocale(request.locale);
    return request.additionalServices
        .map((service) => workshopAdditionalServiceLabel(locale, service))
        .toList();
  }
}
