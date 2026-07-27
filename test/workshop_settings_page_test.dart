import 'dart:convert';

import 'package:cid_digitale/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _towNumber = '+41 91 111 11 11';
const _workshopNumber = '+41 91 222 22 22';
const _workshopEmail = 'werkstatt@example.ch';

Widget _app() {
  return MaterialApp(
    locale: const Locale('de'),
    supportedLocales: const [
      Locale('it'),
      Locale('de'),
      Locale('fr'),
      Locale('en'),
    ],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            key: const Key('open_workshop_settings'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ImpostazioniOfficinaPage(),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'config_officina': jsonEncode({
        'carroNumero': _towNumber,
        'concessionariaNumero': _workshopNumber,
        'concessionariaEmail': _workshopEmail,
      }),
    });
    configOfficina = OfficinaConfig.empty();
    await caricaConfigOfficina();
  });

  testWidgets(
      'workshop settings loads and saves existing fields without Kalender',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byKey(const Key('open_workshop_settings')));
    await tester.pumpAndSettle();

    expect(find.text('Werkstatteinstellungen'), findsOneWidget);
    expect(find.text('Kalender'), findsNothing);
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
    expect(find.text('Abschleppdienst-Nummer'), findsOneWidget);
    expect(find.text('Werkstatt-/Händlernummer'), findsOneWidget);
    expect(find.text('E-Mail Werkstatt / Händler'), findsOneWidget);
    expect(find.text('Einstellungen speichern'), findsOneWidget);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller?.text,
      _towNumber,
    );
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller?.text,
      _workshopNumber,
    );
    expect(
      tester.widget<TextFormField>(fields.at(2)).controller?.text,
      _workshopEmail,
    );

    final saveButton = find.ancestor(
      of: find.text('Einstellungen speichern'),
      matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
    );
    expect(saveButton, findsOneWidget);
    final gap = tester.getTopLeft(saveButton).dy -
        tester.getBottomLeft(fields.at(2)).dy;
    expect(gap, closeTo(32, 1));

    await tester.enterText(fields.at(0), '+41 91 333 33 33');
    await tester.enterText(fields.at(1), '+41 91 444 44 44');
    await tester.enterText(fields.at(2), 'neu@example.ch');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final saved = jsonDecode(
      preferences.getString('config_officina')!,
    ) as Map<String, dynamic>;
    expect(saved['carroNumero'], '+41 91 333 33 33');
    expect(saved['concessionariaNumero'], '+41 91 444 44 44');
    expect(saved['concessionariaEmail'], 'neu@example.ch');
    expect(find.byKey(const Key('open_workshop_settings')), findsOneWidget);
  });
}
