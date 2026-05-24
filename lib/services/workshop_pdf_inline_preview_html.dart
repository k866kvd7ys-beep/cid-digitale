// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

export 'workshop_pdf_inline_preview_stub.dart';

int _pdfPreviewViewCounter = 0;

bool supportsInlinePdfPreviewWeb() {
  return !isIosSafariWeb();
}

bool isIosSafariWeb() {
  final userAgent = html.window.navigator.userAgent.toLowerCase();
  final isIos = userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('ipod');
  final isSafari = userAgent.contains('safari') &&
      !userAgent.contains('crios') &&
      !userAgent.contains('fxios') &&
      !userAgent.contains('edgios');
  return isIos && isSafari;
}

String? createPdfPreviewUrlWeb(Uint8List bytes) {
  final blob = html.Blob([bytes], 'application/pdf');
  return html.Url.createObjectUrlFromBlob(blob);
}

String? registerPdfPreviewViewWeb(String pdfUrl) {
  final viewType = 'workshop-pdf-preview-${_pdfPreviewViewCounter++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    return html.IFrameElement()
      ..src = pdfUrl
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#FFFFFF'
      ..allowFullscreen = true;
  });
  return viewType;
}

void disposePdfPreviewUrlWeb(String? pdfUrl) {
  if (pdfUrl == null || pdfUrl.isEmpty) return;
  html.Url.revokeObjectUrl(pdfUrl);
}
