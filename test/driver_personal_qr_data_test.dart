import 'dart:convert';

import 'package:cid_digitale/models/driver_personal_qr_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates the nested JSON payload expected by the workshop scanner',
      () {
    const data = DriverPersonalQrData(
      courtesy: DriverPersonalQrCourtesy.mr,
      nome: 'Mario',
      cognome: 'Rossi',
      indirizzo: 'Via Roma 12',
      zip: '6900',
      city: 'Lugano',
      country: 'CH',
      telefono: '+41 79 000 00 00',
      email: 'mario@example.com',
      targa: 'TI12345',
      marca: 'Volkswagen',
      modello: 'Golf',
      vin: 'WVWZZZ1JZXW000001',
      kilometraggio: '65000',
      primaImmatricolazione: '2021-05',
      assicurazione: 'AXA',
      numeroPolizza: 'POL-2026-00124',
      numeroSinistro: 'CLM-8842',
      customerNumber: '',
    );

    final payload = jsonDecode(driverPersonalQrDataToJson(data)) as Map;

    expect(payload['type'], DriverPersonalQrData.qrType);
    expect(payload['version'], DriverPersonalQrData.qrVersion);
    expect(payload['roles'], [
      'customer_driver',
      'witness',
      'injured',
    ]);
    expect(payload['person'], {
      'title': 'mr',
      'firstName': 'Mario',
      'lastName': 'Rossi',
      'email': 'mario@example.com',
      'phone': '+41 79 000 00 00',
      'street': 'Via Roma 12',
      'zip': '6900',
      'city': 'Lugano',
      'country': 'CH',
    });
    expect(payload['vehicle'], {
      'brand': 'Volkswagen',
      'model': 'Golf',
      'plate': 'TI12345',
      'vin': 'WVWZZZ1JZXW000001',
      'mileage': '65000',
      'firstRegistration': '2021-05',
    });
    expect(payload['insurance'], {
      'company': 'AXA',
      'policyNumber': 'POL-2026-00124',
      'claimNumber': 'CLM-8842',
    });
  });

  test('parses the generated nested JSON payload back into the draft model',
      () {
    const data = DriverPersonalQrData(
      courtesy: DriverPersonalQrCourtesy.company,
      nome: 'Lucia',
      cognome: 'Bianchi',
      indirizzo: 'Via Cantonale 3',
      zip: '6500',
      city: 'Bellinzona',
      country: 'CH',
      telefono: '+41 91 000 00 00',
      email: 'lucia@example.com',
      targa: 'ZH123456',
      marca: 'BMW',
      modello: 'X3',
      vin: 'WBAXX11020F123456',
      kilometraggio: '120000',
      primaImmatricolazione: '2019-10',
      assicurazione: 'Allianz',
      numeroPolizza: 'AZ-9911',
      numeroSinistro: 'C-7788',
      customerNumber: '',
    );

    final parsed = driverPersonalQrDataFromQrPayload(
      driverPersonalQrDataToJson(data),
    );

    expect(parsed, isNotNull);
    expect(parsed!.courtesy, DriverPersonalQrCourtesy.company);
    expect(parsed.nome, 'Lucia');
    expect(parsed.cognome, 'Bianchi');
    expect(parsed.indirizzo, 'Via Cantonale 3');
    expect(parsed.zip, '6500');
    expect(parsed.city, 'Bellinzona');
    expect(parsed.country, 'CH');
    expect(parsed.telefono, '+41 91 000 00 00');
    expect(parsed.email, 'lucia@example.com');
    expect(parsed.targa, 'ZH123456');
    expect(parsed.marca, 'BMW');
    expect(parsed.modello, 'X3');
    expect(parsed.vin, 'WBAXX11020F123456');
    expect(parsed.kilometraggio, '120000');
    expect(parsed.primaImmatricolazione, '2019-10');
    expect(parsed.assicurazione, 'Allianz');
    expect(parsed.numeroPolizza, 'AZ-9911');
    expect(parsed.numeroSinistro, 'C-7788');
  });

  test('keeps compatibility with the legacy flat QR payload', () {
    const legacyPayload = '''
      {
        "courtesy": "mrs",
        "firstName": "Anna",
        "lastName": "Verdi",
        "address": "Via Nassa 5",
        "zip": "6900",
        "city": "Lugano",
        "country": "CH",
        "phone": "+41 78 111 11 11",
        "email": "anna@example.com",
        "plate": "TI54321",
        "insurance": "Zurich"
      }
    ''';

    final parsed = driverPersonalQrDataFromQrPayload(legacyPayload);

    expect(parsed, isNotNull);
    expect(parsed!.courtesy, DriverPersonalQrCourtesy.mrs);
    expect(parsed.nome, 'Anna');
    expect(parsed.cognome, 'Verdi');
    expect(parsed.targa, 'TI54321');
    expect(parsed.assicurazione, 'Zurich');
  });

  test('filters witness and injured imports down to person-only fields', () {
    const data = DriverPersonalQrData(
      courtesy: DriverPersonalQrCourtesy.mr,
      nome: 'Marco',
      cognome: 'Neri',
      indirizzo: 'Via Stazione 8',
      zip: '6600',
      city: 'Locarno',
      country: 'CH',
      telefono: '+41 76 222 22 22',
      email: 'marco@example.com',
      targa: 'GR54321',
      marca: 'Audi',
      modello: 'A4',
      vin: 'WAUZZZ8K1AA123456',
      kilometraggio: '88000',
      primaImmatricolazione: '2020-03',
      assicurazione: 'Helvetia',
      numeroPolizza: 'HEL-8899',
      numeroSinistro: 'SIN-123',
      customerNumber: '',
    );

    final witness =
        data.scopedForImportRole(DriverPersonalQrImportRole.witness);
    final injured =
        data.scopedForImportRole(DriverPersonalQrImportRole.injured);

    expect(witness.courtesy, isNull);
    expect(witness.nome, 'Marco');
    expect(witness.cognome, 'Neri');
    expect(witness.indirizzo, 'Via Stazione 8');
    expect(witness.zip, '6600');
    expect(witness.city, 'Locarno');
    expect(witness.country, 'CH');
    expect(witness.telefono, '+41 76 222 22 22');
    expect(witness.email, isEmpty);
    expect(witness.targa, isEmpty);
    expect(witness.assicurazione, isEmpty);
    expect(witness.vin, isEmpty);

    expect(injured.nome, 'Marco');
    expect(injured.cognome, 'Neri');
    expect(injured.telefono, '+41 76 222 22 22');
    expect(injured.email, isEmpty);
    expect(injured.modello, isEmpty);
    expect(injured.numeroPolizza, isEmpty);
  });

  test('requires first name, last name and plate to generate the QR', () {
    const incomplete = DriverPersonalQrData.empty();
    const complete = DriverPersonalQrData(
      courtesy: null,
      nome: 'Mario',
      cognome: 'Rossi',
      indirizzo: '',
      zip: '',
      city: '',
      country: '',
      telefono: '',
      email: '',
      targa: 'TI12345',
      marca: '',
      modello: '',
      vin: '',
      kilometraggio: '',
      primaImmatricolazione: '',
      assicurazione: '',
      numeroPolizza: '',
      numeroSinistro: '',
      customerNumber: '',
    );

    expect(incomplete.hasMinimumData, isFalse);
    expect(complete.hasMinimumData, isTrue);
  });
}
