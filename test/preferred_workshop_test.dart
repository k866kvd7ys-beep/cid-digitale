import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/models/workshop_model.dart';
import 'package:cid_digitale/screens/auth/customer_profile_page.dart';
import 'package:cid_digitale/screens/service/workshop_selector_screen.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_customer_auth_service.dart';
import 'helpers/fake_preferred_workshop_repository.dart';

const _account = CustomerAccount(
  id: 'preferred-workshop-customer',
  email: 'antonio@example.com',
  role: customerRole,
  firstName: 'Antonio',
  lastName: 'Privitera',
);

const _profile = CustomerProfile(
  userId: 'preferred-workshop-customer',
  title: 'mr',
  firstName: 'Antonio',
  lastName: 'Privitera',
  street: 'Via Cliente 1',
  postalCode: '6900',
  city: 'Lugano',
  country: 'CH',
  phone: '+41 79 111 22 33',
  email: 'antonio@example.com',
  profileCompleted: true,
);

const _favorite = WorkshopModel(
  id: 'favorite-workshop',
  name: 'Garage Preferito SA',
  email: 'preferito@example.com',
  phone: '+41 91 555 12 34',
  address: 'Via Officina 8',
  city: '6900 Lugano',
  rating: 4.9,
  isOpen: true,
  latitude: 46.0037,
  longitude: 8.9511,
);

Widget _localizedApp({
  required Widget home,
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

Future<void> _pumpProfile(
  WidgetTester tester, {
  required FakeCustomerAuthService auth,
  required FakePreferredWorkshopRepository repository,
  Locale locale = const Locale('it'),
}) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _localizedApp(
      locale: locale,
      home: CustomerProfilePage(
        service: auth,
        account: _account,
        initialProfile: _profile,
        isOnboarding: false,
        preferredWorkshopRepository: repository,
      ),
    ),
  );
  await tester.pump();
}

Finder _buttonWithText(String text) {
  return find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate(
      (widget) => widget is ButtonStyleButton,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'profile chooses with the existing selector, persists and removes only the favorite',
      (tester) async {
    final auth = FakeCustomerAuthService(
      account: _account,
      profile: _profile,
    );
    final repository = FakePreferredWorkshopRepository();
    addTearDown(auth.dispose);

    await _pumpProfile(
      tester,
      auth: auth,
      repository: repository,
    );

    expect(find.text('Officina preferita'), findsOneWidget);
    expect(
      find.text('Nessuna officina preferita selezionata.'),
      findsOneWidget,
    );
    final saveButton = find.byKey(const Key('profile_save'));
    final section = find.byKey(const Key('preferred_workshop_section'));
    expect(
      tester.getBottomLeft(saveButton).dy,
      lessThan(tester.getTopLeft(section).dy),
    );

    await tester.tap(find.text('Scegli officina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byType(WorkshopSelectorScreen), findsOneWidget);
    expect(find.text('Scegli la tua officina'), findsWidgets);
    expect(find.text('Usa la mia posizione'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    final selectButton = find.descendant(
      of: find.byKey(const Key('workshop_option_garage-europa-ag')),
      matching: find.text('Seleziona'),
    );
    await tester.ensureVisible(selectButton);
    await tester.tap(selectButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.saveCalls, 1);
    expect(repository.stored?.name, 'Garage Europa AG');
    expect(auth.saveProfileCalls, 0);
    expect(find.byType(CustomerProfilePage), findsOneWidget);
    expect(find.byType(WorkshopSelectorScreen), findsNothing);
    final profileCard =
        find.byKey(const Key('profile_preferred_workshop_card'));
    expect(
      find.descendant(
        of: profileCard,
        matching: find.text('Garage Europa AG'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: profileCard,
        matching: find.text('Via Cantonale 10, 6900 Lugano'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: profileCard,
        matching: find.text('+41 91 555 10 10'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: profileCard,
        matching: find.text('garage.europa@email.ch'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: profileCard, matching: find.text('4.9')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: profileCard, matching: find.text('Aperto')),
      findsOneWidget,
    );

    await tester.tap(find.text('Rimuovi'));
    await tester.pump();

    expect(repository.removeCalls, 1);
    expect(repository.stored, isNull);
    expect(auth.saveProfileCalls, 0);
    expect(
      find.text('Nessuna officina preferita selezionata.'),
      findsOneWidget,
    );
  });

  testWidgets('saved favorite reloads with complete details and can be changed',
      (tester) async {
    final auth = FakeCustomerAuthService(
      account: _account,
      profile: _profile,
    );
    final repository = FakePreferredWorkshopRepository(stored: _favorite);
    addTearDown(auth.dispose);

    await _pumpProfile(
      tester,
      auth: auth,
      repository: repository,
    );

    expect(repository.loadCalls, 1);
    expect(find.text(_favorite.name), findsOneWidget);
    expect(
        find.text('${_favorite.address}, ${_favorite.city}'), findsOneWidget);
    expect(find.text(_favorite.phone!), findsOneWidget);
    expect(find.text(_favorite.email!), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('Aperto'), findsOneWidget);

    await tester.tap(find.text('Modifica officina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byType(WorkshopSelectorScreen), findsOneWidget);
    expect(find.text('Scegli la tua officina'), findsWidgets);
    expect(find.text('Seleziona'), findsWidgets);
  });

  testWidgets(
      'booking shows favorite before the list and temporary choices never persist',
      (tester) async {
    final repository = FakePreferredWorkshopRepository(stored: _favorite);
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        home: WorkshopSelectorScreen(
          title: 'Servizio officina',
          serviceType: 'service_inspection',
          preferredWorkshopRepository: repository,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final favoriteCard =
        find.byKey(const Key('booking_preferred_workshop_card'));
    final firstWorkshop =
        find.byKey(const Key('workshop_option_garage-europa-ag'));
    expect(favoriteCard, findsOneWidget);
    expect(firstWorkshop, findsOneWidget);
    expect(
      tester.getBottomLeft(favoriteCard).dy,
      lessThan(tester.getTopLeft(firstWorkshop).dy),
    );
    expect(find.text('La tua officina preferita'), findsOneWidget);
    expect(find.text(_favorite.name), findsOneWidget);

    var continueButton =
        tester.widget<FilledButton>(_buttonWithText('Continua'));
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.text('Usa questa officina'));
    await tester.pump();

    continueButton = tester.widget<FilledButton>(_buttonWithText('Continua'));
    expect(continueButton.onPressed, isNotNull);
    expect(firstWorkshop, findsOneWidget);
    expect(repository.saveCalls, 0);
    expect(repository.removeCalls, 0);

    await tester.ensureVisible(firstWorkshop);
    await tester.tap(firstWorkshop);
    await tester.pump();

    expect(repository.stored?.id, _favorite.id);
    expect(repository.saveCalls, 0);
    expect(repository.removeCalls, 0);
  });

  testWidgets('favorite load failure leaves the normal workshop list usable',
      (tester) async {
    final repository = FakePreferredWorkshopRepository()
      ..loadError = StateError('network unavailable');
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        home: WorkshopSelectorScreen(
          title: 'Servizio officina',
          serviceType: 'service_inspection',
          preferredWorkshopRepository: repository,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(const Key('booking_preferred_workshop_card')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('workshop_option_garage-europa-ag')),
      findsOneWidget,
    );
  });

  testWidgets('preferred workshop copy is localized in all four languages',
      (tester) async {
    final translations = <Locale, List<String>>{
      const Locale('it'): [
        'Officina preferita',
        'Nessuna officina preferita selezionata.',
        'Scegli officina',
      ],
      const Locale('de'): [
        'Bevorzugte Werkstatt',
        'Keine bevorzugte Werkstatt ausgewählt.',
        'Werkstatt auswählen',
      ],
      const Locale('fr'): [
        'Atelier préféré',
        'Aucun atelier préféré sélectionné.',
        'Choisir un atelier',
      ],
      const Locale('en'): [
        'Preferred workshop',
        'No preferred workshop selected.',
        'Choose workshop',
      ],
    };

    for (final entry in translations.entries) {
      final auth = FakeCustomerAuthService(
        account: _account,
        profile: _profile,
      );
      final repository = FakePreferredWorkshopRepository();
      await _pumpProfile(
        tester,
        auth: auth,
        repository: repository,
        locale: entry.key,
      );
      for (final text in entry.value) {
        expect(find.text(text), findsOneWidget);
      }
      await auth.dispose();
    }
  });

  test('repository and booking routing contracts remain isolated', () {
    final repositorySource = File(
      'lib/services/preferred_workshop_repository.dart',
    ).readAsStringSync();
    final selectorSource = File(
      'lib/screens/service/workshop_selector_screen.dart',
    ).readAsStringSync();

    expect(repositorySource, contains(".from('customer_profiles')"));
    expect(
      repositorySource,
      contains(".update({'preferred_workshop': _encodeWorkshop(workshop)})"),
    );
    expect(
      repositorySource,
      contains(".update({'preferred_workshop': null})"),
    );
    expect(repositorySource, isNot(contains('customer_vehicles')));
    expect(repositorySource, isNot(contains('SharedPreferences')));
    expect(
      selectorSource,
      contains('selectedWorkshop: workshop,'),
    );
    expect(
      selectorSource,
      contains('_selectedWorkshop = workshop;'),
    );
  });
}
