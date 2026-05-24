import 'dart:typed_data';

Object? preparePdfWindowWeb({
  String? title,
}) {
  return null;
}

bool shouldOpenPdfInNewTabForDownloadWeb() {
  return false;
}

Future<void> openPdfPreviewWeb({
  required Uint8List bytes,
  required String fileName,
  Object? preparedWindow,
}) async {}

Future<void> downloadPdfWeb({
  required Uint8List bytes,
  required String fileName,
  Object? preparedWindow,
}) async {}

Future<void> closePreparedPdfWindowWeb(Object? preparedWindow) async {}
