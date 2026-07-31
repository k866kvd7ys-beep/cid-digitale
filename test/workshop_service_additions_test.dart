import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/l10n/app_localizations_de.dart';
import 'package:cid_digitale/l10n/app_localizations_en.dart';
import 'package:cid_digitale/l10n/app_localizations_fr.dart';
import 'package:cid_digitale/l10n/app_localizations_it.dart';
import 'package:cid_digitale/screens/service/service_anmelden_screen.dart';
import 'package:cid_digitale/screens/service/workshop_service_details_screen.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:cid_digitale/utils/service_booking_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _localizedApp(
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

void _configureMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AppointmentRequestImageInput _photo(int index) {
  return AppointmentRequestImageInput(
    category: AppointmentRequestImageCategory.otherProblem,
    fileName: 'wheel_$index.jpg',
    mimeType: 'image/jpeg',
    previewReference: 'cache:wheel_$index',
    cacheKey: 'wheel_$index',
  );
}

void main() {
  final localizedCopies = <String, AppLocalizations>{
    'it': AppLocalizationsIt(),
    'de': AppLocalizationsDe(),
    'fr': AppLocalizationsFr(),
    'en': AppLocalizationsEn(),
  };

  test('wheel repair and other service use all four ARB localizations', () {
    final expected = <String, List<String>>{
      'it': [
        'Riparazione cerchi',
        'Valutazione e ripristino professionale di cerchi danneggiati.',
        'Altro',
        'Descrivi manualmente il servizio di cui hai bisogno.',
        'Cerchio verniciato standard',
        'Cerchio Diamond Cut',
        'Cerchio bicolore',
        'Cerchio con finitura speciale',
        'Non so, richiedo una valutazione',
        'Foto del cerchio',
        'Che servizio desideri?',
      ],
      'de': [
        'Felgenreparatur',
        'Professionelle Beurteilung und Aufbereitung beschädigter Felgen.',
        'Andere Anfrage',
        'Beschreiben Sie den gewünschten Service manuell.',
        'Standard lackierte Felge',
        'Diamond-Cut-Felge',
        'Zweifarbige Felge',
        'Felge mit Spezialfinish',
        'Ich bin nicht sicher, Bewertung erforderlich',
        'Fotos der Felge',
        'Welchen Service wünschen Sie?',
      ],
      'fr': [
        'Réparation de jantes',
        'Évaluation et remise en état professionnelle des jantes endommagées.',
        'Autre',
        'Décrivez manuellement le service souhaité.',
        'Jante peinte standard',
        'Jante Diamond Cut',
        'Jante bicolore',
        'Jante avec finition spéciale',
        'Je ne sais pas, évaluation demandée',
        'Photos de la jante',
        'Quel service souhaitez-vous ?',
      ],
      'en': [
        'Wheel repair',
        'Professional assessment and restoration of damaged wheels.',
        'Other',
        'Manually describe the service you need.',
        'Standard painted wheel',
        'Diamond Cut wheel',
        'Two-tone wheel',
        'Wheel with special finish',
        'I am not sure, assessment required',
        'Wheel photos',
        'What service do you need?',
      ],
    };

    for (final entry in localizedCopies.entries) {
      final l10n = entry.value;
      expect(
        [
          l10n.workshopServiceWheelRepairTitle,
          l10n.workshopServiceWheelRepairDescription,
          l10n.workshopServiceOtherTitle,
          l10n.workshopServiceOtherDescription,
          l10n.wheelRepairTypeStandardPainted,
          l10n.wheelRepairTypeDiamondCut,
          l10n.wheelRepairTypeTwoTone,
          l10n.wheelRepairTypeSpecialFinish,
          l10n.wheelRepairTypeAssessmentRequired,
          l10n.wheelRepairPhotosTitle,
          l10n.otherServiceQuestion,
        ],
        expected[entry.key],
      );
    }
  });

  testWidgets('service picker contains both new cards and keeps fluids intact',
      (tester) async {
    _configureMobileSurface(tester);
    await tester.pumpWidget(
      _localizedApp(const ServiceAnmeldenScreen()),
    );
    await tester.pumpAndSettle();

    expect(
      workshopServiceLabel('it', workshopServiceFluids),
      'Controllo livelli e rabbocco liquidi',
    );
    expect(
      workshopServiceDescription('it', workshopServiceFluids),
      'Controllo livelli e rabbocco dei liquidi di esercizio.',
    );

    await tester.scrollUntilVisible(
      find.text('Riparazione cerchi'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Riparazione cerchi'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Altro'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Altro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wheel repair card opens the dedicated responsive page',
      (tester) async {
    _configureMobileSurface(tester);
    await tester.pumpWidget(
      _localizedApp(const ServiceAnmeldenScreen()),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Riparazione cerchi'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Riparazione cerchi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wheel_repair_screen')), findsOneWidget);
    expect(find.text('Tipo di cerchio'), findsOneWidget);
    expect(find.text('Foto del cerchio'), findsOneWidget);
    expect(find.byKey(const Key('wheel_photo_add_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wheel type is single-select and description is preserved',
      (tester) async {
    _configureMobileSurface(tester);
    WheelRepairBookingDraft? submittedDraft;
    await tester.pumpWidget(
      _localizedApp(
        WheelRepairServiceScreen(
          onContinue: (draft) => submittedDraft = draft,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final continueButton = find.byKey(
      const Key('wheel_repair_continue_button'),
    );

    await tester.tap(
      find.byKey(const Key('wheel_type_standard_painted')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('wheel_type_diamond_cut')));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const Key('wheel_repair_description_field')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('wheel_repair_description_field')),
      'Graffio sul bordo esterno',
    );
    await tester.scrollUntilVisible(
      continueButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(continueButton);
    await tester.pump();

    expect(submittedDraft, isNotNull);
    expect(submittedDraft!.wheelType, workshopWheelTypeDiamondCut);
    expect(submittedDraft!.description, 'Graffio sul bordo esterno');
    expect(
      workshopWheelTypeFromServiceDetail(
        submittedDraft!.encodedServiceDetail,
      ),
      workshopWheelTypeDiamondCut,
    );
    expect(
      workshopWheelDescriptionFromServiceDetail(
        submittedDraft!.encodedServiceDetail,
      ),
      'Graffio sul bordo esterno',
    );
    expect(tester.takeException(), isNull);
  });

  test('wheel photo collection enforces six photos and supports removal', () {
    final photos = WheelRepairPhotoCollection();
    for (var index = 0; index < WheelRepairPhotoCollection.maxPhotos; index++) {
      expect(photos.add(_photo(index)), isTrue);
    }

    expect(photos.photos, hasLength(6));
    expect(photos.canAdd, isFalse);
    expect(photos.add(_photo(7)), isFalse);

    final removed = photos.removeAt(1);
    expect(removed.fileName, 'wheel_1.jpg');
    expect(photos.photos, hasLength(5));
    expect(photos.canAdd, isTrue);
    expect(
        photos.photos.any((photo) => photo.fileName == 'wheel_1.jpg'), isFalse);
  });

  testWidgets('other service requires text and keeps the 500 character limit',
      (tester) async {
    _configureMobileSurface(tester);
    String? submittedDescription;
    await tester.pumpWidget(
      _localizedApp(
        OtherWorkshopServiceScreen(
          onContinue: (description) => submittedDescription = description,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('other_service_description_field'));
    final continueButton = find.byKey(
      const Key('other_service_continue_button'),
    );
    expect(find.text('0/500'), findsOneWidget);

    await tester.tap(continueButton);
    await tester.pump();
    expect(
      find.text('Descrivi il servizio richiesto per continuare.'),
      findsOneWidget,
    );
    expect(submittedDescription, isNull);

    await tester.enterText(field, 'Diagnosi di un rumore intermittente');
    await tester.tap(continueButton);
    await tester.pump();
    expect(submittedDescription, 'Diagnosi di un rumore intermittente');
    expect(tester.takeException(), isNull);
  });

  test('existing workshop routing and attachment pipeline stay in use', () {
    final selector = File(
      'lib/screens/service/workshop_selector_screen.dart',
    ).readAsStringSync();
    final slotPicker = File(
      'lib/screens/service/workshop_slot_picker_screen.dart',
    ).readAsStringSync();
    final requestDetail = File(
      'lib/screens/request_detail_screen.dart',
    ).readAsStringSync();

    expect(
      selector,
      contains('selectedWorkshop: workshop,'),
    );
    expect(
      selector,
      contains('wheelRepairImages: widget.wheelRepairImages,'),
    );
    expect(
      slotPicker,
      contains('garageId: widget.selectedWorkshop?.id,'),
    );
    expect(
      slotPicker,
      contains('? widget.wheelRepairImages'),
    );
    expect(
      requestDetail,
      contains('request.serviceSelectionKey == workshopServiceWheelRepair'),
    );
    expect(
      requestDetail,
      contains('_otherProblemImageSources()'),
    );
  });

  test('new services remain additive and fluids keep their original order', () {
    expect(
      visibleWorkshopServiceKeys.sublist(
        visibleWorkshopServiceKeys.length - 3,
      ),
      const [
        workshopServiceFluids,
        workshopServiceWheelRepair,
        workshopServiceOther,
      ],
    );
    expect(
      workshopServiceLabel('de', workshopServiceFluids),
      'Niveaukontrolle und Flüssigkeiten auffüllen',
    );
    expect(
      workshopServiceLabel('fr', workshopServiceFluids),
      'Contrôle des niveaux et appoint des liquides',
    );
    expect(
      workshopServiceLabel('en', workshopServiceFluids),
      'Level check and fluid top-up',
    );
  });
}
