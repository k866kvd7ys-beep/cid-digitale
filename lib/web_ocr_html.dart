// Web-only OCR helper using Tesseract.js loaded in web/index.html.
import 'dart:html' as html;
import 'dart:js_interop';

@JS('Tesseract')
external JSAny? get _tesseract;

@JS('Tesseract.recognize')
external JSPromise<JSAny?> _tesseractRecognize(String url, String lang);

@JS()
@staticInterop
class _TessResult {}

extension _TessResultExt on _TessResult {
  external JSAny? get data;
}

@JS()
@staticInterop
class _TessData {}

extension _TessDataExt on _TessData {
  external String get text;
}

Future<String?> performWebOcr(List<int> bytes) async {
  if (_tesseract == null) return null;

  final blob = html.Blob([bytes], 'image/jpeg');
  final url = html.Url.createObjectUrlFromBlob(blob);

  try {
    final promise = _tesseractRecognize(url, 'eng');
    final result = await promise.toDart;
    if (result == null) return null;
    final tessResult = result as _TessResult;
    final data = tessResult.data as _TessData?;
    final text = data?.text;
    return text?.trim();
  } catch (_) {
    return null;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
