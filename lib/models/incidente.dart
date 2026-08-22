class Testimone {
  final String nome;
  final String telefono;

  Testimone({
    required this.nome,
    required this.telefono,
  });

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'telefono': telefono,
      };

  factory Testimone.fromJson(Map<String, dynamic> json) {
    return Testimone(
      nome: json['nome'] ?? '',
      telefono: json['telefono'] ?? '',
    );
  }
}

class Ferito {
  final String nome;
  final String indirizzo;
  final String telefono;

  Ferito({
    required this.nome,
    required this.indirizzo,
    required this.telefono,
  });

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'indirizzo': indirizzo,
        'telefono': telefono,
      };

  factory Ferito.fromJson(Map<String, dynamic> json) {
    return Ferito(
      nome: json['nome'] ?? '',
      indirizzo: json['indirizzo'] ?? '',
      telefono: json['telefono'] ?? '',
    );
  }
}

class ConducenteAggiuntivo {
  const ConducenteAggiuntivo({
    required this.driverKey,
    required this.nome,
    required this.cognome,
    required this.targa,
    required this.assicurazione,
    this.marca = '',
    this.modello = '',
    this.vin = '',
    this.kilometraggio = '',
    this.primaImmatricolazione = '',
    this.numeroPolizza = '',
    this.numeroSinistro = '',
  });

  final String driverKey;
  final String nome;
  final String cognome;
  final String targa;
  final String assicurazione;
  final String marca;
  final String modello;
  final String vin;
  final String kilometraggio;
  final String primaImmatricolazione;
  final String numeroPolizza;
  final String numeroSinistro;

  Map<String, dynamic> toJson() => {
        'driverKey': driverKey,
        'nome': nome,
        'cognome': cognome,
        'targa': targa,
        'assicurazione': assicurazione,
        'marca': marca,
        'modello': modello,
        'vin': vin,
        'kilometraggio': kilometraggio,
        'primaImmatricolazione': primaImmatricolazione,
        'numeroPolizza': numeroPolizza,
        'numeroSinistro': numeroSinistro,
      };

  factory ConducenteAggiuntivo.fromJson(Map<String, dynamic> json) {
    String read(String key) => json[key]?.toString().trim() ?? '';
    return ConducenteAggiuntivo(
      driverKey: read('driverKey'),
      nome: read('nome'),
      cognome: read('cognome'),
      targa: read('targa'),
      assicurazione: read('assicurazione'),
      marca: read('marca'),
      modello: read('modello'),
      vin: read('vin'),
      kilometraggio: read('kilometraggio'),
      primaImmatricolazione: read('primaImmatricolazione'),
      numeroPolizza: read('numeroPolizza'),
      numeroSinistro: read('numeroSinistro'),
    );
  }
}

class FirmaResult {
  final String path;
  final String timestampUtcIso;

  FirmaResult({
    required this.path,
    required this.timestampUtcIso,
  });
}

class Incidente {
  final String id;
  final DateTime dataOra;
  final String luogo;

  final String nomeA;
  final String cognomeA;
  final String targaA;
  final String assicurazioneA;
  final String marcaA;
  final String modelloA;
  final String vinA;
  final String kilometraggioA;
  final String primaImmatricolazioneA;
  final String numeroPolizzaA;
  final String numeroSinistroA;

  final String telefonoA;
  final String emailA;
  final String indirizzoA;

  final String nomeB;
  final String cognomeB;
  final String targaB;
  final String assicurazioneB;
  final String marcaB;
  final String modelloB;
  final String vinB;
  final String kilometraggioB;
  final String primaImmatricolazioneB;
  final String numeroPolizzaB;
  final String numeroSinistroB;

  final String telefonoB;
  final String emailB;
  final String indirizzoB;

  final String descrizione;
  final String danniVeicoloA;
  final String danniVeicoloB;

  final List<Testimone> testimoni;
  final List<Ferito> feriti;
  final List<ConducenteAggiuntivo> conducentiAggiuntivi;

  final String notaVocaleA;
  final String notaVocaleB;
  final String notaAudioAPath;
  final String notaAudioBPath;

  final String fotoLibrettoA;
  final String fotoLibrettoB;
  final List<String> fotoDanni;

  final String firmaAPath;
  final String firmaBPath;

  final String timestampFirmaA;
  final String timestampFirmaB;

  final String colpevole;

  final String codiceOfficina;

  final String hashIntegrita;

  Incidente({
    required this.id,
    required this.dataOra,
    required this.luogo,
    required this.nomeA,
    required this.cognomeA,
    required this.targaA,
    required this.assicurazioneA,
    this.marcaA = '',
    this.modelloA = '',
    this.vinA = '',
    this.kilometraggioA = '',
    this.primaImmatricolazioneA = '',
    this.numeroPolizzaA = '',
    this.numeroSinistroA = '',
    required this.telefonoA,
    required this.emailA,
    required this.indirizzoA,
    required this.nomeB,
    required this.cognomeB,
    required this.targaB,
    required this.assicurazioneB,
    this.marcaB = '',
    this.modelloB = '',
    this.vinB = '',
    this.kilometraggioB = '',
    this.primaImmatricolazioneB = '',
    this.numeroPolizzaB = '',
    this.numeroSinistroB = '',
    required this.telefonoB,
    required this.emailB,
    required this.indirizzoB,
    required this.descrizione,
    required this.danniVeicoloA,
    required this.danniVeicoloB,
    required this.testimoni,
    required this.feriti,
    this.conducentiAggiuntivi = const [],
    required this.notaVocaleA,
    required this.notaVocaleB,
    required this.notaAudioAPath,
    required this.notaAudioBPath,
    required this.fotoLibrettoA,
    required this.fotoLibrettoB,
    required this.fotoDanni,
    required this.firmaAPath,
    required this.firmaBPath,
    required this.timestampFirmaA,
    required this.timestampFirmaB,
    required this.colpevole,
    required this.codiceOfficina,
    required this.hashIntegrita,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dataOra': dataOra.toIso8601String(),
        'luogo': luogo,
        'nomeA': nomeA,
        'cognomeA': cognomeA,
        'targaA': targaA,
        'marcaA': marcaA,
        'modelloA': modelloA,
        'vinA': vinA,
        'kilometraggioA': kilometraggioA,
        'primaImmatricolazioneA': primaImmatricolazioneA,
        'assicurazioneA': assicurazioneA,
        'numeroPolizzaA': numeroPolizzaA,
        'numeroSinistroA': numeroSinistroA,
        'telefonoA': telefonoA,
        'emailA': emailA,
        'indirizzoA': indirizzoA,
        'nomeB': nomeB,
        'cognomeB': cognomeB,
        'targaB': targaB,
        'marcaB': marcaB,
        'modelloB': modelloB,
        'vinB': vinB,
        'kilometraggioB': kilometraggioB,
        'primaImmatricolazioneB': primaImmatricolazioneB,
        'assicurazioneB': assicurazioneB,
        'numeroPolizzaB': numeroPolizzaB,
        'numeroSinistroB': numeroSinistroB,
        'telefonoB': telefonoB,
        'emailB': emailB,
        'indirizzoB': indirizzoB,
        'descrizione': descrizione,
        'danniVeicoloA': danniVeicoloA,
        'danniVeicoloB': danniVeicoloB,
        'testimoni': testimoni.map((t) => t.toJson()).toList(),
        'feriti': feriti.map((f) => f.toJson()).toList(),
        'conducentiAggiuntivi':
            conducentiAggiuntivi.map((driver) => driver.toJson()).toList(),
        'notaVocaleA': notaVocaleA,
        'notaVocaleB': notaVocaleB,
        'notaAudioAPath': notaAudioAPath,
        'notaAudioBPath': notaAudioBPath,
        'fotoLibrettoA': fotoLibrettoA,
        'fotoLibrettoB': fotoLibrettoB,
        'fotoDanni': fotoDanni,
        'firmaAPath': firmaAPath,
        'firmaBPath': firmaBPath,
        'timestampFirmaA': timestampFirmaA,
        'timestampFirmaB': timestampFirmaB,
        'colpevole': colpevole,
        'codiceOfficina': codiceOfficina,
        'hashIntegrita': hashIntegrita,
      };

  factory Incidente.fromJson(Map<String, dynamic> json) {
    List<Testimone> parsedTestimoni = [];
    if (json['testimoni'] is List) {
      parsedTestimoni = (json['testimoni'] as List)
          .map((e) => Testimone.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      final t1Nome = json['testimone1Nome'] ?? '';
      final t1Tel = json['testimone1Telefono'] ?? '';
      final t2Nome = json['testimone2Nome'] ?? '';
      final t2Tel = json['testimone2Telefono'] ?? '';
      if (t1Nome.toString().isNotEmpty || t1Tel.toString().isNotEmpty) {
        parsedTestimoni.add(
          Testimone(nome: t1Nome.toString(), telefono: t1Tel.toString()),
        );
      }
      if (t2Nome.toString().isNotEmpty || t2Tel.toString().isNotEmpty) {
        parsedTestimoni.add(
          Testimone(nome: t2Nome.toString(), telefono: t2Tel.toString()),
        );
      }
    }

    List<Ferito> parsedFeriti = [];
    if (json['feriti'] is List) {
      parsedFeriti = (json['feriti'] as List)
          .map((e) => Ferito.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final parsedDrivers = json['conducentiAggiuntivi'] is List
        ? (json['conducentiAggiuntivi'] as List)
            .whereType<Map>()
            .map((item) => ConducenteAggiuntivo.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : <ConducenteAggiuntivo>[];

    Map<String, dynamic> mapValue(Object? value) {
      return value is Map ? Map<String, dynamic>.from(value) : const {};
    }

    String firstValue(Iterable<Object?> values) {
      for (final value in values) {
        final normalized = value?.toString().trim() ?? '';
        if (normalized.isNotEmpty) return normalized;
      }
      return '';
    }

    final driverA = mapValue(json['driverA']);
    final driverB = mapValue(json['driverB']);
    final vehicleA = mapValue(driverA['vehicle']);
    final vehicleB = mapValue(driverB['vehicle']);
    final insuranceA = mapValue(driverA['insurance_details']);
    final insuranceB = mapValue(driverB['insurance_details']);

    return Incidente(
      id: json['id']?.toString() ?? '',
      dataOra: DateTime.tryParse(json['dataOra'] ?? '') ?? DateTime.now(),
      luogo: json['luogo'] ?? json['place'] ?? '',
      nomeA: json['nomeA'] ?? json['nome'] ?? '',
      cognomeA: json['cognomeA'] ?? '',
      targaA: firstValue(
        [json['targaA'], json['targa'], vehicleA['plate'], driverA['plate']],
      ),
      marcaA: firstValue([json['marcaA'], vehicleA['brand'], driverA['brand']]),
      modelloA:
          firstValue([json['modelloA'], vehicleA['model'], driverA['model']]),
      vinA: firstValue([json['vinA'], vehicleA['vin'], driverA['vin']]),
      kilometraggioA: firstValue(
        [json['kilometraggioA'], vehicleA['mileage'], driverA['mileage']],
      ),
      primaImmatricolazioneA: firstValue([
        json['primaImmatricolazioneA'],
        vehicleA['firstRegistration'],
        driverA['first_registration'],
      ]),
      assicurazioneA: firstValue([
        json['assicurazioneA'],
        insuranceA['company'],
        driverA['insurance'],
      ]),
      numeroPolizzaA: firstValue([
        json['numeroPolizzaA'],
        insuranceA['policyNumber'],
        driverA['policy_number'],
      ]),
      numeroSinistroA: firstValue([
        json['numeroSinistroA'],
        insuranceA['claimNumber'],
        driverA['claim_number'],
      ]),
      telefonoA: json['telefonoA'] ?? json['telefono'] ?? '',
      emailA: json['emailA'] ?? json['email'] ?? '',
      indirizzoA: json['indirizzoA'] ?? '',
      nomeB: json['nomeB'] ?? '',
      cognomeB: json['cognomeB'] ?? '',
      targaB: firstValue([json['targaB'], vehicleB['plate'], driverB['plate']]),
      marcaB: firstValue([json['marcaB'], vehicleB['brand'], driverB['brand']]),
      modelloB:
          firstValue([json['modelloB'], vehicleB['model'], driverB['model']]),
      vinB: firstValue([json['vinB'], vehicleB['vin'], driverB['vin']]),
      kilometraggioB: firstValue(
        [json['kilometraggioB'], vehicleB['mileage'], driverB['mileage']],
      ),
      primaImmatricolazioneB: firstValue([
        json['primaImmatricolazioneB'],
        vehicleB['firstRegistration'],
        driverB['first_registration'],
      ]),
      assicurazioneB: firstValue([
        json['assicurazioneB'],
        insuranceB['company'],
        driverB['insurance'],
      ]),
      numeroPolizzaB: firstValue([
        json['numeroPolizzaB'],
        insuranceB['policyNumber'],
        driverB['policy_number'],
      ]),
      numeroSinistroB: firstValue([
        json['numeroSinistroB'],
        insuranceB['claimNumber'],
        driverB['claim_number'],
      ]),
      telefonoB: json['telefonoB'] ?? '',
      emailB: json['emailB'] ?? '',
      indirizzoB: json['indirizzoB'] ?? '',
      descrizione: json['descrizione'] ?? json['description'] ?? '',
      danniVeicoloA: json['danniVeicoloA'] ?? '',
      danniVeicoloB: json['danniVeicoloB'] ?? '',
      testimoni: parsedTestimoni,
      feriti: parsedFeriti,
      conducentiAggiuntivi: parsedDrivers,
      notaVocaleA: json['notaVocaleA'] ?? '',
      notaVocaleB: json['notaVocaleB'] ?? '',
      notaAudioAPath: json['notaAudioAPath'] ?? '',
      notaAudioBPath: json['notaAudioBPath'] ?? '',
      fotoLibrettoA: json['fotoLibrettoA'] ?? '',
      fotoLibrettoB: json['fotoLibrettoB'] ?? '',
      fotoDanni: (json['fotoDanni'] is List)
          ? (json['fotoDanni'] as List).map((e) => e as String).toList()
          : <String>[],
      firmaAPath: json['firmaAPath'] ?? '',
      firmaBPath: json['firmaBPath'] ?? '',
      timestampFirmaA: json['timestampFirmaA'] ?? '',
      timestampFirmaB: json['timestampFirmaB'] ?? '',
      colpevole: json['colpevole'] ?? '',
      codiceOfficina: json['codiceOfficina'] ?? '',
      hashIntegrita: json['hashIntegrita'] ?? '',
    );
  }
}
