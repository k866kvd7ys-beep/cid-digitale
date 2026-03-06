import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/appointment_request.dart';

class AppointmentRequestsService {
  AppointmentRequestsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AppointmentRequest>> fetchMyRequests({
    String? email,
    String? phone,
    String? licensePlate,
    String? serviceFilter, // 'all'|'service'|'tires'|'damage'
  }) async {
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
    return list.map(AppointmentRequest.fromMap).toList();
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
  }) async {
    final payload = <String, dynamic>{
      'service_type': serviceType,
      'appointment_date': (appointmentDate ?? DateTime.now()).toIso8601String(),
      'appointment_time': appointmentTime ?? '08:00:00',
      'duration_minutes': durationMinutes,
      'customer_name': customerName,
      'phone': phone,
      'email': email,
      'license_plate': licensePlate,
      'notes': notes,
      'locale': locale,
      'damage_type': damageType,
    };

    final res = await _client
        .from('appointment_requests')
        .insert(payload)
        .select()
        .single();
    return AppointmentRequest.fromMap(res as Map<String, dynamic>);
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

    return list.map((row) {
      final tRaw = (row['appointment_time'] ?? '') as String;
      final t = tRaw.length == 5 ? '$tRaw:00' : tRaw;
      final parsed = DateFormat('HH:mm:ss').parse(t);
      return DateTime(
        base.year,
        base.month,
        base.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
      );
    }).toList();
  }

  Future<void> cancelRequest(String id) async {
    await _client.from('appointment_requests').update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
