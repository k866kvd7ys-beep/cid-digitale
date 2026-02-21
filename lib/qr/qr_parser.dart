import 'dart:convert';

class QrParsed {
  final String? token;
  final String? legacyClaimId; // vecchio numerico (NON uuid)
  const QrParsed({this.token, this.legacyClaimId});
}

QrParsed parseQr(String raw) {
  final s = raw.trim();

  // 1) URL con query token=... o t=... (anche dentro fragment #/route?token=...)
  final uri = Uri.tryParse(s);
  if (uri != null) {
    final token = uri.queryParameters['token'] ?? uri.queryParameters['t'];
    if (token != null && token.isNotEmpty) return QrParsed(token: token);

    if (uri.fragment.isNotEmpty) {
      final fragUri = Uri.tryParse('https://x/${uri.fragment}');
      if (fragUri != null) {
        final token2 =
            fragUri.queryParameters['token'] ?? fragUri.queryParameters['t'];
        if (token2 != null && token2.isNotEmpty) {
          return QrParsed(token: token2);
        }
      }
    }
  }

  // 2) JSON {"token":"..."} oppure {"t":"..."} oppure legacy {"claimId":"..."}
  if (s.startsWith('{') && s.endsWith('}')) {
    try {
      final map = (jsonDecode(s) as Map).cast<String, dynamic>();
      final token = map['token']?.toString() ?? map['t']?.toString();
      if (token != null && token.isNotEmpty) return QrParsed(token: token);

      final legacy = map['claimId']?.toString() ?? map['claim_id']?.toString();
      if (legacy != null && legacy.isNotEmpty) {
        return QrParsed(legacyClaimId: legacy);
      }
    } catch (_) {}
  }

  // 3) Legacy puro numerico
  if (RegExp(r'^\d+$').hasMatch(s)) return QrParsed(legacyClaimId: s);

  return const QrParsed();
}
