// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

export 'workshop_pdf_file_helper_stub.dart';

Object? preparePdfWindowWeb({
  String? title,
}) {
  final popup = html.window.open('', '_blank');
  try {
    final dynamic popupDynamic = popup;
    popupDynamic.document?.title = title ?? 'PDF';
    popupDynamic.document?.body?.setInnerHtml('''
      <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;padding:32px;color:#111827;background:#ffffff;">
        <div style="max-width:420px;margin:0 auto;text-align:center;">
          <div style="width:44px;height:44px;border:3px solid #dbeafe;border-top-color:#4b7bff;border-radius:999px;margin:0 auto 18px;animation:spin 1s linear infinite;"></div>
          <div style="font-size:18px;font-weight:700;margin-bottom:8px;">PDF wird erstellt...</div>
          <div style="font-size:14px;color:#6b7280;">Bitte warten Sie einen Moment.</div>
        </div>
      </div>
      <style>@keyframes spin{from{transform:rotate(0deg)}to{transform:rotate(360deg)}}</style>
    ''', validator: html.NodeValidatorBuilder.common()..allowInlineStyles());
  } catch (_) {}
  return popup;
}

bool shouldOpenPdfInNewTabForDownloadWeb() {
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

Future<void> openPdfPreviewWeb({
  required Uint8List bytes,
  required String fileName,
  Object? preparedWindow,
}) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final popup = preparedWindow is html.WindowBase
      ? preparedWindow
      : html.window.open('', '_blank');
  try {
    final dynamic popupDynamic = popup;
    popupDynamic.document?.title = fileName;
    popup.location.href = url;
  } catch (_) {
    _openUrlInNewTab(url);
  }
  Future<void>.delayed(const Duration(minutes: 1), () {
    html.Url.revokeObjectUrl(url);
  });
}

Future<void> downloadPdfWeb({
  required Uint8List bytes,
  required String fileName,
  Object? preparedWindow,
}) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  if (shouldOpenPdfInNewTabForDownloadWeb()) {
    final popup = preparedWindow is html.WindowBase
        ? preparedWindow
        : html.window.open('', '_blank');
    try {
      popup.location.href = url;
    } catch (_) {
      _openUrlInNewTab(url);
    }
    Future<void>.delayed(const Duration(minutes: 1), () {
      html.Url.revokeObjectUrl(url);
    });
    return;
  }

  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(const Duration(seconds: 5), () {
    html.Url.revokeObjectUrl(url);
  });
}

Future<void> closePreparedPdfWindowWeb(Object? preparedWindow) async {
  if (preparedWindow is html.WindowBase) {
    try {
      preparedWindow.close();
    } catch (_) {}
  }
}

void _openUrlInNewTab(String url) {
  final anchor = html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener'
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}
