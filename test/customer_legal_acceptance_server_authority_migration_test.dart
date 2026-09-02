import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/'
      '20260809120000_harden_customer_legal_acceptance.sql',
    ).readAsStringSync();
  });

  test('database generates one authoritative timestamp for both documents', () {
    expect(sql, contains('server_accepted_at := now();'));
    expect(
      sql,
      contains('new.privacy_accepted_at := server_accepted_at;'),
    );
    expect(
      sql,
      contains('new.terms_accepted_at := server_accepted_at;'),
    );
  });

  test('client timestamps are registration signals and are never persisted',
      () {
    expect(
      sql,
      contains("auth_metadata ->> 'privacy_accepted_at'"),
    );
    expect(
      sql,
      contains("auth_metadata ->> 'terms_accepted_at'"),
    );
    expect(sql, isNot(contains('metadata_privacy_accepted_at')));
    expect(sql, isNot(contains('metadata_terms_accepted_at')));
    expect(sql, isNot(contains("::timestamptz")));
  });

  test('database validates and persists only the accepted versions', () {
    expect(
      sql,
      contains("is distinct from '2026-08-08'"),
    );
    expect(sql, contains("new.privacy_version := '2026-08-08';"));
    expect(sql, contains("new.terms_version := '2026-08-08';"));
  });

  test('direct profile updates preserve complete and legacy null values', () {
    expect(sql, contains("if tg_op = 'UPDATE' then"));
    expect(
      sql,
      contains('new.privacy_accepted_at := old.privacy_accepted_at;'),
    );
    expect(sql, contains('new.privacy_version := old.privacy_version;'));
    expect(
      sql,
      contains('new.terms_accepted_at := old.terms_accepted_at;'),
    );
    expect(sql, contains('new.terms_version := old.terms_version;'));
  });

  test('migration changes no data, schema, RLS, policies, or trigger', () {
    final normalized = sql.toLowerCase();
    expect(normalized, isNot(contains('alter table')));
    expect(normalized, isNot(contains('update public.customer_profiles')));
    expect(normalized, isNot(contains('insert into')));
    expect(normalized, isNot(contains('delete from')));
    expect(normalized, isNot(contains('create policy')));
    expect(normalized, isNot(contains('drop policy')));
    expect(normalized, isNot(contains('row level security')));
    expect(normalized, isNot(contains('create trigger')));
    expect(normalized, isNot(contains('drop trigger')));
  });
}
