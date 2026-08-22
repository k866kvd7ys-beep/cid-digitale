import 'dart:convert';

import 'package:cid_digitale/services/cid_email_function_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _supabaseUrl = 'https://project.supabase.co';
const _apiKey = 'sb_publishable_test';
const _accessToken = 'header.payload.signature';
const _claimId = 'b4c49c15-aabc-4608-b1d7-47b07160a5a3';

CidEmailFunctionClient _client(
  http.Client httpClient, {
  Future<String?> Function()? accessTokenProvider,
}) {
  return CidEmailFunctionClient(
    supabaseUrl: _supabaseUrl,
    apiKey: _apiKey,
    accessTokenProvider: accessTokenProvider ?? () async => _accessToken,
    httpClient: httpClient,
  );
}

String? _header(http.BaseRequest request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

void main() {
  test('invia POST con apikey e JWT della sessione autenticata', () async {
    late http.Request capturedRequest;
    final httpClient = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final result = await _client(httpClient).send(claimId: _claimId);

    expect(result.statusCode, 200);
    expect(capturedRequest.method, 'POST');
    expect(
      capturedRequest.url.toString(),
      '$_supabaseUrl/functions/v1/send-cid-email',
    );
    expect(_header(capturedRequest, 'apikey'), _apiKey);
    expect(
      _header(capturedRequest, 'authorization'),
      'Bearer $_accessToken',
    );
    expect(_header(capturedRequest, 'content-type'), 'application/json');
    expect(jsonDecode(capturedRequest.body), <String, String>{
      'claimId': _claimId,
    });
  });

  test('401 produce errore non autorizzato senza tentare parsing JSON',
      () async {
    final httpClient = MockClient((_) async {
      return http.Response(
        '<html>Unauthorized</html>',
        401,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await expectLater(
      _client(httpClient).send(claimId: _claimId),
      throwsA(
        isA<CidEmailSendException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having(
              (error) => error.userMessage,
              'userMessage',
              'Invio e-mail non autorizzato',
            )
            .having(
              (error) => error.technicalDetails,
              'technicalDetails',
              contains('<html>Unauthorized</html>'),
            ),
      ),
    );
  });

  test('risposta HTML non JSON genera un errore leggibile', () async {
    final httpClient = MockClient((_) async {
      return http.Response(
        '<html>Bad gateway</html>',
        502,
        headers: <String, String>{'content-type': 'text/html; charset=utf-8'},
      );
    });

    await expectLater(
      _client(httpClient).send(claimId: _claimId),
      throwsA(
        isA<CidEmailSendException>()
            .having((error) => error.statusCode, 'statusCode', 502)
            .having(
              (error) => error.technicalDetails,
              'technicalDetails',
              allOf(contains('text/html'), contains('Bad gateway')),
            ),
      ),
    );
  });

  test('JSON dichiarato ma malformato non espone FormatException', () async {
    final httpClient = MockClient((_) async {
      return http.Response(
        '<html>temporarily unavailable</html>',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await expectLater(
      _client(httpClient).send(claimId: _claimId),
      throwsA(
        isA<CidEmailSendException>()
            .having(
              (error) => error.userMessage,
              'userMessage',
              'Risposta non valida dal servizio e-mail',
            )
            .having(
              (error) => error.technicalDetails,
              'technicalDetails',
              contains('JSON non valido'),
            ),
      ),
    );
  });

  test('retry riusa lo stesso endpoint e gli stessi header autenticati',
      () async {
    var attempts = 0;
    final authorizationHeaders = <String?>[];
    final httpClient = MockClient((request) async {
      attempts += 1;
      authorizationHeaders.add(_header(request, 'authorization'));
      if (attempts == 1) {
        return http.Response(
          jsonEncode(<String, dynamic>{'error': 'Invalid JWT'}),
          401,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final client = _client(httpClient);

    await expectLater(
      client.send(claimId: _claimId),
      throwsA(isA<CidEmailSendException>()),
    );
    final retryResult = await client.send(claimId: _claimId);

    expect(retryResult.statusCode, 200);
    expect(attempts, 2);
    expect(authorizationHeaders, <String?>[
      'Bearer $_accessToken',
      'Bearer $_accessToken',
    ]);
  });

  test('successo richiede conferma success true', () async {
    final httpClient = MockClient((_) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'message': 'Email inviata correttamente',
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final result = await _client(httpClient).send(claimId: _claimId);

    expect(result.payload['success'], isTrue);
    expect(result.payload['message'], 'Email inviata correttamente');
  });

  test('stato gia inviato non crea una seconda chiamata', () async {
    var requestCount = 0;
    final httpClient = MockClient((_) async {
      requestCount += 1;
      return http.Response('{}', 500);
    });

    final result = await _client(httpClient).send(
      claimId: _claimId,
      alreadySent: true,
    );

    expect(result.alreadySent, isTrue);
    expect(requestCount, 0);
  });

  test('sessione assente non usa la publishable key come bearer', () async {
    var requestCount = 0;
    final httpClient = MockClient((_) async {
      requestCount += 1;
      return http.Response('{}', 200);
    });

    await expectLater(
      _client(
        httpClient,
        accessTokenProvider: () async => null,
      ).send(claimId: _claimId),
      throwsA(
        isA<CidEmailSendException>()
            .having((error) => error.statusCode, 'statusCode', 401),
      ),
    );
    expect(requestCount, 0);
  });
}
