// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'web_share_helper_stub.dart';
export 'web_share_helper_stub.dart';

Future<bool> shareFilesWeb({
  required List<WebShareFile> files,
  String title = 'CID incidente',
  String text = '',
}) async {
  try {
    final shareFiles = <html.File>[
      for (final f in files)
        html.File([f.bytes], f.fileName, {'type': f.mimeType}),
    ];

    final nav = html.window.navigator;
    final dynamic navDynamic = nav;
    final shareMethod = navDynamic.share;

    if (shareMethod != null) {
      await shareMethod({
        'title': title,
        'text': text,
        'files': shareFiles,
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
