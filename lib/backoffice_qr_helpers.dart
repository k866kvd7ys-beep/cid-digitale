// INCOLLA QUI - Token sicuro + payload QR (solo idPratica + token)
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'backoffice_models.dart';

String _bytesToBase64Url(List<int> bytes) {
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// Genera un token random (non memorizzarlo mai in chiaro).
String generateRandomToken({int byteLength = 32}) {
  final secure = Random.secure();
  final bytes = List<int>.generate(byteLength, (_) => secure.nextInt(256));
  return _bytesToBase64Url(bytes);
}

/// Hash SHA-256 del token: da salvare in archivio locale/backoffice.
String hashToken(String token) {
  return sha256.convert(utf8.encode(token)).toString();
}

/// Costruisce il payload QR minimal con id pratica + token.
String buildQrPayload({required String claimId, required String token}) {
  return 'CID:$claimId|T:$token';
}

/// Validazione token: confronta l'hash calcolato con quello salvato.
bool validateToken({required String providedToken, required String storedHash}) {
  return hashToken(providedToken) == storedHash;
}

class SecureQrBundle {
  final String claimId;
  final String token; // Consegnato solo a chi genera il QR.
  final String hashedToken; // Da salvare e usare per verifiche.
  final String qrPayload; // Stringa da mostrare/mandare all'officina.

  const SecureQrBundle._({
    required this.claimId,
    required this.token,
    required this.hashedToken,
    required this.qrPayload,
  });

  factory SecureQrBundle.newClaim({String? claimId}) {
    final generatedId =
        claimId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final token = generateRandomToken();
    final hashed = hashToken(token);
    final payload = buildQrPayload(claimId: generatedId, token: token);

    return SecureQrBundle._(
      claimId: generatedId,
      token: token,
      hashedToken: hashed,
      qrPayload: payload,
    );
  }
}

// INCOLLA QUI - helper locale per creare una ClaimRecord da bundle
ClaimRecord buildClaimFromBundle(
  SecureQrBundle bundle, {
  ClaimStatus status = ClaimStatus.attiva,
  DateTime? now,
  String? codiceOfficina,
}) {
  final base = now ?? DateTime.now().toUtc();
  return ClaimRecord(
    idPratica: bundle.claimId,
    hashedToken: bundle.hashedToken,
    createdAt: base,
    expiresAt: base.add(const Duration(days: 30)),
    retentionUntil: base.add(const Duration(days: 3650)),
    status: status,
    messages: const [],
    attachments: const [],
    codiceOfficina: codiceOfficina,
  );
}
