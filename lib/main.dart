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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ocr_utils.dart';
import 'scanner_libretto_page.dart';
import 'config/supabase_config.dart';
import 'screens/officina/appointments_screen.dart';
import 'screens/service/service_anmelden_screen.dart';
import 'screens/service/raeder_wechsel_screen.dart';
import 'screens/driver_personal_qr_screen.dart';
import 'screens/driver_qr_scanner_screen.dart';
import 'screens/service/workshop_selector_screen.dart';
import 'services/device_location_service.dart';
import 'services/supabase_service.dart';
import 'services/appointment_requests_service.dart';
import 'services/incidents_sync_service.dart';
import 'services/local_image_cache.dart';
import 'models/driver_personal_qr_data.dart';
import 'models/personal_vehicle_data.dart';
import 'services/personal_vehicle_storage.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'qr/qr_payload.dart';
import 'package:cid_digitale/widgets/damage_type_picker_sheet.dart';
import 'widgets/auth/auth_gate.dart';
import 'screens/auth/login_page.dart';
import 'web_share_helper.dart'
    show WebShareFile, shareFilesWeb, webUserAgent, webNavigatorShareAvailable;
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

enum DamagePhotoStatus { local, uploading, uploaded, failed }

class DamagePhotoItem {
  Uint8List? bytes;
  String? localPath;
  String? remoteUrl;
  String? storagePath;
  String? cacheKey;
  DamagePhotoStatus status;
  String? error;
  bool isRemoved;

  DamagePhotoItem({
    required this.status,
    this.bytes,
    this.localPath,
    this.remoteUrl,
    this.storagePath,
    this.cacheKey,
    this.error,
    this.isRemoved = false,
  });
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

bool _isValidSendEmail(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isNotEmpty &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed);
}

List<String> _collectSendRecipients({
  String? emailA,
  String? emailB,
  Iterable<String> extraEmails = const <String>[],
}) {
  final recipients = <String>[];

  void addIfValid(String? candidate) {
    final trimmed = candidate?.trim() ?? '';
    if (!_isValidSendEmail(trimmed) || recipients.contains(trimmed)) return;
    recipients.add(trimmed);
  }

  addIfValid(emailA);
  addIfValid(emailB);
  for (final candidate in extraEmails) {
    addIfValid(candidate);
  }

  return recipients;
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

class ConducenteAggiuntivo {
  final String driverKey;
  final String nome;
  final String cognome;
  final String indirizzo;
  final String zip;
  final String city;
  final String targa;
  final String assicurazione;
  final String telefono;
  final String email;
  final String fotoLibrettoPath;
  final String fotoLibrettoCacheKey;

  ConducenteAggiuntivo({
    required this.driverKey,
    required this.nome,
    required this.cognome,
    required this.indirizzo,
    required this.zip,
    required this.city,
    required this.targa,
    required this.assicurazione,
    required this.telefono,
    required this.email,
    this.fotoLibrettoPath = '',
    this.fotoLibrettoCacheKey = '',
  });

  Map<String, dynamic> toJson() => {
        'driverKey': driverKey,
        'nome': nome,
        'cognome': cognome,
        'indirizzo': indirizzo,
        'zip': zip,
        'city': city,
        'targa': targa,
        'assicurazione': assicurazione,
        'telefono': telefono,
        'email': email,
        'fotoLibrettoPath': fotoLibrettoPath,
        'fotoLibrettoCacheKey': fotoLibrettoCacheKey,
      };

  factory ConducenteAggiuntivo.fromJson(Map<String, dynamic> json) {
    return ConducenteAggiuntivo(
      driverKey: json['driverKey']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      cognome: json['cognome']?.toString() ?? '',
      indirizzo: json['indirizzo']?.toString() ?? '',
      zip: json['zip']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      targa: json['targa']?.toString() ?? '',
      assicurazione: json['assicurazione']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fotoLibrettoPath: json['fotoLibrettoPath']?.toString() ?? '',
      fotoLibrettoCacheKey: json['fotoLibrettoCacheKey']?.toString() ?? '',
    );
  }
}

/// ✅ RESULT FIRMA (STEP C: timestamp firma)
class FirmaResult {
  final String base64Data;
  final String timestampUtcIso;

  FirmaResult({required this.base64Data, required this.timestampUtcIso});
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

  /// ✅ STEP C: timestamp firma A/B (ISO UTC)
  final String timestampFirmaA;
  final String timestampFirmaB;

  final String colpevole;

  final String codiceOfficina;

  /// Impronta di integrità (SHA-256) dei dati e allegati
  final String hashIntegrita;
  final String emailSendStatus;
  final String emailSendMessage;
  final String emailSendLastAttemptAt;

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
    this.emailSendStatus = '',
    this.emailSendMessage = '',
    this.emailSendLastAttemptAt = '',
  });

  String _canonicalAddress(String street, String zip, String city) {
    final locality = [
      zip.trim(),
      city.trim(),
    ].where((value) => value.isNotEmpty).join(' ');

    return [
      street.trim(),
      locality,
    ].where((value) => value.isNotEmpty).join(', ');
  }

  Map<String, dynamic> _canonicalDriver({
    required String firstName,
    required String lastName,
    required String plate,
    required String phone,
    required String email,
    required String address,
    required String insurance,
  }) =>
      {
        'first_name': firstName,
        'last_name': lastName,
        'plate': plate,
        'phone': phone,
        'email': email,
        'address': address,
        'insurance': insurance,
        'policy_number': '',
        'claim_number': '',
        'insurance_product': '',
        'coverage': '',
        'coverage_modules': <String>[],
        'avb': '',
      };

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
        'conducentiAggiuntivi':
            conducentiAggiuntivi.map((d) => d.toJson()).toList(),
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
        'emailSendStatus': emailSendStatus,
        'emailSendMessage': emailSendMessage,
        'emailSendLastAttemptAt': emailSendLastAttemptAt,
        'case_type': 'two_vehicle_accident',
        'damage_type': 'Haftpflichtschaden',
        'description': descrizione,
        'driverA': _canonicalDriver(
          firstName: nomeA,
          lastName: cognomeA,
          plate: targaA,
          phone: telefonoA,
          email: emailA,
          address: _canonicalAddress(indirizzoA, zipA, cityA),
          insurance: assicurazioneA,
        ),
        'driverB': _canonicalDriver(
          firstName: nomeB,
          lastName: cognomeB,
          plate: targaB,
          phone: telefonoB,
          email: emailB,
          address: _canonicalAddress(indirizzoB, zipB, cityB),
          insurance: assicurazioneB,
        ),
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

    List<ConducenteAggiuntivo> parsedConducentiAggiuntivi = [];
    if (json['conducentiAggiuntivi'] is List) {
      parsedConducentiAggiuntivi = (json['conducentiAggiuntivi'] as List)
          .map((e) => ConducenteAggiuntivo.fromJson(e as Map<String, dynamic>))
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
      conducentiAggiuntivi: parsedConducentiAggiuntivi,
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
      emailSendStatus: json['emailSendStatus'] ?? '',
      emailSendMessage: json['emailSendMessage'] ?? '',
      emailSendLastAttemptAt: json['emailSendLastAttemptAt'] ?? '',
    );
  }
}

/// STORAGE /////////////////////////////////////////////////////////////

List<Incidente> incidentiSalvati = [];
final ValueNotifier<int> incidentiRevision = ValueNotifier<int>(0);
const String _pendingSyncQueueKey = 'pendingSyncQueue';
const int _maxPendingSyncAttempts = 3;

Future<void> caricaIncidenti() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('incidenti');
  if (stored == null) {
    incidentiSalvati = [];
    incidentiRevision.value++;
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
      } else {
        incidentiRevision.value++;
      }
    } else {
      incidentiSalvati = [];
      incidentiRevision.value++;
    }
  } catch (_) {
    incidentiSalvati = [];
    incidentiRevision.value++;
  }
}

Future<void> salvaIncidenti() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'incidenti',
    jsonEncode(incidentiSalvati.map((e) => e.toJson()).toList()),
  );
  incidentiRevision.value++;
}

Future<List<Map<String, dynamic>>> _loadPendingSyncQueue() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_pendingSyncQueueKey);
  if (stored == null || stored.trim().isEmpty) {
    return <Map<String, dynamic>>[];
  }

  try {
    final decoded = jsonDecode(stored);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
}

Future<void> _savePendingSyncQueue(List<Map<String, dynamic>> queue) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_pendingSyncQueueKey, jsonEncode(queue));
}

String _pendingSyncEntryLocalId(Map<String, dynamic> entry) {
  final localId = entry['localId']?.toString().trim() ?? '';
  if (localId.isNotEmpty) return localId;
  final incident = entry['incident'];
  if (incident is Map) {
    return incident['id']?.toString().trim() ?? '';
  }
  return '';
}

Future<void> _upsertPendingSyncEntry(Map<String, dynamic> entry) async {
  final queue = await _loadPendingSyncQueue();
  final localId = _pendingSyncEntryLocalId(entry);
  final index =
      queue.indexWhere((item) => _pendingSyncEntryLocalId(item) == localId);
  if (index != -1) {
    queue[index] = entry;
  } else {
    queue.add(entry);
  }
  await _savePendingSyncQueue(queue);
}

Future<void> _removePendingSyncEntry(String localId) async {
  final queue = await _loadPendingSyncQueue();
  queue.removeWhere((entry) => _pendingSyncEntryLocalId(entry) == localId);
  await _savePendingSyncQueue(queue);
}

Future<Map<String, dynamic>?> _findPendingSyncEntry(String incidentId) async {
  final queue = await _loadPendingSyncQueue();
  for (final entry in queue) {
    final localId = _pendingSyncEntryLocalId(entry);
    if (localId == incidentId) return entry;
    final incident = entry['incident'];
    if (incident is Map && incident['id']?.toString().trim() == incidentId) {
      return entry;
    }
  }
  return null;
}

bool _isStorageBackedAttachment(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.startsWith('http') || trimmed.startsWith('claims/');
}

Future<bool> _hasInternetConnection() async {
  try {
    final uri = Uri.parse('$supabaseUrl/auth/v1/health');
    final response = await http.get(uri).timeout(const Duration(seconds: 5));
    return response.statusCode >= 200 && response.statusCode < 500;
  } catch (_) {
    return false;
  }
}

bool _hasCompleteCidSignatures(Incidente incident) {
  bool hasSignature(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    try {
      return base64Decode(trimmed).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  return hasSignature(incident.firmaAPath) && hasSignature(incident.firmaBPath);
}

bool _cidEmailAlreadySent(Incidente incident) =>
    incident.emailSendStatus == 'sent';

String _cidAwaitingSignaturesMessage({required bool synced}) => synced
    ? 'Pratica sincronizzata. L’invio automatico partirà dopo entrambe le firme.'
    : 'Pratica salvata. L’invio automatico partirà dopo entrambe le firme.';

String _cidOfflinePendingMessage() =>
    'Pratica salvata offline. Verrà sincronizzata automaticamente; l’e-mail partirà dopo entrambe le firme.';

Future<Uint8List?> _readQueuedAttachmentBytes(
  Map<String, dynamic> descriptor,
) async {
  final localPath = descriptor['localPath']?.toString().trim() ?? '';
  if (!kIsWeb && localPath.isNotEmpty) {
    final file = File(localPath);
    if (await file.exists()) {
      return file.readAsBytes();
    }
  }

  final cacheKey = descriptor['cacheKey']?.toString().trim() ?? '';
  if (cacheKey.isNotEmpty) {
    final cached = await LocalImageCache.getImage(cacheKey);
    if (cached != null) return cached;
  }

  final bytesBase64 = descriptor['bytesBase64']?.toString().trim() ?? '';
  if (bytesBase64.isNotEmpty) {
    return base64Decode(bytesBase64);
  }

  return null;
}

Future<Incidente> _syncPendingQueueEntry(Map<String, dynamic> entry) async {
  final localId = _pendingSyncEntryLocalId(entry);
  var attempts = (entry['attempts'] as num?)?.toInt() ?? 0;
  var incident = Incidente.fromJson(
    Map<String, dynamic>.from(entry['incident'] as Map),
  );
  final previousId = localId == incident.id ? null : localId;

  debugPrint('SYNC CLAIM START: localId=$localId incidentId=${incident.id}');

  final queueSnapshot = Map<String, dynamic>.from(entry)
    ..['attempts'] = attempts + 1
    ..['lastAttemptAt'] = DateTime.now().toUtc().toIso8601String();
  await _upsertPendingSyncEntry(queueSnapshot);

  incident = await _persistIncidentEmailSendState(
    incident,
    status: 'syncing',
    message: 'Sincronizzazione in corso…',
    previousId: previousId,
  );

  final supabaseService = SupabaseService();
  final realClaimId = await _ensurePersistedClaimId(incident);
  if (realClaimId != incident.id) {
    incident = Incidente.fromJson({
      ...incident.toJson(),
      'id': realClaimId,
    });
  }

  final damageUrls = incident.fotoDanni
      .where((value) => _isStorageBackedAttachment(value))
      .toList();
  var fotoLibrettoA = incident.fotoLibrettoA;
  var fotoLibrettoB = incident.fotoLibrettoB;

  debugPrint('SYNC ATTACHMENTS START: claimId=$realClaimId');

  Future<String?> uploadQueuedAttachment(
    Map<String, dynamic>? descriptor, {
    required String kind,
  }) async {
    if (descriptor == null) return null;
    final bytes = await _readQueuedAttachmentBytes(descriptor);
    if (bytes == null || bytes.isEmpty) return null;
    final filename =
        descriptor['filename']?.toString().trim().isNotEmpty == true
            ? descriptor['filename'].toString().trim()
            : '${kind}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final contentType =
        descriptor['contentType']?.toString().trim().isNotEmpty == true
            ? descriptor['contentType'].toString().trim()
            : 'image/jpeg';
    return supabaseService.uploadClaimImageBytes(
      claimId: realClaimId,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      kind: kind,
    );
  }

  final librettoA = entry['librettoA'];
  if (!_isStorageBackedAttachment(fotoLibrettoA)) {
    final uploaded = await uploadQueuedAttachment(
      librettoA is Map ? Map<String, dynamic>.from(librettoA) : null,
      kind: 'libretto',
    );
    if (uploaded != null && uploaded.isNotEmpty) {
      fotoLibrettoA = uploaded;
    }
  }

  final librettoB = entry['librettoB'];
  if (!_isStorageBackedAttachment(fotoLibrettoB)) {
    final uploaded = await uploadQueuedAttachment(
      librettoB is Map ? Map<String, dynamic>.from(librettoB) : null,
      kind: 'libretto',
    );
    if (uploaded != null && uploaded.isNotEmpty) {
      fotoLibrettoB = uploaded;
    }
  }

  final damageAttachments = entry['damageAttachments'];
  if (damageAttachments is List) {
    for (final rawAttachment in damageAttachments.whereType<Map>()) {
      final attachment = Map<String, dynamic>.from(rawAttachment);
      final uploaded = await uploadQueuedAttachment(attachment, kind: 'damage');
      if (uploaded != null &&
          uploaded.isNotEmpty &&
          !damageUrls.contains(uploaded)) {
        damageUrls.add(uploaded);
      }
    }
  }

  incident = Incidente.fromJson({
    ...incident.toJson(),
    'id': realClaimId,
    'fotoLibrettoA': fotoLibrettoA,
    'fotoLibrettoB': fotoLibrettoB,
    'fotoDanni': damageUrls,
  });

  await Supabase.instance.client.from('claims').update({
    'payload_json': incident.toJson(),
    'workshop_code': incident.codiceOfficina,
    'hashed_token': incident.hashIntegrita,
  }).eq('id', realClaimId);

  try {
    final sync = IncidentsSyncService();
    await sync.uploadIncident(
      payload: incident.toJson(),
      hashSha256: incident.hashIntegrita,
      timestampUtc: DateTime.now().toUtc(),
      locale: linguaSelezionata.value.languageCode,
      deviceId: null,
    );
  } catch (e, st) {
    debugPrint('SYNC ERROR: uploadIncident $e');
    debugPrint('$st');
  }

  if (_cidEmailAlreadySent(incident)) {
    debugPrint('[CIDEmail] skipped: already sent');
    await _removePendingSyncEntry(localId);
    if (kIsWeb) {
      await LocalImageCache.clearIncidentImages(localId);
    }
    debugPrint('SYNC DONE: claimId=${incident.id}');
    return incident;
  }

  if (!_hasCompleteCidSignatures(incident)) {
    debugPrint('[CIDEmail] skipped: signatures missing');
    incident = await _persistIncidentEmailSendState(
      incident,
      status: 'awaiting_signatures',
      message: _cidAwaitingSignaturesMessage(synced: true),
      previousId: previousId,
    );
    await _removePendingSyncEntry(localId);
    if (kIsWeb) {
      await LocalImageCache.clearIncidentImages(localId);
    }
    debugPrint('SYNC DONE: claimId=${incident.id}');
    return incident;
  }

  final recipients = _collectSendRecipients(
    emailA: incident.emailA,
    emailB: incident.emailB,
  );
  if (recipients.isEmpty) {
    incident = await _persistIncidentEmailSendState(
      incident,
      status: 'skipped',
      message:
          'Pratica sincronizzata. Nessuna email disponibile per l’invio automatico.',
      previousId: previousId,
    );
    await _removePendingSyncEntry(localId);
    if (kIsWeb) {
      await LocalImageCache.clearIncidentImages(localId);
    }
    debugPrint('SYNC DONE: claimId=${incident.id}');
    return incident;
  }

  debugPrint('[CIDEmail] sending after both signatures');
  await _invokeSendCidEmailEdgeFunction(
    claimId: realClaimId,
    incident: incident,
    recipients: recipients,
  );
  debugPrint('[CIDEmail] send success');

  incident = await _persistIncidentEmailSendState(
    incident,
    status: 'sent',
    message: 'Pratica sincronizzata e inviata.',
    previousId: previousId,
  );
  await _removePendingSyncEntry(localId);
  if (kIsWeb) {
    await LocalImageCache.clearIncidentImages(localId);
  }
  debugPrint('SYNC DONE: claimId=${incident.id}');
  return incident;
}

Future<void> _syncPendingQueue() async {
  final hasInternet = await _hasInternetConnection();
  if (!hasInternet) return;

  final queue = await _loadPendingSyncQueue();
  if (queue.isEmpty) return;

  debugPrint('SYNC QUEUE START: count=${queue.length}');

  for (final rawEntry in queue) {
    final entry = Map<String, dynamic>.from(rawEntry);
    final attempts = (entry['attempts'] as num?)?.toInt() ?? 0;
    if (attempts >= _maxPendingSyncAttempts) continue;

    try {
      await _syncPendingQueueEntry(entry);
    } catch (e, st) {
      debugPrint('SYNC ERROR: $e');
      debugPrint('$st');
      final incident = Incidente.fromJson(
        Map<String, dynamic>.from(entry['incident'] as Map),
      );
      final stillOnline = await _hasInternetConnection();
      final nextStatus = stillOnline && attempts + 1 >= _maxPendingSyncAttempts
          ? 'failed'
          : 'pending_sync';
      final nextMessage = stillOnline && attempts + 1 >= _maxPendingSyncAttempts
          ? 'Sincronizzazione fallita — Riprova'
          : _cidOfflinePendingMessage();
      final updated = await _persistIncidentEmailSendState(
        incident,
        status: nextStatus,
        message: nextMessage,
        previousId: _pendingSyncEntryLocalId(entry) == incident.id
            ? null
            : _pendingSyncEntryLocalId(entry),
      );
      await _upsertPendingSyncEntry({
        ...entry,
        'incident': updated.toJson(),
        'attempts': attempts + 1,
        'status': nextStatus,
        'lastAttemptAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }
}

class PendingSyncManager {
  static Timer? _timer;
  static bool _syncing = false;

  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(trigger()),
    );
    unawaited(trigger());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> trigger() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _syncPendingQueue();
    } finally {
      _syncing = false;
    }
  }
}

Future<String> calcolaHashIntegrita(Incidente inc) async {
  final data = Map<String, dynamic>.from(inc.toJson());
  data.remove('hashIntegrita');

  final collector = _DigestCollector();
  final digestInput = sha256.startChunkedConversion(collector);

  // Hash dei dati strutturati
  digestInput.add(utf8.encode(jsonEncode(data)));

  if (!kIsWeb) {
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
    conducentiAggiuntivi: inc.conducentiAggiuntivi,
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
    emailSendStatus: inc.emailSendStatus,
    emailSendMessage: inc.emailSendMessage,
    emailSendLastAttemptAt: inc.emailSendLastAttemptAt,
  );
}

Incidente _copyIncidenteWithEmailSendState(
  Incidente inc, {
  required String status,
  required String message,
  String? lastAttemptAt,
}) {
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
    conducentiAggiuntivi: inc.conducentiAggiuntivi,
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
    hashIntegrita: inc.hashIntegrita,
    emailSendStatus: status,
    emailSendMessage: message,
    emailSendLastAttemptAt:
        lastAttemptAt ?? DateTime.now().toUtc().toIso8601String(),
  );
}

Future<Incidente> _persistIncidentEmailSendState(
  Incidente inc, {
  required String status,
  required String message,
  String? previousId,
}) async {
  final updated = _copyIncidenteWithEmailSendState(
    inc,
    status: status,
    message: message,
  );
  debugPrint(
    'EMAIL STATUS SET: '
    'status=$status claimId=${updated.id} '
    'message=$message at=${updated.emailSendLastAttemptAt}',
  );

  final index = incidentiSalvati.indexWhere(
    (e) => e.id == updated.id || (previousId != null && e.id == previousId),
  );
  if (index != -1) {
    incidentiSalvati[index] = updated;
  } else {
    incidentiSalvati.insert(0, updated);
  }
  await salvaIncidenti();
  return updated;
}

// Cache e helper per la generazione del QR CLIENTE (CID1:<token>).
final Map<String, Future<String>> _clientQrTokenCache = {};
final Map<String, Future<String>> _claimUuidCache = {};
const String _workshopPurpose = 'workshop_intake';

Future<String> _ensurePersistedClaimId(Incidente inc) async {
  if (QrPayload.looksLikeUuid(inc.id)) {
    return inc.id;
  }

  SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    throw Exception(
        'Supabase non inizializzato: controlla Supabase.initialize/chiavi.');
  }

  final insertResult = await client
      .from('claims')
      .insert({
        'status': 'warten_auf_freigabe',
        'payload_json': inc.toJson(),
      })
      .select()
      .single();

  final claimId = '${insertResult['id'] ?? ''}'.trim();
  if (!QrPayload.looksLikeUuid(claimId)) {
    throw Exception('Insert claims ha restituito un id non UUID: $claimId');
  }

  return claimId;
}

Future<String> _ensureClaimUuid(Incidente inc) {
  if (QrPayload.looksLikeUuid(inc.id)) {
    return Future.value(inc.id);
  }

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

Future<String?> _ensureWorkshopClaimLink(
  Incidente inc, {
  Duration expiresIn = const Duration(days: 14),
  int maxUses = 10,
}) async {
  debugPrint('QR STEP 1: lookup existing claim_link');
  final claimUuid = await _ensureClaimUuid(inc);
  final now = DateTime.now().toUtc();
  final expiresAtIso = now.add(expiresIn).toIso8601String();

  SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    throw Exception(
        'Supabase non inizializzato: controlla Supabase.initialize/chiavi.');
  }

  try {
    final existing = await client
        .from('claim_links')
        .select('token, expires_at, used_count, max_uses')
        .eq('claim_id', claimUuid)
        .eq('purpose', _workshopPurpose)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      debugPrint('QR STEP 2: existing link found');
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
      if (token.isNotEmpty && !expired && !exhausted) {
        return token;
      }
    }
  } catch (e, st) {
    debugPrint('QR ERROR TYPE: ${e.runtimeType}');
    debugPrint('QR ERROR: $e');
    debugPrint('$st');
  }

  debugPrint('QR STEP 3: create new claim_link');
  Map<String, dynamic> insertRes;
  try {
    insertRes = await client
        .from('claim_links')
        .insert({
          'claim_id': claimUuid,
          'purpose': _workshopPurpose,
          'expires_at': expiresAtIso,
          'max_uses': maxUses,
        })
        .select('token')
        .single();
  } catch (e, st) {
    debugPrint('QR ERROR TYPE: ${e.runtimeType}');
    debugPrint('QR ERROR: $e');
    debugPrint('$st');
    rethrow;
  }

  final token = (insertRes['token'] as String?)?.trim() ?? '';
  if (token.isEmpty) {
    throw Exception('Token claim_links vuoto per officina.');
  }
  debugPrint('QR STEP 4: token generated');
  return token;
}

Future<String> buildClientQrData(Incidente inc) async {
  final token = await _ensureClientQrToken(inc);
  return QrPayload.cid1(token);
}

Future<String> buildWorkshopQrData(Incidente inc) async {
  final token = await _ensureWorkshopClaimLink(inc);
  if (token == null || token.isEmpty) {
    throw Exception('Token QR officina non disponibile.');
  }
  debugPrint('QR STEP 5: qr url built');
  return QrPayload.cid1(token);
}

/// GPS /////////////////////////////////////////////////////////////

const DeviceLocationService _globalDeviceLocationService =
    DeviceLocationService();

Future<Position?> getPosizioneConPermessi() async {
  final result = await _globalDeviceLocationService.requestCurrentPosition(
    timeout: const Duration(seconds: 12),
  );
  return result.position;
}

Future<String?> getIndirizzoDaGps({Position? position}) async {
  final pos = position ?? await getPosizioneConPermessi();
  if (pos == null) return null;

  return _globalDeviceLocationService.resolveAddressLabel(pos);
}

/// ✅ LINGUA MANUALE

const _supportedLangs = <String>['it', 'de', 'fr', 'en'];
const _selectedLocaleKey = 'selected_locale';
const _legacyLocaleKey = 'lang_preference';

Locale _localeFromCode(String code) {
  if (_supportedLangs.contains(code)) return Locale(code);
  return const Locale('de');
}

Future<Locale> caricaLinguaPreferita() async {
  final prefs = await SharedPreferences.getInstance();
  final saved =
      prefs.getString(_selectedLocaleKey) ?? prefs.getString(_legacyLocaleKey);
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
  await prefs.setString(_selectedLocaleKey, code);
  await prefs.setString(_legacyLocaleKey, code);
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

class CidDigitaleApp extends StatefulWidget {
  const CidDigitaleApp({super.key});

  @override
  State<CidDigitaleApp> createState() => _CidDigitaleAppState();
}

class _CidDigitaleAppState extends State<CidDigitaleApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PendingSyncManager.start();
    AppointmentRequestsSyncManager.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PendingSyncManager.stop();
    AppointmentRequestsSyncManager.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PendingSyncManager.trigger());
      unawaited(AppointmentRequestsSyncManager.trigger());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: linguaSelezionata,
      builder: (context, locale, _) {
        return MaterialApp(
          key: ValueKey('locale_${locale.languageCode}'),
          debugShowCheckedModeBanner: false,
          locale: locale,
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
            '/service_anmelden': (_) => const ServiceAnmeldenScreen(),
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
  'Posizione GPS': {
    'it': 'Posizione GPS',
    'de': 'GPS-Position',
    'fr': 'Position GPS',
    'en': 'GPS location',
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

String formatClaimDisplayId(Incidente incidente) {
  final year = incidente.dataOra.year.toString().padLeft(4, '0');
  final source = incidente.id.trim();
  if (source.isEmpty) {
    return 'CID-$year-000000';
  }

  final sanitized =
      source.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '').toUpperCase();
  final seed = sanitized.isNotEmpty ? sanitized : source.toUpperCase();
  var value = 0;
  for (final codeUnit in seed.codeUnits) {
    value = ((value * 31) + codeUnit) % 1000000;
  }
  final serial = value.toString().padLeft(6, '0');
  return 'CID-$year-$serial';
}

String formatWorkshopDisplayCode(Incidente incidente) {
  return '${formatClaimDisplayId(incidente)}-W';
}

Future<void> _syncClaimPayloadSnapshot(Incidente incident) async {
  if (!QrPayload.looksLikeUuid(incident.id)) return;

  try {
    await Supabase.instance.client.from('claims').update({
      'payload_json': incident.toJson(),
      'workshop_code': incident.codiceOfficina,
      'hashed_token': incident.hashIntegrita,
    }).eq('id', incident.id);
    debugPrint(
      '[CIDEmail] payload ready claimId=${incident.id} '
      'hash=${incident.hashIntegrita} workshop=${incident.codiceOfficina}',
    );
  } catch (e, st) {
    debugPrint('[CIDEmail] payload sync warning: $e');
    debugPrint('$st');
  }
}

Future<dynamic> _invokeSendCidEmailEdgeFunction({
  required String claimId,
  required Incidente incident,
  required List<String> recipients,
}) async {
  final displayId = formatClaimDisplayId(incident);
  debugPrint('[CIDEmail] start claimId=$claimId');
  debugPrint('[CIDEmail] displayId $displayId');
  debugPrint('[CIDEmail] recipient ${recipients.join(', ')}');

  await _syncClaimPayloadSnapshot(incident);

  try {
    final result = await Supabase.instance.client.functions.invoke(
      'send-cid-email',
      body: {'claimId': claimId},
    );
    debugPrint(
      '[CIDEmail] resend response status=${result.status} data=${result.data}',
    );
    if (result.status >= 400) {
      throw Exception('Edge function status ${result.status}: ${result.data}');
    }
    if (result.data is Map && (result.data as Map)['success'] == false) {
      throw Exception((result.data as Map)['error'] ?? 'Invio non riuscito');
    }
    return result;
  } catch (e, st) {
    debugPrint('[CIDEmail] error full $e');
    debugPrint('$st');
    rethrow;
  }
}

/// HOME ////////////////////////////////////////////////////////////////

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _homeBackground = Color(0xFFF8FAFC);
  static const Color _homeGradientTop = Color(0xFFEEF6FF);
  static const Color _homePrimary = Color(0xFF2563EB);
  static const Color _homeLightBlue = Color(0xFFEFF6FF);
  static const Color _homeTextDark = Color(0xFF111827);
  static const Color _homeTextGray = Color(0xFF6B7280);
  static const Color _homeBorder = Color(0xFFE5E7EB);

  final AppointmentRequestsService _appointmentRequestsService =
      AppointmentRequestsService();
  late Future<int?> _openRequestsCountFuture;

  String _copy({
    required String it,
    required String de,
    required String fr,
    required String en,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'it':
        return it;
      case 'fr':
        return fr;
      case 'en':
        return en;
      case 'de':
      default:
        return de;
    }
  }

  String _damageOtherLabel(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'it':
        return 'Altro';
      case 'en':
        return 'Other';
      case 'fr':
        return 'Autre';
      case 'de':
      default:
        return 'Sonstiges';
    }
  }

  String? _damageCardSubtitle(BuildContext context, DamageType type) {
    switch (type) {
      case DamageType.comprehensive:
        switch (Localizations.localeOf(context).languageCode) {
          case 'it':
            return 'Collisione con oggetto o danno causato dal conducente';
          case 'en':
            return 'Collision with object or self-caused damage';
          case 'fr':
            return 'Collision avec un objet ou dommage causé par le conducteur';
          case 'de':
          default:
            return 'Kollision mit Objekt oder selbst verursachter Schaden';
        }
      case DamageType.other:
        switch (Localizations.localeOf(context).languageCode) {
          case 'it':
            return 'Segnala problemi tecnici, spie o altri danni.';
          case 'en':
            return 'Report technical problems, warning lights or other damages.';
          case 'fr':
            return 'Signalez des problèmes techniques, voyants ou autres dommages.';
          case 'de':
          default:
            return 'Melden Sie technische Probleme, Warnmeldungen oder sonstige Schäden.';
        }
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _openRequestsCountFuture = _loadOpenRequestsCount();
    incidentiRevision.addListener(_onIncidentiRevision);
    unawaited(PendingSyncManager.trigger());
  }

  @override
  void dispose() {
    incidentiRevision.removeListener(_onIncidentiRevision);
    super.dispose();
  }

  void _onIncidentiRevision() {
    if (!mounted) return;
    setState(() {});
  }

  Future<int?> _loadOpenRequestsCount() async {
    try {
      final requests = await _appointmentRequestsService.fetchMyRequests();
      return requests
          .where((request) =>
              request.requestStatus != 'completed' &&
              request.requestStatus != 'cancelled')
          .length;
    } catch (e) {
      debugPrint('open requests count unavailable: $e');
      return null;
    }
  }

  void _refreshHomeData() {
    if (!mounted) return;
    setState(() {
      _openRequestsCountFuture = _loadOpenRequestsCount();
    });
  }

  Future<PersonalVehicleData?> _showPersonalVehicleSelector(
    PersonalVehicleCollection collection,
  ) {
    var selected = collection.primaryVehicle ?? collection.vehicles.first;
    return showModalBottomSheet<PersonalVehicleData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.of(context)!.personalVehicleSelect,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: collection.vehicles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final vehicle = collection.vehicles[index];
                      final isSelected = vehicle.id == selected.id;
                      final name = vehicle.displayName.isNotEmpty
                          ? vehicle.displayName
                          : vehicle.targa;
                      return InkWell(
                        onTap: () => setSheetState(() => selected = vehicle),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.directions_car_outlined,
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        vehicle.targa,
                                        vehicle.assicurazione,
                                      ]
                                          .where(
                                            (value) => value.trim().isNotEmpty,
                                          )
                                          .join(' · '),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(selected),
                  child: Text(
                    AppLocalizations.of(context)!
                        .personalVehicleContinueWithSelection,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _vaiANuovoIncidente() async {
    PersonalVehicleData? selectedVehicle;
    try {
      final collection = await PersonalVehicleStorage().loadOrMigrate();
      if (!mounted) return;
      if (collection.vehicles.length == 1) {
        selectedVehicle = collection.vehicles.first;
      } else if (collection.vehicles.length > 1) {
        selectedVehicle = await _showPersonalVehicleSelector(collection);
        if (selectedVehicle == null || !mounted) return;
      }
    } catch (_) {
      selectedVehicle = null;
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NuovaPraticaIncidentePage(
          initialVehicle: selectedVehicle,
        ),
      ),
    );
    await caricaIncidenti();
    _refreshHomeData();
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
              DamageType.other,
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
                case DamageType.other:
                  return Icons.more_horiz_rounded;
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
                case DamageType.other:
                  return _damageOtherLabel(context);
              }
            },
            subtitleFor: (t) => _damageCardSubtitle(context, t),
            onSelected: (t) => Navigator.of(ctx).pop(t),
          ),
        );
      },
    );

    if (selected == null) return;

    await _openCalendarSameLogic(selected, l10n);
  }

  Future<void> _openCalendarSameLogic(
    DamageType damageType,
    AppLocalizations l10n,
  ) async {
    final serviceType = _damageServiceType(damageType);
    final title =
        '${l10n.damage_type_title} - ${_damageLabel(l10n, damageType)}';

    await openWorkshopSelectionStep(
      context,
      title: title,
      serviceType: serviceType,
      damageType: damageType.name,
    );
    _refreshHomeData();
  }

  Future<void> _openServiceAnmelden(BuildContext context) async {
    await Navigator.of(context).pushNamed('/service_anmelden');
    _refreshHomeData();
  }

  Future<void> _openRaederWechsel(BuildContext context) async {
    await Navigator.of(context).pushNamed('/raeder_wechsel');
    _refreshHomeData();
  }

  Future<void> _openMyRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MyRequestsPage(
          incidentsTab: StoricoPage(embedOnlyBody: true),
        ),
      ),
    );
    _refreshHomeData();
  }

  Future<void> _openPersonalQr() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DriverPersonalQrScreen(),
      ),
    );
    _refreshHomeData();
  }

  Future<void> _exitHome() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Exit signOut skipped: $e');
    }

    if (!mounted) return;

    final target =
        kIsWeb ? const AuthGate(homeBuilder: _homeBuilder) : const LoginPage();

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  String _openRequestsBadgeLabel(int count) {
    return _copy(
      it: '$count aperte',
      de: '$count offen',
      fr: '$count ouvertes',
      en: '$count open',
    );
  }

  Widget _topBarShell({
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _homeBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeader(String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _topBarShell(
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.language_rounded,
                  size: 20,
                  color: _homeTextDark,
                ),
                tooltip: 'Language',
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
            ),
            _topBarShell(
              child: TextButton.icon(
                onPressed: _exitHome,
                icon: const Icon(
                  Icons.exit_to_app_rounded,
                  size: 18,
                  color: _homeTextDark,
                ),
                label: const Text(
                  'Exit',
                  style: TextStyle(
                    color: _homeTextDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            _topBarShell(
              child: IconButton(
                onPressed: _vaiAImpostazioni,
                icon: const Icon(Icons.settings, color: _homeTextDark),
                tooltip: tr(context, 'home_settings_tooltip'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'CID Digitale',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: _homeTextDark,
                letterSpacing: -0.8,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _homeTextGray,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Widget _buildHeroCard({
    required String title,
    required String subtitle,
  }) {
    return _HomeSurfaceCard(
      radius: 28,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 720;
          final logo = Container(
            width: horizontal ? 134 : 120,
            height: horizontal ? 134 : 120,
            decoration: BoxDecoration(
              color: _homeLightBlue,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.all(18),
            child: Image.asset(
              'assets/images/crashform_logo.png',
              fit: BoxFit.contain,
            ),
          );

          final copy = Column(
            crossAxisAlignment: horizontal
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: horizontal ? TextAlign.left : TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _homeTextDark,
                      letterSpacing: -0.6,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: horizontal ? TextAlign.left : TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _homeTextGray,
                      height: 1.45,
                    ),
              ),
            ],
          );

          if (!horizontal) {
            return Column(
              children: [
                logo,
                const SizedBox(height: 18),
                copy,
              ],
            );
          }

          return Row(
            children: [
              logo,
              const SizedBox(width: 24),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPrimaryIncidentButton(String label) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _homePrimary.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _vaiANuovoIncidente,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _homePrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(60),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }

  Widget _buildMyRequestsCard(AppLocalizations l10n, String subtitle) {
    return FutureBuilder<int?>(
      future: _openRequestsCountFuture,
      builder: (context, snapshot) {
        final count = snapshot.data;
        return _HomeActionCard(
          icon: Icons.inventory_2_rounded,
          iconColor: _homePrimary,
          iconBackgroundColor: _homeLightBlue,
          title: l10n.my_requests_title,
          subtitle: subtitle,
          badgeLabel: count == null ? null : _openRequestsBadgeLabel(count),
          onTap: _openMyRequests,
        );
      },
    );
  }

  Widget _buildPersonalQrCard(String title, String subtitle) {
    return _HomeActionCard(
      icon: Icons.qr_code_2_rounded,
      iconColor: _homePrimary,
      iconBackgroundColor: _homeLightBlue,
      title: title,
      subtitle: subtitle,
      onTap: _openPersonalQr,
    );
  }

  Widget _buildWorkshopServices(
    AppLocalizations l10n,
    String servicesSubtitle,
    String mostRequestedBadge,
    String seasonalBadge,
    String quickHelpBadge,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeSectionHeader(
          title: l10n.workshop_services_title,
          subtitle: servicesSubtitle,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 780;
            if (!wide) {
              return Column(
                children: [
                  _HomeServiceTile(
                    icon: Icons.calendar_month_rounded,
                    title: l10n.service_anmelden,
                    badgeLabel: mostRequestedBadge,
                    onTap: () => _openServiceAnmelden(context),
                  ),
                  const SizedBox(height: 14),
                  _HomeServiceTile(
                    icon: Icons.tire_repair_rounded,
                    title: l10n.raeder_wechsel,
                    badgeLabel: seasonalBadge,
                    onTap: () => _openRaederWechsel(context),
                  ),
                  const SizedBox(height: 14),
                  _HomeServiceTile(
                    icon: Icons.car_crash_rounded,
                    title: l10n.damage_type_title,
                    badgeLabel: quickHelpBadge,
                    onTap: () => _openDamageTypePicker(context),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _HomeServiceTile(
                        icon: Icons.calendar_month_rounded,
                        title: l10n.service_anmelden,
                        badgeLabel: mostRequestedBadge,
                        onTap: () => _openServiceAnmelden(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _HomeServiceTile(
                        icon: Icons.tire_repair_rounded,
                        title: l10n.raeder_wechsel,
                        badgeLabel: seasonalBadge,
                        onTap: () => _openRaederWechsel(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _HomeServiceTile(
                  icon: Icons.car_crash_rounded,
                  title: l10n.damage_type_title,
                  badgeLabel: quickHelpBadge,
                  onTap: () => _openDamageTypePicker(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(
    String title,
    String callWorkshopLabel,
    String findNearbyLabel,
    String emergencyLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeSectionHeader(title: title),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 960
                ? 3
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;
            const gap = 12.0;
            final itemWidth = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (gap * (columns - 1))) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _HomeQuickActionPill(
                    icon: Icons.phone_in_talk_rounded,
                    label: callWorkshopLabel,
                    onTap: _chiamaCarrozzeria,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _HomeQuickActionPill(
                    icon: Icons.location_on_outlined,
                    label: findNearbyLabel,
                    onTap: () {
                      _apriUrl(
                        Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=carrozzeria+vicino+a+me',
                        ),
                        'Impossibile aprire Google Maps.',
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _HomeQuickActionPill(
                    icon: Icons.emergency_rounded,
                    label: emergencyLabel,
                    emergency: true,
                    onTap: _mostraEmergenze,
                  ),
                ),
              ],
            );
          },
        ),
      ],
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
      case DamageType.other:
        return _damageOtherLabel(context);
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
      case DamageType.other:
        return 'damage_other';
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
    final headerSubtitle = _copy(
      it: 'Gestione intelligente degli incidenti',
      de: 'Intelligente Schadenverwaltung',
      fr: 'Gestion intelligente des sinistres',
      en: 'Intelligent accident management',
    );
    final heroTitle = _copy(
      it: 'Benvenuto nel tuo CID Digitale',
      de: 'Willkommen in deinem digitalen Unfallbericht',
      fr: 'Bienvenue dans votre constat numérique',
      en: 'Welcome to your digital accident report',
    );
    final heroSubtitle = _copy(
      it: 'Gestisci incidenti, richieste e servizi officina in modo rapido e sicuro.',
      de: 'Verwalte Unfälle, Anfragen und Werkstattservices schnell und sicher.',
      fr: 'Gérez les accidents, demandes et services d’atelier rapidement et en toute sécurité.',
      en: 'Manage accidents, requests and workshop services quickly and securely.',
    );
    final requestsSubtitle = _copy(
      it: 'Controlla lo stato delle tue pratiche',
      de: 'Status deiner Anfragen prüfen',
      fr: 'Consultez l’état de vos demandes',
      en: 'Check the status of your requests',
    );
    final personalQrTitle = _copy(
      it: 'Mio QR personale',
      de: 'Mein persönlicher QR',
      fr: 'Mon QR personnel',
      en: 'My personal QR',
    );
    final personalQrSubtitle = _copy(
      it: 'Salva i tuoi dati cliente, veicolo e assicurazione e genera un QR pronto per la compilazione automatica.',
      de: 'Speichere Kunden-, Fahrzeug- und Versicherungsdaten und erzeuge einen QR für die automatische Befüllung.',
      fr: 'Enregistre les données client, véhicule et assurance et génère un QR prêt pour le remplissage automatique.',
      en: 'Save customer, vehicle and insurance details and generate a QR ready for automatic filling.',
    );
    final servicesSubtitle = _copy(
      it: 'Prenota rapidamente gli interventi disponibili.',
      de: 'Buche verfügbare Werkstattservices schnell.',
      fr: 'Réservez rapidement les services disponibles.',
      en: 'Quickly book available workshop services.',
    );
    final mostRequestedBadge = _copy(
      it: 'Più richiesto',
      de: 'Häufig gefragt',
      fr: 'Le plus demandé',
      en: 'Most requested',
    );
    final seasonalBadge = _copy(
      it: 'Stagionale',
      de: 'Saisonal',
      fr: 'Saisonnier',
      en: 'Seasonal',
    );
    final quickHelpBadge = _copy(
      it: 'Guida rapida',
      de: 'Schnelle Hilfe',
      fr: 'Aide rapide',
      en: 'Quick help',
    );
    final callWorkshopLabel = _copy(
      it: 'Chiama la mia carrozzeria',
      de: 'Meine Werkstatt anrufen',
      fr: 'Appeler mon atelier',
      en: 'Call my workshop',
    );
    final findNearbyLabel = _copy(
      it: 'Trova carrozzeria nei dintorni',
      de: 'Werkstatt in der Nähe finden',
      fr: 'Trouver un atelier à proximité',
      en: 'Find a nearby workshop',
    );
    final emergencyLabel = _copy(
      it: 'Chiama numeri di emergenza',
      de: 'Notrufnummern anrufen',
      fr: 'Appeler les numéros d’urgence',
      en: 'Call emergency numbers',
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth >= 900 ? 24.0 : 20.0;

    return Scaffold(
      backgroundColor: _homeBackground,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_homeGradientTop, _homeBackground],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: -72,
                right: -42,
                child: _HomeBackgroundOrb(
                  size: 220,
                  color: Color(0xFFDCEBFF),
                ),
              ),
              const Positioned(
                top: 320,
                left: -84,
                child: _HomeBackgroundOrb(
                  size: 180,
                  color: Color(0xFFE8F2FF),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(headerSubtitle),
                        const SizedBox(height: 22),
                        _buildHeroCard(
                          title: heroTitle,
                          subtitle: heroSubtitle,
                        ),
                        const SizedBox(height: 18),
                        _buildPrimaryIncidentButton(
                          tr(context, 'home_new_incident'),
                        ),
                        const SizedBox(height: 18),
                        _buildMyRequestsCard(l10n, requestsSubtitle),
                        const SizedBox(height: 18),
                        _buildPersonalQrCard(
                          personalQrTitle,
                          personalQrSubtitle,
                        ),
                        const SizedBox(height: 22),
                        _buildWorkshopServices(
                          l10n,
                          servicesSubtitle,
                          mostRequestedBadge,
                          seasonalBadge,
                          quickHelpBadge,
                        ),
                        const SizedBox(height: 22),
                        _buildQuickActions(
                          l10n.quick_actions_title,
                          callWorkshopLabel,
                          findNearbyLabel,
                          emergencyLabel,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBackgroundOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _HomeBackgroundOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.75),
        ),
      ),
    );
  }
}

class _HomeSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const _HomeSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _HomeSectionHeader({
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF111827),
        );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF6B7280),
          height: 1.45,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: subtitleStyle),
        ],
      ],
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String subtitle;
  final String? badgeLabel;
  final VoidCallback onTap;

  const _HomeActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _HomeSurfaceCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          if (badgeLabel != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeLabel!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF2563EB),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }
}

class _HomeServiceTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String badgeLabel;
  final VoidCallback onTap;

  const _HomeServiceTile({
    required this.icon,
    required this.title,
    required this.badgeLabel,
    required this.onTap,
  });

  @override
  State<_HomeServiceTile> createState() => _HomeServiceTileState();
}

class _HomeServiceTileState extends State<_HomeServiceTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, _hovered ? -2.0 : 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withOpacity(_hovered ? 0.09 : 0.04),
              blurRadius: _hovered ? 24 : 18,
              offset: Offset(0, _hovered ? 12 : 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Container(
              height: 94,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 24,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF111827),
                                  ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Text(
                            widget.badgeLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeQuickActionPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emergency;

  const _HomeQuickActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emergency = false,
  });

  @override
  State<_HomeQuickActionPill> createState() => _HomeQuickActionPillState();
}

class _HomeQuickActionPillState extends State<_HomeQuickActionPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        widget.emergency ? const Color(0xFFF1C7C7) : const Color(0xFFE5E7EB);
    final iconColor =
        widget.emergency ? const Color(0xFFB42318) : const Color(0xFF2563EB);
    final backgroundColor =
        widget.emergency ? const Color(0xFFFFFBFB) : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, _hovered ? -1.0 : 0.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color:
                  const Color(0xFF0F172A).withOpacity(_hovered ? 0.08 : 0.03),
              blurRadius: _hovered ? 18 : 14,
              offset: Offset(0, _hovered ? 10 : 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF111827),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
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

class _ConducenteExtraFormData {
  final int sequence;
  final String driverKey;
  _DriverCourtesy? courtesy;
  final TextEditingController nomeController;
  final TextEditingController cognomeController;
  final TextEditingController indirizzoController;
  final TextEditingController zipController;
  final TextEditingController cityController;
  final TextEditingController countryController;
  final TextEditingController targaController;
  final TextEditingController assicurazioneController;
  final TextEditingController telefonoController;
  final TextEditingController emailController;
  String? fotoLibrettoPath;
  Uint8List? fotoLibrettoBytes;
  String? fotoLibrettoCacheKey;

  _ConducenteExtraFormData({
    required this.sequence,
    required this.driverKey,
    required this.nomeController,
    required this.cognomeController,
    required this.indirizzoController,
    required this.zipController,
    required this.cityController,
    required this.countryController,
    required this.targaController,
    required this.assicurazioneController,
    required this.telefonoController,
    required this.emailController,
  });

  bool get hasAnyValue {
    return nomeController.text.trim().isNotEmpty ||
        cognomeController.text.trim().isNotEmpty ||
        courtesy != null ||
        indirizzoController.text.trim().isNotEmpty ||
        zipController.text.trim().isNotEmpty ||
        cityController.text.trim().isNotEmpty ||
        countryController.text.trim().isNotEmpty ||
        targaController.text.trim().isNotEmpty ||
        assicurazioneController.text.trim().isNotEmpty ||
        telefonoController.text.trim().isNotEmpty ||
        emailController.text.trim().isNotEmpty ||
        (fotoLibrettoPath?.trim().isNotEmpty ?? false) ||
        (fotoLibrettoCacheKey?.trim().isNotEmpty ?? false) ||
        fotoLibrettoBytes != null;
  }

  String get persistedFotoLibrettoReference {
    final pathValue = fotoLibrettoPath?.trim() ?? '';
    if (pathValue.isNotEmpty) return pathValue;
    final cacheValue = fotoLibrettoCacheKey?.trim() ?? '';
    return cacheValue;
  }

  void dispose() {
    nomeController.dispose();
    cognomeController.dispose();
    indirizzoController.dispose();
    zipController.dispose();
    cityController.dispose();
    countryController.dispose();
    targaController.dispose();
    assicurazioneController.dispose();
    telefonoController.dispose();
    emailController.dispose();
  }
}

class _DriverFieldBundle {
  final TextEditingController nomeController;
  final TextEditingController cognomeController;
  final TextEditingController indirizzoController;
  final TextEditingController zipController;
  final TextEditingController cityController;
  final TextEditingController targaController;
  final TextEditingController assicurazioneController;

  _DriverFieldBundle({
    required this.nomeController,
    required this.cognomeController,
    required this.indirizzoController,
    required this.zipController,
    required this.cityController,
    required this.targaController,
    required this.assicurazioneController,
  });
}

enum _DriverCourtesy { mr, mrs, company }

class _DriverQrImportBundle {
  final TextEditingController nomeController;
  final TextEditingController cognomeController;
  final TextEditingController indirizzoController;
  final TextEditingController zipController;
  final TextEditingController cityController;
  final TextEditingController countryController;
  final TextEditingController targaController;
  final TextEditingController assicurazioneController;
  final TextEditingController telefonoController;
  final TextEditingController emailController;
  final ValueChanged<_DriverCourtesy?> setCourtesy;

  _DriverQrImportBundle({
    required this.nomeController,
    required this.cognomeController,
    required this.indirizzoController,
    required this.zipController,
    required this.cityController,
    required this.countryController,
    required this.targaController,
    required this.assicurazioneController,
    required this.telefonoController,
    required this.emailController,
    required this.setCourtesy,
  });
}

class DriverTarget {
  const DriverTarget._(this.driverKey);

  final String driverKey;

  const DriverTarget.driverA() : driverKey = 'A';
  const DriverTarget.driverB() : driverKey = 'B';

  factory DriverTarget.fromKey(String driverKey) {
    return DriverTarget._(driverKey.trim().toUpperCase());
  }
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
  const NuovaPraticaIncidentePage({
    super.key,
    this.initialVehicle,
  });

  final PersonalVehicleData? initialVehicle;

  @override
  State<NuovaPraticaIncidentePage> createState() =>
      _NuovaPraticaIncidentePageState();
}

class _NuovaPraticaIncidentePageState extends State<NuovaPraticaIncidentePage> {
  static const Color _incidentBackground = Color(0xFFF8FAFC);
  static const Color _incidentCardBorder = Color(0xFFE5E7EB);
  static const Color _incidentMutedBackground = Color(0xFFF3F4F6);
  static const Color _incidentMutedText = Color(0xFF4B5563);
  static const Color _incidentDropBorder = Color(0xFF93C5FD);
  static const double _incidentSectionSpacing = 20;

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
  final _driverACountryController = TextEditingController();
  _DriverCourtesy? _driverACourtesy;

  final _nomeBController = TextEditingController();
  final _cognomeBController = TextEditingController();
  final _targaBController = TextEditingController();
  final _assicurazioneBController = TextEditingController();

  final _telefonoBController = TextEditingController();
  final _emailBController = TextEditingController();
  final _indirizzoBController = TextEditingController();
  final _driverBZipController = TextEditingController();
  final _driverBCityController = TextEditingController();
  final _driverBCountryController = TextEditingController();
  _DriverCourtesy? _driverBCourtesy;

  final _descrizioneController = TextEditingController();
  final _damageVehicleAController = TextEditingController();
  final _damageVehicleBController = TextEditingController();

  final List<_TestimoneFormData> _testimoni = [];
  final List<_FeritoFormData> _feriti = [];
  final List<_ConducenteExtraFormData> _conducentiAggiuntivi = [];
  int _nextConducenteSequence = 0;

  final _notaVocaleAController = TextEditingController();
  final _notaVocaleBController = TextEditingController();

  late DateTime _dataOra;

  final ImagePicker _picker = ImagePicker();
  final SupabaseService _supabaseService = SupabaseService();
  String? _fotoLibrettoAPath;
  String? _fotoLibrettoBPath;
  Uint8List? _fotoLibrettoABytes;
  Uint8List? _fotoLibrettoBBytes;
  String? _fotoLibrettoACacheKey;
  String? _fotoLibrettoBCacheKey;
  final List<DamagePhotoItem> _damagePhotos = [];
  String? _draftClaimId;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _audioPlayerSub;
  bool _isRecordingAudio = false;
  bool _isSavingIncident = false;
  String? _recordingFor;
  String? _currentRecordingPath;
  String? _playingNotaFor;
  String? _notaAudioAPath;
  String? _notaAudioBPath;

  @override
  void initState() {
    super.initState();
    debugPrint('[AccidentGPS] init NuovaPraticaIncidentePage');
    final initialVehicle = widget.initialVehicle;
    if (initialVehicle != null) {
      _targaAController.text = initialVehicle.targa;
      _assicurazioneAController.text = initialVehicle.assicurazione;
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _luogoController.text.trim().isNotEmpty) return;
      debugPrint('[AccidentGPS] auto-populate on open');
      unawaited(_impostaLuogoAutomatico(forceUpdateField: false));
    });
  }

  bool _isAnyCampoBCompilato() {
    return _driverBCourtesy != null ||
        _nomeBController.text.trim().isNotEmpty ||
        _cognomeBController.text.trim().isNotEmpty ||
        _indirizzoBController.text.trim().isNotEmpty ||
        _driverBZipController.text.trim().isNotEmpty ||
        _targaBController.text.trim().isNotEmpty ||
        _assicurazioneBController.text.trim().isNotEmpty ||
        _telefonoBController.text.trim().isNotEmpty ||
        _emailBController.text.trim().isNotEmpty ||
        _driverBCityController.text.trim().isNotEmpty ||
        _driverBCountryController.text.trim().isNotEmpty;
  }

  String _copyText({
    required String it,
    required String de,
    required String fr,
    required String en,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'de':
        return de;
      case 'fr':
        return fr;
      case 'en':
        return en;
      case 'it':
      default:
        return it;
    }
  }

  String _driverKeyFromSequence(int sequence) {
    var value = sequence + 3;
    final buffer = StringBuffer();
    while (value > 0) {
      value--;
      buffer.writeCharCode(65 + (value % 26));
      value ~/= 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  _ConducenteExtraFormData _createConducenteAggiuntivo() {
    final sequence = _nextConducenteSequence++;
    return _ConducenteExtraFormData(
      sequence: sequence,
      driverKey: _driverKeyFromSequence(sequence),
      nomeController: TextEditingController(),
      cognomeController: TextEditingController(),
      indirizzoController: TextEditingController(),
      zipController: TextEditingController(),
      cityController: TextEditingController(),
      countryController: TextEditingController(),
      targaController: TextEditingController(),
      assicurazioneController: TextEditingController(),
      telefonoController: TextEditingController(),
      emailController: TextEditingController(),
    );
  }

  void _addConducenteAggiuntivo() {
    setState(() {
      _conducentiAggiuntivi.add(_createConducenteAggiuntivo());
    });
  }

  void _removeConducenteAggiuntivo(_ConducenteExtraFormData driver) {
    setState(() {
      driver.dispose();
      _conducentiAggiuntivi.remove(driver);
    });
  }

  _ConducenteExtraFormData? _findConducenteAggiuntivo(String key) {
    for (final driver in _conducentiAggiuntivi) {
      if (driver.driverKey == key) return driver;
    }
    return null;
  }

  _DriverFieldBundle? _driverFieldBundleForKey(String key) {
    if (key == 'A') {
      return _DriverFieldBundle(
        nomeController: _nomeAController,
        cognomeController: _cognomeAController,
        indirizzoController: _indirizzoAController,
        zipController: _driverAZipController,
        cityController: _driverACityController,
        targaController: _targaAController,
        assicurazioneController: _assicurazioneAController,
      );
    }
    if (key == 'B') {
      return _DriverFieldBundle(
        nomeController: _nomeBController,
        cognomeController: _cognomeBController,
        indirizzoController: _indirizzoBController,
        zipController: _driverBZipController,
        cityController: _driverBCityController,
        targaController: _targaBController,
        assicurazioneController: _assicurazioneBController,
      );
    }
    final driver = _findConducenteAggiuntivo(key);
    if (driver == null) return null;
    return _DriverFieldBundle(
      nomeController: driver.nomeController,
      cognomeController: driver.cognomeController,
      indirizzoController: driver.indirizzoController,
      zipController: driver.zipController,
      cityController: driver.cityController,
      targaController: driver.targaController,
      assicurazioneController: driver.assicurazioneController,
    );
  }

  _DriverQrImportBundle? _driverQrImportBundleForKey(String key) {
    if (key == 'A') {
      return _DriverQrImportBundle(
        nomeController: _nomeAController,
        cognomeController: _cognomeAController,
        indirizzoController: _indirizzoAController,
        zipController: _driverAZipController,
        cityController: _driverACityController,
        countryController: _driverACountryController,
        targaController: _targaAController,
        assicurazioneController: _assicurazioneAController,
        telefonoController: _telefonoAController,
        emailController: _emailAController,
        setCourtesy: (value) => _driverACourtesy = value,
      );
    }
    if (key == 'B') {
      return _DriverQrImportBundle(
        nomeController: _nomeBController,
        cognomeController: _cognomeBController,
        indirizzoController: _indirizzoBController,
        zipController: _driverBZipController,
        cityController: _driverBCityController,
        countryController: _driverBCountryController,
        targaController: _targaBController,
        assicurazioneController: _assicurazioneBController,
        telefonoController: _telefonoBController,
        emailController: _emailBController,
        setCourtesy: (value) => _driverBCourtesy = value,
      );
    }
    final driver = _findConducenteAggiuntivo(key);
    if (driver == null) return null;
    return _DriverQrImportBundle(
      nomeController: driver.nomeController,
      cognomeController: driver.cognomeController,
      indirizzoController: driver.indirizzoController,
      zipController: driver.zipController,
      cityController: driver.cityController,
      countryController: driver.countryController,
      targaController: driver.targaController,
      assicurazioneController: driver.assicurazioneController,
      telefonoController: driver.telefonoController,
      emailController: driver.emailController,
      setCourtesy: (value) => driver.courtesy = value,
    );
  }

  _DriverCourtesy? _mapDriverQrCourtesy(DriverPersonalQrCourtesy? courtesy) {
    switch (courtesy) {
      case DriverPersonalQrCourtesy.mr:
        return _DriverCourtesy.mr;
      case DriverPersonalQrCourtesy.mrs:
        return _DriverCourtesy.mrs;
      case DriverPersonalQrCourtesy.company:
        return _DriverCourtesy.company;
      case null:
        return null;
    }
  }

  void _writeDriverQrValue(
    TextEditingController controller,
    String value,
  ) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    controller.text = trimmed;
  }

  Future<void> importDriverQrData(
    DriverPersonalQrData data,
    DriverTarget target,
  ) async {
    final driverKey = target.driverKey;
    final bundle = _driverQrImportBundleForKey(driverKey);
    if (bundle == null || !mounted) return;

    debugPrint('[DriverQR] import start target=$driverKey');
    setState(() {
      final courtesy = _mapDriverQrCourtesy(data.courtesy);
      if (courtesy != null) {
        bundle.setCourtesy(courtesy);
      }
      _writeDriverQrValue(bundle.nomeController, data.nome);
      _writeDriverQrValue(bundle.cognomeController, data.cognome);
      _writeDriverQrValue(bundle.indirizzoController, data.indirizzo);
      _writeDriverQrValue(bundle.zipController, data.zip);
      _writeDriverQrValue(bundle.cityController, data.city);
      _writeDriverQrValue(bundle.countryController, data.country);
      _writeDriverQrValue(bundle.telefonoController, data.telefono);
      _writeDriverQrValue(bundle.emailController, data.email);
      _writeDriverQrValue(bundle.targaController, data.targa);
      _writeDriverQrValue(bundle.assicurazioneController, data.assicurazione);
    });
    debugPrint('[DriverQR] import completed target=$driverKey');
  }

  Future<void> _scanDriverQr(String driverKey) async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverQrScannerScreen(
          title: _copyText(
            it: 'Scansiona QR conducente',
            de: 'Fahrer-QR scannen',
            fr: 'Scanner le QR conducteur',
            en: 'Scan driver QR',
          ),
          hint: _copyText(
            it: 'Inquadra il QR personale per importare automaticamente i dati del conducente.',
            de: 'Richten Sie den persönlichen QR-Code aus, um die Fahrerdaten automatisch zu importieren.',
            fr: 'Cadrez le QR personnel pour importer automatiquement les données du conducteur.',
            en: 'Frame the personal QR code to automatically import the driver data.',
          ),
          invalidMessage: _copyText(
            it: 'QR conducente non valido',
            de: 'Ungültiger Fahrer-QR',
            fr: 'QR conducteur non valide',
            en: 'Invalid driver QR',
          ),
          onDetected: (data) => importDriverQrData(
            data,
            DriverTarget.fromKey(driverKey),
          ),
        ),
      ),
    );
    if (!mounted || imported != true) return;
    _mostraSnack(
      _copyText(
        it: 'Dati conducente importati correttamente',
        de: 'Fahrerdaten erfolgreich importiert',
        fr: 'Données conducteur importées avec succès',
        en: 'Driver data imported successfully',
      ),
    );
  }

  void _setLibrettoPreviewForDriver(
    String key, {
    String? path,
    Uint8List? bytes,
    String? cacheKey,
  }) {
    if (key == 'A') {
      _fotoLibrettoAPath = path;
      _fotoLibrettoABytes = bytes;
      _fotoLibrettoACacheKey = cacheKey;
      return;
    }
    if (key == 'B') {
      _fotoLibrettoBPath = path;
      _fotoLibrettoBBytes = bytes;
      _fotoLibrettoBCacheKey = cacheKey;
      return;
    }
    final driver = _findConducenteAggiuntivo(key);
    if (driver == null) return;
    driver.fotoLibrettoPath = path;
    driver.fotoLibrettoBytes = bytes;
    driver.fotoLibrettoCacheKey = cacheKey;
  }

  String _driverTitle(String key) {
    if (key == 'A') return AppLocalizations.of(context)!.driverA;
    if (key == 'B') return AppLocalizations.of(context)!.driverB;
    return _copyText(
      it: 'Conducente $key',
      de: 'Fahrer $key',
      fr: 'Conducteur $key',
      en: 'Driver $key',
    );
  }

  Future<void> _impostaLuogoAutomatico({bool forceUpdateField = false}) async {
    if (_geoLoading) return;

    final enableLocationMessage = tx(context,
        'Attiva la localizzazione sul dispositivo per compilare automaticamente il luogo dell’incidente.');
    final allowLocationMessage = tx(context,
        'Consenti la posizione in Safari per compilare automaticamente il luogo dell’incidente.');
    final unavailableLocationMessage = tx(context,
        'Non siamo riusciti a ottenere la posizione. Verifica che la geolocalizzazione sia attiva e riprova.');
    final gpsLabel = tx(context, 'Posizione GPS');

    debugPrint(
      '[AccidentGPS] start forceUpdateField=$forceUpdateField',
    );
    debugPrint('[AccidentGPS] same workshop GPS method called');
    setState(() {
      _geoLoading = true;
      _geoPosition = null;
      _geoPermission = _GeoPermissionState.unknown;
      _geoErrorMessage = null;
      _addressReadable = null;
      _geoMessage = null;
    });

    try {
      final locationResult =
          await _globalDeviceLocationService.requestCurrentPosition();
      final permissionState = _mapPermission(
          locationResult.permission ?? LocationPermission.denied);
      _geoPermission = permissionState;

      if (!locationResult.serviceEnabled) {
        debugPrint('[AccidentGPS] permission denied service-disabled');
        _setGeoError(
          _GeoPermissionState.unknown,
          enableLocationMessage,
        );
        return;
      }

      debugPrint(
        locationResult.permissionGranted
            ? '[AccidentGPS] permission granted ${locationResult.permission}'
            : '[AccidentGPS] permission denied ${locationResult.permission}',
      );
      if (!locationResult.permissionGranted) {
        _setGeoError(
          permissionState,
          allowLocationMessage,
        );
        return;
      }

      final position = locationResult.position;
      if (position == null) {
        debugPrint('[AccidentGPS] coordinates unavailable');
        _setGeoError(
          permissionState,
          unavailableLocationMessage,
        );
        return;
      }

      debugPrint(
        '[AccidentGPS] coordinates received lat=${position.latitude}, lng=${position.longitude}',
      );

      final gpsFallback = _buildGpsLocationLabel(position, gpsLabel: gpsLabel);
      if (!mounted) return;
      setState(() {
        _geoLoading = false;
        _geoPosition = position;
        _geoErrorMessage = null;
        _addressReadable = null;
        _geoMessage = null;
        final currentValue = _luogoController.text.trim();
        final shouldOverwrite = forceUpdateField ||
            currentValue.isEmpty ||
            _isGpsFallbackValue(currentValue, gpsLabel: gpsLabel);
        if (shouldOverwrite) {
          _luogoController.text = gpsFallback;
          debugPrint('[AccidentGPS] field updated $gpsFallback');
        } else {
          debugPrint('[AccidentGPS] field updated skipped-manual-value');
        }
      });
      unawaited(
        _caricaIndirizzoDaPosizione(
          position,
          forceUpdateField: forceUpdateField,
        ),
      );
    } catch (e, st) {
      debugPrint('[AccidentGPS] coordinates unavailable exception $e\n$st');
      _setGeoError(
        _geoPermission,
        unavailableLocationMessage,
      );
    }
  }

  String _buildGpsLocationLabel(
    Position position, {
    required String gpsLabel,
  }) {
    return '$gpsLabel: ${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)}';
  }

  bool _isGpsFallbackValue(
    String value, {
    required String gpsLabel,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.startsWith('$gpsLabel:') ||
        trimmed.startsWith('Posizione GPS:') ||
        trimmed.startsWith('LAT:');
  }

  bool _shouldHideGeoSuggestionPanel() {
    final currentValue = _luogoController.text.trim();
    if (_geoPosition == null || currentValue.isEmpty) {
      return false;
    }

    final gpsLabel = tx(context, 'Posizione GPS');
    if (_isGpsFallbackValue(currentValue, gpsLabel: gpsLabel)) {
      return true;
    }

    final readableAddress = _addressReadable?.trim() ?? '';
    return readableAddress.isNotEmpty && currentValue == readableAddress;
  }

  void _setGeoError(
    _GeoPermissionState permissionState,
    String message,
  ) {
    debugPrint(
      '[AccidentGPS] error $message (permission=$permissionState)',
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

  Future<void> _caricaIndirizzoDaPosizione(
    Position pos, {
    bool forceUpdateField = true,
  }) async {
    debugPrint(
      '[AccidentGPS] reverse geocode start lat=${pos.latitude}, lng=${pos.longitude}, forceUpdateField=$forceUpdateField',
    );
    final gpsLabel = tx(context, 'Posizione GPS');
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
      debugPrint('[AccidentGPS] reverse geocode status ${res.statusCode}');

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = _formatNominatimAddress(
          body['address'] as Map<String, dynamic>?,
        );
        setState(() {
          if (addr != null && addr.isNotEmpty) {
            _addressReadable = addr;
            debugPrint('[AccidentGPS] reverse geocode success $addr');
            final current = _luogoController.text.trim();
            if (forceUpdateField ||
                current.isEmpty ||
                _isGpsFallbackValue(current, gpsLabel: gpsLabel)) {
              _luogoController.text = addr;
              debugPrint('[AccidentGPS] field updated $addr');
            }
          } else {
            _addressReadable = null;
            debugPrint(
                '[AccidentGPS] reverse geocode fail address-unavailable');
          }
        });
      } else {
        debugPrint(
          '[AccidentGPS] reverse geocode fail status-${res.statusCode}',
        );
        setState(() => _addressReadable = null);
      }
    } catch (e, st) {
      debugPrint('[AccidentGPS] reverse geocode fail $e\n$st');
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
    final hideGeoSuggestionPanel = _shouldHideGeoSuggestionPanel();
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
        if (_suggestionsLoading && !hideGeoSuggestionPanel)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_suggestions.isNotEmpty && !hideGeoSuggestionPanel)
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
    _driverACountryController.dispose();

    _nomeBController.dispose();
    _cognomeBController.dispose();
    _targaBController.dispose();
    _assicurazioneBController.dispose();
    _telefonoBController.dispose();
    _emailBController.dispose();
    _indirizzoBController.dispose();
    _driverBZipController.dispose();
    _driverBCityController.dispose();
    _driverBCountryController.dispose();

    _descrizioneController.dispose();
    _damageVehicleAController.dispose();
    _damageVehicleBController.dispose();

    _notaVocaleAController.dispose();
    _notaVocaleBController.dispose();
    for (final driver in _conducentiAggiuntivi) {
      driver.dispose();
    }
    for (final testimone in _testimoni) {
      testimone.nomeController.dispose();
      testimone.telefonoController.dispose();
    }
    for (final ferito in _feriti) {
      ferito.nomeController.dispose();
      ferito.indirizzoController.dispose();
      ferito.telefonoController.dispose();
    }
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

  List<String> get _damageUploadedUrls => _damagePhotos
      .where((e) =>
          e.status == DamagePhotoStatus.uploaded &&
          e.remoteUrl != null &&
          e.remoteUrl!.isNotEmpty)
      .map((e) => e.remoteUrl!)
      .toList();

  String _extractStoragePath(String url) {
    const marker = 'claim_attachments/';
    final idx = url.indexOf(marker);
    if (idx == -1) return url;
    return url.substring(idx + marker.length);
  }

  Map<String, dynamic>? _buildQueuedAttachmentDescriptor({
    required String kind,
    String? localPath,
    Uint8List? bytes,
    String? filename,
    String? cacheKey,
  }) {
    final cleanPath = localPath?.trim() ?? '';
    final cleanCacheKey = cacheKey?.trim() ?? '';
    final resolvedFilename = (filename?.trim().isNotEmpty == true)
        ? filename!.trim()
        : cleanPath.isNotEmpty
            ? path.basename(cleanPath)
            : '${kind}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (cleanPath.isEmpty && bytes == null && cleanCacheKey.isEmpty) {
      return null;
    }

    return {
      'kind': kind,
      'filename': resolvedFilename,
      'localPath': cleanPath,
      'cacheKey': cleanCacheKey,
      'bytesBase64': bytes != null && !kIsWeb ? base64Encode(bytes) : '',
      'contentType': 'image/jpeg',
    };
  }

  Map<String, dynamic> _buildPendingSyncEntry(
    Incidente incident, {
    required String localId,
    int attempts = 0,
  }) {
    final damageAttachments = _damagePhotos
        .where((item) => (item.remoteUrl?.trim().isEmpty ?? true))
        .map(
          (item) => _buildQueuedAttachmentDescriptor(
            kind: 'damage',
            localPath: item.localPath,
            bytes: item.bytes,
            filename: item.localPath != null && item.localPath!.isNotEmpty
                ? path.basename(item.localPath!)
                : null,
            cacheKey: item.cacheKey,
          ),
        )
        .whereType<Map<String, dynamic>>()
        .toList();

    final librettoA = _buildQueuedAttachmentDescriptor(
      kind: 'libretto',
      localPath: _isStorageBackedAttachment(_fotoLibrettoAPath)
          ? null
          : _fotoLibrettoAPath,
      bytes: _fotoLibrettoABytes,
      filename: _fotoLibrettoAPath != null && _fotoLibrettoAPath!.isNotEmpty
          ? path.basename(_fotoLibrettoAPath!)
          : 'libretto_A.jpg',
      cacheKey: _fotoLibrettoACacheKey,
    );
    final librettoB = _buildQueuedAttachmentDescriptor(
      kind: 'libretto',
      localPath: _isStorageBackedAttachment(_fotoLibrettoBPath)
          ? null
          : _fotoLibrettoBPath,
      bytes: _fotoLibrettoBBytes,
      filename: _fotoLibrettoBPath != null && _fotoLibrettoBPath!.isNotEmpty
          ? path.basename(_fotoLibrettoBPath!)
          : 'libretto_B.jpg',
      cacheKey: _fotoLibrettoBCacheKey,
    );

    return {
      'localId': localId,
      'incident': incident.toJson(),
      'attempts': attempts,
      'status': incident.emailSendStatus,
      'lastAttemptAt': incident.emailSendLastAttemptAt,
      'damageAttachments': damageAttachments,
      'librettoA': librettoA,
      'librettoB': librettoB,
    };
  }

  Future<Incidente> _saveIncidentOffline(
    Incidente incident, {
    required String localId,
  }) async {
    debugPrint('OFFLINE SAVE START: localId=$localId');
    final offlineIncident = await _persistIncidentEmailSendState(
      incident,
      status: 'pending_sync',
      message: _cidOfflinePendingMessage(),
      previousId: localId == incident.id ? null : localId,
    );
    await _upsertPendingSyncEntry(
      _buildPendingSyncEntry(offlineIncident, localId: localId),
    );
    debugPrint(
        'OFFLINE SAVE DONE: localId=$localId incidentId=${offlineIncident.id}');
    return offlineIncident;
  }

  Future<Incidente> _sendCidAutomatically(
    String claimId,
    Incidente incidenteSalvato,
  ) async {
    if (_cidEmailAlreadySent(incidenteSalvato)) {
      debugPrint('[CIDEmail] skipped: already sent');
      return incidenteSalvato;
    }

    if (!_hasCompleteCidSignatures(incidenteSalvato)) {
      debugPrint('[CIDEmail] skipped: signatures missing');
      return _persistIncidentEmailSendState(
        incidenteSalvato,
        status: 'awaiting_signatures',
        message: _cidAwaitingSignaturesMessage(synced: false),
      );
    }

    debugPrint('[CIDEmail] sending after both signatures');
    var currentIncident = await _persistIncidentEmailSendState(
      incidenteSalvato,
      status: 'pending',
      message: 'Invio email in corso...',
    );
    final availableContacts = {
      'emailA': currentIncident.emailA.trim(),
      'emailB': currentIncident.emailB.trim(),
      'officinaEmail': configOfficina.concessionariaEmail.trim(),
      'assicurazioneA': currentIncident.assicurazioneA.trim(),
      'assicurazioneB': currentIncident.assicurazioneB.trim(),
    };
    final recipients = _collectSendRecipients(
      emailA: currentIncident.emailA,
      emailB: currentIncident.emailB,
    );
    debugPrint('SEND CONTACTS AVAILABLE: ${jsonEncode(availableContacts)}');
    debugPrint('SEND RECIPIENTS FINAL: $recipients');
    if (recipients.isEmpty) {
      debugPrint('SEND SKIPPED NO EMAIL: claimId=$claimId');
      currentIncident = await _persistIncidentEmailSendState(
        currentIncident,
        status: 'skipped',
        message:
            'Pratica salvata. Nessuna email disponibile per l’invio automatico.',
      );
      return currentIncident;
    }

    try {
      await _invokeSendCidEmailEdgeFunction(
        claimId: claimId,
        incident: currentIncident,
        recipients: recipients,
      );
      debugPrint('[CIDEmail] send success');
      currentIncident = await _persistIncidentEmailSendState(
        currentIncident,
        status: 'sent',
        message: 'Pratica salvata e inviata correttamente.',
      );
      return currentIncident;
    } catch (e, st) {
      debugPrint('[CIDEmail] error full $e');
      debugPrint('$st');
      currentIncident = await _persistIncidentEmailSendState(
        currentIncident,
        status: 'failed',
        message:
            'Pratica salvata. Invio email non riuscito: riprova più tardi.',
      );
      return currentIncident;
    }
  }

  Future<void> _deleteDamagePhotoFromStorage(DamagePhotoItem item) async {
    final path = item.storagePath?.trim();
    if (path == null || path.isEmpty) {
      debugPrint('DAMAGE PHOTO DELETE STORAGE SKIPPED: no storagePath');
      return;
    }
    try {
      debugPrint('DAMAGE PHOTO DELETE STORAGE START: $path');
      await _supabaseService.client.storage
          .from('claim_attachments')
          .remove([path]);
      debugPrint('DAMAGE PHOTO DELETE STORAGE OK: $path');
    } catch (e, st) {
      debugPrint('DAMAGE PHOTO DELETE STORAGE ERROR: $e');
      debugPrint('$st');
    }
  }

  Future<void> _uploadDamagePhoto(
    DamagePhotoItem item, {
    required String filename,
    required Uint8List bytes,
  }) async {
    if (!mounted) return;
    final claimId = _ensureDraftId();
    final pathHint = 'claims/$claimId/damage/<ts>_$filename';
    setState(() {
      item.status = DamagePhotoStatus.uploading;
      item.error = null;
    });
    debugPrint('DAMAGE PHOTO UPLOAD START pathHint=$pathHint');
    try {
      final uploadedUrl = await _supabaseService.uploadClaimImageBytes(
        claimId: claimId,
        bytes: bytes,
        filename: filename,
        contentType: 'image/jpeg',
        kind: 'damage',
      );
      final storagePath = _extractStoragePath(uploadedUrl);
      if (item.isRemoved) {
        debugPrint(
            'DAMAGE PHOTO REMOVED DURING UPLOAD: cleanup remote file ($storagePath)');
        await _deleteDamagePhotoFromStorage(
          item..storagePath = storagePath,
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        item.status = DamagePhotoStatus.uploaded;
        item.remoteUrl = uploadedUrl;
        item.storagePath = storagePath;
      });
      debugPrint('DAMAGE PHOTO UPLOAD OK: $uploadedUrl');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        item.status = DamagePhotoStatus.failed;
        item.error = e.toString();
      });
      debugPrint('DAMAGE PHOTO UPLOAD ERROR: $e');
    }
  }

  Future<void> _retryDamagePhotoUpload(DamagePhotoItem item) async {
    if (item.status != DamagePhotoStatus.failed || item.bytes == null) return;
    await _uploadDamagePhoto(
      item,
      filename: item.localPath != null
          ? path.basename(item.localPath!)
          : 'damage_${DateTime.now().millisecondsSinceEpoch}.jpg',
      bytes: item.bytes!,
    );
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

    final bundle = _driverFieldBundleForKey(quale);
    if (bundle == null) return false;
    final nomeCtrl = bundle.nomeController;
    final cognomeCtrl = bundle.cognomeController;
    final indirizzoCtrl = bundle.indirizzoController;
    final zipCtrl = bundle.zipController;
    final cityCtrl = bundle.cityController;
    final targaCtrl = bundle.targaController;
    final assicurazioneCtrl = bundle.assicurazioneController;

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
        validator: _isPlausibleName, label: '$quale nome');
    writeIfBetter(cognomeCtrl, cognome,
        validator: _isPlausibleName, label: '$quale cognome');
    writeIfBetter(indirizzoCtrl, indirizzo,
        validator: _isPlausibleAddress, label: '$quale indirizzo');
    writeIfBetter(zipCtrl, cap,
        validator: _isPlausibleZip, label: '$quale cap');
    writeIfBetter(cityCtrl, city,
        validator: _isPlausibleCity, label: '$quale city');
    writeIfBetter(
      assicurazioneCtrl,
      assicurazione,
      validator: _isPlausibleInsurance,
      isBetter: (val) => val.length > assicurazioneCtrl.text.trim().length,
      label: '$quale assicurazione',
    );
    writeIfBetter(
      targaCtrl,
      targa,
      validator: (val) => val != null && extractSwissPlate(val) != null,
      isBetter: (val) =>
          RegExp(r'\d').allMatches(val).length >
          RegExp(r'\d').allMatches(targaCtrl.text).length,
      label: '$quale targa',
    );

    return changed;
  }

  Future<void> _pickAndUploadImage(
      {required String kind, String? quale}) async {
    final claimId = _ensureDraftId();
    var uploadClaimId = claimId;
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

      if (kind == 'damage') {
        String? cacheKey;
        if (kIsWeb) {
          cacheKey =
              '${claimId}_damage_${DateTime.now().millisecondsSinceEpoch}';
          await LocalImageCache.saveImageLocally(cacheKey, bytes);
        }
        final item = DamagePhotoItem(
          status: DamagePhotoStatus.local,
          bytes: bytes,
          localPath: kIsWeb ? null : picked.path,
          cacheKey: cacheKey,
        );
        setState(() {
          _damagePhotos.add(item);
        });
        debugPrint('[Damage] local photo added count=${_damagePhotos.length}');
        _uploadDamagePhoto(item, filename: name, bytes: bytes);
        _mostraSnack('Foto caricata (upload in corso)...');
        return;
      }

      if (kind == 'libretto' && quale != null) {
        String? cacheKey;
        if (kIsWeb) {
          cacheKey =
              '${claimId}_libretto${quale.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}';
          await LocalImageCache.saveImageLocally(cacheKey, bytes);
        }
        setState(() {
          _setLibrettoPreviewForDriver(
            quale,
            path: null,
            bytes: bytes,
            cacheKey: cacheKey,
          );
        });
      }

      // OCR disattivato: il libretto viene solo allegato e mostrato in preview.

      if (kind == 'libretto') {
        if (!QrPayload.looksLikeUuid(uploadClaimId)) {
          final workshopCode = claimId.length > 6
              ? claimId.substring(claimId.length - 6)
              : claimId.padLeft(6, '0');
          final realClaimId = (await _supabaseService.rpcCreateClaimDraft(
            workshopCode: workshopCode,
            payload: const <String, dynamic>{},
          ))
              .trim();
          if (!QrPayload.looksLikeUuid(realClaimId)) {
            throw Exception(
              'create_claim_draft ha restituito un id non UUID: $realClaimId',
            );
          }
          _draftClaimId = realClaimId;
          uploadClaimId = realClaimId;
        }
        debugPrint('UPLOAD LIBRETTO USING REAL CLAIM ID: $uploadClaimId');
      }

      final uploadedUrl = await _supabaseService.uploadClaimImageBytes(
        claimId: uploadClaimId,
        bytes: bytes,
        filename: name,
        contentType: 'image/jpeg',
        kind: kind,
      );
      debugPrint('Upload $kind completato -> $uploadedUrl');

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
    if (index < 0 || index >= _damagePhotos.length) return;
    debugPrint('DAMAGE PHOTO REMOVAL REQUEST: index=$index');
    final removed = _damagePhotos[index];
    removed.isRemoved = true;
    setState(() {
      _damagePhotos.removeAt(index);
    });
    debugPrint('[Damage] removed index=$index url=${removed.remoteUrl ?? '-'} '
        'remaining=${_damagePhotos.length}');
    final shouldDeleteRemote = removed.status == DamagePhotoStatus.uploaded &&
        removed.storagePath != null &&
        removed.storagePath!.trim().isNotEmpty;
    if (shouldDeleteRemote) {
      _deleteDamagePhotoFromStorage(removed);
    }
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

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _incidentCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInnerCard({
    required Widget child,
    Color? backgroundColor,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _incidentCardBorder),
      ),
      child: child,
    );
  }

  Widget _buildResponsivePair(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 680;
        if (!horizontal) {
          return Column(
            children: [
              left,
              const SizedBox(height: 12),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildDriverPreview(String? path, Uint8List? bytes) {
    if ((path == null || path.isEmpty) && bytes == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 132,
          width: double.infinity,
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.cover)
              : Image.file(File(path!), fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildAddOutlinedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
    );
  }

  String _driverAddressFieldLabel() {
    return _copyText(
      it: 'Indirizzo',
      de: 'Adresse',
      fr: 'Adresse',
      en: 'Address',
    );
  }

  String _driverFirstNameFieldLabel() {
    return _copyText(
      it: 'Nome',
      de: 'Vorname',
      fr: 'Prénom',
      en: 'First Name',
    );
  }

  String _driverLastNameFieldLabel() {
    return _copyText(
      it: 'Cognome',
      de: 'Nachname',
      fr: 'Nom',
      en: 'Last Name',
    );
  }

  String _driverPostalCodeFieldLabel() {
    return _copyText(
      it: 'CAP',
      de: 'PLZ',
      fr: 'Code postal',
      en: 'Postal Code',
    );
  }

  String _driverCityFieldLabel() {
    return _copyText(
      it: 'Città',
      de: 'Ort',
      fr: 'Ville',
      en: 'City',
    );
  }

  String _driverCountryFieldLabel() {
    return _copyText(
      it: 'Paese',
      de: 'Land',
      fr: 'Pays',
      en: 'Country',
    );
  }

  String _driverCourtesyLabel() {
    return _copyText(
      it: 'Cortesia / persona giuridica',
      de: 'Anrede / juristische Person',
      fr: 'Civilité / personne morale',
      en: 'Courtesy / legal entity',
    );
  }

  String _driverCourtesyOptionLabel(_DriverCourtesy courtesy) {
    switch (courtesy) {
      case _DriverCourtesy.mr:
        return _copyText(
          it: 'Signor',
          de: 'Herr',
          fr: 'Monsieur',
          en: 'Mr.',
        );
      case _DriverCourtesy.mrs:
        return _copyText(
          it: 'Signora',
          de: 'Frau',
          fr: 'Madame',
          en: 'Mrs.',
        );
      case _DriverCourtesy.company:
        return _copyText(
          it: 'Ditta',
          de: 'Firma',
          fr: 'Société',
          en: 'Company',
        );
    }
  }

  String _vehiclePlateLabel(String driverKey) {
    return _copyText(
      it: 'Targa veicolo $driverKey',
      de: 'Kennzeichen Fahrzeug $driverKey',
      fr: 'Plaque véhicule $driverKey',
      en: 'Vehicle $driverKey plate',
    );
  }

  String _vehicleInsuranceLabel(String driverKey) {
    return _copyText(
      it: 'Assicurazione veicolo $driverKey',
      de: 'Versicherung Fahrzeug $driverKey',
      fr: 'Assurance véhicule $driverKey',
      en: 'Vehicle $driverKey insurance',
    );
  }

  String _driverPhoneLabel(String driverKey) {
    return _copyText(
      it: 'Telefono conducente $driverKey',
      de: 'Telefon Fahrer $driverKey',
      fr: 'Téléphone conducteur $driverKey',
      en: 'Driver $driverKey phone',
    );
  }

  String _driverEmailLabel(String driverKey) {
    return _copyText(
      it: 'Email conducente $driverKey',
      de: 'E-Mail Fahrer $driverKey',
      fr: 'E-mail conducteur $driverKey',
      en: 'Driver $driverKey email',
    );
  }

  String _vehicleInsuranceHint(String driverKey) {
    if (driverKey == 'A') {
      return tx(context, 'Assicurazione veicolo A (es. Allianz)');
    }
    if (driverKey == 'B') {
      return tx(context, 'Assicurazione veicolo B (es. AXA)');
    }
    return _copyText(
      it: 'Es. Allianz',
      de: 'Z. B. Allianz',
      fr: 'Ex. Allianz',
      en: 'E.g. Allianz',
    );
  }

  Widget _buildDriverFormCard({
    required String driverKey,
    required _DriverCourtesy? courtesy,
    required TextEditingController nomeController,
    required TextEditingController cognomeController,
    required TextEditingController indirizzoController,
    required TextEditingController zipController,
    required TextEditingController cityController,
    required TextEditingController countryController,
    required TextEditingController targaController,
    required TextEditingController assicurazioneController,
    required TextEditingController telefonoController,
    required TextEditingController emailController,
    required String? fotoLibrettoPath,
    required Uint8List? fotoLibrettoBytes,
    required String? Function(String?) nomeValidator,
    required String? Function(String?) targaValidator,
    required ValueChanged<_DriverCourtesy?> onCourtesyChanged,
    required VoidCallback onScanQr,
    VoidCallback? onDelete,
  }) {
    return _buildInnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _driverTitle(driverKey),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: _copyText(
                    it: 'Elimina conducente',
                    de: 'Fahrer entfernen',
                    fr: 'Supprimer le conducteur',
                    en: 'Remove driver',
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAddOutlinedButton(
                  onPressed: () => _scattaFotoLibretto(driverKey),
                  icon: kIsWeb
                      ? Icons.photo_camera_outlined
                      : Icons.camera_alt_outlined,
                  label: tx(context, 'Foto libretto'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAddOutlinedButton(
                  onPressed: onScanQr,
                  icon: Icons.qr_code_scanner_outlined,
                  label: _copyText(
                    it: 'Scansiona QR dati',
                    de: 'QR-Daten scannen',
                    fr: 'Scanner QR données',
                    en: 'Scan data QR',
                  ),
                ),
              ),
            ],
          ),
          _buildDriverPreview(fotoLibrettoPath, fotoLibrettoBytes),
          const SizedBox(height: 14),
          DropdownButtonFormField<_DriverCourtesy>(
            initialValue: courtesy,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _driverCourtesyLabel(),
            ),
            items: _DriverCourtesy.values
                .map(
                  (value) => DropdownMenuItem<_DriverCourtesy>(
                    value: value,
                    child: Text(_driverCourtesyOptionLabel(value)),
                  ),
                )
                .toList(),
            onChanged: onCourtesyChanged,
          ),
          const SizedBox(height: 12),
          _buildResponsivePair(
            TextFormField(
              controller: nomeController,
              decoration: InputDecoration(
                labelText: _driverFirstNameFieldLabel(),
              ),
              validator: nomeValidator,
            ),
            TextFormField(
              controller: cognomeController,
              decoration: InputDecoration(
                labelText: _driverLastNameFieldLabel(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: indirizzoController,
            decoration: InputDecoration(
              labelText: _driverAddressFieldLabel(),
            ),
          ),
          const SizedBox(height: 12),
          _buildResponsivePair(
            TextFormField(
              controller: zipController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _driverPostalCodeFieldLabel(),
              ),
            ),
            TextFormField(
              controller: cityController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _driverCityFieldLabel(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: countryController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _driverCountryFieldLabel(),
            ),
          ),
          const SizedBox(height: 12),
          _buildResponsivePair(
            TextFormField(
              controller: targaController,
              decoration: InputDecoration(
                labelText: _vehiclePlateLabel(driverKey),
              ),
              validator: targaValidator,
            ),
            TextFormField(
              controller: assicurazioneController,
              decoration: InputDecoration(
                labelText: _vehicleInsuranceLabel(driverKey),
                hintText: _vehicleInsuranceHint(driverKey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildResponsivePair(
            TextFormField(
              controller: telefonoController,
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
              decoration: InputDecoration(
                labelText: _driverPhoneLabel(driverKey),
                hintText: tx(context, 'Es. +41...'),
              ),
            ),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              decoration: InputDecoration(
                labelText: _driverEmailLabel(driverKey),
                hintText: tx(context, 'nome@email.ch'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuogoSection(String dataOraString) {
    return _buildSectionCard(
      icon: Icons.location_on_outlined,
      title: tx(context, "Luogo dell'incidente"),
      subtitle: _copyText(
        it: 'Data, posizione e controlli iniziali della pratica.',
        de: 'Datum, Ort und erste Angaben des Falls.',
        fr: 'Date, lieu et premiers éléments du dossier.',
        en: 'Date, location and initial case information.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tx(context, 'Data e ora'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            dataOraString,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _luogoController,
            decoration: InputDecoration(
              hintText: tx(context, 'Es. Autostrada A2, uscita Lugano Nord'),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return txStatic("Inserisci il luogo dell'incidente");
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          _buildGeoActions(),
          const SizedBox(height: 16),
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
        ],
      ),
    );
  }

  Widget _buildConducentiSection() {
    final widgets = <Widget>[
      _buildDriverFormCard(
        driverKey: 'A',
        courtesy: _driverACourtesy,
        nomeController: _nomeAController,
        cognomeController: _cognomeAController,
        indirizzoController: _indirizzoAController,
        zipController: _driverAZipController,
        cityController: _driverACityController,
        countryController: _driverACountryController,
        targaController: _targaAController,
        assicurazioneController: _assicurazioneAController,
        telefonoController: _telefonoAController,
        emailController: _emailAController,
        fotoLibrettoPath: _fotoLibrettoAPath,
        fotoLibrettoBytes: _fotoLibrettoABytes,
        nomeValidator: (value) {
          if (value == null || value.trim().isEmpty) {
            return txStatic('Inserisci il nome del conducente A');
          }
          return null;
        },
        targaValidator: (value) {
          if (value == null || value.trim().isEmpty) {
            return txStatic('Inserisci la targa del veicolo A');
          }
          return null;
        },
        onCourtesyChanged: (value) {
          setState(() => _driverACourtesy = value);
        },
        onScanQr: () => _scanDriverQr('A'),
      ),
      const SizedBox(height: 16),
      _buildDriverFormCard(
        driverKey: 'B',
        courtesy: _driverBCourtesy,
        nomeController: _nomeBController,
        cognomeController: _cognomeBController,
        indirizzoController: _indirizzoBController,
        zipController: _driverBZipController,
        cityController: _driverBCityController,
        countryController: _driverBCountryController,
        targaController: _targaBController,
        assicurazioneController: _assicurazioneBController,
        telefonoController: _telefonoBController,
        emailController: _emailBController,
        fotoLibrettoPath: _fotoLibrettoBPath,
        fotoLibrettoBytes: _fotoLibrettoBBytes,
        nomeValidator: (value) {
          if (!_isAnyCampoBCompilato()) return null;
          if (value == null || value.trim().isEmpty) {
            return txStatic('Inserisci il nome del conducente B');
          }
          return null;
        },
        targaValidator: (value) {
          if (!_isAnyCampoBCompilato()) return null;
          if (value == null || value.trim().isEmpty) {
            return txStatic('Inserisci la targa del veicolo B');
          }
          return null;
        },
        onCourtesyChanged: (value) {
          setState(() => _driverBCourtesy = value);
        },
        onScanQr: () => _scanDriverQr('B'),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: _buildAddOutlinedButton(
          onPressed: _addConducenteAggiuntivo,
          icon: Icons.add_circle_outline,
          label: _copyText(
            it: 'Aggiungi conducente',
            de: 'Fahrer hinzufügen',
            fr: 'Ajouter un conducteur',
            en: 'Add driver',
          ),
        ),
      ),
    ];

    for (final driver in _conducentiAggiuntivi) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(
        _buildDriverFormCard(
          driverKey: driver.driverKey,
          courtesy: driver.courtesy,
          nomeController: driver.nomeController,
          cognomeController: driver.cognomeController,
          indirizzoController: driver.indirizzoController,
          zipController: driver.zipController,
          cityController: driver.cityController,
          countryController: driver.countryController,
          targaController: driver.targaController,
          assicurazioneController: driver.assicurazioneController,
          telefonoController: driver.telefonoController,
          emailController: driver.emailController,
          fotoLibrettoPath: driver.fotoLibrettoPath,
          fotoLibrettoBytes: driver.fotoLibrettoBytes,
          nomeValidator: (value) {
            if (!driver.hasAnyValue) return null;
            if (value == null || value.trim().isEmpty) {
              return _copyText(
                it: 'Inserisci il nome del conducente ${driver.driverKey}',
                de: 'Name von Fahrer ${driver.driverKey} eingeben',
                fr: 'Saisissez le prénom du conducteur ${driver.driverKey}',
                en: 'Enter driver ${driver.driverKey} first name',
              );
            }
            return null;
          },
          targaValidator: (value) {
            if (!driver.hasAnyValue) return null;
            if (value == null || value.trim().isEmpty) {
              return _copyText(
                it: 'Inserisci la targa del veicolo ${driver.driverKey}',
                de: 'Kennzeichen von Fahrzeug ${driver.driverKey} eingeben',
                fr: 'Saisissez la plaque du véhicule ${driver.driverKey}',
                en: 'Enter vehicle ${driver.driverKey} plate',
              );
            }
            return null;
          },
          onCourtesyChanged: (value) {
            setState(() => driver.courtesy = value);
          },
          onScanQr: () => _scanDriverQr(driver.driverKey),
          onDelete: () => _removeConducenteAggiuntivo(driver),
        ),
      );
    }

    return _buildSectionCard(
      icon: Icons.people_alt_outlined,
      title: _copyText(
        it: 'Conducenti',
        de: 'Fahrer',
        fr: 'Conducteurs',
        en: 'Drivers',
      ),
      subtitle: _copyText(
        it: 'Dati dei conducenti coinvolti, pronti per essere scalati oltre A e B.',
        de: 'Daten der beteiligten Fahrer, skalierbar über A und B hinaus.',
        fr: 'Données des conducteurs impliqués, évolutives au-delà de A et B.',
        en: 'Driver data, ready to scale beyond A and B.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget _buildTestimoniSection() {
    return _buildSectionCard(
      icon: Icons.groups_outlined,
      title: tx(context, 'Testimoni (se presenti)'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _testimoni.length; i++) ...[
            _buildInnerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_copyText(it: 'Testimone', de: 'Zeuge', fr: 'Témoin', en: 'Witness')} ${i + 1}',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 12),
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
                      const SizedBox(width: 12),
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
                    ],
                  ),
                ],
              ),
            ),
            if (i != _testimoni.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildAddOutlinedButton(
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
              icon: Icons.add,
              label: tx(context, 'Aggiungi testimone'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeritiSection() {
    return _buildSectionCard(
      icon: Icons.healing_outlined,
      title: tx(context, 'Feriti (se presenti)'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_feriti.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _incidentMutedBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _incidentCardBorder),
              ),
              child: Text(
                _copyText(
                  it: 'Nessun ferito segnalato',
                  de: 'Keine Verletzten gemeldet',
                  fr: 'Aucun blessé signalé',
                  en: 'No injuries reported',
                ),
                style: const TextStyle(
                  color: _incidentMutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (_feriti.isNotEmpty)
            ...List.generate(_feriti.length, (i) {
              return Padding(
                padding:
                    EdgeInsets.only(bottom: i == _feriti.length - 1 ? 0 : 12),
                child: _buildInnerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_copyText(it: 'Ferito', de: 'Verletzte Person', fr: 'Blessé', en: 'Injured person')} ${i + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _feriti[i].nomeController,
                        decoration: InputDecoration(
                          labelText: '${tx(context, 'Nome ferito')} ${i + 1}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _feriti[i].indirizzoController,
                        decoration: InputDecoration(
                          labelText:
                              '${tx(context, 'Indirizzo ferito')} ${i + 1}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _feriti[i].telefonoController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText:
                              '${tx(context, 'Telefono ferito')} ${i + 1}',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildAddOutlinedButton(
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
              icon: Icons.add,
              label: tx(context, 'Aggiungi ferito'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDamageBox({
    required String title,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return _buildInnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: title,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDanniSection() {
    return _buildSectionCard(
      icon: Icons.car_repair_outlined,
      title: AppLocalizations.of(context)!.damageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tx(context, 'Descrizione incidente'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descrizioneController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: tx(
                context,
                "Scrivi brevemente come è successo l'incidente...",
              ),
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
          const SizedBox(height: 16),
          _buildResponsivePair(
            _buildDamageBox(
              title: AppLocalizations.of(context)!.damageVehicleA,
              controller: _damageVehicleAController,
              icon: Icons.directions_car_outlined,
            ),
            _buildDamageBox(
              title: AppLocalizations.of(context)!.damageVehicleB,
              controller: _damageVehicleBController,
              icon: Icons.local_shipping_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceNotesSection() {
    return _buildSectionCard(
      icon: Icons.graphic_eq_outlined,
      title: tx(context, 'Note vocali'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAudioNotaControls('A'),
          const SizedBox(height: 16),
          _buildAudioNotaControls('B'),
        ],
      ),
    );
  }

  Widget _buildFotoDannoSection() {
    return _buildSectionCard(
      icon: Icons.photo_camera_back_outlined,
      title: tx(context, 'Foto del danno'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _scattaFotoDanno(),
            child: CustomPaint(
              painter: _DashedRRectPainter(
                color: _incidentDropBorder,
                radius: 16,
              ),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 34,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tx(context, 'Aggiungi foto danno'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _copyText(
                        it: 'Tocca per acquisire immagini del danno e allegarle subito alla pratica.',
                        de: 'Tippen Sie, um Schadenfotos aufzunehmen und direkt anzuhängen.',
                        fr: 'Touchez pour ajouter immédiatement des photos des dommages.',
                        en: 'Tap to capture damage photos and attach them immediately.',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_damagePhotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _damagePhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final item = _damagePhotos[index];
                  final pathStr = item.remoteUrl ?? item.localPath ?? '';
                  final isUrl = item.remoteUrl != null &&
                      item.remoteUrl!.startsWith('http');
                  final previewBytes = item.bytes;
                  final status = item.status;
                  debugPrint(
                      '[DamagePreview] render ${previewBytes != null ? 'bytes' : isUrl ? 'url' : 'file'} $pathStr status=$status');
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
                              borderRadius: BorderRadius.circular(12),
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
                        if (status == DamagePhotoStatus.uploading)
                          const Positioned(
                            left: 6,
                            top: 6,
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (status == DamagePhotoStatus.uploaded)
                          const Positioned(
                            left: 6,
                            top: 6,
                            child: Icon(Icons.check_circle,
                                size: 18, color: Colors.green),
                          ),
                        if (status == DamagePhotoStatus.failed)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: Row(
                              children: [
                                const Icon(Icons.error,
                                    size: 18, color: Colors.red),
                                TextButton(
                                  onPressed: () =>
                                      _retryDamagePhotoUpload(item),
                                  child: const Text(
                                    'Riprova',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSavingIncident ? null : _salvaIncidente,
            icon: _isSavingIncident
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.task_alt),
            label: Text(tx(context, 'Salva incidente')),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _copyText(
            it: 'Puoi salvare in qualsiasi momento.\nLe informazioni verranno salvate in modo sicuro.',
            de: 'Sie können jederzeit speichern.\nDie Informationen werden sicher gespeichert.',
            fr: 'Vous pouvez enregistrer à tout moment.\nLes informations seront sauvegardées en toute sécurité.',
            en: 'You can save at any time.\nThe information will be stored securely.',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
                height: 1.45,
              ),
        ),
      ],
    );
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
            _setLibrettoPreviewForDriver(
              quale,
              path: filename,
              bytes: bytes,
              cacheKey: null,
            );
          });
          _mostraSnack('Foto libretto caricata.');
        }
        return;
      }

      if (result is! OcrLibrettoResult) return;

      setState(() {
        _setLibrettoPreviewForDriver(
          quale,
          path: result.path,
          bytes: null,
          cacheKey: null,
        );
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

      final bytes = await File(foto.path).readAsBytes();
      final item = DamagePhotoItem(
        status: DamagePhotoStatus.local,
        bytes: bytes,
        localPath: foto.path,
      );
      setState(() {
        _damagePhotos.add(item);
      });
      debugPrint('[Damage] local photo added count=${_damagePhotos.length}');
      _uploadDamagePhoto(
        item,
        filename: path.basename(foto.path),
        bytes: bytes,
      );
      _mostraSnack('Foto caricata (upload in corso)...');

      _mostraSnack(
        'Foto del danno aggiunta. Provo a leggere la targa con l\'AI...',
      );
      await _leggiTargaDaFotoDanno(foto.path);
    } catch (_) {
      _mostraSnack('Errore nello scatto della foto del danno.');
    }
  }

  Future<void> _salvaIncidente() async {
    if (_isSavingIncident) return;
    debugPrint('[Save] button tapped');
    setState(() {
      _isSavingIncident = true;
    });
    String? draftId;
    Incidente? nuovo;
    try {
      debugPrint('SAVE STEP 1: validate');
      if (_isRecordingAudio) {
        _mostraSnack(
          'Termina la registrazione della nota vocale prima di salvare.',
        );
        return;
      }

      final formOk = _formKey.currentState!.validate();
      debugPrint('[Save] form valid=$formOk');
      if (!formOk) return;

      final uploading = _damagePhotos
          .where((e) => e.status == DamagePhotoStatus.uploading)
          .length;
      final failed = _damagePhotos
          .where((e) => e.status == DamagePhotoStatus.failed)
          .length;

      debugPrint('[Save] SUBMIT INCIDENTE START');
      debugPrint('[Save] DAMAGE PHOTOS TOTAL: ${_damagePhotos.length}');
      debugPrint('[Save] DAMAGE PHOTOS UPLOADING: $uploading');
      debugPrint('[Save] DAMAGE PHOTOS FAILED: $failed');
      debugPrint(
          '[Save] DAMAGE PHOTOS UPLOADED: ${_damagePhotos.where((e) => e.status == DamagePhotoStatus.uploaded).length}');

      if (uploading > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendere completamento upload foto')),
        );
        return;
      }
      final isOnlineAtSaveStart = await _hasInternetConnection();
      if (failed > 0 && isOnlineAtSaveStart) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Alcune foto non sono state caricate. Riprova o rimuovile.')),
        );
        return;
      }

      debugPrint('SAVE STEP 2: build payload');
      _draftClaimId ??= DateTime.now().millisecondsSinceEpoch.toString();
      draftId = _draftClaimId!;

      final codiceOfficina = draftId.length > 6
          ? draftId.substring(draftId.length - 6)
          : draftId.padLeft(6, '0');

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
      final List<ConducenteAggiuntivo> conducentiAggiuntivi =
          _conducentiAggiuntivi
              .where((driver) => driver.hasAnyValue)
              .map(
                (driver) => ConducenteAggiuntivo(
                  driverKey: driver.driverKey,
                  nome: driver.nomeController.text.trim(),
                  cognome: driver.cognomeController.text.trim(),
                  indirizzo: driver.indirizzoController.text.trim(),
                  zip: driver.zipController.text.trim(),
                  city: driver.cityController.text.trim(),
                  targa: driver.targaController.text.trim(),
                  assicurazione: driver.assicurazioneController.text.trim(),
                  telefono: driver.telefonoController.text.trim(),
                  email: driver.emailController.text.trim(),
                  fotoLibrettoPath: driver.persistedFotoLibrettoReference,
                  fotoLibrettoCacheKey:
                      driver.fotoLibrettoCacheKey?.trim() ?? '',
                ),
              )
              .toList();

      final baseIncidente = Incidente(
        id: draftId,
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
        conducentiAggiuntivi: conducentiAggiuntivi,
        notaVocaleA: _notaVocaleAController.text.trim(),
        notaVocaleB: _notaVocaleBController.text.trim(),
        notaAudioAPath: _notaAudioAPath ?? '',
        notaAudioBPath: _notaAudioBPath ?? '',
        fotoLibrettoA: _fotoLibrettoAPath ?? '',
        fotoLibrettoB: _fotoLibrettoBPath ?? '',
        fotoDanni: _damageUploadedUrls,
        firmaAPath: '',
        firmaBPath: '',
        timestampFirmaA: '',
        timestampFirmaB: '',
        colpevole: '',
        codiceOfficina: codiceOfficina,
        hashIntegrita: '',
      );

      debugPrint('SAVE STEP 3: save incident db');
      nuovo = await aggiornaHashIncidente(baseIncidente);
      if (!isOnlineAtSaveStart) {
        final offlineIncident = await _saveIncidentOffline(
          nuovo,
          localId: draftId,
        );
        _draftClaimId = offlineIncident.id;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineIncident.emailSendMessage)),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DettaglioIncidentePage(incidente: offlineIncident),
          ),
        );
        return;
      }

      final claimId = await _ensurePersistedClaimId(nuovo);
      final incidenteSalvato = claimId == nuovo.id
          ? nuovo
          : Incidente.fromJson({
              ...nuovo.toJson(),
              'id': claimId,
            });

      await _supabaseService.client.from('claims').update({
        'payload_json': incidenteSalvato.toJson(),
        'workshop_code': incidenteSalvato.codiceOfficina,
        'hashed_token': incidenteSalvato.hashIntegrita,
      }).eq('id', claimId);

      if (draftId != claimId) {
        await _supabaseService.client
            .from('claim_attachments')
            .update({'claim_id': claimId}).eq('claim_id', draftId);
      }

      _draftClaimId = claimId;
      debugPrint(
          '[Save] payload fotoDanni count=${incidenteSalvato.fotoDanni.length}');

      incidentiSalvati.insert(0, incidenteSalvato);
      await salvaIncidenti();
      debugPrint('[Save] incident saved locally');
      await caricaIncidenti();
      debugPrint('[Save] list refreshed after save');
      if (kIsWeb) {
        await LocalImageCache.clearIncidentImages(draftId);
      }
      var incidentWithEmailStatus =
          await _sendCidAutomatically(claimId, incidenteSalvato);
      if (incidentWithEmailStatus.emailSendStatus == 'failed' &&
          !await _hasInternetConnection()) {
        incidentWithEmailStatus = await _saveIncidentOffline(
          incidentWithEmailStatus,
          localId: draftId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(incidentWithEmailStatus.emailSendMessage)),
          );
          setState(() {});
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(incidentWithEmailStatus.emailSendMessage)),
        );
        setState(() {});
      }

      debugPrint('SAVE STEP 4: sync incident (non-blocking)');
      try {
        final sync = IncidentsSyncService();
        await sync.uploadIncident(
          payload: incidentWithEmailStatus.toJson(),
          hashSha256: incidentWithEmailStatus.hashIntegrita,
          timestampUtc: DateTime.now().toUtc(),
          locale: Localizations.localeOf(context).languageCode,
          deviceId: null,
        );
        debugPrint('[Save] sync upload success');
      } catch (e, st) {
        debugPrint('[Save] sync upload skipped/failed: $e');
        debugPrint('$st');
      }

      if (!mounted) return;
      debugPrint('SAVE STEP 5: refresh detail + navigate (QR skipped)');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DettaglioIncidentePage(incidente: incidentWithEmailStatus),
        ),
      );
    } catch (e, st) {
      debugPrint('SAVE ERROR TYPE: ${e.runtimeType}');
      debugPrint('SAVE ERROR: $e');
      debugPrint('$st');
      if (nuovo != null && !(await _hasInternetConnection())) {
        final offlineIncident = await _saveIncidentOffline(
          nuovo,
          localId: draftId ?? nuovo.id,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(offlineIncident.emailSendMessage)),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DettaglioIncidentePage(incidente: offlineIncident),
          ),
        );
        return;
      }
      _mostraSnack('Errore durante il salvataggio: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingIncident = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataOraString = formatDataOraLocale(context, _dataOra);

    return Scaffold(
      backgroundColor: _incidentBackground,
      appBar: AppBar(
        title: Text(tx(context, 'Nuova pratica incidente')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLuogoSection(dataOraString),
                const SizedBox(height: _incidentSectionSpacing),
                _buildConducentiSection(),
                const SizedBox(height: _incidentSectionSpacing),
                _buildTestimoniSection(),
                const SizedBox(height: _incidentSectionSpacing),
                _buildFeritiSection(),
                const SizedBox(height: _incidentSectionSpacing),
                _buildDanniSection(),
                if (!kIsWeb) ...[
                  const SizedBox(height: _incidentSectionSpacing),
                  _buildVoiceNotesSection(),
                ],
                const SizedBox(height: _incidentSectionSpacing),
                _buildFotoDannoSection(),
                const SizedBox(height: 24),
                _buildSaveSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRRectPainter({
    required this.color,
    this.radius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 8;
        canvas.drawPath(
          metric.extractPath(
            distance,
            next < metric.length ? next : metric.length,
          ),
          paint,
        );
        distance = next + 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
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
  bool _isSavingSignature = false;

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
    if (_isSavingSignature) return;
    if (_controller.isEmpty) {
      _mostraSnack(tx(context, 'Fai prima la firma sullo schermo.'));
      return;
    }

    setState(() => _isSavingSignature = true);

    try {
      final bytes = await _controller.toPngBytes();
      if (bytes == null || bytes.isEmpty) {
        _mostraSnack(tx(context, 'Firma vuota'));
        return;
      }

      final tsUtc = DateTime.now().toUtc().toIso8601String();
      final base64Signature = base64Encode(bytes);

      Navigator.of(context).pop(
        FirmaResult(base64Data: base64Signature, timestampUtcIso: tsUtc),
      );
    } catch (_) {
      _mostraSnack(tx(context, 'Errore nel salvataggio della firma.'));
    } finally {
      if (mounted) setState(() => _isSavingSignature = false);
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

  String _qrText({
    required String it,
    required String de,
    required String fr,
    required String en,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'de':
        return de;
      case 'fr':
        return fr;
      case 'en':
        return en;
      case 'it':
      default:
        return it;
    }
  }

  String _qrPageTitle() => _qrText(
        it: 'QR per importazione pratica',
        de: 'QR zum Importieren der Schadenakte',
        fr: 'QR pour importer le dossier',
        en: 'QR to import the claim',
      );

  String _qrImportDescription() => _qrText(
        it: 'Mostra questo QR alla carrozzeria per importare automaticamente tutti i dati dell’incidente.',
        de: 'Zeigen Sie diesen QR-Code der Werkstatt, um die Schadenakte automatisch zu importieren.',
        fr: 'Montrez ce QR au garage pour importer automatiquement toutes les données de l’accident.',
        en: 'Show this QR to the workshop to automatically import all accident data.',
      );

  String _generateQrLabel() => _qrText(
        it: 'Genera QR importazione',
        de: 'Import-QR erstellen',
        fr: 'Générer le QR d’import',
        en: 'Generate import QR',
      );

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
      debugPrint('QR STEP FULLSCREEN: load workshop QR');
      final qrData = await buildWorkshopQrData(incidente);
      if (!mounted) return;
      setState(() {
        _qrData = qrData;
        _loadingQr = false;
      });
    } catch (e) {
      debugPrint('QR ERROR TYPE: ${e.runtimeType}');
      debugPrint('QR ERROR: $e');
      if (!mounted) return;
      setState(() {
        _qrError = _qrText(
          it: 'Impossibile generare il QR della pratica',
          de: 'QR der Schadenakte konnte nicht erstellt werden',
          fr: 'Impossible de générer le QR du dossier',
          en: 'Unable to generate the claim QR',
        );
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
        return _qrText(
          it: 'Secondo le parti il conducente ritenuto colpevole è A.',
          de: 'Laut Parteien gilt Fahrer A als verantwortlich.',
          fr: 'Selon les parties, le conducteur jugé responsable est A.',
          en: 'According to the parties, driver A is considered at fault.',
        );
      case 'B':
        return _qrText(
          it: 'Secondo le parti il conducente ritenuto colpevole è B.',
          de: 'Laut Parteien gilt Fahrer B als verantwortlich.',
          fr: 'Selon les parties, le conducteur jugé responsable est B.',
          en: 'According to the parties, driver B is considered at fault.',
        );
      default:
        return _qrText(
          it: 'Responsabilità non dichiarata nelle selezioni.',
          de: 'Haftung in den Auswahlfeldern nicht angegeben.',
          fr: 'Responsabilité non déclarée dans les sélections.',
          en: 'Liability not declared in the selections.',
        );
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
              _qrText(
                it: 'QR pronto. Scegli l’app con cui condividerlo con la carrozzeria.',
                de: 'QR bereit. Wählen Sie die App, um ihn mit der Werkstatt zu teilen.',
                fr: 'QR prêt. Choisissez l’application pour le partager avec le garage.',
                en: 'QR ready. Choose the app to share it with the workshop.',
              ),
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
        subject: _qrPageTitle(),
        text: _qrImportDescription(),
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
        subject: _qrPageTitle(),
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
        title: Text(_qrPageTitle()),
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
                              label: Text(_generateQrLabel()),
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
                  Text(
                    _qrImportDescription(),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_qrText(it: 'Targa A', de: 'Kennzeichen A', fr: 'Plaque A', en: 'Plate A')}: ${incidente.targaA.isEmpty ? '-' : incidente.targaA}  ·  '
                    '${_qrText(it: 'Targa B', de: 'Kennzeichen B', fr: 'Plaque B', en: 'Plate B')}: ${incidente.targaB.isEmpty ? '-' : incidente.targaB}',
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
                    '${_qrText(it: 'Codice officina', de: 'Werkstattcode', fr: 'Code atelier', en: 'Workshop code')}: ${incidente.codiceOfficina}',
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
  bool _isSavingSignature = false;
  bool _isSharingIncident = false;
  bool _isSendingAuto = false;

  Future<String> _qrEmptyFuture() => Future.value('');

  @override
  void initState() {
    super.initState();
    incidente = widget.incidente;
    incidentiRevision.addListener(_onIncidentiRevision);
    _qrDataFuture = _qrEmptyFuture();
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

  @override
  void dispose() {
    incidentiRevision.removeListener(_onIncidentiRevision);
    _detailAudioSub?.cancel();
    unawaited(_detailAudioPlayer.stop());
    _detailAudioPlayer.dispose();
    super.dispose();
  }

  void _onIncidentiRevision() {
    if (!mounted) return;
    final updated = incidentiSalvati.cast<Incidente?>().firstWhere(
          (item) =>
              item?.id == incidente.id ||
              (item?.hashIntegrita.isNotEmpty == true &&
                  item?.hashIntegrita == incidente.hashIntegrita),
          orElse: () => null,
        );
    if (updated == null) return;
    setState(() {
      incidente = updated;
    });
  }

  String _labelResponsabilita() {
    final l10n = AppLocalizations.of(context)!;
    switch (incidente.colpevole) {
      case 'A':
        return l10n.faultLiabilityHintA;
      case 'B':
        return l10n.faultLiabilityHintB;
      default:
        return _detailText(
          it: 'Responsabilità non selezionata.',
          de: 'Haftung nicht ausgewählt.',
          fr: 'Responsabilité non sélectionnée.',
          en: 'Liability not selected.',
        );
    }
  }

  String _detailText({
    required String it,
    required String de,
    required String fr,
    required String en,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'de':
        return de;
      case 'fr':
        return fr;
      case 'en':
        return en;
      case 'it':
      default:
        return it;
    }
  }

  String _pageTitle() => _detailText(
        it: 'Dettagli incidente',
        de: 'Unfallbericht',
        fr: 'Rapport d’accident',
        en: 'Accident report',
      );

  String _emailStatusLabel() {
    switch (incidente.emailSendStatus) {
      case 'sent':
        return _detailText(
          it: 'Sincronizzata e inviata',
          de: 'Synchronisiert und gesendet',
          fr: 'Synchronisé et envoyé',
          en: 'Synced and sent',
        );
      case 'pending_sync':
        return _detailText(
          it: 'Salvata offline',
          de: 'Offline gespeichert',
          fr: 'Enregistré hors ligne',
          en: 'Saved offline',
        );
      case 'awaiting_signatures':
        return _detailText(
          it: 'In attesa delle firme',
          de: 'Wartet auf Unterschriften',
          fr: 'En attente des signatures',
          en: 'Waiting for signatures',
        );
      case 'syncing':
        return _detailText(
          it: 'Sincronizzazione in corso',
          de: 'Synchronisierung läuft',
          fr: 'Synchronisation en cours',
          en: 'Sync in progress',
        );
      case 'skipped':
        return _detailText(
          it: 'Nessuna e-mail disponibile',
          de: 'Keine E-Mail verfügbar',
          fr: 'Aucun e-mail disponible',
          en: 'No email available',
        );
      case 'failed':
        return _detailText(
          it: 'Invio da riprovare',
          de: 'Versand erneut versuchen',
          fr: 'Envoi à réessayer',
          en: 'Retry sending',
        );
      case 'pending':
        return _detailText(
          it: 'Sincronizzazione in corso',
          de: 'Synchronisierung läuft',
          fr: 'Synchronisation en cours',
          en: 'Sync in progress',
        );
      default:
        return '';
    }
  }

  String _emailStatusDescription() {
    switch (incidente.emailSendStatus) {
      case 'sent':
        return _detailText(
          it: 'La pratica risulta inviata correttamente ai destinatari disponibili.',
          de: 'Die Schadenakte wurde erfolgreich an die verfügbaren Empfänger gesendet.',
          fr: 'Le dossier a été envoyé correctement aux destinataires disponibles.',
          en: 'The claim has been sent successfully to the available recipients.',
        );
      case 'pending_sync':
        return _detailText(
          it: 'La pratica è stata salvata offline e verrà sincronizzata automaticamente appena torna la connessione.',
          de: 'Die Schadenakte wurde offline gespeichert und wird automatisch synchronisiert, sobald die Verbindung wieder verfügbar ist.',
          fr: 'Le dossier a été enregistré hors ligne et sera synchronisé automatiquement dès que la connexion sera disponible.',
          en: 'The claim was saved offline and will sync automatically when the connection is available again.',
        );
      case 'awaiting_signatures':
        return _detailText(
          it: 'La pratica è salvata. L’invio automatico partirà solo dopo la firma di entrambi i conducenti.',
          de: 'Die Schadenakte ist gespeichert. Der automatische Versand startet erst, wenn beide Fahrer unterschrieben haben.',
          fr: 'Le dossier est enregistré. L’envoi automatique démarrera seulement après les signatures des deux conducteurs.',
          en: 'The claim is saved. Automatic sending will start only after both drivers have signed.',
        );
      case 'syncing':
      case 'pending':
        return _detailText(
          it: 'Stiamo completando la sincronizzazione della pratica.',
          de: 'Die Synchronisierung der Schadenakte wird gerade abgeschlossen.',
          fr: 'La synchronisation du dossier est en cours.',
          en: 'The claim synchronization is being completed.',
        );
      case 'skipped':
        return _detailText(
          it: 'La pratica è salvata, ma non ci sono indirizzi e-mail disponibili per l’invio automatico.',
          de: 'Die Schadenakte ist gespeichert, es sind jedoch keine E-Mail-Adressen für den automatischen Versand verfügbar.',
          fr: 'Le dossier est enregistré, mais aucune adresse e-mail n’est disponible pour l’envoi automatique.',
          en: 'The claim is saved, but no email addresses are available for automatic sending.',
        );
      case 'failed':
        return _detailText(
          it: 'La pratica è stata salvata correttamente. Puoi riprovare l’invio più tardi.',
          de: 'Die Schadenakte wurde korrekt gespeichert. Sie können den Versand später erneut versuchen.',
          fr: 'Le dossier a bien été enregistré. Vous pourrez réessayer l’envoi plus tard.',
          en: 'The claim was saved correctly. You can retry sending it later.',
        );
      default:
        return incidente.emailSendMessage;
    }
  }

  IconData _emailStatusIcon() {
    switch (incidente.emailSendStatus) {
      case 'sent':
        return Icons.check_circle_outline;
      case 'pending_sync':
        return Icons.wifi_off_outlined;
      case 'awaiting_signatures':
        return Icons.draw_outlined;
      case 'syncing':
      case 'pending':
        return Icons.sync;
      case 'skipped':
        return Icons.mail_outline;
      case 'failed':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  Color _emailStatusBackground() {
    switch (incidente.emailSendStatus) {
      case 'sent':
        return const Color(0xFFDCFCE7);
      case 'pending_sync':
        return const Color(0xFFFFF7ED);
      case 'awaiting_signatures':
        return const Color(0xFFE0F2FE);
      case 'syncing':
      case 'pending':
        return const Color(0xFFDBEAFE);
      case 'skipped':
        return const Color(0xFFFEF3C7);
      case 'failed':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _emailStatusForeground() {
    switch (incidente.emailSendStatus) {
      case 'sent':
        return const Color(0xFF166534);
      case 'pending_sync':
        return const Color(0xFF9A3412);
      case 'awaiting_signatures':
        return const Color(0xFF0F4C81);
      case 'syncing':
      case 'pending':
        return const Color(0xFF1D4ED8);
      case 'skipped':
      case 'failed':
        return const Color(0xFF92400E);
      default:
        return const Color(0xFF4B5563);
    }
  }

  String _emailLastAttemptLabel() {
    if (incidente.emailSendLastAttemptAt.isEmpty) return '';
    final parsed = DateTime.tryParse(incidente.emailSendLastAttemptAt);
    if (parsed == null) return incidente.emailSendLastAttemptAt;
    return formatDataOraLocale(context, parsed.toLocal());
  }

  Widget _buildDetailBadge({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF111827),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftInfoBox({
    required IconData icon,
    required String title,
    required String message,
    Color backgroundColor = const Color(0xFFFEF3C7),
    Color foregroundColor = const Color(0xFF92400E),
    Color borderColor = const Color(0x00000000),
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: foregroundColor.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retryPendingSync() async {
    debugPrint('EMAIL RETRY START: claimId=${incidente.id}');
    final existingEntry = await _findPendingSyncEntry(incidente.id);
    if (existingEntry != null) {
      await _upsertPendingSyncEntry({
        ...existingEntry,
        'attempts': 0,
        'status': 'pending_sync',
        'incident': Incidente.fromJson({
          ...incidente.toJson(),
          'emailSendStatus': 'pending_sync',
          'emailSendMessage': _cidOfflinePendingMessage(),
        }).toJson(),
      });
      await _persistIncidentEmailSendState(
        incidente,
        status: 'pending_sync',
        message: _cidOfflinePendingMessage(),
      );
      await PendingSyncManager.trigger();
    } else {
      await _sendCidAutomatically(incidente.id);
    }
    debugPrint(
      'EMAIL RETRY RESULT: '
      'status=${incidente.emailSendStatus} '
      'message=${incidente.emailSendMessage}',
    );
  }

  Uint8List? _decodeBase64Image(String data) {
    if (data.isEmpty) return null;
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  bool get _firmeComplete =>
      _decodeBase64Image(incidente.firmaAPath) != null &&
      _decodeBase64Image(incidente.firmaBPath) != null;

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
      _qrDataFuture = _qrEmptyFuture();
    });
  }

  void _startWorkshopQr() {
    setState(() {
      _qrDataFuture = buildWorkshopQrData(incidente);
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

  Future<Uint8List> _buildIncidentPdfBytes() async {
    final l10n = AppLocalizations.of(context)!;
    final pdf = pw.Document();
    final dataOra = formatDataOraGeneric(incidente.dataOra);
    final displayClaimId = formatClaimDisplayId(incidente);
    final displayWorkshopCode = formatWorkshopDisplayCode(incidente);
    final langCode = linguaSelezionata.value.languageCode;

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

    final firmaABytes = _decodeBase64Image(incidente.firmaAPath);
    final firmaBBytes = _decodeBase64Image(incidente.firmaBPath);

    if (firmaABytes != null) {
      firmaAImage = pw.MemoryImage(firmaABytes);
    }
    if (firmaBBytes != null) {
      firmaBImage = pw.MemoryImage(firmaBBytes);
    }

    final hasFirmaA = firmaAImage != null;
    final hasFirmaB = firmaBImage != null;

    late final String claimNumberLabel;
    late final String overviewTitle;
    late final String driversTitle;
    late final String descriptionTitle;
    late final String damageTitle;
    late final String liabilityTitle;
    late final String protectionTitle;
    late final String workshopCodeLabel;
    late final String hashLabel;
    late final String timestampLabel;
    late final String signaturesTitle;
    late final String driverAAddressLabel;
    late final String driverBAddressLabel;
    late final String insuranceALabel;
    late final String insuranceBLabel;
    late final String phoneALabel;
    late final String phoneBLabel;
    late final String emailALabel;
    late final String emailBLabel;
    late final String summarySubtitle;
    late final String noDescriptionText;
    late final String noDamageText;
    late final String noAdditionalInfoText;
    late final String witnessesTitle;
    late final String injuriesTitle;
    late final String signedLabel;
    late final String missingSignatureLabel;
    switch (langCode) {
      case 'it':
        claimNumberLabel = 'Numero pratica:';
        overviewTitle = 'Riepilogo pratica';
        driversTitle = 'Conducenti';
        descriptionTitle = 'Descrizione';
        damageTitle = 'Danni';
        liabilityTitle = 'Responsabilità';
        protectionTitle = 'Protezione documento';
        workshopCodeLabel = 'Codice officina';
        hashLabel = 'Hash SHA-256';
        timestampLabel = 'Timestamp UTC';
        signaturesTitle = 'Firme digitali';
        driverAAddressLabel = 'Indirizzo A';
        driverBAddressLabel = 'Indirizzo B';
        insuranceALabel = 'Assicurazione A';
        insuranceBLabel = 'Assicurazione B';
        phoneALabel = 'Telefono A';
        phoneBLabel = 'Telefono B';
        emailALabel = 'Email A';
        emailBLabel = 'Email B';
        summarySubtitle =
            'Documento riepilogativo generato per uso assicurativo, officina e concessionaria.';
        noDescriptionText = 'Nessuna descrizione fornita.';
        noDamageText = 'Nessun danno indicato.';
        noAdditionalInfoText = 'Nessuna informazione aggiuntiva.';
        witnessesTitle = 'Testimoni';
        injuriesTitle = 'Feriti';
        signedLabel = 'Firmato digitalmente';
        missingSignatureLabel = 'Firma non presente';
        break;
      case 'fr':
        claimNumberLabel = 'Numero de dossier :';
        overviewTitle = 'Résumé du dossier';
        driversTitle = 'Conducteurs';
        descriptionTitle = 'Description';
        damageTitle = 'Dommages';
        liabilityTitle = 'Responsabilité';
        protectionTitle = 'Protection du document';
        workshopCodeLabel = 'Code atelier';
        hashLabel = 'Hash SHA-256';
        timestampLabel = 'Horodatage UTC';
        signaturesTitle = 'Signatures numériques';
        driverAAddressLabel = 'Adresse A';
        driverBAddressLabel = 'Adresse B';
        insuranceALabel = 'Assurance A';
        insuranceBLabel = 'Assurance B';
        phoneALabel = 'Téléphone A';
        phoneBLabel = 'Téléphone B';
        emailALabel = 'E-mail A';
        emailBLabel = 'E-mail B';
        summarySubtitle =
            'Document de synthèse généré pour usage assurance, atelier et concession.';
        noDescriptionText = 'Aucune description fournie.';
        noDamageText = 'Aucun dommage indiqué.';
        noAdditionalInfoText = 'Aucune information supplémentaire.';
        witnessesTitle = 'Témoins';
        injuriesTitle = 'Blessés';
        signedLabel = 'Signé numériquement';
        missingSignatureLabel = 'Signature absente';
        break;
      case 'en':
        claimNumberLabel = 'Claim number:';
        overviewTitle = 'Claim overview';
        driversTitle = 'Drivers';
        descriptionTitle = 'Description';
        damageTitle = 'Damage';
        liabilityTitle = 'Liability';
        protectionTitle = 'Document protection';
        workshopCodeLabel = 'Workshop code';
        hashLabel = 'SHA-256 hash';
        timestampLabel = 'UTC timestamp';
        signaturesTitle = 'Digital signatures';
        driverAAddressLabel = 'Address A';
        driverBAddressLabel = 'Address B';
        insuranceALabel = 'Insurance A';
        insuranceBLabel = 'Insurance B';
        phoneALabel = 'Phone A';
        phoneBLabel = 'Phone B';
        emailALabel = 'Email A';
        emailBLabel = 'Email B';
        summarySubtitle =
            'Summary document generated for insurance, workshop and dealership use.';
        noDescriptionText = 'No description provided.';
        noDamageText = 'No damage reported.';
        noAdditionalInfoText = 'No additional information.';
        witnessesTitle = 'Witnesses';
        injuriesTitle = 'Injuries';
        signedLabel = 'Digitally signed';
        missingSignatureLabel = 'Signature not available';
        break;
      case 'de':
      default:
        claimNumberLabel = 'Vorgangsnummer:';
        overviewTitle = 'Aktenübersicht';
        driversTitle = 'Fahrer';
        descriptionTitle = 'Beschreibung';
        damageTitle = 'Beschädigung';
        liabilityTitle = 'Haftung';
        protectionTitle = 'Dokumentschutz';
        workshopCodeLabel = 'Werkstattcode';
        hashLabel = 'SHA-256-Hash';
        timestampLabel = 'UTC-Zeitstempel';
        signaturesTitle = 'Digitale Unterschriften';
        driverAAddressLabel = 'Adresse A';
        driverBAddressLabel = 'Adresse B';
        insuranceALabel = 'Versicherung A';
        insuranceBLabel = 'Versicherung B';
        phoneALabel = 'Telefon A';
        phoneBLabel = 'Telefon B';
        emailALabel = 'E-Mail A';
        emailBLabel = 'E-Mail B';
        summarySubtitle =
            'Zusammenfassendes Dokument für Versicherung, Werkstatt und Autohaus.';
        noDescriptionText = 'Keine Beschreibung angegeben.';
        noDamageText = 'Keine Schäden angegeben.';
        noAdditionalInfoText = 'Keine zusätzlichen Informationen.';
        witnessesTitle = 'Zeugen';
        injuriesTitle = 'Verletzte';
        signedLabel = 'Digital signiert';
        missingSignatureLabel = 'Unterschrift nicht vorhanden';
        break;
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

    final detailLabelStyle = pw.TextStyle(
      fontSize: 8.5,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey700,
    );
    final detailValueStyle = pw.TextStyle(
      fontSize: 10,
      color: PdfColors.grey900,
      height: 1.25,
    );
    final sectionTitleStyle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey900,
    );

    pw.Widget detailLine(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: detailLabelStyle),
            pw.SizedBox(height: 2),
            pw.Text(value, style: detailValueStyle),
          ],
        ),
      );
    }

    pw.Widget sectionBox({
      required String title,
      required List<pw.Widget> children,
      PdfColor background = PdfColors.white,
    }) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: background,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: sectionTitleStyle),
            pw.SizedBox(height: 8),
            ...children,
          ],
        ),
      );
    }

    pw.Widget driverCard({
      required String title,
      required String name,
      required String plate,
      required String insuranceLabel,
      required String insuranceValue,
      required String phoneLabel,
      required String phoneValue,
      required String emailLabel,
      required String emailValue,
      required String addressLabel,
      required String addressValue,
    }) {
      return sectionBox(
        title: title,
        background: PdfColors.grey100,
        children: [
          detailLine(txStatic('Nome'), name),
          detailLine(txStatic('Targa'), plate),
          detailLine(insuranceLabel, insuranceValue),
          detailLine(phoneLabel, phoneValue),
          detailLine(emailLabel, emailValue),
          detailLine(addressLabel, addressValue),
        ],
      );
    }

    String witnessSummary() {
      return incidente.testimoni.map((testimone) {
        final name =
            testimone.nome.trim().isEmpty ? '-' : testimone.nome.trim();
        final phone = testimone.telefono.trim();
        return phone.isEmpty ? name : '$name ($phone)';
      }).join(' · ');
    }

    String injurySummary() {
      return incidente.feriti
          .map((ferito) => [
                ferito.nome.trim(),
                ferito.indirizzo.trim(),
                ferito.telefono.trim(),
              ].where((part) => part.isNotEmpty).join(' · '))
          .where((line) => line.isNotEmpty)
          .join('  |  ');
    }

    final additionalInfoLines = <String>[
      if (incidente.testimoni.isNotEmpty)
        '$witnessesTitle: ${witnessSummary()}',
      if (incidente.feriti.isNotEmpty) '$injuriesTitle: ${injurySummary()}',
    ];

    pw.Widget signatureCard({
      required String title,
      required bool hasSignature,
      required String timestamp,
      required pw.ImageProvider? image,
    }) {
      return sectionBox(
        title: title,
        background: PdfColors.green50,
        children: [
          pw.Text(
            hasSignature ? signedLabel : missingSignatureLabel,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: hasSignature ? PdfColors.green800 : PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            height: 60,
            width: double.infinity,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
            ),
            child: image == null
                ? pw.Text(
                    missingSignatureLabel,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  )
                : pw.Image(image, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 6),
          detailLine(timestampLabel, timestamp),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) {
          return [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue700,
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CID DIGITALE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '$claimNumberLabel $displayClaimId',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    summarySubtitle,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            sectionBox(
              title: overviewTitle,
              background: PdfColors.blue50,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: detailLine(l10n.labelDateTime, dataOra),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: detailLine(
                        l10n.labelPlace,
                        incidente.luogo.isEmpty ? '-' : incidente.luogo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              driversTitle,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: driverCard(
                    title: l10n.pdfDriverA,
                    name: driverAName,
                    plate: incidente.targaA.isEmpty ? '-' : incidente.targaA,
                    insuranceLabel: insuranceALabel,
                    insuranceValue: incidente.assicurazioneA.isEmpty
                        ? '-'
                        : incidente.assicurazioneA,
                    phoneLabel: phoneALabel,
                    phoneValue:
                        incidente.telefonoA.isEmpty ? '-' : incidente.telefonoA,
                    emailLabel: emailALabel,
                    emailValue:
                        incidente.emailA.isEmpty ? '-' : incidente.emailA,
                    addressLabel: driverAAddressLabel,
                    addressValue:
                        indirizzoACompleto.isEmpty ? '-' : indirizzoACompleto,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: driverCard(
                    title: l10n.pdfDriverB,
                    name: driverBName,
                    plate: incidente.targaB.isEmpty ? '-' : incidente.targaB,
                    insuranceLabel: insuranceBLabel,
                    insuranceValue: incidente.assicurazioneB.isEmpty
                        ? '-'
                        : incidente.assicurazioneB,
                    phoneLabel: phoneBLabel,
                    phoneValue:
                        incidente.telefonoB.isEmpty ? '-' : incidente.telefonoB,
                    emailLabel: emailBLabel,
                    emailValue:
                        incidente.emailB.isEmpty ? '-' : incidente.emailB,
                    addressLabel: driverBAddressLabel,
                    addressValue:
                        indirizzoBCompleto.isEmpty ? '-' : indirizzoBCompleto,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            sectionBox(
              title: descriptionTitle,
              children: [
                pw.Text(
                  incidente.descrizione.isEmpty
                      ? noDescriptionText
                      : incidente.descrizione,
                  style: detailValueStyle,
                ),
                if (additionalInfoLines.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    additionalInfoLines.join('\n'),
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                      height: 1.3,
                    ),
                  ),
                ],
                if (additionalInfoLines.isEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: pw.Text(
                      noAdditionalInfoText,
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: sectionBox(
                    title: damageTitle,
                    children: [
                      detailLine(
                        l10n.damageVehicleA,
                        incidente.danniVeicoloA.isEmpty
                            ? noDamageText
                            : incidente.danniVeicoloA,
                      ),
                      detailLine(
                        l10n.damageVehicleB,
                        incidente.danniVeicoloB.isEmpty
                            ? noDamageText
                            : incidente.danniVeicoloB,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: sectionBox(
                    title: liabilityTitle,
                    background: PdfColors.grey100,
                    children: [
                      pw.Text(
                        responsabilitaPdf,
                        style: detailValueStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            sectionBox(
              title: protectionTitle,
              background: PdfColors.blue50,
              children: [
                detailLine(hashLabel, hash),
                detailLine(
                  timestampLabel,
                  'A: ${incidente.timestampFirmaA.isEmpty ? '-' : incidente.timestampFirmaA}   ·   B: ${incidente.timestampFirmaB.isEmpty ? '-' : incidente.timestampFirmaB}',
                ),
                detailLine(workshopCodeLabel, displayWorkshopCode),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              signaturesTitle,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: signatureCard(
                    title: l10n.pdfDriverA,
                    hasSignature: hasFirmaA,
                    timestamp: incidente.timestampFirmaA.isEmpty
                        ? '-'
                        : incidente.timestampFirmaA,
                    image: firmaAImage,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: signatureCard(
                    title: l10n.pdfDriverB,
                    hasSignature: hasFirmaB,
                    timestamp: incidente.timestampFirmaB.isEmpty
                        ? '-'
                        : incidente.timestampFirmaB,
                    image: firmaBImage,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Map<String, String> _buildLocalizedCidEmailContent() {
    String normalizeLang(String code) {
      if (const ['de', 'it', 'fr', 'en'].contains(code)) return code;
      return 'de';
    }

    String valueOrDash(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? '-' : trimmed;
    }

    String fullName(String nome, String cognome) {
      final joined = [nome.trim(), cognome.trim()]
          .where((part) => part.isNotEmpty)
          .join(' ');
      return joined.isEmpty ? '-' : joined;
    }

    String driverSummary(
        String label, String nome, String cognome, String plate) {
      final full = fullName(nome, cognome);
      final plateValue = valueOrDash(plate);
      return plateValue == '-'
          ? '$label: $full'
          : '$label: $full (${_detailText(it: 'Targa', de: 'Kennzeichen', fr: 'Plaque', en: 'Plate')}: $plateValue)';
    }

    final lang = normalizeLang(Localizations.localeOf(context).languageCode);
    final displayClaimId = formatClaimDisplayId(incidente);
    final dataOra = formatDataOraLocale(context, incidente.dataOra);

    late final String subject;
    late final String greeting;
    late final String intro;
    late final String claimNumberLabel;
    late final String dateTimeLabel;
    late final String placeLabel;
    late final String driverALabel;
    late final String driverBLabel;
    late final String pdfNote;
    late final String photosNote;
    late final String closing;

    switch (lang) {
      case 'it':
        subject = 'Pratica incidente digitale $displayClaimId';
        greeting = 'Gentile utente,';
        intro =
            'In allegato trova la pratica incidente digitale n° $displayClaimId.';
        claimNumberLabel = 'Numero pratica';
        dateTimeLabel = 'Data e ora';
        placeLabel = 'Luogo';
        driverALabel = 'Conducente A';
        driverBLabel = 'Conducente B';
        pdfNote =
            'La pratica digitale completa è disponibile nel PDF allegato.';
        photosNote =
            'Le fotografie aggiuntive vengono allegate separatamente quando consentito dai limiti dimensionali.';
        closing = 'Cordiali saluti';
        break;
      case 'fr':
        subject = 'Dossier d’accident numérique $displayClaimId';
        greeting = 'Bonjour,';
        intro =
            'Vous trouverez en pièce jointe le dossier d’accident numérique n° $displayClaimId.';
        claimNumberLabel = 'Numéro de dossier';
        dateTimeLabel = 'Date et heure';
        placeLabel = 'Lieu';
        driverALabel = 'Conducteur A';
        driverBLabel = 'Conducteur B';
        pdfNote =
            'Le dossier numérique complet est disponible dans le PDF joint.';
        photosNote =
            'Des photographies supplémentaires sont jointes séparément lorsque la limite de taille le permet.';
        closing = 'Cordialement';
        break;
      case 'en':
        subject = 'Digital accident claim $displayClaimId';
        greeting = 'Hello,';
        intro =
            'Attached you will find digital accident claim no. $displayClaimId.';
        claimNumberLabel = 'Claim number';
        dateTimeLabel = 'Date and time';
        placeLabel = 'Location';
        driverALabel = 'Driver A';
        driverBLabel = 'Driver B';
        pdfNote =
            'The complete digital claim file is available in the attached PDF.';
        photosNote =
            'Additional photographs are included as separate attachments whenever size limits allow.';
        closing = 'Kind regards';
        break;
      case 'de':
      default:
        subject = 'Digitale Schadenakte $displayClaimId';
        greeting = 'Guten Tag,';
        intro =
            'Im Anhang finden Sie die digitale Schadenakte zur Vorgangsnummer $displayClaimId.';
        claimNumberLabel = 'Vorgangsnummer';
        dateTimeLabel = 'Datum und Uhrzeit';
        placeLabel = 'Ort';
        driverALabel = 'Fahrer A';
        driverBLabel = 'Fahrer B';
        pdfNote =
            'Die vollständige digitale Schadenakte befindet sich im beigefügten PDF.';
        photosNote =
            'Zusätzliche Fotos werden – sofern die Größenbeschränkung dies zulässt – als separate Anhänge übermittelt.';
        closing = 'Freundliche Grüsse';
        break;
    }

    final body = StringBuffer()
      ..writeln('CID Digitale')
      ..writeln('$claimNumberLabel: $displayClaimId')
      ..writeln()
      ..writeln(greeting)
      ..writeln()
      ..writeln(intro)
      ..writeln()
      ..writeln('$dateTimeLabel: $dataOra')
      ..writeln('$placeLabel: ${valueOrDash(incidente.luogo)}')
      ..writeln()
      ..writeln(driverSummary(
        driverALabel,
        incidente.nomeA,
        incidente.cognomeA,
        incidente.targaA,
      ))
      ..writeln(driverSummary(
        driverBLabel,
        incidente.nomeB,
        incidente.cognomeB,
        incidente.targaB,
      ))
      ..writeln()
      ..writeln(pdfNote)
      ..writeln()
      ..writeln(photosNote)
      ..writeln()
      ..writeln(closing);

    return {
      'subject': subject,
      'body': body.toString(),
    };
  }

  Future<void> _shareIncidentPdfAndPhotos() async {
    if (_isSharingIncident) return;
    setState(() => _isSharingIncident = true);
    debugPrint('SHARE STEP 1: start');
    try {
      final emailContent = _buildLocalizedCidEmailContent();
      final displayClaimId = formatClaimDisplayId(incidente);
      final pdfFileName = 'cid-digitale-$displayClaimId.pdf';

      bool _isValidUrl(String? url) {
        if (url == null) return false;
        final u = url.trim();
        return u.isNotEmpty && u.startsWith('http');
      }

      final librettoUrls = [
        incidente.fotoLibrettoA,
        incidente.fotoLibrettoB,
      ].where(_isValidUrl).map((e) => e.trim()).toList();
      final damageLinks =
          incidente.fotoDanni.where(_isValidUrl).map((e) => e.trim()).toList();

      for (final url in librettoUrls) {
        debugPrint('EMAIL URL CHECK: $url');
        debugPrint('EMAIL URL VALID: ${_isValidUrl(url)}');
      }
      for (final url in damageLinks) {
        debugPrint('EMAIL URL CHECK: $url');
        debugPrint('EMAIL URL VALID: ${_isValidUrl(url)}');
      }
      debugPrint('EMAIL BODY DAMAGE COUNT: ${damageLinks.length}');
      for (final url in damageLinks) {
        debugPrint('EMAIL BODY DAMAGE URL: $url');
      }
      final shareText = emailContent['body']!;
      final shareSubject = emailContent['subject']!;

      debugPrint('SHARE STEP 2: build pdf');
      final pdfBytes = await _buildIncidentPdfBytes();
      debugPrint('SHARE STEP 2b: pdf bytes=${pdfBytes.length}');
      debugPrint('ATTACH STEP 1: build pdf');
      debugPrint(
          'ATTACH FILE READY: name=$pdfFileName mime=application/pdf size=${pdfBytes.length}');

      debugPrint('ATTACH STEP 2: collect libretto photos');
      final librettoPaths = <String>[
        incidente.fotoLibrettoA,
        incidente.fotoLibrettoB,
      ].where((e) => e.isNotEmpty).toList();
      final webLibrettoFiles = <WebShareFile>[];
      if (kIsWeb) {
        int idx = 1;
        for (final p in librettoPaths) {
          try {
            if (p.startsWith('http')) {
              debugPrint('DOWNLOAD ATTACH START: $p');
              final resp = await http.get(Uri.parse(p));
              if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                webLibrettoFiles.add(WebShareFile(
                  bytes: resp.bodyBytes,
                  fileName: 'libretto_$idx.jpg',
                  mimeType: 'image/jpeg',
                ));
                debugPrint(
                    'DOWNLOAD ATTACH OK: $p bytes=${resp.bodyBytes.length}');
                debugPrint(
                    'ATTACH FILE READY: name=libretto_$idx.jpg mime=image/jpeg size=${resp.bodyBytes.length}');
                idx++;
              } else {
                debugPrint(
                    'DOWNLOAD ATTACH FAIL: $p status=${resp.statusCode}');
              }
            }
          } catch (e) {
            debugPrint('DOWNLOAD ATTACH FAIL: $p error=$e');
          }
        }
      }
      debugPrint('LIBRETTO COUNT: ${webLibrettoFiles.length}');

      debugPrint('SHARE STEP 3: collect damage photos');
      final damageUrls =
          incidente.fotoDanni.where((e) => e.isNotEmpty).toList();
      final List<Uint8List> damagePhotosBytes = [];
      int skipCount = 0;
      for (final url in damageUrls) {
        try {
          debugPrint('DOWNLOAD ATTACH START: $url');
          final resp = await http.get(Uri.parse(url));
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            damagePhotosBytes.add(resp.bodyBytes);
            debugPrint(
                'DOWNLOAD ATTACH OK: $url bytes=${resp.bodyBytes.length}');
          } else {
            skipCount++;
            debugPrint(
                'DOWNLOAD ATTACH FAIL: $url status=${resp.statusCode} bytes=${resp.bodyBytes.length}');
          }
        } catch (e) {
          skipCount++;
          debugPrint('DOWNLOAD ATTACH FAIL: $url error=$e');
        }
      }
      debugPrint('ATTACHMENTS INCLUDED: ${damagePhotosBytes.length}');
      debugPrint('ATTACHMENTS SKIPPED: $skipCount');
      debugPrint('SHARE STEP 4: attachments ready in memory');
      final webDamageFiles = <WebShareFile>[];
      if (kIsWeb) {
        for (int i = 0; i < damagePhotosBytes.length; i++) {
          final name = 'damage_${i + 1}.jpg';
          webDamageFiles.add(WebShareFile(
              bytes: damagePhotosBytes[i],
              fileName: name,
              mimeType: 'image/jpeg'));
          debugPrint(
              'ATTACH FILE READY: name=$name mime=image/jpeg size=${damagePhotosBytes[i].length}');
        }
      }
      debugPrint('DAMAGE COUNT: ${webDamageFiles.length}');
      debugPrint(
          'ATTACH STEP 4: total candidate attachments = ${1 + webLibrettoFiles.length + webDamageFiles.length}');

      debugPrint('SHARE STEP 5: detect platform');
      if (kIsWeb) {
        debugPrint('WEB SHARE STEP 1: build pdf');
        final pdfWebFile = WebShareFile(
          bytes: pdfBytes,
          fileName: pdfFileName,
          mimeType: 'application/pdf',
        );
        bool shared = false;
        debugPrint('WEB SHARE TAP START');
        debugPrint('WEB SHARE USER AGENT: ${webUserAgent()}');
        debugPrint(
            'WEB SHARE navigator.share available: ${webNavigatorShareAvailable()}');
        debugPrint('WEB SHARE files count: 1');
        debugPrint('WEB SHARE PDF BYTES: ${pdfBytes.length}');
        debugPrint('WEB SHARE FILE NAME: ${pdfWebFile.fileName}');

        final firstDamageOnly = webDamageFiles.isNotEmpty
            ? [webDamageFiles.first]
            : <WebShareFile>[];
        final attemptSets = <List<WebShareFile>>[];
        final attemptMessages = <String>[];
        final attemptDescriptions = <String>[];

        attemptSets.add([pdfWebFile, ...webLibrettoFiles, ...webDamageFiles]);
        attemptMessages.add(tx(context, 'Menu di condivisione aperto.'));
        attemptDescriptions.add('pdf+all photos');

        attemptSets.add([pdfWebFile, ...webLibrettoFiles]);
        attemptMessages.add(
            tx(context, 'Condivisione aperta con gli allegati supportati.'));
        attemptDescriptions.add('pdf+libretto');

        if (firstDamageOnly.isNotEmpty) {
          attemptSets.add([pdfWebFile, ...firstDamageOnly]);
          attemptMessages.add(tx(
              context, 'Condivisione aperta con il PDF e una foto del danno.'));
          attemptDescriptions.add('pdf+first damage');
        }

        attemptSets.add([pdfWebFile]);
        attemptMessages.add(tx(context, 'Condivisione aperta con il PDF.'));
        attemptDescriptions.add('pdf only');

        for (var i = 0; i < attemptSets.length; i++) {
          final files =
              attemptSets[i].where((e) => e.bytes.isNotEmpty).toList();
          if (files.isEmpty) continue;
          final tryLabel = i + 1;
          debugPrint(
              'WEB SHARE TRY $tryLabel (${attemptDescriptions[i]}): set size=${files.length}');
          for (final f in files) {
            debugPrint(
                'ATTACH FILE READY: name=${f.fileName} mime=${f.mimeType} size=${f.bytes.length}');
          }
          try {
            shared = await shareFilesWeb(
              files: files,
              title: shareSubject,
              text: shareText,
            );
            if (shared) {
              debugPrint('WEB SHARE TRY $tryLabel SUCCESS');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(attemptMessages[i])),
                );
              }
              return;
            }
          } catch (e, st) {
            debugPrint('WEB SHARE TRY $tryLabel FAILED: $e');
            debugPrint('$st');
          }
        }

        debugPrint('WEB SHARE STEP 5: fallback download');
        debugPrint('SHARE FLOW: fallback download if share unavailable');
        final pdfUri = Uri.dataFromBytes(pdfBytes, mimeType: 'application/pdf');
        await launchUrl(pdfUri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tx(context,
                  'Condivisione diretta non disponibile su questo browser. PDF scaricato.')),
            ),
          );
        }
        return;
      }

      debugPrint('SHARE STEP 6 (mobile): prepare attachments');
      final tempDir = await getTemporaryDirectory();
      final List<XFile> allegati = [];

      final pdfPath =
          '${tempDir.path}/${pdfFileName.replaceAll('.pdf', '')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(pdfPath).writeAsBytes(pdfBytes);
      allegati
          .add(XFile(pdfPath, mimeType: 'application/pdf', name: pdfFileName));

      // Libretto (locale o scaricato se URL)
      int librettoAdded = 0;
      for (int i = 0; i < librettoPaths.length; i++) {
        final pathLib = librettoPaths[i];
        try {
          if (File(pathLib).existsSync()) {
            allegati.add(XFile(pathLib));
            debugPrint('ATTACH FILE: libretto_${i + 1}.jpg (locale)');
            librettoAdded++;
          } else if (pathLib.startsWith('http')) {
            final resp = await http.get(Uri.parse(pathLib));
            if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
              final lp = '${tempDir.path}/libretto_${i == 0 ? 'A' : 'B'}.jpg';
              await File(lp).writeAsBytes(resp.bodyBytes);
              allegati.add(XFile(lp,
                  mimeType: 'image/jpeg', name: 'libretto_${i + 1}.jpg'));
              debugPrint(
                  'ATTACH FILE: libretto_${i + 1}.jpg size=${resp.bodyBytes.length}');
              librettoAdded++;
            }
          }
        } catch (e, st) {
          debugPrint('ATTACH ERROR TYPE: ${e.runtimeType}');
          debugPrint('ATTACH ERROR: $e');
          debugPrint('$st');
        }
      }

      if (incidente.fotoLibrettoA.isNotEmpty &&
          File(incidente.fotoLibrettoA).existsSync()) {
        allegati.add(XFile(incidente.fotoLibrettoA));
        librettoAdded++;
      }
      if (incidente.fotoLibrettoB.isNotEmpty &&
          File(incidente.fotoLibrettoB).existsSync()) {
        allegati.add(XFile(incidente.fotoLibrettoB));
        librettoAdded++;
      }
      debugPrint('LIBRETTO COUNT (mobile): $librettoAdded');

      int damageAdded = 0;
      for (int i = 0; i < damagePhotosBytes.length; i++) {
        final path = '${tempDir.path}/damage_${i + 1}.jpg';
        await File(path).writeAsBytes(damagePhotosBytes[i]);
        allegati.add(
          XFile(path, mimeType: 'image/jpeg', name: 'damage_${i + 1}.jpg'),
        );
        debugPrint(
            'ATTACH FILE: damage_${i + 1}.jpg size=${damagePhotosBytes[i].length}');
        damageAdded++;
      }
      debugPrint('DAMAGE COUNT (mobile): $damageAdded');

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
        subject: shareSubject,
        text: shareText,
        sharePositionOrigin: const ui.Rect.fromLTWH(0, 0, 1, 1),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx(context, 'Menu di condivisione aperto.')),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('SHARE ERROR TYPE: ${e.runtimeType}');
      debugPrint('SHARE ERROR: $e');
      debugPrint('$st');
      debugPrint('SHARE BUTTON ERROR TYPE: ${e.runtimeType}');
      debugPrint('SHARE BUTTON ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx(context, 'Impossibile aprire la condivisione.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingIncident = false);
    }
  }

  Future<void> _condividiPerAssicurazione(BuildContext context) async {
    debugPrint('SHARE BUTTON TAP');
    debugPrint('SHARE FLOW: native share preferred');
    await _shareIncidentPdfAndPhotos();
  }

  Future<void> _sendCidAutomatically(String claimId) async {
    if (_isSendingAuto) return;
    setState(() => _isSendingAuto = true);
    try {
      String realClaimId = claimId;
      var workingIncident = incidente;
      if (!QrPayload.looksLikeUuid(realClaimId)) {
        realClaimId = await _ensurePersistedClaimId(incidente);
        final updatedIncident = realClaimId == incidente.id
            ? incidente
            : Incidente.fromJson({
                ...incidente.toJson(),
                'id': realClaimId,
              });

        await Supabase.instance.client.from('claims').update({
          'payload_json': updatedIncident.toJson(),
          'workshop_code': updatedIncident.codiceOfficina,
          'hashed_token': updatedIncident.hashIntegrita,
        }).eq('id', realClaimId);

        await Supabase.instance.client
            .from('claim_attachments')
            .update({'claim_id': realClaimId}).eq('claim_id', claimId);

        if (updatedIncident.id != incidente.id) {
          final index =
              incidentiSalvati.indexWhere((e) => e.id == incidente.id);
          if (index != -1) {
            incidentiSalvati[index] = updatedIncident;
            await salvaIncidenti();
          }
          if (mounted) {
            setState(() {
              incidente = updatedIncident;
              _qrDataFuture = _qrEmptyFuture();
            });
          } else {
            incidente = updatedIncident;
          }
        }
        workingIncident = updatedIncident;
      }

      if (_cidEmailAlreadySent(workingIncident)) {
        debugPrint('[CIDEmail] skipped: already sent');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(workingIncident.emailSendMessage)),
          );
        }
        incidente = workingIncident;
        return;
      }

      if (!_hasCompleteCidSignatures(workingIncident)) {
        debugPrint('[CIDEmail] skipped: signatures missing');
        workingIncident = await _persistIncidentEmailSendState(
          workingIncident,
          status: 'awaiting_signatures',
          message: _cidAwaitingSignaturesMessage(synced: false),
          previousId: claimId == realClaimId ? null : claimId,
        );
        if (mounted) {
          setState(() {
            incidente = workingIncident;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(workingIncident.emailSendMessage)),
          );
        } else {
          incidente = workingIncident;
        }
        return;
      }

      debugPrint('[CIDEmail] sending after both signatures');

      workingIncident = await _persistIncidentEmailSendState(
        workingIncident,
        status: 'pending',
        message: 'Invio email in corso...',
        previousId: claimId == realClaimId ? null : claimId,
      );
      if (mounted) {
        setState(() {
          incidente = workingIncident;
        });
      } else {
        incidente = workingIncident;
      }

      final availableContacts = {
        'emailA': workingIncident.emailA.trim(),
        'emailB': workingIncident.emailB.trim(),
        'officinaEmail': configOfficina.concessionariaEmail.trim(),
        'assicurazioneA': workingIncident.assicurazioneA.trim(),
        'assicurazioneB': workingIncident.assicurazioneB.trim(),
      };
      final recipients = _collectSendRecipients(
        emailA: workingIncident.emailA,
        emailB: workingIncident.emailB,
      );
      debugPrint('SEND CONTACTS AVAILABLE: ${jsonEncode(availableContacts)}');
      debugPrint('SEND RECIPIENTS FINAL: $recipients');
      if (recipients.isEmpty) {
        debugPrint('SEND SKIPPED NO EMAIL: claimId=$realClaimId');
        workingIncident = await _persistIncidentEmailSendState(
          workingIncident,
          status: 'skipped',
          message:
              'Pratica salvata. Nessuna email disponibile per l’invio automatico.',
        );
        if (mounted) {
          setState(() {
            incidente = workingIncident;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(workingIncident.emailSendMessage)),
          );
        } else {
          incidente = workingIncident;
        }
        return;
      }

      await _invokeSendCidEmailEdgeFunction(
        claimId: realClaimId,
        incident: workingIncident,
        recipients: recipients,
      );
      debugPrint('[CIDEmail] send success');
      workingIncident = await _persistIncidentEmailSendState(
        workingIncident,
        status: 'sent',
        message: 'Pratica salvata e inviata correttamente.',
      );
      if (mounted) {
        setState(() {
          incidente = workingIncident;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(workingIncident.emailSendMessage),
          ),
        );
      } else {
        incidente = workingIncident;
      }
    } catch (e, st) {
      debugPrint('[CIDEmail] error full $e');
      debugPrint('$st');
      final offline = !await _hasInternetConnection();
      final updatedIncident = await _persistIncidentEmailSendState(
        incidente,
        status: offline ? 'pending_sync' : 'failed',
        message: offline
            ? _cidOfflinePendingMessage()
            : 'Pratica salvata. Invio email non riuscito: riprova più tardi.',
      );
      if (offline) {
        await _upsertPendingSyncEntry({
          'localId': QrPayload.looksLikeUuid(claimId) ? claimId : incidente.id,
          'incident': updatedIncident.toJson(),
          'attempts': 0,
          'status': 'pending_sync',
          'lastAttemptAt': updatedIncident.emailSendLastAttemptAt,
          'damageAttachments': const <Map<String, dynamic>>[],
          'librettoA': null,
          'librettoB': null,
        });
      }
      if (mounted) {
        setState(() {
          incidente = updatedIncident;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedIncident.emailSendMessage),
          ),
        );
      } else {
        incidente = updatedIncident;
      }
    } finally {
      if (mounted) setState(() => _isSendingAuto = false);
    }
  }

  // ====================== EMAIL PRECOMPILATA ======================

  Future<void> _invioEmailPrecompilata() async {
    debugPrint('MAIL STEP 1: collect recipients');
    final emailContent = _buildLocalizedCidEmailContent();
    final availableContacts = {
      'emailA': incidente.emailA.trim(),
      'emailB': incidente.emailB.trim(),
      'officinaEmail': configOfficina.concessionariaEmail.trim(),
      'assicurazioneA': incidente.assicurazioneA.trim(),
      'assicurazioneB': incidente.assicurazioneB.trim(),
    };
    final recipients = _collectSendRecipients(
      emailA: incidente.emailA,
      emailB: incidente.emailB,
      extraEmails: [
        configOfficina.concessionariaEmail,
        incidente.assicurazioneA,
        incidente.assicurazioneB,
      ],
    );
    debugPrint('SEND CONTACTS AVAILABLE: ${jsonEncode(availableContacts)}');
    debugPrint('SEND RECIPIENTS FINAL: $recipients');
    if (recipients.isEmpty) {
      debugPrint('SEND SKIPPED NO EMAIL: claimId=${incidente.id}');
    }

    final subject = Uri.encodeComponent(emailContent['subject']!);

    debugPrint('MAIL STEP 2: build pdf if needed');
    Uint8List pdfBytes;
    try {
      pdfBytes = await _buildIncidentPdfBytes();
    } catch (e, st) {
      debugPrint('MAIL ERROR TYPE: ${e.runtimeType}');
      debugPrint('MAIL ERROR: $e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(tx(context, 'Impossibile aprire l’e-mail precompilata.')),
          ),
        );
      }
      return;
    }

    final damageLinks = incidente.fotoDanni.where((e) => e.isNotEmpty).toList();
    final bodyEncoded = Uri.encodeComponent(emailContent['body']!);
    final toParam = recipients.isEmpty ? '' : recipients.join(',');

    if (kIsWeb) {
      debugPrint('MAIL STEP 3: prepare body (web)');
      // Rendi disponibile il PDF tramite download rapido (data url)
      debugPrint('MAIL STEP 4: trigger PDF download for user');
      final pdfUri = Uri.dataFromBytes(pdfBytes, mimeType: 'application/pdf');
      await launchUrl(pdfUri);

      debugPrint('MAIL STEP 5: open mailto');
      final mailto =
          Uri.parse('mailto:$toParam?subject=$subject&body=$bodyEncoded');
      await launchUrl(mailto);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx(context,
                'Email precompilata aperta. Se necessario allega il PDF appena scaricato.')),
          ),
        );
      }
      return;
    }

    // Mobile / desktop native: proviamo share con allegati reali
    debugPrint('MAIL STEP 3: prepare body (mobile)');
    final tempDir = await getTemporaryDirectory();
    final displayClaimId = formatClaimDisplayId(incidente);
    final pdfFileName = 'cid-digitale-$displayClaimId.pdf';
    final pdfPath =
        '${tempDir.path}/${pdfFileName.replaceAll('.pdf', '')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(pdfPath).writeAsBytes(pdfBytes);
    final allegati = <XFile>[
      XFile(pdfPath, mimeType: 'application/pdf', name: pdfFileName),
    ];

    // Scarica foto danni per allegarle se possibile
    for (int i = 0; i < damageLinks.length; i++) {
      try {
        final resp = await http.get(Uri.parse(damageLinks[i]));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          final pathImg = '${tempDir.path}/damage_mail_${i + 1}.jpg';
          await File(pathImg).writeAsBytes(resp.bodyBytes);
          allegati.add(XFile(pathImg,
              mimeType: 'image/jpeg', name: 'damage_${i + 1}.jpg'));
        }
      } catch (_) {
        // ignora singoli errori foto
      }
    }

    debugPrint('MAIL STEP 4: share with attachments (mobile)');
    try {
      await Share.shareXFiles(
        allegati,
        subject: Uri.decodeComponent(subject),
        text:
            'To: $toParam\n\n${Uri.decodeComponent(bodyEncoded)}\n\n(Allegati inclusi se supportato)',
        sharePositionOrigin: const ui.Rect.fromLTWH(0, 0, 1, 1),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx(context, 'Email precompilata aperta.')),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('MAIL ERROR TYPE: ${e.runtimeType}');
      debugPrint('MAIL ERROR: $e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx(context,
                'Impossibile aprire l’e-mail precompilata. Allegare manualmente i file.')),
          ),
        );
      }
    }

    debugPrint('MAIL STEP 5: done');
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
      conducentiAggiuntivi: incidente.conducentiAggiuntivi,
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
      emailSendStatus: incidente.emailSendStatus,
      emailSendMessage: incidente.emailSendMessage,
      emailSendLastAttemptAt: incidente.emailSendLastAttemptAt,
    );

    final updatedWithHash = await aggiornaHashIncidente(updated);

    final index = incidentiSalvati.indexWhere((e) => e.id == incidente.id);
    if (index != -1) {
      incidentiSalvati[index] = updatedWithHash;
      await salvaIncidenti();
    }

    setState(() {
      incidente = updatedWithHash;
      _qrDataFuture = _qrEmptyFuture();
    });
    unawaited(_syncClaimPayloadSnapshot(updatedWithHash));
    unawaited(_verificaHashIntegrita());
  }

  Future<void> _firmaConducente(bool isA) async {
    if (_locked || _isSavingSignature) return;

    final result = await Navigator.of(context).push<FirmaResult>(
      MaterialPageRoute(
        builder: (_) => FirmaPage(incidente: incidente, isA: isA),
      ),
    );

    if (result == null) return;

    setState(() => _isSavingSignature = true);

    try {
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
        conducentiAggiuntivi: incidente.conducentiAggiuntivi,
        notaVocaleA: incidente.notaVocaleA,
        notaVocaleB: incidente.notaVocaleB,
        notaAudioAPath: incidente.notaAudioAPath,
        notaAudioBPath: incidente.notaAudioBPath,
        fotoLibrettoA: incidente.fotoLibrettoA,
        fotoLibrettoB: incidente.fotoLibrettoB,
        fotoDanni: incidente.fotoDanni,
        firmaAPath: isA ? result.base64Data : incidente.firmaAPath,
        firmaBPath: isA ? incidente.firmaBPath : result.base64Data,
        timestampFirmaA:
            isA ? result.timestampUtcIso : incidente.timestampFirmaA,
        timestampFirmaB:
            isA ? incidente.timestampFirmaB : result.timestampUtcIso,
        colpevole: incidente.colpevole,
        codiceOfficina: incidente.codiceOfficina,
        hashIntegrita: incidente.hashIntegrita,
        emailSendStatus: incidente.emailSendStatus,
        emailSendMessage: incidente.emailSendMessage,
        emailSendLastAttemptAt: incidente.emailSendLastAttemptAt,
      );

      final updatedWithHash = await aggiornaHashIncidente(updated);

      // Salvataggio remoto base64 firma (compatibile Web, senza File).
      try {
        debugPrint('SIGNATURE SAVE START');
        debugPrint('SIGNATURE SIZE: ${result.base64Data.length}');
        debugPrint('INCIDENT ID: ${incidente.id}');

        final client = Supabase.instance.client;
        await client
            .from('incidents')
            .update(isA
                ? {
                    'firmaAPath': result.base64Data,
                    'timestampFirmaA': result.timestampUtcIso,
                  }
                : {
                    'firmaBPath': result.base64Data,
                    'timestampFirmaB': result.timestampUtcIso,
                  })
            .eq('id', incidente.id);
      } catch (e, st) {
        debugPrint('SIGNATURE SAVE ERROR: $e');
        debugPrint('$st');
      }

      final index = incidentiSalvati.indexWhere((e) => e.id == incidente.id);
      if (index != -1) {
        incidentiSalvati[index] = updatedWithHash;
        await salvaIncidenti();
      }

      await _syncClaimPayloadSnapshot(updatedWithHash);

      setState(() {
        incidente = updatedWithHash;
        _qrDataFuture = _qrEmptyFuture();
      });
      unawaited(_verificaHashIntegrita());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tx(context, 'Firma salvata'))),
        );
      }

      if (_hasCompleteCidSignatures(updatedWithHash) &&
          updatedWithHash.emailSendStatus != 'sent') {
        await _sendCidAutomatically(updatedWithHash.id);
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingSignature = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dataOra = formatDataOraLocale(context, incidente.dataOra);
    final emailStatusLabel = _emailStatusLabel();
    final emailStatusDescription = _emailStatusDescription();
    final emailLastAttempt = _emailLastAttemptLabel();
    final bool hasNoteVocali = incidente.notaVocaleA.isNotEmpty ||
        incidente.notaVocaleB.isNotEmpty ||
        incidente.notaAudioAPath.isNotEmpty ||
        incidente.notaAudioBPath.isNotEmpty;
    final bool hasDanni = incidente.danniVeicoloA.isNotEmpty ||
        incidente.danniVeicoloB.isNotEmpty;
    final firmaABytes = _decodeBase64Image(incidente.firmaAPath);
    final firmaBBytes = _decodeBase64Image(incidente.firmaBPath);
    final firmaAExists = firmaABytes != null;
    final firmaBExists = firmaBBytes != null;
    final hasCompleteSignatures =
        incidente.firmaAPath.isNotEmpty && incidente.firmaBPath.isNotEmpty;
    final practiceId = formatClaimDisplayId(incidente);
    final lockedTitle = _detailText(
      it: 'Pratica protetta e conclusa.',
      de: 'Schadenakte geschützt und abgeschlossen.',
      fr: 'Dossier protégé et finalisé.',
      en: 'Claim protected and completed.',
    );
    final lockedMessage = _detailText(
      it: 'Le firme sono state acquisite. La pratica è ora in sola lettura.',
      de: 'Die Unterschriften sind erfasst. Die Akte ist nun schreibgeschützt.',
      fr: 'Les signatures ont été enregistrées. Le dossier est désormais en lecture seule.',
      en: 'The signatures have been recorded. The claim is now read-only.',
    );
    final contactsLines = <String>[
      if (incidente.telefonoA.isNotEmpty || incidente.emailA.isNotEmpty)
        'A ${incidente.telefonoA.isEmpty ? '-' : incidente.telefonoA}'
            '${incidente.emailA.isNotEmpty ? ' · ${incidente.emailA}' : ''}',
      if (incidente.telefonoB.isNotEmpty || incidente.emailB.isNotEmpty)
        'B ${incidente.telefonoB.isEmpty ? '-' : incidente.telefonoB}'
            '${incidente.emailB.isNotEmpty ? ' · ${incidente.emailB}' : ''}',
    ];
    final contactsValue = contactsLines.isEmpty
        ? _detailText(
            it: 'Nessun contatto disponibile',
            de: 'Keine Kontaktdaten verfügbar',
            fr: 'Aucun contact disponible',
            en: 'No contact available',
          )
        : contactsLines.join('\n');
    final integrityTitle = hasCompleteSignatures
        ? _detailText(
            it: 'Integrità verificata con successo.',
            de: 'Integrität erfolgreich verifiziert.',
            fr: 'Intégrité vérifiée avec succès.',
            en: 'Integrity successfully verified.',
          )
        : _detailText(
            it: 'In attesa delle firme digitali.',
            de: 'Warten auf die digitalen Unterschriften.',
            fr: 'En attente des signatures numériques.',
            en: 'Waiting for digital signatures.',
          );
    final integrityMessage = hasCompleteSignatures
        ? _detailText(
            it: 'Questo documento è protetto con hash SHA-256 e timestamp UTC.',
            de: 'Dieses Dokument ist durch SHA-256 und UTC-Zeitstempel geschützt.',
            fr: 'Ce document est protégé par un hachage SHA-256 et un horodatage UTC.',
            en: 'This document is protected by SHA-256 hash and UTC timestamp.',
          )
        : _detailText(
            it: 'La verifica dell’integrità verrà eseguita automaticamente quando entrambi i conducenti avranno firmato.',
            de: 'Die Integritätsprüfung wird automatisch durchgeführt, sobald beide Fahrer unterschrieben haben.',
            fr: 'La vérification de l’intégrité sera effectuée automatiquement dès que les deux conducteurs auront signé.',
            en: 'Integrity verification will be performed automatically after both drivers have signed.',
          );
    final integrityBackgroundColor = hasCompleteSignatures
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFEFF6FF);
    final integrityForegroundColor = hasCompleteSignatures
        ? const Color(0xFF166534)
        : const Color(0xFF1D4ED8);
    final integrityBorderColor = hasCompleteSignatures
        ? const Color(0xFFBBF7D0)
        : const Color(0xFFBFDBFE);
    final integrityIcon =
        hasCompleteSignatures ? Icons.check_circle : Icons.info_outline;

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_detailText(it: 'Pratica n°', de: 'Vorgang Nr.', fr: 'Dossier n°', en: 'Claim no.')} $practiceId',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildDetailBadge(
                                icon: Icons.event_outlined,
                                label:
                                    '${_detailText(it: 'Creata il', de: 'Erstellt am', fr: 'Créé le', en: 'Created on')}: $dataOra',
                                backgroundColor: const Color(0xFFDBEAFE),
                                foregroundColor: const Color(0xFF1D4ED8),
                              ),
                              _buildDetailBadge(
                                icon: Icons.verified_user_outlined,
                                label: _detailText(
                                  it: 'Protetta con hash SHA-256 e timestamp UTC',
                                  de: 'Geschützt mit SHA-256-Hash und UTC-Zeitstempel',
                                  fr: 'Protégé par hash SHA-256 et horodatage UTC',
                                  en: 'Protected with SHA-256 hash and UTC timestamp',
                                ),
                                backgroundColor: const Color(0xFFDCFCE7),
                                foregroundColor: const Color(0xFF166534),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _detailText(
                            it: 'Riepilogo pratica',
                            de: 'Aktenübersicht',
                            fr: 'Résumé du dossier',
                            en: 'Claim overview',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryRow(
                      icon: Icons.schedule_outlined,
                      label: l10n.labelDateTime,
                      value: dataOra,
                    ),
                    _buildSummaryRow(
                      icon: Icons.location_on_outlined,
                      label: l10n.labelPlace,
                      value: incidente.luogo,
                    ),
                    _buildSummaryRow(
                      icon: Icons.perm_contact_calendar_outlined,
                      label: _detailText(
                        it: 'Contatti',
                        de: 'Kontakte',
                        fr: 'Contacts',
                        en: 'Contacts',
                      ),
                      value: contactsValue,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.cloud_done_outlined,
                            size: 18,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 124,
                            child: Text(
                              _detailText(
                                it: 'Stato sincronizzazione',
                                de: 'Synchronisierungsstatus',
                                fr: 'État de synchronisation',
                                en: 'Sync status',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (emailStatusLabel.isNotEmpty)
                                  _buildDetailBadge(
                                    icon: _emailStatusIcon(),
                                    label: emailStatusLabel,
                                    backgroundColor: _emailStatusBackground(),
                                    foregroundColor: _emailStatusForeground(),
                                  ),
                                if (emailLastAttempt.isNotEmpty)
                                  _buildDetailBadge(
                                    icon: Icons.history_toggle_off,
                                    label:
                                        '${_detailText(it: 'Ultimo tentativo', de: 'Letzter Versuch', fr: 'Dernière tentative', en: 'Last attempt')}: $emailLastAttempt',
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    foregroundColor: const Color(0xFF4B5563),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (emailStatusDescription.isNotEmpty &&
                        incidente.emailSendStatus != 'failed') ...[
                      Text(
                        emailStatusDescription,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (incidente.emailSendStatus == 'failed') ...[
                      _buildSoftInfoBox(
                        icon: Icons.warning_amber_rounded,
                        title: _detailText(
                          it: 'Invio e-mail temporaneamente non riuscito.',
                          de: 'E-Mail-Versand vorübergehend nicht erfolgreich.',
                          fr: 'Envoi de l’e-mail temporairement indisponible.',
                          en: 'Email sending is temporarily unavailable.',
                        ),
                        message: _detailText(
                          it: 'La pratica è stata salvata correttamente. Puoi riprovare l’invio più tardi.',
                          de: 'Die Schadenakte wurde korrekt gespeichert. Sie können den Versand später erneut versuchen.',
                          fr: 'Le dossier a bien été enregistré. Vous pourrez réessayer l’envoi plus tard.',
                          en: 'The claim was saved correctly. You can retry sending it later.',
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _buildSoftInfoBox(
                      icon: integrityIcon,
                      title: integrityTitle,
                      message: integrityMessage,
                      backgroundColor: integrityBackgroundColor,
                      foregroundColor: integrityForegroundColor,
                      borderColor: integrityBorderColor,
                    ),
                    const SizedBox(height: 10),
                    if (_locked && !widget.readOnly)
                      _buildSoftInfoBox(
                        icon: Icons.lock_outline,
                        title: lockedTitle,
                        message: lockedMessage,
                        backgroundColor: const Color(0xFFEFF6FF),
                        foregroundColor: const Color(0xFF1D4ED8),
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
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildSoftInfoBox(
                          icon: Icons.lock_outline,
                          title: lockedTitle,
                          message: lockedMessage,
                          backgroundColor: const Color(0xFFEFF6FF),
                          foregroundColor: const Color(0xFF1D4ED8),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 60,
                                child: Image.memory(
                                  firmaABytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _detailText(
                                  it: 'Firmato digitalmente',
                                  de: 'Digital signiert',
                                  fr: 'Signé numériquement',
                                  en: 'Digitally signed',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            _detailText(
                              it: 'Firma A non trovata. Chiedi di firmare di nuovo.',
                              de: 'Unterschrift A nicht gefunden. Bitte erneut unterschreiben.',
                              fr: 'Signature A introuvable. Merci de signer à nouveau.',
                              en: 'Signature A not found. Please sign again.',
                            ),
                            style: TextStyle(
                                fontSize: 12, color: Colors.redAccent),
                          ),
                        Text(
                          '${_detailText(it: 'Timestamp UTC', de: 'UTC-Zeitstempel', fr: 'Horodatage UTC', en: 'UTC timestamp')}: ${incidente.timestampFirmaA.isEmpty ? '-' : incidente.timestampFirmaA}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (incidente.firmaBPath.isNotEmpty) ...[
                        Text(l10n.labelDriverB),
                        const SizedBox(height: 4),
                        if (firmaBExists)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 60,
                                child: Image.memory(
                                  firmaBBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _detailText(
                                  it: 'Firmato digitalmente',
                                  de: 'Digital signiert',
                                  fr: 'Signé numériquement',
                                  en: 'Digitally signed',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            _detailText(
                              it: 'Firma B non trovata. Chiedi di firmare di nuovo.',
                              de: 'Unterschrift B nicht gefunden. Bitte erneut unterschreiben.',
                              fr: 'Signature B introuvable. Merci de signer à nouveau.',
                              en: 'Signature B not found. Please sign again.',
                            ),
                            style: TextStyle(
                                fontSize: 12, color: Colors.redAccent),
                          ),
                        Text(
                          '${_detailText(it: 'Timestamp UTC', de: 'UTC-Zeitstempel', fr: 'Horodatage UTC', en: 'UTC timestamp')}: ${incidente.timestampFirmaB.isEmpty ? '-' : incidente.timestampFirmaB}',
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
                        onPressed: _isSendingAuto
                            ? null
                            : () => _sendCidAutomatically(incidente.id),
                        icon: const Icon(Icons.send),
                        label: Text(
                          _detailText(
                            it: 'Invia automaticamente pratica',
                            de: 'Schadenakte automatisch senden',
                            fr: 'Envoyer automatiquement le dossier',
                            en: 'Send claim automatically',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSharingIncident
                            ? null
                            : () => _condividiPerAssicurazione(context),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          _detailText(
                            it: 'Condividi PDF e foto',
                            de: 'PDF und Fotos teilen',
                            fr: 'Partager PDF et photos',
                            en: 'Share PDF and photos',
                          ),
                        ),
                      ),
                    ),
                    if (incidente.emailSendStatus == 'failed') ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSendingAuto ? null : _retryPendingSync,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            _detailText(
                              it: 'Riprova invio',
                              de: 'Versand erneut versuchen',
                              fr: 'Réessayer l’envoi',
                              en: 'Retry sending',
                            ),
                          ),
                        ),
                      ),
                    ],
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
                          _detailText(
                            it: 'QR per importazione pratica',
                            de: 'QR zum Importieren der Schadenakte',
                            fr: 'QR pour importer le dossier',
                            en: 'QR to import the claim',
                          ),
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
                              const Icon(Icons.info_outline,
                                  color: Colors.orangeAccent),
                              const SizedBox(height: 6),
                              Text(
                                _detailText(
                                  it: 'Impossibile generare il QR della pratica',
                                  de: 'QR der Schadenakte konnte nicht erstellt werden',
                                  fr: 'Impossible de générer le QR du dossier',
                                  en: 'Unable to generate the claim QR',
                                ),
                                style: const TextStyle(
                                    color: Colors.orangeAccent, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _startWorkshopQr,
                                icon: const Icon(Icons.refresh),
                                label: Text(
                                  _detailText(
                                    it: 'Genera QR importazione',
                                    de: 'Import-QR erstellen',
                                    fr: 'Générer le QR d’import',
                                    en: 'Generate import QR',
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        final qrDataReady = snapshot.data ?? '';
                        if (qrDataReady.isEmpty) {
                          return Column(
                            children: [
                              const Icon(Icons.qr_code_2,
                                  color: Colors.blueAccent),
                              const SizedBox(height: 6),
                              Text(
                                _detailText(
                                  it: 'Genera il QR per permettere alla carrozzeria di importare automaticamente la pratica.',
                                  de: 'Erzeugen Sie den QR-Code, damit die Werkstatt die Schadenakte automatisch importieren kann.',
                                  fr: 'Générez le QR pour permettre au garage d’importer automatiquement le dossier.',
                                  en: 'Generate the QR so the workshop can automatically import the claim.',
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _startWorkshopQr,
                                icon: const Icon(Icons.qr_code),
                                label: Text(
                                  _detailText(
                                    it: 'Genera QR importazione',
                                    de: 'Import-QR erstellen',
                                    fr: 'Générer le QR d’import',
                                    en: 'Generate import QR',
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
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
                              _detailText(
                                it: 'Mostra questo QR alla carrozzeria per importare automaticamente tutti i dati dell’incidente.',
                                de: 'Zeigen Sie diesen QR-Code der Werkstatt, um die Schadenakte automatisch zu importieren.',
                                fr: 'Montrez ce QR au garage pour importer automatiquement toutes les données de l’accident.',
                                en: 'Show this QR to the workshop to automatically import all accident data.',
                              ),
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
