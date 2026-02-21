import 'package:flutter/foundation.dart';

class QrPayload {
  static String cid1(String token) {
    final t = token.trim();
    if (t.isEmpty) return '';
    return 'CID1:$t';
  }

  static bool looksLikeToken(String s) {
    final t = s.trim();
    // token in claim_links: spesso hex lungo (32..128). Evita UUID.
    final hex = RegExp(r'^[0-9a-fA-F]{32,128}$');
    return hex.hasMatch(t);
  }

  static bool looksLikeUuid(String s) {
    final t = s.trim();
    final uuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuid.hasMatch(t);
  }

  static void debugLog(String token) {
    if (!kDebugMode) return;
    debugPrint('CLIENT_QR_TOKEN_LEN=${token.trim().length}');
    debugPrint('CLIENT_QR_DATA=${cid1(token)}');
  }
}
