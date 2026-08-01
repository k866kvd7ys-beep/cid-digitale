import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class CustomerIncidentHistorySession {
  String? get currentUserId;

  Stream<String?> get userChanges;
}

class SupabaseCustomerIncidentHistorySession
    implements CustomerIncidentHistorySession {
  SupabaseCustomerIncidentHistorySession({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<String?> get userChanges => _client.auth.onAuthStateChange
      .map((state) => state.session?.user.id)
      .distinct();
}

abstract interface class CustomerIncidentHistoryRemoteDataSource {
  Future<List<Map<String, dynamic>>> loadClaims(String userId);
}

class SupabaseCustomerIncidentHistoryRemoteDataSource
    implements CustomerIncidentHistoryRemoteDataSource {
  SupabaseCustomerIncidentHistoryRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> loadClaims(String userId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId != userId) {
      throw StateError(
        'Authenticated customer does not match incident history owner',
      );
    }

    final response = await _client
        .from('claims')
        .select('id, payload_json, status, created_at')
        .eq('created_by', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}

class CustomerIncidentHistoryEntry {
  const CustomerIncidentHistoryEntry({
    required this.id,
    required this.payload,
    required this.status,
    required this.createdAt,
    required this.isLocalDraft,
  });

  final String id;
  final Map<String, dynamic> payload;
  final String status;
  final DateTime createdAt;
  final bool isLocalDraft;

  Map<String, dynamic> get incidentPayload => {
        ...payload,
        'id': id,
        if (status.isNotEmpty) 'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toCacheMap() => {
        'id': id,
        'payload_json': payload,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}

class CustomerIncidentHistoryLoadResult {
  const CustomerIncidentHistoryLoadResult({
    required this.entries,
    required this.remoteSucceeded,
    this.error,
  });

  final List<CustomerIncidentHistoryEntry> entries;
  final bool remoteSucceeded;
  final Object? error;
}

class CustomerIncidentHistoryRepository {
  CustomerIncidentHistoryRepository({
    CustomerIncidentHistoryRemoteDataSource? remoteDataSource,
    SharedPreferences? preferences,
  })  : _remoteDataSource = remoteDataSource ??
            SupabaseCustomerIncidentHistoryRemoteDataSource(),
        _preferences = preferences;

  static const _cacheKeyPrefix = 'customerIncidentHistory';
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final CustomerIncidentHistoryRemoteDataSource _remoteDataSource;
  final SharedPreferences? _preferences;

  static String cacheKeyForUser(String userId) =>
      '$_cacheKeyPrefix:${userId.trim()}';

  Future<CustomerIncidentHistoryLoadResult> loadForUser({
    required String userId,
    required List<Map<String, dynamic>> localPayloads,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User id is required');
    }

    final localDrafts = localDraftEntries(localPayloads);
    try {
      final rows = await _remoteDataSource.loadClaims(normalizedUserId);
      final remoteEntries = _remoteEntries(rows);
      await _writeCache(normalizedUserId, remoteEntries);
      return CustomerIncidentHistoryLoadResult(
        entries: mergeRemoteWithLocalDrafts(remoteEntries, localDrafts),
        remoteSucceeded: true,
      );
    } catch (error) {
      final cachedEntries = await _readCache(normalizedUserId);
      return CustomerIncidentHistoryLoadResult(
        entries: mergeRemoteWithLocalDrafts(cachedEntries, localDrafts),
        remoteSucceeded: false,
        error: error,
      );
    }
  }

  List<CustomerIncidentHistoryEntry> localDraftEntries(
    List<Map<String, dynamic>> localPayloads,
  ) {
    final drafts = <CustomerIncidentHistoryEntry>[];
    final seenIds = <String>{};

    for (final source in localPayloads) {
      final payload = _normalizePayload(source);
      final id = payload['id']?.toString().trim() ?? '';
      if (id.isEmpty || _uuidPattern.hasMatch(id) || !seenIds.add(id)) {
        continue;
      }
      final createdAt = _parseDate(payload['dataOra']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      drafts.add(
        CustomerIncidentHistoryEntry(
          id: id,
          payload: payload,
          status: '',
          createdAt: createdAt,
          isLocalDraft: true,
        ),
      );
    }

    drafts.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return drafts;
  }

  List<CustomerIncidentHistoryEntry> mergeRemoteWithLocalDrafts(
    List<CustomerIncidentHistoryEntry> remoteEntries,
    List<CustomerIncidentHistoryEntry> localDrafts,
  ) {
    final mergedById = <String, CustomerIncidentHistoryEntry>{};
    for (final entry in remoteEntries) {
      mergedById.putIfAbsent(entry.id, () => entry);
    }
    for (final draft in localDrafts) {
      mergedById.putIfAbsent(draft.id, () => draft);
    }

    final merged = mergedById.values.toList(growable: false);
    merged.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return merged;
  }

  List<CustomerIncidentHistoryEntry> _remoteEntries(
    List<Map<String, dynamic>> rows,
  ) {
    final entries = <CustomerIncidentHistoryEntry>[];
    for (final row in rows) {
      final id = row['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;

      final payloadSource = row['payload_json'];
      final payload = _normalizePayload(
        payloadSource is Map
            ? Map<String, dynamic>.from(payloadSource)
            : const <String, dynamic>{},
      );
      payload['id'] = id;
      final status = row['status']?.toString().trim() ??
          payload['status']?.toString().trim() ??
          '';
      final createdAt = _parseDate(row['created_at']) ??
          _parseDate(payload['dataOra']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

      entries.add(
        CustomerIncidentHistoryEntry(
          id: id,
          payload: payload,
          status: status,
          createdAt: createdAt,
          isLocalDraft: false,
        ),
      );
    }

    entries.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return entries;
  }

  Map<String, dynamic> _normalizePayload(Map<String, dynamic> source) {
    final payload = Map<String, dynamic>.from(source);
    const stringKeys = <String>{
      'id',
      'dataOra',
      'luogo',
      'nomeA',
      'cognomeA',
      'targaA',
      'assicurazioneA',
      'telefonoA',
      'emailA',
      'indirizzoA',
      'zipA',
      'cityA',
      'nomeB',
      'cognomeB',
      'targaB',
      'assicurazioneB',
      'telefonoB',
      'emailB',
      'indirizzoB',
      'zipB',
      'cityB',
      'descrizione',
      'danniVeicoloA',
      'danniVeicoloB',
      'notaVocaleA',
      'notaVocaleB',
      'notaAudioAPath',
      'notaAudioBPath',
      'fotoLibrettoA',
      'fotoLibrettoB',
      'firmaAPath',
      'firmaBPath',
      'timestampFirmaA',
      'timestampFirmaB',
      'colpevole',
      'codiceOfficina',
      'hashIntegrita',
      'emailSendStatus',
      'emailSendMessage',
      'emailSendLastAttemptAt',
      'status',
    };
    for (final key in stringKeys) {
      final value = payload[key];
      if (value != null && value is! String) payload[key] = value.toString();
    }

    for (final key in const <String>{
      'testimoni',
      'feriti',
      'conducentiAggiuntivi',
    }) {
      final value = payload[key];
      payload[key] = value is List
          ? value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
    }

    final photos = payload['fotoDanni'];
    payload['fotoDanni'] = photos is List
        ? photos.map((item) => item.toString()).toList(growable: false)
        : <String>[];
    return payload;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  Future<SharedPreferences> _preferencesInstance() async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<void> _writeCache(
    String userId,
    List<CustomerIncidentHistoryEntry> entries,
  ) async {
    final preferences = await _preferencesInstance();
    await preferences.setString(
      cacheKeyForUser(userId),
      jsonEncode(entries.map((entry) => entry.toCacheMap()).toList()),
    );
  }

  Future<List<CustomerIncidentHistoryEntry>> _readCache(String userId) async {
    final preferences = await _preferencesInstance();
    final stored = preferences.getString(cacheKeyForUser(userId));
    if (stored == null || stored.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return const [];
      final rows = decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      return _remoteEntries(rows);
    } catch (_) {
      return const [];
    }
  }
}
