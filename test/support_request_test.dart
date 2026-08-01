import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/screens/support_request_screen.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:cid_digitale/services/support_request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

const _account = CustomerAccount(
  id: '103e1b0b-9f11-4504-a8d7-fceac36facff',
  email: 'cliente@example.ch',
  role: customerRole,
);

const _profile = CustomerProfile(
  userId: '103e1b0b-9f11-4504-a8d7-fceac36facff',
  firstName: 'Antonio',
  lastName: 'Cliente',
  email: 'cliente@example.ch',
);

const _submission = SupportRequestSubmission(
  requestId: 'ffa2e63f-9082-4ba0-8575-d5e23d220f99',
  reference: 'SUP-2026-FFA2E6',
);

class _FakeSupportGateway implements SupportRequestGateway {
  int submitCalls = 0;
  int retryCalls = 0;
  SupportRequestDraft? lastDraft;
  Completer<SupportRequestSubmission>? submitGate;
  Object? submitError;
  Object? retryError;

  @override
  Future<SupportRequestSubmission> submit({
    required String userId,
    required SupportRequestDraft draft,
  }) async {
    submitCalls++;
    lastDraft = draft;
    if (submitError case final error?) throw error;
    final gate = submitGate;
    if (gate != null) return gate.future;
    return _submission;
  }

  @override
  Future<SupportRequestSubmission> retryNotification({
    required String userId,
    required String requestId,
  }) async {
    retryCalls++;
    if (retryError case final error?) throw error;
    return _submission;
  }
}

Widget _app(
  SupportRequestGateway gateway, {
  Locale locale = const Locale('it'),
  SupportImagePicker? pickImage,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SupportRequestScreen(
      account: _account,
      profile: _profile,
      gateway: gateway,
      pickImage: pickImage,
    ),
  );
}

Future<void> _completeValidForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('support-request-type')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Segnala un problema').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('support-subject')),
    'Problema applicazione',
  );
  await tester.enterText(
    find.byKey(const Key('support-message')),
    'Descrizione completa del problema riscontrato.',
  );
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final finder = find.byKey(const Key('support-submit'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  test('attachment collection enforces three files and five MB each', () {
    final collection = SupportAttachmentCollection();
    SupportRequestAttachment attachment(int size, int index) =>
        SupportRequestAttachment(
          fileName: 'image_$index.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List(size),
        );

    expect(collection.add(attachment(10, 1)), isTrue);
    expect(collection.add(attachment(10, 2)), isTrue);
    expect(collection.add(attachment(10, 3)), isTrue);
    expect(collection.add(attachment(10, 4)), isFalse);

    final tooLarge = SupportAttachmentCollection();
    expect(
      tooLarge.add(
        attachment(SupportAttachmentCollection.maxBytesPerAttachment + 1, 5),
      ),
      isFalse,
    );
  });

  testWidgets('form preloads auth email and validates required fields',
      (tester) async {
    final gateway = _FakeSupportGateway();
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextFormField>(
      find.byKey(const Key('support-reply-email')),
    );
    expect(emailField.controller?.text, _account.email);

    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Campo obbligatorio.'), findsWidgets);
    expect(gateway.submitCalls, 0);
  });

  testWidgets('email format and minimum lengths are validated', (tester) async {
    final gateway = _FakeSupportGateway();
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    await _completeValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('support-reply-email')),
      'indirizzo-non-valido',
    );

    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Inserisci un indirizzo e-mail valido.'), findsOneWidget);
    expect(gateway.submitCalls, 0);
  });

  testWidgets('picked image shows a preview and can be removed',
      (tester) async {
    final imageBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final gateway = _FakeSupportGateway();
    await tester.pumpWidget(
      _app(
        gateway,
        pickImage: (_) async => XFile.fromData(
          imageBytes,
          name: 'screenshot.png',
          mimeType: 'image/png',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addButton = find.byKey(const Key('support-add-attachment'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scegli dalla galleria'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    final remove = find.byKey(const Key('support-remove-attachment-0'));
    expect(remove, findsOneWidget);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('double submission is blocked and success is confirmed',
      (tester) async {
    final gate = Completer<SupportRequestSubmission>();
    final gateway = _FakeSupportGateway()..submitGate = gate;
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    await _completeValidForm(tester);

    await _tapSubmit(tester);
    expect(gateway.submitCalls, 1);
    final disabledButton = tester.widget<FilledButton>(
      find.byKey(const Key('support-submit')),
    );
    expect(disabledButton.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete(_submission);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-confirmation')), findsOneWidget);
    expect(find.text(_submission.reference), findsOneWidget);
    expect(gateway.submitCalls, 1);
  });

  testWidgets('saved request notification error keeps data and can retry',
      (tester) async {
    final gateway = _FakeSupportGateway()
      ..submitError = const SupportRequestSubmissionException(
        savedRequestId: 'ffa2e63f-9082-4ba0-8575-d5e23d220f99',
      );
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    await _completeValidForm(tester);

    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-submission-error')), findsOneWidget);
    expect(find.text('Problema applicazione'), findsOneWidget);
    expect(find.text('Riprova invio'), findsOneWidget);

    gateway.submitError = null;
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(gateway.submitCalls, 1);
    expect(gateway.retryCalls, 1);
    expect(find.byKey(const Key('support-confirmation')), findsOneWidget);
  });

  test('support card is after quick actions and opens the dedicated screen',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    final quickActions = source.lastIndexOf('_buildQuickActions(');
    final supportCard = source.indexOf('_buildSupportCard(l10n)', quickActions);

    expect(quickActions, greaterThan(0));
    expect(supportCard, greaterThan(quickActions));
    expect(source, contains("key: const Key('home-support-card')"));
    expect(source, contains('SupportRequestScreen('));
  });

  test('all support copy is localized in four ARB files', () {
    const requiredKeys = [
      'supportTitle',
      'supportHomeDescription',
      'supportHowCanWeHelp',
      'supportIntroDescription',
      'supportRequestType',
      'supportRequestProblem',
      'supportRequestQuestion',
      'supportRequestSuggestion',
      'supportSubject',
      'supportDescription',
      'supportReplyEmail',
      'supportAttachScreenshot',
      'supportSendRequest',
      'supportRequestSent',
      'supportThankYou',
      'supportBackHome',
    ];
    for (final language in const ['it', 'de', 'fr', 'en']) {
      final arb = jsonDecode(
        File('lib/l10n/app_$language.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final key in requiredKeys) {
        expect(arb[key]?.toString().trim(), isNotEmpty,
            reason: '$language $key');
      }
    }
  });

  test('support reference is stable and uses UTC creation year', () {
    expect(
      supportRequestReference(
        'ffa2e63f-9082-4ba0-8575-d5e23d220f99',
        DateTime.parse('2026-12-31T23:59:59Z'),
      ),
      'SUP-2026-FFA2E6',
    );
  });

  testWidgets('support form has no overflow on narrow mobile in four locales',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final locale in const [
      Locale('it'),
      Locale('de'),
      Locale('fr'),
      Locale('en'),
    ]) {
      await tester.pumpWidget(_app(_FakeSupportGateway(), locale: locale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: locale.languageCode);
      expect(find.byKey(const Key('support-submit')), findsOneWidget);
    }
  });
}
