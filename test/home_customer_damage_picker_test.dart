import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/main.dart';
import 'package:cid_digitale/models/customer_incident_event.dart';
import 'package:cid_digitale/models/customer_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fake_customer_auth_service.dart';

const _profile = CustomerProfile(
  userId: 'home-damage-customer',
  firstName: 'Max',
  lastName: 'Muster',
  email: 'max@example.com',
  profileCompleted: true,
);

Widget _app(FakeCustomerAuthService authService) {
  return MaterialApp(
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(useMaterial3: true),
    home: HomePage(profile: _profile, authService: authService),
  );
}

Future<void> _openCustomerDamagePicker(WidgetTester tester) async {
  final trigger = find.text('Um welchen Schaden handelt es sich?');
  await tester.scrollUntilVisible(
    trigger,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(trigger);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'home-damage-picker-test-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'real customer Home modal shows ten German categories in a scrollable two-column grid',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = FakeCustomerAuthService();
      addTearDown(auth.dispose);
      await tester.pumpWidget(_app(auth));
      await tester.pump();
      while (tester.takeException() != null) {}
      await _openCustomerDamagePicker(tester);

      const labels = [
        'Glasschaden',
        'Hagelschaden',
        'Marderschaden',
        'Parkschaden',
        'Unfall / Kollision',
        'Diebstahl / versuchter Diebstahl',
        'Brand',
        'Naturereignis',
        'Kollision mit Tier',
        'Sonstiges',
      ];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.byKey(const Key('damage_type_picker_scroll')),
        findsOneWidget,
      );

      final glass = tester.getRect(
        find.byKey(
          const ValueKey<CustomerIncidentEventType>(
            CustomerIncidentEventType.glassDamage,
          ),
        ),
      );
      final hail = tester.getRect(
        find.byKey(
          const ValueKey<CustomerIncidentEventType>(
            CustomerIncidentEventType.hail,
          ),
        ),
      );
      final marten = tester.getRect(
        find.byKey(
          const ValueKey<CustomerIncidentEventType>(
            CustomerIncidentEventType.marten,
          ),
        ),
      );
      expect(glass.top, closeTo(hail.top, 0.1));
      expect(glass.left, lessThan(hail.left));
      expect(glass.width, closeTo(hail.width, 0.1));
      expect(marten.top, greaterThan(glass.top));

      await tester.drag(
        find.byKey(const Key('damage_type_picker_scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<CustomerIncidentEventType>(
            CustomerIncidentEventType.other,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('real customer Home modal opens existing natural/theft subtypes',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = FakeCustomerAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(_app(auth));
    await tester.pump();
    while (tester.takeException() != null) {}

    await _openCustomerDamagePicker(tester);
    await tester.ensureVisible(
      find.byKey(
        const ValueKey<CustomerIncidentEventType>(
          CustomerIncidentEventType.naturalEvent,
        ),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey<CustomerIncidentEventType>(
          CustomerIncidentEventType.naturalEvent,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welches Naturereignis?'), findsOneWidget);
    for (final subtype in naturalEventSubtypes) {
      expect(
        find.text(customerIncidentEventSubtypeLabel(subtype, 'de')),
        findsOneWidget,
      );
    }
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await _openCustomerDamagePicker(tester);
    await tester.ensureVisible(
      find.byKey(
        const ValueKey<CustomerIncidentEventType>(
          CustomerIncidentEventType.theft,
        ),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey<CustomerIncidentEventType>(
          CustomerIncidentEventType.theft,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welche Art von Diebstahl?'), findsOneWidget);
    for (final subtype in theftEventSubtypes) {
      expect(
        find.text(customerIncidentEventSubtypeLabel(subtype, 'de')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('new incident receives the category selected in the Home modal',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = FakeCustomerAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(_app(auth));
    await tester.pump();
    while (tester.takeException() != null) {}

    await tester.tap(find.text('Neuer Unfall'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<CustomerIncidentEventType>(
          CustomerIncidentEventType.collision,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NuovaPraticaIncidentePage), findsOneWidget);
    expect(find.text('Was ist passiert?'), findsNothing);
    expect(find.text('Ereignisart'), findsNothing);
    final dynamic state = tester.state(
      find.byType(NuovaPraticaIncidentePage),
    );
    expect(state.incidentEventTypeForTesting, 'collision');
    expect(state.incidentEventSubtypeForTesting, isEmpty);
    while (tester.takeException() != null) {}
  });
}
