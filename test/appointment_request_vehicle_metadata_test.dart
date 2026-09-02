import 'dart:convert';

import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AppointmentApi {
  _AppointmentApi() {
    client = SupabaseClient(
      'https://appointment-metadata-test.supabase.co',
      'appointment-metadata-test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(_handle),
    );
  }

  late final SupabaseClient client;
  Map<String, dynamic>? row;
  final insertPayloads = <Map<String, dynamic>>[];
  final updatePayloads = <Map<String, dynamic>>[];

  Future<http.Response> _handle(http.Request request) async {
    if (request.url.path == '/rest/v1/appointment_requests') {
      if (request.method == 'POST') {
        final payload = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        insertPayloads.add(payload);
        row = _rowFromPayload(payload);
        return _jsonResponse(row!, request);
      }
      if (request.method == 'GET' && row != null) {
        return _jsonResponse(row!, request);
      }
      if (request.method == 'PATCH' && row != null) {
        final payload = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        updatePayloads.add(payload);
        row = <String, dynamic>{...row!, ...payload};
        return _jsonResponse(row!, request);
      }
    }

    return http.Response(
      jsonEncode(<String, dynamic>{'error': 'Unsupported request'}),
      400,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }

  Map<String, dynamic> _rowFromPayload(Map<String, dynamic> payload) => {
    'id': 'request-${insertPayloads.length}',
    'created_at': '2026-09-02T10:00:00.000Z',
    'updated_at': '2026-09-02T10:00:00.000Z',
    ...payload,
  };

  http.Response _jsonResponse(Map<String, dynamic> body, http.Request request) {
    return http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

Future<T> _withConnectivity<T>(bool online, Future<T> Function() operation) {
  return http.runWithClient<Future<T>>(
    operation,
    () => MockClient(
      (request) async =>
          http.Response('', online ? 200 : 503, request: request),
    ),
  );
}

Map<String, dynamic> _decodeNotes(Map<String, dynamic> payload) {
  return Map<String, dynamic>.from(
    jsonDecode(payload['notes'] as String) as Map,
  );
}

Future<AppointmentRequest> _createRequest(
  AppointmentRequestsService service, {
  String? vehicleBrand,
  String? vehicleModel,
  String? insurance,
  String? policyNumber,
}) {
  return service.createRequest(
    serviceType: 'service_anmelden',
    appointmentDate: DateTime(2026, 9, 3),
    appointmentTime: '14:30:00',
    licensePlate: 'AG399854',
    vehicleBrand: vehicleBrand,
    vehicleModel: vehicleModel,
    insurance: insurance,
    policyNumber: policyNumber,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'creation writes selected vehicle and insurance values into notes',
    () async {
      final api = _AppointmentApi();
      addTearDown(api.client.dispose);
      final service = AppointmentRequestsService(client: api.client);

      await _withConnectivity(
        true,
        () => _createRequest(
          service,
          vehicleBrand: ' Audi ',
          vehicleModel: ' e-tron ',
          insurance: ' Zurich ',
          policyNumber: ' POL-BOOKING ',
        ),
      );

      final payload = api.insertPayloads.single;
      final notes = _decodeNotes(payload);
      expect(notes['vehicle_brand'], 'Audi');
      expect(notes['vehicle_model'], 'e-tron');
      expect(notes['insurance'], 'Zurich');
      expect(notes['policy_number'], 'POL-BOOKING');
      expect(payload, isNot(contains('vehicle_brand')));
      expect(payload, isNot(contains('vehicle_model')));
      expect(payload, isNot(contains('insurance')));
      expect(payload, isNot(contains('policy_number')));
    },
  );

  test(
    'status update and cancellation preserve vehicle metadata in notes',
    () async {
      final api = _AppointmentApi();
      addTearDown(api.client.dispose);
      final service = AppointmentRequestsService(client: api.client);

      final created = await _withConnectivity(
        true,
        () => _createRequest(
          service,
          vehicleBrand: 'Audi',
          vehicleModel: 'e-tron',
          insurance: 'Zurich',
          policyNumber: 'POL-BOOKING',
        ),
      );

      await service.updateRequestStatus(
        requestId: created.id,
        requestStatus: 'confirmed',
      );
      await service.cancelRequest(created.id);

      expect(api.updatePayloads, hasLength(2));
      for (final payload in api.updatePayloads) {
        final notes = _decodeNotes(payload);
        expect(notes['vehicle_brand'], 'Audi');
        expect(notes['vehicle_model'], 'e-tron');
        expect(notes['insurance'], 'Zurich');
        expect(notes['policy_number'], 'POL-BOOKING');
      }
      expect(
        _decodeNotes(api.updatePayloads.last)['requestStatus'],
        'cancelled',
      );
    },
  );

  test(
    'offline queue and later synchronization preserve vehicle metadata',
    () async {
      final api = _AppointmentApi();
      addTearDown(api.client.dispose);
      final service = AppointmentRequestsService(client: api.client);

      final queued = await _withConnectivity(
        false,
        () => _createRequest(
          service,
          vehicleBrand: 'Audi',
          vehicleModel: 'e-tron',
          insurance: 'Zurich',
          policyNumber: 'POL-BOOKING',
        ),
      );
      final updatedQueueRequest = await service.updateRequestStatus(
        requestId: queued.id,
        requestStatus: 'confirmed',
      );
      expect(updatedQueueRequest.vehicleBrand, 'Audi');
      expect(updatedQueueRequest.vehicleModel, 'e-tron');
      expect(updatedQueueRequest.insurance, 'Zurich');
      expect(updatedQueueRequest.policyNumber, 'POL-BOOKING');

      await _withConnectivity(true, service.syncPendingRequests);

      final notes = _decodeNotes(api.insertPayloads.single);
      expect(notes['vehicle_brand'], 'Audi');
      expect(notes['vehicle_model'], 'e-tron');
      expect(notes['insurance'], 'Zurich');
      expect(notes['policy_number'], 'POL-BOOKING');
      expect(notes['requestStatus'], 'confirmed');

      final preferences = await SharedPreferences.getInstance();
      expect(
        jsonDecode(preferences.getString('pendingAppointmentRequestsQueue')!),
        isEmpty,
      );
    },
  );

  test(
    'null and blank values are omitted and legacy notes remain valid',
    () async {
      final api = _AppointmentApi();
      addTearDown(api.client.dispose);
      final service = AppointmentRequestsService(client: api.client);

      await _withConnectivity(
        true,
        () => _createRequest(
          service,
          vehicleBrand: null,
          vehicleModel: '   ',
          insurance: '',
          policyNumber: null,
        ),
      );
      final blankNotes = _decodeNotes(api.insertPayloads.single);
      expect(blankNotes, isNot(contains('vehicle_brand')));
      expect(blankNotes, isNot(contains('vehicle_model')));
      expect(blankNotes, isNot(contains('insurance')));
      expect(blankNotes, isNot(contains('policy_number')));

      api.row = {
        'id': 'legacy-request',
        'created_at': '2026-08-01T10:00:00.000Z',
        'updated_at': '2026-08-01T10:00:00.000Z',
        'service_type': 'service_anmelden',
        'appointment_date': '2026-09-03',
        'appointment_time': '14:30:00',
        'duration_minutes': 60,
        'status': 'pending',
        'notes': jsonEncode({
          'text': 'Richiesta precedente',
          'requestStatus': 'pending',
        }),
      };
      await service.updateRequestStatus(
        requestId: 'legacy-request',
        requestStatus: 'confirmed',
      );

      final legacyNotes = _decodeNotes(api.updatePayloads.single);
      expect(legacyNotes['text'], 'Richiesta precedente');
      expect(legacyNotes['requestStatus'], 'confirmed');
      expect(legacyNotes, isNot(contains('vehicle_brand')));
      expect(legacyNotes, isNot(contains('vehicle_model')));
      expect(legacyNotes, isNot(contains('insurance')));
      expect(legacyNotes, isNot(contains('policy_number')));
    },
  );
}
