/// These versions must only change when the corresponding legal document is
/// intentionally revised and a new acceptance cycle has been approved.
const String privacyPolicyVersion = '2026-08-08';
const String termsOfUseVersion = '2026-08-08';

const String privacyAcceptedAtKey = 'privacy_accepted_at';
const String privacyVersionKey = 'privacy_version';
const String termsAcceptedAtKey = 'terms_accepted_at';
const String termsVersionKey = 'terms_version';

class CustomerLegalAcceptance {
  const CustomerLegalAcceptance({
    required this.privacyAcceptedAt,
    required this.privacyVersion,
    required this.termsAcceptedAt,
    required this.termsVersion,
  });

  factory CustomerLegalAcceptance.acceptedNow() {
    return CustomerLegalAcceptance.acceptedAt(DateTime.now());
  }

  factory CustomerLegalAcceptance.acceptedAt(DateTime acceptedAt) {
    final timestamp = acceptedAt.toUtc();
    return CustomerLegalAcceptance(
      privacyAcceptedAt: timestamp,
      privacyVersion: privacyPolicyVersion,
      termsAcceptedAt: timestamp,
      termsVersion: termsOfUseVersion,
    );
  }

  final DateTime privacyAcceptedAt;
  final String privacyVersion;
  final DateTime termsAcceptedAt;
  final String termsVersion;

  static CustomerLegalAcceptance? fromMap(Map<String, dynamic> map) {
    final privacyAcceptedAt = _parseTimestamp(map[privacyAcceptedAtKey]);
    final termsAcceptedAt = _parseTimestamp(map[termsAcceptedAtKey]);
    final privacyVersion = map[privacyVersionKey]?.toString().trim() ?? '';
    final termsVersion = map[termsVersionKey]?.toString().trim() ?? '';

    final allMissing = privacyAcceptedAt == null &&
        termsAcceptedAt == null &&
        privacyVersion.isEmpty &&
        termsVersion.isEmpty;
    if (allMissing) return null;

    final complete = privacyAcceptedAt != null &&
        termsAcceptedAt != null &&
        privacyVersion.isNotEmpty &&
        termsVersion.isNotEmpty;
    if (!complete) return null;

    return CustomerLegalAcceptance(
      privacyAcceptedAt: privacyAcceptedAt,
      privacyVersion: privacyVersion,
      termsAcceptedAt: termsAcceptedAt,
      termsVersion: termsVersion,
    );
  }

  Map<String, dynamic> toAuthMetadata() {
    return {
      privacyAcceptedAtKey: privacyAcceptedAt.toUtc().toIso8601String(),
      privacyVersionKey: privacyVersion,
      termsAcceptedAtKey: termsAcceptedAt.toUtc().toIso8601String(),
      termsVersionKey: termsVersion,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerLegalAcceptance &&
        other.privacyAcceptedAt == privacyAcceptedAt &&
        other.privacyVersion == privacyVersion &&
        other.termsAcceptedAt == termsAcceptedAt &&
        other.termsVersion == termsVersion;
  }

  @override
  int get hashCode => Object.hash(
        privacyAcceptedAt,
        privacyVersion,
        termsAcceptedAt,
        termsVersion,
      );
}
