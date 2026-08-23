import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic email and PDF include each driver vehicle from payload_json',
      () {
    final source =
        File('supabase/functions/send-cid-email/index.ts').readAsStringSync();
    final rowSource = File(
      'supabase/functions/send-cid-email/driver_vehicle_pdf_rows.ts',
    ).readAsStringSync();

    expect(source, contains('const getDriverVehicle ='));
    expect(source, contains(r'payload?.[`marca${variant}`]'));
    expect(source, contains(r'payload?.[`modello${variant}`]'));
    expect(source, contains('vehicle?.brand'));
    expect(source, contains('vehicle?.model'));
    expect(source, contains('const getAdditionalDrivers ='));
    expect(
      source,
      contains('buildDriverVehicleIdentityPdfRows('),
    );
    expect(
      RegExp(r'\.\.\.buildDriverVehicleIdentityPdfRows\(')
          .allMatches(source)
          .length,
      2,
    );
    expect(source, contains('brand: "Marke"'));
    expect(source, contains('model: "Modell"'));
    expect(rowSource, contains('[labels.brand, valueOrDash(vehicle.brand)]'));
    expect(rowSource, contains('[labels.model, valueOrDash(vehicle.model)]'));
    expect(
        rowSource, contains('return normalized.length > 0 ? normalized : "-"'));
    expect(
      source,
      contains(
          '[copy.policyNumber, stringOrDash(driverBVehicle.policyNumber)]'),
    );
    expect(source, contains('for (const driver of additionalDrivers)'));
    expect(source, contains('driverTextBlock(copy.driverA'));
    expect(source, contains('driverTextBlock(copy.driverB'));
    expect(source, contains('additionalDriverPresentations.flatMap'));
  });
}
