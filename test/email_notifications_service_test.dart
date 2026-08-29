import 'dart:convert';
import 'dart:io';

import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/services/email_notifications_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  AppointmentRequest request({String? phone}) {
    final timestamp = DateTime.utc(2026, 8, 29, 10);
    return AppointmentRequest(
      id: 'request-1',
      createdAt: timestamp,
      updatedAt: timestamp,
      serviceType: 'service_test',
      appointmentDate: DateTime(2026, 9, 3),
      appointmentTime: '14:30:00',
      durationMinutes: 60,
      customerName: 'Mario Rossi',
      customerPhone: phone,
      customerEmail: 'mario.rossi@example.com',
      licensePlate: 'TI123456',
      garageName: 'Garage Test',
      garageAddress: 'Via Test 1',
      garageCity: 'Lugano',
      status: 'pending',
      locale: 'it',
    );
  }

  Future<Map<String, dynamic>> sendAndCapture(
      AppointmentRequest request) async {
    Map<String, dynamic>? capturedPayload;
    final client = SupabaseClient(
      'https://appointment-email-test.supabase.co',
      'appointment-email-test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((incomingRequest) async {
        expect(
          incomingRequest.url.path,
          '/functions/v1/send-appointment-confirmation',
        );
        capturedPayload = Map<String, dynamic>.from(
          jsonDecode(incomingRequest.body) as Map,
        );
        return http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json'},
          request: incomingRequest,
        );
      }),
    );
    addTearDown(client.dispose);

    await EmailNotificationsService(client: client)
        .sendAppointmentConfirmation(request: request);

    return capturedPayload!;
  }

  test('confirmation payload includes the customer phone', () async {
    final payload = await sendAndCapture(request(phone: '+41 79 123 45 67'));

    expect(payload['phone'], '+41 79 123 45 67');
    expect(payload['name'], 'Mario Rossi');
    expect(payload['recipient'], 'mario.rossi@example.com');
    expect(payload['plate'], 'TI123456');
    expect(payload['service'], 'service_test');
    expect(payload['date'], '03.09.2026');
    expect(payload['time'], '14:30');
    expect(payload['selected_workshop_name'], 'Garage Test');
    expect(payload['selected_workshop_address'], 'Via Test 1');
    expect(payload['selected_workshop_city'], 'Lugano');
  });

  test('confirmation payload leaves phone empty when it is unavailable',
      () async {
    final payload = await sendAndCapture(request());

    expect(payload['phone'], isNull);
    expect(payload['name'], 'Mario Rossi');
    expect(payload['recipient'], 'mario.rossi@example.com');
  });

  test('email template uses the phone and falls back to a dash', () {
    final source = File(
      'supabase/functions/send-appointment-confirmation/index.ts',
    ).readAsStringSync();

    expect(
      source,
      contains('const customerPhone = stringOrDash(payload?.phone);'),
    );
    expect(source, contains('return trimmed.length === 0 ? "-" : trimmed;'));
    expect(source, contains(r'`${copy.phone}: ${customerPhone}`'));
    expect(
      source,
      contains('buildHtmlDetailRow(copy.phone, escapeHtml(customerPhone))'),
    );
  });
}
