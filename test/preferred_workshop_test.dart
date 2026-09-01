import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/models/workshop_model.dart';
import 'package:cid_digitale/screens/auth/customer_profile_page.dart';
import 'package:cid_digitale/screens/service/workshop_selector_screen.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:cid_digitale/services/device_location_service.dart';
import 'package:cid_digitale/services/places_workshop_search_service.dart';
import 'package:cid_digitale/services/preferred_workshop_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'helpers/fake_customer_auth_service.dart';
import 'helpers/fake_places_workshop_search_service.dart';
import 'helpers/fake_preferred_workshop_repository.dart';
import 'helpers/workshop_fixtures.dart';

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

const _favorite = realPreferredWorkshopFixture;

class _SuccessfulDeviceLocationService extends DeviceLocationService {
  const _SuccessfulDeviceLocationService();

  @override
  Future<DeviceLocationResult> requestCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return DeviceLocationResult(
      serviceEnabled: true,
      permission: LocationPermission.whileInUse,
      position: Position(
        latitude: 46.0037,
        longitude: 8.9511,
        timestamp: DateTime(2026, 8, 31, 12),
        accuracy: 4,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: true,
      ),
    );
  }

  @override
  Future<String?> resolveCityHint(Position position) async => 'Lugano';
}

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
  FakePlacesWorkshopSearchService? placesService,
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
        placesWorkshopSearchService: placesService,
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
      'profile chooses a Google Places result, persists and removes only the favorite',
      (tester) async {
    final auth = FakeCustomerAuthService(
      account: _account,
      profile: _profile,
    );
    final repository = FakePreferredWorkshopRepository();
    final placesService = FakePlacesWorkshopSearchService(
      textResults: const [realPlacesWorkshopFixture],
    );
    addTearDown(auth.dispose);

    await _pumpProfile(
      tester,
      auth: auth,
      repository: repository,
      placesService: placesService,
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
    await tester.pumpAndSettle();

    expect(find.byType(WorkshopSelectorScreen), findsOneWidget);
    expect(find.text('Scegli la tua officina'), findsWidgets);
    expect(find.text('Usa la mia posizione'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Garage Reale');
    await tester.pump(const Duration(milliseconds: 421));
    await tester.pump();

    final workshopOption = find.byKey(
      const Key('workshop_option_google-place-real-workshop'),
    );
    expect(workshopOption, findsOneWidget);
    expect(placesService.textSearchCalls, 1);
    await tester.ensureVisible(workshopOption);
    await tester.tap(workshopOption);
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(repository.stored?.id, realPlacesWorkshopFixture.id);
    expect(auth.saveProfileCalls, 0);
    expect(find.byType(CustomerProfilePage), findsOneWidget);
    expect(find.byType(WorkshopSelectorScreen), findsNothing);
    final profileCard =
        find.byKey(const Key('profile_preferred_workshop_card'));
    expect(
      find.descendant(
        of: profileCard,
        matching: find.text(realPlacesWorkshopFixture.name),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: profileCard,
        matching: find.text(
          '${realPlacesWorkshopFixture.address}, '
          '${realPlacesWorkshopFixture.city}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: profileCard,
        matching: find.text(realPlacesWorkshopFixture.phone!),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: profileCard, matching: find.text('4.6')),
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
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('Aperto'), findsOneWidget);

    await tester.tap(find.text('Modifica officina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byType(WorkshopSelectorScreen), findsOneWidget);
    expect(find.text('Scegli la tua officina'), findsWidgets);
    for (final mockName in legacyMockWorkshopNames) {
      expect(find.text(mockName), findsNothing);
    }
  });

  testWidgets('booking uses a real favorite without persisting temporary state',
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
    expect(favoriteCard, findsOneWidget);
    expect(find.text('La tua officina preferita'), findsOneWidget);
    expect(find.text(_favorite.name), findsOneWidget);

    var continueButton =
        tester.widget<FilledButton>(_buttonWithText('Continua'));
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.text('Usa questa officina'));
    await tester.pump();

    continueButton = tester.widget<FilledButton>(_buttonWithText('Continua'));
    expect(continueButton.onPressed, isNotNull);
    expect(repository.saveCalls, 0);
    expect(repository.removeCalls, 0);
    expect(repository.stored?.id, _favorite.id);
    expect(repository.saveCalls, 0);
    expect(repository.removeCalls, 0);
  });

  testWidgets('favorite load failure leaves Google Places search usable',
      (tester) async {
    final repository = FakePreferredWorkshopRepository()
      ..loadError = StateError('network unavailable');
    final placesService = FakePlacesWorkshopSearchService(
      textResults: const [realPlacesWorkshopFixture],
    );
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
          placesWorkshopSearchService: placesService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(
      find.byKey(const Key('booking_preferred_workshop_card')),
      findsNothing,
    );
    await tester.enterText(find.byType(TextField), 'Garage Reale');
    await tester.pump(const Duration(milliseconds: 421));
    await tester.pump();
    expect(
      find.byKey(
        const Key('workshop_option_google-place-real-workshop'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('production selector starts empty without legacy mock workshops',
      (tester) async {
    final repository = FakePreferredWorkshopRepository();

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
    await tester.pump();

    for (final mockName in legacyMockWorkshopNames) {
      expect(find.text(mockName), findsNothing);
    }
    expect(
        find.byKey(const Key('booking_preferred_workshop_card')), findsNothing);
    expect(find.byKey(const Key('workshop_option_garage-europa-ag')),
        findsNothing);
    expect(
      tester.widget<FilledButton>(_buttonWithText('Continua')).onPressed,
      isNull,
    );
  });

  testWidgets(
      'unconfigured Google Places leaves an empty selector without invented fallback',
      (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        home: WorkshopSelectorScreen(
          title: 'Servizio officina',
          serviceType: 'service_inspection',
          preferredWorkshopRepository: FakePreferredWorkshopRepository(),
          placesWorkshopSearchService: PlacesWorkshopSearchService(apiKey: ''),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Garage');
    await tester.pump(const Duration(milliseconds: 421));
    await tester.pump();

    for (final mockName in legacyMockWorkshopNames) {
      expect(find.text(mockName), findsNothing);
    }
    expect(find.byKey(const Key('workshop_option_garage-europa-ag')),
        findsNothing);
    expect(
      tester.widget<FilledButton>(_buttonWithText('Continua')).onPressed,
      isNull,
    );
  });

  testWidgets(
      'simulated Google Places result is selectable and reaches the calendar route',
      (tester) async {
    final placesService = FakePlacesWorkshopSearchService(
      textResults: const [realPlacesWorkshopFixture],
    );
    WorkshopModel? routedWorkshop;

    await tester.pumpWidget(
      _localizedApp(
        home: WorkshopSelectorScreen(
          title: 'Servizio officina',
          serviceType: 'service_inspection',
          preferredWorkshopRepository: FakePreferredWorkshopRepository(),
          placesWorkshopSearchService: placesService,
          slotPickerBuilder: (workshop) {
            routedWorkshop = workshop;
            return Scaffold(
              body: Text(
                'calendar:${workshop.id}',
                key: const Key('calendar-route-result'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Garage Reale');
    await tester.pump(const Duration(milliseconds: 421));
    await tester.pump();

    final option = find.byKey(
      const Key('workshop_option_google-place-real-workshop'),
    );
    expect(option, findsOneWidget);
    expect(find.text(realPlacesWorkshopFixture.name), findsOneWidget);
    expect(placesService.textSearchCalls, 1);

    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pump();
    await tester.tap(_buttonWithText('Continua'));
    await tester.pumpAndSettle();

    expect(routedWorkshop?.id, realPlacesWorkshopFixture.id);
    expect(find.byKey(const Key('calendar-route-result')), findsOneWidget);
  });

  testWidgets('nearby search keeps using Google Places results',
      (tester) async {
    final placesService = FakePlacesWorkshopSearchService(
      nearbyResults: const [realPlacesWorkshopFixture],
    );

    await tester.pumpWidget(
      _localizedApp(
        home: WorkshopSelectorScreen(
          title: 'Servizio officina',
          serviceType: 'service_inspection',
          preferredWorkshopRepository: FakePreferredWorkshopRepository(),
          placesWorkshopSearchService: placesService,
          deviceLocationService: const _SuccessfulDeviceLocationService(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Usa la mia posizione'));
    await tester.pumpAndSettle();

    expect(placesService.nearbySearchCalls, 1);
    expect(
      find.byKey(
        const Key('workshop_option_google-place-real-workshop'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('legacy mock favorite and preselection are ignored',
      (tester) async {
    final auth = FakeCustomerAuthService(
      account: _account,
      profile: _profile,
    );
    final repository = FakePreferredWorkshopRepository(
      stored: legacyMockWorkshopFixture,
    );
    addTearDown(auth.dispose);

    await _pumpProfile(
      tester,
      auth: auth,
      repository: repository,
    );

    expect(find.text(legacyMockWorkshopFixture.name), findsNothing);
    expect(
      find.text('Nessuna officina preferita selezionata.'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _localizedApp(
        home: WorkshopSelectorScreen(
          title: 'Servizio officina',
          serviceType: 'service_inspection',
          preselectedWorkshop: legacyMockWorkshopFixture,
          preferredWorkshopRepository: repository,
          placesWorkshopSearchService: FakePlacesWorkshopSearchService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(legacyMockWorkshopFixture.name), findsNothing);
    expect(
        find.byKey(const Key('booking_preferred_workshop_card')), findsNothing);
    expect(
      tester.widget<FilledButton>(_buttonWithText('Continua')).onPressed,
      isNull,
    );
  });

  test('all four legacy mock workshop IDs are rejected', () {
    expect(legacyMockWorkshopIds, hasLength(4));
    for (final workshop in legacyMockWorkshopFixtures) {
      expect(isLegacyMockWorkshop(workshop), isTrue, reason: workshop.id);
    }
    expect(isLegacyMockWorkshop(realPreferredWorkshopFixture), isFalse);
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
    expect(repositorySource, contains('legacyMockWorkshopIds'));
    expect(selectorSource, isNot(contains('WorkshopCatalogService')));
    expect(selectorSource, isNot(contains('_catalogWorkshops')));
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
