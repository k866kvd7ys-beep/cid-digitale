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
  required List<WebShareFile> files,
  String title = 'CID incidente',
  String text = '',
}) async {
  return false;
}

String webUserAgent() => 'non-web';
bool webNavigatorShareAvailable() => false;
