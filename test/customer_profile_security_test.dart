import 'dart:io';

import 'package:cid_digitale/models/customer_profile.dart';
import 'package:cid_digitale/services/customer_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const account = CustomerAccount(
    id: 'customer-1',
    email: 'owner@example.com',
    role: customerRole,
  );

  test('profile access guard allows only the authenticated owner', () {
    expect(
      () => CustomerProfileAccessGuard.ensureOwner(account, 'customer-1'),
      returnsNormally,
    );
    expect(
      () => CustomerProfileAccessGuard.ensureOwner(account, 'customer-2'),
      throwsA(
        isA<CustomerAuthException>().having(
          (error) => error.code,
          'code',
          CustomerAuthErrorCode.unauthenticated,
        ),
      ),
    );
    expect(
      () => CustomerProfileAccessGuard.ensureOwner(null, 'customer-1'),
      throwsA(isA<CustomerAuthException>()),
    );
  });

  test('customer profile upsert never contains another account identifier', () {
    const profile = CustomerProfile(
      userId: 'customer-1',
      firstName: 'Mario',
      lastName: 'Rossi',
      email: 'owner@example.com',
      profileCompleted: true,
    );

    CustomerProfileAccessGuard.ensureOwner(account, profile.userId);
    expect(profile.toUpsertMap()['user_id'], account.id);
    expect(profile.toUpsertMap()['profile_completed'], isTrue);
  });

  test('migration enables RLS and scopes every operation to auth.uid', () {
    final sql = File(
      'supabase/migrations/20260724090000_create_customer_profiles.sql',
    ).readAsStringSync();

    expect(sql, contains('enable row level security'));
    expect(sql,
        contains('revoke all on table public.customer_profiles from anon'));
    expect(sql, contains('customer_profiles_select_own'));
    expect(sql, contains('customer_profiles_insert_own'));
    expect(sql, contains('customer_profiles_update_own'));
    expect(sql, contains('customer_profiles_delete_own'));
    expect(
      RegExp(r'auth\.uid\(\)\) = user_id').allMatches(sql).length,
      greaterThanOrEqualTo(5),
    );
    expect(sql, isNot(contains('service_role')));
  });
}
