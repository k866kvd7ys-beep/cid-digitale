import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preferred workshop migration adds only the nullable profile column',
      () {
    final sql = File(
      'supabase/migrations/'
      '20260728200000_add_customer_profile_preferred_workshop.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('alter table public.customer_profiles'));
    expect(
      sql,
      contains('add column if not exists preferred_workshop jsonb'),
    );
    expect(sql, isNot(contains('create table')));
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('delete from')));
    expect(sql, isNot(contains('update public.')));
    expect(sql, isNot(contains('policy')));
    expect(sql, isNot(contains('trigger')));
  });
}
