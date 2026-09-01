import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef CidEmailAccessTokenProvider = Future<String?> Function();

class CidEmailSendResult {
  const CidEmailSendResult({
    required this.statusCode,
    required this.payload,
    this.alreadySent = false,
  });

  final int statusCode;
  final Map<String, dynamic> payload;
  final bool alreadySent;
}

class CidEmailSendException implements Exception {
  const CidEmailSendException({
    required this.userMessage,
    required this.technicalDetails,
    this.statusCode,
  });

  final String userMessage;
  final String technicalDetails;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'CidEmailSendException($technicalDetails)';
}

class CidEmailFunctionClient {
  CidEmailFunctionClient({
    required String supabaseUrl,
    required String apiKey,
    required CidEmailAccessTokenProvider accessTokenProvider,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 60),
  })  : _endpoint = Uri.parse(
          '${supabaseUrl.replaceFirst(RegExp(r'/$'), '')}'
          '/functions/v1/send-cid-email',
        ),
        _apiKey = apiKey,
        _accessTokenProvider = accessTokenProvider,
        _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  final Uri _endpoint;
  final String _apiKey;
  final CidEmailAccessTokenProvider _accessTokenProvider;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration timeout;

  Future<CidEmailSendResult> send({
    required String claimId,
    bool alreadySent = false,
  }) async {
    if (alreadySent) {
      debugPrint('[CIDEmail] skipped: already sent');
      return const CidEmailSendResult(
        statusCode: 200,
        payload: <String, dynamic>{
          'success': true,
          'alreadySent': true,
        },
        alreadySent: true,
      );
    }

    final accessToken = (await _accessTokenProvider())?.trim() ?? '';
    if (accessToken.isEmpty || accessToken == _apiKey) {
      const details =
          'Sessione Supabase assente: access token utente non disponibile.';
      debugPrint('[CIDEmail] Invio e-mail non autorizzato ($details)');
      throw const CidEmailSendException(
        userMessage: 'Invio e-mail non autorizzato',
        technicalDetails: details,
        statusCode: 401,
      );
    }

    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            _endpoint,
            headers: <String, String>{
              'apikey': _apiKey,
              'Authorization': 'Bearer $accessToken',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, String>{'claimId': claimId}),
          )
          .timeout(timeout);
    } on TimeoutException {
      const details = 'operation=send-cid-email, code=timeout';
      debugPrint('[CIDEmail] $details');
      throw const CidEmailSendException(
        userMessage: 'Invio e-mail non riuscito',
        technicalDetails: details,
      );
    } catch (_) {
      const details = 'operation=send-cid-email, code=network_error';
      debugPrint('[CIDEmail] $details');
      throw const CidEmailSendException(
        userMessage: 'Invio e-mail non riuscito',
        technicalDetails: details,
      );
    }

    final statusCode = response.statusCode;
    final contentType = _contentType(response.headers);
    final bodyText = response.body;

    if (statusCode == 401) {
      final details = _technicalResponseDetails(
        statusCode: statusCode,
        code: 'unauthorized',
      );
      debugPrint('[CIDEmail] Invio e-mail non autorizzato ($details)');
      throw CidEmailSendException(
        userMessage: 'Invio e-mail non autorizzato',
        technicalDetails: details,
        statusCode: statusCode,
      );
    }

    Map<String, dynamic>? jsonBody;
    if (_isJsonContentType(contentType)) {
      try {
        final decoded = bodyText.trim().isEmpty ? null : jsonDecode(bodyText);
        if (decoded is Map) {
          jsonBody = Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        final details = _technicalResponseDetails(
          statusCode: statusCode,
          code: 'invalid_json',
        );
        debugPrint('[CIDEmail] risposta JSON non valida ($details)');
        throw CidEmailSendException(
          userMessage: 'Risposta non valida dal servizio e-mail',
          technicalDetails: details,
          statusCode: statusCode,
        );
      }
    }

    if (statusCode < 200 || statusCode >= 300) {
      final details = _technicalResponseDetails(
        statusCode: statusCode,
        code: 'http_error',
      );
      debugPrint('[CIDEmail] invio rifiutato ($details)');
      throw CidEmailSendException(
        userMessage: 'Invio e-mail non riuscito',
        technicalDetails: details,
        statusCode: statusCode,
      );
    }

    if (jsonBody == null) {
      final details = _technicalResponseDetails(
        statusCode: statusCode,
        code: 'unexpected_response',
      );
      debugPrint('[CIDEmail] risposta non JSON ($details)');
      throw CidEmailSendException(
        userMessage: 'Risposta non valida dal servizio e-mail',
        technicalDetails: details,
        statusCode: statusCode,
      );
    }

    if (jsonBody['success'] != true) {
      final details = _technicalResponseDetails(
        statusCode: statusCode,
        code: 'send_not_confirmed',
      );
      debugPrint('[CIDEmail] risposta senza conferma di invio ($details)');
      throw CidEmailSendException(
        userMessage: 'Invio e-mail non riuscito',
        technicalDetails: details,
        statusCode: statusCode,
      );
    }

    debugPrint('[CIDEmail] response status=$statusCode');
    return CidEmailSendResult(
      statusCode: statusCode,
      payload: _sanitizedSuccessPayload(jsonBody),
      alreadySent: jsonBody['alreadySent'] == true,
    );
  }

  void close() {
    if (_ownsHttpClient) _httpClient.close();
  }

  static String _contentType(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'content-type') return entry.value;
    }
    return '';
  }

  static bool _isJsonContentType(String value) {
    final mediaType = value.toLowerCase().split(';').first.trim();
    return mediaType == 'application/json' || mediaType.endsWith('+json');
  }

  static String _technicalResponseDetails({
    required int statusCode,
    required String code,
  }) {
    return 'operation=send-cid-email, status=$statusCode, code=$code';
  }

  static Map<String, dynamic> _sanitizedSuccessPayload(
    Map<String, dynamic> payload,
  ) {
    final sanitized = <String, dynamic>{'success': true};
    if (payload.containsKey('message')) {
      sanitized['message'] = 'Email inviata correttamente';
    }
    if (payload['alreadySent'] is bool) {
      sanitized['alreadySent'] = payload['alreadySent'];
    }
    if (payload['attachmentsCount'] is int) {
      sanitized['attachmentsCount'] = payload['attachmentsCount'];
    }
    if (payload['pdfAttached'] is bool) {
      sanitized['pdfAttached'] = payload['pdfAttached'];
    }
    return sanitized;
  }
}
