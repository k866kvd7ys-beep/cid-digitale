import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClaimByTokenResult {
  final String claimId;
  final dynamic payloadJson;

  ClaimByTokenResult({required this.claimId, required this.payloadJson});
}

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
    required String purpose,
    int expiresHours = 24 * 14,
    int maxUses = 5,
  }) async {
    final res = await client.rpc(
      'create_claim_link',
      params: {
        'p_claim_id': claimId,
        'p_expires_hours': expiresHours,
        'p_max_uses': maxUses,
        'p_purpose': purpose,
      },
    );

    if (res == null) {
      throw Exception('create_claim_link non ha restituito un token');
    }

    String token = '';

    if (res is Map && res['token'] != null) {
      token = res['token'].toString().trim();
    } else if (res is String) {
      final trimmed = res.trim();
      if (trimmed.startsWith('{')) {
        try {
          final parsed = jsonDecode(trimmed);
          if (parsed is Map && parsed['token'] != null) {
            token = parsed['token'].toString().trim();
          }
        } catch (_) {
          token = trimmed;
        }
      } else {
        token = trimmed;
      }
    } else {
      token = res.toString().trim();
    }

    if (token.isEmpty) {
      throw Exception('Token vuoto dalla RPC create_claim_link: $res');
    }

    return token;
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
  }) {
    return createClaimLink(
      claimId: claimId,
      purpose: 'workshop_intake',
      expiresHours: expiresHours,
      maxUses: maxUses,
    );
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

  Future<ClaimByTokenResult> fetchClaimByToken(String token) async {
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

    final claim = await getClaim(claimId);

    return ClaimByTokenResult(
      claimId: claimId,
      payloadJson: claim['payload_json'],
    );
  }

  Future<String?> getCurrentWorkshopOrgId() async {
    try {
      final user = client.auth.currentUser;
      final Map<String, dynamic>? meta =
          user != null ? user.userMetadata as Map<String, dynamic>? : null;
      if (meta != null) {
        final candidates = [
          'workshop_org_id',
          'org_id',
          'organization_id',
          'organisation_id',
        ];
        for (final key in candidates) {
          final v = meta[key];
          if (v != null && v.toString().trim().isNotEmpty) {
            return v.toString().trim();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> markClaimAsInLavorazioneIfWorkshop(String claimId) async {
    try {
      final currentOrgId = await getCurrentWorkshopOrgId();

      final claim = await client
          .from('claims')
          .select('id,status,workshop_org_id')
          .eq('id', claimId)
          .maybeSingle();

      if (claim == null) return;

      final String status =
          (claim['status'] ?? '').toString().trim().toLowerCase();
      final dynamic orgField = claim['workshop_org_id'];
      final String? workshopOrgId =
          (orgField == null || (orgField is String && orgField.trim().isEmpty))
              ? null
              : orgField.toString().trim();

      final initialStatuses = <String>{
        'temp',
        'warten_auf_freigabe',
        'in_attesa',
        'pending',
        'draft',
      };

      final Map<String, dynamic> update = {};
      if (status.isNotEmpty && initialStatuses.contains(status)) {
        update['status'] = 'in_lavorazione';
      }
      if (workshopOrgId == null && currentOrgId != null) {
        update['workshop_org_id'] = currentOrgId;
      }

      if (update.isEmpty) return;

      await client.from('claims').update(update).eq('id', claimId);
    } catch (e) {
      debugPrint('markClaimAsInLavorazioneIfWorkshop failed: $e');
    }
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
