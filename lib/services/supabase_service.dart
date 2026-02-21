import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('Supabase non inizializzato');
    }
  }

  Future<String> createClaim(Map<String, dynamic> cidJson) async {
    final response = await client
        .from('claims')
        .insert({
          'status': 'warten_auf_freigabe',
          'payload_json': cidJson,
        })
        .select('id')
        .single();

    return '${response['id']}';
  }

  Future<String> createClaimLink({
    required String claimId,
    String purpose = 'workshop',
    int maxUses = 50,
  }) async {
    final response = await client
        .from('claim_links')
        .insert({
          'claim_id': claimId,
          'purpose': purpose,
          'max_uses': maxUses,
        })
        .select('token')
        .single();

    return response['token'] as String;
  }

  Future<String> rpcCreateClaimDraft({
    required String workshopCode,
    Map<String, dynamic>? payload,
  }) async {
    final res = await client.rpc('create_claim_draft', params: {
      'p_workshop_code': workshopCode,
      'p_payload_json': payload ?? <String, dynamic>{},
      'p_status': 'warten_auf_freigabe',
      'p_expires_days': 30,
      'p_retention_days': 180,
    });
    if (res == null) {
      throw Exception('create_claim_draft non ha restituito un ID');
    }
    return res.toString();
  }

  Future<String> rpcCreateClaimLinkWorkshop({
    required String claimId,
    int expiresHours = 72,
    int maxUses = 1,
  }) async {
    final res = await client.rpc(
      'create_claim_link',
      params: {
        'p_claim_id': claimId,
        'p_expires_hours': expiresHours,
        'p_max_uses': maxUses,
        'p_purpose': 'workshop_intake',
      },
    );

    if (res == null) {
      throw Exception('RPC returned null');
    }

    String token = '';

    if (res is String) {
      final trimmed = res.trim();
      if (trimmed.startsWith('{')) {
        try {
          final parsed = jsonDecode(trimmed);
          if (parsed is Map && parsed['token'] is String) {
            token = parsed['token'] as String;
          }
        } catch (_) {
          token = trimmed;
        }
      } else {
        token = trimmed;
      }
    } else if (res is Map && res['token'] is String) {
      token = res['token'] as String;
    }

    if (token.isEmpty) {
      throw Exception('Invalid RPC response: $res');
    }

    return token;
  }

  Future<String> uploadClaimImageBytes({
    required String claimId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    required String kind,
    String bucket = 'claim_attachments',
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = filename.replaceAll(' ', '_');
    final path = 'claims/$claimId/$kind/${ts}_$safeName';

    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    final publicUrl = client.storage.from(bucket).getPublicUrl(path);
    if (publicUrl.isEmpty) {
      throw Exception('Impossibile ottenere URL pubblico per $path');
    }
    return publicUrl;
  }

  Future<Map<String, dynamic>> getClaim(String claimId) async {
    final response =
        await client.from('claims').select('*').eq('id', claimId).single();

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> fetchClaimByToken(String token) async {
    final link = await client
        .from('claim_links')
        .select('claim_id, expires_at, used_count, max_uses, purpose')
        .eq('token', token)
        .maybeSingle();

    if (link == null) throw Exception('Invalid/unknown token');

    final expiresAt = link['expires_at'];
    if (expiresAt != null) {
      final dt = DateTime.tryParse(expiresAt.toString());
      if (dt != null && dt.isBefore(DateTime.now().toUtc())) {
        throw Exception('Token expired');
      }
    }

    final claimId = link['claim_id']?.toString();
    if (claimId == null || claimId.isEmpty) {
      throw Exception('Token has no claim_id');
    }

    return getClaim(claimId);
  }

  Future<List<Map<String, dynamic>>> listClaims({int limit = 50}) async {
    final response = await client
        .from('claims')
        .select('id,status,created_at')
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(
      response.map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<List<Map<String, dynamic>>> listRecentClaims({int limit = 10}) async {
    final data = await client
        .from('claims')
        .select('id,status,created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(
      data.map((e) => Map<String, dynamic>.from(e)),
    );
  }
}
