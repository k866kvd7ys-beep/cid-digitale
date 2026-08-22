import 'dart:convert';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/main.dart';
import 'package:cid_digitale/models/personal_vehicle_data.dart';
import 'package:cid_digitale/services/device_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class _DeniedLocationService extends DeviceLocationService {
  const _DeniedLocationService();

  @override
  Future<DeviceLocationResult> requestCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const DeviceLocationResult(
      serviceEnabled: true,
      permission: LocationPermission.denied,
      position: null,
    );
  }
}

class _FakeImagePicker extends ImagePicker {
  _FakeImagePicker(this.file);

  final XFile file;
  int calls = 0;
  final List<double?> maxWidths = [];
  final List<int?> imageQualities = [];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls += 1;
    maxWidths.add(maxWidth);
    imageQualities.add(imageQuality);
    return file;
  }
}

Widget _app({
  PersonalVehicleData? initialVehicle,
  ImagePicker? imagePicker,
  Future<void> Function(String imagePath)? damagePhotoOcrReader,
}) {
  return MaterialApp(
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(useMaterial3: true),
    home: NuovaPraticaIncidentePage(
      initialVehicle: initialVehicle,
      imagePicker: imagePicker,
      damagePhotoOcrReader: damagePhotoOcrReader,
      locationService: const _DeniedLocationService(),
    ),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapVisibleWithoutSettling(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void _useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'testimoni e feriti sono compatti, multipli e rimovibili su iPhone',
      (tester) async {
    _useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Testimoni (se presenti)'), findsOneWidget);
    expect(
      find.text(
        'Aggiungi solo le persone che hanno assistito all’incidente.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('incident_witness_form_0')), findsNothing);
    expect(find.byKey(const Key('incident_injured_form_0')), findsNothing);
    expect(find.text('Nessun ferito segnalato'), findsOneWidget);
    expect(find.textContaining('Numero sinistro veicolo'), findsNothing);
    expect(tester.takeException(), isNull);

    await _tapVisible(tester, find.byKey(const Key('incident_add_witness')));
    expect(find.byKey(const Key('incident_witness_form_0')), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('incident_add_witness')));
    expect(find.byKey(const Key('incident_witness_form_0')), findsOneWidget);
    expect(find.byKey(const Key('incident_witness_form_1')), findsOneWidget);

    await _tapVisible(tester, find.byTooltip('Elimina testimone').first);
    expect(find.byKey(const Key('incident_witness_form_0')), findsOneWidget);
    expect(find.byKey(const Key('incident_witness_form_1')), findsNothing);

    await _tapVisible(tester, find.byTooltip('Elimina testimone').first);
    expect(find.byKey(const Key('incident_witness_form_0')), findsNothing);

    await _tapVisible(tester, find.byKey(const Key('incident_add_injured')));
    expect(find.byKey(const Key('incident_injured_form_0')), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('incident_add_injured')));
    expect(find.byKey(const Key('incident_injured_form_1')), findsOneWidget);

    await _tapVisible(tester, find.byTooltip('Elimina ferito').first);
    expect(find.byKey(const Key('incident_injured_form_0')), findsOneWidget);
    expect(find.byKey(const Key('incident_injured_form_1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('riepilogo compatto veicolo A e B mantiene tutti i campi',
      (tester) async {
    _useViewport(tester, const Size(1280, 1400));
    const vehicle = PersonalVehicleData(
      id: 'vehicle-a',
      targa: 'AG399854',
      marca: 'Porsche',
      modello: 'Cayenne S',
      vin: 'VIN-A',
      kilometraggio: '23000',
      primaImmatricolazione: '2023',
      assicurazione: 'Visana',
      numeroPolizza: 'POL-A',
      numeroSinistro: '',
    );

    await tester.pumpWidget(_app(initialVehicle: vehicle));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('incident_driver_A_vehicle_summary')),
      findsOneWidget,
    );
    expect(find.text('Porsche Cayenne S'), findsWidgets);
    expect(find.text('AG399854 · Visana'), findsOneWidget);
    expect(find.byKey(const Key('incident_driver_A_policy')), findsOneWidget);
    expect(find.byKey(const Key('incident_driver_A_vin')), findsOneWidget);
    expect(find.byKey(const Key('incident_driver_A_mileage')), findsOneWidget);
    expect(
      find.byKey(const Key('incident_driver_A_first_registration')),
      findsOneWidget,
    );

    final brandB = tester.widget<TextFormField>(
      find.byKey(const Key('incident_driver_B_brand')),
    );
    final modelB = tester.widget<TextFormField>(
      find.byKey(const Key('incident_driver_B_model')),
    );
    final plateB = tester.widget<TextFormField>(
      find.byKey(const Key('incident_driver_B_plate')),
    );
    final insuranceB = tester.widget<TextFormField>(
      find.byKey(const Key('incident_driver_B_insurance')),
    );
    brandB.controller!.text = 'Audi';
    modelB.controller!.text = 'A4';
    plateB.controller!.text = 'ZH222222';
    insuranceB.controller!.text = 'Helvetia';
    await tester.pump();

    expect(
      find.byKey(const Key('incident_driver_B_vehicle_summary')),
      findsOneWidget,
    );
    expect(find.text('Audi A4'), findsOneWidget);
    expect(find.text('ZH222222 · Helvetia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('foto danni mostra contatore e blocca la quinta foto',
      (tester) async {
    _useViewport(tester, const Size(390, 844));
    final imagePicker = _FakeImagePicker(
      XFile.fromData(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
          'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
        name: 'damage.png',
        mimeType: 'image/png',
      ),
    );

    await tester.pumpWidget(
      _app(
        imagePicker: imagePicker,
        damagePhotoOcrReader: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Massimo 4 foto'), findsOneWidget);
    expect(find.text('0/4'), findsOneWidget);

    for (var index = 1; index <= 4; index++) {
      await _tapVisibleWithoutSettling(
        tester,
        find.byKey(const Key('incident_add_damage_photo')),
      );
      expect(find.text('$index/4'), findsOneWidget);
    }

    expect(imagePicker.calls, 4);
    expect(imagePicker.maxWidths, everyElement(2000));
    expect(imagePicker.imageQualities, everyElement(80));

    await _tapVisibleWithoutSettling(
      tester,
      find.byKey(const Key('incident_add_damage_photo')),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(imagePicker.calls, 4);
    expect(find.text('4/4'), findsOneWidget);
    expect(
      find.text('Puoi aggiungere al massimo 4 foto del danno.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
