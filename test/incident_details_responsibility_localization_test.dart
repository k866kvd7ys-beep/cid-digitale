import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/l10n/app_localizations_de.dart';
import 'package:cid_digitale/l10n/app_localizations_en.dart';
import 'package:cid_digitale/l10n/app_localizations_fr.dart';
import 'package:cid_digitale/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _mobileCopyHarness(
  Locale locale,
  String instruction,
  String action,
  String information,
) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              instruction,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.send),
                label: Text(action, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              information,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  final copies = <String, (AppLocalizations, String, String, String)>{
    'it': (
      AppLocalizationsIt(),
      'Seleziona il conducente ritenuto responsabile.',
      'Firma e invia automaticamente',
      'Dopo entrambe le firme, la pratica viene inviata automaticamente '
          'via e-mail al conducente A e al conducente B.',
    ),
    'de': (
      AppLocalizationsDe(),
      'Wählen Sie den Fahrer aus, der als verantwortlich gilt.',
      'Unterschreiben und automatisch senden',
      'Nach beiden Unterschriften wird der Bericht automatisch per E-Mail '
          'an Fahrer A und Fahrer B gesendet.',
    ),
    'fr': (
      AppLocalizationsFr(),
      'Sélectionnez le conducteur considéré comme responsable.',
      'Signer et envoyer automatiquement',
      'Après les deux signatures, le dossier est automatiquement envoyé '
          'par e-mail au conducteur A et au conducteur B.',
    ),
    'en': (
      AppLocalizationsEn(),
      'Select the driver considered responsible.',
      'Sign and send automatically',
      'After both signatures, the report is automatically sent by e-mail '
          'to Driver A and Driver B.',
    ),
  };

  for (final entry in copies.entries) {
    testWidgets(
      'responsibility copy uses ${entry.key} localization without mobile overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final (localizations, instruction, action, information) = entry.value;
        expect(
          localizations.accidentDetailsLiabilityInstruction,
          instruction,
        );
        expect(localizations.accidentDetailsSignAndSendAction, action);
        expect(localizations.accidentDetailsAutomaticEmailInfo, information);

        await tester.pumpWidget(
          _mobileCopyHarness(
            Locale(entry.key),
            instruction,
            action,
            information,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(instruction), findsOneWidget);
        expect(find.text(action), findsOneWidget);
        expect(find.text(information), findsOneWidget);

        final actionButton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text(action),
            matching: find.byWidgetPredicate(
              (widget) => widget is ElevatedButton,
            ),
          ),
        );
        expect(actionButton.onPressed, isNotNull);
        expect(tester.getSize(find.text(information)).width,
            lessThanOrEqualTo(318));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('responsibility copy keeps the existing send and share callbacks', () {
    final source = File('lib/main.dart').readAsStringSync();
    final sectionStart = source.indexOf(
      '// ===================== CARD RESPONSABILITÀ + FIRME',
    );
    final sectionEnd = source.indexOf('// QR', sectionStart);
    final section = source.substring(sectionStart, sectionEnd);

    expect(
      section,
      contains(': () => _sendCidAutomatically(incidente.id)'),
    );
    expect(
      section,
      contains(': () => _condividiPerAssicurazione(context)'),
    );
    expect(
      section,
      contains('_labelResponsabilita()'),
    );
    expect(
      section,
      contains('l10n.accidentDetailsSignAndSendAction'),
    );
    expect(
      section,
      contains('l10n.accidentDetailsAutomaticEmailInfo'),
    );
    expect(
      source,
      contains(
        'AppLocalizations.of(context)!.accidentDetailsLiabilityInstruction',
      ),
    );
    expect(section, isNot(contains('Invia automaticamente pratica')));
  });
}
