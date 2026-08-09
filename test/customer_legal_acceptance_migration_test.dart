import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/'
      '20260808160000_add_customer_legal_acceptance.sql',
    ).readAsStringSync();
  });

  test('migration adds only the four nullable consent fields', () {
    expect(sql, contains('privacy_accepted_at timestamptz'));
    expect(sql, contains('privacy_version text'));
    expect(sql, contains('terms_accepted_at timestamptz'));
    expect(sql, contains('terms_version text'));
    expect(sql, isNot(contains('not null default')));
    expect(sql, isNot(contains('update public.customer_profiles')));
  });

  test('constraint permits only all-null or fully populated acceptance', () {
    expect(
      sql,
      contains('customer_profiles_legal_acceptance_all_or_none'),
    );
    expect(sql, contains('privacy_accepted_at is null'));
    expect(sql, contains('privacy_version is null'));
    expect(sql, contains('terms_accepted_at is null'));
    expect(sql, contains('terms_version is null'));
    expect(sql, contains('privacy_accepted_at is not null'));
    expect(sql, contains("nullif(btrim(privacy_version), '') is not null"));
    expect(sql, contains('terms_accepted_at is not null'));
    expect(sql, contains("nullif(btrim(terms_version), '') is not null"));
  });

  test('trigger copies Auth metadata once and preserves recorded consent', () {
    expect(sql, contains('from auth.users'));
    expect(sql, contains('users.raw_user_meta_data'));
    expect(sql, contains("auth_metadata ->> 'privacy_accepted_at'"));
    expect(sql, contains("auth_metadata ->> 'terms_accepted_at'"));
    expect(sql, contains('new.privacy_accepted_at := old.privacy_accepted_at'));
    expect(sql, contains('new.terms_accepted_at := old.terms_accepted_at'));
    expect(sql, contains('before insert or update'));
  });

  test('migration does not change RLS or collect extra tracking data', () {
    expect(sql, isNot(contains('create policy')));
    expect(sql, isNot(contains('enable row level security')));
    expect(sql, isNot(contains('ip_address')));
    expect(sql, isNot(contains('user_agent')));
    expect(sql, isNot(contains('fingerprint')));
    expect(sql, isNot(contains('coordinates')));
  });
}
