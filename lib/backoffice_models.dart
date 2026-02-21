// INCOLLA QUI - Modello base per pratica/backoffice locale (senza backend)
import 'package:flutter/foundation.dart';

enum BackofficeRole { officina, assicurazione }

enum ClaimStatus { bozza, attiva, chiusa }

class ClaimAttachment {
  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;
  final BackofficeRole uploadedBy;

  const ClaimAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'uploadedAt': uploadedAt.toIso8601String(),
        'uploadedBy': uploadedBy.name,
      };

  factory ClaimAttachment.fromJson(Map<String, dynamic> json) {
    return ClaimAttachment(
      id: json['id']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? '',
      sizeBytes: json['sizeBytes'] is int
          ? json['sizeBytes'] as int
          : int.tryParse(json['sizeBytes']?.toString() ?? '') ?? 0,
      uploadedAt: DateTime.tryParse(json['uploadedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      uploadedBy: BackofficeRole.values.firstWhere(
        (r) => r.name == json['uploadedBy'],
        orElse: () => BackofficeRole.officina,
      ),
    );
  }
}

class ClaimMessage {
  final String id;
  final String claimId;
  final BackofficeRole fromRole;
  final String authorName;
  final String text;
  final DateTime sentAt;

  const ClaimMessage({
    required this.id,
    required this.claimId,
    required this.fromRole,
    required this.authorName,
    required this.text,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'claimId': claimId,
        'fromRole': fromRole.name,
        'authorName': authorName,
        'text': text,
        'sentAt': sentAt.toIso8601String(),
      };

  factory ClaimMessage.fromJson(Map<String, dynamic> json) {
    return ClaimMessage(
      id: json['id']?.toString() ?? '',
      claimId: json['claimId']?.toString() ?? '',
      fromRole: BackofficeRole.values.firstWhere(
        (r) => r.name == json['fromRole'],
        orElse: () => BackofficeRole.officina,
      ),
      authorName: json['authorName']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

@immutable
class ClaimRecord {
  final String idPratica;
  final String hashedToken; // Solo hash salvato per GDPR; mai salvare il token in chiaro.
  final DateTime createdAt;
  final DateTime expiresAt; // Validità: 30 giorni.
  final DateTime retentionUntil; // Conservazione: fino a 10 anni.
  final ClaimStatus status;
  final List<ClaimMessage> messages;
  final List<ClaimAttachment> attachments;
  final String? codiceOfficina;

  const ClaimRecord({
    required this.idPratica,
    required this.hashedToken,
    required this.createdAt,
    required this.expiresAt,
    required this.retentionUntil,
    required this.status,
    this.messages = const [],
    this.attachments = const [],
    this.codiceOfficina,
  });

  ClaimRecord copyWith({
    String? idPratica,
    String? hashedToken,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? retentionUntil,
    ClaimStatus? status,
    List<ClaimMessage>? messages,
    List<ClaimAttachment>? attachments,
    String? codiceOfficina,
  }) {
    return ClaimRecord(
      idPratica: idPratica ?? this.idPratica,
      hashedToken: hashedToken ?? this.hashedToken,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      retentionUntil: retentionUntil ?? this.retentionUntil,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      attachments: attachments ?? this.attachments,
      codiceOfficina: codiceOfficina ?? this.codiceOfficina,
    );
  }

  Map<String, dynamic> toJson() => {
        'idPratica': idPratica,
        'hashedToken': hashedToken,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'retentionUntil': retentionUntil.toIso8601String(),
        'status': status.name,
        'messages': messages.map((m) => m.toJson()).toList(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'codiceOfficina': codiceOfficina,
      };

  factory ClaimRecord.fromJson(Map<String, dynamic> json) {
    return ClaimRecord(
      idPratica: json['idPratica']?.toString() ?? '',
      hashedToken: json['hashedToken']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now().toUtc().add(const Duration(days: 30)),
      retentionUntil:
          DateTime.tryParse(json['retentionUntil']?.toString() ?? '') ??
              DateTime.now().toUtc().add(const Duration(days: 3650)),
      status: ClaimStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ClaimStatus.attiva,
      ),
      messages: (json['messages'] is List)
          ? (json['messages'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ClaimMessage.fromJson)
              .toList()
          : const [],
      attachments: (json['attachments'] is List)
          ? (json['attachments'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ClaimAttachment.fromJson)
              .toList()
          : const [],
      codiceOfficina: json['codiceOfficina']?.toString(),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get canBeDeleted => DateTime.now().isAfter(retentionUntil);
}
