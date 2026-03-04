import 'dart:convert';

String? extractTokenFromQr(String raw) {
  final s = raw.trim();

  // Legacy: CID1:<token>
  if (s.toUpperCase().startsWith('CID1:')) {
    final t = s.substring(5).trim();
    return t.isEmpty ? null : t;
  }

  // URL: ...?token=<token>
  try {
    final uri = Uri.parse(s);
    final t = uri.queryParameters['token'];
    if (t != null && t.trim().isNotEmpty) return t.trim();
  } catch (_) {}

  // JSON: {"token":"..."} (opzionale)
  try {
    final obj = jsonDecode(s);
    if (obj is Map && obj['token'] is String) {
      final t = (obj['token'] as String).trim();
      if (t.isNotEmpty) return t;
    }
  } catch (_) {}

  return null;
}
