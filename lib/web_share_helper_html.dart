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
      ...extras.map(
        (f) => html.File([f.bytes], f.fileName, {'type': f.mimeType}),
      ),
    ];

    final nav = html.window.navigator;
    final dynamic navDynamic = nav;
    final canShareMethod = navDynamic.canShare;
    final shareMethod = navDynamic.share;

    final canShare = canShareMethod != null
        ? canShareMethod({'files': files}) == true
        : false;

    if (canShare && shareMethod != null) {
      await shareMethod({
        'title': 'CID incidente',
        'text': 'PDF e allegati incidente',
        'files': files,
      });
      return true;
    }
  } catch (_) {
    rethrow;
  }
  return false;
}
