import 'package:supabase_flutter/supabase_flutter.dart';

class AppointmentRequestsService {
  AppointmentRequestsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> submitRequest({
    required String serviceType,
    String? damageType,
    DateTime? appointmentDate,
    String? appointmentTime,
    int durationMinutes = 60,
    String? customerName,
    String? phone,
    String? email,
    String? licensePlate,
    String? notes,
    String? locale,
  }) async {
    final payload = <String, dynamic>{
      'source': 'cid_app',
      'locale': locale,
      'service_type': serviceType,
      'damage_type': damageType,
      'duration_minutes': durationMinutes,
      'customer_name':
          customerName?.trim().isEmpty == true ? null : customerName?.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'license_plate':
          licensePlate?.trim().isEmpty == true ? null : licensePlate?.trim(),
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
    };

    if (appointmentDate != null) {
      payload['appointment_date'] =
          appointmentDate.toIso8601String().substring(0, 10);
    }
    if (appointmentTime != null && appointmentTime.trim().isNotEmpty) {
      final t = appointmentTime.trim().length == 5
          ? '${appointmentTime.trim()}:00'
          : appointmentTime.trim();
      payload['appointment_time'] = t;
    }

    await _client.from('appointment_requests').insert(payload);
  }
}
