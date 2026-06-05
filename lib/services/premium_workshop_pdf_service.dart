import 'dart:convert';
import 'dart:io';

import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/services/local_image_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PremiumWorkshopPdfResult {
  const PremiumWorkshopPdfResult({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

class PremiumWorkshopPdfService {
  static const PdfColor _accentOrange = PdfColor(0.9373, 0.4745, 0.1843);
  static const PdfColor _textPrimary = PdfColor(0.0667, 0.0941, 0.1529);
  static const PdfColor _textSecondary = PdfColor(0.4196, 0.4588, 0.5216);
  static const PdfColor _borderColor = PdfColor(0.8980, 0.9098, 0.9255);
  static const PdfColor _statusPending = PdfColor(0.4196, 0.4588, 0.5216);
  static const PdfColor _statusConfirmed = PdfColor(0.1451, 0.3882, 0.9216);
  static const PdfColor _statusInProgress = PdfColor(0.4863, 0.2275, 0.9333);
  static const PdfColor _statusCompleted = PdfColor(0.0863, 0.6392, 0.2902);
  static const PdfColor _statusCancelled = PdfColor(0.8627, 0.2392, 0.2392);

  Future<PremiumWorkshopPdfResult> generatePremiumWorkshopPdf({
    required AppointmentRequest request,
    String? localeCode,
    String? workshopName,
  }) async {
    final locale = _normalizeLocale(localeCode ?? request.locale);
    final document = pw.Document(
      title:
          '${_requestTitle(request, locale)} ${_referenceNumber(request.id)}',
      author: 'CrashForm',
      subject: _requestTitle(request, locale),
    );
    final photoGroups = _photoGroupsFor(request, locale);
    final imageRegistry = await _loadPhotoRegistry(photoGroups);
    final generatedAt = _formatDateTime(DateTime.now());
    final workshopLabel = workshopName?.trim().isNotEmpty == true
        ? workshopName!.trim()
        : _copy(
            locale,
            de: 'CrashForm Partnerwerkstatt',
            it: 'CrashForm Partnerwerkstatt',
            en: 'CrashForm Partner Workshop',
            fr: 'Atelier partenaire CrashForm',
          );
    final photoEntries = <_PhotoPageEntry>[
      for (final group in photoGroups)
        for (var i = 0; i < group.sources.length; i++)
          _PhotoPageEntry(
            title: _photoItemTitle(
              baseTitle: group.title,
              index: i,
              total: group.sources.length,
            ),
            image: imageRegistry[group.sources[i]],
          ),
    ];

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        build: (context) => _buildFirstPage(
          context: context,
          locale: locale,
          request: request,
          generatedAt: generatedAt,
          workshopLabel: workshopLabel,
          photoGroups: photoGroups,
        ),
      ),
    );

    for (final entry in photoEntries) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
          build: (context) => _buildPhotoPage(
            locale: locale,
            request: request,
            entry: entry,
          ),
        ),
      );
    }

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        build: (context) => _buildQrPage(
          locale: locale,
          request: request,
        ),
      ),
    );

    final bytes = await document.save();
    return PremiumWorkshopPdfResult(
      bytes: bytes,
      fileName: _pdfFileName(request.id),
    );
  }

  pw.Widget _buildFirstPage({
    required pw.Context context,
    required String locale,
    required AppointmentRequest request,
    required String generatedAt,
    required String workshopLabel,
    required List<_PhotoGroup> photoGroups,
  }) {
    return pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        ..._buildFirstPageDecorations(),
        pw.Container(
          padding: const pw.EdgeInsets.only(
            left: 8,
            top: 4,
            right: 8,
            bottom: 4,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildFirstPageHeader(
                locale: locale,
                request: request,
                generatedAt: generatedAt,
              ),
              pw.SizedBox(height: 18),
              _buildFirstPageCard(
                title: _copy(
                  locale,
                  de: 'Kunde',
                  it: 'Cliente',
                  en: 'Customer',
                  fr: 'Client',
                ),
                rows: [
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Name',
                      it: 'Nome',
                      en: 'Name',
                      fr: 'Nom',
                    ),
                    value: _valueOrDash(request.customerName),
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Telefon',
                      it: 'Telefono',
                      en: 'Phone',
                      fr: 'Telephone',
                    ),
                    value: _valueOrDash(request.customerPhone),
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'E-Mail',
                      it: 'E-Mail',
                      en: 'E-mail',
                      fr: 'E-mail',
                    ),
                    value: _valueOrDash(request.customerEmail),
                    maxLines: 2,
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Kennzeichen',
                      it: 'Targa',
                      en: 'License plate',
                      fr: 'Plaque',
                    ),
                    value: _valueOrDash(request.licensePlate),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              _buildFirstPageCard(
                title: _copy(
                  locale,
                  de: 'Schaden',
                  it: 'Danno',
                  en: 'Damage',
                  fr: 'Dommage',
                ),
                rows: [
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Typ',
                      it: 'Tipo',
                      en: 'Type',
                      fr: 'Type',
                    ),
                    value: _requestTitle(request, locale),
                    maxLines: 1,
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Ort',
                      it: 'Localita',
                      en: 'Town',
                      fr: 'Localite',
                    ),
                    value: _valueOrDash(_damageTown(request)),
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: _isOtherDamageRequest(request)
                          ? 'Problemtag'
                          : 'Schadentag',
                      it: _isOtherDamageRequest(request)
                          ? 'Data problema'
                          : 'Data danno',
                      en: _isOtherDamageRequest(request)
                          ? 'Problem date'
                          : 'Damage date',
                      fr: _isOtherDamageRequest(request)
                          ? 'Date du probleme'
                          : 'Date du dommage',
                    ),
                    value: _valueOrDash(_damageDateLabel(request)),
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: _isOtherDamageRequest(request)
                          ? 'Problemzeit'
                          : 'Schadenzeit',
                      it: _isOtherDamageRequest(request)
                          ? 'Ora problema'
                          : 'Ora danno',
                      en: _isOtherDamageRequest(request)
                          ? 'Problem time'
                          : 'Damage time',
                      fr: _isOtherDamageRequest(request)
                          ? 'Heure du probleme'
                          : 'Heure du dommage',
                    ),
                    value: _valueOrDash(_damageTime(request)),
                  ),
                  if (_isOtherDamageRequest(request))
                    _PdfRow(
                      label: _copy(
                        locale,
                        de: 'Kategorie',
                        it: 'Categoria',
                        en: 'Category',
                        fr: 'Categorie',
                      ),
                      value: _valueOrDash(
                        _otherDamageCategoryLabel(
                          locale,
                          request.otherDamageCategory,
                        ),
                      ),
                    ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Beschreibung',
                      it: 'Descrizione',
                      en: 'Description',
                      fr: 'Description',
                    ),
                    value: _valueOrDash(_damageDescription(request)),
                    maxLines: 1,
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              _buildFirstPageCard(
                title: _copy(
                  locale,
                  de: 'Termin',
                  it: 'Appuntamento',
                  en: 'Appointment',
                  fr: 'Rendez-vous',
                ),
                rows: [
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Tag',
                      it: 'Giorno',
                      en: 'Day',
                      fr: 'Jour',
                    ),
                    value: _formatDate(request.appointmentDate),
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Uhrzeit',
                      it: 'Orario',
                      en: 'Time',
                      fr: 'Heure',
                    ),
                    value: _appointmentTime(request.appointmentTime),
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Werkstatt',
                      it: 'Officina',
                      en: 'Workshop',
                      fr: 'Atelier',
                    ),
                    value: _appointmentWorkshopValue(locale, workshopLabel),
                    maxLines: 1,
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Fahrzeugstatus',
                      it: 'Stato veicolo',
                      en: 'Vehicle status',
                      fr: 'Etat du vehicule',
                    ),
                    isSectionHeader: true,
                    spacingBefore: 10,
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'KM-Stand',
                      it: 'KM attuali',
                      en: 'Current mileage',
                      fr: 'Kilometrage actuel',
                    ),
                    value: _currentKmValue(locale, photoGroups),
                  ),
                  _PdfRow(
                    label: _copy(
                      locale,
                      de: 'Fahrbereit',
                      it: 'Marciante',
                      en: 'Drivable',
                      fr: 'Peut rouler',
                    ),
                    value: _drivableValue(locale, request),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              _buildFirstPageFooter(
                context: context,
                locale: locale,
                generatedAt: generatedAt,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<pw.Widget> _buildFirstPageDecorations() {
    return [
      pw.Positioned(
        left: -18,
        top: 22,
        child: pw.Opacity(
          opacity: 0.12,
          child: pw.Transform.rotate(
            angle: -0.18,
            child: pw.Container(
              width: 2,
              height: 190,
              color: _accentOrange,
            ),
          ),
        ),
      ),
      pw.Positioned(
        left: 6,
        top: 44,
        child: pw.Opacity(
          opacity: 0.07,
          child: pw.Transform.rotate(
            angle: -0.10,
            child: pw.Container(
              width: 1.2,
              height: 152,
              color: _accentOrange,
            ),
          ),
        ),
      ),
      pw.Positioned(
        right: -16,
        top: 14,
        child: pw.Opacity(
          opacity: 0.12,
          child: pw.Transform.rotate(
            angle: 0.20,
            child: pw.Container(
              width: 2,
              height: 208,
              color: _accentOrange,
            ),
          ),
        ),
      ),
      pw.Positioned(
        right: 8,
        top: 58,
        child: pw.Opacity(
          opacity: 0.07,
          child: pw.Transform.rotate(
            angle: 0.12,
            child: pw.Container(
              width: 1.2,
              height: 136,
              color: _accentOrange,
            ),
          ),
        ),
      ),
      pw.Positioned(
        left: -10,
        bottom: 42,
        child: pw.Opacity(
          opacity: 0.06,
          child: pw.Transform.rotate(
            angle: -0.08,
            child: pw.Container(
              width: 1.2,
              height: 122,
              color: _accentOrange,
            ),
          ),
        ),
      ),
      pw.Positioned(
        right: -8,
        bottom: 36,
        child: pw.Opacity(
          opacity: 0.08,
          child: pw.Transform.rotate(
            angle: 0.10,
            child: pw.Container(
              width: 1.2,
              height: 116,
              color: _accentOrange,
            ),
          ),
        ),
      ),
    ];
  }

  pw.Widget _buildFirstPageHeader({
    required String locale,
    required AppointmentRequest request,
    required String generatedAt,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(28),
        border: pw.Border.all(color: _borderColor, width: 1),
        boxShadow: const [
          pw.BoxShadow(
            color: PdfColor(0, 0, 0, 0.035),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildCrashFormBrand(),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Digital Schaden Report',
                  style: const pw.TextStyle(
                    color: _textSecondary,
                    fontSize: 9.5,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _requestTitle(request, locale),
                  style: pw.TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Container(
            width: 170,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _badge(
                  label: _statusLabel(locale, request.requestStatus),
                  textColor: _accentOrange,
                ),
                pw.SizedBox(height: 8),
                _buildFirstPageMetaBlock(
                  label: _copy(
                    locale,
                    de: 'Nummer',
                    it: 'Numero pratica',
                    en: 'Reference number',
                    fr: 'Numero de dossier',
                  ),
                  value: _referenceNumber(request.id),
                ),
                pw.SizedBox(height: 6),
                _buildFirstPageMetaBlock(
                  label: _copy(
                    locale,
                    de: 'PDF erstellt am',
                    it: 'PDF generato il',
                    en: 'PDF generated on',
                    fr: 'PDF genere le',
                  ),
                  value: generatedAt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCrashFormBrand() {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _buildCrashFormMark(),
        pw.SizedBox(width: 10),
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'CRASH',
              style: pw.TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'FORM',
              style: pw.TextStyle(
                color: _accentOrange,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildCrashFormMark() {
    return pw.Container(
      width: 30,
      height: 30,
      decoration: pw.BoxDecoration(
        color: const PdfColor(1, 0.9765, 0.9608),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _accentOrange, width: 1.4),
      ),
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.Positioned(
            top: 7.5,
            child: pw.Transform.rotate(
              angle: -0.22,
              child: pw.Container(
                width: 8.5,
                height: 1.4,
                color: _accentOrange,
              ),
            ),
          ),
          pw.Positioned(
            top: 11,
            child: pw.Container(
              width: 12,
              height: 1.6,
              color: _accentOrange,
            ),
          ),
          pw.Positioned(
            top: 15.5,
            child: pw.Container(
              width: 15.5,
              height: 4.5,
              decoration: pw.BoxDecoration(
                color: _accentOrange,
                borderRadius: pw.BorderRadius.circular(4),
              ),
            ),
          ),
          pw.Positioned(
            left: 6.5,
            bottom: 6,
            child: pw.Container(
              width: 3.3,
              height: 3.3,
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
          pw.Positioned(
            right: 6.5,
            bottom: 6,
            child: pw.Container(
              width: 3.3,
              height: 3.3,
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFirstPageCard({
    required String title,
    required List<_PdfRow> rows,
    int columns = 1,
  }) {
    final resolvedColumns = columns < 1 ? 1 : columns;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(20),
        border: pw.Border.all(color: _borderColor, width: 1),
        boxShadow: const [
          pw.BoxShadow(
            color: PdfColor(0, 0, 0, 0.03),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          ..._buildFirstPageCardRows(
            rows: rows,
            columns: resolvedColumns,
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildFirstPageCardRows({
    required List<_PdfRow> rows,
    required int columns,
  }) {
    if (rows.isEmpty) {
      return const [];
    }

    if (columns <= 1) {
      return [
        for (var i = 0; i < rows.length; i++) ...[
          ..._buildFirstPageRowWidgets(row: rows[i]),
          if (i != rows.length - 1) pw.SizedBox(height: 6),
        ],
      ];
    }

    final widgets = <pw.Widget>[];
    final buffer = <_PdfRow>[];

    void flushBuffer() {
      if (buffer.isEmpty) return;
      if (widgets.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 6));
      }
      widgets.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns; i++) ...[
              pw.Expanded(
                child: i < buffer.length
                    ? pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: _buildFirstPageRowWidgets(row: buffer[i]),
                      )
                    : pw.SizedBox(),
              ),
              if (i != columns - 1) pw.SizedBox(width: 12),
            ],
          ],
        ),
      );
      buffer.clear();
    }

    for (final row in rows) {
      buffer.add(row);
      if (buffer.length == columns) {
        flushBuffer();
      }
    }

    flushBuffer();
    return widgets;
  }

  List<pw.Widget> _buildFirstPageRowWidgets({required _PdfRow row}) {
    return [
      if (row.spacingBefore > 0) pw.SizedBox(height: row.spacingBefore),
      row.isSectionHeader
          ? _buildFirstPageSectionHeader(title: row.label)
          : _buildFirstPageInfoRow(row: row),
    ];
  }

  pw.Widget _buildFirstPageMetaBlock({
    required String label,
    required String value,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: const pw.TextStyle(
              color: _textSecondary,
              fontSize: 7.8,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFirstPageInfoRow({required _PdfRow row}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          row.label.toUpperCase(),
          style: const pw.TextStyle(
            color: _textSecondary,
            fontSize: 7.8,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          row.value,
          softWrap: true,
          maxLines: row.maxLines,
          style: pw.TextStyle(
            color: _textPrimary,
            fontSize: 10.4,
            fontWeight: pw.FontWeight.bold,
            lineSpacing: 1,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFirstPageSectionHeader({required String title}) {
    return pw.Text(
      title.toUpperCase(),
      style: pw.TextStyle(
        color: _textPrimary,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  pw.Widget _buildFirstPageFooter({
    required pw.Context context,
    required String locale,
    required String generatedAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Column(
        children: [
          pw.Container(
            height: 1,
            color: const PdfColor(0.9686, 0.8745, 0.8157),
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  _copy(
                    locale,
                    de: 'CrashForm - Professionelle Schadenaufnahme',
                    it: 'CrashForm - Acquisizione danni professionale',
                    en: 'CrashForm - Professional damage reporting',
                    fr: 'CrashForm - Declaration de dommage professionnelle',
                  ),
                  style: const pw.TextStyle(
                    color: _textSecondary,
                    fontSize: 8,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  '${_copy(
                    locale,
                    de: 'Generiert am',
                    it: 'Generato il',
                    en: 'Generated on',
                    fr: 'Genere le',
                  )}: $generatedAt',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    color: _textSecondary,
                    fontSize: 8,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  '${_copy(
                    locale,
                    de: 'Seite',
                    it: 'Pagina',
                    en: 'Page',
                    fr: 'Page',
                  )} ${context.pageNumber} ${_copy(
                    locale,
                    de: 'von',
                    it: 'di',
                    en: 'of',
                    fr: 'sur',
                  )} ${context.pagesCount}',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(
                    color: _textSecondary,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPhotoPage({
    required String locale,
    required AppointmentRequest request,
    required _PhotoPageEntry entry,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(22),
            border: pw.Border.all(color: _borderColor, width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _requestTitle(request, locale),
                style: pw.TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                _referenceNumber(request.id),
                style: const pw.TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        _buildPhotoTile(
          locale: locale,
          title: entry.title,
          image: entry.image,
          imageBoxHeight: 560,
        ),
      ],
    );
  }

  pw.Widget _buildQrPage({
    required String locale,
    required AppointmentRequest request,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildHeader(
          locale: locale,
          request: request,
          createdAt: _formatDateTime(request.createdAt),
        ),
        pw.SizedBox(height: 18),
        _buildQrSection(locale: locale, request: request),
      ],
    );
  }

  pw.Widget _buildHeader({
    required String locale,
    required AppointmentRequest request,
    required String createdAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(24),
        border: pw.Border.all(color: _borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _requestTitle(request, locale),
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            _copy(
              locale,
              de: 'Premium Werkstattanfrage',
              it: 'Richiesta officina premium',
              en: 'Premium workshop request',
              fr: 'Demande atelier premium',
            ),
            style: const pw.TextStyle(
              color: _textSecondary,
              fontSize: 11,
            ),
          ),
          pw.SizedBox(height: 12),
          _badge(
            label: _statusLabel(locale, request.requestStatus),
            textColor: _statusColor(request.requestStatus),
          ),
          pw.SizedBox(height: 12),
          _metaValue(
            label: _copy(
              locale,
              de: 'Referenznummer',
              it: 'Numero pratica',
              en: 'Reference number',
              fr: 'Numero de dossier',
            ),
            value: _referenceNumber(request.id),
          ),
          pw.SizedBox(height: 8),
          _metaValue(
            label: _copy(
              locale,
              de: 'Erstellt am',
              it: 'Creato il',
              en: 'Created on',
              fr: 'Cree le',
            ),
            value: createdAt,
          ),
        ],
      ),
    );
  }

  pw.Widget _metaValue({
    required String label,
    required String value,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(
            color: _textSecondary,
            fontSize: 9,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: _textPrimary,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSectionCard({
    required String title,
    required List<_PdfRow> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(22),
        border: pw.Border.all(color: _borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            _buildInfoRow(row: rows[i]),
            if (i != rows.length - 1) pw.SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow({required _PdfRow row}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          row.label.toUpperCase(),
          style: const pw.TextStyle(
            color: _textSecondary,
            fontSize: 9,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          row.value,
          style: pw.TextStyle(
            color: _textPrimary,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _photoItemTitle({
    required String baseTitle,
    required int index,
    required int total,
  }) {
    if (total <= 1) return baseTitle;
    return '$baseTitle ${index + 1}';
  }

  pw.Widget _buildPhotoTile({
    required String locale,
    required String title,
    required pw.MemoryImage? image,
    double imageBoxHeight = 236,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            height: imageBoxHeight,
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _borderColor, width: 1),
            ),
            child: image != null
                ? pw.Center(
                    child: pw.Image(
                      image,
                      fit: pw.BoxFit.contain,
                      width: double.infinity,
                      height: imageBoxHeight - 20,
                    ),
                  )
                : pw.Center(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        _copy(
                          locale,
                          de: 'Foto nicht verfuegbar',
                          it: 'Foto non disponibile',
                          en: 'Photo unavailable',
                          fr: 'Photo indisponible',
                        ),
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _pdfFileName(String requestId) {
    final trimmed = requestId.trim();
    final safeId = trimmed.isEmpty
        ? 'request'
        : trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'richiesta_$safeId.pdf';
  }

  pw.Widget _buildQrSection({
    required String locale,
    required AppointmentRequest request,
  }) {
    final qrData = 'appointment-request:${request.id}';
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(22),
        border: pw.Border.all(color: _borderColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 120,
            height: 120,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(18),
              border: pw.Border.all(color: _borderColor, width: 1),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            _copy(
              locale,
              de: 'QR-Code / Referenz',
              it: 'QR code / riferimento',
              en: 'QR code / reference',
              fr: 'QR code / reference',
            ),
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _copy(
              locale,
              de: 'Der QR-Code enthaelt die Referenz dieser Anfrage.',
              it: 'Il QR code contiene il riferimento di questa richiesta.',
              en: 'The QR code contains this request reference.',
              fr: 'Le QR code contient la reference de cette demande.',
            ),
            style: const pw.TextStyle(
              color: _textSecondary,
              fontSize: 11,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            request.id,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _badge({
    required String label,
    required PdfColor textColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(999),
        border: pw.Border.all(color: textColor, width: 1),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  Future<Map<String, pw.MemoryImage>> _loadPhotoRegistry(
    List<_PhotoGroup> groups,
  ) async {
    final registry = <String, pw.MemoryImage>{};
    final sources = <String>{
      for (final group in groups) ...group.sources,
    };
    await Future.wait(
      sources.map((source) async {
        final bytes = await _loadImageBytes(source);
        if (bytes == null || bytes.isEmpty) return;
        try {
          registry[source] = pw.MemoryImage(bytes);
        } catch (_) {}
      }),
    );
    return registry;
  }

  Future<Uint8List?> _loadImageBytes(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) return null;

    if (normalized.startsWith('cache:')) {
      final key = normalized.substring('cache:'.length);
      return LocalImageCache.getImage(key);
    }

    if (normalized.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(normalized));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response.bodyBytes;
        }
      } catch (_) {}
      return null;
    }

    if (!kIsWeb) {
      try {
        final file = File(normalized);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (_) {}
    }

    return null;
  }

  List<_PhotoGroup> _photoGroupsFor(AppointmentRequest request, String locale) {
    if (_isHailDamageRequest(request)) {
      return [
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Fahrzeugausweis',
            it: 'Foto libretto',
            en: 'Vehicle document photo',
            fr: 'Photo carte grise',
          ),
          sources: _readStructuredImages(
            direct: request.hailDamageVehicleDocumentImages,
            notes: request.notes,
            key: 'hailDamageVehicleDocumentImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Hagelschaden',
            it: 'Foto dei danni da grandine',
            en: 'Hail damage photo',
            fr: 'Photo degats grele',
          ),
          sources: _readStructuredImages(
            direct: request.hailDamageDamageImages,
            notes: request.notes,
            key: 'hailDamageDamageImages',
            fallbackKey: 'hailDamageImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Uebersichtsfoto Fahrzeug',
            it: 'Foto panoramica veicolo',
            en: 'Vehicle overview photo',
            fr: 'Photo generale du vehicule',
          ),
          sources: _readStructuredImages(
            direct: request.hailDamageOverviewImages,
            notes: request.notes,
            key: 'hailDamageOverviewImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto aktueller KM-Stand',
            it: 'Foto stato attuale KM',
            en: 'Current mileage photo',
            fr: 'Photo kilometrage actuel',
          ),
          sources: _readStructuredImages(
            direct: request.hailDamageCurrentKmImages,
            notes: request.notes,
            key: 'hailDamageCurrentKmImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Zusaetzliches Foto',
            it: 'Foto aggiuntiva',
            en: 'Additional photo',
            fr: 'Photo supplementaire',
          ),
          sources: _readStructuredImages(
            direct: request.hailDamageExtraImages,
            notes: request.notes,
            key: 'hailDamageExtraImages',
          ),
        ),
      ];
    }

    if (_isParkingDamageRequest(request)) {
      return [
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Fahrzeugausweis',
            it: 'Foto libretto',
            en: 'Vehicle document photo',
            fr: 'Photo carte grise',
          ),
          sources: _readStructuredImages(
            direct: request.parkingDamageVehicleDocumentImages,
            notes: request.notes,
            key: 'parkingDamageVehicleDocumentImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Parkschaden',
            it: 'Foto danno parcheggio',
            en: 'Parking damage photo',
            fr: 'Photo dommage parking',
          ),
          sources: _readStructuredImages(
            direct: request.parkingDamageDamageImages,
            notes: request.notes,
            key: 'parkingDamageDamageImages',
            fallbackKey: 'parkingDamageImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Uebersichtsfoto Fahrzeug',
            it: 'Foto panoramica veicolo',
            en: 'Vehicle overview photo',
            fr: 'Photo generale du vehicule',
          ),
          sources: _readStructuredImages(
            direct: request.parkingDamageOverviewImages,
            notes: request.notes,
            key: 'parkingDamageOverviewImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto aktueller KM-Stand',
            it: 'Foto stato attuale KM',
            en: 'Current mileage photo',
            fr: 'Photo kilometrage actuel',
          ),
          sources: _readStructuredImages(
            direct: request.parkingDamageCurrentKmImages,
            notes: request.notes,
            key: 'parkingDamageCurrentKmImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Zusaetzliches Foto',
            it: 'Foto aggiuntiva',
            en: 'Additional photo',
            fr: 'Photo supplementaire',
          ),
          sources: _readStructuredImages(
            direct: request.parkingDamageExtraImages,
            notes: request.notes,
            key: 'parkingDamageExtraImages',
          ),
        ),
      ];
    }

    if (_isMartenDamageRequest(request)) {
      return [
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Fahrzeugausweis',
            it: 'Foto libretto',
            en: 'Vehicle document photo',
            fr: 'Photo carte grise',
          ),
          sources: _readStructuredImages(
            direct: request.marderDamageVehicleDocumentImages,
            notes: request.notes,
            key: 'marderDamageVehicleDocumentImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Motorraum',
            it: 'Foto vano motore',
            en: 'Engine bay photo',
            fr: 'Photo compartiment moteur',
          ),
          sources: _readStructuredImages(
            direct: request.marderDamageEngineBayImages,
            notes: request.notes,
            key: 'marderDamageEngineBayImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto beschaedigte Kabel',
            it: 'Foto cavi danneggiati',
            en: 'Damaged cable photo',
            fr: 'Photo cables endommages',
          ),
          sources: _readStructuredImages(
            direct: request.marderDamageCableImages,
            notes: request.notes,
            key: 'marderDamageCableImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto aktueller KM-Stand',
            it: 'Foto stato attuale KM',
            en: 'Current mileage photo',
            fr: 'Photo kilometrage actuel',
          ),
          sources: _readStructuredImages(
            direct: request.marderDamageCurrentKmImages,
            notes: request.notes,
            key: 'marderDamageCurrentKmImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Zusaetzliches Foto',
            it: 'Foto aggiuntiva',
            en: 'Additional photo',
            fr: 'Photo supplementaire',
          ),
          sources: _readStructuredImages(
            direct: request.marderDamageExtraImages,
            notes: request.notes,
            key: 'marderDamageExtraImages',
          ),
        ),
      ];
    }

    if (_isComprehensiveDamageRequest(request)) {
      return [
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Fahrzeugausweis',
            it: 'Foto libretto',
            en: 'Vehicle document photo',
            fr: 'Photo carte grise',
          ),
          sources: _readStructuredImages(
            direct: request.fullDamageVehicleDocumentImages,
            notes: request.notes,
            key: 'fullDamageVehicleDocumentImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Schaden Nahaufnahme',
            it: 'Foto danno ravvicinata',
            en: 'Damage close-up photo',
            fr: 'Photo gros plan du dommage',
          ),
          sources: _readStructuredImages(
            direct: request.fullDamageCloseImages,
            notes: request.notes,
            key: 'fullDamageCloseImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Gesamtansicht Fahrzeug',
            it: 'Foto panoramica veicolo',
            en: 'Vehicle overview photo',
            fr: 'Photo vue d ensemble du vehicule',
          ),
          sources: _readStructuredImages(
            direct: request.fullDamageOverviewImages,
            notes: request.notes,
            key: 'fullDamageOverviewImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto aktueller KM-Stand',
            it: 'Foto stato attuale KM',
            en: 'Current mileage photo',
            fr: 'Photo kilometrage actuel',
          ),
          sources: _readStructuredImages(
            direct: request.fullDamageCurrentKmImages,
            notes: request.notes,
            key: 'fullDamageCurrentKmImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Zusaetzliches Foto',
            it: 'Foto aggiuntiva',
            en: 'Additional photo',
            fr: 'Photo supplementaire',
          ),
          sources: _readStructuredImages(
            direct: request.fullDamageExtraImages,
            notes: request.notes,
            key: 'fullDamageExtraImages',
          ),
        ),
      ];
    }

    if (_isOtherDamageRequest(request)) {
      return [
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Fahrzeugausweis',
            it: 'Foto libretto',
            en: 'Vehicle document photo',
            fr: 'Photo carte grise',
          ),
          sources: _readStructuredImages(
            direct: request.otherDamageVehicleDocumentImages,
            notes: request.notes,
            key: 'otherDamageVehicleDocumentImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto Problem / Schaden',
            it: 'Foto problema / danno',
            en: 'Problem / damage photo',
            fr: 'Photo probleme / dommage',
          ),
          sources: _readStructuredImages(
            direct: request.otherDamageProblemImages,
            notes: request.notes,
            key: 'otherDamageProblemImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Foto aktueller KM-Stand',
            it: 'Foto stato attuale KM',
            en: 'Current mileage photo',
            fr: 'Photo kilometrage actuel',
          ),
          sources: _readStructuredImages(
            direct: request.otherDamageCurrentKmImages,
            notes: request.notes,
            key: 'otherDamageCurrentKmImages',
          ),
        ),
        _PhotoGroup(
          title: _copy(
            locale,
            de: 'Zusaetzliches Foto',
            it: 'Foto aggiuntiva',
            en: 'Additional photo',
            fr: 'Photo supplementaire',
          ),
          sources: _readStructuredImages(
            direct: request.otherDamageExtraImages,
            notes: request.notes,
            key: 'otherDamageExtraImages',
          ),
        ),
      ];
    }

    final vehicleDocumentImages = _readStructuredImages(
      direct: request.glassDamageVehicleDocumentImages,
      notes: request.notes,
      key: 'glassDamageVehicleDocumentImages',
    );
    final closeGlassImages = _readStructuredImages(
      direct: request.glassDamageCloseGlassImages,
      notes: request.notes,
      key: 'glassDamageCloseGlassImages',
    );
    final frontVehicleImages = _readStructuredImages(
      direct: request.glassDamageFrontVehicleImages,
      notes: request.notes,
      key: 'glassDamageFrontVehicleImages',
    );
    final currentKmImages = _readStructuredImages(
      direct: request.glassDamageCurrentKmImages,
      notes: request.notes,
      key: 'glassDamageCurrentKmImages',
    );
    final fallbackImages = _readStructuredImages(
      direct: request.glassDamageImages,
      notes: request.notes,
      key: 'glassDamageImages',
    );
    final assigned = <String>{
      ...vehicleDocumentImages,
      ...closeGlassImages,
      ...frontVehicleImages,
      ...currentKmImages,
    };
    final extraImages = fallbackImages
        .where((image) => !assigned.contains(image.trim()))
        .toList();
    return [
      _PhotoGroup(
        title: _copy(
          locale,
          de: 'Foto Fahrzeugausweis',
          it: 'Foto libretto',
          en: 'Vehicle document photo',
          fr: 'Photo carte grise',
        ),
        sources: vehicleDocumentImages,
      ),
      _PhotoGroup(
        title: _copy(
          locale,
          de: 'Nahaufnahme Glas',
          it: 'Foto vetro vicino',
          en: 'Close-up glass photo',
          fr: 'Photo rapprochee du verre',
        ),
        sources: closeGlassImages,
      ),
      _PhotoGroup(
        title: _copy(
          locale,
          de: 'Frontfoto des Fahrzeugs',
          it: 'Foto frontale della macchina',
          en: 'Front vehicle photo',
          fr: 'Photo frontale du vehicule',
        ),
        sources: frontVehicleImages,
      ),
      _PhotoGroup(
        title: _copy(
          locale,
          de: 'Foto aktueller KM-Stand',
          it: 'Foto stato attuale KM',
          en: 'Current mileage photo',
          fr: 'Photo kilometrage actuel',
        ),
        sources: currentKmImages,
      ),
      _PhotoGroup(
        title: _copy(
          locale,
          de: 'Weitere Fotos',
          it: 'Foto aggiuntive',
          en: 'Additional photos',
          fr: 'Photos supplementaires',
        ),
        sources: extraImages,
      ),
    ];
  }

  List<String> _readStructuredImages({
    required List<String> direct,
    required String? notes,
    required String key,
    String? fallbackKey,
  }) {
    final normalizedDirect = direct
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (normalizedDirect.isNotEmpty) return normalizedDirect;

    final decoded = _decodeNotes(notes);
    final fromKey = _stringList(decoded[key]);
    if (fromKey.isNotEmpty) return fromKey;
    if (fallbackKey != null) {
      final fromFallback = _stringList(decoded[fallbackKey]);
      if (fromFallback.isNotEmpty) return fromFallback;
    }
    return const [];
  }

  Map<String, dynamic> _decodeNotes(String? notes) {
    final raw = notes?.trim() ?? '';
    if (raw.isEmpty || !raw.startsWith('{')) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool _isHailDamageRequest(AppointmentRequest request) {
    return request.serviceType == 'damage_hail' ||
        request.damageType == 'damage_hail';
  }

  bool _isMartenDamageRequest(AppointmentRequest request) {
    return request.serviceType == 'damage_marten' ||
        request.damageType == 'damage_marten';
  }

  bool _isComprehensiveDamageRequest(AppointmentRequest request) {
    return request.serviceType == 'damage_comprehensive' ||
        request.damageType == 'damage_comprehensive';
  }

  bool _isOtherDamageRequest(AppointmentRequest request) {
    return request.serviceType == 'damage_other' ||
        request.damageType == 'damage_other';
  }

  bool _isParkingDamageRequest(AppointmentRequest request) {
    return request.serviceType == 'damage_parking' ||
        request.damageType == 'damage_parking';
  }

  String _requestTitle(AppointmentRequest request, String locale) {
    switch (request.damageType ?? request.serviceType) {
      case 'damage_glass':
        return _copy(
          locale,
          de: 'Glasschaden',
          it: 'Glasschaden',
          en: 'Glass damage',
          fr: 'Bris de glace',
        );
      case 'damage_hail':
        return _copy(
          locale,
          de: 'Hagelschaden',
          it: 'Hagelschaden',
          en: 'Hail damage',
          fr: 'Degats de grele',
        );
      case 'damage_parking':
        return _copy(
          locale,
          de: 'Parkschaden',
          it: 'Parkschaden',
          en: 'Parking damage',
          fr: 'Dommage de parking',
        );
      case 'damage_marten':
        return _copy(
          locale,
          de: 'Marderschaden',
          it: 'Marderschaden',
          en: 'Marten damage',
          fr: 'Degats de martre',
        );
      case 'damage_comprehensive':
        return _copy(
          locale,
          de: 'Vollkasko',
          it: 'Vollkasko',
          en: 'Comprehensive',
          fr: 'Tous risques',
        );
      case 'damage_other':
        return _copy(
          locale,
          de: 'Sonstige Schaeden oder technische Probleme',
          it: 'Altri danni o problemi tecnici',
          en: 'Other damages or technical problems',
          fr: 'Autres dommages ou problemes techniques',
        );
      default:
        return _copy(
          locale,
          de: 'Werkstattanfrage',
          it: 'Richiesta officina',
          en: 'Workshop request',
          fr: 'Demande atelier',
        );
    }
  }

  String _damageTown(AppointmentRequest request) {
    if (_isHailDamageRequest(request)) {
      return request.hailDamageTown ?? '';
    }
    if (_isMartenDamageRequest(request)) {
      return request.marderDamageTown ?? '';
    }
    if (_isComprehensiveDamageRequest(request)) {
      return request.fullDamageTown ?? '';
    }
    if (_isOtherDamageRequest(request)) {
      return request.otherDamageTown ?? '';
    }
    if (_isParkingDamageRequest(request)) {
      return request.parkingDamageTown ?? '';
    }
    return request.glassDamageTown ?? '';
  }

  String _damageDateLabel(AppointmentRequest request) {
    if (_isHailDamageRequest(request)) {
      return _formatApiDate(request.hailDamageDate);
    }
    if (_isMartenDamageRequest(request)) {
      return _formatApiDate(request.marderDamageDate);
    }
    if (_isComprehensiveDamageRequest(request)) {
      return _formatApiDate(request.fullDamageDate);
    }
    if (_isOtherDamageRequest(request)) {
      return _formatApiDate(request.otherDamageDate);
    }
    if (_isParkingDamageRequest(request)) {
      return _formatApiDate(request.parkingDamageDate);
    }
    return _formatApiDate(request.glassDamageDate);
  }

  String _damageTime(AppointmentRequest request) {
    if (_isHailDamageRequest(request)) {
      return _normalizeTime(request.hailDamageTime);
    }
    if (_isMartenDamageRequest(request)) {
      return _normalizeTime(request.marderDamageTime);
    }
    if (_isComprehensiveDamageRequest(request)) {
      return _normalizeTime(request.fullDamageTime);
    }
    if (_isOtherDamageRequest(request)) {
      return _normalizeTime(request.otherDamageTime);
    }
    if (_isParkingDamageRequest(request)) {
      return _normalizeTime(request.parkingDamageTime);
    }
    return '-';
  }

  String _damageDescription(AppointmentRequest request) {
    if (_isMartenDamageRequest(request)) {
      return request.marderDamageDescription?.trim().isNotEmpty == true
          ? request.marderDamageDescription!.trim()
          : '-';
    }
    if (_isComprehensiveDamageRequest(request)) {
      return request.fullDamageDescription?.trim().isNotEmpty == true
          ? request.fullDamageDescription!.trim()
          : '-';
    }
    if (_isOtherDamageRequest(request)) {
      return request.otherDamageDescription?.trim().isNotEmpty == true
          ? request.otherDamageDescription!.trim()
          : '-';
    }
    return request.notes?.trim().isNotEmpty == true
        ? request.notes!.trim()
        : '-';
  }

  String _drivableValue(String locale, AppointmentRequest request) {
    if (_isMartenDamageRequest(request)) {
      return _drivableAnswerLabel(locale, request.marderDamageDrivable);
    }
    if (_isComprehensiveDamageRequest(request)) {
      return _drivableAnswerLabel(locale, request.fullDamageDrivable);
    }
    return '-';
  }

  String _appointmentWorkshopValue(String locale, String? workshopLabel) {
    final value = workshopLabel?.trim() ?? '';
    if (value.isNotEmpty) return value;

    return _copy(
      locale,
      de: 'CrashForm Partnerwerkstatt',
      it: 'CrashForm Partnerwerkstatt',
      en: 'CrashForm Partner Workshop',
      fr: 'Atelier partenaire CrashForm',
    );
  }

  String _currentKmValue(String locale, List<_PhotoGroup> photoGroups) {
    final kmGroup = photoGroups.where(
      (group) =>
          group.title ==
          _copy(
            locale,
            de: 'Foto aktueller KM-Stand',
            it: 'Foto stato attuale KM',
            en: 'Current mileage photo',
            fr: 'Photo kilometrage actuel',
          ),
    );
    final count = kmGroup.isEmpty ? 0 : kmGroup.first.sources.length;
    if (count == 0) return '-';
    return _copy(
      locale,
      de: 'Siehe Foto ($count)',
      it: 'Vedi foto ($count)',
      en: 'See photo ($count)',
      fr: 'Voir photo ($count)',
    );
  }

  String _drivableAnswerLabel(String locale, String? rawValue) {
    switch (rawValue?.trim()) {
      case 'yes':
        return _copy(locale, de: 'Ja', it: 'Sì', en: 'Yes', fr: 'Oui');
      case 'no':
        return _copy(locale, de: 'Nein', it: 'No', en: 'No', fr: 'Non');
      case 'not_sure':
        return _copy(
          locale,
          de: 'Unsicher',
          it: 'Non sicuro',
          en: 'Not sure',
          fr: 'Pas sûr',
        );
      default:
        return '-';
    }
  }

  String _otherDamageCategoryLabel(String locale, String? category) {
    switch (category?.trim()) {
      case 'engine_warning':
        return _copy(
          locale,
          de: 'Motorwarnleuchte',
          it: 'Spia motore',
          en: 'Engine warning light',
          fr: 'Voyant moteur',
        );
      case 'battery':
        return _copy(
          locale,
          de: 'Batterieproblem',
          it: 'Problema batteria',
          en: 'Battery problem',
          fr: 'Probleme de batterie',
        );
      case 'air_conditioning':
        return _copy(
          locale,
          de: 'Klimaanlage',
          it: 'Aria condizionata',
          en: 'Air conditioning',
          fr: 'Climatisation',
        );
      case 'electronics':
        return _copy(
          locale,
          de: 'Elektronikproblem',
          it: 'Problema elettronico',
          en: 'Electronic problem',
          fr: 'Probleme electronique',
        );
      case 'noise_vibration':
        return _copy(
          locale,
          de: 'Geraeusch/Vibration',
          it: 'Rumore/Vibrazione',
          en: 'Noise/Vibration',
          fr: 'Bruit/Vibration',
        );
      case 'recall':
        return _copy(
          locale,
          de: 'Rueckrufaktion',
          it: 'Richiamo ufficiale',
          en: 'Official recall',
          fr: 'Rappel officiel',
        );
      case 'other':
        return _copy(
          locale,
          de: 'Sonstiges',
          it: 'Altro',
          en: 'Other',
          fr: 'Autre',
        );
      default:
        return '-';
    }
  }

  String _statusLabel(String locale, String status) {
    return _copy(
      locale,
      de: switch (status) {
        'confirmed' => 'Termin bestaetigt',
        'in_progress' => 'Fahrzeug in Bearbeitung',
        'completed' => 'Reparatur abgeschlossen',
        'cancelled' => 'Termin storniert',
        _ => 'Anfrage gesendet',
      },
      it: switch (status) {
        'confirmed' => 'Appuntamento confermato',
        'in_progress' => 'Veicolo in lavorazione',
        'completed' => 'Riparazione completata',
        'cancelled' => 'Appuntamento annullato',
        _ => 'Richiesta inviata',
      },
      en: switch (status) {
        'confirmed' => 'Appointment confirmed',
        'in_progress' => 'Vehicle in progress',
        'completed' => 'Repair completed',
        'cancelled' => 'Appointment cancelled',
        _ => 'Request sent',
      },
      fr: switch (status) {
        'confirmed' => 'Rendez-vous confirme',
        'in_progress' => 'Vehicule en reparation',
        'completed' => 'Reparation terminee',
        'cancelled' => 'Rendez-vous annule',
        _ => 'Demande envoyee',
      },
    );
  }

  PdfColor _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return _statusConfirmed;
      case 'in_progress':
        return _statusInProgress;
      case 'completed':
        return _statusCompleted;
      case 'cancelled':
        return _statusCancelled;
      case 'pending':
      default:
        return _statusPending;
    }
  }

  String _formatDate(DateTime date) =>
      DateFormat('dd.MM.yyyy').format(date.toLocal());

  String _formatDateTime(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal());
  }

  String _formatApiDate(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return _formatDate(parsed);
  }

  String _appointmentTime(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '-';
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  String _normalizeTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '-';
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  String _referenceNumber(String id) {
    final value = id.trim();
    if (value.isEmpty) return 'REQUEST';
    if (value.startsWith('local_req_')) {
      final suffix = value.replaceFirst('local_req_', '');
      final short =
          suffix.length > 8 ? suffix.substring(suffix.length - 8) : suffix;
      return 'LOC-$short';
    }
    final compact = value.replaceAll('-', '').toUpperCase();
    return compact.length <= 10 ? compact : compact.substring(0, 10);
  }

  String _normalizeLocale(String? raw) {
    final value = raw?.toLowerCase().trim() ?? '';
    if (value.startsWith('it')) return 'it';
    if (value.startsWith('en')) return 'en';
    if (value.startsWith('fr')) return 'fr';
    return 'de';
  }

  String _copy(
    String locale, {
    required String de,
    required String it,
    required String en,
    required String fr,
  }) {
    switch (locale) {
      case 'it':
        return it;
      case 'en':
        return en;
      case 'fr':
        return fr;
      case 'de':
      default:
        return de;
    }
  }

  String _valueOrDash(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '-' : trimmed;
  }
}

class _PdfRow {
  const _PdfRow({
    required this.label,
    this.value = '',
    this.maxLines,
    this.isSectionHeader = false,
    this.spacingBefore = 0,
  });

  final String label;
  final String value;
  final int? maxLines;
  final bool isSectionHeader;
  final double spacingBefore;
}

class _PhotoGroup {
  const _PhotoGroup({
    required this.title,
    required this.sources,
  });

  final String title;
  final List<String> sources;
}

class _PhotoPageEntry {
  const _PhotoPageEntry({
    required this.title,
    required this.image,
  });

  final String title;
  final pw.MemoryImage? image;
}
