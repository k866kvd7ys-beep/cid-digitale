import 'dart:async';

import 'package:cid_digitale/auth/customer_auth_strings.dart';
import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/customer_legal_acceptance.dart';
import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/screens/auth/customer_profile_page.dart';
import 'package:cid_digitale/screens/auth/register_page.dart';
import 'package:cid_digitale/screens/legal/legal_document_page.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_customer_auth_service.dart';
import 'helpers/fake_preferred_workshop_repository.dart';

const _account = CustomerAccount(
  id: 'legal-customer',
  email: 'mario@example.com',
  role: customerRole,
  firstName: 'Mario',
  lastName: 'Rossi',
);

const _profile = CustomerProfile(
  userId: 'legal-customer',
  firstName: 'Mario',
  lastName: 'Rossi',
  email: 'mario@example.com',
  profileCompleted: true,
);

Widget _app(
  Widget home, {
  Locale locale = const Locale('it'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(useMaterial3: true),
    home: home,
  );
}

Future<void> _fillValidRegistration(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('register_first_name')),
    'Mario',
  );
  await tester.enterText(
    find.byKey(const Key('register_last_name')),
    'Rossi',
  );
  await tester.enterText(
    find.byKey(const Key('register_email')),
    'mario@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('register_password')),
    'password123',
  );
  await tester.enterText(
    find.byKey(const Key('register_password_confirmation')),
    'password123',
  );
}

Finder _acceptanceCheckbox(String key) {
  return find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(Checkbox),
  );
}

Future<void> _acceptLegalDocuments(WidgetTester tester) async {
  final acceptance = _acceptanceCheckbox('register_legal_acceptance');
  await tester.ensureVisible(acceptance);
  await tester.tap(acceptance);
}

void main() {
  testWidgets('registration requires the single legal acceptance',
      (tester) async {
    final service = FakeCustomerAuthService(signUpNeedsConfirmation: true);
    addTearDown(service.dispose);
    await tester.pumpWidget(_app(RegisterPage(service: service)));
    await _fillValidRegistration(tester);

    final acceptance = _acceptanceCheckbox('register_legal_acceptance');
    expect(acceptance, findsOneWidget);
    expect(tester.widget<Checkbox>(acceptance).value, isFalse);
    expect(
      find.byKey(const Key('register_privacy_acceptance')),
      findsNothing,
    );
    expect(find.byKey(const Key('register_terms_acceptance')), findsNothing);

    final submit = find.byKey(const Key('register_submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(service.signUpCalls, 0);
    expect(find.text('Devi accettare per continuare.'), findsOneWidget);

    await tester.ensureVisible(acceptance);
    await tester.tap(acceptance);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(service.signUpCalls, 1);
    expect(service.lastLegalAcceptance, isNotNull);
    expect(
      service.lastLegalAcceptance!.privacyAcceptedAt.isUtc,
      isTrue,
    );
    expect(service.lastLegalAcceptance!.termsAcceptedAt.isUtc, isTrue);
    expect(
      service.lastLegalAcceptance!.termsAcceptedAt,
      service.lastLegalAcceptance!.privacyAcceptedAt,
    );
    expect(service.lastLegalAcceptance!.privacyVersion, '2026-08-08');
    expect(service.lastLegalAcceptance!.termsVersion, '2026-08-08');
  });

  test('registration legal acceptance copy is localized in IT DE FR and EN',
      () {
    const expected = <String, List<String>>{
      'it': [
        'Ho preso visione della',
        'Privacy Policy',
        'e accetto i',
        'Termini d’uso',
        '.',
      ],
      'de': [
        'Ich habe die',
        'Datenschutzerklärung',
        'zur Kenntnis genommen und akzeptiere die',
        'Nutzungsbedingungen',
        '.',
      ],
      'fr': [
        'J’ai pris connaissance de la',
        'Politique de confidentialité',
        'et j’accepte les',
        'Conditions d’utilisation',
        '.',
      ],
      'en': [
        'I have read the',
        'Privacy Policy',
        'and accept the',
        'Terms of Use',
        '.',
      ],
    };

    for (final entry in expected.entries) {
      final strings = CustomerAuthStrings(entry.key);
      expect(
        [
          strings.legalAcceptancePrefix,
          strings.privacyPolicy,
          strings.legalAcceptanceMiddle,
          strings.termsOfUse,
          strings.legalAcceptanceSuffix,
        ],
        entry.value,
      );
    }
  });

  testWidgets('registration retry reuses the original acceptance timestamp',
      (tester) async {
    final service = FakeCustomerAuthService(signUpNeedsConfirmation: true)
      ..signUpError = const CustomerAuthException(
        CustomerAuthErrorCode.generic,
      );
    addTearDown(service.dispose);
    await tester.pumpWidget(_app(RegisterPage(service: service)));
    await _fillValidRegistration(tester);
    await _acceptLegalDocuments(tester);

    final submit = find.byKey(const Key('register_submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(service.signUpCalls, 1);

    service.signUpError = null;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(service.signUpCalls, 2);
    expect(service.legalAcceptanceCalls, hasLength(2));
    expect(
      service.legalAcceptanceCalls.first,
      service.legalAcceptanceCalls.last,
    );
  });

  testWidgets('double submit starts only one registration request',
      (tester) async {
    final blocker = Completer<void>();
    final service = FakeCustomerAuthService(signUpNeedsConfirmation: true)
      ..signUpBlocker = blocker;
    addTearDown(() {
      if (!blocker.isCompleted) blocker.complete();
      return service.dispose();
    });
    await tester.pumpWidget(_app(RegisterPage(service: service)));
    await _fillValidRegistration(tester);
    await _acceptLegalDocuments(tester);

    final submit = find.byKey(const Key('register_submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit);

    expect(service.signUpCalls, 1);
    blocker.complete();
    await tester.pumpAndSettle();
  });

  test('acceptance survives confirmation and profile-save retries', () async {
    final acceptance = CustomerLegalAcceptance.acceptedAt(
      DateTime.parse('2026-08-08T12:30:00Z'),
    );
    final service = FakeCustomerAuthService(signUpNeedsConfirmation: true);
    addTearDown(service.dispose);

    final result = await service.signUp(
      firstName: 'Mario',
      lastName: 'Rossi',
      email: _account.email,
      password: 'password123',
      legalAcceptance: acceptance,
    );
    expect(result.emailConfirmationRequired, isTrue);
    expect(service.currentAccount, isNull);

    service.account = _account;
    final firstSave = await service.saveProfile(_profile);
    final retrySave = await service.saveProfile(
      _profile.copyWith(firstName: 'Mario aggiornato'),
    );

    expect(firstSave.legalAcceptance, acceptance);
    expect(retrySave.legalAcceptance, acceptance);
    expect(retrySave.firstName, 'Mario aggiornato');
  });

  test('existing customer without sign-up metadata remains without consent',
      () async {
    final service = FakeCustomerAuthService(
      account: _account,
      profile: _profile,
    );
    addTearDown(service.dispose);

    final saved = await service.saveProfile(
      _profile.copyWith(firstName: 'Legacy updated'),
    );

    expect(saved.legalAcceptance, isNull);
    expect(saved.firstName, 'Legacy updated');
  });

  testWidgets('registration opens Privacy Policy and Terms of Use separately',
      (tester) async {
    final service = FakeCustomerAuthService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_app(RegisterPage(service: service)));

    final privacyLink = find.text('Privacy Policy');
    await tester.ensureVisible(privacyLink);
    await tester.tap(privacyLink);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy_policy_page')), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final termsLink = find.text('Termini d’uso');
    await tester.ensureVisible(termsLink);
    await tester.tap(termsLink);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('terms_of_use_page')), findsOneWidget);
  });

  testWidgets('legal documents are localized in IT DE FR and EN',
      (tester) async {
    const expected = <String, List<String>>{
      'it': ['Privacy Policy', 'Termini d’uso'],
      'de': ['Datenschutzerklärung', 'Nutzungsbedingungen'],
      'fr': ['Politique de confidentialité', 'Conditions d’utilisation'],
      'en': ['Privacy Policy', 'Terms of Use'],
    };

    for (final entry in expected.entries) {
      await tester.pumpWidget(
        _app(
          const LegalDocumentPage(
            documentType: LegalDocumentType.privacyPolicy,
          ),
          locale: Locale(entry.key),
        ),
      );
      await tester.pump();
      expect(find.text(entry.value.first), findsWidgets);
      expect(find.byKey(const Key('legal_draft_notice')), findsOneWidget);

      await tester.pumpWidget(
        _app(
          const LegalDocumentPage(
            documentType: LegalDocumentType.termsOfUse,
          ),
          locale: Locale(entry.key),
        ),
      );
      await tester.pump();
      expect(find.text(entry.value.last), findsWidgets);
      expect(find.byKey(const Key('legal_draft_notice')), findsOneWidget);
    }
  });

  testWidgets('legal pages render on mobile and desktop widths',
      (tester) async {
    for (final size in const [Size(320, 700), Size(1280, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;

      for (final type in LegalDocumentType.values) {
        await tester.pumpWidget(
          _app(LegalDocumentPage(documentType: type)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('legal_document_scroll')), findsOneWidget);
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('profile settings retain access to both legal documents',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = FakeCustomerAuthService(
      account: _account,
      profile: _profile,
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      _app(
        CustomerProfilePage(
          service: service,
          account: _account,
          initialProfile: _profile,
          isOnboarding: false,
          preferredWorkshopRepository: FakePreferredWorkshopRepository(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('profile_legal_documents')), findsOneWidget);
    final privacyLink = find.byKey(const Key('profile_privacy_policy_link'));
    await tester.ensureVisible(privacyLink);
    await tester.tap(privacyLink);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy_policy_page')), findsOneWidget);
  });
}
