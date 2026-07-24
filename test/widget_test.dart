import 'package:cid_digitale/models/driver_personal_qr_data.dart';
import 'package:cid_digitale/services/personal_vehicle_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personal QR v1 compatibility keys remain unchanged', () {
    expect(DriverPersonalQrData.qrVersion, 1);
    expect(DriverPersonalQrData.qrType, 'CID_PERSON_QR');
    expect(
      PersonalVehicleStorage.legacyProfileKey,
      'driver_personal_qr_data_v1',
    );
  });
}
