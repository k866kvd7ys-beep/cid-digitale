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

    expect(payload['customer'], {
      'title': 'mr',
      'first_name': 'Mario',
      'last_name': 'Rossi',
      'email': 'mario@example.com',
      'phone': '+41 79 000 00 00',
      'street': 'Via Roma 12',
      'zip': '6900',
      'city': 'Lugano',
      'country': 'CH',
      'customer_number': '',
    });
    expect(payload['vehicle'], {
      'brand': 'Volkswagen',
      'model': 'Golf',
      'plate': 'TI12345',
      'vin': 'WVWZZZ1JZXW000001',
      'mileage': '65000',
      'year': '2021-05',
    });
    expect(payload['insurance'], {
      'insurance': 'AXA',
      'policy_nr': 'POL-2026-00124',
      'claim_nr': 'CLM-8842',
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
