import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment_request.dart';

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

    return {
      'recipient': request.customerEmail,
      'name': request.customerName,
      'plate': request.licensePlate,
      'service': _mapServiceLabel(request.serviceType),
      'date': dateLabel,
      'time': timeLabel,
    };
  }

  String _formatTime(String raw) {
    final normalized = raw.length == 5 ? '$raw:00' : raw;
    final parsed = DateFormat('HH:mm:ss').tryParse(normalized);
    if (parsed == null) return raw;
    return DateFormat('HH:mm').format(parsed);
  }

  String _mapServiceLabel(String serviceType) {
    switch (serviceType) {
      case 'raeder_sommer':
        return 'Räderwechsel Sommer';
      case 'raeder_winter':
        return 'Räderwechsel Winter';
      case 'service_anmelden':
        return 'Service';
      default:
        return serviceType;
    }
  }
}
