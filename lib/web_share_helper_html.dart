// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'web_share_helper_stub.dart';
export 'web_share_helper_stub.dart';

Future<bool> shareFilesWeb({
  required WebShareFile pdf,
  List<WebShareFile> extras = const <WebShareFile>[],
}) async {
  try {
    final files = <html.File>[
      html.File([pdf.bytes], pdf.fileName, {'type': pdf.mimeType}),
    ];

    final nav = html.window.navigator;
    final dynamic navDynamic = nav;
    final shareMethod = navDynamic.share;

    if (shareMethod != null) {
      await shareMethod({
        'title': 'CID incidente',
        'text': 'PDF incidente',
        'files': files,
      });
      return true;
    }
  } catch (_) {
    rethrow;
  }
  return false;
}

String webUserAgent() => html.window.navigator.userAgent ?? '';
bool webNavigatorShareAvailable() => html.window.navigator.share != null;
