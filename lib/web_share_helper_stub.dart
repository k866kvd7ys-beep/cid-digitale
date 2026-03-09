import 'dart:typed_data';

class WebShareFile {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const WebShareFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}

Future<bool> shareFilesWeb({
  required WebShareFile pdf,
  List<WebShareFile> extras = const <WebShareFile>[],
}) async {
  return false;
}
