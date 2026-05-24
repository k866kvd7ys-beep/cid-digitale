// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
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
  if (shouldOpenPdfInNewTabForDownloadWeb()) {
    await _openPdfDataUrlOnIosSafari(
      bytes: bytes,
      fileName: fileName,
      preparedWindow: preparedWindow,
    );
    return;
  }

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
  if (shouldOpenPdfInNewTabForDownloadWeb()) {
    await _openPdfDataUrlOnIosSafari(
      bytes: bytes,
      fileName: fileName,
      preparedWindow: preparedWindow,
    );
    return;
  }

  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
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

Future<void> _openPdfDataUrlOnIosSafari({
  required Uint8List bytes,
  required String fileName,
  Object? preparedWindow,
}) async {
  final popup = preparedWindow is html.WindowBase
      ? preparedWindow
      : html.window.open('', '_blank');
  final base64Pdf = base64Encode(bytes);
  final dataUrl = 'data:application/pdf;base64,$base64Pdf';

  try {
    _writeIosSafariFallbackPage(
      popup: popup,
      fileName: fileName,
      dataUrl: dataUrl,
    );
  } catch (_) {
    _openDataUrlInNewTab(dataUrl);
  }
}

void _writeIosSafariFallbackPage({
  required html.WindowBase popup,
  required String fileName,
  required String dataUrl,
}) {
  final escapedTitle = const HtmlEscape().convert(fileName);
  final escapedDataUrl = const HtmlEscape().convert(dataUrl);
  final dataUrlJs = jsonEncode(dataUrl);
  final htmlContent = '''
<!DOCTYPE html>
<html lang="de">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$escapedTitle</title>
  </head>
  <body style="margin:0;background:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#111827;">
    <div style="min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;box-sizing:border-box;">
      <div style="width:100%;max-width:420px;background:#ffffff;border:1px solid #e5e7eb;border-radius:24px;box-shadow:0 10px 30px rgba(17,24,39,0.08);padding:28px;box-sizing:border-box;text-align:center;">
        <div style="width:46px;height:46px;border:3px solid #dbeafe;border-top-color:#4b7bff;border-radius:999px;margin:0 auto 18px;animation:spin 1s linear infinite;"></div>
        <div style="font-size:20px;font-weight:700;margin-bottom:8px;">PDF wird geöffnet...</div>
        <div style="font-size:14px;line-height:1.5;color:#6b7280;margin-bottom:18px;">Falls Safari das PDF nicht direkt anzeigt, verwenden Sie bitte den folgenden Button.</div>
        <a href="$escapedDataUrl" target="_blank" rel="noopener" style="display:inline-flex;align-items:center;justify-content:center;min-height:48px;padding:0 20px;border-radius:16px;background:#4b7bff;color:#ffffff;font-weight:700;font-size:15px;text-decoration:none;">PDF in neuem Fenster öffnen</a>
      </div>
    </div>
    <script>
      setTimeout(function () {
        try {
          window.location.href = $dataUrlJs;
        } catch (error) {}
      }, 60);
    </script>
    <style>
      @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
    </style>
  </body>
</html>
''';

  final dynamic popupDynamic = popup;
  final dynamic document = popupDynamic.document;
  document?.open();
  document?.write(htmlContent);
  document?.close();
}

void _openDataUrlInNewTab(String dataUrl) {
  final anchor = html.AnchorElement(href: dataUrl)
    ..target = '_blank'
    ..rel = 'noopener'
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}
