import 'package:cid_digitale/services/workshop_pdf_inline_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WorkshopPdfPreviewScreen extends StatefulWidget {
  const WorkshopPdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.title,
  });

  final Uint8List bytes;
  final String fileName;
  final String title;

  @override
  State<WorkshopPdfPreviewScreen> createState() =>
      _WorkshopPdfPreviewScreenState();
}

class _WorkshopPdfPreviewScreenState extends State<WorkshopPdfPreviewScreen> {
  String? _pdfUrl;
  String? _viewType;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb || !supportsInlinePdfPreviewWeb()) return;
    _pdfUrl = createPdfPreviewUrlWeb(widget.bytes);
    if (_pdfUrl == null || _pdfUrl!.isEmpty) return;
    _viewType = registerPdfPreviewViewWeb(_pdfUrl!);
  }

  @override
  void dispose() {
    disposePdfPreviewUrlWeb(_pdfUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPreviewInline =
        kIsWeb && supportsInlinePdfPreviewWeb() && _viewType != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(color: Color(0xFF111827)),
        ),
      ),
      body: SafeArea(
        child: canPreviewInline
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: HtmlElementView(viewType: _viewType!),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4B7BFF),
                ),
              ),
      ),
    );
  }
}
