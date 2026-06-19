import 'dart:convert';

/// TODO: collegare questo modello allo scanner QR reale nello step successivo.
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

class DriverPersonalQrData {
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
    required this.assicurazione,
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
        assicurazione = '';

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
  final String assicurazione;

  bool get hasMinimumData => nome.trim().isNotEmpty;

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
        assicurazione,
      ].any((value) => value.trim().isNotEmpty);

  String get fullName => [
        nome.trim(),
        cognome.trim(),
      ].where((value) => value.isNotEmpty).join(' ');

  DriverPersonalQrData copyWith({
    DriverPersonalQrCourtesy? courtesy,
    String? nome,
    String? cognome,
    String? indirizzo,
    String? zip,
    String? city,
    String? country,
    String? telefono,
    String? email,
    String? targa,
    String? assicurazione,
  }) {
    return DriverPersonalQrData(
      courtesy: courtesy ?? this.courtesy,
      nome: nome ?? this.nome,
      cognome: cognome ?? this.cognome,
      indirizzo: indirizzo ?? this.indirizzo,
      zip: zip ?? this.zip,
      city: city ?? this.city,
      country: country ?? this.country,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      targa: targa ?? this.targa,
      assicurazione: assicurazione ?? this.assicurazione,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nome': nome.trim(),
      'cognome': cognome.trim(),
      'indirizzo': indirizzo.trim(),
      'zip': zip.trim(),
      'city': city.trim(),
      'country': country.trim(),
      'telefono': telefono.trim(),
      'email': email.trim(),
      'targa': targa.trim(),
      'assicurazione': assicurazione.trim(),
    };
    final courtesyValue = courtesy?.storageValue;
    if (courtesyValue != null && courtesyValue.isNotEmpty) {
      map['courtesy'] = courtesyValue;
    }
    return map;
  }

  String toJsonString() => jsonEncode(toMap());

  factory DriverPersonalQrData.fromMap(Map<String, dynamic> map) {
    String readValue(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value == null) continue;
        final normalized = value.toString().trim();
        if (normalized.isNotEmpty) return normalized;
      }
      return '';
    }

    return DriverPersonalQrData(
      courtesy: driverPersonalQrCourtesyFromString(
        readValue(
          const ['courtesy', 'anrede', 'title', 'salutation', 'civilite'],
        ),
      ),
      nome: readValue(const ['nome', 'firstName', 'vorname', 'prenom']),
      cognome: readValue(const ['cognome', 'lastName', 'nachname', 'nom']),
      indirizzo: readValue(
        const ['indirizzo', 'address', 'adresse', 'streetAddress'],
      ),
      zip: readValue(
        const ['zip', 'cap', 'plz', 'postalCode', 'zipCode', 'codePostal'],
      ),
      city: readValue(const ['city', 'citta', 'città', 'ort', 'ville']),
      country: readValue(
        const ['country', 'land', 'paese', 'pays', 'nation', 'staat'],
      ),
      telefono: readValue(const ['telefono', 'phone', 'telefon', 'mobile']),
      email: readValue(const ['email', 'eMail', 'mail']),
      targa: readValue(
        const ['targa', 'licensePlate', 'plate', 'kennzeichen'],
      ),
      assicurazione: readValue(
        const [
          'assicurazione',
          'insurance',
          'versicherung',
          'assurance',
          'vehicleInsurance',
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
