import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/'
      '20260812120000_add_customer_workshop_settings.sql',
    ).readAsStringSync();
  });

  test('adds only the nullable workshop settings field to customer profiles',
      () {
    final normalized = sql.toLowerCase();
    expect(normalized, contains('alter table public.customer_profiles'));
    expect(
      normalized,
      contains('add column if not exists workshop_settings jsonb'),
    );
    expect(normalized, isNot(contains('not null')));
    expect(normalized, isNot(contains('default')));
  });

  test('does not change data, RLS, Auth, Storage or other tables', () {
    final normalized = sql.toLowerCase();
    expect(normalized, isNot(contains('insert into')));
    expect(normalized, isNot(contains('update ')));
    expect(normalized, isNot(contains('delete from')));
    expect(normalized, isNot(contains('create policy')));
    expect(normalized, isNot(contains('drop policy')));
    expect(normalized, isNot(contains('row level security')));
    expect(normalized, isNot(contains('auth.')));
    expect(normalized, isNot(contains('storage.')));
  });
}
