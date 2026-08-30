import 'dart:io';

import 'package:cid_digitale/main.dart';
import 'package:flutter_test/flutter_test.dart';

String _methodSource(
  String source, {
  required String startMarker,
  required String endMarker,
}) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: 'Missing start marker: $startMarker',
  );
  expect(end, greaterThan(start), reason: 'Missing end marker: $endMarker');
  return source.substring(start, end);
}

void main() {
  late String mainSource;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
  });

  test('web libretto A upload persists its returned URL', () {
    final uploadFlow = _methodSource(
      mainSource,
      startMarker: 'Future<void> _pickAndUploadImage(',
      endMarker: 'void _removeDamagePhoto(',
    );

    expect(
      uploadFlow,
      contains(
        'final uploadedUrl = await _supabaseService.uploadClaimImageBytes(',
      ),
    );
    expect(uploadFlow, contains("if (kind == 'libretto' && mounted)"));
    expect(uploadFlow, contains("if (quale == 'A')"));
    expect(uploadFlow, contains('_fotoLibrettoAPath = uploadedUrl;'));
    expect(
      uploadFlow.indexOf(
        'final uploadedUrl = await _supabaseService.uploadClaimImageBytes(',
      ),
      lessThan(uploadFlow.indexOf('_fotoLibrettoAPath = uploadedUrl;')),
    );

    const librettoA =
        'https://example.supabase.co/storage/v1/object/public/claim_attachments/claims/claim-a/libretto/a.jpg';
    final payload = Incidente.fromJson({
      'id': 'claim-a',
      'dataOra': DateTime.utc(2026, 8, 30).toIso8601String(),
      'fotoLibrettoA': librettoA,
    }).toJson();

    expect(payload['fotoLibrettoA'], librettoA);
  });

  test('web libretto B upload persists its returned URL', () {
    final uploadFlow = _methodSource(
      mainSource,
      startMarker: 'Future<void> _pickAndUploadImage(',
      endMarker: 'void _removeDamagePhoto(',
    );

    expect(uploadFlow, contains("else if (quale == 'B')"));
    expect(uploadFlow, contains('_fotoLibrettoBPath = uploadedUrl;'));

    const librettoB =
        'https://example.supabase.co/storage/v1/object/public/claim_attachments/claims/claim-a/libretto/b.jpg';
    final payload = Incidente.fromJson({
      'id': 'claim-a',
      'dataOra': DateTime.utc(2026, 8, 30).toIso8601String(),
      'fotoLibrettoB': librettoB,
    }).toJson();

    expect(payload['fotoLibrettoB'], librettoB);
  });

  test('damage photo URL propagation remains unchanged', () {
    const damage =
        'https://example.supabase.co/storage/v1/object/public/claim_attachments/claims/claim-a/damage/1.jpg';
    final incident = Incidente.fromJson({
      'id': 'claim-a',
      'dataOra': DateTime.utc(2026, 8, 30).toIso8601String(),
      'fotoDanni': [damage],
    });

    final payload = incident.toJson();

    expect(payload['fotoDanni'], [damage]);
    expect(
      mainSource,
      contains('item.remoteUrl = uploadedUrl;'),
    );
    expect(mainSource, contains('fotoDanni: _damageUploadedUrls,'));
  });

  test('share flow collects PDF, damage photos and both libretti', () {
    final shareFlow = _methodSource(
      mainSource,
      startMarker: 'Future<void> _shareIncidentPdfAndPhotos()',
      endMarker: 'Future<void> _condividiPerAssicurazione(',
    );

    expect(
      shareFlow,
      contains('final pdfBytes = await _buildIncidentPdfBytes();'),
    );
    expect(shareFlow, contains('incidente.fotoLibrettoA'));
    expect(shareFlow, contains('incidente.fotoLibrettoB'));
    expect(shareFlow, contains('incidente.fotoDanni'));
    expect(
      shareFlow,
      contains(
        'attemptSets.add([pdfWebFile, ...webLibrettoFiles, ...webDamageFiles]);',
      ),
    );
    expect(shareFlow, contains('await Share.shareXFiles('));
  });
}
