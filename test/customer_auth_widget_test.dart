import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/screens/auth/login_page.dart';
import 'package:cid_digitale/screens/auth/register_page.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:cid_digitale/widgets/auth/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_customer_auth_service.dart';

const _account = CustomerAccount(
  id: 'customer-1',
  email: 'mario@example.com',
  role: customerRole,
  firstName: 'Mario',
  lastName: 'Rossi',
);

const _completeProfile = CustomerProfile(
  userId: 'customer-1',
  firstName: 'Mario',
  lastName: 'Rossi',
  email: 'mario@example.com',
  profileCompleted: true,
);

const _workshopAccount = CustomerAccount(
  id: 'shared-user',
  email: 'antonio@example.com',
  role: 'workshop',
);

const _workshopCustomerProfile = CustomerProfile(
  userId: 'shared-user',
  firstName: 'Antonio',
  lastName: 'Privitera',
  email: 'antonio@example.com',
  profileCompleted: true,
);

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('it'),
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
    theme: ThemeData(useMaterial3: true),
    home: home,
  );
}

void main() {
  testWidgets('login validates and calls signInWithPassword abstraction',
      (tester) async {
    final service = FakeCustomerAuthService(profile: _completeProfile);
    var authenticated = false;
    await tester.pumpWidget(
      _app(
        LoginPage(
          service: service,
          onAuthenticated: () => authenticated = true,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login_email')),
      'mario@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(service.signInCalls, 1);
    expect(service.lastEmail, 'mario@example.com');
    expect(service.lastPassword, 'password123');
    expect(authenticated, isTrue);
    await service.dispose();
  });

  testWidgets('registration shows mismatched-password validation',
      (tester) async {
    final service = FakeCustomerAuthService();
    await tester.pumpWidget(_app(RegisterPage(service: service)));

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
      'different123',
    );
    await tester.ensureVisible(find.byKey(const Key('register_submit')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pump();

    expect(find.text('Le password non coincidono.'), findsOneWidget);
    expect(service.currentAccount, isNull);
    await service.dispose();
  });

  testWidgets('auth gate sends signed-out users to login', (tester) async {
    final service = FakeCustomerAuthService();
    await tester.pumpWidget(
      _app(
        AuthGate(
          service: service,
          homeBuilder: (_, __, ___) => const Text('HOME'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    await service.dispose();
  });

  testWidgets('auth gate sends incomplete profiles to profile setup',
      (tester) async {
    final service = FakeCustomerAuthService(account: _account);
    await tester.pumpWidget(
      _app(
        AuthGate(
          service: service,
          homeBuilder: (_, __, ___) => const Text('HOME'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_save')), findsOneWidget);
    expect(find.text('Completa il tuo profilo Cliente'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    await service.dispose();
  });

  testWidgets(
      'workshop account without customer profile can complete Customer setup',
      (tester) async {
    final service = FakeCustomerAuthService(account: _workshopAccount);
    await tester.pumpWidget(
      _app(
        AuthGate(
          service: service,
          homeBuilder: (_, __, ___) => const Text('HOME'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completa il tuo profilo Cliente'), findsOneWidget);
    expect(find.text('Questo account non è un account Cliente.'), findsNothing);
    expect(service.signOutCalls, 0);
    expect(service.account?.role, 'workshop');

    await tester.enterText(
      find.byKey(const Key('profile_first_name')),
      'Antonio',
    );
    await tester.enterText(
      find.byKey(const Key('profile_last_name')),
      'Privitera',
    );
    await tester.ensureVisible(find.byKey(const Key('profile_save')));
    await tester.tap(find.byKey(const Key('profile_save')));
    await tester.pumpAndSettle();

    expect(service.saveProfileCalls, 1);
    expect(service.profile?.userId, _workshopAccount.id);
    expect(service.profile?.profileCompleted, isTrue);
    expect(service.account?.role, 'workshop');
    expect(find.text('HOME'), findsOneWidget);
    await service.dispose();
  });

  testWidgets('workshop account with customer profile opens the Customer home',
      (tester) async {
    final service = FakeCustomerAuthService(
      account: _workshopAccount,
      profile: _workshopCustomerProfile,
    );
    await tester.pumpWidget(
      _app(
        AuthGate(
          service: service,
          homeBuilder: (_, profile, __) => Text(
            'HOME ${profile.displayName}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HOME Antonio Privitera'), findsOneWidget);
    expect(service.account?.role, 'workshop');
    expect(service.signOutCalls, 0);
    await service.dispose();
  });

  testWidgets('existing Auth registration points to login and profile setup',
      (tester) async {
    final service = FakeCustomerAuthService()
      ..signUpError = const CustomerAuthException(
        CustomerAuthErrorCode.emailAlreadyRegistered,
      );
    await tester.pumpWidget(_app(LoginPage(service: service)));
    await tester.tap(find.text('Registrati'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('register_first_name')),
      'Antonio',
    );
    await tester.enterText(
      find.byKey(const Key('register_last_name')),
      'Privitera',
    );
    await tester.enterText(
      find.byKey(const Key('register_email')),
      'antonio@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_confirmation')),
      'password123',
    );
    final privacyAcceptance = find.descendant(
      of: find.byKey(const Key('register_privacy_acceptance')),
      matching: find.byType(Checkbox),
    );
    await tester.ensureVisible(privacyAcceptance);
    await tester.tap(privacyAcceptance);
    final termsAcceptance = find.descendant(
      of: find.byKey(const Key('register_terms_acceptance')),
      matching: find.byType(Checkbox),
    );
    await tester.ensureVisible(termsAcceptance);
    await tester.tap(termsAcceptance);
    await tester.ensureVisible(find.byKey(const Key('register_submit')));
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();

    expect(service.signUpCalls, 1);
    expect(
      find.text(
        'Esiste già un account con questa e-mail. '
        'Accedi con la password esistente per attivare anche il profilo Cliente.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('register_existing_account_login')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('register_existing_account_login')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.byKey(const Key('register_submit')), findsNothing);
    await service.dispose();
  });

  testWidgets('auth gate opens the existing home for a complete profile',
      (tester) async {
    final service = FakeCustomerAuthService(
      account: _account,
      profile: _completeProfile,
    );
    await tester.pumpWidget(
      _app(
        AuthGate(
          service: service,
          homeBuilder: (_, profile, __) => Text(
            'HOME ${profile.displayName}',
            key: const Key('existing_customer_home'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('existing_customer_home')), findsOneWidget);
    expect(find.text('HOME Mario Rossi'), findsOneWidget);
    await service.dispose();
  });

  testWidgets('logout returns the auth gate to login', (tester) async {
    final service = FakeCustomerAuthService(
      account: _account,
      profile: _completeProfile,
    );
    await tester.pumpWidget(
      _app(
        AuthGate(
          service: service,
          homeBuilder: (_, __, auth) => FilledButton(
            key: const Key('test_logout'),
            onPressed: auth.signOut,
            child: const Text('LOGOUT'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test_logout')));
    await tester.pumpAndSettle();

    expect(service.signOutCalls, 1);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    await service.dispose();
  });

  testWidgets('login and registration fit a 320 px mobile viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeCustomerAuthService();

    await tester.pumpWidget(_app(LoginPage(service: service)));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_app(RegisterPage(service: service)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
    await service.dispose();
  });
}
