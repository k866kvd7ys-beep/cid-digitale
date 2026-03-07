import 'package:flutter/material.dart';

class OcrLibrettoResult {
  final String path;
  final String? targa;
  final String? nome;
  final String? assicurazione;
  final String? indirizzo;
  final String? capCitta;

  OcrLibrettoResult({
    required this.path,
    this.targa,
    this.nome,
    this.assicurazione,
    this.indirizzo,
    this.capCitta,
  });
}

const _swissCantons = <String>{
  'AG',
  'AI',
  'AR',
  'BE',
  'BL',
  'BS',
  'FR',
  'GE',
  'GL',
  'GR',
  'JU',
  'LU',
  'NE',
  'NW',
  'OW',
  'SG',
  'SH',
  'SO',
  'SZ',
  'TG',
  'TI',
  'UR',
  'VD',
  'VS',
  'ZG',
  'ZH',
};

String _normalizeOcrText(String raw) {
  var text = raw.toUpperCase();
  text = text.replaceAll(RegExp(r'[^A-Z0-9À-ÿ\s]'), ' ');
  text = text.replaceAll('\n', ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

String? extractSwissPlate(String text) {
  if (text.isEmpty) return null;

  var cleaned = text.toUpperCase();
  cleaned = cleaned.replaceAll('\n', ' ');
  cleaned = cleaned.replaceAll(RegExp(r'[\-_:;.,/]'), ' ');
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  debugPrint('[OCR] Swiss plate input: '
      '${cleaned.length > 200 ? cleaned.substring(0, 200) : cleaned}');

  final chRegex =
      RegExp(r'\b([A-Z]{2})\s*([0-9]{1,3}(?:\s*[0-9]{1,3}){0,2})\b');
  for (final m in chRegex.allMatches(cleaned)) {
    final canton = m.group(1)!;
    final digitsRaw = m.group(2) ?? '';
    final digits = digitsRaw.replaceAll(' ', '');
    if (!_swissCantons.contains(canton)) continue;
    if (digits.isEmpty || digits.length > 6) continue;
    final plate = '$canton $digits';
    debugPrint(
        '[OCR] Swiss plate candidate: $canton | raw "$digitsRaw" -> "$plate"');
    return plate;
  }

  return null;
}

String? estraiTargaDaTesto(String rawText) {
  String? extractTargaItalia(String fullText) {
    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final re = RegExp(r'\b([A-Z]{2})\s*([0-9]{3})\s*([A-Z]{2})\b');
    bool hasMarker = false;

    for (final line in lines) {
      final up = line.toUpperCase();
      final marker =
          up.contains('(A') || up.contains('TARGA') || up.contains(' TARGA ');
      if (!marker) continue;
      hasMarker = true;
      final m = re.firstMatch(up);
      if (m != null) {
        return '${m.group(1)}${m.group(2)}${m.group(3)}';
      }
    }

    if (hasMarker) {
      final mGlobal = re.firstMatch(fullText.toUpperCase());
      if (mGlobal != null) {
        return '${mGlobal.group(1)}${mGlobal.group(2)}${mGlobal.group(3)}';
      }
    }
    return null;
  }

  final upperRaw = rawText.toUpperCase();
  final isItalian = upperRaw.contains('(A') ||
      upperRaw.contains('REPUBBLICA ITALIANA') ||
      upperRaw.contains('CARTA DI CIRCOLAZIONE') ||
      upperRaw.contains(' TARGA ');
  if (isItalian) {
    final targaIt = extractTargaItalia(rawText);
    if (targaIt != null) return targaIt;
  }

  String formatIt(String compact) {
    final m = RegExp(r'^([A-Z]{2})([0-9]{3})([A-Z]{2})$').firstMatch(compact);
    if (m != null) {
      return '${m.group(1)} ${m.group(2)} ${m.group(3)}';
    }
    return compact;
  }

  final normalized = _normalizeOcrText(rawText);

  final swissPlate = extractSwissPlate(normalized);
  if (swissPlate != null) return swissPlate;

  final itRegex = RegExp(r'\b([A-Z]{2})\s*([0-9]{3})\s*([A-Z]{2})\b');
  final itMatch = itRegex.firstMatch(normalized);
  if (itMatch != null) {
    final compact = '${itMatch.group(1)}${itMatch.group(2)}${itMatch.group(3)}';
    final cleaned = compact.replaceAll(' ', '');
    if (RegExp(r'^[A-Z]{2}[0-9]{3}[A-Z]{2}$').hasMatch(cleaned)) {
      return '${cleaned.substring(0, 2)} ${cleaned.substring(2, 5)} ${cleaned.substring(5)}';
    }
  }

  final chCompact = RegExp(r'\b([A-Z]{1,2})\s*([0-9]{6})\b');
  final chCompactMatch = chCompact.firstMatch(normalized);
  if (chCompactMatch != null) {
    final letters = chCompactMatch.group(1)!;
    final digits = chCompactMatch.group(2)!;
    return '$letters ${digits.substring(0, 3)} ${digits.substring(3)}';
  }

  final chSplit = RegExp(r'\b([A-Z]{1,2})\s*([0-9]{1,3})\s+([0-9]{2,3})\b');
  final chSplitMatch = chSplit.firstMatch(normalized);
  if (chSplitMatch != null) {
    final letters = chSplitMatch.group(1)!;
    final d1 = chSplitMatch.group(2)!;
    final d2 = chSplitMatch.group(3)!;
    return '$letters $d1$d2';
  }

  for (final token in normalized.split(' ')) {
    final t = token.trim();
    if (t.length < 5 || t.length > 8) continue;
    final letters = RegExp(r'[A-Z]').allMatches(t).length;
    final digits = RegExp(r'[0-9]').allMatches(t).length;
    if (letters >= 2 && digits >= 2) {
      final compact = t.replaceAll(' ', '');
      if (RegExp(r'^[A-Z]{2}[0-9]{3}[A-Z]{2}$').hasMatch(compact)) {
        return '${compact.substring(0, 2)} ${compact.substring(2, 5)} ${compact.substring(5)}';
      }
    }
  }

  return null;
}

Map<String, String?> estraiNomeAssicurazioneIndirizzoDaTesto(
  String rawText, {
  List<String> blocchi = const [],
}) {
  List<String> normalizeLines(String text) => text
      .split('\n')
      .map((l) => _normalizeOcrText(l))
      .where((l) => l.isNotEmpty)
      .toList();

  // Parse specifico libretto IT: campi (C.2.1), (C.2.2), (C.2.3)
  final rawLines = rawText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  String? nomeIta;
  String? indirizzoIta;
  String? capCittaIta;
  int? idxIndirizzoIta;

  String _cleanLabel(String line, String label) {
    return line
        .replaceFirst(
          RegExp('^\\s*\\(?${RegExp.escape(label)}\\)?\\s*[-:]?\\s*',
              caseSensitive: false),
          '',
        )
        .trim();
  }

  bool isCityProv(String line) {
    final trimmed = line.trim();
    final up = trimmed.toUpperCase();
    if (trimmed.startsWith('A '))
      return false; // evita “A CATANIA (CT)” (luogo di nascita)
    if (up.contains('NATO')) return false; // evita “NATO A ...”
    return RegExp(r"^[A-ZÀ-Ÿ' ]{2,}\s*\([A-Z]{2}\)$").hasMatch(trimmed);
  }

  bool isCapCityProv(String line) {
    return RegExp(r"^\d{5}\s+[A-ZÀ-Ÿ' ]{2,}(?:\s*\([A-Z]{2}\))?$")
        .hasMatch(line);
  }

  for (int i = 0; i < rawLines.length; i++) {
    final up = rawLines[i].toUpperCase();
    if (up.contains('C.2.1')) {
      final val = _cleanLabel(rawLines[i], 'C.2.1');
      if (val.isNotEmpty) {
        nomeIta = (nomeIta == null) ? val : '$nomeIta $val';
      }
    }
    if (up.contains('C.2.2')) {
      final val = _cleanLabel(rawLines[i], 'C.2.2');
      if (val.isNotEmpty) {
        nomeIta = (nomeIta == null) ? val : '$nomeIta $val';
      }
    }
    if (up.contains('C.2.3')) {
      final val = _cleanLabel(rawLines[i], 'C.2.3');
      if (val.isNotEmpty) {
        indirizzoIta = val;
        idxIndirizzoIta = i;
      }
    }
    if (isCityProv(up) || isCapCityProv(up)) {
      capCittaIta ??= rawLines[i];
    }
  }

  // Se non abbiamo città ma abbiamo l'indirizzo, prova la riga successiva
  if (capCittaIta == null && idxIndirizzoIta != null) {
    final nextIdx = idxIndirizzoIta! + 1;
    if (nextIdx < rawLines.length) {
      final upNext = rawLines[nextIdx].toUpperCase();
      if (isCityProv(upNext) || isCapCityProv(upNext)) {
        capCittaIta = rawLines[nextIdx];
      }
    }
  }

  // DO NOT MODIFY: valori attesi dal backend/app (non cambiare key o set)
  final possibiliAssicurazioni = <String>{
    'ALLIANZ',
    'AXA',
    'WINTERTHUR',
    'ZURICH',
    'ZÜRICH',
    'GENERALI',
    'BALOISE',
    'BASLER',
    'HELVETIA',
    'MOBILIAR',
    'ELVIA',
    'SWICA',
    'MOBILIERE',
    'LA MOBILIERE',
    'SWISS LIFE',
    'CONCORDIA',
    'CSS',
    'ZURICH CONNECT',
    'SUVA',
    'TCS',
    'NEON',
  };

  // DO NOT MODIFY: indicatori di via CH/FR/DE per l’indirizzo
  final paroleVia = <String>{
    'STRASSE',
    'STR.',
    'STR',
    'WEG',
    'GASSE',
    'PLATZ',
    'ALLEE',
    'RUE',
    'RUE.',
    'CHEMIN',
    'AVENUE',
    'AV.',
    'CHE.',
  };

  // Indicatori di via IT
  final paroleViaIt = <String>{
    'VIA',
    'V.LE',
    'VLE',
    'VIALE',
    'CORSO',
    'C.SO',
    'PIAZZA',
    'P.ZZA',
    'LARGO',
    'LGO',
    'STRADA',
    'STR.',
    'VICO',
    'CONTRADA',
  };

  String? extractTarga(String text) {
    final swiss = extractSwissPlate(text);
    if (swiss != null) return swiss;

    // DO NOT MODIFY: pattern targa CH “AG 399 854” o compatto 6 cifre
    final up = text.toUpperCase().replaceAll(RegExp(r'[-_:;.,/]'), ' ');
    final chSplit = RegExp(r'\b([A-Z]{1,2})\s+([0-9]{1,3})\s+([0-9]{2,3})\b');
    final match = chSplit.firstMatch(up);
    if (match != null) {
      return '${match.group(1)} ${match.group(2)} ${match.group(3)}';
    }
    final chCompact = RegExp(r'\b([A-Z]{1,2})\s*([0-9]{6})\b');
    final m2 = chCompact.firstMatch(up);
    if (m2 != null) {
      final letters = m2.group(1)!;
      final digits = m2.group(2)!;
      return '$letters ${digits.substring(0, 3)} ${digits.substring(3)}';
    }
    return null;
  }

  String? extractCapCitta(String line) {
    final cleaned = line.replaceAll(RegExp(r'[,:;]'), ' ').trim();
    final upLine = cleaned.toUpperCase();
    if (upLine.contains('NATO')) return null;
    if (cleaned.startsWith('A ')) return null;

    // CAP CH 4 cifre + città
    final mCh = RegExp(r"\b([1-9][0-9]{3})\s+([A-Za-zÀ-ÿ' -]{2,})\b")
        .firstMatch(cleaned);
    if (mCh != null) {
      final cap = mCh.group(1)!.trim();
      var city = mCh.group(2)!.trim();
      final normalizedCity =
          city.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
      if (cap == '5400' &&
          (normalizedCity == 'BADERN' || normalizedCity == 'BADRN')) {
        city = 'BADEN';
      }
      return '$cap $city'.trim();
    }

    // CAP IT 5 cifre + città
    final mIt =
        RegExp(r"\b([0-9]{5})\s+([A-Za-zÀ-ÿ' -]{2,})\b").firstMatch(cleaned);
    if (mIt != null) {
      final cap = mIt.group(1)!.trim();
      final city = mIt.group(2)!.trim();
      return '$cap $city'.trim();
    }

    // città seguita da CAP (es. MILANO 20100)
    final mCityCap =
        RegExp(r"\b([A-Za-zÀ-ÿ' -]{2,})\s+([0-9]{4,5})\b").firstMatch(cleaned);
    if (mCityCap != null) {
      final city = mCityCap.group(1)!.trim();
      final cap = mCityCap.group(2)!.trim();
      return '$cap $city'.trim();
    }

    // Solo città + provincia (senza CAP) per IT
    final mCityProv =
        RegExp(r"^[A-ZÀ-Ÿ' ]{2,}\s*\([A-Z]{2}\)\s*$").firstMatch(cleaned);
    if (mCityProv != null && !cleaned.startsWith('A ')) {
      return cleaned;
    }

    return null;
  }

  bool isIndirizzo(String line, String up) {
    final hasNumero = RegExp(r'\b[0-9]{1,4}\b').hasMatch(line);
    final hasTipoVia = paroleVia.any((v) => up.contains(v)) ||
        paroleViaIt.any((v) => up.contains(v));
    return hasNumero && hasTipoVia;
  }

  bool isAssicurazione(String up) =>
      possibiliAssicurazioni.any((k) => up.contains(k));

  final lines = <String>[
    ...normalizeLines(rawText),
    ...blocchi.expand((b) => normalizeLines(b)),
  ];

  String? nome;
  String? indirizzo;
  String? capCitta;
  String? assicurazione;
  String? targa;
  int? idxIndirizzo;
  int? idxCapCitta;

  // Preferisce dati IT se presenti
  if (nomeIta != null && nomeIta!.isNotEmpty) {
    nome = nomeIta;
  }
  if (indirizzoIta != null && indirizzoIta!.isNotEmpty) {
    indirizzo = indirizzoIta;
    idxIndirizzo = idxIndirizzoIta;
  }
  if (capCittaIta != null && capCittaIta!.isNotEmpty) {
    capCitta = capCittaIta;
  }

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final up = line.toUpperCase();

    targa ??= extractTarga(line);

    if (assicurazione == null && isAssicurazione(up)) {
      assicurazione = line;
    }

    capCitta ??= extractCapCitta(line);
    if (capCitta != null && idxCapCitta == null) {
      idxCapCitta = i;
    }

    if (indirizzo == null && isIndirizzo(line, up)) {
      indirizzo = line;
      idxIndirizzo = i;
    }
  }

  // Se indirizzo trovato ma capCitta mancante, prova sulle linee vicine
  if (idxIndirizzo != null && capCitta == null) {
    for (final j in [idxIndirizzo! + 1, idxIndirizzo! - 1]) {
      if (j >= 0 && j < lines.length) {
        final alt = extractCapCitta(lines[j]);
        if (alt != null) {
          capCitta = alt;
          break;
        }
      }
    }
  }

  if (nome == null) {
    // Tentativo primario: 1-2 linee prima dell’indirizzo (tipico layout CH)
    if (idxIndirizzo != null && idxIndirizzo! > 0) {
      final candidati = <String>[];
      for (int j = idxIndirizzo! - 2; j <= idxIndirizzo! - 1; j++) {
        if (j >= 0 && j < lines.length) {
          final l = lines[j];
          final up = l.toUpperCase();
          if (!RegExp(r'[0-9]').hasMatch(l) && !isAssicurazione(up)) {
            candidati.add(l);
          }
        }
      }
      if (candidati.isNotEmpty) {
        nome = candidati.join(' ').trim();
      }
    }

    if (nome == null) {
      // Se abbiamo CAP/città ma non indirizzo, usa la linea precedente come nome
      if (idxCapCitta != null && idxCapCitta! > 0) {
        final prev = lines[idxCapCitta! - 1];
        final upPrev = prev.toUpperCase();
        if (!RegExp(r'[0-9]').hasMatch(prev) && !isAssicurazione(upPrev)) {
          nome = prev;
        }
      }

      for (final l in lines) {
        final up = l.toUpperCase();
        if (!RegExp(r'[0-9]').hasMatch(l) &&
            l.length >= 3 &&
            !isAssicurazione(up)) {
          nome = l;
          break;
        }
      }
    }
  }

  // EDGE CASE: se il libretto ha più indirizzi (es. aziendale + sede), il parser
  // prenderà solo il primo che soddisfa il pattern; valutare gestione multipla in futuro.

  return {
    'nome': nome,
    'indirizzo': indirizzo,
    'capCitta': capCitta,
    'assicurazione': assicurazione,
    'targa': targa,
  };
}
