import 'package:supabase_flutter/supabase_flutter.dart';

class IncidentsSyncService {
  IncidentsSyncService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> uploadIncident({
    required Map<String, dynamic> payload,
    required String hashSha256,
    required DateTime timestampUtc,
    String? locale,
    String? deviceId,
  }) async {
    await _client.from('incidents').insert({
      'hash_sha256': hashSha256,
      'timestamp_utc': timestampUtc.toIso8601String(),
      'locale': locale,
      'device_id': deviceId,
      'payload': payload,
    });
  }
}
