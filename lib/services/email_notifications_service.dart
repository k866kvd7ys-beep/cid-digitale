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
    debugPrint('[EmailConfirm] start');
    final recipient = request.customerEmail?.trim() ?? '';
    debugPrint('[EmailConfirm] recipient $recipient');
    if (recipient.isEmpty) {
      debugPrint('[EmailConfirm] send error missing recipient');
      return;
    }

    final payload = _buildPayload(request);
    debugPrint('[EmailConfirm] payload ready');

    final result = await _client.functions.invoke(functionName, body: payload);
    final responseData = result.data;

    if (result.status >= 400) {
      debugPrint(
        '[EmailConfirm] send error status=${result.status} data=$responseData',
      );
      throw Exception('Edge function status ${result.status}');
    }

    if (responseData is Map && responseData['success'] == false) {
      final errorMessage =
          responseData['error']?.toString() ?? 'Email send failed';
      debugPrint('[EmailConfirm] send error $errorMessage');
      throw Exception(errorMessage);
    }

    debugPrint(
      '[EmailConfirm] send success status=${result.status} data=$responseData',
    );
  }

  Map<String, dynamic> _buildPayload(AppointmentRequest request) {
    final dateLabel = DateFormat('dd.MM.yyyy').format(request.appointmentDate);
    final timeLabel = _formatTime(request.appointmentTime);
    final locale = normalizeWorkshopServiceLocale(request.locale);
    final cleaningPackage = _cleaningPackageLabel(request);
    final serviceDetail = _serviceDetailLabel(request);
    final additionalServices = _additionalServiceLabels(request);
    final serviceLabel = _mapServiceLabel(request);
    final workshopLabel = _workshopLabel(request);
    final workshopFieldLabel = _workshopFieldLabel(locale);

    return {
      'recipient': request.customerEmail,
      'name': request.customerName,
      'plate': request.licensePlate,
      'service': cleaningPackage == null &&
              serviceDetail == null &&
              additionalServices.isEmpty
          ? serviceLabel
          : [
              serviceLabel,
              if (serviceDetail != null)
                '${workshopInspectionSelectionFieldLabel(locale)}: $serviceDetail',
              if (cleaningPackage != null)
                '${workshopCleaningPackageFieldLabel(locale)}: $cleaningPackage',
              if (additionalServices.isNotEmpty)
                '${workshopAdditionalServicesFieldLabel(locale)}:\n- ${additionalServices.join('\n- ')}',
              if (workshopLabel != null) '$workshopFieldLabel:\n$workshopLabel',
            ].join('\n'),
      'date': dateLabel,
      'time': timeLabel,
      if (workshopLabel != null) 'selected_workshop_label': workshopFieldLabel,
      if (workshopLabel != null) 'selected_workshop': workshopLabel,
      if ((request.garageName?.trim().isNotEmpty ?? false))
        'selected_workshop_name': request.garageName!.trim(),
      if ((request.garageAddress?.trim().isNotEmpty ?? false))
        'selected_workshop_address': request.garageAddress!.trim(),
      if ((request.garageCity?.trim().isNotEmpty ?? false))
        'selected_workshop_city': request.garageCity!.trim(),
      if ((request.garageEmail?.trim().isNotEmpty ?? false))
        'selected_workshop_email': request.garageEmail!.trim(),
      if ((request.garagePhone?.trim().isNotEmpty ?? false))
        'selected_workshop_phone': request.garagePhone!.trim(),
      if (serviceDetail != null)
        'service_detail_label': workshopInspectionSelectionFieldLabel(locale),
      if (serviceDetail != null) 'service_detail': serviceDetail,
      if (cleaningPackage != null)
        'cleaning_package_label': workshopCleaningPackageFieldLabel(locale),
      if (cleaningPackage != null) 'cleaning_package': cleaningPackage,
      if (additionalServices.isNotEmpty)
        'additional_services_label':
            workshopAdditionalServicesFieldLabel(locale),
      if (additionalServices.isNotEmpty)
        'additional_services': additionalServices,
      'locale': request.locale,
      'request_id': request.id,
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

  String? _serviceDetailLabel(AppointmentRequest request) {
    return workshopServiceDetailLabel(
      normalizeWorkshopServiceLocale(request.locale),
      serviceType: request.serviceType,
      serviceSelectionKey: request.serviceSelectionKey,
      serviceDetail: request.serviceDetail,
    );
  }

  List<String> _additionalServiceLabels(AppointmentRequest request) {
    if (request.additionalServices.isEmpty) return const [];
    final locale = normalizeWorkshopServiceLocale(request.locale);
    return request.additionalServices
        .map((service) => workshopAdditionalServiceLabel(locale, service))
        .toList();
  }

  String _workshopFieldLabel(String locale) {
    switch (locale) {
      case 'it':
        return 'Officina selezionata';
      case 'en':
        return 'Selected workshop';
      case 'fr':
        return 'Atelier sélectionné';
      case 'de':
      default:
        return 'Ausgewählte Werkstatt';
    }
  }

  String? _workshopLabel(AppointmentRequest request) {
    final lines = [
      request.garageName?.trim() ?? '',
      request.garageAddress?.trim() ?? '',
      request.garageCity?.trim() ?? '',
    ].where((line) => line.isNotEmpty).toList();

    if (lines.isEmpty) {
      return null;
    }

    return lines.join('\n');
  }
}
