import 'dart:io';

import 'package:cid_digitale/models/customer_legal_acceptance.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('recognizes the obfuscated Supabase response for an existing account',
      () {
    final response = AuthResponse(
      user: const User(
        id: 'obfuscated-user',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '',
        identities: [],
      ),
    );

    expect(isExistingAuthAccountSignUpResponse(response), isTrue);
  });

  test('does not classify a new email identity as an existing account', () {
    final response = AuthResponse(
      user: const User(
        id: 'new-user',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '',
        identities: [
          UserIdentity(
            id: 'identity-1',
            userId: 'new-user',
            identityData: {},
            identityId: 'identity-1',
            provider: 'email',
            createdAt: '',
            lastSignInAt: null,
          ),
        ],
      ),
    );

    expect(isExistingAuthAccountSignUpResponse(response), isFalse);
  });

  test('sign-up carries the complete legal acceptance metadata contract', () {
    final acceptance = CustomerLegalAcceptance.acceptedAt(
      DateTime.parse('2026-08-08T12:30:00Z'),
    );
    final metadata = acceptance.toAuthMetadata();

    expect(metadata.keys.toSet(), {
      privacyAcceptedAtKey,
      privacyVersionKey,
      termsAcceptedAtKey,
      termsVersionKey,
    });
    expect(metadata[privacyVersionKey], '2026-08-08');
    expect(metadata[termsVersionKey], '2026-08-08');

    final serviceSource =
        File('lib/services/customer_auth_service.dart').readAsStringSync();
    expect(
      serviceSource,
      contains('...legalAcceptance.toAuthMetadata()'),
    );
  });
}
