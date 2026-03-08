import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ocr_utils.dart';
import 'scanner_libretto_page.dart';
import 'config/supabase_config.dart';
import 'screens/officina/appointments_screen.dart';
import 'screens/service/raeder_wechsel_screen.dart';
import 'screens/service/workshop_slot_picker_screen.dart';
import 'services/supabase_service.dart';
import 'services/incidents_sync_service.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'qr/qr_payload.dart';
import 'package:cid_digitale/widgets/damage_type_picker_sheet.dart';
import 'package:cid_digitale/widgets/quick_action_tile.dart';
import 'widgets/auth/auth_gate.dart';
import 'screens/my_requests_page.dart';
import 'package:crypto/crypto.dart';
import 'web_ocr_stub.dart' if (dart.library.html) 'web_ocr_html.dart';

class NominatimSuggestion {
  final String displayName;
  final double lat;
  final double lon;

  NominatimSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory NominatimSuggestion.fromJson(Map<String, dynamic> json) {
    return NominatimSuggestion(
      displayName: (json['display_name'] as String?) ?? '',
      lat: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      lon: double.tryParse(json['lon']?.toString() ?? '') ?? 0,
    );
  }
}

class _CloudOcrResult {
  final bool success;
  final String? text;
  final String? error;
  final String? details;
  final int? status;
  final dynamic raw;
  final List<_OcrBlock> blocks;

  _CloudOcrResult({
    required this.success,
    this.text,
    this.error,
    this.details,
    this.status,
    this.raw,
    this.blocks = const [],
  });
}

class _OcrBlock {
  final String text;
  final double x;
  final double y;
  final double w;
  final double h;
  final double nx;
  final double ny;

  _OcrBlock({
    required this.text,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.nx,
    required this.ny,
  });
}

bool _isPlausibleName(String? v) =>
    v != null &&
    v.trim().length >= 2 &&
    RegExp(r"^[A-Za-zÀ-ÿ'\-\s]{2,}$").hasMatch(v) &&
    !RegExp(r'\d').hasMatch(v);

bool _isPlausibleAddress(String? v) =>
    v != null &&
    v.trim().length >= 5 &&
    RegExp(r'\d').hasMatch(v) &&
    RegExp(r'[A-Za-z]').hasMatch(v);

bool _isPlausibleCity(String? v) =>
    v != null &&
    v.trim().length >= 2 &&
    RegExp(r'^[A-Za-zÀ-ÿ\s\-]{2,}$').hasMatch(v) &&
    !RegExp(r'PERSONENWAGEN|LIMOUSINE|FAHRZEUG', caseSensitive: false)
        .hasMatch(v);

bool _isPlausibleInsurance(String? v) =>
    v != null && v.trim().length >= 3 && RegExp(r'[A-Za-z]').hasMatch(v);

bool _isPlausibleZip(String? v) =>
    v != null && RegExp(r'^\d{4}$').hasMatch(v.trim());

/// CONFIG OFFICINA //////////////////////////////////////////////////////

class OfficinaConfig {
  final String carroNumero;
  final String concessionariaNumero;
  final String concessionariaEmail;

  OfficinaConfig({
    required this.carroNumero,
    required this.concessionariaNumero,
    required this.concessionariaEmail,
  });

  factory OfficinaConfig.empty() => OfficinaConfig(
        carroNumero: '',
        concessionariaNumero: '',
        concessionariaEmail: '',
      );

  Map<String, dynamic> toJson() => {
        'carroNumero': carroNumero,
        'concessionariaNumero': concessionariaNumero,
        'concessionariaEmail': concessionariaEmail,
      };

  factory OfficinaConfig.fromJson(Map<String, dynamic> json) {
    return OfficinaConfig(
      carroNumero: json['carroNumero'] ?? '',
      concessionariaNumero: json['concessionariaNumero'] ?? '',
      concessionariaEmail: json['concessionariaEmail'] ?? '',
    );
  }
}

OfficinaConfig configOfficina = OfficinaConfig.empty();

Future<void> caricaConfigOfficina() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('config_officina');
  if (stored != null) {
    configOfficina = OfficinaConfig.fromJson(jsonDecode(stored));
  }
}

Future<void> salvaConfigOfficina() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'config_officina',
    jsonEncode(configOfficina.toJson()),
  );
}

/// ✅ MODELLO TESTIMONE

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

/// ✅ MODELLO FERITO
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

/// ✅ RESULT FIRMA (STEP C: timestamp firma)
class FirmaResult {
  final String path;
  final String timestampUtcIso;

  FirmaResult({
    required this.path,
    required this.timestampUtcIso,
  });
}

/// ✅ MODELLO INCIDENTE

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
  final String zipA;
  final String cityA;

  final String nomeB;
  final String cognomeB;
  final String targaB;
  final String assicurazioneB;

  final String telefonoB;
  final String emailB;
  final String indirizzoB;
  final String zipB;
  final String cityB;

  final String descrizione;
  final String danniVeicoloA;
  final String danniVeicoloB;
  final bool? otherObjectDamage;
  final bool? otherVehicleDamage;

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

  /// ✅ STEP C: timestamp firma A/B (ISO UTC)
  final String timestampFirmaA;
  final String timestampFirmaB;

  final String colpevole;

  final String codiceOfficina;

  /// Impronta di integrità (SHA-256) dei dati e allegati
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
    required this.zipA,
    required this.cityA,
    required this.nomeB,
    required this.cognomeB,
    required this.targaB,
    required this.assicurazioneB,
    required this.telefonoB,
    required this.emailB,
    required this.indirizzoB,
    required this.zipB,
    required this.cityB,
    required this.descrizione,
    required this.danniVeicoloA,
    required this.danniVeicoloB,
    required this.otherObjectDamage,
    required this.otherVehicleDamage,
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
        'zipA': zipA,
        'cityA': cityA,
        'nomeB': nomeB,
        'cognomeB': cognomeB,
        'targaB': targaB,
        'assicurazioneB': assicurazioneB,
        'telefonoB': telefonoB,
        'emailB': emailB,
        'indirizzoB': indirizzoB,
        'zipB': zipB,
        'cityB': cityB,
        'descrizione': descrizione,
        'danniVeicoloA': danniVeicoloA,
        'danniVeicoloB': danniVeicoloB,
        'otherObjectDamage': otherObjectDamage,
        'otherVehicleDamage': otherVehicleDamage,
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
    // ✅ compatibilità con vecchia versione (testimone1/2)
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
      luogo: json['luogo'] ?? '',
      nomeA: json['nomeA'] ?? '',
      cognomeA: json['cognomeA'] ?? '',
      targaA: json['targaA'] ?? '',
      assicurazioneA: json['assicurazioneA'] ?? '',
      telefonoA: json['telefonoA'] ?? '',
      emailA: json['emailA'] ?? '',
      indirizzoA: json['indirizzoA'] ?? '',
      zipA: json['zipA'] ?? '',
      cityA: json['cityA'] ?? '',
      nomeB: json['nomeB'] ?? '',
      cognomeB: json['cognomeB'] ?? '',
      targaB: json['targaB'] ?? '',
      assicurazioneB: json['assicurazioneB'] ?? '',
      telefonoB: json['telefonoB'] ?? '',
      emailB: json['emailB'] ?? '',
      indirizzoB: json['indirizzoB'] ?? '',
      zipB: json['zipB'] ?? '',
      cityB: json['cityB'] ?? '',
      descrizione: json['descrizione'] ?? '',
      danniVeicoloA: json['danniVeicoloA'] ?? '',
      danniVeicoloB: json['danniVeicoloB'] ?? '',
      otherObjectDamage: json['otherObjectDamage'] is bool
          ? json['otherObjectDamage'] as bool
          : null,
      otherVehicleDamage: json['otherVehicleDamage'] is bool
          ? json['otherVehicleDamage'] as bool
          : null,
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

/// STORAGE /////////////////////////////////////////////////////////////

List<Incidente> incidentiSalvati = [];

Future<void> caricaIncidenti() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('incidenti');
  if (stored == null) {
    incidentiSalvati = [];
    return;
  }

  try {
    final decoded = jsonDecode(stored);
    if (decoded is List) {
      final List<Incidente> parsed = [];
      bool changed = false;

      for (final e in decoded) {
        if (e is! Map) continue;
        final inc = Incidente.fromJson(Map<String, dynamic>.from(e as Map));

        if (inc.hashIntegrita.isEmpty) {
          parsed.add(await aggiornaHashIncidente(inc));
          changed = true;
        } else {
          parsed.add(inc);
        }
      }

      incidentiSalvati = parsed;
      if (changed) {
        await salvaIncidenti();
      }
    } else {
      incidentiSalvati = [];
    }
  } catch (_) {
    incidentiSalvati = [];
  }
}

Future<void> salvaIncidenti() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'incidenti',
    jsonEncode(incidentiSalvati.map((e) => e.toJson()).toList()),
  );
}

Future<String> calcolaHashIntegrita(Incidente inc) async {
  final data = Map<String, dynamic>.from(inc.toJson());
  data.remove('hashIntegrita');

  final collector = _DigestCollector();
  final digestInput = sha256.startChunkedConversion(collector);

  // Hash dei dati strutturati
  digestInput.add(utf8.encode(jsonEncode(data)));

  final allegati = <String>[
    inc.firmaAPath,
    inc.firmaBPath,
    inc.fotoLibrettoA,
    inc.fotoLibrettoB,
    ...inc.fotoDanni,
    inc.notaAudioAPath,
    inc.notaAudioBPath,
  ];

  for (final path in allegati) {
    if (path.isEmpty) continue;
    final file = File(path);
    if (!await file.exists()) continue;
    try {
      // Lettura chunk per evitare OOM con molti allegati
      await for (final chunk in file.openRead()) {
        digestInput.add(chunk);
      }
    } catch (_) {
      // Se il file non è leggibile, lo saltiamo per non bloccare il salvataggio
      continue;
    }
  }

  digestInput.close();
  return collector.value?.toString() ?? '';
}

class _DigestCollector implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

Future<Incidente> aggiornaHashIncidente(Incidente inc) async {
  final hash = await calcolaHashIntegrita(inc);
  return Incidente(
    id: inc.id,
    dataOra: inc.dataOra,
    luogo: inc.luogo,
    nomeA: inc.nomeA,
    cognomeA: inc.cognomeA,
    targaA: inc.targaA,
    assicurazioneA: inc.assicurazioneA,
    telefonoA: inc.telefonoA,
    emailA: inc.emailA,
    indirizzoA: inc.indirizzoA,
    zipA: inc.zipA,
    cityA: inc.cityA,
    nomeB: inc.nomeB,
    cognomeB: inc.cognomeB,
    targaB: inc.targaB,
    assicurazioneB: inc.assicurazioneB,
    telefonoB: inc.telefonoB,
    emailB: inc.emailB,
    indirizzoB: inc.indirizzoB,
    zipB: inc.zipB,
    cityB: inc.cityB,
    descrizione: inc.descrizione,
    danniVeicoloA: inc.danniVeicoloA,
    danniVeicoloB: inc.danniVeicoloB,
    otherObjectDamage: inc.otherObjectDamage,
    otherVehicleDamage: inc.otherVehicleDamage,
    testimoni: inc.testimoni,
    feriti: inc.feriti,
    notaVocaleA: inc.notaVocaleA,
    notaVocaleB: inc.notaVocaleB,
    notaAudioAPath: inc.notaAudioAPath,
    notaAudioBPath: inc.notaAudioBPath,
    fotoLibrettoA: inc.fotoLibrettoA,
    fotoLibrettoB: inc.fotoLibrettoB,
    fotoDanni: inc.fotoDanni,
    firmaAPath: inc.firmaAPath,
    firmaBPath: inc.firmaBPath,
    timestampFirmaA: inc.timestampFirmaA,
    timestampFirmaB: inc.timestampFirmaB,
    colpevole: inc.colpevole,
    codiceOfficina: inc.codiceOfficina,
    hashIntegrita: hash,
  );
}

// Cache e helper per la generazione del QR CLIENTE (CID1:<token>).
final Map<String, Future<String>> _clientQrTokenCache = {};
final Map<String, Future<String>> _claimUuidCache = {};

Future<String> _ensureClaimUuid(Incidente inc) {
  // Usa cache per non creare più volte la stessa pratica durante la sessione.
  final cached = _claimUuidCache[inc.id];
  if (cached != null) return cached;

  final future = () async {
    final service = SupabaseService();
    final claimUuid = (await service.rpcCreateClaimDraft(
      workshopCode: inc.codiceOfficina,
      payload: inc.toJson(),
    ))
        .toString()
        .trim();

    if (!QrPayload.looksLikeUuid(claimUuid)) {
      throw Exception(
          'RPC create_claim_draft ha restituito un id non UUID: $claimUuid');
    }
    return claimUuid;
  }();

  _claimUuidCache[inc.id] = future;
  return future;
}

Future<String> _ensureClientQrToken(
  Incidente inc, {
  Duration expiresIn = const Duration(days: 30),
  int maxUses = 5,
}) async {
  final claimUuid = await _ensureClaimUuid(inc);
  final cacheKey = claimUuid;
  SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    throw Exception(
        'Supabase non inizializzato: controlla Supabase.initialize/chiavi.');
  }
  final now = DateTime.now().toUtc();
  final expiresAtIso = now.add(expiresIn).toIso8601String();

  await client.from('claims').update({
    'payload_json': inc.toJson(),
    'workshop_code': inc.codiceOfficina,
    'hashed_token': inc.hashIntegrita,
  }).eq('id', claimUuid);

  final future = _clientQrTokenCache.putIfAbsent(cacheKey, () async {
    final existing = await client
        .from('claim_links')
        .select('token, expires_at, used_count, max_uses')
        .eq('claim_id', claimUuid)
        .eq('purpose', 'client')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      final token = (existing['token'] as String?)?.trim() ?? '';
      final usedCount = int.tryParse('${existing['used_count'] ?? '0'}') ?? 0;
      final maxUsesExisting =
          int.tryParse('${existing['max_uses'] ?? maxUses}') ?? maxUses;
      final expiresExistingStr = existing['expires_at']?.toString();
      final expiresExisting = expiresExistingStr != null
          ? DateTime.tryParse(expiresExistingStr)
          : null;
      final expired = expiresExisting != null && expiresExisting.isBefore(now);
      final exhausted = maxUsesExisting > 0 && usedCount >= maxUsesExisting;
      if (token.isNotEmpty &&
          !expired &&
          !exhausted &&
          QrPayload.looksLikeToken(token)) {
        await client.from('claim_links').upsert(
          {
            'token': token,
            'claim_id': inc.id,
            'purpose': 'client',
            'expires_at': expiresAtIso,
            'max_uses': maxUsesExisting,
          },
          onConflict: 'token',
        );
        return token;
      }
    }

    final insertRes = await client
        .from('claim_links')
        .insert({
          'claim_id': claimUuid,
          'purpose': 'client',
          'expires_at': expiresAtIso,
          'max_uses': maxUses,
        })
        .select('token')
        .single();

    final token = (insertRes['token'] as String?)?.trim() ?? '';
    if (token.isEmpty) {
      throw Exception('Token claim_links vuoto.');
    }
    if (!QrPayload.looksLikeToken(token)) {
      final preview = token.length > 12 ? token.substring(0, 12) : token;
      throw Exception(
          'Token QR client non valido (atteso hex, ricevuto: $preview)');
    }
    return token;
  });

  final token = await future;

  QrPayload.debugLog(token);

  await client.from('claim_links').upsert(
    {
      'token': token,
      'claim_id': claimUuid,
      'purpose': 'client',
      'expires_at': expiresAtIso,
      'max_uses': maxUses,
    },
    onConflict: 'token',
  );

  return token;
}

Future<String> buildClientQrData(Incidente inc) async {
  final token = await _ensureClientQrToken(inc);
  return QrPayload.cid1(token);
}

/// GPS /////////////////////////////////////////////////////////////

Future<Position?> getPosizioneConPermessi() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  try {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(const Duration(seconds: 12));
  } on TimeoutException {
    return null;
  }
}

Future<String?> getIndirizzoDaGps({Position? position}) async {
  final pos = position ?? await getPosizioneConPermessi();
  if (pos == null) return null;

  final placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);

  if (placemarks.isEmpty) return null;

  final p = placemarks.first;
  return "${p.street}, ${p.locality}";
}

/// ✅ LINGUA MANUALE

const _supportedLangs = <String>['it', 'de', 'fr', 'en'];

Locale _localeFromCode(String code) {
  if (_supportedLangs.contains(code)) return Locale(code);
  return const Locale('de');
}

Future<Locale> caricaLinguaPreferita() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('lang_preference');
  if (saved != null && _supportedLangs.contains(saved)) {
    return Locale(saved);
  }
  // Usa la lingua di sistema se supportata, altrimenti italiano
  final systemCode =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  if (_supportedLangs.contains(systemCode)) {
    return Locale(systemCode);
  }
  return const Locale('de');
}

Future<void> salvaLinguaPreferita(String code) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('lang_preference', code);
}

ValueNotifier<Locale> linguaSelezionata =
    ValueNotifier<Locale>(const Locale('de'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }
  await caricaIncidenti();
  await caricaConfigOfficina();
  linguaSelezionata.value = await caricaLinguaPreferita();
  runApp(const CidDigitaleApp());
}

class CidDigitaleApp extends StatelessWidget {
  const CidDigitaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: linguaSelezionata,
      builder: (context, locale, _) {
        return MaterialApp(
          key: ValueKey('locale_${locale.languageCode}'),
          debugShowCheckedModeBanner: false,
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: (locales, supported) {
            // Se abbiamo già scelto manualmente, usa quella scelta.
            if (_supportedLangs.contains(locale.languageCode)) {
              return locale;
            }
            // Altrimenti prova a usare la prima lingua di sistema supportata.
            final systemCode = locales?.first.languageCode;
            if (systemCode != null && _supportedLangs.contains(systemCode)) {
              return Locale(systemCode);
            }
            return const Locale('de');
          },
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFE3F2FD),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFE3F2FD),
              foregroundColor: Colors.black,
              centerTitle: true,
              elevation: 0,
            ),
          ),
          routes: {
            '/service_anmelden': (_) => const WorkshopSlotPickerScreen(
                  title: 'Service anmelden',
                  serviceType: 'service_anmelden',
                ),
            '/raeder_wechsel': (_) => const RaederWechselScreen(),
          },
          home: const AuthGate(
            homeBuilder: _homeBuilder,
          ),
        );
      },
    );
  }
}

Widget _homeBuilder(BuildContext context) => const HomePage();

/// Traduttore semplice per la HOME //////////////////////////
String tr(BuildContext context, String key, {Map<String, String>? params}) {
  final lang = Localizations.localeOf(context).languageCode;

  String base(String it, String de, String fr, String en) {
    switch (lang) {
      case 'de':
        return de;
      case 'fr':
        return fr;
      case 'en':
        return en;
      default:
        return it;
    }
  }

  String text;
  switch (key) {
    case 'home_title':
      text = base(
        'CID Digitale',
        'Digitaler Unfallbericht',
        'Constat amiable digital',
        'Digital accident report',
      );
      break;
    case 'home_subtitle':
      text = base(
        'Gestione rapida del tuo CID digitale',
        'Schnelle Verwaltung deines digitalen Unfallberichts',
        'Gestion rapide de ton constat digital',
        'Fast management of your digital accident report',
      );
      break;
    case 'home_new_incident':
      text = base(
          'Nuovo incidente', 'Neuer Unfall', 'Nouvel accident', 'New accident');
      break;
    case 'home_history_empty':
      text = base(
        'Storico incidenti (vuoto)',
        'Unfallhistorie (leer)',
        'Historique des accidents (vide)',
        'Accident history (empty)',
      );
      break;
    case 'home_history_count':
      final count = params?['count'] ?? '0';
      text = base(
        'Storico incidenti ($count)',
        'Unfallhistorie ($count)',
        'Historique des accidents ($count)',
        'Accident history ($count)',
      );
      break;
    case 'home_settings_tooltip':
      text = base(
        'Impostazioni officina',
        'Werkstatt-Einstellungen',
        'Paramètres du garage',
        'Workshop settings',
      );
      break;
    default:
      text = key;
  }

  return text;
}

/// Formattazione data/ora localizzata
String formatDataOraLocale(BuildContext context, DateTime dt) {
  final tag = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMMd(tag).add_Hm().format(dt);
}

String formatDataOraGeneric(DateTime dt, {Locale? locale}) {
  final tag = (locale ?? linguaSelezionata.value).toLanguageTag();
  return DateFormat.yMMMMd(tag).add_Hm().format(dt);
}

String formatFullAddress(String indirizzo, String zip, String city) {
  final parts = [
    indirizzo.trim(),
    zip.trim(),
    city.trim(),
  ].where((part) => part.isNotEmpty).toList();
  return parts.join(', ');
}

/// Traduzioni rapide per testi brevi (pulsanti/etichette) /////////////////////
const Map<String, Map<String, String>> _tMap = {
  'Chiama la mia carrozzeria': {
    'it': 'Chiama la mia carrozzeria',
    'de': 'Meine Werkstatt anrufen',
    'fr': 'Appeler ma carrosserie',
    'en': 'Call my body shop',
  },
  'Trova carrozzeria e i dintorni': {
    'it': 'Trova carrozzeria e i dintorni',
    'de': 'Werkstatt in der Nähe finden',
    'fr': 'Trouver une carrosserie à proximité',
    'en': 'Find a body shop nearby',
  },
  'Chiama numeri di emergenza': {
    'it': 'Chiama numeri di emergenza',
    'de': 'Notrufnummern anrufen',
    'fr': 'Appeler les numéros d’urgence',
    'en': 'Call emergency numbers',
  },
  'Posizione in rilevamento...': {
    'it': 'Posizione in rilevamento...',
    'de': 'Standort wird automatisch ermittelt...',
    'fr': 'Localisation en cours...',
    'en': 'Detecting location...',
  },
  'Indirizzo in caricamento...': {
    'it': 'Indirizzo in caricamento...',
    'de': 'Adresse wird geladen...',
    'fr': 'Chargement de l’adresse...',
    'en': 'Loading address...',
  },
  'Usa la mia posizione': {
    'it': 'Usa la mia posizione',
    'de': 'Meinen Standort verwenden',
    'fr': 'Utiliser ma position',
    'en': 'Use my location',
  },
  'Apri mappa': {
    'it': 'Apri mappa',
    'de': 'Karte öffnen',
    'fr': 'Ouvrir la carte',
    'en': 'Open map',
  },
  'Indirizzo non disponibile': {
    'it': 'Indirizzo non disponibile',
    'de': 'Adresse nicht verfügbar',
    'fr': 'Adresse non disponible',
    'en': 'Address not available',
  },
  'Consenti la posizione in Safari per compilare automaticamente il luogo dell’incidente.':
      {
    'it':
        'Consenti la posizione in Safari per compilare automaticamente il luogo dell’incidente.',
    'de':
        'Erlaube den Standort in Safari, um den Unfallort automatisch zu erfassen.',
    'fr':
        'Autorise la localisation dans Safari pour renseigner automatiquement le lieu de l’accident.',
    'en':
        'Allow location in Safari to automatically fill the accident location.',
  },
  'Attiva la localizzazione sul dispositivo per compilare automaticamente il luogo dell’incidente.':
      {
    'it':
        'Attiva la localizzazione sul dispositivo per compilare automaticamente il luogo dell’incidente.',
    'de':
        'Bitte aktiviere die Standortdienste auf deinem Gerät, um den Unfallort automatisch zu erfassen.',
    'fr':
        'Active la localisation sur ton appareil pour renseigner automatiquement le lieu de l’accident.',
    'en':
        'Please enable location services on your device to automatically fill the accident location.',
  },
  'Impossibile ottenere la posizione (timeout).': {
    'it': 'Impossibile ottenere la posizione (timeout).',
    'de': 'Position konnte nicht ermittelt werden (Timeout).',
    'fr': 'Impossible d’obtenir la position (délai dépassé).',
    'en': 'Unable to get location (timeout).',
  },
  'Non siamo riusciti a ottenere la posizione. Verifica che la geolocalizzazione sia attiva e riprova.':
      {
    'it':
        'Non siamo riusciti a ottenere la posizione. Verifica che la geolocalizzazione sia attiva e riprova.',
    'de':
        'Standort konnte nicht ermittelt werden. Bitte prüfe die Standortfreigabe und versuche es erneut.',
    'fr':
        'Impossible de déterminer votre position. Vérifie l’accès à la localisation puis réessaie.',
    'en':
        'We could not determine your location. Please check location access and try again.',
  },
  'Errore durante la geolocalizzazione.': {
    'it': 'Errore durante la geolocalizzazione.',
    'de': 'Fehler bei der Geolokalisierung.',
    'fr': 'Erreur lors de la géolocalisation.',
    'en': 'Error during geolocation.',
  },
  'Posizione non disponibile.': {
    'it': 'Posizione non disponibile.',
    'de': 'Position nicht verfügbar.',
    'fr': 'Position non disponible.',
    'en': 'Position not available.',
  },
  'Consenti la posizione per compilare automaticamente il luogo dell’incidente.':
      {
    'it':
        'Consenti la posizione per compilare automaticamente il luogo dell’incidente.',
    'de':
        'Bitte erlaube deinen Standort, um den Unfallort automatisch zu erfassen.',
    'fr':
        'Autorise la localisation pour renseigner automatiquement le lieu de l’accident.',
    'en':
        'Please allow location access to automatically fill the accident location.',
  },
  'Riprova': {
    'it': 'Riprova',
    'de': 'Erneut versuchen',
    'fr': 'Réessayer',
    'en': 'Try again',
  },
  'Salva impostazioni': {
    'it': 'Salva impostazioni',
    'de': 'Einstellungen speichern',
    'fr': 'Enregistrer les réglages',
    'en': 'Save settings',
  },
  'Libretto A (AI)': {
    'it': 'Libretto A (AI)',
    'de': 'Fahrzeugausweis A (AI)',
    'fr': 'Carte grise A (IA)',
    'en': 'Registration A (AI)',
  },
  'Libretto B (AI)': {
    'it': 'Libretto B (AI)',
    'de': 'Fahrzeugausweis B (AI)',
    'fr': 'Carte grise B (IA)',
    'en': 'Registration B (AI)',
  },
  'Aggiungi testimone': {
    'it': 'Aggiungi testimone',
    'de': 'Zeugen hinzufügen',
    'fr': 'Ajouter un témoin',
    'en': 'Add witness',
  },
  'Registra nota vocale': {
    'it': 'Registra nota vocale',
    'de': 'Sprachnotiz aufnehmen',
    'fr': 'Enregistrer note vocale',
    'en': 'Record voice note',
  },
  'Ferma registrazione': {
    'it': 'Ferma registrazione',
    'de': 'Aufnahme stoppen',
    'fr': 'Arrêter l’enregistrement',
    'en': 'Stop recording',
  },
  'Riproduci nota': {
    'it': 'Riproduci nota',
    'de': 'Notiz abspielen',
    'fr': 'Lire la note',
    'en': 'Play note',
  },
  'Ferma riproduzione': {
    'it': 'Ferma riproduzione',
    'de': 'Wiedergabe stoppen',
    'fr': 'Arrêter la lecture',
    'en': 'Stop playback',
  },
  'Riproduci': {
    'it': 'Riproduci',
    'de': 'Abspielen',
    'fr': 'Lire',
    'en': 'Play',
  },
  'Ferma': {
    'it': 'Ferma',
    'de': 'Stopp',
    'fr': 'Arrêter',
    'en': 'Stop',
  },
  'Elimina nota': {
    'it': 'Elimina nota',
    'de': 'Notiz löschen',
    'fr': 'Supprimer la note',
    'en': 'Delete note',
  },
  'Aggiungi foto danno': {
    'it': 'Aggiungi foto danno',
    'de': 'Schadensfoto hinzufügen',
    'fr': 'Ajouter photo du dommage',
    'en': 'Add damage photo',
  },
  'Salva incidente e genera QR': {
    'it': 'Salva incidente e genera QR',
    'de': 'Unfall speichern und QR erstellen',
    'fr': 'Enregistrer l’accident et générer le QR',
    'en': 'Save accident and generate QR',
  },
  'Salva impostazioni officina': {
    'it': 'Salva impostazioni officina',
    'de': 'Werkstatteinstellungen speichern',
    'fr': 'Enregistrer les réglages du garage',
    'en': 'Save workshop settings',
  },
  'Salva firma': {
    'it': 'Salva firma',
    'de': 'Unterschrift speichern',
    'fr': 'Enregistrer la signature',
    'en': 'Save signature',
  },
  'Cancella': {
    'it': 'Cancella',
    'de': 'Löschen',
    'fr': 'Effacer',
    'en': 'Clear',
  },
  'Firma conducente A': {
    'it': 'Firma conducente A',
    'de': 'Unterschrift Fahrer A',
    'fr': 'Signature conducteur A',
    'en': 'Signature driver A',
  },
  'Firma conducente B': {
    'it': 'Firma conducente B',
    'de': 'Unterschrift Fahrer B',
    'fr': 'Signature conducteur B',
    'en': 'Signature driver B',
  },
  'Rifirma conducente A': {
    'it': 'Rifirma conducente A',
    'de': 'Neu unterschreiben Fahrer A',
    'fr': 'Resigner conducteur A',
    'en': 'Resign driver A',
  },
  'Rifirma conducente B': {
    'it': 'Rifirma conducente B',
    'de': 'Neu unterschreiben Fahrer B',
    'fr': 'Resigner conducteur B',
    'en': 'Resign driver B',
  },
  'Fai prima la firma sullo schermo.': {
    'it': 'Fai prima la firma sullo schermo.',
    'de': 'Bitte zuerst auf dem Bildschirm unterschreiben.',
    'fr': 'Signez d’abord sur l’écran.',
    'en': 'Sign on the screen first.',
  },
  'Errore nel salvataggio della firma.': {
    'it': 'Errore nel salvataggio della firma.',
    'de': 'Fehler beim Speichern der Unterschrift.',
    'fr': 'Erreur lors de la sauvegarde de la signature.',
    'en': 'Error saving the signature.',
  },
  'Nota vocale non disponibile.': {
    'it': 'Nota vocale non disponibile.',
    'de': 'Sprachnotiz nicht verfügbar.',
    'fr': 'Note vocale indisponible.',
    'en': 'Voice note not available.',
  },
  'Il file audio della nota non è stato trovato.': {
    'it': 'Il file audio della nota non è stato trovato.',
    'de': 'Die Audiodatei der Notiz wurde nicht gefunden.',
    'fr': 'Le fichier audio de la note est introuvable.',
    'en': 'Voice note file not found.',
  },
  'Nota vocale': {
    'it': 'Nota vocale',
    'de': 'Sprachnotiz',
    'fr': 'Note vocale',
    'en': 'Voice note',
  },
  'Firme raccolte': {
    'it': 'Firme raccolte',
    'de': 'Unterschriften erfasst',
    'fr': 'Signatures recueillies',
    'en': 'Signatures collected',
  },
  'Conducente B (dettaglio)': {
    'it': 'Conducente B',
    'de': 'Fahrer B',
    'fr': 'Conducteur B',
    'en': 'Driver B',
  },
  'Conducente B (firma)': {
    'it': 'Conducente B',
    'de': 'Fahrer B',
    'fr': 'Conducteur B',
    'en': 'Driver B',
  },
  'Questo incidente è in sola lettura / bloccato.': {
    'it': 'Questo incidente è in sola lettura / bloccato.',
    'de': 'Dieser Fall ist schreibgeschützt / gesperrt.',
    'fr': 'Ce dossier est en lecture seule / bloqué.',
    'en': 'This case is read-only / locked.',
  },
  'Mostra questo QR alla carrozzeria per importare i dati.': {
    'it': 'Mostra questo QR alla carrozzeria per importare i dati.',
    'de':
        'Zeigen Sie diesen QR-Code der Werkstatt, um die Daten zu importieren.',
    'fr': 'Montrez ce QR à la carrosserie pour importer les données.',
    'en': 'Show this QR to the workshop to import data.',
  },
  'Apri QR a tutto schermo': {
    'it': 'Apri QR a tutto schermo',
    'de': 'QR im Vollbild öffnen',
    'fr': 'Ouvrir le QR en plein écran',
    'en': 'Open QR full screen',
  },
  'Codice officina:': {
    'it': 'Codice officina:',
    'de': 'Werkstattcode:',
    'fr': 'Code atelier :',
    'en': 'Workshop code:',
  },
  'Chiedi al conducente di firmare con il dito.': {
    'it': 'Chiedi al conducente di firmare con il dito.',
    'de': 'Bitte den Fahrer, mit dem Finger zu unterschreiben.',
    'fr': 'Demandez au conducteur de signer avec le doigt.',
    'en': 'Ask the driver to sign with a finger.',
  },
  'CID Digitale – Accesso non disponibile via Web': {
    'it': 'CID Digitale – Accesso non disponibile via Web',
    'de': 'CID Digitale – Web-Zugriff nicht verfügbar',
    'fr': 'CID Digitale – Accès web indisponible',
    'en': 'CID Digitale – Web access not available',
  },
  'La compilazione del CID è disponibile solo tramite app mobile.': {
    'it': 'La compilazione del CID è disponibile solo tramite app mobile.',
    'de': 'Die Ausfüllung des CID ist nur über die mobile App möglich.',
    'fr':
        'La complétion du CID est disponible uniquement via l’application mobile.',
    'en': 'Completing the CID is only available via the mobile app.',
  },
  'Invia PDF + foto alla assicurazione e conducente A e B': {
    'it': 'Invia PDF + foto alla assicurazione e conducente A e B',
    'de': 'PDF + Fotos an Versicherung und Fahrer A/B senden',
    'fr': 'Envoyer PDF + photos à l’assurance et conducteurs A et B',
    'en': 'Send PDF + photos to insurance and drivers A and B',
  },
  'Invia QR a officina': {
    'it': 'Invia QR a officina',
    'de': 'QR an Werkstatt senden',
    'fr': 'Envoyer le QR au garage',
    'en': 'Send QR to workshop',
  },
  'Impostazioni officina': {
    'it': 'Impostazioni officina',
    'de': 'Werkstatteinstellungen',
    'fr': 'Paramètres du garage',
    'en': 'Workshop settings',
  },
  'Nuova pratica incidente': {
    'it': 'Nuova pratica incidente',
    'de': 'Neuer Unfallbericht',
    'fr': 'Nouveau constat d’accident',
    'en': 'New accident report',
  },
  'Storico incidenti': {
    'it': 'Storico incidenti',
    'de': 'Unfallhistorie',
    'fr': 'Historique des accidents',
    'en': 'Accident history',
  },
  'Dettaglio incidente': {
    'it': 'Dettaglio incidente',
    'de': 'Unfalldetails',
    'fr': 'Détail de l’accident',
    'en': 'Accident detail',
  },
  'QR per officina': {
    'it': 'QR per officina',
    'de': 'QR für Werkstatt',
    'fr': 'QR pour le garage',
    'en': 'QR for workshop',
  },
  "Luogo dell'incidente": {
    'it': "Luogo dell'incidente",
    'de': 'Unfallort',
    'fr': "Lieu de l'accident",
    'en': 'Accident location',
  },
  'Conducente B': {
    'it': 'Conducente B',
    'de': 'Fahrer B',
    'fr': 'Conducteur B',
    'en': 'Driver B',
  },
  'Descrizione incidente': {
    'it': 'Descrizione incidente',
    'de': 'Unfallbeschreibung',
    'fr': "Description de l'accident",
    'en': 'Accident description',
  },
  'Testimoni (se presenti)': {
    'it': 'Testimoni (se presenti)',
    'de': 'Zeugen (falls vorhanden)',
    'fr': 'Témoins (le cas échéant)',
    'en': 'Witnesses (if any)',
  },
  'Feriti (se presenti)': {
    'it': 'Feriti (se presenti)',
    'de': 'Verletzte (falls vorhanden)',
    'fr': 'Blessés (le cas échéant)',
    'en': 'Injured (if any)',
  },
  'Aggiungi ferito': {
    'it': 'Aggiungi ferito',
    'de': 'Verletzten hinzufügen',
    'fr': 'Ajouter un blessé',
    'en': 'Add injured person',
  },
  'Nome ferito': {
    'it': 'Nome ferito',
    'de': 'Name des Verletzten',
    'fr': 'Nom du blessé',
    'en': 'Injured name',
  },
  'Indirizzo ferito': {
    'it': 'Indirizzo ferito',
    'de': 'Adresse des Verletzten',
    'fr': 'Adresse du blessé',
    'en': 'Injured address',
  },
  'Telefono ferito': {
    'it': 'Telefono ferito',
    'de': 'Telefon des Verletzten',
    'fr': 'Téléphone du blessé',
    'en': 'Injured phone',
  },
  'Note dei conducenti': {
    'it': 'Note dei conducenti',
    'de': 'Notizen der Fahrer',
    'fr': 'Notes des conducteurs',
    'en': 'Drivers notes',
  },
  'Note vocali': {
    'it': 'Note vocali',
    'de': 'Sprachnotizen',
    'fr': 'Notes vocales',
    'en': 'Voice notes',
  },
  'Foto del danno': {
    'it': 'Foto del danno',
    'de': 'Schadensfotos',
    'fr': 'Photos des dommages',
    'en': 'Damage photos',
  },
  'Riepilogo incidente': {
    'it': 'Riepilogo incidente',
    'de': 'Unfallzusammenfassung',
    'fr': "Résumé de l'accident",
    'en': 'Accident summary',
  },
  'Responsabilità e firme': {
    'it': 'Responsabilità e firme',
    'de': 'Haftung und Unterschriften',
    'fr': 'Responsabilité et signatures',
    'en': 'Liability and signatures',
  },
  'QR per la carrozzeria': {
    'it': 'QR per la carrozzeria',
    'de': 'QR für die Werkstatt',
    'fr': 'QR pour la carrosserie',
    'en': 'QR for the body shop',
  },
  'Azioni rapide': {
    'it': 'Azioni rapide',
    'de': 'Schnellaktionen',
    'fr': 'Actions rapides',
    'en': 'Quick actions',
  },
  'Numero carro attrezzi': {
    'it': 'Numero carro attrezzi',
    'de': 'Abschleppdienst-Nummer',
    'fr': 'Numéro dépanneuse',
    'en': 'Tow truck number',
  },
  'Numero carrozzeria / concessionaria': {
    'it': 'Numero carrozzeria / concessionaria',
    'de': 'Werkstatt-/Händlernummer',
    'fr': 'Numéro carrosserie / concessionnaire',
    'en': 'Body shop / dealer number',
  },
  'Email carrozzeria / concessionaria': {
    'it': 'Email carrozzeria / concessionaria',
    'de': 'E-Mail Werkstatt / Händler',
    'fr': 'Email carrosserie / concessionnaire',
    'en': 'Body shop / dealer email',
  },
  'Nome conducente A': {
    'it': 'Nome conducente A',
    'de': 'Name Fahrer A',
    'fr': 'Nom conducteur A',
    'en': 'Driver A name',
  },
  'Targa veicolo A': {
    'it': 'Targa veicolo A',
    'de': 'Kennzeichen Fahrzeug A',
    'fr': 'Plaque véhicule A',
    'en': 'License plate vehicle A',
  },
  'Assicurazione veicolo A (es. Allianz)': {
    'it': 'Assicurazione veicolo A (es. Allianz)',
    'de': 'Versicherung Fahrzeug A (z.B. Allianz)',
    'fr': 'Assurance véhicule A (ex. Allianz)',
    'en': 'Insurance vehicle A (e.g. Allianz)',
  },
  'Telefono conducente A': {
    'it': 'Telefono conducente A',
    'de': 'Telefon Fahrer A',
    'fr': 'Téléphone conducteur A',
    'en': 'Driver A phone',
  },
  'Email conducente A': {
    'it': 'Email conducente A',
    'de': 'E-Mail Fahrer A',
    'fr': 'Email conducteur A',
    'en': 'Driver A email',
  },
  'Indirizzo conducente A': {
    'it': 'Indirizzo conducente A',
    'de': 'Adresse Fahrer A',
    'fr': 'Adresse conducteur A',
    'en': 'Driver A address',
  },
  'Nome conducente B': {
    'it': 'Nome conducente B',
    'de': 'Name Fahrer B',
    'fr': 'Nom conducteur B',
    'en': 'Driver B name',
  },
  'Targa veicolo B': {
    'it': 'Targa veicolo B',
    'de': 'Kennzeichen Fahrzeug B',
    'fr': 'Plaque véhicule B',
    'en': 'License plate vehicle B',
  },
  'Assicurazione veicolo B (es. AXA)': {
    'it': 'Assicurazione veicolo B (es. AXA)',
    'de': 'Versicherung Fahrzeug B (z.B. AXA)',
    'fr': 'Assurance véhicule B (ex. AXA)',
    'en': 'Insurance vehicle B (e.g. AXA)',
  },
  'Telefono conducente B': {
    'it': 'Telefono conducente B',
    'de': 'Telefon Fahrer B',
    'fr': 'Téléphone conducteur B',
    'en': 'Driver B phone',
  },
  'Email conducente B': {
    'it': 'Email conducente B',
    'de': 'E-Mail Fahrer B',
    'fr': 'Email conducteur B',
    'en': 'Driver B email',
  },
  'Indirizzo conducente B': {
    'it': 'Indirizzo conducente B',
    'de': 'Adresse Fahrer B',
    'fr': 'Adresse conducteur B',
    'en': 'Driver B address',
  },
  'Nome testimone': {
    'it': 'Nome testimone',
    'de': 'Name Zeuge',
    'fr': 'Nom témoin',
    'en': 'Witness name',
  },
  'Telefono testimone': {
    'it': 'Telefono testimone',
    'de': 'Telefon Zeuge',
    'fr': 'Téléphone témoin',
    'en': 'Witness phone',
  },
  'Nota conducente A': {
    'it': 'Nota conducente A',
    'de': 'Notiz Fahrer A',
    'fr': 'Note conducteur A',
    'en': 'Driver A note',
  },
  'Nota conducente B': {
    'it': 'Nota conducente B',
    'de': 'Notiz Fahrer B',
    'fr': 'Note conducteur B',
    'en': 'Driver B note',
  },
  "Scrivi brevemente come è successo l'incidente...": {
    'it': "Scrivi brevemente come è successo l'incidente...",
    'de': 'Beschreibe kurz, wie der Unfall passiert ist...',
    'fr': "Décris brièvement comment l'accident s'est produit...",
    'en': 'Briefly describe how the accident happened...',
  },
  'Es. Autostrada A2, uscita Lugano Nord': {
    'it': 'Es. Autostrada A2, uscita Lugano Nord',
    'de': 'Z.B. Autobahn A2, Ausfahrt Lugano Nord',
    'fr': 'Ex. Autoroute A2, sortie Lugano Nord',
    'en': 'e.g. Highway A2, Lugano Nord exit',
  },
  'Es. +41...': {
    'it': 'Es. +41...',
    'de': 'Z.B. +41...',
    'fr': 'Ex. +41...',
    'en': 'e.g. +41...',
  },
  'nome@email.ch': {
    'it': 'nome@email.ch',
    'de': 'name@email.ch',
    'fr': 'nom@email.ch',
    'en': 'name@email.ch',
  },
  'Data e ora': {
    'it': 'Data e ora',
    'de': 'Datum und Uhrzeit',
    'fr': 'Date et heure',
    'en': 'Date and time',
  },
  'Verifica email/telefono': {
    'it': 'Verifica email/telefono',
    'de': 'E-Mail/Telefon prüfen',
    'fr': 'Vérifier email/téléphone',
    'en': 'Validate email/phone',
  },
  'Se disattivi, i contatti non sono obbligatori (utile in emergenza).': {
    'it': 'Se disattivi, i contatti non sono obbligatori (utile in emergenza).',
    'de':
        'Wenn deaktiviert, sind Kontakte nicht verpflichtend (nützlich im Notfall).',
    'fr':
        'Si désactivé, les contacts ne sont pas obligatoires (utile en urgence).',
    'en': 'If off, contacts are not required (useful in emergencies).',
  },
  'Numeri di emergenza': {
    'it': 'Numeri di emergenza',
    'de': 'Notrufnummern',
    'fr': "Numéros d'urgence",
    'en': 'Emergency numbers',
  },
  'Carro attrezzi': {
    'it': 'Carro attrezzi',
    'de': 'Abschleppdienst',
    'fr': 'Dépanneuse',
    'en': 'Tow truck',
  },
  'Polizia (112)': {
    'it': 'Polizia (112)',
    'de': 'Polizei (112)',
    'fr': 'Police (112)',
    'en': 'Police (112)',
  },
  'Ambulanza (112)': {
    'it': 'Ambulanza (112)',
    'de': 'Ambulanz (112)',
    'fr': 'Ambulance (112)',
    'en': 'Ambulance (112)',
  },
  'Impossibile avviare la chiamata.': {
    'it': 'Impossibile avviare la chiamata.',
    'de': 'Anruf konnte nicht gestartet werden.',
    'fr': "Impossible de lancer l'appel.",
    'en': 'Unable to start the call.',
  },
  'Impossibile aprire Google Maps.': {
    'it': 'Impossibile aprire Google Maps.',
    'de': 'Google Maps kann nicht geöffnet werden.',
    'fr': "Impossible d'ouvrir Google Maps.",
    'en': 'Cannot open Google Maps.',
  },
  'Imposta il numero della carrozzeria nelle Impostazioni officina.': {
    'it': 'Imposta il numero della carrozzeria nelle Impostazioni officina.',
    'de': 'Lege die Werkstattnummer in den Werkstatteinstellungen fest.',
    'fr': 'Renseigne le numéro de la carrosserie dans les paramètres garage.',
    'en': 'Set the body shop number in Workshop settings.',
  },
  'Imposta il numero del carro attrezzi nelle Impostazioni officina.': {
    'it': 'Imposta il numero del carro attrezzi nelle Impostazioni officina.',
    'de': 'Lege die Abschleppdienstnummer in den Werkstatteinstellungen fest.',
    'fr': 'Renseigne le numéro de dépanneuse dans les paramètres garage.',
    'en': 'Set the tow truck number in Workshop settings.',
  },
  'Configura il numero in Impostazioni officina': {
    'it': 'Configura il numero in Impostazioni officina',
    'de': 'Nummer in Werkstatteinstellungen eintragen',
    'fr': 'Configurer le numéro dans Paramètres du garage',
    'en': 'Set the number in Workshop settings',
  },
  'Nessun incidente salvato.': {
    'it': 'Nessun incidente salvato.',
    'de': 'Kein Unfall gespeichert.',
    'fr': 'Aucun accident enregistré.',
    'en': 'No accidents saved.',
  },
  "Inserisci il luogo dell'incidente": {
    'it': "Inserisci il luogo dell'incidente",
    'de': 'Gib den Unfallort ein',
    'fr': "Saisis le lieu de l'accident",
    'en': 'Enter the accident location',
  },
  'Inserisci il nome del conducente A': {
    'it': 'Inserisci il nome del conducente A',
    'de': 'Name von Fahrer A eingeben',
    'fr': 'Saisis le nom du conducteur A',
    'en': 'Enter driver A name',
  },
  'Inserisci la targa del veicolo A': {
    'it': 'Inserisci la targa del veicolo A',
    'de': 'Kennzeichen Fahrzeug A eingeben',
    'fr': 'Saisis la plaque du véhicule A',
    'en': 'Enter vehicle A license plate',
  },
  'Inserisci il nome del conducente B': {
    'it': 'Inserisci il nome del conducente B',
    'de': 'Name von Fahrer B eingeben',
    'fr': 'Saisis le nom du conducteur B',
    'en': 'Enter driver B name',
  },
  'Inserisci la targa del veicolo B': {
    'it': 'Inserisci la targa del veicolo B',
    'de': 'Kennzeichen Fahrzeug B eingeben',
    'fr': 'Saisis la plaque du véhicule B',
    'en': 'Enter vehicle B license plate',
  },
  'Email non valida': {
    'it': 'Email non valida',
    'de': 'Ungültige E-Mail',
    'fr': 'Email non valide',
    'en': 'Invalid email',
  },
  'Numero di telefono non valido': {
    'it': 'Numero di telefono non valido',
    'de': 'Ungültige Telefonnummer',
    'fr': 'Numéro de téléphone invalide',
    'en': 'Invalid phone number',
  },
  'CID digitale - QR per officina': {
    'it': 'CID digitale - QR per officina',
    'de': 'Digitales CID - QR für Werkstatt',
    'fr': 'CID digital - QR pour garage',
    'en': 'Digital CID - QR for workshop',
  },
  'Dati QR pronti. Scegli l\'app (WhatsApp, Mail, ecc.) per mandarli alla tua officina.':
      {
    'it':
        'Dati QR pronti. Scegli l\'app (WhatsApp, Mail, ecc.) per mandarli alla tua officina.',
    'de':
        'QR-Daten bereit. Wähle die App (WhatsApp, Mail, etc.), um sie an deine Werkstatt zu senden.',
    'fr':
        'Données QR prêtes. Choisis l’app (WhatsApp, Mail, etc.) pour les envoyer à ton garage.',
    'en':
        'QR data ready. Choose the app (WhatsApp, Mail, etc.) to send them to your workshop.',
  },
  'Errore durante la condivisione del QR.': {
    'it': 'Errore durante la condivisione del QR.',
    'de': 'Fehler beim Teilen des QR.',
    'fr': 'Erreur lors du partage du QR.',
    'en': 'Error sharing the QR.',
  },
  'CID digitale incidente': {
    'it': 'CID digitale incidente',
    'de': 'Digitales CID Unfall',
    'fr': 'CID digital accident',
    'en': 'Digital CID accident',
  },
  'Invio il CID digitale dell\'incidente per la gestione del sinistro.': {
    'it': 'Invio il CID digitale dell\'incidente per la gestione del sinistro.',
    'de': 'Ich sende das digitale CID für die Schadensbearbeitung.',
    'fr': 'J’envoie le CID digital de l’accident pour la gestion du sinistre.',
    'en': 'Sending the digital CID for claim handling.',
  },
  'PDF e foto generati. Scegli l\'app (Mail, WhatsApp, ecc.) per inviarli.': {
    'it':
        'PDF e foto generati. Scegli l\'app (Mail, WhatsApp, ecc.) per inviarli.',
    'de':
        'PDF und Fotos erstellt. Wähle die App (Mail, WhatsApp, etc.), um sie zu senden.',
    'fr':
        'PDF et photos générés. Choisis l’app (Mail, WhatsApp, etc.) pour les envoyer.',
    'en':
        'PDF and photos created. Choose the app (Mail, WhatsApp, etc.) to send them.',
  },
  'Errore nella generazione o condivisione del PDF e allegati.': {
    'it': 'Errore nella generazione o condivisione del PDF e allegati.',
    'de': 'Fehler beim Erstellen oder Teilen des PDF und der Anhänge.',
    'fr':
        'Erreur lors de la génération ou du partage du PDF et des pièces jointes.',
    'en': 'Error generating or sharing the PDF and attachments.',
  },
  'CID Digitale': {
    'it': 'CID Digitale',
    'de': 'Digitaler Unfallbericht',
    'fr': 'Constat amiable digital',
    'en': 'Digital accident report',
  },
  'Data e ora:': {
    'it': 'Data e ora:',
    'de': 'Datum und Uhrzeit:',
    'fr': 'Date et heure :',
    'en': 'Date and time:',
  },
  'Luogo:': {
    'it': 'Luogo:',
    'de': 'Ort:',
    'fr': 'Lieu :',
    'en': 'Place:',
  },
  'Indirizzo A:': {
    'it': 'Indirizzo A:',
    'de': 'Adresse A:',
    'fr': 'Adresse A :',
    'en': 'Address A:',
  },
  'Indirizzo B:': {
    'it': 'Indirizzo B:',
    'de': 'Adresse B:',
    'fr': 'Adresse B :',
    'en': 'Address B:',
  },
  'Indirizzo:': {
    'it': 'Indirizzo:',
    'de': 'Adresse:',
    'fr': 'Adresse :',
    'en': 'Address:',
  },
  'Assicurazione A:': {
    'it': 'Assicurazione A:',
    'de': 'Versicherung A:',
    'fr': 'Assurance A :',
    'en': 'Insurance A:',
  },
  'Telefono A:': {
    'it': 'Telefono A:',
    'de': 'Telefon A:',
    'fr': 'Téléphone A :',
    'en': 'Phone A:',
  },
  'Email A:': {
    'it': 'Email A:',
    'de': 'E-Mail A:',
    'fr': 'Email A :',
    'en': 'Email A:',
  },
  'Assicurazione B:': {
    'it': 'Assicurazione B:',
    'de': 'Versicherung B:',
    'fr': 'Assurance B :',
    'en': 'Insurance B:',
  },
  'Telefono B:': {
    'it': 'Telefono B:',
    'de': 'Telefon B:',
    'fr': 'Téléphone B :',
    'en': 'Phone B:',
  },
  'Email B:': {
    'it': 'Email B:',
    'de': 'E-Mail B:',
    'fr': 'Email B :',
    'en': 'Email B:',
  },
  'Descrizione:': {
    'it': 'Descrizione:',
    'de': 'Beschreibung:',
    'fr': 'Description :',
    'en': 'Description:',
  },
  'Testimoni:': {
    'it': 'Testimoni:',
    'de': 'Zeugen:',
    'fr': 'Témoins :',
    'en': 'Witnesses:',
  },
  'Feriti:': {
    'it': 'Feriti:',
    'de': 'Verletzte:',
    'fr': 'Blessés :',
    'en': 'Injured:',
  },
  '- Nessun testimone indicato.': {
    'it': '- Nessun testimone indicato.',
    'de': '- Kein Zeuge angegeben.',
    'fr': '- Aucun témoin indiqué.',
    'en': '- No witness provided.',
  },
  '- Nessun ferito indicato.': {
    'it': '- Nessun ferito indicato.',
    'de': '- Kein Verletzter angegeben.',
    'fr': '- Aucun blessé indiqué.',
    'en': '- No injured person provided.',
  },
  'Nome non indicato': {
    'it': 'Nome non indicato',
    'de': 'Name nicht angegeben',
    'fr': 'Nom non indiqué',
    'en': 'Name not provided',
  },
  'Note dei conducenti:': {
    'it': 'Note dei conducenti:',
    'de': 'Notizen der Fahrer:',
    'fr': 'Notes des conducteurs :',
    'en': 'Drivers notes:',
  },
  'Nessuna nota indicata.': {
    'it': 'Nessuna nota indicata.',
    'de': 'Keine Notiz angegeben.',
    'fr': 'Aucune note indiquée.',
    'en': 'No notes provided.',
  },
  'Conducente A (testo):': {
    'it': 'Conducente A (testo):',
    'de': 'Fahrer A (Text):',
    'fr': 'Conducteur A (texte) :',
    'en': 'Driver A (text):',
  },
  'Conducente A: nota vocale allegata (file audio).': {
    'it': 'Conducente A: nota vocale allegata (file audio).',
    'de': 'Fahrer A: Sprachnotiz angehängt (Audiodatei).',
    'fr': 'Conducteur A : note vocale jointe (fichier audio).',
    'en': 'Driver A: voice note attached (audio file).',
  },
  'Conducente B (testo):': {
    'it': 'Conducente B (testo):',
    'de': 'Fahrer B (Text):',
    'fr': 'Conducteur B (texte) :',
    'en': 'Driver B (text):',
  },
  'Conducente B: nota vocale allegata (file audio).': {
    'it': 'Conducente B: nota vocale allegata (file audio).',
    'de': 'Fahrer B: Sprachnotiz angehängt (Audiodatei).',
    'fr': 'Conducteur B : note vocale jointe (fichier audio).',
    'en': 'Driver B: voice note attached (audio file).',
  },
  'Responsabilità (dichiarazione delle parti):': {
    'it': 'Responsabilità (dichiarazione delle parti):',
    'de': 'Haftung (Angabe der Parteien):',
    'fr': 'Responsabilité (déclaration des parties) :',
    'en': 'Liability (as stated by parties):',
  },
  'Responsabilità non dichiarata nelle selezioni dell\'app.': {
    'it': 'Responsabilità non dichiarata nelle selezioni dell\'app.',
    'de': 'Haftung in der App-Auswahl nicht angegeben.',
    'fr': 'Responsabilité non déclarée dans l’app.',
    'en': 'Liability not declared in the app selections.',
  },
  'Secondo le parti il conducente ritenuto colpevole è A.': {
    'it': 'Secondo le parti il conducente ritenuto colpevole è A.',
    'de': 'Laut Parteien gilt Fahrer A als verantwortlich.',
    'fr': 'Selon les parties, le conducteur jugé responsable est A.',
    'en': 'According to the parties, driver A is at fault.',
  },
  'Secondo le parti il conducente ritenuto colpevole è B.': {
    'it': 'Secondo le parti il conducente ritenuto colpevole è B.',
    'de': 'Laut Parteien gilt Fahrer B als verantwortlich.',
    'fr': 'Selon les parties, le conducteur jugé responsable est B.',
    'en': 'According to the parties, driver B is at fault.',
  },
  'Impronta integrità (SHA-256):': {
    'it': 'Impronta integrità (SHA-256):',
    'de': 'Integritäts-Hash (SHA-256):',
    'fr': 'Empreinte d’intégrité (SHA-256) :',
    'en': 'Integrity hash (SHA-256):',
  },
  'Firme:': {
    'it': 'Firme:',
    'de': 'Unterschriften:',
    'fr': 'Signatures :',
    'en': 'Signatures:',
  },
  'Timestamp firma (UTC):': {
    'it': 'Timestamp firma (UTC):',
    'de': 'Unterschrifts-Zeitstempel (UTC):',
    'fr': 'Horodatage signature (UTC) :',
    'en': 'Signature timestamp (UTC):',
  },
  'Le firme apposte confermano la correttezza dei dati inseriti nel presente CID digitale.':
      {
    'it':
        'Le firme apposte confermano la correttezza dei dati inseriti nel presente CID digitale.',
    'de':
        'Die geleisteten Unterschriften bestätigen die Richtigkeit der in diesem digitalen CID enthaltenen Daten.',
    'fr':
        'Les signatures apposées confirment l’exactitude des données de ce CID digital.',
    'en':
        'The signatures confirm the accuracy of the data in this digital CID.',
  },
  'Codice officina (pdf):': {
    'it': 'Codice officina:',
    'de': 'Werkstattcode:',
    'fr': 'Code garage :',
    'en': 'Workshop code:',
  },
  "QR code disponibile nell'app per recuperare rapidamente la pratica.": {
    'it': "QR code disponibile nell'app per recuperare rapidamente la pratica.",
    'de': 'QR-Code in der App verfügbar, um den Vorgang schnell abzurufen.',
    'fr': 'QR code disponible dans l’app pour récupérer rapidement le dossier.',
    'en': 'QR code available in the app to quickly retrieve the case.',
  },
};

String tx(BuildContext context, String it) {
  final lang = Localizations.localeOf(context).languageCode;
  final entry = _tMap[it];
  if (entry == null) return it;
  return entry[lang] ?? entry['it'] ?? it;
}

String txStatic(String it) {
  final lang = linguaSelezionata.value.languageCode;
  final entry = _tMap[it];
  if (entry == null) return it;
  return entry[lang] ?? entry['it'] ?? it;
}

String formatNomeCompleto(String nome, String cognome) {
  if (nome.isEmpty) return cognome;
  if (cognome.isEmpty) return nome;
  return '$nome $cognome';
}

/// HOME ////////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void _vaiANuovoIncidente() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NuovaPraticaIncidentePage()),
    );
    await caricaIncidenti();
    setState(() {});
  }

  void _vaiAImpostazioni() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImpostazioniOfficinaPage()),
    );
    setState(() {});
  }

  Future<void> _openDamageTypePicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    final selected = await showModalBottomSheet<DamageType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: DamageTypePickerSheet(
            title: l10n.damage_type_title,
            subtitle: l10n.damage_type_subtitle,
            cancelText: l10n.cancel,
            types: const [
              DamageType.glass,
              DamageType.hail,
              DamageType.marten,
              DamageType.parking,
              DamageType.comprehensive,
            ],
            selectedDamageType: null,
            iconFor: (t) {
              switch (t) {
                case DamageType.glass:
                  return Icons.grid_view_rounded;
                case DamageType.hail:
                  return Icons.grain_rounded;
                case DamageType.marten:
                  return Icons.pets_rounded;
                case DamageType.parking:
                  return Icons.local_parking_rounded;
                case DamageType.comprehensive:
                  return Icons.description_rounded;
              }
            },
            labelFor: (t) {
              switch (t) {
                case DamageType.glass:
                  return l10n.damage_glass;
                case DamageType.hail:
                  return l10n.damage_hail;
                case DamageType.marten:
                  return l10n.damage_marten;
                case DamageType.parking:
                  return l10n.damage_parking;
                case DamageType.comprehensive:
                  return l10n.damage_comprehensive;
              }
            },
            onSelected: (t) => Navigator.of(ctx).pop(t),
          ),
        );
      },
    );

    if (selected == null) return;

    _openCalendarSameLogic(selected, l10n);
  }

  void _openCalendarSameLogic(DamageType damageType, AppLocalizations l10n) {
    final serviceType = _damageServiceType(damageType);
    final title =
        '${l10n.damage_type_title} - ${_damageLabel(l10n, damageType)}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkshopSlotPickerScreen(
          title: title,
          serviceType: serviceType,
          damageType: damageType.name,
        ),
      ),
    );
  }

  Future<void> _openServiceAnmelden(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WorkshopSlotPickerScreen(
          title: 'Service anmelden',
          serviceType: 'service_anmelden',
        ),
      ),
    );
  }

  Future<void> _openRaederWechsel(BuildContext context) async {
    await Navigator.of(context).pushNamed('/raeder_wechsel');
  }

  Widget _quickActionChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFF2D2D2D).withOpacity(0.25),
          ),
          color: Colors.white.withOpacity(0.35),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF2B4B6B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _damageLabel(AppLocalizations l10n, DamageType type) {
    switch (type) {
      case DamageType.glass:
        return l10n.damage_glass;
      case DamageType.hail:
        return l10n.damage_hail;
      case DamageType.marten:
        return l10n.damage_marten;
      case DamageType.parking:
        return l10n.damage_parking;
      case DamageType.comprehensive:
        return l10n.damage_comprehensive;
    }
  }

  String _damageServiceType(DamageType type) {
    switch (type) {
      case DamageType.glass:
        return 'damage_glass';
      case DamageType.hail:
        return 'damage_hail';
      case DamageType.marten:
        return 'damage_marten';
      case DamageType.parking:
        return 'damage_parking';
      case DamageType.comprehensive:
        return 'damage_comprehensive';
    }
  }

  Future<void> _apriUrl(Uri uri, String messaggioErrore) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(messaggioErrore)));
    }
  }

  Future<void> _chiamaCarrozzeria() async {
    if (configOfficina.concessionariaNumero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(context,
              'Imposta il numero della carrozzeria nelle Impostazioni officina.')),
        ),
      );
      return;
    }
    await _apriUrl(
      Uri.parse('tel:${configOfficina.concessionariaNumero}'),
      tx(context, 'Impossibile avviare la chiamata.'),
    );
  }

  void _mostraEmergenze() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.blue.shade50,
                child: Text(
                  tx(context, 'Numeri di emergenza'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              ListTile(
                tileColor: Colors.blue.shade50,
                leading: const Icon(Icons.local_shipping, color: Colors.blue),
                title: Text(tx(context, 'Carro attrezzi'),
                    style: const TextStyle(color: Colors.black87)),
                subtitle: Text(
                  configOfficina.carroNumero.isEmpty
                      ? tx(context,
                          'Configura il numero in Impostazioni officina')
                      : configOfficina.carroNumero,
                  style: const TextStyle(color: Colors.black54),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (configOfficina.carroNumero.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tx(context,
                            'Imposta il numero del carro attrezzi nelle Impostazioni officina.')),
                      ),
                    );
                  } else {
                    _apriUrl(
                      Uri.parse('tel:${configOfficina.carroNumero}'),
                      tx(context, 'Impossibile avviare la chiamata.'),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                tileColor: Colors.blue.shade50,
                leading: const Icon(Icons.local_police, color: Colors.blue),
                title: Text(tx(context, 'Polizia (112)'),
                    style: const TextStyle(color: Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  _apriUrl(Uri.parse('tel:112'),
                      tx(context, 'Impossibile avviare la chiamata.'));
                },
              ),
              const Divider(height: 1),
              ListTile(
                tileColor: Colors.blue.shade50,
                leading: const Icon(Icons.local_hospital, color: Colors.blue),
                title: Text(tx(context, 'Ambulanza (112)'),
                    style: const TextStyle(color: Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  _apriUrl(Uri.parse('tel:112'),
                      tx(context, 'Impossibile avviare la chiamata.'));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const bool blockWebAccess = false;
    if (kIsWeb && blockWebAccess) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  tx(context, 'CID Digitale – Accesso non disponibile via Web'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  tx(context,
                      'La compilazione del CID è disponibile solo tramite app mobile.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'home_title')),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (value) {
              switch (value) {
                case 'it':
                  linguaSelezionata.value = const Locale('it');
                  unawaited(salvaLinguaPreferita('it'));
                  break;
                case 'de':
                  linguaSelezionata.value = const Locale('de');
                  unawaited(salvaLinguaPreferita('de'));
                  break;
                case 'fr':
                  linguaSelezionata.value = const Locale('fr');
                  unawaited(salvaLinguaPreferita('fr'));
                  break;
                case 'en':
                  linguaSelezionata.value = const Locale('en');
                  unawaited(salvaLinguaPreferita('en'));
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'it', child: Text('🇮🇹 Italiano')),
              PopupMenuItem(value: 'de', child: Text('🇩🇪 Deutsch')),
              PopupMenuItem(value: 'fr', child: Text('🇫🇷 Français')),
              PopupMenuItem(value: 'en', child: Text('🇬🇧 English')),
            ],
          ),
          IconButton(
            onPressed: _vaiAImpostazioni,
            icon: const Icon(Icons.settings),
            tooltip: tr(context, 'home_settings_tooltip'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Image.asset(
                'assets/images/crashform_logo.png',
                height: 120,
                width: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text(
                tr(context, 'home_subtitle'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _vaiANuovoIncidente,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  tr(context, 'home_new_incident'),
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 12),
              _PremiumActionButton(
                icon: Icons.inbox_outlined,
                label: l10n.my_requests_title,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyRequestsPage(
                        incidentsTab: StoricoPage(embedOnlyBody: true),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.workshop_services_title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 12.0;
                  final tileWidth = (constraints.maxWidth - gap) / 2;
                  return Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: tileWidth,
                            child: _HomeServiceTile(
                              icon: Icons.build,
                              title: l10n.service_anmelden,
                              onTap: () => _openServiceAnmelden(context),
                            ),
                          ),
                          const SizedBox(width: gap),
                          SizedBox(
                            width: tileWidth,
                            child: _HomeServiceTile(
                              icon: Icons.tire_repair,
                              title: l10n.raeder_wechsel,
                              onTap: () => _openRaederWechsel(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _HomeServiceTile(
                        icon: Icons.car_crash,
                        title: l10n.damage_type_title,
                        onTap: () => _openDamageTypePicker(context),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                l10n.quick_actions_title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _quickActionChip(
                    context: context,
                    icon: Icons.phone,
                    label: tx(context, 'Chiama la mia carrozzeria'),
                    onTap: _chiamaCarrozzeria,
                  ),
                  _quickActionChip(
                    context: context,
                    icon: Icons.place,
                    label: tx(context, 'Trova carrozzeria e i dintorni'),
                    onTap: () {
                      _apriUrl(
                        Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=carrozzeria+vicino+a+me',
                        ),
                        'Impossibile aprire Google Maps.',
                      );
                    },
                  ),
                  _quickActionChip(
                    context: context,
                    icon: Icons.emergency,
                    label: tx(context, 'Chiama numeri di emergenza'),
                    onTap: _mostraEmergenze,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const _PremiumActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.primary.withOpacity(0.12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withOpacity(0.55)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeServiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _HomeServiceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.iconTheme.color?.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ====================== PARTE 2 / 3 ======================
// (Impostazioni officina + OCR + Nuova pratica + Storico + Firma + QR Officina)
// Incolla questa parte SUBITO DOPO la PARTE 1

/// IMPOSTAZIONI OFFICINA ///////////////////////////////////////////////

class ImpostazioniOfficinaPage extends StatefulWidget {
  const ImpostazioniOfficinaPage({super.key});

  @override
  State<ImpostazioniOfficinaPage> createState() =>
      _ImpostazioniOfficinaPageState();
}

class _ImpostazioniOfficinaPageState extends State<ImpostazioniOfficinaPage> {
  late TextEditingController _carroController;
  late TextEditingController _concessionariaNumeroController;
  late TextEditingController _concessionariaEmailController;

  @override
  void initState() {
    super.initState();
    _carroController = TextEditingController(text: configOfficina.carroNumero);
    _concessionariaNumeroController =
        TextEditingController(text: configOfficina.concessionariaNumero);
    _concessionariaEmailController =
        TextEditingController(text: configOfficina.concessionariaEmail);
  }

  @override
  void dispose() {
    _carroController.dispose();
    _concessionariaNumeroController.dispose();
    _concessionariaEmailController.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    configOfficina = OfficinaConfig(
      carroNumero: _carroController.text.trim(),
      concessionariaNumero: _concessionariaNumeroController.text.trim(),
      concessionariaEmail: _concessionariaEmailController.text.trim(),
    );
    await salvaConfigOfficina();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impostazioni salvate.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Impostazioni officina')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _carroController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tx(context, 'Numero carro attrezzi'),
                hintText: tx(context, 'Es. +41...'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _concessionariaNumeroController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tx(context, 'Numero carrozzeria / concessionaria'),
                hintText: tx(context, 'Es. +41...'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _concessionariaEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: tx(context, 'Email carrozzeria / concessionaria'),
                hintText: tx(context, 'nome@email.ch'),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen(
                        workshopId: 'INSERISCI_WORKSHOP_UUID_QUI',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Kalender'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _salva,
                icon: const Icon(Icons.save),
                label: Text(tx(context, 'Salva impostazioni')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper per form testimoni dinamici /////////////////////////////////

class _TestimoneFormData {
  final TextEditingController nomeController;
  final TextEditingController telefonoController;

  _TestimoneFormData({
    required this.nomeController,
    required this.telefonoController,
  });
}

class _FeritoFormData {
  final TextEditingController nomeController;
  final TextEditingController indirizzoController;
  final TextEditingController telefonoController;

  _FeritoFormData({
    required this.nomeController,
    required this.indirizzoController,
    required this.telefonoController,
  });
}

/// NUOVA PRATICA ///////////////////////////////////////////////////////

enum _GeoPermissionState {
  denied,
  deniedForever,
  whileInUse,
  always,
  unknown,
}

class NuovaPraticaIncidentePage extends StatefulWidget {
  const NuovaPraticaIncidentePage({super.key});

  @override
  State<NuovaPraticaIncidentePage> createState() =>
      _NuovaPraticaIncidentePageState();
}

class _NuovaPraticaIncidentePageState extends State<NuovaPraticaIncidentePage> {
  final _formKey = GlobalKey<FormState>();

  final _luogoController = TextEditingController();
  Position? _geoPosition;
  _GeoPermissionState _geoPermission = _GeoPermissionState.unknown;
  String? _geoErrorMessage;
  String? _addressReadable;
  bool _geoLoading = false;
  String? _geoMessage;
  final List<NominatimSuggestion> _suggestions = [];
  bool _suggestionsLoading = false;
  Timer? _suggestionDebounce;
  bool _validazioneContattiAttiva = true;
  bool? _otherObjectDamage;
  bool? _otherVehicleDamage;

  final _nomeAController = TextEditingController();
  final _cognomeAController = TextEditingController();
  final _targaAController = TextEditingController();
  final _assicurazioneAController = TextEditingController();

  final _telefonoAController = TextEditingController();
  final _emailAController = TextEditingController();
  final _indirizzoAController = TextEditingController();
  final _driverAZipController = TextEditingController();
  final _driverACityController = TextEditingController();

  final _nomeBController = TextEditingController();
  final _cognomeBController = TextEditingController();
  final _targaBController = TextEditingController();
  final _assicurazioneBController = TextEditingController();

  final _telefonoBController = TextEditingController();
  final _emailBController = TextEditingController();
  final _indirizzoBController = TextEditingController();
  final _driverBZipController = TextEditingController();
  final _driverBCityController = TextEditingController();

  final _descrizioneController = TextEditingController();
  final _damageVehicleAController = TextEditingController();
  final _damageVehicleBController = TextEditingController();

  final List<_TestimoneFormData> _testimoni = [];
  final List<_FeritoFormData> _feriti = [];

  final _notaVocaleAController = TextEditingController();
  final _notaVocaleBController = TextEditingController();

  late DateTime _dataOra;

  final ImagePicker _picker = ImagePicker();
  final SupabaseService _supabaseService = SupabaseService();
  String? _fotoLibrettoAPath;
  String? _fotoLibrettoBPath;
  Uint8List? _fotoLibrettoABytes;
  Uint8List? _fotoLibrettoBBytes;
  final List<Uint8List> _fotoDanniBytes = [];
  final List<String> _fotoDanniPaths = [];
  String? _draftClaimId;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _audioPlayerSub;
  bool _isRecordingAudio = false;
  String? _recordingFor;
  String? _currentRecordingPath;
  String? _playingNotaFor;
  String? _notaAudioAPath;
  String? _notaAudioBPath;

  @override
  void initState() {
    super.initState();
    debugPrint('[Geo] init NuovaPraticaIncidentePage');
    _audioPlayerSub = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playingNotaFor = null;
        });
      }
    });
    _dataOra = DateTime.now();
    _luogoController.addListener(_onLuogoChanged);
    _testimoni.add(
      _TestimoneFormData(
        nomeController: TextEditingController(),
        telefonoController: TextEditingController(),
      ),
    );
  }

  bool _isAnyCampoBCompilato() {
    return _nomeBController.text.trim().isNotEmpty ||
        _cognomeBController.text.trim().isNotEmpty ||
        _targaBController.text.trim().isNotEmpty ||
        _assicurazioneBController.text.trim().isNotEmpty ||
        _telefonoBController.text.trim().isNotEmpty ||
        _emailBController.text.trim().isNotEmpty;
  }

  Future<void> _impostaLuogoAutomatico() async {
    if (_geoLoading) return;

    debugPrint('[Geo] start geolocation request');
    setState(() {
      _geoLoading = true;
      _geoPosition = null;
      _geoPermission = _GeoPermissionState.unknown;
      _geoErrorMessage = null;
      _addressReadable = null;
      _geoMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[Geo] service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        _setGeoError(
          _GeoPermissionState.unknown,
          tx(context,
              'Attiva la localizzazione sul dispositivo per compilare automaticamente il luogo dell’incidente.'),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      _geoPermission = _mapPermission(permission);
      debugPrint(
        '[Geo] permission (initial): $permission -> ${_geoPermission.name}',
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        _geoPermission = _mapPermission(permission);
        debugPrint(
          '[Geo] permission (after request): $permission -> ${_geoPermission.name}',
        );
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setGeoError(
          _geoPermission,
          tx(context,
              'Consenti la posizione in Safari per compilare automaticamente il luogo dell’incidente.'),
        );
        return;
      }

      debugPrint('[Geo] calling getCurrentPosition() ...');
      Position? pos;
      String? lastErrorCode;

      try {
        pos = await _getPositionWithTimeout(
          accuracy: LocationAccuracy.high,
          timeout: const Duration(seconds: 9),
        );
      } on TimeoutException catch (e) {
        lastErrorCode = 'timeout_primary';
        debugPrint('[Geo] timeout first attempt: $e');
      } catch (e, st) {
        lastErrorCode = 'error_primary';
        debugPrint('[Geo] exception first attempt: $e\n$st');
      }

      if (pos == null) {
        debugPrint('[Geo] fallback geolocation attempt (balanced accuracy)');
        try {
          pos = await _getPositionWithTimeout(
            accuracy: LocationAccuracy.medium,
            timeout: const Duration(seconds: 5),
          );
        } on TimeoutException catch (e) {
          lastErrorCode = 'timeout_secondary';
          debugPrint('[Geo] timeout second attempt: $e');
        } catch (e, st) {
          lastErrorCode = 'error_secondary';
          debugPrint('[Geo] exception second attempt: $e\n$st');
        }
      }

      if (pos == null) {
        _setGeoError(
          _geoPermission,
          tx(context,
              'Non siamo riusciti a ottenere la posizione. Verifica che la geolocalizzazione sia attiva e riprova.'),
        );
        return;
      }

      final position = pos;

      debugPrint(
        '[Geo] position acquired lat=${position.latitude}, lon=${position.longitude}',
      );

      final indirizzo = await getIndirizzoDaGps(position: position);
      if (!mounted) return;
      setState(() {
        _geoLoading = false;
        _geoPosition = position;
        _geoErrorMessage = null;
        _addressReadable = null;
        if (_luogoController.text.trim().isEmpty) {
          _luogoController.text = indirizzo ??
              'LAT: ${position.latitude.toStringAsFixed(5)}, '
                  'LNG: ${position.longitude.toStringAsFixed(5)}';
        }
      });
      unawaited(_caricaIndirizzoDaPosizione(position));
    } catch (e, st) {
      debugPrint('[Geo] geolocation exception: $e\n$st');
      _setGeoError(
        _geoPermission,
        tx(context,
            'Non siamo riusciti a ottenere la posizione. Verifica che la geolocalizzazione sia attiva e riprova.'),
      );
    }
  }

  Future<Position> _getPositionWithTimeout({
    required LocationAccuracy accuracy,
    required Duration timeout,
  }) {
    debugPrint(
        '[Geo] getCurrentPosition acc=$accuracy timeout=${timeout.inSeconds}s');
    return Geolocator.getCurrentPosition(
      desiredAccuracy: accuracy,
    ).timeout(timeout);
  }

  void _setGeoError(
    _GeoPermissionState permissionState,
    String message,
  ) {
    debugPrint(
      '[Geo] error: $message (permission=$permissionState)',
    );
    if (!mounted) return;
    setState(() {
      _geoLoading = false;
      _geoPosition = null;
      _geoPermission = permissionState;
      _geoErrorMessage = message;
      _addressReadable = null;
      _geoMessage = message;
    });
  }

  _GeoPermissionState _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
        return _GeoPermissionState.denied;
      case LocationPermission.deniedForever:
        return _GeoPermissionState.deniedForever;
      case LocationPermission.whileInUse:
        return _GeoPermissionState.whileInUse;
      case LocationPermission.always:
        return _GeoPermissionState.always;
      default:
        return _GeoPermissionState.unknown;
    }
  }

  Future<void> _caricaIndirizzoDaPosizione(Position pos) async {
    debugPrint(
      '[Geo] reverse geocoding start lat=${pos.latitude}, lon=${pos.longitude}',
    );
    setState(() {
      _addressReadable = null;
    });

    final headers = <String, String>{
      'Accept-Language': Localizations.localeOf(context).toLanguageTag(),
    };
    if (!kIsWeb) {
      headers['User-Agent'] = 'cid-digitale-client/1.0';
    }

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2'
      '&addressdetails=1&lat=${pos.latitude}&lon=${pos.longitude}',
    );

    try {
      final res = await http.get(uri, headers: headers).timeout(
            const Duration(seconds: 10),
          );
      debugPrint('[Geo] reverse geocoding status: ${res.statusCode}');

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = _formatNominatimAddress(
          body['address'] as Map<String, dynamic>?,
        );
        setState(() {
          if (addr != null && addr.isNotEmpty) {
            _addressReadable = addr;
            debugPrint('[Geo] reverse geocoding success: $addr');
            final current = _luogoController.text.trim();
            if (current.isEmpty || current.startsWith('LAT:')) {
              _luogoController.text = addr;
            }
          } else {
            _addressReadable = null;
            debugPrint('[Geo] reverse geocoding address unavailable');
          }
        });
      } else {
        setState(() => _addressReadable = null);
      }
    } catch (e) {
      debugPrint('[Geo] reverse geocoding error: $e');
      if (!mounted) return;
      setState(() => _addressReadable = null);
    }
  }

  String? _formatNominatimAddress(Map<String, dynamic>? address) {
    if (address == null || address.isEmpty) return null;

    String? firstNonEmpty(List<String?> values) {
      for (final value in values) {
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    final road = firstNonEmpty([
      address['road'] as String?,
      address['pedestrian'] as String?,
      address['path'] as String?,
    ]);
    final houseNumber = address['house_number'] as String?;
    final postcode = address['postcode'] as String?;
    final city = firstNonEmpty([
      address['city'] as String?,
      address['town'] as String?,
      address['village'] as String?,
      address['municipality'] as String?,
    ]);
    final state = address['state'] as String?;
    final country = address['country'] as String?;

    final parts = <String>[];

    final streetParts = [
      if (road != null) road,
      if (houseNumber != null && houseNumber.trim().isNotEmpty)
        houseNumber.trim(),
    ];
    final streetLine = streetParts.join(' ').trim();
    if (streetLine.isNotEmpty) {
      parts.add(streetLine);
    }

    final cityParts = [
      if (postcode != null && postcode.trim().isNotEmpty) postcode.trim(),
      if (city != null) city,
    ];
    final cityLine = cityParts.join(' ').trim();
    if (cityLine.isNotEmpty) {
      parts.add(cityLine);
    }

    if (state != null && state.trim().isNotEmpty) {
      parts.add(state.trim());
    }
    if (country != null && country.trim().isNotEmpty) {
      parts.add(country.trim());
    }

    final formatted = parts.join(', ');
    return formatted.isEmpty ? null : formatted;
  }

  Widget _buildGeoActions() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _geoLoading ? null : _impostaLuogoAutomatico,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          icon: _geoLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location, size: 18),
          label: Text(
            tx(context, 'Usa la mia posizione'),
            style: theme.textTheme.bodySmall?.copyWith(
              color:
                  _geoLoading ? theme.disabledColor : theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _apriMappa,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: Text(
            tx(context, 'Apri mappa'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        if (_geoMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _geoMessage!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        if (_suggestionsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: _suggestions
                  .map(
                    (s) => ListTile(
                      dense: true,
                      title: Text(
                        s.displayName,
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () => _selezionaSuggerimento(s),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _luogoController.dispose();

    _nomeAController.dispose();
    _cognomeAController.dispose();
    _targaAController.dispose();
    _assicurazioneAController.dispose();
    _telefonoAController.dispose();
    _emailAController.dispose();
    _indirizzoAController.dispose();
    _driverAZipController.dispose();
    _driverACityController.dispose();

    _nomeBController.dispose();
    _cognomeBController.dispose();
    _targaBController.dispose();
    _assicurazioneBController.dispose();
    _telefonoBController.dispose();
    _emailBController.dispose();
    _indirizzoBController.dispose();
    _driverBZipController.dispose();
    _driverBCityController.dispose();

    _descrizioneController.dispose();
    _damageVehicleAController.dispose();
    _damageVehicleBController.dispose();

    _notaVocaleAController.dispose();
    _notaVocaleBController.dispose();
    _suggestionDebounce?.cancel();
    _luogoController.removeListener(_onLuogoChanged);

    for (final t in _testimoni) {
      t.nomeController.dispose();
      t.telefonoController.dispose();
    }
    for (final f in _feriti) {
      f.nomeController.dispose();
      f.indirizzoController.dispose();
      f.telefonoController.dispose();
    }
    unawaited(_audioPlayerSub?.cancel());
    if (_isRecordingAudio) {
      unawaited(_audioRecorder.stop());
    }
    _audioRecorder.dispose();
    unawaited(_audioPlayer.stop());
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _yesNoRow({
    required String title,
    required bool? value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.yes),
                  value: true,
                  groupValue: value,
                  onChanged: (_) => onChanged(true),
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.no),
                  value: false,
                  groupValue: value,
                  onChanged: (_) => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _mostraSnack(String testo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(testo)),
    );
  }

  void _onLuogoChanged() {
    final query = _luogoController.text.trim();
    if (query.length < 3) {
      _suggestionDebounce?.cancel();
      if (_suggestions.isNotEmpty || _suggestionsLoading) {
        setState(() {
          _suggestions.clear();
          _suggestionsLoading = false;
        });
      }
      return;
    }

    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() {
      _suggestionsLoading = true;
    });
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5');
      final res = await http.get(uri, headers: {
        'Accept-Language': Localizations.localeOf(context).toLanguageTag(),
        'User-Agent': 'cid-digitale-client/1.0',
      }).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
        final parsed = data
            .take(5)
            .map((item) =>
                NominatimSuggestion.fromJson(item as Map<String, dynamic>))
            .where((s) => s.displayName.isNotEmpty)
            .toList();
        setState(() {
          _suggestions
            ..clear()
            ..addAll(parsed);
          _suggestionsLoading = false;
        });
      } else {
        setState(() {
          _suggestions..clear();
          _suggestionsLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions..clear();
        _suggestionsLoading = false;
      });
    }
  }

  Future<void> _apriMappa() async {
    final pos = _geoPosition;
    final uri = pos != null
        ? Uri.parse(
            'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}')
        : Uri.parse('https://www.google.com/maps');
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      _mostraSnack(tx(context, 'Impossibile aprire Google Maps.'));
    }
  }

  void _selezionaSuggerimento(NominatimSuggestion s) {
    final position = Position(
      latitude: s.lat,
      longitude: s.lon,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: false,
    );

    setState(() {
      _luogoController.text = s.displayName;
      _geoPosition = position;
      _addressReadable = s.displayName;
      _suggestions.clear();
      _suggestionsLoading = false;
      _geoMessage = null;
    });
  }

  String _ensureDraftId() {
    _draftClaimId ??= DateTime.now().millisecondsSinceEpoch.toString();
    return _draftClaimId!;
  }

  bool _hasParsedData(Map<String, String?> data, String? plate) {
    if (plate != null && plate.trim().isNotEmpty) return true;
    return data.values.any((v) => v != null && v!.trim().isNotEmpty);
  }

  bool _shouldFallbackOcr(String? text, String? plate) {
    final textLen = text?.trim().length ?? 0;
    if (textLen < 15) return true;
    final digitCount = RegExp(r'\d').allMatches(plate ?? '').length;
    if (plate == null || digitCount < 4) return true;
    return false;
  }

  String? _selectBetterPlate(String? current, String? candidate) {
    if (candidate == null) return current;
    if (current == null || current.isEmpty) return candidate;
    final currentDigits = RegExp(r'\d').allMatches(current).length;
    final candidateDigits = RegExp(r'\d').allMatches(candidate).length;
    return candidateDigits > currentDigits ? candidate : current;
  }

  List<_OcrBlock> _filterBlocksInRegion(
    List<_OcrBlock> blocks, {
    double xMin = 0,
    double xMax = 1,
    double yMin = 0,
    double yMax = 1,
  }) {
    return blocks
        .where(
          (b) => b.nx >= xMin && b.nx <= xMax && b.ny >= yMin && b.ny <= yMax,
        )
        .toList();
  }

  String? _plateFromBlocks(List<_OcrBlock> blocks) {
    final region = _filterBlocksInRegion(blocks, xMin: 0.55, yMax: 0.35);
    String? best;
    for (final b in region) {
      final p = extractSwissPlate(b.text);
      best = _selectBetterPlate(best, p);
    }
    return best;
  }

  Map<String, String?> _extraFromBlocks(List<_OcrBlock> blocks) {
    final owner = _filterBlocksInRegion(blocks, xMax: 0.55, yMax: 0.45);
    final addr =
        _filterBlocksInRegion(blocks, xMax: 0.6, yMin: 0.35, yMax: 0.75);
    final ins =
        _filterBlocksInRegion(blocks, xMax: 0.8, yMin: 0.35, yMax: 0.85);

    final buffer = StringBuffer();
    if (owner.isNotEmpty) buffer.writeln(owner.map((b) => b.text).join('\n'));
    if (addr.isNotEmpty) buffer.writeln(addr.map((b) => b.text).join('\n'));
    if (ins.isNotEmpty) buffer.writeln(ins.map((b) => b.text).join('\n'));

    final combined = buffer.toString().trim();
    if (combined.isEmpty) return {};
    final parsed = estraiNomeAssicurazioneIndirizzoDaTesto(combined);
    return parsed;
  }

  Map<String, String?> _extractSwissFieldsFromAnchors(List<_OcrBlock> blocks) {
    if (blocks.isEmpty) return {};
    Map<String, String?> result = {};

    _OcrBlock? findAnchor(List<String> pats, {double? xMax}) {
      final ups = pats.map((p) => p.toUpperCase()).toList();
      for (final b in blocks) {
        if (xMax != null && b.nx > xMax) continue;
        final up = b.text.toUpperCase();
        if (ups.any((p) => up.contains(p))) return b;
      }
      return null;
    }

    List<_OcrBlock> rightOf(_OcrBlock anchor,
        {double dy = 0.15, double dx = 0.05}) {
      return blocks
          .where((b) =>
              b.nx > anchor.nx + dx &&
              (b.ny - anchor.ny).abs() <= dy &&
              b.ny >= anchor.ny - dy)
          .toList()
        ..sort((a, b) => a.nx.compareTo(b.nx));
    }

    // Campo 15 - targa
    final anchor15 =
        findAnchor(['15', 'SCHILD', 'PLAQUE', 'TARGA', 'NUMMER'], xMax: 0.9);
    if (anchor15 != null) {
      final candidates = rightOf(anchor15);
      String? bestPlate;
      for (final b in candidates) {
        bestPlate = _selectBetterPlate(bestPlate, extractSwissPlate(b.text));
      }
      result['targa'] = bestPlate;
      debugPrint('Anchor 15 found -> plate: ${bestPlate ?? '-'}');
    } else {
      debugPrint('Anchor 15 not found');
    }

    // Campo 09 - assicurazione
    final anchor09 = findAnchor(
      ['09', 'VERSICHERUNG', 'ASSURANCE', 'ASSICURAZIONE', 'ASSICURANZA'],
      xMax: 0.75,
    );
    if (anchor09 != null) {
      final candidates = rightOf(anchor09, dy: 0.2);
      const providers = [
        'AXA',
        'ALLIANZ',
        'ZURICH',
        'GENERALI',
        'HELVETIA',
        'MOBILIAR',
        'VAUDOISE',
        'BALOISE'
      ];
      String? bestIns;
      for (final b in candidates) {
        final up = b.text.toUpperCase();
        if (providers.any((p) => up.contains(p))) {
          bestIns = b.text.trim();
          break;
        }
        if (_isPlausibleInsurance(b.text)) {
          bestIns ??= b.text.trim();
        }
      }
      result['assicurazione'] = bestIns;
      debugPrint('Anchor 09 found -> assicurazione: ${bestIns ?? '-'}');
    } else {
      debugPrint('Anchor 09 not found');
    }

    // Campi 01-06 - anagrafica
    final anchor0106 = findAnchor([
      '01',
      '02',
      '03',
      '04',
      '05',
      '06',
      'NAME',
      'NOM',
      'COGNOME',
      'VORNAME',
      'PRENOM',
      'PRENOMS',
      'DOMICILE',
      'DOMICILIO',
      'DOMICIL'
    ], xMax: 0.65);
    if (anchor0106 != null) {
      final region = blocks
          .where((b) =>
              b.nx > anchor0106.nx + 0.05 &&
              b.ny >= anchor0106.ny - 0.02 &&
              b.ny <= anchor0106.ny + 0.45)
          .toList()
        ..sort((a, b) => a.ny.compareTo(b.ny));
      final lines = region.map((b) => b.text.trim()).toList();
      String? cognome;
      String? nome;
      String? indirizzo;
      String? cap;
      String? city;
      if (lines.isNotEmpty && _isPlausibleName(lines.first)) {
        cognome = lines.first;
      }
      if (lines.length >= 2 && _isPlausibleName(lines[1])) {
        nome = lines[1];
      }
      for (final l in lines.skip(2)) {
        if (indirizzo == null && _isPlausibleAddress(l)) {
          indirizzo = l;
          continue;
        }
        final m =
            RegExp(r'\b([0-9]{4})\s+([A-Za-zÀ-ÿ\-\s]{2,})\b').firstMatch(l);
        if (m != null && cap == null && city == null) {
          cap = m.group(1);
          city = m.group(2)?.trim();
        }
      }
      if (cognome != null) result['cognome'] = cognome;
      if (nome != null) result['nome'] = nome;
      if (indirizzo != null) result['indirizzo'] = indirizzo;
      if (cap != null) result['cap'] = cap;
      if (city != null) result['city'] = city;
      debugPrint(
          'Anchor 01-06 found -> ${result['cognome'] ?? '-'} | ${result['nome'] ?? '-'} | ${indirizzo ?? '-'} | ${cap ?? '-'} ${city ?? '-'}');
    } else {
      debugPrint('Anchor 01-06 not found');
    }

    return result;
  }

  Future<_CloudOcrResult> _callCloudOcr(List<int> bytes) async {
    final b64 = base64Encode(bytes);
    debugPrint('OCR cloud invoke start - base64 length: ${b64.length}');
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ocr-libretto-cloud',
        body: {'imageBase64': b64},
      );
      debugPrint('OCR cloud raw response: ${res.data}');
      final data = res.data;
      List<_OcrBlock> blocks = [];
      if (data is Map && data['blocks'] is List) {
        final rawBlocks = (data['blocks'] as List)
            .whereType<Map>()
            .where((b) =>
                b['text'] != null &&
                b['x'] != null &&
                b['y'] != null &&
                b['w'] != null &&
                b['h'] != null)
            .toList();
        double maxX = 1;
        double maxY = 1;
        for (final b in rawBlocks) {
          final right = (b['x'] as num).toDouble() + (b['w'] as num).toDouble();
          final bottom =
              (b['y'] as num).toDouble() + (b['h'] as num).toDouble();
          if (right > maxX) maxX = right;
          if (bottom > maxY) maxY = bottom;
        }
        blocks = rawBlocks
            .map((b) {
              final x = (b['x'] as num).toDouble();
              final y = (b['y'] as num).toDouble();
              final w = (b['w'] as num).toDouble();
              final h = (b['h'] as num).toDouble();
              final cx = x + w / 2;
              final cy = y + h / 2;
              return _OcrBlock(
                text: (b['text'] as String).trim(),
                x: x,
                y: y,
                w: w,
                h: h,
                nx: cx / maxX,
                ny: cy / maxY,
              );
            })
            .where((b) => b.text.isNotEmpty)
            .toList();
      }
      if (data is Map) {
        return _CloudOcrResult(
          success: data['success'] == true,
          text: (data['text'] as String?)?.trim(),
          error: data['error']?.toString(),
          details: data['details']?.toString(),
          status:
              data['googleStatus'] is int ? data['googleStatus'] as int : null,
          raw: data,
          blocks: blocks,
        );
      }
    } catch (e, st) {
      debugPrint('OCR cloud error: $e\n$st');
      return _CloudOcrResult(
        success: false,
        error: 'exception',
        details: e.toString(),
      );
    }
    return _CloudOcrResult(success: false, error: 'invalid_response');
  }

  bool _applyLibrettoParsedData({
    required String quale,
    String? nome,
    String? cognome,
    String? indirizzo,
    String? cap,
    String? city,
    String? targa,
    String? assicurazione,
  }) {
    debugPrint('OCR apply target=$quale parsed={'
        'nome:$nome, cognome:$cognome, indirizzo:$indirizzo, cap:$cap, city:$city, '
        'targa:$targa, assicurazione:$assicurazione}');

    final isA = quale == 'A';
    final nomeCtrl = isA ? _nomeAController : _nomeBController;
    final cognomeCtrl = isA ? _cognomeAController : _cognomeBController;
    final indirizzoCtrl = isA ? _indirizzoAController : _indirizzoBController;
    final zipCtrl = isA ? _driverAZipController : _driverBZipController;
    final cityCtrl = isA ? _driverACityController : _driverBCityController;
    final targaCtrl = isA ? _targaAController : _targaBController;
    final assicurazioneCtrl =
        isA ? _assicurazioneAController : _assicurazioneBController;

    bool changed = false;

    void writeIfBetter(
      TextEditingController ctrl,
      String? value, {
      bool Function(String)? isBetter,
      bool Function(String?)? validator,
      required String label,
    }) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      if (validator != null && !validator(trimmed)) return;
      final current = ctrl.text.trim();
      if (current.isEmpty) {
        ctrl.text = trimmed;
        debugPrint('write $label = $trimmed');
        changed = true;
        return;
      }
      if (isBetter != null && isBetter(trimmed)) {
        ctrl.text = trimmed;
        debugPrint('replace $label = $trimmed');
        changed = true;
      }
    }

    writeIfBetter(nomeCtrl, nome,
        validator: _isPlausibleName, label: '${isA ? 'A' : 'B'} nome');
    writeIfBetter(cognomeCtrl, cognome,
        validator: _isPlausibleName, label: '${isA ? 'A' : 'B'} cognome');
    writeIfBetter(indirizzoCtrl, indirizzo,
        validator: _isPlausibleAddress, label: '${isA ? 'A' : 'B'} indirizzo');
    writeIfBetter(zipCtrl, cap,
        validator: _isPlausibleZip, label: '${isA ? 'A' : 'B'} cap');
    writeIfBetter(cityCtrl, city,
        validator: _isPlausibleCity, label: '${isA ? 'A' : 'B'} city');
    writeIfBetter(
      assicurazioneCtrl,
      assicurazione,
      validator: _isPlausibleInsurance,
      isBetter: (val) => val.length > assicurazioneCtrl.text.trim().length,
      label: '${isA ? 'A' : 'B'} assicurazione',
    );
    writeIfBetter(
      targaCtrl,
      targa,
      validator: (val) => val != null && extractSwissPlate(val) != null,
      isBetter: (val) =>
          RegExp(r'\d').allMatches(val).length >
          RegExp(r'\d').allMatches(targaCtrl.text).length,
      label: '${isA ? 'A' : 'B'} targa',
    );

    return changed;
  }

  Future<void> _pickAndUploadImage(
      {required String kind, String? quale}) async {
    final claimId = _ensureDraftId();
    if (kind == 'damage') {
      debugPrint(
          '[Damage] pick/upload start platform=${kIsWeb ? 'web' : 'mobile'}');
    }
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final name = picked.name.isNotEmpty
          ? picked.name
          : '${kind}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Conferma upload'),
          content: SizedBox(
            height: 240,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Carica'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      debugPrint(
        'Foto $kind selezionata (quale: ${quale ?? '-'}) nome: $name',
      );
      debugPrint(
          '[Damage] bytes length=${bytes.length} platform=${kIsWeb ? 'web' : 'mobile'} kind=$kind');

      if (kind == 'libretto' && quale != null) {
        setState(() {
          if (quale == 'A') {
            _fotoLibrettoABytes = bytes;
            _fotoLibrettoAPath = null;
          } else {
            _fotoLibrettoBBytes = bytes;
            _fotoLibrettoBPath = null;
          }
        });
      }

      // OCR disattivato: il libretto viene solo allegato e mostrato in preview.

      debugPrint(
          '[DamageUpload] start bucket=claim_attachments path=claims/$claimId/$kind/<ts>_$name');
      final uploadedUrl = await _supabaseService.uploadClaimImageBytes(
        claimId: claimId,
        bytes: bytes,
        filename: name,
        contentType: 'image/jpeg',
        kind: kind,
      );
      debugPrint('Upload $kind completato -> $uploadedUrl');

      if (kind == 'damage') {
        setState(() {
          _fotoDanniBytes.add(bytes);
          _fotoDanniPaths.add(uploadedUrl);
        });
        debugPrint('[Damage] state updated bytes=${_fotoDanniBytes.length} '
            'urls=${_fotoDanniPaths.length}');
      }

      _mostraSnack('Foto caricata');
      await caricaIncidenti();
      debugPrint('[Damage] refresh dettaglio/lista dopo upload ($kind)');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _mostraSnack('Errore upload foto: $e');
    }
  }

  void _removeDamagePhoto(int index) {
    if (index < 0 || index >= _fotoDanniPaths.length) return;
    final removedUrl = _fotoDanniPaths[index];
    setState(() {
      _fotoDanniPaths.removeAt(index);
      if (index < _fotoDanniBytes.length) {
        _fotoDanniBytes.removeAt(index);
      }
    });
    debugPrint('[Damage] removed index=$index url=$removedUrl '
        'remaining=${_fotoDanniPaths.length}');
  }

  String? _validateEmail(String? value) {
    if (!_validazioneContattiAttiva) return null;
    if (value == null || value.trim().isEmpty) return null;
    final email = value.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return txStatic('Email non valida');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (!_validazioneContattiAttiva) return null;
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) {
      return txStatic('Numero di telefono non valido');
    }
    return null;
  }

  Future<String> _creaPercorsoNota(String quale) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/nota_${quale}_$timestamp.m4a';
  }

  Future<void> _startRecordingNota(String quale) async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _mostraSnack(
          'Per registrare la nota vocale devi concedere il permesso microfono.',
        );
        return;
      }
      final path = await _creaPercorsoNota(quale);
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );
      await _audioRecorder.start(config, path: path);
      if (!mounted) return;
      setState(() {
        _isRecordingAudio = true;
        _recordingFor = quale;
        _currentRecordingPath = path;
      });
      _mostraSnack('Registrazione nota vocale $quale in corso...');
    } catch (_) {
      _mostraSnack('Impossibile avviare la registrazione audio.');
    }
  }

  Future<void> _stopRecordingNota() async {
    if (!_isRecordingAudio) return;
    final recordedFor = _recordingFor;
    try {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecordingAudio = false;
        _recordingFor = null;
        final savedPath = path ?? _currentRecordingPath;
        _currentRecordingPath = null;
        if (savedPath != null && recordedFor != null) {
          if (recordedFor == 'A') {
            _notaAudioAPath = savedPath;
          } else {
            _notaAudioBPath = savedPath;
          }
        }
      });
      if (recordedFor != null) {
        _mostraSnack('Nota vocale $recordedFor salvata.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRecordingAudio = false;
        _recordingFor = null;
        _currentRecordingPath = null;
      });
      _mostraSnack('Errore durante la chiusura della registrazione.');
    }
  }

  Future<void> _toggleRecordingNota(String quale) async {
    if (_isRecordingAudio && _recordingFor != quale) {
      _mostraSnack(
        'Termina prima la registrazione in corso prima di avviarne una nuova.',
      );
      return;
    }
    if (_isRecordingAudio) {
      await _stopRecordingNota();
    } else {
      await _startRecordingNota(quale);
    }
  }

  Future<void> _riproduciNota(String quale) async {
    final path = quale == 'A' ? _notaAudioAPath : _notaAudioBPath;
    if (path == null || path.isEmpty) {
      _mostraSnack('Non è presente una nota vocale da riprodurre.');
      return;
    }
    final file = File(path);
    if (!file.existsSync()) {
      _mostraSnack('Il file audio della nota non è più disponibile.');
      return;
    }
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));
      if (!mounted) return;
      setState(() {
        _playingNotaFor = quale;
      });
    } catch (_) {
      _mostraSnack('Errore nella riproduzione della nota vocale.');
    }
  }

  Future<void> _stopRiproduzione() async {
    await _audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _playingNotaFor = null;
    });
  }

  Future<void> _rimuoviNota(String quale) async {
    final path = quale == 'A' ? _notaAudioAPath : _notaAudioBPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      if (quale == 'A') {
        _notaAudioAPath = null;
      } else {
        _notaAudioBPath = null;
      }
    });
  }

  Widget _buildAudioNotaControls(String quale) {
    final bool isRecording = _isRecordingAudio && _recordingFor == quale;
    final bool hasAudio =
        (quale == 'A' ? _notaAudioAPath : _notaAudioBPath)?.isNotEmpty ?? false;
    final bool isPlaying = _playingNotaFor == quale;
    final String label = quale == 'A' ? 'conducente A' : 'conducente B';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nota vocale $label',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _toggleRecordingNota(quale),
              icon: Icon(isRecording ? Icons.stop : Icons.mic),
              label: Text(
                isRecording
                    ? tx(context, 'Ferma registrazione')
                    : tx(context, 'Registra nota vocale'),
              ),
            ),
            if (hasAudio)
              OutlinedButton.icon(
                onPressed: () =>
                    isPlaying ? _stopRiproduzione() : _riproduciNota(quale),
                icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(
                  isPlaying
                      ? tx(context, 'Ferma riproduzione')
                      : tx(context, 'Riproduci nota'),
                ),
              ),
            if (hasAudio)
              OutlinedButton.icon(
                onPressed: () => _rimuoviNota(quale),
                icon: const Icon(Icons.delete_outline),
                label: Text(tx(context, 'Elimina nota')),
              ),
          ],
        ),
        if (isRecording)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Registrazione in corso... parla vicino al microfono.',
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          )
        else if (hasAudio)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              isPlaying
                  ? 'Riproduzione in corso...'
                  : 'Nota vocale salvata. Puoi riascoltarla o eliminarla.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
      ],
    );
  }

  Future<void> _leggiDatiDaLibretto(String imagePath, String quale) async {
    try {
      debugPrint('OCR libretto start ($quale) path: $imagePath');
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final fullText = recognizedText.text;
      debugPrint(
          'OCR libretto ($quale) testo: ${fullText.replaceAll('\n', ' ')}');

      final targaTrovata = estraiTargaDaTesto(fullText);
      final extra = estraiNomeAssicurazioneIndirizzoDaTesto(
        fullText,
        blocchi: recognizedText.blocks.map((b) => b.text).toList(),
      );
      final nomeTrovato = extra['nome'];
      final cognomeTrovato = extra['cognome'];
      final assicurazioneTrovata = extra['assicurazione'];
      final indirizzoTrovato = extra['indirizzo'];
      final capTrovato = extra['cap'];
      final cittaTrovata = extra['city'];
      final marcaTrovata = extra['brand'];
      final modelloTrovato = extra['model'];

      // Secondo pass: prova a trovare la targa nei singoli blocchi (più puliti)
      String? targaSecondoPass;
      for (final block in recognizedText.blocks) {
        targaSecondoPass = estraiTargaDaTesto(block.text);
        if (targaSecondoPass != null) break;
      }
      final targaFinale = targaTrovata ?? targaSecondoPass;
      debugPrint('Targa OCR ($quale): ${targaFinale ?? 'non trovata'}');
      debugPrint(
        'OCR dati libretto -> nome: ${nomeTrovato ?? '-'}, cognome: ${cognomeTrovato ?? '-'}, cap: ${capTrovato ?? '-'}, city: ${cittaTrovata ?? '-'}, assicurazione: ${assicurazioneTrovata ?? '-'}, marca: ${marcaTrovata ?? '-'}, modello: ${modelloTrovato ?? '-'}',
      );

      final parsed = _applyLibrettoParsedData(
        quale: quale,
        nome: nomeTrovato,
        cognome: cognomeTrovato,
        indirizzo: indirizzoTrovato,
        cap: capTrovato,
        city: cittaTrovata,
        targa: targaFinale,
        assicurazione: assicurazioneTrovata,
      );

      final campoTarga = quale == 'A'
          ? _targaAController.text.trim()
          : _targaBController.text.trim();
      debugPrint('Campo targa $quale post OCR: '
          '${campoTarga.isEmpty ? 'vuoto' : campoTarga}');

      final parsedAny = parsed ||
          _hasParsedData(
            {
              'nome': nomeTrovato,
              'cognome': cognomeTrovato,
              'indirizzo': indirizzoTrovato,
              'cap': capTrovato,
              'city': cittaTrovata,
              'assicurazione': assicurazioneTrovata,
            },
            targaFinale,
          );

      if (!parsedAny) {
        _mostraSnack(
          'Nessun dato riconosciuto dal libretto.',
        );
      } else {
        final buffer = StringBuffer('Ho letto la foto:');
        if (targaFinale != null) buffer.write('\n- Targa: $targaFinale');
        if (nomeTrovato != null) buffer.write('\n- Nome: $nomeTrovato');
        if (assicurazioneTrovata != null) {
          buffer.write('\n- Assicurazione: $assicurazioneTrovata');
        }
        if (indirizzoTrovato != null) {
          buffer.write('\n- Indirizzo: $indirizzoTrovato');
        }
        _mostraSnack(buffer.toString());
      }
    } catch (_) {
      _mostraSnack('Errore durante la lettura del libretto.');
    }
  }

  Future<void> _leggiTargaDaFotoDanno(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final fullText = recognizedText.text;
      final targaTrovata = estraiTargaDaTesto(fullText);
      debugPrint('OCR foto danno testo: ${fullText.replaceAll('\n', ' ')}');
      debugPrint('Targa da foto danno: ${targaTrovata ?? 'non trovata'}');

      if (!mounted) return;

      if (targaTrovata == null) {
        _mostraSnack(
          'Foto del danno aggiunta, ma non ho trovato chiaramente una targa. Prova una foto più vicina alla targa.',
        );
        return;
      }

      final targaA = _targaAController.text.trim();
      final targaB = _targaBController.text.trim();

      if (targaA.isEmpty && targaB.isNotEmpty) {
        _targaAController.text = targaTrovata;
        _mostraSnack(
          'Ho riconosciuto la targa "$targaTrovata" e l\'ho messa in A.',
        );
        return;
      }
      if (targaB.isEmpty && targaA.isNotEmpty) {
        _targaBController.text = targaTrovata;
        _mostraSnack(
          'Ho riconosciuto la targa "$targaTrovata" e l\'ho messa in B.',
        );
        return;
      }

      if (targaA.isEmpty && targaB.isEmpty) {
        final scelta = await showDialog<String>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Targa trovata'),
              content: Text(
                'Ho trovato la targa:\n\n$targaTrovata\n\nA quale veicolo vuoi assegnarla?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('A'),
                  child: Text(AppLocalizations.of(context)!.driverA),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('B'),
                  child: Text(tx(context, 'Conducente B')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Annulla'),
                ),
              ],
            );
          },
        );

        if (scelta == 'A') {
          _targaAController.text = targaTrovata;
          _mostraSnack('Targa "$targaTrovata" assegnata al veicolo A.');
        } else if (scelta == 'B') {
          _targaBController.text = targaTrovata;
          _mostraSnack('Targa "$targaTrovata" assegnata al veicolo B.');
        } else {
          _mostraSnack(
            'Ho trovato la targa "$targaTrovata", ma non l\'ho assegnata.',
          );
        }
        return;
      }

      _mostraSnack(
        'Ho trovato la targa "$targaTrovata", ma i campi A e B hanno già una targa. Controlla e correggi se serve.',
      );
    } catch (_) {
      if (!mounted) return;
      _mostraSnack(
        'Errore durante il riconoscimento della targa dalla foto del danno.',
      );
    }
  }

  Future<void> _scattaFotoLibretto(String quale) async {
    if (kIsWeb) {
      await _pickAndUploadImage(kind: 'libretto', quale: quale);
      return;
    }
    try {
      final result = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (_) => ScannerLibrettoPage(quale: quale),
        ),
      );
      if (result == null) return;

      if (result is Map && result['kind'] == 'libretto_photo') {
        final bytes = result['bytes'];
        final filename = result['filename']?.toString();
        if (bytes is Uint8List) {
          setState(() {
            if (quale == 'A') {
              _fotoLibrettoABytes = bytes;
              _fotoLibrettoAPath = filename;
            } else {
              _fotoLibrettoBBytes = bytes;
              _fotoLibrettoBPath = filename;
            }
          });
          _mostraSnack('Foto libretto caricata.');
        }
        return;
      }

      if (result is! OcrLibrettoResult) return;

      setState(() {
        if (quale == 'A') {
          _fotoLibrettoAPath = result.path;
          _fotoLibrettoABytes = null;
        } else {
          _fotoLibrettoBPath = result.path;
          _fotoLibrettoBBytes = null;
        }
      });

      _mostraSnack('Foto libretto $quale caricata.');
    } catch (_) {
      _mostraSnack('Errore nello scatto della foto del libretto $quale.');
    }
  }

  Future<void> _scattaFotoDanno() async {
    debugPrint('[Damage] add photo tapped');
    if (kIsWeb) {
      await _pickAndUploadImage(kind: 'damage');
      return;
    }
    try {
      final foto =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (foto == null) return;

      final claimId = _ensureDraftId();
      final bytes = await File(foto.path).readAsBytes();
      debugPrint(
          '[DamageUpload] start bucket=claim_attachments path=claims/$claimId/damage/<ts>_${path.basename(foto.path)}');
      final uploadedUrl = await _supabaseService.uploadClaimImageBytes(
        claimId: claimId,
        bytes: bytes,
        filename: path.basename(foto.path),
        contentType: 'image/jpeg',
        kind: 'damage',
      );
      debugPrint('Upload foto danno -> $uploadedUrl');

      setState(() {
        _fotoDanniBytes.add(bytes);
        _fotoDanniPaths.add(uploadedUrl);
      });
      debugPrint('[Damage] state updated bytes=${_fotoDanniBytes.length} '
          'urls=${_fotoDanniPaths.length}');

      _mostraSnack('Foto caricata');
      await salvaIncidenti();
      await caricaIncidenti();
      debugPrint('[Damage] refresh dettaglio/lista dopo upload (mobile)');
      if (mounted) setState(() {});

      _mostraSnack(
        'Foto del danno aggiunta. Provo a leggere la targa con l\'AI...',
      );
      await _leggiTargaDaFotoDanno(foto.path);
    } catch (_) {
      _mostraSnack('Errore nello scatto della foto del danno.');
    }
  }

  Future<void> _salvaIncidente() async {
    debugPrint('[Save] button tapped');
    try {
      if (_isRecordingAudio) {
        _mostraSnack(
          'Termina la registrazione della nota vocale prima di salvare.',
        );
        return;
      }

      final formOk = _formKey.currentState!.validate();
      debugPrint('[Save] form valid=$formOk');
      if (!formOk) return;

      _draftClaimId ??= DateTime.now().millisecondsSinceEpoch.toString();
      final id = _draftClaimId!;

      final codiceOfficina =
          id.length > 6 ? id.substring(id.length - 6) : id.padLeft(6, '0');

      final List<Testimone> testimoni = _testimoni
          .map((t) {
            final nome = t.nomeController.text.trim();
            final tel = t.telefonoController.text.trim();
            if (nome.isEmpty && tel.isEmpty) return null;
            return Testimone(nome: nome, telefono: tel);
          })
          .whereType<Testimone>()
          .toList();
      final List<Ferito> feriti = _feriti
          .map((f) {
            final nome = f.nomeController.text.trim();
            final indirizzo = f.indirizzoController.text.trim();
            final tel = f.telefonoController.text.trim();
            if (nome.isEmpty && indirizzo.isEmpty && tel.isEmpty) return null;
            return Ferito(nome: nome, indirizzo: indirizzo, telefono: tel);
          })
          .whereType<Ferito>()
          .toList();

      final baseIncidente = Incidente(
        id: id,
        dataOra: _dataOra,
        luogo: _luogoController.text.trim(),
        nomeA: _nomeAController.text.trim(),
        cognomeA: _cognomeAController.text.trim(),
        targaA: _targaAController.text.trim(),
        assicurazioneA: _assicurazioneAController.text.trim(),
        telefonoA: _telefonoAController.text.trim(),
        emailA: _emailAController.text.trim(),
        indirizzoA: _indirizzoAController.text.trim(),
        zipA: _driverAZipController.text.trim(),
        cityA: _driverACityController.text.trim(),
        nomeB: _nomeBController.text.trim(),
        cognomeB: _cognomeBController.text.trim(),
        targaB: _targaBController.text.trim(),
        assicurazioneB: _assicurazioneBController.text.trim(),
        telefonoB: _telefonoBController.text.trim(),
        emailB: _emailBController.text.trim(),
        indirizzoB: _indirizzoBController.text.trim(),
        zipB: _driverBZipController.text.trim(),
        cityB: _driverBCityController.text.trim(),
        descrizione: _descrizioneController.text.trim(),
        danniVeicoloA: _damageVehicleAController.text.trim(),
        danniVeicoloB: _damageVehicleBController.text.trim(),
        otherObjectDamage: _otherObjectDamage,
        otherVehicleDamage: _otherVehicleDamage,
        testimoni: testimoni,
        feriti: feriti,
        notaVocaleA: _notaVocaleAController.text.trim(),
        notaVocaleB: _notaVocaleBController.text.trim(),
        notaAudioAPath: _notaAudioAPath ?? '',
        notaAudioBPath: _notaAudioBPath ?? '',
        fotoLibrettoA: _fotoLibrettoAPath ?? '',
        fotoLibrettoB: _fotoLibrettoBPath ?? '',
        fotoDanni: List<String>.from(_fotoDanniPaths),
        firmaAPath: '',
        firmaBPath: '',
        timestampFirmaA: '',
        timestampFirmaB: '',
        colpevole: '',
        codiceOfficina: codiceOfficina,
        hashIntegrita: '',
      );

      final nuovo = await aggiornaHashIncidente(baseIncidente);
      debugPrint('[Save] payload fotoDanni count=${nuovo.fotoDanni.length}');

      incidentiSalvati.insert(0, nuovo);
      await salvaIncidenti();
      debugPrint('[Save] incident saved locally');

      final sync = IncidentsSyncService();
      try {
        await sync.uploadIncident(
          payload: nuovo.toJson(),
          hashSha256: nuovo.hashIntegrita,
          timestampUtc: DateTime.now().toUtc(),
          locale: Localizations.localeOf(context).languageCode,
          deviceId: null,
        );
        debugPrint('[Save] sync upload success');
      } catch (e) {
        debugPrint('[Save] sync upload skipped/failed: $e');
      }

      if (!mounted) return;
      debugPrint('[Save] navigating to DettaglioIncidentePage');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DettaglioIncidentePage(incidente: nuovo),
        ),
      );
    } catch (e, st) {
      debugPrint('[Save][error] $e\n$st');
      _mostraSnack('Errore durante il salvataggio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataOraString = formatDataOraLocale(context, _dataOra);

    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Nuova pratica incidente')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx(context, 'Data e ora'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                dataOraString,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Divider(height: 24),
              Text(
                tx(context, "Luogo dell'incidente"),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextFormField(
                controller: _luogoController,
                decoration: InputDecoration(
                  hintText:
                      tx(context, 'Es. Autostrada A2, uscita Lugano Nord'),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return txStatic("Inserisci il luogo dell'incidente");
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              _buildGeoActions(),
              const SizedBox(height: 24),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _validazioneContattiAttiva,
                title: Text(tx(context, 'Verifica email/telefono')),
                subtitle: Text(
                  tx(context,
                      'Se disattivi, i contatti non sono obbligatori (utile in emergenza).'),
                  style: const TextStyle(fontSize: 12),
                ),
                onChanged: (val) {
                  setState(() => _validazioneContattiAttiva = val);
                },
              ),
              const Divider(height: 24),
              Text(
                AppLocalizations.of(context)!.driverA,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (!kIsWeb)
                OutlinedButton.icon(
                  onPressed: () => _scattaFotoLibretto('A'),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(tx(context, 'Foto libretto')),
                ),
              if (kIsWeb)
                OutlinedButton.icon(
                  onPressed: () =>
                      _pickAndUploadImage(kind: 'libretto', quale: 'A'),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Foto libretto'),
                ),
              if ((_fotoLibrettoAPath != null &&
                      _fotoLibrettoAPath!.isNotEmpty) ||
                  _fotoLibrettoABytes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 140,
                    child: _fotoLibrettoABytes != null
                        ? Image.memory(
                            _fotoLibrettoABytes!,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_fotoLibrettoAPath!),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nomeAController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.firstName,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return txStatic('Inserisci il nome del conducente A');
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _cognomeAController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.lastName,
                ),
              ),
              TextFormField(
                controller: _indirizzoAController,
                decoration: InputDecoration(
                  labelText: tx(context, 'Indirizzo conducente A'),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _driverAZipController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.zip,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _driverACityController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.city,
                ),
              ),
              TextFormField(
                controller: _targaAController,
                decoration:
                    InputDecoration(labelText: tx(context, 'Targa veicolo A')),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return txStatic('Inserisci la targa del veicolo A');
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _assicurazioneAController,
                decoration: InputDecoration(
                  labelText:
                      tx(context, 'Assicurazione veicolo A (es. Allianz)'),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _telefonoAController,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
                decoration: InputDecoration(
                  labelText: tx(context, 'Telefono conducente A'),
                  hintText: tx(context, 'Es. +41...'),
                ),
              ),
              TextFormField(
                controller: _emailAController,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                decoration: InputDecoration(
                  labelText: tx(context, 'Email conducente A'),
                  hintText: tx(context, 'nome@email.ch'),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.driverB,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (!kIsWeb)
                OutlinedButton.icon(
                  onPressed: () => _scattaFotoLibretto('B'),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(tx(context, 'Foto libretto')),
                ),
              if (kIsWeb)
                OutlinedButton.icon(
                  onPressed: () =>
                      _pickAndUploadImage(kind: 'libretto', quale: 'B'),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Foto libretto'),
                ),
              if ((_fotoLibrettoBPath != null &&
                      _fotoLibrettoBPath!.isNotEmpty) ||
                  _fotoLibrettoBBytes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 140,
                    child: _fotoLibrettoBBytes != null
                        ? Image.memory(
                            _fotoLibrettoBBytes!,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_fotoLibrettoBPath!),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nomeBController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.firstName,
                ),
                validator: (value) {
                  if (!_isAnyCampoBCompilato()) return null;
                  if (value == null || value.trim().isEmpty) {
                    return txStatic('Inserisci il nome del conducente B');
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _cognomeBController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.lastName,
                ),
              ),
              TextFormField(
                controller: _indirizzoBController,
                decoration: InputDecoration(
                  labelText: tx(context, 'Indirizzo conducente B'),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _driverBZipController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.zip,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _driverBCityController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.city,
                ),
              ),
              TextFormField(
                controller: _targaBController,
                decoration:
                    InputDecoration(labelText: tx(context, 'Targa veicolo B')),
                validator: (value) {
                  if (!_isAnyCampoBCompilato()) return null;
                  if (value == null || value.trim().isEmpty) {
                    return txStatic('Inserisci la targa del veicolo B');
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _assicurazioneBController,
                decoration: InputDecoration(
                  labelText: tx(context, 'Assicurazione veicolo B (es. AXA)'),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _telefonoBController,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
                decoration: InputDecoration(
                  labelText: tx(context, 'Telefono conducente B'),
                  hintText: tx(context, 'Es. +41...'),
                ),
              ),
              TextFormField(
                controller: _emailBController,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                decoration: InputDecoration(
                  labelText: tx(context, 'Email conducente B'),
                  hintText: tx(context, 'nome@email.ch'),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tx(context, 'Descrizione incidente'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextFormField(
                controller: _descrizioneController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: tx(context,
                      "Scrivi brevemente come è successo l'incidente..."),
                ),
              ),
              const SizedBox(height: 16),
              _yesNoRow(
                title: AppLocalizations.of(context)!.other_object_damage_q,
                value: _otherObjectDamage,
                onChanged: (v) => setState(() => _otherObjectDamage = v),
              ),
              _yesNoRow(
                title: AppLocalizations.of(context)!.other_vehicle_damage_q,
                value: _otherVehicleDamage,
                onChanged: (v) => setState(() => _otherVehicleDamage = v),
              ),
              const SizedBox(height: 24),
              Text(
                tx(context, 'Testimoni (se presenti)'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < _testimoni.length; i++) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _testimoni[i].nomeController,
                        decoration: InputDecoration(
                          labelText:
                              '${tx(context, 'Nome testimone')} ${i + 1}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _testimoni[i].telefonoController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText:
                              '${tx(context, 'Telefono testimone')} ${i + 1}',
                        ),
                      ),
                    ),
                    if (_testimoni.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() {
                            _testimoni[i].nomeController.dispose();
                            _testimoni[i].telefonoController.dispose();
                            _testimoni.removeAt(i);
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _testimoni.add(
                        _TestimoneFormData(
                          nomeController: TextEditingController(),
                          telefonoController: TextEditingController(),
                        ),
                      );
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: Text(tx(context, 'Aggiungi testimone')),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tx(context, 'Feriti (se presenti)'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_feriti.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '-',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              for (int i = 0; i < _feriti.length; i++) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _feriti[i].nomeController,
                        decoration: InputDecoration(
                          labelText: '${tx(context, 'Nome ferito')} ${i + 1}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _feriti[i].indirizzoController,
                        decoration: InputDecoration(
                          labelText:
                              '${tx(context, 'Indirizzo ferito')} ${i + 1}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _feriti[i].telefonoController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText:
                              '${tx(context, 'Telefono ferito')} ${i + 1}',
                        ),
                      ),
                    ),
                    if (_feriti.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() {
                            _feriti[i].nomeController.dispose();
                            _feriti[i].indirizzoController.dispose();
                            _feriti[i].telefonoController.dispose();
                            _feriti.removeAt(i);
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _feriti.add(
                        _FeritoFormData(
                          nomeController: TextEditingController(),
                          indirizzoController: TextEditingController(),
                          telefonoController: TextEditingController(),
                        ),
                      );
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: Text(tx(context, 'Aggiungi ferito')),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.damageTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _damageVehicleAController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.damageVehicleA,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _damageVehicleBController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.damageVehicleB,
                ),
              ),
              const SizedBox(height: 16),
              if (!kIsWeb) ...[
                Text(
                  tx(context, 'Note vocali'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildAudioNotaControls('A'),
                const SizedBox(height: 12),
                _buildAudioNotaControls('B'),
                const SizedBox(height: 24),
              ],
              Text(
                tx(context, 'Foto del danno'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _scattaFotoDanno(),
                icon: const Icon(Icons.camera),
                label: Text(tx(context, 'Aggiungi foto danno')),
              ),
              if (_fotoDanniPaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fotoDanniPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final pathStr = _fotoDanniPaths[index];
                      final isUrl = pathStr.startsWith('http');
                      final previewBytes = index < _fotoDanniBytes.length
                          ? _fotoDanniBytes[index]
                          : null;
                      debugPrint(
                          '[DamagePreview] render ${previewBytes != null ? 'bytes' : isUrl ? 'url' : 'file'} $pathStr');
                      return AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      child: previewBytes != null
                                          ? Image.memory(
                                              previewBytes,
                                              fit: BoxFit.contain,
                                            )
                                          : isUrl
                                              ? Image.network(
                                                  pathStr,
                                                  fit: BoxFit.contain,
                                                )
                                              : Image.file(
                                                  File(pathStr),
                                                  fit: BoxFit.contain,
                                                ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: previewBytes != null
                                      ? Image.memory(
                                          previewBytes,
                                          fit: BoxFit.cover,
                                        )
                                      : isUrl
                                          ? Image.network(
                                              pathStr,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              File(pathStr),
                                              fit: BoxFit.cover,
                                            ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: InkWell(
                                onTap: () => _removeDamagePhoto(index),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _salvaIncidente,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: Text(tx(context, 'Salva incidente e genera QR')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// STORICO /////////////////////////////////////////////////////////////

class StoricoPage extends StatefulWidget {
  final bool embedOnlyBody;

  const StoricoPage({super.key, this.embedOnlyBody = false});

  @override
  State<StoricoPage> createState() => _StoricoPageState();
}

class _StoricoPageState extends State<StoricoPage> {
  @override
  Widget build(BuildContext context) {
    final body = incidentiSalvati.isEmpty
        ? Center(child: Text(tx(context, 'Nessun incidente salvato.')))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: incidentiSalvati.length,
            itemBuilder: (context, index) {
              final inc = incidentiSalvati[index];
              final dataOra = formatDataOraLocale(context, inc.dataOra);
              final indirizzoACompleto =
                  formatFullAddress(inc.indirizzoA, inc.zipA, inc.cityA);
              final indirizzoBCompleto =
                  formatFullAddress(inc.indirizzoB, inc.zipB, inc.cityB);

              String resp;
              if (inc.colpevole == 'A') {
                resp = 'Resp: A';
              } else if (inc.colpevole == 'B') {
                resp = 'Resp: B';
              } else {
                resp = 'Resp: n/d';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text('$dataOra - ${inc.luogo}'),
                  subtitle: Text(
                    'A: ${formatNomeCompleto(inc.nomeA, inc.cognomeA)} (${inc.targaA})'
                    '${inc.telefonoA.isNotEmpty ? ' · ${inc.telefonoA}' : ''}'
                    '${indirizzoACompleto.isNotEmpty ? ' · $indirizzoACompleto' : ''}'
                    '${inc.emailA.isNotEmpty ? '\n   ${inc.emailA}' : ''}\n'
                    'B: ${formatNomeCompleto(inc.nomeB, inc.cognomeB)} (${inc.targaB})'
                    '${inc.telefonoB.isNotEmpty ? ' · ${inc.telefonoB}' : ''}'
                    '${indirizzoBCompleto.isNotEmpty ? ' · $indirizzoBCompleto' : ''}'
                    '${inc.emailB.isNotEmpty ? '\n   ${inc.emailB}' : ''}\n'
                    '$resp\n'
                    'Cod. officina: ${inc.codiceOfficina}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DettaglioIncidentePage(
                          incidente: inc,
                          readOnly: true,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );

    if (widget.embedOnlyBody) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Storico incidenti')),
      ),
      body: body,
    );
  }
}

/// PAGINA FIRMA ////////////////////////////////////////////////////////

class FirmaPage extends StatefulWidget {
  final Incidente incidente;
  final bool isA;

  const FirmaPage({
    super.key,
    required this.incidente,
    required this.isA,
  });

  @override
  State<FirmaPage> createState() => _FirmaPageState();
}

class _FirmaPageState extends State<FirmaPage> {
  late SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _mostraSnack(String testo) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  Future<void> _salvaFirma() async {
    if (_controller.isEmpty) {
      _mostraSnack(tx(context, 'Fai prima la firma sullo schermo.'));
      return;
    }

    try {
      final bytes = await _controller.toPngBytes();
      if (bytes == null) {
        _mostraSnack(tx(context, 'Errore nel salvataggio della firma.'));
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final firmaDir = Directory('${dir.path}/firme');
      if (!await firmaDir.exists()) {
        await firmaDir.create(recursive: true);
      }
      final file = File(
        '${firmaDir.path}/firma_${widget.incidente.id}_${widget.isA ? 'A' : 'B'}.png',
      );
      await file.writeAsBytes(bytes);

      final tsUtc = DateTime.now().toUtc().toIso8601String();

      Navigator.of(context).pop(
        FirmaResult(path: file.path, timestampUtcIso: tsUtc),
      );
    } catch (_) {
      _mostraSnack(tx(context, 'Errore nel salvataggio della firma.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.isA ? tx(context, 'Conducente A') : tx(context, 'Conducente B');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isA
            ? tx(context, 'Firma conducente A')
            : tx(context, 'Firma conducente B')),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            '${tx(context, 'Chiedi al conducente di firmare con il dito.')} ($label)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
              ),
              child: Signature(
                controller: _controller,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _controller.clear(),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Cancella'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _salvaFirma,
                    icon: const Icon(Icons.check),
                    label: const Text('Salva firma'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// QR FULLSCREEN PER OFFICINA //////////////////////////////////////////

class QrCarrozzeriaPage extends StatefulWidget {
  final Incidente incidente;

  const QrCarrozzeriaPage({super.key, required this.incidente});

  @override
  State<QrCarrozzeriaPage> createState() => _QrCarrozzeriaPageState();
}

class _QrCarrozzeriaPageState extends State<QrCarrozzeriaPage> {
  String? _qrData;
  String? _qrError;
  bool _loadingQr = true;

  Incidente get incidente => widget.incidente;

  @override
  void initState() {
    super.initState();
    _loadQrData();
  }

  Future<void> _loadQrData() async {
    setState(() {
      _loadingQr = true;
      _qrError = null;
    });
    try {
      final qrData = await buildClientQrData(incidente);
      if (!mounted) return;
      setState(() {
        _qrData = qrData;
        _loadingQr = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _qrError = e.toString();
        _loadingQr = false;
      });
    }
  }

  // INCOLLA QUI - genera file PNG del QR per la condivisione
  Future<File> _generaQrPngFile(String qrData) async {
    // MODIFICA QUI: QR con sfondo bianco e dimensione ridotta per compatibilità WhatsApp
    const double qrSize = 520;
    final painter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      gapless: true,
      color: Colors.black,
      emptyColor: Colors.white,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, qrSize, qrSize),
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, qrSize, qrSize),
      Paint()..color = Colors.white,
    );
    painter.paint(canvas, const Size(qrSize, qrSize));
    final image =
        await recorder.endRecording().toImage(qrSize.toInt(), qrSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Impossibile creare PNG QR');
    }
    final Uint8List bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  String _testoResponsabilita() {
    switch (incidente.colpevole) {
      case 'A':
        return 'Secondo le parti il conducente ritenuto colpevole è A.';
      case 'B':
        return 'Secondo le parti il conducente ritenuto colpevole è B.';
      default:
        return 'Responsabilità non dichiarata nelle selezioni.';
    }
  }

  Future<void> _condividiQr(BuildContext context) async {
    final qrData = _qrData;
    if (qrData == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tx(context,
                  'QR non ancora pronto. Attendi qualche secondo e riprova.'),
            ),
          ),
        );
      }
      return;
    }

    void _mostraSuccesso() {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tx(context,
                  'Dati QR pronti. Scegli l\'app (WhatsApp, Mail, ecc.) per mandarli alla tua officina.'),
            ),
          ),
        );
      }
    }

    try {
      final pngFile = await _generaQrPngFile(qrData);
      await Share.shareXFiles(
        [
          XFile(
            pngFile.path,
            mimeType: 'image/png',
            name: 'qr_${incidente.id}.png',
          ),
        ],
        subject: tx(context, 'CID digitale - QR per officina'),
        text: tx(
            context, 'Mostra questo QR alla carrozzeria per importare i dati.'),
        sharePositionOrigin: const ui.Rect.fromLTWH(0, 0, 1, 1),
      );
      _mostraSuccesso();
      // FINE MODIFICA
      return;
    } catch (_) {
      // fallback testuale se PNG non disponibile
    }

    try {
      await Share.share(
        qrData,
        subject: tx(context, 'CID digitale - QR per officina'),
        sharePositionOrigin: const ui.Rect.fromLTWH(0, 0, 1, 1),
      );
      _mostraSuccesso();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(tx(context, 'Errore durante la condivisione del QR.')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataOra = formatDataOraLocale(context, incidente.dataOra);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tx(context, 'QR per officina')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Builder(
                    builder: (_) {
                      if (_loadingQr) {
                        return SizedBox(
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: MediaQuery.of(context).size.width * 0.4,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (_qrError != null) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent),
                            const SizedBox(height: 8),
                            Text(
                              tx(context, 'Errore QR'),
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _qrError!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _loadQrData,
                              icon: const Icon(Icons.refresh),
                              label: Text(tx(context, 'Riprova')),
                            ),
                          ],
                        );
                      }
                      final qrDataReady = _qrData!;
                      return QrImageView(
                        data: qrDataReady,
                        version: QrVersions.auto,
                        // MODIFICA QUI: dimensione visuale QR ridotta
                        size: MediaQuery.of(context).size.width * 0.6,
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Mostra questo QR all\'officina per importare subito '
                    'tutti i dati della pratica (anche contatti, testimoni e note).',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Targa A: ${incidente.targaA.isEmpty ? '-' : incidente.targaA}  ·  '
                    'Targa B: ${incidente.targaB.isEmpty ? '-' : incidente.targaB}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _testoResponsabilita(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Codice officina: ${incidente.codiceOfficina}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dataOra,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_qrData != null && !_loadingQr && _qrError == null)
                              ? () => _condividiQr(context)
                              : null,
                      icon: const Icon(Icons.ios_share),
                      label: Text(tx(context, 'Invia QR a officina')),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ====================== PARTE 3 / 3 ======================
// (DettaglioIncidentePage MODIFICATA: invio PDF sotto firme + blocco modifiche dopo firme)
// Incolla questa parte SUBITO DOPO la PARTE 2

/// DETTAGLIO ///////////////////////////////////////////////////////////

class DettaglioIncidentePage extends StatefulWidget {
  final Incidente incidente;
  final bool readOnly;

  const DettaglioIncidentePage({
    super.key,
    required this.incidente,
    this.readOnly = false,
  });

  @override
  State<DettaglioIncidentePage> createState() => _DettaglioIncidentePageState();
}

class _DettaglioIncidentePageState extends State<DettaglioIncidentePage> {
  late Incidente incidente;
  late final AudioPlayer _detailAudioPlayer;
  StreamSubscription<void>? _detailAudioSub;
  String? _notaInRiproduzione;
  bool? _hashValido;
  late Future<String> _qrDataFuture;

  @override
  void initState() {
    super.initState();
    incidente = widget.incidente;
    _qrDataFuture = buildClientQrData(incidente);
    _detailAudioPlayer = AudioPlayer();
    _detailAudioSub = _detailAudioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _notaInRiproduzione = null;
        });
      }
    });
    unawaited(_verificaHashIntegrita());
  }

  String _labelResponsabilita() {
    final l10n = AppLocalizations.of(context)!;
    switch (incidente.colpevole) {
      case 'A':
        return l10n.faultLiabilityHintA;
      case 'B':
        return l10n.faultLiabilityHintB;
      default:
        return 'Responsabilità non selezionata.';
    }
  }

  bool get _firmeComplete =>
      incidente.firmaAPath.isNotEmpty &&
      File(incidente.firmaAPath).existsSync() &&
      incidente.firmaBPath.isNotEmpty &&
      File(incidente.firmaBPath).existsSync();

  bool get _locked => widget.readOnly || _firmeComplete;

  // ✅ STEP B: calcolo hash SHA-256 dei dati pratica + allegati
  Future<String> _calcolaHashPratica() async {
    if (incidente.hashIntegrita.isNotEmpty) {
      return incidente.hashIntegrita;
    }
    return calcolaHashIntegrita(incidente);
  }

  Future<void> _verificaHashIntegrita() async {
    final calcolato = await calcolaHashIntegrita(incidente);
    if (!mounted) return;
    setState(() {
      _hashValido = incidente.hashIntegrita.isEmpty
          ? null
          : incidente.hashIntegrita == calcolato;
    });
  }

  void _refreshQrData() {
    setState(() {
      _qrDataFuture = buildClientQrData(incidente);
    });
  }

  Future<void> _apriUrl(
      BuildContext context, Uri uri, String messaggioErrore) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tx(context, messaggioErrore))));
    }
  }

  void _mostraEmergenze(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.blue.shade50,
                child: Text(
                  tx(context, 'Numeri di emergenza'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              ListTile(
                tileColor: Colors.blue.shade50,
                leading: const Icon(Icons.local_shipping, color: Colors.blue),
                title: Text(tx(context, 'Carro attrezzi'),
                    style: const TextStyle(color: Colors.black87)),
                subtitle: Text(
                  configOfficina.carroNumero.isEmpty
                      ? tx(context,
                          'Configura il numero in Impostazioni officina')
                      : configOfficina.carroNumero,
                  style: const TextStyle(color: Colors.black54),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (configOfficina.carroNumero.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tx(context,
                            'Imposta il numero del carro attrezzi nelle Impostazioni officina.')),
                      ),
                    );
                  } else {
                    _apriUrl(
                      context,
                      Uri.parse('tel:${configOfficina.carroNumero}'),
                      tx(context, 'Impossibile avviare la chiamata.'),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                tileColor: Colors.blue.shade50,
                leading: const Icon(Icons.local_police, color: Colors.blue),
                title: Text(tx(context, 'Polizia (112)'),
                    style: const TextStyle(color: Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  _apriUrl(context, Uri.parse('tel:112'),
                      tx(context, 'Impossibile avviare la chiamata.'));
                },
              ),
              const Divider(height: 1),
              ListTile(
                tileColor: Colors.blue.shade50,
                leading: const Icon(Icons.local_hospital, color: Colors.blue),
                title: Text(tx(context, 'Ambulanza (112)'),
                    style: const TextStyle(color: Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  _apriUrl(context, Uri.parse('tel:112'),
                      tx(context, 'Impossibile avviare la chiamata.'));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _mostraSnackDettaglio(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(testo)),
    );
  }

  Widget _notaAudioWidget(String quale) {
    final l10n = AppLocalizations.of(context)!;
    final bool isPlaying = _notaInRiproduzione == quale;
    final label =
        quale == 'A' ? l10n.labelDriverAVoice : l10n.labelDriverBVoice;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => isPlaying
                ? _fermaNotaIncidente()
                : _riproduciNotaIncidente(quale),
            icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
            label: Text(
              isPlaying ? tx(context, 'Ferma') : tx(context, 'Riproduci'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _riproduciNotaIncidente(String quale) async {
    final path =
        quale == 'A' ? incidente.notaAudioAPath : incidente.notaAudioBPath;
    if (path.isEmpty) {
      _mostraSnackDettaglio(tx(context, 'Nota vocale non disponibile.'));
      return;
    }
    final file = File(path);
    if (!file.existsSync()) {
      _mostraSnackDettaglio(
          tx(context, 'Il file audio della nota non è stato trovato.'));
      return;
    }
    try {
      await _detailAudioPlayer.stop();
      await _detailAudioPlayer.play(DeviceFileSource(path));
      if (!mounted) return;
      setState(() {
        _notaInRiproduzione = quale;
      });
    } catch (_) {
      _mostraSnackDettaglio('Errore durante la riproduzione della nota audio.');
    }
  }

  Future<void> _fermaNotaIncidente() async {
    await _detailAudioPlayer.stop();
    if (!mounted) return;
    setState(() {
      _notaInRiproduzione = null;
    });
  }

  @override
  void dispose() {
    unawaited(_detailAudioSub?.cancel());
    unawaited(_detailAudioPlayer.stop());
    _detailAudioPlayer.dispose();
    super.dispose();
  }

  Future<File> _creaPdfFile() async {
    final l10n = AppLocalizations.of(context)!;
    final pdf = pw.Document();
    final dataOra = formatDataOraGeneric(incidente.dataOra);

    // ✅ STEP B: hash integrità
    final hash = await _calcolaHashPratica();
    final driverAName = formatNomeCompleto(incidente.nomeA, incidente.cognomeA);
    final driverBName = formatNomeCompleto(incidente.nomeB, incidente.cognomeB);
    final indirizzoACompleto = formatFullAddress(
        incidente.indirizzoA, incidente.zipA, incidente.cityA);
    final indirizzoBCompleto = formatFullAddress(
        incidente.indirizzoB, incidente.zipB, incidente.cityB);

    pw.ImageProvider? firmaAImage;
    pw.ImageProvider? firmaBImage;

    if (incidente.firmaAPath.isNotEmpty &&
        File(incidente.firmaAPath).existsSync()) {
      final bytesA = await File(incidente.firmaAPath).readAsBytes();
      firmaAImage = pw.MemoryImage(bytesA);
    }
    if (incidente.firmaBPath.isNotEmpty &&
        File(incidente.firmaBPath).existsSync()) {
      final bytesB = await File(incidente.firmaBPath).readAsBytes();
      firmaBImage = pw.MemoryImage(bytesB);
    }

    String responsabilitaPdf;
    switch (incidente.colpevole) {
      case 'A':
        responsabilitaPdf =
            l10n.pdfLiabilityAccordingToParties(l10n.pdfDriverA);
        break;
      case 'B':
        responsabilitaPdf =
            l10n.pdfLiabilityAccordingToParties(l10n.pdfDriverB);
        break;
      default:
        responsabilitaPdf =
            txStatic("Responsabilità non dichiarata nelle selezioni dell'app.");
        break;
    }

    pdf.addPage(
      pw.Page(
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                txStatic('CID Digitale'),
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Text('${l10n.labelDateTime} $dataOra'),
              pw.Text('${l10n.labelPlace} ${incidente.luogo}'),
              pw.SizedBox(height: 8),
              pw.Text('${l10n.pdfDriverA}: $driverAName (${incidente.targaA})'),
              pw.Text(
                  '${txStatic('Assicurazione A:')} ${incidente.assicurazioneA.isEmpty ? '-' : incidente.assicurazioneA}'),
              pw.Text(
                  '${txStatic('Telefono A:')} ${incidente.telefonoA.isEmpty ? '-' : incidente.telefonoA}'),
              pw.Text(
                  '${txStatic('Email A:')} ${incidente.emailA.isEmpty ? '-' : incidente.emailA}'),
              pw.Text(
                  '${txStatic('Indirizzo A:')} ${indirizzoACompleto.isEmpty ? '-' : indirizzoACompleto}'),
              pw.SizedBox(height: 6),
              pw.Text('${l10n.pdfDriverB}: $driverBName (${incidente.targaB})'),
              pw.Text(
                  '${txStatic('Assicurazione B:')} ${incidente.assicurazioneB.isEmpty ? '-' : incidente.assicurazioneB}'),
              pw.Text(
                  '${txStatic('Telefono B:')} ${incidente.telefonoB.isEmpty ? '-' : incidente.telefonoB}'),
              pw.Text(
                  '${txStatic('Email B:')} ${incidente.emailB.isEmpty ? '-' : incidente.emailB}'),
              pw.Text(
                  '${txStatic('Indirizzo B:')} ${indirizzoBCompleto.isEmpty ? '-' : indirizzoBCompleto}'),
              pw.SizedBox(height: 12),
              pw.Text(txStatic('Descrizione:'),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  incidente.descrizione.isEmpty ? '-' : incidente.descrizione),
              pw.SizedBox(height: 12),
              pw.Text(txStatic('Testimoni:'),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (incidente.testimoni.isEmpty)
                pw.Text(txStatic('- Nessun testimone indicato.'))
              else ...[
                for (final t in incidente.testimoni)
                  pw.Text(
                    '- ${t.nome.isEmpty ? txStatic('Nome non indicato') : t.nome}'
                    '${t.telefono.isNotEmpty ? ' (${t.telefono})' : ''}',
                  ),
              ],
              pw.SizedBox(height: 12),
              pw.Text(txStatic('Feriti:'),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (incidente.feriti.isEmpty)
                pw.Text(txStatic('- Nessun ferito indicato.'))
              else ...[
                for (final f in incidente.feriti)
                  pw.Text(
                    '- ${f.nome.isEmpty ? txStatic('Nome non indicato') : f.nome}'
                    '${f.indirizzo.isNotEmpty ? ' · ${f.indirizzo}' : ''}'
                    '${f.telefono.isNotEmpty ? ' (${f.telefono})' : ''}',
                  ),
              ],
              pw.SizedBox(height: 12),
              pw.Text(l10n.damageTitle,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (incidente.danniVeicoloA.isEmpty &&
                  incidente.danniVeicoloB.isEmpty)
                pw.Text('-')
              else ...[
                pw.Text(
                  '${l10n.damageVehicleA}: ${incidente.danniVeicoloA.isEmpty ? '-' : incidente.danniVeicoloA}',
                ),
                pw.Text(
                  '${l10n.damageVehicleB}: ${incidente.danniVeicoloB.isEmpty ? '-' : incidente.danniVeicoloB}',
                ),
              ],
              if (incidente.notaVocaleA.isNotEmpty ||
                  incidente.notaVocaleB.isNotEmpty ||
                  incidente.notaAudioAPath.isNotEmpty ||
                  incidente.notaAudioBPath.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text(txStatic('Note vocali'),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                if (incidente.notaVocaleA.isNotEmpty)
                  pw.Text('${l10n.labelDriverAText} ${incidente.notaVocaleA}'),
                if (incidente.notaAudioAPath.isNotEmpty)
                  pw.Text(
                    txStatic(
                        'Conducente A: nota vocale allegata (file audio).'),
                    style: pw.TextStyle(fontSize: 10),
                  ),
                if (incidente.notaVocaleB.isNotEmpty)
                  pw.Text('${l10n.labelDriverBText} ${incidente.notaVocaleB}'),
                if (incidente.notaAudioBPath.isNotEmpty)
                  pw.Text(
                    txStatic(
                        'Conducente B: nota vocale allegata (file audio).'),
                    style: pw.TextStyle(fontSize: 10),
                  ),
              ],
              pw.SizedBox(height: 12),
              pw.Text(l10n.pdfLiabilityHeading,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(responsabilitaPdf),
              pw.SizedBox(height: 14),
              pw.Text(
                '${txStatic('Impronta integrità (SHA-256):')} $hash',
                style: pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 12),
              if (firmaAImage != null || firmaBImage != null) ...[
                pw.Text(txStatic('Firme:'),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (firmaAImage != null)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(l10n.pdfDriverA),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              width: 150,
                              height: 60,
                              decoration: pw.BoxDecoration(
                                  border: pw.Border.all(width: 0.5)),
                              child:
                                  pw.Image(firmaAImage, fit: pw.BoxFit.contain),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              '${txStatic('Timestamp firma (UTC):')} ${incidente.timestampFirmaA.isEmpty ? '-' : incidente.timestampFirmaA}',
                              style: pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    if (firmaBImage != null) pw.SizedBox(width: 24),
                    if (firmaBImage != null)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(l10n.pdfDriverB),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              width: 150,
                              height: 60,
                              decoration: pw.BoxDecoration(
                                  border: pw.Border.all(width: 0.5)),
                              child:
                                  pw.Image(firmaBImage, fit: pw.BoxFit.contain),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              '${txStatic('Timestamp firma (UTC):')} ${incidente.timestampFirmaB.isEmpty ? '-' : incidente.timestampFirmaB}',
                              style: pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  txStatic(
                      'Le firme apposte confermano la correttezza dei dati inseriti nel presente CID digitale.'),
                  style: pw.TextStyle(fontSize: 9),
                ),
              ],
              pw.SizedBox(height: 12),
              pw.Text(
                  '${txStatic('Codice officina:')} ${incidente.codiceOfficina}',
                  style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 4),
              pw.Text(
                txStatic(
                    "QR code disponibile nell'app per recuperare rapidamente la pratica."),
                style: pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/cid_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _condividiPdf(String testo) async {
    try {
      final pdfFile = await _creaPdfFile();

      final List<XFile> allegati = [
        XFile(
          pdfFile.path,
          mimeType: 'application/pdf',
          name: 'cid_${incidente.id}.pdf',
        ),
      ];

      if (incidente.fotoLibrettoA.isNotEmpty &&
          File(incidente.fotoLibrettoA).existsSync()) {
        allegati.add(XFile(incidente.fotoLibrettoA));
      }

      if (incidente.fotoLibrettoB.isNotEmpty &&
          File(incidente.fotoLibrettoB).existsSync()) {
        allegati.add(XFile(incidente.fotoLibrettoB));
      }

      for (final path in incidente.fotoDanni) {
        if (path.isNotEmpty && File(path).existsSync()) {
          allegati.add(XFile(path));
        }
      }

      if (incidente.notaAudioAPath.isNotEmpty &&
          File(incidente.notaAudioAPath).existsSync()) {
        allegati.add(XFile(incidente.notaAudioAPath));
      }
      if (incidente.notaAudioBPath.isNotEmpty &&
          File(incidente.notaAudioBPath).existsSync()) {
        allegati.add(XFile(incidente.notaAudioBPath));
      }

      await Share.shareXFiles(
        allegati,
        subject: tx(context, 'CID digitale incidente'),
        text: testo,
        sharePositionOrigin: const ui.Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx(context,
                'Errore nella generazione o condivisione del PDF e allegati.')),
          ),
        );
      }
    }
  }

  Future<void> _condividiPerAssicurazione(BuildContext context) async {
    await _condividiPdf(
      tx(context,
          'Invio il CID digitale dell\'incidente per la gestione del sinistro.'),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(context,
              'PDF e foto generati. Scegli l\'app (Mail, WhatsApp, ecc.) per inviarli.')),
        ),
      );
    }
  }

  Future<void> _chiamaConcessionaria(BuildContext context) async {
    if (configOfficina.concessionariaNumero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Imposta il numero della carrozzeria nelle Impostazioni officina.'),
        ),
      );
      return;
    }
    await _apriUrl(
      context,
      Uri.parse('tel:${configOfficina.concessionariaNumero}'),
      'Impossibile avviare la chiamata.',
    );
  }

  // ====================== COLPEVOLE + FIRME (BLOCCO) ======================

  Future<void> _impostaColpevole(String value) async {
    if (_locked) return;

    final updated = Incidente(
      id: incidente.id,
      dataOra: incidente.dataOra,
      luogo: incidente.luogo,
      nomeA: incidente.nomeA,
      cognomeA: incidente.cognomeA,
      targaA: incidente.targaA,
      assicurazioneA: incidente.assicurazioneA,
      telefonoA: incidente.telefonoA,
      emailA: incidente.emailA,
      indirizzoA: incidente.indirizzoA,
      zipA: incidente.zipA,
      cityA: incidente.cityA,
      nomeB: incidente.nomeB,
      cognomeB: incidente.cognomeB,
      targaB: incidente.targaB,
      assicurazioneB: incidente.assicurazioneB,
      telefonoB: incidente.telefonoB,
      emailB: incidente.emailB,
      indirizzoB: incidente.indirizzoB,
      zipB: incidente.zipB,
      cityB: incidente.cityB,
      descrizione: incidente.descrizione,
      danniVeicoloA: incidente.danniVeicoloA,
      danniVeicoloB: incidente.danniVeicoloB,
      otherObjectDamage: incidente.otherObjectDamage,
      otherVehicleDamage: incidente.otherVehicleDamage,
      testimoni: incidente.testimoni,
      feriti: incidente.feriti,
      notaVocaleA: incidente.notaVocaleA,
      notaVocaleB: incidente.notaVocaleB,
      notaAudioAPath: incidente.notaAudioAPath,
      notaAudioBPath: incidente.notaAudioBPath,
      fotoLibrettoA: incidente.fotoLibrettoA,
      fotoLibrettoB: incidente.fotoLibrettoB,
      fotoDanni: incidente.fotoDanni,
      firmaAPath: incidente.firmaAPath,
      firmaBPath: incidente.firmaBPath,
      timestampFirmaA: incidente.timestampFirmaA,
      timestampFirmaB: incidente.timestampFirmaB,
      colpevole: value,
      codiceOfficina: incidente.codiceOfficina,
      hashIntegrita: incidente.hashIntegrita,
    );

    final updatedWithHash = await aggiornaHashIncidente(updated);

    final index = incidentiSalvati.indexWhere((e) => e.id == incidente.id);
    if (index != -1) {
      incidentiSalvati[index] = updatedWithHash;
      await salvaIncidenti();
    }

    setState(() {
      incidente = updatedWithHash;
      _qrDataFuture = buildClientQrData(updatedWithHash);
    });
    unawaited(_verificaHashIntegrita());
  }

  Future<void> _firmaConducente(bool isA) async {
    if (_locked) return;

    final result = await Navigator.of(context).push<FirmaResult>(
      MaterialPageRoute(
        builder: (_) => FirmaPage(incidente: incidente, isA: isA),
      ),
    );

    if (result == null) return;

    final updated = Incidente(
      id: incidente.id,
      dataOra: incidente.dataOra,
      luogo: incidente.luogo,
      nomeA: incidente.nomeA,
      cognomeA: incidente.cognomeA,
      targaA: incidente.targaA,
      assicurazioneA: incidente.assicurazioneA,
      telefonoA: incidente.telefonoA,
      emailA: incidente.emailA,
      indirizzoA: incidente.indirizzoA,
      zipA: incidente.zipA,
      cityA: incidente.cityA,
      nomeB: incidente.nomeB,
      cognomeB: incidente.cognomeB,
      targaB: incidente.targaB,
      assicurazioneB: incidente.assicurazioneB,
      telefonoB: incidente.telefonoB,
      emailB: incidente.emailB,
      indirizzoB: incidente.indirizzoB,
      zipB: incidente.zipB,
      cityB: incidente.cityB,
      descrizione: incidente.descrizione,
      danniVeicoloA: incidente.danniVeicoloA,
      danniVeicoloB: incidente.danniVeicoloB,
      otherObjectDamage: incidente.otherObjectDamage,
      otherVehicleDamage: incidente.otherVehicleDamage,
      testimoni: incidente.testimoni,
      feriti: incidente.feriti,
      notaVocaleA: incidente.notaVocaleA,
      notaVocaleB: incidente.notaVocaleB,
      notaAudioAPath: incidente.notaAudioAPath,
      notaAudioBPath: incidente.notaAudioBPath,
      fotoLibrettoA: incidente.fotoLibrettoA,
      fotoLibrettoB: incidente.fotoLibrettoB,
      fotoDanni: incidente.fotoDanni,
      firmaAPath: isA ? result.path : incidente.firmaAPath,
      firmaBPath: isA ? incidente.firmaBPath : result.path,
      timestampFirmaA: isA ? result.timestampUtcIso : incidente.timestampFirmaA,
      timestampFirmaB: isA ? incidente.timestampFirmaB : result.timestampUtcIso,
      colpevole: incidente.colpevole,
      codiceOfficina: incidente.codiceOfficina,
      hashIntegrita: incidente.hashIntegrita,
    );

    final updatedWithHash = await aggiornaHashIncidente(updated);

    final index = incidentiSalvati.indexWhere((e) => e.id == incidente.id);
    if (index != -1) {
      incidentiSalvati[index] = updatedWithHash;
      await salvaIncidenti();
    }

    setState(() {
      incidente = updatedWithHash;
      _qrDataFuture = buildClientQrData(updatedWithHash);
    });
    unawaited(_verificaHashIntegrita());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dataOra = formatDataOraLocale(context, incidente.dataOra);
    final bool hasNoteVocali = incidente.notaVocaleA.isNotEmpty ||
        incidente.notaVocaleB.isNotEmpty ||
        incidente.notaAudioAPath.isNotEmpty ||
        incidente.notaAudioBPath.isNotEmpty;
    final bool hasDanni = incidente.danniVeicoloA.isNotEmpty ||
        incidente.danniVeicoloB.isNotEmpty;
    final firmaAFile =
        incidente.firmaAPath.isNotEmpty ? File(incidente.firmaAPath) : null;
    final firmaBFile =
        incidente.firmaBPath.isNotEmpty ? File(incidente.firmaBPath) : null;
    final firmaAExists = firmaAFile?.existsSync() ?? false;
    final firmaBExists = firmaBFile?.existsSync() ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Dettaglio incidente')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx(context, 'Riepilogo incidente'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('${l10n.labelDateTime} $dataOra'),
                          Text('${l10n.labelPlace} ${incidente.luogo}'),
                          const SizedBox(height: 6),
                          if (incidente.telefonoA.isNotEmpty ||
                              incidente.emailA.isNotEmpty ||
                              incidente.telefonoB.isNotEmpty ||
                              incidente.emailB.isNotEmpty)
                            Text(
                              'Contatti: '
                              'A ${incidente.telefonoA.isEmpty ? '-' : incidente.telefonoA}'
                              '${incidente.emailA.isNotEmpty ? ' · ${incidente.emailA}' : ''}'
                              '  |  '
                              'B ${incidente.telefonoB.isEmpty ? '-' : incidente.telefonoB}'
                              '${incidente.emailB.isNotEmpty ? ' · ${incidente.emailB}' : ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            )
                          else
                            const Text(
                              'Contatti non inseriti (email/telefono A e B vuoti).',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.redAccent),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _labelResponsabilita(),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          if (_hashValido == false) ...[
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context)!
                                  .integrityNotVerifiedWarning,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red),
                            ),
                          ] else if (incidente.hashIntegrita.isEmpty) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Impronta di integrità non disponibile per questa pratica.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ] else if (_hashValido == null) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Verifica integrità in corso...',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ],
                          if (_locked && !widget.readOnly) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Firme completate: pratica bloccata (non più modificabile).',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (hasDanni) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.car_repair, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.damageTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (incidente.danniVeicoloA.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${AppLocalizations.of(context)!.damageVehicleA}: ${incidente.danniVeicoloA}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      if (incidente.danniVeicoloB.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${AppLocalizations.of(context)!.damageVehicleB}: ${incidente.danniVeicoloB}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (hasNoteVocali) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.record_voice_over,
                              color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            tx(context, 'Note vocali'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (incidente.notaVocaleA.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${l10n.labelDriverAText} ${incidente.notaVocaleA}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      if (incidente.notaAudioAPath.isNotEmpty)
                        _notaAudioWidget('A'),
                      if (incidente.notaVocaleB.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          child: Text(
                            '${l10n.labelDriverBText} ${incidente.notaVocaleB}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      if (incidente.notaAudioBPath.isNotEmpty)
                        _notaAudioWidget('B'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (incidente.testimoni.isNotEmpty ||
                incidente.feriti.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_outline, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            tx(context, 'Testimoni (se presenti)'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (incidente.testimoni.isEmpty)
                        Text(
                          tx(context, '- Nessun testimone indicato.'),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        )
                      else
                        ...incidente.testimoni.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${t.nome.isEmpty ? tx(context, 'Nome non indicato') : t.nome}'
                              '${t.telefono.isNotEmpty ? ' (${t.telefono})' : ''}',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        tx(context, 'Feriti (se presenti)'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (incidente.feriti.isEmpty)
                        Text(
                          tx(context, '- Nessun ferito indicato.'),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        )
                      else
                        ...incidente.feriti.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${f.nome.isEmpty ? tx(context, 'Nome non indicato') : f.nome}'
                              '${f.indirizzo.isNotEmpty ? ' · ${f.indirizzo}' : ''}'
                              '${f.telefono.isNotEmpty ? ' (${f.telefono})' : ''}',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ===================== CARD RESPONSABILITÀ + FIRME + (NUOVO) INVIO PDF SOTTO FIRME =====================
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gavel_outlined, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          tx(context, 'Responsabilità e firme'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _labelResponsabilita(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    if (!_locked) ...[
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text(l10n.labelDriverA),
                              value: 'A',
                              groupValue: incidente.colpevole,
                              onChanged: (val) {
                                if (val != null) _impostaColpevole(val);
                              },
                              dense: true,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text(l10n.labelDriverB),
                              value: 'B',
                              groupValue: incidente.colpevole,
                              onChanged: (val) {
                                if (val != null) _impostaColpevole(val);
                              },
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          tx(context,
                              'Questo incidente è in sola lettura / bloccato.'),
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    if (incidente.firmaAPath.isNotEmpty ||
                        incidente.firmaBPath.isNotEmpty) ...[
                      Text(
                        tx(context, 'Firme raccolte'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (incidente.firmaAPath.isNotEmpty) ...[
                        Text(l10n.labelDriverA),
                        const SizedBox(height: 4),
                        if (firmaAExists)
                          SizedBox(
                            height: 60,
                            child: Image.file(firmaAFile!, fit: BoxFit.contain),
                          )
                        else
                          const Text(
                            'File firma A non trovato. Chiedi di firmare di nuovo.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.redAccent),
                          ),
                        Text(
                          'Timestamp (UTC): ${incidente.timestampFirmaA.isEmpty ? '-' : incidente.timestampFirmaA}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (incidente.firmaBPath.isNotEmpty) ...[
                        Text(l10n.labelDriverB),
                        const SizedBox(height: 4),
                        if (firmaBExists)
                          SizedBox(
                            height: 60,
                            child: Image.file(firmaBFile!, fit: BoxFit.contain),
                          )
                        else
                          const Text(
                            'File firma B non trovato. Chiedi di firmare di nuovo.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.redAccent),
                          ),
                        Text(
                          'Timestamp (UTC): ${incidente.timestampFirmaB.isEmpty ? '-' : incidente.timestampFirmaB}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],

                    if (!_locked) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _firmaConducente(true),
                          icon: const Icon(Icons.edit),
                          label: Text(
                            incidente.firmaAPath.isEmpty
                                ? tx(context, 'Firma conducente A')
                                : tx(context, 'Rifirma conducente A'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _firmaConducente(false),
                          icon: const Icon(Icons.edit),
                          label: Text(
                            incidente.firmaBPath.isEmpty
                                ? tx(context, 'Firma conducente B')
                                : tx(context, 'Rifirma conducente B'),
                          ),
                        ),
                      ),
                    ],

                    // ✅ QUI: SOTTO LE FIRME (come richiesto)
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _condividiPerAssicurazione(context),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          tx(context,
                              'Invia PDF + foto alla assicurazione e conducente A e B'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // QR
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_2, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          tx(context, 'QR per la carrozzeria'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<String>(
                      future: _qrDataFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Column(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.redAccent),
                              const SizedBox(height: 6),
                              Text(
                                tx(context, 'Errore QR:'),
                                style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${snapshot.error}',
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _refreshQrData,
                                icon: const Icon(Icons.refresh),
                                label: Text(tx(context, 'Rigenera QR')),
                              ),
                            ],
                          );
                        }
                        final qrDataReady = snapshot.data ?? '';
                        return Column(
                          children: [
                            Center(
                              child: QrImageView(
                                data: qrDataReady,
                                version: QrVersions.auto,
                                size: 200,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tx(context,
                                  'Mostra questo QR alla carrozzeria per importare i dati.'),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => QrCarrozzeriaPage(
                                        incidente: incidente,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.fullscreen),
                                label: Text(
                                  tx(context, 'Apri QR a tutto schermo'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tx(context, 'Codice officina:')} ${incidente.codiceOfficina}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ✅ Azioni rapide: rimangono solo i 3 pulsanti (PDF è stato spostato sotto firme)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flash_on, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          tx(context, 'Azioni rapide'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _chiamaConcessionaria(context),
                        icon: const Icon(Icons.phone_enabled),
                        label: Text(tx(context, 'Chiama la mia carrozzeria')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _apriUrl(
                            context,
                            Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=carrozzeria+vicino+a+me',
                            ),
                            'Impossibile aprire Google Maps.',
                          );
                        },
                        icon: const Icon(Icons.location_on_outlined),
                        label: Text(
                          tx(context, 'Trova carrozzeria e i dintorni'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _mostraEmergenze(context),
                        icon: const Icon(Icons.phone_in_talk),
                        label: Text(tx(context, 'Chiama numeri di emergenza')),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
