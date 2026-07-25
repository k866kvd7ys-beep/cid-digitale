import 'package:cid_digitale/screens/auth/login_page.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:cid_digitale/widgets/auth/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_customer_auth_service.dart';

const _workshopAccount = CustomerAccount(
  id: 'workshop-user',
  email: 'workshop@example.com',
  role: 'workshop',
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

AuthGate _recoveryGate(FakeCustomerAuthService service) {
  return AuthGate(
    service: service,
    passwordRecoveryRoute: true,
    homeBuilder: (_, __, ___) => const Text('HOME'),
  );
}

void main() {
  test('password recovery uses the production public redirect', () {
    expect(customerPasswordRecoveryPath, '/reset-password');
    expect(
      customerPasswordRecoveryRedirectUrl,
      'https://cid-client.vercel.app/reset-password',
    );
    expect(customerPasswordRecoveryRedirectUrl, isNot(contains('localhost')));
  });

  testWidgets(
      'PASSWORD_RECOVERY is handled before customer role and profile checks',
      (tester) async {
    final service = FakeCustomerAuthService(
      account: _workshopAccount,
      initialAuthState: const CustomerAuthState(
        event: CustomerAuthEventType.passwordRecovery,
        hasSession: true,
      ),
    );
    await tester.pumpWidget(_app(_recoveryGate(service)));
    await tester.pumpAndSettle();

    expect(find.text('Crea una nuova password'), findsOneWidget);
    expect(find.byKey(const Key('recovery_submit')), findsOneWidget);
    expect(find.text('Questo account non è un account Cliente.'), findsNothing);
    expect(service.loadProfileCalls, 0);
    expect(service.signOutCalls, 0);
    await service.dispose();
  });

  testWidgets('recovery event is recognized even before route evaluation',
      (tester) async {
    final service = FakeCustomerAuthService(
      account: _workshopAccount,
      initialAuthState: const CustomerAuthState(
        event: CustomerAuthEventType.passwordRecovery,
        hasSession: true,
      ),
    );
    await tester.pumpWidget(
      _app(
        AuthGate(
          service: service,
          passwordRecoveryRoute: false,
          homeBuilder: (_, __, ___) => const Text('HOME'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recovery_submit')), findsOneWidget);
    expect(service.loadProfileCalls, 0);
    await service.dispose();
  });

  testWidgets(
      'an implicit recovery session works without a PKCE verifier on this device',
      (tester) async {
    final service = FakeCustomerAuthService(
      account: _workshopAccount,
      initialAuthState: const CustomerAuthState(
        event: CustomerAuthEventType.initialSession,
        hasSession: false,
      ),
    )..implicitRecoveryResult = true;
    await tester.pumpWidget(_app(_recoveryGate(service)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recovery_submit')), findsOneWidget);
    expect(service.loadProfileCalls, 0);
    expect(find.text('Questo account non è un account Cliente.'), findsNothing);
    await service.dispose();
  });

  testWidgets('new password must be at least eight characters and match',
      (tester) async {
    final service = FakeCustomerAuthService(
      account: _workshopAccount,
      initialAuthState: const CustomerAuthState(
        event: CustomerAuthEventType.passwordRecovery,
        hasSession: true,
      ),
    );
    await tester.pumpWidget(_app(_recoveryGate(service)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('recovery_password')),
      'short',
    );
    await tester.enterText(
      find.byKey(const Key('recovery_password_confirmation')),
      'different',
    );
    await tester.tap(find.byKey(const Key('recovery_submit')));
    await tester.pump();

    expect(
      find.text('La password deve contenere almeno 8 caratteri.'),
      findsOneWidget,
    );
    expect(find.text('Le password non coincidono.'), findsOneWidget);
    expect(service.updatePasswordCalls, 0);
    await service.dispose();
  });

  testWidgets('successful recovery updates, signs out and returns to login',
      (tester) async {
    final service = FakeCustomerAuthService(
      account: _workshopAccount,
      initialAuthState: const CustomerAuthState(
        event: CustomerAuthEventType.passwordRecovery,
        hasSession: true,
      ),
    );
    await tester.pumpWidget(_app(_recoveryGate(service)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('recovery_password')),
      'newPassword123',
    );
    await tester.enterText(
      find.byKey(const Key('recovery_password_confirmation')),
      'newPassword123',
    );
    await tester.tap(find.byKey(const Key('recovery_submit')));
    await tester.pumpAndSettle();

    expect(service.updatePasswordCalls, 1);
    expect(service.lastUpdatedPassword, 'newPassword123');
    expect(service.signOutCalls, 1);
    expect(service.loadProfileCalls, 0);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(
      find.text(
        'Password aggiornata correttamente. La nuova password è valida sia '
        'nel CID Cliente sia nel Tool Officina.',
      ),
      findsOneWidget,
    );
    expect(find.text('HOME'), findsNothing);
    await service.dispose();
  });

  testWidgets('missing recovery session shows the expired-link state',
      (tester) async {
    final service = FakeCustomerAuthService(
      initialAuthState: const CustomerAuthState(
        event: CustomerAuthEventType.initialSession,
        hasSession: false,
      ),
    );
    await tester.pumpWidget(_app(_recoveryGate(service)));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Il link di recupero non è più valido. Richiedi una nuova e-mail.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('recovery_request_new_email')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reset_email')), findsOneWidget);
    expect(find.text('Reimposta la password'), findsOneWidget);
    await service.dispose();
  });

  testWidgets('normal login accepts the existing workshop Auth account',
      (tester) async {
    final service = FakeCustomerAuthService(account: _workshopAccount);
    await tester.pumpWidget(_app(LoginPage(service: service)));

    await tester.enterText(
      find.byKey(const Key('login_email')),
      'workshop@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(service.signInCalls, 1);
    expect(service.currentAccount?.role, 'workshop');
    expect(find.text('Questo account non è un account Cliente.'), findsNothing);
    await service.dispose();
  });

  testWidgets('recovery page has no overflow on an iPhone-sized viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeCustomerAuthService(
      account: _workshopAccount,
      initialAuthState: const CustomerAuthState(
        event: CustomerAuthEventType.passwordRecovery,
        hasSession: true,
      ),
    );

    await tester.pumpWidget(_app(_recoveryGate(service)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('recovery_submit')), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    await service.dispose();
  });
}
