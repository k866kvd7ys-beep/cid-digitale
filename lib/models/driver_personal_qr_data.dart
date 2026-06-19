import 'dart:convert';

/// TODO: collegare questo modello allo scanner QR reale nello step successivo.
class DriverPersonalQrData {
  const DriverPersonalQrData({
    required this.nome,
    required this.cognome,
    required this.indirizzo,
    required this.zip,
    required this.city,
    required this.telefono,
    required this.email,
    required this.targa,
    required this.assicurazione,
  });

  const DriverPersonalQrData.empty()
      : nome = '',
        cognome = '',
        indirizzo = '',
        zip = '',
        city = '',
        telefono = '',
        email = '',
        targa = '',
        assicurazione = '';

  final String nome;
  final String cognome;
  final String indirizzo;
  final String zip;
  final String city;
  final String telefono;
  final String email;
  final String targa;
  final String assicurazione;

  bool get hasAnyValue => [
        nome,
        cognome,
        indirizzo,
        zip,
        city,
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
    String? nome,
    String? cognome,
    String? indirizzo,
    String? zip,
    String? city,
    String? telefono,
    String? email,
    String? targa,
    String? assicurazione,
  }) {
    return DriverPersonalQrData(
      nome: nome ?? this.nome,
      cognome: cognome ?? this.cognome,
      indirizzo: indirizzo ?? this.indirizzo,
      zip: zip ?? this.zip,
      city: city ?? this.city,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      targa: targa ?? this.targa,
      assicurazione: assicurazione ?? this.assicurazione,
    );
  }

  Map<String, dynamic> toMap() => {
        'nome': nome.trim(),
        'cognome': cognome.trim(),
        'indirizzo': indirizzo.trim(),
        'zip': zip.trim(),
        'city': city.trim(),
        'telefono': telefono.trim(),
        'email': email.trim(),
        'targa': targa.trim(),
        'assicurazione': assicurazione.trim(),
      };

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
      nome: readValue(const ['nome', 'firstName', 'vorname', 'prenom']),
      cognome: readValue(const ['cognome', 'lastName', 'nachname', 'nom']),
      indirizzo: readValue(
        const ['indirizzo', 'address', 'adresse', 'streetAddress'],
      ),
      zip: readValue(
        const ['zip', 'cap', 'plz', 'postalCode', 'zipCode', 'codePostal'],
      ),
      city: readValue(const ['city', 'citta', 'città', 'ort', 'ville']),
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
