import 'dart:convert';
import 'dart:io';

import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/services/email_notifications_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  AppointmentRequest request({
    String? phone,
    String? vehicleBrand = 'Audi',
    String? vehicleModel = 'e-tron',
  }) {
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
      licensePlate: 'AG399854',
      vehicleBrand: vehicleBrand,
      vehicleModel: vehicleModel,
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
    expect(payload['vehicle'], 'Audi e-tron');
    expect(payload['name'], 'Mario Rossi');
    expect(payload['recipient'], 'mario.rossi@example.com');
    expect(payload['plate'], 'AG399854');
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

  test('confirmation payload omits the vehicle name when unavailable',
      () async {
    final payload = await sendAndCapture(
      request(
        phone: '+41 79 123 45 67',
        vehicleBrand: null,
        vehicleModel: null,
      ),
    );

    expect(payload, isNot(contains('vehicle')));
    expect(payload['plate'], 'AG399854');
    expect(payload['phone'], '+41 79 123 45 67');
  });

  test('confirmation payload uses the available vehicle detail', () async {
    final brandOnly = await sendAndCapture(
      request(vehicleBrand: 'Audi', vehicleModel: null),
    );
    final modelOnly = await sendAndCapture(
      request(vehicleBrand: null, vehicleModel: 'e-tron'),
    );

    expect(brandOnly['vehicle'], 'Audi');
    expect(modelOnly['vehicle'], 'e-tron');
  });

  test('vehicle fields survive the appointment queue map round trip', () {
    final restored = AppointmentRequest.fromMap(request().toMap());

    expect(restored.vehicleBrand, 'Audi');
    expect(restored.vehicleModel, 'e-tron');
    expect(restored.licensePlate, 'AG399854');
  });

  test('service error does not propagate recipient or raw response body',
      () async {
    const sensitiveEmail = 'cliente.sensibile@example.com';
    const sensitiveClaimId = 'claim-sensitive-123';
    final debugMessages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) debugMessages.add(message);
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    final client = SupabaseClient(
      'https://appointment-email-test.supabase.co',
      'appointment-email-test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((incomingRequest) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': false,
            'error': 'Delivery failed for $sensitiveEmail',
            'claimId': sensitiveClaimId,
            'rawBody': <String, dynamic>{'recipient': sensitiveEmail},
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
          request: incomingRequest,
        );
      }),
    );
    addTearDown(client.dispose);

    Object? capturedError;
    try {
      await EmailNotificationsService(client: client)
          .sendAppointmentConfirmation(request: request());
    } catch (error) {
      capturedError = error;
    }

    expect(capturedError, isNotNull);
    final exposedText = <String>[
      capturedError.toString(),
      ...debugMessages,
    ].join('\n');
    expect(exposedText, contains('Email send failed'));
    expect(exposedText, isNot(contains(sensitiveEmail)));
    expect(exposedText, isNot(contains(sensitiveClaimId)));
    expect(exposedText, isNot(contains('rawBody')));
  });

  test('HTTP error does not propagate FunctionException details', () async {
    const sensitiveEmail = 'cliente.http@example.com';
    const sensitiveClaimId = 'claim-http-sensitive-456';
    final debugMessages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) debugMessages.add(message);
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    final client = SupabaseClient(
      'https://appointment-email-test.supabase.co',
      'appointment-email-test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((incomingRequest) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': false,
            'error': 'Delivery failed for $sensitiveEmail',
            'claimId': sensitiveClaimId,
            'rawBody': <String, dynamic>{'recipient': sensitiveEmail},
          }),
          400,
          headers: <String, String>{'content-type': 'application/json'},
          request: incomingRequest,
        );
      }),
    );
    addTearDown(client.dispose);

    Object? capturedError;
    try {
      await EmailNotificationsService(client: client)
          .sendAppointmentConfirmation(request: request());
    } catch (error) {
      capturedError = error;
    }

    expect(capturedError, isNotNull);
    final exposedText = <String>[
      capturedError.toString(),
      ...debugMessages,
    ].join('\n');
    expect(exposedText, contains('Email send failed'));
    expect(exposedText, contains('status=400'));
    expect(exposedText, isNot(contains(sensitiveEmail)));
    expect(exposedText, isNot(contains(sensitiveClaimId)));
    expect(exposedText, isNot(contains('rawBody')));
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
    expect(source, contains('const vehicle = String(payload?.vehicle ??'));
    expect(source, contains('vehicle.length > 0 ? vehicle : null'));
    expect(source, contains('vehicle: "Marca / Modello"'));
    expect(
      source,
      contains('buildHtmlDetailRow(copy.vehicle, escapeHtml(vehicle))'),
    );
    expect(
        source, contains('buildHtmlDetailRow(copy.plate, escapeHtml(plate))'));
    expect(
      source.indexOf('vehicle.length > 0 ? vehicle : null'),
      lessThan(source.indexOf(r'`${copy.plate}: ${plate}`')),
    );
    expect(
      source.indexOf(
        'buildHtmlDetailRow(copy.vehicle, escapeHtml(vehicle))',
      ),
      lessThan(
        source.indexOf('buildHtmlDetailRow(copy.plate, escapeHtml(plate))'),
      ),
    );
  });
}
