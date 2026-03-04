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

  final String telefonoA;
  final String emailA;
  final String indirizzoA;

  final String nomeB;
  final String cognomeB;
  final String targaB;
  final String assicurazioneB;

  final String telefonoB;
  final String emailB;
  final String indirizzoB;

  final String descrizione;
  final String danniVeicoloA;
  final String danniVeicoloB;

  final List<Testimone> testimoni;
  final List<Ferito> feriti;

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
    required this.telefonoA,
    required this.emailA,
    required this.indirizzoA,
    required this.nomeB,
    required this.cognomeB,
    required this.targaB,
    required this.assicurazioneB,
    required this.telefonoB,
    required this.emailB,
    required this.indirizzoB,
    required this.descrizione,
    required this.danniVeicoloA,
    required this.danniVeicoloB,
    required this.testimoni,
    required this.feriti,
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
        'assicurazioneA': assicurazioneA,
        'telefonoA': telefonoA,
        'emailA': emailA,
        'indirizzoA': indirizzoA,
        'nomeB': nomeB,
        'cognomeB': cognomeB,
        'targaB': targaB,
        'assicurazioneB': assicurazioneB,
        'telefonoB': telefonoB,
        'emailB': emailB,
        'indirizzoB': indirizzoB,
        'descrizione': descrizione,
        'danniVeicoloA': danniVeicoloA,
        'danniVeicoloB': danniVeicoloB,
        'testimoni': testimoni.map((t) => t.toJson()).toList(),
        'feriti': feriti.map((f) => f.toJson()).toList(),
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

    return Incidente(
      id: json['id']?.toString() ?? '',
      dataOra: DateTime.tryParse(json['dataOra'] ?? '') ?? DateTime.now(),
      luogo: json['luogo'] ?? json['place'] ?? '',
      nomeA: json['nomeA'] ?? json['nome'] ?? '',
      cognomeA: json['cognomeA'] ?? '',
      targaA: json['targaA'] ?? json['targa'] ?? '',
      assicurazioneA: json['assicurazioneA'] ?? '',
      telefonoA: json['telefonoA'] ?? json['telefono'] ?? '',
      emailA: json['emailA'] ?? json['email'] ?? '',
      indirizzoA: json['indirizzoA'] ?? '',
      nomeB: json['nomeB'] ?? '',
      cognomeB: json['cognomeB'] ?? '',
      targaB: json['targaB'] ?? '',
      assicurazioneB: json['assicurazioneB'] ?? '',
      telefonoB: json['telefonoB'] ?? '',
      emailB: json['emailB'] ?? '',
      indirizzoB: json['indirizzoB'] ?? '',
      descrizione: json['descrizione'] ?? json['description'] ?? '',
      danniVeicoloA: json['danniVeicoloA'] ?? '',
      danniVeicoloB: json['danniVeicoloB'] ?? '',
      testimoni: parsedTestimoni,
      feriti: parsedFeriti,
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
