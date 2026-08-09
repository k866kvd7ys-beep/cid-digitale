import 'package:cid_digitale/models/customer_legal_acceptance.dart';
import 'package:cid_digitale/models/customer_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acceptedAt generates UTC timestamps and intentional document versions',
      () {
    final acceptance = CustomerLegalAcceptance.acceptedAt(
      DateTime.parse('2026-08-08T14:30:00+02:00'),
    );

    expect(
      acceptance.privacyAcceptedAt,
      DateTime.parse('2026-08-08T12:30:00Z'),
    );
    expect(acceptance.termsAcceptedAt, acceptance.privacyAcceptedAt);
    expect(acceptance.privacyVersion, '2026-08-08');
    expect(acceptance.termsVersion, '2026-08-08');
  });

  test('Auth metadata round-trip keeps both complete acceptances', () {
    final acceptance = CustomerLegalAcceptance.acceptedAt(
      DateTime.parse('2026-08-08T12:30:00Z'),
    );

    expect(
      CustomerLegalAcceptance.fromMap(acceptance.toAuthMetadata()),
      acceptance,
    );
  });

  test('missing or partial acceptance never becomes an invented consent', () {
    expect(CustomerLegalAcceptance.fromMap(const {}), isNull);
    expect(
      CustomerLegalAcceptance.fromMap(const {
        privacyAcceptedAtKey: '2026-08-08T12:30:00Z',
        privacyVersionKey: '2026-08-08',
      }),
      isNull,
    );
    expect(
      CustomerLegalAcceptance.fromMap(const {
        privacyAcceptedAtKey: 'invalid',
        privacyVersionKey: '2026-08-08',
        termsAcceptedAtKey: '2026-08-08T12:30:00Z',
        termsVersionKey: '2026-08-08',
      }),
      isNull,
    );
  });

  test('legacy customer profile with no acceptance remains valid and null', () {
    final profile = CustomerProfile.fromMap(const {
      'user_id': 'legacy-customer',
      'first_name': 'Legacy',
      'last_name': 'Customer',
      'email': 'legacy@example.com',
      'profile_completed': true,
    });

    expect(profile.legalAcceptance, isNull);
    expect(profile.toUpsertMap(), isNot(contains(privacyAcceptedAtKey)));
    expect(profile.toUpsertMap(), isNot(contains(privacyVersionKey)));
    expect(profile.toUpsertMap(), isNot(contains(termsAcceptedAtKey)));
    expect(profile.toUpsertMap(), isNot(contains(termsVersionKey)));
  });

  test('profile reads a complete acceptance returned by the database', () {
    final profile = CustomerProfile.fromMap(const {
      'user_id': 'new-customer',
      'first_name': 'New',
      'last_name': 'Customer',
      'email': 'new@example.com',
      'profile_completed': true,
      privacyAcceptedAtKey: '2026-08-08T12:30:00Z',
      privacyVersionKey: '2026-08-08',
      termsAcceptedAtKey: '2026-08-08T12:30:00Z',
      termsVersionKey: '2026-08-08',
    });

    expect(profile.legalAcceptance, isNotNull);
    expect(profile.legalAcceptance!.privacyVersion, '2026-08-08');
    expect(profile.legalAcceptance!.termsVersion, '2026-08-08');
  });
}
