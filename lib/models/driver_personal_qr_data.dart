import 'dart:convert';

enum DriverPersonalQrCourtesy {
  mr('mr'),
  mrs('mrs'),
  company('company');

  const DriverPersonalQrCourtesy(this.storageValue);

  final String storageValue;
}

DriverPersonalQrCourtesy? driverPersonalQrCourtesyFromString(String? raw) {
  final normalized = raw?.trim().toLowerCase() ?? '';
  switch (normalized) {
    case 'mr':
    case 'herr':
    case 'signor':
    case 'monsieur':
      return DriverPersonalQrCourtesy.mr;
    case 'mrs':
    case 'frau':
    case 'signora':
    case 'madame':
      return DriverPersonalQrCourtesy.mrs;
    case 'company':
    case 'firma':
    case 'ditta':
    case 'societe':
    case 'société':
      return DriverPersonalQrCourtesy.company;
    default:
      return null;
  }
}

enum DriverPersonalQrImportRole {
  customerDriver('customer_driver'),
  witness('witness'),
  injured('injured');

  const DriverPersonalQrImportRole(this.payloadValue);

  final String payloadValue;
}

class DriverPersonalQrData {
  static const String qrType = 'CID_PERSON_QR';
  static const int qrVersion = 1;
  static const Object _unset = Object();

  const DriverPersonalQrData({
    this.courtesy,
    required this.nome,
    required this.cognome,
    required this.indirizzo,
    required this.zip,
    required this.city,
    required this.country,
    required this.telefono,
    required this.email,
    required this.targa,
    required this.marca,
    required this.modello,
    required this.vin,
    required this.kilometraggio,
    required this.primaImmatricolazione,
    required this.assicurazione,
    required this.numeroPolizza,
    required this.numeroSinistro,
    required this.customerNumber,
  });

  const DriverPersonalQrData.empty()
      : courtesy = null,
        nome = '',
        cognome = '',
        indirizzo = '',
        zip = '',
        city = '',
        country = '',
        telefono = '',
        email = '',
        targa = '',
        marca = '',
        modello = '',
        vin = '',
        kilometraggio = '',
        primaImmatricolazione = '',
        assicurazione = '',
        numeroPolizza = '',
        numeroSinistro = '',
        customerNumber = '';

  final DriverPersonalQrCourtesy? courtesy;
  final String nome;
  final String cognome;
  final String indirizzo;
  final String zip;
  final String city;
  final String country;
  final String telefono;
  final String email;
  final String targa;
  final String marca;
  final String modello;
  final String vin;
  final String kilometraggio;
  final String primaImmatricolazione;
  final String assicurazione;
  final String numeroPolizza;
  final String numeroSinistro;
  final String customerNumber;

  bool get hasMinimumData =>
      nome.trim().isNotEmpty &&
      cognome.trim().isNotEmpty &&
      targa.trim().isNotEmpty;

  bool get hasAnyValue => [
        courtesy?.storageValue ?? '',
        nome,
        cognome,
        indirizzo,
        zip,
        city,
        country,
        telefono,
        email,
        targa,
        marca,
        modello,
        vin,
        kilometraggio,
        primaImmatricolazione,
        assicurazione,
        numeroPolizza,
        numeroSinistro,
        customerNumber,
      ].any((value) => value.trim().isNotEmpty);

  String get fullName => [
        nome.trim(),
        cognome.trim(),
      ].where((value) => value.isNotEmpty).join(' ');

  String get vehicleSummary => [
        marca.trim(),
        modello.trim(),
      ].where((value) => value.isNotEmpty).join(' ');

  String get insuranceSummary => [
        assicurazione.trim(),
        numeroPolizza.trim(),
      ].where((value) => value.isNotEmpty).join(' · ');

  List<String> get supportedRoles => DriverPersonalQrImportRole.values
      .map((role) => role.payloadValue)
      .toList(growable: false);

  DriverPersonalQrData scopedForImportRole(
    DriverPersonalQrImportRole role, {
    bool includeEmail = false,
  }) {
    switch (role) {
      case DriverPersonalQrImportRole.customerDriver:
        return this;
      case DriverPersonalQrImportRole.witness:
      case DriverPersonalQrImportRole.injured:
        return copyWith(
          courtesy: null,
          email: includeEmail ? email : '',
          targa: '',
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
    }
  }

  DriverPersonalQrData copyWith({
    Object? courtesy = _unset,
    String? nome,
    String? cognome,
    String? indirizzo,
    String? zip,
    String? city,
    String? country,
    String? telefono,
    String? email,
    String? targa,
    String? marca,
    String? modello,
    String? vin,
    String? kilometraggio,
    String? primaImmatricolazione,
    String? assicurazione,
    String? numeroPolizza,
    String? numeroSinistro,
    String? customerNumber,
  }) {
    return DriverPersonalQrData(
      courtesy: identical(courtesy, _unset)
          ? this.courtesy
          : courtesy as DriverPersonalQrCourtesy?,
      nome: nome ?? this.nome,
      cognome: cognome ?? this.cognome,
      indirizzo: indirizzo ?? this.indirizzo,
      zip: zip ?? this.zip,
      city: city ?? this.city,
      country: country ?? this.country,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      targa: targa ?? this.targa,
      marca: marca ?? this.marca,
      modello: modello ?? this.modello,
      vin: vin ?? this.vin,
      kilometraggio: kilometraggio ?? this.kilometraggio,
      primaImmatricolazione:
          primaImmatricolazione ?? this.primaImmatricolazione,
      assicurazione: assicurazione ?? this.assicurazione,
      numeroPolizza: numeroPolizza ?? this.numeroPolizza,
      numeroSinistro: numeroSinistro ?? this.numeroSinistro,
      customerNumber: customerNumber ?? this.customerNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': qrType,
      'version': qrVersion,
      'roles': supportedRoles,
      'person': <String, dynamic>{
        'title': courtesy?.storageValue ?? '',
        'firstName': nome.trim(),
        'lastName': cognome.trim(),
        'email': email.trim(),
        'phone': telefono.trim(),
        'street': indirizzo.trim(),
        'zip': zip.trim(),
        'city': city.trim(),
        'country': country.trim(),
      },
      'vehicle': <String, dynamic>{
        'brand': marca.trim(),
        'model': modello.trim(),
        'plate': targa.trim(),
        'vin': vin.trim(),
        'mileage': kilometraggio.trim(),
        'firstRegistration': primaImmatricolazione.trim(),
      },
      'insurance': <String, dynamic>{
        'company': assicurazione.trim(),
        'policyNumber': numeroPolizza.trim(),
        'claimNumber': numeroSinistro.trim(),
      },
    };
  }

  String toJsonString() => jsonEncode(toMap());

  factory DriverPersonalQrData.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> readSection(String key) {
      final raw = map[key];
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return const <String, dynamic>{};
    }

    final person = readSection('person');
    final customer = readSection('customer');
    final vehicle = readSection('vehicle');
    final insurance = readSection('insurance');
    final sources = <Map<String, dynamic>>[
      person,
      customer,
      vehicle,
      insurance,
      map,
    ];

    String readValue(List<String> keys) {
      for (final source in sources) {
        for (final key in keys) {
          final value = source[key];
          if (value == null) continue;
          final normalized = value.toString().trim();
          if (normalized.isNotEmpty) return normalized;
        }
      }
      return '';
    }

    return DriverPersonalQrData(
      courtesy: driverPersonalQrCourtesyFromString(
        readValue(
          const [
            'courtesy',
            'anrede',
            'title',
            'salutation',
            'civilite',
            'civilité',
          ],
        ),
      ),
      nome: readValue(
        const [
          'nome',
          'first_name',
          'firstName',
          'vorname',
          'prenom',
        ],
      ),
      cognome: readValue(
        const ['cognome', 'last_name', 'lastName', 'nachname', 'nom'],
      ),
      indirizzo: readValue(
        const [
          'indirizzo',
          'street',
          'address',
          'adresse',
          'streetAddress',
          'street_address',
        ],
      ),
      zip: readValue(
        const [
          'zip',
          'cap',
          'plz',
          'postalCode',
          'zipCode',
          'postal_code',
          'codePostal',
        ],
      ),
      city: readValue(const ['city', 'citta', 'città', 'ort', 'ville']),
      country: readValue(
        const ['country', 'land', 'paese', 'pays', 'nation', 'staat'],
      ),
      telefono: readValue(const ['telefono', 'phone', 'telefon', 'mobile']),
      email: readValue(const ['email', 'eMail', 'mail']),
      targa: readValue(
        const [
          'targa',
          'licensePlate',
          'license_plate',
          'plate',
          'kennzeichen',
        ],
      ),
      marca: readValue(const ['brand', 'marca', 'make']),
      modello: readValue(const ['model', 'modello', 'tipo', 'type']),
      vin: readValue(
        const ['vin', 'telaio', 'numero_telaio', 'numeroTelaio', 'chassis'],
      ),
      kilometraggio: readValue(
        const ['mileage', 'kilometraggio', 'kilometer', 'km', 'odometer'],
      ),
      primaImmatricolazione: readValue(
        const [
          'year',
          'first_registration',
          'firstRegistration',
          'prima_immatricolazione',
          'primaImmatricolazione',
          'immatricolazione',
        ],
      ),
      assicurazione: readValue(
        const [
          'company',
          'assicurazione',
          'insurance',
          'versicherung',
          'assurance',
          'vehicleInsurance',
        ],
      ),
      numeroPolizza: readValue(
        const [
          'policyNumber',
          'policy_nr',
          'policy_number',
          'numero_polizza',
          'numeroPolizza',
          'polizza',
        ],
      ),
      numeroSinistro: readValue(
        const [
          'claimNumber',
          'claim_nr',
          'claim_number',
          'numero_sinistro',
          'numeroSinistro',
          'sinistro',
        ],
      ),
      customerNumber: readValue(
        const [
          'customer_number',
          'customerNumber',
          'numero_cliente',
          'numeroCliente',
          'kundennummer',
        ],
      ),
    );
  }

  factory DriverPersonalQrData.fromJsonString(String source) {
    if (source.trim().isEmpty) {
      return const DriverPersonalQrData.empty();
    }

    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return DriverPersonalQrData.fromMap(decoded);
      }
      if (decoded is Map) {
        return DriverPersonalQrData.fromMap(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      return const DriverPersonalQrData.empty();
    }

    return const DriverPersonalQrData.empty();
  }
}

Map<String, dynamic> driverPersonalQrDataToMap(DriverPersonalQrData data) {
  return data.toMap();
}

String driverPersonalQrDataToJson(DriverPersonalQrData data) {
  return data.toJsonString();
}

DriverPersonalQrData driverPersonalQrDataFromMap(Map<String, dynamic> map) {
  return DriverPersonalQrData.fromMap(map);
}

DriverPersonalQrData driverPersonalQrDataFromJson(String source) {
  return DriverPersonalQrData.fromJsonString(source);
}

DriverPersonalQrData? driverPersonalQrDataFromQrPayload(String source) {
  if (source.trim().isEmpty) return null;

  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    final data = DriverPersonalQrData.fromMap(map);
    if (!data.hasAnyValue) return null;
    return data;
  } catch (_) {
    return null;
  }
}
