import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

enum SupportRequestType {
  problem('problem'),
  question('question'),
  suggestion('suggestion');

  const SupportRequestType(this.value);

  final String value;
}

class SupportRequestAttachment {
  const SupportRequestAttachment({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  int get byteSize => bytes.lengthInBytes;
}

class SupportRequestDraft {
  const SupportRequestDraft({
    required this.requestType,
    required this.subject,
    required this.message,
    required this.replyEmail,
    required this.attachments,
  });

  final SupportRequestType requestType;
  final String subject;
  final String message;
  final String replyEmail;
  final List<SupportRequestAttachment> attachments;
}

class SupportRequestSubmission {
  const SupportRequestSubmission({
    required this.requestId,
    required this.reference,
  });

  final String requestId;
  final String reference;
}

class SupportRequestSubmissionException implements Exception {
  const SupportRequestSubmissionException({this.savedRequestId});

  final String? savedRequestId;
}

abstract interface class SupportRequestGateway {
  Future<SupportRequestSubmission> submit({
    required String userId,
    required SupportRequestDraft draft,
  });

  Future<SupportRequestSubmission> retryNotification({
    required String userId,
    required String requestId,
  });
}

class SupabaseSupportRequestGateway implements SupportRequestGateway {
  SupabaseSupportRequestGateway({
    SupabaseClient? client,
    String Function()? requestIdFactory,
  })  : _client = client ?? Supabase.instance.client,
        _requestIdFactory = requestIdFactory ?? _newUuidV4;

  static const String bucketName = 'support-attachments';
  static const String notificationFunction =
      'send-support-request-notification';

  final SupabaseClient _client;
  final String Function() _requestIdFactory;

  @override
  Future<SupportRequestSubmission> submit({
    required String userId,
    required SupportRequestDraft draft,
  }) async {
    _ensureAuthenticatedOwner(userId);
    final requestId = _requestIdFactory();
    final uploadedPaths = <String>[];
    var requestSaved = false;

    try {
      final attachmentMetadata = <Map<String, dynamic>>[];
      for (var index = 0; index < draft.attachments.length; index++) {
        final attachment = draft.attachments[index];
        final fileName = _safeFileName(attachment.fileName, index);
        final objectPath = '$userId/$requestId/'
            '${index + 1}_${DateTime.now().microsecondsSinceEpoch}_$fileName';
        await _client.storage.from(bucketName).uploadBinary(
              objectPath,
              attachment.bytes,
              fileOptions: FileOptions(
                contentType: attachment.mimeType,
                upsert: false,
              ),
            );
        uploadedPaths.add(objectPath);
        attachmentMetadata.add({
          'bucket': bucketName,
          'path': objectPath,
          'file_name': fileName,
          'mime_type': attachment.mimeType,
          'byte_size': attachment.byteSize,
        });
      }

      final row = await _client
          .from('support_requests')
          .insert({
            'id': requestId,
            'created_by': userId,
            'user_email': draft.replyEmail.trim(),
            'request_type': draft.requestType.value,
            'subject': draft.subject.trim(),
            'message': draft.message.trim(),
            'attachment_urls': attachmentMetadata,
          })
          .select('id, created_at')
          .single();
      requestSaved = true;

      return await _notify(
        userId: userId,
        requestId: requestId,
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      );
    } catch (_) {
      if (!requestSaved && uploadedPaths.isNotEmpty) {
        try {
          await _client.storage.from(bucketName).remove(uploadedPaths);
        } catch (_) {}
      }
      throw SupportRequestSubmissionException(
        savedRequestId: requestSaved ? requestId : null,
      );
    }
  }

  @override
  Future<SupportRequestSubmission> retryNotification({
    required String userId,
    required String requestId,
  }) async {
    _ensureAuthenticatedOwner(userId);
    try {
      final row = await _client
          .from('support_requests')
          .select('id, created_at')
          .eq('id', requestId)
          .eq('created_by', userId)
          .single();
      return await _notify(
        userId: userId,
        requestId: requestId,
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      );
    } catch (_) {
      throw SupportRequestSubmissionException(savedRequestId: requestId);
    }
  }

  Future<SupportRequestSubmission> _notify({
    required String userId,
    required String requestId,
    required DateTime? createdAt,
  }) async {
    _ensureAuthenticatedOwner(userId);
    final response = await _client.functions.invoke(
      notificationFunction,
      body: {'request_id': requestId},
    );
    final data = response.data;
    if (response.status >= 400 || data is! Map || data['success'] != true) {
      throw SupportRequestSubmissionException(savedRequestId: requestId);
    }
    return SupportRequestSubmission(
      requestId: requestId,
      reference: data['reference']?.toString().trim().isNotEmpty == true
          ? data['reference'].toString().trim()
          : supportRequestReference(requestId, createdAt ?? DateTime.now()),
    );
  }

  void _ensureAuthenticatedOwner(String userId) {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId != userId) {
      throw const SupportRequestSubmissionException();
    }
  }

  static String _safeFileName(String value, int index) {
    final sanitized = value.trim().replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]'),
          '_',
        );
    return sanitized.isEmpty ? 'support_${index + 1}.jpg' : sanitized;
  }

  static String _newUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}

String supportRequestReference(String requestId, DateTime createdAt) {
  final compactId = requestId.replaceAll('-', '').toUpperCase();
  final suffix = compactId.length >= 6 ? compactId.substring(0, 6) : compactId;
  return 'SUP-${createdAt.toUtc().year}-$suffix';
}
