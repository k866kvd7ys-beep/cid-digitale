import 'dart:typed_data';

bool supportsInlinePdfPreviewWeb() {
  return false;
}

bool isIosSafariWeb() {
  return false;
}

String? createPdfPreviewUrlWeb(Uint8List bytes) {
  return null;
}

String? registerPdfPreviewViewWeb(String pdfUrl) {
  return null;
}

void disposePdfPreviewUrlWeb(String? pdfUrl) {}
