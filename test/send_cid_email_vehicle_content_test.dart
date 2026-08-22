import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic email and PDF include each driver vehicle from payload_json',
      () {
    final source =
        File('supabase/functions/send-cid-email/index.ts').readAsStringSync();

    expect(source, contains('const getDriverVehicle ='));
    expect(source, contains('const getAdditionalDrivers ='));
    expect(
      source,
      contains('[copy.vehicle, joinNonEmpty([driverAVehicle.brand'),
    );
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
